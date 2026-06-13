@testable import RemoteInfoCore
import XCTest

final class MockTelemetryCollectorTests: XCTestCase {
    func testCollectsTelemetryForMockHost() async throws {
        let collector = MockTelemetryCollector()

        let telemetry = try await collector.collect(for: MockTelemetryCollector.hosts[0])

        XCTAssertEqual(telemetry.kernelRelease, "6.8.0-mock")
        XCTAssertGreaterThan(telemetry.cpuUsagePercent, 0)
        XCTAssertGreaterThan(telemetry.memoryTotalBytes, telemetry.memoryUsedBytes)
        XCTAssertGreaterThan(telemetry.rootTotalBytes, telemetry.rootUsedBytes)
    }

    func testTelemetryChangesAcrossCollections() async throws {
        let collector = MockTelemetryCollector()
        let host = MockTelemetryCollector.hosts[0]

        let first = try await collector.collect(for: host)
        let second = try await collector.collect(for: host)

        XCTAssertNotEqual(first.cpuUsagePercent, second.cpuUsagePercent)
        XCTAssertNotEqual(first.load1, second.load1)
    }
}
