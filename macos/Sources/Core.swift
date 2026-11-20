// KL-06 • local macOS companion. No EFI, firmware, network or driver writes.
import Foundation
import AppKit
import IOKit
import IOKit.ps
import Metal
import CoreAudio
import Darwin

struct ControlError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Tweak {
    let id: String, domain: String, key: String, title: String
    let value: Any
    let restart: String
    var applicationID: CFString {
        domain == "global" ? kCFPreferencesAnyApplication : domain as CFString
    }
    static let all: [Tweak] = [
        Tweak(id: "dock-autohide", domain: "com.apple.dock", key: "autohide", title: "Automatically hide Dock", value: true, restart: "Dock"),
        Tweak(id: "dock-reveal", domain: "com.apple.dock", key: "autohide-delay", title: "Shorter Dock reveal delay", value: 0.15, restart: "Dock"),
        Tweak(id: "dock-scale", domain: "com.apple.dock", key: "mineffect", title: "Scale minimize effect", value: "scale", restart: "Dock"),
        Tweak(id: "dock-launch", domain: "com.apple.dock", key: "launchanim", title: "Stop Dock launch bounce", value: false, restart: "Dock"),
        Tweak(id: "finder-path", domain: "com.apple.finder", key: "ShowPathbar", title: "Finder path bar", value: true, restart: "Finder"),
        Tweak(id: "finder-status", domain: "com.apple.finder", key: "ShowStatusBar", title: "Finder status bar", value: true, restart: "Finder"),
        Tweak(id: "finder-hidden", domain: "com.apple.finder", key: "AppleShowAllFiles", title: "Show hidden files", value: true, restart: "Finder"),
        Tweak(id: "file-extensions", domain: "global", key: "AppleShowAllExtensions", title: "Show filename extensions", value: true, restart: "Finder"),
        Tweak(id: "scrollbars", domain: "global", key: "AppleShowScrollBars", title: "Always show scroll bars", value: "Always", restart: "Relaunch affected apps"),
        Tweak(id: "dock-recents", domain: "com.apple.dock", key: "show-recents", title: "Hide recent apps in Dock", value: false, restart: "Dock"),
        Tweak(id: "finder-folders-first", domain: "com.apple.finder", key: "_FXSortFoldersFirst", title: "Folders first in Finder", value: true, restart: "Finder"),
        Tweak(id: "natural-scroll", domain: "global", key: "com.apple.swipescrolldirection", title: "Natural scrolling", value: true, restart: "Relaunch affected apps")
    ]
}

final class PreferenceStore {
    struct Entry: Codable {
        let original: Data? // nil preserves the original ABSENCE of an explicit setting.
        let applied: Data
    }
    private var entries: [String: Entry] = [:]
    private let journalURL: URL
    private var journalError = false

    private let reader: ((Tweak) -> Any?)?
    private let writer: ((Any?, Tweak) throws -> Void)?
    private let forced: ((Tweak) -> Bool)?

