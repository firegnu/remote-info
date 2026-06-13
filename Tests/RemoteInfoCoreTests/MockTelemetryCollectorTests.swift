@testable import RemoteInfoCore
import XCTest

final class MockTelemetryCollectorTests: XCTestCase {
    func testCollectsTelemetryForMockHost() async throws {
        let collector = MockTelemetryCollector()

        let telemetry = try await collector.collect(for: MockTelemetryCollector.hosts[0])

        XCTAssertEqual(telemetry.kernelRelease, "6.8.0-mock")
        XCTAssertGreaterThan(telemetry.cpuUsagePercent, 0)
        XCTAssertEqual(telemetry.cpuCoreCount, 32)
        XCTAssertGreaterThan(telemetry.memoryTotalBytes, telemetry.memoryUsedBytes)
        XCTAssertGreaterThan(telemetry.rootTotalBytes, telemetry.rootUsedBytes)
        XCTAssertEqual(telemetry.gpus.count, 1)
        let gpu = try XCTUnwrap(telemetry.gpus.first)
        XCTAssertEqual(gpu.name, "NVIDIA GeForce RTX 5090")
        XCTAssertEqual(gpu.memoryTotalMiB, 32_768)
        XCTAssertGreaterThan(gpu.utilizationPercent, 0)
        XCTAssertFalse(telemetry.topProcesses.isEmpty)
        XCTAssertEqual(telemetry.topProcesses[0].command, "python3")
        let network = try XCTUnwrap(telemetry.network)
        XCTAssertEqual(network.interfaceName, "eth0")
        XCTAssertEqual(network.operstate, "up")
        XCTAssertGreaterThan(network.receiveBytesPerSecond, 0)
        XCTAssertEqual(network.publicIPAddress, "203.0.113.10")
        XCTAssertEqual(network.publicIPCountryCode, "JP")
        XCTAssertEqual(network.publicIPRegion, "Tokyo")
    }

    func testTelemetryChangesAcrossCollections() async throws {
        let collector = MockTelemetryCollector()
        let host = MockTelemetryCollector.hosts[0]

        let first = try await collector.collect(for: host)
        let second = try await collector.collect(for: host)

        XCTAssertNotEqual(first.cpuUsagePercent, second.cpuUsagePercent)
        XCTAssertNotEqual(first.load1, second.load1)
        let firstGPU = try XCTUnwrap(first.gpus.first)
        let secondGPU = try XCTUnwrap(second.gpus.first)
        XCTAssertNotEqual(firstGPU.utilizationPercent, secondGPU.utilizationPercent)
        XCTAssertNotEqual(firstGPU.memoryUsedMiB, secondGPU.memoryUsedMiB)
        XCTAssertNotEqual(first.topProcesses[0].cpuPercent, second.topProcesses[0].cpuPercent)
        XCTAssertNotEqual(first.network?.receiveBytesPerSecond, second.network?.receiveBytesPerSecond)
    }
}
