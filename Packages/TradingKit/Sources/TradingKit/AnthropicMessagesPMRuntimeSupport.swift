import Foundation

public protocol AnthropicMessagesHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionAnthropicMessagesHTTPClient: AnthropicMessagesHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

public protocol PMAnthropicSynthesisProviding: Sendable {
    func synthesizeConversationReply(
        request: PMConversationOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMConversationOpenAISynthesisOutput
}

public struct AnthropicMessagesPMSynthesisProvider: PMAnthropicSynthesisProviding {
    public static let defaultAnthropicVersion = "2023-06-01"
    public static let pmConversationToolName = "emit_pm_conversation_reply"

    private let httpClient: any AnthropicMessagesHTTPClient
    private let endpoint: URL
    private let anthropicVersion: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        httpClient: any AnthropicMessagesHTTPClient = URLSessionAnthropicMessagesHTTPClient(),
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        anthropicVersion: String = Self.defaultAnthropicVersion
    ) {
        self.httpClient = httpClient
        self.endpoint = endpoint
        self.anthropicVersion = anthropicVersion
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func synthesizeConversationReply(
        request: PMConversationOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMConversationOpenAISynthesisOutput {
        let schema = sanitizeAnthropicStrictToolInputSchema(
            anthropicPMConversationToolInputSchema()
        ).schema
        do {
            try validateAnthropicStrictToolInputSchema(schema)
        } catch let error as AnthropicStrictToolSchemaValidationError {
            throw PMOpenAISynthesisError.invalidSchema(
                reason: "schema_name=pm_conversation_reply \(error.boundedSummary)"
            )
        }

        let body = AnthropicMessagesRequestBody(
            model: request.runtimeIdentifier,
            maxTokens: 4_096,
            system: """
            You are the PM inside an app-owned control plane. Produce a bounded owner-facing reply grounded only in the provided app context. Do not invent execution, approval, or trade authority. Do not imply external research or portfolio facts not present in the prompt. For direct Live order review actions, preserve the Alpaca-order requirements supplied in the user prompt: symbol, side, market/limit type, time-in-force, and either exact quantity or notional sizing; limit orders require a positive limit price, and notional nearest-share market orders should keep the notional for the app-owned route to size from current Store price. Use the required client tool exactly once with valid input matching its schema. Do not expose hidden reasoning or provider runtime plumbing in the reply body.

            The tool schema is compact for Anthropic strict tool use. Put the natural owner-facing answer in replyBody. For ordinary answer-only turns, set actionPlanJSON to the empty string exactly and set resolutionJSON to the empty string exactly; do not put prose, markdown fences, comments, or explanatory text in either JSON field. When a hidden app action is genuinely needed, put compact JSON matching this app-owned shape in actionPlanJSON: {"summary":"...","actions":[{"actionType":"answer_only","summary":"..."}]}. Action objects may include title, body, detail, targetId, charterId, proposalSymbol, proposalSide, proposalQuantity, liveOrderSymbol, liveOrderSide, liveOrderQuantity, liveOrderNotionalAmount, liveOrderType, liveOrderTimeInForce, liveOrderLimitPrice, runtimeSettingScope, runtimeIdentifier, reasoningMode, requestedOutputs, decisionType, requestType, instructionTargetKind, operatingTruthKind, watchlistOperation, watchlistSymbols, and sourceMessageIds only when needed. If resolution is useful, put compact JSON like {"intentClass":"general","disposition":"conversation_only","sourceMessageIds":[]}. Invalid action-plan JSON is rejected by the app; optional resolution metadata may be ignored for answer-only turns.
            """,
            messages: [
                AnthropicMessagesRequestBody.Message(
                    role: "user",
                    content: makePMConversationPromptText(from: request)
                )
            ],
            tools: [
                AnthropicMessagesRequestBody.ToolDefinition(
                    name: Self.pmConversationToolName,
                    description: "Emit the PM conversation visible reply and hidden bounded action plan as one structured object for app validation.",
                    inputSchema: schema,
                    strict: true
                )
            ],
            toolChoice: AnthropicMessagesRequestBody.ToolChoice(
                type: "tool",
                name: Self.pmConversationToolName
            )
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.httpBody = try encoder.encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: urlRequest)
        } catch {
            throw PMOpenAISynthesisError.providerTransport(provider: .anthropic)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PMOpenAISynthesisError.providerInvalidResponse(provider: .anthropic)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PMOpenAISynthesisError.providerHTTPStatus(
                provider: .anthropic,
                status: http.statusCode,
                responseSummary: anthropicMessagesHTTPErrorSummary(from: data)
            )
        }

        let envelope: AnthropicMessagesResponseEnvelope
        do {
            envelope = try decoder.decode(AnthropicMessagesResponseEnvelope.self, from: data)
        } catch {
            throw PMOpenAISynthesisError.providerInvalidResponse(provider: .anthropic)
        }

        guard let toolUse = envelope.content.first(where: {
            $0.type == "tool_use" && $0.name == Self.pmConversationToolName
        }) else {
            let stopReason = envelope.stopReason ?? "missing"
            throw PMOpenAISynthesisError.providerMalformedResponse(
                provider: .anthropic,
                reason: "missing_pm_conversation_tool_use stop_reason=\(boundedAnthropicIdentifier(stopReason))"
            )
        }

        return try decodeAnthropicPMConversationToolInput(
            toolUse.input,
            encoder: encoder,
            decoder: decoder
        )
    }
}

struct AnthropicStrictToolSchemaValidationError: Error, Sendable, Equatable {
    let boundedSummary: String
}

struct AnthropicStrictToolSchemaSanitizationResult: Sendable, Equatable {
    let schema: JSONValue
    let removedKeywordCounts: [String: Int]

