import Foundation

// MARK: - Security Request Types

/// Request body for scanning a URL for prompt injection.
public struct SecurityScanURLRequest: Codable, Sendable {
    /// URL to scan.
    public var url: String

    public init(url: String) {
        self.url = url
    }
}

/// Request body for scanning raw HTML content.
public struct SecurityScanHTMLRequest: Codable, Sendable {
    /// Raw HTML to scan.
    public var html: String

    /// Rendered visible text (for structural analysis).
    public var visibleText: String?

    /// Source URL (for context).
    public var url: String?

    public init(html: String, visibleText: String? = nil, url: String? = nil) {
        self.html = html
        self.visibleText = visibleText
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case html, url
        case visibleText = "visible_text"
    }
}

/// Request body for `POST /qai/v1/security/scan-code`.
///
/// Two modes: set `code` (with `filename` so the language can be detected) to
/// scan one file, or set `url` to clone a git repository over HTTPS and scan a
/// tree. One of the two is required.
public struct SecurityScanCodeRequest: Codable, Sendable {
    /// Source of the single file to scan.
    public var code: String?

    /// Filename for `code`; the language is detected from its extension.
    public var filename: String?

    /// Language override, when the filename does not settle it.
    public var language: String?

    /// Git repository URL to clone (shallow) and scan instead of `code`. Any
    /// `https://` URL is accepted; only the scheme is checked.
    public var url: String?

    /// Branch to check out for `url`.
    public var branch: String?

    /// Subdirectory of the checkout to scan. Must be relative and stay inside
    /// the repository root.
    public var path: String?

    public init(
        code: String? = nil,
        filename: String? = nil,
        language: String? = nil,
        url: String? = nil,
        branch: String? = nil,
        path: String? = nil
    ) {
        self.code = code
        self.filename = filename
        self.language = language
        self.url = url
        self.branch = branch
        self.path = path
    }
}

/// Request body for reporting a suspicious URL.
public struct SecurityReportRequest: Codable, Sendable {
    /// URL to report.
    public var url: String

    /// Description of the suspected threat.
    public var description: String?

    /// Category of the suspected threat.
    public var category: String?

    public init(url: String, description: String? = nil, category: String? = nil) {
        self.url = url
        self.description = description
        self.category = category
    }
}

// MARK: - Security Response Types

/// Response from a security scan.
public struct SecurityScanResponse: Codable, Sendable {
    /// Full threat assessment.
    public var assessment: SecurityAssessment

    /// Request identifier.
    public var requestId: String

    public init(assessment: SecurityAssessment, requestId: String = "") {
        self.assessment = assessment
        self.requestId = requestId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assessment = try container.decode(SecurityAssessment.self, forKey: .assessment)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case assessment
        case requestId = "request_id"
    }
}

/// Threat assessment for a scanned page.
public struct SecurityAssessment: Codable, Sendable {
    /// Source URL.
    public var url: String

    /// Overall threat level: "none", "low", "medium", "high", "critical".
    public var threatLevel: String

    /// Numeric threat score (0.0 - 100.0).
    public var threatScore: Double

    /// Individual findings. Sent as `null` for a clean page.
    @NullToEmpty public var findings: [SecurityFinding]

    /// Length of hidden text content detected.
    public var hiddenTextLength: Int

    /// Length of visible text content. Always 0 for a URL scan, which
    /// fetches raw HTML only.
    public var visibleTextLength: Int

    /// Ratio of hidden to total content.
    public var hiddenRatio: Double

    /// Human-readable summary.
    public var summary: String

