import Foundation
import ServiceManagement

class BackgroundActivityReader {
    static let shared = BackgroundActivityReader()

    func readBackgroundActivities() -> [BackgroundActivity] {
        var activities: [BackgroundActivity] = []

        // Read from sfltool (macOS background items manager)
        activities.append(contentsOf: readFromSFLTool())

        return activities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func readFromSFLTool() -> [BackgroundActivity] {
        var items: [BackgroundActivity] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sfltool")
        process.arguments = ["dumpbtm"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                items = parseBackgroundItems(output: output)
            }
        } catch {
            // Fallback to reading from backgrounditems database
            items = readFromBackgroundItemsDB()
        }

        return items
    }

    private func parseBackgroundItems(output: String) -> [BackgroundActivity] {
        var items: [BackgroundActivity] = []
        let lines = output.components(separatedBy: .newlines)

        var currentItem: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty && !currentItem.isEmpty {
                // End of an item
                if let name = currentItem["Name"] ?? currentItem["Label"],
                   let bundleID = currentItem["BundleIdentifier"] {

                    let enabled = currentItem["Enabled"]?.lowercased() != "false"
                    let path = currentItem["Path"] ?? currentItem["URL"] ?? ""

                    let type: BackgroundActivity.BackgroundActivityType
                    if currentItem["Type"]?.contains("Login") == true {
                        type = .loginItem
                    } else if currentItem["Type"]?.contains("Agent") == true {
                        type = .agent
                    } else {
                        type = .backgroundItem
                    }

                    items.append(BackgroundActivity(
                        name: name,
                        path: path,
                        isEnabled: enabled,
                        publisher: currentItem["Developer"],
                        startupImpact: "Low",
                        bundleIdentifier: bundleID,
                        type: type
                    ))
                }
                currentItem.removeAll()
            } else if trimmed.contains(":") {
                let components = trimmed.components(separatedBy: ":")
                if components.count >= 2 {
                    let key = components[0].trimmingCharacters(in: .whitespaces)
                    let value = components[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    currentItem[key] = value
                }
            }
        }

        return items
    }

    private func readFromBackgroundItemsDB() -> [BackgroundActivity] {
        var items: [BackgroundActivity] = []

        // Try to read from backgrounditems.btm database
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dbPath = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("com.apple.backgroundtaskmanagementagent")
            .appendingPathComponent("backgrounditems.btm")

        if FileManager.default.fileExists(atPath: dbPath.path),
           let data = try? Data(contentsOf: dbPath),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {

            if let objects = plist["$objects"] as? [Any] {
                for obj in objects {
                    if let dict = obj as? [String: Any],
                       let bundleID = dict["bundleIdentifier"] as? String ?? dict["identifier"] as? String,
                       !bundleID.isEmpty {

                        let name = dict["name"] as? String ?? bundleID.components(separatedBy: ".").last ?? bundleID
                        let path = dict["path"] as? String ?? dict["url"] as? String ?? ""
                        let enabled = dict["enabled"] as? Bool ?? true

                        items.append(BackgroundActivity(
                            name: name,
                            path: path,
                            isEnabled: enabled,
                            publisher: dict["developer"] as? String,
                            startupImpact: "Low",
                            bundleIdentifier: bundleID,
                            type: .backgroundItem
                        ))
                    }
                }
            }
        }

        return items
    }

    func toggleBackgroundActivity(_ item: BackgroundActivity) {
        // Use sfltool to enable/disable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sfltool")

        if item.isEnabled {
            process.arguments = ["remove-item", "-l", item.bundleIdentifier ?? item.name]
        } else {
            process.arguments = ["add-item", "-l", item.bundleIdentifier ?? item.name]
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to toggle background activity: \(error)")
        }
    }
}
