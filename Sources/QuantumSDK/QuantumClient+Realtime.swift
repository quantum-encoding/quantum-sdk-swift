import Foundation

// Realtime voice over WebSocket: the gateway's xAI proxy (`/qai/v1/realtime`)
// and its ElevenLabs conversational proxy (`/qai/v1/realtime/elevenlabs`),
// plus a direct connect for a token minted with `realtimeSession`.
//
// ```swift
// let (sender, receiver) = try await client.realtimeConnect(config: RealtimeConfig())
// Task {
//     for await event in receiver {
//         switch event {
//         case .audioDelta(let delta): play(delta)
//         case .transcriptDone(let transcript, _): print(transcript)
//         case .closed(_, let reason): print("closed:", reason)
//         default: break
//         }
//     }
// }
// try await sender.sendAudio(base64PCM: chunk)
// ```

// MARK: - Sender

/// Write half of a realtime session — send audio and control frames.
public final class RealtimeSender: @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    /// Send a base64-encoded PCM audio chunk (`input_audio_buffer.append`).
    public func sendAudio(base64PCM: String) async throws {
        try await sendJSON(["type": "input_audio_buffer.append", "audio": base64PCM])
    }

    /// Send a text message: creates a user conversation item and requests a
    /// response.
    public func sendText(_ text: String) async throws {
        try await sendJSON([
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [["type": "input_text", "text": text]],
            ] as [String: Any],
        ])
        try await sendJSON([
            "type": "response.create",
            "response": ["modalities": ["text", "audio"]] as [String: Any],
        ])
    }

    /// Send a function/tool call result back to the model and request the
    /// next response.
    public func sendFunctionResult(callId: String, output: String) async throws {
        try await sendJSON([
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callId,
                "output": output,
            ] as [String: Any],
        ])
        try await sendJSON(["type": "response.create"])
    }

    /// Cancel the current response (interrupt the model).
    public func cancelResponse() async throws {
        try await sendJSON(["type": "response.cancel"])
    }

    /// Send one base64-encoded PCM chunk on an ElevenLabs conversational
    /// socket opened with `elevenlabsConnect`.
    ///
    /// That protocol takes microphone audio as `user_audio_chunk`, not the
    /// `input_audio_buffer.append` frame ``sendAudio(base64PCM:)`` sends.
    public func sendElevenLabsAudio(base64PCM: String) async throws {
        try await sendJSON(["user_audio_chunk": base64PCM])
    }

    /// Send an arbitrary JSON object frame — the escape hatch for provider
    /// protocols the typed helpers do not cover.
    public func sendJSON(_ object: [String: AnyCodable]) async throws {
        try await sendJSON(object.mapValues(\.value))
    }

    /// Close the WebSocket connection gracefully.
    public func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }

    func sendJSON(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try await sendRaw(String(decoding: data, as: UTF8.self))
    }

    /// Send a raw text frame.
    func sendRaw(_ text: String) async throws {
        do {
            try await task.send(.string(text))
        } catch let error as URLError where error.code == .cancelled {
            throw QuantumError.cancelled
        } catch {
            throw QuantumError.networkError(underlying: error)
        }
    }
}

// MARK: - Receiver

/// Read half of a realtime session — receive audio, transcripts, tool calls
/// and the socket's end. Iterate it as an `AsyncSequence` or call
/// ``recv()`` directly.
public final class RealtimeReceiver: @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let handshake: WebSocketHandshake?
    private let lock = NSLock()
    private var finished = false

    init(task: URLSessionWebSocketTask, handshake: WebSocketHandshake?) {
        self.task = task
        self.handshake = handshake
    }

    /// Receive the next event. A close frame or a read failure is delivered
    /// as ``RealtimeEvent/closed(code:reason:)`` /
    /// ``RealtimeEvent/transportError(message:)`` and then `nil` on every
    /// later call.
    public func recv() async -> RealtimeEvent? {
        while true {
            if lock.withLock({ finished }) { return nil }

            do {
                switch try await task.receive() {
                case .string(let text):
                    return parseRealtimeEvent(text)
                case .data:
                    continue
                @unknown default:
                    continue
                }
            } catch {
                lock.withLock { finished = true }
                if task.closeCode != .invalid {
                    let reason = task.closeReason.map { String(decoding: $0, as: UTF8.self) } ?? ""
                    return .closed(code: task.closeCode.rawValue, reason: reason)
                }
                return .transportError(message: error.localizedDescription)
            }
        }
    }
}

