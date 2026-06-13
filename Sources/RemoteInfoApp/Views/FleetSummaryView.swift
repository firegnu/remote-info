import RemoteInfoCore
import SwiftUI

struct FleetSummaryView: View {
    let hostStates: [HostState]

    var body: some View {
        HStack(spacing: 7) {
            summaryChip(label: "Online", value: "\(onlineCount)", color: .green)
            summaryChip(label: "Stale", value: "\(staleCount)", color: .yellow)
            summaryChip(label: "Offline", value: "\(offlineCount)", color: .red)
        }
    }

    private var onlineCount: Int {
        hostStates.filter { $0.status == .online }.count
    }

    private var staleCount: Int {
        hostStates.filter { $0.status == .stale }.count
    }

    private var offlineCount: Int {
        hostStates.filter {
            if case .offline = $0.status {
                return true
            }
            return false
        }.count
    }

    private func summaryChip(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .lineLimit(1)
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(.thinMaterial, in: Capsule())
    }
}
