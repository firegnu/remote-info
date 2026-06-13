import RemoteInfoCore
import SwiftUI

struct HostListRowView: View {
    let state: HostState
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.host.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(updatedText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    statusBadge
                }

                HStack(spacing: 5) {
                    miniMetric(label: "CPU", value: cpuText, severity: cpuSeverity)
                    miniMetric(label: "MEM", value: memoryText, severity: memorySeverity)
                    miniMetric(label: "GPU", value: gpuText, severity: gpuSeverity)
                }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 9)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.primary.opacity(0.08)
        }
        return Color.clear
    }

    private var rowBorderColor: Color {
        if isSelected {
            return Color.primary.opacity(0.18)
        }
        return Color.clear
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusColor)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(statusColor.opacity(0.12), in: Capsule())
            .lineLimit(1)
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
            return .yellow
        case .offline:
            return .red
        }
    }

    private var updatedText: String {
        guard let telemetry = state.telemetry else {
            return state.host.sshTarget
        }
        return "Updated \(RemoteInfoFormatters.age(since: telemetry.collectedAt))"
    }

    private var cpuText: String {
        guard let telemetry = state.telemetry else {
            return "--"
        }
        return RemoteInfoFormatters.processCPUUsage(telemetry.cpuUsagePercent)
    }

    private var cpuSeverity: MetricSeverity {
        guard let telemetry = state.telemetry else {
            return .unknown
        }
        return MetricSeverity.cpuUsage(telemetry.cpuUsagePercent)
    }

    private var memoryText: String {
        guard let telemetry = state.telemetry else {
            return "--"
        }
        return RemoteInfoFormatters.percent(telemetry.memoryUsagePercent)
    }

    private var memorySeverity: MetricSeverity {
        guard let telemetry = state.telemetry else {
            return .unknown
        }
        return MetricSeverity.capacityUsage(telemetry.memoryUsagePercent)
    }

    private var gpuText: String {
        guard let gpu = state.telemetry?.gpus.first else {
            return "--"
        }
        return RemoteInfoFormatters.celsius(gpu.temperatureCelsius)
    }

    private var gpuSeverity: MetricSeverity {
        guard let gpu = state.telemetry?.gpus.first else {
            return .unknown
        }
        return MetricSeverity.gpuTemperature(gpu.temperatureCelsius)
    }

    private func miniMetric(label: String, value: String, severity: MetricSeverity) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(.secondary)
                .fontWeight(.bold)

            Spacer(minLength: 2)

            Text(value)
                .foregroundStyle(severity.metricColor)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption2.monospacedDigit())
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

extension HostState {
    var displaySeverity: MetricSeverity {
        var severities: [MetricSeverity] = [statusSeverity]

        if let telemetry {
            severities.append(MetricSeverity.cpuUsage(telemetry.cpuUsagePercent))
            severities.append(MetricSeverity.loadAverage(telemetry.load1, coreCount: telemetry.cpuCoreCount))
            severities.append(MetricSeverity.capacityUsage(telemetry.memoryUsagePercent))
            severities.append(MetricSeverity.capacityUsage(telemetry.rootUsagePercent))
            severities.append(MetricSeverity.latency(telemetry.latencySeconds))

            if let network = telemetry.network {
                severities.append(MetricSeverity.networkOperstate(network.operstate))
            }

            for gpu in telemetry.gpus {
                severities.append(MetricSeverity.gpuTemperature(gpu.temperatureCelsius))
                severities.append(MetricSeverity.capacityUsage(gpu.memoryUsagePercent))
                severities.append(MetricSeverity.gpuPowerUsage(gpu.powerUsagePercent))
                severities.append(MetricSeverity.gpuFanSpeed(gpu.fanSpeedPercent))
            }
        }

        return severities.max { $0.displayPriority < $1.displayPriority } ?? .unknown
    }

    private var statusSeverity: MetricSeverity {
        if isRefreshing {
            return .unknown
        }

        switch status {
        case .online:
            return .normal
        case .stale:
            return .attention
        case .offline:
            return .critical
        case .idle, .loading:
            return .unknown
        }
    }
}

extension MetricSeverity {
    var displayPriority: Int {
        switch self {
        case .unknown:
            return 0
        case .normal:
            return 1
        case .attention:
            return 2
        case .elevated:
            return 3
        case .critical:
            return 4
        }
    }
}