extension RealtimeReceiver: AsyncSequence {
    public typealias Element = RealtimeEvent

    public struct AsyncIterator: AsyncIteratorProtocol {
        let receiver: RealtimeReceiver

        public mutating func next() async -> RealtimeEvent? {
            await receiver.recv()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(receiver: self)
    }
}

// MARK: - Handshake

/// Task delegate that resolves once the upgrade succeeds or the task fails
/// before opening, so `connect` can report a refused upgrade as an error
/// instead of handing back a dead socket.
final class WebSocketHandshake: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: Result<Void, Error>?
    private var continuation: CheckedContinuation<Void, Error>?

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        settle(.success(()))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        settle(.failure(error ?? URLError(.badServerResponse)))
    }

    func awaitOpen() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            lock.lock()
            if let outcome {
                lock.unlock()
                c.resume(with: outcome)
            } else {
                continuation = c
                lock.unlock()
            }
        }
    }

    private func settle(_ result: Result<Void, Error>) {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return
        }
        outcome = result
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}

/// Maps a gateway refusal (a refused WebSocket upgrade, a rejected event
/// stream) onto ``QuantumError/api(statusCode:code:message:requestId:)``.
///
/// The gateway refuses with its JSON error body — the nested
/// `{"error":{"message","code","type"}}` envelope or the flat
/// `{"error":"unauthorized"}` the proxy handlers write — and `body` is parsed
/// either way when the transport exposes it. `URLSessionWebSocketTask`
/// exposes only the status line and headers of a failed handshake, so on
/// that path `body` is nil and the code is derived from the status (401
/// `authentication_error`, 402 `insufficient_balance`, 502 `upstream_error`,
/// 503 `service_unavailable`).
func gatewayError(statusCode: Int, body: Data?, requestId: String?) -> QuantumError {
    var code: String
    switch statusCode {
    case 401: code = "authentication_error"
    case 402: code = "insufficient_balance"
    case 502: code = "upstream_error"
    case 503: code = "service_unavailable"
    default: code = "websocket_upgrade"
    }
    var message = HTTPURLResponse.localizedString(forStatusCode: statusCode)

    if let body, let raw = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
        if let nested = raw["error"] as? [String: Any] {
            if let m = nested["message"] as? String { message = m }
            if let c = nested["code"] as? String {
                code = c
            } else if let t = nested["type"] as? String {
                code = t
            }
        } else if let flat = raw["error"] as? String {
            message = flat
        } else if let m = raw["message"] as? String {
            message = m
        }
    } else if let body, let text = String(data: body, encoding: .utf8), !text.isEmpty {
        message = text
    }

    return .api(statusCode: statusCode, code: code, message: message, requestId: requestId)
}

// MARK: - Client surface

extension QuantumClient {
    /// Open a realtime voice session through the gateway's xAI proxy.
    ///
    /// Connects to `{baseURL}/qai/v1/realtime` with the client's credentials
    /// (`Authorization` + `X-API-Key`), `config.model` riding as the `model`
    /// query parameter, then sends a `session.update` frame built from
    /// `config` (OpenAI frame shape for `gpt-` models, xAI's otherwise). The
    /// gateway reserves one funded minute up front and meters the session
    /// minute by minute; it closes the socket when the balance runs out
    /// (the close reason says why).
    ///
    /// A refused upgrade (401 unauthenticated, 402 insufficient balance, 503
    /// not configured) throws ``QuantumError/api(statusCode:code:message:requestId:)``.
    public func realtimeConnect(config: RealtimeConfig) async throws -> (sender: RealtimeSender, receiver: RealtimeReceiver) {
        var path = "/qai/v1/realtime"
        if !config.model.isEmpty {
            let model = config.model.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? config.model
            path += "?model=\(model)"
        }
        let pair = try await connectGatewayWebSocket(path: path)
        try await pair.sender.sendJSON(buildSessionUpdate(config).mapValues(\.value))
        return pair
    }

