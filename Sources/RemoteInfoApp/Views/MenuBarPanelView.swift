import RemoteInfoCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: TelemetryStore
    let configurationError: String?
    let refreshEnabled: Bool
    let isMockMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if isMockMode {
                mockModeView
            }

            if let configurationError {
                configurationErrorView(configurationError)
            }

            FleetSummaryView(hostStates: store.hostStates)

            VStack(spacing: 10) {
                ForEach(store.hostStates) { state in
                    HostCardView(state: state)
                }
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 420)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Remote Info")
                    .font(.headline)
                Text(lastRefreshText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if refreshEnabled {
                    Task {
                        await store.refreshAll()
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .disabled(!refreshEnabled || store.hostStates.contains { $0.isRefreshing })
            .help("Refresh")
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label(footerText, systemImage: isMockMode ? "shippingbox" : "gearshape")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
        }
    }

    private var mockModeView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.blue)
            Text("Mock telemetry mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footerText: String {
        if isMockMode {
            return "Using local mock data"
        }

        return "~/.config/remote-info/hosts.json"
    }

    private var lastRefreshText: String {
        guard let date = store.lastRefreshStartedAt else {
            return "Not refreshed yet"
        }

        return "Last refresh \(date.formatted(date: .omitted, time: .shortened))"
    }

    private func configurationErrorView(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
