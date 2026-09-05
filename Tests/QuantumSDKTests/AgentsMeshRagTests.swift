import XCTest
@testable import QuantumSDK

/// Meshy job params (meshy.go), RAG responses (routes_rag*.go) and the
/// collection proxy (routes_rag_collections.go, ragproxy/store.go).
final class AgentsMeshRagTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Mesh

    func testRetextureSendsTheStyleKeysMeshyReads() throws {
        let json = try encodeToObject(RetextureRequest(inputTaskId: "task_1", textStylePrompt: "weathered bronze", enablePbr: true))
        XCTAssertEqual(json["input_task_id"] as? String, "task_1")
        XCTAssertEqual(json["text_style_prompt"] as? String, "weathered bronze")
        XCTAssertEqual(json["enable_pbr"] as? Bool, true)
        XCTAssertNil(json["prompt"])
        XCTAssertNil(json["image_style_url"])
        XCTAssertEqual(Set(json.keys), ["input_task_id", "text_style_prompt", "enable_pbr"])
    }

    func testRigRequestCarriesTextureImage() throws {
        let json = try encodeToObject(RigRequest(modelUrl: "https://x/m.glb", heightMeters: 1.8, textureImageUrl: "https://x/t.png"))
        XCTAssertEqual(Set(json.keys), ["model_url", "height_meters", "texture_image_url"])
    }

    func testRigOutputDecodesFromTheJobResult() throws {
        let fixture = """
        {"job_id":"j1","status":"completed","type":"3d/rig",
         "result":{"result":{"rigged_character_fbx_url":"https://x/rig.fbx",
                             "rigged_character_glb_url":"https://x/rig.glb",
                             "basic_animations":{"walking_glb_url":"https://x/walk.glb",
                                                 "walking_fbx_url":"https://x/walk.fbx",
                                                 "walking_armature_glb_url":"https://x/walk-arm.glb",
                                                 "running_glb_url":"https://x/run.glb",
                                                 "running_fbx_url":"https://x/run.fbx",
                                                 "running_armature_glb_url":"https://x/run-arm.glb"}},
                   "task_id":"m1","cost_ticks":10,"request_id":"r1"},
         "cost_ticks":10}
        """
        let job = try JSONDecoder().decode(JobStatusResponse.self, from: Data(fixture.utf8))
        let output = try XCTUnwrap(try RigOutput.from(job: job))
        XCTAssertEqual(output.riggedCharacterGlbUrl, "https://x/rig.glb")
        XCTAssertEqual(output.basicAnimations?.walkingGlbUrl, "https://x/walk.glb")
        XCTAssertEqual(output.basicAnimations?.runningArmatureGlbUrl, "https://x/run-arm.glb")
    }

    func testRigOutputIsNilWithoutAResult() throws {
        let job = try JSONDecoder().decode(JobStatusResponse.self, from: Data(#"{"job_id":"j1","status":"failed","error":"x"}"#.utf8))
        XCTAssertNil(try RigOutput.from(job: job))
    }

    // MARK: - RAG

    func testVertexSearchDecodesANullResultList() throws {
        let response = try JSONDecoder().decode(RagSearchResponse.self, from: Data(
            #"{"results":null,"query":"billing","corpora":["docs"],"cost_ticks":0,"request_id":"req_1"}"#.utf8
        ))
        XCTAssertTrue(response.results.isEmpty)
        XCTAssertEqual(response.corpora?.count, 1)
    }

    func testVertexSearchDecodesTheHandlerResultShape() throws {
        let response = try JSONDecoder().decode(RagSearchResponse.self, from: Data("""
        {"results":[{"source_uri":"gs://b/f.md","source_name":"f.md","text":"ticks","score":0.8,"distance":0.2}],
         "query":"billing","corpora":null,"cost_ticks":5,"request_id":"req_1"}
        """.utf8))
        XCTAssertEqual(response.results[0].sourceName, "f.md")
        XCTAssertNil(response.corpora)
    }

    func testCorporaDecodesNull() throws {
        let response = try JSONDecoder().decode(RagCorporaResponse.self, from: Data(#"{"corpora":null,"request_id":"r"}"#.utf8))
        XCTAssertTrue(response.corpora.isEmpty)
    }

    func testSurrealSearchDecodesNullAndRowsWithoutTitle() throws {
        let empty = try JSONDecoder().decode(SurrealRagSearchResponse.self, from: Data(
            #"{"results":null,"query":"q","cost_ticks":0,"request_id":"req_2"}"#.utf8
        ))
        XCTAssertTrue(empty.results.isEmpty)
        XCTAssertNil(empty.provider)

        let hits = try JSONDecoder().decode(SurrealRagSearchResponse.self, from: Data("""
        {"results":[{"provider":"xai","source_file":"chat.md","content":"stream=true","score":0.91}],
         "query":"streaming","provider":"xai","cost_ticks":3,"request_id":"req_3"}
        """.utf8))
        XCTAssertEqual(hits.results[0].provider, "xai")
        XCTAssertNil(hits.results[0].title)
        XCTAssertEqual(hits.results[0].content, "stream=true")
    }

    func testSurrealProvidersReadTheChunksKeyAndANullList() throws {
        let response = try JSONDecoder().decode(SurrealRagProvidersResponse.self, from: Data(
            #"{"providers":[{"provider":"xai","chunks":412}],"request_id":"req_4"}"#.utf8
        ))
        XCTAssertEqual(response.providers[0].chunks, 412)

        let empty = try JSONDecoder().decode(SurrealRagProvidersResponse.self, from: Data(#"{"providers":null,"request_id":"req_5"}"#.utf8))
        XCTAssertTrue(empty.providers.isEmpty)
    }

    // MARK: - Collections

    func testSearchRequestOmitsAnEmptyCollectionFilterAndSendsMaxChunks() throws {
        let json = try encodeToObject(CollectionSearchRequest(query: "how does billing work", maxChunks: 5))
        XCTAssertEqual(json["max_chunks"] as? Int, 5)
        XCTAssertNil(json["collection_ids"])
        XCTAssertNil(json["mode"])
        XCTAssertNil(json["max_results"])
        XCTAssertEqual(Set(json.keys), ["query", "max_chunks"])

        let filtered = try encodeToObject(CollectionSearchRequest(query: "q", collectionIds: ["c1"]))
        XCTAssertEqual(filtered["collection_ids"] as? [String], ["c1"])
    }

    func testCreateRequestKeys() throws {
        let json = try encodeToObject(CreateCollectionRequest(name: "docs", description: "d"))
        XCTAssertEqual(Set(json.keys), ["name", "description"])
    }

    func testSearchResultsCarryTheCollectionTheyCameFrom() throws {
        let response = try JSONDecoder().decode(CollectionSearchResponse.self, from: Data("""
        {"results":[{"content":"ticks are 1e-10 USD","score":0.91,"collection":"docs","collection_id":"c1",
                     "document_id":"d1","filename":"billing.md","is_shared":true}],
         "query":"billing","collections_searched":2,"request_id":"req_1"}
        """.utf8))
        XCTAssertEqual(response.collectionsSearched, 2)
        XCTAssertEqual(response.results[0].collection, "docs")
        XCTAssertEqual(response.results[0].isShared, true)
    }

    func testCollectionDetailDecodesANullDocumentList() throws {
        let detail = try JSONDecoder().decode(CollectionDetail.self, from: Data("""
        {"collection":{"id":"c1","owner":"u1","provider":"xai","name":"docs","description":"",
                       "provider_collection_id":"xc1","document_count":0,"created_at":"2026-01-01T00:00:00Z"},
         "documents":null}
        """.utf8))
        XCTAssertEqual(detail.collection.providerCollectionId, "xc1")
        XCTAssertTrue(detail.documents.isEmpty)
    }

    func testListDecodesNullCollections() throws {
        let list = try JSONDecoder().decode(CollectionsListResponse.self, from: Data(#"{"collections":null,"request_id":"r"}"#.utf8))
        XCTAssertTrue(list.collections.isEmpty)
    }

    func testUploadResultDecodesTheDocumentRecord() throws {
        let document = try JSONDecoder().decode(CollectionUploadResult.self, from: Data("""
        {"id":"d1","collection_id":"c1","file_id":"file_9","filename":"spec.pdf",
         "status":"indexed","chunks":12,"uploaded_at":"2026-01-01T00:00:00Z"}
        """.utf8))
        XCTAssertEqual(document.filename, "spec.pdf")
        XCTAssertEqual(document.status, "indexed")
        XCTAssertEqual(document.chunks, 12)
    }

    func testDeleteResponse() throws {
        let response = try JSONDecoder().decode(DeleteCollectionResponse.self, from: Data(#"{"deleted":true,"id":"c1"}"#.utf8))
        XCTAssertTrue(response.deleted)
        XCTAssertEqual(response.id, "c1")
    }
}
