import Foundation

// MARK: - HeyGen Avatar Realtime (Broadcast)
//
// A realtime session makes an avatar speak live and publishes a plain HLS
// stream (720p). Sessions are PREPAID: the entire `maxDurationSeconds` block
// is charged at create time and is NOT refunded on early cancel (cancelling
// only stops the upstream meter).
//
// Recommended flow:
// 1. `createAvatarRealtimeSession` → `streamId`
// 2. Poll `getAvatarRealtimeSession` (~2s) until `status == "streaming"`,
//    then play `hlsUrl`
// 3. For `text_stream` sessions, append text with `sendAvatarRealtimeText`
//    and close with `isFinal: true` (idle timeout is ~30s without new text)
// 4. `cancelAvatarRealtimeSession` as soon as you're done
//
// Not to be confused with the WebSocket voice realtime API (`RealtimeSession`).

/// Audio input union for `audio`-type realtime sessions,
/// discriminated by `inputType` (wire field `type`).
public struct AvatarAudioInput: Codable, Sendable {
    /// Input kind: "url" | "asset_id" | "base64".
    public var inputType: String

    /// Publicly accessible HTTPS URL (when `inputType == "url"`).
    public var url: String?

    /// HeyGen asset id from an asset upload (when `inputType == "asset_id"`).
    public var assetId: String?

    /// MIME type, e.g. "audio/mpeg" (when `inputType == "base64"`).
    public var mediaType: String?

    /// Base64-encoded audio bytes (when `inputType == "base64"`).
    public var data: String?

    public init(
        inputType: String,
        url: String? = nil,
        assetId: String? = nil,
        mediaType: String? = nil,
        data: String? = nil
    ) {
        self.inputType = inputType
        self.url = url
        self.assetId = assetId
        self.mediaType = mediaType
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case url, data
        case inputType = "type"
        case assetId = "asset_id"
        case mediaType = "media_type"
    }
}

/// Request body for creating a live avatar session (prepaid).
public struct AvatarRealtimeRequest: Codable, Sendable {
    /// Session kind: "tts" | "audio" | "text_stream".
    public var sessionType: String

    /// HeyGen photo-avatar / motion-avatar look id (required for all kinds).
    public var avatarId: String

    /// Voice id — required for "tts" and "text_stream", must be omitted for "audio".
    public var voiceId: String?

    /// The fixed script ("tts") or the initial non-empty seed ("text_stream").
    public var text: String?

    /// Audio input — required for "audio", must be omitted for "tts"/"text_stream".
    public var audio: AvatarAudioInput?

    /// Prepaid block in seconds (1–3600). The whole block is charged at
    /// create time; early cancel does NOT refund.
    public var maxDurationSeconds: Int

    public init(
        sessionType: String,
        avatarId: String,
        maxDurationSeconds: Int,
        voiceId: String? = nil,
        text: String? = nil,
        audio: AvatarAudioInput? = nil
    ) {
        self.sessionType = sessionType
        self.avatarId = avatarId
        self.maxDurationSeconds = maxDurationSeconds
        self.voiceId = voiceId
        self.text = text
        self.audio = audio
    }

    enum CodingKeys: String, CodingKey {
        case text, audio
        case sessionType = "type"
        case avatarId = "avatar_id"
        case voiceId = "voice_id"
        case maxDurationSeconds = "max_duration_seconds"
    }
}

/// Response from creating a live avatar session.
public struct AvatarRealtimeCreateResponse: Codable, Sendable {
    /// Session id — use in the status/text/cancel calls.
    public var streamId: String

    /// Always "pending" at create.
    public var status: String

    /// Echo of `maxDurationSeconds`.
    public var prepaidSeconds: Int

    /// Ticks charged for the prepaid block.
    public var costTicks: Int64

    /// Post-deduction credit balance in ticks (from the X-QAI-Balance-After
    /// header; Receipt Pattern).
    public var balanceAfter: Int64?

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case status
        case streamId = "stream_id"
        case prepaidSeconds = "prepaid_seconds"
        case costTicks = "cost_ticks"
        case balanceAfter = "balance_after"
        case requestId = "request_id"
    }
}

/// Response from a session status check.
public struct AvatarRealtimeStatusResponse: Codable, Sendable {
    /// Session id.
    public var streamId: String

    /// "pending" | "streaming" | "completed" | "error".
    public var status: String

    /// HLS `.m3u8` playback URL (720p); present once streaming.
    public var hlsUrl: String?

    /// Failure detail when `status == "error"`.
    public var errorMessage: String?

    /// On completed text_stream sessions: "final_marker" | "idle_timeout".
    public var endReason: String?

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case status
        case streamId = "stream_id"
        case hlsUrl = "hls_url"
        case errorMessage = "error_message"
        case endReason = "end_reason"
        case requestId = "request_id"
    }
}

/// Request body for appending a text delta to a `text_stream` session.
public struct AvatarRealtimeTextRequest: Codable, Sendable {
    /// Text fragment to append (a token or coalesced batch). Required unless
    /// `isFinal` is true, in which case it may be empty (and is omitted from
    /// the wire body).
    public var delta: String

    /// True closes the text input (appending afterwards fails upstream with
    /// a 410 provider_error). Wire field: `final`.
    public var isFinal: Bool

    public init(delta: String = "", isFinal: Bool = false) {
        self.delta = delta
        self.isFinal = isFinal
    }

    /// A delta-append request.
    public static func delta(_ delta: String) -> AvatarRealtimeTextRequest {
        AvatarRealtimeTextRequest(delta: delta, isFinal: false)
    }

    /// A close-the-stream request (empty final marker).
    public static func finalMarker() -> AvatarRealtimeTextRequest {
        AvatarRealtimeTextRequest(delta: "", isFinal: true)
    }

    enum CodingKeys: String, CodingKey {
        case delta
        case isFinal = "final"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        delta = try container.decodeIfPresent(String.self, forKey: .delta) ?? ""
        isFinal = try container.decodeIfPresent(Bool.self, forKey: .isFinal) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Empty delta is omitted entirely (final-marker requests carry only `final`).
        if !delta.isEmpty {
            try container.encode(delta, forKey: .delta)
        }
        try container.encode(isFinal, forKey: .isFinal)
    }
}

/// Response from appending a text delta.
public struct AvatarRealtimeTextResponse: Codable, Sendable {
    /// Always true on success.
    public var ok: Bool

    /// Total text bytes buffered for the session so far.
    public var bufferedBytes: Int64

    /// Echo of the request's `final` flag. Wire field: `final`.
    public var isFinal: Bool

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case ok
        case bufferedBytes = "buffered_bytes"
        case isFinal = "final"
        case requestId = "request_id"
    }
}

/// Response from cancelling a session early.
public struct AvatarRealtimeCancelResponse: Codable, Sendable {
    /// Session id.
    public var streamId: String

    /// True = this call initiated cancellation; false = the session was
    /// already terminal (cancel is idempotent).
    public var cancelled: Bool

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case cancelled
        case streamId = "stream_id"
        case requestId = "request_id"
    }
}
