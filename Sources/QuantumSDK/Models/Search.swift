import Foundation

// MARK: - Web Search

/// Request body for the `/qai/v1/search/web` endpoint (Brave).
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

    /// Safe search level: "off", "moderate", "strict".
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

    /// Builds a request from a query plus a reusable ``SearchOptions`` set.
    public init(query: String, options: SearchOptions) {
        self.init(
            query: query,
            count: options.count,
            offset: options.offset,
            country: options.country,
            language: options.language,
            freshness: options.freshness,
            safesearch: options.safesearch
        )
    }
}

/// How Brave understood the query.
public struct QueryInfo: Codable, Sendable {
    /// The query as submitted.
    public var original: String

    /// The query after spell correction, when it was altered.
    public var altered: String?

    /// Detected query language.
    public var language: String?

    /// True when spellcheck was disabled for the request.
    public var spellcheckOff: Bool

    enum CodingKeys: String, CodingKey {
        case original, altered, language
        case spellcheckOff = "spellcheck_off"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        original = try c.decodeIfPresent(String.self, forKey: .original) ?? ""
        altered = try c.decodeIfPresent(String.self, forKey: .altered)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        spellcheckOff = try c.decodeIfPresent(Bool.self, forKey: .spellcheckOff) ?? false
    }
}

/// Parsed parts of a result URL.
public struct MetaUrl: Codable, Sendable {
    public var scheme: String
    public var netloc: String
    public var hostname: String

    /// Favicon URL for the result's site.
    public var favicon: String?

    public var path: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try c.decodeIfPresent(String.self, forKey: .scheme) ?? ""
        netloc = try c.decodeIfPresent(String.self, forKey: .netloc) ?? ""
        hostname = try c.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        favicon = try c.decodeIfPresent(String.self, forKey: .favicon)
        path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
    }
}

/// A thumbnail image.
public struct Thumbnail: Codable, Sendable {
    /// Image URL.
    public var src: String
    public var height: Int
    public var width: Int

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        src = try c.decodeIfPresent(String.self, forKey: .src) ?? ""
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? 0
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? 0
    }
}

/// A single web search result.
public struct WebResult: Codable, Sendable {
    /// Page title.
    public var title: String

    /// Page URL.
    public var url: String

    /// Result description / snippet.
    public var description: String

    /// Further snippets from the page.
    @NullToEmpty public var extraSnippets: [String]

    /// Age of the result (e.g. "2 hours ago").
    public var age: String?

    /// Page language.
    public var language: String?

    /// Parsed URL parts, including the site favicon.
    public var metaUrl: MetaUrl?

    /// Page thumbnail.
    public var thumbnail: Thumbnail?

    /// Favicon URL for the result's site, when Brave supplied one
    /// (`metaUrl.favicon`; there is no top-level favicon on the wire).
    public var favicon: String? { metaUrl?.favicon }

    enum CodingKeys: String, CodingKey {
        case title, url, description, age, language, thumbnail
        case extraSnippets = "extra_snippets"
        case metaUrl = "meta_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        _extraSnippets = try c.decode(NullToEmpty<String>.self, forKey: .extraSnippets)
        age = try c.decodeIfPresent(String.self, forKey: .age)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        metaUrl = try c.decodeIfPresent(MetaUrl.self, forKey: .metaUrl)
        thumbnail = try c.decodeIfPresent(Thumbnail.self, forKey: .thumbnail)
    }
}

/// A news search result.
public struct NewsResult: Codable, Sendable {
    /// Article title.
    public var title: String

    /// Article URL.
    public var url: String

    /// Short description.
    public var description: String

    /// Age of the article.
    public var age: String?

    /// Publisher name.
    public var source: String?

    /// Article thumbnail.
    public var thumbnail: Thumbnail?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(String.self, forKey: .url)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        age = try c.decodeIfPresent(String.self, forKey: .age)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        thumbnail = try c.decodeIfPresent(Thumbnail.self, forKey: .thumbnail)
    }
}

