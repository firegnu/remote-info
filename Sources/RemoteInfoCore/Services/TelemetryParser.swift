import Foundation

public enum TelemetryParseError: Error, Equatable, LocalizedError {
    case missingKey(String)
    case invalidLine(String)
    case duplicateKey(String)
    case invalidNumber(key: String, value: String)

    public var errorDescription: String? {
        switch self {
        case .missingKey(let key):
            "Telemetry output is missing required key '\(key)'."
        case .invalidLine(let line):
            "Telemetry output contains an invalid line: '\(line)'."
        case .duplicateKey(let key):
            "Telemetry output contains duplicate key '\(key)'."
        case .invalidNumber(let key, let value):
            "Telemetry key '\(key)' has invalid numeric value '\(value)'."
        }
    }
}

public struct TelemetryParser: Sendable {
    public init() {}

    public func parse(
        _ output: String,
        collectedAt: Date,
        latency: TimeInterval
    ) throws -> HostTelemetry {
        let values = try parseValues(from: output)

        return HostTelemetry(
            collectedAt: collectedAt,
            latencySeconds: latency,
            uptimeSeconds: try intValue("uptime_seconds", in: values),
            load1: try doubleValue("load1", in: values),
            load5: try doubleValue("load5", in: values),
            load15: try doubleValue("load15", in: values),
            cpuUsagePercent: try doubleValue("cpu_usage_percent", in: values),
            memoryUsedBytes: try int64Value("memory_used_bytes", in: values),
            memoryTotalBytes: try int64Value("memory_total_bytes", in: values),
            rootUsedBytes: try int64Value("root_used_bytes", in: values),
            rootTotalBytes: try int64Value("root_total_bytes", in: values)
        )
    }

    private func parseValues(from output: String) throws -> [String: String] {
        var values: [String: String] = [:]

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let separatorIndex = line.firstIndex(of: "=") else {
                throw TelemetryParseError.invalidLine(line)
            }

            let key = String(line[..<separatorIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if values[key] != nil {
                throw TelemetryParseError.duplicateKey(key)
            }
            values[key] = value
        }

        return values
    }

    private func stringValue(_ key: String, in values: [String: String]) throws -> String {
        guard let value = values[key] else {
            throw TelemetryParseError.missingKey(key)
        }
        return value
    }

    private func intValue(_ key: String, in values: [String: String]) throws -> Int {
        let value = try stringValue(key, in: values)
        guard let parsedValue = Int(value) else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsedValue
    }

    private func int64Value(_ key: String, in values: [String: String]) throws -> Int64 {
        let value = try stringValue(key, in: values)
        guard let parsedValue = Int64(value) else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsedValue
    }

    private func doubleValue(_ key: String, in values: [String: String]) throws -> Double {
        let value = try stringValue(key, in: values)
        guard let parsedValue = Double(value), parsedValue.isFinite else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsedValue
    }
}
