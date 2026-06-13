@testable import RemoteInfoCore
import XCTest

final class MetricSeverityTests: XCTestCase {
    func testCPUUsageSeverityThresholds() {
        XCTAssertEqual(MetricSeverity.cpuUsage(49.9), .normal)
        XCTAssertEqual(MetricSeverity.cpuUsage(50), .attention)
        XCTAssertEqual(MetricSeverity.cpuUsage(75), .elevated)
        XCTAssertEqual(MetricSeverity.cpuUsage(90), .critical)
        XCTAssertEqual(MetricSeverity.cpuUsage(.nan), .unknown)
    }

    func testCapacityUsageSeverityThresholds() {
        XCTAssertEqual(MetricSeverity.capacityUsage(69.9), .normal)
        XCTAssertEqual(MetricSeverity.capacityUsage(70), .attention)
        XCTAssertEqual(MetricSeverity.capacityUsage(85), .elevated)
        XCTAssertEqual(MetricSeverity.capacityUsage(95), .critical)
        XCTAssertEqual(MetricSeverity.capacityUsage(.nan), .unknown)
    }

    func testLoadAverageSeverityUsesCoreCount() {
        XCTAssertEqual(MetricSeverity.loadAverage(15.9, coreCount: 32), .normal)
        XCTAssertEqual(MetricSeverity.loadAverage(16, coreCount: 32), .attention)
        XCTAssertEqual(MetricSeverity.loadAverage(24, coreCount: 32), .elevated)
        XCTAssertEqual(MetricSeverity.loadAverage(32, coreCount: 32), .critical)
        XCTAssertEqual(MetricSeverity.loadAverage(1, coreCount: 0), .unknown)
    }

    func testLatencySeverityThresholds() {
        XCTAssertEqual(MetricSeverity.latency(0.299), .normal)
        XCTAssertEqual(MetricSeverity.latency(0.3), .attention)
        XCTAssertEqual(MetricSeverity.latency(0.8), .elevated)
        XCTAssertEqual(MetricSeverity.latency(2), .critical)
        XCTAssertEqual(MetricSeverity.latency(.nan), .unknown)
    }

    func testNetworkOperstateSeverity() {
        XCTAssertEqual(MetricSeverity.networkOperstate("up"), .normal)
        XCTAssertEqual(MetricSeverity.networkOperstate("down"), .critical)
        XCTAssertEqual(MetricSeverity.networkOperstate("unknown"), .unknown)
        XCTAssertEqual(MetricSeverity.networkOperstate(""), .unknown)
    }

    func testNetworkErrorSeverityHighlightsNonZeroCounts() {
        XCTAssertEqual(MetricSeverity.networkErrors(0), .normal)
        XCTAssertEqual(MetricSeverity.networkErrors(1), .elevated)
        XCTAssertEqual(MetricSeverity.networkErrors(10), .critical)
        XCTAssertEqual(MetricSeverity.networkErrors(-1), .unknown)
    }

    func testGPUTemperatureSeverityThresholds() {
        XCTAssertEqual(MetricSeverity.gpuTemperature(74.9), .normal)
        XCTAssertEqual(MetricSeverity.gpuTemperature(75), .attention)
        XCTAssertEqual(MetricSeverity.gpuTemperature(83), .elevated)
        XCTAssertEqual(MetricSeverity.gpuTemperature(88), .critical)
        XCTAssertEqual(MetricSeverity.gpuTemperature(.nan), .unknown)
    }

    func testGPUPowerSeverityThresholds() {
        XCTAssertEqual(MetricSeverity.gpuPowerUsage(89.9), .normal)
        XCTAssertEqual(MetricSeverity.gpuPowerUsage(90), .attention)
        XCTAssertEqual(MetricSeverity.gpuPowerUsage(97), .elevated)
        XCTAssertEqual(MetricSeverity.gpuPowerUsage(100), .critical)
        XCTAssertEqual(MetricSeverity.gpuPowerUsage(.nan), .unknown)
    }

    func testGPUFanSeverityThresholds() {
        XCTAssertEqual(MetricSeverity.gpuFanSpeed(74.9), .normal)
        XCTAssertEqual(MetricSeverity.gpuFanSpeed(75), .attention)
        XCTAssertEqual(MetricSeverity.gpuFanSpeed(90), .elevated)
        XCTAssertEqual(MetricSeverity.gpuFanSpeed(.nan), .unknown)
    }
}
