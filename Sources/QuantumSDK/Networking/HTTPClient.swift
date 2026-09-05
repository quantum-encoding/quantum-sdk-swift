import Foundation

// MARK: - Locked box

/// A single mutable slot guarded by a lock. The lock is the whole story:
/// every read and write goes through it, which is what makes the
/// `@unchecked Sendable` honest.
final class Locked<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Value) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}

// MARK: - HTTPClient

/// Internal HTTP client wrapping two `URLSession`s (buffered and
/// streaming) with authentication, caller headers and the replay policy.
final class HTTPClient: Sendable {
    /// How many times one request may be replayed after its first attempt.
    static let maxRetries = 3
    /// Backoff before the first replay; doubles on each further replay.
    static let initialBackoff: TimeInterval = 0.5
    /// Longest `Retry-After` the SDK honours. A larger value is clamped so
    /// a misbehaving server cannot park a caller indefinitely.
    static let maxRetryAfter: TimeInterval = 30

    /// Which responses a request may be replayed on.
    ///
    /// The gateway bills chat, session chat and every media route through
    /// a reserve→settle rail that never reads `Idempotency-Key`, and
    /// key-minting and Stripe checkout routes have no dedupe at all.
    /// Replaying such a POST after a 502/503/504 that masked a completed
    /// operation runs it, and charges for it, again. So a POST is replayed
    /// on 429 only, unless the caller opted in with a key on a route that
    /// honours it.
    enum Replay: Sendable {
        /// Single attempt.
        case none
        /// Replay on 429 only. A 429 is answered before any provider call
        /// or charge, so replaying it can never duplicate work.
        case rateLimitOnly
        /// Replay on 429, 502, 503 and 504.
        case transient

        func allows(_ status: Int) -> Bool {
            switch self {
            case .none: return false
            case .rateLimitOnly: return status == 429
            case .transient: return status == 429 || status == 502 || status == 503 || status == 504
            }
        }
    }

    /// Header names that callers may not override: the credential lives
    /// in them, and a caller-supplied value would silently replace it.
    static func isReservedHeader(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "authorization" || lower == "x-api-key"
    }

    /// True when `value` can be sent as an HTTP header value: tab, visible
    /// ASCII, and obs-text bytes. A trailing newline read from a file is
    /// the usual failure.
    static func isValidHeaderValue(_ value: String) -> Bool {
        value.utf8.allSatisfy { byte in
            byte == 0x09 || (0x20...0x7E).contains(byte) || byte >= 0x80
        }
    }

