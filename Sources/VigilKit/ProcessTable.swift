import Darwin
import Foundation

/// One process as seen in a single sample of the process table.
public struct ProcessRecord: Sendable, Hashable {
    public let pid: pid_t
    public let parent: pid_t
    public let name: String
    public let path: String
    /// Total user and system CPU time in nanoseconds since the process started.
    public let cpuTime: UInt64
    public let started: Date

    public init(pid: pid_t, parent: pid_t, name: String, path: String, cpuTime: UInt64, started: Date) {
        self.pid = pid
        self.parent = parent
        self.name = name
        self.path = path
        self.cpuTime = cpuTime
        self.started = started
    }
}

/// A snapshot of every process owned by the current user, read through libproc.
public struct ProcessTable: Sendable {
    public let records: [pid_t: ProcessRecord]
    public let takenAt: Date
    private let children: [pid_t: [pid_t]]

    public init(records: [ProcessRecord], takenAt: Date = Date()) {
        var byPID: [pid_t: ProcessRecord] = [:]
        var children: [pid_t: [pid_t]] = [:]
        for record in records {
            byPID[record.pid] = record
            children[record.parent, default: []].append(record.pid)
        }
        self.records = byPID
        self.children = children
        self.takenAt = takenAt
    }

    /// Reads the live process table for the current user.
    public static func current() -> ProcessTable {
        let uid = getuid()
        let ticks = Self.nanosecondsPerTick
        var records: [ProcessRecord] = []
        for pid in allPIDs() {
            var info = proc_taskallinfo()
            let size = Int32(MemoryLayout<proc_taskallinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size) == size,
                  info.pbsd.pbi_uid == uid else { continue }
            let name = withUnsafeBytes(of: info.pbsd.pbi_name) { cString($0) }
            let comm = withUnsafeBytes(of: info.pbsd.pbi_comm) { cString($0) }
            let path = executablePath(of: pid)
            let cpu = Double(info.ptinfo.pti_total_user + info.ptinfo.pti_total_system) * ticks
            records.append(ProcessRecord(
                pid: pid,
                parent: pid_t(info.pbsd.pbi_ppid),
                name: path.isEmpty ? (name.isEmpty ? comm : name) : (path as NSString).lastPathComponent,
                path: path,
                cpuTime: UInt64(cpu),
                started: Date(timeIntervalSince1970: TimeInterval(info.pbsd.pbi_start_tvsec))
            ))
        }
        return ProcessTable(records: records)
    }

    /// Every process below `pid`, not including `pid` itself.
    public func descendants(of pid: pid_t) -> [ProcessRecord] {
        var result: [ProcessRecord] = []
        var queue = children[pid] ?? []
        var seen: Set<pid_t> = [pid]
        while let next = queue.popLast() {
            guard seen.insert(next).inserted, let record = records[next] else { continue }
            result.append(record)
            queue.append(contentsOf: children[next] ?? [])
        }
        return result
    }

    /// The chain of parents above `pid`, nearest first.
    public func ancestors(of pid: pid_t) -> [ProcessRecord] {
        var result: [ProcessRecord] = []
        var current = records[pid]?.parent ?? 0
        var seen: Set<pid_t> = [pid]
        while current > 1, seen.insert(current).inserted, let record = records[current] {
            result.append(record)
            current = record.parent
        }
        return result
    }

    // MARK: - libproc

    private static func allPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 128)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        return pids.prefix(Int(max(count, 0))).filter { $0 > 0 }
    }

    private static func executablePath(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }

    /// Task CPU times are reported in Mach absolute time units, which are not
    /// nanoseconds on Apple silicon.
    private static let nanosecondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }()

    /// The arguments a process was started with, read with `KERN_PROCARGS2`.
    public static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }
        return parseProcArgs(Array(buffer.prefix(size)))
    }

    /// Splits a `KERN_PROCARGS2` buffer: a 32 bit argument count, the executable
    /// path, padding, then the arguments, each ending in a zero byte.
    public static func parseProcArgs(_ bytes: [UInt8]) -> [String] {
        guard bytes.count > 4 else { return [] }
        let argc = Int(bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        var index = 4
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        while index < bytes.count, bytes[index] == 0 { index += 1 }
        var arguments: [String] = []
        while arguments.count < argc, index < bytes.count {
            let start = index
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            arguments.append(String(decoding: bytes[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments
    }

    /// The working directory of a process, where an agent was started.
    public static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { cString($0) }
        return path.isEmpty ? nil : path
    }
}

private func cString(_ raw: UnsafeRawBufferPointer) -> String {
    let bytes = raw.bindMemory(to: UInt8.self)
    let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
    return String(decoding: bytes[..<end], as: UTF8.self)
}
