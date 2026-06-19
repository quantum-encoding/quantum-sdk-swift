import XCTest
@testable import QuantumSDK

/// Verifies the wire encoding of TtsRequest — specifically that the newly
/// wired-through `instructions` (voice steering) param serializes to the exact
/// JSON key the backend expects, and is OMITTED entirely when nil (so existing
/// requests that don't set it are byte-for-byte unchanged).
final class TtsRequestEncodingTests: XCTestCase {

    private func encodeToObject(_ req: TtsRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    func testInstructionsEncodesWhenSet() throws {
        let req = TtsRequest(
            model: "gpt-4o-mini-tts",
            text: "Hello there.",
            voice: "alloy",
            instructions: "Speak in a cheerful, theatrical British accent"
        )
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["instructions"] as? String, "Speak in a cheerful, theatrical British accent")
    }

    func testInstructionsOmittedWhenNil() throws {
        let req = TtsRequest(model: "tts-1", text: "Hello there.", voice: "alloy")
        let obj = try encodeToObject(req)
        XCTAssertNil(obj["instructions"], "instructions must be absent (not null) when nil")
        XCTAssertFalse(obj.keys.contains("instructions"))
    }

    func testMinimalRequestUnchanged() throws {
        // A request built the old way (model/text only) must encode exactly
        // those keys and nothing new.
        let req = TtsRequest(model: "tts-1", text: "duck")
        let obj = try encodeToObject(req)
        XCTAssertEqual(Set(obj.keys), ["model", "text"])
    }

    func testOutputFormatStillSnakeCasesToFormat() throws {
        // Pre-existing CodingKey mapping (outputFormat -> "format") must survive
        // the addition of `instructions`.
        let req = TtsRequest(model: "gpt-4o-mini-tts", text: "x", outputFormat: "wav", instructions: "calm")
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["format"] as? String, "wav")
        XCTAssertNil(obj["outputFormat"])
        XCTAssertEqual(obj["instructions"] as? String, "calm")
    }

    func testRoundTripDecode() throws {
        let json = """
        {"model":"gpt-4o-mini-tts","text":"x","voice":"alloy","instructions":"whisper softly"}
        """.data(using: .utf8)!
        let req = try JSONDecoder().decode(TtsRequest.self, from: json)
        XCTAssertEqual(req.instructions, "whisper softly")
        XCTAssertEqual(req.voice, "alloy")
    }
}
