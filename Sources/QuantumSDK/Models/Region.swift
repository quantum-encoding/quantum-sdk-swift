import Foundation

/// An inference region for region-scoped routing.
///
/// The gateway routes inference in-region when a region is attached to the
/// work (EU AI Act Art 50 compliance shipped 2026-08-19): a key minted with
/// a region scope routes every request made with it, and a chat request can
/// override that scope for one call. Regions pick the serving endpoints
/// inside the ONE gateway host (`https://api.quantumencoding.ai`) — there
/// is no region-per-hostname.
///
/// Two places a region is expressed on the wire, both typed here:
/// - key mint: ``CreateKeyRequest/region``
/// - per-chat override: ``ChatRequest/region`` (chat only — the agent
///   endpoint routes by key scope by design)
///
/// The backend accepts region ALIASES and silently degrades anything it
/// doesn't recognize to unscoped legacy routing — never an error.
/// ``init(parsing:)`` therefore rejects unknown values client-side instead
/// of letting a typo route silently unscoped.
public enum Region: String, Codable, Sendable, CaseIterable {
    /// US-serving endpoints (Vertex us-rep + us-central1).
    case americas
    /// EU-serving endpoints (Vertex eu-rep + europe-west4).
    case europe
    /// Asia-serving endpoints (DashScope token-plan ap-southeast-1 for
    /// qwen3.6+, intl for the long tail).
    case asia

    /// Parses a region, tolerating the aliases the backend accepts
    /// (`us`/`america`, `eu`/`eea`, `apac`/`asia-pacific`),
    /// case-insensitively. Returns `nil` for anything else — the backend
    /// would degrade an unknown value to unscoped routing without an error,
    /// so the SDK refuses it instead.
    public init?(parsing raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "americas", "america", "us":
            self = .americas
        case "europe", "eu", "eea":
            self = .europe
        case "asia", "apac", "asia-pacific":
            self = .asia
        default:
            return nil
        }
    }
}
