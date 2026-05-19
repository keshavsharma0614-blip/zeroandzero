import Foundation

public enum JSONValue: Sendable, Equatable, Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object: [String: JSONValue] = [:]
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var array: [JSONValue] = []
            while !container.isAtEnd {
                array.append(try container.decode(JSONValue.self))
            }
            self = .array(array)
            return
        }

        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case .array(let values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case .object(let values):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for key in values.keys.sorted() {
                guard let codingKey = DynamicCodingKey(stringValue: key),
                      let value = values[key]
                else {
                    continue
                }
                try container.encode(value, forKey: codingKey)
            }
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    public var doubleValue: Double? {
        if case .number(let value) = self {
            return value
        }
        return nil
    }

    public var intValue: Int? {
        guard let number = doubleValue else {
            return nil
        }
        let rounded = number.rounded()
        guard abs(number - rounded) < 0.000_000_1 else {
            return nil
        }
        return Int(rounded)
    }

    public static func parseObject(json: String) throws -> [String: JSONValue] {
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object(let object) = decoded else {
            throw JSONValueError.expectedObject
        }
        return object
    }

    public func toFoundationObject() -> Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return NSNull()
        case .array(let values):
            return values.map { $0.toFoundationObject() }
        case .object(let values):
            return values.mapValues { $0.toFoundationObject() }
        }
    }
}

public enum JSONValueError: Error, Sendable {
    case expectedObject
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
