import Foundation

/// A coding agent Vigil knows how to recognise in the process table.
public struct AgentKind: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let name: String
    /// Executable file names that are this agent when run directly.
    public let executables: [String]
    /// Text in the arguments of an interpreter (node, bun, python) that marks
    /// a script as this agent, such as its package name.
    public let markers: [String]
    /// Text in the executable path, for agents installed as versioned
    /// binaries whose file name is the version, such as Claude Code's
    /// `~/.local/share/claude/versions/2.1.296`.
    public let pathMarkers: [String]
    /// Text in the arguments that marks a helper rather than an agent session,
    /// such as the native messaging host a browser extension starts.
    public let exclusions: [String]

    public init(id: String, name: String, executables: [String], markers: [String] = [],
                pathMarkers: [String] = [], exclusions: [String] = []) {
        self.id = id
        self.name = name
        self.executables = executables
        self.markers = markers
        self.pathMarkers = pathMarkers
        self.exclusions = exclusions
    }
}

public struct AgentCatalog: Sendable {
    public let kinds: [AgentKind]

    public init(kinds: [AgentKind] = AgentCatalog.builtIn) {
        self.kinds = kinds
    }

    public static let builtIn: [AgentKind] = [
        AgentKind(id: "claude", name: "Claude Code", executables: ["claude"],
                  markers: ["@anthropic-ai/claude-code/"],
                  pathMarkers: ["/claude/versions/"],
                  exclusions: ["--chrome-native-host", "mcp serve"]),
        AgentKind(id: "codex", name: "Codex", executables: ["codex"],
                  markers: ["@openai/codex/"],
                  exclusions: ["chrome-extension://", "mcp-server"]),
        AgentKind(id: "gemini", name: "Gemini CLI", executables: ["gemini"],
                  markers: ["@google/gemini-cli/"]),
        AgentKind(id: "copilot", name: "Copilot CLI", executables: ["copilot"],
                  markers: ["@github/copilot/"]),
        AgentKind(id: "cursor", name: "Cursor Agent", executables: ["cursor-agent"],
                  markers: ["cursor-agent"]),
        AgentKind(id: "opencode", name: "OpenCode", executables: ["opencode"],
                  markers: ["opencode-ai/"]),
        AgentKind(id: "amp", name: "Amp", executables: ["amp"],
                  markers: ["@sourcegraph/amp/"]),
        AgentKind(id: "aider", name: "Aider", executables: ["aider"],
                  markers: ["/bin/aider"]),
        AgentKind(id: "goose", name: "Goose", executables: ["goose"]),
        AgentKind(id: "qwen", name: "Qwen Code", executables: ["qwen"],
                  markers: ["@qwen-code/"]),
        AgentKind(id: "droid", name: "Droid", executables: ["droid"])
    ]

    /// Interpreters whose scripts are checked for markers. Arguments are only
    /// read for these and for named executables, which keeps a scan cheap.
    static let interpreters: Set<String> = ["node", "bun", "deno", "python", "python3", "ruby"]

    /// Whether the arguments of a process with this name are worth reading.
    public func needsArguments(forExecutable name: String, path: String = "") -> Bool {
        let lowered = name.lowercased()
        if Self.interpreters.contains(lowered) || lowered.hasPrefix("python3.") { return true }
        return kinds.contains { kind in
            kind.executables.contains(lowered) || kind.pathMarkers.contains { path.contains($0) }
        }
    }

    /// The agent a process is, if any.
    public func match(executable name: String, path: String = "", arguments: [String]) -> AgentKind? {
        let lowered = name.lowercased()
        let joined = arguments.joined(separator: " ")
        let isInterpreter = Self.interpreters.contains(lowered) || lowered.hasPrefix("python3.")
        for kind in kinds {
            let named = kind.executables.contains(lowered) || kind.pathMarkers.contains { path.contains($0) }
            let scripted = isInterpreter && kind.markers.contains { joined.contains($0) }
            guard named || scripted else { continue }
            if kind.exclusions.contains(where: { joined.contains($0) }) { continue }
            return kind
        }
        return nil
    }
}
