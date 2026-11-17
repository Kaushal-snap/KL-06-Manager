// Native logic tests. Fake preference functions ONLY: no real preference/power/hardware writes.
import Foundation

var checks = 0
func check(_ passed: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    if !passed() { print("FAIL: \(label)"); exit(1) }
    print("PASS: \(label)")
}
func rejects(_ label: String, _ action: () throws -> Void) {
    do { try action(); check(false, label) }
    catch { check(true, label) }
}
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KL-06-native-tests-" + UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
func store(_ file: String, _ values: NSMutableDictionary, _ forced: Bool = false) -> PreferenceStore {
    PreferenceStore(journalURL: directory.appendingPathComponent(file), reader: { values[$0.id] },
                    writer: { value, tweak in
                        if let value = value { values[tweak.id] = value } else { values.removeObject(forKey: tweak.id) }
                    }, forced: { _ in forced })
}
let values = NSMutableDictionary()
let first = store("restore.plist", values)
check(first.states().allSatisfy { ($0["saved"] as? Bool) == false }, "read-only startup has no saved changes")
_ = try first.apply("dock-autohide")
check((values["dock-autohide"] as? Bool) == true, "apply updates only fake preferences")
check(FileManager.default.fileExists(atPath: directory.appendingPathComponent("restore.plist").path), "journal exists before/after apply")
_ = try first.restore("dock-autohide")
check(values["dock-autohide"] == nil, "restores original ABSENCE, not a guessed false")
values["dock-autohide"] = false
_ = try first.apply("dock-autohide")
let reopened = store("restore.plist", values)
_ = try reopened.restore("dock-autohide")
check((values["dock-autohide"] as? Bool) == false, "exact original false survives app restart")
values["dock-scale"] = "genie"
_ = try first.apply("dock-scale")
values["dock-scale"] = "external-newer-choice"
rejects("external newer choice blocks restore") { _ = try first.restore("dock-scale") }
check((values["dock-scale"] as? String) == "external-newer-choice", "conflict preserved")
rejects("external newer choice blocks re-apply") { _ = try first.apply("dock-scale") }
check(first.states().first { ($0["id"] as? String) == "dock-scale" }?["conflict"] as? Bool == true, "conflict exposed to UI")
let managed = store("managed.plist", values, true)
rejects("managed preference is never changed") { _ = try managed.apply("dock-launch") }
rejects("arbitrary preference ID is rejected") { _ = try first.apply("csr-active-config") }
let brokenURL = directory.appendingPathComponent("broken.plist")
try Data("not-a-journal".utf8).write(to: brokenURL)
let broken = store("broken.plist", values)
rejects("corrupt journal blocks new writes") { _ = try broken.apply("finder-hidden") }
check(values["finder-hidden"] == nil, "corrupt journal leaves fake preference unchanged")
let parentFile = directory.appendingPathComponent("not-a-directory")
try Data([1]).write(to: parentFile)
let unsafeStore = PreferenceStore(journalURL: parentFile.appendingPathComponent("restore.plist"), reader: { values[$0.id] }, writer: { value,tweak in values[tweak.id] = value }, forced: { _ in false })
rejects("failed journal save aborts before write") { _ = try unsafeStore.apply("finder-hidden") }
check(values["finder-hidden"] == nil, "save failure did not touch preference")
let already = NSMutableDictionary(dictionary: ["dock-autohide": true])
let noOp = store("noop.plist", already)
_ = try noOp.apply("dock-autohide")
check(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("noop.plist").path), "already-configured preference does not create an invented baseline")
let sample = """
CPU Power: 1.40 W
GPU Power: 250 mW
CPU die temperature: 52.0 C
System Average frequency as fraction of nominal: 39.25% (1060.91 Mhz)
OwnerPrivateApp 123 4.0
CPU Power: PRIVATE-CANARY
Serial Number: PRIVATE-CANARY
"""
let fields = PowerSample.parse(sample)
check(fields.count == 4, "only allowlisted numerical power fields survive")
check(!String(describing: fields).contains("PRIVATE"), "no task, identifier or malformed counter is emitted")
check(PowerSample.parse("").isEmpty, "unsupported power fields remain empty")
check(Set(Tweak.all.map { $0.id }).count == 12, "native tweak IDs unique")
check(!PowerSample.command.contains("tasks"), "no process sampler in privileged command")
let link = directory.appendingPathComponent("symlink.plist")
try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory.appendingPathComponent("restore.plist"))
let linked = store("symlink.plist", values)
rejects("symlink journal is rejected") { _ = try linked.apply("finder-status") }
// Policy tests only: no F13 registration or real input observation in this test process.
check(F13HotKey.keyCode == 105, "shortcut is macOS F13 keyCode 105")
check(F13HotKey.modifiers == 0, "shortcut has no modifier keys")
for active in [false, true] {
    for visible in [false, true] {
        for miniaturized in [false, true] {
            for dialog in [false, true] {
                let expected: F13WindowAction = dialog ? .focusDialog : active && visible && !miniaturized ? .hide : .show
                check(F13WindowPolicy.action(appIsActive: active, windowIsVisible: visible, windowIsMiniaturized: miniaturized, hasDialog: dialog) == expected,
                      "F13 window policy active=\(active) visible=\(visible) minimized=\(miniaturized) dialog=\(dialog)")
            }
        }
    }
}
var latch = F13PressLatch()
check(!latch.update(pressed: false), "unmatched key release does nothing")
check(latch.update(pressed: true), "first F13 press toggles once")
check(!latch.update(pressed: true), "holding F13 cannot repeatedly toggle")
check(!latch.update(pressed: false), "release does not toggle")
check(latch.update(pressed: true), "next F13 press can toggle again")
latch.reset()
check(latch.update(pressed: true), "unregister/reset clears any stale held-key state")
let fanFixture: [String: Any] = ["status": "ok", "queryDurationSeconds": 0.05, "fans": [["status": "ok", "rpm": 1800.0]]]
check(FanSamplePolicy.age(nowUptime: 12, completedUptime: 10, nowWall: 1100, completedWall: 1000) == 100, "fan wall-clock age catches time asleep")
check(FanSamplePolicy.age(nowUptime: 20, completedUptime: 10, nowWall: 900, completedWall: 1000) == 10, "backwards wall clock cannot make cached fan younger")
check((FanSamplePolicy.project(fanFixture, age: 2)["status"] as? String) == "ok", "fresh synthetic fan stays valid")
let staleFan = FanSamplePolicy.project(fanFixture, age: 13)
check((staleFan["status"] as? String) == "stale", "old synthetic fan is explicitly stale")
check(((staleFan["fans"] as? [[String: Any]])?.first?["rpm"]) is NSNull, "stale fan RPM is removed instead of replaced with zero")
var slowFan = fanFixture; slowFan["queryDurationSeconds"] = 15.0
check((FanSamplePolicy.project(slowFan, age: 0)["status"] as? String) == "stale", "slow returned query is not labelled fresh")

