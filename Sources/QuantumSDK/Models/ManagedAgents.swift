import Foundation

// Anthropic Managed Agents passthrough.
//
// `/qai/v1/managed-agents/<rest>` is a thin reverse proxy onto Anthropic's
// hosted Managed Agents REST surface (`agents`, `environments`, `sessions`,
// `deployments`, `vaults`). The gateway injects the org's Anthropic
// credentials and the beta headers, so the client never holds the provider
// key, and egress goes through the gateway's SSRF-safe pool.
//
// This passthrough is admin-only. Managed Agents spend Anthropic credits the
// gateway cannot meter inline, so the fail-closed billing rule restricts it.
// End-user managed-agent work goes through the mirrored agent-runtime
// surface (`Models/AgentRuntime.swift`), which is metered.
//
// Paths and query strings are forwarded verbatim after the prefix, and the
// upstream shapes are Anthropic's rather than the gateway's, so the bodies
// are untyped: `[String: AnyCodable]` in and out. `..` segments are rejected.

/// An event from a Managed Agents SSE stream, relayed unbuffered from
/// Anthropic. The shape is Anthropic's; see ``AgentStreamEvent``.
public typealias ManagedAgentsEvent = AgentStreamEvent
