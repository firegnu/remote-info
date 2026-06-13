import Foundation

public struct ProcessTelemetry: Equatable, Identifiable, Sendable {
    public let pid: Int
    public let command: String
    public let cpuPercent: Double
    public let memoryPercent: Double

    public var id: Int {
        pid
    }

    public init(
        pid: Int,
        command: String,
        cpuPercent: Double,
        memoryPercent: Double
    ) {
        self.pid = pid
        self.command = command
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
    }
}
