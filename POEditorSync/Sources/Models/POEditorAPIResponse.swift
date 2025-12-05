import Foundation

struct POEditorAPIResponse {
    let status: String
    let code: String
    let message: String
    let result: [String: Any]?

    init(data: Data) throws {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? [String: Any],
              let status = response["status"] as? String,
              let code = response["code"] as? String,
              let message = response["message"] as? String else {
            throw ValidationError("Invalid POEditor API response format")
        }

        self.status = status
        self.code = code
        self.message = message
        self.result = json["result"] as? [String: Any]
    }

    var isSuccess: Bool {
        return status == "success"
    }
}
