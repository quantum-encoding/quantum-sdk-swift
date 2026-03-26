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

/// Response from creating a job.
public struct JobCreateResponse: Codable, Sendable {
    /// Job ID for polling.
    public var jobId: String

    /// Current job status.
    public var status: String

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
    }
}

// MARK: - Job Status

/// Response from checking job status.
public struct JobStatusResponse: Codable, Sendable {
    /// Job ID.
    public var jobId: String

    /// Current status ("pending", "processing", "completed", "failed", "timeout").
    public var status: String

    /// Job result (when completed).
    public var result: AnyCodable?

    /// Error message (when failed).
    public var error: String?

    /// Cost in ticks.
    public var costTicks: Int64

    public init(
        jobId: String,
        status: String,
        result: AnyCodable? = nil,
        error: String? = nil,
        costTicks: Int64 = 0
    ) {
        self.jobId = jobId
        self.status = status
        self.result = result
        self.error = error
        self.costTicks = costTicks
    }

    enum CodingKeys: String, CodingKey {
        case status, result, error
        case jobId = "job_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - Job Summary

/// Summary of a job in the list response.
public struct JobSummary: Codable, Sendable {
    /// Job ID.
    public var jobId: String

    /// Current status.
    public var status: String

    /// Job type.
    public var jobType: String?

    /// Creation timestamp.
    public var createdAt: String?

    /// Completion timestamp.
    public var completedAt: String?

    /// Cost in ticks.
    public var costTicks: Int64

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
        case jobType = "type"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case costTicks = "cost_ticks"
    }
}

/// Response from listing jobs.
public struct ListJobsResponse: Codable, Sendable {
    /// Jobs.
    public var jobs: [JobSummary]
}

// MARK: - Job Accepted

/// Response from async job submission (HeyGen, 3D, etc.).
public struct JobAcceptedResponse: Codable, Sendable {
    /// Unique job identifier for polling.
    public var jobId: String

    /// Initial job status (e.g. "pending").
    public var status: String?

    /// Job type.
    public var jobType: String?

    /// Unique request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
        case jobType = "type"
        case requestId = "request_id"
    }
}

// MARK: - Job List Entry

/// A single job entry in the detailed job list response.
public struct JobListEntry: Codable, Sendable {
    /// Unique job identifier.
    public var jobId: String

    /// Job type (e.g. "video/generate", "audio/tts").
    public var jobType: String?

    /// Job status ("pending", "processing", "completed", "failed").
    public var status: String

    /// Job output when completed.
    public var result: AnyCodable?

    /// Error message if the job failed.
    public var error: String?

    /// Total cost in ticks.
    public var costTicks: Int64?

    /// Job creation timestamp.
    public var createdAt: String?

    /// When processing began.
    public var startedAt: String?

    /// When the job finished.
    public var completedAt: String?

    /// Originating request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case status, result, error
        case jobId = "job_id"
        case jobType = "type"
        case costTicks = "cost_ticks"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case requestId = "request_id"
    }
}

/// Response from listing jobs (detailed variant).
public struct JobListResponse: Codable, Sendable {
    /// The list of jobs.
    public var jobs: [JobListEntry]

    /// Unique request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case jobs
        case requestId = "request_id"
    }
}

// MARK: - Job Stream Event

/// A single SSE event from a job stream.
public struct JobStreamEvent: Codable, Sendable {
    /// Event type (e.g. "progress", "complete", "error").
    public var eventType: String?

    /// Job identifier.
    public var jobId: String?

    /// Job status.
    public var status: String?

    /// Job result (on completion).
    public var result: AnyCodable?

    /// Error message (on failure).
    public var error: String?

    /// Total cost in ticks.
    public var costTicks: Int64?

    /// Completion timestamp.
    public var completedAt: String?

    enum CodingKeys: String, CodingKey {
        case status, result, error
        case eventType = "type"
        case jobId = "job_id"
        case costTicks = "cost_ticks"
        case completedAt = "completed_at"
    }
}

// MARK: - 3D Generation

/// Request for 3D model generation via the jobs system.
public struct Generate3DRequest: Codable, Sendable {
    /// Model for 3D generation.
    public var model: String

    /// Text prompt.
    public var prompt: String?

    /// Image URL as input.
    public var imageUrl: String?

    public init(model: String, prompt: String? = nil, imageUrl: String? = nil) {
        self.model = model
        self.prompt = prompt
        self.imageUrl = imageUrl
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt
        case imageUrl = "image_url"
    }
}
