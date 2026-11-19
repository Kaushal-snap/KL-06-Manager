import Foundation
import CoreFoundation
import Network
import Security
import CryptoKit

enum LANError: Error { case invalid, unavailable, refused }
struct LANHTTP {
    static func privateURL(_ raw: String) -> URL? {
        guard let c = URLComponents(string: raw), c.scheme == "https", c.port == 8766,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.path.isEmpty || c.path == "/", let host = c.host else { return nil }
        let p = host.split(separator: ".", omittingEmptySubsequences: false)
        guard p.count == 4 else { return nil }
        var v: [Int] = []
        for part in p { guard let n = Int(part), (0...255).contains(n), String(n) == String(part) else { return nil }; v.append(n) }
        guard v[0] == 10 || (v[0] == 172 && (16...31).contains(v[1])) || (v[0] == 192 && v[1] == 168) else { return nil }
        return c.url
    }
    static func post(base: URL, pin: String, path: String, body: [String: Any], token: String?) async throws -> [String: Any] {
        guard let host = base.host, privateURL(base.absoluteString) != nil, pin.range(of: "^[a-f0-9]{64}\\z", options: .regularExpression) != nil,
              ["/v1/pair", "/v1/pair/finish", "/v1/state", "/v1/command", "/v1/result", "/v1/disconnect"].contains(path) else { throw LANError.invalid }
        let raw = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        guard raw.count <= 16384 else { throw LANError.invalid }
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "app.kl06.pinned-lan")
            let tls = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
            sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, trust, complete in
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                guard let certificate = SecTrustCopyCertificateChain(secTrust, 0) else { complete(false); return }
                let hash = SHA256.hash(data: SecCertificateCopyData(certificate) as Data).map { String(format: "%02x", $0) }.joined()
                // Trust only the full out-of-band owner-confirmed pin for this one session.
                // No global trust store/ATS exception or trust-all URLSession delegate.
                let a = Array(hash.utf8), b = Array(pin.utf8)
                complete(a.count == b.count && zip(a,b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0)
            }, queue)
            let connection = NWConnection(host: NWEndpoint.Host(host), port: 8766, using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))
            let lock = NSLock(); var finished = false; var received = Data()
            func finish(_ result: Result<[String: Any], Error>) {
                lock.lock(); if finished { lock.unlock(); return }; finished = true; lock.unlock()
                connection.stateUpdateHandler = nil; connection.cancel(); continuation.resume(with: result)
            }
            func read() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, complete, error in
                    if let data = data { received.append(data) }
                    guard received.count <= 280000 else { finish(.failure(LANError.refused)); return }
                    if let range = received.range(of: Data("\r\n\r\n".utf8)) {
                        guard range.lowerBound <= 8192, let header = String(data: received[..<range.lowerBound], encoding: .ascii) else { finish(.failure(LANError.refused)); return }
                        let lines = header.components(separatedBy: "\r\n")
                        let status = lines.first?.split(separator: " ").dropFirst().first.flatMap { Int($0) }
                        guard status == 200 || status == 202, !header.lowercased().contains("transfer-encoding:") else { finish(.failure(LANError.refused)); return }
                        let lengths = lines.filter { $0.lowercased().hasPrefix("content-length:") }
                        guard lengths.count == 1, let length = Int(lengths[0].split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)), (0...262144).contains(length) else { finish(.failure(LANError.refused)); return }
                        let content = received[range.upperBound...]
                        if content.count >= length {
                            do { guard let object = try JSONSerialization.jsonObject(with: Data(content.prefix(length))) as? [String: Any] else { throw LANError.refused }; finish(.success(object)) } catch { finish(.failure(LANError.refused)) }
                            return
                        }
                    }
                    if error != nil || complete { finish(.failure(LANError.unavailable)); return }
                    read()
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var header = "POST \(path) HTTP/1.1\r\nHost: \(host):8766\r\nContent-Type: application/json\r\nContent-Length: \(raw.count)\r\nConnection: close\r\n"
                    if let token = token { guard token.range(of: "^[a-f0-9]{64}\\z", options: .regularExpression) != nil else { finish(.failure(LANError.invalid)); return }; header += "Authorization: Bearer \(token)\r\n" }
                    var request = Data((header + "\r\n").utf8); request.append(raw)
                    connection.send(content: request, completion: .contentProcessed { error in if error != nil { finish(.failure(LANError.unavailable)) } else { read() } })
                case .failed: finish(.failure(LANError.unavailable))
                default: break
                }
            }
            queue.asyncAfter(deadline: .now() + 12) { finish(.failure(LANError.unavailable)) }
            connection.start(queue: queue)
        }
    }
}
actor PinnedLaptop {
    private var base: URL?, pin: String?, code: String?, ticket: String?, token: String?, last: String?
    private var expiry: Double = 0
    private var busy = false
    func paired() -> Bool { token != nil && Date().timeIntervalSince1970 < expiry }
    private func send(_ path: String, _ body: [String: Any], auth: Bool) async throws -> [String: Any] {
        guard !busy, let base = base, let pin = pin, !auth || paired() else { throw LANError.invalid }
        busy = true; defer { busy = false }
        return try await LANHTTP.post(base: base, pin: pin, path: path, body: body, token: auth ? token : nil)
    }
    func pair(_ p: [String: Any]) async throws -> [String: Any] {
        guard !busy, Set(p.keys) == ["host", "pin", "code"], let host = p["host"] as? String, let url = LANHTTP.privateURL(host), let fingerprint = (p["pin"] as? String)?.lowercased(), fingerprint.range(of: "^[a-f0-9]{64}\\z", options: .regularExpression) != nil,
              let secret = (p["code"] as? String)?.lowercased(), secret.range(of: "^[a-f0-9]{32}\\z", options: .regularExpression) != nil else { throw LANError.invalid }
        base = url; pin = fingerprint; code = secret; token = nil; expiry = 0; ticket = nil; last = nil
        let result = try await send("/v1/pair", ["code": secret, "platform": "ios"], auth: false)
        guard let identifier = result["ticket"] as? String else { throw LANError.refused }; ticket = identifier
        return ["status": "Approve this iOS device on the laptop, then finish pairing."]
    }
    func finish() async throws -> [String: Any] {
        guard !busy, let ticket = ticket, let code = code else { throw LANError.invalid }
        let result = try await send("/v1/pair/finish", ["ticket": ticket, "code": code], auth: false)
        if result["status"] as? String == "paired" {
            guard let token = result["token"] as? String, token.range(of: "^[a-f0-9]{64}\\z", options: .regularExpression) != nil, let expires = result["expiresAt"] as? Double else { throw LANError.refused }
            self.token = token; expiry = expires; self.ticket = nil; self.code = nil
        }
        return ["status": paired() ? "Paired. Every write still requires laptop confirmation." : "Awaiting laptop confirmation."]
    }
    func state() async throws -> [String: Any] { try await send("/v1/state", [:], auth: true) }
    private func allowed(_ operation: String, _ p: [String: Any]) -> Bool {
        switch operation {
        case "setVolume", "setBrightness":
            guard Set(p.keys) == ["value"], let value = p["value"] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return false }
            let minVal: Double = operation == "setBrightness" ? 1.0 : 0.0
            return value.doubleValue.isFinite && (minVal...100).contains(value.doubleValue)
        case "applyTweak", "restoreTweak":
            let ids = Set(["dock-autohide", "dock-reveal", "dock-scale", "dock-launch", "finder-path", "finder-status", "finder-hidden", "file-extensions", "scrollbars", "dock-recents", "finder-folders-first", "natural-scroll", "win-extensions", "win-hidden", "win-theme-dark"])
            return Set(p.keys) == ["id"] && ids.contains(p["id"] as? String ?? "")
        case "restoreAll", "keepAwake": return p.isEmpty
        default: return false
        }
    }
    func command(_ body: [String: Any]) async throws -> [String: Any] {
        guard Set(body.keys) == ["operation", "params"], let operation = body["operation"] as? String, ["setVolume", "setBrightness", "applyTweak", "restoreTweak", "restoreAll", "keepAwake"].contains(operation), let p = body["params"] as? [String: Any], allowed(operation, p) else { throw LANError.invalid }
        let result = try await send("/v1/command", body, auth: true); last = result["id"] as? String
        return ["status": "Queued; confirm the requested action on the laptop within 90 seconds."]
    }
    func result() async throws -> [String: Any] { guard let last = last else { throw LANError.invalid }; return try await send("/v1/result", ["id": last], auth: true) }
    func disconnect() async -> [String: Any] {
        guard !busy else { return ["status": "A LAN request is still running. Retry disconnect shortly."] }
        _ = try? await send("/v1/disconnect", [:], auth: true)
        base = nil; pin = nil; code = nil; token = nil; ticket = nil; last = nil; expiry = 0
        return ["status": "Disconnected locally. Stop the laptop session to revoke all devices if unreachable."]
    }
}
