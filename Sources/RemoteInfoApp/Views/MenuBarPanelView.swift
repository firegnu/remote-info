import RemoteInfoCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: TelemetryStore
    let configurationError: String?
    let refreshEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

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
            Label("~/.config/remote-info/hosts.json", systemImage: "gearshape")
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
