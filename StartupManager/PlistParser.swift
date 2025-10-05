import Foundation

class PlistParser {
    // Validate plist for security - only check for malicious patterns
    static func validatePlist(_ plist: [String: Any]) -> Bool {
        // Check for suspicious executable paths (but don't require Program/ProgramArguments)
        if let program = plist["Program"] as? String {
            if program.contains("..") || program.hasPrefix("/tmp/") || program.hasPrefix("/var/tmp/") {
                return false
            }
        }

        if let programArgs = plist["ProgramArguments"] as? [String], let first = programArgs.first {
            if first.contains("..") || first.hasPrefix("/tmp/") || first.hasPrefix("/var/tmp/") {
                return false
            }
        }

        return true
    }

    static func parsePlist(at path: String) -> [String: Any]? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        // Validate plist before returning
        guard validatePlist(plist) else {
            print("Warning: Invalid or potentially malicious plist at \(path)")
            return nil
        }

        return plist
    }

    static func parseLaunchAgent(from url: URL) -> LaunchAgent? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let label = plist["Label"] as? String ?? url.lastPathComponent
        let name = label.components(separatedBy: ".").last ?? label

        // Check if agent is loaded using launchctl
        let isEnabled = isServiceLoaded(label: label)

        return LaunchAgent(
            name: name,
            path: url.path,
            isEnabled: isEnabled,
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

        // Check if daemon is loaded using launchctl
        let isEnabled = isServiceLoaded(label: label)

        return LaunchDaemon(
            name: name,
            path: url.path,
            isEnabled: isEnabled,
            publisher: plist["Program"] as? String,
            startupImpact: "High",
            label: label,
            keepAlive: keepAlive
        )
    }

    // Helper function to check if a service is loaded
    private static func isServiceLoaded(label: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", label]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            // If exit code is 0, service is loaded
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}