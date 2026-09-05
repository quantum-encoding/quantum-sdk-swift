import Foundation

// MARK: - TTS

/// ElevenLabs voice synthesis tuning. All 0–1 ranges. The gateway forwards
/// `voice_settings` verbatim and sets nothing itself, so an unset field is
/// left to ElevenLabs' own default. Ignored by non-ElevenLabs models.
public struct TTSVoiceSettings: Codable, Sendable, Hashable {
    public var stability: Double?
    public var similarityBoost: Double?
    public var style: Double?
    public var useSpeakerBoost: Bool?

    public init(stability: Double? = nil, similarityBoost: Double? = nil,
                style: Double? = nil, useSpeakerBoost: Bool? = nil) {
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style
        self.useSpeakerBoost = useSpeakerBoost
    }

    enum CodingKeys: String, CodingKey {
        case stability, style
        case similarityBoost = "similarity_boost"
        case useSpeakerBoost = "use_speaker_boost"
    }
}

/// Request body for text-to-speech.
public struct TtsRequest: Codable, Sendable {
    /// TTS model (e.g. "tts-1", "eleven_multilingual_v2", "grok-3-tts").
    public var model: String

    /// Text to synthesise into speech.
    public var text: String

    /// Voice to use (e.g. "alloy", "echo", "nova", "Rachel").
    public var voice: String?

    /// Audio format (e.g. "mp3", "wav", "opus"). Default: "mp3".
    public var outputFormat: String?

    /// Speech rate (provider-dependent).
    public var speed: Double?

    /// Voice-steering instructions (tone, emotion, accent). OpenAI
    /// gpt-4o-mini-tts only — the backend drops it for tts-1/tts-1-hd, which
    /// reject the field. Omitted from the JSON body when nil.
    public var instructions: String?

    /// ElevenLabs synthesis tuning (ignored by other providers).
    public var voiceSettings: TTSVoiceSettings?

    public init(model: String, text: String, voice: String? = nil, outputFormat: String? = nil, speed: Double? = nil, instructions: String? = nil, voiceSettings: TTSVoiceSettings? = nil) {
        self.model = model
        self.text = text
        self.voice = voice
        self.outputFormat = outputFormat
        self.speed = speed
        self.instructions = instructions
        self.voiceSettings = voiceSettings
    }

    enum CodingKeys: String, CodingKey {
        case model, text, voice, speed, instructions
        case outputFormat = "format"
        case voiceSettings = "voice_settings"
    }
}

/// Legacy alias.
public typealias TTSRequest = TtsRequest

/// Parity alias matching Rust SDK naming.
public typealias TextToSpeechRequest = TtsRequest

/// Response from text-to-speech.
public struct TtsResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Audio file size.
    public var sizeBytes: Int64

    /// Model that generated the audio.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format, model
        case audioBase64 = "audio_base64"
        case sizeBytes = "size_bytes"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// Legacy alias.
public typealias TTSResponse = TtsResponse

/// Parity alias matching Rust SDK naming.
public typealias TextToSpeechResponse = TtsResponse

// MARK: - STT

/// Request body for speech-to-text.
public struct SttRequest: Codable, Sendable {
    /// STT model (e.g. "whisper-1", "scribe_v2").
    public var model: String

    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Original filename (helps with format detection).
    public var filename: String?

    /// BCP-47 language code hint (e.g. "en", "de").
    public var language: String?

    public init(model: String, audioBase64: String, filename: String? = nil, language: String? = nil) {
        self.model = model
        self.audioBase64 = audioBase64
        self.filename = filename
        self.language = language
    }

    enum CodingKeys: String, CodingKey {
        case model, filename, language
        case audioBase64 = "audio_base64"
    }
}

/// Legacy alias.
public typealias STTRequest = SttRequest

/// Parity alias matching Rust SDK naming.
public typealias SpeechToTextRequest = SttRequest

/// Response from speech-to-text.
public struct SttResponse: Codable, Sendable {
    /// Transcribed text.
    public var text: String