/// A video search result.
public struct VideoResult: Codable, Sendable {
    /// Video title.
    public var title: String

    /// Video page URL.
    public var url: String

    /// Short description.
    public var description: String

    /// Video thumbnail.
    public var thumbnail: Thumbnail?

    /// Age of the video.
    public var age: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(String.self, forKey: .url)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        thumbnail = try c.decodeIfPresent(Thumbnail.self, forKey: .thumbnail)
        age = try c.decodeIfPresent(String.self, forKey: .age)
    }
}

/// An infobox (knowledge panel) result.
public struct Infobox: Codable, Sendable {
    /// Infobox title.
    public var title: String

    /// Short description.
    public var description: String

    /// Long description.
    public var longDesc: String?

    /// Source URL.
    public var url: String?

    /// Infobox kind (e.g. "generic", "entity"). Wire field: `type`.
    public var kind: String?

    /// Images attached to the panel.
    @NullToEmpty public var images: [Thumbnail]

    enum CodingKeys: String, CodingKey {
        case title, description, url, images
        case longDesc = "long_desc"
        case kind = "type"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        longDesc = try c.decodeIfPresent(String.self, forKey: .longDesc)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        _images = try c.decode(NullToEmpty<Thumbnail>.self, forKey: .images)
    }
}

/// Backwards-compatible alias.
public typealias InfoboxResult = Infobox

/// A discussion / forum result.
public struct Discussion: Codable, Sendable {
    /// Discussion title.
    public var title: String

    /// Discussion URL.
    public var url: String

    /// Short description.
    public var description: String

    /// Age of the discussion.
    public var age: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(String.self, forKey: .url)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        age = try c.decodeIfPresent(String.self, forKey: .age)
    }
}

/// Backwards-compatible alias.
public typealias DiscussionResult = Discussion

/// A Brave result family: `{"results": [...]}` on the wire (or `null`, or
/// absent), flattened to its list.
@propertyWrapper
public struct BraveResults<Element: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [Element]

    public init(wrappedValue: [Element] = []) {
        self.wrappedValue = wrappedValue
    }

    private struct Family: Codable {
        @NullToEmpty var results: [Element]
    }

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        wrappedValue = single.decodeNil() ? [] : try single.decode(Family.self).results
    }

    public func encode(to encoder: Encoder) throws {
        try Family(results: NullToEmpty(wrappedValue: wrappedValue)).encode(to: encoder)
    }
}

extension KeyedDecodingContainer {
    /// A missing family decodes to an empty list.
    public func decode<E>(_ type: BraveResults<E>.Type, forKey key: Key) throws -> BraveResults<E> {
        try decodeIfPresent(type, forKey: key) ?? BraveResults()
    }
}

/// Response from the web search endpoint: Brave's own envelope, relayed
/// unchanged. Each result family arrives as `{"results": [...]}` and is
/// flattened to its list here.
public struct WebSearchResponse: Codable, Sendable {
    /// How Brave understood the query.
    public var query: QueryInfo?

    /// Web search results.
    @BraveResults public var web: [WebResult]

    /// News results.
    @BraveResults public var news: [NewsResult]

    /// Video results.
    @BraveResults public var videos: [VideoResult]

    /// Knowledge panel, when Brave produced one.
    public var infobox: Infobox?

    /// Discussion / forum results.
    @BraveResults public var discussions: [Discussion]
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

    /// Freshness filter ("pd", "pw", "pm").
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

    /// Builds a request from a query plus a reusable ``ContextOptions`` set.
    public init(query: String, options: ContextOptions) {
        self.init(
            query: query,
            count: options.count,
            country: options.country,
            language: options.language,
            freshness: options.freshness
        )
    }
}

/// A content chunk from search context.
public struct SearchContextChunk: Codable, Sendable {
    /// Extracted page content.
    public var content: String

