import Foundation

// MARK: - POEditor API Endpoint

enum POEditorEndpoint {
    case listLanguages
    case addLanguage(language: String)
    case uploadTranslations(language: String, updating: String)
    case exportProject(language: String, type: String, referenceLanguage: String?, filters: [String]?)

    // MARK: - Properties

    var path: String {
        switch self {
        case .listLanguages:
            return "/v2/languages/list"
        case .addLanguage:
            return "/v2/languages/add"
        case .uploadTranslations:
            return "/v2/projects/upload"
        case .exportProject:
            return "/v2/projects/export"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listLanguages, .addLanguage, .uploadTranslations, .exportProject:
            return .post
        }
    }

    var parameters: [String: String] {
        switch self {
        case .listLanguages:
            return [:]

        case .addLanguage(let language):
            return ["language": language]

        case .uploadTranslations(let language, let updating):
            return [
                "language": language,
                "updating": updating
            ]

        case .exportProject(let language, let type, let referenceLanguage, let filters):
            var params: [String: String] = [
                "language": language,
                "type": type
            ]

            if let referenceLanguage = referenceLanguage {
                params["reference_language"] = referenceLanguage
            }

            if let filters = filters, !filters.isEmpty {
                params["filters"] = filters.joined(separator: ",")
            }

            return params
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
