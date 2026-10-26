import SwiftUI
import Charts

struct Overview: View {
    @ObservedObject var monitor: Monitor
    @State private var hours = 1
    @State private var usageDays = 1
    private var trend: [ActivitySample] { monitor.samples.filter { $0.date >= Date().addingTimeInterval(-Double(hours) * 3600) } }
    private var apps: [AppDuration] {
        let start = usageDays == 1 ? Calendar.current.startOfDay(for: Date()) : Date().addingTimeInterval(-7 * 86400)
        return Array(Insights.appTotals(monitor.slices, since: start).prefix(8))
    }
    private var activeCount: Int { trend.filter { !$0.idle }.count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What this means", systemImage: "lightbulb.fill").font(.headline)
                        Text(monitor.paused ? "Tracking is paused. Resume to collect fresh readings. Your saved history stays on this Mac." : Insights.hint(cpu: monitor.systemCPU, thermal: monitor.thermal, idle: monitor.idle))
                        if let top = monitor.rows.first {
                            Text("Highest process CPU estimate: \(URL(fileURLWithPath: top.name).lastPathComponent) · \(Int(top.cpu))%. Open Processes to inspect its full path.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                HStack {
                    Text("CPU load over time").font(.title2.bold())
                    Spacer()
                    Picker("Period", selection: $hours) { Text("1 hour").tag(1); Text("6 hours").tag(6); Text("24 hours").tag(24) }.pickerStyle(.segmented).frame(width: 260)
                }
                if trend.compactMap(\.cpu).isEmpty {
                    empty("Collecting CPU readings", "Keep MacWatch open. One point is saved about every 30 seconds; the first CPU interval needs two readings.")
                } else {
                    Chart(trend) { sample in
                        if let cpu = sample.cpu {
                            PointMark(x: .value("Time", sample.date), y: .value("CPU %", cpu))
                                .foregroundStyle(by: .value("Metric", "System CPU (%)"))
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("CPU capacity (%)")
                    .chartLegend(position: .bottom)
                    .frame(height: 170)
                    .accessibilityLabel("System CPU samples from zero to one hundred percent")
                }
                Text("0% is idle CPU capacity; 100% means all cores are busy. Dots are actual saved readings. Gaps can mean the app was closed, paused or the Mac slept. This is not a temperature graph.").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 20) {
                    GroupBox("Active versus idle samples") {
                        VStack(alignment: .leading, spacing: 10) {
                            if trend.isEmpty { Text("Waiting for activity samples.") }
                            else {
                                Chart {
                                    BarMark(x: .value("Samples", activeCount), y: .value("State", "Active")).foregroundStyle(.blue)
                                    BarMark(x: .value("Samples", trend.count - activeCount), y: .value("State", "Idle")).foregroundStyle(.gray)
                                }.chartXAxisLabel("Observed samples").frame(height: 100)
                                Text("\(Int(Double(activeCount) / Double(trend.count) * 100))% of observed samples were active.").font(.headline)
                            }
                            Text("Idle means no input for 60 seconds. This describes input activity, not productivity. Missing time is excluded.").font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    GroupBox("Heat status explained") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(monitor.thermal, systemImage: "thermometer.medium").font(.title2.bold())
                            Text("Normal: within normal limits.\nWarm: slightly elevated.\nHot: thermal pressure is high.\nCritical: heat is affecting performance.")
                            Text("Reported by macOS. CPU/GPU degrees and fan RPM are not available in this version.").font(.caption).foregroundStyle(.secondary)
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                HStack {
                    Text("Where your active time goes").font(.title2.bold())
                    Spacer()
                    Picker("Usage range", selection: $usageDays) { Text("Today").tag(1); Text("Last 7 days").tag(7) }.pickerStyle(.segmented).frame(width: 230)
                }
                if apps.isEmpty {
                    empty("Your app usage will appear here", "Use your Mac normally with MacWatch running. Only the foreground app is counted; idle time is excluded.")
                } else {
                    Chart(apps) { app in
                        BarMark(x: .value("Minutes", app.seconds / 60), y: .value("App", app.app))
                            .foregroundStyle(.blue.gradient)
                            .annotation(position: .trailing) { Text(String(format: "%.1f min", app.seconds / 60)).font(.caption) }
                    }.chartYAxis { AxisMarks(position: .leading) }
                    .chartXAxisLabel("Active minutes")
                    .frame(height: max(100, CGFloat(apps.count) * 32))
                }
                Text("Top 8 apps, sampled about every 5 seconds. Today uses your Mac's local calendar. Last 7 days is a rolling window. Estimates may miss brief switches; historical totals from v0.1 cannot be assigned to a day.").font(.caption).foregroundStyle(.secondary)
                GroupBox("Simple ways to investigate unexpected activity") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Check Processes for sustained CPU usage. A short spike during a build or launch is normal.")
                        Text("2. Compare Connections with the apps you opened. A socket is not proof that data is being sent.")
                        Text("3. Review Startup and System Settings → General → Login Items for apps you no longer use.")
                        Text("4. If heat stays high, pause demanding work and check ventilation. Avoid force-quitting unfamiliar system processes.")
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(18)
        }
    }
    private func empty(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(detail).foregroundStyle(.secondary) }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
