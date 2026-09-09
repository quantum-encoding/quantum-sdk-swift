import Foundation

// MARK: - Image Request

/// Request body for image generation.
public struct ImageRequest: Codable, Sendable {
    /// Image generation model (e.g. "grok-imagine-image", "gpt-image-1", "dall-e-3").
    public var model: String

    /// Describes the image to generate.
    public var prompt: String

    /// Number of images to generate (default 1).
    public var count: Int?

    /// Output dimensions (e.g. "1024x1024", "1536x1024").
    public var size: String?

    /// Aspect ratio (e.g. "16:9", "1:1").
    public var aspectRatio: String?

    /// Quality level (e.g. "standard", "hd").
    public var quality: String?

    /// Image format (e.g. "png", "jpeg", "webp").
    public var outputFormat: String?

    /// Output quality 0-100 for JPEG/WebP (GPT-Image). Schema id
    /// `output_compression`; ignored for PNG and by other providers.
    public var compression: Int?

    /// Style preset (e.g. "vivid", "natural"). DALL-E 3 specific.
    public var style: String?

    /// Background mode (e.g. "auto", "transparent", "opaque"). GPT-Image specific.
    public var background: String?

    /// Deterministic seed. Sent as `seed`; the gateway's image request has no
    /// such field today, so it is dropped for every provider.
    public var seed: Int?

    /// Classifier-free guidance scale. Sent as `cfg_scale`; the gateway's
    /// image request has no such field today, so it is dropped for every
    /// provider.
    public var cfgScale: Double?

    /// Image URL or data URI for image-to-3D conversion (Meshy).
    public var imageUrl: String?

    /// Mesh topology: "triangle" or "quad".
    public var topology: String?

    /// Target polygon count (100-300,000).
    public var targetPolycount: Int?

    /// Symmetry mode: "auto", "on", or "off".
    public var symmetryMode: String?

    /// Pose mode: "", "a-pose", or "t-pose".
    public var poseMode: String?

    /// Generate PBR texture maps (base_color, metallic, roughness, normal).
    public var enablePbr: Bool?

    /// Catalog-schema-driven parameters with no typed field here —
    /// `negative_prompt`, `person_generation`, `number_of_images`, and
    /// whatever else the model's schema accepts. Flattened into the top-level
    /// body, so an entry lands beside `prompt` rather than nested under a key.
    /// Empty by default, and an empty map encodes to nothing.
    ///
    /// A name that collides with a typed field overwrites it, since both write
    /// to the same JSON object.
    public var extra: [String: AnyCodable]

