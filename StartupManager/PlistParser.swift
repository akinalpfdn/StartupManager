import Foundation

class PlistParser {
    static func parseLaunchAgent(from url: URL) -> LaunchAgent? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let label = plist["Label"] as? String ?? url.lastPathComponent
        let name = label.components(separatedBy: ".").last ?? label

        return LaunchAgent(
            name: name,
            path: url.path,
            isEnabled: true,
            publisher: plist["Program"] as? String,
            startupImpact: "Medium",
            label: label
        )
    }

    static func parseLaunchDaemon(from url: URL) -> LaunchDaemon? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let label = plist["Label"] as? String ?? url.lastPathComponent
        let name = label.components(separatedBy: ".").last ?? label
        let keepAlive = plist["KeepAlive"] as? Bool ?? false

        return LaunchDaemon(
            name: name,
            path: url.path,
            isEnabled: true,
            publisher: plist["Program"] as? String,
            startupImpact: "High",
            label: label,
            keepAlive: keepAlive
        )
    }
}