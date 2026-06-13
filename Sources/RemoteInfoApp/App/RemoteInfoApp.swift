import RemoteInfoCore
import SwiftUI

@main
struct RemoteInfoApp: App {
    @StateObject private var store: TelemetryStore
    private let configurationError: String?
    private let refreshEnabled: Bool

    init() {
        let bootstrap = Self.bootstrapStore()
        _store = StateObject(wrappedValue: bootstrap.store)
        configurationError = bootstrap.configurationError
        refreshEnabled = bootstrap.refreshEnabled

        if bootstrap.refreshEnabled {
            Task { @MainActor in
                await bootstrap.store.refreshAll()
                bootstrap.store.startPeriodicRefresh()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("Remote Info", systemImage: "server.rack") {
            MenuBarPanelView(
                store: store,
                configurationError: configurationError,
                refreshEnabled: refreshEnabled
            )
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private static func bootstrapStore() -> (
        store: TelemetryStore,
        configurationError: String?,
        refreshEnabled: Bool
    ) {
        do {
            let hosts = try HostConfigLoader().loadDefault()
            return (TelemetryStore(hosts: hosts), nil, true)
        } catch {
            return (
                TelemetryStore(
                    hosts: [
                        HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
                        HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
                    ]
                ),
                error.localizedDescription,
                false
            )
        }
    }
}
