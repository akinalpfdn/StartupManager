import SwiftUI

struct DetailPanelView: View {
    let category: String
    let items: [any LaunchItem]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var searchText: String
    @Binding var selectedItems: Set<String>
    let onRefresh: () -> Void
    let onToggleItem: (any LaunchItem) -> Void
    let onRemoveItem: (any LaunchItem) -> Void
    let onDismissError: () -> Void
    let onBatchDisable: () -> Void
    let onBatchRemove: () -> Void
    let onBackup: () -> Void
    let onExport: () -> Void
    let onImport: () -> Void
    let onAddLoginItem: (URL) -> Void
    let onChangePriority: (any LaunchItem, String) -> Void

    @State private var isTargeted = false

    var body: some View {
        if isLoading {
            VStack {
                ProgressView("Loading startup items...")
                Text("Scanning system directories...")
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 600, minHeight: 400)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("StartupManager")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Spacer()

                    Menu {
                        Button {
                            onBackup()
                        } label: {
                            Label("Create Backup", systemImage: "archivebox")
                        }
                        Button {
                            onExport()
                        } label: {
                            Label("Export...", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            onImport()
                        } label: {
                            Label("Import...", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("Backup", systemImage: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)

                    Button {
                        onRefresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()

                // Error Message
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.primary)
                        Spacer()
                        Button("Dismiss") {
                            onDismissError()
                        }
                        .buttonStyle(.glass)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Content
                if !category.isEmpty {
                    // Search Bar & Batch Actions
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search items...", text: $searchText)
                                .textFieldStyle(.plain)
                                .onChange(of: searchText) { _ in
                                    selectedItems.removeAll()
                                }
                        }
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                        if !selectedItems.isEmpty {
                            Text("\(selectedItems.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                onBatchDisable()
                            } label: {
                                Label("Disable", systemImage: "power")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                onBatchRemove()
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    HStack {
                        Text(category)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if category == "Login Items" {
                            Spacer()
                            Text("Drag & drop apps here to add")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    List(selection: $selectedItems) {
                        ForEach(items, id: \.path) { item in
                            LaunchItemRow(item: item, onToggle: {
                                onToggleItem(item)
                            }, onChangePriority: !(item is LoginItem) ? { priority in
                                onChangePriority(item, priority)
                            } : nil)
                            .tag(item.path)
                            .contextMenu {
                                Button {
                                    onToggleItem(item)
                                } label: {
                                    Label("Toggle Enabled", systemImage: "power")
                                }
                                Button(role: .destructive) {
                                    onRemoveItem(item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                Button {
                                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                } label: {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                            }
                        }
                    }
                    .id(searchText + category)
                    .scrollContentBackground(.hidden)
                    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                        // Only allow drops for Login Items category
                        guard category == "Login Items" else { return false }

                        for provider in providers {
                            _ = provider.loadObject(ofClass: URL.self) { url, error in
                                if let url = url, url.pathExtension == "app" {
                                    DispatchQueue.main.async {
                                        onAddLoginItem(url)
                                    }
                                }
                            }
                        }
                        return true
                    }
                    .overlay {
                        if isTargeted && category == "Login Items" {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.accentColor, lineWidth: 3, antialiased: true)
                                .background(Color.accentColor.opacity(0.1))
                        }
                    }
                } else {
                    Text("Select a category to view startup items")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
}
