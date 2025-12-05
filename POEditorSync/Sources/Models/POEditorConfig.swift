import Foundation

struct POEditorConfig: Codable {
    let apiToken: String
    let projectId: String
    let projectPath: String
    let workspacePath: String?
    let languages: [String]?
    let upload: UploadConfig?
    let download: DownloadConfig?
    let verbose: Bool

    enum CodingKeys: String, CodingKey {
        case apiToken = "api_token"
        case projectId = "project_id"
        case projectPath = "project_path"
        case workspacePath = "workspace_path"
        case languages
        case upload
        case download
        case verbose
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiToken = try container.decode(String.self, forKey: .apiToken)
        projectId = try container.decode(String.self, forKey: .projectId)

        // Try workspace_path first, then fall back to project_path
        workspacePath = try container.decodeIfPresent(String.self, forKey: .workspacePath)
        if let workspace = workspacePath {
            projectPath = workspace
        } else {
            projectPath = try container.decode(String.self, forKey: .projectPath)
        }

        languages = try container.decodeIfPresent([String].self, forKey: .languages)
        upload = try container.decodeIfPresent(UploadConfig.self, forKey: .upload)
        download = try container.decodeIfPresent(DownloadConfig.self, forKey: .download)
        verbose = try container.decodeIfPresent(Bool.self, forKey: .verbose) ?? false
    }

    /// Check if we're using a workspace (vs a standalone project)
    var isWorkspace: Bool {
        return workspacePath != nil || projectPath.hasSuffix(".xcworkspace")
    }

    /// Get languages, either from config or by auto-detecting from project
    func getLanguages() throws -> [String] {
        if let languages = languages, !languages.isEmpty {
            return languages
        }
        return try XcodeService.detectLanguages(projectPath: projectPath)
    }

    /// Create logger with current verbose setting
    func createLogger() -> Logger {
        return Logger(isVerbose: verbose)
    }

    struct UploadConfig: Codable {
        let updating: String?
        let overwrite: Bool
        let syncTerms: Bool

        enum CodingKeys: String, CodingKey {
            case updating
            case overwrite
            case syncTerms = "sync_terms"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            updating = try container.decodeIfPresent(String.self, forKey: .updating)
            overwrite = try container.decodeIfPresent(Bool.self, forKey: .overwrite) ?? false
            syncTerms = try container.decodeIfPresent(Bool.self, forKey: .syncTerms) ?? false
        }
    }

    struct DownloadConfig: Codable {
        let filters: [String]?
    }
}