    /// Model that performed transcription.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case text, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// Legacy alias.
public typealias STTResponse = SttResponse

/// Parity alias matching Rust SDK naming.
public typealias SpeechToTextResponse = SttResponse

/// Response from `POST /qai/v1/audio/stt/realtime-token`.
///
/// The client connects straight to `wsEndpoint` with `?token=<token>`; the
/// gateway brokers only the credential, there is no proxy hop. The gateway
/// bills a flat per-session estimate when the token is minted and reports a
/// 15-minute TTL; ElevenLabs treats the token as single-use, which the
/// gateway neither enforces nor observes.
public struct RealtimeSttTokenResponse: Codable, Sendable {
    /// Realtime credential. Pass it as the `token` query parameter on the
    /// WebSocket connect.
    public var token: String

    /// Token lifetime in seconds (900).
    public var expiresIn: Int64

    /// WebSocket endpoint the token authenticates against.
    public var wsEndpoint: String

    /// Ticks charged for the session estimate.
    public var costTicks: Int64

    /// Gateway request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case token
        case expiresIn = "expires_in"
        case wsEndpoint = "ws_endpoint"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decodeIfPresent(String.self, forKey: .token) ?? ""
        expiresIn = try c.decodeIfPresent(Int64.self, forKey: .expiresIn) ?? 0
        wsEndpoint = try c.decodeIfPresent(String.self, forKey: .wsEndpoint) ?? ""
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

/// The token is a credential, so descriptions mask it.
extension RealtimeSttTokenResponse: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "RealtimeSttTokenResponse(token: \(token.isEmpty ? "" : "<redacted>"), expiresIn: \(expiresIn), wsEndpoint: \(wsEndpoint), costTicks: \(costTicks), requestId: \(requestId))"
    }

    public var debugDescription: String { description }
}

// MARK: - Music

/// Request body for the `/qai/v1/audio/music` endpoint.
public struct MusicRequest: Codable, Sendable {
    /// Music generation model (e.g. "lyria").
    public var model: String

    /// Describes the music to generate.
    public var prompt: String

    /// Target duration in seconds (default 30).
    public var durationSeconds: Int?

    public init(model: String, prompt: String, durationSeconds: Int? = nil) {
        self.model = model
        self.prompt = prompt
        self.durationSeconds = durationSeconds
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt
        case durationSeconds = "duration_seconds"
    }
}

/// A single generated music clip.
public struct MusicClip: Codable, Sendable {
    /// Base64-encoded audio data.
    public var base64: String?

    /// Audio format (e.g. "mp3", "wav").
    public var format: String?

    /// Audio file size.
    public var sizeBytes: Int64?

    /// Clip index within the batch.
    public var index: Int?

    enum CodingKeys: String, CodingKey {
        case base64, format, index
        case sizeBytes = "size_bytes"
    }
}

/// Response from the `/qai/v1/audio/music` endpoint.
public struct MusicResponse: Codable, Sendable {
    /// Generated music clips (empty when the gateway sends `null`).
    @NullToEmpty public var audioClips: [MusicClip]

    /// Model that generated the music.
    public var model: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case model
        case audioClips = "audio_clips"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Sound Effects

/// Request body for sound effects generation.
public struct SoundEffectRequest: Codable, Sendable {
    /// Text prompt describing the sound effect.
    public var prompt: String

    /// Optional duration in seconds.
    public var durationSeconds: Double?

    public init(prompt: String, durationSeconds: Double? = nil) {
        self.prompt = prompt
        self.durationSeconds = durationSeconds
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case durationSeconds = "duration_seconds"
    }
}

/// Response from sound effects generation.
public struct SoundEffectResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String?

    /// Audio format (e.g. "mp3").
    public var format: String?

    /// File size in bytes.
    public var sizeBytes: Int64?

    /// Model used.
    public var model: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format, model
        case audioBase64 = "audio_base64"
        case sizeBytes = "size_bytes"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Dialogue

/// A single dialogue turn, used to build a ``DialogueRequest`` with
/// ``DialogueRequest/init(turns:model:)``.
public struct DialogueTurn: Codable, Sendable {
    /// Speaker name or identifier.
    public var speaker: String

