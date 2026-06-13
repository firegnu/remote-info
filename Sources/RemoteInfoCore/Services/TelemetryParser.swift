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
            cpuCoreCount: try intValue("cpu_core_count", in: values),
            memoryUsedBytes: try int64Value("memory_used_bytes", in: values),
            memoryTotalBytes: try int64Value("memory_total_bytes", in: values),
            rootUsedBytes: try int64Value("root_used_bytes", in: values),
            rootTotalBytes: try int64Value("root_total_bytes", in: values),
            gpus: try gpuValues(from: parsedOutput.gpuPayloads),
            topProcesses: try processValues(from: parsedOutput.processPayloads),
            network: try networkValue(from: parsedOutput.networkPayload)
        )
    }

    private func parseValues(from output: String) throws -> ParsedTelemetryOutput {
        var values: [String: String] = [:]
        var gpuPayloads: [String] = []
        var processPayloads: [String] = []
        var networkPayload: String?

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
            if key == "process" {
                processPayloads.append(value)
                continue
            }
            if key == "network" {
                if networkPayload != nil {
                    throw TelemetryParseError.duplicateKey(key)
                }
                networkPayload = value
                continue
            }
            if values[key] != nil {
                throw TelemetryParseError.duplicateKey(key)
            }
            values[key] = value
        }

        return ParsedTelemetryOutput(
            values: values,
            gpuPayloads: gpuPayloads,
            processPayloads: processPayloads,
            networkPayload: networkPayload
        )
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

    private func processValues(from payloads: [String]) throws -> [ProcessTelemetry] {
        try payloads.map(processValue)
    }

    private func processValue(from payload: String) throws -> ProcessTelemetry {
        let fields = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 4 else {
            throw TelemetryParseError.invalidLine("process=\(payload)")
        }

        return ProcessTelemetry(
            pid: try intValue("process.pid", value: fields[0]),
            command: fields[1],
            cpuPercent: try doubleValue("process.cpu_percent", value: fields[2]),
            memoryPercent: try doubleValue("process.memory_percent", value: fields[3])
        )
    }

    private func networkValue(from payload: String?) throws -> NetworkTelemetry? {
        guard let payload else {
            return nil
        }

        let fields = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 8 || fields.count == 11 || fields.count == 12 else {
            throw TelemetryParseError.invalidLine("network=\(payload)")
        }

        let hasPublicIP = fields.count == 12
        let hasLocation = fields.count >= 11
        let locationOffset = hasPublicIP ? 9 : 8

        return NetworkTelemetry(
            interfaceName: fields[0],
            operstate: fields[1],
            receiveBytesPerSecond: try int64Value("network.receive_bytes_per_second", value: fields[2]),
            transmitBytesPerSecond: try int64Value("network.transmit_bytes_per_second", value: fields[3]),
            receiveErrors: try int64Value("network.receive_errors", value: fields[4]),
            transmitErrors: try int64Value("network.transmit_errors", value: fields[5]),
            receiveDrops: try int64Value("network.receive_drops", value: fields[6]),
            transmitDrops: try int64Value("network.transmit_drops", value: fields[7]),
            publicIPAddress: hasPublicIP ? fields[8] : "",
            publicIPCountryCode: hasLocation ? fields[locationOffset] : "",
            publicIPRegion: hasLocation ? fields[locationOffset + 1] : "",
            publicIPCity: hasLocation ? fields[locationOffset + 2] : ""
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
    let processPayloads: [String]
    let networkPayload: String?
}
