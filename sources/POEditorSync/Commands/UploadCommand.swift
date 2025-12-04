import Foundation
import ArgumentParser

struct UploadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "upload",
        abstract: "Upload source strings to POEditor"
    )

    @Flag(name: .long, help: "Delete terms in POEditor that are not in the uploaded file")
    var deleteOtherKeys: Bool = false

    @Flag(name: .long, help: "Initial upload - only upload source language (en) to create terms")
    var initial: Bool = false

    @Option(name: [.short, .long], help: "Specific language(s) to upload (e.g., --language uk --language pt-br)")
    var language: [String] = []

    mutating func run() throws {
        let config = try ConfigService.loadConfig()
        let logger = config.createLogger()
        let fileSystem = FileSystemService()

        let languages = try prepareLanguages(config: config, logger: logger)
        let tempDir = try exportLocalizations(
            languages: languages,
            config: config,
            fileSystem: fileSystem,
            logger: logger
        )
        defer {
            try? fileSystem.removeItem(at: tempDir)
        }

        try displayExportStatistics(
            languages: languages,
            tempDir: tempDir,
            logger: logger
        )

        if initial {
            try performInitialSetup(
                languages: languages,
                tempDir: tempDir,
                config: config,
                logger: logger
            )
        } else {
            try performNormalUpload(
                languages: languages,
                tempDir: tempDir,
                config: config,
                logger: logger
            )
        }
    }

    // MARK: - Private Methods

    private mutating func prepareLanguages(config: POEditorConfig, logger: Logger) throws -> [String] {
        var languages = try config.getLanguages()

        if !language.isEmpty {
            let requestedLanguages = Set(language)
            let availableLanguages = Set(languages)
            let invalidLanguages = requestedLanguages.subtracting(availableLanguages)

            if !invalidLanguages.isEmpty {
                throw ValidationError("The following requested languages are not in your Xcode project: \(invalidLanguages.sorted().joined(separator: ", ")). Available languages: \(availableLanguages.sorted().joined(separator: ", "))")
            }

            languages = languages.filter { requestedLanguages.contains($0) }
            logger.info("🎯 Filtering to specific languages: \(language.joined(separator: ", "))\n")
        }

        return languages
    }

    private func exportLocalizations(
        languages: [String],
        config: POEditorConfig,
        fileSystem: FileSystemService,
        logger: Logger
    ) throws -> URL {
        logger.verbose("Exporting localizations from Xcode project...")
        logger.verbose("  Project: \(config.projectPath)")
        logger.verbose("  Languages: \(languages.joined(separator: ", "))")

        let tempDir = try fileSystem.createTemporaryDirectory(prefix: Constants.exportDirectoryPrefix)
        try XcodeService.exportLocalizations(config: config, languages: languages, to: tempDir.path)

        return tempDir
    }

    private func displayExportStatistics(
        languages: [String],
        tempDir: URL,
        logger: Logger
    ) throws {
        let stats = try XcodeService.getExportStatistics(from: tempDir.path, languages: languages)
        logger.section("📊 Export Statistics")
        logger.info("   Total languages: \(languages.count)")
        for (lang, count) in stats.sorted(by: { $0.key < $1.key }) {
            logger.info("   • \(lang): \(count) terms")
        }
    }

    private func performInitialSetup(
        languages: [String],
        tempDir: URL,
        config: POEditorConfig,
        logger: Logger
    ) throws {
        logger.section("🔄 Initial Setup Mode")

        try addLanguagesToPOEditor(languages: languages, config: config, logger: logger)

        logger.progress("\n Waiting \(Int(Constants.apiRateLimitDelay)) seconds before uploading translations...")
        Thread.sleep(forTimeInterval: Constants.apiRateLimitDelay)

        try uploadTranslations(
            languages: languages,
            tempDir: tempDir,
            stepPrefix: "\nStep 2: ",
            config: config,
            logger: logger
        )

        logger.success("\nInitial setup complete!")
    }

    private func addLanguagesToPOEditor(
        languages: [String],
        config: POEditorConfig,
        logger: Logger
    ) throws {
        logger.info("Step 1: Adding languages to POEditor project...")
        for (index, lang) in languages.enumerated() {
            logger.info("  [\(index + 1)/\(languages.count)] Adding \(lang)...")
            try POEditorAPIService.addLanguage(config: config, language: lang)

            if index < languages.count - 1 {
                logger.progress("Waiting \(Int(Constants.languageAddDelay)) seconds...")
                Thread.sleep(forTimeInterval: Constants.languageAddDelay)
            }
        }
    }

    private func performNormalUpload(
        languages: [String],
        tempDir: URL,
        config: POEditorConfig,
        logger: Logger
    ) throws {
        logger.section("📤 Uploading Translations to POEditor")

        try uploadTranslations(
            languages: languages,
            tempDir: tempDir,
            stepPrefix: nil,
            config: config,
            logger: logger
        )

        logger.section("Upload complete!")
    }

    private func uploadTranslations(
        languages: [String],
        tempDir: URL,
        stepPrefix: String?,
        config: POEditorConfig,
        logger: Logger
    ) throws {
        if let prefix = stepPrefix {
            logger.info("\(prefix)Uploading translations to POEditor...\n")
        }

        for (index, lang) in languages.enumerated() {
            logger.info("[\(index + 1)/\(languages.count)] Uploading \(lang)...")
            try POEditorAPIService.uploadTranslations(
                config: config,
                language: lang,
                exportPath: tempDir.path,
                syncTerms: deleteOtherKeys,
                updating: config.upload?.updating ?? "terms_translations"
            )

            if index < languages.count - 1 {
                logger.progress("Waiting \(Int(Constants.apiRateLimitDelay)) seconds (POEditor rate limit)...\n")
                Thread.sleep(forTimeInterval: Constants.apiRateLimitDelay)
            }
        }
    }
}
