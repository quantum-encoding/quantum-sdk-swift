import Foundation

// Sandbox-backed orchestration and inference against self-deployed models.
// Types live in Models/CloudRun.swift and Models/Inference.swift.

extension QuantumClient {
    // MARK: - Cloud Run

    /// Starts a sandbox-backed agent run and returns its SSE event stream.
    ///
    /// See ``CloudRunRequest`` for the knobs and ``AgentStreamEvent`` for
    /// the stream contract.
    ///
    /// `POST /qai/v1/cloudrun`
    public func cloudrun(_ request: CloudRunRequest) -> AsyncThrowingStream<CloudRunEvent, any Error> {
        agentEventStream(path: "/qai/v1/cloudrun", body: request)
    }

    // MARK: - Inference

    /// Sends an OpenAI-compatible completion request to a deployment.
    ///
    /// `body` is forwarded as-is; it must not set `stream`. Use
    /// ``inferenceStream(deploymentId:body:)`` for that.
    ///
    /// `POST /qai/v1/inference/{id}`
    public func inference(deploymentId: String, body: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        let (data, _): ([String: AnyCodable], _) = try await doReq(
            method: "POST", path: "/qai/v1/inference/\(deploymentId.strictQueryEncoded)", body: body
        )
        return data
    }

    /// Streams an OpenAI-compatible completion from a deployment.
    ///
    /// `stream: true` is set on the forwarded body, and the upstream SSE
    /// chunks are relayed through unchanged.
    ///
    /// `POST /qai/v1/inference/{id}`
    public func inferenceStream(deploymentId: String, body: [String: AnyCodable]) -> AsyncThrowingStream<InferenceEvent, any Error> {
        var body = body
        body["stream"] = AnyCodable(true)
        return agentEventStream(path: "/qai/v1/inference/\(deploymentId.strictQueryEncoded)", body: body)
    }
}
