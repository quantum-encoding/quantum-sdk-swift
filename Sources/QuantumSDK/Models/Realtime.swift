import Foundation

// MARK: - Realtime Session

/// Response from the `/qai/v1/realtime/session` endpoint.
///
/// Two shapes share this type. An xAI session carries `ephemeralToken`,
/// `url` and no `provider`; an ElevenLabs session carries `signedUrl`
/// (whose query string is the credential) and `provider == "elevenlabs"`.
/// ``wsUrl`` picks whichever is set. Absent fields decode to `""`.
public struct RealtimeSession: Codable, Sendable {
    /// Ephemeral token for a direct xAI WebSocket connection.
    public var ephemeralToken: String

    /// WebSocket URL for an xAI session ("wss://api.x.ai/v1/realtime").
    public var url: String

    /// Signed WebSocket URL for an ElevenLabs session; the credential is in
    /// the URL.
    public var signedUrl: String

    /// Session ID for billing (pass to `realtimeEnd` on disconnect).
    public var sessionId: String

    /// `"elevenlabs"` for ElevenLabs sessions; empty for xAI.
    public var provider: String

    /// The WebSocket URL to connect to — `signedUrl` when set, else `url`.
    public var wsUrl: String {
        signedUrl.isEmpty ? url : signedUrl
    }

    public init(ephemeralToken: String = "", url: String = "", signedUrl: String = "", sessionId: String = "", provider: String = "") {
        self.ephemeralToken = ephemeralToken
        self.url = url
        self.signedUrl = signedUrl
        self.sessionId = sessionId
        self.provider = provider
    }

    enum CodingKeys: String, CodingKey {
        case url, provider
        case ephemeralToken = "ephemeral_token"
        case signedUrl = "signed_url"
        case sessionId = "session_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ephemeralToken = try c.decodeIfPresent(String.self, forKey: .ephemeralToken) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        signedUrl = try c.decodeIfPresent(String.self, forKey: .signedUrl) ?? ""
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
    }
}

/// The token and the signed URL are credentials, so string conversion,
/// interpolation and `dump` mask them.
extension RealtimeSession: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        let masked = { (value: String) in value.isEmpty ? "" : "<redacted>" }
        return "RealtimeSession(ephemeralToken: \(masked(ephemeralToken)), url: \(url), signedUrl: \(masked(signedUrl)), sessionId: \(sessionId), provider: \(provider))"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(self, children: [
            "ephemeralToken": ephemeralToken.isEmpty ? "" : "<redacted>",
            "url": url,
            "signedUrl": signedUrl.isEmpty ? "" : "<redacted>",
            "sessionId": sessionId,
            "provider": provider,
        ])
    }
}

/// Backwards-compatible alias for ``RealtimeSession``.
public typealias RealtimeSessionResponse = RealtimeSession

// MARK: - Realtime Config

/// Configuration for a realtime voice session over the gateway proxy.
public struct RealtimeConfig: Encodable, Sendable {
    /// Voice to use (e.g. "Sal", "Eve", "Vesper" on xAI). Default: "Sal".
    public var voice: String

    /// System instructions for the AI.
    public var instructions: String

    /// PCM sample rate in Hz. Default: 24000.
    public var sampleRate: Int

    /// Tool definitions (xAI Realtime API format).
    public var tools: [AnyCodable]

    /// Model for the session (e.g. "grok-realtime-beta"). Sent to the gateway
    /// as the `model` query parameter, which it forwards upstream and bills
    /// against; empty means the gateway default. Also placed in the
    /// `session.update` frame.
    public var model: String

    public init(
        voice: String = "Sal",
        instructions: String = "",
        sampleRate: Int = 24000,
        tools: [AnyCodable] = [],
        model: String = ""
    ) {
        self.voice = voice
        self.instructions = instructions
        self.sampleRate = sampleRate
        self.tools = tools
        self.model = model
    }

    enum CodingKeys: String, CodingKey {
        case voice, instructions, tools, model
        case sampleRate = "sample_rate"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(voice, forKey: .voice)
        try c.encode(instructions, forKey: .instructions)
        try c.encode(sampleRate, forKey: .sampleRate)
        if !tools.isEmpty { try c.encode(tools, forKey: .tools) }
        if !model.isEmpty { try c.encode(model, forKey: .model) }
    }
}

/// Connection parameters for the ElevenLabs conversational-voice proxy.
///
/// Every field is optional: the gateway falls back to its own default voice
/// and model, and creates a conversational agent on the fly when `agentId` is
/// absent.
public struct ElevenLabsProxyConfig: Sendable {
    /// ElevenLabs voice id. Applied when the gateway creates the agent for
    /// this session; an existing `agentId` keeps its own voice.
    public var voiceId: String?

    /// ElevenLabs model id. Applied when the gateway creates the agent for
    /// this session, like `voiceId`.
    public var model: String?

