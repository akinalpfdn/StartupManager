import SwiftUI

struct ImpactIndicator: View {
    let impact: String
    let onChangePriority: ((String) -> Void)?

    init(impact: String, onChangePriority: ((String) -> Void)? = nil) {
        self.impact = impact
        self.onChangePriority = onChangePriority
    }

    var body: some View {
        if let onChangePriority = onChangePriority {
            Menu {
                Button("Low") { onChangePriority("Low") }
                Button("Medium") { onChangePriority("Medium") }
                Button("High") { onChangePriority("High") }
            } label: {
                HStack(spacing: 4) {
                    Text(impact)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(impactColor, in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else {
            Text(impact)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(impactColor, in: Capsule())
        }
    }

    private var impactColor: Color {
        switch impact {
        case "Low":
            return .green
        case "Medium":
            return .orange
        case "High":
            return .red
        default:
            return .gray
        }
    }
}
