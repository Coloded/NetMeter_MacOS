import Foundation
import Darwin

final class DiagnosticCenter {
    static let shared = DiagnosticCenter()
    func record(_ category: String, _ event: String, detail: String = "") {}
}

@main
struct BoundedCommandTests {
    static func require(_ value: Bool, _ message: String) {
        guard value else { fputs("FAIL: \(message)\n", stderr); exit(1) }
        print("PASS: \(message)")
    }
    static func main() throws {
        require(BoundedCommand.run("/bin/echo", ["netmeter fixture"], timeout: 1) == "netmeter fixture\n", "successful stdout is returned")
        require(BoundedCommand.run("/usr/bin/false", [], timeout: 1) == nil, "nonzero exit is unavailable")
        require(BoundedCommand.run("/definitely/not/a/netmeter/executable", [], timeout: 1) == nil, "missing executable is unavailable")
        let large = BoundedCommand.run("/usr/bin/head", ["-c", "131072", "/dev/zero"], timeout: 2)
        require(large?.utf8.count == 131072, "stdout larger than pipe capacity does not deadlock")
        let start = ProcessInfo.processInfo.systemUptime
        require(BoundedCommand.run("/bin/sleep", ["20"], timeout: 0.1) == nil, "timed out command is unavailable")
        require(ProcessInfo.processInfo.systemUptime - start < 2, "timeout is bounded")

        let streamingStart = ProcessInfo.processInfo.systemUptime
        require(BoundedCommand.run("/usr/bin/yes", ["netmeter bounded fixture"], timeout: 0.1) == nil, "continuous stdout is bounded and rejected")
        require(ProcessInfo.processInfo.systemUptime - streamingStart < 2, "continuous stdout cannot starve deadline/output cap")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("netmeter-command-qa-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pidfile = directory.appendingPathComponent("child.pid")
        let quoted = "'" + pidfile.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let launch = "/bin/sleep 30 & echo $! > " + quoted + "; exit 0"
        let descendantStart = ProcessInfo.processInfo.systemUptime
        _ = BoundedCommand.run("/bin/sh", ["-c", launch], timeout: 0.2)
        let elapsed = ProcessInfo.processInfo.systemUptime - descendantStart
        let pidString = try String(contentsOf: pidfile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = Int32(pidString), pid > 1 else { fatalError("Fixture child PID unavailable") }
        let childAlive = kill(pid, 0) == 0
        // Always clean up our own fixture, including on a regression failure.
        if childAlive { kill(pid, SIGKILL) }
        require(elapsed < 2, "descendant holding stdout cannot block the caller")
        require(!childAlive, "descendant holding stdout is terminated rather than left behind")
    }
}
