import Foundation

// MARK: - TTS

/// Request body for the `/qai/v1/audio/tts` endpoint.
public struct TTSRequest: Codable, Sendable {
    /// Model for text-to-speech.
    public var model: String?

    /// Text to speak.
    public var text: String

    /// Voice ID.
    public var voice: String?

    /// Output format (e.g. "mp3", "wav").
    public var format: String?

    /// Speaking speed.
    public var speed: Double?

    public init(text: String, model: String? = nil, voice: String? = nil, format: String? = nil, speed: Double? = nil) {
        self.text = text
        self.model = model
        self.voice = voice
        self.format = format
        self.speed = speed
    }
}

/// Response from the `/qai/v1/audio/tts` endpoint.
public struct TTSResponse: Codable, Sendable {
    /// URL of the generated audio.
    public var audioUrl: String

    /// Audio format.
    public var format: String

    /// Duration in seconds.
    public var durationSeconds: Double

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case format
        case audioUrl = "audio_url"
        case durationSeconds = "duration_seconds"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - STT

/// Request body for the `/qai/v1/audio/stt` endpoint.
public struct STTRequest: Codable, Sendable {
    /// Model for speech-to-text.
    public var model: String?

    /// Base64-encoded audio data.
    public var audio: String

    /// Audio format (e.g. "wav", "mp3").
    public var format: String?

    /// BCP-47 language code.
    public var language: String?

    public init(audio: String, model: String? = nil, format: String? = nil, language: String? = nil) {
        self.audio = audio
        self.model = model
        self.format = format
        self.language = language
    }
}

/// Response from the `/qai/v1/audio/stt` endpoint.
public struct STTResponse: Codable, Sendable {
    /// Transcribed text.
    public var text: String

    /// Detected language.
    public var language: String

    /// Duration in seconds.
    public var durationSeconds: Double

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case text, language
        case durationSeconds = "duration_seconds"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Music

/// Request body for the `/qai/v1/audio/music` endpoint.
public struct MusicRequest: Codable, Sendable {
    /// Text prompt describing the music.
    public var prompt: String

    /// Duration in seconds.
    public var duration: Int?

    /// Model to use for music generation.
    public var model: String?

    public init(prompt: String, duration: Int? = nil, model: String? = nil) {
        self.prompt = prompt
        self.duration = duration
        self.model = model
    }
}

/// A single generated music clip.
public struct MusicClip: Codable, Sendable {
    /// URL of the generated audio.
    public var audioUrl: String

    /// Title of the clip.
    public var title: String?

    /// Tags describing the clip.
    public var tags: String?

    /// Duration in seconds.
    public var durationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case title, tags
        case audioUrl = "audio_url"
        case durationSeconds = "duration_seconds"
    }
}

/// Response from the `/qai/v1/audio/music` endpoint.
public struct MusicResponse: Codable, Sendable {
    /// Generated music clips.
    public var clips: [MusicClip]

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case clips
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Sound Effects

/// Request body for the `/qai/v1/audio/sound-effects` endpoint.
public struct SoundEffectRequest: Codable, Sendable {
    /// Text prompt describing the sound effect.
    public var text: String

    /// Duration in seconds.
    public var durationSeconds: Double?

    /// Prompt influence factor.
    public var promptInfluence: Double?

    public init(text: String, durationSeconds: Double? = nil, promptInfluence: Double? = nil) {
        self.text = text
        self.durationSeconds = durationSeconds
        self.promptInfluence = promptInfluence
    }

    enum CodingKeys: String, CodingKey {
        case text
        case durationSeconds = "duration_seconds"
        case promptInfluence = "prompt_influence"
    }
}

/// Response from the `/qai/v1/audio/sound-effects` endpoint.
public struct SoundEffectResponse: Codable, Sendable {
    /// URL of the generated audio.
    public var audioUrl: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Dialogue

/// Request body for the `/qai/v1/audio/dialogue` endpoint.
public struct DialogueRequest: Codable, Sendable {
    /// Script with speaker names and lines.
    public var script: String