    var totalRemovedKeywordCount: Int {
        removedKeywordCounts.values.reduce(0, +)
    }

    func removedCount(for keyword: String) -> Int {
        removedKeywordCounts[keyword] ?? 0
    }
}

func anthropicPMConversationToolInputSchema() -> JSONValue {
    .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object([
            "replyBody": .object([
                "type": .string("string"),
                "description": .string("Natural-language PM reply visible to the owner.")
            ]),
            "actionPlanJSON": .object([
                "type": .string("string"),
                "description": .string("Empty string exactly for no hidden action plan; otherwise compact JSON object text for PMConversationActionPlan. Do not use markdown fences or prose.")
            ]),
            "resolutionJSON": .object([
                "type": .string("string"),
                "description": .string("Empty string exactly for no resolution state; otherwise compact JSON object text for PMConversationResolutionState. Do not use markdown fences or prose.")
            ])
        ]),
        "required": .array([
            .string("actionPlanJSON"),
            .string("replyBody"),
            .string("resolutionJSON")
        ])
    ])
}

func validateAnthropicStrictToolInputSchema(_ schema: JSONValue) throws {
    guard let root = schema.objectValue else {
        throw AnthropicStrictToolSchemaValidationError(boundedSummary: "root_must_be_object")
    }
    guard root["type"]?.stringValue == "object" else {
        throw AnthropicStrictToolSchemaValidationError(boundedSummary: "root_type_must_be_object")
    }
    guard root["properties"]?.objectValue != nil else {
        throw AnthropicStrictToolSchemaValidationError(boundedSummary: "root_properties_missing")
    }
    guard root["additionalProperties"]?.boolValue == false else {
        throw AnthropicStrictToolSchemaValidationError(boundedSummary: "root_must_disallow_additional_properties")
    }

    let stats = anthropicStrictToolSchemaStats(schema)
    if stats.unsupportedKeywordCounts.isEmpty == false {
        let summary = stats.unsupportedKeywordCounts
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        throw AnthropicStrictToolSchemaValidationError(
            boundedSummary: "unsupported_keywords_present \(summary)"
        )
    }
    if stats.unionCount > 16 {
        throw AnthropicStrictToolSchemaValidationError(
            boundedSummary: "union_count_exceeds_anthropic_strict_limit count=\(stats.unionCount) max=16"
        )
    }
    if stats.optionalParameterCount > 24 {
        throw AnthropicStrictToolSchemaValidationError(
            boundedSummary: "optional_parameter_count_exceeds_anthropic_strict_limit count=\(stats.optionalParameterCount) max=24"
        )
    }
}

private struct AnthropicStrictToolSchemaStats: Sendable, Equatable {
    var unionCount: Int = 0
    var optionalParameterCount: Int = 0
    var unsupportedKeywordCounts: [String: Int] = [:]
}

private func anthropicStrictToolSchemaStats(_ value: JSONValue) -> AnthropicStrictToolSchemaStats {
    var stats = AnthropicStrictToolSchemaStats()
    collectAnthropicStrictToolSchemaStats(value, into: &stats)
    return stats
}

