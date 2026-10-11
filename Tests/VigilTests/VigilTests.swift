import Darwin
import XCTest
@testable import VigilKit

final class CatalogTests: XCTestCase {
    let catalog = AgentCatalog()

    func testNamedExecutables() {
        XCTAssertEqual(catalog.match(executable: "claude", arguments: ["claude"])?.id, "claude")
        XCTAssertEqual(catalog.match(executable: "codex", arguments: ["codex", "exec"])?.id, "codex")
        XCTAssertEqual(catalog.match(executable: "cursor-agent", arguments: [])?.id, "cursor")
        XCTAssertNil(catalog.match(executable: "zsh", arguments: ["-zsh"]))
    }

    func testVersionedBinaryMatchesByPath() {
        let path = "/Users/me/.local/share/claude/versions/2.1.296"
        XCTAssertTrue(catalog.needsArguments(forExecutable: "2.1.296", path: path))
        XCTAssertEqual(catalog.match(executable: "2.1.296", path: path, arguments: ["/Users/me/.local/bin/claude"])?.id, "claude")
        XCTAssertFalse(catalog.needsArguments(forExecutable: "2.1.296", path: "/opt/tool/2.1.296"))
    }

    func testScriptsRunByInterpreters() {
        let claude = ["node", "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"]
        XCTAssertEqual(catalog.match(executable: "node", arguments: claude)?.id, "claude")
        let gemini = ["node", "/opt/homebrew/lib/node_modules/@google/gemini-cli/dist/index.js"]
        XCTAssertEqual(catalog.match(executable: "node", arguments: gemini)?.id, "gemini")
        XCTAssertEqual(catalog.match(executable: "python3.12", arguments: ["python3", "/Users/me/.local/bin/aider"])?.id, "aider")
        XCTAssertNil(catalog.match(executable: "node", arguments: ["node", "server.js"]))
    }

    func testHelpersAreExcluded() {
        XCTAssertNil(catalog.match(executable: "claude", arguments: ["claude", "--chrome-native-host"]))
        XCTAssertNil(catalog.match(executable: "claude", arguments: ["claude", "mcp", "serve"]))
    }

    func testOnlyRelevantProcessesHaveTheirArgumentsRead() {
        XCTAssertTrue(catalog.needsArguments(forExecutable: "node"))
        XCTAssertTrue(catalog.needsArguments(forExecutable: "Claude"))
        XCTAssertFalse(catalog.needsArguments(forExecutable: "Safari"))
    }
}

