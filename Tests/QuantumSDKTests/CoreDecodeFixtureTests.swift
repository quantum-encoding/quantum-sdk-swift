import XCTest
@testable import QuantumSDK

/// Every touched response type decodes the shape its gateway handler
/// writes.
final class CoreDecodeFixtureTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: Auth

    func testASignInReadsTheGatewaysUserShape() throws {
        // routes_account.go writes display_name / photo_url and the key.
        let body = """
        {"token":"qai_s_x","session_token":"qai_s_x","expires_at":"2026-09-06T00:00:00Z",
         "api_key":"qai_k_y","email":"a@b.c","credit_usd":1.5,
         "user":{"id":"u1","email":"a@b.c","display_name":"Ada","photo_url":"https://p/x.png","credit_ticks":15000000000,"role":"user"}}
        """
        let r = try decode(AuthResponse.self, body)
        XCTAssertEqual(r.token, "qai_s_x")
        XCTAssertEqual(r.apiKey, "qai_k_y")
        XCTAssertEqual(r.expiresAt, "2026-09-06T00:00:00Z")
        XCTAssertEqual(r.creditUsd, 1.5)
        XCTAssertEqual(r.user.name, "Ada")
        XCTAssertEqual(r.user.avatarUrl, "https://p/x.png")
        XCTAssertEqual(r.user.creditTicks, 15_000_000_000)
        XCTAssertEqual(r.user.role, "user")
    }

    func testAnAuthResponseDescriptionMasksBothCredentials() throws {
        let r = try decode(AuthResponse.self, #"{"token":"qai_s_LIVESESSIONTOKEN","api_key":"qai_k_LIVEAPIKEY","user":{"id":"u1"}}"#)
        for shown in ["\(r)", String(reflecting: r), r.description] {
            XCTAssertFalse(shown.contains("LIVESESSIONTOKEN"), shown)
            XCTAssertFalse(shown.contains("LIVEAPIKEY"), shown)
        }
        XCTAssertTrue(r.description.contains("[redacted]"))
    }

    func testVerifyKeyAndRevokeSessionShapes() throws {
        let v = try decode(VerifyKeyResponse.self, #"{"verified":true,"user_id":"u1","apple_sub":"001.x","email":"a@b.c","created_at":"2026-01-01T00:00:00Z"}"#)
        XCTAssertTrue(v.verified)
        XCTAssertEqual(v.userId, "u1")
        XCTAssertEqual(v.appleSub, "001.x")
        let s = try decode(RevokeSessionResponse.self, #"{"status":"revoked"}"#)
        XCTAssertEqual(s.status, "revoked")
    }

    // MARK: Account

    func testAccountBalanceReadsBalanceTicks() throws {
        // routes_account.go: user_id, balance_ticks, balance_usd, ticks_per_usd.
        let b = try decode(BalanceResponse.self, #"{"user_id":"u1","balance_ticks":25000000000,"balance_usd":2.5,"ticks_per_usd":10000000000}"#)
        XCTAssertEqual(b.userId, "u1")
        XCTAssertEqual(b.balanceTicks, 25_000_000_000)
        XCTAssertEqual(b.balanceUsd, 2.5)
        XCTAssertEqual(b.ticksPerUsd, 10_000_000_000)
    }

    func testPricingIsAMapKeyedByModelId() throws {
        // routes_meta.go writes {"pricing": {<id>: entry}, "count", "margin"}.
        let body = """
        {"pricing":{"claude-sonnet-4-6":{"provider":"anthropic","model":"claude-sonnet-4-6",
            "display_name":"Claude Sonnet 4.6","category":"Text","context_window":"200K",
            "input_per_million":3.3,"output_per_million":16.5,"cached_per_million":0.33},
            "grok-imagine-image":{"provider":"xai","model":"grok-imagine-image","display_name":"Grok Imagine",
            "category":"Image","per_unit_price":0.077,"price_unit":"per image"}},"count":2,"margin":0.1}
        """
        let resp = try decode(PricingResponse.self, body)
        let sonnet = try XCTUnwrap(resp.pricing["claude-sonnet-4-6"])
        XCTAssertEqual(sonnet.provider, "anthropic")
        XCTAssertEqual(sonnet.inputPerMillion, 3.3)
        XCTAssertEqual(sonnet.cachedPerMillion, 0.33)
        XCTAssertEqual(sonnet.contextWindow, "200K")
        let image = try XCTUnwrap(resp.pricing["grok-imagine-image"])
        XCTAssertEqual(image.perUnitPrice, 0.077)
        XCTAssertEqual(image.priceUnit, "per image")
        XCTAssertEqual(image.inputPerMillion, 0)
        let asInfo: PricingInfo = image
        XCTAssertEqual(asInfo.model, "grok-imagine-image")
    }

    func testUsageSummaryTolerantOfMissingByProvider() throws {
        let r = try decode(UsageSummaryResponse.self, #"{"months":[{"month":"2026-08","total_requests":3,"total_input_tokens":1,"total_output_tokens":2,"total_cost_usd":0.1,"total_margin_usd":0.01}]}"#)
        XCTAssertEqual(r.months[0].byProvider.count, 0)
    }

    func testAccountDeletionShapes() throws {
        let d = try decode(AccountDeleteResponse.self, #"{"status":"deleted","deleted_at":"2026-09-05T00:00:00Z","content_purged_after":"2026-10-05T00:00:00Z","records_kept_until":"2033-09-05T00:00:00Z","forfeited_credit_usd":1.25,"detail":"Your account and sign-in have been deleted."}"#)
        XCTAssertEqual(d.status, "deleted")
        XCTAssertEqual(d.forfeitedCreditUsd, 1.25)
        let active = try decode(DeletionStatus.self, #"{"status":"active"}"#)
        XCTAssertEqual(active.status, "active")
        XCTAssertNil(active.purgeAfter)
        let pending = try decode(DeletionStatus.self, #"{"status":"deleted","app":"cosmicduck","requested_at":"t","purge_after":"p","retention_until":"r"}"#)
        XCTAssertEqual(pending.purgeAfter, "p")
    }

    // MARK: Credits

    func testCreditPacksReadTheGatewayShape() throws {
        // routes_credits.go: {id,label,amount_usd,ticks,popular?,description?}.
        let r = try decode(CreditPacksResponse.self, #"{"packs":[{"id":"p5","label":"$5 Starter","amount_usd":5,"ticks":50000000000,"popular":true}]}"#)
        let p = r.packs[0]
        XCTAssertEqual(p.id, "p5")
        XCTAssertEqual(p.label, "$5 Starter")
        XCTAssertEqual(p.amountUsd, 5)
        XCTAssertEqual(p.ticks, 50_000_000_000)
        XCTAssertEqual(p.popular, true)
        XCTAssertNil(p.description)
    }

    func testTiersReadTheGatewaysTierInfoShape() throws {
        // billing.TierInfo: {tier,label,margin_percent,description,requirements}.
        let body = #"{"tiers":[{"tier":"standard","label":"Standard","margin_percent":10,"description":"Pay as you go","requirements":"None"}]}"#
        let t = try decode(CreditTiersResponse.self, body).tiers[0]
        XCTAssertEqual(t.tier, "standard")
        XCTAssertEqual(t.label, "Standard")
        XCTAssertEqual(t.marginPercent, 10)
        XCTAssertEqual(t.requirements, "None")
    }

    func testLifetimeShapes() throws {
        let plans = try decode(LifetimePlansResponse.self, #"{"plans":[{"id":"lt1","label":"Lifetime","amount_usd":499,"seats":1}]}"#)
        XCTAssertEqual(plans.plans[0].amountUsd, 499)
        XCTAssertEqual(plans.plans[0].seats, 1)
        let purchase = try decode(LifetimePurchaseResponse.self, #"{"checkout_url":"https://checkout","session_id":"cs_1","plan":{"id":"lt1","label":"Lifetime","amount_usd":499}}"#)
        XCTAssertEqual(purchase.checkoutUrl, "https://checkout")
        XCTAssertEqual(purchase.sessionId, "cs_1")
        XCTAssertEqual(purchase.plan.seats, 0)
    }

    // MARK: Keys

    func testKeyResponsesDecodeAndMaskSecrets() throws {
        let created = try decode(CreateKeyResponse.self, #"{"key":"qai_k_SECRETVALUE","details":{"id":"k1","name":"n","key_prefix":"qai_k_SE","scope":{"region":"eu"},"spent_ticks":0,"revoked":false,"created_at":"t"}}"#)
        XCTAssertEqual(created.key, "qai_k_SECRETVALUE")
        XCTAssertEqual(created.details.scopeRegion, .europe, "the scope alias parses")
        XCTAssertFalse("\(created)".contains("SECRETVALUE"))

        let devices = try decode(ListDeviceKeysResponse.self, #"{"devices":[{"key_id":"k2","device_id":"iphone","key_prefix":"qai_k_ab","created_at":"t"}]}"#)
        XCTAssertEqual(devices.devices[0].deviceId, "iphone")

        let rotated = try decode(RotateKeyResponse.self, #"{"key":"qai_k_NEWSECRET","details":{"id":"k3","name":"n","key_prefix":"qai_k_NE"},"old_key_id":"k1"}"#)
        XCTAssertEqual(rotated.oldKeyId, "k1")
        XCTAssertFalse("\(rotated)".contains("NEWSECRET"))

        let usage = try decode(KeyUsageResponse.self, #"{"days":[{"day":"2026-09-01","requests":4,"cost_usd":0.02}],"models":[{"model":"m","requests":4,"cost_usd":0.02}],"total_cost_usd":0.02}"#)
        XCTAssertEqual(usage.days[0].inputTokens, 0)
        XCTAssertEqual(usage.totalCostUsd, 0.02)

        let ephemeral = try decode(EphemeralKeyResponse.self, #"{"token":"qai_eph_SECRET","expires_at":"t","base_url":"https://api.quantumencoding.ai"}"#)
        XCTAssertEqual(ephemeral.expiresAt, "t")
        XCTAssertFalse("\(ephemeral)".contains("eph_SECRET"))

        let partner = try decode(PartnerKeyResponse.self, #"{"key":"qai_k_PARTNERSECRET","details":{"id":"k4","name":"partner:u"},"base_url":"https://api.quantumencoding.ai"}"#)
        XCTAssertEqual(partner.details.id, "k4")
        XCTAssertFalse("\(partner)".contains("PARTNERSECRET"))
    }

    // MARK: Chat / session

    func testSessionChatDecodesWithoutCompacted() throws {
        // routes_sessions.go omits `compacted` on every turn that was not compacted.
        let body = #"{"session_id":"s1","response":{"id":"r1","model":"m","content":[{"type":"text","text":"hi"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1,"cost_ticks":2}},"context":{"turn_count":1,"estimated_tokens":10}}"#
        let r = try decode(SessionChatResponse.self, body)
        XCTAssertEqual(r.sessionId, "s1")
        XCTAssertFalse(r.context.compacted)
        XCTAssertEqual(r.response.text, "hi")
    }

    func testChatUsageLeavesAbsentCountsNil() throws {
        let u = try decode(ChatUsage.self, #"{"input_tokens":3,"output_tokens":9,"cost_ticks":5}"#)
        XCTAssertNil(u.cachedTokens)
        XCTAssertNil(u.reasoningTokens)
        let r = try decode(ChatUsage.self, #"{"input_tokens":3,"output_tokens":9,"cost_ticks":5,"cached_tokens":2,"reasoning_tokens":4}"#)
        XCTAssertEqual(r.cachedTokens, 2)
        XCTAssertEqual(r.reasoningTokens, 4)
    }

    func testChatResponseNullContentIsEmpty() throws {
        let r = try decode(ChatResponse.self, #"{"id":"r","model":"m","content":null,"stop_reason":"refusal"}"#)
        XCTAssertEqual(r.content.count, 0)
        XCTAssertTrue(r.isRefusal)
    }

    func testAMalformedContentBlockArrayIsAnErrorNotNil() throws {
        let null = try decode(ChatMessage.self, #"{"role":"assistant","content_blocks":null}"#)
        XCTAssertNil(null.contentBlocks)
        XCTAssertThrowsError(try decode(ChatMessage.self, #"{"role":"assistant","content_blocks":[{"type":42}]}"#))
    }

    func testEstimateShape() throws {
        let e = try decode(EstimateResponse.self, #"{"estimated_cost_ticks":123456,"estimated_cost_usd":0.0000123456}"#)
        XCTAssertEqual(e.estimatedCostTicks, 123_456)
        XCTAssertEqual(e.model, "")
    }

    func testRegionDecodesAliasesAndRejectsUnknown() throws {
        XCTAssertEqual(try decode([Region].self, #"["us","EU","apac","americas"]"#), [.americas, .europe, .asia, .americas])
        XCTAssertThrowsError(try decode(Region.self, #""orbital""#))
    }

    func testParameterDefaultsMayBeArraysOrObjects() throws {
        let spec = try decode(ParameterSpec.self, #"{"id":"sizes","label":"Sizes","kind":"enum","default":["1024x1024","512x512"]}"#)
        guard case let .array(values)? = spec.defaultValue else {
            return XCTFail("expected an array default")
        }
        XCTAssertEqual(values.first?.stringValue, "1024x1024")
        XCTAssertNil(spec.defaultValue?.intValue)
    }

    func testAnyCodableEqualityIsStructural() {
        XCTAssertEqual(AnyCodable(["a": 1, "b": [true, "x"]]), AnyCodable(["b": [true, "x"], "a": 1.0]))
        XCTAssertEqual(AnyCodable(1).hashValue, AnyCodable(1.0).hashValue)
        XCTAssertNotEqual(AnyCodable(1), AnyCodable(true))
        XCTAssertNotEqual(AnyCodable(0), AnyCodable(false))
        XCTAssertEqual(AnyCodable(AnyCodable("x")), AnyCodable("x"))
        XCTAssertEqual(AnyCodable(NSNull()), AnyCodable(nilLiteral: ()))
    }
}
