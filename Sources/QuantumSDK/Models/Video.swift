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

// MARK: - HeyGen Typed Responses

/// Response from listing HeyGen avatars (includes requestId).
public struct HeyGenAvatarsResponse: Codable, Sendable {
    /// Available avatars (raw JSON items).
    public var avatars: [AnyCodable]?

    /// Unique request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case avatars
        case requestId = "request_id"
    }
}

/// Response from listing HeyGen templates (includes requestId).
public struct HeyGenTemplatesResponse: Codable, Sendable {
    /// Available templates (raw JSON items).
    public var templates: [AnyCodable]?

    /// Unique request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case templates
        case requestId = "request_id"
    }
}

// MARK: - HeyGen Template v3 (variable schema + render)

/// A variable slot referenced by a template scene.
public struct VideoTemplateSceneVariable: Codable, Sendable {
    /// Variable name (key into the template's `variables` map).
    public var name: String

    /// Variable kind (e.g. "text", "image", "character", "voice").
    public var variableType: String

    enum CodingKeys: String, CodingKey {
        case name
        case variableType = "variable_type"
    }
}

/// A scene in a template, in template order.
public struct VideoTemplateScene: Codable, Sendable {
    /// Scene identifier (usable in a generate request's `sceneIds`).
    public var sceneId: String

    /// Scene script with placeholders unreplaced (e.g. "Introducing {{headline}}...").
    public var script: String

    /// Variables referenced by this scene.
    public var variables: [VideoTemplateSceneVariable]

    enum CodingKeys: String, CodingKey {
        case script, variables
        case sceneId = "scene_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sceneId = try container.decode(String.self, forKey: .sceneId)
        script = try container.decodeIfPresent(String.self, forKey: .script) ?? ""
        variables = try container.decodeIfPresent([VideoTemplateSceneVariable].self, forKey: .variables) ?? []
    }
}

/// Detailed template info: variable schema + scenes.
///
/// Each `variables[name]` value is a discriminated union on its `"type"` field
/// ("text" | "image" | "video" | "audio" | "voice" | "character"; unknown
/// future types round-trip verbatim), returned in the exact shape a generate
/// request accepts — replace defaults and submit back.
public struct VideoTemplateDetail: Codable, Sendable {
    /// Template identifier.
    public var id: String

    /// Template name.
    public var name: String

    /// Aspect ratio (e.g. "16:9").
    public var aspectRatio: String

    /// Variable schema keyed by variable name (union values kept as raw JSON
    /// so unknown future variable types round-trip verbatim).
    public var variables: [String: AnyCodable]

    /// Scenes in template order.
    public var scenes: [VideoTemplateScene]

    enum CodingKeys: String, CodingKey {
        case id, name, variables, scenes
        case aspectRatio = "aspect_ratio"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        aspectRatio = try container.decodeIfPresent(String.self, forKey: .aspectRatio) ?? ""
        variables = try container.decodeIfPresent([String: AnyCodable].self, forKey: .variables) ?? [:]
        scenes = try container.decodeIfPresent([VideoTemplateScene].self, forKey: .scenes) ?? []
    }
}

/// Response from inspecting a template's variable schema (unbilled).
public struct VideoTemplateDetailResponse: Codable, Sendable {
    /// The template detail.
    public var template: VideoTemplateDetail

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case template
        case requestId = "request_id"
    }
}

/// Output dimension for a template render. Both values must be even,
/// each 128–4096, and keep the template aspect ratio.
public struct VideoTemplateDimension: Codable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Subtitle position for burned-in captions.
public struct VideoSubtitlePosition: Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Subtitle options for a template render (implies captions).
public struct VideoTemplateSubtitles: Codable, Sendable {
    /// Subtitle preset (e.g. "classic", "bold", "bright"). Required.
    public var presetName: String

    /// Alignment (default 2).
    public var alignment: Int?