    /// True when `name` is an RFC 7230 token: non-empty, made of the
    /// characters a header name may contain.
    static func isValidHeaderName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.utf8.allSatisfy { byte in
            switch byte {
            case UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"):
                return true
            case UInt8(ascii: "!"), UInt8(ascii: "#"), UInt8(ascii: "$"), UInt8(ascii: "%"),
                 UInt8(ascii: "&"), UInt8(ascii: "'"), UInt8(ascii: "*"), UInt8(ascii: "+"),
                 UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: "^"), UInt8(ascii: "_"),
                 UInt8(ascii: "`"), UInt8(ascii: "|"), UInt8(ascii: "~"):
                return true
            default:
                return false
            }
        }
    }

    /// Buffered session: carries the configured timeout.
    private let session: URLSession
    /// Streaming session: the same headers, no idle timeout. An SSE stream
    /// is open for as long as the model talks; cancellation is task
    /// cancellation.
    private let streamSession: URLSession
    private let baseURLString: String
    private let apiKey: String
    /// Caller headers (`X-Quantum-App` and `extraHeaders`), validated at
    /// construction and never containing a reserved name.
    private let extraHeaders: [(name: String, value: String)]
    /// Optional GCP identity token for Cloud Run IAM. When set,
    /// `Authorization` carries this token and `X-API-Key` carries the API
    /// key; the gateway reads `X-API-Key` first.
    private let cloudRunIdentityToken = Locked<String?>(nil)
    /// Header-derived meta of the most recent 2xx response, whichever
    /// helper produced it.
    let lastMeta = Locked<ResponseMeta?>(nil)

    init(
        baseURL: URL,
        apiKey: String,
        session: URLSession,
        streamSession: URLSession,
        extraHeaders: [(name: String, value: String)] = []
    ) {
        self.baseURLString = baseURL.absoluteString
        self.apiKey = apiKey
        self.session = session
        self.streamSession = streamSession
        self.extraHeaders = extraHeaders
    }

    func setCloudRunIdentityToken(_ token: String?) {
        cloudRunIdentityToken.set(token)
    }

    /// Credential headers, then the caller's. The reserved-name guard at
    /// construction is the only reason the caller's cannot clobber auth.
    private func applyHeaders(_ request: inout URLRequest) {
        if let idToken = cloudRunIdentityToken.get() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        // X-API-Key duplicates the credential for proxies that consume the
        // Authorization header before it reaches the gateway.
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        for header in extraHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
    }

    private func makeRequest(method: String, path: String) throws -> URLRequest {
        guard let url = URL(string: baseURLString + path) else {
            throw QuantumError.invalidArgument("Invalid path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        applyHeaders(&request)
        return request
    }

    /// The buffered session. A WebSocket handshake sets its own per-request
    /// timeout, so it does not need the no-timeout streaming session.
    var urlSession: URLSession { session }

    /// A request to an absolute URL carrying this client's credentials. The
    /// path-taking helpers cannot serve the WebSocket handshake, whose scheme
    /// and host are rewritten from the base URL rather than appended to it.
    func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        applyHeaders(&request)
        return request
    }

    // MARK: - Response Metadata

    struct ResponseMeta: Sendable {
        var requestId: String
        var model: String
        var costTicks: Int
        /// Post-charge wallet balance (signed: claw-back can go negative).
        /// Sent by the media routes only.
        var balanceAfter: Int64?

        init(_ response: HTTPURLResponse) {
            requestId = response.value(forHTTPHeaderField: "X-QAI-Request-Id") ?? ""
            model = response.value(forHTTPHeaderField: "X-QAI-Model") ?? ""
            costTicks = Int(response.value(forHTTPHeaderField: "X-QAI-Cost-Ticks") ?? "0") ?? 0
            balanceAfter = response.value(forHTTPHeaderField: "X-QAI-Balance-After").flatMap { Int64($0) }
        }
    }

    // MARK: - JSON Request

    /// Sends a JSON request and decodes the response.
    ///
    /// Replay policy by method: a GET is replayed on 429/502/503/504 (reads
    /// bill nothing); a POST on 429 only, waiting for the response's
    /// `Retry-After` when it carries one and 0.5 s / 1 s / 2 s otherwise,
    /// up to three times; every other method is a single attempt. A 502,
    /// 503 or 504 on a POST is thrown, never replayed: see ``Replay``. To
    /// opt a POST into 5xx replay on a route that dedupes, use
    /// ``doJSONIdempotent(method:path:body:idempotencyKey:)``.
    ///
    /// - Parameters:
    ///   - idempotencyKey: `Idempotency-Key` header value. A POST always
    ///     sends one (a fresh UUID when nil) and reuses it across replays,
    ///     so routes that dedupe see one logical request. It does not
    ///     change the replay policy. Ignored on other methods.
    func doJSON<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil
    ) async throws -> (data: T, meta: ResponseMeta) {
        let replay: Replay
        switch method.uppercased() {
        case "GET": replay = .transient
        case "POST": replay = .rateLimitOnly
        default: replay = .none
        }
        return try await doJSON(method: method, path: path, body: body, idempotencyKey: idempotencyKey, replay: replay)
    }

    /// Like ``doJSON(method:path:body:idempotencyKey:)`` but with a
    /// caller-supplied idempotency key that also opts the request into
    /// replay on 502/503/504.
    ///
    /// Only routes billed through the gateway's `DeductAndTrack` rail read
    /// `Idempotency-Key`: agent, batch, jobs, search, scanner, rag,
    /// documents, vision, voice, compute and deployments, inference,
    /// missions, cloudrun and security. On those the billing result is
    /// cached for 24 hours under (key, account); the request body is not
    /// part of the cache key, so a key reused for a different payload
    /// returns the first request's billing result while the provider
    /// still runs. Use one key per logical request.
    ///
    /// The key is ignored on `/chat`, `/chat/session`, `/chat/estimate`,
    /// every image, video, audio and avatar route, and on keys, credits,
    /// auth and account. Opt in on those only if a duplicate charge (or a
    /// duplicate key / checkout session) after a masked success is
    /// acceptable.
    func doJSONIdempotent<T: Decodable>(
        method: String = "POST",
        path: String,
        body: (any Encodable)? = nil,
        idempotencyKey: String
    ) async throws -> (data: T, meta: ResponseMeta) {
        try await doJSON(method: method, path: path, body: body, idempotencyKey: idempotencyKey, replay: .transient)
    }

    private func doJSON<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)?,
        idempotencyKey: String?,
        replay: Replay
    ) async throws -> (data: T, meta: ResponseMeta) {
        var request = try makeRequest(method: method, path: path)

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(EncodableWrapper(body))
        }

        if method.uppercased() == "POST" {
            request.setValue(idempotencyKey ?? UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        }

        let (data, response) = try await send(request, replay: replay)
        return try decodeSuccess(data, response)
    }

    // MARK: - Stream Request

    /// Sends a request expecting an SSE response and returns the raw byte
    /// stream. Single attempt, on the no-timeout streaming session, with
    /// the same credential and caller headers as every other request.
    ///
    /// - Parameters:
    ///   - idempotencyKey: `Idempotency-Key` value for a POST (a fresh UUID
    ///     when nil). The streaming chat routes do not read it; it only
    ///     matters on the routes listed under
    ///     ``doJSONIdempotent(method:path:body:idempotencyKey:)``.
    func doStreamRequest(
        method: String = "POST",
        path: String,
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let bodyData = try body.map { try JSONEncoder().encode(EncodableWrapper($0)) }
        return try await doStreamRequest(method: method, path: path, bodyData: bodyData, idempotencyKey: idempotencyKey)
    }

    /// Sends a GET expecting an SSE response. See
    /// ``doStreamRequest(method:path:body:idempotencyKey:)``.
    func doStreamGet(path: String) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        try await doStreamRequest(method: "GET", path: path, bodyData: nil, idempotencyKey: nil)
    }

    /// The streaming request with an already-encoded JSON body, for callers
    /// that encode before hopping into a `Task` (a `Data` is `Sendable`; an
    /// arbitrary `Encodable` may not be).
    func doStreamRequest(
        method: String,
        path: String,
        bodyData: Data?,
        idempotencyKey: String?
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        var request = try makeRequest(method: method, path: path)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }
        if method.uppercased() == "POST" {
            request.setValue(idempotencyKey ?? UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await streamSession.bytes(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw QuantumError.cancelled
        } catch {
            throw QuantumError.networkError(underlying: error)
        }
        let httpResponse = try Self.httpResponse(response)

        guard (200..<300).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            throw parseAPIError(data: errorData, response: httpResponse)
        }

        lastMeta.set(ResponseMeta(httpResponse))
        return (bytes, httpResponse)
    }

    // MARK: - Multipart Upload

    /// Sends a multipart/form-data upload and decodes the JSON response.
    /// `fields` adds plain (non-file) form fields alongside the file part.
    /// Single attempt: a multipart body is not replayed. An
    /// `Idempotency-Key` (a fresh UUID when nil) lets a route that dedupes
    /// recognise a re-issued upload.
    func doMultipart<T: Decodable>(
        path: String,
        fieldName: String,
        filename: String,
        data fileData: Data,
        contentType: String = "application/octet-stream",
        fields: [String: String] = [:],
        idempotencyKey: String? = nil
    ) async throws -> (data: T, meta: ResponseMeta) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try makeRequest(method: "POST", path: path)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey ?? UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")

        var body = Data()
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data(value.utf8))
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let (data, response) = try await send(request, replay: .none)
        return try decodeSuccess(data, response)
    }

    // MARK: - Raw Upload

    /// Sends a raw binary body with a specific content type and decodes
    /// the JSON response. Single attempt.
    func doRawUpload<T: Decodable>(
        method: String = "POST",
        path: String,
        data bodyData: Data,
        contentType: String,
        idempotencyKey: String? = nil
    ) async throws -> (data: T, meta: ResponseMeta) {
        var request = try makeRequest(method: method, path: path)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if method.uppercased() == "POST" {
            request.setValue(idempotencyKey ?? UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = bodyData

        let (data, response) = try await send(request, replay: .none)
        return try decodeSuccess(data, response)
    }

    // MARK: - Raw Download

    /// Sends a request and returns raw bytes (no JSON decoding). A GET is
    /// replayed like ``doJSON(method:path:body:idempotencyKey:)``'s GETs;
    /// any other method is a single attempt.
    func doRawDownload(
        method: String = "GET",
        path: String
    ) async throws -> (data: Data, meta: ResponseMeta) {
        let request = try makeRequest(method: method, path: path)
        let replay: Replay = method.uppercased() == "GET" ? .transient : .none
        let (data, response) = try await send(request, replay: replay)
        let meta = ResponseMeta(response)
        lastMeta.set(meta)
        return (data, meta)
    }

    // MARK: - Send with replay

    /// Sends `request`, replaying it per `replay`, and returns the first
    /// 2xx response. A non-2xx that is not replayable, or the last
    /// replay's failure, is thrown as ``QuantumError/api(statusCode:code:message:requestId:)``.
    private func send(_ request: URLRequest, replay: Replay) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            let (data, response) = try await perform(request)
            let httpResponse = try Self.httpResponse(response)
            let status = httpResponse.statusCode

            if (200..<300).contains(status) {
                return (data, httpResponse)
            }
            guard replay.allows(status), attempt < Self.maxRetries else {
                throw parseAPIError(data: data, response: httpResponse)
            }
            if Self.isPermanentError(data) {
                throw parseAPIError(data: data, response: httpResponse)
            }

            attempt += 1
            let delay = Self.retryAfter(httpResponse) ?? Self.backoff(attempt: attempt)
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                throw QuantumError.cancelled
            }
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw QuantumError.cancelled
        } catch {
            throw QuantumError.networkError(underlying: error)
        }
    }

    private static func httpResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuantumError.networkError(underlying: URLError(.badServerResponse))
        }
        return httpResponse
    }

    /// The `Retry-After` delay a response asks for, when it carries one in
    /// the delay-seconds form the gateway uses (`5` per credential, `10`
    /// per IP). The HTTP-date form is not parsed. Clamped to
    /// ``maxRetryAfter``.
    static func retryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = UInt64(raw.trimmingCharacters(in: .whitespaces))
        else { return nil }
        return min(TimeInterval(seconds), maxRetryAfter)
    }

    /// Delay before replay number `attempt` (1-based) when the response
    /// carried no usable `Retry-After`.
    static func backoff(attempt: Int) -> TimeInterval {
        initialBackoff * pow(2, Double(max(attempt, 1) - 1))
    }

    /// True when an error body describes a permanent (non-retryable)
    /// failure even though it arrived under a retryable status: a 502
    /// wrapping a provider 400, say.
    static func isPermanentError(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else { return false }
        return text.contains("content moderation")
            || text.contains("content_policy")
            || text.contains("safety_block")
            || text.contains("invalid argument")
            || text.contains("invalid_request")
            || (text.contains("status 400") && text.contains("rejected"))
    }

    // MARK: - Decoding

    /// Decodes a 2xx body. A body that is an error envelope (a moderation
    /// block delivered with a 200, say) is thrown as the API error it
    /// describes; any other decode failure carries the `DecodingError`
    /// only, never the body.
    private func decodeSuccess<T: Decodable>(_ data: Data, _ response: HTTPURLResponse) throws -> (data: T, meta: ResponseMeta) {
        let meta = ResponseMeta(response)
        lastMeta.set(meta)
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return (decoded, meta)
        } catch let decodeError {
            if let envelope = parseErrorEnvelope(data), let message = envelope.message, !message.isEmpty {
                throw parseAPIError(data: data, response: response)
            }
            throw QuantumError.decodingFailed(underlying: decodeError)
        }
    }

    /// Longest slice of a non-envelope error body that goes into the
    /// error message.
    private static let maxRawErrorBody = 512

    private func parseAPIError(data: Data, response: HTTPURLResponse) -> QuantumError {
        let statusCode = response.statusCode
        let requestId = response.value(forHTTPHeaderField: "X-QAI-Request-Id") ?? ""
        let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)

        var code = statusText
        var message: String
        if let envelope = parseErrorEnvelope(data) {
            if let envelopeCode = envelope.code, !envelopeCode.isEmpty {
                code = envelopeCode
            }
            if let envelopeMessage = envelope.message, !envelopeMessage.isEmpty {
                message = envelopeMessage
            } else {
                message = Self.safeBodyText(data)
            }
        } else {
            message = Self.safeBodyText(data)
        }

        return .api(
            statusCode: statusCode,
            code: code,
            message: message,
            requestId: requestId.isEmpty ? nil : requestId
        )
    }

    /// A non-envelope error body as message text: the body when it is
    /// short plain text (a proxy's `busy`, say), a summary when it is HTML
    /// or long. An upstream error page never lands verbatim in a log.
    static func safeBodyText(_ data: Data) -> String {
        guard !data.isEmpty else { return "empty response body" }
        guard let text = String(data: data, encoding: .utf8) else {
            return "non-UTF-8 response body (\(data.count) bytes)"
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("<!doctype") || lower.hasPrefix("<html") || lower.hasPrefix("<") {
            return "non-JSON response body (\(data.count) bytes)"
        }
        if trimmed.utf8.count > maxRawErrorBody {
            return String(trimmed.prefix(maxRawErrorBody)) + "…"
        }
        return trimmed
    }
}

// MARK: - EncodableWrapper (internal)

/// Internal type-erased Encodable wrapper for passing to JSONEncoder.
struct EncodableWrapper: Encodable {
    private let wrapped: any Encodable

    init(_ value: any Encodable) {
        self.wrapped = value
    }

    func encode(to encoder: Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}
