import Foundation

// MARK: - Balance

/// Response from the `/qai/v1/account/balance` endpoint.
public struct BalanceResponse: Codable, Sendable {
    /// User ID.
    public var userId: String?

    /// Credit balance in ticks.
    public var balanceTicks: Int64

    /// Credit balance in USD.
    public var balanceUsd: Double

    /// Conversion rate (ticks per USD).
    public var ticksPerUsd: Int64

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case balanceTicks = "balance_ticks"
        case balanceUsd = "balance_usd"
        case ticksPerUsd = "ticks_per_usd"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        balanceTicks = try c.decode(Int64.self, forKey: .balanceTicks)
        balanceUsd = try c.decode(Double.self, forKey: .balanceUsd)
        ticksPerUsd = try c.decodeIfPresent(Int64.self, forKey: .ticksPerUsd) ?? Int64(ticksPerUSD)
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
    public var deltaTicks: Int64?

    /// Balance after this entry.
    public var balanceAfter: Int64?

    /// Input tokens.
    public var inputTokens: Int64?

    /// Output tokens.
    public var outputTokens: Int64?

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

    /// Cursor for the next page. Present only when ``hasMore`` is true.
    public var nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case entries
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

/// Query parameters for usage history.
public struct UsageQuery: Codable, Sendable {
    /// Max entries per page, 1 to 100. A value outside that range is not
    /// clamped: the gateway ignores it and serves the default page of 20.
    public var limit: Int?

    /// Cursor for pagination (from the previous response's `nextCursor`).
    public var startAfter: String?

    public init(limit: Int? = nil, startAfter: String? = nil) {
        self.limit = limit
        self.startAfter = startAfter
    }

    enum CodingKeys: String, CodingKey {
        case limit
        case startAfter = "start_after"
    }
}

// MARK: - Usage Summary

/// Monthly usage summary.
public struct UsageSummaryMonth: Codable, Sendable {
    /// Month (e.g. "2026-03").
    public var month: String

    /// Total requests.
    public var totalRequests: Int64

    /// Total input tokens.
    public var totalInputTokens: Int64

    /// Total output tokens.
    public var totalOutputTokens: Int64

    /// Total cost in USD.
    public var totalCostUsd: Double

    /// Total margin in USD.
    public var totalMarginUsd: Double

    /// Breakdown by provider. Empty when the gateway sends none.
    public var byProvider: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case month
        case totalRequests = "total_requests"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCostUsd = "total_cost_usd"
        case totalMarginUsd = "total_margin_usd"
        case byProvider = "by_provider"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month = try c.decode(String.self, forKey: .month)
        totalRequests = try c.decodeIfPresent(Int64.self, forKey: .totalRequests) ?? 0
        totalInputTokens = try c.decodeIfPresent(Int64.self, forKey: .totalInputTokens) ?? 0
        totalOutputTokens = try c.decodeIfPresent(Int64.self, forKey: .totalOutputTokens) ?? 0
        totalCostUsd = try c.decodeIfPresent(Double.self, forKey: .totalCostUsd) ?? 0
        totalMarginUsd = try c.decodeIfPresent(Double.self, forKey: .totalMarginUsd) ?? 0
        byProvider = try c.decodeIfPresent([AnyCodable].self, forKey: .byProvider) ?? []
    }
}

/// Response from the `/qai/v1/account/usage/summary` endpoint.
public struct UsageSummaryResponse: Codable, Sendable {
    /// Monthly summaries.
    public var months: [UsageSummaryMonth]
}

// MARK: - Pricing

/// One model's pricing, as `/qai/v1/pricing` sends it, with the gateway's
/// margin already applied. The model id is the map key in
/// ``PricingResponse/pricing``; the entry repeats it in ``model``.
public struct PricingEntry: Codable, Sendable {
    /// Provider name.
    public var provider: String

    /// Model ID.
    public var model: String

    /// Display name.
    public var displayName: String

    /// Model category ("Text", "Image", ...).
    public var category: String?

    /// Human-readable context window (e.g. "200K").
    public var contextWindow: String?

    /// Input cost per million tokens.
    public var inputPerMillion: Double

    /// Output cost per million tokens.
    public var outputPerMillion: Double

    /// Cached input cost per million tokens.
    public var cachedPerMillion: Double

    /// Flat price for media models (per image, per second, ...).
    public var perUnitPrice: Double?

    /// Unit for ``perUnitPrice`` (e.g. "per image").
    public var priceUnit: String?

    enum CodingKeys: String, CodingKey {
        case provider, model, category
        case displayName = "display_name"
        case contextWindow = "context_window"
        case inputPerMillion = "input_per_million"
        case outputPerMillion = "output_per_million"
        case cachedPerMillion = "cached_per_million"
        case perUnitPrice = "per_unit_price"
        case priceUnit = "price_unit"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category)
        contextWindow = try c.decodeIfPresent(String.self, forKey: .contextWindow)
        inputPerMillion = try c.decodeIfPresent(Double.self, forKey: .inputPerMillion) ?? 0
        outputPerMillion = try c.decodeIfPresent(Double.self, forKey: .outputPerMillion) ?? 0
        cachedPerMillion = try c.decodeIfPresent(Double.self, forKey: .cachedPerMillion) ?? 0
        perUnitPrice = try c.decodeIfPresent(Double.self, forKey: .perUnitPrice)
        priceUnit = try c.decodeIfPresent(String.self, forKey: .priceUnit)
    }
}

