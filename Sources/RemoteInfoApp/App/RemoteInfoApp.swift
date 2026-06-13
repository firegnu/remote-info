import RemoteInfoCore
import SwiftUI

@main
struct RemoteInfoApp: App {
    @StateObject private var store: TelemetryStore
    private let configurationError: String?

    init() {
        let bootstrap = Self.bootstrapStore()
        _store = StateObject(wrappedValue: bootstrap.store)
        configurationError = bootstrap.configurationError

        Task { @MainActor in
            await bootstrap.store.refreshAll()
            bootstrap.store.startPeriodicRefresh()
        }
    }

    var body: some Scene {
        MenuBarExtra("Remote Info", systemImage: "server.rack") {
            MenuBarPanelView(store: store, configurationError: configurationError)
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private static func bootstrapStore() -> (store: TelemetryStore, configurationError: String?) {
        do {
            let hosts = try HostConfigLoader().loadDefault()
            return (TelemetryStore(hosts: hosts), nil)
        } catch {
            return (
                TelemetryStore(
                    hosts: [
                        HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
                        HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
                    ]
                ),
                error.localizedDescription
            )
        }
    }
}
