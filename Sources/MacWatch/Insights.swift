import Foundation

struct ActivitySample: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let cpu: Double?
    let idle: Bool
    let thermal: String
}
struct UsageSlice: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let app: String
    let seconds: Double
}
struct AppDuration: Identifiable {
    var id: String { app }
    let app: String
    let seconds: Double
}
enum Insights {
    static func cpuPercent(previous: [UInt64], current: [UInt64]) -> Double? {
        guard previous.count == 4, current.count == 4, zip(previous, current).allSatisfy({ $0 <= $1 }) else { return nil }
        let delta = zip(previous, current).map { $1 - $0 }
        let total = delta.reduce(0, +)
        guard total > 0 else { return nil }
        return Double(total - delta[2]) / Double(total) * 100
    }
    static func appTotals(_ slices: [UsageSlice], since: Date) -> [AppDuration] {
        var totals: [String: Double] = [:]
        for slice in slices where slice.date >= since { totals[slice.app, default: 0] += slice.seconds }
        return totals.map { AppDuration(app: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }
    }
    static func hint(cpu: Double?, thermal: String, idle: Bool) -> String {
        if thermal == "Hot" || thermal == "Critical" { return "Your Mac reports thermal pressure. Pause heavy tasks, keep vents clear, and inspect the busiest processes. CPU load alone does not measure temperature." }
        guard let cpu else { return "Collecting the first CPU interval. Charts appear as real samples arrive; no activity is reconstructed from before MacWatch opened." }
        if cpu >= 80 { return "Most CPU capacity is busy. Builds, games and video exports can explain this. If unexpected, inspect the Processes tab before closing an app." }
        if idle && cpu >= 25 { return "Your Mac is working while you are away. Backups, updates and indexing are common causes. Check the top processes if this continues." }
        return "CPU load is moderate or low. If your Mac still feels slow, inspect memory-heavy processes and available storage in Activity Monitor and System Settings." 
    }
}
