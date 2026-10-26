import SwiftUI
import AppKit
import CoreGraphics

func command(_ path: String, _ args: [String]) -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    process.environment = ["LC_ALL": "C", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
    do {
        try process.run()
        // Drain before waiting so large process/socket lists cannot fill the pipe.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return "Unavailable (permission, tool, or system limitation)." }
        return String(decoding: data, as: UTF8.self)
    } catch { return "Unavailable: \(error.localizedDescription)" }
}

@MainActor final class Monitor: ObservableObject {
    @Published var rows: [ProcessRow] = []
    @Published var events: [ActivityEvent] = []
    @Published var usage: [String: Double] = [:]
    @Published var thermal = "Checking"
    @Published var idle = false
    @Published var battery = "Checking"
    @Published var connections = "Click Refresh to inspect current TCP and UDP sockets."
    @Published var startup = "Click Refresh to list launch services."
    @Published var lastSample: Date?
    @Published var error: String?
    private var rules = DetectionRules()
    private var task: Task<Void, Never>?
    private var previousTime = Date()
    private var previousApp: String?
    private var previousActive = false
    private var lastThermal = ""
    private var sampleCount = 0
    private let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MacWatch")
    private var historyURL: URL { folder.appendingPathComponent("history.json") }
    init() {
        if let data = try? Data(contentsOf: historyURL), let saved = try? JSONDecoder().decode([ActivityEvent].self, from: data) { events = saved }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("usage.json")), let saved = try? JSONDecoder().decode([String: Double].self, from: data) { usage = saved }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.sample()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    func record(_ message: String) {
        events.insert(ActivityEvent(message: message), at: 0)
        events = Array(events.prefix(500))
    }
    func persist() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(events).write(to: historyURL, options: .atomic)
            try JSONEncoder().encode(usage).write(to: folder.appendingPathComponent("usage.json"), options: .atomic)
        } catch { self.error = "Could not save local history: \(error.localizedDescription)" }
    }
    func sample() async {
        let output = await Task.detached { command("/bin/ps", ["-axo", "pid=,pcpu=,rss=,comm="]) }.value
        let parsed = output.split(separator: "\n").compactMap { ProcessRow.parse(String($0)) }
        if parsed.isEmpty { error = "Process list unavailable. Other readings may still work." }
        rows = parsed.sorted { $0.cpu > $1.cpu }
        let now = Date()
        let elapsed = now.timeIntervalSince(previousTime)
        idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null) >= 60
        if previousActive, !idle, elapsed < 30, let app = previousApp { usage[app, default: 0] += elapsed }
        previousTime = now
        previousApp = NSWorkspace.shared.frontmostApplication?.localizedName
        previousActive = !idle
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "Normal"
        case .fair: thermal = "Warm"
        case .serious: thermal = "Hot"
        case .critical: thermal = "Critical"
        @unknown default: thermal = "Unknown"
        }
        if thermal != lastThermal {
            if thermal == "Hot" || thermal == "Critical" { record("Thermal status: \(thermal). Review the highest CPU processes and check ventilation.") }
            lastThermal = thermal
        }
        for alert in rules.evaluate(rows, idle: idle) { record(alert) }
        sampleCount += 1
        if sampleCount == 1 || sampleCount % 6 == 0 {
            battery = await Task.detached { command("/usr/bin/pmset", ["-g", "batt"]) }.value
            persist()
        }
        lastSample = now
    }
    func refreshConnections() {
        Task {
            connections = "Reading…"
            connections = await Task.detached { command("/usr/sbin/lsof", ["-nP", "-i"]) }.value
        }
    }
    func refreshStartup() {
        Task {
            startup = "Reading…"
            startup = await Task.detached {
                let fm = FileManager.default
                let paths = [fm.homeDirectoryForCurrentUser.path + "/Library/LaunchAgents", "/Library/LaunchAgents", "/Library/LaunchDaemons"]
                return paths.map { path in
                    let files = (try? fm.contentsOfDirectory(atPath: path)) ?? []
                    return path + "\n" + (files.isEmpty ? "No readable entries" : files.sorted().joined(separator: "\n"))
                }.joined(separator: "\n\n")
            }.value
        }
    }
    func clearHistory() { events = []; usage = [:]; persist() }
}

