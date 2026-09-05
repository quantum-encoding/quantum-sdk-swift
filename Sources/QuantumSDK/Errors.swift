import Foundation

// MARK: - QuantumError

/// Errors thrown by the QuantumSDK.
public enum QuantumError: Error, LocalizedError, Sendable {
    /// The API answered with an error envelope. Usually a non-2xx status;
    /// a 2xx whose body is an error envelope (a moderation block, say)
    /// lands here too with the 2xx status. Errors the SDK raises locally
    /// before any request is sent (`invalid_api_key`, `invalid_header`)
    /// carry `statusCode == 0`.
    case api(statusCode: Int, code: String, message: String, requestId: String?)

    /// A 2xx body could not be decoded into the expected type. Carries the
    /// `DecodingError` only, never the body: sign-in and key-minting
    /// responses open with live credentials, and library code must not
    /// copy those into an error message or a log.
    case decodingFailed(underlying: any Swift.Error)

    /// The response body was empty or missing.
    case emptyResponse

    /// The SSE stream produced data the SDK could not use.
    case streamError(String)

    /// A network-level error occurred.
    case networkError(underlying: any Swift.Error)

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
            return "qai: decoding failed: \(Self.describe(decoding: error))"
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

    /// A `DecodingError` rendered from its coding path and description
    /// only. `localizedDescription` on a `DecodingError` is a generic
    /// sentence; the context is where the useful part lives, and it never
    /// includes the raw body.
    private static func describe(decoding error: any Swift.Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        let context: DecodingError.Context
        let prefix: String
        switch decodingError {
        case let .keyNotFound(key, ctx):
            prefix = "missing key '\(key.stringValue)'"
            context = ctx
        case let .typeMismatch(type, ctx):
            prefix = "type mismatch (expected \(type))"
            context = ctx
        case let .valueNotFound(type, ctx):
            prefix = "null where \(type) expected"
            context = ctx
        case let .dataCorrupted(ctx):
            prefix = "data corrupted"
            context = ctx
        @unknown default:
            return "decoding error"
        }
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? prefix : "\(prefix) at \(path)"
    }

    /// HTTP status of an ``api(statusCode:code:message:requestId:)`` error;
    /// `nil` for every other case.
    public var statusCode: Int? {
        if case let .api(statusCode, _, _, _) = self { return statusCode }
        return nil
    }

    /// Raw wire code of an ``api(statusCode:code:message:requestId:)``
    /// error; `nil` for every other case.
    public var code: String? {
        if case let .api(_, code, _, _) = self { return code }
        return nil
    }

    /// Request id of an ``api(statusCode:code:message:requestId:)`` error,
    /// when the response carried `X-QAI-Request-Id`.
    public var requestId: String? {
        if case let .api(_, _, _, requestId) = self { return requestId }
        return nil
    }

    /// The strongly-typed error code. ``ErrorCode/unknown`` for a code
    /// this SDK does not recognise and for every non-API error.
    public var typedCode: ErrorCode {
        guard let code else { return .unknown }
        return ErrorCode(wire: code)
    }

    /// True for a 429, and for a 2xx envelope whose code is one of the
    /// rate-limit family.
    public var isRateLimit: Bool {
        guard case let .api(statusCode, _, _, _) = self else { return false }
        if statusCode == 429 { return true }
        switch typedCode {
        case .rateLimitedPerKey, .rateLimitedPerIP, .rateLimited, .quotaExceeded:
            return true
        default:
            return false
        }
    }

    /// True for a 401 or 403.
    public var isAuth: Bool {
        guard case let .api(statusCode, _, _, _) = self else { return false }
        return statusCode == 401 || statusCode == 403
    }

    /// True for a 404.
    public var isNotFound: Bool {
        guard case let .api(statusCode, _, _, _) = self else { return false }
        return statusCode == 404
    }

    /// True for a 402, and for any status whose code is
    /// ``ErrorCode/insufficientBalance``. Use this to branch retry vs.
    /// top-up in caller code.
    public var isInsufficientBalance: Bool {
        guard case let .api(statusCode, _, _, _) = self else { return false }
        return statusCode == 402 || typedCode == .insufficientBalance
    }
}

