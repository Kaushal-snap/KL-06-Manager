import Foundation

// One background read at most every five seconds. No UI-thread IOKit calls,
// driver installation, helper service or SMC writes. A stalled kernel query
// cannot be forcibly cancelled; no second query overlaps it.
enum FanSamplePolicy {
    static func age(nowUptime: TimeInterval, completedUptime: TimeInterval, nowWall: TimeInterval, completedWall: TimeInterval) -> TimeInterval {
        // Wall age catches time asleep; monotonic age resists a backwards clock.
        return max(0, max(nowUptime - completedUptime, nowWall - completedWall))
    }
    static func project(_ input: [String: Any], age: TimeInterval) -> [String: Any] {
        var result = input; result["ageSeconds"] = age
        let duration = result["queryDurationSeconds"] as? Double ?? 0
        if !age.isFinite || age > 12 || duration > 12 {
            result["status"] = "stale"
            result["fans"] = (result["fans"] as? [[String: Any]] ?? []).map { row -> [String: Any] in
                var value = row; value["rpm"] = NSNull(); value["status"] = "stale"; return value
            }
        }
        return result
    }
}
final class FanMonitor {
    private let queue = DispatchQueue(label: "app.kl06.smc-read", qos: .utility)
    private let lock = NSLock()
    private var busy = false
    private var attempted = false
    private var lastAttempt: TimeInterval = -.infinity
    private var completed: TimeInterval?
    private var completedWall: TimeInterval?
    private var cached: [String: Any] = [:]
    func snapshot(requestRead: Bool = true) -> [String: Any] {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        if requestRead && !busy && now - lastAttempt >= 5 {
            busy = true; attempted = true; lastAttempt = now
            queue.async { [weak self] in
                guard let self = self else { return }
                let started = ProcessInfo.processInfo.systemUptime
                var report = kl06_fan_report()
                kl06_read_fans(&report)
                let done = ProcessInfo.processInfo.systemUptime, doneDate = Date()
                var readings: [[String: Any]] = []
                let items = [report.fans.0, report.fans.1]
                for index in 0..<min(2, Int(report.fan_count_read)) {
                    let fan = items[index]
                    var value: [String: Any] = ["index": index, "status": String(cString: kl06_fan_status_name(fan.status)), "rpm": NSNull()]
                    if fan.status == 0 && fan.rpm.isFinite && fan.rpm >= 0 && fan.rpm <= 30000 { value["rpm"] = fan.rpm }
                    readings.append(value)
                }
                var result: [String: Any] = ["status": String(cString: kl06_fan_status_name(report.status)),
                    "source": "Existing AppleSMC / VirtualSMC provider", "quality": "provider-reported-not-calibrated", "fans": readings,
                    "reportedAt": ISO8601DateFormatter().string(from: doneDate), "queryDurationSeconds": max(0, done - started),
                    "ageBasis": "time-since-query-completion-not-physical-sensor-age", "physicalSensorAgeSeconds": NSNull(),
                    "manualControl": false, "pollSeconds": 5]
                if report.status == 0 || report.status == 6 || report.status == 8 { result["reportedCount"] = report.fan_count_reported }
                self.lock.lock(); self.cached = result; self.completed = done; self.completedWall = doneDate.timeIntervalSince1970; self.busy = false; self.lock.unlock()
            }
        }
        var result: [String: Any]
        if let done = completed, let wall = completedWall {
            let age = FanSamplePolicy.age(nowUptime: now, completedUptime: done, nowWall: Date().timeIntervalSince1970, completedWall: wall)
            result = FanSamplePolicy.project(cached, age: age)
        } else { result = ["status": attempted ? "sampling" : "not-sampled", "fans": [], "manualControl": false] }
        result["busy"] = busy
        lock.unlock(); return result
    }
}