final class TrackerTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_000_000)

    /// A fake process table where the agent is PID 100, with optional tools.
    func table(at offset: TimeInterval, agentCPU: TimeInterval, tools: [(pid: pid_t, cpu: TimeInterval, started: TimeInterval)] = []) -> ProcessTable {
        var records = [ProcessRecord(pid: 100, parent: 1, name: "claude", path: "/usr/local/bin/claude",
                                     cpuTime: UInt64(agentCPU * 1e9), started: start)]
        for tool in tools {
            records.append(ProcessRecord(pid: tool.pid, parent: 100, name: "zsh", path: "/bin/zsh",
                                         cpuTime: UInt64(tool.cpu * 1e9), started: start.addingTimeInterval(tool.started)))
        }
        return ProcessTable(records: records, takenAt: start.addingTimeInterval(offset))
    }

    func update(_ tracker: AgentTracker, _ table: ProcessTable, bytes: UInt64) -> (agents: [AgentSnapshot], events: [AgentEvent]) {
        tracker.update(with: table, traffic: [100: bytes], arguments: { _ in ["claude"] }, directory: { _ in "/Users/me/app" })
    }

    func testIdleAgentWithLowCPUIsNotWorking() {
        // An agent kept at one percent by its host, with only keep alive pings.
        let tracker = AgentTracker()
        var bytes: UInt64 = 0
        var last: AgentSnapshot?
        for step in 0..<6 {
            bytes += 75
            last = update(tracker, table(at: Double(step) * 5, agentCPU: Double(step) * 0.05), bytes: bytes).agents.first
        }
        XCTAssertEqual(last?.activity, .waiting)
        XCTAssertNil(last?.lastActive)
    }

    func testStreamingAgentIsWorking() {
        let tracker = AgentTracker()
        _ = update(tracker, table(at: 0, agentCPU: 0), bytes: 0)
        let first = update(tracker, table(at: 5, agentCPU: 0.05), bytes: 8_000).agents.first
        XCTAssertEqual(first?.activity, .waiting, "one sample of traffic could be a background sync")
        let agent = update(tracker, table(at: 10, agentCPU: 0.1), bytes: 16_000).agents.first
        XCTAssertEqual(agent?.activity, .working)
        XCTAssertEqual(agent?.traffic ?? 0, 1600, accuracy: 1)
        XCTAssertEqual(agent?.project, "app")
    }

    func testOneBurstOfTrafficIsNotWork() {
        // Idle sessions in an IDE were seen sending about 8 KB at once.
        let tracker = AgentTracker()
        var activities: [AgentActivity] = []
        for (step, bytes) in [0, 75, 8_000, 8_075, 8_150, 8_225].enumerated() {
            activities += update(tracker, table(at: Double(step) * 5, agentCPU: Double(step) * 0.05), bytes: UInt64(bytes)).agents.map(\.activity)
        }
        XCTAssertFalse(activities.contains(.working))
    }

    func testFreshToolCountsAsWorkWithoutTraffic() {
        let tracker = AgentTracker()
        _ = update(tracker, table(at: 0, agentCPU: 0), bytes: 0)
        _ = update(tracker, table(at: 5, agentCPU: 0), bytes: 5_000)
        // The model asked for a command; it now runs quietly for minutes.
        var agent: AgentSnapshot?
        for step in 2..<40 {
            agent = update(tracker, table(at: Double(step) * 5, agentCPU: 0, tools: [(200, 0.1, 7)]), bytes: 5_000).agents.first
        }
        XCTAssertEqual(agent?.activity, .working)
    }

    func testOldBackgroundToolDoesNotHoldForever() {
        var policy = ActivityPolicy()
        policy.toolWindow = 60
        let tracker = AgentTracker(policy: policy)
        _ = update(tracker, table(at: 0, agentCPU: 0), bytes: 0)
        _ = update(tracker, table(at: 5, agentCPU: 0), bytes: 5_000)
        var agent: AgentSnapshot?
        for step in 2..<30 {
            agent = update(tracker, table(at: Double(step) * 5, agentCPU: 0, tools: [(200, 0.1, 7)]), bytes: 5_000).agents.first
        }
        XCTAssertEqual(agent?.activity, .waiting)
    }

    func testBusyToolCountsAsWork() {
        let tracker = AgentTracker()
        _ = update(tracker, table(at: 0, agentCPU: 0, tools: [(300, 0, -3600)]), bytes: 0)
        let agent = update(tracker, table(at: 5, agentCPU: 0, tools: [(300, 2, -3600)]), bytes: 0).agents.first
        XCTAssertEqual(agent?.activity, .working)
        XCTAssertEqual(agent?.toolCPU ?? 0, 40, accuracy: 0.1)
    }

    func testSettledEventAfterARealRun() {
        let tracker = AgentTracker()
        var bytes: UInt64 = 0
        var events: [AgentEvent] = []
        for step in 0...20 {
            if step <= 12 { bytes += 10_000 }
            events += update(tracker, table(at: Double(step) * 5, agentCPU: 0), bytes: bytes).events
        }
        let settled = events.compactMap { event -> TimeInterval? in
            if case let .settled(_, workedFor) = event { return workedFor }
            return nil
        }
        XCTAssertEqual(settled.count, 1)
        // Traffic runs from 5 to 60 seconds. Two samples are needed to start
        // a run and the window carries it one sample past the last traffic.
        XCTAssertEqual(settled.first ?? 0, 55, accuracy: 0.1)
    }

    func testNoSettledEventForABlip() {
        let tracker = AgentTracker()
        var events: [AgentEvent] = []
        for step in 0...10 {
            events += update(tracker, table(at: Double(step) * 5, agentCPU: 0), bytes: step >= 1 ? 9_000 : 0).events
        }
        XCTAssertFalse(events.contains { if case .settled = $0 { return true } else { return false } })
    }

    func testExitedEvent() {
        let tracker = AgentTracker()
        _ = update(tracker, table(at: 0, agentCPU: 0), bytes: 0)
        let events = tracker.update(with: ProcessTable(records: [], takenAt: start.addingTimeInterval(5)), traffic: [:]).events
        XCTAssertEqual(events.count, 1)
        guard case .exited = events.first else { return XCTFail("expected an exit") }
    }

    func testNestedAgentBelongsToTheOuterOne() {
        let records = [
            ProcessRecord(pid: 100, parent: 1, name: "node", path: "/usr/bin/node", cpuTime: 0, started: start),
            ProcessRecord(pid: 101, parent: 100, name: "codex", path: "/opt/codex/codex", cpuTime: 0, started: start)
        ]
        let tracker = AgentTracker()
        let arguments: (pid_t) -> [String] = { $0 == 100 ? ["node", "/lib/node_modules/@openai/codex/bin/codex.js"] : ["codex"] }
        _ = tracker.update(with: ProcessTable(records: records, takenAt: start), traffic: [101: 0], arguments: arguments, directory: { _ in nil })
        _ = tracker.update(with: ProcessTable(records: records, takenAt: start.addingTimeInterval(5)),
                           traffic: [101: 10_000], arguments: arguments, directory: { _ in nil })
        let agents = tracker.update(with: ProcessTable(records: records, takenAt: start.addingTimeInterval(10)),
                                    traffic: [101: 20_000], arguments: arguments, directory: { _ in nil }).agents
        XCTAssertEqual(agents.map(\.pid), [100])
        XCTAssertEqual(agents.first?.activity, .working)
    }

    func testGraceKeepsAQuietAgentHolding() {
        let tracker = AgentTracker()
        _ = update(tracker, table(at: 0, agentCPU: 0), bytes: 0)
        _ = update(tracker, table(at: 5, agentCPU: 0), bytes: 9_000)
        _ = update(tracker, table(at: 10, agentCPU: 0), bytes: 18_000)
        var agent: AgentSnapshot!
        for step in 3..<6 { agent = update(tracker, table(at: Double(step) * 5, agentCPU: 0), bytes: 18_000).agents[0] }
        XCTAssertEqual(agent.activity, .waiting)
        let now = start.addingTimeInterval(25)
        XCTAssertEqual(agent.lastActive, start.addingTimeInterval(15))
        XCTAssertTrue(holdsAwake(agent, at: now, grace: 180))
        XCTAssertFalse(holdsAwake(agent, at: now.addingTimeInterval(200), grace: 180))
    }
}

