# Changelog

## 0.9.0 — unreleased

Parity with the Rust reference crate at 0.9.0, and with the gateway as of
September 2026. Every request body now carries the keys its handler reads, and
every response type decodes the shape its handler writes.

### Added

- New surfaces: the agent runtime (agents, environments, sessions with an SSE
  stream, workspaces), the managed-agents passthrough, media sessions, files
  (multipart upload), Gemini context caches, licences, the code scanner (scan,
  upload, diff, verify, audit, vulnerabilities, scans and their types and
  graph), Cloud Run over SSE, and dedicated inference endpoints buffered and
  streaming.
- Realtime voice over `URLSessionWebSocketTask`: `realtimeConnect` through the
  gateway proxy and `elevenlabsConnect` through the ElevenLabs proxy, with a
  sender/receiver pair whose close frames and transport errors surface as
  events rather than as a silent end of stream.
- `agentStep`, on the real `POST /qai/v1/agent` contract — one non-streaming
  turn with tool passthrough. `agentRun` had been a second mission stream.
- Core methods the reference already had: `authGoogle`, `authFirebase`,
  `verifyKey`, `revokeSession`, `listDeviceKeys`, `rotateKey`, `keyUsage`,
  `createEphemeralKey`, `createPartnerKey`, `lifetimePlans`,
  `lifetimePurchase`, `accountDelete`, `accountDeletionStatus`, `estimateChat`,
  `chatSessionStream`. Plus `googleSearch`, `audioSTTRealtimeToken`,
  `securityScanCode` and `collectionsSearchFull`.
- `MissionRequest` and `MissionCreateRequest` carry `context` and
  `useContext`. Both mission routes decode the same gateway struct and both
  prepend the context to the goal, so reference material can travel with a goal
  the way the playground sends it.
- `ClientConfiguration`: a per-client timeout, an `app` header, caller-supplied
  extra headers, and a custom `URLSession`. `Authorization` and `X-API-Key` are
  reserved and naming either fails construction rather than being silently
  overridden.
- A typed `ErrorCode` with `typedCode` on the API error, folding the gateway's
  legacy lowercase `type` strings onto the same variants the reference uses.
- `@NullToEmpty`, `@NullToEmptyMap` and `@BraveResults` in
  `Models/WireDecoding.swift` and `Models/Search.swift`, for the list and map
  fields a nil Go slice or map serialises as `null`. Both a `null` and an absent
  key decode to empty, which is what removed most of the decode failures below.
- `extra` on `ImageRequest` and `VideoRequest`: a `[String: AnyCodable]`
  flattened into the top-level body, for the catalog-schema-driven parameters a
  model accepts that have no typed field here — `negative_prompt`,
  `person_generation`, `resolution`, `generate_audio`. The reference forwards
  these with `#[serde(flatten)]`, and without an equivalent a Swift caller
  could not send them at all. Empty by default, and an empty map is invisible on
  the wire.
- Complete strict-concurrency checking on the library target. A data race here
  is a compile error in a consumer's Swift 6 language-mode build, so it is one
  here too.

### Changed (breaking)

- **Both initializers throw.** `QuantumClient(apiKey:baseURL:session:)` and
  `QuantumClient(configuration:)` validate instead of trapping: `invalid_api_key`
  for a key that cannot be an HTTP header value (a trailing newline read from a
  file is the usual cause), `invalid_header` for a reserved or malformed extra
  header, `invalidArgument` for a base URL that does not parse as `http` or
  `https` with a host. Construction used to `fatalError` on a bad base URL,
  which took the host process with it. There is no `fatalError` left in the
  package, and no forced cast on a response.
- **Retries.** A POST is replayed only on 429, never on 502/503/504; a GET
  replays on all four. `Retry-After` is honoured on 429 and clamped to 30 s,
  with a 0.5 s / 1 s / 2 s backoff only when the header is absent. A 502 that
  wraps a permanent provider error — a moderation block, say — is not replayed
  at all. `Idempotency-Key` now rides every JSON POST and is reused across
  replays, where it used to be minted fresh per call on ten routes and absent
  from the rest, so it could never match an earlier attempt.
  `doJSONIdempotent` opts a deduping route into 5xx replay explicitly.