    /// Voice mapping (speaker name -> voice ID).
    public var voices: [String: String]

    /// Model for dialogue generation.
    public var model: String?

    public init(script: String, voices: [String: String], model: String? = nil) {
        self.script = script
        self.voices = voices
        self.model = model
    }
}

/// Response from the `/qai/v1/audio/dialogue` endpoint.
public struct DialogueResponse: Codable, Sendable {
    /// URL of the generated audio.
    public var audioUrl: String

    /// Duration in seconds.
    public var durationSeconds: Double

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case durationSeconds = "duration_seconds"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Speech to Speech

/// Request body for the `/qai/v1/audio/speech-to-speech` endpoint.
public struct SpeechToSpeechRequest: Codable, Sendable {
    /// Base64-encoded source audio.
    public var audio: String

    /// Target voice ID.
    public var voiceId: String

    /// Model for voice conversion.
    public var model: String?

    public init(audio: String, voiceId: String, model: String? = nil) {
        self.audio = audio
        self.voiceId = voiceId
        self.model = model
    }

    enum CodingKeys: String, CodingKey {
        case audio, model
        case voiceId = "voice_id"
    }
}

/// Response from the `/qai/v1/audio/speech-to-speech` endpoint.
public struct SpeechToSpeechResponse: Codable, Sendable {
    /// URL of the generated audio.
    public var audioUrl: String

    /// Duration in seconds.
    public var durationSeconds: Double

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case durationSeconds = "duration_seconds"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Voice Isolation

/// Request body for the `/qai/v1/audio/isolate` endpoint.
public struct IsolateVoiceRequest: Codable, Sendable {
    /// Base64-encoded audio.
    public var audio: String

    public init(audio: String) {
        self.audio = audio
    }
}

/// Response from the `/qai/v1/audio/isolate` endpoint.
public struct IsolateVoiceResponse: Codable, Sendable {
    /// URL of the isolated audio.
    public var audioUrl: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Voice Remix

/// Request body for the `/qai/v1/audio/remix` endpoint.
public struct RemixVoiceRequest: Codable, Sendable {
    /// Base64-encoded audio.
    public var audio: String

    /// Target voice ID.
    public var voiceId: String

    public init(audio: String, voiceId: String) {
        self.audio = audio
        self.voiceId = voiceId
    }

    enum CodingKeys: String, CodingKey {
        case audio
        case voiceId = "voice_id"
    }
}

/// Response from the `/qai/v1/audio/remix` endpoint.
public struct RemixVoiceResponse: Codable, Sendable {
    /// URL of the remixed audio.
    public var audioUrl: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Dubbing

/// Request body for the `/qai/v1/audio/dub` endpoint.
public struct DubRequest: Codable, Sendable {
    /// Base64-encoded audio/video to dub.
    public var audio: String

    /// Target language code.
    public var targetLang: String

    /// Source language code.
    public var sourceLang: String?

    public init(audio: String, targetLang: String, sourceLang: String? = nil) {
        self.audio = audio
        self.targetLang = targetLang
        self.sourceLang = sourceLang
    }

    enum CodingKeys: String, CodingKey {
        case audio
        case targetLang = "target_lang"
        case sourceLang = "source_lang"
    }
}

/// Response from the `/qai/v1/audio/dub` endpoint.
public struct DubResponse: Codable, Sendable {
    /// URL of the dubbed audio.
    public var audioUrl: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Alignment

/// Request body for the `/qai/v1/audio/align` endpoint.
public struct AlignRequest: Codable, Sendable {
    /// Base64-encoded audio.
    public var audio: String

    /// Text to align against the audio.
    public var text: String