final class SystemTests: XCTestCase {
    func testProcArgsParsing() {
        var bytes: [UInt8] = []
        withUnsafeBytes(of: Int32(2)) { bytes.append(contentsOf: $0) }
        bytes += Array("/usr/bin/node".utf8) + [0, 0, 0]
        bytes += Array("node".utf8) + [0] + Array("cli.js".utf8) + [0]
        bytes += Array("HOME=/Users/me".utf8) + [0]
        XCTAssertEqual(ProcessTable.parseProcArgs(bytes), ["node", "cli.js"])
    }

    func testNettopParsing() {
        let output = """
        ,bytes_in,bytes_out,
        2.1.296.49894,1138868,721454,
        Google Chrome H.812,10,20,
        syslogd.574,0,6106,
        """
        let usage = NetworkUsage.parse(output)
        XCTAssertEqual(usage[49894], 1_860_322)
        XCTAssertEqual(usage[812], 30)
        XCTAssertEqual(usage[574], 6106)
        XCTAssertEqual(usage.count, 3)
    }

    func testLiveTableSeesThisProcess() {
        let table = ProcessTable.current()
        let me = table.records[getpid()]
        XCTAssertNotNil(me)
        XCTAssertGreaterThan(me?.cpuTime ?? 0, 0)
        XCTAssertFalse(table.ancestors(of: getpid()).isEmpty)
    }

    func testSleepDisabledParsing() {
        XCTAssertTrue(LidMode.parseSleepDisabled("System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n"))
        XCTAssertFalse(LidMode.parseSleepDisabled(" SleepDisabled\t\t0\n"))
        XCTAssertFalse(LidMode.parseSleepDisabled("Currently in use:\n sleep 1\n"))
    }

    func testSudoersRuleIsNarrow() throws {
        XCTAssertEqual(try LidMode.sudoersRule(for: "folahan"),
                       "folahan ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0")
        for bad in ["", "root ALL=(ALL) ALL", "a,b", "x\ny", "../etc", "me ALL", ".hidden", "it's"] {
            XCTAssertThrowsError(try LidMode.sudoersRule(for: bad), bad)
        }
    }

    func testInstallScriptValidatesBeforeInstalling() throws {
        let script = try LidMode.installScript(for: "folahan")
        let validate = try XCTUnwrap(script.range(of: "visudo -cqf"))
        let install = try XCTUnwrap(script.range(of: "mv -f"))
        XCTAssertLessThan(validate.lowerBound, install.lowerBound)
        XCTAssertTrue(script.hasPrefix("set -e"))
    }

    func testGuardPlistRunsAtLoadAndOnAnInterval() throws {
        let plist = try PropertyListSerialization.propertyList(from: LidMode.guardPlist(), format: nil) as? [String: Any]
        XCTAssertEqual(plist?["Label"] as? String, LidMode.guardLabel)
        XCTAssertEqual(plist?["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist?["StartInterval"] as? Int, 30)
        let command = (plist?["ProgramArguments"] as? [String])?.last ?? ""
        XCTAssertTrue(command.contains("pgrep -qx Vigil"))
        XCTAssertTrue(command.contains("disablesleep 0"))
    }

    func testGuardPolicy() {
        let policy = GuardPolicy(batteryFloor: 25)
        XCTAssertNil(policy.trip(thermal: .fair, battery: BatteryState(percent: 30, onBattery: true)))
        XCTAssertEqual(policy.trip(thermal: .serious, battery: nil), .heat(.serious))
        XCTAssertEqual(policy.trip(thermal: .nominal, battery: BatteryState(percent: 20, onBattery: true)), .battery(20))
        XCTAssertNil(policy.trip(thermal: .nominal, battery: BatteryState(percent: 5, onBattery: false)))
    }

    func testFormatting() {
        XCTAssertEqual(Format.duration(42), "42s")
        XCTAssertEqual(Format.duration(125), "2m")
        XCTAssertEqual(Format.duration(3900), "1h 05m")
        XCTAssertEqual(Format.duration(90_000), "1d 01h")
        XCTAssertEqual(Format.countdown(65), "1:05")
        XCTAssertEqual(Format.countdown(3725), "1:02:05")
        XCTAssertEqual(Format.rate(15), "15 B/s")
        XCTAssertEqual(Format.rate(4200), "4.2 KB/s")
        XCTAssertEqual(Format.count(1, "agent"), "1 agent")
        XCTAssertEqual(Format.count(3, "agent"), "3 agents")
    }
}
