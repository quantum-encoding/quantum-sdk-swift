# QuantumSDK

Swift SDK for the [Quantum AI API](https://api.quantumencoding.ai) (Cosmic Duck).

**Swift 5.9+ | iOS 16+ | macOS 13+ | tvOS 16+ | watchOS 9+**

Zero dependencies -- uses `URLSession` and `async/await` only.

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/quantum-encoding/quantum-sdk-swift.git", from: "1.0.0"),
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import QuantumSDK

let client = QuantumClient(apiKey: "qai_k_your_key_here")

// Chat
let response = try await client.chat(
    model: "gemini-2.5-flash",
    messages: [.user("Hello! What is quantum computing?")]
)
print(response.text)

// Streaming
for try await event in client.chatStream(
    model: "claude-sonnet-4-6",
    messages: [.user("Write a haiku about Swift")]
) {
    print(event.delta?.text ?? "", terminator: "")
}
```

## Features

### Chat Completions

```swift
// Non-streaming
let response = try await client.chat(
    model: "gpt-5-mini",
    messages: [
        .system("You are a helpful assistant."),
        .user("Explain async/await in Swift"),
    ],
    temperature: 0.7,
    maxTokens: 1000
)
print(response.text)
print("Cost: \(response.costTicks) ticks")

// With tools
let tools = [ChatTool(name: "get_weather", description: "Get current weather", parameters: [
    "type": "object",
    "properties": ["city": ["type": "string"]],
])]
let response = try await client.chat(model: "claude-sonnet-4-6", messages: [.user("Weather in London?")], tools: tools)
```

### Session Chat (Server-Managed History)

```swift
// Start a session
let session = try await client.chatSession(message: "Hello!", model: "gemini-2.5-flash")
print(session.sessionId)

// Continue the conversation
let followUp = try await client.chatSession(
    message: "Tell me more",
    sessionId: session.sessionId
)
```

### Agent Orchestration

```swift
for try await event in client.agentRun(task: "Research the latest AI papers and summarize them") {
    switch event.type {
    case "conductor": print("[Conductor] \(event.content ?? "")")
    case "worker_start": print("[Worker: \(event.worker ?? "")] started")
    case "content_delta": print(event.content ?? "", terminator: "")
    case "done": print("\n--- Done ---")
    default: break
    }
}
```

### Image Generation

```swift
let images = try await client.generateImage(
    model: "grok-imagine-image",
    prompt: "A cosmic duck floating in space",
    size: "1024x1024"
)
for image in images.images {
    print(image.url ?? "base64 data")
}

// Image editing
let edited = try await client.editImage(ImageEditRequest(
    model: "gpt-image-1",
    prompt: "Make the sky purple",
    image: base64ImageData
))
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

### Video Generation

```swift
let video = try await client.generateVideo(
    model: "veo-3.1",
    prompt: "A drone flying over mountains at sunset"
)
print(video.videos.first?.url ?? "")
```

### Embeddings

```swift
let embeddings = try await client.embed(input: "Hello world", model: "text-embedding-3-small")
print(embeddings.embeddings.first?.count ?? 0, "dimensions")
```

### Jobs (Async Processing)

```swift
// Create a 3D generation job
let job = try await client.generate3D(model: "meshy-6", prompt: "a medieval sword")

// Poll until complete
let result = try await client.pollJob(jobId: job.jobId)
print(result.status, result.result ?? "")

// Or stream progress
for try await event in client.streamJob(jobId: job.jobId) {
    print(event.type, event.progress ?? 0)
}
```

### Voice Management

```swift
// List voices
let voices = try await client.listVoices()

// Clone a voice
let cloned = try await client.cloneVoice(CloneVoiceRequest(
    name: "My Voice",
    audioSamples: [base64Audio1, base64Audio2]
))

// Browse shared voice library
let library = try await client.voiceLibrary(query: VoiceLibraryQuery(
    query: "narrator",
    gender: "male",
    language: "en"
))
```

### Credits & Billing

```swift
let balance = try await client.creditBalance()
print("Balance: $\(balance.balanceUsd)")

let packs = try await client.creditPacks()
for pack in packs.packs {
    print("\(pack.name ?? pack.id): $\(pack.priceUsd)")
}
```

### Realtime Voice

```swift
// Get ephemeral token for direct WebSocket connection
let session = try await client.realtimeSession(provider: "xai")
print(session.url, session.ephemeralToken)

// End session when done
try await client.realtimeEnd(sessionId: session.sessionId, durationSeconds: 120)
```

## Error Handling

All methods throw `QuantumError`:

```swift
do {
    let response = try await client.chat(model: "gpt-5-mini", messages: [.user("Hello")])
} catch let error as QuantumError {
    if error.isRateLimit {
        // Back off and retry
    } else if error.isAuth {
        // Invalid or expired API key
    } else if error.isNotFound {
        // Resource not found
    }
    print(error.localizedDescription)
}
```

## Authentication

The SDK uses `X-API-Key` header authentication. Keys come in two formats:

- `qai_...` -- Primary account keys
- `qai_k_...` -- Scoped keys (created via the Keys API)

## API Reference

| Category | Methods |
|----------|---------|
| **Chat** | `chat()`, `chatStream()` |
| **Session** | `chatSession()` |
| **Agent** | `agentRun()`, `missionRun()` |
| **Image** | `generateImage()`, `editImage()` |
| **Audio** | `speak()`, `transcribe()`, `soundEffects()`, `generateMusic()`, `generateMusicAdvanced()`, `dialogue()`, `speechToSpeech()`, `isolateVoice()`, `remixVoice()`, `dub()`, `align()`, `voiceDesign()`, `starfishTTS()` |
| **Finetunes** | `listFinetunes()`, `createFinetune()`, `deleteFinetune()` |
| **Video** | `generateVideo()`, `videoStudio()`, `videoTranslate()`, `videoPhotoAvatar()`, `videoDigitalTwin()`, `videoAvatars()`, `videoTemplates()`, `videoHeygenVoices()` |
| **Embeddings** | `embed()` |
| **Documents** | `extractDocument()`, `chunkDocument()`, `processDocument()` |
| **RAG** | `ragSearch()`, `ragCorpora()`, `surrealRagSearch()`, `surrealRagProviders()` |
| **Models** | `listModels()`, `getPricing()` |
| **Account** | `accountBalance()`, `accountUsage()`, `accountUsageSummary()`, `accountPricing()` |
| **Jobs** | `createJob()`, `getJob()`, `pollJob()`, `listJobs()`, `generate3D()`, `streamJob()` |
| **Keys** | `createKey()`, `listKeys()`, `revokeKey()` |
| **Compute** | `computeTemplates()`, `computeProvision()`, `computeInstances()`, `computeInstance()`, `computeDelete()`, `computeSSHKey()`, `computeKeepalive()` |
| **Voices** | `listVoices()`, `cloneVoice()`, `deleteVoice()`, `voiceLibrary()`, `addVoiceFromLibrary()` |
| **Realtime** | `realtimeSession()`, `realtimeEnd()`, `realtimeRefresh()` |
| **Batch** | `batchSubmit()`, `batchSubmitJsonl()`, `batchJobs()`, `batchJob()` |
| **Credits** | `creditPacks()`, `creditPurchase()`, `creditBalance()`, `creditTiers()`, `devProgramApply()` |
| **Auth** | `authApple()` |
| **Contact** | `contact()` |

## License

MIT
