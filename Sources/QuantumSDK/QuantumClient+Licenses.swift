import Foundation

// Cross-app licence routes. Types live in Models/Licenses.swift.

extension QuantumClient {
    /// Lists the caller's licences, each active one carrying a freshly
    /// signed JWT. An active licence whose re-signing fails is left out of
    /// the list entirely rather than returned without a key; it reappears
    /// on a later call once signing succeeds.
    ///
    /// Pass `app` to filter to a single app, or nil for all apps.
    ///
    /// `GET /qai/v1/licenses/mine`
    public func licensesMine(app: String? = nil) async throws -> LicensesResponse {
        var path = "/qai/v1/licenses/mine"
        if let app { path += "?app=\(app.strictQueryEncoded)" }
        let (data, _): (LicensesResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Fetches licence ids revoked since a timestamp. No authentication
    /// required.
    ///
    /// `since` is RFC3339; omitting it defaults to 30 days ago server-side.
    ///
    /// `GET /qai/v1/licenses/revocations`
    public func licenseRevocations(since: String? = nil) async throws -> LicenseRevocationsResponse {
        var path = "/qai/v1/licenses/revocations"
        if let since { path += "?since=\(since.strictQueryEncoded)" }
        let (data, _): (LicenseRevocationsResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Fetches the public key(s) that verify licence JWTs. No
    /// authentication required.
    ///
    /// `GET /qai/v1/licenses/public-key`
    public func licensePublicKey() async throws -> LicensePublicKeyResponse {
        let (data, _): (LicensePublicKeyResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/licenses/public-key"
        )
        return data
    }
}