    // Injection is used only by the Mac tests; they never write real desktop preferences.
    init(journalURL overrideURL: URL? = nil, reader: ((Tweak) -> Any?)? = nil,
         writer: ((Any?, Tweak) throws -> Void)? = nil, forced: ((Tweak) -> Bool)? = nil) {
        self.reader = reader; self.writer = writer; self.forced = forced
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        journalURL = overrideURL ?? base.appendingPathComponent("KL-Asus", isDirectory: true).appendingPathComponent("Restore-v1.plist")
        if FileManager.default.fileExists(atPath: journalURL.path) {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: journalURL.path)
                guard (attrs[.type] as? FileAttributeType) == .typeRegular,
                      ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) < 128 * 1024 else { throw ControlError(message: "Invalid restore journal.") }
                entries = try PropertyListDecoder().decode([String: Entry].self, from: Data(contentsOf: journalURL))
                guard Set(entries.keys).isSubset(of: Set(Tweak.all.map { $0.id })) else { throw ControlError(message: "Unknown restore entry.") }
                for (id, entry) in entries {
                    guard let tweak = Tweak.all.first(where: { $0.id == id }), entry.applied == (try encoded(tweak.value)), entry.original == nil || entry.original!.count < 32768 else { throw ControlError(message: "Invalid saved preference value.") }
                    _ = try decoded(entry.original)
                }
            } catch { journalError = true }
        }
    }
    private func encoded(_ value: Any?) throws -> Data? {
        guard let value = value else { return nil }
        return try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
    }
    private func decoded(_ data: Data?) throws -> Any? {
        guard let data = data else { return nil }
        guard let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any], Set(root.keys) == ["value"], let value = root["value"] else {
            throw ControlError(message: "Invalid preference backup. No settings changed.")
        }
        return value
    }
    private func isForced(_ tweak: Tweak) -> Bool {
        forced?(tweak) ?? CFPreferencesAppValueIsForced(tweak.key as CFString, tweak.applicationID)
    }
    private func read(_ tweak: Tweak) -> Any? {
        if let reader = reader { return reader(tweak) }
        return CFPreferencesCopyValue(tweak.key as CFString, tweak.applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    private func write(_ value: Any?, _ tweak: Tweak) throws {
        if let writer = writer { try writer(value, tweak) }
        else {
            CFPreferencesSetValue(tweak.key as CFString, value as CFPropertyList?, tweak.applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            guard CFPreferencesSynchronize(tweak.applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
                throw ControlError(message: "macOS did not confirm the preference write. The restore record is retained.")
            }
        }
        guard try encoded(read(tweak)) == encoded(value) else {
            throw ControlError(message: "Preference read-back did not match. Stop here; the restore record is retained.")
        }
    }
    private func save() throws {
        let fm = FileManager.default
        let directory = journalURL.deletingLastPathComponent()
        if fm.fileExists(atPath: directory.path) {
            let attrs = try fm.attributesOfItem(atPath: directory.path)
            guard (attrs[.type] as? FileAttributeType) == .typeDirectory else { throw ControlError(message: "Unsafe restore directory.") }
        } else {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        if fm.fileExists(atPath: journalURL.path) {
            let attrs = try fm.attributesOfItem(atPath: journalURL.path)
            guard (attrs[.type] as? FileAttributeType) == .typeRegular else { throw ControlError(message: "Unsafe restore file.") }
        }
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        try encoder.encode(entries).write(to: journalURL, options: [.atomic])
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: journalURL.path)
    }
    func states() -> [[String: Any]] {
        Tweak.all.map { tweak in
            let current = try? encoded(read(tweak))
            let target = try? encoded(tweak.value)
            let entry = entries[tweak.id]
            return ["id": tweak.id, "saved": entry != nil, "matches": current == target,
                    "conflict": entry != nil && current != entry?.applied && current != entry?.original,
                    "managed": isForced(tweak),
                    "blocked": journalError]
        }
    }
    func apply(_ id: String) throws -> String {
        guard !journalError else { throw ControlError(message: "Restore journal unreadable. Changes are blocked; keep the journal for review.") }
        guard let tweak = Tweak.all.first(where: { $0.id == id }) else { throw ControlError(message: "Unknown tweak.") }
        guard !isForced(tweak) else { throw ControlError(message: "This preference is managed by macOS or an administrator.") }
        let before = try encoded(read(tweak)); let target = try encoded(tweak.value)!
        if let old = entries[id], before != old.applied {
            throw ControlError(message: "This setting changed outside KL-06. It will not be overwritten.")
        }
        if before == target { return "Already configured. No setting or backup was changed." }
        // Journal must be on disk BEFORE the system preference is touched.
        let previous = entries[id]
        entries[id] = Entry(original: previous != nil ? previous!.original : before, applied: target)
        do { try save() } catch { entries[id] = previous; throw ControlError(message: "Could not save a restore point. No preference changed.") }
        guard try encoded(read(tweak)) == before else { throw ControlError(message: "Preference changed externally before write. No setting was written; keep the journal for review.") }
        try write(tweak.value, tweak)
        return "Applied. Restart \(tweak.restart) when convenient. This is a desktop preference, not a CPU/GPU boost."
    }
    func restore(_ id: String) throws -> String {
        guard !journalError else { throw ControlError(message: "Restore journal unreadable. Automatic restore blocked.") }
        guard let tweak = Tweak.all.first(where: { $0.id == id }), let entry = entries[id] else { return "No saved change for this setting." }
        guard !isForced(tweak) else { throw ControlError(message: "Managed preference: restore blocked.") }
        let current = try encoded(read(tweak))
        guard current == entry.applied || current == entry.original else {
            throw ControlError(message: "Conflict: another app or you changed this setting. Restore skipped to preserve that newer choice.")
        }
        if current == entry.applied { try write(try decoded(entry.original), tweak) }
        entries.removeValue(forKey: id)
        do { try save() } catch { entries[id] = entry; throw ControlError(message: "Preference restored, but journal update failed. Retain the journal for review.") }
        return "Original preference restored, including an originally unset key. Restart \(tweak.restart) when convenient."
    }
    func restoreAll() -> [String] {
        let keys = entries.keys.sorted()
        if keys.isEmpty { return ["No saved changes to restore."] }
        return keys.map { id in
            do { return "\(id): \(try restore(id))" }
            catch { return "\(id): skipped; \(error.localizedDescription)" }
        }
    }
}

final class HardwareMonitor {
    private var lastTicks: [UInt32]?
    private var lastTickTime: TimeInterval?
    private var lastTickWall: TimeInterval?
    private var cpuInterval: TimeInterval?
    private let fanMonitor = FanMonitor()
    private var lastSnapshotTime: TimeInterval = -.infinity
    private var lastSnapshotWall: TimeInterval = -.infinity
    private var cachedSnapshot: [String: Any]?
    private func sysctlText(_ key: String) -> String {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0, size < 4096 else { return "Unavailable" }
        var data = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &data, &size, nil, 0) == 0 else { return "Unavailable" }
        return String(cString: data)
    }
    private func cpuLoad() -> Double? {
        var info = host_cpu_load_info_data_t()
        let capacity = MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(capacity)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: capacity) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
        let now = ProcessInfo.processInfo.systemUptime, wall = Date().timeIntervalSince1970
        defer { lastTicks = ticks; lastTickTime = now; lastTickWall = wall }
        cpuInterval = nil
        guard let old = lastTicks, let previous = lastTickTime, let previousWall = lastTickWall,
              now > previous, now - previous <= 10, wall >= previousWall, wall - previousWall <= 10 else { return nil }
        cpuInterval = now - previous
        let delta = zip(ticks, old).map { pair in Double(pair.0 &- pair.1) }; let total = delta.reduce(0, +)
        return total > 0 ? max(0, min(100, 100 * (total - delta[2]) / total)) : nil
    }
    private func memory() -> [String: Any] {
        var info = vm_statistics64_data_t()
        let capacity = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(capacity)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: capacity) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        var result: [String: Any] = ["totalGB": total / 1073741824]
        if kr == KERN_SUCCESS {
            let used = Double(info.active_count) + Double(info.wire_count) + Double(info.compressor_page_count)
            result["usedGB"] = min(total, used * Double(vm_kernel_page_size)) / 1073741824
            result["compressedGB"] = Double(info.compressor_page_count) * Double(vm_kernel_page_size) / 1073741824
        }
        var swap = xsw_usage(); var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 { result["swapMB"] = Double(swap.xsu_used) / 1048576 }
        return result
    }
    private func battery() -> [String: Any] {
        var result: [String: Any] = [:]
        // Read only these numerical fields; never collect the battery registry dictionary or serial.
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            for key in ["DesignCapacity", "AppleRawMaxCapacity", "MaxCapacity", "CycleCount"] {
                if let v = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber,
                   v.doubleValue >= 0, v.doubleValue.isFinite { result[key] = v.doubleValue }
            }
        }
        if let design = result["DesignCapacity"] as? Double, let full = (result["AppleRawMaxCapacity"] ?? result["MaxCapacity"]) as? Double,
           design > 100, full > 100, full < design * 1.5 { result["healthPercent"] = 100 * full / design }
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let descriptor = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                      (descriptor["Type"] as? String) == "InternalBattery" else { continue }
                if let current = descriptor["Current Capacity"] as? NSNumber, let maxValue = descriptor["Max Capacity"] as? NSNumber,
                   maxValue.doubleValue > 0 { result["chargePercent"] = max(0, min(100, 100 * current.doubleValue / maxValue.doubleValue)) }
                result["charging"] = (descriptor["Is Charging"] as? Bool) ?? false
                result["onAC"] = (descriptor["Power Source State"] as? String) == "AC Power"
                break
            }
        }
        return result
    }
    func state(requestFanRead: Bool = true) -> [String: Any] {
        let now = ProcessInfo.processInfo.systemUptime, wall = Date().timeIntervalSince1970
        if now >= lastSnapshotTime, now - lastSnapshotTime < 1, wall >= lastSnapshotWall, wall - lastSnapshotWall < 1, let cached = cachedSnapshot { return cached }
        var cpu: [String: Any] = ["name": sysctlText("machdep.cpu.brand_string"), "logicalCores": ProcessInfo.processInfo.processorCount]
        if let load = cpuLoad() { cpu["loadPercent"] = load; if let interval = cpuInterval { cpu["intervalSeconds"] = interval } }
        cpu["source"] = "mach host CPU tick deltas"
        let gpu: [[String: Any]] = MTLCopyAllDevices().map {
            ["name": $0.name, "lowPower": $0.isLowPower, "metal3Family": $0.supportsFamily(.metal3)]
        }
        var storage: [String: Any] = [:]
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let free = attrs[.systemFreeSize] as? NSNumber, let total = attrs[.systemSize] as? NSNumber {
            storage = ["freeGB": free.doubleValue / 1073741824, "totalGB": total.doubleValue / 1073741824]
        }
        let displayID = CGMainDisplayID()
        let refresh = CGDisplayCopyDisplayMode(displayID)?.refreshRate ?? 0
        let display: [String: Any] = ["width": CGDisplayPixelsWide(displayID), "height": CGDisplayPixelsHigh(displayID),
                                     "refreshHz": refresh, "screenCount": NSScreen.screens.count]
        let volume: Any = AudioControl.read().map { $0 as Any } ?? NSNull()
        let brightness: Any = DisplayControl.read().map { $0 as Any } ?? NSNull()
        #if arch(x86_64)
        let architecture = "x86_64"
        #elseif arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "other"
        #endif
        let snapshot: [String: Any] = ["mode": "native", "platform": "macos", "version": "0.4.7-beta", "build": 12,
                "sampledAtUnix": Date().timeIntervalSince1970, "sampledUptimeSeconds": ProcessInfo.processInfo.systemUptime,
                "sampledAt": ISO8601DateFormatter().string(from: Date()), "architecture": architecture, "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "smbiosModel": sysctlText("hw.model"), "cpu": cpu, "memory": memory(), "gpu": gpu,
                "battery": battery(), "storage": storage, "display": display, "volume": volume, "brightness": brightness,
                "thermalState": ProcessInfo.processInfo.thermalState.rawValue, "fan": fanMonitor.snapshot(requestRead: requestFanRead)]
        cachedSnapshot = snapshot; lastSnapshotTime = now; lastSnapshotWall = wall; return snapshot
    }
}

