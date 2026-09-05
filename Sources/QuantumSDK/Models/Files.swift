import Foundation

// Multimodal file uploads.
//
// `POST /qai/v1/files` proxies a single file to Gemini's Files API and returns
// a `fileUri` that can be attached to a subsequent chat request as a
// `file_uri` part, pinned by a context cache (`cacheCreate`), or used to open
// a media session (`mediaSessionCreate`).
//
// The gateway holds the provider credential, caps the body at 100 MiB, and
// enforces a MIME allowlist: PNG / JPEG / WebP / HEIC / HEIF images, MP4 /
// WebM / QuickTime video, MPEG / WAV / OGG / FLAC audio, and PDF.

/// Response from `POST /qai/v1/files`.
public struct FileUploadResponse: Codable, Sendable {
    /// The provider resource URI to attach to later calls.
    public var fileUri: String

    /// Provider resource name (`files/<id>`).
    public var name: String

    /// MIME type as recorded by the provider.
    public var mimeType: String

    /// Size of the stored file in bytes.
    public var sizeBytes: Int64

    /// Duration in seconds for video uploads; zero for images, audio, and PDFs.
    public var durationSeconds: Int64

    /// RFC3339 expiry, when the provider reported one. Files are transient —
    /// re-upload after expiry.
    public var expiresAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case fileUri = "file_uri"
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case durationSeconds = "duration_seconds"
        case expiresAt = "expires_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileUri = try c.decodeIfPresent(String.self, forKey: .fileUri) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? ""
        sizeBytes = try c.decodeIfPresent(Int64.self, forKey: .sizeBytes) ?? 0
        durationSeconds = try c.decodeIfPresent(Int64.self, forKey: .durationSeconds) ?? 0
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt) ?? ""
    }
}
