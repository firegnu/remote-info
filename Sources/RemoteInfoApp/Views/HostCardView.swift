import RemoteInfoCore
import SwiftUI

struct HostCardView: View {
    let state: HostState
    let showsContainer: Bool

    private let metricColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(state: HostState, showsContainer: Bool = true) {
        self.state = state
        self.showsContainer = showsContainer
    }

    var body: some View {
        if showsContainer {
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 7) {
            header

            if let telemetry = state.telemetry {
                metrics(for: telemetry)
            }

            if case .offline(let message) = state.status {
                messageCard(message)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.host.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(state.host.sshTarget)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let telemetry = state.telemetry {
                    Text("Updated \(RemoteInfoFormatters.age(since: telemetry.collectedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            statusBadge
        }
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
        .background(statusColor.opacity(0.14), in: Capsule())
    }

    @ViewBuilder
    private func metrics(for telemetry: HostTelemetry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: metricColumns, spacing: 6) {
                detailMetricCard(
                    label: "CPU",
                    symbolName: "cpu",
                    value: RemoteInfoFormatters.processCPUUsage(telemetry.cpuUsagePercent),
                    detail: coreDetail(telemetry.cpuCoreCount),
                    chip: coreDetail(telemetry.cpuCoreCount),
                    severity: MetricSeverity.cpuUsage(telemetry.cpuUsagePercent)
                )

                detailMetricCard(
                    label: "LOAD",
                    symbolName: "speedometer",
                    value: loadValue(telemetry.load1),
                    detail: "1 min average",
                    chip: coreDetail(telemetry.cpuCoreCount),
                    severity: MetricSeverity.loadAverage(telemetry.load1, coreCount: telemetry.cpuCoreCount)
                )

                detailMetricCard(
                    label: "MEM",
                    symbolName: "memorychip",
                    value: RemoteInfoFormatters.percent(telemetry.memoryUsagePercent),
                    detail: "\(RemoteInfoFormatters.bytes(telemetry.memoryTotalBytes)) total",
                    chip: memoryChip(telemetry.memoryUsagePercent),
                    severity: MetricSeverity.capacityUsage(telemetry.memoryUsagePercent)
                )

                detailMetricCard(
                    label: "DISK",
                    symbolName: "externaldrive",
                    value: RemoteInfoFormatters.percent(telemetry.rootUsagePercent),
                    detail: "\(RemoteInfoFormatters.bytes(telemetry.rootTotalBytes)) total",
                    chip: RemoteInfoFormatters.bytes(telemetry.rootTotalBytes),
                    severity: MetricSeverity.capacityUsage(telemetry.rootUsagePercent)
                )

                detailMetricCard(
                    label: "SSH",
                    symbolName: "point.3.connected.trianglepath.dotted",
                    value: RemoteInfoFormatters.latency(telemetry.latencySeconds),
                    detail: "round trip",
                    chip: "latency",
                    severity: MetricSeverity.latency(telemetry.latencySeconds)
                )

                detailMetricCard(
                    label: "UPTIME",
                    symbolName: "clock",
                    value: RemoteInfoFormatters.uptime(telemetry.uptimeSeconds),
                    detail: telemetry.kernelRelease,
                    chip: "kernel",
                    severity: nil
                )
            }

            if let network = telemetry.network {
                networkCard(network)
            }

            if !telemetry.topProcesses.isEmpty {
                processCard(Array(telemetry.topProcesses.prefix(5)))
            }

            if telemetry.gpus.isEmpty {
                gpuUnavailableCard()
            } else {
                ForEach(telemetry.gpus) { gpu in
                    gpuCard(gpu)
                }
            }
        }
    }

    private func detailMetricCard(
        label: String,
        symbolName: String,
        value: String,
        detail: String,
        chip: String,
        severity: MetricSeverity?
    ) -> some View {
        metricCard(minHeight: 72) {
            VStack(alignment: .leading, spacing: 5) {
                metricCardHeader(label: label, symbolName: symbolName, chip: chip, severity: severity)

                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(severity?.metricColor ?? .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(detail)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private func networkCard(_ network: NetworkTelemetry) -> some View {
        let severity = MetricSeverity.networkOperstate(network.operstate)
        let locationLabel = RemoteInfoFormatters.networkLocationLabel(
            countryCode: network.publicIPCountryCode,
            region: network.publicIPRegion,
            city: network.publicIPCity
        )

        return metricCard {
            VStack(alignment: .leading, spacing: 5) {
                metricCardHeader(
                    label: "NET",
                    symbolName: "network",
                    chip: network.operstate,
                    severity: severity
                )

                Text(RemoteInfoFormatters.networkTraffic(
                    receiveBytesPerSecond: network.receiveBytesPerSecond,
                    transmitBytesPerSecond: network.transmitBytesPerSecond
                ))
                .font(.body.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        metadataChip(RemoteInfoFormatters.networkInterfaceLabel(network.interfaceName))
                        metadataChip(RemoteInfoFormatters.networkIPAddressLabel(network.publicIPAddress))
                    }

                    metadataChip(locationLabel)
                }
                .lineLimit(1)
            }
        }
    }

    private func processCard(_ processes: [ProcessTelemetry]) -> some View {
        metricCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label {
                        Text("TOP CPU")
                            .font(.callout.weight(.semibold))
                    } icon: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("CPU")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 68, alignment: .trailing)
                    Text("MEM")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 1) {
                    ForEach(processes) { process in
                        processListRow(for: process)
                    }
                }
            }
        }
    }

