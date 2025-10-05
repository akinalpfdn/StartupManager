import Foundation
import ServiceManagement

class LoginItemsReader {
    static let shared = LoginItemsReader()

    // Read login items using AppleScript (most reliable method)
    func readLoginItems() -> [LoginItem] {
        var items: [LoginItem] = []

        print("Reading login items...")

        // Use AppleScript to get login items (most reliable way)
        items.append(contentsOf: readFromSystemPreferences())
        print("AppleScript returned \(items.count) items")

        // Also try legacy methods as fallback
        if items.isEmpty {
            print("Trying legacy method...")
            items.append(contentsOf: readLegacyLoginItems())
            print("Legacy method returned \(items.count) items")
        }

        return items
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
                            get the path of login item "\(item)"
                        end tell
                        """

                        var path = item
                        if let detailAppleScript = NSAppleScript(source: detailScript) {
                            let pathResult = detailAppleScript.executeAndReturnError(nil)
                            if let pathString = pathResult.stringValue {
                                path = pathString
                            }
                        }

                        items.append(LoginItem(
                            name: item,
                            path: path,
                            isEnabled: true,
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
        // Use AppleScript to toggle
        let toggleScript = """
        tell application "System Events"
            set loginItemExists to exists login item "\(item.name)"
            if loginItemExists then
                delete login item "\(item.name)"
            end if
        end tell
        """

        if let appleScript = NSAppleScript(source: toggleScript) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error = error {
                print("Error toggling login item: \(error)")
            }
        }
    }
}
