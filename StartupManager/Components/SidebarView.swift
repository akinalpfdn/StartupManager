import SwiftUI

struct SidebarView: View {
    @Binding var selectedCategory: String
    let loginItemsCount: Int
    let launchAgentsCount: Int
    let launchDaemonsCount: Int
    let loginItems: [LoginItem]
    let launchAgents: [LaunchAgent]
    let launchDaemons: [LaunchDaemon]

    private let categories = [
        ("Login Items", "person.circle"),
        ("Launch Agents", "app.badge"),
        ("Launch Daemons", "gearshape.2")
    ]

    private var totalImpact: (totalTime: TimeInterval, enabledTime: TimeInterval, itemCount: Int) {
        PerformanceAnalyzer.shared.calculateTotalStartupImpact(
            loginItems: loginItems,
            launchAgents: launchAgents,
            launchDaemons: launchDaemons
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Performance Summary
            VStack(spacing: 8) {
                Text("Startup Impact")
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text(String(format: "%.1fs", totalImpact.enabledTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Text("\(totalImpact.itemCount) items enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()

            Divider()

            Text("Categories")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

            List(categories, id: \.0, selection: $selectedCategory) { category in
                HStack {
                    Image(systemName: category.1)
                        .foregroundColor(.accentColor)
                    Text(category.0)
                    Spacer()
                    Text("\(getCount(for: category.0))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 220)
    }

    private func getCount(for category: String) -> Int {
        switch category {
        case "Login Items":
            return loginItemsCount
        case "Launch Agents":
            return launchAgentsCount
        case "Launch Daemons":
            return launchDaemonsCount
        default:
            return 0
        }
    }
}
