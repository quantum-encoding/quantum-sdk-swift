import Foundation

// Code scanner: structural analysis of a codebase.
//
// The scanner parses a source tree (a GitHub URL, an OpenAPI spec, or an
// uploaded tar.gz) into a `CodebaseGraph` of modules, types, fields,
// functions, and call edges. Scans are persisted per-user and can then be
// diffed against each other, verified against a `Blueprint`, queried a type
// at a time for agent grounding, or rendered as an SVG graph.
//
// `scannerAudit` is a separate, LLM-backed pass: it returns a job id
// immediately and analyses each file asynchronously; poll it with `getJob`.

// MARK: - Code graph

/// A source file or module in a scanned codebase.
public struct CodeModule: Codable, Sendable {
    /// Path relative to the scan root.
    public var path: String

    /// Detected language (`rust`, `go`, `typescript`, `python`, `swift`,
    /// `kotlin`).
    public var language: String?

    /// Line count.
    public var lines: Int64?

    public init(path: String, language: String? = nil, lines: Int64? = nil) {
        self.path = path
        self.language = language
        self.lines = lines
    }
}

/// A field within a ``CodeType``.
public struct CodeField: Codable, Sendable {
    /// Field name as declared.
    public var name: String

    /// Declared type, as source text.
    public var type: String?

    /// Whether the field is optional / nullable.
    public var optional: Bool?

    /// Serialised name from a JSON tag / serde rename, when the source
    /// declares one.
    public var jsonTag: String?

    public init(name: String, type: String? = nil, optional: Bool? = nil, jsonTag: String? = nil) {
        self.name = name
        self.type = type
        self.optional = optional
        self.jsonTag = jsonTag
    }

    enum CodingKeys: String, CodingKey {
        case name, type, optional
        case jsonTag = "json_tag"
    }
}

/// A struct, class, interface, enum, or data class.
public struct CodeType: Codable, Sendable {
    /// Type name.
    public var name: String

    /// Declaration kind (`struct`, `class`, `interface`, `enum`,
    /// `data_class`).
    public var kind: String?

    /// File the type is declared in.
    public var file: String?

    /// First line of the declaration.
    public var lineStart: Int64?

    /// Last line of the declaration.
    public var lineEnd: Int64?

    /// Declared visibility (`public`, `private`, `internal`).
    public var visibility: String?

    /// The type's fields.
    @NullToEmpty public var fields: [CodeField]

    /// Names of methods attached to the type.
    @NullToEmpty public var methods: [String]

    /// Raw source, present only when the scan requested `includeSource`.
    public var source: String?

    public init(
        name: String,
        kind: String? = nil,
        file: String? = nil,
        lineStart: Int64? = nil,
        lineEnd: Int64? = nil,
        visibility: String? = nil,
        fields: [CodeField] = [],
        methods: [String] = [],
        source: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.file = file
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.visibility = visibility
        self.fields = fields
        self.methods = methods
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case name, kind, file, visibility, fields, methods, source
        case lineStart = "line_start"
        case lineEnd = "line_end"
    }
}

/// A standalone function or a method.
public struct CodeFunction: Codable, Sendable {
    /// Function name.
    public var name: String

    /// File the function is declared in.
    public var file: String?

    /// First line of the declaration.
    public var lineStart: Int64?

    /// Last line of the declaration.
    public var lineEnd: Int64?

    /// Parameter list, as source text.
    public var params: String?

    /// Return type, as source text.
    public var returnType: String?

    /// Type this function is a method on, when it is one.
    public var receiver: String?

    /// Declared visibility (`public`, `private`).
    public var visibility: String?

    /// Whether the function is asynchronous.
    public var isAsync: Bool?

    /// Raw source, present only when the scan requested `includeSource`.
    public var source: String?

    public init(
        name: String,
        file: String? = nil,
        lineStart: Int64? = nil,
        lineEnd: Int64? = nil,
        params: String? = nil,
        returnType: String? = nil,
        receiver: String? = nil,
        visibility: String? = nil,
        isAsync: Bool? = nil,
        source: String? = nil
    ) {
        self.name = name
        self.file = file
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.params = params
        self.returnType = returnType
        self.receiver = receiver
        self.visibility = visibility
        self.isAsync = isAsync
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case name, file, params, receiver, visibility, source
        case lineStart = "line_start"
        case lineEnd = "line_end"
        case returnType = "return_type"
        case isAsync = "is_async"
    }
}

