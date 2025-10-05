import SwiftUI

struct ContentView: View {
    @StateObject private var manager = LaunchItemManager()
    @State private var selectedCategory = "Login Items"
    @State private var window: NSWindow?
    @State private var searchText = ""
    @State private var selectedItems = Set<String>()
    @State private var showingBatchRemoveConfirmation = false
    @State private var itemToRemove: (any LaunchItem)?

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
                // Step 3.3: Interactive Features - Search & Filter
                DetailPanelView(
                    category: selectedCategory,
                    items: filteredItems,
                    isLoading: manager.isLoading,
                    errorMessage: manager.errorMessage,
                    searchText: $searchText,
                    selectedItems: $selectedItems,
                    onRefresh: { manager.loadAllItems() },
                    onToggleItem: { item in manager.toggleItem(item) },
                    onRemoveItem: { item in
                        itemToRemove = item
                    },
                    onDismissError: { manager.errorMessage = nil },
                    onBatchDisable: { batchDisableItems() },
                    onBatchRemove: { showingBatchRemoveConfirmation = true }
                )
            }
            .onAppear {
                manager.loadAllItems()
            }
            .alert("Remove Item", isPresented: .constant(itemToRemove != nil), presenting: itemToRemove) { item in
                Button("Cancel", role: .cancel) {
                    itemToRemove = nil
                }
                Button("Remove", role: .destructive) {
                    manager.removeItem(item)
                    itemToRemove = nil
                }
            } message: { item in
                Text("Are you sure you want to remove '\(item.name)'? This action cannot be undone.")
            }
            .alert("Remove \(selectedItems.count) Items", isPresented: $showingBatchRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove All", role: .destructive) {
                    batchRemoveItems()
                }
            } message: {
                Text("Are you sure you want to remove \(selectedItems.count) selected items? This action cannot be undone.")
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

    private var filteredItems: [any LaunchItem] {
        let items = getItems(for: selectedCategory)
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            item.path.localizedCaseInsensitiveContains(searchText) ||
            (item.publisher?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func batchDisableItems() {
        for itemPath in selectedItems {
            if let item = filteredItems.first(where: { $0.path == itemPath }) {
                manager.toggleItem(item)
            }
        }
        selectedItems.removeAll()
    }

    private func batchRemoveItems() {
        // Güvenlik kontrolü: System dosyalarını kontrol et
        let systemPaths = selectedItems.filter { path in
            path.hasPrefix("/System/") || path.hasPrefix("/Library/LaunchDaemons")
        }

        if !systemPaths.isEmpty {
            manager.errorMessage = "Cannot remove system files. Only user-level items can be removed."
            return
        }

        for itemPath in selectedItems {
            if let item = filteredItems.first(where: { $0.path == itemPath }) {
                manager.removeItem(item)
            }
        }
        selectedItems.removeAll()
    }
}

#Preview {
    ContentView()
}