    /// Text for this speaker to say.
    public var text: String

    /// Voice ID for this speaker. A speaker needs a voice on at least one
    /// of its turns; every turn of the same speaker must agree.
    public var voice: String?

    public init(speaker: String, text: String, voice: String? = nil) {
        self.speaker = speaker
        self.text = text
        self.voice = voice
    }
}

/// Voice mapping for ElevenLabs dialogue.
public struct DialogueVoice: Codable, Sendable {
    public var voiceId: String
    public var name: String

    public init(voiceId: String, name: String) {
        self.voiceId = voiceId
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case name
        case voiceId = "voice_id"
    }
}

/// Request body for dialogue generation: `text` (the full script) plus
/// `voices` (speaker-to-voice mapping). Billed per character of `text`.
public struct DialogueRequest: Codable, Sendable {
    /// Full dialogue script (e.g. "Speaker1: Hello!\nSpeaker2: Hi there!").
    public var text: String

    /// Voice mappings -- each speaker name mapped to a voice_id (at least one).
    public var voices: [DialogueVoice]

    /// Dialogue model (default "eleven_v3").
    public var model: String?

    /// Output audio format.
    public var outputFormat: String?

    /// Seed for reproducible generation.
    public var seed: Int?

    public init(text: String, voices: [DialogueVoice], model: String? = nil, outputFormat: String? = nil, seed: Int? = nil) {
        self.text = text
        self.voices = voices
        self.model = model
        self.outputFormat = outputFormat
        self.seed = seed
    }

    /// Builds a request from individual turns: the script becomes
    /// "Speaker: text" lines and `voices` gets one entry per speaker, in
    /// order of first appearance.
    ///
    /// Every speaker must carry a voice on at least one turn, and all of a
    /// speaker's turns must name the same voice; otherwise this throws
    /// ``QuantumError/invalidArgument(_:)`` rather than sending a script the
    /// gateway would bill with an unmapped speaker.
    public init(turns: [DialogueTurn], model: String? = nil) throws {
        var voices: [DialogueVoice] = []
        for turn in turns {
            guard let voiceId = turn.voice else { continue }
            if let existing = voices.first(where: { $0.name == turn.speaker }) {
                if existing.voiceId != voiceId {
                    throw QuantumError.invalidArgument(
                        "speaker \"\(turn.speaker)\" maps to both voice \"\(existing.voiceId)\" and voice \"\(voiceId)\""
                    )
                }
            } else {
                voices.append(DialogueVoice(voiceId: voiceId, name: turn.speaker))
            }
        }
        if let unmapped = turns.first(where: { turn in !voices.contains { $0.name == turn.speaker } }) {
            throw QuantumError.invalidArgument("speaker \"\(unmapped.speaker)\" has no voice on any turn")
        }
        self.init(
            text: turns.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n"),
            voices: voices,
            model: model
        )
    }

    enum CodingKeys: String, CodingKey {
        case text, voices, model, seed
        case outputFormat = "output_format"
    }
}

/// Response from dialogue generation.
public struct DialogueResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Audio file size.
    public var sizeBytes: Int64

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format, model
        case audioBase64 = "audio_base64"
        case sizeBytes = "size_bytes"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Speech to Speech

/// Request body for speech-to-speech conversion (ElevenLabs).
///
/// The gateway fixes the model to `eleven_multilingual_v2` and the provider
/// default output format; neither can be chosen per request.
public struct SpeechToSpeechRequest: Codable, Sendable {
    /// Target voice identifier (required).
    public var voiceId: String

    /// Base64-encoded source audio (required).
    public var audioBase64: String

    public init(voiceId: String, audioBase64: String) {
        self.voiceId = voiceId
        self.audioBase64 = audioBase64
    }

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case audioBase64 = "audio_base64"
    }
}

