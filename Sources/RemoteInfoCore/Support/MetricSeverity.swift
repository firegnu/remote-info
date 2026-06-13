import Foundation

public enum MetricSeverity: Equatable, Sendable {
    case normal
    case attention
    case elevated
    case critical
    case unknown

    public static func cpuUsage(_ percent: Double) -> MetricSeverity {
        threshold(percent, attention: 50, elevated: 75, critical: 90)
    }

    public static func capacityUsage(_ percent: Double) -> MetricSeverity {
        threshold(percent, attention: 70, elevated: 85, critical: 95)
    }

    public static func loadAverage(_ load: Double, coreCount: Int) -> MetricSeverity {
        guard load.isFinite, coreCount > 0 else {
            return .unknown
        }

        return threshold(load / Double(coreCount), attention: 0.5, elevated: 0.75, critical: 1)
    }

    public static func latency(_ seconds: TimeInterval) -> MetricSeverity {
        guard seconds.isFinite, seconds >= 0 else {
            return .unknown
        }

        return threshold(seconds, attention: 0.3, elevated: 0.8, critical: 2)
    }

    public static func networkOperstate(_ operstate: String) -> MetricSeverity {
        let normalized = operstate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized == "up" {
            return .normal
        }
        if normalized.isEmpty || normalized == "unknown" {
            return .unknown
        }
        return .critical
    }

    public static func networkErrors(_ count: Int64) -> MetricSeverity {
        if count < 0 {
            return .unknown
        }
        if count >= 10 {
            return .critical
        }
        if count > 0 {
            return .elevated
        }
        return .normal
    }

    public static func gpuTemperature(_ celsius: Double) -> MetricSeverity {
        threshold(celsius, attention: 75, elevated: 83, critical: 88)
    }

    public static func gpuPowerUsage(_ percent: Double) -> MetricSeverity {
        threshold(percent, attention: 90, elevated: 97, critical: 100)
    }

    public static func gpuFanSpeed(_ percent: Double) -> MetricSeverity {
        guard percent.isFinite else {
            return .unknown
        }

        if percent >= 90 {
            return .elevated
        }
        if percent >= 75 {
            return .attention
        }
        return .normal
    }

    private static func threshold(
        _ value: Double,
        attention: Double,
        elevated: Double,
        critical: Double
    ) -> MetricSeverity {
        guard value.isFinite else {
            return .unknown
        }

        if value >= critical {
            return .critical
        }
        if value >= elevated {
            return .elevated
        }
        if value >= attention {
            return .attention
        }
        return .normal
    }
}