// MARK: - ErrorCode

/// Strongly-typed view of the API's error codes.
///
/// Match on this rather than on the message: the message is human-readable
/// and may change between releases, while the code is part of the wire
/// contract and is never repurposed.
///
/// The gateway has two generations of code. Canonical codes are uppercase
/// snake_case (`KEY_FROZEN_BY_BUDGET`) and each is its own case. Most 4xx
/// responses, though, still come from a legacy writer that copies a
/// lowercase `type` into `code` (`invalid_request`, `authentication_error`,
/// `not_found`, `forbidden`, `provider_error`, `invalid_state`, …); those
/// are folded onto the case with the same meaning, and a family with no
/// canonical counterpart gets its own generic case (``authenticationError``,
/// ``invalidState``, ``providerError``, ``rateLimited``).
///
/// ``unknown`` covers a code this SDK version does not recognise (one added
/// after the SDK was built) and a response with no code field at all. In
/// every case the raw string is preserved on ``QuantumError/code`` so
/// callers can still match on it.
public enum ErrorCode: Sendable, Hashable {
    // Auth / identity
    case authHeaderMissing
    case authHeaderEmpty
    case keyBearerMalformed
    /// `KEY_NOT_FOUND`, and the legacy `invalid_key` from `verifyKey`.
    case keyNotFound
    case keyExpired
    case keyRevokedByAdmin
    case keyRevokedByOwner
    /// `KEY_ROTATED`: the key was replaced by `rotateKey` and its grace
    /// period (if any) has elapsed.
    case keyRotated
    /// The partner's budget kill-switch fired. Unlike a self-revoke or
    /// admin-revoke the user's account is fine; the partner's billing is
    /// not, and the remedy is for the partner to top up.
    case keyFrozenByBudget
    case keyPartnerRejected
    case sessionExpired
    case ephemeralExpired
    /// `ACCOUNT_DELETED`: the account behind the credential was deleted;
    /// the credential is dead for good.
    case accountDeleted
    /// The legacy `authentication_error` / `unauthorized` / `auth_error`
    /// types: the credential was missing, rejected or is not allowed to do
    /// this, with no finer canonical code attached.
    case authenticationError

    // Authz / scope
    case scopeEndpointDenied
    case adminRequired
    case serviceAccountRequired
    /// `APP_SCOPE_MISMATCH`: the key is scoped to a different app than the
    /// one `X-Quantum-App` names.
    case appScopeMismatch
    /// `PERMISSION_DENIED`, and the legacy `forbidden` / `permission_error`
    /// types: the caller is authenticated but may not touch this resource.
    case permissionDenied

    // Billing / credits
    case insufficientBalance
    case trialExpired
    case subscriptionLapsed
    case spendCapExceeded
    /// Runtime variant of the partner budget freeze, fired mid-request;
    /// ``keyFrozenByBudget`` fires at auth time.
    case budgetFrozen
    case paymentNotConfigured
    case billingPortalNoHistory

    // Rate / quota
    case rateLimitedPerKey
    case rateLimitedPerIP
    case quotaExceeded
    /// The legacy `rate_limited` / `rate_limit_exceeded` types with no
    /// per-key / per-IP code attached.
    case rateLimited

    // Provider / upstream
    case providerRateLimited
    case providerUnavailable
    case providerAuthFailed
    case providerInvalidRequest
    /// `PROVIDER_FEATURE_DISALLOWED`: a feature (structured outputs, say)
    /// is blocked by provider or org configuration, not by the request.
    /// Retrying will not help; the operator has to change the config.
    case providerFeatureDisallowed
    /// Moderation block on the request content, not on account state: the
    /// user can retry with different content.
    case contentRejected
    case modelNotAvailable
    /// The legacy `provider_error` / `upstream_error` types: the upstream
    /// provider failed and the gateway attached no finer code.
    case providerError

