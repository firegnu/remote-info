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
            let lowercaseMessage = message.lowercased()
            if lowercaseMessage.contains("permission denied") {
                return "SSH authentication failed. Check your SSH key, ssh-agent, and BatchMode access."
            }
            if lowercaseMessage.contains("could not resolve hostname")
                || lowercaseMessage.contains("name or service not known")
                || lowercaseMessage.contains("nodename nor servname") {
                return "SSH host could not be resolved. Check the host alias in ~/.ssh/config."
            }
            if lowercaseMessage.contains("timed out") {
                return "SSH connection timed out. Check network reachability, firewall rules, or VPN state."
            }
            if lowercaseMessage.contains("connection refused") {
                return "SSH connection was refused. Check that sshd is running and reachable on the target."
            }
            if message.isEmpty {
                return "SSH command failed with exit code \(exitCode)."
            }
            return "SSH command failed with exit code \(exitCode): \(message)"
        case .parserFailed(let message):
            return "Failed to parse telemetry output: \(message)"
        }
    }
}
