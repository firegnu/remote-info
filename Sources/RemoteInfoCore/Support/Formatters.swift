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