enum AudioControl {
    private static func device() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(0); var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr, id != 0 else { return nil }
        return id
    }
    private static func elements(_ id: AudioDeviceID) -> [AudioObjectPropertyElement] {
        var master = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(id, &master) { return [kAudioObjectPropertyElementMain] }
        return [UInt32(1), UInt32(2)].filter { element in
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            return AudioObjectHasProperty(id, &address)
        }
    }
    static func read() -> Double? {
        guard let id = device() else { return nil }
        var values: [Double] = []
        for element in elements(id) {
            var value: Float32 = 0; var size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            if AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, value.isFinite, (0...1).contains(value) { values.append(Double(value) * 100) }
        }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    static func set(_ percent: Double) throws {
        guard percent.isFinite, (0...100).contains(percent), let id = device() else { throw ControlError(message: "System output volume is unavailable.") }
        let channels = elements(id)
        guard !channels.isEmpty else { throw ControlError(message: "This output exposes no software volume control. Use Sound settings.") }
        var old: [(AudioObjectPropertyAddress, Float32)] = []
        for element in channels {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            var settable = DarwinBoolean(false); var value: Float32 = 0; var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectIsPropertySettable(id, &address, &settable) == noErr, settable.boolValue,
                  AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, value.isFinite, (0...1).contains(value) else { throw ControlError(message: "Volume is not writable on this output.") }
            old.append((address, value))
        }
        var written: [AudioObjectPropertyAddress] = []
        func rollbackOwnedChannels() {
            for item in old where written.contains(where: { $0.mElement == item.0.mElement }) {
                var address = item.0; var current: Float32 = 0; var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(id, &address, 0, nil, &size, &current) == noErr,
                   current.isFinite, abs(Double(current) - percent / 100) <= 0.02 {
                    var original = item.1
                    _ = AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &original)
                }
            }
        }
        for item in old {
            var address = item.0; var value = Float32(percent / 100)
            guard AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr else {
                rollbackOwnedChannels()
                throw ControlError(message: "Volume change failed; only unchanged owned channels received a best-effort rollback.")
            }
            written.append(address)
        }
        for item in old {
            var address = item.0; var readback: Float32 = 0; var size = UInt32(MemoryLayout<Float32>.size)
            guard device() == id, AudioObjectGetPropertyData(id, &address, 0, nil, &size, &readback) == noErr,
                  readback.isFinite, abs(Double(readback) - percent / 100) <= 0.02 else {
                rollbackOwnedChannels()
                throw ControlError(message: "The output route or volume readback changed. Only still-owned channels received a best-effort rollback; no success is assumed.")
            }
        }
    }
}

