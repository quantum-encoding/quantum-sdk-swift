import Foundation

// Batch processing — submit multiple prompts in a single request, run at
// batch (lower-priority, discounted) pricing.
//
// Batch jobs live in their own store and are read back with `batchJobs` /
// `batchJob`, not the Jobs API (`GET /qai/v1/jobs/{id}` answers 404 for a
// batch id).

// MARK: - Batch Job

/// A single job in a batch submission.
public struct BatchJob: Codable, Sendable {
    /// Model to use for this job (must be a priced model, else the whole
    /// submission is rejected with 400).
    public var model: String

    /// The prompt text.
    public var prompt: String

    /// Optional title for this job.
    public var title: String?

    /// Optional system prompt (prepended to the prompt server-side).
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
    /// Jobs to submit (1–100).
    public var jobs: [BatchJob]

    public init(jobs: [BatchJob]) {
        self.jobs = jobs
    }
}

/// Response from batch submission (202 Accepted).
///
/// `jobIds` can be shorter than the input: jobs with an empty `model` or
/// `prompt` are skipped silently, as is any job whose store write failed,
/// and there is no per-index error. Ids are in input order among the
/// accepted jobs, so keep your own mapping when the counts differ.
public struct BatchSubmitResponse: Codable, Sendable {
    /// The IDs of the created jobs (in input order among accepted jobs).
    @NullToEmpty public var jobIds: [String]

    /// Number of jobs created (equals `jobIds.count`).
    public var jobs: Int64

    /// Submission label derived from the accepted count.
    public var batchId: String

    /// Pricing note from the gateway.
    public var pricing: String

    /// Status of the batch submission (always "queued").
    public var status: String

    enum CodingKeys: String, CodingKey {
        case jobs, pricing, status
        case jobIds = "job_ids"
        case batchId = "batch_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _jobIds = try c.decode(NullToEmpty<String>.self, forKey: .jobIds)
        jobs = try c.decodeIfPresent(Int64.self, forKey: .jobs) ?? 0
        batchId = try c.decodeIfPresent(String.self, forKey: .batchId) ?? ""
        pricing = try c.decodeIfPresent(String.self, forKey: .pricing) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
    }
}

/// Alias of ``BatchSubmitResponse``: the JSONL route reuses the array
/// handler and answers with the same envelope.
public typealias BatchJsonlResponse = BatchSubmitResponse

// MARK: - Batch Job Info

/// A batch job as stored by the gateway (`internal/batch.Job`).
public struct BatchJobInfo: Codable, Sendable {
    /// Job identifier.
    public var id: String

    /// "queued" | "running" | "paused" | "complete" | "failed" | "cancelled".
    public var status: String

    /// Queue priority (batch jobs share one low priority).
    public var priority: Int

    /// Job kind ("user_batch" for SDK submissions). Wire field: `type`.
    public var jobType: String

    /// Job title (the submitted one, or one derived from the prompt).
    public var title: String

    /// Prompt as stored (with any system prompt prepended).
    public var prompt: String

    /// Model used for this job.
    public var model: String

    /// Model output (present when complete and stored inline).
    public var output: String?

    /// GCS location of the output when it was too large to inline.
    public var outputGcs: String?

    /// Error message (present when failed).
    public var error: String?

    /// Submitting user id.
    public var createdBy: String

    /// When the job was created (RFC 3339).
    public var createdAt: String

    /// When processing began.
    public var startedAt: String?

    /// When the job finished.
    public var completedAt: String?

    /// Tokens consumed (present once complete).
    public var tokens: Int64

    enum CodingKeys: String, CodingKey {
        case id, status, priority, title, prompt, model, output, error, tokens
        case jobType = "type"
        case outputGcs = "output_gcs"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(String.self, forKey: .status)
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        jobType = try c.decodeIfPresent(String.self, forKey: .jobType) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        output = try c.decodeIfPresent(String.self, forKey: .output)
        outputGcs = try c.decodeIfPresent(String.self, forKey: .outputGcs)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
        tokens = try c.decodeIfPresent(Int64.self, forKey: .tokens) ?? 0
    }
}

/// Response from listing batch jobs.
public struct BatchJobsResponse: Codable, Sendable {
    /// The caller's batch jobs (see `batchJobs()` for the window).
    @NullToEmpty public var jobs: [BatchJobInfo]
}