/// One function calling another, extracted when the scan requested
/// `includeCallGraph`.
public struct CallEdge: Codable, Sendable {
    /// Caller, qualified as `file::function`.
    public var from: String

    /// Name of the function being called.
    public var to: String

    /// Line number of the call site.
    public var callLine: Int64?

    public init(from: String, to: String, callLine: Int64? = nil) {
        self.from = from
        self.to = to
        self.callLine = callLine
    }

    enum CodingKeys: String, CodingKey {
        case from, to
        case callLine = "call_line"
    }
}

/// The full structural representation of a codebase.
public struct CodebaseGraph: Codable, Sendable {
    /// Scanned modules.
    @NullToEmpty public var modules: [CodeModule]

    /// Declared types.
    @NullToEmpty public var types: [CodeType]

    /// Declared functions.
    @NullToEmpty public var functions: [CodeFunction]

    /// Call edges; empty unless the scan requested the call graph.
    @NullToEmpty public var callEdges: [CallEdge]

    public init(
        modules: [CodeModule] = [],
        types: [CodeType] = [],
        functions: [CodeFunction] = [],
        callEdges: [CallEdge] = []
    ) {
        self.modules = modules
        self.types = types
        self.functions = functions
        self.callEdges = callEdges
    }

    enum CodingKeys: String, CodingKey {
        case modules, types, functions
        case callEdges = "call_edges"
    }
}

/// Counts summarising what a scan found.
public struct ScanStats: Codable, Sendable {
    /// Files parsed.
    public var files: Int64?
    /// Types found.
    public var types: Int64?
    /// Fields across all types.
    public var fields: Int64?
    /// Functions found.
    public var functions: Int64?
    /// Call edges extracted.
    public var callEdges: Int64?
    /// Modules found.
    public var modules: Int64?

    enum CodingKeys: String, CodingKey {
        case files, types, fields, functions, modules
        case callEdges = "call_edges"
    }
}

// MARK: - Scan

/// Request body for `POST /qai/v1/scanner/scan`.
public struct ScanRequest: Codable, Sendable {
    /// What to scan: a `github://owner/repo` or `https://github.com/...` URL,
    /// an OpenAPI spec URL, or a directory on the gateway's own filesystem
    /// under `/workspace` or `/tmp` (any other local path is 403
    /// `forbidden`). Required.
    public var source: String

    /// Git branch to check out. Defaults to `main`.
    public var branch: String?

    /// Restrict parsing to these languages. Empty scans every supported
    /// language.
    public var languages: [String]?

    /// Include raw source text on each type and function.
    public var includeSource: Bool?

    /// Extract call edges between functions.
    public var includeCallGraph: Bool?

    /// Label for this scan. Defaults to the source string.
    public var name: String?

    public init(
        source: String,
        branch: String? = nil,
        languages: [String]? = nil,
        includeSource: Bool? = nil,
        includeCallGraph: Bool? = nil,
        name: String? = nil
    ) {
        self.source = source
        self.branch = branch
        self.languages = languages
        self.includeSource = includeSource
        self.includeCallGraph = includeCallGraph
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case source, branch, languages, name
        case includeSource = "include_source"
        case includeCallGraph = "include_call_graph"
    }
}

/// A completed scan and its graph.
public struct ScanResult: Codable, Sendable {
    /// Scan identifier, used by the diff / verify / type-query routes.
    public var scanId: String

    /// Label of the scan.
    public var name: String?

    /// The source that was scanned.
    public var source: String?

    /// Summary counts.
    public var stats: ScanStats?

    /// The parsed graph. Listing endpoints return scans with an empty graph;
    /// fetch the scan by id for the full structure.
    public var graph: CodebaseGraph?

    /// RFC3339 creation timestamp.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case name, source, stats, graph
        case scanId = "scan_id"
        case createdAt = "created_at"
    }
}

/// Response from `GET /qai/v1/scanner/scans`.
public struct ScanListResponse: Codable, Sendable {
    /// The caller's scans, newest first (capped at 100 server-side).
    @NullToEmpty public var scans: [ScanResult]

    /// Gateway request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case scans
        case requestId = "request_id"
    }
}

