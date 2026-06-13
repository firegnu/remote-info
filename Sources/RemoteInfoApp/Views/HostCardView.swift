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

    @ViewBuilder
    private func metrics(for telemetry: HostTelemetry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

            if telemetry.network != nil || !telemetry.topProcesses.isEmpty {
                activityPanel(for: telemetry)
            }

            ForEach(telemetry.gpus) { gpu in
                gpuPanel(for: gpu)
            }
        }
    }

    private func activityPanel(for telemetry: HostTelemetry) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider()

            Text("Activity")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let network = telemetry.network {
                networkRow(for: network)
            }

            if !telemetry.topProcesses.isEmpty {
                processRow(for: Array(telemetry.topProcesses.prefix(3)))
            }
        }
    }

    private func networkRow(for network: NetworkTelemetry) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                activityLabel("NET")
                networkIdentity(for: network)
                Spacer(minLength: 8)
                networkMetric(label: "RX", value: RemoteInfoFormatters.bytesPerSecond(network.receiveBytesPerSecond))
                networkMetric(label: "TX", value: RemoteInfoFormatters.bytesPerSecond(network.transmitBytesPerSecond))
                networkMetric(label: "ERR", value: "\(network.errorCount + network.dropCount)")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    activityLabel("NET")
                    networkIdentity(for: network)
                    Spacer(minLength: 8)
                    networkMetric(label: "ERR", value: "\(network.errorCount + network.dropCount)")
                }
                HStack(spacing: 10) {
                    networkMetric(label: "RX", value: RemoteInfoFormatters.bytesPerSecond(network.receiveBytesPerSecond))
                    networkMetric(label: "TX", value: RemoteInfoFormatters.bytesPerSecond(network.transmitBytesPerSecond))
                }
                .padding(.leading, 38)
            }
        }
    }

    private func processRow(for processes: [ProcessTelemetry]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                activityLabel("CPU")
                ForEach(processes) { process in
                    processText(for: process)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                activityLabel("CPU")
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(processes) { process in
                        processText(for: process)
                    }
                }
            }
        }
    }

    private func activityLabel(_ label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 30, alignment: .leading)
            .lineLimit(1)
    }

    private func networkIdentity(for network: NetworkTelemetry) -> some View {
        HStack(spacing: 4) {
            Text(network.interfaceName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(network.operstate)
                .font(.caption2)
                .foregroundStyle(network.operstate == "up" ? .green : .secondary)
                .lineLimit(1)
        }
    }

    private func networkMetric(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func processText(for process: ProcessTelemetry) -> some View {
        Text("\(process.command) \(RemoteInfoFormatters.percent(process.cpuPercent))")
            .font(.caption.monospacedDigit().weight(.semibold))
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(0.75)
    }

    private func gpuPanel(for gpu: GPUTelemetry) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider()

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(gpu.name) GPU \(gpu.index)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("Driver \(gpu.driverVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(RemoteInfoFormatters.celsius(gpu.temperatureCelsius))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            gpuBar(
                label: "UTIL",
                value: gpu.utilizationPercent,
                valueText: RemoteInfoFormatters.percent(gpu.utilizationPercent)
            )
            gpuBar(
                label: "VRAM",
                value: gpu.memoryUsagePercent,
                valueText: "\(RemoteInfoFormatters.mebibytesAsGibibytes(gpu.memoryUsedMiB)) / \(RemoteInfoFormatters.mebibytesAsGibibytes(gpu.memoryTotalMiB))"
            )

            Grid(horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    MetricView(
                        label: "POWER",
                        value: "\(RemoteInfoFormatters.watts(gpu.powerDrawWatts)) / \(RemoteInfoFormatters.watts(gpu.powerLimitWatts))"
                    )
                    MetricView(label: "FAN", value: RemoteInfoFormatters.percent(gpu.fanSpeedPercent))
                    MetricView(label: "CLOCK", value: RemoteInfoFormatters.megahertzAsGigahertz(gpu.graphicsClockMHz))
                }
            }
        }
    }

    private func gpuBar(label: String, value: Double, valueText: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)
            ProgressView(value: boundedPercent(value), total: 100)
                .progressViewStyle(.linear)
            Text(valueText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(width: 86, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func boundedPercent(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        return min(max(value, 0), 100)
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
