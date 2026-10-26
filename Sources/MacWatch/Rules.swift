import Foundation
struct ProcessRow: Identifiable {
    var id: Int { pid }
    let pid: Int
    let cpu: Double
    let memoryMB: Double
    let name: String
    static func parse(_ line: String) -> ProcessRow? {
        let parts = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard parts.count == 4, let pid = Int(parts[0]), let cpu = Double(parts[1]), let rss = Double(parts[2]) else { return nil }
        return ProcessRow(pid: pid, cpu: cpu, memoryMB: rss / 1024, name: String(parts[3]))
    }
}
struct ActivityEvent: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    let message: String
}
struct DetectionRules {
    var streaks: [String: Int] = [:]
    mutating func evaluate(_ rows: [ProcessRow], idle: Bool) -> [String] {
        var next: [String: Int] = [:]
        var alerts: [String] = []
        for row in rows {
            let key = "\(row.pid):\(row.name)"
            if row.cpu >= (idle ? 25 : 80) {
                let count = (streaks[key] ?? 0) + 1
                next[key] = count
                if count == 6 { alerts.append("\(row.name) (PID \(row.pid)) sustained high CPU: \(Int(row.cpu))%\(idle ? " while you were idle" : ""). Inspect in Activity Monitor if unexpected.") }
            }
        }
        streaks = next
        return alerts
    }
}
