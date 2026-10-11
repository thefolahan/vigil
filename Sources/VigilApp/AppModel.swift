import AppKit
import Combine
import ServiceManagement
import VigilKit

@MainActor
final class AppModel: ObservableObject {
    // MARK: Live state

    @Published private(set) var agents: [AgentSnapshot] = []
    @Published private(set) var isAwake = false
    @Published private(set) var sessionStarted: Date?
    @Published private(set) var lidModeInstalled = false
    @Published private(set) var lidHeldOpen = false
    @Published private(set) var lidClosed = false
    @Published private(set) var trip: GuardTrip?
    @Published private(set) var thermal: ProcessInfo.ThermalState = .nominal
    @Published private(set) var battery: BatteryState?
    @Published private(set) var holdUntil: Date?
    @Published private(set) var sessions: [SessionRecord] = SessionStore.load()
    @Published private(set) var now = Date()
    @Published var setupError: String?
    @Published private(set) var settingUp = false

    // MARK: Settings

    @Published var watchAgents: Bool { didSet { defaults.set(watchAgents, forKey: "watchAgents"); tick() } }
    @Published var lidMode: Bool {
        didSet {
            guard !demo, oldValue != lidMode else { return }
            defaults.set(lidMode, forKey: "lidMode")
            tick()
        }
    }
    @Published var graceMinutes: Int { didSet { defaults.set(graceMinutes, forKey: "graceMinutes"); tick() } }
    @Published var batteryFloor: Int { didSet { defaults.set(batteryFloor, forKey: "batteryFloor"); tick() } }
    @Published var notifyWhenDone: Bool { didSet { defaults.set(notifyWhenDone, forKey: "notifyWhenDone") } }
    @Published var phoneTopic: String { didSet { defaults.set(phoneTopic, forKey: "phoneTopic") } }
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                setupError = "Open at login could not be changed: \(error.localizedDescription)"
            }
        }
    }

    private let defaults = UserDefaults.standard
    private let tracker = AgentTracker()
    private let assertion = SleepAssertion()
    private let notifier = Notifier()
    private var timer: Timer?
    private var sessionAgents: [String] = []
    private var lidClosedTime: TimeInterval = 0
    private var lastTick = Date()
    private var stopReason = "Every agent finished"

    init() {
        defaults.register(defaults: [
            "watchAgents": true, "lidMode": false, "graceMinutes": 3, "batteryFloor": 25,
            "notifyWhenDone": true, "phoneTopic": ""
        ])
        watchAgents = defaults.bool(forKey: "watchAgents")
        lidMode = defaults.bool(forKey: "lidMode")
        graceMinutes = defaults.integer(forKey: "graceMinutes")
        batteryFloor = defaults.integer(forKey: "batteryFloor")
        notifyWhenDone = defaults.bool(forKey: "notifyWhenDone")
        phoneTopic = defaults.string(forKey: "phoneTopic") ?? ""
        launchAtLogin = SMAppService.mainApp.status == .enabled

        // A previous run that ended without restoring sleep, such as a crash.
        if FileManager.default.fileExists(atPath: LidMode.markerURL.path) {
            try? LidMode.setSleepDisabled(false)
        }
        lidModeInstalled = LidMode.isInstalled()
        if lidModeInstalled { try? LidMode.installGuard() }
        notifier.requestPermission()

        tick()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    // MARK: Derived

    var grace: TimeInterval { TimeInterval(graceMinutes * 60) }
    var workingAgents: [AgentSnapshot] { agents.filter { $0.activity == .working } }
    var heldBy: [AgentSnapshot] { watchAgents ? agents.filter { holdsAwake($0, at: now, grace: grace) } : [] }
    var holdActive: Bool { holdUntil.map { $0 > now } ?? false }

    var headline: String {
        if !isAwake { return agents.isEmpty ? "Nothing to watch" : "Agents are idle" }
        let count = heldBy.count
        if count == 0 { return "Holding awake" }
        return "Watching \(Format.count(count, "agent"))"
    }

    var detail: String {
        if let trip { return trip.message }
        if isAwake, let sessionStarted {
            var parts = ["Awake for \(Format.duration(now.timeIntervalSince(sessionStarted)))"]
            if holdActive, let holdUntil {
                parts.append(holdUntil == .distantFuture ? "held until you stop" : "held for \(Format.countdown(holdUntil.timeIntervalSince(now)))")
            } else if workingAgents.isEmpty, let last = heldBy.compactMap(\.lastActive).max() {
                parts.append("sleeps in \(Format.countdown(grace - now.timeIntervalSince(last)))")
            }
            return parts.joined(separator: ", ")
        }
        return agents.isEmpty ? "Your Mac can sleep as usual." : "Your Mac can sleep. Vigil wakes up when they do."
    }

    // MARK: Loop

    /// `-VigilDemo YES` shows sample agents for screenshots and never touches
    /// power settings.
    private let demo = UserDefaults.standard.bool(forKey: "VigilDemo")

    func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        self.now = now
        if demo {
            showDemo(at: now)
            return
        }

        let (agents, events) = tracker.sample()
        self.agents = agents
        thermal = ProcessInfo.processInfo.thermalState
        battery = SystemHealth.battery()
        lidClosed = SystemHealth.lidClosed()
        if let holdUntil, holdUntil <= now {
            self.holdUntil = nil
            stopReason = "The hold ran out"
        }

        let busy = heldBy
        var stayAwake = !busy.isEmpty || holdActive
        trip = GuardPolicy(batteryFloor: batteryFloor).trip(thermal: thermal, battery: battery)
        if thermal == .critical {
            stayAwake = false
            stopReason = "The Mac was critically hot"
        }

        // Session bookkeeping happens before power changes so the end of a
        // session is recorded even if the Mac sleeps right after.
        if stayAwake {
            if sessionStarted == nil {
                sessionStarted = now
                sessionAgents = []
                lidClosedTime = 0
                stopReason = "Every agent finished"
            }
            for agent in busy where agent.activity == .working {
                let label = "\(agent.kind.name) in \(agent.project)"
                if !sessionAgents.contains(label) { sessionAgents.append(label) }
            }
            if lidClosed, lidHeldOpen { lidClosedTime += elapsed }
        } else if let started = sessionStarted {
            finishSession(started: started, at: now)
        }

        handle(events)
        apply(stayAwake: stayAwake, busy: busy)
    }

    private func apply(stayAwake: Bool, busy: [AgentSnapshot]) {
        isAwake = stayAwake
        if stayAwake {
            let reason = busy.isEmpty ? "Vigil: held awake" : "Vigil: \(busy.map(\.kind.name).joined(separator: ", ")) working"
            assertion.hold(reason: reason)
        } else {
            assertion.release()
        }

        let wantLid = stayAwake && lidMode && lidModeInstalled && trip == nil
        guard wantLid != lidHeldOpen else { return }
        do {
            try LidMode.setSleepDisabled(wantLid)
            lidHeldOpen = wantLid
            if !wantLid, lidClosed { LidMode.sleepNow() }
        } catch {
            setupError = error.localizedDescription
            lidModeInstalled = LidMode.isInstalled()
        }
    }

    private func handle(_ events: [AgentEvent]) {
        for event in events {
            guard case let .settled(agent, workedFor) = event, notifyWhenDone else { continue }
            let title = "\(agent.kind.name) stopped in \(agent.project)"
            let body = "It worked for \(Format.duration(workedFor)) and is now finished or waiting for you."
            notifier.post(title: title, body: body)
            sendToPhone(title: title, body: body)
        }
    }

    private func finishSession(started: Date, at now: Date) {
        let record = SessionRecord(started: started, ended: now, agents: sessionAgents, lidClosed: lidClosedTime, endReason: stopReason)
        sessionStarted = nil
        guard record.length >= 60 else { return }
        sessions.insert(record, at: 0)
        SessionStore.save(sessions)
        if notifyWhenDone, !record.agents.isEmpty {
            let title = "Your Mac can sleep again"
            let body = "\(stopReason) after \(Format.duration(record.length))."
            notifier.post(title: title, body: body)
            sendToPhone(title: title, body: body)
        }
    }

    /// Phone alerts go through ntfy, and only while you are away from the Mac.
    private func sendToPhone(title: String, body: String) {
        let topic = phoneTopic.trimmingCharacters(in: .whitespaces)
        guard !topic.isEmpty, lidClosed || SystemHealth.secondsSinceInput() > 300 else { return }
        PhoneAlert.send(topic: topic, title: title, body: body)
    }

    private func showDemo(at now: Date) {
        func agent(_ pid: pid_t, _ id: String, _ folder: String, working: Bool, since: TimeInterval, quiet: TimeInterval = 0,
                   traffic: Double, seed: Double) -> AgentSnapshot {
            let kind = AgentCatalog.builtIn.first { $0.id == id }!
            let history = (0..<24).map { index -> Double in
                guard working || quiet > 0 else { return 15 }
                let wave = abs(sin(Double(index) * 0.7 + seed)) * traffic * 1.6 + abs(cos(Double(index) * 1.9 + seed)) * traffic * 0.6
                return quiet > 0 && index > 18 ? 15 : wave
            }
            return AgentSnapshot(id: pid, kind: kind, directory: "/Users/demo/code/\(folder)", started: now.addingTimeInterval(-since - 600),
                                 activity: working ? .working : .waiting, cpu: working ? 2.1 : 0.4, traffic: working ? traffic : 15,
                                 toolCPU: 0, lastActive: working ? now : (quiet > 0 ? now.addingTimeInterval(-quiet) : nil),
                                 workingSince: working ? now.addingTimeInterval(-since) : nil, workedFor: since, history: history)
        }
        agents = [
            agent(4120, "claude", "api-pilot", working: true, since: 47 * 60, traffic: 2400, seed: 0.3),
            agent(4388, "codex", "clipline", working: true, since: 12 * 60, traffic: 1300, seed: 1.7),
            agent(4501, "gemini", "842games", working: false, since: 6 * 60, quiet: 64, traffic: 900, seed: 2.4),
            agent(3907, "claude", "cleartweet", working: false, since: 0, traffic: 0, seed: 0),
            agent(3311, "opencode", "notes", working: false, since: 0, traffic: 0, seed: 0)
        ]
        thermal = .nominal
        battery = BatteryState(percent: 84, onBattery: false)
        lidClosed = false
        lidModeInstalled = true
        lidMode = true
        lidHeldOpen = true
        isAwake = true
        if sessionStarted == nil { sessionStarted = now.addingTimeInterval(-52 * 60) }
        if sessions.first?.agents.first != "Claude Code in api-pilot" {
            let day = now.addingTimeInterval(-86_400)
            sessions = [
                SessionRecord(started: day, ended: day.addingTimeInterval(2 * 3600 + 14 * 60),
                              agents: ["Claude Code in api-pilot", "Codex in clipline"], lidClosed: 95 * 60, endReason: "Every agent finished"),
                SessionRecord(started: day.addingTimeInterval(-30_000), ended: day.addingTimeInterval(-27_100),
                              agents: ["Claude Code in cleartweet"], lidClosed: 0, endReason: "Every agent finished")
            ]
        }
    }

    // MARK: Actions

    func hold(for minutes: Int?) {
        holdUntil = minutes.map { Date().addingTimeInterval(TimeInterval($0 * 60)) } ?? .distantFuture
        tick()
    }

    func stopHold() {
        holdUntil = nil
        stopReason = "You stopped the hold"
        tick()
    }

    func clearHistory() {
        sessions = []
        SessionStore.save([])
    }

    func sendTestAlert() {
        let topic = phoneTopic.trimmingCharacters(in: .whitespaces)
        guard !topic.isEmpty else { return }
        PhoneAlert.send(topic: topic, title: "Vigil is connected", body: "Alerts about your agents will arrive here while you are away.")
    }

    /// Installs the sudoers rule behind lid mode. macOS asks for an
    /// administrator password once.
    func setUpLidMode() {
        settingUp = true
        setupError = nil
        defer { settingUp = false }
        do {
            let script = try LidMode.installScript(for: NSUserName())
            try runAsAdministrator(script, prompt: "Vigil needs your password once to let you turn sleep off and on while the lid is closed.")
            try LidMode.installGuard()
            lidModeInstalled = LidMode.isInstalled()
            if lidModeInstalled { lidMode = true } else { setupError = "Setup finished, but the rule did not take effect." }
        } catch {
            setupError = error.localizedDescription
        }
    }

    func removeLidMode() {
        setupError = nil
        do {
            try runAsAdministrator(LidMode.uninstallScript, prompt: "Vigil needs your password to remove its lid mode permission.")
            LidMode.removeGuard()
            try? FileManager.default.removeItem(at: LidMode.markerURL)
            lidHeldOpen = false
            lidMode = false
            lidModeInstalled = LidMode.isInstalled()
        } catch {
            setupError = error.localizedDescription
        }
    }

    /// Restores normal sleep before the app quits.
    func shutDown() {
        timer?.invalidate()
        if let started = sessionStarted {
            stopReason = "Vigil quit"
            finishSession(started: started, at: Date())
        }
        assertion.release()
        if lidHeldOpen { try? LidMode.setSleepDisabled(false) }
    }

    private func runAsAdministrator(_ script: String, prompt: String) throws {
        func quoted(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n") + "\""
        }
        let source = "do shell script \(quoted(script)) with prompt \(quoted(prompt)) with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            if number == -128 { throw SetupCancelled() }
            throw NSError(domain: "Vigil", code: number ?? 1, userInfo: [
                NSLocalizedDescriptionKey: error[NSAppleScript.errorMessage] as? String ?? "The administrator step failed."
            ])
        }
    }
}

struct SetupCancelled: LocalizedError {
    var errorDescription: String? { "Setup was cancelled." }
}
