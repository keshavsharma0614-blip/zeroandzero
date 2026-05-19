import Foundation

enum OpenAIResponsesStructuredSchemaValidationError: Error, Sendable, Equatable {
    case rootMustBeObject
    case rootAnyOfUnsupported
    case objectMissingAdditionalPropertiesFalse(path: [String])
    case objectMissingProperties(path: [String])
    case objectRequiredMismatch(path: [String], expected: [String], actual: [String])
    case anyOfBranchInvalid(path: [String], branchIndex: Int, reason: String)

    var boundedSummary: String {
        switch self {
        case .rootMustBeObject:
            return "schema_root_must_be_object"
        case .rootAnyOfUnsupported:
            return "schema_root_anyof_unsupported"
        case .objectMissingAdditionalPropertiesFalse(let path):
            return "schema_path=\(path.joined(separator: ".")) missing_additional_properties_false"
        case .objectMissingProperties(let path):
            return "schema_path=\(path.joined(separator: ".")) missing_properties"
        case .objectRequiredMismatch(let path, let expected, let actual):
            return "schema_path=\(path.joined(separator: ".")) required_mismatch expected=\(expected.joined(separator: ",")) actual=\(actual.joined(separator: ","))"
        case .anyOfBranchInvalid(let path, let branchIndex, let reason):
            return "schema_path=\(path.joined(separator: ".")) anyof_branch=\(branchIndex) \(reason)"
        }
    }
}

struct OpenAIResponsesStructuredRequestBody: Encodable {
    static let longRunningRequestTimeout: TimeInterval = 420

    struct ReasoningRequest: Encodable {
        let effort: String
    }

    struct ToolRequest: Encodable {
        let type: String
        let searchContextSize: String?
        let externalWebAccess: Bool?

        init(
            type: String,
            searchContextSize: String? = nil,
            externalWebAccess: Bool? = nil
        ) {
            self.type = type
            self.searchContextSize = searchContextSize
            self.externalWebAccess = externalWebAccess
        }

        enum CodingKeys: String, CodingKey {
            case type
            case searchContextSize = "search_context_size"
            case externalWebAccess = "external_web_access"
        }
    }

    struct TextRequest: Encodable {
        struct FormatRequest: Encodable {
            let type: String
            let name: String
            let strict: Bool
            let schema: JSONValue
        }

        let format: FormatRequest
    }

    let model: String
    let store: Bool
    let instructions: String
    let input: String
    let tools: [ToolRequest]?
    let toolChoice: String?
    let reasoning: ReasoningRequest?
    let text: TextRequest

    init(
        model: String,
        store: Bool,
        instructions: String,
        input: String,
        tools: [ToolRequest]? = nil,
        toolChoice: String? = nil,
        reasoning: ReasoningRequest? = nil,
        text: TextRequest
    ) {
        self.model = model
        self.store = store
        self.instructions = instructions
        self.input = input
        self.tools = tools
        self.toolChoice = toolChoice
        self.reasoning = reasoning
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case model
        case store
        case instructions
        case input
        case tools
        case toolChoice = "tool_choice"
        case reasoning
        case text
    }
}

struct OpenAIResponsesStructuredEnvelope: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            let type: String?
            let text: String?
            let refusal: String?
        }

        let type: String?
        let content: [ContentItem]?
    }

    let outputText: String?
    let output: [OutputItem]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

