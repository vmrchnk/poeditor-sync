import Foundation
import ArgumentParser

struct DownloadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download translations from POEditor and import to Xcode"
    )

    @Option(name: [.short, .long], help: "Specific language(s) to download (e.g., --language uk --language pt-br)")
    var language: [String] = []

    mutating func run() throws {
        let config = try ConfigService.loadConfig()
        let logger = config.createLogger()
        let fileSystem = FileSystemService()

        let poeditorLanguages = try fetchAndDisplayAvailableLanguages(config: config, logger: logger)
        let sourceLanguage = try determineSourceLanguage(from: poeditorLanguages, logger: logger)
        let missingInProject = try validateLanguagesWithXcode(
            poeditorLanguages: poeditorLanguages,
            config: config,
            logger: logger
        )

        let downloadDir = Constants.downloadDirectory
        try fileSystem.ensureDirectoryExists(atPath: downloadDir)

        let languagesToDownload = try prepareLanguagesToDownload(
            poeditorLanguages: poeditorLanguages,
            sourceLanguage: sourceLanguage,
            config: config,
            logger: logger
        )

        try downloadTranslations(
            languages: languagesToDownload,
            sourceLanguage: sourceLanguage,
            downloadDir: downloadDir,
            config: config,
            logger: logger
        )

        try importLocalizations(
            languages: languagesToDownload,
            downloadDir: downloadDir,
            config: config,
            logger: logger
        )

        displayCompletionSummary(
            languagesToDownload: languagesToDownload,
            missingInProject: missingInProject,
            downloadDir: downloadDir,
            fileSystem: fileSystem,
            logger: logger
        )
    }

    // MARK: - Private Methods

    private func fetchAndDisplayAvailableLanguages(config: POEditorConfig, logger: Logger) throws -> [POEditorLanguage] {
        logger.info("🔍 Checking available languages in POEditor...")
        let poeditorLanguages = try POEditorAPIService.listLanguages(config: config)

        logger.section("📋 Available Languages in POEditor")
        for lang in poeditorLanguages.sorted(by: { $0.code < $1.code }) {
            let percentageStr = String(format: "%.1f%%", lang.percentage)
            logger.info("  • \(lang.code) (\(lang.name)): \(lang.translations) terms, \(percentageStr) translated")
        }

        return poeditorLanguages
    }

    private func determineSourceLanguage(from languages: [POEditorLanguage], logger: Logger) throws -> String {
        guard let sourceLanguageObj = languages.max(by: { $0.translations < $1.translations }) else {
            throw ValidationError("No languages found in POEditor project")
        }
        logger.info("\n🔍 Auto-detected source language: \(sourceLanguageObj.code) (\(sourceLanguageObj.translations) terms)")
        return sourceLanguageObj.code
    }

    private func validateLanguagesWithXcode(
        poeditorLanguages: [POEditorLanguage],
        config: POEditorConfig,
        logger: Logger
    ) throws -> Set<String> {
        let xcodeLanguages = try config.getLanguages()
        let localLanguagesSet = Set(xcodeLanguages)
        let poeditorLanguageCodes = Set(poeditorLanguages.map { $0.code })
        let missingInPOEditor = localLanguagesSet.subtracting(poeditorLanguageCodes)
        let missingInProject = poeditorLanguageCodes.subtracting(localLanguagesSet)

        if !missingInPOEditor.isEmpty {
            logger.warning("Languages in Xcode but NOT in POEditor:")
            for lang in missingInPOEditor.sorted() {
                logger.warning("   • \(lang)")
            }
            logger.info(" Consider adding these languages to POEditor.\n")
        }

        if !missingInProject.isEmpty {
            logger.warning("\n Languages in POEditor but NOT in Xcode:")
            for lang in missingInProject.sorted() {
                logger.info("   • \(lang)")
            }
            logger.info("   These will be automatically added by xcodebuild during import.\n")
        }

        if missingInPOEditor.isEmpty && missingInProject.isEmpty {
            logger.success("\nAll POEditor languages are in your Xcode project\n")
        }

        return missingInProject
    }

    private mutating func prepareLanguagesToDownload(
        poeditorLanguages: [POEditorLanguage],
        sourceLanguage: String,
        config: POEditorConfig,
        logger: Logger
    ) throws -> [String] {
        var languagesToDownload = poeditorLanguages
            .map { $0.code }
            .filter { $0 != sourceLanguage }

        if !language.isEmpty {
            languagesToDownload = try filterByRequestedLanguages(
                languagesToDownload: languagesToDownload,
                sourceLanguage: sourceLanguage,
                config: config,
                logger: logger
            )
        }

        return languagesToDownload
    }

    private mutating func filterByRequestedLanguages(
        languagesToDownload: [String],
        sourceLanguage: String,
        config: POEditorConfig,
        logger: Logger
    ) throws -> [String] {
        let requestedLanguages = Set(language)
        var availableLanguages = Set(languagesToDownload)
        let localLanguagesSet = Set(try config.getLanguages())
        let missingInPOEditor = requestedLanguages.subtracting(availableLanguages).subtracting([sourceLanguage])

        if !missingInPOEditor.isEmpty {
            let languagesInProject = missingInPOEditor.filter { localLanguagesSet.contains($0) }
            let completelyInvalid = missingInPOEditor.subtracting(languagesInProject)

            if !completelyInvalid.isEmpty {
                throw ValidationError("The following requested languages are not in POEditor or Xcode project: \(completelyInvalid.sorted().joined(separator: ", ")). Available in POEditor: \(availableLanguages.sorted().joined(separator: ", ")), Available in Xcode: \(localLanguagesSet.sorted().joined(separator: ", "))")
            }

            if !languagesInProject.isEmpty {
                try addMissingLanguagesToPOEditor(languagesInProject, config: config, logger: logger)
                availableLanguages.formUnion(languagesInProject)
            }
        }

        var filtered = languagesToDownload.filter { requestedLanguages.contains($0) }
        filtered.append(contentsOf: requestedLanguages.filter { !filtered.contains($0) && $0 != sourceLanguage })

        if filtered.isEmpty {
            throw ValidationError("No valid languages to download. Available languages: \(availableLanguages.sorted().joined(separator: ", "))")
        }

        logger.info("🎯 Filtering to specific languages: \(language.joined(separator: ", "))\n")
        return filtered
    }

    private func addMissingLanguagesToPOEditor(
        _ languages: Set<String>,
        config: POEditorConfig,
        logger: Logger
    ) throws {
        logger.info("\n➕ Adding missing languages to POEditor...")
        let sortedLanguages = languages.sorted()
        for (index, lang) in sortedLanguages.enumerated() {
            logger.info("  [\(index + 1)/\(sortedLanguages.count)] Adding \(lang)...")
            try POEditorAPIService.addLanguage(config: config, language: lang)

            if index < sortedLanguages.count - 1 {
                logger.progress("Waiting \(Int(Constants.languageAddDelay)) seconds...")
                Thread.sleep(forTimeInterval: Constants.languageAddDelay)
            }
        }
        logger.success("Languages added successfully!\n")
    }

    private func downloadTranslations(
        languages: [String],
        sourceLanguage: String,
        downloadDir: String,
        config: POEditorConfig,
        logger: Logger
    ) throws {
        logger.section("📥 Downloading Translations from POEditor")
        logger.info("   Source language (skipped): \(sourceLanguage)")
        logger.info("   Languages to download: \(languages.count)\n")

        for (index, lang) in languages.enumerated() {
            logger.info("[\(index + 1)/\(languages.count)] Processing \(lang)...")
            try POEditorAPIService.downloadTranslations(
                config: config,
                language: lang,
                referenceLanguage: sourceLanguage,
                downloadPath: downloadDir
            )

            if index < languages.count - 1 {
                logger.progress("Waiting \(Int(Constants.downloadDelay)) seconds...\n")
                Thread.sleep(forTimeInterval: Constants.downloadDelay)
            }
        }
    }

    private func importLocalizations(
        languages: [String],
        downloadDir: String,
        config: POEditorConfig,
        logger: Logger
    ) throws {
        logger.section("📦 Importing Localizations into Xcode Project")

        for (index, lang) in languages.enumerated() {
            logger.info("[\(index + 1)/\(languages.count)] Importing \(lang)...")
            try XcodeService.importLocalization(config: config, language: lang, from: downloadDir)
        }
    }

    private func displayCompletionSummary(
        languagesToDownload: [String],
        missingInProject: Set<String>,
        downloadDir: String,
        fileSystem: FileSystemService,
        logger: Logger
    ) {
        logger.success("\nAll operations completed successfully!")
        logger.info("Languages processed: \(languagesToDownload.joined(separator: ", "))")

        if !missingInProject.isEmpty {
            logger.info("\n🎉 New languages added to your Xcode project:")
            for lang in missingInProject.sorted() {
                logger.info("   • \(lang)")
            }
        }

        logger.info("\n🧹 Cleaning up temporary files...")
        try? fileSystem.removeItem(atPath: downloadDir)
        logger.success("Removed \(downloadDir)/")
    }
}
