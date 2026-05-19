import Foundation
import Testing
@testable import TradingKit

@Test("OpenAI PM synthesis provider builds a valid strict structured request for pm_conversation_reply")
func openAIPMSynthesisProviderBuildsValidStructuredRequest() async throws {
    let httpClient = StubPMOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"replyBody\\":\\"The latest proposed paper portfolio I can recover is long NVDA and short NYCB.\\",\\"actionPlan\\":null,\\"resolution\\":null}"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.openai.com/v1/responses")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = OpenAIResponsesPMSynthesisProvider(httpClient: httpClient)

    let result = try await provider.synthesizeConversationReply(
        request: makeOpenAIPMConversationRequest(runtimeIdentifier: "gpt-5.4", reasoningMode: .standard),
        apiKey: "test-openai-key"
    )

    #expect(result.replyBody.contains("latest proposed paper portfolio"))

    let request = try #require(await httpClient.lastRequest)
    #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
    #expect(request.httpMethod == "POST")
    #expect(request.timeoutInterval == OpenAIResponsesStructuredRequestBody.longRunningRequestTimeout)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-openai-key")
    let body = try #require(request.httpBody)
    let bodyText = String(decoding: body, as: UTF8.self)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    let text = try #require(json["text"]?.objectValue)
    let format = try #require(text["format"]?.objectValue)
    let schema = try #require(format["schema"])

    #expect(json["model"]?.stringValue == "gpt-5.4")
    #expect(format["type"]?.stringValue == "json_schema")
    #expect(format["name"]?.stringValue == "pm_conversation_reply")
    #expect(format["strict"]?.boolValue == true)
    #expect(bodyText.contains("selectedSkillReferences"))
    #expect(bodyText.contains("skillId"))
    #expect(bodyText.contains("exact active Agent Skill ids"))

    try validateOpenAIResponsesStructuredSchema(schema)

    let rootProperties = try #require(schema.objectValue?["properties"]?.objectValue)
    let resolution = try #require(rootProperties["resolution"]?.objectValue?["anyOf"]?.arrayValue?.first?.objectValue)
    let resolutionProperties = try #require(resolution["properties"]?.objectValue)
    let resolutionRequiredValues = try #require(resolution["required"]?.arrayValue)
    let resolutionRequired = resolutionRequiredValues.compactMap(\.stringValue)
    #expect(Set(resolutionProperties.keys) == Set(resolutionRequired))
    #expect(resolutionProperties["pendingAsk"] != nil)
}

@Test("OpenAI PM synthesis prompt includes app-owned signal actionability truth")
func openAIPMSynthesisPromptIncludesSignalTruth() async throws {
    let httpClient = StubPMOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"replyBody\\":\\"Those are FYI research alerts, not owner decisions.\\",\\"actionPlan\\":null,\\"resolution\\":null}"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.openai.com/v1/responses")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = OpenAIResponsesPMSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesizeConversationReply(
        request: makeOpenAIPMConversationRequest(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .standard,
            ownerMessageBody: "What are these new signals?",
            confirmedAppTruthSummary: [
                "Confirmed signal truth: 4 new research alert(s): 0 owner-review/proposal-candidate, 4 FYI/monitor-only/PM-review.",
                "Signal sig-fyi NVDA: status=new, actionability=notify_only, action=notify_only, direction=neutral."
            ]
        ),
        apiKey: "test-openai-key"
    )

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let bodyText = String(decoding: body, as: UTF8.self)
    #expect(bodyText.contains("Confirmed signal truth"))
    #expect(bodyText.contains("actionability=notify_only"))
    #expect(bodyText.contains("research alerts"))
}

@Test("OpenAI PM synthesis prompt includes Alpaca Live order review requirements")
func openAIPMSynthesisPromptIncludesAlpacaLiveOrderReviewRequirements() async throws {
    let httpClient = StubPMOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"replyBody\\":\\"I’ll create an in-app Live order review.\\",\\"actionPlan\\":null,\\"resolution\\":null}"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.openai.com/v1/responses")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = OpenAIResponsesPMSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesizeConversationReply(
        request: makeOpenAIPMConversationRequest(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .standard,
            ownerMessageBody: "Purchase $10,000 to the nearest share of META stock live. Market order opened for today."
        ),
        apiKey: "test-openai-key"
    )

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let bodyText = String(decoding: body, as: UTF8.self)
    #expect(bodyText.contains("reviewable Alpaca order instruction"))
    #expect(bodyText.contains("symbol, side, quantity or notional, order type, and time-in-force"))
    #expect(bodyText.contains("opened for today"))
    #expect(bodyText.contains("liveOrderNotionalAmount"))
    #expect(bodyText.contains("current usable symbol price"))
}

