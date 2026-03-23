import Foundation

// MARK: - ApiError

/// An error returned by the Quantum AI API (non-2xx response).
public struct ApiError: Codable, Sendable {
    /// The HTTP status code from the response.
    public var statusCode: UInt16

    /// The error type from the API (e.g. "invalid_request", "rate_limit").
    public var code: String

    /// The human-readable error description.
    public var message: String

    /// The unique request identifier from the X-QAI-Request-Id header.
    public var requestId: String

    public init(statusCode: UInt16, code: String, message: String, requestId: String = "") {
        self.statusCode = statusCode
        self.code = code
        self.message = message
        self.requestId = requestId
    }

    /// Returns true if this is a 429 rate limit response.
    public var isRateLimit: Bool { statusCode == 429 }

    /// Returns true if this is a 401 or 403 authentication/authorization failure.
    public var isAuth: Bool { statusCode == 401 || statusCode == 403 }

    /// Returns true if this is a 404 not found response.
    public var isNotFound: Bool { statusCode == 404 }

    enum CodingKeys: String, CodingKey {
        case code, message
        case statusCode = "status_code"
        case requestId = "request_id"
    }
}

// MARK: - QuantumError

/// Errors thrown by the QuantumSDK.
public enum QuantumError: Error, LocalizedError, Sendable {
    /// The API returned a non-2xx status code.
    case api(statusCode: Int, code: String, message: String, requestId: String?)

    /// The response body could not be decoded.
    case decodingFailed(underlying: Error)

    /// The response body was empty or missing.
    case emptyResponse

    /// The SSE stream produced invalid data.
    case streamError(String)

    /// A network-level error occurred.
    case networkError(underlying: Error)

    /// The request was cancelled.
    case cancelled

    /// An invalid argument was provided.
    case invalidArgument(String)

    public var errorDescription: String? {
        switch self {
        case let .api(statusCode, code, message, requestId):
            if let requestId {
                return "qai: \(statusCode) \(code): \(message) (request_id=\(requestId))"
            }
            return "qai: \(statusCode) \(code): \(message)"
        case let .decodingFailed(error):
            return "qai: decoding failed: \(error.localizedDescription)"
        case .emptyResponse:
            return "qai: empty response body"
        case let .streamError(message):
            return "qai: stream error: \(message)"
        case let .networkError(error):
            return "qai: network error: \(error.localizedDescription)"
        case .cancelled:
            return "qai: request cancelled"
        case let .invalidArgument(message):
            return "qai: invalid argument: \(message)"
        }
    }

    /// True if the error is a 429 rate limit response.
    public var isRateLimit: Bool {
        if case let .api(statusCode, _, _, _) = self { return statusCode == 429 }
        return false
    }

    /// True if the error is a 401 or 403 auth failure.
    public var isAuth: Bool {
        if case let .api(statusCode, _, _, _) = self {
            return statusCode == 401 || statusCode == 403
        }
        return false
    }

    /// True if the error is a 404 not found response.
    public var isNotFound: Bool {
        if case let .api(statusCode, _, _, _) = self { return statusCode == 404 }
        return false
    }
}

// MARK: - Error (enum matching Rust)

/// Error types returned by the Quantum AI SDK (mirrors Rust Error enum).
public enum Error: Swift.Error, Sendable {
    /// The API returned a non-2xx status code.
    case api(ApiError)
    /// An HTTP transport error occurred.
    case http(Swift.Error)
    /// A serialization or deserialization error occurred.
    case json(Swift.Error)
}

// MARK: - API Error Body (internal)

struct APIErrorBody: Decodable {
    struct ErrorDetail: Decodable {
        let message: String
        let type: String?
        let code: String?
    }

    let error: ErrorDetail
}

// MARK: - Response Meta

/// Metadata extracted from response headers.
public struct ResponseMeta: Codable, Sendable {
    /// Cost in ticks from X-QAI-Cost-Ticks header.
    public var costTicks: Int64

    /// Request ID from X-QAI-Request-Id header.
    public var requestId: String

    /// Model from X-QAI-Model header.
    public var model: String

    public init(costTicks: Int64 = 0, requestId: String = "", model: String = "") {
        self.costTicks = costTicks
        self.requestId = requestId
        self.model = model
    }

    enum CodingKeys: String, CodingKey {
        case model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}
