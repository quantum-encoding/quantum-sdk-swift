import Foundation

// MARK: - Document Extract

/// Request body for the `/qai/v1/documents/extract` endpoint.
public struct DocumentRequest: Codable, Sendable {
    /// Document content (base64 or URL).
    public var content: String

    /// Content type (e.g. "pdf", "image", "url").
    public var type: String?

    /// Model for extraction.
    public var model: String?

    public init(content: String, type: String? = nil, model: String? = nil) {
        self.content = content
        self.type = type
        self.model = model
    }
}

/// Response from the `/qai/v1/documents/extract` endpoint.
public struct DocumentResponse: Codable, Sendable {
    /// Extracted text.
    public var text: String

    /// Number of pages (if applicable).
    public var pages: Int?

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case text, pages
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Document Chunk

/// Request body for the `/qai/v1/documents/chunk` endpoint.
public struct ChunkDocumentRequest: Codable, Sendable {
    /// Text to chunk.
    public var text: String

    /// Target chunk size in tokens.
    public var chunkSize: Int?

    public init(text: String, chunkSize: Int? = nil) {
        self.text = text
        self.chunkSize = chunkSize
    }

    enum CodingKeys: String, CodingKey {
        case text
        case chunkSize = "chunk_size"
    }
}

/// A single document chunk.
public struct DocumentChunk: Codable, Sendable {
    /// Chunk text.
    public var text: String

    /// Chunk index.
    public var index: Int

    /// Token count.
    public var tokens: Int
}

/// Response from the `/qai/v1/documents/chunk` endpoint.
public struct ChunkDocumentResponse: Codable, Sendable {
    /// Document chunks.
    public var chunks: [DocumentChunk]

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case chunks
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Document Process

/// Request body for the `/qai/v1/documents/process` endpoint.
public struct ProcessDocumentRequest: Codable, Sendable {
    /// Text to process.
    public var text: String

    /// Processing instructions.
    public var instructions: String?

    /// Model for processing.
    public var model: String?

    public init(text: String, instructions: String? = nil, model: String? = nil) {
        self.text = text
        self.instructions = instructions
        self.model = model
    }
}

/// Response from the `/qai/v1/documents/process` endpoint.
public struct ProcessDocumentResponse: Codable, Sendable {
    /// Processed result.
    public var result: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case result
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}
