import Darwin
import Foundation

public enum AgentActivity: String, Sendable, Codable {
    /// Talking to its model, or running a tool that is busy on the CPU.
    case working
    /// Idle at its prompt, done or waiting for an answer from you.
    case waiting
}

/// What Vigil knows about one running agent after the latest sample.
public struct AgentSnapshot: Sendable, Identifiable, Hashable {
    public let id: pid_t
    public let kind: AgentKind
    public let directory: String?
    public let started: Date
    public let activity: AgentActivity
    /// CPU used by the agent process itself, averaged over the window.
    public let cpu: Double
    /// Bytes a second to and from its model, averaged over the window.
    public let traffic: Double
    /// CPU used by every process the agent started, averaged over the window.
    public let toolCPU: Double
    /// When the agent was last seen working.
    public let lastActive: Date?
    /// When the current stretch of work began, while working.
    public let workingSince: Date?
    /// Total time this agent has been seen working.
    public let workedFor: TimeInterval
    /// Recent traffic readings in bytes a second, oldest first.
    public let history: [Double]

    public init(id: pid_t, kind: AgentKind, directory: String?, started: Date, activity: AgentActivity, cpu: Double,
                traffic: Double, toolCPU: Double, lastActive: Date?, workingSince: Date?, workedFor: TimeInterval, history: [Double]) {
        self.id = id
        self.kind = kind
        self.directory = directory
        self.started = started
        self.activity = activity
        self.cpu = cpu
        self.traffic = traffic
        self.toolCPU = toolCPU
        self.lastActive = lastActive
        self.workingSince = workingSince
        self.workedFor = workedFor
        self.history = history
    }

    public var pid: pid_t { id }

    /// The folder the agent was started in, for display.
    public var project: String {
        guard let directory else { return "unknown folder" }
        if directory == NSHomeDirectory() { return "~" }
        return (directory as NSString).lastPathComponent
    }
}

public enum AgentEvent: Sendable, Equatable {
    case appeared(AgentSnapshot)
    /// The agent stopped after a real stretch of work: finished, or waiting
    /// for a permission or a reply.
    case settled(AgentSnapshot, workedFor: TimeInterval)
    case exited(AgentSnapshot)
}

public struct ActivityPolicy: Sendable, Equatable {
    /// Bytes a second that count as talking to the model. Idle sessions
    /// exchange keep alive pings at about 15; a streaming reply is far above.
    public var trafficThreshold: Double = 120
    /// Percent of one core the agent itself must use to count as working
    /// without traffic, such as a local model running in process. It is high
    /// because some hosts keep an idle agent at around one percent.
    public var agentThreshold: Double = 15
    /// Percent of one core its tools must use to count on their own, such as
    /// a build or a test run started by the agent.
    public var toolThreshold: Double = 3
    /// A tool the agent started just after talking to its model counts as work
    /// for this long, even while it waits quietly, such as a test run against
    /// a slow server. Past that it counts only while busy on the CPU, so a dev
    /// server left running in the background does not hold the Mac forever.
    public var toolWindow: TimeInterval = 600
    /// Number of samples averaged.
    public var window: Int = 3
    /// How long an agent must stay idle before it counts as settled.
    public var settleAfter: TimeInterval = 20
    /// The shortest stretch of work worth a notification.
    public var minimumRun: TimeInterval = 45

    public init() {}
}

/// Follows agents across samples of the process table and decides which of
/// them are working.
public final class AgentTracker {
    public let catalog: AgentCatalog
    public var policy: ActivityPolicy

    private struct State {
        var kind: AgentKind
        var directory: String?
        var started: Date
        var ownSamples: [Double] = []
        var trafficSamples: [Double] = []
        var treeSamples: [Double] = []
        var history: [Double] = []
        var lastActive: Date?
        var lastTraffic: Date?
        var workingSince: Date?
        var runStarted: Date?
        var workedFor: TimeInterval = 0
        var activity: AgentActivity = .waiting
        var announcedRun = true
    }

