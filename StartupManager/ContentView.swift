import SwiftUI

struct ContentView: View {
    @StateObject private var manager = LaunchItemManager()
    @State private var selectedCategory = "Login Items"
    @State private var window: NSWindow?

    var body: some View {
        ZStack {
            WindowAccessor(window: $window)
            TransparentWindowView()
                .ignoresSafeArea()

            NavigationSplitView {
                // Step 3.2: Refactored Sidebar Component
                SidebarView(
                    selectedCategory: $selectedCategory,
                    loginItemsCount: manager.loginItems.count,
                    launchAgentsCount: manager.launchAgents.count,
                    launchDaemonsCount: manager.launchDaemons.count
                )
            } detail: {
                // Step 3.2: Refactored Detail Panel Component
                DetailPanelView(
                    category: selectedCategory,
                    items: getItems(for: selectedCategory),
                    isLoading: manager.isLoading,
                    errorMessage: manager.errorMessage,
                    onRefresh: { manager.loadAllItems() },
                    onToggleItem: { item in manager.toggleItem(item) },
                    onRemoveItem: { item in manager.removeItem(item) },
                    onDismissError: { manager.errorMessage = nil }
                )
            }
            .onAppear {
                manager.loadAllItems()
            }
        }
    }

    private func getItems(for category: String) -> [any LaunchItem] {
        switch category {
        case "Login Items":
            return manager.loginItems
        case "Launch Agents":
            return manager.launchAgents
        case "Launch Daemons":
            return manager.launchDaemons
        default:
            return []
        }
    }
}

#Preview {
    ContentView()
}