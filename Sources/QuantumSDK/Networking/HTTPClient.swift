import Foundation

/// Internal HTTP client wrapping URLSession with authentication.
actor HTTPClient {
    private let session: URLSession
    private let baseURLString: String
    private let apiKey: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURLString = baseURL.absoluteString
        self.apiKey = apiKey
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
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
        body: (any Encodable & Sendable)? = nil
    ) async throws -> (data: T, meta: ResponseMeta) {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        body: any Encodable & Sendable
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
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
