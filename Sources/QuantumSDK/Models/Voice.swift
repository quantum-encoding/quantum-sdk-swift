import Foundation

// MARK: - Voice

/// A voice available for TTS.
public struct Voice: Codable, Sendable {
    /// Voice identifier.
    public var voiceId: String

    /// Human-readable voice name.
    public var name: String

    /// Voice category (e.g. "premade", "cloned", "professional").
    public var category: String

    /// Provider (e.g. "elevenlabs", "openai", "gemini").
    public var provider: String?

    /// TTS model id to pass to `speak(...)` to synthesize with this voice — so
    /// callers don't hardcode the provider→model mapping. ElevenLabs carries the
    /// standard default; callers may override.
    public var model: String?

    /// Language/locale codes supported (not sent by the gateway today).
    public var languages: [String]?

    /// Voice gender (not sent by the gateway today).
    public var gender: String?

    /// Whether this is a cloned voice.
    public var isCloned: Bool?

    /// Voice description.
    public var description: String?

    /// Preview audio URL.
    public var previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, category, provider, model, languages, gender, description
        case voiceId = "voice_id"
        case isCloned = "is_cloned"
        case previewUrl = "preview_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        voiceId = try c.decode(String.self, forKey: .voiceId)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        provider = try c.decodeIfPresent(String.self, forKey: .provider)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        languages = try c.decodeIfPresent([String].self, forKey: .languages)
        gender = try c.decodeIfPresent(String.self, forKey: .gender)
        isCloned = try c.decodeIfPresent(Bool.self, forKey: .isCloned)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        previewUrl = try c.decodeIfPresent(String.self, forKey: .previewUrl)
    }
}

/// Legacy alias.
public typealias VoiceInfo = Voice

/// Response from listing voices.
public struct VoicesResponse: Codable, Sendable {
    /// Available voices: built-in catalogs first, then the live ElevenLabs
    /// library (omitted when that fetch fails).
    @NullToEmpty public var voices: [Voice]

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case voices
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _voices = try c.decode(NullToEmpty<Voice>.self, forKey: .voices)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

// MARK: - Clone Voice

/// Request body for instant voice cloning from audio samples.
public struct CloneVoiceRequest: Codable, Sendable {
    /// Display name for the cloned voice.
    public var name: String

    /// Description of the voice.
    public var description: String?

    /// Base64-encoded audio files for cloning (at least one).
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

/// Response from cloning a voice.
public struct CloneVoiceResponse: Codable, Sendable {
    /// The new voice identifier.
    public var voiceId: String

    /// The name assigned to the cloned voice (echo of the request).
    public var name: String

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case name
        case voiceId = "voice_id"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        voiceId = try c.decode(String.self, forKey: .voiceId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
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

    /// Category (e.g. "professional", "generated").
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

    /// Free-text descriptive tag.
    public var descriptive: String?

    /// Characters synthesised with this voice across the library.
    public var usageCharacterCount: Int64?

    /// Rating.
    public var rate: Double?

    /// Number of clones.
    public var clonedByCount: Int64?

    /// Whether free users can use this voice.
    public var freeUsersAllowed: Bool?

    /// Whether live moderation applies to this voice.
    public var liveModerationEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case name, category, description, gender, age, accent, language, rate, descriptive
        case publicOwnerId = "public_owner_id"
        case voiceId = "voice_id"
        case previewUrl = "preview_url"
        case useCase = "use_case"
        case usageCharacterCount = "usage_character_count"
        case clonedByCount = "cloned_by_count"
        case freeUsersAllowed = "free_users_allowed"
        case liveModerationEnabled = "live_moderation_enabled"
    }
}

/// Response from browsing the voice library.
public struct SharedVoicesResponse: Codable, Sendable {
    /// Shared voices matching the query.
    @NullToEmpty public var voices: [SharedVoice]

    /// Whether more results are available.
    public var hasMore: Bool

    /// Pagination cursor: pass as ``VoiceLibraryQuery/cursor`` to fetch the
    /// next page while `hasMore` is true.
    public var lastSortId: String?

    enum CodingKeys: String, CodingKey {
        case voices
        case hasMore = "has_more"
        case lastSortId = "last_sort_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _voices = try c.decode(NullToEmpty<SharedVoice>.self, forKey: .voices)
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        lastSortId = try c.decodeIfPresent(String.self, forKey: .lastSortId)
    }
}

/// Query parameters for browsing the voice library.
public struct VoiceLibraryQuery: Codable, Sendable {
    /// Search text. Wire param: `q`.
    public var query: String?

    /// Maximum number of results per page (gateway default 30).
    public var pageSize: Int?

    /// Pagination cursor: the previous response's `lastSortId`.
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
        case cursor, gender, language
        case query = "q"
        case pageSize = "page_size"
        case useCase = "use_case"
    }

    /// The route's query-string pairs, in wire order, values percent-encoded.
    var queryItems: [String] {
        var params: [String] = []
        if let q = query { params.append("q=\(Self.encode(q))") }
        if let ps = pageSize { params.append("page_size=\(ps)") }
        if let c = cursor { params.append("cursor=\(Self.encode(c))") }
        if let g = gender { params.append("gender=\(Self.encode(g))") }
        if let l = language { params.append("language=\(Self.encode(l))") }
        if let u = useCase { params.append("use_case=\(Self.encode(u))") }
        return params
    }

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
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

    /// Always "added".
    public var status: String

    enum CodingKeys: String, CodingKey {
        case status
        case voiceId = "voice_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        voiceId = try c.decode(String.self, forKey: .voiceId)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
    }
}

extension CharacterSet {
    /// Characters that may appear unescaped in a query-string *value*:
    /// unreserved characters only, so `&`, `=`, `+`, `?` and `/` inside a
    /// value are escaped rather than parsed as delimiters.
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
