// ParameterSpec — per-model generation parameter schema.
//
// Returned by `GET /qai/v1/models` under each model's `parameters` field.
// Describes what the model supports, not how to render it — clients pick
// the renderer (menu / stepper / slider) based on the semantic `kind`.
//
// Schema version lives on ``ModelsResponse/schemaVersion``. The parser
// tolerates unknown `kind` values (they decode as `.unknown` and should be
// skipped by renderers) so rolling out new kinds server-side doesn't break
// older clients.

import Foundation

// MARK: - ParameterSpec

/// One adjustable generation parameter of a model.
public struct ParameterSpec: Codable, Identifiable, Hashable, Sendable {
    /// Wire ID of the parameter (e.g. "temperature").
    public var id: String

    /// Human-readable label.
    public var label: String

    /// Semantic kind that picks the client-side renderer.
    public var kind: Kind

    /// Allowed values, for `.enum` kinds.
    public var values: [String]?

    /// Server-side default.
    public var defaultValue: ParameterValue?

    /// Minimum, for numeric kinds.
    public var min: Double?

    /// Maximum, for numeric kinds.
    public var max: Double?

    /// Step increment, for numeric kinds.
    public var step: Double?

    /// Whether the parameter must be sent.
    public var required: Bool?

    /// Gating on other parameters' values.
    public var availability: Availability?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case kind
        case values
        case defaultValue = "default"
        case min
        case max
        case step
        case required
        case availability
    }

    public init(
        id: String,
        label: String,
        kind: Kind,
        values: [String]? = nil,
        defaultValue: ParameterValue? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil,
        required: Bool? = nil,
        availability: Availability? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.values = values
        self.defaultValue = defaultValue
        self.min = min
        self.max = max
        self.step = step
        self.required = required
        self.availability = availability
    }

    /// Parameter kind. Unknown wire values decode as `.unknown` for
    /// forward compatibility.
    public enum Kind: String, Codable, Sendable {
        case `enum`
        case integer
        case float
        case boolean
        case string
        case range
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unknown
        }
    }

    /// Whether this parameter is gated on another parameter's value.
    /// `requires` entries are AND-ed; each entry is `"id=value"`.
    public struct Availability: Codable, Hashable, Sendable {
        public var requires: [String]?

        public init(requires: [String]? = nil) {
            self.requires = requires
        }
    }
}

// MARK: - ParameterValue

/// Heterogeneous JSON-like value carried in `default` and in user-selected
/// settings. Supports the four primitive shapes the schema uses.
public enum ParameterValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    // MARK: Codable

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        throw DecodingError.dataCorruptedError(
            in: c,
            debugDescription: "ParameterValue must be string/int/double/bool"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        }
    }

    // MARK: Convenience accessors

    public var stringValue: String? {
        switch self {
        case .string(let v): return v
        case .int(let v):    return String(v)
        case .double(let v): return String(v)
        case .bool(let v):   return String(v)
        }
    }

    public var intValue: Int? {
        switch self {
        case .int(let v):    return v
        case .double(let v): return Int(v)
        case .string(let v): return Int(v)
        case .bool(let v):   return v ? 1 : 0
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v):    return Double(v)
        case .string(let v): return Double(v)
        case .bool(let v):   return v ? 1 : 0
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let v):   return v
        case .int(let v):    return v != 0
        case .string(let v): return Bool(v)
        case .double(let v): return v != 0
        }
    }
}

// MARK: - Availability resolution

extension ParameterSpec {
    /// Returns true if this parameter should be shown given the current
    /// user-selected values. Absent availability means always visible.
    public func isAvailable(given selections: [String: ParameterValue]) -> Bool {
        guard let req = availability?.requires, !req.isEmpty else { return true }
        for clause in req {
            // Each clause is "param_id=value" (value string-comparable).
            let parts = clause.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let (id, expected) = (parts[0], parts[1])
            let current = selections[id]?.stringValue ?? ""
            if current != expected { return false }
        }
        return true
    }
}
