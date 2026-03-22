import Foundation

// MARK: - Missing Parity Methods

extension QuantumClient {

    /// Submit a chat completion as an async job.
    ///
    /// Useful for long-running models (e.g. Opus) where synchronous
    /// `/qai/v1/chat` may time out. Use `streamJob()` or `pollJob()` to get the result.
    ///
    /// ```swift
    /// let job = try await client.chatJob(ChatRequest(
    ///     model: "claude-opus-4-6",
    ///     messages: [.user("Summarize all of Wikipedia")]
    /// ))
    /// for try await event in client.streamJob(jobId: job.jobId) {
    ///     print(event.type, event.status ?? "")
    /// }
    /// ```
    public func chatJob(_ request: ChatRequest) async throws -> JobCreateResponse {
        // Encode the ChatRequest to JSON, then decode as [String: AnyCodable] for the job params.
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let params = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        return try await createJob(type: "chat", params: params)
    }

    /// Query compute billing from BigQuery via the QAI backend.
    ///
    /// - Parameter request: Billing query filters (instance ID, date range).
    /// - Returns: Billing entries and total cost.
    public func computeBilling(_ request: BillingRequest) async throws -> BillingResponse {
        let (data, _): (BillingResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/compute/billing", body: request
        )
        return data
    }
}
