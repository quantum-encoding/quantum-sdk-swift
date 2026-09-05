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
