// Credits — purchase credit packs, check balance, view tiers, lifetime
// plans, and apply for the developer program.
//
// Packs, tiers and lifetime plans need no authentication.

import Foundation

// MARK: - Credit Packs

/// A credit pack available for purchase.
public struct CreditPack: Codable, Sendable {
    /// Unique pack identifier.
    public var id: String

    /// Display label (e.g. "$5 Starter").
    public var label: String

    /// Price in USD.
    public var amountUsd: Double

    /// Number of credit ticks included.
    public var ticks: Int64

    /// Description.
    public var description: String?

    /// Whether this is the popular/recommended pack.
    public var popular: Bool?

    enum CodingKeys: String, CodingKey {
        case id, label, ticks, description, popular
        case amountUsd = "amount_usd"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        amountUsd = try c.decodeIfPresent(Double.self, forKey: .amountUsd) ?? 0
        ticks = try c.decodeIfPresent(Int64.self, forKey: .ticks) ?? 0
        description = try c.decodeIfPresent(String.self, forKey: .description)
        popular = try c.decodeIfPresent(Bool.self, forKey: .popular)
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

/// A developer tier, as `/qai/v1/credits/tiers` describes it.
public struct CreditTier: Codable, Sendable {
    /// Tier identifier (e.g. `"standard"`, `"lifetime"`, `"internal"`).
    public var tier: String

    /// Display label.
    public var label: String

    /// Margin the gateway adds on top of provider cost, in percent.
    public var marginPercent: Double

    /// What the tier offers.
    public var description: String

    /// How an account qualifies for it.
    public var requirements: String

    enum CodingKeys: String, CodingKey {
        case tier, label, description, requirements
        case marginPercent = "margin_percent"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tier = try c.decode(String.self, forKey: .tier)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        marginPercent = try c.decodeIfPresent(Double.self, forKey: .marginPercent) ?? 0
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        requirements = try c.decodeIfPresent(String.self, forKey: .requirements) ?? ""
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

    /// Expected monthly spend in USD; `expected_monthly_usd` on the wire.
    public var expectedMonthlyUsd: Double?

    /// Website URL.
    public var website: String?

    public init(useCase: String, company: String? = nil, expectedMonthlyUsd: Double? = nil, website: String? = nil) {
        self.useCase = useCase
        self.company = company
        self.expectedMonthlyUsd = expectedMonthlyUsd
        self.website = website
    }

    enum CodingKeys: String, CodingKey {
        case company, website
        case useCase = "use_case"
        case expectedMonthlyUsd = "expected_monthly_usd"
    }
}

/// Response from the developer program application.
public struct DevProgramApplyResponse: Codable, Sendable {
    /// Application status.
    public var status: String
}

// MARK: - Lifetime

/// A one-time lifetime unlock product.
public struct LifetimePlan: Codable, Sendable {
    public var id: String
    public var label: String
    public var amountUsd: Double
    /// Seats included; 0 means unlimited.
    public var seats: Int64
    public var description: String?

    enum CodingKeys: String, CodingKey {
        case id, label, seats, description
        case amountUsd = "amount_usd"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        amountUsd = try c.decodeIfPresent(Double.self, forKey: .amountUsd) ?? 0
        seats = try c.decodeIfPresent(Int64.self, forKey: .seats) ?? 0
        description = try c.decodeIfPresent(String.self, forKey: .description)
    }
}

/// Response from `lifetimePlans()`.
public struct LifetimePlansResponse: Codable, Sendable {
    public var plans: [LifetimePlan]
}

/// Request body for buying a lifetime plan.
public struct LifetimePurchaseRequest: Codable, Sendable {
    public var planId: String
    public var successUrl: String?
    public var cancelUrl: String?

    public init(planId: String, successUrl: String? = nil, cancelUrl: String? = nil) {
        self.planId = planId
        self.successUrl = successUrl
        self.cancelUrl = cancelUrl
    }

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case successUrl = "success_url"
        case cancelUrl = "cancel_url"
    }
}

/// Response from `lifetimePurchase(_:)`: where to pay.
public struct LifetimePurchaseResponse: Codable, Sendable {
    public var checkoutUrl: String
    public var sessionId: String
    public var plan: LifetimePlan

    enum CodingKeys: String, CodingKey {
        case plan
        case checkoutUrl = "checkout_url"
        case sessionId = "session_id"
    }
}
