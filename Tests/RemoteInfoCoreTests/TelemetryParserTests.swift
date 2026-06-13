@testable import RemoteInfoCore
import XCTest

final class TelemetryParserTests: XCTestCase {
    func testParsesCompleteOutput() throws {
        let collectedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let latency: TimeInterval = 0.125

        let telemetry = try TelemetryParser().parse(
            completeOutput,
            collectedAt: collectedAt,
            latency: latency
        )

        XCTAssertEqual(telemetry.collectedAt, collectedAt)
        XCTAssertEqual(telemetry.latencySeconds, latency)
        XCTAssertEqual(telemetry.kernelRelease, "6.8.0-test")
        XCTAssertEqual(telemetry.uptimeSeconds, 123_456)
        XCTAssertEqual(telemetry.load1, 0.42)
        XCTAssertEqual(telemetry.load5, 0.38)
        XCTAssertEqual(telemetry.load15, 0.31)
        XCTAssertEqual(telemetry.cpuUsagePercent, 18.2)
        XCTAssertEqual(telemetry.cpuCoreCount, 32)
        XCTAssertEqual(telemetry.memoryUsedBytes, 4_412_346_368)
        XCTAssertEqual(telemetry.memoryTotalBytes, 10_307_921_510)
        XCTAssertEqual(telemetry.rootUsedBytes, 77_309_411_328)
        XCTAssertEqual(telemetry.rootTotalBytes, 107_374_182_400)
        XCTAssertEqual(telemetry.gpus.count, 1)
        XCTAssertEqual(telemetry.gpus[0].index, 0)
        XCTAssertEqual(telemetry.gpus[0].name, "NVIDIA GeForce RTX 5090")
        XCTAssertEqual(telemetry.gpus[0].driverVersion, "575.64")
        XCTAssertEqual(telemetry.gpus[0].utilizationPercent, 88)
        XCTAssertEqual(telemetry.gpus[0].memoryUsedMiB, 29_800)
        XCTAssertEqual(telemetry.gpus[0].memoryTotalMiB, 32_768)
        XCTAssertEqual(telemetry.gpus[0].temperatureCelsius, 72)
        XCTAssertEqual(telemetry.gpus[0].powerDrawWatts, 512)
        XCTAssertEqual(telemetry.gpus[0].powerLimitWatts, 575)
        XCTAssertEqual(telemetry.gpus[0].fanSpeedPercent, 64)
        XCTAssertEqual(telemetry.gpus[0].graphicsClockMHz, 2_620)
        XCTAssertEqual(telemetry.topProcesses.count, 2)
        XCTAssertEqual(telemetry.topProcesses[0].pid, 2_411)
        XCTAssertEqual(telemetry.topProcesses[0].command, "python3")
        XCTAssertEqual(telemetry.topProcesses[0].cpuPercent, 216.4)
        XCTAssertEqual(telemetry.topProcesses[0].memoryPercent, 12.1)
        XCTAssertEqual(telemetry.topProcesses[1].command, "ollama")
        let network = try XCTUnwrap(telemetry.network)
        XCTAssertEqual(network.interfaceName, "eth0")
        XCTAssertEqual(network.operstate, "up")
        XCTAssertEqual(network.receiveBytesPerSecond, 18_398_656)
        XCTAssertEqual(network.transmitBytesPerSecond, 3_355_443)
        XCTAssertEqual(network.errorCount, 0)
        XCTAssertEqual(network.dropCount, 0)
        XCTAssertEqual(network.publicIPAddress, "203.0.113.10")
        XCTAssertEqual(network.publicIPCountryCode, "JP")
        XCTAssertEqual(network.publicIPRegion, "Tokyo")
        XCTAssertEqual(network.publicIPCity, "Tokyo")
    }

    func testIgnoresUnknownKeys() throws {
        let output = completeOutput + "\nextra_key=ignored\n"

        let telemetry = try TelemetryParser().parse(
            output,
            collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            latency: 0.2
        )

        XCTAssertEqual(telemetry.uptimeSeconds, 123_456)
    }

