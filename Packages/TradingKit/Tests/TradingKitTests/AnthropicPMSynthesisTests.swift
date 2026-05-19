import Foundation
import Testing
@testable import TradingKit

@Test("Anthropic PM synthesis provider builds forced strict tool-use Messages request")
func anthropicPMSynthesisProviderBuildsForcedStrictToolUseRequest() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            Data("""
            {
              "id": "msg_test",
              "type": "message",
              "role": "assistant",
              "model": "claude-sonnet-4-20250514",
              "content": [
                {
                  "type": "tool_use",
                  "id": "toolu_test",
                  "name": "emit_pm_conversation_reply",
                  "input": {
                    "replyBody": "I can answer this from the current PM context.",
                    "actionPlanJSON": "",
                    "resolutionJSON": ""
                  }
                }
              ],
              "stop_reason": "tool_use"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)
    let conversationRequest = makeAnthropicPMConversationRequest(
        ownerMessageBody: "What is the latest from our Recent News Analyst?",
        confirmedAppTruthSummary: [
            "Portfolio Watch live-data truth: selected 3 (NVDA, AAPL, KSS); requested 3/3; active subscriptions 3/3; usable Store prices 0/3; market-data connection subscribed.",
            "Portfolio Watch first-update caveat: selected symbols still waiting for usable quote/trade/bar truth: NVDA, AAPL, KSS."
        ],
        analystArtifactSummary: [
            "FULL_ANALYST_REPORT_DOCUMENT\nAnalyst lane: Recent News Analyst\nReport id: recent-news-current\nHeadline/current view: AI/legal headlines were confirmed but remain monitor-only."
        ]
    )

    let output = try await provider.synthesizeConversationReply(
        request: conversationRequest,
        apiKey: "test-anthropic-key"
    )

    #expect(output.replyBody == "I can answer this from the current PM context.")

    let request = try #require(await httpClient.lastRequest)
    #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-anthropic-key")
    #expect(request.value(forHTTPHeaderField: "anthropic-version") == AnthropicMessagesPMSynthesisProvider.defaultAnthropicVersion)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

    let body = try #require(request.httpBody)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    #expect(json["model"]?.stringValue == "claude-sonnet-4-20250514")
    #expect(json["thinking"] == nil)
    #expect(json["text"] == nil)
    #expect(json["response_format"] == nil)
    #expect(json["output_config"] == nil)
    let messages = try #require(json["messages"]?.arrayValue)
    let userMessage = try #require(messages.first?.objectValue)
    let userContent = try #require(userMessage["content"]?.stringValue)
    #expect(userContent.contains("What is the latest from our Recent News Analyst?"))
    #expect(userContent.contains("FULL_ANALYST_REPORT_DOCUMENT"))
    #expect(userContent.contains("Recent News Analyst"))
    #expect(userContent.contains("AI/legal headlines were confirmed"))
    #expect(userContent.contains("Portfolio Watch live-data truth"))
    #expect(userContent.contains("waiting for usable quote/trade/bar truth"))

    let tools = try #require(json["tools"]?.arrayValue)
    let tool = try #require(tools.first?.objectValue)
    #expect(tool["name"]?.stringValue == "emit_pm_conversation_reply")
    #expect(tool["strict"]?.boolValue == true)
    let schema = try #require(tool["input_schema"])
    try validateAnthropicStrictToolInputSchema(schema)
    #expect(countSchemaKeyword("anyOf", in: schema) == 0)
    #expect(countSchemaKeyword("oneOf", in: schema) == 0)
    #expect(countSchemaKeyword("allOf", in: schema) == 0)
    #expect(unsupportedAnthropicSchemaKeywords(in: schema).isEmpty)
    let schemaProperties = try #require(schema.objectValue?["properties"]?.objectValue)
    #expect(schemaProperties["replyBody"] != nil)
    #expect(schemaProperties["actionPlanJSON"] != nil)
    #expect(schemaProperties["resolutionJSON"] != nil)

    let toolChoice = try #require(json["tool_choice"]?.objectValue)
    #expect(toolChoice["type"]?.stringValue == "tool")
    #expect(toolChoice["name"]?.stringValue == "emit_pm_conversation_reply")
}

@Test("Anthropic PM synthesis prompt includes app-owned signal actionability truth")
func anthropicPMSynthesisPromptIncludesSignalTruth() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "Those signals are FYI research alerts, not owner decisions."
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(
            ownerMessageBody: "Are these signals actionable?",
            confirmedAppTruthSummary: [
                "Confirmed signal truth: 4 new research alert(s): 0 owner-review/proposal-candidate, 4 FYI/monitor-only/PM-review.",
                "Signal sig-fyi NVDA: status=new, actionability=notify_only, action=notify_only, direction=neutral."
            ]
        ),
        apiKey: "test-anthropic-key"
    )

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    let messages = try #require(json["messages"]?.arrayValue)
    let userMessage = try #require(messages.first?.objectValue)
    let userContent = try #require(userMessage["content"]?.stringValue)
    #expect(userContent.contains("Confirmed signal truth"))
    #expect(userContent.contains("actionability=notify_only"))
    #expect(userContent.contains("research alerts"))
}

@Test("Anthropic PM synthesis request includes Alpaca Live order review requirements")
func anthropicPMSynthesisRequestIncludesAlpacaLiveOrderReviewRequirements() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "I’ll create an in-app Live order review."
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(
            ownerMessageBody: "Purchase $10,000 to the nearest share of META stock live. Market order opened for today."
        ),
        apiKey: "test-anthropic-key"
    )

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    let system = try #require(json["system"]?.stringValue)
    let messages = try #require(json["messages"]?.arrayValue)
    let userMessage = try #require(messages.first?.objectValue)
    let userContent = try #require(userMessage["content"]?.stringValue)

    #expect(system.contains("symbol, side, market/limit type, time-in-force"))
    #expect(system.contains("notional nearest-share market orders"))
    #expect(userContent.contains("reviewable Alpaca order instruction"))
    #expect(userContent.contains("opened for today"))
    #expect(userContent.contains("liveOrderNotionalAmount"))
}

@Test("Anthropic strict tool sanitizer strips unsupported scalar constraints and preserves shape")
func anthropicStrictToolSanitizerStripsUnsupportedScalarConstraints() throws {
    let schema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object([
            "quantity": .object([
                "type": .string("integer"),
                "minimum": .number(1),
                "maximum": .number(10),
                "exclusiveMinimum": .number(0),
                "exclusiveMaximum": .number(11),
                "multipleOf": .number(1),
                "description": .string("Share quantity.")
            ]),
            "note": .object([
                "type": .string("string"),
                "minLength": .number(1),
                "maxLength": .number(240),
                "pattern": .string("^[A-Z]+$"),
                "format": .string("email"),
                "description": .string("Operator note.")
            ])
        ]),
        "required": .array([.string("note"), .string("quantity")])
    ])

    #expect(throws: AnthropicStrictToolSchemaValidationError.self) {
        try validateAnthropicStrictToolInputSchema(schema)
    }

    let result = sanitizeAnthropicStrictToolInputSchema(schema)

    #expect(result.removedCount(for: "minimum") == 1)
    #expect(result.removedCount(for: "maximum") == 1)
    #expect(result.removedCount(for: "exclusiveMinimum") == 1)
    #expect(result.removedCount(for: "exclusiveMaximum") == 1)
    #expect(result.removedCount(for: "multipleOf") == 1)
    #expect(result.removedCount(for: "minLength") == 1)
    #expect(result.removedCount(for: "maxLength") == 1)
    #expect(result.removedCount(for: "pattern") == 1)
    #expect(result.removedCount(for: "format") == 1)
    #expect(unsupportedAnthropicSchemaKeywords(in: result.schema).isEmpty)
    try validateAnthropicStrictToolInputSchema(result.schema)

    let root = try #require(result.schema.objectValue)
    #expect(root["type"]?.stringValue == "object")
    #expect(root["additionalProperties"]?.boolValue == false)
    let properties = try #require(root["properties"]?.objectValue)
    let quantity = try #require(properties["quantity"]?.objectValue)
    #expect(quantity["type"]?.stringValue == "integer")
    #expect(quantity["description"]?.stringValue?.contains("Client-side validation preserves") == true)
    let note = try #require(properties["note"]?.objectValue)
    #expect(note["type"]?.stringValue == "string")
    #expect(note["description"]?.stringValue?.contains("Operator note.") == true)
}

@Test("Anthropic strict tool sanitizer strips unsupported array and object constraints recursively")
func anthropicStrictToolSanitizerStripsUnsupportedNestedConstraints() throws {
    let schema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "minProperties": .number(1),
        "maxProperties": .number(3),
        "properties": .object([
            "symbols": .object([
                "type": .string("array"),
                "minItems": .number(1),
                "maxItems": .number(5),
                "uniqueItems": .bool(true),
                "contains": .object(["type": .string("string")]),
                "items": .object([
                    "type": .string("string"),
                    "enum": .array([.string("AAPL"), .string("NVDA")])
                ])
            ]),
            "nested": .object([
                "type": .string("object"),
                "additionalProperties": .bool(false),
                "propertyNames": .object(["pattern": .string("^[a-z]+$")]),
                "patternProperties": .object([
                    "^x-": .object(["type": .string("string")])
                ]),
                "properties": .object([
                    "flag": .object([
                        "type": .string("boolean"),
                        "const": .bool(true),
                        "not": .object(["type": .string("null")])
                    ])
                ]),
                "required": .array([.string("flag")])
            ])
        ]),
        "required": .array([.string("nested"), .string("symbols")])
    ])

    let result = sanitizeAnthropicStrictToolInputSchema(schema)

    for keyword in [
        "minProperties",
        "maxProperties",
        "minItems",
        "maxItems",
        "uniqueItems",
        "contains",
        "propertyNames",
        "patternProperties",
        "pattern",
        "const",
        "not"
    ] {
        #expect(result.removedCount(for: keyword) >= 1)
    }
    #expect(unsupportedAnthropicSchemaKeywords(in: result.schema).isEmpty)
    try validateAnthropicStrictToolInputSchema(result.schema)

    let root = try #require(result.schema.objectValue)
    let properties = try #require(root["properties"]?.objectValue)
    let symbols = try #require(properties["symbols"]?.objectValue)
    #expect(symbols["type"]?.stringValue == "array")
    let itemSchema = try #require(symbols["items"]?.objectValue)
    #expect(itemSchema["enum"]?.arrayValue?.compactMap(\.stringValue) == ["AAPL", "NVDA"])
    let nested = try #require(properties["nested"]?.objectValue)
    #expect(nested["additionalProperties"]?.boolValue == false)
    #expect(nested["required"]?.arrayValue?.compactMap(\.stringValue) == ["flag"])
}

@Test("Anthropic PM tool schema is sanitized before request encoding")
func anthropicPMSynthesisProviderEncodesSanitizedSchema() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(replyBody: "Schema accepted."),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    let body = try #require(await httpClient.lastRequest?.httpBody)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    let tool = try #require(json["tools"]?.arrayValue?.first?.objectValue)
    let schema = try #require(tool["input_schema"])

    #expect(unsupportedAnthropicSchemaKeywords(in: schema).isEmpty)
    try validateAnthropicStrictToolInputSchema(schema)
}

@Test("Anthropic PM schema validator rejects OpenAI nullable union schema")
func anthropicStrictToolValidatorRejectsOpenAISchemaUnionBudget() {
    #expect(throws: AnthropicStrictToolSchemaValidationError.self) {
        try validateAnthropicStrictToolInputSchema(pmConversationSchema())
    }
}

@Test("Anthropic PM synthesis parses compact action plan JSON through existing model")
func anthropicPMSynthesisProviderParsesCompactActionPlanJSON() async throws {
    let actionPlanJSON = #"{"summary":"Answer only.","actions":[{"actionType":"answer_only","summary":"No app mutation required."}]}"#
    let resolutionJSON = #"{"intentClass":"general","disposition":"conversation_only","sourceMessageIds":[]}"#
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "I can answer directly.",
                actionPlanJSON: actionPlanJSON,
                resolutionJSON: resolutionJSON
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.replyBody == "I can answer directly.")
    #expect(output.actionPlan?.summary == "Answer only.")
    #expect(output.actionPlan?.actions.first?.actionType == .answerOnly)
    #expect(output.resolution?.intentClass == .general)
    #expect(output.resolution?.disposition == .conversationOnly)
}

@Test("Anthropic PM synthesis treats empty object JSON strings as no action or resolution")
func anthropicPMSynthesisProviderTreatsEmptyObjectJSONStringsAsNoOp() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "I can answer without an app action.",
                actionPlanJSON: "{}",
                resolutionJSON: "{}"
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.replyBody == "I can answer without an app action.")
    #expect(output.actionPlan == nil)
    #expect(output.resolution == nil)
}

@Test("Anthropic PM synthesis parses ask-follow-up action plan JSON")
func anthropicPMSynthesisProviderParsesAskFollowUpActionPlanJSON() async throws {
    let actionPlanJSON = #"{"summary":"Ask one follow-up.","actions":[{"actionType":"ask_follow_up","summary":"Need a date range.","body":"Which date range should I use?"}]}"#
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "Which date range should I use?",
                actionPlanJSON: actionPlanJSON
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.actionPlan?.actions.first?.actionType == .askFollowUp)
    #expect(output.actionPlan?.actions.first?.body == "Which date range should I use?")
}

@Test("Anthropic PM synthesis recovers visible reply when optional resolution JSON is malformed and no action is needed")
func anthropicPMSynthesisProviderRecoversFromMalformedResolutionJSONForAnswerOnlyTurn() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "The latest Recent News Analyst report is available in the provided context.",
                actionPlanJSON: "",
                resolutionJSON: "conversation_only"
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.replyBody.contains("Recent News Analyst"))
    #expect(output.actionPlan == nil)
    #expect(output.resolution == nil)
}

@Test("Anthropic PM synthesis recovers malformed resolution JSON when action plan is non-consequential")
func anthropicPMSynthesisProviderRecoversMalformedResolutionJSONForNonConsequentialActionPlan() async throws {
    let actionPlanJSON = #"{"summary":"Answer only.","actions":[{"actionType":"answer_only","summary":"No app mutation required."}]}"#
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "I can answer safely.",
                actionPlanJSON: actionPlanJSON,
                resolutionJSON: "```json\n{}\n```"
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.replyBody == "I can answer safely.")
    #expect(output.actionPlan?.actions.first?.actionType == .answerOnly)
    #expect(output.resolution == nil)
}

@Test("Anthropic PM synthesis rejects malformed resolution JSON when action plan is consequential")
func anthropicPMSynthesisProviderRejectsMalformedResolutionJSONForConsequentialActionPlan() async throws {
    let actionPlanJSON = #"{"summary":"Update working truth.","actions":[{"actionType":"update_conversation_working_truth","summary":"Treat the proposed paper portfolio as working context.","body":"Working context update.","operatingTruthKind":"working_portfolio_definition"}]}"#
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "I am updating the working context.",
                actionPlanJSON: actionPlanJSON,
                resolutionJSON: "not valid JSON"
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    await #expect(throws: PMOpenAISynthesisError.providerMalformedResponse(
        provider: .anthropic,
        reason: "invalid_pm_conversation_resolution_json shape=non_json_text"
    )) {
        try await provider.synthesizeConversationReply(
            request: makeAnthropicPMConversationRequest(),
            apiKey: "test-anthropic-key"
        )
    }
}

@Test("Anthropic PM synthesis rejects wrong tool name")
func anthropicPMSynthesisProviderRejectsWrongToolName() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            Data("""
            {
              "id": "msg_test",
              "type": "message",
              "role": "assistant",
              "model": "claude-sonnet-4-20250514",
              "content": [
                {
                  "type": "tool_use",
                  "id": "toolu_test",
                  "name": "other_tool",
                  "input": {
                    "replyBody": "Wrong tool.",
                    "actionPlanJSON": "",
                    "resolutionJSON": ""
                  }
                }
              ],
              "stop_reason": "tool_use"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    await #expect(throws: PMOpenAISynthesisError.providerMalformedResponse(
        provider: .anthropic,
        reason: "missing_pm_conversation_tool_use stop_reason=tool_use"
    )) {
        try await provider.synthesizeConversationReply(
            request: makeAnthropicPMConversationRequest(),
            apiKey: "test-anthropic-key"
        )
    }
}

