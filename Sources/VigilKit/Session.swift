import Foundation

/// One finished stretch of keeping the Mac awake, kept for the history list.
public struct SessionRecord: Codable, Identifiable, Sendable, Hashable {
    public var id = UUID()
    public var started: Date
    public var ended: Date
    /// "Claude Code in devfolahan" for each agent that worked.
    public var agents: [String]
    /// How long of it the lid was closed.
    public var lidClosed: TimeInterval
    public var endReason: String

    public init(started: Date, ended: Date, agents: [String], lidClosed: TimeInterval, endReason: String) {
        self.started = started
        self.ended = ended
        self.agents = agents
        self.lidClosed = lidClosed
        self.endReason = endReason
    }

    public var length: TimeInterval { ended.timeIntervalSince(started) }
}

public enum SessionStore {
    static let key = "sessionHistory"
    static let limit = 30

    public static func load(_ defaults: UserDefaults = .standard) -> [SessionRecord] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    public static func save(_ sessions: [SessionRecord], _ defaults: UserDefaults = .standard) {
        let trimmed = Array(sessions.prefix(limit))
        if let data = try? JSONEncoder().encode(trimmed) { defaults.set(data, forKey: key) }
    }
}
