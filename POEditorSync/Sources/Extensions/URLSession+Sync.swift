import Foundation

extension URLSession {
    func syncRequest(with request: URLRequest) throws -> (Data, URLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Data, URLResponse), Error>?

        dataTask(with: request) { data, response, error in
            if let error = error {
                result = .failure(error)
            } else if let data = data, let response = response {
                result = .success((data, response))
            } else {
                result = .failure(ValidationError("Invalid response"))
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()

        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw ValidationError("Request timeout")
        }
    }
}
