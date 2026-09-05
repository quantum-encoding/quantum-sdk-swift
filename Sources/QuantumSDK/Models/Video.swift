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
    /// Base64-encoded video bytes (never a URL on this route).
    public var base64: String

    /// Video format (e.g. "mp4").
    public var format: String

    /// Video file size.
    public var sizeBytes: Int64

    /// Video index within the batch.
    public var index: Int

    enum CodingKeys: String, CodingKey {
        case base64, format, index
        case sizeBytes = "size_bytes"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base64 = try c.decode(String.self, forKey: .base64)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        sizeBytes = try c.decodeIfPresent(Int64.self, forKey: .sizeBytes) ?? 0
        index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
    }
}

// MARK: - Video Response

/// Response from video generation.
public struct VideoResponse: Codable, Sendable {
    /// Generated videos.
    @NullToEmpty public var videos: [GeneratedVideo]

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Post-charge credit balance in ticks, when the body carries it.
    public var balanceAfter: Int64?

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case videos, model
        case costTicks = "cost_ticks"
        case balanceAfter = "balance_after"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _videos = try c.decode(NullToEmpty<GeneratedVideo>.self, forKey: .videos)
        model = try c.decode(String.self, forKey: .model)
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        balanceAfter = try c.decodeIfPresent(Int64.self, forKey: .balanceAfter)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

/// Backwards-compatible alias: the HeyGen video routes answer with the
/// shared 202 job envelope (which never carries a cost).
public typealias JobResponse = JobAcceptedResponse

// MARK: - HeyGen Studio

/// Request body for a HeyGen studio talking-head video: one avatar reading
/// one script in one voice. All three fields are required.
///
/// Submission is gated by a balance preflight estimated from the script
/// length, so an under-funded caller gets 402 at submit rather than a
/// failed job.
public struct VideoStudioRequest: Codable, Sendable {
    /// HeyGen avatar id.
    public var avatarId: String

    /// Script the avatar speaks.
    public var script: String

    /// HeyGen voice id.
    public var voiceId: String

    public init(avatarId: String, script: String, voiceId: String) {
        self.avatarId = avatarId
        self.script = script
        self.voiceId = voiceId
    }

    enum CodingKeys: String, CodingKey {
        case script
        case avatarId = "avatar_id"
        case voiceId = "voice_id"
    }
}

/// Backwards-compatible alias.
public typealias StudioVideoRequest = VideoStudioRequest

// MARK: - HeyGen Translate

/// Request body for video translation. The source must be reachable by
/// URL; there is no inline-bytes variant on this route.
public struct VideoTranslateRequest: Codable, Sendable {
    /// URL of the video to translate (required).
    public var videoUrl: String

    /// Target language (required). Wire field `output_language`.
    public var outputLanguage: String

    /// Source language (auto-detected if omitted).
    public var sourceLanguage: String?

    /// Title for the translated video.
    public var title: String?

    public init(videoUrl: String, outputLanguage: String, sourceLanguage: String? = nil, title: String? = nil) {
        self.videoUrl = videoUrl
        self.outputLanguage = outputLanguage
        self.sourceLanguage = sourceLanguage
        self.title = title
    }

    enum CodingKeys: String, CodingKey {
        case title
        case videoUrl = "video_url"
        case outputLanguage = "output_language"
        case sourceLanguage = "source_language"
    }
}

/// Backwards-compatible alias.
public typealias TranslateRequest = VideoTranslateRequest

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

// MARK: - HeyGen Digital Twin (creation)

/// Request body for creating a digital twin from training footage
/// (`POST /qai/v1/video/digital-twin`, JSON variant). This trains an avatar;
/// it does not render a video — see ``TwinVideoRequest`` for that.
///
/// A flat fee is held before the body is decoded and released on every
/// error path, so a rejected request costs nothing but a ledger round-trip.
public struct DigitalTwinCreateRequest: Codable, Sendable {
    /// Display name for the twin.
    public var name: String

    /// URL of the training footage (required).
    public var videoUrl: String

    /// Add the look to an existing avatar group instead of creating one.
    public var avatarGroupId: String?

    public init(name: String, videoUrl: String, avatarGroupId: String? = nil) {
        self.name = name
        self.videoUrl = videoUrl
        self.avatarGroupId = avatarGroupId
    }

    enum CodingKeys: String, CodingKey {
        case name
        case videoUrl = "video_url"
        case avatarGroupId = "avatar_group_id"
    }
}

// MARK: - HeyGen Avatars

/// A HeyGen avatar look.
public struct Avatar: Codable, Sendable {
    /// Avatar identifier (what the video routes accept as `avatar_id`).
    public var avatarId: String

    /// Avatar name. Wire field: `avatar_name`.
    public var name: String

    /// Avatar gender.
    public var gender: String

    /// Preview image URL. Wire field: `preview_image_url`.
    public var previewUrl: String

    /// Look type: "studio_avatar" | "digital_twin" | "photo_avatar".
    /// Wire field: `type`.
    public var avatarType: String

