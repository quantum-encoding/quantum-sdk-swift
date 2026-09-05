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

    /// Target polygon count (100-300,000). Omitted when unset; Meshy applies
    /// its own default.
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
///
/// One of `textStylePrompt` and `imageStyleUrl` is required; the job fails
/// otherwise.
public struct RetextureRequest: Codable, Sendable {
    /// ID of a completed 3D task to retexture.
    public var inputTaskId: String?

    /// Direct URL to a 3D model file.
    public var modelUrl: String?

    /// Text prompt describing the desired texture.
    public var textStylePrompt: String?

    /// URL of a reference image whose style the texture follows.
    public var imageStyleUrl: String?

    /// Meshy AI model to use. Omitted when unset; Meshy applies its own
    /// default.
    public var aiModel: String?

    /// Keep the model's existing UV layout.
    public var enableOriginalUv: Bool?

    /// Enable PBR texture maps (metallic, roughness, normal).
    public var enablePbr: Bool?

    /// Strip baked lighting from the generated texture.
    public var removeLighting: Bool?

    /// Output formats: "glb", "fbx", "obj", "usdz", "stl", "blend".
    public var targetFormats: [String]?

    public init(
        inputTaskId: String? = nil,
        modelUrl: String? = nil,
        textStylePrompt: String? = nil,
        imageStyleUrl: String? = nil,
        aiModel: String? = nil,
        enableOriginalUv: Bool? = nil,
        enablePbr: Bool? = nil,
        removeLighting: Bool? = nil,
        targetFormats: [String]? = nil
    ) {
        self.inputTaskId = inputTaskId
        self.modelUrl = modelUrl
        self.textStylePrompt = textStylePrompt
        self.imageStyleUrl = imageStyleUrl
        self.aiModel = aiModel
        self.enableOriginalUv = enableOriginalUv
        self.enablePbr = enablePbr
        self.removeLighting = removeLighting
        self.targetFormats = targetFormats
    }

    enum CodingKeys: String, CodingKey {
        case inputTaskId = "input_task_id"
        case modelUrl = "model_url"
        case textStylePrompt = "text_style_prompt"
        case imageStyleUrl = "image_style_url"
        case aiModel = "ai_model"
        case enableOriginalUv = "enable_original_uv"
        case enablePbr = "enable_pbr"
        case removeLighting = "remove_lighting"
        case targetFormats = "target_formats"
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

    /// URL of a texture image to apply to the rigged character.
    public var textureImageUrl: String?

    public init(inputTaskId: String? = nil, modelUrl: String? = nil, heightMeters: Double? = nil, textureImageUrl: String? = nil) {
        self.inputTaskId = inputTaskId
        self.modelUrl = modelUrl
        self.heightMeters = heightMeters
        self.textureImageUrl = textureImageUrl
    }

    enum CodingKeys: String, CodingKey {
        case inputTaskId = "input_task_id"
        case modelUrl = "model_url"
        case heightMeters = "height_meters"
        case textureImageUrl = "texture_image_url"
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

/// Backwards-compatible alias for ``AnimationPostProcess``.
public typealias PostProcess = AnimationPostProcess

// MARK: - Rig output

/// URLs for the walk and run cycles Meshy bakes into every rigging result.
/// There are no idle animations; use ``QuantumClient/animate(_:)`` for
/// anything else.
public struct BasicAnimations: Codable, Sendable {
    /// Walking animation in GLB format.
    public var walkingGlbUrl: String?

    /// Walking animation in FBX format.
    public var walkingFbxUrl: String?

    /// Walking animation as an armature-only GLB.
    public var walkingArmatureGlbUrl: String?

    /// Running animation in GLB format.
    public var runningGlbUrl: String?

    /// Running animation in FBX format.
    public var runningFbxUrl: String?

    /// Running animation as an armature-only GLB.
    public var runningArmatureGlbUrl: String?

    enum CodingKeys: String, CodingKey {
        case walkingGlbUrl = "walking_glb_url"
        case walkingFbxUrl = "walking_fbx_url"
        case walkingArmatureGlbUrl = "walking_armature_glb_url"
        case runningGlbUrl = "running_glb_url"
        case runningFbxUrl = "running_fbx_url"
        case runningArmatureGlbUrl = "running_armature_glb_url"
    }
}

/// The rigging output of a completed job. The job's `result` is an envelope
/// (`result`, `task_id`, `cost_ticks`, `request_id`); this is its `result`
/// member.
public struct RigOutput: Codable, Sendable {
    /// The rigged character in FBX format.
    public var riggedCharacterFbxUrl: String?

    /// The rigged character in GLB format.
    public var riggedCharacterGlbUrl: String?

    /// Walk and run cycles, when Meshy produced them.
    public var basicAnimations: BasicAnimations?

    enum CodingKeys: String, CodingKey {
        case riggedCharacterFbxUrl = "rigged_character_fbx_url"
        case riggedCharacterGlbUrl = "rigged_character_glb_url"
        case basicAnimations = "basic_animations"
    }

    /// Decodes the rigging output from a finished job. `nil` when the job
    /// carries no `result` (it failed or is still running).
    public static func from(job: JobStatusResponse) throws -> RigOutput? {
        guard let envelope = job.result?.value as? [String: Any],
              let output = envelope["result"],
              !(output is NSNull)
        else { return nil }
        let data = try JSONSerialization.data(withJSONObject: output)
        return try JSONDecoder().decode(RigOutput.self, from: data)
    }
}
