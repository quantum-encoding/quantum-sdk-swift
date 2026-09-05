import Foundation

/// A list field the gateway may serialise as `null` (a nil Go slice) or omit
/// entirely; both decode to an empty array instead of failing.
///
/// `JSONDecoder` treats an explicit `null` on a non-optional `[T]` as a type
/// mismatch and a missing key as `keyNotFound`. Wrapping the property makes
/// both cases `[]`, so callers never branch on nil for "no results":
///
/// ```swift
/// public struct VoicesResponse: Codable {
///     @NullToEmpty public var voices: [Voice]
/// }
/// ```
@propertyWrapper
public struct NullToEmpty<Element: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [Element]

    public init(wrappedValue: [Element] = []) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = container.decodeNil() ? [] : try container.decode([Element].self)
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension NullToEmpty: Equatable where Element: Equatable {}
extension NullToEmpty: Hashable where Element: Hashable {}

extension KeyedDecodingContainer {
    /// A missing key decodes to an empty list (synthesised `Codable` routes
    /// wrapped properties through this overload).
    public func decode<E>(_ type: NullToEmpty<E>.Type, forKey key: Key) throws -> NullToEmpty<E> {
        try decodeIfPresent(type, forKey: key) ?? NullToEmpty()
    }
}

/// A map field the gateway may serialise as `null` (a nil Go map) or omit
/// entirely; both decode to an empty dictionary instead of failing. The map
/// form of ``NullToEmpty``, for the same reason.
@propertyWrapper
public struct NullToEmptyMap<Value: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [String: Value]

    public init(wrappedValue: [String: Value] = [:]) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = container.decodeNil() ? [:] : try container.decode([String: Value].self)
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension NullToEmptyMap: Equatable where Value: Equatable {}

extension KeyedDecodingContainer {
    /// A missing key decodes to an empty dictionary, the same as an explicit `null`.
    public func decode<V>(_ type: NullToEmptyMap<V>.Type, forKey key: Key) throws -> NullToEmptyMap<V> {
        try decodeIfPresent(type, forKey: key) ?? NullToEmptyMap()
    }
}

// MARK: - Flattened extra parameters

/// A key that stands for whatever name is on the wire, for the parameters a
/// request type has no typed field for.
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

/// Writes a flatten map into the same JSON object as the typed keys, which is
/// what the reference SDK's `#[serde(flatten)]` does. An empty map writes
/// nothing, so a request that sets no extra parameters is byte-identical to one
/// built before the field existed.
func encodeFlattened(_ extra: [String: AnyCodable], into encoder: Encoder) throws {
    guard !extra.isEmpty else { return }
    var container = encoder.container(keyedBy: AnyCodingKey.self)
    for (name, value) in extra {
        try container.encode(value, forKey: AnyCodingKey(stringValue: name))
    }
}

/// The decode half: every key that is not one of `known` — wire names, not
/// Swift property names — is collected into the flatten map, so a body
/// round-trips through the type without losing the parameters it carries.
func decodeFlattened(from decoder: Decoder, known: Set<String>) throws -> [String: AnyCodable] {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    var extra: [String: AnyCodable] = [:]
    for key in container.allKeys where !known.contains(key.stringValue) {
        extra[key.stringValue] = try container.decode(AnyCodable.self, forKey: key)
    }
    return extra
}
