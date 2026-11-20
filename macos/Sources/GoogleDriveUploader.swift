import AppKit
import Foundation
import Network
import Security
import CryptoKit

/// Native Google Drive uploader. Uses a Desktop OAuth client, PKCE, loopback
/// redirect, drive.file scope, and Keychain refresh-token storage. No web server.
final class GoogleDriveUploader {
    static let shared = GoogleDriveUploader()
    private let service = "app.klasus.controlcenter.google-drive"
    private let queue = DispatchQueue(label: "app.klasus.google-drive.oauth")
    private let session = URLSession(configuration: .ephemeral)
    private let scope = "https://www.googleapis.com/auth/drive.file"
    private init() {}

    var isConnected: Bool { keychainRead("refreshToken") != nil && keychainRead("clientID") != nil }
    var configuredClientID: String? { keychainRead("clientID") }

    func connect(clientID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard clientID.range(of: #"^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$"#, options: .regularExpression) != nil else {
            completion(.failure(error("Enter a valid Google Desktop OAuth client ID."))); return
        }
        keychainWrite(clientID, account: "clientID")
        authorize(clientID: clientID, completion: completion)
    }

    func upload(_ report: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard report.count <= 2 * 1024 * 1024 else { completion(.failure(error("Diagnostic report exceeds the 2 MiB upload limit."))); return }
        guard let clientID = keychainRead("clientID"), let refresh = keychainRead("refreshToken") else {
            completion(.failure(error("Google Drive is not connected. Choose Connect Google Drive first."))); return
        }
        refreshAccessToken(clientID: clientID, refreshToken: refresh) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success(let token): self.uploadWithAccessToken(report, token: token, completion: completion)
            }
        }
    }

    private func authorize(clientID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let verifier = randomURLSafe(64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        let state = randomURLSafe(32)
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host("127.0.0.1"), port: .any)
        let listener: NWListener
        do { listener = try NWListener(using: parameters, on: .any) }
        catch { completion(.failure(error)); return }
        var redirectURI = ""
        listener.newConnectionHandler = { [weak listener] connection in
            connection.start(queue: self.queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, receiveError in
                guard receiveError == nil, let data, let request = String(data: data, encoding: .utf8),
                      let first = request.components(separatedBy: "\r\n").first,
                      let path = first.split(separator: " ").dropFirst().first,
                      let callback = URLComponents(string: "http://127.0.0.1\(path)"),
                      let returnedState = callback.queryItems?.first(where: { $0.name == "state" })?.value,
                      returnedState == state,
                      let code = callback.queryItems?.first(where: { $0.name == "code" })?.value else {
                    let body = "Authorization failed. You can close this browser tab."
                    let response = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                    connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in connection.cancel() })
                    listener?.cancel()
                    completion(.failure(self.error("Google OAuth callback was invalid or cancelled.")))
                    return
                }
                let body = "Google Drive connected to KL-06. You can close this tab and return to the app."
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in connection.cancel() })
                listener?.cancel()
                self.exchangeCode(code, verifier: verifier, redirectURI: redirectURI, clientID: clientID, completion: completion)
            }
        }
        listener.stateUpdateHandler = { stateValue in
            guard case .ready = stateValue, let port = listener.port?.rawValue else {
                if case .failed(let e) = stateValue { listener.cancel(); completion(.failure(e)) }
                return
            }
            redirectURI = "http://127.0.0.1:\(port)"
            var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: self.scope),
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "consent"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
            guard let url = components.url, NSWorkspace.shared.open(url) else {
                listener.cancel(); completion(.failure(self.error("Could not open the system browser for Google authorization."))); return
            }
        }
        listener.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 180) {
            if listener.state != .cancelled {
                listener.cancel()
                completion(.failure(self.error("Google authorization timed out after three minutes.")))
            }
        }
    }

    private func exchangeCode(_ code: String, verifier: String, redirectURI: String, clientID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let body = form([
            "client_id": clientID, "code": code, "code_verifier": verifier,
            "grant_type": "authorization_code", "redirect_uri": redirectURI
        ])
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type"); request.httpBody = body
        session.dataTask(with: request) { data, response, failure in
            if let failure { completion(.failure(failure)); return }
            guard let data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let refresh = json["refresh_token"] as? String else {
                completion(.failure(self.apiError(data, response, fallback: "Google did not return a refresh token. Reconnect and approve Drive access."))); return
            }
            self.keychainWrite(refresh, account: "refreshToken")
            completion(.success(()))
        }.resume()
    }

    private func refreshAccessToken(clientID: String, refreshToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form(["client_id": clientID, "refresh_token": refreshToken, "grant_type": "refresh_token"])
        session.dataTask(with: request) { data, response, failure in
            if let failure { completion(.failure(failure)); return }
            guard let data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else {
                completion(.failure(self.apiError(data, response, fallback: "Could not refresh Google Drive authorization. Reconnect the account."))); return
            }
            completion(.success(token))
        }.resume()
    }

    private func uploadWithAccessToken(_ report: Data, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        let proceed: (String) -> Void = { folderID in
            let boundary = "KL06-\(UUID().uuidString)"
            let name = "KL-06-diagnostics-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).json"
            var body = Data()
            body.append("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
            let metadata: [String: Any] = ["name": name, "mimeType": "application/json", "parents": [folderID]]
            body.append((try! JSONSerialization.data(withJSONObject: metadata)) )
            body.append("\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".data(using: .utf8)!)
            body.append(report)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            var request = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink")!)
            request.httpMethod = "POST"; request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type"); request.httpBody = body
            self.session.dataTask(with: request) { data, response, failure in
                if let failure { completion(.failure(failure)); return }
                guard let data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let fileID = json["id"] as? String else {
                    completion(.failure(self.apiError(data, response, fallback: "Google Drive rejected the diagnostic upload."))); return
                }
                completion(.success("Uploaded privately to My Drive / KL-06 Diagnostics. File ID: \(fileID)"))
            }.resume()
        }
        if let folder = keychainRead("folderID") { proceed(folder); return }
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files?fields=id")!)
        request.httpMethod = "POST"; request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["name": "KL-06 Diagnostics", "mimeType": "application/vnd.google-apps.folder"])
        session.dataTask(with: request) { data, response, failure in
            if let failure { completion(.failure(failure)); return }
            guard let data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let folder = json["id"] as? String else {
                completion(.failure(self.apiError(data, response, fallback: "Could not create the private diagnostics folder."))); return
            }
            self.keychainWrite(folder, account: "folderID"); proceed(folder)
        }.resume()
    }

    func disconnect() {
        ["clientID", "refreshToken", "folderID"].forEach { keychainDelete($0) }
    }

    private func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let value = values.keys.sorted().map { key in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = values[key]!.addingPercentEncoding(withAllowedCharacters: allowed) ?? values[key]!
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return value.data(using: .utf8)!
    }
    private func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded
    }
    private func keychainRead(_ account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func keychainWrite(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var add = query; attrs.forEach { add[$0.key] = $0.value }; SecItemAdd(add as CFDictionary, nil)
        }
    }
    private func keychainDelete(_ account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
    private func apiError(_ data: Data?, _ response: URLResponse?, fallback: String) -> Error {
        if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any], let message = error["message"] as? String { return self.error(message) }
        if let http = response as? HTTPURLResponse { return self.error("\(fallback) HTTP \(http.statusCode).") }
        return self.error(fallback)
    }
    private func error(_ message: String) -> NSError { NSError(domain: "KL06.GoogleDrive", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
