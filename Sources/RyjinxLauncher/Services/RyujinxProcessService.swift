import Foundation
import Darwin

final class RyujinxProcessService: @unchecked Sendable {
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func launch(executableURL: URL, gamePath: URL, onOutput: @Sendable @escaping (ConsoleLine) -> Void, onTermination: @Sendable @escaping (Int32) -> Void) throws {
        guard process == nil || process?.isRunning == false else {
            return
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [gamePath.path]
        process.qualityOfService = .userInteractive

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                onOutput(ConsoleLine(timestamp: Date(), text: text, stream: .stdout))
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                onOutput(ConsoleLine(timestamp: Date(), text: text, stream: .stderr))
            }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                onTermination(proc.terminationStatus)
            }
            self?.cleanup()
        }

        self.process = process
        self.stdoutPipe = stdout
        self.stderrPipe = stderr

        try process.run()
        elevatePriority(for: process)
    }

    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        cleanup()
    }

    private func cleanup() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    private func elevatePriority(for process: Process) {
        let pid = process.processIdentifier
        _ = setpriority(PRIO_PROCESS, id_t(pid), -5)
    }
}
