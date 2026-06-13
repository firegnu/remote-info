import Foundation

public enum RemoteInfoFormatters {
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: value)
    }

    public static func latency(_ value: TimeInterval) -> String {
        "\(Int((value * 1_000).rounded())) ms"
    }

    public static func uptime(_ value: Int) -> String {
        let days = value / 86_400
        let hours = (value % 86_400) / 3_600

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        return "\(hours)h"
    }
}
