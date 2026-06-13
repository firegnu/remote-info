import Foundation

public actor MockTelemetryCollector: TelemetryCollecting {
    public static let hosts = [
        HostConfig(id: "mock-alpha", name: "Mock Alpha", sshTarget: "mock-alpha"),
        HostConfig(id: "mock-beta", name: "Mock Beta", sshTarget: "mock-beta")
    ]

    private var sampleIndex = 0

    public init() {}

    public func collect(for host: HostConfig) async throws -> HostTelemetry {
        sampleIndex += 1

        let hostOffset = host.id == Self.hosts.last?.id ? 13 : 0
        let step = sampleIndex + hostOffset
        let phase = Double(step % 24)
        let memoryTotalBytes: Int64 = 16 * 1_024 * 1_024 * 1_024
        let rootTotalBytes: Int64 = 512 * 1_024 * 1_024 * 1_024
        let memoryUsageRatio = 0.42 + (phase.truncatingRemainder(dividingBy: 8) * 0.025)
        let rootUsageRatio = 0.58 + (Double(hostOffset) * 0.004)

        return HostTelemetry(
            collectedAt: Date(),
            latencySeconds: 0.028 + Double(step % 5) * 0.006,
            kernelRelease: "6.8.0-mock",
            uptimeSeconds: 864_000 + step * 97,
            load1: 0.35 + phase * 0.07,
            load5: 0.42 + phase * 0.04,
            load15: 0.48 + phase * 0.025,
            cpuUsagePercent: 12 + phase * 2.3,
            memoryUsedBytes: Int64(Double(memoryTotalBytes) * memoryUsageRatio),
            memoryTotalBytes: memoryTotalBytes,
            rootUsedBytes: Int64(Double(rootTotalBytes) * rootUsageRatio),
            rootTotalBytes: rootTotalBytes
        )
    }
}
