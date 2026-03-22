import Foundation

// MARK: - Video Request

/// Request body for the `/qai/v1/video/generate` endpoint.
public struct VideoRequest: Codable, Sendable {
    /// Model for video generation.
    public var model: String

    /// Text prompt.
    public var prompt: String

    /// Duration in seconds.
    public var duration: Int?

    /// Resolution (e.g. "720p", "1080p").
    public var resolution: String?

    public init(model: String, prompt: String, duration: Int? = nil, resolution: String? = nil) {
        self.model = model
        self.prompt = prompt
        self.duration = duration
        self.resolution = resolution
    }
}

// MARK: - Generated Video

/// A single generated video.
public struct GeneratedVideo: Codable, Sendable {
    /// URL of the generated video.
    public var url: String

    /// Duration in seconds.
    public var durationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case url
        case durationSeconds = "duration_seconds"
    }
}

// MARK: - Video Response

/// Response from the `/qai/v1/video/generate` endpoint.
public struct VideoResponse: Codable, Sendable {
    /// Generated videos.
    public var videos: [GeneratedVideo]

    /// Model used.
    public var model: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case videos, model
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - HeyGen Types

/// Request body for the `/qai/v1/video/studio` endpoint.
public struct VideoStudioRequest: Codable, Sendable {
    /// Avatar ID.
    public var avatarId: String

    /// Script text.
    public var script: String

    /// Voice ID (optional).
    public var voiceId: String?

    /// Clips for multi-scene videos.
    public var clips: [StudioClip]?

    public init(avatarId: String, script: String, voiceId: String? = nil, clips: [StudioClip]? = nil) {
        self.avatarId = avatarId
        self.script = script
        self.voiceId = voiceId
        self.clips = clips
    }

    enum CodingKeys: String, CodingKey {
        case script, clips
        case avatarId = "avatar_id"
        case voiceId = "voice_id"
    }
}

/// A single clip in a multi-scene studio video.
public struct StudioClip: Codable, Sendable {
    /// Avatar ID.
    public var avatarId: String

    /// Script text.
    public var script: String

    /// Voice ID.
    public var voiceId: String?

    /// Background image/color.
    public var background: String?

    public init(avatarId: String, script: String, voiceId: String? = nil, background: String? = nil) {
        self.avatarId = avatarId
        self.script = script
        self.voiceId = voiceId
        self.background = background
    }

    enum CodingKeys: String, CodingKey {
        case script, background
        case avatarId = "avatar_id"
        case voiceId = "voice_id"
    }
}

/// Request body for the `/qai/v1/video/translate` endpoint.
public struct VideoTranslateRequest: Codable, Sendable {
    /// URL of the video to translate.
    public var videoUrl: String

    /// Target language code.
    public var targetLang: String

    /// Source language code (auto-detect if omitted).
    public var sourceLang: String?

    public init(videoUrl: String, targetLang: String, sourceLang: String? = nil) {
        self.videoUrl = videoUrl
        self.targetLang = targetLang
        self.sourceLang = sourceLang
    }

    enum CodingKeys: String, CodingKey {
        case videoUrl = "video_url"
        case targetLang = "target_lang"
        case sourceLang = "source_lang"
    }
}

/// Request body for the `/qai/v1/video/photo-avatar` endpoint.
public struct PhotoAvatarRequest: Codable, Sendable {
    /// Base64-encoded photo image.
    public var image: String

    public init(image: String) {
        self.image = image
    }
}

/// Request body for the `/qai/v1/video/digital-twin` endpoint.
public struct DigitalTwinRequest: Codable, Sendable {
    /// Base64-encoded training video.
    public var video: String

    public init(video: String) {
        self.video = video
    }
}

/// Response from async HeyGen job endpoints.
public struct AsyncJobResponse: Codable, Sendable {
    /// Job ID for polling.
    public var jobId: String

    /// Current job status.
    public var status: String

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
    }
}

/// A HeyGen avatar.
public struct HeyGenAvatar: Codable, Sendable {
    /// Avatar ID.
    public var avatarId: String

    /// Avatar display name.
    public var avatarName: String

    /// Preview image URL.
    public var previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case avatarId = "avatar_id"
        case avatarName = "avatar_name"
        case previewUrl = "preview_url"
    }
}

/// Response from the `/qai/v1/video/avatars` endpoint.
public struct AvatarsResponse: Codable, Sendable {
    /// Available avatars.
    public var avatars: [HeyGenAvatar]
}

/// A HeyGen template.
public struct HeyGenTemplate: Codable, Sendable {
    /// Template ID.
    public var templateId: String

    /// Template name.
    public var name: String

    enum CodingKeys: String, CodingKey {
        case name
        case templateId = "template_id"
    }
}

/// Response from the `/qai/v1/video/templates` endpoint.
public struct HeyGenTemplatesResponse: Codable, Sendable {
    /// Available templates.
    public var templates: [HeyGenTemplate]
}

/// A HeyGen voice.
public struct HeyGenVoice: Codable, Sendable {
    /// Voice ID.
    public var voiceId: String

    /// Voice name.
    public var name: String

    /// Language code.
    public var language: String?

    enum CodingKeys: String, CodingKey {
        case name, language
        case voiceId = "voice_id"
    }
}

/// Response from the `/qai/v1/video/heygen-voices` endpoint.
public struct HeyGenVoicesResponse: Codable, Sendable {
    /// Available voices.
    public var voices: [HeyGenVoice]
}