    /// Open an ElevenLabs conversational voice session through the gateway
    /// proxy (`GET /qai/v1/realtime/elevenlabs`, WebSocket upgrade).
    ///
    /// The gateway holds the ElevenLabs credential, reserves one funded
    /// minute up front, and meters the session minute by minute, so the
    /// connection closes when the balance runs out.
    ///
    /// The frames on this socket are ElevenLabs' conversational protocol, not
    /// the xAI/OpenAI realtime one: send microphone audio with
    /// ``RealtimeSender/sendElevenLabsAudio(base64PCM:)`` and anything else
    /// with ``RealtimeSender/sendJSON(_:)``. Incoming frames the shared
    /// parser does not recognise arrive as ``RealtimeEvent/unknown(_:)``
    /// carrying the raw JSON.
    public func elevenlabsConnect(config: ElevenLabsProxyConfig) async throws -> (sender: RealtimeSender, receiver: RealtimeReceiver) {
        try await connectGatewayWebSocket(path: "/qai/v1/realtime/elevenlabs" + config.queryString)
    }

    /// Open a realtime voice session directly to xAI, bypassing the proxy,
    /// with an ephemeral token from ``realtimeSession(provider:)``. Lower
    /// latency than the proxy path.
    public static func realtimeConnectDirect(
        ephemeralToken: String,
        config: RealtimeConfig,
        session: URLSession = QuantumClient.webSocketSession
    ) async throws -> (sender: RealtimeSender, receiver: RealtimeReceiver) {
        try await realtimeConnectDirect(
            url: "wss://api.x.ai/v1/realtime", token: ephemeralToken, config: config, session: session
        )
    }

    /// Open a realtime voice session to a specific WebSocket URL, sending
    /// `token` as a bearer and a `session.update` frame built from `config`.
    /// This is the xAI/OpenAI protocol: an ElevenLabs signed URL speaks a
    /// different one and belongs with ``elevenlabsConnect(config:)``.
    public static func realtimeConnectDirect(
        url: String,
        token: String,
        config: RealtimeConfig,
        session: URLSession = QuantumClient.webSocketSession
    ) async throws -> (sender: RealtimeSender, receiver: RealtimeReceiver) {
        guard let target = URL(string: url) else {
            throw QuantumError.invalidArgument("Invalid WebSocket URL: \(url)")
        }
        var request = URLRequest(url: target)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let pair = try await openWebSocket(request: request, session: session)
        try await pair.sender.sendJSON(buildSessionUpdate(config).mapValues(\.value))
        return pair
    }

    /// Session for direct (non-gateway) sockets: no per-request timeout, so a
    /// quiet socket is not torn down between turns.
    public static let webSocketSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        return URLSession(configuration: config)
    }()

    /// Opens a WebSocket to a gateway path, carrying this client's
    /// credentials on the handshake and going through the client's own
    /// URLSession.
    func connectGatewayWebSocket(path: String) async throws -> (sender: RealtimeSender, receiver: RealtimeReceiver) {
        guard let url = URL(string: Self.webSocketBase(from: baseURLString) + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        let request = http.authorizedRequest(url: url)
        return try await Self.openWebSocket(request: request, session: http.urlSession)
    }

    /// `https://` → `wss://`, `http://` → `ws://`, trailing slash dropped.
    static func webSocketBase(from base: String) -> String {
        var trimmed = base
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.hasPrefix("https://") { return "wss://" + trimmed.dropFirst("https://".count) }
        if trimmed.hasPrefix("http://") { return "ws://" + trimmed.dropFirst("http://".count) }
        return trimmed
    }

    private static func openWebSocket(request: URLRequest, session: URLSession) async throws -> (sender: RealtimeSender, receiver: RealtimeReceiver) {
        var request = request
        request.timeoutInterval = 15
        let handshake = WebSocketHandshake()
        let task = session.webSocketTask(with: request)
        task.delegate = handshake
        task.resume()
        do {
            try await handshake.awaitOpen()
        } catch {
            task.cancel()
            if let response = task.response as? HTTPURLResponse {
                throw gatewayError(
                    statusCode: response.statusCode,
                    body: nil,
                    requestId: response.value(forHTTPHeaderField: "X-QAI-Request-Id")
                )
            }
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw QuantumError.api(statusCode: 0, code: "timeout", message: "WebSocket connection timed out (15s)", requestId: nil)
            }
            throw QuantumError.networkError(underlying: error)
        }
        return (RealtimeSender(task: task), RealtimeReceiver(task: task, handshake: handshake))
    }
}