    private var states: [pid_t: State] = [:]
    private var previous: ProcessTable?
    private var previousTraffic: [pid_t: UInt64] = [:]
    private var argumentCache: [pid_t: (started: Date, kind: AgentKind?)] = [:]
    /// Samples taken so far. Activity is known from the second one on.
    public private(set) var samples = 0

    public init(catalog: AgentCatalog = AgentCatalog(), policy: ActivityPolicy = ActivityPolicy()) {
        self.catalog = catalog
        self.policy = policy
    }

    /// Samples the live process table and network counters.
    public func sample() -> (agents: [AgentSnapshot], events: [AgentEvent]) {
        update(with: .current(), traffic: NetworkUsage.snapshot())
    }

    /// Takes a new sample and returns every agent with the events it caused.
    /// `traffic` holds cumulative bytes in and out for each process.
    public func update(
        with table: ProcessTable,
        traffic: [pid_t: UInt64],
        arguments: (pid_t) -> [String] = ProcessTable.arguments(of:),
        directory: (pid_t) -> String? = ProcessTable.workingDirectory(of:)
    ) -> (agents: [AgentSnapshot], events: [AgentEvent]) {
        var events: [AgentEvent] = []
        let found = findAgents(in: table, arguments: arguments)
        let elapsed = previous.map { table.takenAt.timeIntervalSince($0.takenAt) } ?? 0

        for (pid, state) in states where found[pid] == nil {
            events.append(.exited(snapshot(pid: pid, state: state)))
            states[pid] = nil
        }

        for (pid, agent) in found {
            let kind = agent.kind
            guard let record = table.records[pid] else { continue }
            var state = states[pid] ?? State(kind: kind, directory: directory(pid), started: record.started)
            let isNew = states[pid] == nil

            if elapsed > 0 {
                // The agent's own processes, including the binary behind a
                // node wrapper, count as the agent; everything else it started
                // counts as its tools.
                let core = [record] + agent.nested.compactMap { table.records[$0] }
                let corePIDs = Set(core.map(\.pid))
                let own = percent(of: core.reduce(0) { $0 + cpuDelta($1) }, over: elapsed)
                let tools = table.descendants(of: pid).filter { !corePIDs.contains($0.pid) }
                let tree = percent(of: tools.reduce(0) { $0 + cpuDelta($1) }, over: elapsed)
                let bytes = core.reduce(UInt64(0)) { total, process in
                    let now = traffic[process.pid] ?? 0
                    // Counters restart when connections close, so a drop is
                    // read as no traffic rather than a negative rate.
                    return total + (now &- min(previousTraffic[process.pid] ?? now, now))
                }
                let rate = Double(bytes) / elapsed
                state.ownSamples = Array((state.ownSamples + [own]).suffix(policy.window))
                state.treeSamples = Array((state.treeSamples + [tree]).suffix(policy.window))
                state.trafficSamples = Array((state.trafficSamples + [rate]).suffix(policy.window))
                state.history = Array((state.history + [rate]).suffix(60))

                let now = table.takenAt
                // A reply streams across several samples. Idle sessions
                // sometimes sync a few kilobytes at once, which fits in one.
                let talking = state.trafficSamples.filter { $0 >= policy.trafficThreshold }.count >= 2
                if rate >= policy.trafficThreshold { state.lastTraffic = now }
                // A tool started within moments of the model's last reply,
                // which is how an agent runs a command it was asked to run.
                let runningTool = state.lastTraffic.map { last in
                    tools.contains { tool in
                        corePIDs.contains(tool.parent) && tool.started >= last.addingTimeInterval(-30)
                            && now.timeIntervalSince(tool.started) <= policy.toolWindow
                    }
                } ?? false
                let working = talking || runningTool
                    || average(state.ownSamples) >= policy.agentThreshold
                    || average(state.treeSamples) >= policy.toolThreshold

                if working {
                    if state.activity == .waiting { state.workingSince = now }
                    if state.runStarted == nil {
                        state.runStarted = now
                        state.announcedRun = false
                    }
                    state.workedFor += elapsed
                    state.lastActive = now
                    state.activity = .working
                } else {
                    state.activity = .waiting
                    state.workingSince = nil
                    if let runStarted = state.runStarted, let lastActive = state.lastActive,
                       now.timeIntervalSince(lastActive) >= policy.settleAfter {
                        let run = lastActive.timeIntervalSince(runStarted)
                        if !state.announcedRun, run >= policy.minimumRun {
                            events.append(.settled(snapshot(pid: pid, state: state), workedFor: run))
                        }
                        state.announcedRun = true
                        state.runStarted = nil
                    }
                }
            }

            states[pid] = state
            if isNew, previous != nil { events.append(.appeared(snapshot(pid: pid, state: state))) }
        }

        previous = table
        previousTraffic = traffic
        samples += 1
        argumentCache = argumentCache.filter { table.records[$0.key]?.started == $0.value.started }
        let agents = states.map { snapshot(pid: $0.key, state: $0.value) }
            .sorted { ($0.started, $0.pid) < ($1.started, $1.pid) }
        return (agents, events)
    }

