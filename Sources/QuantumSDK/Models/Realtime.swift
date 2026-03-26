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

/// Backwards-compatible alias for ``RealtimeSession``.
public typealias RealtimeSessionResponse = RealtimeSession

// MARK: - Realtime Config

/// Configuration for a realtime voice session.
public struct RealtimeConfig: Codable, Sendable {
    /// Voice to use (e.g. "Sal", "Eve", "Vesper"). Default: "Sal".
    public var voice: String?

    /// System instructions for the AI.
    public var instructions: String?

    /// Model to use for the realtime session.
    public var model: String?

    /// PCM sample rate in Hz. Default: 24000.
    public var sampleRate: Int?

    /// Tool definitions (xAI Realtime API format).
    public var tools: [AnyCodable]?

    public init(
        voice: String? = nil,
        instructions: String? = nil,
        model: String? = nil,
        sampleRate: Int? = nil,
        tools: [AnyCodable]? = nil
    ) {
        self.voice = voice
        self.instructions = instructions
        self.model = model
        self.sampleRate = sampleRate
        self.tools = tools
    }

    enum CodingKeys: String, CodingKey {
        case voice, instructions, model, tools
        case sampleRate = "sample_rate"
    }
}

// MARK: - Realtime Event

/// Parsed incoming event from the realtime API.
public enum RealtimeEvent: Sendable {
    /// Session configuration acknowledged.
    case sessionReady

    /// Base64-encoded PCM audio chunk from the assistant.
    case audioDelta(delta: String)

    /// Partial transcript text.
    case transcriptDelta(delta: String, source: String)

    /// Final transcript for a completed utterance.
    case transcriptDone(transcript: String, source: String)

    /// Voice activity detected -- user started speaking.
    case speechStarted

    /// Voice activity ended -- user stopped speaking.
    case speechStopped

    /// The model is requesting a function/tool call.
    case functionCall(name: String, callId: String, arguments: String)

    /// The model finished its response turn.
    case responseDone

    /// An error from the realtime API.
    case error(message: String)

    /// An event type we don't explicitly handle.
    case unknown(AnyCodable)
}
