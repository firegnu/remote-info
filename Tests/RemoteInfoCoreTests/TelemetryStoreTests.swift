@testable import RemoteInfoCore
import XCTest

@MainActor
final class TelemetryStoreTests: XCTestCase {
    func testDefaultPeriodicRefreshIntervalIsFiveMinutes() {
        XCTAssertEqual(TelemetryStore.defaultPeriodicRefreshInterval, 300)
    }

    func testRefreshAllUpdatesHostsIndependently() async {
        let collector = FakeTelemetryCollector()
        collector.enqueue([
            "host-a": .success(sampleTelemetry(cpuUsagePercent: 10)),
            "host-b": .failure(TelemetryCollectionError.sshFailed(exitCode: 255, message: "Permission denied"))
        ])
        let store = TelemetryStore(hosts: hosts, collector: collector)

        await store.refreshAll()

        XCTAssertEqual(store.hostStates[0].status, .online)
        XCTAssertEqual(store.hostStates[0].telemetry?.cpuUsagePercent, 10)
        XCTAssertEqual(
            store.hostStates[1].status,
            .offline("SSH command failed with exit code 255: Permission denied")
        )
        XCTAssertNil(store.hostStates[1].telemetry)
    }

    func testKeepsLastSuccessfulTelemetryWhenLaterRefreshFails() async {
        let collector = FakeTelemetryCollector()
        collector.enqueue([
            "host-a": .success(sampleTelemetry(cpuUsagePercent: 10)),
            "host-b": .success(sampleTelemetry(cpuUsagePercent: 20))
        ])
        collector.enqueue([
            "host-a": .failure(TelemetryCollectionError.sshFailed(exitCode: 255, message: "Permission denied")),
            "host-b": .success(sampleTelemetry(cpuUsagePercent: 30))
        ])
        let store = TelemetryStore(hosts: hosts, collector: collector)

        await store.refreshAll()
        await store.refreshAll()

        XCTAssertEqual(
            store.hostStates[0].status,
            .offline("SSH command failed with exit code 255: Permission denied")
        )
        XCTAssertEqual(store.hostStates[0].telemetry?.cpuUsagePercent, 10)
        XCTAssertEqual(store.hostStates[1].status, .online)
        XCTAssertEqual(store.hostStates[1].telemetry?.cpuUsagePercent, 30)
    }

    func testRefreshAllStartsHostCollectionsConcurrently() async {
        let collector = BlockingTelemetryCollector()
        let store = TelemetryStore(hosts: hosts, collector: collector)

        let refreshTask = Task {
            await store.refreshAll()
        }

        let startedBothBeforeRelease = await collector.waitUntilStartedCount(2, timeoutSeconds: 0.2)
        let maxInFlightCount = await collector.currentMaxInFlightCount()

        XCTAssertTrue(startedBothBeforeRelease)
        XCTAssertEqual(maxInFlightCount, 2)

        await collector.succeed(hostID: "host-a", telemetry: sampleTelemetry(cpuUsagePercent: 10))
        _ = await collector.waitUntilStarted(hostID: "host-b", timeoutSeconds: 0.2)
        await collector.succeed(hostID: "host-b", telemetry: sampleTelemetry(cpuUsagePercent: 20))

        await refreshTask.value

        XCTAssertEqual(store.hostStates[0].status, .online)
        XCTAssertEqual(store.hostStates[1].status, .online)
    }

    func testPeriodicRefreshSleepsBeforeRefreshing() async throws {
        let collector = FakeTelemetryCollector()
        collector.enqueue([
            "host-a": .success(sampleTelemetry(cpuUsagePercent: 10)),
            "host-b": .success(sampleTelemetry(cpuUsagePercent: 20))
        ])
        let store = TelemetryStore(hosts: hosts, collector: collector)

        store.startPeriodicRefresh(every: 0.05)
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(collector.collectCount, 0)

        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(collector.collectCount, 2)
        store.stopPeriodicRefresh()
    }

    private var hosts: [HostConfig] {
        [
            HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
            HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
        ]
    }

    private func sampleTelemetry(cpuUsagePercent: Double) -> HostTelemetry {
        HostTelemetry(
            collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            latencySeconds: 0.25,
            kernelRelease: "6.8.0-test",
            uptimeSeconds: 123_456,
            load1: 0.42,
            load5: 0.38,
            load15: 0.31,
            cpuUsagePercent: cpuUsagePercent,
            memoryUsedBytes: 4_412_346_368,
            memoryTotalBytes: 10_307_921_510,
            rootUsedBytes: 77_309_411_328,
            rootTotalBytes: 107_374_182_400
        )
    }
}

@MainActor
private final class FakeTelemetryCollector: TelemetryCollecting {
    private var queuedResults: [[String: Result<HostTelemetry, Error>]] = []
    private var activeResults: [String: Result<HostTelemetry, Error>]?
    private var remainingActiveResults = 0
    private(set) var collectCount = 0

    func enqueue(_ results: [String: Result<HostTelemetry, Error>]) {
        queuedResults.append(results)
    }

    func collect(for host: HostConfig) async throws -> HostTelemetry {
        collectCount += 1

        if activeResults == nil, !queuedResults.isEmpty {
            activeResults = queuedResults.removeFirst()
            remainingActiveResults = activeResults?.count ?? 0
        }

        guard let result = activeResults?[host.id] else {
            throw TelemetryCollectionError.parserFailed("Missing fake result for \(host.id)")
        }

        remainingActiveResults -= 1
        if remainingActiveResults == 0 {
            activeResults = nil
        }

        return try result.get()
    }
}

private actor BlockingTelemetryCollector: TelemetryCollecting {
    private var startedHostIDs: [String] = []
    private var continuations: [String: CheckedContinuation<HostTelemetry, Error>] = [:]
    private var inFlightCount = 0
    private(set) var maxInFlightCount = 0

    func collect(for host: HostConfig) async throws -> HostTelemetry {
        startedHostIDs.append(host.id)
        inFlightCount += 1
        maxInFlightCount = max(maxInFlightCount, inFlightCount)

        defer {
            inFlightCount -= 1
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations[host.id] = continuation
        }
    }

    func succeed(hostID: String, telemetry: HostTelemetry) {
        continuations.removeValue(forKey: hostID)?.resume(returning: telemetry)
    }

    func currentMaxInFlightCount() -> Int {
        maxInFlightCount
    }

    func waitUntilStarted(hostID: String, timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while !startedHostIDs.contains(hostID), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        return startedHostIDs.contains(hostID)
    }

    func waitUntilStartedCount(_ count: Int, timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while startedHostIDs.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        return startedHostIDs.count >= count
    }
}