// Pure bridge/companion policy checks only; no socket/process is opened.
for (address, expected) in [("10.0.0.1", true), ("192.168.1.2", true), ("172.31.1.2", true), ("127.0.0.1", false), ("8.8.8.8", false), ("010.0.0.1", false), ("10.0.0.1\n", false)] {
    check(CompanionPolicy.privateIPv4(address) == expected, "private LAN policy \(address.trimmingCharacters(in: .whitespacesAndNewlines))")
}
check(CompanionPolicy.allowed("setVolume", ["value": 37.5]), "numeric remote volume allowlisted")
check(!CompanionPolicy.allowed("setVolume", ["value": true]), "boolean is not remote volume")
check(!CompanionPolicy.allowed("setVolume", ["value": 50, "shell": "bad"]), "extra command field refused")
check(!CompanionPolicy.allowed("setFan", ["value": 2000]), "no remote fan-write method")
check(!CompanionPolicy.allowed("powerSample", [:]), "phone cannot trigger administrator authorization")
check(!NativeBridgePolicy.allowed("state", ["extra": true]), "native state rejects unexpected parameters")
check(NativeBridgePolicy.allowed("applyTweak", ["id": "dock-recents"]), "new journalled tweak is allowlisted")
check(!NativeBridgePolicy.allowed("applyTweak", ["id": "../boot"]), "arbitrary tweak ID refused")

print("\(checks) native logic checks passed. No real desktop settings, sensors or global shortcut were accessed by these tests.")
