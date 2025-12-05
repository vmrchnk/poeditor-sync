import Foundation

struct XcodeService {
    private let fileSystem: FileSystemService
    private let logger: Logger

    init(fileSystem: FileSystemService = FileSystemService(), logger: Logger = Logger()) {
        self.fileSystem = fileSystem
        self.logger = logger
    }

    // MARK: - Instance Methods

    /// Detect available languages from Xcode project
    /// Automatically detects whether project uses .xcstrings (modern) or .lproj directories (legacy)
    func detectLanguages(projectPath: String) throws -> [String] {
        let projectURL = URL(fileURLWithPath: projectPath)
        let projectDir = projectURL.deletingLastPathComponent().path

        // Check if project uses .xcstrings files (modern approach)
        if let xcstringsLanguages = try? detectLanguagesFromXCStrings(projectDir: projectDir),
           !xcstringsLanguages.isEmpty {
            logger.verbose("📦 Using .xcstrings format")
            logger.verbose("Languages: \(xcstringsLanguages.joined(separator: ", "))")
            return sortLanguages(xcstringsLanguages)
        }

        // Fallback to .lproj directories (legacy approach)
        let lprojLanguages = try fileSystem.findLanguageDirectories(inPath: projectDir)

        guard !lprojLanguages.isEmpty else {
            throw ValidationError("No .xcstrings files or .lproj directories found in project. Please ensure your project has localized resources.")
        }

        logger.verbose("📁 Using .lproj directories format")
        logger.verbose("Languages: \(lprojLanguages.joined(separator: ", "))")
        return sortLanguages(lprojLanguages)
    }

    /// Detect languages from .xcstrings files in project
    private func detectLanguagesFromXCStrings(projectDir: String) throws -> [String] {
        // Find all .xcstrings files in the project
        let findProcess = Process()
        findProcess.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        findProcess.arguments = [projectDir, "-name", "*.xcstrings", "-type", "f"]

        let pipe = Pipe()
        findProcess.standardOutput = pipe

        try findProcess.run()
        findProcess.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        let xcstringsFiles = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }

        guard !xcstringsFiles.isEmpty else {
            return []
        }

        // Parse all .xcstrings files and collect unique languages
        var allLanguages = Set<String>()

        for filePath in xcstringsFiles {
            if let languages = try? parseLanguagesFromXCStrings(filePath: filePath) {
                allLanguages.formUnion(languages)
            }
        }

        // Filter out unwanted language codes
        let filteredLanguages = allLanguages.filter { lang in
            // Exclude Base and mul (multilingual) as they are not actual language codes
            lang != "Base" && lang != "mul"
        }

        return Array(filteredLanguages)
    }

    /// Parse languages from a single .xcstrings file
    private func parseLanguagesFromXCStrings(filePath: String) throws -> Set<String> {
        let content = try fileSystem.readFile(atPath: filePath)
        guard let data = content.data(using: .utf8) else {
            return []
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let strings = json?["strings"] as? [String: Any] else {
            return []
        }

        var languages = Set<String>()

        // Iterate through all string entries
        for (_, stringData) in strings {
            guard let stringDict = stringData as? [String: Any],
                  let localizations = stringDict["localizations"] as? [String: Any] else {
                continue
            }

            // Collect all language codes from localizations
            for (languageCode, _) in localizations {
                languages.insert(languageCode)
            }
        }

        return languages
    }

    /// Sort languages with 'en' first
    private func sortLanguages(_ languages: [String]) -> [String] {
        return languages.sorted { lang1, lang2 in
            if lang1 == "en" { return true }
            if lang2 == "en" { return false }
            return lang1 < lang2
        }
    }

    /// Export localizations from Xcode project
    func exportLocalizations(config: POEditorConfig, languages: [String], to path: String) throws {
        logger.info("📤 Starting localization export...")
        logger.verbose("Project type: \(config.isWorkspace ? "workspace" : "project")")
        logger.verbose("Project path: \(config.projectPath)")
        logger.verbose("Export path: \(path)")
        logger.verbose("Languages: \(languages.joined(separator: ", "))")

        var arguments = ["-exportLocalizations"]

        // Use -workspace or -project depending on config
        if config.isWorkspace {
            arguments.append(contentsOf: ["-workspace", config.projectPath])
        } else {
            arguments.append(contentsOf: ["-project", config.projectPath])
        }

        arguments.append(contentsOf: ["-localizationPath", path])

        // Add each language
        for language in languages {
            arguments.append("-exportLanguage")
            arguments.append(language)
        }

        logger.info("🔧 Running xcodebuild with arguments:")
        logger.info("   \(arguments.joined(separator: " "))")
        logger.info("⏳ This may take a few minutes...")

        try Process.run("/usr/bin/xcodebuild", arguments: arguments, verbose: config.verbose)

        logger.success("✅ Export completed successfully")
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

        var arguments = ["-importLocalizations"]

        // Use -workspace or -project depending on config
        if config.isWorkspace {
            arguments.append(contentsOf: ["-workspace", config.projectPath])
        } else {
            arguments.append(contentsOf: ["-project", config.projectPath])
        }

        arguments.append(contentsOf: ["-localizationPath", xliffPath])

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
