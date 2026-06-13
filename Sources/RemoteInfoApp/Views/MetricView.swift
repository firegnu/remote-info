import RemoteInfoCore
import SwiftUI

struct MetricView: View {
    let label: String
    let value: String
    let severity: MetricSeverity?
    let isStacked: Bool

    init(
        label: String,
        value: String,
        severity: MetricSeverity? = nil,
        isStacked: Bool = false
    ) {
        self.label = label
        self.value = value
        self.severity = severity
        self.isStacked = isStacked
    }

    var body: some View {
        if isStacked {
            VStack(alignment: .leading, spacing: 4) {
                labelRow
                valueText
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        } else {
            inlineBody
        }
    }

    private var inlineBody: some View {
        HStack(spacing: 6) {
            labelRow

            Spacer(minLength: 4)

            valueText
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var labelRow: some View {
        HStack(spacing: 4) {
            if let severity {
                Circle()
                    .fill(severity.metricColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var valueText: some View {
        Text(value)
            .font(valueFont)
            .fontWeight(.semibold)
            .foregroundStyle(severity?.metricColor ?? .primary)
            .lineLimit(1)
            .minimumScaleFactor(isStacked ? 0.85 : 0.7)
    }

    private var valueFont: Font {
        if isStacked {
            return .title3.monospacedDigit()
        }
        return .callout.monospacedDigit()
    }
}

extension MetricSeverity {
    var metricColor: Color {
        switch self {
        case .normal:
            return .green
        case .attention:
            return .yellow
        case .elevated:
            return .orange
        case .critical:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
