import Foundation

// MARK: - Vision Request

/// Request body for vision analysis endpoints.
public struct VisionRequest: Codable, Sendable {
    /// Base64-encoded image (with or without data: prefix).
    public var imageBase64: String?

    /// Image URL (fetched by the model provider).
    public var imageURL: String?

    /// Model to use. Default: gemini-2.5-flash.
    public var model: String?

    /// Analysis profile: "combined" (default), "scene", "objects", "ocr", "quality".
    public var profile: String?

    /// Domain context for relevance checking.
    public var context: VisionContext?

    public init(
        imageBase64: String? = nil,
        imageURL: String? = nil,
        model: String? = nil,
        profile: String? = nil,
        context: VisionContext? = nil
    ) {
        self.imageBase64 = imageBase64
        self.imageURL = imageURL
        self.model = model
        self.profile = profile
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case imageURL = "image_url"
        case model, profile, context
    }
}

/// Domain context for relevance analysis.
public struct VisionContext: Codable, Sendable {
    /// Installation type (e.g. "solar", "heat_pump", "ev_charger").
    public var installationType: String?

    /// Phase (e.g. "pre_install", "installation", "post_install").
    public var phase: String?

    /// Expected items for relevance checking.
    public var expectedItems: [String]?

    public init(
        installationType: String? = nil,
        phase: String? = nil,
        expectedItems: [String]? = nil
    ) {
        self.installationType = installationType
        self.phase = phase
        self.expectedItems = expectedItems
    }

    enum CodingKeys: String, CodingKey {
        case installationType = "installation_type"
        case phase
        case expectedItems = "expected_items"
    }
}

// MARK: - Vision Response

/// Full vision analysis response.
public struct VisionResponse: Codable, Sendable {
    /// Scene description.
    public var caption: String?

    /// Suggested tags (lowercase_snake_case).
    public var tags: [String]

    /// Detected objects with bounding boxes.
    public var objects: [DetectedObject]

    /// Image quality assessment.
    public var quality: QualityAssessment?

    /// Relevance check against context.
    public var relevance: RelevanceCheck?

    /// Extracted text and overlay metadata.
    public var ocr: OCRResult?

    /// Model used.
    public var model: String

    /// Cost in ticks.
    public var costTicks: Int64

    /// Request identifier.
    public var requestId: String

    public init(
        caption: String? = nil,
        tags: [String] = [],
        objects: [DetectedObject] = [],
        quality: QualityAssessment? = nil,
        relevance: RelevanceCheck? = nil,
        ocr: OCRResult? = nil,
        model: String = "",
        costTicks: Int64 = 0,
        requestId: String = ""
    ) {
        self.caption = caption
        self.tags = tags
        self.objects = objects
        self.quality = quality
        self.relevance = relevance
        self.ocr = ocr
        self.model = model
        self.costTicks = costTicks
        self.requestId = requestId
    }

    enum CodingKeys: String, CodingKey {
        case caption, tags, objects, quality, relevance, ocr, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// A detected object with bounding box.
public struct DetectedObject: Codable, Sendable {
    /// Object label.
    public var label: String

    /// Detection confidence (0.0 - 1.0).
    public var confidence: Double

    /// Bounding box: [y_min, x_min, y_max, x_max] normalised to 0-1000.
    public var boundingBox: [Int]

    public init(label: String = "", confidence: Double = 0, boundingBox: [Int] = []) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }

    enum CodingKeys: String, CodingKey {
        case label, confidence
        case boundingBox = "bounding_box"
    }
}

/// Image quality assessment.
public struct QualityAssessment: Codable, Sendable {
    /// Overall rating: "good", "acceptable", "poor".
    public var overall: String

    /// Quality score (0.0 - 1.0).
    public var score: Double

    /// Blur level: "none", "slight", "significant".
    public var blur: String

    /// Lighting: "well_lit", "dim", "dark".
    public var darkness: String

    /// Resolution: "high", "adequate", "low".
    public var resolution: String

    /// Exposure: "correct", "over", "under".
    public var exposure: String

    /// Specific issues found.
    public var issues: [String]

    public init(
        overall: String = "",
        score: Double = 0,
        blur: String = "",
        darkness: String = "",
        resolution: String = "",
        exposure: String = "",
        issues: [String] = []
    ) {
        self.overall = overall
        self.score = score
        self.blur = blur
        self.darkness = darkness
        self.resolution = resolution
        self.exposure = exposure
        self.issues = issues
    }
}

/// Relevance check against expected content.
public struct RelevanceCheck: Codable, Sendable {
    /// Whether the image is relevant to the context.
    public var relevant: Bool

    /// Relevance score (0.0 - 1.0).
    public var score: Double

    /// Items expected based on context.
    public var expectedItems: [String]

    /// Items actually found in the image.
    public var foundItems: [String]

    /// Expected but not found.
    public var missingItems: [String]

    /// Found but not expected.
    public var unexpectedItems: [String]

    /// Additional notes.
    public var notes: String?

    public init(
        relevant: Bool = false,
        score: Double = 0,
        expectedItems: [String] = [],
        foundItems: [String] = [],
        missingItems: [String] = [],
        unexpectedItems: [String] = [],
        notes: String? = nil
    ) {
        self.relevant = relevant
        self.score = score
        self.expectedItems = expectedItems
        self.foundItems = foundItems
        self.missingItems = missingItems
        self.unexpectedItems = unexpectedItems
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case relevant, score, notes
        case expectedItems = "expected_items"
        case foundItems = "found_items"
        case missingItems = "missing_items"
        case unexpectedItems = "unexpected_items"
    }
}

/// OCR / text extraction result.
public struct OCRResult: Codable, Sendable {
    /// All extracted text concatenated.
    public var text: String?

    /// Extracted metadata (GPS, timestamp, address, etc.).
    public var metadata: [String: String]

    /// Individual text overlays with positions.
    public var overlays: [TextOverlay]

    public init(
        text: String? = nil,
        metadata: [String: String] = [:],
        overlays: [TextOverlay] = []
    ) {
        self.text = text
        self.metadata = metadata
        self.overlays = overlays
    }
}

/// A detected text region in the image.
public struct TextOverlay: Codable, Sendable {
    /// Extracted text content.
    public var text: String

    /// Bounding box: [y_min, x_min, y_max, x_max] normalised to 0-1000.
    public var boundingBox: [Int]?

    /// Overlay type: "gps", "timestamp", "address", "label", "other".
    public var overlayType: String?

    public init(text: String = "", boundingBox: [Int]? = nil, overlayType: String? = nil) {
        self.text = text
        self.boundingBox = boundingBox
        self.overlayType = overlayType
    }

    enum CodingKeys: String, CodingKey {
        case text
        case boundingBox = "bounding_box"
        case overlayType = "type"
    }
}

// MARK: - Client Extension

extension QuantumClient {
    /// Full combined vision analysis (scene + objects + quality + OCR + relevance).
    public func visionAnalyze(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/vision/analyze", body: request
        )
        return data
    }

    /// Object detection with bounding boxes.
    public func visionDetect(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/vision/detect", body: request
        )
        return data
    }

    /// Scene description and tags.
    public func visionDescribe(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/vision/describe", body: request
        )
        return data
    }

    /// Text extraction and overlay metadata (OCR).
    public func visionOCR(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/vision/ocr", body: request
        )
        return data
    }

    /// Image quality assessment.
    public func visionQuality(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/vision/quality", body: request
        )
        return data
    }
}
