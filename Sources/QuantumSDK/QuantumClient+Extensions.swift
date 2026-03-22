import Foundation

// MARK: - Missing Parity Methods

extension QuantumClient {

    /// Submit a chat completion as an async job.
    ///
    /// Useful for long-running models (e.g. Opus) where synchronous
    /// `/qai/v1/chat` may time out. Use `streamJob()` or `pollJob()` to get the result.
    ///
    /// ```swift
    /// let job = try await client.chatJob(ChatRequest(
    ///     model: "claude-opus-4-6",
    ///     messages: [.user("Summarize all of Wikipedia")]
    /// ))
    /// for try await event in client.streamJob(jobId: job.jobId) {
    ///     print(event.type, event.status ?? "")
    /// }
    /// ```
    public func chatJob(_ request: ChatRequest) async throws -> JobCreateResponse {
        // Encode the ChatRequest to JSON, then decode as [String: AnyCodable] for the job params.
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        return try await createJob(type: "chat", params: params)
    }

    /// Query compute billing from BigQuery via the QAI backend.
    ///
    /// - Parameter request: Billing query filters (instance ID, date range).
    /// - Returns: Billing entries and total cost.
    public func computeBilling(_ request: BillingRequest) async throws -> BillingResponse {
        let (data, _): (BillingResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/compute/billing", body: request
        )
        return data
    }
}

// MARK: - 3D Mesh Operations

public struct RemeshRequest: Codable, Sendable {
    public var inputTaskId: String?
    public var modelUrl: String?
    public var targetFormats: [String]?
    public var topology: String?
    public var targetPolycount: Int?
    public var resizeHeight: Double?
    public var originAt: String?
    public var convertFormatOnly: Bool?

    enum CodingKeys: String, CodingKey {
        case inputTaskId = "input_task_id"
        case modelUrl = "model_url"
        case targetFormats = "target_formats"
        case topology
        case targetPolycount = "target_polycount"
        case resizeHeight = "resize_height"
        case originAt = "origin_at"
        case convertFormatOnly = "convert_format_only"
    }

    public init(inputTaskId: String? = nil, modelUrl: String? = nil, targetFormats: [String]? = nil,
                topology: String? = nil, targetPolycount: Int? = nil, resizeHeight: Double? = nil,
                originAt: String? = nil, convertFormatOnly: Bool? = nil) {
        self.inputTaskId = inputTaskId; self.modelUrl = modelUrl; self.targetFormats = targetFormats
        self.topology = topology; self.targetPolycount = targetPolycount; self.resizeHeight = resizeHeight
        self.originAt = originAt; self.convertFormatOnly = convertFormatOnly
    }
}

public struct RigRequest: Codable, Sendable {
    public var inputTaskId: String?
    public var modelUrl: String?
    public var heightMeters: Double?
    public var textureImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case inputTaskId = "input_task_id"
        case modelUrl = "model_url"
        case heightMeters = "height_meters"
        case textureImageUrl = "texture_image_url"
    }

    public init(inputTaskId: String? = nil, modelUrl: String? = nil,
                heightMeters: Double? = nil, textureImageUrl: String? = nil) {
        self.inputTaskId = inputTaskId; self.modelUrl = modelUrl
        self.heightMeters = heightMeters; self.textureImageUrl = textureImageUrl
    }
}

public struct AnimateRequest: Codable, Sendable {
    public var rigTaskId: String
    public var actionId: Int
    public var postProcess: PostProcessOptions?

    public struct PostProcessOptions: Codable, Sendable {
        public var operationType: String
        public var fps: Int?
        enum CodingKeys: String, CodingKey { case operationType = "operation_type"; case fps }
        public init(operationType: String, fps: Int? = nil) { self.operationType = operationType; self.fps = fps }
    }

    enum CodingKeys: String, CodingKey { case rigTaskId = "rig_task_id"; case actionId = "action_id"; case postProcess = "post_process" }

    public init(rigTaskId: String, actionId: Int, postProcess: PostProcessOptions? = nil) {
        self.rigTaskId = rigTaskId; self.actionId = actionId; self.postProcess = postProcess
    }
}

extension QuantumClient {
    /// Remesh a 3D model. Submits job and polls to completion.
    public func remesh(_ request: RemeshRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/remesh", params: params)
        return try await pollJob(jobId: job.jobId, intervalMs: 5000, maxAttempts: 120)
    }

    /// Rig a humanoid 3D model. Returns rigged character + basic walk/run animations.
    public func rig(_ request: RigRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/rig", params: params)
        return try await pollJob(jobId: job.jobId, intervalMs: 5000, maxAttempts: 120)
    }

    /// Apply an animation to a rigged character.
    public func animate(_ request: AnimateRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/animate", params: params)
        return try await pollJob(jobId: job.jobId, intervalMs: 5000, maxAttempts: 120)
    }
}

// MARK: - Retexture

public struct RetextureRequest: Codable, Sendable {
    public var inputTaskId: String?
    public var modelUrl: String?
    public var textStylePrompt: String?
    public var imageStyleUrl: String?
    public var aiModel: String?
    public var enableOriginalUv: Bool?
    public var enablePbr: Bool?
    public var removeLighting: Bool?
    public var targetFormats: [String]?

    enum CodingKeys: String, CodingKey {
        case inputTaskId = "input_task_id"; case modelUrl = "model_url"
        case textStylePrompt = "text_style_prompt"; case imageStyleUrl = "image_style_url"
        case aiModel = "ai_model"; case enableOriginalUv = "enable_original_uv"
        case enablePbr = "enable_pbr"; case removeLighting = "remove_lighting"
        case targetFormats = "target_formats"
    }

    public init(inputTaskId: String? = nil, modelUrl: String? = nil,
                textStylePrompt: String? = nil, imageStyleUrl: String? = nil,
                aiModel: String? = nil, enableOriginalUv: Bool? = nil,
                enablePbr: Bool? = nil, removeLighting: Bool? = nil,
                targetFormats: [String]? = nil) {
        self.inputTaskId = inputTaskId; self.modelUrl = modelUrl
        self.textStylePrompt = textStylePrompt; self.imageStyleUrl = imageStyleUrl
        self.aiModel = aiModel; self.enableOriginalUv = enableOriginalUv
        self.enablePbr = enablePbr; self.removeLighting = removeLighting
        self.targetFormats = targetFormats
    }
}

extension QuantumClient {
    /// Retexture a 3D model with AI-generated textures from text or image.
    public func retexture(_ request: RetextureRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/retexture", params: params)
        return try await pollJob(jobId: job.jobId, intervalMs: 5000, maxAttempts: 120)
    }
}