    enum CodingKeys: String, CodingKey {
        case gender
        case avatarId = "avatar_id"
        case name = "avatar_name"
        case previewUrl = "preview_image_url"
        case avatarType = "type"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        avatarId = try c.decode(String.self, forKey: .avatarId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        gender = try c.decodeIfPresent(String.self, forKey: .gender) ?? ""
        previewUrl = try c.decodeIfPresent(String.self, forKey: .previewUrl) ?? ""
        avatarType = try c.decodeIfPresent(String.self, forKey: .avatarType) ?? ""
    }
}

/// Response from listing HeyGen avatars.
public struct AvatarsResponse: Codable, Sendable {
    /// Available avatars.
    @NullToEmpty public var avatars: [Avatar]

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case avatars
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _avatars = try c.decode(NullToEmpty<Avatar>.self, forKey: .avatars)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

// MARK: - HeyGen Templates

/// A HeyGen video template (API-ready, draft-v4 templates only).
public struct VideoTemplate: Codable, Sendable {
    /// Template identifier.
    public var templateId: String

    /// Template name.
    public var name: String

    /// Thumbnail image URL. Wire field: `thumbnail_image_url`.
    public var thumbnailUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case templateId = "template_id"
        case thumbnailUrl = "thumbnail_image_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        templateId = try c.decode(String.self, forKey: .templateId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl) ?? ""
    }
}

/// Response from listing HeyGen video templates.
public struct VideoTemplatesResponse: Codable, Sendable {
    /// Available templates.
    @NullToEmpty public var templates: [VideoTemplate]

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case templates
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _templates = try c.decode(NullToEmpty<VideoTemplate>.self, forKey: .templates)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

// MARK: - HeyGen Voices

/// A HeyGen voice.
public struct HeyGenVoice: Codable, Sendable {
    /// Voice identifier.
    public var voiceId: String

    /// Voice name. Wire field: `display_name`.
    public var name: String

    /// Language.
    public var language: String

    /// Gender.
    public var gender: String

    /// Preview audio URL. Wire field: `preview_audio`.
    public var previewUrl: String

    enum CodingKeys: String, CodingKey {
        case language, gender
        case voiceId = "voice_id"
        case name = "display_name"
        case previewUrl = "preview_audio"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        voiceId = try c.decode(String.self, forKey: .voiceId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? ""
        gender = try c.decodeIfPresent(String.self, forKey: .gender) ?? ""
        previewUrl = try c.decodeIfPresent(String.self, forKey: .previewUrl) ?? ""
    }
}

/// Response from listing HeyGen voices.
public struct HeyGenVoicesResponse: Codable, Sendable {
    /// Available voices (public catalog followed by the account's private
    /// voices).
    @NullToEmpty public var voices: [HeyGenVoice]

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case voices
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _voices = try c.decode(NullToEmpty<HeyGenVoice>.self, forKey: .voices)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        variableType = try c.decodeIfPresent(String.self, forKey: .variableType) ?? ""
    }
}

/// A scene in a template, in template order.
public struct VideoTemplateScene: Codable, Sendable {
    /// Scene identifier (usable in a generate request's `sceneIds`).
    public var sceneId: String

    /// Scene script with placeholders unreplaced (e.g. "Introducing {{headline}}...").
    public var script: String

    /// Variables referenced by this scene.
    @NullToEmpty public var variables: [VideoTemplateSceneVariable]

    enum CodingKeys: String, CodingKey {
        case script, variables
        case sceneId = "scene_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sceneId = try container.decode(String.self, forKey: .sceneId)
        script = try container.decodeIfPresent(String.self, forKey: .script) ?? ""
        _variables = try container.decode(NullToEmpty<VideoTemplateSceneVariable>.self, forKey: .variables)
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
    @NullToEmpty public var scenes: [VideoTemplateScene]

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
        _scenes = try container.decode(NullToEmpty<VideoTemplateScene>.self, forKey: .scenes)
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        template = try c.decode(VideoTemplateDetail.self, forKey: .template)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

/// Output dimension for a template render. HeyGen requires both values
/// even, each 128–4096, and matching the template aspect ratio; neither the
/// SDK nor the gateway checks this at submit, so a bad dimension is accepted
/// with 202 and surfaces later as a failed job.
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
    }
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemIndex = try c.decodeIfPresent(Int.self, forKey: .itemIndex) ?? 0
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        videoId = try c.decodeIfPresent(String.self, forKey: .videoId)
        videoUrl = try c.decodeIfPresent(String.self, forKey: .videoUrl)
        error = try c.decodeIfPresent(VideoBatchItemError.self, forKey: .error)
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
    @NullToEmpty public var items: [VideoBatchItem]

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
        _items = try container.decode(NullToEmpty<VideoBatchItem>.self, forKey: .items)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextToken = try container.decodeIfPresent(String.self, forKey: .nextToken) ?? ""
        billingStatus = try container.decodeIfPresent(String.self, forKey: .billingStatus) ?? ""
        costTicks = try container.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}