@Test("Anthropic PM synthesis rejects malformed compact action plan JSON")
func anthropicPMSynthesisProviderRejectsMalformedActionPlanJSON() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "This should fail safe.",
                actionPlanJSON: #"{"summary":"broken","actions":"not-an-array"}"#
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    await #expect(throws: PMOpenAISynthesisError.providerMalformedResponse(
        provider: .anthropic,
        reason: "invalid_pm_conversation_action_plan_json shape=object_string"
    )) {
        try await provider.synthesizeConversationReply(
            request: makeAnthropicPMConversationRequest(),
            apiKey: "test-anthropic-key"
        )
    }
}

@Test("Anthropic PM synthesis rejects markdown-wrapped action plan JSON")
func anthropicPMSynthesisProviderRejectsMarkdownWrappedActionPlanJSON() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            makeAnthropicToolUseResponse(
                replyBody: "This should fail safe.",
                actionPlanJSON: "```json\n{\"summary\":\"No-op\",\"actions\":[]}\n```"
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    await #expect(throws: PMOpenAISynthesisError.providerMalformedResponse(
        provider: .anthropic,
        reason: "invalid_pm_conversation_action_plan_json shape=markdown_fence"
    )) {
        try await provider.synthesizeConversationReply(
            request: makeAnthropicPMConversationRequest(),
            apiKey: "test-anthropic-key"
        )
    }
}

