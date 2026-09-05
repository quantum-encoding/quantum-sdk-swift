import Foundation

// MARK: - Vision Request

/// Request body for vision analysis endpoints.
public struct VisionRequest: Codable, Sendable {
    /// Base64-encoded image (with or without data: prefix). The reliable
    /// input: the bytes reach the model as an image part on every gateway
    /// version.
    public var imageBase64: String?

    /// Image URL. Current gateways fetch it server-side through an
    /// SSRF-guarded client and send the bytes to the model (400 when the
    /// fetch fails); the provider never sees the URL. Gateways older than the
    /// September 2026 vision fix pasted the URL into the prompt as text.
    /// Prefer `imageBase64` unless you know the gateway you talk to.
    public var imageURL: String?

    /// Model to use. Default: gemini-2.5-flash.
    public var model: String?

    /// Analysis profile: "combined" (default), "scene", "objects", "ocr",
    /// "quality". Overrides the default profile of whichever `vision*`
    /// method sends it.
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

/// Full vision analysis response. Every section is `omitempty` on the wire
/// and each profile's prompt only fills its own sections, so a `describe`
/// answer has no `objects`, an `ocr` answer has neither, and so on; absent
/// lists decode to `[]`, absent sections to `nil`.
public struct VisionResponse: Codable, Sendable {
    /// Scene description.
    public var caption: String?

    /// Suggested tags (lowercase_snake_case).
    @NullToEmpty public var tags: [String]

    /// Detected objects with bounding boxes.
    @NullToEmpty public var objects: [DetectedObject]

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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        _tags = try c.decode(NullToEmpty<String>.self, forKey: .tags)
        _objects = try c.decode(NullToEmpty<DetectedObject>.self, forKey: .objects)
        quality = try c.decodeIfPresent(QualityAssessment.self, forKey: .quality)
        relevance = try c.decodeIfPresent(RelevanceCheck.self, forKey: .relevance)
        ocr = try c.decodeIfPresent(OCRResult.self, forKey: .ocr)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        boundingBox = try c.decodeIfPresent([Int].self, forKey: .boundingBox) ?? []
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

    /// Specific issues found (empty when the model reported none).
    @NullToEmpty public var issues: [String]

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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        overall = try c.decodeIfPresent(String.self, forKey: .overall) ?? ""
        score = try c.decodeIfPresent(Double.self, forKey: .score) ?? 0
        blur = try c.decodeIfPresent(String.self, forKey: .blur) ?? ""
        darkness = try c.decodeIfPresent(String.self, forKey: .darkness) ?? ""
        resolution = try c.decodeIfPresent(String.self, forKey: .resolution) ?? ""
        exposure = try c.decodeIfPresent(String.self, forKey: .exposure) ?? ""
        _issues = try c.decode(NullToEmpty<String>.self, forKey: .issues)
    }
}

/// Relevance check against expected content.
public struct RelevanceCheck: Codable, Sendable {
    /// Whether the image is relevant to the context.
    public var relevant: Bool

    /// Relevance score (0.0 - 1.0).
    public var score: Double

    /// Items expected based on context.
    @NullToEmpty public var expectedItems: [String]

    /// Items actually found in the image.
    @NullToEmpty public var foundItems: [String]

    /// Expected but not found.
    @NullToEmpty public var missingItems: [String]

    /// Found but not expected.
    @NullToEmpty public var unexpectedItems: [String]

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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relevant = try c.decodeIfPresent(Bool.self, forKey: .relevant) ?? false
        score = try c.decodeIfPresent(Double.self, forKey: .score) ?? 0
        _expectedItems = try c.decode(NullToEmpty<String>.self, forKey: .expectedItems)
        _foundItems = try c.decode(NullToEmpty<String>.self, forKey: .foundItems)
        _missingItems = try c.decode(NullToEmpty<String>.self, forKey: .missingItems)
        _unexpectedItems = try c.decode(NullToEmpty<String>.self, forKey: .unexpectedItems)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}

/// OCR / text extraction result.
public struct OCRResult: Codable, Sendable {
    /// All extracted text concatenated.
    public var text: String?

    /// Extracted metadata (GPS, timestamp, address, etc.).
    public var metadata: [String: String]

    /// Individual text overlays with positions.
    @NullToEmpty public var overlays: [TextOverlay]

    public init(
        text: String? = nil,
        metadata: [String: String] = [:],
        overlays: [TextOverlay] = []
    ) {
        self.text = text
        self.metadata = metadata
        self.overlays = overlays
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        metadata = try c.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        _overlays = try c.decode(NullToEmpty<TextOverlay>.self, forKey: .overlays)
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        boundingBox = try c.decodeIfPresent([Int].self, forKey: .boundingBox)
        overlayType = try c.decodeIfPresent(String.self, forKey: .overlayType)
    }
}

// MARK: - Client Extension

// Each `vision*` method only sets the default profile for its route; a
// `profile` in the request overrides it, so `visionDetect` with
// `profile: "ocr"` runs OCR. Leave `profile` unset to get the analysis the
// method name promises.
extension QuantumClient {
    /// Full combined vision analysis (scene + objects + quality + OCR + relevance).
    public func visionAnalyze(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/vision/analyze", body: request
        )
        return data
    }

    /// Object detection with bounding boxes (default profile "objects"; a
    /// request `profile` overrides it).
    public func visionDetect(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/vision/detect", body: request
        )
        return data
    }

    /// Scene description and tags (default profile "scene"; a request
    /// `profile` overrides it).
    public func visionDescribe(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/vision/describe", body: request
        )
        return data
    }

    /// Text extraction and overlay metadata (default profile "ocr"; a
    /// request `profile` overrides it).
    public func visionOCR(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/vision/ocr", body: request
        )
        return data
    }

    /// Image quality assessment (default profile "quality"; a request
    /// `profile` overrides it).
    public func visionQuality(_ request: VisionRequest) async throws -> VisionResponse {
        let (data, _): (VisionResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/vision/quality", body: request
        )
        return data
    }
}