    /// Disable word highlighting.
    public var disableHighlight: Bool?

    /// Font size.
    public var fontSize: Int?

    /// Subtitle position.
    public var position: VideoSubtitlePosition?

    public init(
        presetName: String,
        alignment: Int? = nil,
        disableHighlight: Bool? = nil,
        fontSize: Int? = nil,
        position: VideoSubtitlePosition? = nil
    ) {
        self.presetName = presetName
        self.alignment = alignment
        self.disableHighlight = disableHighlight
        self.fontSize = fontSize
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case alignment, position
        case presetName = "preset_name"
        case disableHighlight = "disable_highlight"
        case fontSize = "font_size"
    }
}

/// Request body for rendering a video from a template (async job).
public struct VideoTemplateGenerateRequest: Codable, Sendable {
    /// Variable overrides keyed by name (at least one required). Values use
    /// the same union shapes returned by the template detail route; omitted
    /// variables keep the template defaults.
    public var variables: [String: AnyCodable]

    /// Names the generated video.
    public var title: String?

    /// Restrict the render to these scenes, in order (repeats allowed).
    public var sceneIds: [String]?

    /// Output dimension (must keep the template aspect ratio).
    public var dimension: VideoTemplateDimension?

    /// Frames per second: 25 (default), 30, or 60.
    public var fps: Int?

    /// Burn captions (default false).
    public var caption: Bool?

    /// Subtitle options (implies captions).
    public var subtitles: VideoTemplateSubtitles?

    /// Background audio moves with scenes (default true).
    public var reorderMusic: Bool?

    /// Keep text vertically centered (default false).
    public var keepTextVerticallyCentered: Bool?

    /// Include a GIF preview in the webhook payload.
    public var includeGif: Bool?

    /// Enable a public share page.
    public var enableSharing: Bool?

    /// HeyGen folder id.
    public var folderId: String?

    /// Brand voice id.
    public var brandVoiceId: String?

    public init(
        variables: [String: AnyCodable],
        title: String? = nil,
        sceneIds: [String]? = nil,
        dimension: VideoTemplateDimension? = nil,
        fps: Int? = nil,
        caption: Bool? = nil,
        subtitles: VideoTemplateSubtitles? = nil,
        reorderMusic: Bool? = nil,
        keepTextVerticallyCentered: Bool? = nil,
        includeGif: Bool? = nil,
        enableSharing: Bool? = nil,
        folderId: String? = nil,
        brandVoiceId: String? = nil
    ) {
        self.variables = variables
        self.title = title
        self.sceneIds = sceneIds
        self.dimension = dimension
        self.fps = fps
        self.caption = caption
        self.subtitles = subtitles
        self.reorderMusic = reorderMusic
        self.keepTextVerticallyCentered = keepTextVerticallyCentered
        self.includeGif = includeGif
        self.enableSharing = enableSharing
        self.folderId = folderId
        self.brandVoiceId = brandVoiceId
    }

    enum CodingKeys: String, CodingKey {
        case variables, title, dimension, fps, caption, subtitles
        case sceneIds = "scene_ids"
        case reorderMusic = "reorder_music"
        case keepTextVerticallyCentered = "keep_text_vertically_centered"
        case includeGif = "include_gif"
        case enableSharing = "enable_sharing"
        case folderId = "folder_id"
        case brandVoiceId = "brand_voice_id"
    }
}

// MARK: - HeyGen Batch Videos

/// Request body for submitting a batch of videos.
public struct VideoBatchSubmitRequest: Codable, Sendable {
    /// 1–100 raw HeyGen `POST /v3/videos` request bodies, passed through
    /// verbatim. Each is polymorphic, discriminated by its `"type"` field
    /// ("avatar" | "image" | "cinematic_avatar"), so items are kept as
    /// opaque JSON objects.
    public var videos: [AnyCodable]

    /// Display name for the batch in the HeyGen app.
    public var title: String?

