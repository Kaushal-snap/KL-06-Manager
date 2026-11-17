import AppKit
import WebKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var statusItem: NSStatusItem!
    private let monitor = HardwareMonitor()
    private let preferences = PreferenceStore()
    private var awakeTask: Process?
    private var sampleBusy = false
    private var latestPower: [[String: String]] = []
    private var resourceURL: URL!
    private var globalHotKey: F13HotKey?
    private var shortcutStatus = "F13 has not been registered."
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
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first(where: { $0.processIdentifier != getpid() }) {
            let alert = NSAlert(); alert.messageText = "Quit the running KL app first"
            alert.informativeText = "Another KL app is already running. Quit it with Command-Q, then open this KL-06 0.2.1 build again to use F13. This copy has not started. The shared app identity and original preference restore journal are preserved; no restore data was deleted."
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
        window.title = "KL-06"; window.minSize = NSSize(width: 1020, height: 690)
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
        let alert = NSAlert(); alert.messageText = "KL-06 0.2.1"
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
        var value = monitor.state(); value["tweaks"] = preferences.states()
        value["awake"] = awakeTask?.isRunning ?? false; value["powerSample"] = latestPower
        value["hotkey"] = ["keyCode": F13HotKey.keyCode, "modifiers": F13HotKey.modifiers, "registered": globalHotKey?.isRegistered == true] as [String: Any]
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
        let params = body["params"] as? [String: Any] ?? [:]
        do {
            switch method {
            case "state": reply(id, state())
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
                        guard let self = self else { return }; self.sampleBusy = false; self.latestPower = sample
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
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.isFileURL,
              url.standardizedFileURL == resourceURL.appendingPathComponent("index.html").standardizedFileURL else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
    func applicationWillTerminate(_ notification: Notification) {
        globalHotKey?.unregister(); globalHotKey = nil
        awakeTask?.terminate(); awakeTask = nil
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
