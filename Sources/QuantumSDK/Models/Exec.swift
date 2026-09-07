import Foundation

// MARK: - Sandbox Exec

/// One file placed into the sandbox workspace before the command runs.
///
/// `content` is written VERBATIM, so it is text only: sending base64 here
/// lands a text file full of base64 where the bytes belong, which corrupts
/// silently and only shows up in whatever consumes the file. Binary INBOUND
/// is not yet supported by the runner; binary OUTBOUND comes back correctly
/// via ``ExecArtifact/encoding``.
public struct ExecFile: Codable, Sendable {
    /// Path relative to the workspace root, e.g. `"Sources/main.swift"`.
    public var path: String

    /// UTF-8 text contents.
    public var content: String

    public init(path: String, content: String) {
        self.path = path
        self.content = content
    }
}

/// Which container image the command runs in.
///
/// The lane is always sent explicitly. An unset lane means `web` at the
/// gateway — a Node-only image that cold-starts in seconds — so a toolchain
/// request must name `full` rather than rely on a default, and a plain
/// `npm run build` must not drag a multi-gigabyte image out of cold storage.
public struct ExecLane: RawRepresentable, Codable, Sendable, Hashable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// Node-only image. Fast cold start; no Swift, Go or system toolchain.
    public static let web = ExecLane(rawValue: "web")

    /// Full toolchain image — what a Swift, Go or native build needs.
    public static let full = ExecLane(rawValue: "full")
}

/// Request body for the sandbox exec routes.
public struct ExecRequest: Codable, Sendable {
    /// Files written into a fresh workspace before the command runs.
    public var files: [ExecFile]

    /// The command, run as `bash -c <command>` inside the workspace.
    public var command: String

    /// Working directory relative to the workspace root. Defaults to the root.
    public var workdir: String?

    /// Wall-clock ceiling in seconds. Gateway default 600, hard cap 3600.
    public var timeoutSec: Int?

    /// Reuse marker. Passing the same id across calls keeps the workspace and
    /// build cache warm, which is the difference between a
    /// compile-fix-recompile loop being pleasant and being painful.
    public var sessionID: String?

    /// Paths, relative to the workdir, to read back after the command exits.
    /// Empty returns output only.
    public var outputs: [String]?

    /// Which image to run in. See ``ExecLane``.
    public var lane: ExecLane?

    public init(
        files: [ExecFile] = [],
        command: String,
        workdir: String? = nil,
        timeoutSec: Int? = nil,
        sessionID: String? = nil,
        outputs: [String]? = nil,
        lane: ExecLane? = nil
    ) {
        self.files = files
        self.command = command
        self.workdir = workdir
        self.timeoutSec = timeoutSec
        self.sessionID = sessionID
        self.outputs = outputs
        self.lane = lane
    }

    enum CodingKeys: String, CodingKey {
        case files, command, workdir, outputs, lane
        case timeoutSec = "timeout_sec"
        case sessionID = "session_id"
    }
}

/// A file collected back out of the workspace after the command exits.
public struct ExecArtifact: Codable, Sendable {
    /// Path relative to the workdir.
    public var path: String

    /// File contents, decoded according to ``encoding``.
    public var content: String

    /// `"utf8"` or `"base64"`. A built binary or image arrives base64, so
    /// anything writing these bytes must decode rather than assume text.
    public var encoding: String

    /// Size in bytes of the decoded content.
    public var bytes: Int

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decode(String.self, forKey: .path)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        encoding = try c.decodeIfPresent(String.self, forKey: .encoding) ?? "utf8"
        bytes = try c.decodeIfPresent(Int.self, forKey: .bytes) ?? 0
    }
}

/// Result of a non-streaming sandbox run.
public struct ExecResponse: Codable, Sendable {
    /// The command's exit status. 124 is the conventional timeout code.
    public var exitCode: Int

    public var stdout: String
    public var stderr: String

    /// Wall-clock duration of the run.
    public var durationMs: Int64

    /// Whether output was cut short by the runner's size cap.
    public var truncated: Bool

    /// Files named by ``ExecRequest/outputs``.
    @NullToEmpty public var artifacts: [ExecArtifact]

    enum CodingKeys: String, CodingKey {
        case stdout, stderr, truncated, artifacts
        case exitCode = "exit_code"
        case durationMs = "duration_ms"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exitCode = try c.decodeIfPresent(Int.self, forKey: .exitCode) ?? 0
        stdout = try c.decodeIfPresent(String.self, forKey: .stdout) ?? ""
        stderr = try c.decodeIfPresent(String.self, forKey: .stderr) ?? ""
        durationMs = try c.decodeIfPresent(Int64.self, forKey: .durationMs) ?? 0
        truncated = try c.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
        _artifacts = try c.decode(NullToEmpty<ExecArtifact>.self, forKey: .artifacts)
    }
}
