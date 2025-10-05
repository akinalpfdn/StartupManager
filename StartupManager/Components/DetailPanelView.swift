import SwiftUI

struct DetailPanelView: View {
    let category: String
    let items: [any LaunchItem]
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onToggleItem: (any LaunchItem) -> Void
    let onRemoveItem: (any LaunchItem) -> Void
    let onDismissError: () -> Void

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
                    Text(category)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    List {
                        ForEach(items, id: \.path) { item in
                            LaunchItemRow(item: item) {
                                onToggleItem(item)
                            }
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
                    .scrollContentBackground(.hidden)
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
