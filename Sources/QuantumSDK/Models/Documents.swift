import Foundation

// Document extraction and chunking.
//
// The gateway extracts PDF and DOCX in-process and bills mechanical compute
// at $0.001 per MB; there is no OCR, so a scanned PDF with no text layer
// answers 422 `extraction_failed`. Uploads are multipart (field `file`),
// capped at 50 MB.

// MARK: - Document Extract

/// A document upload for extraction.
public struct DocumentRequest: Sendable {
    /// Raw file bytes.
    public var content: Data

    /// Filename, used with `mimeType` to pick the extractor.
    public var filename: String

    /// MIME type of the file (e.g. `application/pdf`). Sniffed from the
    /// filename when omitted.
    public var mimeType: String?

    /// Also return the images embedded in a PDF, base64-encoded.
    public var extractImages: Bool

    public init(content: Data, filename: String, mimeType: String? = nil, extractImages: Bool = false) {
        self.content = content
        self.filename = filename
        self.mimeType = mimeType
        self.extractImages = extractImages
    }
}

/// An image pulled out of a PDF.
public struct DocumentImage: Codable, Sendable {
    /// Image name within the document.
    public var name: String

    /// MIME type of the encoded image.
    public var mime: String

    /// Base64 of the complete encoded image file.
    public var data: String
}

/// How the document was processed.
public struct DocumentMeta: Codable, Sendable {
    /// Extractor that handled the file (e.g. `pdf`, `docx`).
    public var extractionMethod: String

    /// Images found in the document (present when images were requested).
    public var imagesFound: Int

    /// Number of chunks produced (chunk and process routes).
    public var chunkCount: Int

    public init(extractionMethod: String = "", imagesFound: Int = 0, chunkCount: Int = 0) {
        self.extractionMethod = extractionMethod
        self.imagesFound = imagesFound
        self.chunkCount = chunkCount
    }

    enum CodingKeys: String, CodingKey {
        case extractionMethod = "extraction_method"
        case imagesFound = "images_found"
        case chunkCount = "chunk_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        extractionMethod = try c.decodeIfPresent(String.self, forKey: .extractionMethod) ?? ""
        imagesFound = try c.decodeIfPresent(Int.self, forKey: .imagesFound) ?? 0
        chunkCount = try c.decodeIfPresent(Int.self, forKey: .chunkCount) ?? 0
    }
}

/// Response from document extraction.
public struct DocumentResponse: Codable, Sendable {
    /// Extracted text as Markdown.
    public var markdown: String

    /// Output format (`markdown`).
    public var format: String

    /// Extraction metadata.
    public var meta: DocumentMeta

    /// Embedded images, when `extractImages` was set.
    @NullToEmpty public var images: [DocumentImage]

    /// Total cost in ticks (filled from the response headers when the body
    /// omits it).
    public var costTicks: Int64

    /// Unique request identifier (filled from the response headers when the
    /// body omits it).
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case markdown, format, meta, images
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        markdown = try c.decode(String.self, forKey: .markdown)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        meta = try c.decodeIfPresent(DocumentMeta.self, forKey: .meta) ?? DocumentMeta()
        _images = try c.decode(NullToEmpty<DocumentImage>.self, forKey: .images)
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

// MARK: - Document Chunk

/// A document upload for chunking.
public struct ChunkDocumentRequest: Sendable {
    /// Raw file bytes.
    public var content: Data

    /// Filename, used with `mimeType` to pick the extractor.
    public var filename: String

    /// MIME type of the file. Sniffed from the filename when omitted.
    public var mimeType: String?

    /// Chunk size in characters (gateway default 2000).
    public var chunkSize: Int?

    /// Overlap between consecutive chunks in characters (gateway default 200).
    public var overlap: Int?

