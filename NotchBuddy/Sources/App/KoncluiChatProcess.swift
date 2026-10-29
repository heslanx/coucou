import Foundation

// Koncluí: runs the official CLIs (claude, codex) and `security` as subprocesses, off the main
// thread, with a timeout, and ends the process when the consumer stops listening (the chat closed,
// a new conversation, the app quitting). Foundation only. GitHub build only: the App Store build is
// sandboxed and cannot start them.
#if !APPSTORE

enum KoncluiProcess {

    enum Event: Sendable {
        case line(String)
        /// The process could not start (missing binary, no permission); the last event.
        case failedToStart(String)
        /// The last event of a process that ran. `stderr` is the tail only.
        case exit(code: Int32, stderr: String, timedOut: Bool)
    }

    struct Output: Sendable {
        var stdout: String
        var stderr: String
        var exitCode: Int32
        var timedOut: Bool
    }

    /// stdout split into lines as it arrives. Cancelling the consuming task terminates the process.
    static func stream(_ executable: String, _ arguments: [String], environment: [String: String]? = nil,
                       directory: URL? = nil, input: Data? = nil,
                       timeout: TimeInterval) -> AsyncStream<Event> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let child = Child()
            let process = child.process
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let environment { process.environment = environment }
            if let directory { process.currentDirectoryURL = directory }
            let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr

            let buffers = Buffers()
            let eof = DispatchGroup()
            let exited = DispatchGroup()
            eof.enter(); eof.enter(); exited.enter()

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    for line in buffers.flushStdout() { continuation.yield(.line(line)) }
                    eof.leave()
                } else {
                    for line in buffers.appendStdout(data) { continuation.yield(.line(line)) }
                }
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    eof.leave()
                } else {
                    buffers.appendStderr(data)
                }
            }
            process.terminationHandler = { _ in exited.leave() }

            do {
                try process.run()
            } catch {
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                continuation.yield(.failedToStart(error.localizedDescription))
                continuation.finish()
                return
            }
            Registry.add(child)

            // The prompt goes in through stdin (never argv: it stays out of `ps` and has no length limit).
            let writer = stdin.fileHandleForWriting
            DispatchQueue.global().async {
                if let input { try? writer.write(contentsOf: input) }
                try? writer.close()
            }

            let timer = DispatchWorkItem {
                guard child.process.isRunning else { return }
                buffers.markTimedOut()
                stop(child)
            }
            child.setTimer(timer)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)

            // The process is gone; a grandchild holding the pipes open must not hold the chat up.
            DispatchQueue.global().async {
                exited.wait()
                child.cancelTimer()
                Registry.remove(child)
                _ = eof.wait(timeout: .now() + 1.5)
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                for line in buffers.flushStdout() { continuation.yield(.line(line)) }
                continuation.yield(.exit(code: child.process.terminationStatus, stderr: buffers.stderrTail(),
                                         timedOut: buffers.timedOut))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                child.cancelTimer()
                if child.process.isRunning { stop(child) }
            }
        }
    }

    /// Runs to the end and returns what it printed; nil when it could not start.
    static func capture(_ executable: String, _ arguments: [String], environment: [String: String]? = nil,
                        directory: URL? = nil, input: Data? = nil, timeout: TimeInterval) async -> Output? {
        var lines: [String] = []
        for await event in stream(executable, arguments, environment: environment, directory: directory,
                                  input: input, timeout: timeout) {
            switch event {
            case .line(let line):
                lines.append(line)
            case .failedToStart:
                return nil
            case .exit(let code, let stderr, let timedOut):
                return Output(stdout: lines.joined(separator: "\n"), stderr: stderr, exitCode: code, timedOut: timedOut)
            }
        }
        return nil
    }

    /// Ends every process still running: the app is quitting.
    static func terminateAll() {
        Registry.all().forEach(stop)
    }

    /// SIGTERM, then SIGKILL two seconds later if it ignored it.
    private static func stop(_ child: Child) {
        child.process.terminate()
        let pid = child.process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if child.process.isRunning { kill(pid, SIGKILL) }
        }
    }

    /// `Process` is not Sendable; every use here goes through these few thread-safe calls.
    private final class Child: @unchecked Sendable {
        let process = Process()
        private let lock = NSLock()
        private var timer: DispatchWorkItem?

        func setTimer(_ item: DispatchWorkItem) { lock.withLock { timer = item } }
        func cancelTimer() { lock.withLock { timer?.cancel(); timer = nil } }
    }

    // MARK: Bookkeeping

    private final class Buffers: @unchecked Sendable {
        private let lock = NSLock()
        private var pending = Data()
        private var errors = Data()
        private var expired = false

        func appendStdout(_ data: Data) -> [String] {
            lock.withLock {
                pending.append(data)
                var lines: [String] = []
                while let newline = pending.firstIndex(of: 0x0A) {
                    lines.append(String(decoding: pending[pending.startIndex..<newline], as: UTF8.self))
                    pending.removeSubrange(pending.startIndex...newline)
                }
                return lines
            }
        }

        func flushStdout() -> [String] {
            lock.withLock {
                defer { pending.removeAll() }
                return pending.isEmpty ? [] : [String(decoding: pending, as: UTF8.self)]
            }
        }

        func appendStderr(_ data: Data) {
            lock.withLock {
                errors.append(data)
                if errors.count > 8192 { errors = errors.suffix(4096) }
            }
        }

        func stderrTail() -> String {
            lock.withLock { String(decoding: errors.suffix(2048), as: UTF8.self) }
        }

        func markTimedOut() { lock.withLock { expired = true } }
        var timedOut: Bool { lock.withLock { expired } }
    }

    private enum Registry {
        nonisolated(unsafe) private static var running: [ObjectIdentifier: Child] = [:]
        private static let lock = NSLock()

        static func add(_ child: Child) { lock.withLock { running[ObjectIdentifier(child)] = child } }
        static func remove(_ child: Child) { lock.withLock { running[ObjectIdentifier(child)] = nil } }
        static func all() -> [Child] { lock.withLock { Array(running.values) } }
    }
}

#endif
