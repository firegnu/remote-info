import RemoteInfoCore
import SwiftUI

struct FleetSummaryView: View {
    let hostStates: [HostState]

    var body: some View {
        HStack(spacing: 8) {
            summaryCell(label: "ONLINE", value: "\(onlineCount)/\(hostStates.count)")
            summaryCell(label: "LOAD", value: maxLoadText)
            summaryCell(label: "ERRORS", value: "\(errorCount)")
        }
    }

    private var onlineCount: Int {
        hostStates.filter { $0.status == .online || $0.status == .stale }.count
    }

    private var errorCount: Int {
        hostStates.filter {
            if case .offline = $0.status {
                return true
            }
            return false
        }.count
    }

    private var maxLoadText: String {
        let loads = hostStates.compactMap { $0.telemetry?.load1 }
        guard let maxLoad = loads.max() else {
            return "--"
        }
        return String(format: "%.2f", maxLoad)
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
