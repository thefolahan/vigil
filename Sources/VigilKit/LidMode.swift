import Foundation

/// Keeps a MacBook running with the lid closed.
///
/// macOS sleeps when the lid closes, whatever power assertions are held,
/// unless `pmset disablesleep` is on, and that needs root. One time setup
/// installs a sudoers rule that lets the signed in user run exactly two
/// commands without a password, `pmset -a disablesleep 1` and
/// `pmset -a disablesleep 0`, and a guard agent that turns sleep back on if
/// Vigil quits or crashes while it was off.
public enum LidMode {
    public static let sudoersPath = "/etc/sudoers.d/vigil"
    public static let guardLabel = "com.thefolahan.vigil.guard"
    static let pmset = "/usr/bin/pmset"
    static let sudo = "/usr/bin/sudo"

    public static var markerURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Vigil/lid-mode-on")
    }

    public static var guardPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(guardLabel).plist")
    }

    public enum Failure: Error, LocalizedError {
        case unsafeUserName(String)
        case command(String)

        public var errorDescription: String? {
            switch self {
            case .unsafeUserName(let name): return "The user name \(name) cannot be written into a sudoers rule safely."
            case .command(let output): return output.isEmpty ? "The power setting could not be changed." : output
            }
        }
    }

    // MARK: - Setup

    /// The sudoers line for `user`. Only plain account names are accepted, so
    /// nothing in the name can widen the rule.
    public static func sudoersRule(for user: String) throws -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._")
        guard !user.isEmpty, user.count <= 64, user.first != ".",
              user.unicodeScalars.allSatisfy(allowed.contains) else {
            throw Failure.unsafeUserName(user)
        }
        return "\(user) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 1, \(pmset) -a disablesleep 0"
    }

    /// A shell script to run as root that checks the rule with visudo before
    /// moving it into place, so a bad file can never lock sudo.
    public static func installScript(for user: String) throws -> String {
        let rule = try sudoersRule(for: user)
        return """
        set -e
        f=$(/usr/bin/mktemp /tmp/vigil.XXXXXX)
        /usr/bin/printf '%s\\n' '\(rule)' > "$f"
        /usr/sbin/visudo -cqf "$f"
        /usr/sbin/chown root:wheel "$f"
        /bin/chmod 0440 "$f"
        /bin/mv -f "$f" \(sudoersPath)
        """
    }

    public static let uninstallScript = """
    \(pmset) -a disablesleep 0
    /bin/rm -f \(sudoersPath)
    """

    /// Whether Vigil's sudoers rule is in place and works without a password.
    /// The file is checked as well, because `sudo -l` also succeeds through
    /// any other rule that needs no password.
    public static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
            && run(sudo, ["-n", "-l", pmset, "-a", "disablesleep", "0"]).status == 0
    }

    // MARK: - Switching

    /// Whether sleep is currently disabled system wide.
    public static func sleepDisabled() -> Bool {
        parseSleepDisabled(run(pmset, ["-g"]).output)
    }

    public static func parseSleepDisabled(_ output: String) -> Bool {
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if fields.first == "SleepDisabled" { return fields.dropFirst().first == "1" }
        }
        return false
    }

    public static func setSleepDisabled(_ disabled: Bool) throws {
        if disabled {
            try FileManager.default.createDirectory(at: markerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: markerURL.path, contents: Data())
        }
        let result = run(sudo, ["-n", pmset, "-a", "disablesleep", disabled ? "1" : "0"])
        guard result.status == 0 else { throw Failure.command(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if !disabled { try? FileManager.default.removeItem(at: markerURL) }
    }

    /// Puts the Mac to sleep now. Needs no privileges.
    public static func sleepNow() {
        _ = run(pmset, ["sleepnow"])
    }

    // MARK: - Guard agent

    /// A launch agent that runs every 30 seconds and at login. If Vigil turned
    /// sleep off and is no longer running, it turns sleep back on.
    public static func guardPlist() -> Data {
        let script = """
        if [ -f "\(markerURL.path)" ] && ! /usr/bin/pgrep -qx Vigil; then \
        \(sudo) -n \(pmset) -a disablesleep 0 && /bin/rm -f "\(markerURL.path)"; fi
        """
        let plist: [String: Any] = [
            "Label": guardLabel,
            "ProgramArguments": ["/bin/sh", "-c", script],
            "StartInterval": 30,
            "RunAtLoad": true,
            "ProcessType": "Background"
        ]
        return (try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)) ?? Data()
    }

    public static func installGuard() throws {
        let url = guardPlistURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = guardPlist()
        if (try? Data(contentsOf: url)) == data, guardLoaded() { return }
        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(guardLabel)"])
        try data.write(to: url)
        _ = run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", url.path])
    }

    public static func removeGuard() {
        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(guardLabel)"])
        try? FileManager.default.removeItem(at: guardPlistURL)
    }

    public static func guardLoaded() -> Bool {
        run("/bin/launchctl", ["print", "gui/\(getuid())/\(guardLabel)"]).status == 0
    }

    // MARK: -

    @discardableResult
    static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