private func collectAnthropicStrictToolSchemaStats(
    _ value: JSONValue,
    into stats: inout AnthropicStrictToolSchemaStats
) {
    switch value {
    case .object(let object):
        for key in object.keys where anthropicUnsupportedStrictToolSchemaKeywords.contains(key) {
            stats.unsupportedKeywordCounts[key, default: 0] += 1
        }
        if let anyOf = object["anyOf"]?.arrayValue {
            stats.unionCount += max(0, anyOf.count - 1)
        }
        if let oneOf = object["oneOf"]?.arrayValue {
            stats.unionCount += max(0, oneOf.count - 1)
        }
        if let allOf = object["allOf"]?.arrayValue {
            stats.unionCount += max(0, allOf.count - 1)
        }
        if let typeArray = object["type"]?.arrayValue, typeArray.count > 1 {
            stats.unionCount += typeArray.count - 1
        }
        if let properties = object["properties"]?.objectValue {
            let requiredValues = object["required"]?.arrayValue ?? []
            let required = Set(requiredValues.compactMap(\.stringValue))
            stats.optionalParameterCount += properties.keys.filter { required.contains($0) == false }.count
        }
        for child in object.values {
            collectAnthropicStrictToolSchemaStats(child, into: &stats)
        }
    case .array(let array):
        for child in array {
            collectAnthropicStrictToolSchemaStats(child, into: &stats)
        }
    case .string, .number, .bool, .null:
        break
    }
}

private let anthropicUnsupportedStrictToolSchemaKeywords: Set<String> = [
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
    "contains",
    "minContains",
    "maxContains",
    "minProperties",
    "maxProperties",
    "propertyNames",
    "patternProperties",
    "dependentRequired",
    "dependentSchemas",
    "dependencies",
    "additionalItems",
    "unevaluatedItems",
    "unevaluatedProperties",
    "if",
    "then",
    "else",
    "not",
    "const"
]

func sanitizeAnthropicStrictToolInputSchema(_ schema: JSONValue) -> AnthropicStrictToolSchemaSanitizationResult {
    var removedKeywordCounts: [String: Int] = [:]
    let sanitized = sanitizeAnthropicStrictToolInputSchemaValue(
        schema,
        removedKeywordCounts: &removedKeywordCounts
    )
    return AnthropicStrictToolSchemaSanitizationResult(
        schema: sanitized,
        removedKeywordCounts: removedKeywordCounts
    )
}

private func sanitizeAnthropicStrictToolInputSchemaValue(
    _ value: JSONValue,
    removedKeywordCounts: inout [String: Int]
) -> JSONValue {
    switch value {
    case .object(let object):
        var sanitized: [String: JSONValue] = [:]
        var removedKeywords: [String] = []

        for (key, child) in object {
            if anthropicUnsupportedStrictToolSchemaKeywords.contains(key) {
                removedKeywordCounts[key, default: 0] += 1
                collectAnthropicUnsupportedStrictToolSchemaKeywordCounts(
                    child,
                    into: &removedKeywordCounts
                )
                removedKeywords.append(key)
                continue
            }
            sanitized[key] = sanitizeAnthropicStrictToolInputSchemaValue(
                child,
                removedKeywordCounts: &removedKeywordCounts
            )
        }

        if removedKeywords.isEmpty == false {
            sanitized["description"] = appendAnthropicSchemaConstraintHint(
                to: sanitized["description"],
                removedKeywords: removedKeywords
            )
        }

        return .object(sanitized)
    case .array(let array):
        return .array(array.map {
            sanitizeAnthropicStrictToolInputSchemaValue(
                $0,
                removedKeywordCounts: &removedKeywordCounts
            )
        })
    case .string, .number, .bool, .null:
        return value
    }
}

private func collectAnthropicUnsupportedStrictToolSchemaKeywordCounts(
    _ value: JSONValue,
    into counts: inout [String: Int]
) {
    switch value {
    case .object(let object):
        for (key, child) in object {
            if anthropicUnsupportedStrictToolSchemaKeywords.contains(key) {
                counts[key, default: 0] += 1
            }
            collectAnthropicUnsupportedStrictToolSchemaKeywordCounts(child, into: &counts)
        }
    case .array(let array):
        for child in array {
            collectAnthropicUnsupportedStrictToolSchemaKeywordCounts(child, into: &counts)
        }
    case .string, .number, .bool, .null:
        break
    }
}

private func appendAnthropicSchemaConstraintHint(
    to description: JSONValue?,
    removedKeywords: [String]
) -> JSONValue {
    let uniqueKeywords = Array(Set(removedKeywords)).sorted()
    let hint = "Client-side validation preserves removed Anthropic-unsupported constraints: \(uniqueKeywords.joined(separator: ", "))."
    let existing = description?.stringValue?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if let existing, existing.isEmpty == false {
        return .string("\(existing) \(hint)")
    }
    return .string(hint)
}

