import Foundation

// Agent, mission, RAG, courses and compute routes.
extension QuantumClient {
    // MARK: - Agent

    /// Run a server-side agent orchestration. Returns a stream of ``AgentEvent`` values.
    ///
    /// ```swift
    /// for try await event in client.agentRun(task: "Research the latest AI papers") {
    ///     print(event.type, event.content ?? "")
    /// }
    /// ```
    public func agentRun(
        task: String,
        conductorModel: String? = nil,
        workers: [AgentWorkerConfig]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil,
        capabilities: [String]? = nil
    ) -> AsyncThrowingStream<AgentEvent, any Error> {
        let request = AgentRequest(
            task: task,
            conductorModel: conductorModel,
            workers: workers,
            maxSteps: maxSteps,
            systemPrompt: systemPrompt,
            capabilities: capabilities
        )
        return agentRun(request)
    }

    /// Run an agent orchestration with a full ``AgentRequest``.
    ///
    /// `AgentRequest` carries the conductor-style
    /// `{ goal, conductor_model, workers, max_steps, ... }` shape, which is
    /// the Mission orchestrator's contract, so it posts to `/qai/v1/missions`.
    /// `/qai/v1/agent` is the stateless provider-passthrough endpoint and takes
    /// an Anthropic-style `{ model, messages, tools, ... }` body. Swift exposes
    /// the goal field as `task`; `CodingKeys` remaps it to `goal` on the wire.
    public func agentRun(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        return makeSSEStream(path: "/qai/v1/missions", body: request) { data in
            try self.parseAgentEvent(data)
        }
    }

    // MARK: - Mission

    /// Run a full mission orchestration. Returns a stream of ``MissionEvent`` values.
    public func missionRun(
        goal: String,
        conductorModel: String? = nil,
        workers: [String: MissionWorker]? = nil,
        maxSteps: Int? = nil
    ) -> AsyncThrowingStream<MissionEvent, any Error> {
        let request = MissionRequest(
            goal: goal,
            conductorModel: conductorModel,
            workers: workers,
            maxSteps: maxSteps
        )
        return missionRun(request)
    }

    /// Run a mission orchestration with a full ``MissionRequest``.
    public func missionRun(_ request: MissionRequest) -> AsyncThrowingStream<MissionEvent, any Error> {
        return makeSSEStream(path: "/qai/v1/missions", body: request) { data in
            try self.parseMissionEvent(data)
        }
    }

    // MARK: - RAG

    /// Search Vertex AI RAG corpora for relevant documentation.
    public func ragSearch(_ request: RAGSearchRequest) async throws -> RAGSearchResponse {
        let (data, _): (RAGSearchResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/rag/search", body: request
        )
        return data
    }

    /// List available Vertex AI RAG corpora.
    public func ragCorpora() async throws -> [RAGCorpus] {
        struct Body: Decodable { let corpora: [RAGCorpus]; let request_id: String }
        let (data, _): (Body, _) = try await doReq(method: "GET", path: "/qai/v1/rag/corpora")
        return data.corpora
    }

    /// Search provider API documentation via SurrealDB vector search.
    public func surrealRagSearch(_ request: SurrealRAGSearchRequest) async throws -> SurrealRAGSearchResponse {
        let (data, _): (SurrealRAGSearchResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/rag/surreal/search", body: request
        )
        return data
    }

    /// List available documentation providers in SurrealDB RAG.
    public func surrealRagProviders() async throws -> SurrealRAGProvidersResponse {
        let (data, _): (SurrealRAGProvidersResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/rag/surreal/providers"
        )
        return data
    }

    // MARK: - Learn Courses

    /// List the published Learn course catalog.
    public func listCourses() async throws -> [CatalogCourse] {
        let (data, _): (CourseListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/courses"
        )
        return data.courses
    }

    /// Get a signed download URL for a (free) course bundle.
    public func courseDownload(id: String) async throws -> CourseDownloadResponse {
        let (data, _): (CourseDownloadResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/courses/\(id)/download"
        )
        return data
    }

    /// Publish a .duckcourse zip bundle to the catalog (admin only).
    public func publishCourse(zipData: Data) async throws -> CoursePublishResponse {
        struct PublishRequest: Encodable {
            let zipBase64: String
            enum CodingKeys: String, CodingKey { case zipBase64 = "zip_base64" }
        }
        let (data, _): (CoursePublishResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/courses/publish",
            body: PublishRequest(zipBase64: zipData.base64EncodedString())
        )
        return data
    }

    /// Get the Learn sandbox guest image manifest (signed URLs + checksums).
    public func learnGuestImage() async throws -> GuestImageResponse {
        let (data, _): (GuestImageResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/learn/guest-image"
        )
        return data
    }

    // MARK: - Compute

    /// Get available compute templates with pricing.
    public func computeTemplates() async throws -> TemplatesResponse {
        let (data, _): (TemplatesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/templates"
        )
        return data
    }

    /// Provision a new GPU compute instance.
    public func computeProvision(_ request: ProvisionRequest) async throws -> ProvisionResponse {
        let (data, _): (ProvisionResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/provision", body: request
        )
        return data
    }

    /// List all compute instances for the authenticated user.
    public func computeInstances() async throws -> InstancesResponse {
        let (data, _): (InstancesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/instances"
        )
        return data
    }

    /// Get full status of a single compute instance.
    public func computeInstance(id: String) async throws -> InstanceResponse {
        let (data, _): (InstanceResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/instance/\(id)"
        )
        return data
    }

    /// Tear down a compute instance and finalize billing.
    public func computeDelete(id: String) async throws -> DeleteResponse {
        let (data, _): (DeleteResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/compute/instance/\(id)"
        )
        return data
    }

    /// Inject an SSH public key into a running instance.
    public func computeSSHKey(id: String, sshPublicKey: String) async throws -> StatusResponse {
        let request = SSHKeyRequest(sshPublicKey: sshPublicKey)
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/instance/\(id)/ssh-key", body: request
        )
        return data
    }

    /// Reset the inactivity timer on a compute instance.
    public func computeKeepalive(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/instance/\(id)/keepalive"
        )
        return data
    }
}
