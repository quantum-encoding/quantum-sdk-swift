import Foundation

// MARK: - TTS

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

    public init(model: String, text: String, voice: String? = nil, outputFormat: String? = nil, speed: Double? = nil) {
        self.model = model
        self.text = text
        self.voice = voice
        self.outputFormat = outputFormat
        self.speed = speed
    }

    enum CodingKeys: String, CodingKey {
        case model, text, voice, speed
        case outputFormat = "format"
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
    /// Generated music clips.
    public var audioClips: [MusicClip]?

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

// MARK: - Audio Response (generic)

/// Generic audio response used by multiple advanced audio endpoints.
public struct AudioResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String?

    /// Audio format (e.g. "mp3", "wav").
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

/// A single dialogue turn.
public struct DialogueTurn: Codable, Sendable {
    /// Speaker name or identifier.
    public var speaker: String

    /// Text for this speaker to say.
    public var text: String

    /// Voice ID to use for this speaker.
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

/// Request body for dialogue generation.
public struct DialogueRequest: Codable, Sendable {
    /// Full dialogue script.
    public var text: String

    /// Voice mappings -- each speaker name mapped to a voice_id.
    public var voices: [DialogueVoice]

    /// Dialogue model.
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

/// Request body for speech-to-speech conversion.
public struct SpeechToSpeechRequest: Codable, Sendable {
    /// Model for conversion.
    public var model: String?

    /// Base64-encoded source audio.
    public var audioBase64: String

    /// Target voice.
    public var voice: String?

    /// Output audio format.
    public var outputFormat: String?

    public init(audioBase64: String, model: String? = nil, voice: String? = nil, outputFormat: String? = nil) {
        self.audioBase64 = audioBase64
        self.model = model
        self.voice = voice
        self.outputFormat = outputFormat
    }

    enum CodingKeys: String, CodingKey {
        case model, voice
        case audioBase64 = "audio_base64"
        case outputFormat = "format"
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

/// Request body for voice isolation.
public struct IsolateRequest: Codable, Sendable {
    /// Base64-encoded audio to isolate voice from.
    public var audioBase64: String

    /// Output audio format.
    public var outputFormat: String?

    public init(audioBase64: String, outputFormat: String? = nil) {
        self.audioBase64 = audioBase64
        self.outputFormat = outputFormat
    }

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
        case outputFormat = "format"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias IsolateVoiceRequest = IsolateRequest

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

/// Request body for voice remixing.
public struct RemixRequest: Codable, Sendable {
    /// Base64-encoded source audio.
    public var audioBase64: String

    /// Target voice for the remix.
    public var voice: String?

    /// Model for remixing.
    public var model: String?

    /// Output audio format.
    public var outputFormat: String?

    public init(audioBase64: String, voice: String? = nil, model: String? = nil, outputFormat: String? = nil) {
        self.audioBase64 = audioBase64
        self.voice = voice
        self.model = model
        self.outputFormat = outputFormat
    }

    enum CodingKeys: String, CodingKey {
        case voice, model
        case audioBase64 = "audio_base64"
        case outputFormat = "format"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias RemixVoiceRequest = RemixRequest

/// Response from voice remixing.
public struct RemixVoiceResponse: Codable, Sendable {
    /// Base64-encoded audio data.
    public var audioBase64: String?

    /// Audio format (e.g. "mp3").
    public var format: String

    /// Audio file size.
    public var sizeBytes: Int64

    /// Voice ID used for remix.
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

/// Request body for audio dubbing.
public struct DubRequest: Codable, Sendable {
    /// Base64-encoded source audio or video.
    public var audioBase64: String

    /// Original filename (helps detect format).
    public var filename: String?

    /// Target language (BCP-47 code, e.g. "es", "de").
    public var targetLanguage: String

    /// Source language (auto-detected if omitted).
    public var sourceLanguage: String?

    public init(audioBase64: String, targetLanguage: String, filename: String? = nil, sourceLanguage: String? = nil) {
        self.audioBase64 = audioBase64
        self.targetLanguage = targetLanguage
        self.filename = filename
        self.sourceLanguage = sourceLanguage
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case audioBase64 = "audio_base64"
        case targetLanguage = "target_language"
        case sourceLanguage = "source_language"
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

    /// Transcript text to align against the audio.
    public var text: String

    /// Language code.
    public var language: String?

    public init(audioBase64: String, text: String, language: String? = nil) {
        self.audioBase64 = audioBase64
        self.text = text
        self.language = language
    }

    enum CodingKeys: String, CodingKey {
        case text, language
        case audioBase64 = "audio_base64"
    }
}

/// A single alignment segment.
public struct AlignmentSegment: Codable, Sendable {
    /// Aligned text.
    public var text: String

    /// Start time in seconds.
    public var start: Double

    /// End time in seconds.
    public var end: Double
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
}

/// Response from audio alignment.
public struct AlignResponse: Codable, Sendable {
    /// Aligned segments.
    public var segments: [AlignmentSegment]?

    /// Word-level alignment.
    public var alignment: [AlignedWord]?

    /// Model used.
    public var model: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case segments, alignment, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Voice Design

/// Request body for voice design (generating a voice from a description).
public struct VoiceDesignRequest: Codable, Sendable {
    /// Text description of the desired voice.
    public var description: String

    /// Sample text to speak with the designed voice.
    public var text: String?

    /// Output audio format.
    public var outputFormat: String?

    public init(description: String, text: String? = nil, outputFormat: String? = nil) {
        self.description = description
        self.text = text
        self.outputFormat = outputFormat
    }

    enum CodingKeys: String, CodingKey {
        case description
        case text = "sample_text"
        case outputFormat = "format"
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

/// Response from voice design.
public struct VoiceDesignResponse: Codable, Sendable {
    /// Voice previews.
    public var previews: [VoicePreview]

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

// MARK: - Starfish TTS

/// Request body for Starfish TTS.
public struct StarfishTTSRequest: Codable, Sendable {
    /// Text to synthesise.
    public var text: String

    /// Voice identifier.
    public var voice: String?

    /// Output audio format.
    public var outputFormat: String?

    /// Speech speed multiplier.
    public var speed: Double?

    public init(text: String, voice: String? = nil, outputFormat: String? = nil, speed: Double? = nil) {
        self.text = text
        self.voice = voice
        self.outputFormat = outputFormat
        self.speed = speed
    }

    enum CodingKeys: String, CodingKey {
        case text, voice, speed
        case outputFormat = "format"
    }
}

/// Response from Starfish TTS.
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

// MARK: - Advanced Music

/// Advanced music generation request.
public struct MusicAdvancedRequest: Codable, Sendable {
    /// Text prompt describing the music.
    public var prompt: String

    /// Target duration in seconds.
    public var durationSeconds: Int?

    /// Model to use.
    public var model: String?

    /// Finetune ID to apply.
    public var finetuneId: String?

    public init(prompt: String, durationSeconds: Int? = nil, model: String? = nil, finetuneId: String? = nil) {
        self.prompt = prompt
        self.durationSeconds = durationSeconds
        self.model = model
        self.finetuneId = finetuneId
    }

    enum CodingKeys: String, CodingKey {
        case prompt, model
        case durationSeconds = "duration_seconds"
        case finetuneId = "finetune_id"
    }
}

/// A single clip from advanced music generation.
public struct MusicAdvancedClip: Codable, Sendable {
    /// Base64-encoded audio data.
    public var base64: String

    /// Audio format (e.g. "mp3").
    public var format: String

    /// File size in bytes.
    public var size: Int64
}

/// Response from advanced music generation.
public struct MusicAdvancedResponse: Codable, Sendable {
    /// Generated music clips.
    public var clips: [MusicAdvancedClip]

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
}

// MARK: - Music Finetune

/// Music finetune info.
public struct MusicFinetuneInfo: Codable, Sendable {
    /// Finetune identifier.
    public var finetuneId: String

    /// Finetune name.
    public var name: String

    /// Description.
    public var description: String?

    /// Current status.
    public var status: String

    /// Model ID.
    public var modelId: String?

    /// ISO timestamp.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case name, description, status
        case finetuneId = "finetune_id"
        case modelId = "model_id"
        case createdAt = "created_at"
    }
}

/// Response from listing music finetunes.
public struct MusicFinetuneListResponse: Codable, Sendable {
    /// Available finetunes.
    public var finetunes: [MusicFinetuneInfo]
}

/// Request to create a music finetune.
public struct MusicFinetuneCreateRequest: Codable, Sendable {
    /// Name for the finetune.
    public var name: String

    /// Optional description.
    public var description: String?

    /// Base64-encoded audio samples.
    public var samples: [String]

    public init(name: String, description: String? = nil, samples: [String]) {
        self.name = name
        self.description = description
        self.samples = samples
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
public struct ElevenMusicRequest: Codable, Sendable {
    public var model: String
    public var prompt: String
    public var sections: [MusicSection]?
    public var durationSeconds: Int?
    public var language: String?
    public var vocals: Bool?
    public var style: String?
    public var styleExclude: String?
    public var finetuneId: String?
    public var editReferenceId: String?
    public var editInstruction: String?

    public init(
        model: String,
        prompt: String,
        sections: [MusicSection]? = nil,
        durationSeconds: Int? = nil,
        language: String? = nil,
        vocals: Bool? = nil,
        style: String? = nil,
        styleExclude: String? = nil,
        finetuneId: String? = nil,
        editReferenceId: String? = nil,
        editInstruction: String? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.sections = sections
        self.durationSeconds = durationSeconds
        self.language = language
        self.vocals = vocals
        self.style = style
        self.styleExclude = styleExclude
        self.finetuneId = finetuneId
        self.editReferenceId = editReferenceId
        self.editInstruction = editInstruction
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, sections, language, vocals, style
        case durationSeconds = "duration_seconds"
        case styleExclude = "style_exclude"
        case finetuneId = "finetune_id"
        case editReferenceId = "edit_reference_id"
        case editInstruction = "edit_instruction"
    }
}

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
}

/// Response from advanced music generation.
public struct ElevenMusicResponse: Codable, Sendable {
    /// Generated music clips.
    public var clips: [ElevenMusicClip]

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
}

/// Info about a music finetune.
public struct FinetuneInfo: Codable, Sendable {
    public var finetuneId: String
    public var name: String
    public var status: String
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case name, status
        case finetuneId = "finetune_id"
        case createdAt = "created_at"
    }
}

/// Response from listing finetunes.
public struct ListFinetunesResponse: Codable, Sendable {
    public var finetunes: [FinetuneInfo]
}
