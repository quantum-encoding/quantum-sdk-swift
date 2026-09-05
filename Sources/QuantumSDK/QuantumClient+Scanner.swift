import Foundation

// Code scanner routes. Types live in Models/Scanner.swift.

extension QuantumClient {
    /// Scans a codebase or an OpenAPI spec into a structural graph.
    ///
    /// `POST /qai/v1/scanner/scan`
    public func scannerScan(_ request: ScanRequest) async throws -> ScanResult {
        let (data, _): (ScanResult, _) = try await doReq(
            method: "POST", path: "/qai/v1/scanner/scan", body: request
        )
        return data
    }

    /// Scans an uploaded source archive.
    ///
    /// `archive` is a tar.gz of the tree (50 MB cap). `languages` restricts
    /// parsing when non-empty.
    ///
    /// `POST /qai/v1/scanner/upload` (multipart: `file`, `name`, `languages`)
    public func scannerUpload(name: String, archive: Data, languages: [String] = []) async throws -> ScanResult {
        var fields = ["name": name]
        if !languages.isEmpty {
            fields["languages"] = languages.joined(separator: ",")
        }
        let (data, _): (ScanResult, _) = try await http.doMultipart(
            path: "/qai/v1/scanner/upload",
            fieldName: "file",
            filename: "\(name).tar.gz",
            data: archive,
            contentType: "application/gzip",
            fields: fields
        )
        return data
    }

    /// Compares two codebases structurally and reports the gaps.
    ///
    /// `POST /qai/v1/scanner/diff`
    public func scannerDiff(_ request: DiffRequest) async throws -> DiffResult {
        let (data, _): (DiffResult, _) = try await doReq(
            method: "POST", path: "/qai/v1/scanner/diff", body: request
        )
        return data
    }

    /// Verifies a codebase against a blueprint of the structure it should
    /// have.
    ///
    /// `POST /qai/v1/scanner/verify`
    public func scannerVerify(_ request: VerifyRequest) async throws -> VerifyResult {
        let (data, _): (VerifyResult, _) = try await doReq(
            method: "POST", path: "/qai/v1/scanner/verify", body: request
        )
        return data
    }

    /// Starts an LLM code audit over an uploaded source archive.
    ///
    /// Returns as soon as the job is accepted; the analysis runs in the
    /// background and bills per file. `profile` defaults to
    /// `security-redteam` and `model` to the gateway's default audit model
    /// when nil. Poll the job with ``getJob(jobId:)``; its result is an
    /// ``AuditResult``.
    ///
    /// `POST /qai/v1/scanner/audit` (multipart: `file`, `model`, `profile`)
    public func scannerAudit(archive: Data, profile: String? = nil, model: String? = nil) async throws -> AuditJobResponse {
        var fields: [String: String] = [:]
        if let profile { fields["profile"] = profile }
        if let model { fields["model"] = model }
        let (data, _): (AuditJobResponse, _) = try await http.doMultipart(
            path: "/qai/v1/scanner/audit",
            fieldName: "file",
            filename: "audit.tar.gz",
            data: archive,
            contentType: "application/gzip",
            fields: fields
        )
        return data
    }

    /// Runs the security detector over a public GitHub repository.
    ///
    /// The findings come straight from the detector, so they are returned
    /// untyped.
    ///
    /// `POST /qai/v1/scanner/vulnerabilities`
    public func scannerVulnerabilities(_ request: VulnerabilityScanRequest) async throws -> [String: AnyCodable] {
        let (data, _): ([String: AnyCodable], _) = try await doReq(
            method: "POST", path: "/qai/v1/scanner/vulnerabilities", body: request
        )
        return data
    }

    /// Lists the caller's saved scans, newest first.
    ///
    /// `GET /qai/v1/scanner/scans`
    public func scannerScans() async throws -> ScanListResponse {
        let (data, _): (ScanListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/scanner/scans"
        )
        return data
    }

    /// Fetches one saved scan with its full graph.
    ///
    /// `GET /qai/v1/scanner/scans/{id}`
    public func scannerScanGet(scanId: String) async throws -> ScanResult {
        let (data, _): (ScanResult, _) = try await doReq(
            method: "GET", path: "/qai/v1/scanner/scans/\(scanId.strictQueryEncoded)"
        )
        return data
    }

    /// Deletes a saved scan.
    ///
    /// `DELETE /qai/v1/scanner/scans/{id}`
    public func scannerScanDelete(scanId: String) async throws -> ScanDeleteResponse {
        let (data, _): (ScanDeleteResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/scanner/scans/\(scanId.strictQueryEncoded)"
        )
        return data
    }

    /// Lists every type in a scan by name and kind: the discovery step before
    /// ``scannerType(scanId:typeName:)``.
    ///
    /// `GET /qai/v1/scanner/scans/{id}/types`
    public func scannerTypes(scanId: String) async throws -> ScanTypeListResponse {
        let (data, _): (ScanTypeListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/scanner/scans/\(scanId.strictQueryEncoded)/types"
        )
        return data
    }

    /// Fetches one type from a scan with its fields, methods, and the types
    /// it references. The name match is case-insensitive.
    ///
    /// `GET /qai/v1/scanner/scans/{id}/types/{name}`
    public func scannerType(scanId: String, typeName: String) async throws -> ScanTypeDetail {
        let (data, _): (ScanTypeDetail, _) = try await doReq(
            method: "GET",
            path: "/qai/v1/scanner/scans/\(scanId.strictQueryEncoded)/types/\(typeName.strictQueryEncoded)"
        )
        return data
    }

    /// Renders a scan's graph as SVG. Returns the raw document.
    ///
    /// `GET /qai/v1/scanner/scans/{id}/graph.svg`
    public func scannerGraphSVG(scanId: String) async throws -> String {
        let (data, _) = try await http.doRawDownload(
            path: "/qai/v1/scanner/scans/\(scanId.strictQueryEncoded)/graph.svg"
        )
        return String(decoding: data, as: UTF8.self)
    }
}