    public init(content: Data, filename: String, mimeType: String? = nil, chunkSize: Int? = nil, overlap: Int? = nil) {
        self.content = content
        self.filename = filename
        self.mimeType = mimeType
        self.chunkSize = chunkSize
        self.overlap = overlap
    }
}

/// Backwards-compatible alias.
public typealias ChunkRequest = ChunkDocumentRequest

/// A single document chunk.
public struct DocumentChunk: Codable, Sendable {
    /// Chunk index.
    public var index: Int

    /// Chunk text content.
    public var text: String
}

/// Response from document chunking.
public struct ChunkDocumentResponse: Codable, Sendable {
    /// Output format (`markdown`).
    public var format: String

    /// Extraction metadata; `chunkCount` is the length of `chunks`.
    public var meta: DocumentMeta

    /// Document chunks.
    @NullToEmpty public var chunks: [DocumentChunk]

    /// Total cost in ticks (filled from the response headers when the body
    /// omits it).
    public var costTicks: Int64

    /// Unique request identifier (filled from the response headers when the
    /// body omits it).
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case format, meta, chunks
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        meta = try c.decodeIfPresent(DocumentMeta.self, forKey: .meta) ?? DocumentMeta()
        _chunks = try c.decode(NullToEmpty<DocumentChunk>.self, forKey: .chunks)
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

/// Backwards-compatible alias.
public typealias ChunkResponse = ChunkDocumentResponse

// MARK: - Document Process

/// A document upload for the full pipeline: extraction, chunking and
/// optional image extraction in one call. No model is involved.
public struct ProcessDocumentRequest: Sendable {
    /// Raw file bytes.
    public var content: Data

    /// Filename, used with `mimeType` to pick the extractor.
    public var filename: String

    /// MIME type of the file. Sniffed from the filename when omitted.
    public var mimeType: String?

    /// Also return the images embedded in a PDF, base64-encoded.
    public var extractImages: Bool

    /// Chunk size in characters (gateway default 2000).
    public var chunkSize: Int?

    /// Overlap between consecutive chunks in characters (gateway default 200).
    public var overlap: Int?

    public init(
        content: Data,
        filename: String,
        mimeType: String? = nil,
        extractImages: Bool = false,
        chunkSize: Int? = nil,
        overlap: Int? = nil
    ) {
        self.content = content
        self.filename = filename
        self.mimeType = mimeType
        self.extractImages = extractImages
        self.chunkSize = chunkSize
        self.overlap = overlap
    }
}

/// Backwards-compatible alias.
public typealias ProcessRequest = ProcessDocumentRequest

/// Response from the document pipeline.
public struct ProcessDocumentResponse: Codable, Sendable {
    /// Extracted text as Markdown.
    public var markdown: String

    /// Output format (`markdown`).
    public var format: String

    /// Extraction metadata.
    public var meta: DocumentMeta

    /// Document chunks.
    @NullToEmpty public var chunks: [DocumentChunk]

    /// Embedded images, when `extractImages` was set.
    @NullToEmpty public var images: [DocumentImage]

    /// Total cost in ticks (filled from the response headers when the body
    /// omits it).
    public var costTicks: Int64

    /// Unique request identifier (filled from the response headers when the
    /// body omits it).
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case markdown, format, meta, chunks, images
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        markdown = try c.decode(String.self, forKey: .markdown)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        meta = try c.decodeIfPresent(DocumentMeta.self, forKey: .meta) ?? DocumentMeta()
        _chunks = try c.decode(NullToEmpty<DocumentChunk>.self, forKey: .chunks)
        _images = try c.decode(NullToEmpty<DocumentImage>.self, forKey: .images)
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }
}

/// Backwards-compatible alias.
public typealias ProcessResponse = ProcessDocumentResponse

/// The plain form fields the document routes read beside the `file` part.
/// Kept as a function so the encode tests can assert the exact keys.
func documentFormFields(extractImages: Bool, chunkSize: Int?, overlap: Int?) -> [String: String] {
    var fields: [String: String] = [:]
    if extractImages { fields["extract_images"] = "true" }
    if let chunkSize { fields["chunk_size"] = String(chunkSize) }
    if let overlap { fields["overlap"] = String(overlap) }
    return fields
}