    private func findAgents(in table: ProcessTable, arguments: (pid_t) -> [String]) -> [pid_t: (kind: AgentKind, nested: [pid_t])] {
        var matched: [pid_t: AgentKind] = [:]
        for record in table.records.values where catalog.needsArguments(forExecutable: record.name, path: record.path) {
            if let cached = argumentCache[record.pid], cached.started == record.started {
                if let kind = cached.kind { matched[record.pid] = kind }
                continue
            }
            let kind = catalog.match(executable: record.name, path: record.path, arguments: arguments(record.pid))
            argumentCache[record.pid] = (record.started, kind)
            if let kind { matched[record.pid] = kind }
        }
        // An agent started by another agent, or the binary behind a node
        // wrapper, is part of the outermost one.
        var result: [pid_t: (kind: AgentKind, nested: [pid_t])] = [:]
        for (pid, kind) in matched {
            if let outer = table.ancestors(of: pid).last(where: { matched[$0.pid] != nil }) {
                result[outer.pid, default: (matched[outer.pid]!, [])].nested.append(pid)
            } else if result[pid] == nil {
                result[pid] = (kind, [])
            }
        }
        return result
    }

    private func cpuDelta(_ record: ProcessRecord) -> UInt64 {
        guard let previous else { return 0 }
        if let before = previous.records[record.pid], before.started == record.started {
            return record.cpuTime &- min(before.cpuTime, record.cpuTime)
        }
        // Started since the last sample, so all of its time is new.
        return record.started >= previous.takenAt.addingTimeInterval(-1) ? record.cpuTime : 0
    }

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func percent(of nanoseconds: UInt64, over seconds: TimeInterval) -> Double {
        Double(nanoseconds) / (seconds * 1_000_000_000) * 100
    }

    private func snapshot(pid: pid_t, state: State) -> AgentSnapshot {
        AgentSnapshot(
            id: pid,
            kind: state.kind,
            directory: state.directory,
            started: state.started,
            activity: state.activity,
            cpu: average(state.ownSamples),
            traffic: average(state.trafficSamples),
            toolCPU: average(state.treeSamples),
            lastActive: state.lastActive,
            workingSince: state.workingSince,
            workedFor: state.workedFor,
            history: state.history
        )
    }
}

/// Whether an agent still holds the Mac awake: working now, or worked within
/// the grace period, so a long pause for a slow reply does not end the session.
public func holdsAwake(_ agent: AgentSnapshot, at now: Date, grace: TimeInterval) -> Bool {
    if agent.activity == .working { return true }
    guard let lastActive = agent.lastActive else { return false }
    return now.timeIntervalSince(lastActive) < grace
}