private struct AnthropicPMConversationToolInput: Decodable, Sendable, Equatable {
    let replyBody: String
    let actionPlanJSON: String
    let resolutionJSON: String
}

private func decodeAnthropicPMConversationToolInput(
    _ input: JSONValue,
    encoder: JSONEncoder,
    decoder: JSONDecoder
) throws -> PMConversationOpenAISynthesisOutput {
    let inputData = try encoder.encode(input)
    let decodedInput: AnthropicPMConversationToolInput
    do {
        decodedInput = try decoder.decode(AnthropicPMConversationToolInput.self, from: inputData)
    } catch {
        throw PMOpenAISynthesisError.providerMalformedResponse(
            provider: .anthropic,
            reason: "invalid_pm_conversation_tool_input"
        )
    }

    let actionPlan = try decodeAnthropicOptionalJSONString(
        decodedInput.actionPlanJSON,
        as: PMConversationActionPlan.self,
        fieldName: "action_plan_json",
        decoder: decoder
    )
    let resolutionResult = decodeAnthropicOptionalJSONStringResult(
        decodedInput.resolutionJSON,
        as: PMConversationResolutionState.self,
        decoder: decoder
    )
    let resolution: PMConversationResolutionState?
    switch resolutionResult {
    case .decoded(let value):
        resolution = value
    case .empty:
        resolution = nil
    case .invalid(let shape):
        guard anthropicActionPlanAllowsResolutionRecovery(actionPlan) else {
            throw PMOpenAISynthesisError.providerMalformedResponse(
                provider: .anthropic,
                reason: "invalid_pm_conversation_resolution_json shape=\(shape)"
            )
        }
        resolution = nil
    }

    return try PMConversationOpenAISynthesisOutput(
        replyBody: decodedInput.replyBody,
        actionPlan: actionPlan,
        resolution: resolution
    ).validated()
}

private func decodeAnthropicOptionalJSONString<T: Decodable & Sendable>(
    _ value: String,
    as type: T.Type,
    fieldName: String,
    decoder: JSONDecoder
) throws -> T? {
    let result = decodeAnthropicOptionalJSONStringResult(
        value,
        as: type,
        decoder: decoder
    )
    switch result {
    case .decoded(let decoded):
        return decoded
    case .empty:
        return nil
    case .invalid(let shape):
        throw PMOpenAISynthesisError.providerMalformedResponse(
            provider: .anthropic,
            reason: "invalid_pm_conversation_\(fieldName) shape=\(shape)"
        )
    }
}

private enum AnthropicOptionalJSONStringDecodeResult<T>: Sendable where T: Sendable {
    case empty
    case decoded(T)
    case invalid(shape: String)
}

private func decodeAnthropicOptionalJSONStringResult<T: Decodable & Sendable>(
    _ value: String,
    as type: T.Type,
    decoder: JSONDecoder
) -> AnthropicOptionalJSONStringDecodeResult<T> {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false, trimmed.lowercased() != "null" else {
        return .empty
    }
    if trimmed == "{}" {
        return .empty
    }
    guard let data = trimmed.data(using: .utf8) else {
        return .invalid(shape: anthropicOptionalJSONStringShape(trimmed))
    }
    do {
        return .decoded(try decoder.decode(type, from: data))
    } catch {
        return .invalid(shape: anthropicOptionalJSONStringShape(trimmed))
    }
}

private func anthropicActionPlanAllowsResolutionRecovery(_ actionPlan: PMConversationActionPlan?) -> Bool {
    guard let actionPlan else { return true }
    guard actionPlan.actions.isEmpty == false else { return true }
    return actionPlan.actions.allSatisfy {
        $0.actionType == .answerOnly || $0.actionType == .askFollowUp
    }
}

private func anthropicOptionalJSONStringShape(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return "empty" }
    let lowered = trimmed.lowercased()
    if lowered == "null" { return "null_literal" }
    if trimmed.hasPrefix("```") { return "markdown_fence" }
    if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") { return "object_string" }
    if trimmed.hasPrefix("["), trimmed.hasSuffix("]") { return "array_string" }
    if trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") { return "quoted_string" }
    if trimmed.contains("{") || trimmed.contains("}") { return "mixed_object_text" }
    return "non_json_text"
}

struct AnthropicMessagesRequestBody: Encodable {
    struct Message: Encodable, Equatable {
        let role: String
        let content: String
    }

