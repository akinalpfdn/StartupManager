import SwiftUI

struct SidebarView: View {
    @Binding var selectedCategory: String
    let loginItemsCount: Int
    let launchAgentsCount: Int
    let launchDaemonsCount: Int

    private let categories = [
        ("Login Items", "person.circle"),
        ("Launch Agents", "app.badge"),
        ("Launch Daemons", "gearshape.2")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Startup Items")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)

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
