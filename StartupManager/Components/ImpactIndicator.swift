import SwiftUI

struct ImpactIndicator: View {
    let impact: String
    let onTap: (() -> Void)?

    init(impact: String, onTap: (() -> Void)? = nil) {
        self.impact = impact
        self.onTap = onTap
    }

    var body: some View {
        if let onTap = onTap {
            Menu {
                Button("Low") { onTap() }
                Button("Medium") { onTap() }
                Button("High") { onTap() }
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
