import Foundation

// MARK: - Batch Job

/// A single job in a batch submission.
public struct BatchJob: Codable, Sendable {
    /// Model to use for this job.
    public var model: String

    /// The prompt text.
    public var prompt: String

    /// Optional title for this job.
    public var title: String?

    /// Optional system prompt.
    public var systemPrompt: String?

    /// Optional maximum tokens to generate.
    public var maxTokens: Int64?

    public init(
        model: String,
        prompt: String,
        title: String? = nil,
        systemPrompt: String? = nil,
        maxTokens: Int64? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.title = title
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, title
        case systemPrompt = "system_prompt"
        case maxTokens = "max_tokens"
    }
}

/// Legacy alias.
public typealias BatchJobInput = BatchJob

/// Request body for the `/qai/v1/batch` endpoint.
public struct BatchSubmitRequest: Codable, Sendable {
    /// Array of jobs to submit.
    public var jobs: [BatchJob]

    public init(jobs: [BatchJob]) {
        self.jobs = jobs
    }
}

/// Response from batch submission.
public struct BatchSubmitResponse: Codable, Sendable {
    /// The IDs of the created jobs.
    public var jobIds: [String]

    /// Status of the batch submission.
    public var status: String

    enum CodingKeys: String, CodingKey {
        case status
        case jobIds = "job_ids"
    }
}

// MARK: - Batch JSONL

/// Response from JSONL batch submission.
public struct BatchJsonlResponse: Codable, Sendable {
    /// The IDs of the created jobs.
    public var jobIds: [String]

    enum CodingKeys: String, CodingKey {
        case jobIds = "job_ids"
    }
}

// MARK: - Batch Job Info

/// A single job in the batch jobs list.
public struct BatchJobInfo: Codable, Sendable {
    /// Job ID.
    public var jobId: String

    /// Current status.
    public var status: String

    /// Model used.
    public var model: String?

    /// Job title.
    public var title: String?

    /// Creation timestamp.
    public var createdAt: String?

    /// Completion timestamp.
    public var completedAt: String?

    /// Job result.
    public var result: AnyCodable?

    /// Error message.
    public var error: String?

    /// Cost in ticks.
    public var costTicks: Int64

    enum CodingKeys: String, CodingKey {
        case status, model, title, result, error
        case jobId = "job_id"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case costTicks = "cost_ticks"
    }
}

/// Response from listing batch jobs.
public struct BatchJobsResponse: Codable, Sendable {
    /// Batch jobs.
    public var jobs: [BatchJobInfo]
}
