import Foundation

@MainActor
public struct TelemetryBootstrap {
    public let store: TelemetryStore
    public let configurationError: String?
    public let refreshEnabled: Bool
    public let isMockMode: Bool
}

public enum TelemetryBootstrapper {
    public static let mockModeEnvironmentKey = "REMOTE_INFO_MOCK_MODE"

    @MainActor
    public static func bootstrap(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        configLoader: any HostConfigLoading = HostConfigLoader()
    ) -> TelemetryBootstrap {
        if isMockModeEnabled(in: environment) {
            return TelemetryBootstrap(
                store: TelemetryStore(
                    hosts: MockTelemetryCollector.hosts,
                    collector: MockTelemetryCollector()
                ),
                configurationError: nil,
                refreshEnabled: true,
                isMockMode: true
            )
        }

        do {
            let hosts = try configLoader.loadDefault()
            return TelemetryBootstrap(
                store: TelemetryStore(hosts: hosts),
                configurationError: nil,
                refreshEnabled: true,
                isMockMode: false
            )
        } catch {
            return TelemetryBootstrap(
                store: TelemetryStore(
                    hosts: [
                        HostConfig(id: "host-a", name: "Host A", sshTarget: "CHANGE_ME_HOST_A"),
                        HostConfig(id: "host-b", name: "Host B", sshTarget: "CHANGE_ME_HOST_B")
                    ]
                ),
                configurationError: error.localizedDescription,
                refreshEnabled: false,
                isMockMode: false
            )
        }
    }

    private static func isMockModeEnabled(in environment: [String: String]) -> Bool {
        guard let rawValue = environment[mockModeEnvironmentKey] else {
            return false
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "1" || value == "true" || value == "yes"
    }
}