/// Response from speech-to-speech conversion.
public struct SpeechToSpeechResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Audio file size.
    public var sizeBytes: Int64

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format, model
        case audioBase64 = "audio_base64"
        case sizeBytes = "size_bytes"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Voice Isolation

/// Request body for voice isolation. The output format is the provider
/// default and cannot be chosen.
public struct IsolateVoiceRequest: Codable, Sendable {
    /// Base64-encoded audio to isolate voice from.
    public var audioBase64: String

    /// Original filename (helps detect the container format).
    public var filename: String?

    public init(audioBase64: String, filename: String? = nil) {
        self.audioBase64 = audioBase64
        self.filename = filename
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case audioBase64 = "audio_base64"
    }
}

/// Backwards-compatible alias.
public typealias IsolateRequest = IsolateVoiceRequest

/// Response from voice isolation.
public struct IsolateVoiceResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Audio file size.
    public var sizeBytes: Int64

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format
        case audioBase64 = "audio_base64"
        case sizeBytes = "size_bytes"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Voice Remix

/// Request body for voice remixing (ElevenLabs voice remix). Only
/// `audioBase64` is required; the remaining knobs steer the remix and are
/// forwarded as-is. Billed flat per request, whether or not any knob is set.
public struct RemixVoiceRequest: Codable, Sendable {
    /// Base64-encoded source audio (required).
    public var audioBase64: String

    /// Original filename (helps detect the container format).
    public var filename: String?

    /// Target gender for the remixed voice.
    public var gender: String?

    /// Target accent.
    public var accent: String?

    /// Target speaking style.
    public var style: String?

    /// Target pacing.
    public var pacing: String?

    /// Audio quality setting.
    public var audioQuality: String?

    /// How strongly the attributes steer the remix.
    public var promptStrength: String?

    /// Script to speak in the remixed voice.
    public var script: String?

    public init(
        audioBase64: String,
        filename: String? = nil,
        gender: String? = nil,
        accent: String? = nil,
        style: String? = nil,
        pacing: String? = nil,
        audioQuality: String? = nil,
        promptStrength: String? = nil,
        script: String? = nil
    ) {
        self.audioBase64 = audioBase64
        self.filename = filename
        self.gender = gender
        self.accent = accent
        self.style = style
        self.pacing = pacing
        self.audioQuality = audioQuality
        self.promptStrength = promptStrength
        self.script = script
    }

    enum CodingKeys: String, CodingKey {
        case filename, gender, accent, style, pacing, script
        case audioBase64 = "audio_base64"
        case audioQuality = "audio_quality"
        case promptStrength = "prompt_strength"
    }
}

/// Backwards-compatible alias.
public typealias RemixRequest = RemixVoiceRequest

/// Response from voice remixing.
public struct RemixVoiceResponse: Codable, Sendable {
    /// Base64-encoded audio data (absent when the provider returned none).
    public var audioBase64: String?

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Audio file size.
    public var sizeBytes: Int64

    /// Identifier of the remixed voice, when the provider created one.
    public var voiceId: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format
        case audioBase64 = "audio_base64"
        case sizeBytes = "size_bytes"
        case voiceId = "voice_id"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Dubbing

/// Request body for audio dubbing. One of `audioBase64` or `sourceUrl` is
/// required.
public struct DubRequest: Codable, Sendable {
    /// Base64-encoded source audio or video.
    public var audioBase64: String?

    /// Original filename (helps detect format).
    public var filename: String?

    /// URL to source media (alternative to `audioBase64`).
    public var sourceUrl: String?

    /// Target language (BCP-47 code, e.g. "es", "de"). Wire field `target_lang`.
    public var targetLang: String

    /// Source language (auto-detected if omitted). Wire field `source_lang`.
    public var sourceLang: String?

    /// Number of speakers.
    public var numSpeakers: Int?

    /// Enable highest quality processing.
    public var highestResolution: Bool?

