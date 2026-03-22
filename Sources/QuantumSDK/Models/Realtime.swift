import Foundation

// MARK: - Realtime Session

/// Response from the `/qai/v1/realtime/session` endpoint.
public struct RealtimeSession: Codable, Sendable {
    /// Ephemeral token for direct WebSocket connection.
    public var ephemeralToken: String

    /// WebSocket URL to connect to.
    public var url: String

    /// Signed WebSocket URL (ElevenLabs).
    public var signedUrl: String?

    /// Session ID for billing.
    public var sessionId: String

    /// Provider name (e.g. "xai", "elevenlabs").
    public var provider: String?

    enum CodingKeys: String, CodingKey {
        case url, provider
        case ephemeralToken = "ephemeral_token"
        case signedUrl = "signed_url"
        case sessionId = "session_id"
    }
}

// MARK: - Realtime Config

/// Configuration for a realtime voice session.
public struct RealtimeConfig: Sendable {
    /// Voice to use (e.g. "Sal", "Eve", "Vesper"). Default: "Sal".
    public var voice: String?

    /// System instructions for the AI.
    public var instructions: String?

    /// PCM sample rate in Hz. Default: 24000.
    public var sampleRate: Int?

    /// Tool definitions (xAI Realtime API format).
    public var tools: [[String: AnyCodable]]?

    public init(
        voice: String? = nil,
        instructions: String? = nil,
        sampleRate: Int? = nil,
        tools: [[String: AnyCodable]]? = nil
    ) {
        self.voice = voice
        self.instructions = instructions
        self.sampleRate = sampleRate
        self.tools = tools
    }
}