    public init(
        model: String,
        prompt: String,
        count: Int? = nil,
        size: String? = nil,
        aspectRatio: String? = nil,
        quality: String? = nil,
        outputFormat: String? = nil,
        compression: Int? = nil,
        style: String? = nil,
        background: String? = nil,
        seed: Int? = nil,
        cfgScale: Double? = nil,
        imageUrl: String? = nil,
        topology: String? = nil,
        targetPolycount: Int? = nil,
        symmetryMode: String? = nil,
        poseMode: String? = nil,
        enablePbr: Bool? = nil,
        extra: [String: AnyCodable] = [:]
    ) {
        self.model = model
        self.prompt = prompt
        self.count = count
        self.size = size
        self.aspectRatio = aspectRatio
        self.quality = quality
        self.outputFormat = outputFormat
        self.compression = compression
        self.style = style
        self.background = background
        self.seed = seed
        self.cfgScale = cfgScale
        self.imageUrl = imageUrl
        self.topology = topology
        self.targetPolycount = targetPolycount
        self.symmetryMode = symmetryMode
        self.poseMode = poseMode
        self.enablePbr = enablePbr
        self.extra = extra
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case model, prompt, count, size, quality, style, background, seed, topology
        case cfgScale = "cfg_scale"
        case aspectRatio = "aspect_ratio"
        case outputFormat = "output_format"
        case compression = "output_compression"
        case imageUrl = "image_url"
        case targetPolycount = "target_polycount"
        case symmetryMode = "symmetry_mode"
        case poseMode = "pose_mode"
        case enablePbr = "enable_pbr"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        model = try c.decode(String.self, forKey: .model)
        prompt = try c.decode(String.self, forKey: .prompt)
        count = try c.decodeIfPresent(Int.self, forKey: .count)
        size = try c.decodeIfPresent(String.self, forKey: .size)
        aspectRatio = try c.decodeIfPresent(String.self, forKey: .aspectRatio)
        quality = try c.decodeIfPresent(String.self, forKey: .quality)
        outputFormat = try c.decodeIfPresent(String.self, forKey: .outputFormat)
        compression = try c.decodeIfPresent(Int.self, forKey: .compression)
        style = try c.decodeIfPresent(String.self, forKey: .style)
        background = try c.decodeIfPresent(String.self, forKey: .background)
        seed = try c.decodeIfPresent(Int.self, forKey: .seed)
        cfgScale = try c.decodeIfPresent(Double.self, forKey: .cfgScale)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        topology = try c.decodeIfPresent(String.self, forKey: .topology)
        targetPolycount = try c.decodeIfPresent(Int.self, forKey: .targetPolycount)
        symmetryMode = try c.decodeIfPresent(String.self, forKey: .symmetryMode)
        poseMode = try c.decodeIfPresent(String.self, forKey: .poseMode)
        enablePbr = try c.decodeIfPresent(Bool.self, forKey: .enablePbr)
        extra = try decodeFlattened(from: decoder, known: Set(CodingKeys.allCases.map(\.rawValue)))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(model, forKey: .model)
        try c.encode(prompt, forKey: .prompt)
        try c.encodeIfPresent(count, forKey: .count)
        try c.encodeIfPresent(size, forKey: .size)
        try c.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
        try c.encodeIfPresent(quality, forKey: .quality)
        try c.encodeIfPresent(outputFormat, forKey: .outputFormat)
        try c.encodeIfPresent(compression, forKey: .compression)
        try c.encodeIfPresent(style, forKey: .style)
        try c.encodeIfPresent(background, forKey: .background)
        try c.encodeIfPresent(seed, forKey: .seed)
        try c.encodeIfPresent(cfgScale, forKey: .cfgScale)
        try c.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try c.encodeIfPresent(topology, forKey: .topology)
        try c.encodeIfPresent(targetPolycount, forKey: .targetPolycount)
        try c.encodeIfPresent(symmetryMode, forKey: .symmetryMode)
        try c.encodeIfPresent(poseMode, forKey: .poseMode)
        try c.encodeIfPresent(enablePbr, forKey: .enablePbr)
        try encodeFlattened(extra, into: encoder)
    }
}

// MARK: - Generated Image

/// A single generated image. Always inline bytes; no route emits a URL.
public struct GeneratedImage: Codable, Sendable {
    /// Base64-encoded image data.
    public var base64: String

    /// Image format (e.g. "png", "jpeg").
    public var format: String

    /// Image index within the batch.
    public var index: Int

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base64 = try c.decode(String.self, forKey: .base64)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
    }
}

// MARK: - Image Usage

/// The token counts behind a token-priced image charge.
///
/// Flat-priced models report none and ``ImageResponse/usage`` is `nil`: their
/// rate is per image and checkable without them. For a token-priced model
/// these are the whole audit — two real gpt-image-2 generations on the same
/// day came back at $0.0527 and $0.01628, a 3x spread with nothing else on
/// the wire to explain it.
public struct ImageUsage: Codable, Sendable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }

    public init(promptTokens: Int = 0, completionTokens: Int = 0, totalTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        promptTokens = try c.decodeIfPresent(Int.self, forKey: .promptTokens) ?? 0
        completionTokens = try c.decodeIfPresent(Int.self, forKey: .completionTokens) ?? 0
        totalTokens = try c.decodeIfPresent(Int.self, forKey: .totalTokens) ?? 0
    }
}