    public init(
        targetLang: String,
        audioBase64: String? = nil,
        filename: String? = nil,
        sourceUrl: String? = nil,
        sourceLang: String? = nil,
        numSpeakers: Int? = nil,
        highestResolution: Bool? = nil
    ) {
        self.targetLang = targetLang
        self.audioBase64 = audioBase64
        self.filename = filename
        self.sourceUrl = sourceUrl
        self.sourceLang = sourceLang
        self.numSpeakers = numSpeakers
        self.highestResolution = highestResolution
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case audioBase64 = "audio_base64"
        case sourceUrl = "source_url"
        case targetLang = "target_lang"
        case sourceLang = "source_lang"
        case numSpeakers = "num_speakers"
        case highestResolution = "highest_resolution"
    }
}

/// Response from dubbing.
public struct DubResponse: Codable, Sendable {
    /// Dubbing job ID.
    public var dubbingId: String

    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Target language used.
    public var targetLang: String

    /// Job status.
    public var status: String

    /// Processing time in seconds.
    public var processingTimeSeconds: Double

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format, status
        case dubbingId = "dubbing_id"
        case audioBase64 = "audio_base64"
        case targetLang = "target_lang"
        case processingTimeSeconds = "processing_time_seconds"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Alignment

/// Request body for audio alignment / forced alignment.
public struct AlignRequest: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Original filename (helps detect the container format).
    public var filename: String?

    /// Transcript text to align against the audio.
    public var text: String

    /// Language code.
    public var language: String?

    public init(audioBase64: String, text: String, filename: String? = nil, language: String? = nil) {
        self.audioBase64 = audioBase64
        self.text = text
        self.filename = filename
        self.language = language
    }

    enum CodingKeys: String, CodingKey {
        case text, language, filename
        case audioBase64 = "audio_base64"
    }
}

/// A single word with timing information from forced alignment.
public struct AlignedWord: Codable, Sendable {
    /// Word text.
    public var text: String

    /// Start time in seconds.
    public var startTime: Double

    /// End time in seconds.
    public var endTime: Double

    /// Alignment confidence score.
    public var confidence: Double

    enum CodingKeys: String, CodingKey {
        case text, confidence
        case startTime = "start_time"
        case endTime = "end_time"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        startTime = try c.decode(Double.self, forKey: .startTime)
        endTime = try c.decode(Double.self, forKey: .endTime)
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
    }
}

/// Response from audio alignment. Only word-level timings exist on the
/// wire; there is no segment level.
public struct AlignResponse: Codable, Sendable {
    /// Word-level alignment.
    @NullToEmpty public var alignment: [AlignedWord]

    /// Model used.
    public var model: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case alignment, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Voice Design

/// Request body for voice design (generating a voice from a description).
/// The preview format is the provider default and cannot be chosen.
public struct VoiceDesignRequest: Codable, Sendable {
    /// Text description of the desired voice. Wire field `voice_description`.
    public var description: String

    /// Sample text the previews speak (required). Wire field `sample_text`.
    public var text: String

    public init(description: String, text: String) {
        self.description = description
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case description = "voice_description"
        case text = "sample_text"
    }
}

/// A single voice preview from voice design.
public struct VoicePreview: Codable, Sendable {
    /// Generated voice identifier.
    public var generatedVoiceId: String

    /// Base64-encoded audio data.
    public var audioBase64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    enum CodingKeys: String, CodingKey {
        case format
        case generatedVoiceId = "generated_voice_id"
        case audioBase64 = "audio_base64"
    }
}

/// Response from voice design: several candidate voices, each with a
/// preview clip. Save the chosen `generatedVoiceId` with
/// `saveDesignedVoice` to keep it.
public struct VoiceDesignResponse: Codable, Sendable {
    /// Candidate voices.
    @NullToEmpty public var previews: [VoicePreview]

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case previews
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// A designed voice persisted to the account.
public struct SavedDesignedVoice: Codable, Sendable {
    public var voiceId: String
    public var name: String

    enum CodingKeys: String, CodingKey {
        case name
        case voiceId = "voice_id"
    }
}

// MARK: - Starfish TTS

/// Request body for Starfish TTS (HeyGen). The output format is the provider
/// default and cannot be chosen.
public struct StarfishTTSRequest: Codable, Sendable {
    /// Text to synthesise (required).
    public var text: String

