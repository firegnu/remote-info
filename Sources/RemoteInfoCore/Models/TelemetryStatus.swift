import Foundation

public enum TelemetryStatus: Equatable, Sendable {
    case idle
    case loading
    case online
    case stale
    case offline(String)
}

public enum TelemetryCollectionError: Error, Equatable, LocalizedError {
    case sshFailed(exitCode: Int32, message: String)
    case parserFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sshFailed(let exitCode, let message):
            if message.isEmpty {
                return "SSH command failed with exit code \(exitCode)."
            }
            return "SSH command failed with exit code \(exitCode): \(message)"
        case .parserFailed(let message):
            return "Failed to parse telemetry output: \(message)"
        }
    }
}
