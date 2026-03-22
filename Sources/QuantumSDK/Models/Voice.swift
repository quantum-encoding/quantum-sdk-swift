import Foundation

// MARK: - Voice Info

/// Information about a voice.
public struct VoiceInfo: Codable, Sendable {
    /// Voice ID.
    public var voiceId: String

    /// Voice name.
    public var name: String

    /// Provider (e.g. "elevenlabs").
    public var provider: String

    /// Preview audio URL.
    public var previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, provider
        case voiceId = "voice_id"
        case previewUrl = "preview_url"
    }
}

/// Response from the `/qai/v1/voices` endpoint.
public struct VoicesResponse: Codable, Sendable {
    /// Available voices.
    public var voices: [VoiceInfo]
}

// MARK: - Clone Voice

/// Request body for the `/qai/v1/voices/clone` endpoint.
public struct CloneVoiceRequest: Codable, Sendable {
    /// Name for the cloned voice.
    public var name: String

    /// Base64-encoded audio samples.
    public var audioSamples: [String]

    /// Description of the voice.
    public var description: String?

    public init(name: String, audioSamples: [String], description: String? = nil) {
        self.name = name
        self.audioSamples = audioSamples
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case audioSamples = "audio_samples"
    }
}

/// Response from the `/qai/v1/voices/clone` endpoint.
public struct CloneVoiceResponse: Codable, Sendable {
    /// ID of the cloned voice.
    public var voiceId: String

    /// Name of the cloned voice.
    public var name: String

    enum CodingKeys: String, CodingKey {
        case name
        case voiceId = "voice_id"
    }
}

// MARK: - Voice Library

/// A shared voice from the community library.
public struct SharedVoice: Codable, Sendable {
    /// Public owner ID.
    public var publicOwnerId: String

    /// Voice ID.
    public var voiceId: String

    /// Voice name.
    public var name: String

    /// Category.
    public var category: String?

    /// Description.
    public var description: String?

    /// Preview audio URL.
    public var previewUrl: String?

    /// Gender.
    public var gender: String?

    /// Age range.
    public var age: String?

    /// Accent.
    public var accent: String?

    /// Language.
    public var language: String?

    /// Use case.
    public var useCase: String?

    /// Rating.
    public var rate: Double?

    /// Number of clones.
    public var clonedByCount: Int?

    /// Whether free users can use this voice.
    public var freeUsersAllowed: Bool?

    enum CodingKeys: String, CodingKey {
        case name, category, description, gender, age, accent, language, rate
        case publicOwnerId = "public_owner_id"
        case voiceId = "voice_id"
        case previewUrl = "preview_url"
        case useCase = "use_case"
        case clonedByCount = "cloned_by_count"
        case freeUsersAllowed = "free_users_allowed"
    }
}

/// Response from the `/qai/v1/voices/library` endpoint.
public struct SharedVoicesResponse: Codable, Sendable {
    /// Shared voices.
    public var voices: [SharedVoice]

    /// Cursor for pagination.
    public var nextCursor: String?

    /// Whether more results are available.
    public var hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case voices
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Query parameters for browsing the voice library.
public struct VoiceLibraryQuery: Sendable {
    /// Search query.
    public var query: String?

    /// Page size.
    public var pageSize: Int?

    /// Pagination cursor.
    public var cursor: String?

    /// Filter by gender.
    public var gender: String?

    /// Filter by language.
    public var language: String?

    /// Filter by use case.
    public var useCase: String?

    public init(
        query: String? = nil,
        pageSize: Int? = nil,
        cursor: String? = nil,
        gender: String? = nil,
        language: String? = nil,
        useCase: String? = nil
    ) {
        self.query = query
        self.pageSize = pageSize
        self.cursor = cursor
        self.gender = gender
        self.language = language
        self.useCase = useCase
    }
}

/// Request body for the `/qai/v1/voices/library/add` endpoint.
public struct AddVoiceFromLibraryRequest: Codable, Sendable {
    /// Public owner ID.
    public var publicOwnerId: String

    /// Voice ID.
    public var voiceId: String

    /// Custom name for the voice.
    public var name: String?

    public init(publicOwnerId: String, voiceId: String, name: String? = nil) {
        self.publicOwnerId = publicOwnerId
        self.voiceId = voiceId
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case name
        case publicOwnerId = "public_owner_id"
        case voiceId = "voice_id"
    }
}

/// Response from the `/qai/v1/voices/library/add` endpoint.
public struct AddVoiceFromLibraryResponse: Codable, Sendable {
    /// ID of the added voice.
    public var voiceId: String

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
    }
}
