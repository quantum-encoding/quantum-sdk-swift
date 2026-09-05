import Foundation

// Media sessions, multimodal file uploads and Gemini context caches.
extension QuantumClient {
    // MARK: - Media Sessions

    /// Create a media session: pins a file, builds a context cache over it,
    /// and returns the session record.
    ///
    /// `POST /qai/v1/media-sessions`
    public func mediaSessionCreate(_ request: MediaSessionCreateRequest) async throws -> MediaSession {
        let (data, _): (MediaSession, _) = try await doReq(
            method: "POST", path: "/qai/v1/media-sessions", body: request
        )
        return data
    }

    /// List the caller's media sessions, most recently used first, at most
    /// fifty.
    ///
    /// `GET /qai/v1/media-sessions`
    public func mediaSessionList() async throws -> MediaSessionListResponse {
        let (data, _): (MediaSessionListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/media-sessions"
        )
        return data
    }

    /// Read one media session's state, including its conversation history.
    ///
    /// `GET /qai/v1/media-sessions/{id}`
    public func mediaSessionGet(id: String) async throws -> MediaSession {
        let (data, _): (MediaSession, _) = try await doReq(
            method: "GET", path: "/qai/v1/media-sessions/\(Self.pathSegment(id))"
        )
        return data
    }

    /// Send the next user turn to a media session and return the answer.
    ///
    /// `POST /qai/v1/media-sessions/{id}/chat`
    public func mediaSessionChat(id: String, _ request: MediaSessionChatRequest) async throws -> MediaSessionChatResponse {
        let (data, _): (MediaSessionChatResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/media-sessions/\(Self.pathSegment(id))/chat", body: request
        )
        return data
    }

    /// Delete a media session; its context cache is released on a
    /// best-effort basis. Idempotent.
    ///
    /// `DELETE /qai/v1/media-sessions/{id}`
    public func mediaSessionDelete(id: String) async throws -> MediaSessionDeleteResponse {
        let (data, _): (MediaSessionDeleteResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/media-sessions/\(Self.pathSegment(id))"
        )
        return data
    }

    // MARK: - Files

    /// Upload one file for multimodal use and return its `fileUri`.
    ///
    /// `mimeType` must be in the gateway's allowlist (see ``FileUploadResponse``);
    /// the upload is rejected at intake otherwise.
    ///
    /// `POST /qai/v1/files` (multipart, field `file`)
    public func fileUpload(filename: String, mimeType: String, content: Data) async throws -> FileUploadResponse {
        let (data, _): (FileUploadResponse, HTTPClient.ResponseMeta) = try await doMultipartReq(
            path: "/qai/v1/files",
            fieldName: "file",
            filename: filename,
            data: content,
            contentType: mimeType
        )
        return data
    }

    // MARK: - Caches

    /// Create a context cache over an uploaded file.
    ///
    /// `POST /qai/v1/caches`
    public func cacheCreate(_ request: CacheCreateRequest) async throws -> CacheCreateResponse {
        let (data, _): (CacheCreateResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/caches", body: request
        )
        return data
    }

    /// Release a context cache early rather than waiting for its TTL.
    ///
    /// `cacheName` may be the full `cachedContents/<id>` resource name or just
    /// the `<id>` suffix; the gateway normalises both.
    ///
    /// `DELETE /qai/v1/caches/{name}`
    public func cacheDelete(cacheName: String) async throws -> CacheDeleteResponse {
        let (data, _): (CacheDeleteResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/caches/\(cacheName)"
        )
        return data
    }

    /// Percent-encodes one path segment.
    static func pathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
