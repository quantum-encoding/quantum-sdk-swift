import XCTest
@testable import QuantumSDK

/// The catalog-parameter escape hatch on `ImageRequest` and `VideoRequest`.
/// The reference SDK flattens a map into the top-level body with
/// `#[serde(flatten)]`; these assert the Swift equivalent puts the parameters
/// where the gateway reads them and gives them back on the way in.
final class FlattenedExtraTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Encoding flattens rather than nesting

    func testImageExtraLandsBesideTheTypedKeys() throws {
        let obj = try encodeToObject(ImageRequest(
            model: "gpt-image-1",
            prompt: "a cat",
            extra: [
                "negative_prompt": AnyCodable("blurry"),
                "person_generation": AnyCodable("allow_adult"),
                "number_of_images": AnyCodable(3),
            ]
        ))
        // Nested under an "extra" key the gateway would never read.
        XCTAssertNil(obj["extra"])
        XCTAssertEqual(obj["negative_prompt"] as? String, "blurry")
        XCTAssertEqual(obj["person_generation"] as? String, "allow_adult")
        XCTAssertEqual(obj["number_of_images"] as? Int, 3)
        XCTAssertEqual(obj["model"] as? String, "gpt-image-1")
        XCTAssertEqual(obj["prompt"] as? String, "a cat")
    }

    func testVideoExtraLandsBesideTheTypedKeys() throws {
        let obj = try encodeToObject(VideoRequest(
            model: "veo-2",
            prompt: "a duck in orbit",
            durationSeconds: 8,
            extra: ["generate_audio": AnyCodable(true), "resolution": AnyCodable("1080p")]
        ))
        XCTAssertNil(obj["extra"])
        XCTAssertEqual(obj["generate_audio"] as? Bool, true)
        XCTAssertEqual(obj["resolution"] as? String, "1080p")
        XCTAssertEqual(obj["duration_seconds"] as? Int, 8)
        XCTAssertNil(obj["aspect_ratio"])
    }

    func testAnEmptyExtraEncodesNothing() throws {
        // A caller that never sets extra sends a body identical to the one
        // this type produced before the field existed.
        XCTAssertEqual(
            try encodeToObject(ImageRequest(model: "m", prompt: "p")).keys.sorted(),
            ["model", "prompt"]
        )
        XCTAssertEqual(
            try encodeToObject(VideoRequest(model: "m", prompt: "p")).keys.sorted(),
            ["model", "prompt"]
        )
    }

    // MARK: - Decoding collects what has no typed field

    func testUnknownKeysDecodeIntoExtra() throws {
        let json = #"{"model":"m","prompt":"p","negative_prompt":"blurry","output_compression":80}"#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ImageRequest.self, from: json)
        XCTAssertEqual(req.model, "m")
        XCTAssertEqual(req.compression, 80, "a typed field still decodes into its own property")
        XCTAssertEqual(req.extra["negative_prompt"]?.value as? String, "blurry")
        XCTAssertNil(req.extra["output_compression"], "a typed key is not also collected as extra")
        XCTAssertNil(req.extra["prompt"])
    }

    func testExtraSurvivesARoundTrip() throws {
        let json = #"{"model":"veo-2","prompt":"p","sample_count":4}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VideoRequest.self, from: json)
        XCTAssertEqual(decoded.extra["sample_count"]?.value as? Int, 4)

        let reencoded = try encodeToObject(decoded)
        XCTAssertEqual(reencoded["sample_count"] as? Int, 4)
        XCTAssertEqual(reencoded["model"] as? String, "veo-2")
        XCTAssertNil(reencoded["extra"])
    }
}