    public init(audio: String, text: String) {
        self.audio = audio
        self.text = text
    }
}

/// A word with timestamp alignment.
public struct AlignedWord: Codable, Sendable {
    /// The word.
    public var word: String

    /// Start time in seconds.
    public var start: Double

    /// End time in seconds.
    public var end: Double
}

/// Response from the `/qai/v1/audio/align` endpoint.
public struct AlignResponse: Codable, Sendable {
    /// Aligned words with timestamps.
    public var words: [AlignedWord]

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case words
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Voice Design

/// Request body for the `/qai/v1/audio/voice-design` endpoint.
public struct VoiceDesignRequest: Codable, Sendable {
    /// Text description of the desired voice.
    public var description: String

    /// Text to preview the voice with.
    public var previewText: String?

    public init(description: String, previewText: String? = nil) {
        self.description = description
        self.previewText = previewText
    }

    enum CodingKeys: String, CodingKey {
        case description
        case previewText = "preview_text"
    }
}

/// A single voice preview.
public struct VoicePreview: Codable, Sendable {
    /// URL of the preview audio.
    public var audioUrl: String

    /// Voice ID.
    public var voiceId: String

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case voiceId = "voice_id"
    }
}

/// Response from the `/qai/v1/audio/voice-design` endpoint.
public struct VoiceDesignResponse: Codable, Sendable {
    /// Generated voice previews.
    public var previews: [VoicePreview]

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case previews
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Starfish TTS

/// Request body for the `/qai/v1/audio/starfish-tts` endpoint.
public struct StarfishTTSRequest: Codable, Sendable {
    /// Text to speak.
    public var text: String

    /// Base64-encoded reference audio for voice cloning.
    public var referenceAudio: String?

    public init(text: String, referenceAudio: String? = nil) {
        self.text = text
        self.referenceAudio = referenceAudio
    }

    enum CodingKeys: String, CodingKey {
        case text
        case referenceAudio = "reference_audio"
    }
}

/// Response from the `/qai/v1/audio/starfish-tts` endpoint.
public struct StarfishTTSResponse: Codable, Sendable {
    /// URL of the generated audio.
    public var audioUrl: String

    /// Duration in seconds.
    public var durationSeconds: Double

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
        case durationSeconds = "duration_seconds"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Advanced Music

/// Request body for the `/qai/v1/audio/music/advanced` endpoint.
public struct MusicAdvancedRequest: Codable, Sendable {
    /// Prompt describing the music to generate.
    public var prompt: String

    /// Target duration in seconds.
    public var durationSeconds: Int?

    /// Music generation model.
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

/// A single clip from advanced music generation (base64 encoded).
public struct MusicAdvancedClip: Codable, Sendable {
    /// Base64-encoded audio data.
    public var base64: String

    /// Audio format.
    public var format: String

    /// File size in bytes.
    public var size: Int
}

/// Response from the `/qai/v1/audio/music/advanced` endpoint.
public struct MusicAdvancedResponse: Codable, Sendable {
    /// Generated clips.
    public var clips: [MusicAdvancedClip]

    /// Model used.
    public var model: String

    /// Cost in ticks.
    public var costTicks: Int

    /// Unique request ID.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case clips, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Music Finetunes

/// Information about a music finetune.
public struct MusicFinetuneInfo: Codable, Sendable {
    /// Finetune ID.
    public var finetuneId: String

    /// Finetune name.
    public var name: String

    /// Finetune description.
    public var description: String?

    /// Current status.
    public var status: String

    /// Model ID.
    public var modelId: String?

    /// Creation timestamp.
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

/// Request body for creating a music finetune.
public struct MusicFinetuneCreateRequest: Codable, Sendable {
    /// Finetune name.
    public var name: String

    /// Description.
    public var description: String?

    /// Base64-encoded audio samples.
    public var samples: [String]

    public init(name: String, description: String? = nil, samples: [String]) {
        self.name = name
        self.description = description
        self.samples = samples
    }
}
