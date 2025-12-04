import Foundation

// MARK: - POEditor Language Model

struct POEditorLanguage {
    let name: String
    let code: String
    let translations: Int
    let percentage: Double
    let updated: String?
}

// MARK: - POEditor API Service

struct POEditorAPIService {
    private let networkClient: NetworkClient
    private let fileSystem: FileSystemService
    private let logger: Logger

    init(config: POEditorConfig, fileSystem: FileSystemService = FileSystemService(), logger: Logger? = nil) {
        self.networkClient = POEditorNetworkClient(config: config, logger: logger)
        self.fileSystem = fileSystem
        self.logger = logger ?? config.createLogger()
    }

    // MARK: - Public Methods

    /// List available languages in POEditor project
    func listLanguages() throws -> [POEditorLanguage] {
        let endpoint = POEditorEndpoint.listLanguages
        let data = try networkClient.execute(endpoint)
        let apiResponse = try POEditorAPIResponse(data: data)

        guard apiResponse.isSuccess else {
            throw ValidationError("POEditor API error: \(apiResponse.message)")
        }

        guard let result = apiResponse.result,
              let languagesArray = result["languages"] as? [[String: Any]] else {
            throw ValidationError("Failed to parse languages list from POEditor")
        }

        return languagesArray.compactMap { langDict in
            guard let code = langDict["code"] as? String,
                  let name = langDict["name"] as? String,
                  let translations = langDict["translations"] as? Int,
                  let percentage = langDict["percentage"] as? Double else {
                return nil
            }

            let updated = langDict["updated"] as? String
            return POEditorLanguage(
                name: name,
                code: code,
                translations: translations,
                percentage: percentage,
                updated: updated
            )
        }
    }

    /// Add a language to POEditor project
    func addLanguage(_ language: String) throws {
        logger.verbose("    Adding language '\(language)' to POEditor...")

        let endpoint = POEditorEndpoint.addLanguage(language: language)
        let data = try networkClient.execute(endpoint)
        let apiResponse = try POEditorAPIResponse(data: data)

        if apiResponse.isSuccess {
            logger.success("    \(apiResponse.message)")
        } else if apiResponse.status == "fail" {
            // Language might already exist - that's okay
            if apiResponse.message.contains("already") {
                logger.info("    ℹ️  Language '\(language)' already exists")
            } else {
                logger.warning("    \(apiResponse.message)")
            }
        }
    }

    /// Upload translations to POEditor
    func uploadTranslations(
        language: String,
        exportPath: String,
        syncTerms: Bool,
        updating: String
    ) throws {
        let xliffPath = "\(exportPath)/\(language).xcloc/\(Constants.localizedContentsPath)/\(language)\(Constants.xliffExtension)"

        guard fileSystem.fileExists(atPath: xliffPath) else {
            logger.warning("Skipping \(language): XLIFF file not found")
            return
        }

        logger.verbose("Uploading \(language) to POEditor...")
        logger.verbose("  File: \(xliffPath)")

        // Prepare additional parameters
        var additionalParams: [String: String] = [:]

        if networkClient.config.upload?.overwrite ?? false {
            additionalParams["overwrite"] = "1"
        }

        if syncTerms || (networkClient.config.upload?.syncTerms ?? false) {
            additionalParams["sync_terms"] = "1"
        }

        logger.verbose("  Parameters: updating=\(updating), overwrite=\(additionalParams["overwrite"] ?? "0"), sync_terms=\(additionalParams["sync_terms"] ?? "0")")

        // Load file data
        let fileData = try fileSystem.readData(atPath: xliffPath)
        logger.verbose("  File size: \(String(format: "%.1f", Double(fileData.count) / 1024.0)) KB")

        // Execute multipart request
        let endpoint = POEditorEndpoint.uploadTranslations(language: language, updating: updating)
        let data = try networkClient.executeMultipart(
            endpoint,
            fileData: fileData,
            fileName: "\(language)\(Constants.xliffExtension)",
            mimeType: "application/x-xliff+xml",
            additionalParameters: additionalParams
        )

        let apiResponse = try POEditorAPIResponse(data: data)

        guard apiResponse.isSuccess else {
            throw ValidationError("POEditor API error for \(language): \(apiResponse.message)")
        }

        printUploadResults(for: language, response: apiResponse)
    }

