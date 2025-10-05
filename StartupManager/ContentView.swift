import SwiftUI

struct ContentView: View {
    @StateObject private var manager = LaunchItemManager()
    @State private var selectedCategory = "Login Items"
    @State private var window: NSWindow?
    @State private var searchText = ""
    @State private var selectedItems = Set<String>()
    @State private var showingBatchRemoveConfirmation = false
    @State private var showingSingleRemoveConfirmation = false
    @State private var itemToRemovePath: String?
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    @State private var showingBackupSuccess = false
    @State private var backupSuccessMessage = ""

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
                    launchDaemonsCount: manager.launchDaemons.count,
                    loginItems: manager.loginItems,
                    launchAgents: manager.launchAgents,
                    launchDaemons: manager.launchDaemons
                )
                .onChange(of: selectedCategory) { _ in
                    selectedItems.removeAll()
                    searchText = ""
                }
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
                        itemToRemovePath = item.path
                        showingSingleRemoveConfirmation = true
                    },
                    onDismissError: { manager.errorMessage = nil },
                    onBatchDisable: { batchDisableItems() },
                    onBatchRemove: { showingBatchRemoveConfirmation = true },
                    onBackup: { createBackup() },
                    onExport: { exportConfiguration() },
                    onImport: { importConfiguration() },
                    onAddLoginItem: { url in
                        LoginItemsReader.shared.addLoginItem(appURL: url)
                        manager.loadAllItems()
                    },
                    onChangePriority: { item, priority in
                        manager.changePriority(item: item, priority: priority)
                    }
                )
            }
            .onAppear {
                manager.loadAllItems()
            }
            .alert("Remove Item", isPresented: $showingSingleRemoveConfirmation) {
                Button("Cancel", role: .cancel) {
                    itemToRemovePath = nil
                }
                Button("Remove", role: .destructive) {
                    if let path = itemToRemovePath,
                       let item = filteredItems.first(where: { $0.path == path }) {
                        manager.removeItem(item)
                    }
                    itemToRemovePath = nil
                }
            } message: {
                if let path = itemToRemovePath,
                   let item = filteredItems.first(where: { $0.path == path }) {
                    Text("Are you sure you want to remove '\(item.name)'? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to remove this item? This action cannot be undone.")
                }
            }
            .alert("Remove \(selectedItems.count) Items", isPresented: $showingBatchRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove All", role: .destructive) {
                    batchRemoveItems()
                }
            } message: {
                Text("Are you sure you want to remove \(selectedItems.count) selected items? This action cannot be undone.")
            }
            .alert("Backup Created", isPresented: $showingBackupSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(backupSuccessMessage)
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

    private func createBackup() {
        do {
            let backupURL = try BackupManager.shared.createBackup(
                loginItems: manager.loginItems,
                launchAgents: manager.launchAgents,
                launchDaemons: manager.launchDaemons
            )
            manager.errorMessage = nil
            backupSuccessMessage = "Backup saved to:\n\(backupURL.path)"
            showingBackupSuccess = true
        } catch {
            manager.errorMessage = "Failed to create backup: \(error.localizedDescription)"
        }
    }

    private func exportConfiguration() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "startup_config_\(Date().timeIntervalSince1970).json"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try BackupManager.shared.exportConfiguration(
                        loginItems: manager.loginItems,
                        launchAgents: manager.launchAgents,
                        launchDaemons: manager.launchDaemons,
                        to: url
                    )
                    manager.errorMessage = nil
                } catch {
                    manager.errorMessage = "Failed to export: \(error.localizedDescription)"
                }
            }
        }
    }

    private func importConfiguration() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let config = try BackupManager.shared.loadConfiguration(from: url)
                    // TODO: Apply configuration
                    manager.errorMessage = "Import successful! Loaded \(config.launchAgents.count) agents and \(config.launchDaemons.count) daemons."
                } catch {
                    manager.errorMessage = "Failed to import: \(error.localizedDescription)"
                }
            }
        }
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