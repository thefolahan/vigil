import Foundation

public enum Format {
    /// A short duration such as "45s", "12m" or "2h 05m".
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return String(format: "%dh %02dm", hours, minutes % 60) }
        return String(format: "%dd %02dh", hours / 24, hours % 24)
    }

    /// A countdown such as "1:04:09" or "4:09".
    public static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600, minutes = total / 60 % 60, rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// "15 B/s", "4.2 KB/s".
    public static func rate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1000 { return "\(Int(bytesPerSecond)) B/s" }
        if bytesPerSecond < 1_000_000 { return String(format: "%.1f KB/s", bytesPerSecond / 1000) }
        return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
    }

    public static func cpu(_ percent: Double) -> String {
        percent < 10 ? String(format: "%.1f%%", percent) : String(format: "%.0f%%", percent)
    }

    /// "1 agent", "3 agents".
    public static func count(_ value: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(value) \(value == 1 ? singular : (plural ?? singular + "s"))"
    }
}
