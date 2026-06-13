@testable import RemoteInfoCore
import XCTest

@MainActor
final class TelemetryBootstrapperTests: XCTestCase {
    func testMockModeBypassesConfigLoaderAndEnablesRefresh() {
        let loader = RecordingHostConfigLoader(result: .failure(HostConfigError.fileMissing(URL(filePath: "/missing"))))

        let bootstrap = TelemetryBootstrapper.bootstrap(
            environment: [TelemetryBootstrapper.mockModeEnvironmentKey: "1"],
            configLoader: loader
        )

        XCTAssertEqual(loader.loadDefaultCallCount, 0)
        XCTAssertTrue(bootstrap.refreshEnabled)
        XCTAssertTrue(bootstrap.isMockMode)
        XCTAssertNil(bootstrap.configurationError)
        XCTAssertEqual(bootstrap.store.hostStates.map(\.host), MockTelemetryCollector.hosts)
    }

    func testDefaultModeLoadsHostConfig() {
        let hosts = [
            HostConfig(id: "host-a", name: "Host A", sshTarget: "test-host-a"),
            HostConfig(id: "host-b", name: "Host B", sshTarget: "test-host-b")
        ]
        let loader = RecordingHostConfigLoader(result: .success(hosts))

        let bootstrap = TelemetryBootstrapper.bootstrap(
            environment: [:],
            configLoader: loader
        )

        XCTAssertEqual(loader.loadDefaultCallCount, 1)
        XCTAssertTrue(bootstrap.refreshEnabled)
        XCTAssertFalse(bootstrap.isMockMode)
        XCTAssertNil(bootstrap.configurationError)
        XCTAssertEqual(bootstrap.store.hostStates.map(\.host), hosts)
    }
}

private final class RecordingHostConfigLoader: HostConfigLoading {
    private let result: Result<[HostConfig], Error>
    private(set) var loadDefaultCallCount = 0

    init(result: Result<[HostConfig], Error>) {
        self.result = result
    }

    func loadDefault() throws -> [HostConfig] {
        loadDefaultCallCount += 1
        return try result.get()
    }
}
