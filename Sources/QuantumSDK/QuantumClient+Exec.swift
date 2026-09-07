import Foundation

// MARK: - Sandbox Exec

extension QuantumClient {

    /// Runs a command in an ephemeral sandbox and returns the whole result.
    ///
    /// Files are written into a fresh workspace, `bash -c <command>` runs
    /// inside it, and the workspace is destroyed when the call returns unless
    /// ``ExecRequest/sessionID`` names one to keep warm. There is no model and
    /// no agent inside the sandbox — it runs exactly the command it is given.
    ///
    /// Billing is wall-clock and survives the caller hanging up: the container
    /// ran either way, so abandoning the request does not avoid the charge.
    ///
    /// `POST /qai/v1/exec/sync`
    public func exec(_ request: ExecRequest) async throws -> ExecResponse {
        let (data, _): (ExecResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/exec/sync", body: request
        )
        return data
    }

    /// Streams a sandbox run, yielding output as it is produced.
    ///
    /// Use this rather than ``exec(_:)`` when a human is watching: a build
    /// that prints for two minutes should not arrive as silence followed by a
    /// wall of text. The stream ends after the exit event.
    ///
    /// `POST /qai/v1/exec`
    public func execStream(_ request: ExecRequest) -> AsyncThrowingStream<ExecEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, _) = try await http.doStreamRequest(
                        path: "/qai/v1/exec", body: request
                    )
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !payload.isEmpty, payload != "[DONE]" else { continue }
                        guard let data = payload.data(using: .utf8) else { continue }
                        continuation.yield(Self.execEvent(fromPayload: data))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Decodes one SSE payload into an ``ExecEvent``, falling back to
    /// ``ExecEvent/unknown`` so an event type added later does not break a
    /// client that predates it.
    static func execEvent(fromPayload data: Data) -> ExecEvent {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return .unknown(String(data: data, encoding: .utf8) ?? "")
        }
        switch type {
        case "stdout", "stderr":
            let text = object["line"] as? String ?? object["text"] as? String ?? ""
            return type == "stdout" ? .stdout(text) : .stderr(text)
        case "artifact":
            guard let artifact = try? JSONDecoder().decode(ExecArtifact.self, from: data) else {
                return .unknown(String(data: data, encoding: .utf8) ?? "")
            }
            return .artifact(artifact)
        case "artifacts_done":
            return .artifactsDone(count: object["count"] as? Int ?? 0,
                                  truncated: object["truncated"] as? Bool ?? false)
        case "exit", "done":
            return .exit(code: object["exit_code"] as? Int ?? 0,
                         durationMs: (object["duration_ms"] as? Int).map(Int64.init) ?? 0)
        case "error":
            return .failed(object["error"] as? String ?? object["message"] as? String ?? "sandbox error")
        default:
            return .unknown(String(data: data, encoding: .utf8) ?? "")
        }
    }
}

/// One event from a streaming sandbox run.
public enum ExecEvent: Sendable {
    case stdout(String)
    case stderr(String)
    case artifact(ExecArtifact)
    case artifactsDone(count: Int, truncated: Bool)
    case exit(code: Int, durationMs: Int64)
    case failed(String)
    /// An event this SDK version does not know, kept as raw text.
    case unknown(String)
}
