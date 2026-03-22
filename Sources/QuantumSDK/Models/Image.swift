import Foundation

// MARK: - Image Request

/// Request body for the `/qai/v1/images/generate` endpoint.
public struct ImageRequest: Codable, Sendable {
    /// Model for image generation.
    public var model: String

    /// Text prompt describing the image.
    public var prompt: String

    /// Number of images to generate.
    public var n: Int?

    /// Image size (e.g. "1024x1024").
    public var size: String?

    /// Quality level (e.g. "standard", "hd").
    public var quality: String?

    public init(model: String, prompt: String, n: Int? = nil, size: String? = nil, quality: String? = nil) {
        self.model = model
        self.prompt = prompt
        self.n = n
        self.size = size
        self.quality = quality
    }
}

// MARK: - Generated Image

/// A single generated image.
public struct GeneratedImage: Codable, Sendable {
    /// URL of the generated image.
    public var url: String?

    /// Base64-encoded image data.
    public var b64Json: String?

    enum CodingKeys: String, CodingKey {
        case url
        case b64Json = "b64_json"
    }
}

// MARK: - Image Response

/// Response from the `/qai/v1/images/generate` endpoint.
public struct ImageResponse: Codable, Sendable {
    /// Generated images.
    public var images: [GeneratedImage]

    /// Model used.
    public var model: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case images, model
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Image Edit Request

/// Request body for the `/qai/v1/images/edit` endpoint.
public struct ImageEditRequest: Codable, Sendable {
    /// Model for image editing.
    public var model: String

    /// Text prompt describing the edit.
    public var prompt: String

    /// Base64-encoded source image.
    public var image: String

    /// Optional mask image for inpainting.
    public var mask: String?

    /// Image size.
    public var size: String?

    /// Number of images.
    public var n: Int?

    public init(
        model: String,
        prompt: String,
        image: String,
        mask: String? = nil,
        size: String? = nil,
        n: Int? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.image = image
        self.mask = mask
        self.size = size
        self.n = n
    }
}

// MARK: - Image Edit Response

/// Response from the `/qai/v1/images/edit` endpoint.
public struct ImageEditResponse: Codable, Sendable {
    /// Edited images.
    public var images: [GeneratedImage]

    /// Model used.
    public var model: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case images, model
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}
