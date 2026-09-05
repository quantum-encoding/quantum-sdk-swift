import Foundation

// MARK: - Job Create

/// Request to create an async job.
public struct JobCreateRequest: Codable, Sendable {
    /// Job type (e.g. "video/generate", "audio/music").
    public var jobType: String

    /// Job parameters (model-specific).
    public var params: AnyCodable

    public init(jobType: String, params: AnyCodable) {
        self.jobType = jobType
        self.params = params
    }

    enum CodingKeys: String, CodingKey {
        case params
        case jobType = "type"
    }
}

// MARK: - Job Accepted

/// The 202 envelope every async submission answers with: the Jobs API,
/// the HeyGen video routes (studio, translate, photo-avatar, twin-video,
/// template render) and the 3D pipeline. Poll with `getJob` / `pollJob`
/// or subscribe with `streamJob`.
///
/// No cost appears here; `costTicks` is reported by `getJob` once the job
/// has settled.
public struct JobAcceptedResponse: Codable, Sendable {
    /// Unique job identifier for polling.
    public var jobId: String

    /// Initial job status (always "pending").
    public var status: String

    /// Job type (e.g. "video/studio", "3d/generate").
    public var jobType: String?

    /// Unique request identifier.
    public var requestId: String?

    /// Creation timestamp (RFC 3339). Sent by `POST /qai/v1/jobs`; the
    /// dedicated media routes omit it.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
        case jobType = "type"
        case requestId = "request_id"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try c.decode(String.self, forKey: .jobId)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        jobType = try c.decodeIfPresent(String.self, forKey: .jobType)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

/// Alias of ``JobAcceptedResponse``: `POST /qai/v1/jobs` answers with the
/// same envelope as every other async route.
public typealias JobCreateResponse = JobAcceptedResponse

// MARK: - Job Status

/// A job as reported by `GET /qai/v1/jobs/{id}` and, per entry, by
/// `GET /qai/v1/jobs`.
public struct JobStatusResponse: Codable, Sendable {
    /// Unique job identifier.
    public var jobId: String

    /// "pending" | "running" | "completed" | "failed". Only the last two
    /// are terminal.
    public var status: String

    /// Job type (e.g. "video/generate", "audio/tts").
    public var jobType: String?

    /// Job output when completed. Results stored in GCS are inlined here.
    public var result: AnyCodable?

    /// Error message if the job failed.
    public var error: String?

    /// Total cost in ticks (0 until the job has settled).
    public var costTicks: Int64

    /// Originating request identifier.
    public var requestId: String?

    /// Job creation timestamp (RFC 3339).
    public var createdAt: String?

    /// When processing began.
    public var startedAt: String?

    /// When the job finished.
    public var completedAt: String?

    public init(
        jobId: String,
        status: String,
        jobType: String? = nil,
        result: AnyCodable? = nil,
        error: String? = nil,
        costTicks: Int64 = 0,
        requestId: String? = nil,
        createdAt: String? = nil,
        startedAt: String? = nil,
        completedAt: String? = nil
    ) {
        self.jobId = jobId
        self.status = status
        self.jobType = jobType
        self.result = result
        self.error = error
        self.costTicks = costTicks
        self.requestId = requestId
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case status, result, error
        case jobId = "job_id"
        case jobType = "type"
        case costTicks = "cost_ticks"
        case requestId = "request_id"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try c.decode(String.self, forKey: .jobId)
        status = try c.decode(String.self, forKey: .status)
        jobType = try c.decodeIfPresent(String.self, forKey: .jobType)
        result = try c.decodeIfPresent(AnyCodable.self, forKey: .result)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
    }
}

/// Alias of ``JobStatusResponse``: list entries carry the same fields as a
/// single status read.
public typealias JobListEntry = JobStatusResponse

/// Response from listing jobs.
public struct JobListResponse: Codable, Sendable {
    /// The caller's newest jobs (at most 50).
    @NullToEmpty public var jobs: [JobStatusResponse]

    /// Unique request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case jobs
        case requestId = "request_id"
    }
}

/// Alias of ``JobListResponse``.
public typealias ListJobsResponse = JobListResponse

// MARK: - Job Stream Event

/// A single SSE event from a job stream.
///
/// `error` events come in two flavours: a job failure carries `jobId`,
/// `status: "failed"` and the job's `error`; the stream's own 10-minute
/// deadline emits `{"type":"error","error":"stream timeout (10 minutes)"}`
/// with no `jobId` or `status`, and the job keeps running — reopen the
/// stream or fall back to `pollJob`.
public struct JobStreamEvent: Codable, Sendable {
    /// Event type: "progress", "complete", "error".
    public var eventType: String

    /// Job identifier (absent on a stream-timeout error).
    public var jobId: String?

    /// Job status.
    public var status: String?

    /// Job result (on completion).
    public var result: AnyCodable?

    /// Error message (on failure or stream timeout).
    public var error: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Completion timestamp.
    public var completedAt: String?

    /// True when this `error` event is the stream's own deadline rather
    /// than a job failure; the job is still running.
    public var isStreamTimeout: Bool {
        eventType == "error" && jobId == nil && status == nil
    }

    enum CodingKeys: String, CodingKey {
        case status, result, error
        case eventType = "type"
        case jobId = "job_id"
        case costTicks = "cost_ticks"
        case completedAt = "completed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try c.decodeIfPresent(String.self, forKey: .eventType) ?? ""
        jobId = try c.decodeIfPresent(String.self, forKey: .jobId)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        result = try c.decodeIfPresent(AnyCodable.self, forKey: .result)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        costTicks = try c.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
    }
}
