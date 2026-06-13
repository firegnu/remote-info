import Foundation

public struct GPUTelemetry: Equatable, Identifiable, Sendable {
    public let index: Int
    public let name: String
    public let driverVersion: String
    public let utilizationPercent: Double
    public let memoryUsedMiB: Int64
    public let memoryTotalMiB: Int64
    public let temperatureCelsius: Double
    public let powerDrawWatts: Double
    public let powerLimitWatts: Double
    public let fanSpeedPercent: Double
    public let graphicsClockMHz: Int

    public var id: Int {
        index
    }

    public init(
        index: Int,
        name: String,
        driverVersion: String,
        utilizationPercent: Double,
        memoryUsedMiB: Int64,
        memoryTotalMiB: Int64,
        temperatureCelsius: Double,
        powerDrawWatts: Double,
        powerLimitWatts: Double,
        fanSpeedPercent: Double,
        graphicsClockMHz: Int
    ) {
        self.index = index
        self.name = name
        self.driverVersion = driverVersion
        self.utilizationPercent = utilizationPercent
        self.memoryUsedMiB = memoryUsedMiB
        self.memoryTotalMiB = memoryTotalMiB
        self.temperatureCelsius = temperatureCelsius
        self.powerDrawWatts = powerDrawWatts
        self.powerLimitWatts = powerLimitWatts
        self.fanSpeedPercent = fanSpeedPercent
        self.graphicsClockMHz = graphicsClockMHz
    }

    public var memoryUsagePercent: Double {
        guard memoryTotalMiB > 0 else {
            return 0
        }
        return Double(memoryUsedMiB) / Double(memoryTotalMiB) * 100
    }

    public var powerUsagePercent: Double {
        guard powerLimitWatts > 0 else {
            return 0
        }
        return powerDrawWatts / powerLimitWatts * 100
    }
}
