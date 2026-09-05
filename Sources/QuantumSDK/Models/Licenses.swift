import Foundation

// Cross-app licences.
//
// Licences are minted by the fulfilment paths (Stripe webhook, in-app
// purchase verification) and carry an Ed25519-signed JWT that a client caches
// locally and verifies offline. These routes are the read / maintain surface:
//
// - `licensesMine` lists the caller's licences, each with a freshly signed
//   JWT (a call renews the offline-validity window).
// - `licenseRevocations` is a public, id-only feed a client polls to drop
//   refunded or disputed licences from its cache.
// - `licensePublicKey` is the public JWKS-style verification key.
//
// The revocations and public-key routes do not require authentication.

/// One licence held by the caller.
public struct License: Codable, Sendable {
    /// Licence identifier.
    public var id: String

    /// App the licence unlocks.
    public var app: String?

    /// SKU purchased.
    public var sku: String?

    /// Fulfilment source (e.g. `"stripe"`, `"app_store"`, `"google_play"`).
    public var source: String?

    /// Provider-side transaction id the licence was minted from.
    public var sourceTransaction: String?

    /// RFC3339 issue timestamp of the underlying licence row (not of the JWT,
    /// which is re-signed on every read).
    public var issuedAt: String?

    /// RFC3339 expiry.
    public var expiresAt: String?

    /// `"active"` or `"revoked"`.
    public var status: String?

    /// The signed licence JWT. Absent for revoked licences; they stay in the
    /// list so a client can tell "receipt landed, access withdrawn" apart
    /// from "receipt never arrived".
    public var licenseKey: String?

    enum CodingKeys: String, CodingKey {
        case id, app, sku, source, status
        case sourceTransaction = "source_transaction"
        case issuedAt = "issued_at"
        case expiresAt = "expires_at"
        case licenseKey = "license_key"
    }
}

/// Response from `GET /qai/v1/licenses/mine`.
public struct LicensesResponse: Codable, Sendable {
    /// The caller's licences.
    @NullToEmpty public var licenses: [License]
}

/// Response from `GET /qai/v1/licenses/revocations`.
public struct LicenseRevocationsResponse: Codable, Sendable {
    /// Licence ids revoked strictly after the requested `since`.
    @NullToEmpty public var revokedIds: [String]

    /// The `since` bound the server actually applied, RFC3339.
    public var since: String?

    /// Server time the feed was generated, RFC3339. Use it as the next poll's
    /// `since`.
    public var asOf: String?

    enum CodingKeys: String, CodingKey {
        case since
        case revokedIds = "revoked_ids"
        case asOf = "as_of"
    }
}

/// One JWKS entry carrying the licence verification key.
public struct LicenseJwk: Codable, Sendable {
    /// Key type: `"OKP"` for the Ed25519 licence key.
    public var kty: String?

    /// Curve: `"Ed25519"`.
    public var crv: String?

    /// Signing algorithm: `"EdDSA"`.
    public var alg: String?

    /// Key use: `"sig"`. Wire key `use`.
    public var keyUse: String?

    /// Key id, matching the `kid` header of issued licence JWTs.
    public var kid: String

    /// The base64url (unpadded) Ed25519 public key.
    public var x: String

    enum CodingKeys: String, CodingKey {
        case kty, crv, alg, kid, x
        case keyUse = "use"
    }
}

/// Response from `GET /qai/v1/licenses/public-key`.
///
/// Rotation appends a new entry while keeping the old one, so a client must
/// select by `kid` rather than assuming a single key.
public struct LicensePublicKeyResponse: Codable, Sendable {
    /// The active verification keys.
    @NullToEmpty public var keys: [LicenseJwk]
}
