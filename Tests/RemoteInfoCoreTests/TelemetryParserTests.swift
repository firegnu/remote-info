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
        XCTAssertEqual(telemetry.uptimeSeconds, 123_456)
        XCTAssertEqual(telemetry.load1, 0.42)
        XCTAssertEqual(telemetry.load5, 0.38)
        XCTAssertEqual(telemetry.load15, 0.31)
        XCTAssertEqual(telemetry.cpuUsagePercent, 18.2)
        XCTAssertEqual(telemetry.memoryUsedBytes, 4_412_346_368)
        XCTAssertEqual(telemetry.memoryTotalBytes, 10_307_921_510)
        XCTAssertEqual(telemetry.rootUsedBytes, 77_309_411_328)
        XCTAssertEqual(telemetry.rootTotalBytes, 107_374_182_400)
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
        load1=0.42
        load5=0.38
        load15=0.31
        cpu_usage_percent=18.2
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
        load1=not-a-number
        load5=0.38
        load15=0.31
        cpu_usage_percent=18.2
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

    func testRejectsNonFiniteDoubleValues() {
        let output = """
        uptime_seconds=123456
        load1=nan
        load5=0.38
        load15=0.31
        cpu_usage_percent=18.2
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
        load1 = 0.42
        load5= 0.38
        load15 =0.31
        cpu_usage_percent = 18.2
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

    func testPercentFormatterHandlesNonFiniteValues() {
        XCTAssertEqual(RemoteInfoFormatters.percent(.nan), "--")
        XCTAssertEqual(RemoteInfoFormatters.percent(.infinity), "--")
        XCTAssertEqual(RemoteInfoFormatters.percent(-.infinity), "--")
    }

    private let completeOutput = """
    uptime_seconds=123456
    load1=0.42
    load5=0.38
    load15=0.31
    cpu_usage_percent=18.2
    memory_used_bytes=4412346368
    memory_total_bytes=10307921510
    root_used_bytes=77309411328
    root_total_bytes=107374182400
    """
}
