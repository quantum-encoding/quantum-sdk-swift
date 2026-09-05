import Foundation

// MARK: - Chat Jobs

extension QuantumClient {

    /// Submit a chat completion as an async job.
    ///
    /// Useful for long-running models (e.g. Opus) where synchronous
    /// `/qai/v1/chat` may time out. Use `streamJob()` or `pollJob()` to get the result.
    ///
    /// ```swift
    /// let job = try await client.chatJob(ChatRequest(
    ///     model: "claude-opus-4-6",
    ///     messages: [.user("Summarize all of Wikipedia")]
    /// ))
    /// for try await event in client.streamJob(jobId: job.jobId) {
    ///     print(event.type, event.status ?? "")
    /// }
    /// ```
    public func chatJob(_ request: ChatRequest) async throws -> JobCreateResponse {
        // Encode the ChatRequest to JSON, then decode as [String: AnyCodable] for the job params.
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        return try await createJob(type: "chat", params: params)
    }
}

// MARK: - 3D Mesh Operations

extension QuantumClient {
    /// Remesh a 3D model. Submits job and polls to completion.
    public func remesh(_ request: RemeshRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/remesh", params: params)
        return try await pollJob(jobId: job.jobId, interval: 5.0, maxAttempts: 120)
    }

    /// Rig a humanoid 3D model. The job's `result` is a ``RigOutput``:
    /// rigged FBX/GLB URLs and the basic walk/run animations. Decode it with
    /// ``RigOutput/from(job:)``.
    public func rig(_ request: RigRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/rig", params: params)
        return try await pollJob(jobId: job.jobId, interval: 5.0, maxAttempts: 120)
    }

    /// Apply an animation to a rigged character.
    public func animate(_ request: AnimateRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/animate", params: params)
        return try await pollJob(jobId: job.jobId, interval: 5.0, maxAttempts: 120)
    }
}

// MARK: - Retexture

extension QuantumClient {
    /// Retexture a 3D model with AI-generated textures from a text style
    /// prompt or a reference image (one of the two is required).
    public func retexture(_ request: RetextureRequest) async throws -> JobStatusResponse {
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: JSONEncoder().encode(request))
        let job = try await createJob(type: "3d/retexture", params: params)
        return try await pollJob(jobId: job.jobId, interval: 5.0, maxAttempts: 120)
    }
}

// MARK: - Realtime Session With Config

extension QuantumClient {
    /// Request a realtime session with full configuration (voice, prompt, tools for ElevenLabs ConvAI).
    public func realtimeSessionWith(_ body: [String: AnyCodable]) async throws -> RealtimeSession {
        struct Wrapper: Encodable {
            let body: [String: AnyCodable]
            func encode(to encoder: Encoder) throws {
                try body.encode(to: encoder)
            }
        }
        let (data, _): (RealtimeSession, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/realtime/session", body: Wrapper(body: body)
        )
        return data
    }
}

// MARK: - RAG Collection Proxy

extension QuantumClient {

    /// Lists the caller's collections plus the shared ones. Empty when the
    /// caller has neither.
    ///
    /// `GET /qai/v1/rag/collections`
    public func collectionsList() async throws -> [Collection] {
        let (data, _): (CollectionsListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/rag/collections"
        )
        return data.collections
    }

    /// Creates a collection owned by the caller. Bills $0.001 and always
    /// creates on xAI whatever `provider` says.
    ///
    /// `POST /qai/v1/rag/collections` (201)
    public func collectionsCreate(_ request: CreateCollectionRequest, idempotencyKey: String? = nil) async throws -> Collection {
        let (data, _): (Collection, _) = try await doReq(
            method: "POST", path: "/qai/v1/rag/collections", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Creates a collection with just a name. See ``collectionsCreate(_:idempotencyKey:)``.
    public func collectionsCreate(_ name: String) async throws -> Collection {
        try await collectionsCreate(CreateCollectionRequest(name: name))
    }

    /// Reads one collection with its documents. The collection must be owned
    /// by the caller or shared.
    ///
    /// `GET /qai/v1/rag/collections/{id}`
    public func collectionsGet(_ id: String) async throws -> CollectionDetail {
        let (data, _): (CollectionDetail, _) = try await doReq(
            method: "GET", path: "/qai/v1/rag/collections/\(id.strictQueryEncoded)"
        )
        return data
    }

    /// Deletes a collection. Owner only (or admin); a shared collection
    /// cannot be deleted by a reader (403).
    ///
    /// `DELETE /qai/v1/rag/collections/{id}`
    @discardableResult
    public func collectionsDelete(_ id: String) async throws -> DeleteCollectionResponse {
        let (data, _): (DeleteCollectionResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/rag/collections/\(id.strictQueryEncoded)"
        )
        return data
    }

    /// Lists the documents in a collection.
    ///
    /// The gateway serves documents alongside the collection itself, so this
    /// reads the same route as ``collectionsGet(_:)`` and returns just the
    /// documents.
    ///
    /// `GET /qai/v1/rag/collections/{id}`
    public func collectionsDocuments(_ collectionId: String) async throws -> [CollectionDocument] {
        try await collectionsGet(collectionId).documents
    }

    /// Uploads a file into a collection. The gateway performs the two-step
    /// provider upload (file store, then index into the collection) with its
    /// own credential. Bills $0.01, caps the file at 10 MB, and records the
    /// document as `indexed` immediately with no chunk count.
    ///
    /// `POST /qai/v1/rag/collections/{id}/upload` (multipart, field `file`)
    public func collectionsUpload(
        collectionId: String,
        filename: String,
        content: Data
    ) async throws -> CollectionUploadResult {
        let (data, _): (CollectionUploadResult, _) = try await http.doMultipart(
            path: "/qai/v1/rag/collections/\(collectionId.strictQueryEncoded)/upload",
            fieldName: "file",
            filename: filename,
            data: content
        )
        return data
    }

    /// Searches across collections and returns the matched chunks, best score
    /// first.
    ///
    /// Leave ``CollectionSearchRequest/collectionIds`` empty to search
    /// everything the caller can read: their own collections and the shared
    /// ones. Use ``collectionsSearchFull(_:)`` when the surrounding metadata
    /// matters.
    ///
    /// `POST /qai/v1/rag/collections/search`
    public func collectionsSearch(_ request: CollectionSearchRequest) async throws -> [CollectionSearchResult] {
        try await collectionsSearchFull(request).results
    }

    /// Searches across collections and returns the whole response, including
    /// how many collections were reached.
    ///
    /// `POST /qai/v1/rag/collections/search`
    public func collectionsSearchFull(_ request: CollectionSearchRequest) async throws -> CollectionSearchResponse {
        let (data, _): (CollectionSearchResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/rag/collections/search", body: request
        )
        return data
    }
}