enum DisplayControl {
    private typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let displayServicesHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    }()

    private static let getBrightness: DisplayServicesGetBrightnessFunc? = {
        guard let handle = displayServicesHandle,
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: DisplayServicesGetBrightnessFunc.self)
    }()

    private static let setBrightness: DisplayServicesSetBrightnessFunc? = {
        guard let handle = displayServicesHandle,
              let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: DisplayServicesSetBrightnessFunc.self)
    }()

    static func read() -> Double? {
        var val: Float = 0
        if let get = getBrightness, get(CGMainDisplayID(), &val) == 0, val.isFinite, (0...1).contains(val) {
            return Double(val) * 100
        }
        var iter: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iter) == kIOReturnSuccess {
            defer { IOObjectRelease(iter) }
            var service = IOIteratorNext(iter)
            while service != 0 {
                defer { IOObjectRelease(service); service = IOIteratorNext(iter) }
                var b: Float = 0
                if IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &b) == kIOReturnSuccess,
                   b.isFinite, (0...1).contains(b) {
                    return Double(b) * 100
                }
            }
        }
        return nil
    }

    static func set(_ percent: Double) throws {
        guard percent.isFinite, (1...100).contains(percent) else {
            throw ControlError(message: "Invalid brightness level.")
        }
        let val = Float(percent / 100.0)
        var success = false
        if let setFn = setBrightness {
            if setFn(CGMainDisplayID(), val) == 0 {
                success = true
            }
        }
        if !success {
            var iter: io_iterator_t = 0
            if IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iter) == kIOReturnSuccess {
                defer { IOObjectRelease(iter) }
                var service = IOIteratorNext(iter)
                while service != 0 {
                    let current = service
                    service = IOIteratorNext(iter)
                    if IODisplaySetFloatParameter(current, 0, kIODisplayBrightnessKey as CFString, val) == kIOReturnSuccess {
                        success = true
                    }
                    IOObjectRelease(current)
                }
            }
        }
        guard success else {
            throw ControlError(message: "Hardware display brightness control unavailable on this display route.")
        }
    }
}


