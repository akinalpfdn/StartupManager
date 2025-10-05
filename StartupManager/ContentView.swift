import SwiftUI

struct ContentView: View {
    @StateObject private var manager = LaunchItemManager()
    @State private var selectedCategory = "Login Items"

    var body: some View {
        NavigationSplitView {
            // Step 3.1: Sidebar with Liquid Glass
            VStack(spacing: 0) {
                Text("Startup Items")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)

                List(["Login Items", "Launch Agents", "Launch Daemons"], id: \.self, selection: $selectedCategory) { category in
                    HStack {
                        Image(systemName: getCategoryIcon(for: category))
                            .foregroundColor(.accentColor)
                        Text(category)
                        Spacer()
                        Text("\(getItemCount(for: category))")
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
        } detail: {
            if manager.isLoading {
                VStack {
                    ProgressView("Loading startup items...")
                    Text("Scanning system directories...")
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 600, minHeight: 400)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("StartupManager")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            manager.loadAllItems()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding()

                    if let errorMessage = manager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .foregroundColor(.primary)
                            Spacer()
                            Button("Dismiss") {
                                manager.errorMessage = nil
                            }
                            .buttonStyle(.glass)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    if !selectedCategory.isEmpty {
                        Text(selectedCategory)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        List {
                            ForEach(getItems(for: selectedCategory), id: \.path) { item in
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
                                                manager.toggleItem(item)
                                            }

                                        Text(item.startupImpact)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(getImpactColor(item.startupImpact), in: Capsule())
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .contextMenu {
                                    Button {
                                        manager.toggleItem(item)
                                    } label: {
                                        Label("Toggle Enabled", systemImage: "power")
                                    }
                                    Button(role: .destructive) {
                                        manager.removeItem(item)
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
        .background(.thinMaterial)
        .onAppear {
            manager.loadAllItems()
        }
    }

    private func getItemCount(for category: String) -> Int {
        switch category {
        case "Login Items":
            return manager.loginItems.count
        case "Launch Agents":
            return manager.launchAgents.count
        case "Launch Daemons":
            return manager.launchDaemons.count
        default:
            return 0
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

    private func getImpactColor(_ impact: String) -> Color {
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

    private func getCategoryIcon(for category: String) -> String {
        switch category {
        case "Login Items":
            return "person.circle"
        case "Launch Agents":
            return "app.badge"
        case "Launch Daemons":
            return "gearshape.2"
        default:
            return "questionmark.circle"
        }
    }
}

#Preview {
    ContentView()
}