@Test("Anthropic PM synthesis classifies provider errors without exposing payload bodies")
func anthropicPMSynthesisProviderClassifiesProviderErrors() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            Data("""
            {
              "type": "error",
              "error": {
                "type": "rate_limit_error",
                "message": "Your account has hit a rate limit."
              },
              "request_id": "req_test"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    await #expect(throws: PMOpenAISynthesisError.providerHTTPStatus(
        provider: .anthropic,
        status: 429,
        responseSummary: "type=rate_limit_error message=Your account has hit a rate limit."
    )) {
        try await provider.synthesizeConversationReply(
            request: makeAnthropicPMConversationRequest(),
            apiKey: "test-anthropic-key"
        )
    }
}

@Test("Anthropic PM synthesis treats request-too-large as retryable after bounded compaction")
func anthropicPMSynthesisProviderClassifiesRequestTooLarge() {
    let error = PMOpenAISynthesisError.providerHTTPStatus(
        provider: .anthropic,
        status: 413,
        responseSummary: "type=request_too_large message=Request exceeds the maximum allowed number of bytes."
    )

    #expect(error.boundedSummary.contains("anthropic_request_too_large_status=413"))
    #expect(error.retryableAfterContextCompaction == true)
    #expect(error.providerReturnedContent == true)
}

@Test("Anthropic PM synthesis rejects missing structured tool output")
func anthropicPMSynthesisProviderRejectsMissingToolUse() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            Data("""
            {
              "id": "msg_test",
              "type": "message",
              "role": "assistant",
              "model": "claude-sonnet-4-20250514",
              "content": [
                {
                  "type": "text",
                  "text": "Plain text should not be accepted for PM safe-apply."
                }
              ],
              "stop_reason": "end_turn"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    await #expect(throws: PMOpenAISynthesisError.providerMalformedResponse(
        provider: .anthropic,
        reason: "missing_pm_conversation_tool_use stop_reason=end_turn"
    )) {
        try await provider.synthesizeConversationReply(
            request: makeAnthropicPMConversationRequest(),
            apiKey: "test-anthropic-key"
        )
    }
}

