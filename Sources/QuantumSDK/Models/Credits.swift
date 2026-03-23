import Foundation

// MARK: - Credit Packs

/// A credit pack available for purchase.
public struct CreditPack: Codable, Sendable {
    /// Pack ID.
    public var id: String

    /// Pack name.
    public var name: String?

    /// Price in USD.
    public var priceUsd: Double

    /// Credit ticks included.
    public var creditTicks: Int64

    /// Description.
    public var description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case priceUsd = "price_usd"
        case creditTicks = "credit_ticks"
    }
}

/// Response from the `/qai/v1/credits/packs` endpoint.
public struct CreditPacksResponse: Codable, Sendable {
    /// Available credit packs.
    public var packs: [CreditPack]
}

// MARK: - Purchase

/// Request body for the `/qai/v1/credits/purchase` endpoint.
public struct CreditPurchaseRequest: Codable, Sendable {
    /// Pack ID to purchase.
    public var packId: String

    /// URL to redirect to on success.
    public var successUrl: String?

    /// URL to redirect to on cancellation.
    public var cancelUrl: String?

    public init(packId: String, successUrl: String? = nil, cancelUrl: String? = nil) {
        self.packId = packId
        self.successUrl = successUrl
        self.cancelUrl = cancelUrl
    }

    enum CodingKeys: String, CodingKey {
        case packId = "pack_id"
        case successUrl = "success_url"
        case cancelUrl = "cancel_url"
    }
}

/// Response from purchasing a credit pack.
public struct CreditPurchaseResponse: Codable, Sendable {
    /// Checkout URL for payment.
    public var checkoutUrl: String

    enum CodingKeys: String, CodingKey {
        case checkoutUrl = "checkout_url"
    }
}

// MARK: - Balance

/// Response from the `/qai/v1/credits/balance` endpoint.
public struct CreditBalanceResponse: Codable, Sendable {
    /// Balance in ticks.
    public var balanceTicks: Int64

    /// Balance in USD.
    public var balanceUsd: Double

    enum CodingKeys: String, CodingKey {
        case balanceTicks = "balance_ticks"
        case balanceUsd = "balance_usd"
    }
}

// MARK: - Tiers

/// A pricing tier.
public struct CreditTier: Codable, Sendable {
    /// Tier name.
    public var name: String?

    /// Minimum balance requirement.
    public var minBalance: Int64?

    /// Discount percentage.
    public var discountPercent: Double?

    /// Additional tier data.
    public var extra: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case name, extra
        case minBalance = "min_balance"
        case discountPercent = "discount_percent"
    }
}

/// Response from the `/qai/v1/credits/tiers` endpoint.
public struct CreditTiersResponse: Codable, Sendable {
    /// Available tiers.
    public var tiers: [CreditTier]
}

// MARK: - Developer Program

/// Request body for the `/qai/v1/credits/dev-program` endpoint.
public struct DevProgramApplyRequest: Codable, Sendable {
    /// Use case description.
    public var useCase: String

    /// Company name.
    public var company: String?

    /// Expected monthly spend in USD.
    public var expectedUsd: Double?

    /// Website URL.
    public var website: String?

    public init(useCase: String, company: String? = nil, expectedUsd: Double? = nil, website: String? = nil) {
        self.useCase = useCase
        self.company = company
        self.expectedUsd = expectedUsd
        self.website = website
    }

    enum CodingKeys: String, CodingKey {
        case company, website
        case useCase = "use_case"
        case expectedUsd = "expected_usd"
    }
}

/// Response from the developer program application.
public struct DevProgramApplyResponse: Codable, Sendable {
    /// Application status.
    public var status: String
}