    /// Download translations from POEditor
    func downloadTranslations(
        language: String,
        referenceLanguage: String,
        downloadPath: String
    ) throws {
        // Determine reference language and filters
        let refLang = language != referenceLanguage ? referenceLanguage : nil
        let filters = language != referenceLanguage ? networkClient.config.download?.filters : nil

        if let refLang = refLang {
            logger.verbose("  Reference language: \(refLang)")
        }
        if let filters = filters, !filters.isEmpty {
            logger.verbose("  Filters: \(filters.joined(separator: ", "))")
        }

        // Request export
        let endpoint = POEditorEndpoint.exportProject(
            language: language,
            type: "xliff",
            referenceLanguage: refLang,
            filters: filters
        )

        let data = try networkClient.execute(endpoint)
        let apiResponse = try POEditorAPIResponse(data: data)

        guard apiResponse.isSuccess else {
            throw ValidationError("POEditor API error for \(language): \(apiResponse.message)")
        }

        guard let result = apiResponse.result,
              let urlString = result["url"] as? String,
              let downloadURL = URL(string: urlString) else {
            throw ValidationError("Failed to get download URL for \(language)")
        }

        // Download the XLIFF file
        let (fileData, _) = try URLSession.shared.syncRequest(with: URLRequest(url: downloadURL))
        let sizeInKB = Double(fileData.count) / 1024.0
        logger.success("  Downloaded \(String(format: "%.1f", sizeInKB)) KB")

        // Save XLIFF file
        let xliffPath = "\(downloadPath)/\(language)\(Constants.xliffExtension)"
        try fileSystem.writeData(fileData, toPath: xliffPath)
        logger.verbose("  💾 Saved to: \(xliffPath)")
    }

    // MARK: - Private Methods

    private func printUploadResults(for language: String, response: POEditorAPIResponse) {
        logger.info("\n📤 POEditor Upload Results (\(language)):")

        guard let result = response.result else { return }

        if let terms = result["terms"] as? [String: Any] {
            let parsed = terms["parsed"] as? Int ?? 0
            let added = terms["added"] as? Int ?? 0
            let deleted = terms["deleted"] as? Int ?? 0
            logger.info("  Terms:")
            logger.info("    • Parsed: \(parsed)")
            if added > 0 { logger.info("    • Added: \(added)") }
            if deleted > 0 { logger.info("    • Deleted: \(deleted)") }
        }

        if let translations = result["translations"] as? [String: Any] {
            let parsed = translations["parsed"] as? Int ?? 0
            let added = translations["added"] as? Int ?? 0
            let updated = translations["updated"] as? Int ?? 0
            logger.info("  Translations:")
            logger.info("    • Parsed: \(parsed)")
            if added > 0 { logger.info("    • Added: \(added)") }
            if updated > 0 { logger.info("    • Updated: \(updated)") }
        }
    }
}

// MARK: - Static Methods (Backward Compatibility)

extension POEditorAPIService {
    /// List available languages in POEditor project
    static func listLanguages(config: POEditorConfig) throws -> [POEditorLanguage] {
        let service = POEditorAPIService(config: config)
        return try service.listLanguages()
    }

    /// Add a language to POEditor project
    static func addLanguage(config: POEditorConfig, language: String) throws {
        let service = POEditorAPIService(config: config)
        try service.addLanguage(language)
    }

    /// Upload translations to POEditor
    static func uploadTranslations(
        config: POEditorConfig,
        language: String,
        exportPath: String,
        syncTerms: Bool,
        updating: String
    ) throws {
        let service = POEditorAPIService(config: config)
        try service.uploadTranslations(
            language: language,
            exportPath: exportPath,
            syncTerms: syncTerms,
            updating: updating
        )
    }

    /// Download translations from POEditor
    static func downloadTranslations(
        config: POEditorConfig,
        language: String,
        referenceLanguage: String,
        downloadPath: String
    ) throws {
        let service = POEditorAPIService(config: config)
        try service.downloadTranslations(
            language: language,
            referenceLanguage: referenceLanguage,
            downloadPath: downloadPath
        )
    }
}