    func testReportsMissingRequiredKey() {
        let output = """
        uptime_seconds=123456
        kernel_release=6.8.0-test
        load1=0.42
        load5=0.38
        load15=0.31
        cpu_usage_percent=18.2
        cpu_core_count=32
        memory_used_bytes=4412346368
        memory_total_bytes=10307921510
        root_used_bytes=77309411328
        """

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(error as? TelemetryParseError, .missingKey("root_total_bytes"))
        }
    }

    func testReportsMalformedNumbers() {
        let output = """
        uptime_seconds=123456
        kernel_release=6.8.0-test
        load1=not-a-number
        load5=0.38
        load15=0.31
        cpu_usage_percent=18.2
        cpu_core_count=32
        memory_used_bytes=4412346368
        memory_total_bytes=10307921510
        root_used_bytes=77309411328
        root_total_bytes=107374182400
        """

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(
                error as? TelemetryParseError,
                .invalidNumber(key: "load1", value: "not-a-number")
            )
        }
    }

    func testReportsInvalidLineWithoutSeparator() {
        let output = completeOutput + "\nnot-a-key-value-line\n"

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(error as? TelemetryParseError, .invalidLine("not-a-key-value-line"))
        }
    }

    func testRejectsNonFiniteDoubleValues() {
        let output = """
        uptime_seconds=123456
        kernel_release=6.8.0-test
        load1=nan
        load5=0.38
        load15=0.31
        cpu_usage_percent=18.2
        cpu_core_count=32
        memory_used_bytes=4412346368
        memory_total_bytes=10307921510
        root_used_bytes=77309411328
        root_total_bytes=107374182400
        """

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(error as? TelemetryParseError, .invalidNumber(key: "load1", value: "nan"))
        }
    }

    func testTrimsWhitespaceAroundKeysAndValues() throws {
        let output = """
        uptime_seconds = 123456
        kernel_release = 6.8.0-test
        load1 = 0.42
        load5= 0.38
        load15 =0.31
        cpu_usage_percent = 18.2
        cpu_core_count = 32
        memory_used_bytes = 4412346368
        memory_total_bytes = 10307921510
        root_used_bytes = 77309411328
        root_total_bytes = 107374182400
        """

        let telemetry = try TelemetryParser().parse(
            output,
            collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            latency: 0.2
        )

        XCTAssertEqual(telemetry.load1, 0.42)
        XCTAssertEqual(telemetry.load5, 0.38)
        XCTAssertEqual(telemetry.load15, 0.31)
    }

    func testRejectsDuplicateKeys() {
        let output = completeOutput + "\nload1=0.99\n"

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(error as? TelemetryParseError, .duplicateKey("load1"))
        }
    }

    func testAllowsOutputWithoutGPULines() throws {
        let telemetry = try TelemetryParser().parse(
            systemOnlyOutput,
            collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            latency: 0.2
        )

        XCTAssertEqual(telemetry.gpus, [])
    }

    func testAllowsOutputWithoutActivityLines() throws {
        let telemetry = try TelemetryParser().parse(
            systemOnlyOutput,
            collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            latency: 0.2
        )

        XCTAssertEqual(telemetry.topProcesses, [])
        XCTAssertNil(telemetry.network)
    }

    func testReportsMalformedGPUValues() {
        let output = completeOutput.replacingOccurrences(of: "|88|", with: "|not-a-number|")

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(
                error as? TelemetryParseError,
                .invalidNumber(key: "gpu.utilization_percent", value: "not-a-number")
            )
        }
    }

    func testReportsMalformedProcessValues() {
        let output = completeOutput.replacingOccurrences(of: "|216.4|", with: "|bad|")

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(
                error as? TelemetryParseError,
                .invalidNumber(key: "process.cpu_percent", value: "bad")
            )
        }
    }

    func testReportsMalformedNetworkValues() {
        let output = completeOutput.replacingOccurrences(of: "|18398656|", with: "|bad|")

        XCTAssertThrowsError(
            try TelemetryParser().parse(
                output,
                collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                latency: 0.2
            )
        ) { error in
            XCTAssertEqual(
                error as? TelemetryParseError,
                .invalidNumber(key: "network.receive_bytes_per_second", value: "bad")
            )
        }
    }

    func testPercentFormatterHandlesNonFiniteValues() {
        XCTAssertEqual(RemoteInfoFormatters.percent(.nan), "--")
        XCTAssertEqual(RemoteInfoFormatters.percent(.infinity), "--")
        XCTAssertEqual(RemoteInfoFormatters.percent(-.infinity), "--")
        XCTAssertEqual(RemoteInfoFormatters.percent(1e100), "--")
        XCTAssertEqual(RemoteInfoFormatters.percent(42.4), "42%")
    }

    func testCPUUsageFormatterKeepsLowUtilizationPrecisionAndShowsCoreCount() {
        XCTAssertEqual(RemoteInfoFormatters.cpuUsage(0, coreCount: 32), "0.00% / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.cpuUsage(0.01, coreCount: 32), "0.01% / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.cpuUsage(0.1, coreCount: 32), "0.10% / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.cpuUsage(9.4, coreCount: 32), "9.40% / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.cpuUsage(12.4, coreCount: 32), "12% / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.cpuUsage(.nan, coreCount: 32), "-- / 32 cores")
    }

    func testProcessCPUUsageFormatterKeepsLowUtilizationPrecision() {
        XCTAssertEqual(RemoteInfoFormatters.processCPUUsage(0), "0.00%")
        XCTAssertEqual(RemoteInfoFormatters.processCPUUsage(0.1), "0.10%")
        XCTAssertEqual(RemoteInfoFormatters.processCPUUsage(0.3), "0.30%")
        XCTAssertEqual(RemoteInfoFormatters.processCPUUsage(9.4), "9.40%")
        XCTAssertEqual(RemoteInfoFormatters.processCPUUsage(12.4), "12%")
        XCTAssertEqual(RemoteInfoFormatters.processCPUUsage(.nan), "--")
    }

    func testProcessMemoryUsageFormatterKeepsLowUtilizationPrecision() {
        XCTAssertEqual(RemoteInfoFormatters.processMemoryUsage(0), "0.0%")
        XCTAssertEqual(RemoteInfoFormatters.processMemoryUsage(0.6), "0.6%")
        XCTAssertEqual(RemoteInfoFormatters.processMemoryUsage(1.3), "1.3%")
        XCTAssertEqual(RemoteInfoFormatters.processMemoryUsage(9.4), "9.4%")
        XCTAssertEqual(RemoteInfoFormatters.processMemoryUsage(12.4), "12%")
        XCTAssertEqual(RemoteInfoFormatters.processMemoryUsage(.nan), "--")
    }

    func testMemoryUsageFormatterShowsTotalMemory() {
        let totalBytes: Int64 = 128 * 1_024 * 1_024 * 1_024

        XCTAssertEqual(RemoteInfoFormatters.memoryUsage(33.6, totalBytes: totalBytes), "34% / 128 GB")
        XCTAssertEqual(RemoteInfoFormatters.memoryUsage(.nan, totalBytes: totalBytes), "-- / 128 GB")
        XCTAssertEqual(RemoteInfoFormatters.memoryUsage(42.4, totalBytes: 0), "42%")
    }

    func testDiskUsageFormatterShowsTotalCapacity() {
        let totalBytes: Int64 = 512 * 1_024 * 1_024 * 1_024

        XCTAssertEqual(RemoteInfoFormatters.diskUsage(71.6, totalBytes: totalBytes), "72% / 512 GB")
        XCTAssertEqual(RemoteInfoFormatters.diskUsage(.nan, totalBytes: totalBytes), "-- / 512 GB")
        XCTAssertEqual(RemoteInfoFormatters.diskUsage(42.4, totalBytes: 0), "42%")
    }

    func testLoadAverageFormatterShowsCoreContext() {
        XCTAssertEqual(RemoteInfoFormatters.loadAverage(0, coreCount: 32), "0.00 / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.loadAverage(0.01, coreCount: 32), "0.01 / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.loadAverage(1.25, coreCount: 32), "1.25 / 32 cores")
        XCTAssertEqual(RemoteInfoFormatters.loadAverage(.nan, coreCount: 32), "-- / 32 cores")
    }

    func testLatencyFormatterHandlesNonFiniteValues() {
        XCTAssertEqual(RemoteInfoFormatters.latency(.nan), "--")
        XCTAssertEqual(RemoteInfoFormatters.latency(.infinity), "--")
        XCTAssertEqual(RemoteInfoFormatters.latency(-.infinity), "--")
        XCTAssertEqual(RemoteInfoFormatters.latency(1e100), "--")
        XCTAssertEqual(RemoteInfoFormatters.latency(0.125), "125 ms")
    }

    func testGPUFormatters() {
        XCTAssertEqual(RemoteInfoFormatters.mebibytesAsGibibytes(29_800), "29.1 GB")
        XCTAssertEqual(RemoteInfoFormatters.watts(512.4), "512 W")
        XCTAssertEqual(RemoteInfoFormatters.gpuPower(22.1, limit: 575), "22/575 W")
        XCTAssertEqual(RemoteInfoFormatters.celsius(72.2), "72 C")
        XCTAssertEqual(RemoteInfoFormatters.megahertzAsGigahertz(2_620), "2.62 GHz")
    }

    func testRateFormatter() {
        XCTAssertEqual(RemoteInfoFormatters.bytesPerSecond(18_398_656), "17.5 MB/s")
    }

    func testNetworkActivityFormatters() {
        XCTAssertEqual(
            RemoteInfoFormatters.networkTraffic(
                receiveBytesPerSecond: 18_398_656,
                transmitBytesPerSecond: 3_355_443
            ),
            "↓ 17.5 MB/s  ↑ 3.2 MB/s"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.networkLocation(
                countryCode: "JP",
                region: "Tokyo",
                city: "Tokyo"
            ),
            "🇯🇵 Tokyo"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.networkLocation(
                countryCode: "CN",
                region: "Shaanxi",
                city: "Xi'an"
            ),
            "🇨🇳 Shaanxi"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.networkLocation(
                countryCode: "",
                region: "",
                city: ""
            ),
            "--"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.networkIdentity(
                interfaceName: "eth0",
                publicIPAddress: "203.0.113.10",
                countryCode: "JP",
                region: "Tokyo",
                city: "Tokyo"
            ),
            "eth0 · IP 203.0.113.10 · 🇯🇵 Tokyo"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.networkIdentity(
                interfaceName: "physical",
                publicIPAddress: "",
                countryCode: "",
                region: "",
                city: ""
            ),
            "physical · IP -- · LOC --"
        )
        XCTAssertEqual(RemoteInfoFormatters.networkInterfaceLabel("eth0"), "eth0")
        XCTAssertEqual(RemoteInfoFormatters.networkInterfaceLabel(" "), "--")
        XCTAssertEqual(RemoteInfoFormatters.networkIPAddressLabel("203.0.113.10"), "IP 203.0.113.10")
        XCTAssertEqual(RemoteInfoFormatters.networkIPAddressLabel(""), "IP --")
        XCTAssertEqual(
            RemoteInfoFormatters.networkLocationLabel(
                countryCode: "JP",
                region: "Tokyo",
                city: "Tokyo"
            ),
            "🇯🇵 Tokyo"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.networkLocationLabel(
                countryCode: "",
                region: "",
                city: ""
            ),
            "LOC --"
        )
    }

    func testAgeFormatter() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            RemoteInfoFormatters.age(
                since: Date(timeIntervalSince1970: 1_699_999_997),
                now: now
            ),
            "just now"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.age(
                since: Date(timeIntervalSince1970: 1_699_999_955),
                now: now
            ),
            "45s ago"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.age(
                since: Date(timeIntervalSince1970: 1_699_999_700),
                now: now
            ),
            "5m ago"
        )
        XCTAssertEqual(
            RemoteInfoFormatters.age(
                since: Date(timeIntervalSince1970: 1_700_000_030),
                now: now
            ),
            "--"
        )
    }

    private let completeOutput = """
    uptime_seconds=123456
    kernel_release=6.8.0-test
    load1=0.42
    load5=0.38
    load15=0.31
    cpu_usage_percent=18.2
    cpu_core_count=32
    memory_used_bytes=4412346368
    memory_total_bytes=10307921510
    root_used_bytes=77309411328
    root_total_bytes=107374182400
    gpu=0|NVIDIA GeForce RTX 5090|575.64|88|29800|32768|72|512|575|64|2620
    process=2411|python3|216.4|12.1
    process=1830|ollama|94.2|8.4
    network=eth0|up|18398656|3355443|0|0|0|0|203.0.113.10|JP|Tokyo|Tokyo
    """

    private let systemOnlyOutput = """
    uptime_seconds=123456
    kernel_release=6.8.0-test
    load1=0.42
    load5=0.38
    load15=0.31
    cpu_usage_percent=18.2
    cpu_core_count=32
    memory_used_bytes=4412346368
    memory_total_bytes=10307921510
    root_used_bytes=77309411328
    root_total_bytes=107374182400
    """
}