/// Response from `DELETE /qai/v1/scanner/scans/{id}`.
public struct ScanDeleteResponse: Codable, Sendable {
    /// True once the scan is gone.
    public var deleted: Bool

    /// The scan that was deleted.
    public var scanId: String?

    /// Gateway request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case deleted
        case scanId = "scan_id"
        case requestId = "request_id"
    }
}

// MARK: - Type queries

/// A lightweight type entry from `GET /qai/v1/scanner/scans/{id}/types`.
public struct ScanTypeSummary: Codable, Sendable {
    /// Type name.
    public var name: String

    /// Declaration kind.
    public var kind: String?

    /// File the type is declared in.
    public var file: String?

    /// Number of fields on the type.
    public var fieldCount: Int64?

    /// Declared visibility.
    public var visibility: String?

    enum CodingKeys: String, CodingKey {
        case name, kind, file, visibility
        case fieldCount = "field_count"
    }
}

/// Response from `GET /qai/v1/scanner/scans/{id}/types`.
public struct ScanTypeListResponse: Codable, Sendable {
    /// Every type in the scan, names and kinds only.
    @NullToEmpty public var types: [ScanTypeSummary]

    /// Number of entries in `types`.
    public var count: Int64?

    /// The scan queried.
    public var scanId: String?

    /// Label of the scan.
    public var scanName: String?

    /// Gateway request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case types, count
        case scanId = "scan_id"
        case scanName = "scan_name"
        case requestId = "request_id"
    }
}

/// Response from `GET /qai/v1/scanner/scans/{id}/types/{name}`: one type with
/// everything an agent needs to write against it.
public struct ScanTypeDetail: Codable, Sendable {
    /// The type itself, with its fields. Wire key `type`.
    public var codeType: CodeType

    /// Methods attached to the type.
    @NullToEmpty public var methods: [CodeFunction]

    /// Types referenced by the type's field declarations.
    @NullToEmpty public var references: [CodeType]

    /// The scan queried.
    public var scanId: String?

    /// Label of the scan.
    public var scanName: String?

    /// Gateway request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case methods, references
        case codeType = "type"
        case scanId = "scan_id"
        case scanName = "scan_name"
        case requestId = "request_id"
    }
}

// MARK: - Diff

/// Request body for `POST /qai/v1/scanner/diff`.
///
/// Each side is given either by scan id or as an inline graph. The gateway
/// resolves the id form against the caller's own scans.
public struct DiffRequest: Codable, Sendable {
    /// Scan id of the reference codebase. Wire key `base`.
    public var baseScanId: String?

    /// Scan id of the codebase being compared. Wire key `target`.
    public var targetScanId: String?

    /// Inline reference graph, instead of `baseScanId`.
    public var baseGraph: CodebaseGraph?

    /// Inline comparison graph, instead of `targetScanId`.
    public var targetGraph: CodebaseGraph?

    /// Label for the reference side in the result.
    public var baseName: String?

    /// Label for the comparison side in the result.
    public var targetName: String?

    public init(
        baseScanId: String? = nil,
        targetScanId: String? = nil,
        baseGraph: CodebaseGraph? = nil,
        targetGraph: CodebaseGraph? = nil,
        baseName: String? = nil,
        targetName: String? = nil
    ) {
        self.baseScanId = baseScanId
        self.targetScanId = targetScanId
        self.baseGraph = baseGraph
        self.targetGraph = targetGraph
        self.baseName = baseName
        self.targetName = targetName
    }

    enum CodingKeys: String, CodingKey {
        case baseScanId = "base"
        case targetScanId = "target"
        case baseGraph = "base_graph"
        case targetGraph = "target_graph"
        case baseName = "base_name"
        case targetName = "target_name"
    }
}

/// A type present in both codebases under different casing conventions.
public struct ConventionDiff: Codable, Sendable {
    /// Name as spelled in the reference codebase.
    public var baseName: String?

    /// Name as spelled in the compared codebase.
    public var targetName: String?

    enum CodingKeys: String, CodingKey {
        case baseName = "base_name"
        case targetName = "target_name"
    }
}

/// Response from `POST /qai/v1/scanner/diff`.
public struct DiffResult: Codable, Sendable {
    /// Label of the reference side.
    public var base: String?

    /// Label of the compared side.
    public var target: String?

    /// Types in the reference but not the target: real gaps.
    @NullToEmpty public var missingTypes: [String]

