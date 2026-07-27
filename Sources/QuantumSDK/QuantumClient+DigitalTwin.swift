// QuantumClient+DigitalTwin — HeyGen digital twins through the gateway:
// train a lifelike avatar from real footage of a person, collect the
// subject's consent via HeyGen's hosted page, then render videos of the
// trained twin from a script (HeyGen voice) or supplied narration audio
// (e.g. an ElevenLabs cloned-voice render).
//
// The consent step is not optional: HeyGen only finishes training after the
// person in the footage records the consent statement at the returned
// `consentUrl` (links expire after 24h — mint a fresh one with
// `digitalTwinConsentLink`).
//
// Copyright (c) 2025-2026 Quantum Encoding Ltd

import Foundation

// MARK: - Models

/// Response of digital-twin creation (`POST /qai/v1/video/digital-twin`).
public struct DigitalTwinCreateResponse: Codable, Sendable {
    /// Avatar group id — the twin's identity; poll status with it.
    public var groupId: String?
    /// Look id usable on twin-video once training completes.
    public var avatarId: String?
    public var name: String?
    /// "processing" | "pending_consent" | "failed" | "completed"
    public var status: String?
    public var consentStatus: String?
    /// Hosted consent-page URL (valid 24h) for the avatar's subject.
    public var consentUrl: String?
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case avatarId = "avatar_id"
        case name, status
        case consentStatus = "consent_status"
        case consentUrl = "consent_url"
        case requestId = "request_id"
    }
}

/// One trained (or in-training) twin in the account's private catalog.
public struct DigitalTwinSummary: Codable, Sendable, Identifiable {
    public var groupId: String
    public var name: String?
    public var status: String?
    public var consentStatus: String?
    public var previewImageUrl: String?
    public var looksCount: Int?
    public var defaultVoiceId: String?

    public var id: String { groupId }

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case name, status
        case consentStatus = "consent_status"
        case previewImageUrl = "preview_image_url"
        case looksCount = "looks_count"
        case defaultVoiceId = "default_voice_id"
    }
}

/// A concrete look of a twin group; `avatarId` is what twin-video renders.
public struct DigitalTwinLook: Codable, Sendable, Identifiable {
    public var avatarId: String
    public var name: String?
    public var status: String?
    public var previewImageUrl: String?
    /// Supported rendering engines ("avatar_iii" | "avatar_iv" | "avatar_v").
    public var engines: [String]?

    public var id: String { avatarId }

    enum CodingKeys: String, CodingKey {
        case avatarId = "avatar_id"
        case name, status, engines
        case previewImageUrl = "preview_image_url"
    }
}

/// Training/consent status of one twin group.
public struct DigitalTwinStatusResponse: Codable, Sendable {
    public var groupId: String
    public var name: String?
    public var status: String?
    public var consentStatus: String?
    public var looks: [DigitalTwinLook]?
    public var errorCode: String?
    public var errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case name, status, looks
        case consentStatus = "consent_status"
        case errorCode = "error_code"
        case errorMessage = "error_message"
    }
}

/// Response of a consent-link mint.
public struct DigitalTwinConsentLinkResponse: Codable, Sendable {
    public var consentUrl: String
    public var consentStatus: String?
    public var status: String?

    enum CodingKeys: String, CodingKey {
        case consentUrl = "consent_url"
        case consentStatus = "consent_status"
        case status
    }
}

/// Request body for `POST /qai/v1/video/twin-video`: a trained avatar look
/// delivering a script (HeyGen TTS) or supplied narration audio. Exactly one
/// of `script` (+ `voiceId`) or `audioBase64` is required.
public struct TwinVideoRequest: Codable, Sendable {
    public var avatarId: String
    public var script: String?
    /// HeyGen voice id — required with `script`.
    public var voiceId: String?
    /// Base64 narration audio (e.g. an ElevenLabs cloned-voice render).
    public var audioBase64: String?
    /// Media type of `audioBase64` (e.g. "audio/mpeg", "audio/wav").
    public var audioMediaType: String?
    /// "16:9" | "9:16" | "4:5" | "5:4" | "1:1" | "auto"
    public var aspectRatio: String?
    /// "720p" | "1080p" | "4k"
    public var resolution: String?
    public var title: String?
    /// Rendering engine override; leave nil for auto (Avatar V when the
    /// look supports it).
    public var engine: String?

