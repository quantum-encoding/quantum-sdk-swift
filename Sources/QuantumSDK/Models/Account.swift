import Foundation

// MARK: - Balance

/// Response from the `/qai/v1/account/balance` endpoint.
public struct BalanceResponse: Codable, Sendable {
    /// User ID.
    public var userId: String

    /// Credit balance in ticks.
    public var creditTicks: Int

    /// Credit balance in USD.
    public var creditUsd: Double

    /// Conversion rate (ticks per USD).
    public var ticksPerUsd: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case creditTicks = "credit_ticks"
        case creditUsd = "credit_usd"
        case ticksPerUsd = "ticks_per_usd"
    }
}

// MARK: - Usage

/// A single usage ledger entry.
public struct UsageEntry: Codable, Sendable {
    /// Entry ID.
    public var id: String

    /// Request ID.
    public var requestId: String?

    /// Model used.
    public var model: String?

    /// Provider.
    public var provider: String?

    /// API endpoint.
    public var endpoint: String?

    /// Cost delta in ticks.
    public var deltaTicks: Int?

    /// Balance after this entry.
    public var balanceAfter: Int?

    /// Input tokens.
    public var inputTokens: Int?

    /// Output tokens.
    public var outputTokens: Int?

    /// Timestamp.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, model, provider, endpoint
        case requestId = "request_id"
        case deltaTicks = "delta_ticks"
        case balanceAfter = "balance_after"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case createdAt = "created_at"
    }
}

/// Response from the `/qai/v1/account/usage` endpoint.
public struct UsageResponse: Codable, Sendable {
    /// Usage entries.
    public var entries: [UsageEntry]

    /// Whether more entries are available.
    public var hasMore: Bool

    /// Cursor for the next page.
    public var nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case entries
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

/// Query parameters for usage history.
public struct UsageQuery: Sendable {
    /// Maximum number of entries.
    public var limit: Int?

    /// Cursor for pagination.
    public var startAfter: String?

    public init(limit: Int? = nil, startAfter: String? = nil) {
        self.limit = limit
        self.startAfter = startAfter
    }
}

// MARK: - Usage Summary

/// Monthly usage summary.
public struct UsageSummaryMonth: Codable, Sendable {
    /// Month (e.g. "2026-03").
    public var month: String

    /// Total requests.
    public var totalRequests: Int

    /// Total input tokens.
    public var totalInputTokens: Int

    /// Total output tokens.
    public var totalOutputTokens: Int

    /// Total cost in USD.
    public var totalCostUsd: Double

    /// Total margin in USD.
    public var totalMarginUsd: Double

    /// Breakdown by provider.
    public var byProvider: [AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case month
        case totalRequests = "total_requests"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCostUsd = "total_cost_usd"
        case totalMarginUsd = "total_margin_usd"
        case byProvider = "by_provider"
    }
}

/// Response from the `/qai/v1/account/usage/summary` endpoint.
public struct UsageSummaryResponse: Codable, Sendable {
    /// Monthly summaries.
    public var months: [UsageSummaryMonth]
}

// MARK: - Pricing

/// A pricing entry for a model.
public struct PricingEntry: Codable, Sendable {
    /// Provider name.
    public var provider: String

    /// Model ID.
    public var model: String

    /// Display name.
    public var displayName: String

    /// Input cost per million tokens.
    public var inputPerMillion: Double

    /// Output cost per million tokens.
    public var outputPerMillion: Double

    /// Cached input cost per million tokens.
    public var cachedPerMillion: Double?

    enum CodingKeys: String, CodingKey {
        case provider = "Provider"
        case model = "Model"
        case displayName = "DisplayName"
        case inputPerMillion = "InputPerMillion"
        case outputPerMillion = "OutputPerMillion"
        case cachedPerMillion = "CachedPerMillion"
    }
}

/// Response from the account pricing endpoint.
public struct AccountPricingResponse: Codable, Sendable {
    /// Pricing map (model ID -> pricing entry).
    public var pricing: [String: PricingEntry]
}

// MARK: - Model Info

/// Information about an available model.
public struct ModelInfo: Codable, Sendable {
    /// Model ID.
    public var id: String

    /// Provider name.
    public var provider: String

    /// Display name.
    public var displayName: String

    /// Input cost per million tokens.
    public var inputPerMillion: Double

    /// Output cost per million tokens.
    public var outputPerMillion: Double

    enum CodingKeys: String, CodingKey {
        case id, provider
        case displayName = "display_name"
        case inputPerMillion = "input_per_million"
        case outputPerMillion = "output_per_million"
    }
}

/// Pricing information for a model.
public struct PricingInfo: Codable, Sendable {
    /// Model ID.
    public var id: String

    /// Provider name.
    public var provider: String

    /// Display name.
    public var displayName: String

    /// Input cost per million tokens.
    public var inputPerMillion: Double

    /// Output cost per million tokens.
    public var outputPerMillion: Double

    enum CodingKeys: String, CodingKey {
        case id, provider
        case displayName = "display_name"
        case inputPerMillion = "input_per_million"
        case outputPerMillion = "output_per_million"
    }
}

// MARK: - Status Response

/// Generic status response used by many endpoints.
public struct StatusResponse: Codable, Sendable {
    /// Status string (e.g. "revoked", "deleted", "alive", "sent").
    public var status: String
}

// MARK: - Contact

/// Request body for the `/qai/v1/contact` endpoint.
public struct ContactRequest: Codable, Sendable {
    /// Sender name.
    public var name: String

    /// Sender email address.
    public var email: String

    /// Message body.
    public var message: String

    public init(name: String, email: String, message: String) {
        self.name = name
        self.email = email
        self.message = message
    }
}
