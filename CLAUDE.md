# quantum-sdk-swift

## SDK Parity Check

This SDK must stay in sync with the Rust reference SDK. Use `sdk-graph` to check parity.

`sdk-graph` resolves its graph file against the **working directory**, so run
every command from the collection root. Run it from anywhere else and you
silently start a second graph holding only the SDKs you happened to scan there.

```bash
cd ~/work/poly-repo/quantum-ai-polyrepo/qe-sdk-collection

sdk-graph scan --sdk swift --dir swift_projects/quantum-sdk/Sources  # after making changes
sdk-graph scan --sdk rust  --dir rust_projects/quantum-sdk/src       # if not recently scanned
sdk-graph diff --base rust --target swift                            # what Swift is missing
sdk-graph stats
```

- Binary: `~/go/bin/sdk-graph` (in PATH)
- Source: `~/work/poly-repo/quantum-ai-polyrepo/quantum-ai-backend/cmd/sdk-graph/main.go`
- Graph: `~/work/poly-repo/quantum-ai-polyrepo/qe-sdk-collection/sdk-graph.json`

A stale graph from 2026-03-23 sits at `quantum-ai-backend/sdk-graph.json`.
Nothing reads it — don't inspect it or treat its counts as current.

## Workflow

1. Before starting work: run `sdk-graph diff --base rust --target swift` to see current gaps
2. After adding types/fields: rescan with `sdk-graph scan`
3. Verify gap reduced: run diff again
4. Goal: no *unintended* missing types or fields vs Rust

## Reading the diff

The diff is a name-and-tag comparison, so it reports shape differences it
cannot judge. These rows are intended divergence — do not "fix" them:

- `Error`, `ApiError` — Swift's equivalent is `QuantumError`.
- `OcrResult`, `SecurityScanHtmlRequest`, `SecurityScanUrlRequest` — Swift uses
  correct acronym casing: `OCRResult`, `SecurityScanHTMLRequest`,
  `SecurityScanURLRequest`.
- `StreamEvent`, `AgentStreamEvent` — Swift models these tagged unions as an
  `enum` with associated values; the diff reads each Rust field as missing
  because an enum records no fields.
- The `Scrape*` / `Screenshot*` types — those gateway routes were retired to
  close an abuse vector. Rust still carries deprecated stubs; Swift carries
  nothing. This gap is permanent by design.
- Types that are `Sendable` but not `Codable`: the multipart document bodies
  (`DocumentRequest`, `ChunkDocumentRequest`, `ProcessDocumentRequest`), the
  query-parameter configs (`AudioSoundsQuery`, `ElevenLabsProxyConfig`), the
  local stream wrappers (`StreamSession`, `SessionChatStream`,
  `StreamToolUseInputDelta`) and `RuntimeAgentUpdate`. None of these travels as
  JSON — their properties are read as form parts, query values or plain Swift —
  so they have no `CodingKeys`, and the diff compares a camelCase property name
  against a snake_case wire tag that was never there.
- `balance_after` on `TtsResponse`, `SttResponse` and `MusicResponse`. The
  gateway sends it as the `X-QAI-Balance-After` header, and
  `QuantumClient.lastResponseMeta` is the documented way to read per-request
  cost for a response that does not carry it inline.

Anything else in the diff is worth investigating against the Rust source before
changing Swift: the scanner has had blind spots before (property-wrapped
fields, typealiases and serde renames were all invisible until fixed), so
confirm a row is real by reading both declarations.

## Reference Implementation

The Rust SDK is the source of truth: `~/work/poly-repo/quantum-ai-polyrepo/qe-sdk-collection/rust_projects/quantum-sdk/src/`

When adding missing types, follow the Rust SDK's field names and JSON serialization. Map types idiomatically:
- Rust `Option<T>` → Swift `T?`
- Rust `Vec<T>` → Swift `[T]`
- Rust `String` → Swift `String`
- Rust `serde(rename = "snake_case")` → Swift `CodingKeys` enum with `case camelCase = "snake_case"`
- A type that travels as JSON conforms to `Codable, Sendable`. One that does not
  — a multipart body, a query-parameter config, a local wrapper around a stream
  — is `Sendable` only, and adding `Codable` to it would invent a wire shape
  that nothing reads.
- Rust `#[serde(flatten)]` → an `extra: [String: AnyCodable]` encoded into the
  same container as the typed keys; see `ImageRequest` and the helpers in
  `Models/WireDecoding.swift`.

## API Server

Backend: https://api.quantumencoding.ai
Repo: ~/work/poly-repo/quantum-ai-polyrepo/quantum-ai-backend
