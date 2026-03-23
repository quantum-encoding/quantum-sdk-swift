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

    /// Style preset (e.g. "vivid", "natural"). DALL-E 3 specific.
    public var style: String?

    /// Background mode (e.g. "auto", "transparent", "opaque"). GPT-Image specific.
    public var background: String?

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
        style: String? = nil,
        background: String? = nil,
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
        self.style = style
        self.background = background
        self.imageUrl = imageUrl
        self.topology = topology
        self.targetPolycount = targetPolycount
        self.symmetryMode = symmetryMode
        self.poseMode = poseMode
        self.enablePbr = enablePbr
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, count, size, quality, style, background, topology
        case aspectRatio = "aspect_ratio"
        case outputFormat = "output_format"
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
        image: String? = nil,
        mask: String? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.inputImages = inputImages
        self.count = count
        self.size = size
        self.image = image
        self.mask = mask
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, count, size, image, mask
        case inputImages = "input_images"
    }
}

// MARK: - Image Edit Response

/// Response from image editing (same shape as generation).
public typealias ImageEditResponse = ImageResponse
