// TTSContractTests — the TTS request contract on POST /qai/v1/audio/tts, and
// the voice catalogue on GET /qai/v1/voices.
//
// Gemini exposes no parameters for tone, accent or pace — the steering is
// prose in `instructions` plus inline tags inside `text` — so these tests pin
// the field names the handler actually decodes. Source of truth: backend
// internal/server/routes_media.go (ttsRequest, ttsVoiceSettings, ttsSpeaker)
// and internal/server/routes_voice.go (voiceResponse).
//
// Copyright (c) 2025-2026 Quantum Encoding Ltd

import XCTest
@testable import QuantumSDK

final class TTSContractTests: XCTestCase {
    private func encoded(_ request: TtsRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: the house voice

    /// The gateway supplies gemini-3.1-flash-tts-preview + Laomedeia when the
    /// request names neither. An empty model must be OMITTED, not sent —
    /// "model": "" pins the request to a model that does not exist.
    func testTextAloneIsACompleteRequest() throws {
        let body = try encoded(TtsRequest(text: "Hello"))

        XCTAssertEqual(body["text"] as? String, "Hello")
        XCTAssertNil(body["model"], "an empty model was sent")
        XCTAssertNil(body["voice"])
        XCTAssertNil(body["speakers"])
        XCTAssertNil(body["voice_settings"])
        XCTAssertNil(body["instructions"])
    }

    // MARK: steering

    func testSteeringFieldsUseTheWireNames() throws {
        let body = try encoded(TtsRequest(
            model: "gemini-3.1-flash-tts-preview",
            text: "[excited] Hi! [whispers] can you keep a secret?",
            voice: "Laomedeia",
            outputFormat: "wav",
            speed: 1.1,
            instructions: "Read aloud with a natural British accent",
            language: "en-GB",
            sampleRate: 24000,
            bitRate: 128_000
        ))

        XCTAssertEqual(body["model"] as? String, "gemini-3.1-flash-tts-preview")
        XCTAssertEqual(body["voice"] as? String, "Laomedeia")
        // outputFormat rides as "format" — the handler reads no other key.
        XCTAssertEqual(body["format"] as? String, "wav")
        XCTAssertNil(body["outputFormat"])
        XCTAssertEqual(body["speed"] as? Double, 1.1)
        XCTAssertEqual(body["instructions"] as? String, "Read aloud with a natural British accent")
        XCTAssertEqual(body["language"] as? String, "en-GB")
        XCTAssertEqual(body["sample_rate"] as? Int, 24000)
        XCTAssertEqual(body["bit_rate"] as? Int, 128_000)
    }

    // MARK: dialogue

    /// Two speakers, labelled to match the lines the text carries.
    func testTwoSpeakerDialogue() throws {
        let body = try encoded(TtsRequest(
            text: "Lacey: Hi there.\nCustomer: [excited] Hi!",
            instructions: "Lacey is calm; the customer is cheerful",
            speakers: [
                TTSSpeaker(name: "Lacey", voice: "Laomedeia"),
                TTSSpeaker(name: "Customer", voice: "Puck"),
            ]
        ))

        let speakers = try XCTUnwrap(body["speakers"] as? [[String: Any]])
        XCTAssertEqual(speakers.count, 2, "gemini takes exactly two speakers")
        XCTAssertEqual(speakers[0]["name"] as? String, "Lacey")
        XCTAssertEqual(speakers[0]["voice"] as? String, "Laomedeia")
        XCTAssertEqual(speakers[1]["name"] as? String, "Customer")
        XCTAssertEqual(speakers[1]["voice"] as? String, "Puck")
    }

    // MARK: ElevenLabs tuning

    /// 0.0 stability is a real setting the provider honours, so a zeroed
    /// object silently retunes the voice rather than leaving the default.
    func testVoiceSettingsOmitWhatWasNotSet() throws {
        let body = try encoded(TtsRequest(
            text: "hi",
            voiceSettings: TTSVoiceSettings(stability: 0.4, useSpeakerBoost: true)
        ))

        let vs = try XCTUnwrap(body["voice_settings"] as? [String: Any])
        XCTAssertEqual(vs["stability"] as? Double, 0.4)
        XCTAssertEqual(vs["use_speaker_boost"] as? Bool, true)
        XCTAssertNil(vs["similarity_boost"], "an unset knob was sent as zero")
        XCTAssertNil(vs["style"], "an unset knob was sent as zero")
    }

    // MARK: round trip

    /// A request decodes back into the same shape, including an absent model.
    func testRequestRoundTrips() throws {
        let json = """
        {"text":"hi","format":"wav","language":"en-GB","sample_rate":24000,
         "bit_rate":128000,"speakers":[{"name":"A","voice":"Puck"},
         {"name":"B","voice":"Kore"}]}
        """
        let req = try JSONDecoder().decode(TtsRequest.self, from: Data(json.utf8))

        XCTAssertEqual(req.model, "", "an absent model decodes as empty, not a failure")
        XCTAssertEqual(req.outputFormat, "wav")
        XCTAssertEqual(req.language, "en-GB")
        XCTAssertEqual(req.sampleRate, 24000)
        XCTAssertEqual(req.bitRate, 128_000)
        XCTAssertEqual(req.speakers?.count, 2)
        XCTAssertEqual(req.speakers?[0].voice, "Puck")
    }

    // MARK: the voice catalogue

    func testVoiceListingDecodesEveryDocumentedField() throws {
        let json = """
        {"voices":[
          {"voice_id":"Laomedeia","name":"Laomedeia","category":"premade",
           "provider":"gemini","model":"gemini-3.1-flash-tts-preview","is_cloned":false},
          {"voice_id":"el_7f3","name":"Rachel","category":"cloned",
           "provider":"elevenlabs","model":"eleven_multilingual_v2","is_cloned":true,
           "description":"warm narrator","preview_url":"https://cdn/x.mp3"}
        ],"request_id":"qai_req_1"}
        """
        let resp = try JSONDecoder().decode(VoicesResponse.self, from: Data(json.utf8))
        XCTAssertEqual(resp.voices.count, 2)

        let gemini = resp.voices[0]
        XCTAssertEqual(gemini.voiceId, "Laomedeia")
        XCTAssertEqual(gemini.provider, "gemini")
        // The model to pass back to speak() for this voice, so a picker never
        // hardcodes the provider-to-model mapping.
        XCTAssertEqual(gemini.model, "gemini-3.1-flash-tts-preview")

        let el = resp.voices[1]
        XCTAssertEqual(el.category, "cloned")
        XCTAssertEqual(el.provider, "elevenlabs")
    }
}
