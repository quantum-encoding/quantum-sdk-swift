import Foundation

// MARK: - Document Extract

/// Request body for document extraction.
public struct DocumentRequest: Codable, Sendable {
    /// Base64-encoded file content.
    public var fileBase64: String

    /// Original filename (helps determine the file type).
    public var filename: String

    /// Desired output format (e.g. "markdown", "text").
    public var outputFormat: String?

    public init(fileBase64: String, filename: String, outputFormat: String? = nil) {
        self.fileBase64 = fileBase64
        self.filename = filename
        self.outputFormat = outputFormat
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case fileBase64 = "file_base64"
        case outputFormat = "output_format"
    }
}

/// Response from document extraction.
public struct DocumentResponse: Codable, Sendable {
    /// Extracted text content.
    public var content: String

    /// Format of the extracted content (e.g. "markdown").
    public var format: String?

    /// Provider-specific metadata about the document.
    public var meta: [String: AnyCodable]?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case content, format, meta
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

// MARK: - Document Chunk

/// Request body for document chunking.
public struct ChunkRequest: Codable, Sendable {
    /// Base64-encoded file content.
    public var fileBase64: String

    /// Original filename.
    public var filename: String

    /// Maximum chunk size in tokens.
    public var maxChunkTokens: Int?

    /// Overlap between chunks in tokens.
    public var overlapTokens: Int?

    public init(fileBase64: String, filename: String, maxChunkTokens: Int? = nil, overlapTokens: Int? = nil) {
        self.fileBase64 = fileBase64
        self.filename = filename
        self.maxChunkTokens = maxChunkTokens
        self.overlapTokens = overlapTokens
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case fileBase64 = "file_base64"
        case maxChunkTokens = "max_chunk_tokens"
        case overlapTokens = "overlap_tokens"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias ChunkDocumentRequest = ChunkRequest

/// A single document chunk.
public struct DocumentChunk: Codable, Sendable {
    /// Chunk index.
    public var index: Int

    /// Chunk text content.
    public var text: String

    /// Estimated token count.
    public var tokenCount: Int?

    enum CodingKeys: String, CodingKey {
        case index, text
        case tokenCount = "token_count"
    }
}

/// Response from document chunking.
public struct ChunkResponse: Codable, Sendable {
    /// Document chunks.
    public var chunks: [DocumentChunk]

    /// Total number of chunks.
    public var totalChunks: Int?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case chunks
        case totalChunks = "total_chunks"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias ChunkDocumentResponse = ChunkResponse

// MARK: - Document Process

/// Request body for document processing (combined extraction + analysis).
public struct ProcessRequest: Codable, Sendable {
    /// Base64-encoded file content.
    public var fileBase64: String

    /// Original filename.
    public var filename: String

    /// Processing instructions or prompt.
    public var prompt: String?

    /// Model to use for processing.
    public var model: String?

    public init(fileBase64: String, filename: String, prompt: String? = nil, model: String? = nil) {
        self.fileBase64 = fileBase64
        self.filename = filename
        self.prompt = prompt
        self.model = model
    }

    enum CodingKeys: String, CodingKey {
        case filename, prompt, model
        case fileBase64 = "file_base64"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias ProcessDocumentRequest = ProcessRequest

/// Response from document processing.
public struct ProcessResponse: Codable, Sendable {
    /// Processed content / analysis result.
    public var content: String

    /// Model used for processing.
    public var model: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case content, model
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// Parity alias matching Rust SDK naming.
public typealias ProcessDocumentResponse = ProcessResponse
