import Foundation

struct StartupConfiguration: Codable {
    let timestamp: Date
    let loginItems: [String]
    let launchAgents: [LaunchAgentBackup]
    let launchDaemons: [LaunchDaemonBackup]

    struct LaunchAgentBackup: Codable {
        let path: String
        let isEnabled: Bool
    }

    struct LaunchDaemonBackup: Codable {
        let path: String
        let isEnabled: Bool
    }
}

class BackupManager {
    static let shared = BackupManager()

    private let backupDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backupDir = appSupport.appendingPathComponent("StartupManager/Backups")
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        return backupDir
    }()

    func createBackup(loginItems: [LoginItem], launchAgents: [LaunchAgent], launchDaemons: [LaunchDaemon]) throws -> URL {
        let config = StartupConfiguration(
            timestamp: Date(),
            loginItems: loginItems.map { $0.path },
            launchAgents: launchAgents.map { .init(path: $0.path, isEnabled: $0.isEnabled) },
            launchDaemons: launchDaemons.map { .init(path: $0.path, isEnabled: $0.isEnabled) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(config)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "backup_\(formatter.string(from: Date())).json"
        let fileURL = backupDirectory.appendingPathComponent(filename)

        try data.write(to: fileURL)
        return fileURL
    }

    func exportConfiguration(loginItems: [LoginItem], launchAgents: [LaunchAgent], launchDaemons: [LaunchDaemon], to url: URL) throws {
        let config = StartupConfiguration(
            timestamp: Date(),
            loginItems: loginItems.map { $0.path },
            launchAgents: launchAgents.map { .init(path: $0.path, isEnabled: $0.isEnabled) },
            launchDaemons: launchDaemons.map { .init(path: $0.path, isEnabled: $0.isEnabled) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(config)
        try data.write(to: url)
    }

    func loadConfiguration(from url: URL) throws -> StartupConfiguration {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StartupConfiguration.self, from: data)
    }

    func listBackups() -> [URL] {
        let files = try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
        return files?.filter { $0.pathExtension == "json" }.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        } ?? []
    }

    func deleteBackup(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