    /// Source URL.
    public var url: String

    /// Page title.
    public var title: String

    /// Relevance score.
    public var score: Double

    /// Content type (e.g. "text/html").
    public var contentType: String?

    enum CodingKeys: String, CodingKey {
        case content, url, title, score
        case contentType = "content_type"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode(String.self, forKey: .content)
        url = try c.decode(String.self, forKey: .url)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        score = try c.decodeIfPresent(Double.self, forKey: .score) ?? 0
        contentType = try c.decodeIfPresent(String.self, forKey: .contentType)
    }
}

/// A source reference from search context.
public struct SearchContextSource: Codable, Sendable {
    /// Source URL.
    public var url: String

    /// Source title.
    public var title: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decode(String.self, forKey: .url)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    }
}

/// Response from the search context endpoint.
public struct SearchContextResponse: Codable, Sendable {
    /// Content chunks extracted from search results.
    @NullToEmpty public var chunks: [SearchContextChunk]

    /// Source references.
    @NullToEmpty public var sources: [SearchContextSource]

    /// The query, as echoed by Brave.
    public var query: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _chunks = try c.decode(NullToEmpty<SearchContextChunk>.self, forKey: .chunks)
        _sources = try c.decode(NullToEmpty<SearchContextSource>.self, forKey: .sources)
        query = try c.decodeIfPresent(String.self, forKey: .query) ?? ""
    }
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
    public var title: String

    /// Snippet from the source.
    public var snippet: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decode(String.self, forKey: .url)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        snippet = try c.decodeIfPresent(String.self, forKey: .snippet)
    }
}

/// A choice in the search answer response.
public struct SearchAnswerChoice: Codable, Sendable {
    /// Choice index.
    public var index: Int

    /// The generated message, absent when the choice carries none.
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
    @NullToEmpty public var choices: [SearchAnswerChoice]

    /// Model that produced the answer.
    public var model: String

    /// Unique response identifier.
    public var id: String

    /// Citations used in the answer.
    @NullToEmpty public var citations: [SearchAnswerCitation]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _choices = try c.decode(NullToEmpty<SearchAnswerChoice>.self, forKey: .choices)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        _citations = try c.decode(NullToEmpty<SearchAnswerCitation>.self, forKey: .citations)
    }
}

// MARK: - Google Grounded Search (Gemini + google_search tool)

/// Request body for Google grounded search via Gemini.
///
/// The premium search backend: Google's index rather than Brave's, billed
/// per executed query at $0.035 each. The model decides how many queries one
/// prompt becomes; `webSearchQueries` on the response lists them.
public struct GoogleSearchRequest: Codable, Sendable {
    /// Search query. Free-form natural language; the model translates it
    /// into one or more concrete Google searches.
    public var query: String

    public init(query: String) {
        self.query = query
    }
}

/// A web source returned by Google grounding.
public struct GoogleSearchCitation: Codable, Sendable {
    /// Source URL (may be a Google redirect link the user can follow).
    public var url: String

    /// Source title from the search result.
    public var title: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decode(String.self, forKey: .url)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    }
}

/// Links a span of the answer text to one or more citation indices,
/// enabling inline-citation rendering.
public struct GoogleSearchSupport: Codable, Sendable {
    /// Byte offset where this span starts in the answer text.
    public var startIndex: Int

    /// Byte offset where this span ends (exclusive).
    public var endIndex: Int

    /// The text of the span, so a renderer can match by content when the
    /// answer has been transformed and the byte offsets no longer apply.
    public var text: String

    /// Indices into `citations` for the sources backing this span.
    @NullToEmpty public var groundingChunkIndices: [Int]

