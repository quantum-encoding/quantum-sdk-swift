import Foundation

// MARK: - Missing Parity Methods

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

    /// Query compute billing from BigQuery via the QAI backend.
    ///
    /// - Parameter request: Billing query filters (instance ID, date range).
    /// - Returns: Billing entries and total cost.
    public func computeBilling(_ request: BillingRequest) async throws -> BillingResponse {
        let (data, _): (BillingResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/compute/billing", body: request
        )
        return data
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

    /// Rig a humanoid 3D model. Returns rigged character + basic walk/run animations.
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
    /// Retexture a 3D model with AI-generated textures from text or image.
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

    /// Lists the user's collections plus shared collections.
    public func collectionsList() async throws -> [Collection] {
        struct Response: Decodable { let collections: [Collection] }
        let (data, _): (Response, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/rag/collections"
        )
        return data.collections
    }

    /// Creates a new user-owned collection.
    ///
    /// - Parameter name: Human-readable name for the collection.
    /// - Returns: The newly created collection.
    public func collectionsCreate(_ name: String) async throws -> Collection {
        struct Body: Encodable { let name: String }
        let (data, _): (Collection, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/rag/collections", body: Body(name: name)
        )
        return data
    }

    /// Gets details for a single collection (must be owned or shared).
    ///
    /// - Parameter id: Collection ID.
    /// - Returns: The collection.
    public func collectionsGet(_ id: String) async throws -> Collection {
        let (data, _): (Collection, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/rag/collections/\(id)"
        )
        return data
    }

    /// Deletes a collection (owner only).
    ///
    /// - Parameter id: Collection ID.
    public func collectionsDelete(_ id: String) async throws {
        struct Response: Decodable { let message: String? }
        let (_, _): (Response, _) = try await http.doJSON(
            method: "DELETE", path: "/qai/v1/rag/collections/\(id)"
        )
    }

    /// Lists documents in a collection.
    ///
    /// - Parameter collectionId: Collection ID.
    /// - Returns: Array of documents.
    public func collectionsDocuments(_ collectionId: String) async throws -> [CollectionDocument] {
        struct Response: Decodable { let documents: [CollectionDocument] }
        let (data, _): (Response, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/rag/collections/\(collectionId)/documents"
        )
        return data.documents
    }

    /// Uploads a file to a collection.
    ///
    /// The server handles the two-step upload (files API + management API) with the master key.
    ///
    /// - Parameters:
    ///   - collectionId: Target collection ID.
    ///   - filename: Name for the uploaded file.
    ///   - content: Raw file data.
    /// - Returns: Upload result with file ID and size.
    public func collectionsUpload(
        collectionId: String,
        filename: String,
        content: Data
    ) async throws -> CollectionUploadResult {
        let (data, _): (CollectionUploadResult, _) = try await http.doMultipart(
            path: "/qai/v1/rag/collections/\(collectionId)/upload",
            fieldName: "file",
            filename: filename,
            data: content
        )
        return data
    }

    /// Searches across collections (user's + shared) with hybrid/semantic/keyword mode.
    ///
    /// - Parameter request: Search parameters including query and collection IDs.
    /// - Returns: Array of search results.
    public func collectionsSearch(_ request: CollectionSearchRequest) async throws -> [CollectionSearchResult] {
        struct Response: Decodable { let results: [CollectionSearchResult] }
        let (data, _): (Response, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/rag/search/collections", body: request
        )
        return data.results
    }
}