    // Request shape / validation
    /// `INVALID_REQUEST`, and the legacy `invalid_request` /
    /// `invalid_request_error` / `bad_request` / `missing_fields` types.
    case invalidRequest
    case invalidRequestBody
    case missingRequiredField
    case fieldTooLong
    case invalidAttachment
    case attachmentTooLarge
    /// `FILE_MIME_UNSUPPORTED`: `/qai/v1/files` rejected the upload's MIME
    /// type.
    case fileMimeUnsupported
    case unsupportedCapability
    /// The legacy `invalid_state` / `conflict` types: the resource is not
    /// in a state that allows the operation (rotating an already-rotated
    /// key, extending a deployment that is not ready).
    case invalidState

    // System
    case internalError
    case serviceUnavailable
    case stripeApiError
    case idempotencyConflict
    /// `NOT_FOUND`, and the legacy `not_found` / `scan_not_found` /
    /// `type_not_found` types.
    case notFound

    // Per-product paywall codes
    case recipeBoxPaywall

    /// Unrecognised or absent code; the raw string is on
    /// ``QuantumError/code``.
    case unknown

    /// Parses the wire code string. Canonical uppercase codes map
    /// one-to-one; the legacy lowercase `type` strings the gateway copies
    /// into `code` on most 4xx responses are folded onto the case with the
    /// same meaning. Unknown strings (including empty) yield ``unknown``.
    /// The match is case-sensitive in both generations.
    public init(wire code: String) {
        switch code {
        case "AUTH_HEADER_MISSING": self = .authHeaderMissing
        case "AUTH_HEADER_EMPTY": self = .authHeaderEmpty
        case "KEY_BEARER_MALFORMED": self = .keyBearerMalformed
        case "KEY_NOT_FOUND", "invalid_key": self = .keyNotFound
        case "KEY_EXPIRED": self = .keyExpired
        case "KEY_REVOKED_BY_ADMIN": self = .keyRevokedByAdmin
        case "KEY_REVOKED_BY_OWNER": self = .keyRevokedByOwner
        case "KEY_ROTATED": self = .keyRotated
        case "KEY_FROZEN_BY_BUDGET": self = .keyFrozenByBudget
        case "KEY_PARTNER_REJECTED": self = .keyPartnerRejected
        case "SESSION_EXPIRED": self = .sessionExpired
        case "EPHEMERAL_EXPIRED": self = .ephemeralExpired
        case "ACCOUNT_DELETED": self = .accountDeleted
        case "authentication_error", "unauthorized", "auth_error": self = .authenticationError
        case "SCOPE_ENDPOINT_DENIED": self = .scopeEndpointDenied
        case "ADMIN_REQUIRED": self = .adminRequired
        case "SERVICE_ACCOUNT_REQUIRED": self = .serviceAccountRequired
        case "APP_SCOPE_MISMATCH": self = .appScopeMismatch
        case "PERMISSION_DENIED", "forbidden", "permission_error": self = .permissionDenied
        case "INSUFFICIENT_BALANCE", "insufficient_balance", "insufficient_funds", "balance_zero":
            self = .insufficientBalance
        case "TRIAL_EXPIRED": self = .trialExpired
        case "SUBSCRIPTION_LAPSED": self = .subscriptionLapsed
        case "SPEND_CAP_EXCEEDED": self = .spendCapExceeded
        case "BUDGET_FROZEN": self = .budgetFrozen
        case "PAYMENT_NOT_CONFIGURED": self = .paymentNotConfigured
        case "BILLING_PORTAL_NO_HISTORY", "no_billing_history": self = .billingPortalNoHistory
        case "RATE_LIMITED_PER_KEY": self = .rateLimitedPerKey
        case "RATE_LIMITED_PER_IP": self = .rateLimitedPerIP
        case "QUOTA_EXCEEDED": self = .quotaExceeded
        case "rate_limited", "rate_limit_exceeded", "rate_limit": self = .rateLimited
        case "PROVIDER_RATE_LIMITED": self = .providerRateLimited
        case "PROVIDER_UNAVAILABLE": self = .providerUnavailable
        case "PROVIDER_AUTH_FAILED": self = .providerAuthFailed
        case "PROVIDER_INVALID_REQUEST": self = .providerInvalidRequest
        case "PROVIDER_FEATURE_DISALLOWED": self = .providerFeatureDisallowed
        case "CONTENT_REJECTED": self = .contentRejected
        case "MODEL_NOT_AVAILABLE": self = .modelNotAvailable
        case "provider_error", "upstream_error": self = .providerError
        case "INVALID_REQUEST", "invalid_request", "invalid_request_error", "bad_request", "missing_fields":
            self = .invalidRequest
        case "INVALID_REQUEST_BODY": self = .invalidRequestBody
        case "MISSING_REQUIRED_FIELD": self = .missingRequiredField
        case "FIELD_TOO_LONG", "field_too_long": self = .fieldTooLong
        case "INVALID_ATTACHMENT", "invalid_attachment": self = .invalidAttachment
        case "ATTACHMENT_TOO_LARGE", "attachment_too_large": self = .attachmentTooLarge
        case "FILE_MIME_UNSUPPORTED": self = .fileMimeUnsupported
        case "UNSUPPORTED_CAPABILITY", "capability_error": self = .unsupportedCapability
        case "invalid_state", "conflict": self = .invalidState
        case "INTERNAL_ERROR", "internal_error": self = .internalError
        case "SERVICE_UNAVAILABLE", "service_unavailable", "unavailable": self = .serviceUnavailable
        case "STRIPE_API_ERROR", "stripe_error": self = .stripeApiError
        case "IDEMPOTENCY_CONFLICT": self = .idempotencyConflict
        case "NOT_FOUND", "not_found", "scan_not_found", "type_not_found": self = .notFound
        case "RECIPE_BOX_PAYWALL", "recipe_box_paywall": self = .recipeBoxPaywall
        default: self = .unknown
        }
    }
}

