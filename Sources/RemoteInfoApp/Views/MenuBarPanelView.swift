import RemoteInfoCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: TelemetryStore
    let configurationError: String?
    let refreshEnabled: Bool
    let isMockMode: Bool
    @State private var selectedHostID: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 6) {
                if isMockMode {
                    mockModeView
                }

                if let configurationError {
                    configurationErrorView(configurationError)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, isMockMode || configurationError != nil ? 10 : 0)

            Divider()

            HStack(spacing: 0) {
                hostSidebar
                    .padding(.leading, 10)
                    .padding(.vertical, 10)
                    .padding(.trailing, 8)

                detailPane
            }
        }
        .frame(width: 820, height: 762)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Remote Info")
                    .font(.headline)
                Text(lastRefreshText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            FleetSummaryView(hostStates: store.hostStates)

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
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var hostSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hosts")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("Worst first")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 11)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(sortedHostStates) { state in
                        HostListRowView(
                            state: state,
                            isSelected: state.id == currentSelectedHostID
                        ) {
                            selectedHostID = state.id
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }

            Divider()

            footer
        }
        .frame(width: 270)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedState {
            HostCardView(state: selectedState, showsContainer: false)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView(
                "No Hosts",
                systemImage: "server.rack",
                description: Text("Add at least one host to ~/.config/remote-info/hosts.json.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sortedHostStates: [HostState] {
        store.hostStates.sorted { lhs, rhs in
            if lhs.displaySeverity.displayPriority == rhs.displaySeverity.displayPriority {
                return lhs.host.name.localizedStandardCompare(rhs.host.name) == .orderedAscending
            }
            return lhs.displaySeverity.displayPriority > rhs.displaySeverity.displayPriority
        }
    }

    private var selectedState: HostState? {
        if let selectedHostID,
           let state = store.hostStates.first(where: { $0.id == selectedHostID }) {
            return state
        }

        return sortedHostStates.first
    }

    private var currentSelectedHostID: String? {
        selectedState?.id
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
