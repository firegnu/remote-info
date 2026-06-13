import Foundation

public struct HostTelemetry: Equatable, Sendable {
    public let collectedAt: Date
    public let latencySeconds: TimeInterval
    public let kernelRelease: String
    public let uptimeSeconds: Int
    public let load1: Double
    public let load5: Double
    public let load15: Double
    public let cpuUsagePercent: Double
    public let memoryUsedBytes: Int64
    public let memoryTotalBytes: Int64
    public let rootUsedBytes: Int64
    public let rootTotalBytes: Int64
    public let gpus: [GPUTelemetry]

    public init(
        collectedAt: Date,
        latencySeconds: TimeInterval,
        kernelRelease: String,
        uptimeSeconds: Int,
        load1: Double,
        load5: Double,
        load15: Double,
        cpuUsagePercent: Double,
        memoryUsedBytes: Int64,
        memoryTotalBytes: Int64,
        rootUsedBytes: Int64,
        rootTotalBytes: Int64,
        gpus: [GPUTelemetry] = []
    ) {
        self.collectedAt = collectedAt
        self.latencySeconds = latencySeconds
        self.kernelRelease = kernelRelease
        self.uptimeSeconds = uptimeSeconds
        self.load1 = load1
        self.load5 = load5
        self.load15 = load15
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.rootUsedBytes = rootUsedBytes
        self.rootTotalBytes = rootTotalBytes
        self.gpus = gpus
    }

    public var memoryUsagePercent: Double {
        guard memoryTotalBytes > 0 else {
            return 0
        }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes) * 100
    }

    public var rootUsagePercent: Double {
        guard rootTotalBytes > 0 else {
            return 0
        }
        return Double(rootUsedBytes) / Double(rootTotalBytes) * 100
    }
}
