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

/// A single web search result.
public struct WebResult: Codable, Sendable {
    /// Page title.
    public var title: String

    /// Page URL.
    public var url: String

    /// Result description / snippet.
    public var description: String?

    /// Age of the result (e.g. "2 hours ago").
    public var age: String?

    /// Favicon URL.
    public var favicon: String?
}

/// A news search result.
public struct NewsResult: Codable, Sendable {
    /// Article title.
    public var title: String

    /// Article URL.
    public var url: String

    /// Short description.
    public var description: String?

    /// Age of the article.
    public var age: String?

    /// Publisher name.
    public var source: String?
}

/// A video search result.
public struct VideoResult: Codable, Sendable {
    /// Video title.
    public var title: String

    /// Video page URL.
    public var url: String

    /// Short description.
    public var description: String?

    /// Thumbnail URL.
    public var thumbnail: String?

    /// Age of the video.
    public var age: String?
}

/// An infobox (knowledge panel) result.
public struct InfoboxResult: Codable, Sendable {
    /// Infobox title.
    public var title: String

    /// Long description.
    public var description: String?

    /// Source URL.
    public var url: String?
}

/// Parity alias matching Rust SDK naming.
public typealias Infobox = InfoboxResult

/// A discussion / forum result.
public struct DiscussionResult: Codable, Sendable {
    /// Discussion title.
    public var title: String

    /// Discussion URL.
    public var url: String

    /// Short description.
    public var description: String?

    /// Age of the discussion.
    public var age: String?

    /// Forum name.
    public var forum: String?
}

/// Parity alias matching Rust SDK naming.
public typealias Discussion = DiscussionResult

/// Response from the web search endpoint.
public struct WebSearchResponse: Codable, Sendable {
    /// Original query.
    public var query: String?

    /// Web search results.
    public var web: [WebResult]?

    /// News results.
    public var news: [NewsResult]?

    /// Video results.
    public var videos: [VideoResult]?

    /// Infobox / knowledge panel entries.
    public var infobox: [InfoboxResult]?

    /// Discussion / forum results.
    public var discussions: [DiscussionResult]?
}

// MARK: - Search Context

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

/// A content chunk from search context.
public struct SearchContextChunk: Codable, Sendable {
    /// Extracted page content.
    public var content: String?

    /// Source URL.
    public var url: String?

    /// Page title.
    public var title: String?

    /// Relevance score.
    public var score: Double?

    /// Content type (e.g. "text/html").
    public var contentType: String?

    enum CodingKeys: String, CodingKey {
        case content, url, title, score
        case contentType = "content_type"
    }
}

/// A source reference from search context.
public struct SearchContextSource: Codable, Sendable {
    /// Source URL.
    public var url: String?

    /// Source title.
    public var title: String?
}

/// Response from the search context endpoint.
public struct SearchContextResponse: Codable, Sendable {
    /// Content chunks extracted from search results.
    public var chunks: [SearchContextChunk]?

    /// Source references.
    public var sources: [SearchContextSource]?

    /// Original query.
    public var query: String?
}

// MARK: - Search Answer

/// A chat message for the search answer endpoint.
public struct SearchAnswerMessage: Codable, Sendable {
    /// Message role ("user", "assistant", "system").
    public var role: String

    /// Message text content.
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Request body for search answer (AI-generated answer grounded in search).
public struct SearchAnswerRequest: Codable, Sendable {
    /// Conversation messages.
    public var messages: [SearchAnswerMessage]

    /// Model to use for answer generation.
    public var model: String?

    public init(messages: [SearchAnswerMessage], model: String? = nil) {
        self.messages = messages
        self.model = model
    }
}

/// A citation reference in a search answer.
public struct SearchAnswerCitation: Codable, Sendable {
    /// Source URL.
    public var url: String

    /// Source title.
    public var title: String?

    /// Snippet from the source.
    public var snippet: String?
}

/// A choice in the search answer response.
public struct SearchAnswerChoice: Codable, Sendable {
    /// Choice index.
    public var index: Int

    /// The generated message.
    public var message: SearchAnswerMessage?

    /// Finish reason (e.g. "stop").
    public var finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

/// Response from the search answer endpoint.
public struct SearchAnswerResponse: Codable, Sendable {
    /// Generated answer choices.
    public var choices: [SearchAnswerChoice]

    /// Model that produced the answer.
    public var model: String?

    /// Unique response identifier.
    public var id: String?

    /// Citations used in the answer.
    public var citations: [SearchAnswerCitation]?
}
