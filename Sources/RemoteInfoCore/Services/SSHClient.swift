import Foundation

public struct SSHResult: Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let elapsedSeconds: TimeInterval

    public init(stdout: String, stderr: String, exitCode: Int32, elapsedSeconds: TimeInterval) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.elapsedSeconds = elapsedSeconds
    }
}

public protocol SSHRunning: Sendable {
    func run(host: String, script: String, timeoutSeconds: TimeInterval) async throws -> SSHResult
}

public struct SSHClient: SSHRunning {
    public init() {}

    public func run(host: String, script: String, timeoutSeconds: TimeInterval) async throws -> SSHResult {
        try await Task.detached {
            try runSSHProcess(host: host, script: script, timeoutSeconds: timeoutSeconds)
        }.value
    }
}

private func runSSHProcess(host: String, script: String, timeoutSeconds: TimeInterval) throws -> SSHResult {
    let process = Process()
    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let startedAt = Date()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
    process.arguments = [
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=\(Int(timeoutSeconds))",
        "-o", "StrictHostKeyChecking=accept-new",
        host,
        "sh", "-s"
    ]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()

    if let scriptData = script.data(using: .utf8) {
        stdinPipe.fileHandleForWriting.write(scriptData)
    }
    stdinPipe.fileHandleForWriting.closeFile()

    let waitTimeout = max(0, timeoutSeconds) + 2
    let deadline = Date().addingTimeInterval(waitTimeout)
    while process.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.05)
    }

    if process.isRunning {
        process.terminate()
        process.waitUntilExit()
    }

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let elapsedSeconds = Date().timeIntervalSince(startedAt)

    return SSHResult(
        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
        stderr: String(data: stderrData, encoding: .utf8) ?? "",
        exitCode: process.terminationStatus,
        elapsedSeconds: elapsedSeconds
    )
}
