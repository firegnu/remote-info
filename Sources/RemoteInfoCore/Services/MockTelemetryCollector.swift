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
        let gpuUtilization = 24 + phase * 2.6
        let gpuMemoryTotalMiB: Int64 = 32_768
        let gpuMemoryUsedMiB = Int64(8_192 + phase * 740 + Double(hostOffset * 180))
        let receiveBytesPerSecond = Int64(4_200_000 + step * 480_000)
        let transmitBytesPerSecond = Int64(760_000 + step * 110_000)

        return HostTelemetry(
            collectedAt: Date(),
            latencySeconds: 0.028 + Double(step % 5) * 0.006,
            kernelRelease: "6.8.0-mock",
            uptimeSeconds: 864_000 + step * 97,
            load1: 0.35 + phase * 0.07,
            load5: 0.42 + phase * 0.04,
            load15: 0.48 + phase * 0.025,
            cpuUsagePercent: 12 + phase * 2.3,
            cpuCoreCount: 32,
            memoryUsedBytes: Int64(Double(memoryTotalBytes) * memoryUsageRatio),
            memoryTotalBytes: memoryTotalBytes,
            rootUsedBytes: Int64(Double(rootTotalBytes) * rootUsageRatio),
            rootTotalBytes: rootTotalBytes,
            gpus: [
                GPUTelemetry(
                    index: 0,
                    name: "NVIDIA GeForce RTX 5090",
                    driverVersion: "575.64",
                    utilizationPercent: gpuUtilization,
                    memoryUsedMiB: gpuMemoryUsedMiB,
                    memoryTotalMiB: gpuMemoryTotalMiB,
                    temperatureCelsius: 46 + phase * 1.4,
                    powerDrawWatts: 185 + phase * 13,
                    powerLimitWatts: 575,
                    fanSpeedPercent: 32 + phase * 1.7,
                    graphicsClockMHz: 1_950 + step * 11
                )
            ],
            topProcesses: [
                ProcessTelemetry(
                    pid: 2_411 + hostOffset,
                    command: "python3",
                    cpuPercent: 118 + phase * 4.1,
                    memoryPercent: 12.1
                ),
                ProcessTelemetry(
                    pid: 1_830 + hostOffset,
                    command: "ollama",
                    cpuPercent: 46 + phase * 2.3,
                    memoryPercent: 8.4
                ),
                ProcessTelemetry(
                    pid: 4_208 + hostOffset,
                    command: "ffmpeg",
                    cpuPercent: 18 + phase,
                    memoryPercent: 2.6
                ),
                ProcessTelemetry(
                    pid: 4_495 + hostOffset,
                    command: "v2rayN",
                    cpuPercent: 0.3 + phase * 0.02,
                    memoryPercent: 0.6
                ),
                ProcessTelemetry(
                    pid: 4_809 + hostOffset,
                    command: "java",
                    cpuPercent: 0.1 + phase * 0.01,
                    memoryPercent: 1.3
                )
            ],
            network: NetworkTelemetry(
                interfaceName: "eth0",
                operstate: "up",
                receiveBytesPerSecond: receiveBytesPerSecond,
                transmitBytesPerSecond: transmitBytesPerSecond,
                receiveErrors: 0,
                transmitErrors: 0,
                receiveDrops: 0,
                transmitDrops: 0,
                publicIPAddress: hostOffset == 0 ? "203.0.113.10" : "198.51.100.23",
                publicIPCountryCode: hostOffset == 0 ? "JP" : "CN",
                publicIPRegion: hostOffset == 0 ? "Tokyo" : "Shaanxi",
                publicIPCity: hostOffset == 0 ? "Tokyo" : "Xi'an"
            )
        )
    }
}
