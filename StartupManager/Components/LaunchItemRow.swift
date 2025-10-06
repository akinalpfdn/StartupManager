import SwiftUI

struct LaunchItemRow: View {
    let item: any LaunchItem
    let onToggle: () -> Void

    @State private var isToggling = false

    private var performanceMetrics: PerformanceMetrics {
        PerformanceAnalyzer.shared.analyzeItem(item)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let publisher = item.publisher {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.caption2)
                            Text(publisher)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }

                    // Performance metrics
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(String(format: "%.1fs", performanceMetrics.estimatedStartupTime))
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { newValue in
                        if !isToggling {
                            isToggling = true
                            onToggle()
                            // Reset after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isToggling = false
                            }
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle())
                .disabled(isToggling)

                // Show impact indicator for Launch Agents/Daemons only (not Login Items)
                if !(item is LoginItem) {
                    ImpactIndicator(impact: item.startupImpact)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .tag(item.path)
    }
}
