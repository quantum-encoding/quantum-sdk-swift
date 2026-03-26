import Foundation

// MARK: - Voice

/// A voice available for TTS.
public struct Voice: Codable, Sendable {
    /// Voice identifier.
    public var voiceId: String

    /// Human-readable voice name.
    public var name: String

    /// Provider (e.g. "elevenlabs", "openai").
    public var provider: String?

    /// Language/locale codes supported.
    public var languages: [String]?

    /// Voice gender.
    public var gender: String?

    /// Whether this is a cloned voice.
    public var isCloned: Bool?

    /// Preview audio URL.
    public var previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, provider, languages, gender
        case voiceId = "voice_id"
        case isCloned = "is_cloned"
        case previewUrl = "preview_url"
    }
}

/// Legacy alias.
public typealias VoiceInfo = Voice

/// Response from listing voices.
public struct VoicesResponse: Codable, Sendable {
    /// Available voices.
    public var voices: [Voice]
}

// MARK: - Clone Voice

/// A file to include in a voice clone request.
public struct CloneVoiceFile: Sendable {
    /// Original filename (e.g. "sample.mp3").
    public var filename: String

    /// Raw file bytes.
    public var data: Data

    /// MIME type (e.g. "audio/mpeg").
    public var mimeType: String

    public init(filename: String, data: Data, mimeType: String) {
        self.filename = filename
        self.data = data
        self.mimeType = mimeType
    }
}

/// Response from cloning a voice.
public struct CloneVoiceResponse: Codable, Sendable {
    /// The new voice identifier.
    public var voiceId: String

    /// The name assigned to the cloned voice.
    public var name: String

    /// Status message.
    public var status: String?

    enum CodingKeys: String, CodingKey {
        case name, status
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
    public var clonedByCount: Int64?

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

/// Response from browsing the voice library.
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
public struct VoiceLibraryQuery: Codable, Sendable {
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

    enum CodingKeys: String, CodingKey {
        case query, cursor, gender, language
        case pageSize = "page_size"
        case useCase = "use_case"
    }
}

/// Request body for adding a voice from the library.
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

/// Response from adding a voice from the library.
public struct AddVoiceFromLibraryResponse: Codable, Sendable {
    /// ID of the added voice.
    public var voiceId: String

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
    }
}

// MARK: - Clone Voice Request

/// Request body for instant voice cloning from audio samples (JSON path).
public struct CloneVoiceRequest: Codable, Sendable {
    /// Display name for the cloned voice.
    public var name: String

    /// Description of the voice.
    public var description: String?

    /// Base64-encoded audio files for cloning.
    public var audioSamples: [String]

    public init(name: String, description: String? = nil, audioSamples: [String]) {
        self.name = name
        self.description = description
        self.audioSamples = audioSamples
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case audioSamples = "audio_samples"
    }
}
