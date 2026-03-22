import Foundation

// MARK: - Web Search

/// Request body for the `/qai/v1/search/web` endpoint.
public struct WebSearchRequest: Codable, Sendable {
    /// Search query.
    public var query: String

    /// Number of results to return.
    public var count: Int?

    /// Offset for pagination.
    public var offset: Int?

    /// Country code (e.g. "US", "GB").
    public var country: String?

    /// Language code (e.g. "en", "fr").
    public var language: String?

    /// Freshness filter: "pd" (past day), "pw" (past week), "pm" (past month).
    public var freshness: String?

    /// Safe search level.
    public var safesearch: String?

    public init(
        query: String,
        count: Int? = nil,
        offset: Int? = nil,
        country: String? = nil,
        language: String? = nil,
        freshness: String? = nil,
        safesearch: String? = nil
    ) {
        self.query = query
        self.count = count
        self.offset = offset
        self.country = country
        self.language = language
        self.freshness = freshness
        self.safesearch = safesearch
    }
}

/// Response from the `/qai/v1/search/web` endpoint.
public struct WebSearchResponse: Codable, Sendable {
    /// Query information.
    public var query: SearchQueryInfo?

    /// Web search results.
    public var web: SearchWebResults?

    /// News results.
    public var news: SearchNewsResults?

    /// Video results.
    public var videos: SearchVideoResults?

    /// Infobox result.
    public var infobox: SearchInfobox?

    /// Discussion results.
    public var discussions: SearchDiscussionResults?
}

/// Information about the parsed query.
public struct SearchQueryInfo: Codable, Sendable {
    /// Original query string.
    public var original: String?

    /// Altered/corrected query.
    public var altered: String?

    /// Detected language.
    public var language: String?

    /// Whether spellcheck was disabled.
    public var spellcheckOff: Bool?

    enum CodingKeys: String, CodingKey {
        case original, altered, language
        case spellcheckOff = "spellcheck_off"
    }
}

/// Web search results container.
public struct SearchWebResults: Codable, Sendable {
    /// List of web results.
    public var results: [SearchWebResult]

    /// Whether results are family-friendly.
    public var familyFriendly: Bool?

    enum CodingKeys: String, CodingKey {
        case results
        case familyFriendly = "family_friendly"
    }
}

/// A single web search result.
public struct SearchWebResult: Codable, Sendable {
    /// Page title.
    public var title: String?

    /// Page URL.
    public var url: String?

    /// Short description/snippet.
    public var description: String?

    /// Additional text snippets.
    public var extraSnippets: [String]?

    /// Age of the result (e.g. "2 hours ago").
    public var age: String?

    /// Content language.
    public var language: String?

    /// Whether the result is family-friendly.
    public var familyFriendly: Bool?

    /// URL metadata.
    public var metaUrl: SearchMetaURL?

    /// Thumbnail image.
    public var thumbnail: SearchThumbnail?

    enum CodingKeys: String, CodingKey {
        case title, url, description, age, language, thumbnail
        case extraSnippets = "extra_snippets"
        case familyFriendly = "family_friendly"
        case metaUrl = "meta_url"
    }
}

/// URL metadata for a search result.
public struct SearchMetaURL: Codable, Sendable {
    public var scheme: String?
    public var netloc: String?
    public var hostname: String?
    public var favicon: String?
    public var path: String?
}

/// Thumbnail image metadata.
public struct SearchThumbnail: Codable, Sendable {
    public var src: String?
    public var height: Int?
    public var width: Int?
}

/// News search results container.
public struct SearchNewsResults: Codable, Sendable {
    public var results: [SearchNewsResult]
}

/// A single news result.
public struct SearchNewsResult: Codable, Sendable {
    public var title: String?
    public var url: String?
    public var description: String?
    public var age: String?
    public var source: String?
    public var thumbnail: SearchThumbnail?
}

/// Video search results container.
public struct SearchVideoResults: Codable, Sendable {
    public var results: [SearchVideoResult]
}

/// A single video result.
public struct SearchVideoResult: Codable, Sendable {
    public var title: String?
    public var url: String?
    public var description: String?
    public var age: String?
    public var thumbnail: SearchThumbnail?
}

