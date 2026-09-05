import Foundation
import XCTest
@testable import QuantumSDK

// MARK: - Scripted mock transport

/// URLProtocol that answers each request with the next scripted response
/// and records what it was asked, so the replay policy and the wire
/// headers can be asserted without a network. Distinct from the HeyGen
/// tests' single-stub mock: this one is a queue, because a replay is a
/// second request.
final class CoreMockProtocol: URLProtocol {
    struct Canned {
        var status: Int
        var body: Data
        var headers: [String: String]

        init(status: Int, body: String, headers: [String: String] = [:]) {
            self.status = status
            self.body = Data(body.utf8)
            self.headers = headers
        }
    }

    struct Recorded {
        var method: String
        var url: URL
        var headers: [String: String]
        var body: Data

        /// Header lookup, case-insensitive on the name.
        func header(_ name: String) -> String? {
            headers.first { $0.key.lowercased() == name.lowercased() }?.value
        }
    }

    private static let lock = NSLock()
    private static var script: [Canned] = []
    private static var recorded: [Recorded] = []

    /// Replaces the script and clears the recording.
    static func script(_ responses: [Canned]) {
        lock.lock()
        defer { lock.unlock() }
        script = responses
        recorded = []
    }

    /// Every request seen since the last `script(_:)`.
    static var requests: [Recorded] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private static func take(_ request: Recorded) -> Canned {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(request)
        if script.isEmpty {
            return Canned(status: 599, body: #"{"error":{"message":"mock script exhausted","type":"mock"}}"#)
        }
        return script.removeFirst()
    }

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let canned = Self.take(Recorded(
            method: request.httpMethod ?? "",
            url: request.url!,
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.readBody(of: request)
        ))
        var headers = canned.headers
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: canned.status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: canned.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// A client wired to ``CoreMockProtocol`` with an app id and an extra
/// header, like the Rust crate's test client.
func makeMockClient(apiKey: String = "qai_k_test", region: Region? = nil) throws -> QuantumClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CoreMockProtocol.self]
    var configuration = ClientConfiguration(apiKey: apiKey, baseURL: "https://mock.gateway.invalid")
    configuration.session = URLSession(configuration: config)
    configuration.app = "recipe-box"
    configuration.extraHeaders = [(name: "X-Correlation-Id", value: "abc-123")]
    configuration.region = region
    return try QuantumClient(configuration: configuration)
}

struct OkBody: Decodable {
    let ok: Bool
}

func apiStatus(_ error: any Error, file: StaticString = #filePath, line: UInt = #line) -> Int {
    guard let quantum = error as? QuantumError, case let .api(status, _, _, _) = quantum else {
        XCTFail("expected QuantumError.api, got \(error)", file: file, line: line)
        return -1
    }
    return status
}