    /// HeyGen voice identifier (required).
    public var voiceId: String

    /// Input type (e.g. "text", "ssml").
    public var inputType: String?

    /// Speech speed multiplier.
    public var speed: Double?

    /// BCP-47 language code.
    public var language: String?

    /// Locale code.
    public var locale: String?

    public init(text: String, voiceId: String, inputType: String? = nil, speed: Double? = nil, language: String? = nil, locale: String? = nil) {
        self.text = text
        self.voiceId = voiceId
        self.inputType = inputType
        self.speed = speed
        self.language = language
        self.locale = locale
    }

    enum CodingKeys: String, CodingKey {
        case text, speed, language, locale
        case voiceId = "voice_id"
        case inputType = "input_type"
    }
}

/// Response from Starfish TTS. The audio arrives as `audioBase64` or as a
/// `url`, whichever the provider returned.
public struct StarfishTTSResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String?

    /// URL of the generated audio.
    public var url: String?

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Audio file size.
    public var sizeBytes: Int64

    /// Audio duration in seconds.
    public var duration: Double

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case url, format, duration, model
        case audioBase64 = "audio_base64"
        case sizeBytes = "size_bytes"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Eleven Music

/// A section within an Eleven Music generation request.
public struct MusicSection: Codable, Sendable {
    public var sectionType: String
    public var lyrics: String?
    public var style: String?
    public var styleExclude: String?

    public init(sectionType: String, lyrics: String? = nil, style: String? = nil, styleExclude: String? = nil) {
        self.sectionType = sectionType
        self.lyrics = lyrics
        self.style = style
        self.styleExclude = styleExclude
    }

    enum CodingKeys: String, CodingKey {
        case lyrics, style
        case sectionType = "section_type"
        case styleExclude = "style_exclude"
    }
}

/// Request body for advanced music generation (ElevenLabs Eleven Music).
/// Either `prompt` or `sections` is required. Editing an earlier generation
/// is not supported on this route.
public struct ElevenMusicRequest: Codable, Sendable {
    /// Describes the music to generate.
    public var prompt: String

    /// Music model (gateway default "music_v1").
    public var model: String?

    /// Structured sections (verse, chorus, …) with lyrics and style.
    public var sections: [MusicSection]?

    /// Target duration in seconds (default 30). Cost scales with duration.
    public var durationSeconds: Int?

    /// Accepted by the gateway but not forwarded to the provider yet; steer
    /// language through the prompt or lyrics instead.
    public var language: String?

    /// Include vocals.
    public var vocals: Bool?

    /// Global style.
    public var style: String?

    /// Styles to avoid.
    public var styleExclude: String?

    /// Finetune to generate with (see `listFinetunes`).
    public var finetuneId: String?

    public init(
        prompt: String,
        model: String? = nil,
        sections: [MusicSection]? = nil,
        durationSeconds: Int? = nil,
        language: String? = nil,
        vocals: Bool? = nil,
        style: String? = nil,
        styleExclude: String? = nil,
        finetuneId: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.sections = sections
        self.durationSeconds = durationSeconds
        self.language = language
        self.vocals = vocals
        self.style = style
        self.styleExclude = styleExclude
        self.finetuneId = finetuneId
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, sections, language, vocals, style
        case durationSeconds = "duration_seconds"
        case styleExclude = "style_exclude"
        case finetuneId = "finetune_id"
    }
}

/// Backwards-compatible alias: the advanced-music route has one request shape.
public typealias MusicAdvancedRequest = ElevenMusicRequest

/// A single music clip from advanced generation.
public struct ElevenMusicClip: Codable, Sendable {
    /// Base64-encoded audio data.
    public var base64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    /// File size in bytes.
    public var size: Int64