    public init(
        url: String = "",
        threatLevel: String = "",
        threatScore: Double = 0,
        findings: [SecurityFinding] = [],
        hiddenTextLength: Int = 0,
        visibleTextLength: Int = 0,
        hiddenRatio: Double = 0,
        summary: String = ""
    ) {
        self.url = url
        self.threatLevel = threatLevel
        self.threatScore = threatScore
        self.findings = findings
        self.hiddenTextLength = hiddenTextLength
        self.visibleTextLength = visibleTextLength
        self.hiddenRatio = hiddenRatio
        self.summary = summary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        threatLevel = try container.decodeIfPresent(String.self, forKey: .threatLevel) ?? ""
        threatScore = try container.decodeIfPresent(Double.self, forKey: .threatScore) ?? 0
        _findings = try container.decode(NullToEmpty<SecurityFinding>.self, forKey: .findings)
        hiddenTextLength = try container.decodeIfPresent(Int.self, forKey: .hiddenTextLength) ?? 0
        visibleTextLength = try container.decodeIfPresent(Int.self, forKey: .visibleTextLength) ?? 0
        hiddenRatio = try container.decodeIfPresent(Double.self, forKey: .hiddenRatio) ?? 0
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case url, findings, summary
        case threatLevel = "threat_level"
        case threatScore = "threat_score"
        case hiddenTextLength = "hidden_text_length"
        case visibleTextLength = "visible_text_length"
        case hiddenRatio = "hidden_ratio"
    }
}

/// A single detected injection pattern.
public struct SecurityFinding: Codable, Sendable {
    /// Category: "instruction_override", "role_impersonation", "data_exfiltration",
    /// "hidden_text", "hidden_comment", "model_targeting", "encoded_payload",
    /// "structural_anomaly", "meta_injection", "safety_override".
    public var category: String

    /// Pattern that matched.
    public var pattern: String

    /// Offending content (truncated).
    public var content: String

    /// Location in the page.
    public var location: String

    /// Threat level for this finding.
    public var threat: String

    /// Detection confidence (0.0 - 1.0).
    public var confidence: Double

    /// Human-readable description.
    public var description: String

    public init(
        category: String = "",
        pattern: String = "",
        content: String = "",
        location: String = "",
        threat: String = "",
        confidence: Double = 0,
        description: String = ""
    ) {
        self.category = category
        self.pattern = pattern
        self.content = content
        self.location = location
        self.threat = threat
        self.confidence = confidence
        self.description = description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        threat = try container.decodeIfPresent(String.self, forKey: .threat) ?? ""
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case category, pattern, content, location, threat, confidence, description
    }
}

/// One issue found by the code security scan.
public struct CodeScanFinding: Codable, Sendable {
    /// Issue category.
    public var category: String?

    /// Severity (`critical`, `high`, `medium`, `low`).
    public var severity: String?

    /// The rule that matched.
    public var pattern: String?

    /// File the issue is in.
    public var file: String?

    /// Line the issue is on.
    public var line: Int64?

    /// The offending line, truncated.
    public var content: String?

    /// What is wrong.
    public var description: String?

    /// Suggested fix, when the rule carries one.
    public var fix: String?

    /// Whether this matches a known machine-generated code pattern.
    public var aiPattern: Bool?

    enum CodingKeys: String, CodingKey {
        case category, severity, pattern, file, line, content, description, fix
        case aiPattern = "ai_pattern"
    }
}

/// Response from `POST /qai/v1/security/scan-code`.
public struct CodeScanReport: Codable, Sendable {
    /// What was scanned: the filename in single-file mode, the scanned
    /// directory otherwise.
    public var path: String?

    /// Number of files scanned.
    public var filesScanned: Int64?

    /// Everything found.
    @NullToEmpty public var findings: [CodeScanFinding]

    /// Finding counts keyed by severity.
    @NullToEmptyMap public var summary: [String: Int64]

    /// Finding counts keyed by category.
    @NullToEmptyMap public var categories: [String: Int64]

    /// Security score from 0 to 100; higher is better.
    public var score: Double?

    enum CodingKeys: String, CodingKey {
        case path, findings, summary, categories, score
        case filesScanned = "files_scanned"
    }
}

/// Response from checking a URL against the registry.
public struct SecurityCheckResponse: Codable, Sendable {
    /// URL that was checked.
    public var url: String

    /// Whether the URL is blocked.
    public var blocked: Bool