func openAIResponsesHTTPErrorSummary(from data: Data) -> String? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let error = object["error"] as? [String: Any] else {
        return nil
    }

    let message = (error["message"] as? String)?
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let type = (error["type"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    let code = (error["code"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    let param = (error["param"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    var parts: [String] = []
    if let code, code.isEmpty == false { parts.append("code=\(code)") }
    if let type, type.isEmpty == false { parts.append("type=\(type)") }
    if let param, param.isEmpty == false { parts.append("param=\(param)") }
    if let message, message.isEmpty == false {
        parts.append("message=\(openAIResponsesTrimmed(message, limit: 180))")
    }

    guard parts.isEmpty == false else { return nil }
    return parts.joined(separator: " ")
}

func openAIResponsesExtractStructuredText(from envelope: OpenAIResponsesStructuredEnvelope) -> String? {
    if let outputText = envelope.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
       !outputText.isEmpty {
        return outputText
    }

    for item in envelope.output ?? [] {
        for content in item.content ?? [] {
            if let text = content.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
        }
    }
    return nil
}

func openAIResponsesStrictCompatibleSchema(_ value: JSONValue) -> JSONValue {
    switch value {
    case .object(let object):
        var sanitized: [String: JSONValue] = [:]
        for (key, child) in object {
            guard openAIResponsesUnsupportedStrictSchemaKeywords.contains(key) == false else {
                continue
            }
            sanitized[key] = openAIResponsesStrictCompatibleSchema(child)
        }
        return .object(sanitized)
    case .array(let values):
        return .array(values.map(openAIResponsesStrictCompatibleSchema))
    case .string, .number, .bool, .null:
        return value
    }
}

private let openAIResponsesUnsupportedStrictSchemaKeywords: Set<String> = [
    "minimum",
    "maximum",
    "exclusiveMinimum",
    "exclusiveMaximum",
    "multipleOf",
    "minLength",
    "maxLength",
    "pattern",
    "format",
    "minItems",
    "maxItems",
    "uniqueItems",
    "minProperties",
    "maxProperties"
]

func openAIResponsesContainsRefusal(in envelope: OpenAIResponsesStructuredEnvelope) -> Bool {
    for item in envelope.output ?? [] {
        for content in item.content ?? [] {
            if let refusal = content.refusal?.trimmingCharacters(in: .whitespacesAndNewlines),
               !refusal.isEmpty {
                return true
            }
        }
    }
    return false
}

func openAIResponsesStripJSONCodeFences(from text: String) -> String {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedText.hasPrefix("```") else {
        return trimmedText
    }
    let withoutOpening = trimmedText
        .replacingOccurrences(of: "^```[a-zA-Z0-9_-]*\\n", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\n```$", with: "", options: .regularExpression)
    return withoutOpening.trimmingCharacters(in: .whitespacesAndNewlines)
}

func openAIResponsesTrimmed(_ value: String, limit: Int) -> String {
    let collapsed = value
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if collapsed.count <= limit {
        return collapsed
    }
    return String(collapsed.prefix(limit)) + "..."
}

func validateOpenAIResponsesStructuredSchema(_ schema: JSONValue) throws {
    try validateOpenAIResponsesStructuredSchema(schema, path: ["schema"], isRoot: true)
}

private func validateOpenAIResponsesStructuredSchema(
    _ schema: JSONValue,
    path: [String],
    isRoot: Bool
) throws {
    guard let object = schema.objectValue else {
        return
    }

    if let anyOf = object["anyOf"]?.arrayValue {
        if isRoot {
            throw OpenAIResponsesStructuredSchemaValidationError.rootAnyOfUnsupported
        }
        for (index, branch) in anyOf.enumerated() {
            do {
                try validateOpenAIResponsesStructuredSchema(
                    branch,
                    path: path + ["anyOf[\(index)]"],
                    isRoot: false
                )
            } catch let error as OpenAIResponsesStructuredSchemaValidationError {
                throw OpenAIResponsesStructuredSchemaValidationError.anyOfBranchInvalid(
                    path: path,
                    branchIndex: index,
                    reason: error.boundedSummary
                )
            }
        }
        return
    }

    let typeValue = object["type"]
    if isRoot {
        guard typeValue?.stringValue == "object" else {
            throw OpenAIResponsesStructuredSchemaValidationError.rootMustBeObject
        }
    }

    if typeValue?.stringValue == "object" {
        guard object["additionalProperties"]?.boolValue == false else {
            throw OpenAIResponsesStructuredSchemaValidationError.objectMissingAdditionalPropertiesFalse(path: path)
        }
        guard let properties = object["properties"]?.objectValue else {
            throw OpenAIResponsesStructuredSchemaValidationError.objectMissingProperties(path: path)
        }
        let expected = properties.keys.sorted()
        let actual = (object["required"]?.arrayValue ?? []).compactMap(\.stringValue).sorted()
        guard expected == actual else {
            throw OpenAIResponsesStructuredSchemaValidationError.objectRequiredMismatch(
                path: path,
                expected: expected,
                actual: actual
            )
        }
        for key in expected {
            if let propertySchema = properties[key] {
                try validateOpenAIResponsesStructuredSchema(
                    propertySchema,
                    path: path + ["properties", key],
                    isRoot: false
                )
            }
        }
    }

    if typeValue?.stringValue == "array",
       let items = object["items"] {
        try validateOpenAIResponsesStructuredSchema(items, path: path + ["items"], isRoot: false)
    }
}