@Test("Anthropic PM synthesis ignores returned thinking blocks and parses only PM tool input")
func anthropicPMSynthesisProviderDoesNotPersistThinkingBlocks() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            Data("""
            {
              "id": "msg_test",
              "type": "message",
              "role": "assistant",
              "model": "claude-sonnet-4-20250514",
              "content": [
                {
                  "type": "thinking",
                  "thinking": "hidden reasoning that must not become PM memory"
                },
                {
                  "type": "tool_use",
                  "id": "toolu_test",
                  "name": "emit_pm_conversation_reply",
                  "input": {
                    "replyBody": "Only this owner-facing reply is accepted.",
                    "actionPlanJSON": "",
                    "resolutionJSON": ""
                  }
                }
              ],
              "stop_reason": "tool_use"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.replyBody == "Only this owner-facing reply is accepted.")
    #expect(output.replyBody.contains("hidden reasoning") == false)
}

@Test("Anthropic PM synthesis selects the matching tool use when multiple content blocks are returned")
func anthropicPMSynthesisProviderSelectsMatchingToolUseAmongMultipleBlocks() async throws {
    let httpClient = StubAnthropicMessagesHTTPClient(
        response: .success(
            Data("""
            {
              "id": "msg_test",
              "type": "message",
              "role": "assistant",
              "model": "claude-sonnet-4-20250514",
              "content": [
                {
                  "type": "text",
                  "text": "Preparing the structured reply."
                },
                {
                  "type": "tool_use",
                  "id": "toolu_wrong",
                  "name": "other_tool",
                  "input": {
                    "replyBody": "Wrong tool.",
                    "actionPlanJSON": "",
                    "resolutionJSON": ""
                  }
                },
                {
                  "type": "tool_use",
                  "id": "toolu_test",
                  "name": "emit_pm_conversation_reply",
                  "input": {
                    "replyBody": "Correct PM reply.",
                    "actionPlanJSON": "",
                    "resolutionJSON": ""
                  }
                }
              ],
              "stop_reason": "tool_use"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesizeConversationReply(
        request: makeAnthropicPMConversationRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.replyBody == "Correct PM reply.")
}

private func makeAnthropicPMConversationRequest(
    ownerMessageBody: String = "Can you summarize the current PM context?",
    confirmedAppTruthSummary: [String] = [],
    analystArtifactSummary: [String] = []
) -> PMConversationOpenAISynthesisRequest {
    PMConversationOpenAISynthesisRequest(
        runtimeIdentifier: "claude-sonnet-4-20250514",
        reasoningMode: .standard,
        plannerMode: "owner_conversation_action_planning",
        sessionChannel: "in_app",
        ownerMessageBody: ownerMessageBody,
        confirmedAppTruthSummary: confirmedAppTruthSummary,
        analystArtifactSummary: analystArtifactSummary
    )
}

private func makeAnthropicToolUseResponse(
    replyBody: String,
    actionPlanJSON: String = "",
    resolutionJSON: String = ""
) -> Data {
    let escapedReply = jsonEscapedString(replyBody)
    let escapedActionPlan = jsonEscapedString(actionPlanJSON)
    let escapedResolution = jsonEscapedString(resolutionJSON)
    return Data("""
    {
      "id": "msg_test",
      "type": "message",
      "role": "assistant",
      "model": "claude-sonnet-4-20250514",
      "content": [
        {
          "type": "tool_use",
          "id": "toolu_test",
          "name": "emit_pm_conversation_reply",
          "input": {
            "replyBody": "\(escapedReply)",
            "actionPlanJSON": "\(escapedActionPlan)",
            "resolutionJSON": "\(escapedResolution)"
          }
        }
      ],
      "stop_reason": "tool_use"
    }
    """.utf8)
}

private func jsonEscapedString(_ value: String) -> String {
    let data = try! JSONEncoder().encode(value)
    let encoded = String(decoding: data, as: UTF8.self)
    return String(encoded.dropFirst().dropLast())
}

private func countSchemaKeyword(_ keyword: String, in value: JSONValue) -> Int {
    switch value {
    case .object(let object):
        return (object[keyword] == nil ? 0 : 1)
            + object.values.reduce(0) { $0 + countSchemaKeyword(keyword, in: $1) }
    case .array(let array):
        return array.reduce(0) { $0 + countSchemaKeyword(keyword, in: $1) }
    case .string, .number, .bool, .null:
        return 0
    }
}

private func unsupportedAnthropicSchemaKeywords(in value: JSONValue) -> [String] {
    let unsupported = Set([
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
    ])
    switch value {
    case .object(let object):
        let local = object.keys.filter { unsupported.contains($0) }
        return local + object.values.flatMap(unsupportedAnthropicSchemaKeywords)
    case .array(let array):
        return array.flatMap(unsupportedAnthropicSchemaKeywords)
    case .string, .number, .bool, .null:
        return []
    }
}

private actor StubAnthropicMessagesHTTPClient: AnthropicMessagesHTTPClient {
    enum Response {
        case success(Data, URLResponse)
        case failure(any Error)
    }

    private let response: Response
    private(set) var lastRequest: URLRequest?

    init(response: Response) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        switch response {
        case let .success(data, response):
            return (data, response)
        case let .failure(error):
            throw error
        }
    }
}
