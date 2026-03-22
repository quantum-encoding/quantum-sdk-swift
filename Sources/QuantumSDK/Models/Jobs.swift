import Foundation

// MARK: - Job Create

/// Request body for the `/qai/v1/jobs` endpoint.
public struct JobCreateRequest: Codable, Sendable {
    /// Job type (e.g. "3d/generate", "video/generate").
    public var type: String

    /// Job parameters.
    public var params: [String: AnyCodable]

    public init(type: String, params: [String: AnyCodable]) {
        self.type = type
        self.params = params
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
    public var costTicks: Int

    public init(
        jobId: String,
        status: String,
        result: AnyCodable? = nil,
        error: String? = nil,
        costTicks: Int = 0
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

// MARK: - Job List

/// A single job in the jobs list.
public struct JobListItem: Codable, Sendable {
    /// Job ID.
    public var jobId: String

    /// Current status.
    public var status: String

    /// Job type.
    public var type: String?

    /// Creation timestamp.
    public var createdAt: String?

    /// Completion timestamp.
    public var completedAt: String?

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case status, type
        case jobId = "job_id"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case costTicks = "cost_ticks"
    }
}

/// Response from listing jobs.
public struct JobListResponse: Codable, Sendable {
    /// Jobs.
    public var jobs: [JobListItem]
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
