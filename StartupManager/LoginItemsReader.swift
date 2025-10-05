import Foundation
import ServiceManagement

class LoginItemsReader {
    static let shared = LoginItemsReader()

    // Local database to persist login items state
    private let userDefaults = UserDefaults.standard
    private let loginItemsKey = "SavedLoginItems"

    // Store login item state locally
    private struct SavedLoginItem: Codable {
        let name: String
        let path: String
        let isEnabled: Bool
        let publisher: String?
    }

    private func saveLoginItems(_ items: [LoginItem]) {
        let savedItems = items.map { SavedLoginItem(name: $0.name, path: $0.path, isEnabled: $0.isEnabled, publisher: $0.publisher) }
        if let encoded = try? JSONEncoder().encode(savedItems) {
            userDefaults.set(encoded, forKey: loginItemsKey)
        }
    }

    private func loadSavedLoginItems() -> [SavedLoginItem] {
        guard let data = userDefaults.data(forKey: loginItemsKey),
              let items = try? JSONDecoder().decode([SavedLoginItem].self, from: data) else {
            return []
        }
        return items
    }

    // Read login items using AppleScript (most reliable method)
    func readLoginItems() -> [LoginItem] {
        print("Reading login items...")

        // Load saved items from local database
        let savedItems = loadSavedLoginItems()
        var savedDict = Dictionary(uniqueKeysWithValues: savedItems.map { ($0.name, $0) })

        // Read current items from system
        var systemItems: [LoginItem] = []
        systemItems.append(contentsOf: readFromSystemPreferences())
        print("AppleScript returned \(systemItems.count) items")

        if systemItems.isEmpty {
            print("Trying legacy method...")
            systemItems.append(contentsOf: readLegacyLoginItems())
            print("Legacy method returned \(systemItems.count) items")
        }

        // Merge: Update saved items with system data (new items)
        for systemItem in systemItems {
            if savedDict[systemItem.name] == nil {
                // New item from system, add it
                savedDict[systemItem.name] = SavedLoginItem(
                    name: systemItem.name,
                    path: systemItem.path,
                    isEnabled: systemItem.isEnabled,
                    publisher: systemItem.publisher
                )
            }
        }

        // Convert saved items back to LoginItem array
        let mergedItems = savedDict.values.map { saved in
            LoginItem(
                name: saved.name,
                path: saved.path,
                isEnabled: saved.isEnabled,
                publisher: saved.publisher,
                startupImpact: "Low"
            )
        }

        // Save merged state
        saveLoginItems(mergedItems)

        return mergedItems
    }

    // Read legacy login items from ~/Library/Preferences
    private func readLegacyLoginItems() -> [LoginItem] {
        var items: [LoginItem] = []

        // Try to read from LSSharedFileList (deprecated but still works)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let loginItemsPlist = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("com.apple.backgroundtaskmanagementagent")
            .appendingPathComponent("backgrounditems.btm")

        print("Checking for plist at: \(loginItemsPlist.path)")

        if FileManager.default.fileExists(atPath: loginItemsPlist.path) {
            print("Plist file exists")
            if let data = try? Data(contentsOf: loginItemsPlist),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {

                print("Plist parsed, keys: \(plist.keys)")

                // Parse background items
                if let itemsDict = plist["$objects"] as? [[String: Any]] {
                    print("Found \(itemsDict.count) objects")
                    for dict in itemsDict {
                        if let name = dict["Name"] as? String,
                           let url = dict["URL"] as? String {
                            items.append(LoginItem(
                                name: name,
                                path: url,
                                isEnabled: true,
                                publisher: nil,
                                startupImpact: "Low"
                            ))
                        }
                    }
                }
            }
        } else {
            print("Plist file does not exist")
        }

        return items
    }

