import Foundation

/// Internal HTTP client wrapping URLSession with authentication.
final class HTTPClient: Sendable {
    private let session: URLSession
    private let baseURLString: String
    private let apiKey: String

    init(baseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURLString = baseURL.absoluteString
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Response Metadata

    struct ResponseMeta: Sendable {
        var requestId: String
        var model: String
        var costTicks: Int
    }

    // MARK: - JSON Request

    /// Send a JSON request and decode the response.
    func doJSON<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil
    ) async throws -> (data: T, meta: ResponseMeta) {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(EncodableWrapper(body))
        }

        let (data, response) = try await performRequest(request)
        let httpResponse = response as! HTTPURLResponse

        let meta = ResponseMeta(
            requestId: httpResponse.value(forHTTPHeaderField: "X-QAI-Request-Id") ?? "",
            model: httpResponse.value(forHTTPHeaderField: "X-QAI-Model") ?? "",
            costTicks: Int(httpResponse.value(forHTTPHeaderField: "X-QAI-Cost-Ticks") ?? "0") ?? 0
        )

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            throw parseAPIError(data: data, statusCode: httpResponse.statusCode, requestId: meta.requestId)
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(T.self, from: data)
            return (decoded, meta)
        } catch {
            throw QuantumError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Stream Request

    /// Send a JSON request expecting an SSE response. Returns the raw byte stream.
    func doStreamRequest(
        path: String,
        body: any Encodable
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(EncodableWrapper(body))

        let (bytes, response) = try await session.bytes(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            // Read the error body
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let requestId = httpResponse.value(forHTTPHeaderField: "X-QAI-Request-Id") ?? ""
            throw parseAPIError(data: errorData, statusCode: httpResponse.statusCode, requestId: requestId)
        }

        return (bytes, httpResponse)
    }

    // MARK: - Multipart Upload

    /// Send a multipart/form-data upload and decode the JSON response.
    func doMultipart<T: Decodable>(
        path: String,
        fieldName: String,
        filename: String,
        data fileData: Data,
        contentType: String = "application/octet-stream"
    ) async throws -> (data: T, meta: ResponseMeta) {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await performRequest(request)
        let httpResponse = response as! HTTPURLResponse

        let meta = ResponseMeta(
            requestId: httpResponse.value(forHTTPHeaderField: "X-QAI-Request-Id") ?? "",
            model: httpResponse.value(forHTTPHeaderField: "X-QAI-Model") ?? "",
            costTicks: Int(httpResponse.value(forHTTPHeaderField: "X-QAI-Cost-Ticks") ?? "0") ?? 0
        )

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            throw parseAPIError(data: data, statusCode: httpResponse.statusCode, requestId: meta.requestId)
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(T.self, from: data)
            return (decoded, meta)
        } catch {
            throw QuantumError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Raw Upload

    /// Send a raw binary body with a specific content type and decode the JSON response.
    func doRawUpload<T: Decodable>(
        method: String = "POST",
        path: String,
        data bodyData: Data,
        contentType: String
    ) async throws -> (data: T, meta: ResponseMeta) {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await performRequest(request)
        let httpResponse = response as! HTTPURLResponse

        let meta = ResponseMeta(
            requestId: httpResponse.value(forHTTPHeaderField: "X-QAI-Request-Id") ?? "",
            model: httpResponse.value(forHTTPHeaderField: "X-QAI-Model") ?? "",
            costTicks: Int(httpResponse.value(forHTTPHeaderField: "X-QAI-Cost-Ticks") ?? "0") ?? 0
        )

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            throw parseAPIError(data: data, statusCode: httpResponse.statusCode, requestId: meta.requestId)
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(T.self, from: data)
            return (decoded, meta)
        } catch {
            throw QuantumError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Raw Download

    /// Send a request and return raw bytes (no JSON decoding).
    func doRawDownload(
        method: String = "GET",
        path: String
    ) async throws -> (data: Data, meta: ResponseMeta) {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)
        let httpResponse = response as! HTTPURLResponse

        let meta = ResponseMeta(
            requestId: httpResponse.value(forHTTPHeaderField: "X-QAI-Request-Id") ?? "",
            model: httpResponse.value(forHTTPHeaderField: "X-QAI-Model") ?? "",
            costTicks: Int(httpResponse.value(forHTTPHeaderField: "X-QAI-Cost-Ticks") ?? "0") ?? 0
        )

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            throw parseAPIError(data: data, statusCode: httpResponse.statusCode, requestId: meta.requestId)
        }

        return (data, meta)
    }

    // MARK: - Private

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw QuantumError.cancelled
        } catch {
            throw QuantumError.networkError(underlying: error)
        }
    }

    private func parseAPIError(data: Data, statusCode: Int, requestId: String) -> QuantumError {
        var code = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        var message = String(data: data, encoding: .utf8) ?? "Unknown error"

        let decoder = JSONDecoder()
        if let body = try? decoder.decode(APIErrorBody.self, from: data) {
            message = body.error.message
            if let errorCode = body.error.code {
                code = errorCode
            } else if let errorType = body.error.type {
                code = errorType
            }
        }

        return .api(
            statusCode: statusCode,
            code: code,
            message: message,
            requestId: requestId.isEmpty ? nil : requestId
        )
    }
}

// MARK: - EncodableWrapper (internal)

/// Internal type-erased Encodable wrapper for passing to JSONEncoder.
struct EncodableWrapper: Encodable {
    private let wrapped: any Encodable

    init(_ value: any Encodable) {
        self.wrapped = value
    }

    func encode(to encoder: Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}
