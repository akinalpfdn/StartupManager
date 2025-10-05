import SwiftUI

struct LaunchItemRow: View {
    let item: any LaunchItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let publisher = item.publisher {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.caption2)
                        Text(publisher)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Toggle("", isOn: .constant(item.isEnabled))
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: item.isEnabled) { _ in
                        onToggle()
                    }

                ImpactIndicator(impact: item.startupImpact)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
