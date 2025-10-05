import SwiftUI

struct ImpactIndicator: View {
    let impact: String

    var body: some View {
        Text(impact)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(impactColor, in: Capsule())
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
