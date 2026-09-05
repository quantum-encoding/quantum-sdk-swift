# QuantumSDK

Swift client SDK for the [Quantum AI API](https://api.quantumencoding.ai).

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/quantum-encoding/quantum-sdk-swift.git", from: "0.9.0"),
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import QuantumSDK

let client = try QuantumClient(apiKey: "qai_k_your_key_here")
let response = try await client.chat(
    model: "gemini-2.5-flash",
    messages: [.user("Hello! What is quantum computing?")]
)
print(response.text)
```

## Features

- 242 client methods across 10 AI providers and 45+ models
- Swift concurrency with async/await throughout
- Streaming via `AsyncThrowingStream`, and WebSocket realtime voice
- Codable request/response types
- Zero dependencies (URLSession only)
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+
- Retries that never replay a billed POST, with `Idempotency-Key` on every JSON request
- Typed error codes, and errors that never carry a response body or a credential
- Agent orchestration, agent runtime sessions and managed agents over SSE
- Code scanning, GPU/CPU compute rental (requires per-account admin approval)
- Batch processing (async jobs, billed at the real-time rate)

## Examples

### Chat Completion

```swift
import QuantumSDK

let client = try QuantumClient(apiKey: "qai_k_your_key_here")

let response = try await client.chat(
    model: "claude-opus-4-8",
    messages: [
        .system("You are a helpful assistant."),
        .user("Explain protocols in Swift"),
    ],
    temperature: 0.7,
    maxTokens: 1000
)
print(response.text)
```

### Streaming

```swift
for try await event in client.chatStream(
    model: "claude-opus-4-8",
    messages: [.user("Write a haiku about Swift")]
) {
    if let text = event.delta?.text {
        print(text, terminator: "")
    }
}
```

### Image Generation

```swift
let images = try await client.generateImage(
    model: "grok-imagine-image",
    prompt: "A cosmic duck in space",
    size: "1024x1024"
)
for image in images.images {
    print(image.format, image.base64.count)
}
```

### Text-to-Speech

```swift
let audio = try await client.speak(
    text: "Welcome to Quantum AI!",
    model: "gpt-4o-mini-tts",
    voice: "alloy",
    outputFormat: "mp3"
)
print(audio.format, audio.sizeBytes)
```

Audio comes back as base64 in `audioBase64`; no route returns a URL.

### Web Search

```swift
let results = try await client.webSearch(WebSearchRequest(query: "latest Swift releases 2026"))
for result in results.web {
    print("\(result.title): \(result.url)")
}
```

`web`, `news`, `videos` and `discussions` are non-optional and empty when Brave
returned no family for the query.

### Agent Orchestration

```swift
for try await event in client.missionRun(goal: "Research quantum computing breakthroughs") {
    print(event.eventType, event.data.keys.sorted())
}
```

For a single non-streaming turn with tool passthrough, use `agentStep`:

```swift
let reply = try await client.agentStep(AgentRequest(
    model: "claude-sonnet-4-6",
    messages: [.user("List three Swift concurrency pitfalls.")]
))
print(reply.stopReason, reply.content.count)
```

## Surface

242 public client methods. Grouped by what they cover:

| Area | Covers |
|------|--------|
| Chat & sessions | Text generation, streaming, session chat, cost estimation |
| Agents & missions | Single agent steps, mission runs and mission streams |
| Agent runtime | Runtime agents, environments, sessions, session streaming, workspaces |
| Managed agents | Passthrough get/post/delete plus streaming variants |
| Images | Generation and editing |
| Video & avatars | Generation, studio, translation, photo avatars, batch status |
| HeyGen & digital twin | HeyGen v3 video, twin creation, status, consent, twin video |
| Audio & voices | TTS, STT, speech-to-speech, music, dialogue, dubbing, remix, isolate, align, voice design and cloning |
| Realtime | WebSocket voice sessions, gateway and ElevenLabs proxy, ephemeral tokens |
| Vision | Detect, describe, OCR, quality, analyze |
| Embeddings | Text embeddings |
| RAG & collections | Vertex AI and SurrealDB search, corpora, collection proxy |
| Documents | Extract, chunk, process (multipart) |
| Search | Web search, context, answers, Google grounding |
| Code scanner | Scan, upload, diff, verify, audit, vulnerabilities, graphs |
| Jobs & batch | Async job polling and streaming, batch submit and status |
| Compute & Cloud Run | GPU/CPU rental (admin-approved accounts only), deployments, sandboxed orchestration |
| Inference | Dedicated deployments, buffered and streaming |
| Media sessions, files, caches | Session create/list/get/chat/delete, multipart file upload, Gemini context caches |
| Licences | Licence listing, revocations, public key |
| Security | URL and HTML scanning, code scanning, check, blocklist, report |
| Account, keys & credits | Balance, usage, key management and rotation, packs, tiers, lifetime, dev programme |
| Auth | Google, Firebase, Apple, key verification, session revocation |
| Models & pricing | Model list, pricing map, parameters |
| Courses | Learn courses, downloads, publishing |

## Authentication

Pass your API key when creating the client:

```swift
let client = try QuantumClient(apiKey: "qai_k_your_key_here")
```

The SDK sends the key as `Authorization: Bearer <key>` and duplicates it in
`X-API-Key`, for proxies that consume the `Authorization` header before it
reaches the gateway.

Three credential shapes are accepted:

| Prefix | What it is |
|--------|-----------|
| `qai_k_` | A persistent API key. Use this. |
| `qai_eph_` | A short-lived ephemeral key, minted for `internal`-tier callers. |
| `qai_` | A session token from sign-in. It expires; it is not a primary key. |

Both initializers throw and neither traps. `QuantumClient(apiKey:baseURL:session:)`
validates the same way `QuantumClient(configuration:)` does: `invalid_api_key`
for a key that is not a legal header value (a trailing newline read from a file
is the usual cause), `invalid_header` for an extra header that is reserved or
malformed, and `invalidArgument` for a base URL that does not parse as `http` or
`https` with a host.

Get your API key at [cosmicduck.dev](https://cosmicduck.dev).

## Pricing

See [api.quantumencoding.ai/pricing](https://api.quantumencoding.ai/pricing) for current rates.

The **Lifetime tier** offers 0% margin at-cost pricing via a one-time payment.

## Other SDKs

The Rust crate is the reference implementation. The other SDKs track it at
their own pace and do not all expose the same surface yet — check the version
before assuming a method exists.

| Language | Package | Version | Install |
|----------|---------|---------|---------|
| Rust | quantum-sdk | 0.9.0 | `cargo add quantum-sdk` |
| Go | quantum-sdk | 0.7.0 | `go get github.com/quantum-encoding/quantum-sdk` |
| TypeScript | @quantum-encoding/quantum-sdk | 0.7.1 | `npm i @quantum-encoding/quantum-sdk` |
| Python | quantum-sdk | 0.7.1 | `pip install quantum-sdk` |
| **Swift** | QuantumSDK | 0.9.0 | Swift Package Manager |
| Kotlin | quantum-sdk | 0.5.0 | Gradle dependency |

MCP server: `npx @quantum-encoding/ai-conductor-mcp`

## API Reference

- Interactive docs: [api.quantumencoding.ai/docs](https://api.quantumencoding.ai/docs)
- OpenAPI spec: [api.quantumencoding.ai/openapi.yaml](https://api.quantumencoding.ai/openapi.yaml)
- LLM context: [api.quantumencoding.ai/llms.txt](https://api.quantumencoding.ai/llms.txt)

## License

MIT