    // Read from System Preferences
    private func readFromSystemPreferences() -> [LoginItem] {
        var items: [LoginItem] = []

        // Use AppleScript to get login items (most reliable way)
        let script = """
        tell application "System Events"
            get the name of every login item
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)

            if let error = error {
                print("AppleScript error: \(error)")
                print("Error description: \(error[NSAppleScript.errorMessage] ?? "Unknown")")
                return items
            }

            print("AppleScript result type: \(result.descriptorType)")

            if let descriptor = result.coerce(toDescriptorType: typeAEList) {
                print("Successfully coerced to list, items: \(descriptor.numberOfItems)")
                for i in 1...descriptor.numberOfItems {
                    if let item = descriptor.atIndex(i)?.stringValue {
                        // Get more details for each item
                        let detailScript = """
                        tell application "System Events"
                            set itemPath to path of login item "\(item)"
                            set itemHidden to hidden of login item "\(item)"
                            return {itemPath, itemHidden}
                        end tell
                        """

                        var path = item
                        var isEnabled = true
                        if let detailAppleScript = NSAppleScript(source: detailScript) {
                            var detailError: NSDictionary?
                            let pathResult = detailAppleScript.executeAndReturnError(&detailError)

                            if detailError == nil, let listDescriptor = pathResult.coerce(toDescriptorType: typeAEList) {
                                if listDescriptor.numberOfItems >= 2 {
                                    path = listDescriptor.atIndex(1)?.stringValue ?? item
                                    // Hidden = true means disabled
                                    isEnabled = !(listDescriptor.atIndex(2)?.booleanValue ?? false)
                                }
                            }
                        }

                        items.append(LoginItem(
                            name: item,
                            path: path,
                            isEnabled: isEnabled,
                            publisher: nil,
                            startupImpact: "Low"
                        ))
                    }
                }
            } else {
                print("Could not coerce to typeAEList")
            }
        }

        return items
    }

    // Toggle login item on/off
    func toggleLoginItem(_ item: LoginItem) {
        print("Toggling login item: \(item.name), current isEnabled: \(item.isEnabled)")

        if item.isEnabled {
            // Disable: DELETE from login items (won't launch at startup)
            let disableScript = """
            tell application "System Events"
                set loginItemExists to exists login item "\(item.name)"
                if loginItemExists then
                    delete login item "\(item.name)"
                end if
            end tell
            """

            if let appleScript = NSAppleScript(source: disableScript) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)

                if let error = error {
                    print("Error disabling login item: \(error)")
                } else {
                    print("Successfully disabled (removed from system): \(item.name)")
                    // Update local database: keep item but mark as disabled
                    updateLocalItemState(name: item.name, isEnabled: false)
                }
            }
        } else {
            // Enable: ADD to login items (will launch at startup)
            let enableScript = """
            tell application "System Events"
                make login item at end with properties {path:"\(item.path)", hidden:false}
            end tell
            """

            if let appleScript = NSAppleScript(source: enableScript) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)

                if let error = error {
                    print("Error enabling login item: \(error)")
                } else {
                    print("Successfully enabled (added to system): \(item.name)")
                    // Update local database: mark as enabled
                    updateLocalItemState(name: item.name, isEnabled: true)
                }
            }
        }
    }

    private func updateLocalItemState(name: String, isEnabled: Bool) {
        var savedItems = loadSavedLoginItems()
        if let index = savedItems.firstIndex(where: { $0.name == name }) {
            savedItems[index] = SavedLoginItem(
                name: savedItems[index].name,
                path: savedItems[index].path,
                isEnabled: isEnabled,
                publisher: savedItems[index].publisher
            )
            if let encoded = try? JSONEncoder().encode(savedItems) {
                userDefaults.set(encoded, forKey: loginItemsKey)
            }
        }
    }

    // Add new app to login items
    func addLoginItem(appURL: URL) {
        print("Adding login item: \(appURL.path)")

        let appName = appURL.deletingPathExtension().lastPathComponent

        // Add to system via AppleScript
        let addScript = """
        tell application "System Events"
            make login item at end with properties {path:"\(appURL.path)", hidden:false}
        end tell
        """

        if let appleScript = NSAppleScript(source: addScript) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error = error {
                print("Error adding login item: \(error)")
            } else {
                print("Successfully added to system: \(appName)")
                // Add to local database
                var savedItems = loadSavedLoginItems()
                let newItem = SavedLoginItem(
                    name: appName,
                    path: appURL.path,
                    isEnabled: true,
                    publisher: nil
                )
                savedItems.append(newItem)
                if let encoded = try? JSONEncoder().encode(savedItems) {
                    userDefaults.set(encoded, forKey: loginItemsKey)
                }
            }
        }
    }

    // Change priority (move up/down in launch order)
    func changePriority(item: LoginItem, direction: PriorityDirection) {
        print("Changing priority for \(item.name) - direction: \(direction)")

        // Delete from current position
        let deleteScript = """
        tell application "System Events"
            delete login item "\(item.name)"
        end tell
        """

        // Re-add at different position
        let position = direction == .high ? "beginning" : "end"
        let addScript = """
        tell application "System Events"
            make login item at \(position) with properties {path:"\(item.path)", hidden:false}
        end tell
        """

        // Execute delete then add
        if let deleteAppleScript = NSAppleScript(source: deleteScript),
           let addAppleScript = NSAppleScript(source: addScript) {

            var error: NSDictionary?
            deleteAppleScript.executeAndReturnError(&error)

            if error == nil {
                addAppleScript.executeAndReturnError(&error)
                if let error = error {
                    print("Error changing priority: \(error)")
                } else {
                    print("Successfully changed priority for: \(item.name)")
                }
            }
        }
    }

    enum PriorityDirection {
        case high  // Move to beginning (higher priority)
        case low   // Move to end (lower priority)
    }
}
