import Foundation

// Agent turns, mission runs, RAG, courses, compute rentals and model
// deployments. The shared SSE reader for every ``AgentStreamEvent`` stream
// (missions, Cloud Run, managed agents, inference) also lives here.

// MARK: - Shared helpers

extension String {
    /// Percent-encodes the string for use as one query-string value or one
    /// path segment: every byte outside the RFC 3986 unreserved set
    /// (`A-Z a-z 0-9 - . _ ~`) is escaped, so `&`, `=`, `?`, `/`, `#`, `+`
    /// and spaces can never split or extend the request.
    var strictQueryEncoded: String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}

extension QuantumClient {
    /// Opens an SSE stream and yields one ``AgentStreamEvent`` per `data:`
    /// payload.
    ///
    /// - A payload that does not parse yields an `error` event carrying
    ///   `error: "parse SSE: ..."` and the stream continues.
    /// - The `[DONE]` sentinel yields a synthesised `done` event.
    /// - A transport failure mid-stream, or a body that ends before
    ///   `[DONE]`, yields a final `error` event with `transport: true` and
    ///   the stream ends. It does not throw: a non-2xx status before the
    ///   stream opens (or a body that cannot be encoded) is the only thrown
    ///   failure.
    ///
    /// The body is encoded before the reading task starts so only `Data`
    /// crosses into it.
    func agentEventStream(method: String = "POST", path: String, body: (any Encodable)?) -> AsyncThrowingStream<AgentStreamEvent, any Error> {
        let encoded: Result<Data?, any Error> = Result {
            try body.map { try JSONEncoder().encode(EncodableWrapper($0)) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, _) = try await self.http.doStreamRequest(
                        method: method, path: path, bodyData: try encoded.get(), idempotencyKey: nil
                    )
                    var sawDone = false
                    do {
                        for try await sseEvent in SSEParser(bytes: bytes) {
                            switch sseEvent {
                            case .done:
                                sawDone = true
                                continuation.yield(AgentStreamEvent(eventType: "done"))
                            case let .data(data):
                                continuation.yield(Self.decodeAgentStreamEvent(data))
                            case let .error(message):
                                continuation.yield(Self.agentErrorEvent("parse SSE: \(message)", transport: false))
                            }
                        }
                    } catch is CancellationError {
                        continuation.finish()
                        return
                    } catch let error as URLError where error.code == .cancelled {
                        continuation.finish()
                        return
                    } catch {
                        continuation.yield(Self.agentErrorEvent("transport: \(error.localizedDescription)", transport: true))
                        continuation.finish()
                        return
                    }
                    if !sawDone {
                        continuation.yield(Self.agentErrorEvent("transport: stream ended before [DONE]", transport: true))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Decodes one SSE payload, or synthesises a parse-error event.
    static func decodeAgentStreamEvent(_ data: Data) -> AgentStreamEvent {
        do {
            return try JSONDecoder().decode(AgentStreamEvent.self, from: data)
        } catch {
            return agentErrorEvent("parse SSE: \(error.localizedDescription)", transport: false)
        }
    }

    static func agentErrorEvent(_ message: String, transport: Bool) -> AgentStreamEvent {
        var data: [String: AnyCodable] = ["error": AnyCodable(message)]
        if transport { data["transport"] = AnyCodable(true) }
        return AgentStreamEvent(eventType: "error", data: data)
    }
}

// MARK: - Agent (single turn)

extension QuantumClient {
    /// Runs one model turn with tool-call passthrough.
    ///
    /// The gateway calls the provider once, non-streaming, and returns the
    /// text and any tool calls. It executes nothing: when
    /// ``AgentResponse/stopReason`` is `"tool_use"`, run each
    /// ``AgentResponse/toolUse`` locally, then call again with the history
    /// extended by ``AgentResponse/toMessage()`` and one
    /// ``AgentMessage/toolResult(toolCallId:content:isError:)`` per call.
    /// The turn is billed at the model's chat rate.
    ///
    /// `POST /qai/v1/agent`
    public func agentStep(_ request: AgentRequest, idempotencyKey: String? = nil) async throws -> AgentResponse {
        var (response, meta): (AgentResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/agent", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        if response.costTicks == 0 { response.costTicks = Int64(meta.costTicks) }
        if response.id.isEmpty { response.id = meta.requestId }
        return response
    }

    // MARK: - Mission

    /// Starts a mission run and returns its SSE event stream.
    ///
    /// Missions are higher-level than a single agent turn: the conductor
    /// plans, assigns named workers, and manages context across steps, all
    /// server-side. Events are the loose ``AgentStreamEvent`` shape; the
    /// typed ``MissionStreamEvent`` view of the same wire is
    /// ``missionStream(_:)``.
    ///
    /// `POST /qai/v1/missions`
    public func missionRun(_ request: MissionRequest) -> AsyncThrowingStream<AgentStreamEvent, any Error> {
        agentEventStream(path: "/qai/v1/missions", body: request)
    }

    /// Starts a mission run from a goal and optional overrides. See
    /// ``missionRun(_:)``.
    public func missionRun(
        goal: String,
        conductorModel: String? = nil,
        workers: [String: MissionWorker]? = nil,
        maxSteps: Int? = nil
    ) -> AsyncThrowingStream<AgentStreamEvent, any Error> {
        missionRun(MissionRequest(goal: goal, conductorModel: conductorModel, workers: workers, maxSteps: maxSteps))
    }

    // MARK: - RAG

    /// Searches Vertex AI RAG corpora for relevant documentation. Bills
    /// $0.002 per query.
    public func ragSearch(_ request: RAGSearchRequest, idempotencyKey: String? = nil) async throws -> RAGSearchResponse {
        let (data, _): (RAGSearchResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/rag/search", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Lists available Vertex AI RAG corpora. Free; empty when none exist.
    public func ragCorpora() async throws -> [RAGCorpus] {
        let (data, _): (RagCorporaResponse, _) = try await doReq(method: "GET", path: "/qai/v1/rag/corpora")
        return data.corpora
    }

    /// Searches provider API documentation via SurrealDB vector search.
    /// Bills $0.001 per query.
    public func surrealRagSearch(_ request: SurrealRAGSearchRequest, idempotencyKey: String? = nil) async throws -> SurrealRAGSearchResponse {
        let (data, _): (SurrealRAGSearchResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/rag/surreal/search", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Lists available documentation providers in SurrealDB RAG.
    public func surrealRagProviders() async throws -> SurrealRAGProvidersResponse {
        let (data, _): (SurrealRAGProvidersResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/rag/surreal/providers"
        )
        return data
    }

    // MARK: - Learn Courses

    /// Lists the published Learn course catalog.
    public func listCourses() async throws -> [CatalogCourse] {
        let (data, _): (CourseListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/courses"
        )
        return data.courses
    }

    /// Gets a signed download URL (valid one hour) for a free course bundle.
    /// A paid course answers 402 `payment_required`.
    public func courseDownload(id: String) async throws -> CourseDownloadResponse {
        let (data, _): (CourseDownloadResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/courses/\(id.strictQueryEncoded)/download"
        )
        return data
    }

    /// Publishes a .duckcourse zip bundle to the catalog (admin only, 20 MB
    /// cap).
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

    /// Gets the Learn sandbox guest image manifest (signed URLs + checksums).
    public func learnGuestImage() async throws -> GuestImageResponse {
        let (data, _): (GuestImageResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/learn/guest-image"
        )
        return data
    }

    // MARK: - Compute

    /// Lists available compute templates (GPU configurations and pricing).
    ///
    /// `GET /qai/v1/compute/templates`
    public func computeTemplates() async throws -> TemplatesResponse {
        let (data, _): (TemplatesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/templates"
        )
        return data
    }

    /// Provisions a new GPU compute instance.
    ///
    /// Requires per-account compute approval (403 `compute_not_approved`
    /// otherwise). One hour at the template's billed rate (`hourlyUsd`, or
    /// `spotHourlyUsd` with `spot: true`) is deducted before the VM exists;
    /// the balance must cover that hour, or the template's `minDepositUsd`
    /// when it is higher (402 `insufficient_funds`). `autoTeardownMinutes`
    /// is clamped to 30...1440.
    ///
    /// Templates flagged `requiresApproval` (the largest multi-GPU
    /// machines) are refused with 400 `confirmation_required` unless
    /// `confirm` is `true`, which sends `?confirm=yes`. Pass `false` for
    /// every other template; the flag is ignored there.
    ///
    /// `POST /qai/v1/compute/provision`
    public func computeProvision(_ request: ProvisionRequest, confirm: Bool, idempotencyKey: String? = nil) async throws -> ProvisionResponse {
        let (data, _): (ProvisionResponse, _) = try await doReq(
            method: "POST", path: Self.provisionPath(confirm: confirm), body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// The provision route, with the confirmation flag the high-cost
    /// templates require.
    static func provisionPath(confirm: Bool) -> String {
        confirm ? "/qai/v1/compute/provision?confirm=yes" : "/qai/v1/compute/provision"
    }

    /// Lists the caller's compute instances, terminated ones included.
    ///
    /// `GET /qai/v1/compute/instances`
    public func computeInstances() async throws -> InstancesResponse {
        let (data, _): (InstancesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/instances"
        )
        return data
    }

    /// Gets details for one compute instance, including its live GCE
    /// status and public IP when running. 404 for an unknown id, 403 for
    /// someone else's.
    ///
    /// `GET /qai/v1/compute/instance/{id}`
    public func computeInstance(id: String) async throws -> ComputeInstanceInfo {
        let (data, _): (ComputeInstanceInfo, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/instance/\(id.strictQueryEncoded)"
        )
        return data
    }

    /// Tears down a compute instance and settles its bill: the shortfall of
    /// `hourly × ceil(uptime hours)` (minimum one hour) is charged against
    /// the deposit, and an overpayment is not refunded. 409
    /// `still_provisioning` / `already_terminated` in those states.
    ///
    /// `DELETE /qai/v1/compute/instance/{id}`
    public func computeDelete(id: String) async throws -> DeleteResponse {
        let (data, _): (DeleteResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/compute/instance/\(id.strictQueryEncoded)"
        )
        return data
    }

    /// Adds an SSH public key to a running compute instance (409
    /// `not_running` otherwise). Requires compute approval.
    ///
    /// `POST /qai/v1/compute/instance/{id}/ssh-key`
    public func computeSSHKey(id: String, _ request: SSHKeyRequest) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/instance/\(id.strictQueryEncoded)/ssh-key", body: request
        )
        return data
    }

    /// Adds an SSH public key for the default `cosmic` login. See
    /// ``computeSSHKey(id:_:)``.
    public func computeSSHKey(id: String, publicKey: String) async throws -> StatusResponse {
        try await computeSSHKey(id: id, SSHKeyRequest(publicKey: publicKey))
    }

    /// Sends a keepalive to prevent auto-teardown of a compute instance.
    /// Refused with 402 `balance_zero` when the balance is exhausted.
    ///
    /// `POST /qai/v1/compute/instance/{id}/keepalive`
    public func computeKeepalive(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/instance/\(id.strictQueryEncoded)/keepalive"
        )
        return data
    }

    // MARK: - Model deployments

    /// Lists deployable models: curated configurations with live pricing,
    /// plus whatever the dynamic Model Garden catalogue reports.
    ///
    /// `GET /qai/v1/compute/catalog`
    public func computeCatalog() async throws -> ComputeCatalogResponse {
        let (data, _): (ComputeCatalogResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/catalog"
        )
        return data
    }

    /// Prices a model deployment without billing for it.
    ///
    /// Sends the request with `confirmed` forced off, so the gateway answers
    /// with an estimate and the resolved machine spec. Even the estimate
    /// needs per-account compute approval: an unapproved account gets 403
    /// `compute_not_approved` before anything is priced.
    ///
    /// `POST /qai/v1/compute/deploy-model`
    public func computeDeployModelEstimate(_ request: DeployModelRequest) async throws -> DeployModelEstimate {
        var request = request
        request.confirmed = nil
        let (data, _): (DeployModelEstimate, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/deploy-model", body: request
        )
        return data
    }

    /// Provisions a model deployment, deducting the full duration up front.
    ///
    /// Sends the request with `confirmed` forced on. Provisioning is
    /// asynchronous: poll ``computeDeployment(id:)`` until the status is
    /// `ready`, then call it through ``inference(deploymentId:body:)``. A
    /// failed provision is refunded.
    ///
    /// `POST /qai/v1/compute/deploy-model`
    public func computeDeployModel(_ request: DeployModelRequest, idempotencyKey: String? = nil) async throws -> DeployModelAccepted {
        var request = request
        request.confirmed = true
        let (data, _): (DeployModelAccepted, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/deploy-model", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Lists the caller's model deployments.
    ///
    /// `GET /qai/v1/compute/deployments`
    public func computeDeployments() async throws -> DeploymentsResponse {
        let (data, _): (DeploymentsResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/deployments"
        )
        return data
    }

    /// Reads one model deployment, including its endpoint URL once ready.
    ///
    /// `GET /qai/v1/compute/deployments/{id}`
    public func computeDeployment(id: String) async throws -> ModelDeployment {
        let (data, _): (ModelDeployment, _) = try await doReq(
            method: "GET", path: "/qai/v1/compute/deployments/\(id.strictQueryEncoded)"
        )
        return data
    }

    /// Extends a ready deployment's lifetime, billing for the extra hours.
    ///
    /// Requires compute approval (403 `compute_not_approved`). Only a
    /// `ready` deployment can be extended (400 `invalid_state`). `hours` at
    /// or below zero becomes 1; the extension is refused with 402
    /// `insufficient_funds` when the balance does not cover it.
    ///
    /// `POST /qai/v1/compute/deployments/{id}/extend`
    public func computeDeploymentExtend(id: String, hours: Int, idempotencyKey: String? = nil) async throws -> ExtendDeploymentResponse {
        let (data, _): (ExtendDeploymentResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/compute/deployments/\(id.strictQueryEncoded)/extend",
            body: ExtendDeploymentRequest(hours: hours),
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Tears a model deployment down early. The remaining hours are not
    /// refunded.
    ///
    /// `DELETE /qai/v1/compute/deployments/{id}`
    public func computeDeploymentDelete(id: String) async throws -> DeploymentDeleteResponse {
        let (data, _): (DeploymentDeleteResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/compute/deployments/\(id.strictQueryEncoded)"
        )
        return data
    }
}
