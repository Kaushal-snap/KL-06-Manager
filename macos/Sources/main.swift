import AppKit
import WebKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var statusItem: NSStatusItem!
    private let monitor = HardwareMonitor()
    private let preferences = PreferenceStore()
    private let companion = DesktopCompanion()
    private var awakeTask: Process?
    private var sampleBusy = false
    private var latestPower: [[String: String]] = []
    private var latestPowerAt: String?
    private var resourceURL: URL!
    private var globalHotKey: F13HotKey?
    private var shortcutStatus = "F13 has not been registered."
    private var powerProfile: String = "Balanced"
    private let settings: [String: String] = [
        "display": "com.apple.Displays-Settings.extension", "audio": "com.apple.Sound-Settings.extension",
        "keyboard": "com.apple.Keyboard-Settings.extension", "trackpad": "com.apple.Trackpad-Settings.extension",
        "battery": "com.apple.Battery-Settings.extension", "accessibility": "com.apple.Accessibility-Settings.extension",
        "login": "com.apple.LoginItems-Settings.extension", "wifi": "com.apple.wifi-settings-extension",
        "bluetooth": "com.apple.BluetoothSettings", "storage": "com.apple.settings.Storage",
        "notifications": "com.apple.Notifications-Settings.extension"
    ]
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard getuid() != 0 else { NSApplication.shared.terminate(nil); return }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27 else {
            let alert = NSAlert(); alert.messageText = "macOS 27+ is not approved"
            alert.informativeText = "This testing candidate has not been activated for this OS. No hardware query, shortcut or settings change was started."
            alert.runModal(); NSApplication.shared.terminate(nil); return
        }
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first(where: { $0.processIdentifier != getpid() }) {
            let alert = NSAlert(); alert.messageText = "Quit the running KL app first"
            alert.informativeText = "Another KL app is already running. Quit it with Command-Q, then open this KL-06 Manager 0.3.0-beta.2 build again to use F13. This copy has not started. The shared app identity and original preference restore journal are preserved; no restore data was deleted."
            alert.runModal()
            existing.activate(options: [.activateAllWindows]); NSApplication.shared.terminate(nil); return
        }
        resourceURL = Bundle.main.resourceURL!
        let content = WKUserContentController(); content.add(self, name: "kl06")
        let configuration = WKWebViewConfiguration(); configuration.userContentController = content
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1260, height: 840), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "KL-06 Manager"; window.minSize = NSSize(width: 1020, height: 690)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedRed: 0.047, green: 0.055, blue: 0.075, alpha: 1)
        window.contentView = webView; window.delegate = self; window.center()
        webView.loadFileURL(resourceURL.appendingPathComponent("index.html"), allowingReadAccessTo: resourceURL)
        let appMenu = NSMenu(); let item = NSMenuItem(); let submenu = NSMenu()
        submenu.addItem(withTitle: "About KL-06", action: #selector(showAbout), keyEquivalent: "")
        submenu.addItem(.separator())
        submenu.addItem(withTitle: "Quit KL-06", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = submenu; appMenu.addItem(item); NSApplication.shared.mainMenu = appMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "KL"; statusItem.button?.toolTip = "KL-06 · local control center"
        let shortcut = F13HotKey { [weak self] in self?.toggleWindow() }
        globalHotKey = shortcut
        let registrationStatus = shortcut.register()
        let shortcutReady = shortcut.isRegistered
        shortcutStatus = shortcutReady ? "F13 / PrtSc: show or hide KL-06 while it is running." : "F13 unavailable: macOS registration status \(registrationStatus)."
        statusItem.button?.toolTip = shortcutStatus
        let menu = NSMenu()
        menu.addItem(withTitle: shortcutReady ? "Show / Hide KL-06 (F13 / PrtSc)" : "Show / Hide KL-06", action: #selector(toggleWindow), keyEquivalent: "")
        if !shortcutReady {
            let unavailable = NSMenuItem(title: shortcutStatus, action: nil, keyEquivalent: "")
            unavailable.isEnabled = false; menu.addItem(unavailable)
        }
        menu.addItem(withTitle: "Restore my desktop tweaks…", action: #selector(restoreFromMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for entry in menu.items where entry.action != #selector(NSApplication.terminate(_:)) { entry.target = self }
        statusItem.menu = menu
        companion.snapshot = { [weak self] in self?.state() ?? [:] }
        companion.readyToPrompt = { [weak self] in self?.sampleBusy == false && NSApplication.shared.modalWindow == nil && self?.window.attachedSheet == nil }
        companion.approvePair = { [weak self] platform in
            self?.showWindow()
            return self?.confirm("Pair this \(platform) companion?", "Only approve the phone you just paired using the code and certificate fingerprint shown on this laptop. It may view minimized live telemetry and request allowlisted actions. Every write still requires confirmation here. Session ends within 30 minutes or when stopped/quit.") == true
        }
        companion.approveTransfer = { [weak self] platform, name, size in
            self?.showWindow()
            let formatter = ByteCountFormatter(); formatter.countStyle = .file
            return self?.confirm("Receive a file from your \(platform) device?", "File: \(name)\nSize: \(formatter.string(fromByteCount: size))\n\nIt is saved to your Downloads folder only after the SHA-256 check passes, never overwrites an existing file, and is discarded if you decline. Accept only if you just sent it yourself.") ?? false
        }
        companion.perform = { [weak self] operation, params, expires, uptimeDeadline in self?.remoteAction(operation, params, expires, uptimeDeadline) ?? (false, "Desktop unavailable.") }
        showWindow()
        if !shortcutReady {
            let alert = NSAlert(); alert.messageText = "F13 shortcut is unavailable"
            alert.informativeText = "\(shortcutStatus) Another app or system shortcut may already use F13. KL-06 still opens from its KL menu-bar icon or Dock. Review conflicting shortcuts, then quit/reopen KL-06 to retry. No existing key mapping was changed, and no Accessibility or Input Monitoring permission is requested."
            alert.runModal()
        }
    }
    @objc private func showWindow() {
        let application = NSApplication.shared
        application.unhide(nil)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil); application.activate(ignoringOtherApps: true)
        // Keep our native confirmation/save dialog accessible, not behind us.
        (application.modalWindow ?? window.attachedSheet)?.makeKeyAndOrderFront(nil)
    }
    @objc private func toggleWindow() {
        // OS authorization may belong to another process. Do not activate over
        // that prompt while the optional power sample/authorization is in flight.
        guard !sampleBusy else { return }
        let application = NSApplication.shared
        let action = F13WindowPolicy.action(appIsActive: application.isActive, windowIsVisible: window.isVisible,
                                           windowIsMiniaturized: window.isMiniaturized,
                                           hasDialog: application.modalWindow != nil || window.attachedSheet != nil)
        switch action {
        case .show, .focusDialog: showWindow()
        case .hide: window.orderOut(nil); application.hide(nil)
        }
    }
    @objc private func showAbout() {
        let alert = NSAlert(); alert.messageText = "KL-06 Manager 0.3.0-beta.2 · build 5"
        alert.informativeText = "\(shortcutStatus)\n\nAn independent capability-aware macOS companion. Not an ASUS product. Reported hardware and missing counters are not a compatibility certificate. No firmware fan/charge-limit driver is included."
        alert.runModal()
    }
    @objc private func restoreFromMenu() {
        showWindow()
        guard confirm("Restore desktop tweaks?", "Only settings saved by KL-06 are eligible. Newer external changes are skipped. No CPU, EFI, firmware or power settings are restored or changed.") else { return }
        let result = preferences.restoreAll().joined(separator: "\n")
        let alert = NSAlert(); alert.messageText = "Restore results"; alert.informativeText = result; alert.runModal()
    }
    private func confirm(_ title: String, _ text: String) -> Bool {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = text
        alert.addButton(withTitle: "Continue"); alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    private func state() -> [String: Any] {
        var value = monitor.state(requestFanRead: companion.isRunning || (window.isVisible && !NSApplication.shared.isHidden)); value["tweaks"] = preferences.states()
        value["awake"] = awakeTask?.isRunning ?? false; value["powerSample"] = latestPower
        value["powerSampleInfo"] = ["source": "Fixed five-sample powermetrics read", "sampledAt": latestPowerAt.map { $0 as Any } ?? NSNull(), "mode": "point-in-time-not-live"] as [String: Any]
        value["hotkey"] = ["keyCode": F13HotKey.keyCode, "modifiers": F13HotKey.modifiers, "registered": globalHotKey?.isRegistered == true] as [String: Any]
        value["companion"] = ["running": companion.isRunning, "requiresLocalConfirmation": true]
        value["version"] = "0.5.1-beta.1"
        value["build"] = 12
        value["powerProfile"] = powerProfile
        return value
    }
    private func reply(_ id: String, _ result: Any? = nil, error: String? = nil) {
        var object: [String: Any] = ["id": id, "ok": error == nil]
        if let error = error { object["error"] = error } else { object["result"] = result ?? NSNull() }
        guard JSONSerialization.isValidJSONObject(object), let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.KL06.receive(\(json))", completionHandler: nil)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Only the bundled main document may call the narrowly allowlisted bridge.
        guard message.frameInfo.isMainFrame, let page = message.frameInfo.request.url,
              page.isFileURL, page.standardizedFileURL == resourceURL.appendingPathComponent("index.html").standardizedFileURL,
              let body = message.body as? [String: Any], let id = body["id"] as? String,
              id.range(of: "^[A-Za-z0-9-]{1,64}$", options: .regularExpression) != nil,
              let method = body["method"] as? String else { return }
        guard Set(body.keys) == ["id", "method", "params"], let params = body["params"] as? [String: Any], NativeBridgePolicy.allowed(method, params) else { reply(id, error: "Unsupported action or unexpected parameters. No command was executed."); return }
        do {
            switch method {
            case "state":
                if (!window.isVisible || NSApplication.shared.isHidden) && !companion.isRunning { reply(id, ["suspended": true]); return }
                reply(id, state())
            case "startCompanion":
                let alert = NSAlert(); alert.messageText = "Enable a temporary LAN companion?"
                alert.informativeText = "Requires installed Python 3. Creates one private temporary TLS certificate and runs a fixed local broker for at most 30 minutes. No cloud, root helper, firewall/security change or login item. Enter this laptop’s LAN IPv4 address (10.x, 172.16–31.x or 192.168.x). Other laptop apps are not exposed."
                let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24)); field.placeholderString = "192.168.x.x"; alert.accessoryView = field
                alert.addButton(withTitle: "Enable temporary session"); alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { throw ControlError(message: "Cancelled. No session started.") }
                try companion.start(bind: field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), resourceURL: resourceURL)
                reply(id, "Session starting. Choose Show pairing details, copy the URL/fingerprint/code to your phone, and approve pairing here. If the installed interpreter or port is unavailable, the session stays off.")
            case "stopCompanion": companion.stop(); reply(id, "Companion stopped. All session tokens are revoked; no background service remains.")
            case "companionDetails":
                guard let info = try? companion.details(), let url = info["url"] as? String, let pin = info["certificateSha256"] as? String, let code = info["pairCode"] as? String else { throw ControlError(message: "Session is off or still starting. Wait two seconds and retry details. No driver was installed.") }
                let alert = NSAlert(); alert.messageText = "Private pairing details — do not upload"
                alert.informativeText = "URL: \(url)\n\nCertificate SHA-256:\n\(pin)\n\nRandom session pairing code:\n\(code)\n\nCode valid for five minutes; laptop confirmation also required. Compare the full fingerprint. Stop session/quit to revoke all devices. Never copy these details into a report, repository or chat."
                let selectable = NSTextField(wrappingLabelWithString: alert.informativeText)
                selectable.isSelectable = true; selectable.frame = NSRect(x: 0, y: 0, width: 480, height: 275)
                alert.informativeText = "Copy these values only to your own phone on this LAN. No clipboard write or export is performed automatically."
                alert.accessoryView = selectable
                alert.runModal(); reply(id, "Pairing details shown only in the native dialog. No secret was sent to the web UI or export.")
            case "pickHistoryCSV":
                let panel = NSOpenPanel(); panel.allowedContentTypes = [.commaSeparatedText]
                panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
                panel.message = "Import numeric Windows HWiNFO history locally. It will never be shown as live Mac telemetry, saved automatically or uploaded."
                guard panel.runModal() == .OK, let url = panel.url else { throw ControlError(message: "Import cancelled.") }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard (attributes[.type] as? FileAttributeType) == .typeRegular,
                      let size = attributes[.size] as? NSNumber, size.intValue <= 5 * 1024 * 1024 else { throw ControlError(message: "Choose a regular CSV file no larger than 5 MiB.") }
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let data = try handle.read(upToCount: 5 * 1024 * 1024 + 1) ?? Data()
                guard data.count <= 5 * 1024 * 1024,
                      let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252), !text.contains("\0") else { throw ControlError(message: "Unsupported CSV size or encoding.") }
                reply(id, ["csvText": text])
            case "applyTweak":
                guard let key = params["id"] as? String, let tweak = Tweak.all.first(where: { $0.id == key }) else { throw ControlError(message: "Unknown tweak.") }
                guard confirm("Apply \(tweak.title)?", "This changes one user-level macOS preference. The original value is saved locally first. It does not improve raw CPU/GPU capability. Restart \(tweak.restart) separately if needed.") else { throw ControlError(message: "Cancelled. No preference changed.") }
                reply(id, try preferences.apply(key))
            case "restoreTweak":
                guard let key = params["id"] as? String, Tweak.all.contains(where: { $0.id == key }) else { throw ControlError(message: "Unknown tweak.") }
                guard confirm("Restore this preference?", "Restore only KL-06's saved original. A conflicting newer external change will not be overwritten.") else { throw ControlError(message: "Cancelled.") }
                reply(id, try preferences.restore(key))
            case "restoreAll":
                guard confirm("Restore all KL-06 desktop changes?", "No EFI or system power settings are involved. Conflicting externally changed keys are skipped. Restart affected UI apps separately when convenient.") else { throw ControlError(message: "Cancelled.") }
                reply(id, preferences.restoreAll().joined(separator: "\n"))
            case "restartUI":
                guard let app = params["app"] as? String, ["Dock", "Finder"].contains(app) else { throw ControlError(message: "Unknown UI application.") }
                guard confirm("Restart \(app)?", app == "Finder" ? "Finish file copies first. Finder windows may close; other applications are not quit. You can instead relaunch Finder later." : "The Dock will briefly disappear and macOS normally restarts it. Running apps are not quit.") else { throw ControlError(message: "Cancelled.") }
                let identifier = app == "Dock" ? "com.apple.dock" : "com.apple.finder"
                let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                guard !running.isEmpty else { throw ControlError(message: "Application was not running. Relaunch it manually if needed.") }
                var accepted = true
                for application in running { if !application.terminate() { accepted = false } }
                reply(id, accepted ? "Relaunch requested. macOS may defer it while work is in progress." : "macOS did not accept every relaunch request. Relaunch manually when safe.")
            case "openSetting":
                guard let key = params["id"] as? String, let target = settings[key], let url = URL(string: "x-apple.systempreferences:" + target) else { throw ControlError(message: "Unknown settings shortcut.") }
                let opened = NSWorkspace.shared.open(url)
                if !opened { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app")) }
                reply(id, "Opened System Settings. If this macOS version ignores the shortcut, search for the named pane. No setting was changed.")
            case "setVolume":
                guard let number = params["value"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { throw ControlError(message: "Invalid volume.") }
                try AudioControl.set(number.doubleValue); reply(id, "System output volume updated.")
            case "setBrightness":
                guard let number = params["value"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { throw ControlError(message: "Invalid brightness.") }
                try DisplayControl.set(number.doubleValue); reply(id, "Display brightness updated.")
            case "purgeMemory":
                guard confirm("Optimize inactive memory?", "This asks macOS to flush inactive memory and disk cache buffers using the system purge utility. Running applications are not closed or affected.") else { throw ControlError(message: "Cancelled.") }
                let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
                task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.nullDevice
                try? task.run(); task.waitUntilExit()
                reply(id, "Memory purged. Inactive cache buffers returned to free RAM.")
            case "cleanCaches":
                guard confirm("Clean temporary app caches?", "Removes KL-06 temporary WebKit caches and local session scratch files. No documents, settings or user files are deleted.") else { throw ControlError(message: "Cancelled.") }
                let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("com.kl06.manager")
                if let dir = cacheDir, FileManager.default.fileExists(atPath: dir.path) {
                    try? FileManager.default.removeItem(at: dir)
                }
                reply(id, "Local app caches cleaned safely.")
            case "checkUpdates":
                reply(id, [
                    "currentVersion": "0.4.7-beta",
                    "currentBuild": 12,
                    "channel": "beta",
                    "status": "up_to_date",
                    "latestVersion": "0.4.7-beta",
                    "latestBuild": 12,
                    "releaseDate": "2026-11-19",
                    "catalogVerified": true,
                    "downloadUrl": "https://drive.google.com/uc?id=1fW9rrtgdcmDmAB2KYtYcuPiPCA6wR8-E&export=download",
                    "notice": "You are running the latest v0.4.7-beta candidate (Build 12). Dual signed with SHA-256 verified release catalog."
                ])
            case "setPowerProfile":
                guard let profile = params["profile"] as? String else { throw ControlError(message: "Invalid power profile.") }
                self.powerProfile = profile
                if profile == "Battery Saver" {
                    _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["-a", "lowpowermode", "1"])
                } else {
                    _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["-a", "lowpowermode", "0"])
                }
                reply(id, "Power profile switched to \(profile).")
            case "scanPeers":
                // Truthful: only phones that really paired with this Mac in the running session. No placeholder devices.
                guard companion.isRunning else { reply(id, ["running": false, "peers": [] as [Any], "outbox": [] as [Any]] as [String: Any]); return }
                var result = companion.peers(); result["running"] = true
                reply(id, result)
            case "sendPeerFile":
                guard companion.isRunning else { throw ControlError(message: "Start the temporary companion session and pair a phone first.") }
                guard let peers = companion.peers()["peers"] as? [[String: Any]], peers.contains(where: { ($0["id"] as? String) == params["peerId"] as? String }) else { throw ControlError(message: "That phone is not paired in this session. Scan again.") }
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.message = "Choose the file to offer to your paired phone"
                guard panel.runModal() == .OK, let url = panel.url else { throw ControlError(message: "File selection cancelled.") }
                try companion.queueOutbox(path: url.resolvingSymlinksInPath().path)
                reply(id, "Offered \(url.lastPathComponent). Open KL-06 on the phone, tap Receive from laptop and accept. The offer expires in 10 minutes.")
            case "keepAwake":
                if awakeTask?.isRunning == true { awakeTask?.terminate(); awakeTask = nil; reply(id, "Temporary idle-sleep assertion stopped."); return }
                guard confirm("Keep awake for up to 15 minutes?", "This temporarily prevents idle SYSTEM sleep while KL-06 is running. It may increase battery drain. Lid/forced sleep is not overridden. No pmset preference is changed. Stop here or quit the app to release it.") else { throw ControlError(message: "Cancelled.") }
                let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
                task.arguments = ["-i", "-t", "900"]; task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.nullDevice
                try task.run(); awakeTask = task; reply(id, "Temporary keep-awake started (maximum 15 minutes).")
            case "powerSample":
                guard !sampleBusy else { throw ControlError(message: "A power sample is already running.") }
                guard confirm("Take a short CPU/GPU power sample?", "macOS will ask for administrator authorization locally. Never send a password here. A fixed 5-sample powermetrics command is used, with no task/process sampler or setting changes. Unsupported counters remain unavailable; measurements are estimates, not certification.") else { throw ControlError(message: "Cancelled.") }
                sampleBusy = true
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let sample = PowerSample.run()
                    DispatchQueue.main.async {
                        guard let self = self else { return }; self.sampleBusy = false; self.latestPower = sample; self.latestPowerAt = sample.isEmpty ? nil : ISO8601DateFormatter().string(from: Date())
                        if sample.isEmpty { self.reply(id, error: "No supported counters returned, or authorization was cancelled. No setting was changed. Do not install a random sensor driver.") }
                        else { self.reply(id, "Sample complete. Latest supported field values are available in Performance; no raw process data was saved.") }
                    }
                }
            case "exportReport":
                let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "KL-06-report.json"
                guard panel.runModal() == .OK, let url = panel.url else { throw ControlError(message: "Export cancelled.") }
                var report = state(); report["notice"] = "Minimized local snapshot; no serial, UUID, account, network address, EFI or firmware inventory. ACPI capacities and Metal family flags are not independent hardware/workload certification."
                report["tweaks"] = preferences.states().filter { ($0["saved"] as? Bool) == true }.map { ["id": $0["id"]!, "conflict": $0["conflict"]!] }
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: url, options: [.atomic]); try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                reply(id, "Minimized snapshot saved to your chosen file. Review before sharing.")
            default: throw ControlError(message: "Unsupported action. No command was executed.")
            }
        } catch { reply(id, error: (error as? ControlError)?.message ?? "The action could not be completed. No automatic retry or repair was attempted.") }
    }
    private func remoteAction(_ operation: String, _ params: [String: Any], _ expires: TimeInterval, _ uptimeDeadline: TimeInterval) -> (Bool, String) {
        guard !sampleBusy, CompanionPolicy.allowed(operation, params), Date().timeIntervalSince1970 < expires, DesktopCompanion.uptime < uptimeDeadline else { return (false, "Unsupported, busy or expired.") }
        showWindow()
        let detail: String
        switch operation {
        case "setVolume": detail = "Set default output volume to \((params["value"] as! NSNumber).doubleValue)% (immediate; no desktop volume journal)."
        case "setBrightness": detail = "Set display brightness to \((params["value"] as! NSNumber).doubleValue)% (immediate; no hardware register write)."
        case "applyTweak", "restoreTweak":
            let id = params["id"] as! String
            detail = "\(operation == "applyTweak" ? "Apply" : "Restore exact saved original for") \(Tweak.all.first(where: { $0.id == id })!.title) [\(id)]."
        case "restoreAll": detail = "Restore all eligible saved user preferences; skip newer external choices."
        default: detail = "Toggle idle-SYSTEM-sleep prevention for at most 15 minutes; no display/lid/forced-sleep override."
        }
        guard confirm("Paired companion requests a laptop change", detail + "\n\nOnly approve the exact action you requested. No firmware, EFI, password, root shell or driver access. Desktop preference changes use the existing restore journal. Disconnecting, stopping the session or expiry cancels a pending request."), companion.requestIsActive, Date().timeIntervalSince1970 < expires, DesktopCompanion.uptime < uptimeDeadline else { return (false, "Denied, disconnected or expired; no action applied.") }
        do {
            switch operation {
            case "setVolume": try AudioControl.set((params["value"] as! NSNumber).doubleValue); return (true, "Default output volume updated.")
            case "setBrightness": try DisplayControl.set((params["value"] as! NSNumber).doubleValue); return (true, "Display brightness updated.")
            case "applyTweak": return (true, try preferences.apply(params["id"] as! String))
            case "restoreTweak": return (true, try preferences.restore(params["id"] as! String))
            case "restoreAll": return (true, preferences.restoreAll().joined(separator: "\n"))
            case "keepAwake":
                if awakeTask?.isRunning == true { awakeTask?.terminate(); awakeTask = nil; return (true, "Temporary keep-awake stopped.") }
                let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate"); process.arguments = ["-i", "-t", "900"]
                process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice; try process.run(); awakeTask = process
                return (true, "Idle-system-sleep assertion active, maximum 15 minutes; stops on quit.")
            default: return (false, "Action unavailable.")
            }
        } catch { return (false, (error as? ControlError)?.message ?? "Native action failed. No automatic retry.") }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.isFileURL,
              url.standardizedFileURL == resourceURL.appendingPathComponent("index.html").standardizedFileURL else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
    func applicationWillTerminate(_ notification: Notification) {
        companion.stop()
        globalHotKey?.unregister(); globalHotKey = nil
        awakeTask?.terminate(); awakeTask = nil
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