    private func processListRow(for process: ProcessTelemetry) -> some View {
        let severity = MetricSeverity.cpuUsage(process.cpuPercent)

        return HStack(spacing: 8) {
            Circle()
                .fill(severity.metricColor)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)

            Text(process.command)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(RemoteInfoFormatters.processCPUUsage(process.cpuPercent))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(severity.metricColor)
                .frame(width: 68, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(RemoteInfoFormatters.processMemoryUsage(process.memoryPercent))
                .font(.callout.monospacedDigit().weight(.semibold))
                .frame(width: 60, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 20)
    }

    private func gpuCard(_ gpu: GPUTelemetry) -> some View {
        let temperatureSeverity = MetricSeverity.gpuTemperature(gpu.temperatureCelsius)
        let vramSeverity = MetricSeverity.capacityUsage(gpu.memoryUsagePercent)
        let powerSeverity = MetricSeverity.gpuPowerUsage(gpu.powerUsagePercent)
        let fanSeverity = MetricSeverity.gpuFanSpeed(gpu.fanSpeedPercent)

        return metricCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(gpu.name) GPU \(gpu.index)")
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("Driver \(gpu.driverVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: "display")
                    }
                    .foregroundStyle(temperatureSeverity.metricColor)

                    Spacer(minLength: 8)

                    statusChip(
                        RemoteInfoFormatters.celsius(gpu.temperatureCelsius),
                        severity: temperatureSeverity
                    )
                }

                gpuBar(
                    label: "UTIL",
                    value: gpu.utilizationPercent,
                    valueText: RemoteInfoFormatters.percent(gpu.utilizationPercent),
                    color: MetricSeverity.normal.metricColor
                )
                gpuBar(
                    label: "VRAM",
                    value: gpu.memoryUsagePercent,
                    valueText: "\(RemoteInfoFormatters.mebibytesAsGibibytes(gpu.memoryUsedMiB)) / \(RemoteInfoFormatters.mebibytesAsGibibytes(gpu.memoryTotalMiB))",
                    color: vramSeverity.metricColor
                )

                HStack(spacing: 9) {
                    compactStat(
                        label: "POWER",
                        value: RemoteInfoFormatters.gpuPower(gpu.powerDrawWatts, limit: gpu.powerLimitWatts),
                        severity: powerSeverity
                    )
                    compactStat(
                        label: "FAN",
                        value: RemoteInfoFormatters.percent(gpu.fanSpeedPercent),
                        severity: fanSeverity
                    )
                    compactStat(
                        label: "CLOCK",
                        value: RemoteInfoFormatters.megahertzAsGigahertz(gpu.graphicsClockMHz),
                        severity: nil
                    )
                }
            }
        }
    }

    private func gpuUnavailableCard() -> some View {
        metricCard(minHeight: 76) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "display")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text("No NVIDIA telemetry")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("This host did not report GPU metrics.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                statusChip("not detected", severity: nil)
            }
        }
    }

    private func messageCard(_ message: String) -> some View {
        metricCard {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricCard<Content: View>(
        minHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(7)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.primary.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 5)
    }

    private func metricCardHeader(
        label: String,
        symbolName: String,
        chip: String,
        severity: MetricSeverity?
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Label {
                Text(label)
                    .font(.caption.weight(.semibold))
            } icon: {
                Image(systemName: symbolName)
            }
            .foregroundStyle(severity?.metricColor ?? .secondary)

            Spacer(minLength: 8)

            statusChip(chip, severity: severity)
        }
    }

    private func statusChip(_ text: String, severity: MetricSeverity?) -> some View {
        let color = severity?.metricColor ?? Color.secondary

        return Text(text)
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func metadataChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func compactStat(label: String, value: String, severity: MetricSeverity?) -> some View {
        HStack(spacing: 4) {
            if let severity {
                Circle()
                    .fill(severity.metricColor)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
            }
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(severity?.metricColor ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gpuBar(label: String, value: Double, valueText: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            ProgressView(value: boundedPercent(value), total: 100)
                .progressViewStyle(.linear)
                .tint(color)
            Text(valueText)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 112, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func boundedPercent(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        return min(max(value, 0), 100)
    }

    private func loadValue(_ value: Double) -> String {
        guard value.isFinite else {
            return "--"
        }
        return String(format: "%.2f", value)
    }

    private func coreDetail(_ coreCount: Int) -> String {
        guard coreCount > 0 else {
            return "cores unknown"
        }
        return "\(coreCount) cores"
    }

    private func memoryChip(_ percent: Double) -> String {
        "\(RemoteInfoFormatters.percent(percent)) used"
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
