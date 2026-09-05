import XCTest
@testable import QuantumSDK

/// Code scanner shapes (internal/scanner/types.go, routes_scanner.go).
final class AgentsScannerTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testScanRequestOmitsUnsetOptions() throws {
        let json = try encodeToObject(ScanRequest(source: "https://github.com/quantum-encoding/quantum-sdk-rs", includeCallGraph: true))
        XCTAssertEqual(json["include_call_graph"] as? Bool, true)
        XCTAssertNil(json["branch"])
        XCTAssertNil(json["languages"])
        XCTAssertEqual(Set(json.keys), ["source", "include_call_graph"])
    }

    func testDiffRequestRenamesScanIdsToBaseAndTarget() throws {
        let json = try encodeToObject(DiffRequest(baseScanId: "scan_a", targetScanId: "scan_b"))
        XCTAssertEqual(json["base"] as? String, "scan_a")
        XCTAssertEqual(json["target"] as? String, "scan_b")
        XCTAssertNil(json["base_scan_id"])
        XCTAssertNil(json["base_graph"])
        XCTAssertEqual(Set(json.keys), ["base", "target"])
    }

    func testVerifyRequestKeys() throws {
        let blueprint = Blueprint(name: "sdk", types: [BlueprintType(name: "ChatRequest", fields: [CodeField(name: "model", type: "String")])])
        let json = try encodeToObject(VerifyRequest(blueprint: blueprint, scanId: "s1"))
        XCTAssertEqual(Set(json.keys), ["blueprint", "scan_id"])
        let blueprintJSON = try XCTUnwrap(json["blueprint"] as? [String: Any])
        XCTAssertEqual(Set(blueprintJSON.keys), ["name", "types"])
    }

    func testVulnerabilityRequestKeys() throws {
        let json = try encodeToObject(VulnerabilityScanRequest(source: "https://github.com/o/r", options: VulnerabilityScanOptions(cveCheck: true)))
        XCTAssertEqual((json["options"] as? [String: Any])?["cve_check"] as? Bool, true)
        XCTAssertEqual(Set(json.keys), ["source", "options"])
    }

    func testDiffResultDecodesMissingFieldMap() throws {
        let fixture = """
        {"base":"rust","target":"go","missing_types":["ChatUsage"],
         "extra_types":null,"missing_fields":{"ChatRequest":["region"]},
         "completion":0.75,"total_gaps":2}
        """
        let result = try JSONDecoder().decode(DiffResult.self, from: Data(fixture.utf8))
        XCTAssertEqual(result.missingTypes, ["ChatUsage"])
        XCTAssertTrue(result.extraTypes.isEmpty)
        XCTAssertEqual(result.missingFields["ChatRequest"], ["region"])
        XCTAssertEqual(result.totalGaps, 2)
    }

    func testTypeDetailReadsTheReservedTypeKey() throws {
        let fixture = """
        {"type":{"name":"ChatRequest","kind":"struct","file":"src/chat.rs",
                 "fields":[{"name":"model","type":"String","optional":false}]},
         "methods":null,"references":null,"scan_id":"s1","scan_name":"rust"}
        """
        let detail = try JSONDecoder().decode(ScanTypeDetail.self, from: Data(fixture.utf8))
        XCTAssertEqual(detail.codeType.name, "ChatRequest")
        XCTAssertEqual(detail.codeType.fields[0].type, "String")
        XCTAssertTrue(detail.methods.isEmpty)
    }

    func testScanResultAndListShapes() throws {
        let fixture = """
        {"scan_id":"s1","name":"rust","source":"https://github.com/o/r",
         "stats":{"files":3,"types":5,"fields":12,"functions":7,"call_edges":0,"modules":3},
         "graph":{"modules":[{"path":"src/lib.rs","language":"rust","lines":40}],"types":[],"functions":[]},
         "created_at":"2026-01-01T00:00:00Z"}
        """
        let scan = try JSONDecoder().decode(ScanResult.self, from: Data(fixture.utf8))
        XCTAssertEqual(scan.stats?.types, 5)
        XCTAssertEqual(scan.graph?.modules[0].language, "rust")
        XCTAssertTrue(scan.graph?.callEdges.isEmpty ?? false)

        let list = try JSONDecoder().decode(ScanListResponse.self, from: Data(#"{"scans":null,"request_id":"r"}"#.utf8))
        XCTAssertTrue(list.scans.isEmpty)

        let types = try JSONDecoder().decode(ScanTypeListResponse.self, from: Data("""
        {"types":[{"name":"A","kind":"struct","file":"a.go","field_count":2,"visibility":"public"}],
         "count":1,"scan_id":"s1","scan_name":"rust","request_id":"r"}
        """.utf8))
        XCTAssertEqual(types.types[0].fieldCount, 2)

        let deleted = try JSONDecoder().decode(ScanDeleteResponse.self, from: Data(#"{"deleted":true,"scan_id":"s1","request_id":"r"}"#.utf8))
        XCTAssertTrue(deleted.deleted)
    }

    func testAuditShapes() throws {
        let accepted = try JSONDecoder().decode(AuditJobResponse.self, from: Data("""
        {"job_id":"j1","profile":"security-redteam","model":"claude-sonnet-4-6","files_to_analyze":12,"estimated_cost":"$0.42"}
        """.utf8))
        XCTAssertEqual(accepted.jobId, "j1")
        XCTAssertEqual(accepted.filesToAnalyze, 12)

        let result = try JSONDecoder().decode(AuditResult.self, from: Data("""
        {"profile":"security-redteam","model":"m","files_analyzed":11,"files_errored":1,
         "total_tokens_in":100,"total_tokens_out":50,"duration_seconds":12.5,"cost_usd":0.4,
         "files":[{"path":"a.go","language":"go","tokens_in":10,"tokens_out":5,"findings":"ok"}]}
        """.utf8))
        XCTAssertEqual(result.files[0].findings, "ok")
        XCTAssertEqual(result.filesErrored, 1)
    }

    func testVerifyResultDecodesNullLists() throws {
        let result = try JSONDecoder().decode(VerifyResult.self, from: Data("""
        {"passed":false,"completion":0.5,"missing_types":["X"],"missing_fields":null,
         "missing_functions":null,"missing_modules":null,"file_status":[{"path":"a.go","exists":true,"complete":false}]}
        """.utf8))
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.missingFields.isEmpty)
        XCTAssertEqual(result.fileStatus[0].complete, false)
    }
}
