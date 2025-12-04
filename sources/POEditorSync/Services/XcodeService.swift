import Foundation

struct XcodeService {
    private let fileSystem: FileSystemService
    private let logger: Logger

    init(fileSystem: FileSystemService = FileSystemService(), logger: Logger = Logger()) {
        self.fileSystem = fileSystem
        self.logger = logger
    }

    // MARK: - Instance Methods

    /// Detect available languages from Xcode project by scanning .lproj directories
    func detectLanguages(projectPath: String) throws -> [String] {
        let projectURL = URL(fileURLWithPath: projectPath)
        let projectDir = projectURL.deletingLastPathComponent().path

        let languages = try fileSystem.findLanguageDirectories(inPath: projectDir)

        guard !languages.isEmpty else {
            throw ValidationError("No .lproj directories found in project. Please ensure your project has localized resources.")
        }

        // Sort languages, putting 'en' first if present
        return languages.sorted { lang1, lang2 in
            if lang1 == "en" { return true }
            if lang2 == "en" { return false }
            return lang1 < lang2
        }
    }

    /// Export localizations from Xcode project
    func exportLocalizations(config: POEditorConfig, languages: [String], to path: String) throws {
        var arguments = [
            "-exportLocalizations",
            "-project", config.projectPath,
            "-localizationPath", path
        ]

        // Add each language
        for language in languages {
            arguments.append("-exportLanguage")
            arguments.append(language)
        }

        try Process.run("/usr/bin/xcodebuild", arguments: arguments, verbose: config.verbose)
    }

    /// Get export statistics from XLIFF files
    func getExportStatistics(from path: String, languages: [String]) throws -> [String: Int] {
        var stats: [String: Int] = [:]

        for language in languages {
            let xliffPath = "\(path)/\(language).xcloc/\(Constants.localizedContentsPath)/\(language)\(Constants.xliffExtension)"

            guard fileSystem.fileExists(atPath: xliffPath) else {
                stats[language] = 0
                continue
            }

            let content = try fileSystem.readFile(atPath: xliffPath)

            // Count <trans-unit> elements
            let pattern = "<trans-unit"
            let count = content.components(separatedBy: pattern).count - 1
            stats[language] = count
        }

        return stats
    }

    /// Import localizations into Xcode project
    func importLocalization(config: POEditorConfig, language: String, from path: String) throws {
        let xliffPath = "\(path)/\(language)\(Constants.xliffExtension)"

        guard fileSystem.fileExists(atPath: xliffPath) else {
            logger.warning("  XLIFF file not found at: \(xliffPath)")
            return
        }

        logger.verbose("  📂 Source: \(xliffPath)")

        let arguments = [
            "-importLocalizations",
            "-project", config.projectPath,
            "-localizationPath", xliffPath
        ]

        try Process.run("/usr/bin/xcodebuild", arguments: arguments, verbose: config.verbose)
        logger.success("  Imported \(language)")
    }
}

// MARK: - Static Methods (Backward Compatibility)

extension XcodeService {
    static func detectLanguages(projectPath: String) throws -> [String] {
        let service = XcodeService()
        return try service.detectLanguages(projectPath: projectPath)
    }

    static func exportLocalizations(config: POEditorConfig, languages: [String], to path: String) throws {
        let service = XcodeService()
        try service.exportLocalizations(config: config, languages: languages, to: path)
    }

    static func getExportStatistics(from path: String, languages: [String]) throws -> [String: Int] {
        let service = XcodeService()
        return try service.getExportStatistics(from: path, languages: languages)
    }

    static func importLocalization(config: POEditorConfig, language: String, from path: String) throws {
        let service = XcodeService()
        try service.importLocalization(config: config, language: language, from: path)
    }
}
