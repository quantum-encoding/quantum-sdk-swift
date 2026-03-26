import Foundation

// MARK: - Video Request

/// Request body for video generation.
public struct VideoRequest: Codable, Sendable {
    /// Video generation model (e.g. "heygen", "grok-imagine-video", "sora-2", "veo-2").
    public var model: String

    /// Describes the video to generate.
    public var prompt: String

    /// Target video duration in seconds (default 8).
    public var durationSeconds: Int?

    /// Video aspect ratio (e.g. "16:9", "9:16").
    public var aspectRatio: String?

    public init(model: String, prompt: String, durationSeconds: Int? = nil, aspectRatio: String? = nil) {
        self.model = model
        self.prompt = prompt
        self.durationSeconds = durationSeconds
        self.aspectRatio = aspectRatio
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt
        case durationSeconds = "duration_seconds"
        case aspectRatio = "aspect_ratio"
    }
}

// MARK: - Generated Video

/// A single generated video.
public struct GeneratedVideo: Codable, Sendable {
    /// Base64-encoded video data (or a URL).
    public var base64: String?

    /// Video format (e.g. "mp4").
    public var format: String?

    /// Video file size.
    public var sizeBytes: Int64?

    /// Video index within the batch.
    public var index: Int?

    /// URL of the generated video (legacy).
    public var url: String?

    enum CodingKeys: String, CodingKey {
        case base64, format, index, url
        case sizeBytes = "size_bytes"
    }
}

// MARK: - Video Response

/// Response from video generation.
public struct VideoResponse: Codable, Sendable {
    /// Generated videos.
    public var videos: [GeneratedVideo]

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case videos, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Job Response

/// Response from async video job submission.
public struct JobResponse: Codable, Sendable {
    /// Job identifier for polling status.
    public var jobId: String

    /// Current status.
    public var status: String

    /// Total cost in ticks (may be 0 until job completes).
    public var costTicks: Int64

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - HeyGen Studio

/// A clip in a studio video.
public struct StudioClip: Codable, Sendable {
    /// Avatar ID.
    public var avatarId: String?

    /// Voice ID.
    public var voiceId: String?

    /// Script text for this clip.
    public var script: String?

    /// Background settings.
    public var background: AnyCodable?

    public init(avatarId: String? = nil, voiceId: String? = nil, script: String? = nil, background: AnyCodable? = nil) {
        self.avatarId = avatarId
        self.voiceId = voiceId
        self.script = script
        self.background = background
    }

    enum CodingKeys: String, CodingKey {
        case script, background
        case avatarId = "avatar_id"
        case voiceId = "voice_id"
    }
}

/// Request body for HeyGen studio video creation.
public struct StudioVideoRequest: Codable, Sendable {
    /// Video title.
    public var title: String?

    /// Video clips.
    public var clips: [StudioClip]

    /// Video dimensions.
    public var dimension: String?

    /// Aspect ratio.
    public var aspectRatio: String?

    public init(clips: [StudioClip], title: String? = nil, dimension: String? = nil, aspectRatio: String? = nil) {
        self.clips = clips
        self.title = title
        self.dimension = dimension
        self.aspectRatio = aspectRatio
    }

    enum CodingKeys: String, CodingKey {
        case title, clips, dimension
        case aspectRatio = "aspect_ratio"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias VideoStudioRequest = StudioVideoRequest

// MARK: - HeyGen Translate

/// Request body for video translation.
public struct TranslateRequest: Codable, Sendable {
    /// URL of the video to translate.
    public var videoUrl: String?

    /// Base64-encoded video (alternative to URL).
    public var videoBase64: String?

    /// Target language code.
    public var targetLanguage: String

    /// Source language code (auto-detected if omitted).
    public var sourceLanguage: String?

    public init(targetLanguage: String, videoUrl: String? = nil, videoBase64: String? = nil, sourceLanguage: String? = nil) {
        self.targetLanguage = targetLanguage
        self.videoUrl = videoUrl
        self.videoBase64 = videoBase64
        self.sourceLanguage = sourceLanguage
    }

    enum CodingKeys: String, CodingKey {
        case videoUrl = "video_url"
        case videoBase64 = "video_base64"
        case targetLanguage = "target_language"
        case sourceLanguage = "source_language"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias VideoTranslateRequest = TranslateRequest

// MARK: - HeyGen Photo Avatar

/// Request body for creating a photo avatar video.
public struct PhotoAvatarRequest: Codable, Sendable {
    /// Base64-encoded photo.
    public var photoBase64: String

    /// Script text for the avatar to speak.
    public var script: String

    /// Voice ID.
    public var voiceId: String?

    /// Aspect ratio.
    public var aspectRatio: String?

    public init(photoBase64: String, script: String, voiceId: String? = nil, aspectRatio: String? = nil) {
        self.photoBase64 = photoBase64
        self.script = script
        self.voiceId = voiceId
        self.aspectRatio = aspectRatio
    }

    enum CodingKeys: String, CodingKey {
        case script
        case photoBase64 = "photo_base64"
        case voiceId = "voice_id"
        case aspectRatio = "aspect_ratio"
    }
}

// MARK: - HeyGen Digital Twin

/// Request body for digital twin video generation.
public struct DigitalTwinRequest: Codable, Sendable {
    /// Digital twin / avatar ID.
    public var avatarId: String

    /// Script text.
    public var script: String

    /// Voice ID (uses twin's default voice if omitted).
    public var voiceId: String?

    /// Aspect ratio.
    public var aspectRatio: String?

    public init(avatarId: String, script: String, voiceId: String? = nil, aspectRatio: String? = nil) {
        self.avatarId = avatarId
        self.script = script
        self.voiceId = voiceId
        self.aspectRatio = aspectRatio
    }

    enum CodingKeys: String, CodingKey {
        case script
        case avatarId = "avatar_id"
        case voiceId = "voice_id"
        case aspectRatio = "aspect_ratio"
    }
}

// MARK: - HeyGen Avatars

/// A HeyGen avatar.
public struct Avatar: Codable, Sendable {
    /// Avatar identifier.
    public var avatarId: String

    /// Avatar name.
    public var name: String?

    /// Avatar gender.
    public var gender: String?

    /// Preview image URL.
    public var previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, gender
        case avatarId = "avatar_id"
        case previewUrl = "preview_url"
    }
}

/// Response from listing HeyGen avatars.
public struct AvatarsResponse: Codable, Sendable {
    public var avatars: [Avatar]
}

// MARK: - HeyGen Templates

/// A HeyGen video template.
public struct VideoTemplate: Codable, Sendable {
    /// Template identifier.
    public var templateId: String

    /// Template name.
    public var name: String?

    /// Preview image URL.
    public var previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case templateId = "template_id"
        case previewUrl = "preview_url"
    }
}

/// Response from listing HeyGen video templates.
public struct VideoTemplatesResponse: Codable, Sendable {
    public var templates: [VideoTemplate]
}

// MARK: - HeyGen Voices

/// A HeyGen voice.
public struct HeyGenVoice: Codable, Sendable {
    /// Voice identifier.
    public var voiceId: String

    /// Voice name.
    public var name: String?

    /// Language.
    public var language: String?

    /// Gender.
    public var gender: String?

    /// Additional fields.
    public var extra: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case name, language, gender, extra
        case voiceId = "voice_id"
    }
}

/// Response from listing HeyGen voices.
public struct HeyGenVoicesResponse: Codable, Sendable {
    public var voices: [HeyGenVoice]
}