    enum CodingKeys: String, CodingKey {
        case base64, format, size
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base64 = try c.decodeIfPresent(String.self, forKey: .base64) ?? ""
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        size = try c.decodeIfPresent(Int64.self, forKey: .size) ?? 0
    }
}

/// Backwards-compatible alias.
public typealias MusicAdvancedClip = ElevenMusicClip

/// Response from advanced music generation.
public struct ElevenMusicResponse: Codable, Sendable {
    /// Generated music clips.
    @NullToEmpty public var clips: [ElevenMusicClip]

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case clips, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _clips = try c.decode(NullToEmpty<ElevenMusicClip>.self, forKey: .clips)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

/// Backwards-compatible alias.
public typealias MusicAdvancedResponse = ElevenMusicResponse

// MARK: - Music Finetunes

/// A music finetune as the gateway reports it. Creation returns `id` and
/// `status` only; `modelId` appears once training has produced a model.
public struct FinetuneInfo: Codable, Sendable {
    /// Finetune identifier.
    public var id: String

    /// Training status.
    public var status: String

    /// Model id to pass as `finetuneId`, once available.
    public var modelId: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case modelId = "model_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        modelId = try c.decodeIfPresent(String.self, forKey: .modelId)
    }
}

/// Backwards-compatible alias: the single-finetune read and the list items
/// share one wire shape.
public typealias MusicFinetuneStatus = FinetuneInfo

/// Response from listing music finetunes.
public struct ListFinetunesResponse: Codable, Sendable {
    /// Finetunes on the account.
    @NullToEmpty public var finetunes: [FinetuneInfo]
}

/// Backwards-compatible alias.
public typealias MusicFinetuneListResponse = ListFinetunesResponse

/// Request to create a music finetune.
public struct MusicFinetuneCreateRequest: Codable, Sendable {
    /// Name for the finetune.
    public var name: String

    /// Optional description.
    public var description: String?

    /// Base64-encoded audio samples (at least one).
    public var samples: [String]

    public init(name: String, description: String? = nil, samples: [String]) {
        self.name = name
        self.description = description
        self.samples = samples
    }
}

// MARK: - HeyGen Sounds Search (background music + sound effects)

/// Query parameters for searching the sounds catalog.
public struct AudioSoundsQuery: Sendable {
    /// Natural-language description of the sound wanted (required).
    public var query: String

    /// Catalog to search: "music" | "sound_effects" (API default: "music").
    /// Wire param: `type`.
    public var soundType: String?

    /// Max results, 1–50 (API default 10).
    public var limit: Int?

    /// Minimum similarity score, 0–1 (API default 0.7).
    public var minScore: Double?

    /// Opaque cursor from a previous response's `nextToken`.
    public var token: String?

    public init(
        query: String,
        soundType: String? = nil,
        limit: Int? = nil,
        minScore: Double? = nil,
        token: String? = nil
    ) {
        self.query = query
        self.soundType = soundType
        self.limit = limit
        self.minScore = minScore
        self.token = token
    }
}

/// A track from the sounds catalog.
public struct AudioSound: Codable, Sendable {
    /// Track identifier.
    public var id: String

    /// Track name.
    public var name: String

    /// Track description.
    public var description: String

    /// Pre-signed WAV URL with a limited lifetime — download promptly,
    /// do not cache.
    public var audioUrl: String

    /// Duration in seconds.
    public var duration: Double

    /// Similarity score 0–1 (best first).
    public var score: Double

    /// "music" | "sound_effects". Wire field: `type`.
    public var soundType: String

    enum CodingKeys: String, CodingKey {
        case id, name, description, duration, score
        case audioUrl = "audio_url"
        case soundType = "type"
    }
}

/// Response from searching the sounds catalog (unbilled).
public struct AudioSoundsResponse: Codable, Sendable {
    /// Matching tracks, best score first (empty page → `[]`).
    @NullToEmpty public var sounds: [AudioSound]

    /// More pages exist.
    public var hasMore: Bool

    /// Pass as `token` for the next page (may be empty).
    public var nextToken: String

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case sounds
        case hasMore = "has_more"
        case nextToken = "next_token"
        case requestId = "request_id"
    }
}
