import Foundation

// MARK: - Network Client Protocol

protocol NetworkClient {
    var baseURL: String { get }
    var config: POEditorConfig { get }

    func execute(_ endpoint: POEditorEndpoint) throws -> Data
    func executeMultipart(_ endpoint: POEditorEndpoint, fileData: Data, fileName: String, mimeType: String, additionalParameters: [String: String]) throws -> Data
}

// MARK: - POEditor Network Client

final class POEditorNetworkClient: NetworkClient {
    let baseURL: String
    let config: POEditorConfig
    private let logger: Logger

    init(config: POEditorConfig, baseURL: String = "https://api.poeditor.com", logger: Logger? = nil) {
        self.config = config
        self.baseURL = baseURL
        self.logger = logger ?? config.createLogger()
    }

    // MARK: - Public Methods

    func execute(_ endpoint: POEditorEndpoint) throws -> Data {
        let request = try buildRequest(for: endpoint)

        logger.debug("API Request: \(endpoint.path)")
        for (key, value) in endpoint.parameters where key != "api_token" {
            logger.debug("  \(key): \(value)")
        }

        let (data, _) = try URLSession.shared.syncRequest(with: request)
        return data
    }

    func executeMultipart(
        _ endpoint: POEditorEndpoint,
        fileData: Data,
        fileName: String,
        mimeType: String,
        additionalParameters: [String: String] = [:]
    ) throws -> Data {
        let request = try buildMultipartRequest(
            for: endpoint,
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            additionalParameters: additionalParameters
        )

        let (data, _) = try URLSession.shared.syncRequest(with: request)
        return data
    }

    // MARK: - Private Methods

    private func buildRequest(for endpoint: POEditorEndpoint) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw ValidationError("Invalid URL: \(baseURL + endpoint.path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Add authentication and common parameters
        var parameters = endpoint.parameters
        parameters["api_token"] = config.apiToken
        parameters["id"] = config.projectId

        // Encode parameters
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        return request
    }

    private func buildMultipartRequest(
        for endpoint: POEditorEndpoint,
        fileData: Data,
        fileName: String,
        mimeType: String,
        additionalParameters: [String: String]
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw ValidationError("Invalid URL: \(baseURL + endpoint.path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add authentication parameters
        body.append(formField(name: "api_token", value: config.apiToken, boundary: boundary))
        body.append(formField(name: "id", value: config.projectId, boundary: boundary))

        // Add endpoint parameters
        for (key, value) in endpoint.parameters {
            body.append(formField(name: key, value: value, boundary: boundary))
        }

        // Add additional parameters
        for (key, value) in additionalParameters {
            body.append(formField(name: key, value: value, boundary: boundary))
        }

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        return request
    }

    private func formField(name: String, value: String, boundary: String) -> Data {
        var fieldData = Data()
        fieldData.append("--\(boundary)\r\n".data(using: .utf8)!)
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        fieldData.append("\(value)\r\n".data(using: .utf8)!)
        return fieldData
    }
}
