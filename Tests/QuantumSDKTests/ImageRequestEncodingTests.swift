import XCTest
@testable import QuantumSDK

/// Verifies the wire encoding of ImageRequest — specifically that the newly
/// wired-through params (background / seed / cfg_scale) serialize to the exact
/// snake_case JSON keys the backend expects, and are OMITTED entirely when nil
/// (so existing requests that don't set them are byte-for-byte unchanged).
final class ImageRequestEncodingTests: XCTestCase {

    private func encodeToObject(_ req: ImageRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    func testBackgroundEncodesWhenSet() throws {
        let req = ImageRequest(model: "gpt-image-1", prompt: "a cat", background: "transparent")
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["background"] as? String, "transparent")
    }

    func testBackgroundOmittedWhenNil() throws {
        let req = ImageRequest(model: "gpt-image-1", prompt: "a cat")
        let obj = try encodeToObject(req)
        XCTAssertNil(obj["background"], "background must be absent (not null) when nil")
        // Sanity: nil optionals are omitted, not encoded as JSON null.
        XCTAssertFalse(obj.keys.contains("background"))
        XCTAssertFalse(obj.keys.contains("seed"))
        XCTAssertFalse(obj.keys.contains("cfg_scale"))
    }

    func testSeedAndCfgScaleUseSnakeCaseKeys() throws {
        let req = ImageRequest(
            model: "gpt-image-1",
            prompt: "a cat",
            background: "opaque",
            seed: 42,
            cfgScale: 7.5
        )
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["seed"] as? Int, 42)
        XCTAssertEqual(obj["cfg_scale"] as? Double, 7.5)
        XCTAssertEqual(obj["background"] as? String, "opaque")
        // The pre-existing required fields are still present and correct.
        XCTAssertEqual(obj["model"] as? String, "gpt-image-1")
        XCTAssertEqual(obj["prompt"] as? String, "a cat")
    }

    func testMinimalRequestUnchanged() throws {
        // A request built the old way (model/prompt/count/size/quality) must
        // encode exactly those keys and nothing new.
        let req = ImageRequest(model: "grok-imagine-image", prompt: "duck", count: 2, size: "1024x1024", quality: "high")
        let obj = try encodeToObject(req)
        XCTAssertEqual(Set(obj.keys), ["model", "prompt", "count", "size", "quality"])
    }

    func testRoundTripDecode() throws {
        let json = """
        {"model":"gpt-image-1","prompt":"x","background":"transparent","seed":7,"cfg_scale":3.0}
        """.data(using: .utf8)!
        let req = try JSONDecoder().decode(ImageRequest.self, from: json)
        XCTAssertEqual(req.background, "transparent")
        XCTAssertEqual(req.seed, 7)
        XCTAssertEqual(req.cfgScale, 3.0)
    }
}
