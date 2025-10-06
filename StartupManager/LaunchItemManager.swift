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

                // Check if it's a system file - requires admin privileges
                if item.path.hasPrefix("/System/") || item.path.hasPrefix("/Library/") {
                    await MainActor.run {
                        self.errorMessage = "System files require admin privileges.\n\nTo toggle system Launch Agents/Daemons, use Terminal:\n\nsudo launchctl \(item.isEnabled ? "unload" : "load") \(item.path)\n\nFile: \(item.path)"
                    }
                    return
                }

                // LaunchAgent veya LaunchDaemon için launchctl ile enable/disable
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/launchctl")

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

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
                    // Capture error output
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    let stdOutput = String(data: outputData, encoding: .utf8) ?? ""

                    let combinedOutput = (errorOutput + stdOutput).trimmingCharacters(in: .whitespacesAndNewlines)

                    let errorMsg: String
                    if !combinedOutput.isEmpty {
                        errorMsg = "launchctl error (exit code \(process.terminationStatus)):\n\n\(combinedOutput)\n\nFile: \(item.path)"
                    } else {
                        errorMsg = "launchctl failed with exit code \(process.terminationStatus)\n\nFile: \(item.path)"
                    }

                    throw NSError(domain: "LaunchItemManager", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
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

                    let errorPipe = Pipe()
                    unloadProcess.standardError = errorPipe

                    try? unloadProcess.run()
                    unloadProcess.waitUntilExit()

                    // Check if unload failed
                    if unloadProcess.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                        if !errorOutput.isEmpty {
                            throw NSError(domain: "LaunchItemManager", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "Failed to unload before removal:\n\n\(errorOutput)\n\nFile: \(item.path)"
                            ])
                        }
                    }
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
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refreshItems() {
        loadAllItems()
    }
}