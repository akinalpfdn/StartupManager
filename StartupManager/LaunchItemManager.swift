import Foundation
import ServiceManagement

class LaunchItemManager: ObservableObject {
    @Published var loginItems: [LoginItem] = []
    @Published var launchAgents: [LaunchAgent] = []
    @Published var launchDaemons: [LaunchDaemon] = []
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

            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    private func loadLoginItems() async {
        // TODO: ServiceManagement ile login items yüklenecek
        let sampleItems = [
            LoginItem(name: "Dropbox", path: "/Applications/Dropbox.app", isEnabled: true, publisher: "Dropbox Inc.", startupImpact: "Medium"),
            LoginItem(name: "Spotify", path: "/Applications/Spotify.app", isEnabled: false, publisher: "Spotify Ltd.", startupImpact: "High")
        ]

        DispatchQueue.main.async {
            self.loginItems = sampleItems
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
            self.launchAgents = agents
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
            self.launchDaemons = daemons
        }
    }
}