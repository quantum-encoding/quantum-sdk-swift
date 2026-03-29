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

    /// Individual findings.
    public var findings: [SecurityFinding]

    /// Length of hidden text content detected.
    public var hiddenTextLength: Int

    /// Length of visible text content.
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
    public var entries: [SecurityBlocklistEntry]

    /// Total count.
    public var count: Int

    /// Filter status used.
    public var status: String

    public init(entries: [SecurityBlocklistEntry] = [], count: Int = 0, status: String = "") {
        self.entries = entries
        self.count = count
        self.status = status
    }
}

/// A single blocklist entry.
public struct SecurityBlocklistEntry: Codable, Sendable {
    /// Entry identifier.
    public var id: String?

    /// Blocked URL.
    public var url: String

    /// Registry status.
    public var status: String

    /// Threat level.
    public var threatLevel: String

    /// Threat score.
    public var threatScore: Double

    /// Detection categories.
    public var categories: [String]

    /// Number of findings.
    public var findingsCount: Int

    /// Hidden content ratio.
    public var hiddenRatio: Double

    /// First seen timestamp.
    public var firstSeen: String?

    /// Summary.
    public var summary: String

    public init(
        id: String? = nil,
        url: String = "",
        status: String = "",
        threatLevel: String = "",
        threatScore: Double = 0,
        categories: [String] = [],
        findingsCount: Int = 0,
        hiddenRatio: Double = 0,
        firstSeen: String? = nil,
        summary: String = ""
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

    enum CodingKeys: String, CodingKey {
        case url, status, message
        case threatLevel = "threat_level"
    }
}

// MARK: - Client Extension

extension QuantumClient {
    /// Scan a URL for prompt injection attacks.
    public func securityScanURL(_ url: String) async throws -> SecurityScanResponse {
        let request = SecurityScanURLRequest(url: url)
        let (data, _): (SecurityScanResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/security/scan-url", body: request
        )
        return data
    }

    /// Scan raw HTML content for prompt injection.
    public func securityScanHTML(_ request: SecurityScanHTMLRequest) async throws -> SecurityScanResponse {
        let (data, _): (SecurityScanResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/security/scan-html", body: request
        )
        return data
    }

    /// Check a URL against the injection registry.
    public func securityCheck(_ url: String) async throws -> SecurityCheckResponse {
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let (data, _): (SecurityCheckResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/security/check?url=\(encoded)"
        )
        return data
    }

    /// Get the injection blocklist feed.
    public func securityBlocklist(status: String? = nil) async throws -> SecurityBlocklistResponse {
        var path = "/qai/v1/security/blocklist"
        if let status { path += "?status=\(status)" }
        let (data, _): (SecurityBlocklistResponse, _) = try await http.doJSON(method: "GET", path: path)
        return data
    }

    /// Report a suspicious URL.
    public func securityReport(_ request: SecurityReportRequest) async throws -> SecurityReportResponse {
        let (data, _): (SecurityReportResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/security/report", body: request
        )
        return data
    }
}
