import Foundation

// Inference against a self-deployed model.
//
// `POST /qai/v1/inference/{id}` proxies an OpenAI-compatible chat-completion
// request to a Vertex endpoint stood up by `computeDeployModel`. The
// deployment must be `ready`; the caller must own it, or it must be marked
// public. Billing is per token on top of the hourly deployment cost.
//
// The request and response are forwarded verbatim, so both are untyped
// (`[String: AnyCodable]`): the shape is whatever the deployed server speaks
// (vLLM's OpenAI-compatible surface for the catalogue models).

/// One relayed SSE chunk from ``QuantumClient/inferenceStream(deploymentId:body:)``,
/// in the deployed server's own OpenAI-compatible shape.
public typealias InferenceEvent = AgentStreamEvent