@main struct MacWatchApp: App {
    @StateObject private var monitor = Monitor()
    var body: some Scene {
        WindowGroup { Dashboard(monitor: monitor).frame(minWidth: 950, minHeight: 670) }
        MenuBarExtra("MacWatch · \(monitor.thermal)", systemImage: "waveform.path.ecg") {
            Text("Thermal status: \(monitor.thermal)")
            Text("\(monitor.rows.count) processes · \(monitor.idle ? "Idle" : "Active")")
            Divider()
            Button("Show dashboard") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil) }
            Button("Quit MacWatch") { monitor.persist(); NSApplication.shared.terminate(nil) }
        }
    }
}
struct Dashboard: View {
    @ObservedObject var monitor: Monitor
    @State private var query = ""
    @State private var clear = false
    var filtered: [ProcessRow] { monitor.rows.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || String($0.pid).contains(query) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading) {
                    Text("MacWatch").font(.largeTitle.bold())
                    Text("Know what your Mac is doing.").foregroundStyle(.secondary)
                }
                Spacer()
                Label(monitor.idle ? "Idle" : "Active", systemImage: "circle.fill").foregroundStyle(.mint)
                Button("Activity Monitor") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")) }
            }
            HStack(spacing: 12) {
                metric("Thermal status", monitor.thermal, "thermometer.medium")
                metric("Processes", "\(monitor.rows.count)", "cpu")
                metric("Process memory sum", String(format: "%.1f GB", monitor.rows.reduce(0) { $0 + $1.memoryMB } / 1024), "memorychip")
                metric("Saved alerts", "\(monitor.events.count)", "bell.badge")
            }
            Text("CPU/GPU °C and fan RPM: unavailable in this version. Thermal status is macOS heat pressure, not a temperature measurement. Process memory can count shared pages more than once.").font(.caption).foregroundStyle(.secondary)
            if let error = monitor.error { Text(error).foregroundStyle(.orange) }
            TabView {
                VStack {
                    TextField("Search process or PID", text: $query).textFieldStyle(.roundedBorder)
                    Table(filtered) {
                        TableColumn("Process") { row in Text(row.name).help(row.name) }
                        TableColumn("PID") { row in Text("\(row.pid)") }.width(70)
                        TableColumn("CPU %") { row in Text(String(format: "%.1f", row.cpu)) }.width(90)
                        TableColumn("Memory MB") { row in Text(String(format: "%.0f", row.memoryMB)) }.width(110)
                    }
                    Text("CPU uses ps's recent/lifetime estimate; 100% represents one CPU core. Alerts require six consecutive high samples (~30 seconds). Background activity is often legitimate.").font(.caption).foregroundStyle(.secondary)
                }.padding().tabItem { Label("Processes", systemImage: "cpu") }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Unusual activity").font(.title2.bold())
                        Text("High CPU ≥80%, or ≥25% while idle for 60 seconds. These are review hints, not malware verdicts. No processes are stopped automatically.").foregroundStyle(.secondary)
                        if monitor.events.isEmpty { Text("No sustained high usage detected yet. Monitoring runs while MacWatch is open.") }
                        ForEach(monitor.events) { event in
                            VStack(alignment: .leading) { Text(event.date, style: .date).font(.caption); Text(event.date, style: .time).font(.caption); Text(event.message) }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding()
                }.tabItem { Label("Alerts", systemImage: "bell") }
                inspection(monitor.connections, action: monitor.refreshConnections, note: "Read-only TCP/UDP socket snapshot. Some processes require additional privileges and may be absent. Connections alone do not imply suspicious activity; this does not measure bandwidth.")
                    .tabItem { Label("Connections", systemImage: "network") }
                inspection(monitor.startup, action: monitor.refreshStartup, note: "Third-party launch plist inventory. For modern Login Items and background permissions, open System Settings → General → Login Items. This list is not exhaustive.")
                    .tabItem { Label("Startup", systemImage: "power") }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Foreground app time").font(.title2.bold())
                        Text("Sampled every 5 seconds while active; stored locally. No keystrokes, screenshots, browser history or document content collected.").foregroundStyle(.secondary)
                        ForEach(monitor.usage.sorted { $0.value > $1.value }, id: \.key) { entry in
                            HStack { Text(entry.key); Spacer(); Text(String(format: "%.1f min", entry.value / 60)) }
                        }
                        Divider()
                        Text(monitor.battery).font(.system(.body, design: .monospaced))
                        Button("Delete local history", role: .destructive) { clear = true }
                    }.padding()
                }.tabItem { Label("Usage & battery", systemImage: "chart.bar") }
            }
            HStack { Text("Private • Local • Read only"); Spacer(); if let date = monitor.lastSample { Text("Updated \(date.formatted(date: .omitted, time: .standard))") } }.font(.caption).foregroundStyle(.secondary)
        }.padding(24).tint(.cyan)
        .confirmationDialog("Delete all saved alerts and app usage?", isPresented: $clear) { Button("Delete history", role: .destructive) { monitor.clearHistory() } }
    }
    func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Label(title, systemImage: icon).foregroundStyle(.secondary); Text(value).font(.title.bold()) }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
    }
    func inspection(_ text: String, action: @escaping () -> Void, note: String) -> some View {
        VStack(alignment: .leading) { HStack { Text(note).font(.caption).foregroundStyle(.secondary); Spacer(); Button("Refresh", action: action) }; ScrollView([.vertical, .horizontal]) { Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) } }.padding()
    }
}
