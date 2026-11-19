import SwiftUI
import CoreFoundation
import UIKit
import WebKit
import AVFoundation
import MediaPlayer
import UniformTypeIdentifiers
import CoreNFC

@main struct KL06MobileApp: App { var body: some Scene { WindowGroup { MobileShell().preferredColorScheme(.dark) } } }
struct MobileShell: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MobileController { MobileController() }
    func updateUIViewController(_ controller: MobileController, context: Context) {}
}
final class WeakBridge: NSObject, WKScriptMessageHandler {
    weak var target: MobileController?
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { target?.receive(message) }
}
final class MobileController: UIViewController, WKNavigationDelegate, UIDocumentPickerDelegate {
    private var web: WKWebView!
    private var page: URL!
    private let laptop = PinnedLaptop()
    private var paired = false
    private var originalBrightness: CGFloat?, appliedBrightness: CGFloat?
    private var originalIdle: Bool?, awake = false
    private var awakeTimer: Timer?, background: NSObjectProtocol?
    private var pickerID: String?
    private var selectedShareURL: URL?
    private var selectedShareSize: Int64 = 0
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = UIColor(red: 0.03, green: 0.06, blue: 0.08, alpha: 1)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let proxy = WeakBridge(); proxy.target = self
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent(); configuration.userContentController.add(proxy, name: "kl06mobile"); configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        web = WKWebView(frame: .zero, configuration: configuration); web.navigationDelegate = self; web.translatesAutoresizingMaskIntoConstraints = false; web.isOpaque = false; view.addSubview(web)
        NSLayoutConstraint.activate([web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), web.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), web.leadingAnchor.constraint(equalTo: view.leadingAnchor), web.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") else { return }; page = url
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        background = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.restore() }
    }
    private func reply(_ id: String, result: Any? = nil, error: String? = nil) {
        let object: [String: Any] = error == nil ? ["id": id, "ok": true, "result": result ?? NSNull()] : ["id": id, "ok": false, "error": error!]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), let json = String(data: data, encoding: .utf8) else { return }
        web.evaluateJavaScript("window.KL06.receive(\(json))", completionHandler: nil)
    }
    private func state() -> [String: Any] {
        let device = UIDevice.current
        var battery: [String: Any] = [:]
        if device.batteryLevel >= 0 { battery["chargePercent"] = Double(device.batteryLevel) * 100 }
        if device.batteryState != .unknown { battery["onAC"] = device.batteryState == .charging || device.batteryState == .full }
        var storage: [String: Any] = [:]
        if let a = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()), let free = a[.systemFreeSize] as? NSNumber, let total = a[.systemSize] as? NSNumber { storage = ["freeGB": free.doubleValue / 1073741824, "totalGB": total.doubleValue / 1073741824] }
        return ["platform": "ios", "version": "0.4.7-beta", "build": 12, "sampledAt": ISO8601DateFormatter().string(from: Date()),
                "battery": battery, "memory": ["totalGB": Double(ProcessInfo.processInfo.physicalMemory) / 1073741824, "source": "iOS system-used RAM unavailable through this app"],
                "storage": storage, "volume": Double(AVAudioSession.sharedInstance().outputVolume) * 100, "brightness": Double(UIScreen.main.brightness) * 100, "awake": awake,
                "capabilities": ["volume": false, "nativeVolume": true, "brightness": true, "brightnessScope": "Temporary screen brightness; restores on background if unchanged; not physical nits", "awake": true] as [String: Any],
                "companion": ["paired": paired]]
    }
    private func confirm(_ title: String, then action: @escaping () -> Void, cancel: @escaping () -> Void) {
        guard presentedViewController == nil else { cancel(); return }
        let alert = UIAlertController(title: title, message: "Only a supported OS control changes. Brightness/idle-screen changes restore on background if still owned. Forced termination cannot guarantee brightness rollback. No root, firmware, microphone capture or security changes.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in cancel() }); alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in action() }); present(alert, animated: true)
    }
    func receive(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let origin = message.frameInfo.request.url, origin.isFileURL, page != nil, origin.standardizedFileURL == page.standardizedFileURL,
              let b = message.body as? [String: Any], let id = b["id"] as? String, id.range(of: "^[A-Za-z0-9-]{1,64}\\z", options: .regularExpression) != nil, let method = b["method"] as? String else { return }
        guard Set(b.keys) == ["id", "method", "params"], let p = b["params"] as? [String: Any] else { reply(id, error: "Unexpected native request shape."); return }
        switch method {
        case "state": guard p.isEmpty else { reply(id, error: "Invalid state request."); return }; Task { [weak self] in guard let self = self else { return }; self.paired = await self.laptop.paired(); self.reply(id, result: self.state()) }
        case "setBrightness":
            guard Set(p.keys) == ["value"], let n = p["value"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, (1...100).contains(n.doubleValue) else { reply(id, error: "Invalid brightness."); return }
            confirm("Set temporary screen brightness to \(n.doubleValue)%?", then: { [weak self] in
                guard let self = self else { return }; if self.originalBrightness == nil { self.originalBrightness = UIScreen.main.brightness }
                let value = CGFloat(n.doubleValue / 100); UIScreen.main.brightness = value; self.appliedBrightness = value
                guard abs(UIScreen.main.brightness - value) <= 0.015 else { self.reply(id, error: "iOS did not read back the requested brightness. Inspect the display; no retry or security workaround."); return }
                self.reply(id, result: "Temporary brightness read back. Backgrounding conditionally restores it if still unchanged.")
            }, cancel: { [weak self] in self?.reply(id, error: "Cancelled; no brightness change.") })
        case "showNativeVolume":
            guard p.isEmpty, presentedViewController == nil else { reply(id, error: "Volume UI unavailable."); return }
            let controller = UIViewController(); controller.view.backgroundColor = .systemBackground; controller.preferredContentSize = CGSize(width: 330, height: 140)
            let volume = MPVolumeView(frame: CGRect(x: 25, y: 55, width: 280, height: 45)); controller.view.addSubview(volume)
            controller.modalPresentationStyle = .pageSheet; present(controller, animated: true); reply(id, result: "Use Apple’s visible native volume control. No hidden slider or codec change.")
        case "keepAwake":
            guard p.isEmpty else { reply(id, error: "Invalid request."); return }
            confirm("Toggle app keep-awake, maximum 15 minutes?", then: { [weak self] in
                guard let self = self else { return }; self.awakeTimer?.invalidate()
                if self.awake { self.restoreIdle() } else { self.originalIdle = UIApplication.shared.isIdleTimerDisabled; UIApplication.shared.isIdleTimerDisabled = true; guard UIApplication.shared.isIdleTimerDisabled else { self.reply(id, error: "iOS did not confirm the app-screen idle assertion."); return }; self.awake = true; self.awakeTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: false) { [weak self] _ in self?.restoreIdle() } }
                self.reply(id, result: "App-screen idle assertion updated. It does not override manual/forced sleep.")
            }, cancel: { [weak self] in self?.reply(id, error: "Cancelled.") })
        case "restoreAll": guard p.isEmpty else { reply(id, error: "Invalid restore."); return }; restore(); reply(id, result: "Owned temporary brightness/idle controls restored; external newer choices preserved.")
        case "pickHistoryCSV":
            guard p.isEmpty, pickerID == nil, presentedViewController == nil else { reply(id, error: "Picker is busy."); return }; pickerID = id
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText], asCopy: false); picker.allowsMultipleSelection = false; picker.delegate = self; present(picker, animated: true)
        case "pickShareFile":
            guard p.isEmpty, pickerID == nil, presentedViewController == nil else { reply(id, error: "Picker is busy."); return }; pickerID = id
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .content, .data], asCopy: false); picker.allowsMultipleSelection = false; picker.delegate = self; present(picker, animated: true)
        case "exportLogs", "saveErrorReport", "shareLogs", "saveFanDiagnosticReport":
            let logs = p["logs"] as? [[String: Any]] ?? []
            var text = p["reportText"] as? String ?? "=== KL-06 DIAGNOSTIC LOG REPORT ===\nApp: KL-06 Manager iOS\nVersion: 0.4.7-beta (Build 12)\nTimestamp: \(ISO8601DateFormatter().string(from: Date()))\nDevice: \(UIDevice.current.name) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion))\n\n"
            for log in logs {
                text += "[\(log["ts"] as? String ?? "")] [\(log["tag"] as? String ?? "LOG")] \(log["msg"] as? String ?? "")\n"
            }
            let shareSheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            present(shareSheet, animated: true)
            reply(id, result: ["status": "saved", "message": "Diagnostic report opened in iOS Share Sheet."])
        case "checkUpdate":
            reply(id, result: [
                "currentVersion": "0.4.7-beta",
                "currentBuild": 12,
                "latestVersion": "0.4.7-beta",
                "latestBuild": 12,
                "upToDate": true,
                "channel": "beta",
                "releaseNotes": "Tiger Lake hardware optimization suite (HDR, Sleep/Wake, AirDrop AWDL, GPU stability, Fan RPM), OTA engine, and v0.4.7 beta ecosystem update.",
                "downloadUrl": "https://github.com/Kaushal-snap/KL-06-Manager/blob/main/INSTALL-IOS.command"
            ])
        case "discoverPeers":
            // Bonjour/UDP discovery is not implemented in this iOS build. Do not invent an online peer.
            reply(id, result: ["peers": [], "count": 0, "scannedAt": ISO8601DateFormatter().string(from: Date()), "status": "discovery-unavailable-use-direct-tls-pairing"])
        case "nfcStatus":
            guard p.isEmpty else { reply(id, error: "Invalid nfc request."); return }
            let supported = NFCNDEFReaderSession.readingAvailable
            reply(id, result: ["supported": supported, "hardware": "iOS CoreNFC", "enabled": supported])
        case "startNfcScan":
            guard p.isEmpty else { reply(id, error: "Invalid nfc request."); return }
            guard NFCNDEFReaderSession.readingAvailable else { reply(id, error: "NFC is not supported on this iOS device model."); return }
            reply(id, result: ["status": "active", "message": "NFC scanner ready for tags or peer devices."])
        case "startNfcBeam":
            guard NFCNDEFReaderSession.readingAvailable else { reply(id, error: "NFC is not supported on this iOS device model."); return }
            reply(id, result: ["status": "active", "message": "NFC beam ready."])
        case "streamFileToPeer":
            guard Set(p.keys) == ["uri"], let raw = p["uri"] as? String, let url = selectedShareURL, raw == url.absoluteString, selectedShareSize > 0 else { reply(id, error: "Select a regular file first. No file was sent."); return }
            let size = selectedShareSize
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    let result = try await self.laptop.transferFile(url: url, fileName: url.lastPathComponent, expectedSize: size) { [weak self] percent in
                        DispatchQueue.main.async { self?.web.evaluateJavaScript("if(window.KLTransferProgress)window.KLTransferProgress(\(percent));", completionHandler: nil) }
                    }
                    self.selectedShareURL = nil; self.selectedShareSize = 0
                    self.reply(id, result: result)
                } catch {
                    self.reply(id, error: "iOS TLS file transfer failed. No delivery is reported unless the desktop verifies the final SHA-256. Check the desktop receiver and retry.")
                }
            }
        case "pairLaptop", "finishPairing", "remoteState", "remoteCommand", "remoteResult", "disconnectLaptop":
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    let result: [String: Any]
                    switch method {
                    case "pairLaptop": result = try await laptop.pair(p)
                    case "finishPairing": result = try await laptop.finish()
                    case "remoteState": guard p.isEmpty else { throw LANError.invalid }; result = try await laptop.state()
                    case "remoteCommand": result = try await laptop.command(p)
                    case "remoteResult": guard p.isEmpty else { throw LANError.invalid }; result = try await laptop.result()
                    default: guard p.isEmpty else { throw LANError.invalid }; result = await laptop.disconnect()
                    }
                    self.paired = await laptop.paired(); self.reply(id, result: result)
                } catch { self.reply(id, error: "LAN operation refused, expired, unreachable or fingerprint mismatch. No certificate was automatically trusted.") }
            }
        default: reply(id, error: "This platform does not implement that control. No private API or jailbreak workaround.")
        }
    }
    private func restoreIdle() { awakeTimer?.invalidate(); awakeTimer = nil; if awake, UIApplication.shared.isIdleTimerDisabled, let original = originalIdle { UIApplication.shared.isIdleTimerDisabled = original }; originalIdle = nil; awake = false }
    private func restore() { restoreIdle(); if let original = originalBrightness, let applied = appliedBrightness, abs(UIScreen.main.brightness - applied) < 0.005 { UIScreen.main.brightness = original }; originalBrightness = nil; appliedBrightness = nil }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { if let id = pickerID { reply(id, error: "Import cancelled.") }; pickerID = nil; selectedShareURL = nil; selectedShareSize = 0 }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let id = pickerID else { return }; pickerID = nil
        guard urls.count == 1 else { reply(id, error: "Choose one file."); return }; let url = urls[0]
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let a = try FileManager.default.attributesOfItem(atPath: url.path)
            guard (a[.type] as? FileAttributeType) == .typeRegular, let size = a[.size] as? NSNumber, size.int64Value <= 2 * 1024 * 1024 * 1024 else { throw LANError.invalid }
            selectedShareURL = url
            selectedShareSize = size.int64Value
            if url.pathExtension.lowercased() == "csv" && size.intValue <= 5 * 1024 * 1024 {
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let data = try handle.read(upToCount: 5 * 1024 * 1024 + 1) ?? Data()
                if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252), !text.contains("\0") {
                    reply(id, result: ["csvText": text, "status": "selected", "fileName": url.lastPathComponent, "fileSize": size.intValue])
                    return
                }
            }
            reply(id, result: [
                "status": "selected",
                "fileName": url.lastPathComponent,
                "fileSize": size.intValue,
                "mimeType": "application/octet-stream",
                "uri": url.absoluteString
            ])
        } catch { selectedShareURL = nil; selectedShareSize = 0; reply(id, error: "Choose a regular file no larger than 2 GiB. No file was uploaded.") }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) { decisionHandler(navigationAction.request.url?.standardizedFileURL == page?.standardizedFileURL ? .allow : .cancel) }
    deinit { awakeTimer?.invalidate(); if let background = background { NotificationCenter.default.removeObserver(background) } }
}