    /// Threat level (if blocked).
    public var threatLevel: String?

    /// Threat score (if blocked).
    public var threatScore: Double?

    /// Detection categories (if blocked).
    public var categories: [String]?

    /// First seen timestamp.
    public var firstSeen: String?

    /// Last seen timestamp.
    public var lastSeen: String?

    /// Number of reports.
    public var reportCount: Int?

    /// Registry status: "confirmed", "suspected".
    public var status: String?

    /// Human-readable message.
    public var message: String?

    public init(
        url: String = "",
        blocked: Bool = false,
        threatLevel: String? = nil,
        threatScore: Double? = nil,
        categories: [String]? = nil,
        firstSeen: String? = nil,
        lastSeen: String? = nil,
        reportCount: Int? = nil,
        status: String? = nil,
        message: String? = nil
    ) {
        self.url = url
        self.blocked = blocked
        self.threatLevel = threatLevel
        self.threatScore = threatScore
        self.categories = categories
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.reportCount = reportCount
        self.status = status
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case url, blocked, categories, status, message
        case threatLevel = "threat_level"
        case threatScore = "threat_score"
        case firstSeen = "first_seen"
        case lastSeen = "last_seen"
        case reportCount = "report_count"
    }
}

/// Response from the blocklist feed.
public struct SecurityBlocklistResponse: Codable, Sendable {
    /// Blocklist entries.
    @NullToEmpty public var entries: [SecurityBlocklistEntry]

    /// Total count.
    public var count: Int

    /// Filter status used.
    public var status: String

    public init(entries: [SecurityBlocklistEntry] = [], count: Int = 0, status: String = "") {
        self.entries = entries
        self.count = count
        self.status = status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _entries = try container.decode(NullToEmpty<SecurityBlocklistEntry>.self, forKey: .entries)
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case entries, count, status
    }
}

/// A single blocklist entry.
///
/// Entries written by a scan carry the full shape; entries created by a
/// community report (`status: "suspected"`) carry only `url`, `status`,
/// `threat_level: "unknown"`, `threat_score: 0`, `report_count` and the
/// timestamps, so the scan-only fields are optional.
public struct SecurityBlocklistEntry: Codable, Sendable {
    /// Entry identifier.
    public var id: String?

    /// Blocked URL.
    public var url: String

    /// Registry status.
    public var status: String

    /// Threat level.
    public var threatLevel: String?

    /// Threat score.
    public var threatScore: Double?

    /// Detection categories. Empty on report-created entries.
    @NullToEmpty public var categories: [String]

    /// Number of findings.
    public var findingsCount: Int?

    /// Hidden content ratio.
    public var hiddenRatio: Double?

    /// First seen timestamp.
    public var firstSeen: String?

    /// Summary.
    public var summary: String?

    public init(
        id: String? = nil,
        url: String = "",
        status: String = "",
        threatLevel: String? = nil,
        threatScore: Double? = nil,
        categories: [String] = [],
        findingsCount: Int? = nil,
        hiddenRatio: Double? = nil,
        firstSeen: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.url = url
        self.status = status
        self.threatLevel = threatLevel
        self.threatScore = threatScore
        self.categories = categories
        self.findingsCount = findingsCount
        self.hiddenRatio = hiddenRatio
        self.firstSeen = firstSeen
        self.summary = summary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        threatLevel = try container.decodeIfPresent(String.self, forKey: .threatLevel)
        threatScore = try container.decodeIfPresent(Double.self, forKey: .threatScore)
        _categories = try container.decode(NullToEmpty<String>.self, forKey: .categories)
        findingsCount = try container.decodeIfPresent(Int.self, forKey: .findingsCount)
        hiddenRatio = try container.decodeIfPresent(Double.self, forKey: .hiddenRatio)
        firstSeen = try container.decodeIfPresent(String.self, forKey: .firstSeen)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
    }