    enum CodingKeys: String, CodingKey {
        case text
        case startIndex = "start_index"
        case endIndex = "end_index"
        case groundingChunkIndices = "grounding_chunk_indices"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startIndex = try c.decode(Int.self, forKey: .startIndex)
        endIndex = try c.decode(Int.self, forKey: .endIndex)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        _groundingChunkIndices = try c.decode(NullToEmpty<Int>.self, forKey: .groundingChunkIndices)
    }
}

/// Response from the Google grounded search endpoint.
public struct GoogleSearchResponse: Codable, Sendable {
    /// The grounded answer text Gemini produced. May be empty if the
    /// model decided no answer was warranted.
    public var answer: String

    /// Web sources Gemini grounded its answer on.
    @NullToEmpty public var citations: [GoogleSearchCitation]

    /// HTML/CSS widget of search-suggestion chips. Google's grounding terms
    /// require it to be rendered, unmodified, alongside any grounded response.
    public var searchEntryPoint: String

    /// The queries Gemini executed against Google Search; each one is a
    /// billing unit.
    @NullToEmpty public var webSearchQueries: [String]

    /// Inline-citation spans linking text segments to citations.
    @NullToEmpty public var supports: [GoogleSearchSupport]

    enum CodingKeys: String, CodingKey {
        case answer, citations, supports
        case searchEntryPoint = "search_entry_point"
        case webSearchQueries = "web_search_queries"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        answer = try c.decodeIfPresent(String.self, forKey: .answer) ?? ""
        _citations = try c.decode(NullToEmpty<GoogleSearchCitation>.self, forKey: .citations)
        searchEntryPoint = try c.decodeIfPresent(String.self, forKey: .searchEntryPoint) ?? ""
        _webSearchQueries = try c.decode(NullToEmpty<String>.self, forKey: .webSearchQueries)
        _supports = try c.decode(NullToEmpty<GoogleSearchSupport>.self, forKey: .supports)
    }
}

// MARK: - Aliases & Options

/// Backwards-compatible alias for ``SearchContextChunk``.
public typealias ContextChunk = SearchContextChunk

/// Backwards-compatible alias for ``SearchAnswerMessage``.
public typealias SearchMessage = SearchAnswerMessage

/// Backwards-compatible alias: the context route has one response shape.
public typealias LLMContextResponse = SearchContextResponse

/// Reusable filter set for web search requests; apply with
/// ``WebSearchRequest/init(query:options:)``. Keys and vocabularies match
/// the route (`freshness` is "pd" / "pw" / "pm", the safe-search key is
/// `safesearch`).
public struct SearchOptions: Codable, Sendable {
    /// Number of results to return.
    public var count: Int?

    /// Zero-based result offset for pagination.
    public var offset: Int?

    /// Country code filter (e.g. "US", "GB").
    public var country: String?

    /// Language code filter (e.g. "en", "fr").
    public var language: String?

    /// Freshness filter: "pd" (past day), "pw" (past week), "pm" (past month).
    public var freshness: String?

    /// Safe search level: "off", "moderate", "strict".
    public var safesearch: String?

    public init(
        count: Int? = nil,
        offset: Int? = nil,
        country: String? = nil,
        language: String? = nil,
        freshness: String? = nil,
        safesearch: String? = nil
    ) {
        self.count = count
        self.offset = offset
        self.country = country
        self.language = language
        self.freshness = freshness
        self.safesearch = safesearch
    }
}

/// Reusable filter set for context search requests; apply with
/// ``SearchContextRequest/init(query:options:)``.
public struct ContextOptions: Codable, Sendable {
    /// Number of context chunks to return.
    public var count: Int?

    /// Country code filter.
    public var country: String?

    /// Language code filter.
    public var language: String?

    /// Freshness filter: "pd" (past day), "pw" (past week), "pm" (past month).
    public var freshness: String?

    public init(
        count: Int? = nil,
        country: String? = nil,
        language: String? = nil,
        freshness: String? = nil
    ) {
        self.count = count
        self.country = country
        self.language = language
        self.freshness = freshness
    }
}
