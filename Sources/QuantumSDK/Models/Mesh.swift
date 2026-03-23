import Foundation

// MARK: - Remesh

/// Request for a 3D remesh operation.
public struct RemeshRequest: Codable, Sendable {
    /// ID of a completed 3D generation task (from Meshy).
    public var inputTaskId: String?

    /// Direct URL to a 3D model file (alternative to inputTaskId).
    public var modelUrl: String?

    /// Output formats: "glb", "fbx", "obj", "usdz", "stl", "blend".
    public var targetFormats: [String]?

    /// Mesh topology: "quad" or "triangle".
    public var topology: String?

    /// Target polygon count (100-300,000). Default: 30000.
    public var targetPolycount: Int?

    /// Resize height in meters (0 = no resize).
    public var resizeHeight: Double?

    /// Origin placement: "bottom", "center", or "" (no change).
    public var originAt: String?

    /// If true, skip remeshing and only convert formats.
    public var convertFormatOnly: Bool?

    public init(
        inputTaskId: String? = nil,
        modelUrl: String? = nil,
        targetFormats: [String]? = nil,
        topology: String? = nil,
        targetPolycount: Int? = nil,
        resizeHeight: Double? = nil,
        originAt: String? = nil,
        convertFormatOnly: Bool? = nil
    ) {
        self.inputTaskId = inputTaskId
        self.modelUrl = modelUrl
        self.targetFormats = targetFormats
        self.topology = topology
        self.targetPolycount = targetPolycount
        self.resizeHeight = resizeHeight
        self.originAt = originAt
        self.convertFormatOnly = convertFormatOnly
    }

    enum CodingKeys: String, CodingKey {
        case topology
        case inputTaskId = "input_task_id"
        case modelUrl = "model_url"
        case targetFormats = "target_formats"
        case targetPolycount = "target_polycount"
        case resizeHeight = "resize_height"
        case originAt = "origin_at"
        case convertFormatOnly = "convert_format_only"
    }
}

// MARK: - Model URLs

/// URLs for each exported format in a remesh result.
public struct ModelUrls: Codable, Sendable {
    public var glb: String?
    public var fbx: String?
    public var obj: String?
    public var usdz: String?
    public var stl: String?
    public var blend: String?

    public init(glb: String? = nil, fbx: String? = nil, obj: String? = nil, usdz: String? = nil, stl: String? = nil, blend: String? = nil) {
        self.glb = glb
        self.fbx = fbx
        self.obj = obj
        self.usdz = usdz
        self.stl = stl
        self.blend = blend
    }
}

// MARK: - Retexture

/// Request for AI retexturing of an existing 3D model.
public struct RetextureRequest: Codable, Sendable {
    /// ID of a completed 3D task to retexture.
    public var inputTaskId: String?

    /// Direct URL to a 3D model file.
    public var modelUrl: String?

    /// Text prompt describing the desired texture.
    public var prompt: String

    /// Enable PBR texture maps (metallic, roughness, normal).
    public var enablePbr: Bool?

    /// Meshy AI model to use (default: "meshy-6").
    public var aiModel: String?

    public init(prompt: String, inputTaskId: String? = nil, modelUrl: String? = nil, enablePbr: Bool? = nil, aiModel: String? = nil) {
        self.prompt = prompt
        self.inputTaskId = inputTaskId
        self.modelUrl = modelUrl
        self.enablePbr = enablePbr
        self.aiModel = aiModel
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case inputTaskId = "input_task_id"
        case modelUrl = "model_url"
        case enablePbr = "enable_pbr"
        case aiModel = "ai_model"
    }
}

// MARK: - Rig

/// Request for auto-rigging a humanoid 3D model.
public struct RigRequest: Codable, Sendable {
    /// ID of a completed 3D task.
    public var inputTaskId: String?

    /// Direct URL to a 3D model file.
    public var modelUrl: String?

    /// Height of the character in meters (for skeleton scaling).
    public var heightMeters: Double?

    public init(inputTaskId: String? = nil, modelUrl: String? = nil, heightMeters: Double? = nil) {
        self.inputTaskId = inputTaskId
        self.modelUrl = modelUrl
        self.heightMeters = heightMeters
    }

    enum CodingKeys: String, CodingKey {
        case inputTaskId = "input_task_id"
        case modelUrl = "model_url"
        case heightMeters = "height_meters"
    }
}

// MARK: - Animate

/// Request for applying an animation to a rigged character.
public struct AnimateRequest: Codable, Sendable {
    /// ID of a completed rigging task.
    public var rigTaskId: String

    /// Animation action ID from Meshy's animation library.
    public var actionId: Int

    /// Optional post-processing (e.g. FPS conversion, format conversion).
    public var postProcess: AnimationPostProcess?

    public init(rigTaskId: String, actionId: Int, postProcess: AnimationPostProcess? = nil) {
        self.rigTaskId = rigTaskId
        self.actionId = actionId
        self.postProcess = postProcess
    }

    enum CodingKeys: String, CodingKey {
        case rigTaskId = "rig_task_id"
        case actionId = "action_id"
        case postProcess = "post_process"
    }
}

/// Post-processing options for animation export.
public struct AnimationPostProcess: Codable, Sendable {
    /// Operation: "change_fps", "fbx2usdz", "extract_armature".
    public var operationType: String

    /// Target FPS (for "change_fps"): 24, 25, 30, 60.
    public var fps: Int?

    public init(operationType: String, fps: Int? = nil) {
        self.operationType = operationType
        self.fps = fps
    }

    enum CodingKeys: String, CodingKey {
        case fps
        case operationType = "operation_type"
    }
}
