import XCTest
@testable import QuantumSDK

/// Security routes (routes_security.go, injection/scanner.go): the strict
/// query encoding that keeps a checked URL whole, and the two blocklist
/// entry shapes.
final class AgentsSecurityTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Strict URL encoding

    func testStrictEncodingEscapesEveryReservedCharacter() {
        let raw = "https://evil.example/page?b=1&c=2#frag+x y/z"
        let encoded = raw.strictQueryEncoded
        for forbidden in ["&", "=", "?", "/", "#", "+", " ", ":"] {
            XCTAssertFalse(encoded.contains(forbidden), "\(forbidden) must be escaped, got \(encoded)")
        }
        XCTAssertEqual(encoded, "https%3A%2F%2Fevil.example%2Fpage%3Fb%3D1%26c%3D2%23frag%2Bx%20y%2Fz")
        XCTAssertEqual(encoded.removingPercentEncoding, raw)
    }

    func testStrictEncodingLeavesUnreservedCharactersAlone() {
        XCTAssertEqual("abc-XYZ_0.9~".strictQueryEncoded, "abc-XYZ_0.9~")
    }

    func testCheckedUrlSurvivesAsOneQueryParameter() throws {
        let raw = "https://evil.example/page?b=1&c=2"
        let path = QuantumClient.securityCheckPath(url: raw)
        let components = try XCTUnwrap(URLComponents(string: "https://gateway.test" + path))
        let items = try XCTUnwrap(components.queryItems)
        XCTAssertEqual(items.count, 1, "the URL's own query must not become extra parameters")
        XCTAssertEqual(items[0].name, "url")
        XCTAssertEqual(items[0].value, raw)
    }

    func testStatusFilterIsEncoded() {
        XCTAssertEqual("a b&c".strictQueryEncoded, "a%20b%26c")
    }

    // MARK: - Requests

    func testScanCodeRequestSendsOnlySetFields() throws {
        let json = try encodeToObject(SecurityScanCodeRequest(code: "eval(x)", filename: "a.py"))
        XCTAssertEqual(Set(json.keys), ["code", "filename"])
        let repo = try encodeToObject(SecurityScanCodeRequest(url: "https://github.com/o/r", branch: "main", path: "src"))
        XCTAssertEqual(Set(repo.keys), ["url", "branch", "path"])
    }

    // MARK: - Responses

    func testCleanPageWithNullFindingsDecodes() throws {
        let fixture = """
        {"assessment":{"url":"https://ok.example","threat_level":"none","threat_score":0,
                       "findings":null,"hidden_text_length":0,"visible_text_length":0,
                       "hidden_ratio":0,"summary":"No injection patterns detected"},
         "request_id":"req_1"}
        """
        let response = try JSONDecoder().decode(SecurityScanResponse.self, from: Data(fixture.utf8))
        XCTAssertTrue(response.assessment.findings.isEmpty)
        XCTAssertEqual(response.assessment.threatLevel, "none")
    }

    func testBlocklistDecodesBothEntryShapes() throws {
        // First entry: written by a scan. Second: created by a community report.
        let fixture = """
        {"entries":[
          {"id":"a","url":"https://bad.example","status":"confirmed","threat_level":"high","threat_score":72.5,
           "categories":["instruction_override"],"findings_count":3,"hidden_ratio":0.4,
           "first_seen":"2026-01-01T00:00:00Z","summary":"3 findings"},
          {"id":"b","url":"https://sus.example","status":"suspected","threat_level":"unknown","threat_score":0,
           "report_count":1,"first_seen":"2026-01-02T00:00:00Z","last_seen":"2026-01-02T00:00:00Z",
           "reported_by":"u1","description":"looks off","category":"phishing"}],
         "count":2,"status":"all"}
        """
        let response = try JSONDecoder().decode(SecurityBlocklistResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response.entries[0].categories, ["instruction_override"])
        XCTAssertEqual(response.entries[0].findingsCount, 3)
        XCTAssertEqual(response.entries[1].status, "suspected")
        XCTAssertTrue(response.entries[1].categories.isEmpty)
        XCTAssertNil(response.entries[1].summary)
        XCTAssertNil(response.entries[1].findingsCount)
    }

    func testCodeScanReportDecodesNullCollections() throws {
        let fixture = """
        {"path":"a.py","files_scanned":1,"findings":null,"summary":null,"categories":{"injection":1},"score":92.5}
        """
        let report = try JSONDecoder().decode(CodeScanReport.self, from: Data(fixture.utf8))
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertTrue(report.summary.isEmpty)
        XCTAssertEqual(report.categories["injection"], 1)
        XCTAssertEqual(report.score, 92.5)
    }

    func testCheckResponseDecodesBothBranches() throws {
        let blocked = try JSONDecoder().decode(SecurityCheckResponse.self, from: Data("""
        {"url":"https://bad.example","blocked":true,"threat_level":"high","threat_score":72.5,
         "categories":["hidden_text"],"first_seen":"2026-01-01T00:00:00Z","last_seen":"2026-01-01T00:00:00Z",
         "report_count":2,"status":"confirmed"}
        """.utf8))
        XCTAssertTrue(blocked.blocked)
        XCTAssertEqual(blocked.reportCount, 2)

        let clean = try JSONDecoder().decode(SecurityCheckResponse.self, from: Data(
            #"{"url":"https://ok.example","blocked":false,"message":"URL not in registry"}"#.utf8
        ))
        XCTAssertFalse(clean.blocked)
        XCTAssertNil(clean.threatLevel)
    }
}
