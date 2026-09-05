import Foundation

// Agent runtime (agents, environments, sessions, workspaces) and the
// admin-only Managed Agents passthrough. Types live in
// Models/AgentRuntime.swift and Models/ManagedAgents.swift.

// MARK: - Agent runtime

extension QuantumClient {
    // MARK: Agents

    /// Creates a runtime agent (201). Free; spend starts at session start.
    ///
    /// `POST /qai/v1/agent-runtime/agents`
    public func agentRuntimeAgentCreate(_ request: RuntimeAgentRequest) async throws -> RuntimeAgent {
        let (data, _): (RuntimeAgent, _) = try await doReq(
            method: "POST", path: "/qai/v1/agent-runtime/agents", body: request
        )
        return data
    }

    /// Lists the caller's runtime agents.
    ///
    /// `limit` caps the page size when it is 1...500; any other value,
    /// larger ones included, silently becomes the server default of 50.
    ///
    /// `GET /qai/v1/agent-runtime/agents`
    public func agentRuntimeAgents(limit: Int? = nil) async throws -> RuntimeAgentsResponse {
        var path = "/qai/v1/agent-runtime/agents"
        if let limit { path += "?limit=\(limit)" }
        let (data, _): (RuntimeAgentsResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Reads one runtime agent.
    ///
    /// `GET /qai/v1/agent-runtime/agents/{id}`
    public func agentRuntimeAgentGet(id: String) async throws -> RuntimeAgent {
        let (data, _): (RuntimeAgent, _) = try await doReq(
            method: "GET", path: "/qai/v1/agent-runtime/agents/\(id.strictQueryEncoded)"
        )
        return data
    }

    /// Updates a runtime agent's config and returns the new version.
    ///
    /// The gateway's update route writes every field, so this reads the
    /// stored agent first, merges `update` onto it with
    /// ``RuntimeAgentUpdate/apply(to:)``, and sends the whole body. The two
    /// calls are not atomic: a concurrent update landing between them is
    /// overwritten.
    ///
    /// `GET` then `PUT /qai/v1/agent-runtime/agents/{id}`
    public func agentRuntimeAgentUpdate(id: String, _ update: RuntimeAgentUpdate) async throws -> RuntimeAgentUpdateResponse {
        let current = try await agentRuntimeAgentGet(id: id)
        let body = update.apply(to: current)
        let (data, _): (RuntimeAgentUpdateResponse, _) = try await doReq(
            method: "PUT", path: "/qai/v1/agent-runtime/agents/\(id.strictQueryEncoded)", body: body
        )
        return data
    }

    /// Deletes a runtime agent. The gateway answers `204 No Content`.
    ///
    /// `DELETE /qai/v1/agent-runtime/agents/{id}`
    public func agentRuntimeAgentDelete(id: String) async throws {
        _ = try await http.doRawDownload(
            method: "DELETE", path: "/qai/v1/agent-runtime/agents/\(id.strictQueryEncoded)"
        )
    }

    // MARK: Environments

    /// Creates a runtime environment (201).
    ///
    /// `POST /qai/v1/agent-runtime/environments`
    public func agentRuntimeEnvironmentCreate(_ request: RuntimeEnvironmentRequest) async throws -> RuntimeEnvironment {
        let (data, _): (RuntimeEnvironment, _) = try await doReq(
            method: "POST", path: "/qai/v1/agent-runtime/environments", body: request
        )
        return data
    }

    /// Lists the caller's runtime environments.
    ///
    /// `limit` caps the page size when it is 1...500; any other value,
    /// larger ones included, silently becomes the server default of 50.
    ///
    /// `GET /qai/v1/agent-runtime/environments`
    public func agentRuntimeEnvironments(limit: Int? = nil) async throws -> RuntimeEnvironmentsResponse {
        var path = "/qai/v1/agent-runtime/environments"
        if let limit { path += "?limit=\(limit)" }
        let (data, _): (RuntimeEnvironmentsResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Deletes a runtime environment. The gateway answers `204 No Content`.
    ///
    /// `DELETE /qai/v1/agent-runtime/environments/{id}`
    public func agentRuntimeEnvironmentDelete(id: String) async throws {
        _ = try await http.doRawDownload(
            method: "DELETE", path: "/qai/v1/agent-runtime/environments/\(id.strictQueryEncoded)"
        )
    }

    // MARK: Sessions

    /// Starts a session for an agent in an environment (201).
    ///
    /// Sessions on a `managed-agents` environment are admin-only; the
    /// `coding-session` backend is open to any owner.
    ///
    /// `POST /qai/v1/agent-runtime/sessions`
    public func agentRuntimeSessionStart(_ request: StartSessionRequest) async throws -> RuntimeSession {
        let (data, _): (RuntimeSession, _) = try await doReq(
            method: "POST", path: "/qai/v1/agent-runtime/sessions", body: request
        )
        return data
    }

    /// Appends an event to a running session; this is how a user turn is
    /// sent (202).
    ///
    /// `POST /qai/v1/agent-runtime/sessions/events`
    public func agentRuntimeSessionEvent(_ session: RuntimeSession, event: RuntimeEvent) async throws -> RuntimeOkResponse {
        let (data, _): (RuntimeOkResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/agent-runtime/sessions/events",
            body: AppendEventRequest(session: session, event: event)
        )
        return data
    }

    /// The stream route with the session descriptor as one strictly
    /// encoded query value.
    static func agentRuntimeStreamPath(session: RuntimeSession, since: Int64?) throws -> String {
        let descriptor = String(decoding: try JSONEncoder().encode(session), as: UTF8.self)
        var path = "/qai/v1/agent-runtime/sessions/stream?session=\(descriptor.strictQueryEncoded)"
        if let since { path += "&since=\(since)" }
        return path
    }

    /// Streams a session's events.
    ///
    /// The session descriptor rides the query string, so the stream is a
    /// stateless GET. Pass `since`, the ``RuntimeEvent/index`` of the last
    /// structural event seen, to replay the durable events past it before
    /// bridging to the live stream; ephemeral events are not replayed.
    ///
    /// Nothing is dropped: a payload that is not a JSON object arrives as an
    /// `unknown` event carrying the raw text, and a transport failure as a
    /// final `error` event (see ``RuntimeEvent``). Only a non-2xx status
    /// before the stream opens throws.
    ///
    /// `GET /qai/v1/agent-runtime/sessions/stream`
    public func agentRuntimeSessionStream(_ session: RuntimeSession, since: Int64? = nil) -> AsyncThrowingStream<RuntimeEvent, any Error> {
        let path = Result { try Self.agentRuntimeStreamPath(session: session, since: since) }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, _) = try await self.http.doStreamGet(path: try path.get())
                    do {
                        for try await sseEvent in SSEParser(bytes: bytes) {
                            switch sseEvent {
                            case .done:
                                continue
                            case let .data(data):
                                continuation.yield(Self.runtimeEvent(fromPayload: data))
                            case let .error(message):
                                continuation.yield(RuntimeEvent(type: "unknown", content: message))
                            }
                        }
                    } catch is CancellationError {
                        continuation.finish()
                        return
                    } catch let error as URLError where error.code == .cancelled {
                        continuation.finish()
                        return
                    } catch {
                        continuation.yield(RuntimeEvent(type: "error", content: "transport: \(error.localizedDescription)"))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Stops a running session.
    ///
    /// `POST /qai/v1/agent-runtime/sessions/stop`
    public func agentRuntimeSessionStop(_ session: RuntimeSession) async throws -> RuntimeOkResponse {
        let (data, _): (RuntimeOkResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/agent-runtime/sessions/stop", body: session
        )
        return data
    }

    /// Downloads a session's current server-side working tree as a
    /// `.tar.gz`.
    ///
    /// This is the whole-copy counterpart to the per-turn diff, for clients
    /// with no local checkout to apply a diff onto. `coding-session` only.
    ///
    /// `POST /qai/v1/agent-runtime/sessions/workspace`
    public func agentRuntimeSessionWorkspace(_ session: RuntimeSession) async throws -> Data {
        let (bytes, _) = try await http.doStreamRequest(
            path: "/qai/v1/agent-runtime/sessions/workspace", body: session
        )
        var archive = Data()
        for try await byte in bytes {
            archive.append(byte)
        }
        return archive
    }

    /// Stages a workspace archive for a later session launch (201).
    ///
    /// `archive` is a `.tar.gz` or `.zip` of the tree (150 MB cap). Set the
    /// returned object as ``OverlayConfig/workspaceObject`` on the
    /// environment that launches the session.
    ///
    /// `POST /qai/v1/agent-runtime/workspaces` (multipart, field `file`)
    public func agentRuntimeStageWorkspace(filename: String, archive: Data) async throws -> StageWorkspaceResponse {
        let (data, _): (StageWorkspaceResponse, _) = try await http.doMultipart(
            path: "/qai/v1/agent-runtime/workspaces",
            fieldName: "file",
            filename: filename,
            data: archive
        )
        return data
    }

    /// Turns one SSE payload into the event the session stream yields: the
    /// decoded ``RuntimeEvent``, or an `unknown` event carrying the raw text
    /// when the payload is not a JSON object.
    static func runtimeEvent(fromPayload data: Data) -> RuntimeEvent {
        if let event = try? JSONDecoder().decode(RuntimeEvent.self, from: data) {
            return event
        }
        return RuntimeEvent(type: "unknown", content: String(decoding: data, as: UTF8.self))
    }
}

// MARK: - Managed Agents passthrough

extension QuantumClient {
    /// The passthrough route for a Managed Agents path (everything after
    /// `/qai/v1/managed-agents/`, query string included).
    static func managedAgentsPath(_ path: String) -> String {
        "/qai/v1/managed-agents/\(path)"
    }

    /// Sends a GET to the Managed Agents passthrough.
    ///
    /// `path` is everything after `/qai/v1/managed-agents/`, query string
    /// included (e.g. `"agents?limit=20"`). Admin-only.
    ///
    /// `GET /qai/v1/managed-agents/{path}`
    public func managedAgentsGet(_ path: String) async throws -> [String: AnyCodable] {
        let (data, _): ([String: AnyCodable], _) = try await doReq(
            method: "GET", path: Self.managedAgentsPath(path)
        )
        return data
    }

    /// Sends a POST to the Managed Agents passthrough. Admin-only.
    ///
    /// `POST /qai/v1/managed-agents/{path}`
    public func managedAgentsPost(_ path: String, body: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        let (data, _): ([String: AnyCodable], _) = try await doReq(
            method: "POST", path: Self.managedAgentsPath(path), body: body
        )
        return data
    }

    /// Sends a DELETE to the Managed Agents passthrough. Admin-only.
    ///
    /// `DELETE /qai/v1/managed-agents/{path}`
    public func managedAgentsDelete(_ path: String) async throws -> [String: AnyCodable] {
        let (data, _): ([String: AnyCodable], _) = try await doReq(
            method: "DELETE", path: Self.managedAgentsPath(path)
        )
        return data
    }

    /// Opens a Managed Agents SSE stream, e.g.
    /// `"sessions/sesn_123/events/stream"`.
    ///
    /// The gateway relays the upstream stream unbuffered. Admin-only.
    ///
    /// `GET /qai/v1/managed-agents/{path}`
    public func managedAgentsStream(_ path: String) -> AsyncThrowingStream<ManagedAgentsEvent, any Error> {
        agentEventStream(method: "GET", path: Self.managedAgentsPath(path), body: nil)
    }

    /// Opens a Managed Agents SSE stream that is started by a POST body.
    /// The gateway relays the upstream stream unbuffered. Admin-only.
    ///
    /// `POST /qai/v1/managed-agents/{path}`
    public func managedAgentsPostStream(_ path: String, body: [String: AnyCodable]) -> AsyncThrowingStream<ManagedAgentsEvent, any Error> {
        agentEventStream(path: Self.managedAgentsPath(path), body: body)
    }
}
