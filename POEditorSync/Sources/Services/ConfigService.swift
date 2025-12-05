import Foundation
import Yams

struct ConfigService {
    private let fileSystem: FileSystemService

    init(fileSystem: FileSystemService = FileSystemService()) {
        self.fileSystem = fileSystem
    }

    func loadConfig() throws -> POEditorConfig {
        let configPath = ".poeditor.yml"
        guard fileSystem.fileExists(atPath: configPath) else {
            throw ValidationError("Configuration file not found: \(configPath)")
        }

        let configString = try fileSystem.readFile(atPath: configPath)
        return try YAMLDecoder().decode(POEditorConfig.self, from: configString)
    }

    // MARK: - Static Method (Backward Compatibility)

    static func loadConfig() throws -> POEditorConfig {
        let service = ConfigService()
        return try service.loadConfig()
    }
}