/// An infobox (knowledge panel) result.
public struct SearchInfobox: Codable, Sendable {
    public var title: String?
    public var url: String?
    public var description: String?
    public var longDesc: String?
    public var type: String?
    public var images: [SearchThumbnail]?

    enum CodingKeys: String, CodingKey {
        case title, url, description, type, images
        case longDesc = "long_desc"
    }
}

/// Discussion/forum results container.
public struct SearchDiscussionResults: Codable, Sendable {
    public var results: [SearchDiscussionResult]
}

/// A single discussion/forum result.
public struct SearchDiscussionResult: Codable, Sendable {
    public var title: String?
    public var url: String?
    public var description: String?
    public var age: String?
}

// MARK: - Search Context (LLM Grounding)

/// Request body for the `/qai/v1/search/context` endpoint.
public struct SearchContextRequest: Codable, Sendable {
    /// Search query.
    public var query: String

    /// Number of content chunks to return.
    public var count: Int?

    /// Country code.
    public var country: String?

    /// Language code.
    public var language: String?

    /// Freshness filter.
    public var freshness: String?

    public init(
        query: String,
        count: Int? = nil,
        country: String? = nil,
        language: String? = nil,
        freshness: String? = nil
    ) {
        self.query = query
        self.count = count
        self.country = country
        self.language = language
        self.freshness = freshness
    }
}

/// Response from the `/qai/v1/search/context` endpoint.
public struct SearchContextResponse: Codable, Sendable {
    /// Extracted content chunks for LLM grounding.
    public var chunks: [SearchContentChunk]

    /// Source pages.
    public var sources: [SearchContextSource]?

    /// Original query.
    public var query: String?
}

/// A content chunk extracted for LLM context.
public struct SearchContentChunk: Codable, Sendable {
    /// Text content.
    public var content: String?

    /// Source URL.
    public var url: String?

    /// Source page title.
    public var title: String?

    /// Relevance score.
    public var score: Double?

    /// Content type.
    public var contentType: String?

    /// Chunk index.
    public var index: Int?

    enum CodingKeys: String, CodingKey {
        case content, url, title, score, index
        case contentType = "content_type"
    }
}

/// A source page for context results.
public struct SearchContextSource: Codable, Sendable {
    /// Source URL.
    public var url: String?

    /// Page title.
    public var title: String?

    /// Page description.
    public var description: String?

    /// Text snippet.
    public var snippet: String?
}

// MARK: - Search Answer

/// A message in a search answer conversation.
public struct SearchMessage: Codable, Sendable {
    /// Message role ("user" or "assistant").
    public var role: String

    /// Message content.
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }

    /// Create a user message.
    public static func user(_ content: String) -> SearchMessage {
        SearchMessage(role: "user", content: content)
    }

    /// Create an assistant message.
    public static func assistant(_ content: String) -> SearchMessage {
        SearchMessage(role: "assistant", content: content)
    }
}

/// Request body for the `/qai/v1/search/answer` endpoint.
public struct SearchAnswerRequest: Codable, Sendable {
    /// Conversation messages.
    public var messages: [SearchMessage]

    /// Model to use for answer generation.
    public var model: String?

    public init(messages: [SearchMessage], model: String? = nil) {
        self.messages = messages
        self.model = model
    }
}

/// Response from the `/qai/v1/search/answer` endpoint.
public struct SearchAnswerResponse: Codable, Sendable {
    /// Answer choices.
    public var choices: [SearchAnswerChoice]

    /// Model used for generation.
    public var model: String?

    /// Response ID.
    public var id: String?

    /// Citations supporting the answer.
    public var citations: [SearchCitation]?
}

/// A single answer choice.
public struct SearchAnswerChoice: Codable, Sendable {
    /// Choice index.
    public var index: Int

    /// The generated message.
    public var message: SearchMessage?

    /// Reason the generation finished.
    public var finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

/// A citation from a search answer.
public struct SearchCitation: Codable, Sendable {
    /// Source URL.
    public var url: String?

    /// Source title.
    public var title: String?

    /// Relevant snippet.
    public var snippet: String?
}
