import RemoteInfoCore
import SwiftUI

@main
struct RemoteInfoApp: App {
    @StateObject private var store: TelemetryStore
    private let configurationError: String?
    private let refreshEnabled: Bool
    private let isMockMode: Bool

    init() {
        let bootstrap = TelemetryBootstrapper.bootstrap()
        _store = StateObject(wrappedValue: bootstrap.store)
        configurationError = bootstrap.configurationError
        refreshEnabled = bootstrap.refreshEnabled
        isMockMode = bootstrap.isMockMode

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
                refreshEnabled: refreshEnabled,
                isMockMode: isMockMode
            )
        }
        .menuBarExtraStyle(.window)
    }
}
