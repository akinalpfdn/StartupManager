import Foundation
import ServiceManagement

class LaunchItemManager: ObservableObject {
    @Published var loginItems: [LoginItem] = []
    @Published var launchAgents: [LaunchAgent] = []
    @Published var launchDaemons: [LaunchDaemon] = []
    @Published var backgroundActivities: [BackgroundActivity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let launchAgentsPaths = [
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
        URL(fileURLWithPath: "/Library/LaunchAgents"),
        URL(fileURLWithPath: "/System/Library/LaunchAgents")
    ]

    private let launchDaemonsPaths = [
        URL(fileURLWithPath: "/Library/LaunchDaemons"),
        URL(fileURLWithPath: "/System/Library/LaunchDaemons")
    ]

    func loadAllItems() {
        isLoading = true
        errorMessage = nil

        Task {
            await loadLoginItems()
            await loadLaunchAgents()
            await loadLaunchDaemons()
            await loadBackgroundActivities()

            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    private func loadLoginItems() async {
        let items = LoginItemsReader.shared.readLoginItems()

        DispatchQueue.main.async {
            self.loginItems = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func loadLaunchAgents() async {
        var agents: [LaunchAgent] = []

        for path in launchAgentsPaths {
            if let items = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
                .filter({ $0.pathExtension == "plist" }) {

                for item in items {
                    if let agent = PlistParser.parseLaunchAgent(from: item) {
                        agents.append(agent)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.launchAgents = agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func loadLaunchDaemons() async {
        var daemons: [LaunchDaemon] = []

        for path in launchDaemonsPaths {
            if let items = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
                .filter({ $0.pathExtension == "plist" }) {

                for item in items {
                    if let daemon = PlistParser.parseLaunchDaemon(from: item) {
                        daemons.append(daemon)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.launchDaemons = daemons.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func loadBackgroundActivities() async {
        let items = BackgroundActivityReader.shared.readBackgroundActivities()

        DispatchQueue.main.async {
            self.backgroundActivities = items
        }
    }

    func toggleItem(_ item: any LaunchItem) {
        Task {
            do {
                // Check if it's a login item
                if item is LoginItem {
                    LoginItemsReader.shared.toggleLoginItem(item as! LoginItem)
                    await MainActor.run {
                        self.errorMessage = nil
                        // Update local state only
                        if let index = self.loginItems.firstIndex(where: { $0.path == item.path }) {
                            self.loginItems[index] = LoginItem(
                                name: self.loginItems[index].name,
                                path: self.loginItems[index].path,
                                isEnabled: !self.loginItems[index].isEnabled,
                                publisher: self.loginItems[index].publisher,
                                startupImpact: self.loginItems[index].startupImpact
                            )
                        }
                    }
                    return
                }

                // Check if it's a background activity
                if let bgActivity = item as? BackgroundActivity {
                    BackgroundActivityReader.shared.toggleBackgroundActivity(bgActivity)
                    await MainActor.run {
                        self.errorMessage = nil
                        // Update local state only
                        if let index = self.backgroundActivities.firstIndex(where: { $0.path == item.path }) {
                            self.backgroundActivities[index] = BackgroundActivity(
                                name: bgActivity.name,
                                path: bgActivity.path,
                                isEnabled: !bgActivity.isEnabled,
                                publisher: bgActivity.publisher,
                                startupImpact: bgActivity.startupImpact,
                                bundleIdentifier: bgActivity.bundleIdentifier,
                                type: bgActivity.type
                            )
                        }
                    }
                    return
                }

                // LaunchAgent veya LaunchDaemon için launchctl ile enable/disable
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/launchctl")

                if item.isEnabled {
                    // Disable: unload
                    process.arguments = ["unload", item.path]
                } else {
                    // Enable: load
                    process.arguments = ["load", item.path]
                }

                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    await MainActor.run {
                        self.errorMessage = nil
                        // Update local state only
                        if let agent = item as? LaunchAgent,
                           let index = self.launchAgents.firstIndex(where: { $0.path == item.path }) {
                            self.launchAgents[index] = LaunchAgent(
                                name: agent.name,
                                path: agent.path,
                                isEnabled: !agent.isEnabled,
                                publisher: agent.publisher,
                                startupImpact: agent.startupImpact,
                                label: agent.label
                            )
                        } else if let daemon = item as? LaunchDaemon,
                                  let index = self.launchDaemons.firstIndex(where: { $0.path == item.path }) {
                            self.launchDaemons[index] = LaunchDaemon(
                                name: daemon.name,
                                path: daemon.path,
                                isEnabled: !daemon.isEnabled,
                                publisher: daemon.publisher,
                                startupImpact: daemon.startupImpact,
                                label: daemon.label,
                                keepAlive: daemon.keepAlive
                            )
                        }
                    }
                } else {
                    throw NSError(domain: "LaunchItemManager", code: Int(process.terminationStatus))
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to toggle item: \(error.localizedDescription). You may need admin privileges."
                }
            }
        }
    }

    func removeItem(_ item: any LaunchItem) {
        Task {
            // Güvenlik kontrolü: System dosyalarını koruma
            if item.path.hasPrefix("/System/") || item.path.hasPrefix("/Library/LaunchDaemons") {
                await MainActor.run {
                    self.errorMessage = "Cannot remove system files. This item is protected."
                }
                return
            }

            do {
                // Önce unload et
                if item.isEnabled {
                    let unloadProcess = Process()
                    unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                    unloadProcess.arguments = ["unload", item.path]
                    try? unloadProcess.run()
                    unloadProcess.waitUntilExit()
                }

                // Sonra dosyayı sil
                try FileManager.default.removeItem(atPath: item.path)

                await MainActor.run {
                    self.errorMessage = nil
                    // Reload data to reflect changes
                    self.loadAllItems()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to remove item: \(error.localizedDescription). You may need admin privileges."
                }
            }
        }
    }

    func refreshItems() {
        loadAllItems()
    }
}