    public init(videos: [AnyCodable], title: String? = nil) {
        self.videos = videos
        self.title = title
    }
}

/// Response from submitting a video batch (202 Accepted).
public struct VideoBatchSubmitResponse: Codable, Sendable {
    /// Batch id — poll `videoBatchStatus` with it.
    public var batchId: String

    /// Always "processing" at submit.
    public var status: String

    /// Count of submitted items.
    public var totalItems: Int

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case status
        case batchId = "batch_id"
        case totalItems = "total_items"
        case requestId = "request_id"
    }
}

/// Query parameters for the batch status page.
public struct VideoBatchStatusQuery: Sendable {
    /// Page size (1–100; upstream default 100).
    public var limit: Int?

    /// Opaque cursor from a previous response's `nextToken`.
    public var token: String?

    public init(limit: Int? = nil, token: String? = nil) {
        self.limit = limit
        self.token = token
    }
}

/// Per-item error detail in a batch status page.
public struct VideoBatchItemError: Codable, Sendable {
    public var code: String
    public var message: String
}

/// One item of a batch status page, ordered by `itemIndex`.
public struct VideoBatchItem: Codable, Sendable {
    /// Zero-based position in the submitted `videos` array.
    public var itemIndex: Int

    /// "queued" | "processing" | "completed" | "failed".
    public var status: String

    /// Present once the item's video exists.
    public var videoId: String?

    /// Present only when `billingStatus == "settled"` and the item completed.
    public var videoUrl: String?

    /// Present only when the item failed.
    public var error: VideoBatchItemError?

    enum CodingKeys: String, CodingKey {
        case status, error
        case itemIndex = "item_index"
        case videoId = "video_id"
        case videoUrl = "video_url"
    }
}

/// Response from a batch status check (one cursor-paginated page of items).
///
/// Billing settles the first time a GET observes a terminal batch status;
/// `videoUrl` values are withheld until `billingStatus == "settled"` —
/// keep polling until then to obtain URLs.
public struct VideoBatchStatusResponse: Codable, Sendable {
    /// Batch id.
    public var batchId: String

    /// Batch display name (may be empty).
    public var title: String

    /// Batch-level status: "processing" | "completed" | "failed".
    public var status: String

    /// Count of submitted items.
    public var totalItems: Int

    /// Per-item-status counts across the whole batch.
    public var countsByStatus: [String: Int]

    /// Batch creation time in unix seconds (upstream HeyGen timestamp).
    public var createdAt: Int64

    /// One page of items, ordered by `itemIndex`.
    public var items: [VideoBatchItem]

    /// More item pages exist.
    public var hasMore: Bool

    /// Pass as `token` for the next page (may be empty).
    public var nextToken: String

    /// "unsettled" | "settlement_pending" | "settled".
    public var billingStatus: String

    /// Total ticks charged for the batch; 0 until settled.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case title, status, items
        case batchId = "batch_id"
        case totalItems = "total_items"
        case countsByStatus = "counts_by_status"
        case createdAt = "created_at"
        case hasMore = "has_more"
        case nextToken = "next_token"
        case billingStatus = "billing_status"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        batchId = try container.decode(String.self, forKey: .batchId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        status = try container.decode(String.self, forKey: .status)
        totalItems = try container.decodeIfPresent(Int.self, forKey: .totalItems) ?? 0
        countsByStatus = try container.decodeIfPresent([String: Int].self, forKey: .countsByStatus) ?? [:]
        createdAt = try container.decodeIfPresent(Int64.self, forKey: .createdAt) ?? 0
        items = try container.decodeIfPresent([VideoBatchItem].self, forKey: .items) ?? []
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextToken = try container.decodeIfPresent(String.self, forKey: .nextToken) ?? ""
        billingStatus = try container.decodeIfPresent(String.self, forKey: .billingStatus) ?? ""
        costTicks = try container.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}
