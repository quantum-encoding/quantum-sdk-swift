import XCTest
@testable import QuantumSDK

/// Verifies the wire encoding of the HeyGen v3 request models — exact
/// snake_case keys per the gateway contract, and omission (not null) of
/// unset optionals so bodies match the backend's expectations byte-for-byte.
final class HeyGenV3EncodingTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    // MARK: - AvatarRealtimeRequest

    func testRealtimeCreateRequestOmitsEmptyOptionals() throws {
        let req = AvatarRealtimeRequest(
            sessionType: "tts",
            avatarId: "av_1",
            maxDurationSeconds: 60,
            voiceId: "v_1",
            text: "Hello"
        )
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["type"] as? String, "tts")
        XCTAssertEqual(obj["avatar_id"] as? String, "av_1")
        XCTAssertEqual(obj["voice_id"] as? String, "v_1")
        XCTAssertEqual(obj["text"] as? String, "Hello")
        XCTAssertEqual(obj["max_duration_seconds"] as? Int, 60)
        XCTAssertFalse(obj.keys.contains("audio"), "audio must be absent for tts sessions")
        XCTAssertEqual(
            Set(obj.keys),
            ["type", "avatar_id", "voice_id", "text", "max_duration_seconds"]
        )
    }

    func testRealtimeCreateRequestAudioUnion() throws {
        let req = AvatarRealtimeRequest(
            sessionType: "audio",
            avatarId: "av_1",
            maxDurationSeconds: 120,
            audio: AvatarAudioInput(inputType: "base64", mediaType: "audio/mpeg", data: "AQID")
        )
        let obj = try encodeToObject(req)
        XCTAssertFalse(obj.keys.contains("voice_id"), "voice_id must be absent for audio sessions")
        XCTAssertFalse(obj.keys.contains("text"))
        let audio = obj["audio"] as? [String: Any]
        XCTAssertEqual(audio?["type"] as? String, "base64")
        XCTAssertEqual(audio?["media_type"] as? String, "audio/mpeg")
        XCTAssertEqual(audio?["data"] as? String, "AQID")
        XCTAssertNil(audio?["url"])
        XCTAssertNil(audio?["asset_id"])
    }

    // MARK: - AvatarRealtimeTextRequest

    func testTextRequestDeltaSerialization() throws {
        let obj = try encodeToObject(AvatarRealtimeTextRequest.delta(" more"))
        XCTAssertEqual(obj["delta"] as? String, " more")
        XCTAssertEqual(obj["final"] as? Bool, false)
    }

    func testTextRequestFinalMarkerOmitsEmptyDelta() throws {
        let obj = try encodeToObject(AvatarRealtimeTextRequest.finalMarker())
        XCTAssertFalse(obj.keys.contains("delta"), "empty delta must be omitted entirely")
        XCTAssertEqual(obj["final"] as? Bool, true)
    }

    // MARK: - VideoTemplateGenerateRequest

    func testTemplateGenerateMinimalEncodesOnlyVariables() throws {
        let req = VideoTemplateGenerateRequest(
            variables: ["headline": AnyCodable(["type": "text", "content": "New!"])]
        )
        let obj = try encodeToObject(req)
        XCTAssertEqual(Set(obj.keys), ["variables"])
        let headline = (obj["variables"] as? [String: Any])?["headline"] as? [String: Any]
        XCTAssertEqual(headline?["type"] as? String, "text")
        XCTAssertEqual(headline?["content"] as? String, "New!")
    }

    func testTemplateGenerateFullFieldKeys() throws {
        let req = VideoTemplateGenerateRequest(
            variables: ["headline": AnyCodable(["type": "text", "content": "x"])],
            title: "Launch",
            sceneIds: ["scene_1", "scene_1"],
            dimension: VideoTemplateDimension(width: 1920, height: 1080),
            fps: 30,
            caption: true,
            subtitles: VideoTemplateSubtitles(
                presetName: "classic",
                alignment: 2,
                disableHighlight: true,
                fontSize: 24,
                position: VideoSubtitlePosition(x: 0.5, y: 0.9)
            ),
            reorderMusic: false,
            keepTextVerticallyCentered: true,
            includeGif: true,
            enableSharing: true,
            folderId: "f_1",
            brandVoiceId: "bv_1"
        )
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["title"] as? String, "Launch")
        XCTAssertEqual(obj["scene_ids"] as? [String], ["scene_1", "scene_1"])
        let dim = obj["dimension"] as? [String: Any]
        XCTAssertEqual(dim?["width"] as? Int, 1920)
        XCTAssertEqual(dim?["height"] as? Int, 1080)
        XCTAssertEqual(obj["fps"] as? Int, 30)
        XCTAssertEqual(obj["caption"] as? Bool, true)
        let subs = obj["subtitles"] as? [String: Any]
        XCTAssertEqual(subs?["preset_name"] as? String, "classic")
        XCTAssertEqual(subs?["alignment"] as? Int, 2)
        XCTAssertEqual(subs?["disable_highlight"] as? Bool, true)
        XCTAssertEqual(subs?["font_size"] as? Int, 24)
        let pos = subs?["position"] as? [String: Any]
        XCTAssertEqual(pos?["x"] as? Double, 0.5)
        XCTAssertEqual(pos?["y"] as? Double, 0.9)
        XCTAssertEqual(obj["reorder_music"] as? Bool, false)
        XCTAssertEqual(obj["keep_text_vertically_centered"] as? Bool, true)
        XCTAssertEqual(obj["include_gif"] as? Bool, true)
        XCTAssertEqual(obj["enable_sharing"] as? Bool, true)
        XCTAssertEqual(obj["folder_id"] as? String, "f_1")
        XCTAssertEqual(obj["brand_voice_id"] as? String, "bv_1")
    }

    // MARK: - VideoBatchSubmitRequest

    func testBatchSubmitEncodesOpaqueVideos() throws {
        let req = VideoBatchSubmitRequest(
            videos: [
                AnyCodable([
                    "type": "avatar",
                    "avatar_id": "av_1",
                    "voice_id": "v_1",
                    "script": "Welcome!",
                ]),
                AnyCodable(["type": "cinematic_avatar", "avatar_id": ["look_1", "look_2"]]),
            ],
            title: "Onboarding videos"
        )
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["title"] as? String, "Onboarding videos")
        let videos = obj["videos"] as? [[String: Any]]
        XCTAssertEqual(videos?.count, 2)
        XCTAssertEqual(videos?[0]["type"] as? String, "avatar")
        XCTAssertEqual(videos?[0]["script"] as? String, "Welcome!")
        // cinematic_avatar carries avatar_id as an ARRAY — the opaque
        // passthrough must preserve per-variant field shapes verbatim.
        XCTAssertEqual(videos?[1]["avatar_id"] as? [String], ["look_1", "look_2"])
    }

    func testBatchSubmitOmitsNilTitle() throws {
        let req = VideoBatchSubmitRequest(videos: [AnyCodable(["type": "avatar"])])
        let obj = try encodeToObject(req)
        XCTAssertEqual(Set(obj.keys), ["videos"])
    }

    // MARK: - Response decode spot-checks (contract JSON)

    func testTemplateDetailVariableUnionRoundTrip() throws {
        let json = """
        {
          "template": {
            "id": "tmpl_5f0a",
            "name": "Product Launch",
            "aspect_ratio": "16:9",
            "variables": {
              "headline": { "type": "text", "content": "Default headline" },
              "presenter": { "type": "character", "character_id": "Abigail", "character_type": "avatar" }
            },
            "scenes": [
              {
                "scene_id": "scene_1",
                "script": "Introducing {{headline}}...",
                "variables": [ { "name": "headline", "variable_type": "text" } ]
              }
            ]
          },
          "request_id": "req_abc"
        }
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(VideoTemplateDetailResponse.self, from: json)
        XCTAssertEqual(resp.template.id, "tmpl_5f0a")
        XCTAssertEqual(resp.template.aspectRatio, "16:9")
        XCTAssertEqual(resp.requestId, "req_abc")
        let headline = resp.template.variables["headline"]?.value as? [String: Any]
        XCTAssertEqual(headline?["type"] as? String, "text")
        XCTAssertEqual(headline?["content"] as? String, "Default headline")
        XCTAssertEqual(resp.template.scenes.count, 1)
        XCTAssertEqual(resp.template.scenes[0].sceneId, "scene_1")
        XCTAssertEqual(resp.template.scenes[0].variables[0].name, "headline")
        XCTAssertEqual(resp.template.scenes[0].variables[0].variableType, "text")

        // Round-trip: a fetched variable union feeds straight back into a
        // generate request unchanged.
        let generate = VideoTemplateGenerateRequest(
            variables: ["headline": resp.template.variables["headline"]!]
        )
        let obj = try encodeToObject(generate)
        let sent = (obj["variables"] as? [String: Any])?["headline"] as? [String: Any]
        XCTAssertEqual(sent?["type"] as? String, "text")
        XCTAssertEqual(sent?["content"] as? String, "Default headline")
    }

    func testTextResponseDecodesFinalKey() throws {
        let json = """
        {"ok":true,"buffered_bytes":512,"final":false,"request_id":"req_1"}
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(AvatarRealtimeTextResponse.self, from: json)
        XCTAssertTrue(resp.ok)
        XCTAssertEqual(resp.bufferedBytes, 512)
        XCTAssertFalse(resp.isFinal)
        XCTAssertEqual(resp.requestId, "req_1")
    }
}
