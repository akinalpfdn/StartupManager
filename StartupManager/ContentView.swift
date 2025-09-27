import SwiftUI

struct ContentView: View {
    @StateObject private var manager = LaunchItemManager()
    @State private var selectedCategory = "Login Items"

    var body: some View {
        NavigationSplitView {
            VStack {
                Text("Startup Items")
                    .font(.headline)
                    .padding()
                List(["Login Items", "Launch Agents", "Launch Daemons"], id: \.self, selection: $selectedCategory) { category in
                    HStack {
                        Text(category)
                        Spacer()
                        Text("\(getItemCount(for: category))")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 200)
        } detail: {
            if manager.isLoading {
                VStack {
                    ProgressView("Loading startup items...")
                    Text("Scanning system directories...")
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 600, minHeight: 400)
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Text("StartupManager")
                            .font(.largeTitle)
                        Spacer()
                        Button("Refresh") {
                            manager.loadAllItems()
                        }
                    }
                    .padding()

                    if let errorMessage = manager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .foregroundColor(.orange)
                            Spacer()
                            Button("Dismiss") {
                                manager.errorMessage = nil
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }

                    if !selectedCategory.isEmpty {
                        Text(selectedCategory)
                            .font(.title2)
                            .padding(.horizontal)

                        List {
                            ForEach(getItems(for: selectedCategory), id: \.path) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.headline)
                                        Text(item.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let publisher = item.publisher {
                                            Text(publisher)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    Spacer()

                                    HStack {
                                        Toggle("", isOn: .constant(item.isEnabled))
                                            .toggleStyle(SwitchToggleStyle())
                                            .onChange(of: item.isEnabled) { _ in
                                                manager.toggleItem(item)
                                            }

                                        Text(item.startupImpact)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(getImpactColor(item.startupImpact))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                            .font(.caption)
                                    }
                                }
                                .padding(.vertical, 2)
                                .contextMenu {
                                    Button("Toggle Enabled") {
                                        manager.toggleItem(item)
                                    }
                                    Button("Remove", role: .destructive) {
                                        manager.removeItem(item)
                                    }
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                    }
                                }
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
}

#Preview {
    ContentView()
}