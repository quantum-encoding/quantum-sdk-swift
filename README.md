# QuantumSDK

Swift client SDK for the [Quantum AI API](https://api.quantumencoding.ai).

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/quantum-encoding/quantum-sdk-swift.git", from: "0.4.0"),
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import QuantumSDK

let client = QuantumClient(apiKey: "qai_k_your_key_here")
let response = try await client.chat(
    model: "gemini-2.5-flash",
    messages: [.user("Hello! What is quantum computing?")]
)
print(response.text)
```

## Features

- 110+ endpoints across 10 AI providers and 45+ models
- Swift concurrency with async/await throughout
- Streaming via `AsyncThrowingStream`
- Codable request/response types
- Zero dependencies (URLSession only)
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+
- Agent orchestration with SSE event streams
- GPU/CPU compute rental
- Batch processing (50% discount)

## Examples

### Chat Completion

```swift
import QuantumSDK

let client = QuantumClient(apiKey: "qai_k_your_key_here")

let response = try await client.chat(
    model: "claude-sonnet-4-6",
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
    model: "claude-sonnet-4-6",
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
    print(image.url ?? "base64")
}
```

### Text-to-Speech

```swift
let audio = try await client.speak(
    text: "Welcome to Quantum AI!",
    voice: "alloy",
    format: "mp3"
)
print(audio.audioUrl)
```

### Web Search

```swift
let results = try await client.webSearch("latest Swift releases 2026")
for result in results.results {
    print("\(result.title): \(result.url)")
}
```

### Agent Orchestration

```swift
for try await event in client.agentRun(task: "Research quantum computing breakthroughs") {
    switch event.type {
    case "content_delta": print(event.content ?? "", terminator: "")
    case "done": print("\n--- Done ---")
    default: break
    }
}
```

## All Endpoints

| Category | Endpoints | Description |
|----------|-----------|-------------|
| Chat | 2 | Text generation + session chat |
| Agent | 2 | Multi-step orchestration + missions |
| Images | 2 | Generation + editing |
| Video | 7 | Generation, studio, translation, avatars |
| Audio | 13 | TTS, STT, music, dialogue, dubbing, voice design |
| Voices | 5 | Clone, list, delete, library, design |
| Embeddings | 1 | Text embeddings |
| RAG | 4 | Vertex AI + SurrealDB search |
| Documents | 3 | Extract, chunk, process |
| Search | 3 | Web search, context, answers |
| Scanner | 11 | Code scanning, type queries, diffs |
| Scraper | 2 | Doc scraping + screenshots |
| Jobs | 3 | Async job management |
| Compute | 7 | GPU/CPU rental |
| Keys | 3 | API key management |
| Account | 3 | Balance, usage, summary |
| Credits | 6 | Packs, tiers, lifetime, purchase |
| Batch | 4 | 50% discount batch processing |
| Realtime | 3 | Voice sessions |
| Models | 2 | Model list + pricing |

## Authentication

Pass your API key when creating the client:

```swift
let client = QuantumClient(apiKey: "qai_k_your_key_here")
```

The SDK sends it as the `X-API-Key` header. Both `qai_...` (primary) and `qai_k_...` (scoped) keys are supported. You can also use `Authorization: Bearer <key>`.

Get your API key at [cosmicduck.dev](https://cosmicduck.dev).

## Pricing

See [api.quantumencoding.ai/pricing](https://api.quantumencoding.ai/pricing) for current rates.

The **Lifetime tier** offers 0% margin at-cost pricing via a one-time payment.

## Other SDKs

All SDKs are at v0.4.0 with type parity verified by scanner.

| Language | Package | Install |
|----------|---------|---------|
| Rust | quantum-sdk | `cargo add quantum-sdk` |
| Go | quantum-sdk | `go get github.com/quantum-encoding/quantum-sdk` |
| TypeScript | @quantum-encoding/quantum-sdk | `npm i @quantum-encoding/quantum-sdk` |
| Python | quantum-sdk | `pip install quantum-sdk` |
| **Swift** | QuantumSDK | Swift Package Manager |
| Kotlin | quantum-sdk | Gradle dependency |

MCP server: `npx @quantum-encoding/ai-conductor-mcp`

## API Reference

- Interactive docs: [api.quantumencoding.ai/docs](https://api.quantumencoding.ai/docs)
- OpenAPI spec: [api.quantumencoding.ai/openapi.yaml](https://api.quantumencoding.ai/openapi.yaml)
- LLM context: [api.quantumencoding.ai/llms.txt](https://api.quantumencoding.ai/llms.txt)

## License

MIT