@Test("OpenAI PM synthesis prompt treats explicit analyst tasking as fresh work despite prior artifacts")
func openAIPMSynthesisPromptRequiresFreshAnalystTaskingForExplicitOwnerAsk() async throws {
    let httpClient = StubPMOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"replyBody\\":\\"I’ll launch a fresh Technology Analyst task for META.\\",\\"actionPlan\\":{\\"summary\\":\\"Launch analyst task\\",\\"actions\\":[{\\"actionType\\":\\"launch_ad_hoc_analyst_delegation\\",\\"summary\\":\\"Launch fresh META research\\",\\"charterId\\":\\"bench-sector-technology\\"}]},\\"resolution\\":null}"
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.openai.com/v1/responses")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = OpenAIResponsesPMSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesizeConversationReply(
        request: makeOpenAIPMConversationRequest(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .standard,
            ownerMessageBody: "Have the Technology Analyst research META across earnings, Connect, product releases, valuation, cash, and whether it can make meaningful technology-platform progress.",
            confirmedAppTruthSummary: [
                "Prior analyst artifact: META evidence-bounded read from an older task; source gaps remain open.",
                "analyst_bench_member id=bench-sector-technology title=Technology Analyst analyst=bench-sector-technology-analyst coverage=Technology and technology platforms ad_hoc=yes"
            ]
        ),
        apiKey: "test-openai-key"
    )

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    let promptText = try #require(json["input"]?.stringValue)
    #expect(promptText.contains("use `launch_ad_hoc_analyst_delegation`"))
    #expect(promptText.contains("Existing analyst memos, findings, standing reports, and prior follow-through messages are context for a fresh analyst-tasking request, not substitutes for it"))
    #expect(promptText.contains("Use `answer_only` from prior artifacts only when the owner asks for status, readback, explanation, or prior results"))
    #expect(promptText.contains("unless the selected charter/source policy, owner/task wording, or hard app governance expressly restricts the source set"))
    #expect(promptText.contains("Prior analyst artifact: META evidence-bounded read"))
}

@Test("PM structured schema validator catches missing required keys under resolution")
func pmStructuredSchemaValidatorFlagsInvalidResolutionShape() throws {
    let invalidSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object([
            "replyBody": .object(["type": .string("string")]),
            "actionPlan": .object(["type": .string("null")]),
            "resolution": .object([
                "type": .string("object"),
                "additionalProperties": .bool(false),
                "properties": .object([
                    "intentClass": .object(["type": .string("string")]),
                    "disposition": .object(["type": .string("string")]),
                    "pendingAsk": .object(["type": .string("null")])
                ]),
                "required": .array([
                    .string("intentClass"),
                    .string("disposition")
                ])
            ])
        ]),
        "required": .array([
            .string("replyBody"),
            .string("actionPlan"),
            .string("resolution")
        ])
    ])

    do {
        try validateOpenAIResponsesStructuredSchema(invalidSchema)
        Issue.record("Expected invalid resolution schema to fail validation.")
    } catch let error as OpenAIResponsesStructuredSchemaValidationError {
        #expect(error.boundedSummary.contains("schema.properties.resolution"))
        #expect(error.boundedSummary.contains("required_mismatch"))
    }
}

@Test("OpenAI PM synthesis provider preserves bounded error detail for oversized requests")
func openAIPMSynthesisProviderPreservesOversizedRequestDetail() async throws {
    let httpClient = StubPMOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "error": {
                "message": "This request exceeded the model context length.",
                "type": "invalid_request_error",
                "param": "input",
                "code": "context_length_exceeded"
              }
            }
            """.utf8),
            HTTPURLResponse(
                url: URL(string: "https://api.openai.com/v1/responses")!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: [:]
            )!
        )
    )
    let provider = OpenAIResponsesPMSynthesisProvider(httpClient: httpClient)

    await #expect(throws: PMOpenAISynthesisError.httpStatus(400, responseSummary: "code=context_length_exceeded type=invalid_request_error param=input message=This request exceeded the model context length.")) {
        try await provider.synthesizeConversationReply(
            request: PMConversationOpenAISynthesisRequest(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                plannerMode: "owner_conversation_action_planning",
                sessionChannel: "in_app",
                ownerMessageBody: "What was the latest proposed paper portfolio?"
            ),
            apiKey: "test-openai-key"
        )
    }
}

@Test("OpenAI PM invalid schema errors stay precise and non-retryable")
func openAIPMSynthesisProviderClassifiesInvalidSchemaPrecisely() async throws {
    let error = PMOpenAISynthesisError.invalidSchema(
        reason: "schema_name=pm_conversation_reply schema_path=schema.properties.resolution required_mismatch"
    )
    #expect(error.boundedSummary.contains("invalid_schema"))
    #expect(error.providerReturnedContent == false)
    #expect(error.providerResponseAccepted == false)
    #expect(error.retryableAfterContextCompaction == false)
}

@Test("OpenAI PM synthesis provider exposes request-too-large bounded summary")
func openAIPMSynthesisProviderExposesRequestTooLargeSummary() async throws {
    let error = PMOpenAISynthesisError.httpStatus(
        400,
        responseSummary: "code=context_length_exceeded type=invalid_request_error param=input message=This request exceeded the model context length."
    )

    #expect(error.boundedSummary.contains("openai_request_too_large_status=400"))
    #expect(error.retryableAfterContextCompaction == true)
    #expect(error.providerReturnedContent == true)
    #expect(error.providerResponseAccepted == false)
}

private actor StubPMOpenAIResponsesHTTPClient: OpenAIResponsesHTTPClient {
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
        case let .success(data, urlResponse):
            return (data, urlResponse)
        case let .failure(error):
            throw error
        }
    }
}

private func makeOpenAIPMConversationRequest(
    runtimeIdentifier: String,
    reasoningMode: AnalystRuntimeReasoningMode?,
    ownerMessageBody: String = "What was the latest proposed paper portfolio?",
    confirmedAppTruthSummary: [String] = []
) -> PMConversationOpenAISynthesisRequest {
    PMConversationOpenAISynthesisRequest(
        runtimeIdentifier: runtimeIdentifier,
        reasoningMode: reasoningMode,
        plannerMode: "owner_conversation_action_planning",
        sessionChannel: "in_app",
        ownerMessageBody: ownerMessageBody,
        confirmedAppTruthSummary: confirmedAppTruthSummary
    )
}
