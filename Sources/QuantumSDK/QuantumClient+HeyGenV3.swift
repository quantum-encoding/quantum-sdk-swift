import Foundation

// MARK: - HeyGen v3: Avatar Realtime (Broadcast)

extension QuantumClient {
    /// Create a live avatar realtime session (HeyGen Broadcast).
    ///
    /// PREPAID: the entire `maxDurationSeconds` block (1–3600 s) is charged
    /// at create time; cancelling early does NOT refund.
    ///
    /// Poll ``getAvatarRealtimeSession(streamId:)`` (~2s) until
    /// `status == "streaming"`, then play `hlsUrl`.
    public func createAvatarRealtimeSession(
        _ request: AvatarRealtimeRequest,
        idempotencyKey: String? = nil
    ) async throws -> AvatarRealtimeCreateResponse {
        let (data, meta): (AvatarRealtimeCreateResponse, HTTPClient.ResponseMeta) = try await http.doJSON(
            method: "POST", path: "/qai/v1/avatar/realtime", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        // Fill billing fields from the X-QAI-* headers when the body didn't
        // carry them (Receipt Pattern; matches the Rust reference SDK).
        var response = data
        if response.costTicks == 0 { response.costTicks = Int64(meta.costTicks) }
        if response.balanceAfter == nil { response.balanceAfter = meta.balanceAfter }
        if response.requestId.isEmpty { response.requestId = meta.requestId }
        return response
    }

    /// Get the live status of an avatar realtime session.
    ///
    /// Poll (~2s) until `status == "streaming"`, then play `hlsUrl`.
    /// "completed" and "error" are terminal. text_stream sessions idle out
    /// after ~30s without new text.
    public func getAvatarRealtimeSession(streamId: String) async throws -> AvatarRealtimeStatusResponse {
        let (data, _): (AvatarRealtimeStatusResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/avatar/realtime/\(streamId)"
        )
        return data
    }

    /// Append a text delta to a `text_stream` session (or close it with
    /// ``AvatarRealtimeTextRequest/finalMarker()``).
    public func sendAvatarRealtimeText(
        streamId: String,
        _ request: AvatarRealtimeTextRequest
    ) async throws -> AvatarRealtimeTextResponse {
        let (data, _): (AvatarRealtimeTextResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/avatar/realtime/\(streamId)/text", body: request
        )
        return data
    }

    /// Append a text delta to a `text_stream` session.
    ///
    /// - Parameters:
    ///   - delta: Text fragment to append (may be empty only when `final` is true).
    ///   - final: True closes the text input.
    public func sendAvatarRealtimeText(
        streamId: String,
        delta: String,
        final: Bool = false
    ) async throws -> AvatarRealtimeTextResponse {
        try await sendAvatarRealtimeText(
            streamId: streamId,
            AvatarRealtimeTextRequest(delta: delta, isFinal: final)
        )
    }

    /// Terminate an avatar realtime session early (idempotent; no refund —
    /// this only stops HeyGen's upstream meter).
    public func cancelAvatarRealtimeSession(streamId: String) async throws -> AvatarRealtimeCancelResponse {
        let (data, _): (AvatarRealtimeCancelResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/avatar/realtime/\(streamId)/cancel"
        )
        return data
    }
}

// MARK: - HeyGen v3: Sounds Search

extension QuantumClient {
    /// Search HeyGen's background-music and sound-effects catalogs
    /// (semantic ranking, best score first). Unbilled catalog route.
    ///
    /// `audioUrl` values are pre-signed WAV links with a limited lifetime —
    /// download promptly, do not cache.
    public func searchAudioSounds(_ query: AudioSoundsQuery) async throws -> AudioSoundsResponse {
        var params: [String] = [
            "query=\(query.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query.query)"
        ]
        if let t = query.soundType { params.append("type=\(t)") }
        if let limit = query.limit { params.append("limit=\(limit)") }
        if let minScore = query.minScore { params.append("min_score=\(minScore)") }
        if let token = query.token {
            params.append("token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)")
        }
        let path = "/qai/v1/audio/sounds?" + params.joined(separator: "&")

        let (data, _): (AudioSoundsResponse, _) = try await http.doJSON(method: "GET", path: path)
        return data
    }
}

// MARK: - HeyGen v3: Template Render + Batch

extension QuantumClient {
    /// Inspect a HeyGen template's variable schema and scenes (unbilled).
    ///
    /// Only draft-v4 templates with variables are supported upstream; an
    /// unknown template id surfaces as a `provider_error`.
    public func videoTemplateDetail(templateId: String) async throws -> VideoTemplateDetailResponse {
        let (data, _): (VideoTemplateDetailResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/video/template/\(templateId)"
        )
        return data
    }

    /// Render a video from a HeyGen template (async job type
    /// "video/template-v3").
    ///
    /// Returns the accepted-job envelope — poll with ``getJob(jobId:)`` /
    /// ``pollJob(jobId:interval:maxAttempts:)`` (or SSE via
    /// ``streamJob(jobId:)``) until "completed"/"failed", then read
    /// `result.video_url`. Deep validation happens at execution time, so
    /// violations surface as a failed job rather than a 4xx at submit.
    public func videoTemplateGenerate(
        templateId: String,
        _ request: VideoTemplateGenerateRequest,
        idempotencyKey: String? = nil
    ) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/template/\(templateId)", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Submit 1–100 raw HeyGen video payloads as one batch (202 Accepted).
    ///
    /// Poll ``videoBatchStatus(batchId:query:)`` for progress and delivery.
    public func videoBatchSubmit(
        _ request: VideoBatchSubmitRequest,
        idempotencyKey: String? = nil
    ) async throws -> VideoBatchSubmitResponse {
        let (data, _): (VideoBatchSubmitResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/batch", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Get a batch's status plus one cursor-paginated page of items.
    ///
    /// Poll (~5s) until `status` is terminal, then keep polling until
    /// `billingStatus == "settled"` — per-item `videoUrl` values are
    /// withheld until settlement. Collect URLs across pages via `nextToken`.
    public func videoBatchStatus(
        batchId: String,
        query: VideoBatchStatusQuery? = nil
    ) async throws -> VideoBatchStatusResponse {
        var params: [String] = []
        if let limit = query?.limit { params.append("limit=\(limit)") }
        if let token = query?.token {
            params.append("token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)")
        }
        var path = "/qai/v1/video/batch/\(batchId)"
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }

        let (data, _): (VideoBatchStatusResponse, _) = try await http.doJSON(method: "GET", path: path)
        return data
    }
}