    /// Types in the target but not the reference.
    @NullToEmpty public var extraTypes: [String]

    /// Types that exist on both sides but differ only in casing; not gaps.
    @NullToEmpty public var conventionDiffs: [ConventionDiff]

    /// Type name to field names missing from the target.
    @NullToEmptyMap public var missingFields: [String: [String]]

    /// Functions in the reference but not the target.
    @NullToEmpty public var missingFunctions: [String]

    /// Fraction of the reference surface present in the target, 0.0 to 1.0.
    public var completion: Double?

    /// Total count of missing types, fields, and functions.
    public var totalGaps: Int64?

    enum CodingKeys: String, CodingKey {
        case base, target, completion
        case missingTypes = "missing_types"
        case extraTypes = "extra_types"
        case conventionDiffs = "convention_diffs"
        case missingFields = "missing_fields"
        case missingFunctions = "missing_functions"
        case totalGaps = "total_gaps"
    }
}

// MARK: - Verify

/// An expected type in a ``Blueprint``.
public struct BlueprintType: Codable, Sendable {
    /// Expected type name.
    public var name: String

    /// Expected declaration kind.
    public var kind: String?

    /// Expected fields.
    public var fields: [CodeField]?

    public init(name: String, kind: String? = nil, fields: [CodeField]? = nil) {
        self.name = name
        self.kind = kind
        self.fields = fields
    }
}

/// An expected function in a ``Blueprint``.
public struct BlueprintFunction: Codable, Sendable {
    /// Expected function name.
    public var name: String

    /// Expected parameter list, as source text.
    public var params: String?

    /// Expected return type, as source text.
    public var returnType: String?

    public init(name: String, params: String? = nil, returnType: String? = nil) {
        self.name = name
        self.params = params
        self.returnType = returnType
    }

    enum CodingKeys: String, CodingKey {
        case name, params
        case returnType = "return_type"
    }
}

/// An expected file in a ``Blueprint``.
public struct BlueprintModule: Codable, Sendable {
    /// Expected path, relative to the scan root.
    public var path: String

    public init(path: String) {
        self.path = path
    }
}

/// The structure a codebase is expected to have.
public struct Blueprint: Codable, Sendable {
    /// Label for the blueprint.
    public var name: String

    /// Expected types.
    public var types: [BlueprintType]?

    /// Expected functions.
    public var functions: [BlueprintFunction]?

    /// Expected modules.
    public var modules: [BlueprintModule]?

    public init(
        name: String,
        types: [BlueprintType]? = nil,
        functions: [BlueprintFunction]? = nil,
        modules: [BlueprintModule]? = nil
    ) {
        self.name = name
        self.types = types
        self.functions = functions
        self.modules = modules
    }
}

/// Request body for `POST /qai/v1/scanner/verify`.
///
/// Provide either `source` (scanned fresh) or `scanId` (an existing scan).
public struct VerifyRequest: Codable, Sendable {
    /// The expected structure.
    public var blueprint: Blueprint

    /// Codebase to verify: a GitHub URL, or a directory on the gateway's own
    /// filesystem under `/workspace` or `/tmp` (any other local path is 403
    /// `forbidden`).
    public var source: String?

    /// Git branch for `source`.
    public var branch: String?

    /// Existing scan to verify against, instead of `source`.
    public var scanId: String?

    public init(blueprint: Blueprint, source: String? = nil, branch: String? = nil, scanId: String? = nil) {
        self.blueprint = blueprint
        self.source = source
        self.branch = branch
        self.scanId = scanId
    }

    enum CodingKeys: String, CodingKey {
        case blueprint, source, branch
        case scanId = "scan_id"
    }
}

/// Whether one expected module exists and is complete.
public struct FileStatus: Codable, Sendable {
    /// Expected path.
    public var path: String?

    /// Whether the file was found.
    public var exists: Bool?

    /// Whether every symbol the blueprint expects in it was found.
    public var complete: Bool?
}

/// Response from `POST /qai/v1/scanner/verify`.
public struct VerifyResult: Codable, Sendable {
    /// True when nothing the blueprint expects is missing.
    public var passed: Bool

    /// Fraction of the blueprint present, 0.0 to 1.0.
    public var completion: Double?

    /// Expected types that were not found.
    @NullToEmpty public var missingTypes: [String]