    struct ToolDefinition: Encodable, Equatable {
        let type: String?
        let name: String
        let description: String?
        let inputSchema: JSONValue?
        let strict: Bool?
        let maxUses: Int?
        let blockedDomains: [String]?

        init(
            name: String,
            description: String,
            inputSchema: JSONValue,
            strict: Bool
        ) {
            self.type = nil
            self.name = name
            self.description = description
            self.inputSchema = inputSchema
            self.strict = strict
            self.maxUses = nil
            self.blockedDomains = nil
        }

        init(
            type: String,
            name: String,
            maxUses: Int? = nil,
            blockedDomains: [String]? = nil
        ) {
            self.type = type
            self.name = name
            self.description = nil
            self.inputSchema = nil
            self.strict = nil
            self.maxUses = maxUses
            self.blockedDomains = blockedDomains
        }

        enum CodingKeys: String, CodingKey {
            case type
            case name
            case description
            case inputSchema = "input_schema"
            case strict
            case maxUses = "max_uses"
            case blockedDomains = "blocked_domains"
        }
    }

    struct ToolChoice: Encodable, Equatable {
        let type: String
        let name: String?

        init(type: String, name: String? = nil) {
            self.type = type
            self.name = name
        }
    }

    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]
    let tools: [ToolDefinition]
    let toolChoice: ToolChoice

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case tools
        case toolChoice = "tool_choice"
    }
}

struct AnthropicMessagesResponseEnvelope: Decodable, Equatable {
    struct ContentBlock: Decodable, Equatable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: JSONValue

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case id
            case name
            case input
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(String.self, forKey: .type)
            self.text = try container.decodeIfPresent(String.self, forKey: .text)
            self.id = try container.decodeIfPresent(String.self, forKey: .id)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.input = try container.decodeIfPresent(JSONValue.self, forKey: .input) ?? .object([:])
        }
    }

    let id: String?
    let type: String?
    let role: String?
    let model: String?
    let content: [ContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case model
        case content
        case stopReason = "stop_reason"
    }
}

func anthropicMessagesHTTPErrorSummary(from data: Data) -> String? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    guard let error = object["error"] as? [String: Any] else {
        return nil
    }

    let type = (error["type"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    let message = (error["message"] as? String)?
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    var parts: [String] = []
    if let type, type.isEmpty == false {
        parts.append("type=\(boundedAnthropicIdentifier(type))")
    }
    if let message, message.isEmpty == false {
        parts.append("message=\(openAIResponsesTrimmed(message, limit: 180))")
    }
    guard parts.isEmpty == false else { return nil }
    return parts.joined(separator: " ")
}

func anthropicHTTPStatusSummary(_ status: Int, detail: String?) -> String {
    let normalizedDetail = detail?
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let loweredDetail = normalizedDetail?.lowercased() ?? ""
    let indicatesInvalidSchema = loweredDetail.contains("schema")
        || loweredDetail.contains("tool")
        || loweredDetail.contains("input_schema")
    let indicatesOversizedRequest = loweredDetail.contains("context_length")
        || loweredDetail.contains("maximum context")
        || loweredDetail.contains("too many tokens")
        || loweredDetail.contains("input too long")
        || loweredDetail.contains("request too large")
        || loweredDetail.contains("request_too_large")
        || loweredDetail.contains("too_large")

    let base: String
    switch status {
    case 401, 403:
        base = "anthropic_auth_failure_status=\(status)"
    case 402:
        base = "anthropic_rate_limit_or_quota_status=\(status)"
    case 404, 422:
        base = "anthropic_invalid_runtime_status=\(status)"
    case 429:
        base = "anthropic_rate_limit_or_quota_status=\(status)"
    case 400 where indicatesInvalidSchema:
        base = "anthropic_invalid_schema_status=\(status)"
    case 400 where indicatesOversizedRequest:
        base = "anthropic_request_too_large_status=\(status)"
    case 413:
        base = "anthropic_request_too_large_status=\(status)"
    case 408, 409, 500..<600:
        base = "anthropic_provider_failure_status=\(status)"
    default:
        base = "anthropic_http_status=\(status)"
    }

    guard let normalizedDetail, normalizedDetail.isEmpty == false else {
        return base
    }
    return "\(base) detail=\(openAIResponsesTrimmed(normalizedDetail, limit: 200))"
}

func boundedAnthropicIdentifier(_ value: String) -> String {
    let normalized = value
        .replacingOccurrences(of: "[^a-zA-Z0-9_=-]+", with: "_", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        .lowercased()
    return openAIResponsesTrimmed(normalized.isEmpty ? "unknown" : normalized, limit: 80)
}