    enum CodingKeys: String, CodingKey {
        case id, url, status, categories, summary
        case threatLevel = "threat_level"
        case threatScore = "threat_score"
        case findingsCount = "findings_count"
        case hiddenRatio = "hidden_ratio"
        case firstSeen = "first_seen"
    }
}

/// Response from reporting a URL.
public struct SecurityReportResponse: Codable, Sendable {
    /// URL that was reported.
    public var url: String

    /// Report status: "existing" or "suspected".
    public var status: String

    /// Message.
    public var message: String

    /// Threat level (if already in registry).
    public var threatLevel: String?

    public init(url: String = "", status: String = "", message: String = "", threatLevel: String? = nil) {
        self.url = url
        self.status = status
        self.message = message
        self.threatLevel = threatLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        threatLevel = try container.decodeIfPresent(String.self, forKey: .threatLevel)
    }

    enum CodingKeys: String, CodingKey {
        case url, status, message
        case threatLevel = "threat_level"
    }
}

// MARK: - Client Extension

extension QuantumClient {
    /// Scans a URL for prompt injection attacks.
    ///
    /// Bills $0.005 per call. Private and metadata targets are refused (502
    /// `scraper_error: blocked URL`); the fetch is raw HTML only, capped at
    /// 5 MB, so `visibleTextLength` is always 0. A page scoring 40 or more
    /// is registered in the blocklist automatically.
    ///
    /// `POST /qai/v1/security/scan-url`
    public func securityScanURL(_ url: String, idempotencyKey: String? = nil) async throws -> SecurityScanResponse {
        let request = SecurityScanURLRequest(url: url)
        let (data, _): (SecurityScanResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/security/scan-url", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Scans raw HTML content for prompt injection.
    ///
    /// `POST /qai/v1/security/scan-html`
    public func securityScanHTML(_ request: SecurityScanHTMLRequest, idempotencyKey: String? = nil) async throws -> SecurityScanResponse {
        let (data, _): (SecurityScanResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/security/scan-html", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Scans source code for security issues: one file inline, or a git
    /// repository the gateway clones.
    ///
    /// `POST /qai/v1/security/scan-code`
    public func securityScanCode(_ request: SecurityScanCodeRequest, idempotencyKey: String? = nil) async throws -> CodeScanReport {
        let (data, _): (CodeScanReport, _) = try await doReq(
            method: "POST", path: "/qai/v1/security/scan-code", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Checks a URL against the injection registry. The whole URL, its own
    /// query string included, is sent as one percent-encoded parameter, so
    /// the registry is consulted for exactly the URL given.
    ///
    /// `GET /qai/v1/security/check?url=...`
    public func securityCheck(_ url: String) async throws -> SecurityCheckResponse {
        let (data, _): (SecurityCheckResponse, _) = try await doReq(
            method: "GET", path: Self.securityCheckPath(url: url)
        )
        return data
    }

    /// The check route with the URL as one strictly encoded query value.
    static func securityCheckPath(url: String) -> String {
        "/qai/v1/security/check?url=\(url.strictQueryEncoded)"
    }

    /// Gets the injection blocklist feed. Admin-only: every other caller gets
    /// 403 `forbidden`.
    ///
    /// `status` is `confirmed` (the default), `suspected`, or `all`. At most
    /// 100 entries come back, highest threat score first, with each entry's
    /// payload sample stripped.
    ///
    /// `GET /qai/v1/security/blocklist`
    public func securityBlocklist(status: String? = nil) async throws -> SecurityBlocklistResponse {
        var path = "/qai/v1/security/blocklist"
        if let status { path += "?status=\(status.strictQueryEncoded)" }
        let (data, _): (SecurityBlocklistResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Reports a suspicious URL: 200 `existing` when it is already
    /// registered (its report count is incremented), 201 `suspected` when
    /// it is new.
    ///
    /// `POST /qai/v1/security/report`
    public func securityReport(_ request: SecurityReportRequest) async throws -> SecurityReportResponse {
        let (data, _): (SecurityReportResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/security/report", body: request
        )
        return data
    }
}
