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

    /// Deterministic seed. Same seed + prompt + params reproduces an image
    /// (provider support varies; ignored where unsupported).
    public var seed: Int?

    /// Classifier-free guidance scale — how strongly the model adheres to the
    /// prompt (provider support varies; ignored where unsupported).
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
        enablePbr: Bool? = nil
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
    }

    enum CodingKeys: String, CodingKey {
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
}

// MARK: - Generated Image

/// A single generated image.
public struct GeneratedImage: Codable, Sendable {
    /// Base64-encoded image data.
    public var base64: String?

    /// Image format (e.g. "png", "jpeg").
    public var format: String?

    /// Image index within the batch.
    public var index: Int?

    /// URL of the generated image (legacy).
    public var url: String?

    enum CodingKeys: String, CodingKey {
        case base64, format, index, url
    }
}

// MARK: - Image Response

/// Response from image generation.
public struct ImageResponse: Codable, Sendable {
    /// Generated images.
    public var images: [GeneratedImage]

    /// Model used.
    public var model: String

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case images, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Image Edit Request

/// Request body for image editing.
public struct ImageEditRequest: Codable, Sendable {
    /// Editing model (e.g. "gpt-image-1", "grok-imagine-image").
    public var model: String

    /// Describes the desired edit.
    public var prompt: String

    /// Base64-encoded input images.
    public var inputImages: [String]?

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

    /// Base64-encoded source image (legacy).
    public var image: String?

    /// Optional mask image for inpainting (legacy).
    public var mask: String?

    public init(
        model: String,
        prompt: String,
        inputImages: [String]? = nil,
        count: Int? = nil,
        size: String? = nil,
        aspectRatio: String? = nil,
        imageSize: String? = nil,
        quality: String? = nil,
        outputFormat: String? = nil,
        background: String? = nil,
        inputFidelity: String? = nil,
        grounding: Bool? = nil,
        image: String? = nil,
        mask: String? = nil
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
        self.image = image
        self.mask = mask
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, count, size, quality, background, grounding, image, mask
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