/// Alias of ``PricingEntry``: the element type of `getPricing()`.
public typealias PricingInfo = PricingEntry

/// Pricing response (map of model_id to entry).
public struct PricingResponse: Codable, Sendable {
    /// Pricing map keyed by model id.
    public var pricing: [String: PricingEntry]
}

/// Legacy alias.
public typealias AccountPricingResponse = PricingResponse

// MARK: - Model Info

/// Information about an available model, as returned by `GET /qai/v1/models`.
public struct ModelInfo: Codable, Sendable {
    /// Model ID.
    public var id: String

    /// Provider name.
    public var provider: String

    /// Model category ("Text", "Image", "Video", "TTS", "STT", "Music",
    /// "Audio", "3D", "Embedding", "Realtime", "Vision").
    public var category: String

    /// Display name.
    public var displayName: String

    /// Human-readable context window (e.g. "200K"). Absent for media models.
    public var contextWindow: String?

    /// Input cost per million tokens. Absent for per-unit-priced models.
    public var inputPerMillion: Double?

    /// Output cost per million tokens. Absent for per-unit-priced models.
    public var outputPerMillion: Double?

    /// Flat price for media models (per image, per second, ...).
    public var perUnitPrice: Double?

    /// Unit for ``perUnitPrice`` (e.g. "per image").
    public var priceUnit: String?

    /// Routing hint ("direct", "vertex-maas", …).
    public var route: String?

    /// Reachable via GCP/Vertex credentials.
    public var vertexAvailable: Bool?

    /// Rolling aliases that resolve to this model (e.g. "claude-opus-latest").
    /// Prefer sending the alias so backend model swaps don't break pinned picks.
    public var aliases: [String]?

    /// True when this model is the current target of a rolling alias: the
    /// recommended "latest" default for its family/category.
    public var isDefault: Bool?

    /// Per-model generation parameter schema — present on servers that
    /// implement the v1+ `/qai/v1/models` contract, absent on older servers.
    public var parameters: [ParameterSpec]?

    enum CodingKeys: String, CodingKey {
        case id, provider, category, parameters, route, aliases
        case displayName = "display_name"
        case contextWindow = "context_window"
        case inputPerMillion = "input_per_million"
        case outputPerMillion = "output_per_million"
        case perUnitPrice = "per_unit_price"
        case priceUnit = "price_unit"
        case vertexAvailable = "vertex_available"
        case isDefault = "is_default"
    }

    public init(
        id: String,
        provider: String,
        category: String,
        displayName: String,
        contextWindow: String? = nil,
        inputPerMillion: Double? = nil,
        outputPerMillion: Double? = nil,
        perUnitPrice: Double? = nil,
        priceUnit: String? = nil,
        route: String? = nil,
        vertexAvailable: Bool? = nil,
        aliases: [String]? = nil,
        isDefault: Bool? = nil,
        parameters: [ParameterSpec]? = nil
    ) {
        self.id = id
        self.provider = provider
        self.category = category
        self.displayName = displayName
        self.contextWindow = contextWindow
        self.inputPerMillion = inputPerMillion
        self.outputPerMillion = outputPerMillion
        self.perUnitPrice = perUnitPrice
        self.priceUnit = priceUnit
        self.route = route
        self.vertexAvailable = vertexAvailable
        self.aliases = aliases
        self.isDefault = isDefault
        self.parameters = parameters
    }
}

/// Response envelope from `GET /qai/v1/models`.
public struct ModelsResponse: Codable, Sendable {
    /// Version of the response envelope. Clients compare against their
    /// supported range. `nil` means schema 0 / legacy backend.
    public var schemaVersion: Int?

    /// Number of models.
    public var count: Int?

    /// Available models.
    public var models: [ModelInfo]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case count, models
    }
}

// MARK: - Account deletion

/// What deleting the account did.
public struct AccountDeleteResponse: Codable, Sendable {
    /// `"deleted"`.
    public var status: String
    public var deletedAt: String?
    /// When the content becomes eligible for destruction.
    public var contentPurgedAfter: String?
    /// When the pseudonymised payment records may be dropped.
    public var recordsKeptUntil: String?
    /// Credit given up by deleting, in USD.
    public var forfeitedCreditUsd: Double?
    /// The sentence to show the person.
    public var detail: String?

    enum CodingKeys: String, CodingKey {
        case status, detail
        case deletedAt = "deleted_at"
        case contentPurgedAfter = "content_purged_after"
        case recordsKeptUntil = "records_kept_until"
        case forfeitedCreditUsd = "forfeited_credit_usd"
    }
}

/// The account's deletion state: `"active"` with nothing else, or the
/// deletion record.
public struct DeletionStatus: Codable, Sendable {
    public var status: String
    public var app: String?
    public var requestedAt: String?
    public var purgeAfter: String?
    public var retentionUntil: String?
    public var purgedAt: String?

    enum CodingKeys: String, CodingKey {
        case status, app
        case requestedAt = "requested_at"
        case purgeAfter = "purge_after"
        case retentionUntil = "retention_until"
        case purgedAt = "purged_at"
    }
}

/// The body `accountDelete()` sends: the confirmation phrase the gateway
/// demands.
struct AccountDeleteRequest: Encodable {
    let confirm: String
}

// MARK: - Status Response

/// Generic status response used by many endpoints.
public struct StatusResponse: Codable, Sendable {
    /// Status string (e.g. "revoked", "deleted", "alive", "sent").
    public var status: String

    /// Optional human-readable message.
    public var message: String?
}
