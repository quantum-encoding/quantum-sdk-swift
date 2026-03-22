import Foundation

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

// MARK: - API Error Body (internal)

struct APIErrorBody: Decodable {
    struct ErrorDetail: Decodable {
        let message: String
        let type: String?
        let code: String?
    }

    let error: ErrorDetail
}