    /// Type name to expected field names that were not found.
    @NullToEmptyMap public var missingFields: [String: [String]]

    /// Expected functions that were not found.
    @NullToEmpty public var missingFunctions: [String]

    /// Expected modules that were not found.
    @NullToEmpty public var missingModules: [String]

    /// Per-module existence and completeness.
    @NullToEmpty public var fileStatus: [FileStatus]

    enum CodingKeys: String, CodingKey {
        case passed, completion
        case missingTypes = "missing_types"
        case missingFields = "missing_fields"
        case missingFunctions = "missing_functions"
        case missingModules = "missing_modules"
        case fileStatus = "file_status"
    }
}

// MARK: - Audit

/// Response from `POST /qai/v1/scanner/audit`: the audit runs asynchronously,
/// so this is the accepted job, not the findings.
public struct AuditJobResponse: Codable, Sendable {
    /// Job id to poll with ``QuantumClient/getJob(jobId:)``.
    public var jobId: String

    /// Audit profile that was applied.
    public var profile: String?

    /// Model the analysis runs on.
    public var model: String?

    /// Number of source files that survived filtering and will be analysed.
    public var filesToAnalyze: Int64?

    /// Pre-flight cost estimate, pre-formatted for display.
    public var estimatedCost: String?

    enum CodingKeys: String, CodingKey {
        case profile, model
        case jobId = "job_id"
        case filesToAnalyze = "files_to_analyze"
        case estimatedCost = "estimated_cost"
    }
}

/// One file's findings from a completed audit job.
public struct AuditFileResult: Codable, Sendable {
    /// Path relative to the uploaded root.
    public var path: String?

    /// Detected language.
    public var language: String?

    /// Input tokens spent on this file.
    public var tokensIn: Int64?

    /// Output tokens produced for this file.
    public var tokensOut: Int64?

    /// The model's findings for this file.
    public var findings: String?

    /// Why this file could not be analysed, when it could not be.
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case path, language, findings, error
        case tokensIn = "tokens_in"
        case tokensOut = "tokens_out"
    }
}

/// The manifest a completed audit job produces.
public struct AuditResult: Codable, Sendable {
    /// Audit profile that was applied.
    public var profile: String?

    /// Model the analysis ran on.
    public var model: String?

    /// Files successfully analysed.
    public var filesAnalyzed: Int64?

    /// Files that errored.
    public var filesErrored: Int64?

    /// Total input tokens across all files.
    public var totalTokensIn: Int64?

    /// Total output tokens across all files.
    public var totalTokensOut: Int64?

    /// Wall-clock duration of the audit.
    public var durationSeconds: Double?

    /// Actual cost of the audit in USD.
    public var costUsd: Double?

    /// Per-file findings.
    @NullToEmpty public var files: [AuditFileResult]

    enum CodingKeys: String, CodingKey {
        case profile, model, files
        case filesAnalyzed = "files_analyzed"
        case filesErrored = "files_errored"
        case totalTokensIn = "total_tokens_in"
        case totalTokensOut = "total_tokens_out"
        case durationSeconds = "duration_seconds"
        case costUsd = "cost_usd"
    }
}

// MARK: - Vulnerabilities

/// Options for `POST /qai/v1/scanner/vulnerabilities`.
public struct VulnerabilityScanOptions: Codable, Sendable {
    /// Also produce a threat model.
    public var threatModel: Bool?

    /// Also cross-reference dependencies against known CVEs.
    public var cveCheck: Bool?

    public init(threatModel: Bool? = nil, cveCheck: Bool? = nil) {
        self.threatModel = threatModel
        self.cveCheck = cveCheck
    }

    enum CodingKeys: String, CodingKey {
        case threatModel = "threat_model"
        case cveCheck = "cve_check"
    }
}

/// Request body for `POST /qai/v1/scanner/vulnerabilities`.
public struct VulnerabilityScanRequest: Codable, Sendable {
    /// GitHub URL to scan. Local paths are rejected; the handler only accepts
    /// `https://github.com/owner/repo`.
    public var source: String

    /// Label for the scan.
    public var name: String?

    /// Detector options.
    public var options: VulnerabilityScanOptions?

    public init(source: String, name: String? = nil, options: VulnerabilityScanOptions? = nil) {
        self.source = source
        self.name = name
        self.options = options
    }
}
