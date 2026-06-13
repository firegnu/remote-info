import Foundation

public enum RemoteInfoFormatters {
    public static func percent(_ value: Double) -> String {
        guard let roundedValue = roundedInt(value) else {
            return "--"
        }

        return "\(roundedValue)%"
    }

    public static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: value)
    }

    public static func bytesPerSecond(_ value: Int64) -> String {
        "\(bytes(value))/s"
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

    public static func watts(_ value: Double) -> String {
        guard let watts = roundedInt(value) else {
            return "--"
        }
        return "\(watts) W"
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
}
