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
        let parsedOutput = try parseValues(from: output)
        let values = parsedOutput.values

        return HostTelemetry(
            collectedAt: collectedAt,
            latencySeconds: latency,
            kernelRelease: try stringValue("kernel_release", in: values),
            uptimeSeconds: try intValue("uptime_seconds", in: values),
            load1: try doubleValue("load1", in: values),
            load5: try doubleValue("load5", in: values),
            load15: try doubleValue("load15", in: values),
            cpuUsagePercent: try doubleValue("cpu_usage_percent", in: values),
            memoryUsedBytes: try int64Value("memory_used_bytes", in: values),
            memoryTotalBytes: try int64Value("memory_total_bytes", in: values),
            rootUsedBytes: try int64Value("root_used_bytes", in: values),
            rootTotalBytes: try int64Value("root_total_bytes", in: values),
            gpus: try gpuValues(from: parsedOutput.gpuPayloads)
        )
    }

    private func parseValues(from output: String) throws -> ParsedTelemetryOutput {
        var values: [String: String] = [:]
        var gpuPayloads: [String] = []

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let separatorIndex = line.firstIndex(of: "=") else {
                throw TelemetryParseError.invalidLine(line)
            }

            let key = String(line[..<separatorIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "gpu" {
                gpuPayloads.append(value)
                continue
            }
            if values[key] != nil {
                throw TelemetryParseError.duplicateKey(key)
            }
            values[key] = value
        }

        return ParsedTelemetryOutput(values: values, gpuPayloads: gpuPayloads)
    }

    private func gpuValues(from payloads: [String]) throws -> [GPUTelemetry] {
        try payloads.map(gpuValue)
    }

    private func gpuValue(from payload: String) throws -> GPUTelemetry {
        let fields = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 11 else {
            throw TelemetryParseError.invalidLine("gpu=\(payload)")
        }

        return GPUTelemetry(
            index: try intValue("gpu.index", value: fields[0]),
            name: fields[1],
            driverVersion: fields[2],
            utilizationPercent: try doubleValue("gpu.utilization_percent", value: fields[3]),
            memoryUsedMiB: try int64Value("gpu.memory_used_mib", value: fields[4]),
            memoryTotalMiB: try int64Value("gpu.memory_total_mib", value: fields[5]),
            temperatureCelsius: try doubleValue("gpu.temperature_celsius", value: fields[6]),
            powerDrawWatts: try doubleValue("gpu.power_draw_watts", value: fields[7]),
            powerLimitWatts: try doubleValue("gpu.power_limit_watts", value: fields[8]),
            fanSpeedPercent: try doubleValue("gpu.fan_speed_percent", value: fields[9]),
            graphicsClockMHz: try intValue("gpu.graphics_clock_mhz", value: fields[10])
        )
    }

    private func stringValue(_ key: String, in values: [String: String]) throws -> String {
        guard let value = values[key] else {
            throw TelemetryParseError.missingKey(key)
        }
        return value
    }

    private func intValue(_ key: String, in values: [String: String]) throws -> Int {
        let value = try stringValue(key, in: values)
        return try intValue(key, value: value)
    }

    private func intValue(_ key: String, value: String) throws -> Int {
        guard let parsedValue = Int(value) else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsedValue
    }

    private func int64Value(_ key: String, in values: [String: String]) throws -> Int64 {
        let value = try stringValue(key, in: values)
        return try int64Value(key, value: value)
    }

    private func int64Value(_ key: String, value: String) throws -> Int64 {
        guard let parsedValue = Int64(value) else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsedValue
    }

    private func doubleValue(_ key: String, in values: [String: String]) throws -> Double {
        let value = try stringValue(key, in: values)
        return try doubleValue(key, value: value)
    }

    private func doubleValue(_ key: String, value: String) throws -> Double {
        guard let parsedValue = Double(value), parsedValue.isFinite else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsedValue
    }
}

private struct ParsedTelemetryOutput {
    let values: [String: String]
    let gpuPayloads: [String]
}