    /// An existing conversational agent to connect to. Omit to have the
    /// gateway create one for this session.
    public var agentId: String?

    public init(voiceId: String? = nil, model: String? = nil, agentId: String? = nil) {
        self.voiceId = voiceId
        self.model = model
        self.agentId = agentId
    }

    /// The proxy's query string, including the leading `?` (empty when
    /// nothing is set). Values are percent-encoded.
    var queryString: String {
        var params: [String] = []
        if let voiceId { params.append("voice_id=\(Self.encode(voiceId))") }
        if let model { params.append("model=\(Self.encode(model))") }
        if let agentId { params.append("agent_id=\(Self.encode(agentId))") }
        return params.isEmpty ? "" : "?" + params.joined(separator: "&")
    }

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
    }
}

// MARK: - Realtime Event

/// Parsed incoming event from the realtime API.
public enum RealtimeEvent: Sendable {
    /// Session configuration acknowledged.
    case sessionReady

    /// Base64-encoded PCM audio chunk from the assistant.
    case audioDelta(delta: String)

    /// Partial transcript text. `source` is "input" for user speech,
    /// "output" for assistant speech.
    case transcriptDelta(delta: String, source: String)

    /// Final transcript for a completed utterance. `source` is "input" for
    /// user speech, "output" for assistant speech.
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

    /// The peer closed the socket. `reason` carries the close frame's text,
    /// which the gateway uses to say why ("insufficient balance", "session
    /// duration limit reached"); empty on a plain hang-up.
    case closed(code: Int?, reason: String)

    /// The socket failed while reading; nothing more will arrive.
    case transportError(message: String)

    /// An event type we don't explicitly handle (the raw JSON, or the raw
    /// text when the frame was not JSON).
    case unknown(AnyCodable)
}

// MARK: - Protocol helpers

/// Builds the `session.update` frame from a config. A `gpt-` model gets the
/// OpenAI frame shape; everything else, including the gateway's
/// `grok-realtime` defaults, gets xAI's.
func buildSessionUpdate(_ config: RealtimeConfig) -> [String: AnyCodable] {
    let isOpenAI = config.model.hasPrefix("gpt-")

    var session: [String: AnyCodable] = [
        "voice": AnyCodable(config.voice),
        "instructions": AnyCodable(config.instructions),
        "turn_detection": AnyCodable(["type": "server_vad"] as [String: Any]),
        "tools": AnyCodable(config.tools.map(\.value)),
    ]

    if !config.model.isEmpty {
        session["model"] = AnyCodable(config.model)
    }

    if isOpenAI {
        session["modalities"] = AnyCodable(["text", "audio"])
        session["input_audio_format"] = AnyCodable("pcm16")
        session["output_audio_format"] = AnyCodable("pcm16")
        session["input_audio_transcription"] = AnyCodable(["model": "gpt-4o-mini-transcribe"] as [String: Any])
    } else {
        session["input_audio_transcription"] = AnyCodable(["model": "grok-2-audio"] as [String: Any])
        let format: [String: Any] = ["format": ["type": "audio/pcm", "rate": config.sampleRate] as [String: Any]]
        session["audio"] = AnyCodable(["input": format, "output": format] as [String: Any])
    }

    return [
        "type": AnyCodable("session.update"),
        "session": AnyCodable(session.mapValues(\.value)),
    ]
}

/// Parses one text frame from the realtime socket into an event.
func parseRealtimeEvent(_ text: String) -> RealtimeEvent {
    guard let data = text.data(using: .utf8),
          let raw = try? JSONSerialization.jsonObject(with: data),
          let object = raw as? [String: Any] else {
        return .unknown(AnyCodable(text))
    }

    let string = { (key: String) in object[key] as? String ?? "" }
    let type = string("type")

    switch type {
    case "session.updated":
        return .sessionReady

    case "response.audio.delta", "response.output_audio.delta":
        return .audioDelta(delta: string("delta"))

    case "response.audio_transcript.delta", "response.output_audio_transcript.delta":
        return .transcriptDelta(delta: string("delta"), source: "output")

    case "response.audio_transcript.done", "response.output_audio_transcript.done":
        return .transcriptDone(transcript: string("transcript"), source: "output")

    case "conversation.item.input_audio_transcription.completed":
        return .transcriptDone(transcript: string("transcript"), source: "input")

    case "input_audio_buffer.speech_started":
        return .speechStarted

    case "input_audio_buffer.speech_stopped":
        return .speechStopped

    case "response.function_call_arguments.done":
        return .functionCall(name: string("name"), callId: string("call_id"), arguments: string("arguments"))

    case "response.done":
        return .responseDone

    case "error":
        let nested = (object["error"] as? [String: Any])?["message"] as? String
        let message = nested ?? (object["message"] as? String) ?? "unknown error"
        return .error(message: message)

    default:
        return .unknown(AnyCodable(object))
    }
}
