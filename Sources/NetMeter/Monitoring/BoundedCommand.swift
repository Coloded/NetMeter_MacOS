import Foundation
import Darwin

enum BoundedCommand {
    static func run(_ executable: String, _ arguments: [String], timeout: Double = 2) -> String? {
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else { return nil }
        let readFD = descriptors[0], writeFD = descriptors[1]
        defer { close(readFD) }
        _ = fcntl(readFD, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeFD, F_SETFD, FD_CLOEXEC)
        _ = fcntl(readFD, F_SETFL, O_NONBLOCK)
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawn_file_actions_adddup2(&actions, writeFD, STDOUT_FILENO)
        posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addclose(&actions, readFD)
        posix_spawn_file_actions_addclose(&actions, writeFD)
        // An isolated process group lets the deadline terminate descendants too,
        // including a child retaining stdout after its parent has already exited.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let environment = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; environment.forEach { free($0) } }
        var pid: pid_t = 0
        let launched = argv.withUnsafeBufferPointer { args in environment.withUnsafeBufferPointer { env in
            posix_spawn(&pid, executable, &actions, &attributes, UnsafeMutablePointer(mutating: args.baseAddress!), UnsafeMutablePointer(mutating: env.baseAddress!))
        } }
        close(writeFD)
        let name = URL(fileURLWithPath: executable).lastPathComponent
        guard launched == 0 else { DiagnosticCenter.shared.record("command", "launch_failed", detail: name); return nil }
        var output = Data(), bytes = [UInt8](repeating: 0, count: 16384)
        var status: Int32 = 0, reaped = false, eof = false
        let deadline = ProcessInfo.processInfo.systemUptime + max(timeout, 0.01)
        while true {
            while ProcessInfo.processInfo.systemUptime < deadline && output.count <= 4 * 1024 * 1024 {
                let count = read(readFD, &bytes, bytes.count)
                if count > 0 { output.append(contentsOf: bytes.prefix(count)) }
                else { if count == 0 { eof = true }; break }
            }
            if !reaped { reaped = waitpid(pid, &status, WNOHANG) == pid }
            if reaped && eof {
                guard status == 0 else { DiagnosticCenter.shared.record("command", "failed", detail: name); return nil }
                return String(data: output, encoding: .utf8)
            }
            if ProcessInfo.processInfo.systemUptime >= deadline || output.count > 4 * 1024 * 1024 {
                kill(-pid, SIGTERM)
                usleep(50_000)
                kill(-pid, SIGKILL)
                if !reaped { _ = waitpid(pid, &status, 0) }
                DiagnosticCenter.shared.record("command", "timeout", detail: name)
                return nil
            }
            usleep(5_000)
        }
    }
}
