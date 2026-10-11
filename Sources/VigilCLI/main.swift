import Darwin
import Foundation
import VigilKit

let version = "1.0.1"

let usage = """
vigil \(version): keeps your Mac awake while your coding agents work.

Usage:
  vigil status [--json]          Show every running agent and whether it is working.
  vigil wait [--grace SECONDS]   Block until no agent has worked for SECONDS (default 60).
  vigil watch                    Print a line whenever an agent starts or stops working.
  vigil run COMMAND [ARGS...]    Keep the Mac awake until COMMAND exits.
  vigil agents                   List the agents Vigil recognises.

The menu bar app does all of this on its own, and can keep running with the lid closed.
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("vigil: \(message)\n".utf8))
    exit(2)
}

/// Two samples a short time apart, which is enough to tell working from idle.
func sample(_ tracker: AgentTracker, gap: TimeInterval = 2) -> [AgentSnapshot] {
    _ = tracker.sample()
    Thread.sleep(forTimeInterval: gap)
    return tracker.sample().agents
}

func status(json: Bool) {
    var policy = ActivityPolicy()
    policy.window = 1
    let agents = sample(AgentTracker(policy: policy))
    if json {
        let rows: [[String: Any]] = agents.map {
            ["pid": $0.pid, "agent": $0.kind.id, "name": $0.kind.name, "directory": $0.directory ?? NSNull(),
             "state": $0.activity.rawValue, "cpu": ($0.cpu * 10).rounded() / 10, "bytesPerSecond": Int($0.traffic), "toolCPU": ($0.toolCPU * 10).rounded() / 10,
             "started": ISO8601DateFormatter().string(from: $0.started)]
        }
        let data = try! JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        return
    }
    guard !agents.isEmpty else {
        print("No agents running. Your Mac can sleep.")
        return
    }
    let working = agents.filter { $0.activity == .working }.count
    print(working > 0 ? "\(Format.count(working, "agent")) working, Mac held awake.\n" : "Every agent is idle. Your Mac can sleep.\n")
    let header = ["PID", "AGENT", "STATE", "TRAFFIC", "CPU", "TOOLS", "UP", "FOLDER"]
    let rows = agents.map {
        [String($0.pid), $0.kind.name, $0.activity == .working ? "working" : "idle", Format.rate($0.traffic), Format.cpu($0.cpu),
         Format.cpu($0.toolCPU), Format.duration(Date().timeIntervalSince($0.started)),
         ($0.directory ?? "?").replacingOccurrences(of: NSHomeDirectory(), with: "~")]
    }
    let widths = header.indices.map { column in ([header] + rows).map { $0[column].count }.max() ?? 0 }
    for row in [header] + rows {
        print(row.enumerated().map { $1.padding(toLength: widths[$0], withPad: " ", startingAt: 0) }.joined(separator: "  "))
    }
}

func wait(grace: TimeInterval) {
    let tracker = AgentTracker()
    let assertion = SleepAssertion()
    var announced = false
    while true {
        let now = Date()
        let agents = tracker.sample().agents
        let busy = agents.filter { holdsAwake($0, at: now, grace: grace) }
        if busy.isEmpty, tracker.samples >= 3 {
            assertion.release()
            print("Every agent is idle.")
            return
        }
        assertion.hold(reason: "vigil wait: \(Format.count(busy.count, "agent")) working")
        if !announced, !busy.isEmpty {
            print("Waiting for \(busy.map { "\($0.kind.name) in \($0.project)" }.joined(separator: ", ")).")
            announced = true
        }
        Thread.sleep(forTimeInterval: 5)
    }
}

func watch() {
    setvbuf(stdout, nil, _IOLBF, 0)
    let tracker = AgentTracker()
    var last: [pid_t: AgentActivity] = [:]
    let clock = DateFormatter()
    clock.dateFormat = "HH:mm:ss"
    while true {
        let (agents, events) = tracker.sample()
        let time = clock.string(from: Date())
        if tracker.samples > 1 {
            for agent in agents where last[agent.pid] != agent.activity {
                let detail = "\(Format.rate(agent.traffic)), cpu \(Format.cpu(agent.cpu)), tools \(Format.cpu(agent.toolCPU))"
                print("\(time)  \(agent.kind.name) in \(agent.project) [\(agent.pid)] \(agent.activity == .working ? "working" : "idle") (\(detail))")
            }
            for case let .settled(agent, workedFor) in events {
                print("\(time)  \(agent.kind.name) in \(agent.project) [\(agent.pid)] settled after \(Format.duration(workedFor))")
            }
            for case let .exited(agent) in events {
                print("\(time)  \(agent.kind.name) in \(agent.project) [\(agent.pid)] exited")
            }
        }
        last = Dictionary(uniqueKeysWithValues: agents.map { ($0.pid, $0.activity) })
        Thread.sleep(forTimeInterval: 5)
    }
}

func run(_ command: [String]) -> Never {
    let assertion = SleepAssertion()
    assertion.hold(reason: "vigil run: \(command.joined(separator: " "))")
    var pid: pid_t = 0
    let argv = command.map { strdup($0) } + [nil]
    let spawned = posix_spawnp(&pid, command[0], nil, nil, argv, environ)
    argv.forEach { free($0) }
    guard spawned == 0 else { fail("cannot run \(command[0]): \(String(cString: strerror(spawned)))") }
    signal(SIGINT, SIG_IGN)
    var status: Int32 = 0
    while waitpid(pid, &status, 0) == -1, errno == EINTR {}
    assertion.release()
    if status & 0x7f != 0 { exit(128 + (status & 0x7f)) }
    exit((status >> 8) & 0xff)
}

var arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "status":
    status(json: arguments.contains("--json"))
case "wait":
    var grace: TimeInterval = 60
    if let index = arguments.firstIndex(of: "--grace") {
        guard index + 1 < arguments.count, let value = TimeInterval(arguments[index + 1]), value >= 0 else {
            fail("--grace needs a number of seconds")
        }
        grace = value
    }
    wait(grace: grace)
case "watch":
    watch()
case "run":
    arguments.removeFirst()
    if arguments.first == "--" { arguments.removeFirst() }
    guard !arguments.isEmpty else { fail("run needs a command") }
    run(arguments)
case "agents":
    for kind in AgentCatalog.builtIn {
        print("\(kind.name.padding(toLength: 14, withPad: " ", startingAt: 0))\(kind.executables.joined(separator: ", "))")
    }
case "--version", "-v", "version":
    print(version)
case nil, "help", "--help", "-h":
    print(usage)
default:
    fail("unknown command \(arguments[0]). Run vigil help.")
}