// MARK: - Image Response

/// Response from image generation.
public struct ImageResponse: Codable, Sendable {
    /// Generated images.
    @NullToEmpty public var images: [GeneratedImage]

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Post-charge credit balance in ticks, when the body carries it.
    public var balanceAfter: Int64?

    /// Unique request identifier.
    public var requestId: String

    /// The prompt the provider actually generated from, when it rewrote the
    /// one it was given.
    ///
    /// gpt-image routinely rewrites; the picture is made from this text, not
    /// from what was sent. A caller holding only its own prompt cannot
    /// reproduce its own image, and cannot tell why the output drifted.
    /// `nil` when the provider returned no rewrite.
    public var revisedPrompt: String?

    /// The token counts the charge was computed from, for models priced on
    /// tokens rather than per image. `nil` on flat-priced models.
    public var usage: ImageUsage?

    enum CodingKeys: String, CodingKey {
        case images, model, usage
        case costTicks = "cost_ticks"
        case balanceAfter = "balance_after"
        case requestId = "request_id"
        case revisedPrompt = "revised_prompt"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _images = try c.decode(NullToEmpty<GeneratedImage>.self, forKey: .images)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        balanceAfter = try c.decodeIfPresent(Int64.self, forKey: .balanceAfter)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
        revisedPrompt = try c.decodeIfPresent(String.self, forKey: .revisedPrompt)
        usage = try c.decodeIfPresent(ImageUsage.self, forKey: .usage)
    }
}

// MARK: - Image Edit Request

/// Request body for image editing. `inputImages` is required by the route
/// (`model, prompt, and input_images are required`).
public struct ImageEditRequest: Codable, Sendable {
    /// Editing model (e.g. "gpt-image-1", "grok-imagine-image").
    public var model: String

    /// Describes the desired edit.
    public var prompt: String

    /// Base64-encoded input images (at least one).
    public var inputImages: [String]

    /// Number of edited images to generate (default 1).
    public var count: Int?

    /// Output dimensions.
    public var size: String?

    /// Aspect ratio, e.g. "1:1", "16:9" (Gemini image edit).
    public var aspectRatio: String?

    /// Output resolution tier: "1K", "2K", "4K" (Gemini Pro image edit).
    public var imageSize: String?

    /// Quality: "auto", "low", "medium", "high" (GPT-Image).
    public var quality: String?

    /// Output format: "png", "jpeg", "webp" (GPT-Image).
    public var outputFormat: String?

    /// Background: "auto", "transparent", "opaque" (GPT-Image).
    public var background: String?

    /// "high" preserves faces/details from the input (GPT-Image).
    public var inputFidelity: String?

    /// Enable Google Search grounding (Gemini Pro only).
    public var grounding: Bool?

    public init(
        model: String,
        prompt: String,
        inputImages: [String],
        count: Int? = nil,
        size: String? = nil,
        aspectRatio: String? = nil,
        imageSize: String? = nil,
        quality: String? = nil,
        outputFormat: String? = nil,
        background: String? = nil,
        inputFidelity: String? = nil,
        grounding: Bool? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.inputImages = inputImages
        self.count = count
        self.size = size
        self.aspectRatio = aspectRatio
        self.imageSize = imageSize
        self.quality = quality
        self.outputFormat = outputFormat
        self.background = background
        self.inputFidelity = inputFidelity
        self.grounding = grounding
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, count, size, quality, background, grounding
        case inputImages = "input_images"
        case aspectRatio = "aspect_ratio"
        case imageSize = "image_size"
        case outputFormat = "output_format"
        case inputFidelity = "input_fidelity"
    }
}

// MARK: - Image Edit Response

/// Response from image editing (same shape as generation).
public typealias ImageEditResponse = ImageResponse