- **`ChatResponse` requires `id` and `model`.** A gateway error envelope
  written with a 2xx status used to decode into an empty success, so a
  moderation block on a billed request looked like a delivered completion with
  no text. Failing to decode routes the body to the error-envelope check and
  surfaces `.api` with the envelope's own code. An empty `model` is still
  allowed and backfilled from `X-QAI-Model`.
- `Collection` is `RagCollection`. The old name remains as a public typealias,
  so existing callers compile. Bare `Collection` was also the standard-library
  protocol, and any consumer writing it unqualified still has to qualify it —
  that ambiguity is why the type moved.
- `ChatRequest.capabilities` is gone. The gateway's chat request has no such
  field, so the value was discarded and every tool was forwarded regardless: a
  "Safe Mode" that did nothing. The three-state allowlist lives on
  `AgentRequest`, where `/qai/v1/agent` reads it — `nil` forwards every tool,
  `[]` forwards none, a list forwards those named.
- Streaming uses its own `URLSession` with the idle timeout removed, and the
  buffered default timeout is 600 s so the gateway's own five-minute media
  deadline arrives first. One session used to serve both, so a five-minute gap
  between SSE bytes aborted a stream that was still alive.
- `getPricing` returns `[String: PricingInfo]`. The gateway keys that object by
  model id; decoding it as an array always failed.
- A URL passed to `securityCheck` is encoded with an RFC 3986 unreserved set
  only. `.urlQueryAllowed` left `?`, `&` and `=` alone, so a checked URL that
  carried its own query string was split into several parameters and the
  registry was consulted for the truncated part — a blocked URL with a query
  came back `blocked: false`. Query values elsewhere are strictly encoded too.
- `RealtimeSession` redacts `ephemeralToken` and `signedUrl` in its
  `description`, `debugDescription` and reflection. The ElevenLabs signed URL
  carries its own authentication, and default reflection prints every stored
  property, so one `print(session)` leaked a live credential.

### Removed

- The scraper surface — `ScrapeTarget`, `ScrapeRequest`, `ScrapeResponse` and
  the five screenshot types. The gateway retired `/qai/v1/scraper/*` to close an
  abuse vector: it was an open proxy for fetching arbitrary URLs and capturing
  arbitrary pages. The Rust crate still carries both methods as deprecated
  stubs that 404; Swift carries nothing, because removing a route that exists
  to be abused is not a change that warrants a deprecation window.
- `computeBilling`, `workspaceUpload` and `workspaceDownload`. None of the three
  routes is registered, so all three answered 404 or 405.
- `AgentEvent`, `MissionEvent` and the parsers that built them —
  `makeSSEStream`, `parseAgentEvent`, `parseMissionEvent`, `RawAgentEvent`.
  `AgentStreamEvent` and `MissionStreamEvent` are the shapes the live streams
  yield; nothing returned the two removed structs.
- Duplicate shapes for one wire object, consolidated to one type each.

### Fixed

Requests the gateway rejected outright, or accepted while ignoring the field
that mattered:

- Documents: `extractDocument`, `chunkDocument` and `processDocument` post
  multipart with a `file` part, not a JSON body. `chunk_size` and `overlap` are
  characters, not tokens.
- `batchSubmitJsonl` sends the raw NDJSON body. It wrapped the whole file in
  `{"jsonl": "…"}`, which the gateway split by line and found no job in.
- `streamJob` opens a GET SSE stream. It posted a body to a route registered
  only as `GET /qai/v1/jobs/{id}/stream`, which answered 405 and yielded no
  event at all.
- Audio: `DubRequest` sends `target_lang`/`source_lang`; `VoiceDesignRequest`
  sends `voice_description` and the required `sample_text`;
  `SpeechToSpeechRequest` and `StarfishTTSRequest` carry the required
  `voice_id`; `RemixVoiceRequest` reaches the attribute knobs the route reads
  (`gender`, `accent`, `style`, `pacing`, `audio_quality`, `prompt_strength`,
  `script`) instead of three it ignores.
- Voice library search sends `q` and paginates on `last_sort_id`. It sent
  `query`, which the gateway dropped, and read a cursor key the gateway never
  emitted, so `hasMore` could not be followed.
- Video: `StudioVideoRequest` and `TranslateRequest` carry the keys their
  routes require, and the two-argument `videoDigitalTwin` no longer omits the
  `voice_id` the twin-video route requires whenever a script is present.
