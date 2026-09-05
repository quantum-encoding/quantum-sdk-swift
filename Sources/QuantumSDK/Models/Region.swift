import Foundation

/// An inference region for region-scoped routing.
///
/// The gateway routes inference in-region when a region is attached to the
/// work (EU AI Act Art 50): a key minted with a region scope routes every
/// request made with it, and a chat request can override that scope for one
/// call. Regions pick the serving endpoints inside a single gateway host;
/// there is no region-per-hostname.
///
/// Two places a region is expressed on the wire, both typed here:
/// - key mint: ``CreateKeyRequest/region``
/// - per-chat override: ``ChatRequest/region`` (chat only — the agent
///   endpoint routes by key scope by design)
///
/// The backend accepts region ALIASES and silently degrades anything it
/// doesn't recognize to unscoped legacy routing — never an error. Every
/// place a region reaches the wire is typed, and both ``init(parsing:)`` and
/// `Decodable` reject unknown values, so a typo cannot route silently
/// unscoped.
public enum Region: String, Codable, Sendable, CaseIterable {
    /// US-serving endpoints (us-central1).
    case americas
    /// EU-serving endpoints (europe-west4).
    case europe
    /// Asia-serving endpoints (DashScope).
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

    /// Decodes with the same alias rules as ``init(parsing:)``; an unknown
    /// value is a decode error.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let region = Region(parsing: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unknown region '\(raw)' — expected americas | europe | asia (aliases: us, eu, apac)"
            )
        }
        self = region
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