    public init(
        avatarId: String,
        script: String? = nil,
        voiceId: String? = nil,
        audioBase64: String? = nil,
        audioMediaType: String? = nil,
        aspectRatio: String? = nil,
        resolution: String? = nil,
        title: String? = nil,
        engine: String? = nil
    ) {
        self.avatarId = avatarId
        self.script = script
        self.voiceId = voiceId
        self.audioBase64 = audioBase64
        self.audioMediaType = audioMediaType
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.title = title
        self.engine = engine
    }

    enum CodingKeys: String, CodingKey {
        case avatarId = "avatar_id"
        case script
        case voiceId = "voice_id"
        case audioBase64 = "audio_base64"
        case audioMediaType = "audio_media_type"
        case aspectRatio = "aspect_ratio"
        case resolution, title, engine
    }
}

private struct DigitalTwinListEnvelope: Codable {
    var groups: [DigitalTwinSummary]
}

private struct DigitalTwinURLCreateRequest: Codable {
    var name: String
    var videoUrl: String
    var avatarGroupId: String?
    enum CodingKeys: String, CodingKey {
        case name
        case videoUrl = "video_url"
        case avatarGroupId = "avatar_group_id"
    }
}

private struct ConsentLinkRequest: Codable {
    var rerouteUrl: String?
    enum CodingKeys: String, CodingKey { case rerouteUrl = "reroute_url" }
}

// MARK: - Client surface

extension QuantumClient {
    /// Create a digital twin by uploading training footage (15s–10min of the
    /// person speaking to camera, one clearly visible face, ≥720p). Returns
    /// the group id plus a hosted consent URL to send to the person in the
    /// footage — training completes only after they record consent there.
    /// Flat $5.00 charge.
    public func createDigitalTwin(
        name: String,
        footage: Data,
        filename: String = "training.mp4",
        contentType: String = "video/mp4",
        avatarGroupId: String? = nil
    ) async throws -> DigitalTwinCreateResponse {
        var fields = ["name": name]
        if let avatarGroupId { fields["avatar_group_id"] = avatarGroupId }
        let (data, _): (DigitalTwinCreateResponse, HTTPClient.ResponseMeta) = try await http.doMultipart(
            path: "/qai/v1/video/digital-twin",
            fieldName: "training",
            filename: filename,
            data: footage,
            contentType: contentType,
            fields: fields
        )
        return data
    }

    /// Create a digital twin from a publicly fetchable footage URL.
    public func createDigitalTwin(
        name: String,
        videoURL: String,
        avatarGroupId: String? = nil
    ) async throws -> DigitalTwinCreateResponse {
        let (data, _): (DigitalTwinCreateResponse, HTTPClient.ResponseMeta) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/digital-twin", body: DigitalTwinURLCreateRequest(name: name, videoUrl: videoURL, avatarGroupId: avatarGroupId), idempotencyKey: nil
        )
        return data
    }

    /// List the account's own twins ("My Twins").
    public func digitalTwins() async throws -> [DigitalTwinSummary] {
        let (data, _): (DigitalTwinListEnvelope, HTTPClient.ResponseMeta) = try await http.doJSON(
            method: "GET", path: "/qai/v1/video/digital-twins", body: nil as String?, idempotencyKey: nil
        )
        return data.groups
    }

    /// Training + consent status of one twin, including its renderable looks.
    public func digitalTwinStatus(groupId: String) async throws -> DigitalTwinStatusResponse {
        let (data, _): (DigitalTwinStatusResponse, HTTPClient.ResponseMeta) = try await http.doJSON(
            method: "GET",
            path: "/qai/v1/video/digital-twin/\(groupId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupId)",
            body: nil as String?, idempotencyKey: nil
        )
        return data
    }

    /// Mint a fresh hosted consent-page URL for a twin group (links expire
    /// after 24h). Send it to the person the avatar depicts.
    public func digitalTwinConsentLink(groupId: String, rerouteUrl: String? = nil) async throws -> DigitalTwinConsentLinkResponse {
        let (data, _): (DigitalTwinConsentLinkResponse, HTTPClient.ResponseMeta) = try await http.doJSON(
            method: "POST",
            path: "/qai/v1/video/digital-twin/\(groupId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupId)/consent-link",
            body: ConsentLinkRequest(rerouteUrl: rerouteUrl), idempotencyKey: nil
        )
        return data
    }

    /// Render a video of a trained twin delivering a script or narration
    /// audio. Async job — poll with the returned job id; billed per
    /// generated second. See ``TwinVideoRequest``.
    public func twinVideo(_ request: TwinVideoRequest) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, HTTPClient.ResponseMeta) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/twin-video", body: request,
            idempotencyKey: UUID().uuidString
        )
        return data
    }
}