enum PowerSample {
    // A fixed, bounded read-only command. Never interpolate web input into a privileged script.
    static let command = "/usr/bin/powermetrics --samplers cpu_power,gpu_power -i 1000 -n 5"
    static func run() -> [[String: String]] {
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let source = "with timeout of 30 seconds\n do shell script \"" + command + "\" with administrator privileges\nend timeout"
        task.arguments = ["-e", source]
        let pipe = Pipe(); task.standardOutput = pipe; task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
        guard task.terminationStatus == 0, data.count < 512 * 1024, let text = String(data: data, encoding: .utf8) else { return [] }
        return parse(text)
    }
    static func parse(_ text: String) -> [[String: String]] {
        let labels = "(?:CPU Power|GPU Power|Package Power|CPU die temperature|GPU die temperature|System Average frequency as fraction of nominal|System Average frequency|GPU HW active frequency|GPU active frequency|Package C[0-9]+ residency|Core C[0-9]+ residency|Intel energy model derived package power \\(CPUs\\+GT\\+SA\\)|Intel energy model derived (?:IA/CPU|GT/GPU) power)"
        let number = "[+-]?[0-9]+(?:\\.[0-9]+)?\\s*(?:mW|W|MHz|Mhz|GHz|C|%)(?:\\s*\\([0-9.]+\\s*(?:MHz|Mhz|GHz)\\))?"
        guard let expression = try? NSRegularExpression(pattern: "^\\s*(" + labels + "):\\s*(" + number + ")\\s*$") else { return [] }
        var fields: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            if let match = expression.firstMatch(in: line, range: range),
               let k = Range(match.range(at: 1), in: line), let v = Range(match.range(at: 2), in: line) {
                fields[String(line[k])] = String(line[v]) // latest sample per field; no raw output saved.
            }
        }
        return fields.keys.sorted().map { ["label": $0, "value": fields[$0]!] }
    }
}
