import XCTest
// Not @testable: these compile against the public API exactly as a
// consumer of the package does, so a missing `public` is a failure here.
import QuantumSDK

/// Every Swift block in README.md, transcribed verbatim. A sample that stops
/// compiling is a documentation bug: it is the first thing a new caller
/// copies. Regenerate from the README rather than editing by hand.
///
/// Each block sits in a closure that is assigned and discarded, never called.
/// The closure is still fully type-checked, so these are compile guards — they
/// must not reach the network, and a sample that runs would bill a real key.
final class ReadmeExampleTests: XCTestCase {
    /// README block 2.
    func testReadmeBlock2Compiles() {
        let example: () async throws -> Void = {

            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            let response = try await client.chat(
                model: "gemini-2.5-flash",
                messages: [.user("Hello! What is quantum computing?")]
            )
            print(response.text)
        }
        _ = example
    }

    /// README block 3.
    func testReadmeBlock3Compiles() {
        let example: () async throws -> Void = {

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
        }
        _ = example
    }

    /// README block 4.
    func testReadmeBlock4Compiles() {
        let example: () async throws -> Void = {
            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            for try await event in client.chatStream(
                model: "claude-opus-4-8",
                messages: [.user("Write a haiku about Swift")]
            ) {
                if let text = event.delta?.text {
                    print(text, terminator: "")
                }
            }
        }
        _ = example
    }

    /// README block 5.
    func testReadmeBlock5Compiles() {
        let example: () async throws -> Void = {
            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            let images = try await client.generateImage(
                model: "grok-imagine-image",
                prompt: "A cosmic duck in space",
                size: "1024x1024"
            )
            for image in images.images {
                print(image.format, image.base64.count)
            }
        }
        _ = example
    }

    /// README block 6.
    func testReadmeBlock6Compiles() {
        let example: () async throws -> Void = {
            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            let audio = try await client.speak(
                text: "Welcome to Quantum AI!",
                model: "gpt-4o-mini-tts",
                voice: "alloy",
                outputFormat: "mp3"
            )
            print(audio.format, audio.sizeBytes)
        }
        _ = example
    }

    /// README block 7.
    func testReadmeBlock7Compiles() {
        let example: () async throws -> Void = {
            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            let results = try await client.webSearch(WebSearchRequest(query: "latest Swift releases 2026"))
            for result in results.web {
                print("\(result.title): \(result.url)")
            }
        }
        _ = example
    }

    /// README block 8.
    func testReadmeBlock8Compiles() {
        let example: () async throws -> Void = {
            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            for try await event in client.missionRun(goal: "Research quantum computing breakthroughs") {
                print(event.eventType, event.data.keys.sorted())
            }
        }
        _ = example
    }

    /// README block 9.
    func testReadmeBlock9Compiles() {
        let example: () async throws -> Void = {
            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            let reply = try await client.agentStep(AgentRequest(
                model: "claude-sonnet-4-6",
                messages: [.user("List three Swift concurrency pitfalls.")]
            ))
            print(reply.stopReason, reply.content.count)
        }
        _ = example
    }

    /// README block 10.
    func testReadmeBlock10Compiles() {
        let example: () async throws -> Void = {
            let client = try QuantumClient(apiKey: "qai_k_your_key_here")
            _ = client
        }
        _ = example
    }

    /// Construction validates rather than trapping, so every block above
    /// needs a `try`. These assert the two failure modes the README names.
    func testReadmeClaimAboutThrowingInitializers() {
        XCTAssertThrowsError(try QuantumClient(apiKey: "qai_k_from_a_file\n")) { error in
            guard case let .api(_, code, _, _) = error as? QuantumError ?? QuantumError.cancelled else {
                return XCTFail("expected an api error, got \(error)")
            }
            XCTAssertEqual(code, "invalid_api_key")
        }
        XCTAssertThrowsError(try QuantumClient(apiKey: "qai_k_test", baseURL: "file:///etc"))
    }
}
