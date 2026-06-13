import RemoteInfoCore
import SwiftUI

struct HostCardView: View {
    let state: HostState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.host.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(state.host.sshTarget)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                statusBadge
            }

            if let telemetry = state.telemetry {
                metrics(for: telemetry)
            }

            if case .offline(let message) = state.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: statusSymbolName)
                .imageScale(.small)
            Text(statusText)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(statusColor)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.thinMaterial, in: Capsule())
    }

    private func metrics(for telemetry: HostTelemetry) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                MetricView(label: "CPU", value: RemoteInfoFormatters.percent(telemetry.cpuUsagePercent))
                MetricView(label: "LOAD", value: String(format: "%.2f", telemetry.load1))
                MetricView(label: "MEM", value: RemoteInfoFormatters.percent(telemetry.memoryUsagePercent))
            }
            GridRow {
                MetricView(label: "DISK", value: RemoteInfoFormatters.percent(telemetry.rootUsagePercent))
                MetricView(label: "UPTIME", value: RemoteInfoFormatters.uptime(telemetry.uptimeSeconds))
                MetricView(label: "SSH", value: RemoteInfoFormatters.latency(telemetry.latencySeconds))
            }
            GridRow {
                MetricView(label: "KERNEL", value: telemetry.kernelRelease)
                    .gridCellColumns(3)
            }
        }
    }

    private var statusText: String {
        if state.isRefreshing {
            return "Loading"
        }

        switch state.status {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading"
        case .online:
            return "Online"
        case .stale:
            return "Stale"
        case .offline:
            return "Offline"
        }
    }

    private var statusSymbolName: String {
        if state.isRefreshing {
            return "arrow.triangle.2.circlepath"
        }

        switch state.status {
        case .idle:
            return "circle"
        case .loading:
            return "arrow.triangle.2.circlepath"
        case .online:
            return "checkmark.circle.fill"
        case .stale:
            return "clock.fill"
        case .offline:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        if state.isRefreshing {
            return .secondary
        }

        switch state.status {
        case .idle, .loading:
            return .secondary
        case .online:
            return .green
        case .stale:
            return .orange
        case .offline:
            return .red
        }
    }
}