// MARK: - Error envelopes (internal)

/// The usual envelope: `{"error": {"message", "type", "code"}}`.
struct APIErrorBody: Decodable {
    struct ErrorDetail: Decodable {
        let message: String?
        let type: String?
        let code: String?
    }

    let error: ErrorDetail
}

/// The flat envelope a few routes (`/qai/v1/agent` among them) write:
/// `{"error": "<code>", "message": "…"}`.
struct FlatAPIErrorBody: Decodable {
    let error: String
    let message: String?
}

/// The `(code, message)` an error body carries, in either envelope. `nil`
/// when the body is neither.
func parseErrorEnvelope(_ data: Data) -> (code: String?, message: String?)? {
    let decoder = JSONDecoder()
    if let nested = try? decoder.decode(APIErrorBody.self, from: data) {
        let code = [nested.error.code, nested.error.type]
            .compactMap { $0 }
            .first { !$0.isEmpty }
        return (code, nested.error.message)
    }
    if let flat = try? decoder.decode(FlatAPIErrorBody.self, from: data) {
        return (flat.error.isEmpty ? nil : flat.error, flat.message)
    }
    return nil
}

// MARK: - Response Meta

/// Metadata extracted from response headers.
public struct ResponseMeta: Codable, Sendable {
    /// Cost in ticks from `X-QAI-Cost-Ticks`. Zero when the route sends no
    /// cost header: a semantic-cache hit on chat, or a route that does not
    /// bill.
    public var costTicks: Int64

    /// Request ID from `X-QAI-Request-Id`, set on every response.
    public var requestId: String

    /// Model from `X-QAI-Model` (chat routes).
    public var model: String

    /// Post-charge wallet balance in ticks from `X-QAI-Balance-After`.
    /// Signed: the claw-back path can drive the balance negative. Only the
    /// media routes (image, video, audio, avatar) send the header; on chat,
    /// session chat, search, keys, credits and account calls this is `nil`.
    /// Use `creditBalance` / `accountBalance` for the balance after a chat.
    public var balanceAfter: Int64?

    public init(costTicks: Int64 = 0, requestId: String = "", model: String = "", balanceAfter: Int64? = nil) {
        self.costTicks = costTicks
        self.requestId = requestId
        self.model = model
        self.balanceAfter = balanceAfter
    }

    enum CodingKeys: String, CodingKey {
        case model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
        case balanceAfter = "balance_after"
    }
}