- `collectionsSearch` posts to `/qai/v1/rag/collections/search`, not
  `/qai/v1/rag/search/collections`. `collectionsGet` decodes the
  `{collection, documents}` envelope the handler writes. `collectionsDocuments`
  reads that same envelope instead of a route that does not exist.

Responses that could not decode, each of which failed after the call was billed:

- `accountBalance` and `creditPacks` always threw. The wire keys are
  `balance_ticks`/`balance_usd`/`ticks_per_usd` and `amount_usd`/`ticks`;
  neither type named them, so the balance check and the purchase flow could not
  start.
- `CreditTier` had the wire shape at last — `tier`, `label`, `margin_percent`,
  `description`, `requirements`. Every field it used to declare was always nil.
- `chatSession` no longer throws on an ordinary turn. `SessionContext.compacted`
  is `omitempty` on the wire, so it is absent from every non-compacted turn and
  the reply was discarded after the provider had run and the user had paid.
- `AuthResponse` keeps the persistent `api_key` minted at sign-in, plus
  `expires_at` and `credit_usd`. It decoded the session token and the user id
  only, leaving a caller with an expiring credential as its only one.
  `AuthAppleRequest` can now send `nonce`, `device_id` and
  `authorization_code`, without which replay protection was never enforced for
  this SDK's sign-ins.
- `DevProgramApplyRequest` sends `expected_monthly_usd`, the key the gateway
  reads. It sent `expected_usd`, so the value was dropped and the application
  stored as zero.
- Vision responses decode a normal reply. The gateway marks every array
  `omitempty` and each profile omits the other profiles' keys, so requiring
  both `tags` and `objects` made `visionDetect`, `visionDescribe`, `visionOCR`
  and `visionQuality` throw on a successful, billed call.
- `pollJob` no longer throws on its first poll of an unsettled job:
  `cost_ticks` is `omitempty` and absent while a job is pending or running.
- `webSearch` reads Brave's `{results: […]}` families. They are relayed
  verbatim, so decoding them as bare arrays failed every search.
- `SecurityAssessment.findings` decodes a clean page, which serialises
  `"findings": null`, and `securityBlocklist(status:)` decodes community-report
  entries, which carry none of the fields a confirmed entry has.
- `BatchJobInfo` uses the wire object's `id` key and its status vocabulary.
- Mission list and get decode a mission in any state. Both required
  non-optional fields that only some paths write, so listing one mission failed
  and reading a pending or running one failed.
- `missionStream` reaches its `mission_completed` event. `MissionCost` declared
  the per-tier costs as `Int?` where the wire sends `{Prompt, Completion}`
  objects, so the final event of every non-codegen run threw.

Streams:

- A stream that ends without `[DONE]` yields a final event marked
  `transport: true` and `done: true` instead of finishing normally, so a
  truncated run cannot be read as a completed one. A payload that fails to parse
  yields an `error` event and the stream continues.
- The failure types `invalid_request` and `rate_limit` fill `error` the way
  `error` does. Both carry a `message`, and only `error` was being read, so a
  rate-limited stream produced a text-less event and then ended.
- `citations` events are no longer discarded on the streaming path, and a
  failed mission's reason reaches the caller: the gateway puts it in `message`,
  which is now the fallback for `error`.
- Errors never carry a response body or a credential. A decode failure reports
  the decoding error only, and a non-JSON error body is summarised rather than
  copied, so an upstream HTML page cannot land verbatim in a log.

### Documentation

- Every Swift sample in the README compiles, and `ReadmeExampleTests` holds the
  blocks verbatim against the public API so a sample that stops building fails
  the test suite. Four of the seven did not compile.
- Claims that were not true are gone: a visionOS platform the package does not
  declare, an endpoint table counting the retired scraper category, "all SDKs
  are at v0.4.0 and share the same type surface" when they span 0.5.0 to 0.9.0
  and agreeing on a surface is the work in progress, and a key-prefix table
  that called an expiring `qai_` session token the primary key.
- Doc comments describe what the code does rather than how it got there, and
  say where a limit is enforced. `AvatarRealtimeRequest` no longer implies the
  SDK checks `voiceId` against `audio`: the gateway reserves the prepaid block
  first, the upstream rejects the combination, the hold is released, and the
  caller gets a 502 where a 400 belongs.
