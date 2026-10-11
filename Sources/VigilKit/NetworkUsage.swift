import Darwin
import Foundation

/// Bytes each process has sent and received, read from `nettop`.
///
/// An agent talking to its model streams tokens, hundreds of bytes a second
/// or more, while an idle session only exchanges keep alive pings, about
/// fifteen bytes a second. That gap is a far better signal of work than CPU,
/// because some hosts keep an idle agent busy on the CPU.
public enum NetworkUsage {
    /// Cumulative bytes in and out for every process with a socket.
    public static func snapshot() -> [pid_t: UInt64] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-P", "-L", "1", "-x", "-n", "-J", "bytes_in,bytes_out"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return [:]
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return parse(String(decoding: data, as: UTF8.self))
    }

    /// Parses lines such as `2.1.296.49894,1138868,721454,`, where the first
    /// field is the process name and its PID joined by a dot.
    public static func parse(_ text: String) -> [pid_t: UInt64] {
        var result: [pid_t: UInt64] = [:]
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 3, let dot = fields[0].lastIndex(of: "."),
                  let pid = pid_t(fields[0][fields[0].index(after: dot)...]),
                  let received = UInt64(fields[1]), let sent = UInt64(fields[2]) else { continue }
            result[pid, default: 0] += received + sent
        }
        return result
    }
}
