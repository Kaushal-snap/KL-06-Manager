import AppKit
import Foundation
import Darwin

enum NativeBridgePolicy {
    static let settingIDs = Set(["display", "audio", "keyboard", "trackpad", "battery", "accessibility", "login", "wifi", "bluetooth", "storage", "notifications"])
    static func allowed(_ operation: String, _ params: [String: Any]) -> Bool {
        if ["state", "startCompanion", "stopCompanion", "companionDetails", "pickHistoryCSV", "powerSample", "exportReport", "purgeMemory", "cleanCaches", "checkUpdates", "scanPeers"].contains(operation) { return params.isEmpty }
        if operation == "restartUI" { return Set(params.keys) == ["app"] && ["Dock", "Finder"].contains(params["app"] as? String ?? "") }
        if operation == "openSetting" { return Set(params.keys) == ["id"] && settingIDs.contains(params["id"] as? String ?? "") }
        if operation == "setPowerProfile" { return Set(params.keys) == ["profile"] && ["High Performance", "Balanced", "Battery Saver"].contains(params["profile"] as? String ?? "") }
        if operation == "setBatteryLimit" { return Set(params.keys) == ["limit"] && [60, 80, 100].contains((params["limit"] as? NSNumber)?.intValue ?? -1) }
        if operation == "sendPeerFile" { return Set(params.keys) == ["peerId"] && (params["peerId"] as? String)?.isEmpty == false }
        return CompanionPolicy.allowed(operation, params)
    }
}
enum CompanionPolicy {
    static func privateIPv4(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        var n: [Int] = []
        for p in parts { guard !p.isEmpty, p.allSatisfy({ $0.isASCII && $0.isNumber }), let v = Int(p), v <= 255, String(v) == p else { return false }; n.append(v) }
        return n[0] == 10 || (n[0] == 172 && (16...31).contains(n[1])) || (n[0] == 192 && n[1] == 168)
    }
    static func allowed(_ operation: String, _ params: [String: Any]) -> Bool {
        switch operation {
        case "setVolume", "setBrightness":
            guard Set(params.keys) == ["value"], let n = params["value"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return false }
            let minVal: Double = operation == "setBrightness" ? 1 : 0
            return n.doubleValue.isFinite && (minVal...100).contains(n.doubleValue)
        case "applyTweak", "restoreTweak": return Set(params.keys) == ["id"] && Tweak.all.contains { $0.id == params["id"] as? String }
        case "restoreAll", "keepAwake": return params.isEmpty
        default: return false
        }
    }
}
// Explicit user-session broker. No root helper, login item, firewall change or cloud endpoint.
final class DesktopCompanion {
    private static let uptimeScale: Double = {
        var info = mach_timebase_info_data_t()
        guard mach_timebase_info(&info) == KERN_SUCCESS, info.numer > 0, info.denom > 0 else { return .infinity }
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()
    static var uptime: Double { Double(mach_absolute_time()) * uptimeScale }
    private var task: Process?
    private var folder: URL?
    private var timer: Timer?
    private var processing = false
    private var activeRequest: URL?
    var requestIsActive: Bool { isRunning && activeRequest.map { FileManager.default.fileExists(atPath: $0.path) } == true }
    var snapshot: (() -> [String: Any])?
    var readyToPrompt: (() -> Bool)?
    var approvePair: ((String) -> Bool)?
    /// (platform, sanitized file name, size in bytes) -> the laptop owner's decision for an incoming file.
    var approveTransfer: ((String, String, Int64) -> Bool)?
    var perform: ((String, [String: Any], TimeInterval, TimeInterval) -> (Bool, String))?
    var isRunning: Bool { task?.isRunning == true }
    private func write(_ value: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        try data.write(to: url, options: [.atomic]); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private func read(_ url: URL, max: Int = 16384) throws -> [String: Any] {
        let a = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (a[.type] as? FileAttributeType) == .typeRegular, let size = a[.size] as? NSNumber, size.intValue <= max else { throw ControlError(message: "Unsafe companion record.") }
        let data = try Data(contentsOf: url)
        guard data.count <= max, let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ControlError(message: "Invalid companion record.") }
        return result
    }
    private func python() -> String? {
        // Only already-installed interpreters. No xcode-select install or downloads.
        let select = Process(); let pipe = Pipe(); select.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select"); select.arguments = ["-p"]; select.standardOutput = pipe; select.standardError = FileHandle.nullDevice
        var candidates = ["/usr/local/bin/python3", "/opt/homebrew/bin/python3"]
        if (try? select.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile(); select.waitUntilExit()
            if select.terminationStatus == 0, let directory = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), directory.hasPrefix("/") { candidates.insert(directory + "/usr/bin/python3", at: 0) }
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    func start(bind: String, resourceURL: URL) throws {
        guard !isRunning, getuid() != 0, CompanionPolicy.privateIPv4(bind), let interpreter = python() else { throw ControlError(message: "Use a LAN IPv4 address and an already-installed Python 3 interpreter. No component was downloaded or enabled.") }
        stop()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("KL06-Companion-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]); folder = root
        do {
            let certificate = Process(); certificate.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
            certificate.arguments = ["req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes", "-days", "1", "-subj", "/CN=KL-06-Local-Companion", "-keyout", root.appendingPathComponent("key.pem").path, "-out", root.appendingPathComponent("cert.pem").path]
            certificate.standardOutput = FileHandle.nullDevice; certificate.standardError = FileHandle.nullDevice
            try certificate.run(); certificate.waitUntilExit()
            guard certificate.terminationStatus == 0 else { throw ControlError(message: "Local certificate creation failed. Nothing was installed or globally trusted.") }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: root.appendingPathComponent("key.pem").path)
            let process = Process(); process.executableURL = URL(fileURLWithPath: interpreter)
            process.arguments = ["-I", resourceURL.appendingPathComponent("Companion/server.py").path, "--directory", root.path, "--bind", bind]
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try process.run(); task = process
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
            tick()
        } catch { stop(); throw error }
    }
    func details() throws -> [String: Any] {
        guard isRunning, let folder = folder else { throw ControlError(message: "Companion is not running.") }
        let value = try read(folder.appendingPathComponent("session.json"))
        guard let expiry = value["pairCodeExpiresAt"] as? Double, let uptimeExpiry = value["pairCodeExpiresMonotonic"] as? Double, expiry > Date().timeIntervalSince1970, uptimeExpiry > DesktopCompanion.uptime else { throw ControlError(message: "Pairing code expired. Stop and explicitly start a new session; existing tokens are not silently extended.") }
        return value
    }
    func tick() {
        guard !processing else { return }
        guard isRunning, let root = folder else { if folder != nil { stop() }; return }
        processing = true; defer { processing = false }
        if let value = snapshot?() { try? write(["schema": "KL06_DESKTOP_SNAPSHOT_V1", "writtenAt": Date().timeIntervalSince1970, "state": value], to: root.appendingPathComponent("snapshot.json")) }
        guard readyToPrompt?() != false else { return }
        let requests = root.appendingPathComponent("requests", isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(at: requests, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.lastPathComponent.range(of: "^[a-f0-9]{32}\\.json$", options: .regularExpression) != nil else { continue }
            defer { try? FileManager.default.removeItem(at: url) }
            guard let message = try? read(url), let id = message["id"] as? String, id + ".json" == url.lastPathComponent,
                  message["schema"] as? String == "KL06_COMPANION_V1", let expires = message["expiresAt"] as? Double,
                  let created = message["createdAt"] as? Double, created <= Date().timeIntervalSince1970 + 2, expires >= created, expires - created <= 91,
                  let createdUptime = message["createdMonotonic"] as? Double, let uptimeDeadline = message["expiresMonotonic"] as? Double, createdUptime <= DesktopCompanion.uptime + 2, uptimeDeadline >= createdUptime, uptimeDeadline - createdUptime <= 91, uptimeDeadline > DesktopCompanion.uptime,
                  expires > Date().timeIntervalSince1970 else { continue }
            var reply: [String: Any] = ["ok": false, "approved": false, "message": "Refused or expired."]
            if message["kind"] as? String == "pair", let platform = message["platform"] as? String, ["android", "ios"].contains(platform) {
                reply["approved"] = approvePair?(platform) == true && expires > Date().timeIntervalSince1970 && uptimeDeadline > DesktopCompanion.uptime && isRunning
            } else if message["kind"] as? String == "transfer", let platform = message["platform"] as? String,
                      ["android", "ios", "macos", "windows", "unknown"].contains(platform),
                      let name = message["fileName"] as? String, !name.isEmpty, name.utf8.count <= 255,
                      !name.contains("/"), !name.contains("\\"), !name.contains("\0"),
                      let sizeNumber = message["fileSize"] as? NSNumber, CFGetTypeID(sizeNumber) != CFBooleanGetTypeID(),
                      sizeNumber.int64Value >= 0, sizeNumber.int64Value <= 2 * 1024 * 1024 * 1024 {
                let approved = approveTransfer?(platform, name, sizeNumber.int64Value) == true && expires > Date().timeIntervalSince1970 && uptimeDeadline > DesktopCompanion.uptime && isRunning
                reply["approved"] = approved; reply["ok"] = approved
                reply["message"] = approved ? "Accepted on the laptop." : "Declined or expired on the laptop."
            } else if message["kind"] as? String == "command", let operation = message["operation"] as? String,
                      let params = message["params"] as? [String: Any], CompanionPolicy.allowed(operation, params) {
                activeRequest = url
                let outcome = perform?(operation, params, expires, uptimeDeadline) ?? (false, "No native handler available.")
                activeRequest = nil
                reply["ok"] = outcome.0; reply["message"] = outcome.1
            }
            try? write(reply, to: requests.appendingPathComponent(id + ".result.json"))
        }
    }
    /// Really paired phones (written by the broker; never contains tokens). Empty when nothing is paired.
    func peers() -> [String: Any] {
        guard isRunning, let folder = folder, let value = try? read(folder.appendingPathComponent("peers.json"), max: 65536) else { return ["peers": [], "outbox": []] }
        return ["peers": value["peers"] as? [[String: Any]] ?? [], "outbox": value["outbox"] as? [[String: Any]] ?? []]
    }
    /// Queue a file the owner picked in the native open panel for download by a paired phone.
    /// Only the path is written (0600, private temp folder); the broker re-validates it and hashes it itself.
    func queueOutbox(path: String) throws {
        guard isRunning, let folder = folder else { throw ControlError(message: "Start the temporary companion session and pair a phone first.") }
        var info = stat()
        guard path.hasPrefix("/"), lstat(path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_nlink == 1, info.st_uid == getuid(),
              info.st_size <= 2 * 1024 * 1024 * 1024 else { throw ControlError(message: "Choose one of your own regular files up to 2 GB (no folders, links or aliases).") }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let now = Date().timeIntervalSince1970
        try write(["schema": "KL06_OUTBOX_V1", "id": id, "path": path, "createdAt": now, "expiresAt": now + 600], to: folder.appendingPathComponent("outbox", isDirectory: true).appendingPathComponent(id + ".json"))
    }
    func stop() {
        timer?.invalidate(); timer = nil; activeRequest = nil
        task?.terminate(); task = nil
        if let ownFolder = folder { try? FileManager.default.removeItem(at: ownFolder) }
        folder = nil
    }
    deinit { stop() }
}
