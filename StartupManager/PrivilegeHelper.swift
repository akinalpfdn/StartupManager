import Foundation
import Security

class PrivilegeHelper {
    static let shared = PrivilegeHelper()

    // Check if the app has admin privileges
    func hasAdminPrivileges() -> Bool {
        return geteuid() == 0
    }

    // Request admin privileges using AuthorizationServices
    func requestAdminPrivileges(for reason: String) -> Bool {
        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(
            name: kAuthorizationRightExecute,
            valueLength: 0,
            value: nil,
            flags: 0
        )
        var authRights = AuthorizationRights(count: 1, items: &authItem)

        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        let status = AuthorizationCreate(
            &authRights,
            nil,
            flags,
            &authRef
        )

        if status == errAuthorizationSuccess {
            if let authRef = authRef {
                AuthorizationFree(authRef, [])
            }
            return true
        }

        return false
    }

    // Execute command with admin privileges
    func executeWithPrivileges(command: String, arguments: [String]) throws {
        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(
            name: kAuthorizationRightExecute,
            valueLength: 0,
            value: nil,
            flags: 0
        )
        var authRights = AuthorizationRights(count: 1, items: &authItem)

        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights]

        let status = AuthorizationCreate(
            &authRights,
            nil,
            flags,
            &authRef
        )

        guard status == errAuthorizationSuccess, let authRef = authRef else {
            throw NSError(
                domain: "PrivilegeHelper",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Failed to obtain authorization"]
            )
        }

        defer {
            AuthorizationFree(authRef, [])
        }

        // Use regular Process with sudo for simplicity
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [command] + arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "PrivilegeHelper",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Command failed with status \(process.terminationStatus)"]
            )
        }
    }

    // Check if path requires admin privileges
    func requiresAdminPrivileges(path: String) -> Bool {
        // System paths require admin
        if path.hasPrefix("/System/") ||
           path.hasPrefix("/Library/LaunchDaemons/") ||
           path.hasPrefix("/Library/LaunchAgents/") {
            return true
        }

        // Check file permissions
        let fileManager = FileManager.default
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let posixPerms = attrs[.posixPermissions] as? NSNumber else {
            return false
        }

        // If owner is root (uid 0), requires admin
        if let ownerID = attrs[.ownerAccountID] as? NSNumber, ownerID.intValue == 0 {
            return true
        }

        return false
    }
}
