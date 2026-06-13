import Foundation

public enum RemoteInfoFormatters {
    public static func percent(_ value: Double) -> String {
        guard let roundedValue = roundedInt(value) else {
            return "--"
        }

        return "\(roundedValue)%"
    }

    public static func cpuUsage(_ value: Double, coreCount: Int) -> String {
        let usageText: String
        if value.isFinite, abs(value) < 10 {
            usageText = String(format: "%.2f%%", value)
        } else {
            usageText = percent(value)
        }

        guard coreCount > 0 else {
            return usageText
        }
        return "\(usageText) / \(coreCount) cores"
    }

    public static func processCPUUsage(_ value: Double) -> String {
        if value.isFinite, abs(value) < 10 {
            return String(format: "%.2f%%", value)
        }
        return percent(value)
    }

    public static func processMemoryUsage(_ value: Double) -> String {
        if value.isFinite, abs(value) < 10 {
            return String(format: "%.1f%%", value)
        }
        return percent(value)
    }

    public static func loadAverage(_ value: Double, coreCount: Int) -> String {
        let loadText: String
        if value.isFinite {
            loadText = String(format: "%.2f", value)
        } else {
            loadText = "--"
        }

        guard coreCount > 0 else {
            return loadText
        }
        return "\(loadText) / \(coreCount) cores"
    }

    public static func memoryUsage(_ value: Double, totalBytes: Int64) -> String {
        let usageText = percent(value)

        guard totalBytes > 0 else {
            return usageText
        }
        return "\(usageText) / \(bytes(totalBytes))"
    }

    public static func diskUsage(_ value: Double, totalBytes: Int64) -> String {
        memoryUsage(value, totalBytes: totalBytes)
    }

    public static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: value)
    }

    public static func bytesPerSecond(_ value: Int64) -> String {
        "\(bytes(value))/s"
    }

    public static func networkTraffic(
        receiveBytesPerSecond: Int64,
        transmitBytesPerSecond: Int64
    ) -> String {
        "↓ \(bytesPerSecond(receiveBytesPerSecond))  ↑ \(bytesPerSecond(transmitBytesPerSecond))"
    }

    public static func networkLocation(
        countryCode: String,
        region: String,
        city: String
    ) -> String {
        let place = preferredNetworkPlace(region: region, city: city)
        guard !place.isEmpty else {
            return "--"
        }

        let flag = flagEmoji(countryCode: countryCode)
        if flag.isEmpty {
            return place
        }
        return "\(flag) \(place)"
    }

    public static func networkIdentity(
        interfaceName: String,
        publicIPAddress: String,
        countryCode: String,
        region: String,
        city: String
    ) -> String {
        [
            networkInterfaceLabel(interfaceName),
            networkIPAddressLabel(publicIPAddress),
            networkLocationLabel(countryCode: countryCode, region: region, city: city)
        ].joined(separator: " · ")
    }

    public static func networkInterfaceLabel(_ interfaceName: String) -> String {
        let trimmedInterfaceName = interfaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedInterfaceName.isEmpty ? "--" : trimmedInterfaceName
    }

    public static func networkIPAddressLabel(_ publicIPAddress: String) -> String {
        let trimmedIPAddress = publicIPAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return "IP \(trimmedIPAddress.isEmpty ? "--" : trimmedIPAddress)"
    }

    public static func networkLocationLabel(
        countryCode: String,
        region: String,
        city: String
    ) -> String {
        let location = networkLocation(countryCode: countryCode, region: region, city: city)
        return location == "--" ? "LOC --" : location
    }

    public static func mebibytesAsGibibytes(_ value: Int64) -> String {
        let gibibytes = Double(value) / 1_024
        guard gibibytes.isFinite else {
            return "--"
        }
        return String(format: "%.1f GB", gibibytes)
    }

    public static func latency(_ value: TimeInterval) -> String {
        guard let milliseconds = roundedInt(value * 1_000) else {
            return "--"
        }

        return "\(milliseconds) ms"
    }

    public static func uptime(_ value: Int) -> String {
        let days = value / 86_400
        let hours = (value % 86_400) / 3_600

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        return "\(hours)h"
    }

    public static func age(since date: Date, now: Date = Date()) -> String {
        let ageSeconds = now.timeIntervalSince(date)
        guard let seconds = roundedInt(ageSeconds), seconds >= 0 else {
            return "--"
        }

        if seconds < 10 {
            return "just now"
        }
        if seconds < 60 {
            return "\(seconds)s ago"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }

        return "\(minutes / 60)h ago"
    }

    public static func watts(_ value: Double) -> String {
        guard let watts = roundedInt(value) else {
            return "--"
        }
        return "\(watts) W"
    }

    public static func gpuPower(_ draw: Double, limit: Double) -> String {
        guard let drawWatts = roundedInt(draw),
              let limitWatts = roundedInt(limit) else {
            return "--"
        }
        return "\(drawWatts)/\(limitWatts) W"
    }

    public static func celsius(_ value: Double) -> String {
        guard let celsius = roundedInt(value) else {
            return "--"
        }
        return "\(celsius) C"
    }

    public static func megahertzAsGigahertz(_ value: Int) -> String {
        let gigahertz = Double(value) / 1_000
        guard gigahertz.isFinite else {
            return "--"
        }
        return String(format: "%.2f GHz", gigahertz)
    }

    private static func roundedInt(_ value: Double) -> Int? {
        let roundedValue = value.rounded()
        let upperBound = Double(Int.max)

        guard roundedValue.isFinite,
              roundedValue >= Double(Int.min),
              roundedValue < upperBound else {
            return nil
        }

        return Int(roundedValue)
    }

    private static func preferredNetworkPlace(region: String, city: String) -> String {
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRegion.isEmpty {
            return trimmedRegion
        }
        return city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func flagEmoji(countryCode: String) -> String {
        let scalars = countryCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .unicodeScalars

        guard scalars.count == 2 else {
            return ""
        }

        let regionalIndicatorBase: UInt32 = 127_397
        let flagScalars = scalars.compactMap { scalar -> UnicodeScalar? in
            guard scalar.value >= 65, scalar.value <= 90 else {
                return nil
            }
            return UnicodeScalar(regionalIndicatorBase + scalar.value)
        }

        guard flagScalars.count == 2 else {
            return ""
        }
        return String(String.UnicodeScalarView(flagScalars))
    }
}
