import Foundation
import ServiceManagement
import AppKit

class BackgroundActivityReader {
    static let shared = BackgroundActivityReader()

    func readBackgroundActivities() -> [BackgroundActivity] {
        var activities: [BackgroundActivity] = []

        // Try to read from backgrounditems.btm database
        activities.append(contentsOf: readFromBackgroundItemsDB())

        // Deduplicate by bundle identifier
        var seen = Set<String>()
        activities = activities.filter { item in
            let key = item.bundleIdentifier ?? item.path
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        return activities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func readFromBackgroundItemsDB() -> [BackgroundActivity] {
        var items: [BackgroundActivity] = []

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dbPath = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("com.apple.backgroundtaskmanagementagent")
            .appendingPathComponent("backgrounditems.btm")

        // Check if we have permission to read the file
        guard FileManager.default.fileExists(atPath: dbPath.path) else {
            return items
        }

        guard FileManager.default.isReadableFile(atPath: dbPath.path) else {
            // Request Full Disk Access
            DispatchQueue.main.async {
                self.showFullDiskAccessAlert()
            }
            return items
        }

        // Try to parse the plist
        guard let data = try? Data(contentsOf: dbPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let objects = plist["$objects"] as? [Any] else {
            return items
        }

        // Parse NSKeyedArchiver format
        var containers: [[String: Any]] = []

        for obj in objects {
            if let dict = obj as? [String: Any],
               let className = (dict["$class"] as? [String: Any])?["$classname"] as? String ?? dict["$classname"] as? String,
               className == "BackgroundItemContainer" || className.contains("Container") {
                containers.append(dict)
            }
        }

        // Extract items from containers
        for container in containers {
            if let bookmark = extractBookmarkInfo(from: container, objects: objects) {
                items.append(BackgroundActivity(
                    name: bookmark.name,
                    path: bookmark.path,
                    isEnabled: bookmark.isEnabled,
                    publisher: bookmark.publisher,
                    startupImpact: "Low",
                    bundleIdentifier: bookmark.bundleID,
                    type: .backgroundItem
                ))
            }
        }

        return items
    }

    private func extractBookmarkInfo(from container: [String: Any], objects: [Any]) -> (name: String, path: String, isEnabled: Bool, bundleID: String?, publisher: String?)? {
        // This is a simplified parser - NSKeyedArchiver is complex
        // Extract what we can from the bookmark data

        if let bookmarkRef = container["bookmark"],
           let bookmarkIndex = (bookmarkRef as? [String: Any])?["value"] as? Int,
           bookmarkIndex < objects.count,
           let bookmarkDict = objects[bookmarkIndex] as? [String: Any],
           let dataRef = bookmarkDict["data"],
           let dataIndex = (dataRef as? [String: Any])?["value"] as? Int,
           dataIndex < objects.count,
           let bookmarkData = objects[dataIndex] as? Data {

            // Try to resolve bookmark to URL
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) {
                let name = url.deletingPathExtension().lastPathComponent
                let bundleID = Bundle(url: url)?.bundleIdentifier

                return (
                    name: name,
                    path: url.path,
                    isEnabled: true,
                    bundleID: bundleID,
                    publisher: nil
                )
            }
        }

        return nil
    }

    private func showFullDiskAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "StartupManager needs Full Disk Access to read Background Items.\n\n1. Open System Settings → Privacy & Security → Full Disk Access\n2. Add StartupManager to the list\n3. Restart the app"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open System Settings
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        }
    }

    func toggleBackgroundActivity(_ item: BackgroundActivity) {
        // Background items can't be easily toggled programmatically
        // Show alert to user
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Manual Action Required"
            alert.informativeText = "Background Items must be toggled in System Settings.\n\nGo to: System Settings → General → Login Items → Background Items"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            }
        }
    }

    // Check if we have Full Disk Access
    func hasFullDiskAccess() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let testPath = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("com.apple.backgroundtaskmanagementagent")
            .appendingPathComponent("backgrounditems.btm")

        return FileManager.default.isReadableFile(atPath: testPath.path)
    }
}
