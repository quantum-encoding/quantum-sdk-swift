import Foundation

/// A type-erased Codable value for handling dynamic JSON.
///
/// Use this for fields that can contain arbitrary JSON values:
/// ```swift
/// let params: [String: AnyCodable] = [
///     "model": "meshy-6",
///     "prompt": "a sword",
///     "count": 3,
///     "detailed": true,
/// ]
/// ```
///
/// Equality and hashing are structural over the JSON value: two
/// dictionaries with the same entries are equal whatever their storage
/// order, `1` and `1.0` are equal, and a nested box compares as its
/// payload.
///
/// `@unchecked Sendable`: ``value`` is typed `Any`, but it only ever holds
/// JSON values (`NSNull`, `Bool`, `Int`, `Double`, `String`, arrays and
/// dictionaries of those), all immutable value types, and it is a `let`.
public struct AnyCodable: Codable, @unchecked Sendable, Hashable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let nested as AnyCodable:
            // A nested box (a value inside AnyCodable([String: AnyCodable]))
            // encodes as its payload; without this case it would match nothing
            // below and throw an EncodingError.
            try container.encode(nested)
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        Canonical(lhs.value) == Canonical(rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(Canonical(value))
    }

    /// The JSON value in a form with one representation per value, so
    /// equality and hashing agree with each other and with JSON semantics.
    indirect enum Canonical: Hashable {
        case null
        case bool(Bool)
        case number(Double)
        case string(String)
        case array([Canonical])
        case object([String: Canonical])
        /// A value that is not JSON; compared by its description.
        case other(String)

        init(_ value: Any) {
            switch value {
            case let nested as AnyCodable:
                self = Canonical(nested.value)
            case is NSNull:
                self = .null
            case let number as NSNumber:
                // A Bool bridges to a CFBoolean NSNumber; every other
                // NSNumber is numeric. Checking the CF type tells a native
                // `true` from a native `1`, which `as? Bool` alone does not.
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    self = .bool(number.boolValue)
                } else {
                    self = .number(number.doubleValue)
                }
            case let string as String:
                self = .string(string)
            case let array as [Any]:
                self = .array(array.map(Canonical.init))
            case let dict as [String: Any]:
                self = .object(dict.mapValues(Canonical.init))
            default:
                self = .other(String(describing: value))
            }
        }
    }
}

// MARK: - ExpressibleBy Conformances

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.init(NSNull())
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}
