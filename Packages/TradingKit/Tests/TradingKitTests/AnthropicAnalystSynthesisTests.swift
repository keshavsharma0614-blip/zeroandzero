import Foundation
import Testing
@testable import TradingKit

@Test("Anthropic analyst synthesis provider builds forced strict tool-use request")
func anthropicAnalystSynthesisProviderBuildsForcedStrictToolUseRequest() async throws {
    let httpClient = StubAnthropicAnalystHTTPClient(
        response: .success((
            makeAnthropicAnalystToolUseResponse(),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        ))
    )
    let provider = AnthropicMessagesAnalystSynthesisProvider(
        httpClient: httpClient,
        requestTimeoutSeconds: 180
    )

    let output = try await provider.synthesize(
        request: makeAnthropicAnalystRequest(),
        apiKey: "test-anthropic-key"
    )

    #expect(output.memoTitle == "Anthropic analyst memo")
    #expect(output.findingTitle == "Anthropic analyst finding")

    let request = try #require(await httpClient.lastRequest)
    #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-anthropic-key")
    #expect(request.value(forHTTPHeaderField: "anthropic-version") == AnthropicMessagesPMSynthesisProvider.defaultAnthropicVersion)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.timeoutInterval == 180)

    let body = try #require(request.httpBody)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    #expect(json["model"]?.stringValue == "claude-sonnet-4-6")
    #expect(json["thinking"] == nil)
    #expect(json["response_format"] == nil)
    #expect(json["output_config"] == nil)

    let messages = try #require(json["messages"]?.arrayValue)
    let userMessage = try #require(messages.first?.objectValue)
    let userContent = try #require(userMessage["content"]?.stringValue)
    #expect(userContent.contains("Technology Analyst"))
    #expect(userContent.contains("Nvidia AI buildout faces power constraints"))
    #expect(userContent.contains("AI Index Report"))

    let tools = try #require(json["tools"]?.arrayValue)
    let webSearchTool = try #require(tools.first?.objectValue)
    #expect(webSearchTool["type"]?.stringValue == "web_search_20250305")
    #expect(webSearchTool["name"]?.stringValue == "web_search")
    #expect(webSearchTool["max_uses"] == nil)
    let tool = try #require(tools.dropFirst().first?.objectValue)
    #expect(tool["name"]?.stringValue == "emit_analyst_synthesis")
    #expect(tool["strict"]?.boolValue == true)
    let schema = try #require(tool["input_schema"])
    try validateAnthropicStrictToolInputSchema(schema)
    #expect(anthropicAnalystUnsupportedSchemaKeywords(in: schema).isEmpty)
    let properties = try #require(schema.objectValue?["properties"]?.objectValue)
    #expect(properties["findingTitle"] != nil)
    #expect(properties["memoExecutiveSummary"] != nil)
    #expect(properties["memoExecutiveSummary"]?.objectValue?["description"]?.stringValue?.contains("PM-useful") == true)
    #expect(properties["memoEvidenceSummary"]?.objectValue?["description"]?.stringValue?.contains("material app-owned news") == true)
    let toolDescription = try #require(tool["description"]?.stringValue)
    #expect(toolDescription.contains("Never use placeholders") == true)
    #expect(userContent.contains("Standing sector/overlay memo quality rules") == true)
    #expect(userContent.contains("Do not write \"null\", \"placeholder\"") == true)
    #expect(userContent.contains("Public/domain web research is enabled") == true)
    #expect(userContent.contains("direct question-driven web searches") == true)
    let schemaProperties = try #require(schema.objectValue?["properties"]?.objectValue)
    #expect(schemaProperties["skillUsageSummaries"] != nil)

    let toolChoice = try #require(json["tool_choice"]?.objectValue)
    #expect(toolChoice["type"]?.stringValue == "auto")
    #expect(toolChoice["name"] == nil)
}

@Test("Anthropic analyst synthesis provider includes selected Agent Skills and parses usage")
func anthropicAnalystSynthesisProviderIncludesSelectedAgentSkills() async throws {
    let httpClient = StubAnthropicAnalystHTTPClient(
        response: .success((
            makeAnthropicAnalystToolUseResponse(skillUsageJSON: """
            [
              {
                "skillId": "skill-source-quality-corroboration",
                "skillTitle": "Source Quality And Corroboration",
                "requirement": "required",
                "usage": "applied",
                "usageSummary": "Separated app-owned news from supplemental source support."
              }
            ]
            """),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        ))
    )
    let provider = AnthropicMessagesAnalystSynthesisProvider(httpClient: httpClient)

    let output = try await provider.synthesize(
        request: makeAnthropicAnalystRequest(
            selectedSkills: [
                AgentSkillContextItem(
                    skillId: AgentSkillSeed.sourceQualityCorroborationID,
                    title: "Source Quality And Corroboration",
                    summary: "Classify evidence strength and gaps.",
                    documentBody: "# Source Quality And Corroboration\n\nSeparate app-owned news, primary sources, weak support, and gaps.",
                    category: .sourceEvaluationMethod,
                    requirement: .required,
                    rationale: "Recent News reports must classify support quality.",
                    availability: .active,
                    skillUpdatedAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ]
        ),
        apiKey: "test-anthropic-key"
    )

    #expect(output.skillUsageSummaries.first?.skillId == AgentSkillSeed.sourceQualityCorroborationID)
    #expect(output.skillUsageSummaries.first?.usage == .applied)

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let json = try JSONDecoder().decode([String: JSONValue].self, from: body)
    let message = try #require(json["messages"]?.arrayValue?.first?.objectValue)
    let userContent = try #require(message["content"]?.stringValue)
    #expect(userContent.contains("Selected Agent Skills:") == true)
    #expect(userContent.contains("Source Quality And Corroboration") == true)
    #expect(userContent.contains("method_body=") == true)
    #expect(userContent.contains("methodology guidance only") == true)
}

@Test("Anthropic analyst synthesis provider classifies transport timeouts with bounded detail")
func anthropicAnalystSynthesisProviderClassifiesTransportTimeout() async throws {
    let httpClient = StubAnthropicAnalystHTTPClient(
        response: .failure(URLError(.timedOut))
    )
    let provider = AnthropicMessagesAnalystSynthesisProvider(httpClient: httpClient)

    do {
        _ = try await provider.synthesize(
            request: makeAnthropicAnalystRequest(),
            apiKey: "test-anthropic-key"
        )
        Issue.record("Expected Anthropic analyst provider to throw on timeout.")
    } catch let error as AnalystAnthropicSynthesisError {
        #expect(error.boundedSummary == "anthropic_transport_error=timed_out")
    }
}

@Test("Anthropic analyst synthesis provider rejects malformed tool input safely")
func anthropicAnalystSynthesisProviderRejectsMalformedToolInput() async throws {
    let httpClient = StubAnthropicAnalystHTTPClient(
        response: .success((
            Data("""
            {
              "id": "msg_bad",
              "type": "message",
              "role": "assistant",
              "model": "claude-sonnet-4-6",
              "content": [
                {
                  "type": "tool_use",
                  "id": "toolu_bad",
                  "name": "emit_analyst_synthesis",
                  "input": {
                    "findingTitle": "",
                    "findingSummary": "",
                    "findingThesis": "",
                    "findingConfidence": 0.4,
                    "findingTimeHorizon": "quarterly",
                    "memoTitle": "",
                    "memoExecutiveSummary": "",
                    "memoCurrentView": "",
                    "memoEvidenceSummary": "",
                    "memoUncertaintySummary": "",
                    "memoRecommendedNextStep": "",
                    "suggestedSymbols": [],
                    "suggestedTags": []
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
        ))
    )
    let provider = AnthropicMessagesAnalystSynthesisProvider(httpClient: httpClient)

    await #expect(throws: AnalystAnthropicSynthesisError.self) {
        _ = try await provider.synthesize(
            request: makeAnthropicAnalystRequest(),
            apiKey: "test-anthropic-key"
        )
    }
}

@Test("Anthropic analyst synthesis provider rejects placeholder memo fields safely")
func anthropicAnalystSynthesisProviderRejectsPlaceholderMemoFields() async throws {
    let httpClient = StubAnthropicAnalystHTTPClient(
        response: .success((
            makeAnthropicAnalystToolUseResponse(
                memoExecutiveSummary: "null",
                memoEvidenceSummary: "placeholder"
            ),
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
        ))
    )
    let provider = AnthropicMessagesAnalystSynthesisProvider(httpClient: httpClient)

    do {
        _ = try await provider.synthesize(
            request: makeAnthropicAnalystRequest(),
            apiKey: "test-anthropic-key"
        )
        Issue.record("Expected Anthropic analyst provider to reject placeholder memo fields.")
    } catch let error as AnalystAnthropicSynthesisError {
        #expect(error.boundedSummary == "anthropic_malformed_response=openai_malformed_response=placeholder_required_field_memoExecutiveSummary")
    }
}

@Test("Analyst synthesis output validation accepts concise substantive memo fields")
func analystSynthesisValidationAcceptsConciseSubstantiveMemoFields() throws {
    let output = AnalystOpenAISynthesisOutput(
        findingTitle: "Technology signal",
        findingSummary: "AI infrastructure evidence is still monitor-worthy.",
        findingThesis: "Power and deployment constraints shape timing but do not invalidate demand.",
        findingConfidence: 0.68,
        findingTimeHorizon: "quarterly",
        memoTitle: "Technology monitor memo",
        memoExecutiveSummary: "AI infrastructure remains constructive, but power timing is the gating issue.",
        memoCurrentView: "Keep infrastructure exposure under review while separating demand from deployment timing.",
        memoEvidenceSummary: "App-owned news and supplemental context both point to power and capex timing as the key support.",
        memoUncertaintySummary: "Primary disclosures are still needed before increasing conviction.",
        memoRecommendedNextStep: "Monitor earnings commentary and keep any next step behind PM review.",
        suggestedSymbols: ["nvda"],
        suggestedTags: ["AI"]
    )

    let validated = try output.validated()
    #expect(validated.memoExecutiveSummary.contains("power timing"))
    #expect(validated.suggestedSymbols == ["NVDA"])
}

@Test("Anthropic analyst synthesis provider classifies provider errors without exposing payload bodies")
func anthropicAnalystSynthesisProviderClassifiesProviderErrors() async throws {
    let errorBody = Data("""
    {
      "type": "error",
      "error": {
        "type": "rate_limit_error",
        "message": "too many requests for this workspace"
      }
    }
    """.utf8)
    let httpClient = StubAnthropicAnalystHTTPClient(
        response: .success((
            errorBody,
            HTTPURLResponse(
                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: [:]
            )!
        ))
    )
    let provider = AnthropicMessagesAnalystSynthesisProvider(httpClient: httpClient)

    do {
        _ = try await provider.synthesize(
            request: makeAnthropicAnalystRequest(),
            apiKey: "test-anthropic-key"
        )
        Issue.record("Expected Anthropic analyst provider to throw on HTTP 429.")
    } catch let error as AnalystAnthropicSynthesisError {
        #expect(error.boundedSummary.contains("anthropic_rate_limit_or_quota_status=429") == true)
        #expect(error.boundedSummary.contains("\"type\"") == false)
        #expect(error.boundedSummary.contains("\"message\"") == false)
    }
}

private actor StubAnthropicAnalystHTTPClient: AnthropicMessagesHTTPClient {
    let response: Result<(Data, URLResponse), Error>
    private(set) var lastRequest: URLRequest?

    init(response: Result<(Data, URLResponse), Error>) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return try response.get()
    }
}

private func makeAnthropicAnalystRequest(
    selectedSkills: [AgentSkillContextItem] = []
) -> AnalystOpenAISynthesisRequest {
    AnalystOpenAISynthesisRequest(
        runtimeIdentifier: "claude-sonnet-4-6",
        reasoningMode: .standard,
        charterTitle: "Technology Analyst",
        charterSummary: "Focus on technology, AI, semiconductors, and software platform signals.",
        charterDocumentBodyExcerpt: "Technology Analyst charter: app-news-first, no trade authority.",
        taskTitle: "Technology Analyst standing report refresh",
        taskDescription: "Review current technology evidence for PM review.",
        taskIntent: "standard_standing_report",
        researchPlanSummary: "Use app-owned news first, then bounded approved evidence.",
        missingInformationItems: [],
        researchQuestionItems: ["Are AI infrastructure constraints changing the technology risk/reward?"],
        plannedSourceTargets: [
            AnalystOpenAISynthesisRequest.PlannedSourceTarget(
                label: "AI Index Report",
                category: "approved_external_source",
                source: "https://aiindex.stanford.edu/report/",
                whyItMatters: "Approved AI infrastructure context."
            )
        ],
        sourceGapItems: [],
        newsItems: [
            AnalystOpenAISynthesisRequest.NewsItem(
                source: "rss_marketwatch",
                title: "Nvidia AI buildout faces power constraints",
                summary: "Power and capex frictions still shape monetization timing.",
                symbols: ["NVDA", "MSFT"],
                tags: ["ai", "power"],
                publishedAt: Date(timeIntervalSince1970: 1_700_700_000)
            )
        ],
        externalEvidenceItems: [
            AnalystOpenAISynthesisRequest.EvidenceItem(
                sourceID: "stanford-ai-index-report",
                title: "AI Index Report",
                summary: "Scaling frictions remain relevant.",
                snippet: "Power availability remains a buildout bottleneck.",
                url: "https://aiindex.stanford.edu/report/",
                observedAt: Date(timeIntervalSince1970: 1_700_700_010),
                provenanceNote: "approved_allowlist_source:stanford_ai_index",
                baselineRelation: "incremental_context",
                incrementalValueSummary: "Adds bounded external context."
            )
        ],
        externalEvidenceIssues: [],
        selectedSkills: selectedSkills
    )
}

private func makeAnthropicAnalystToolUseResponse(
    memoExecutiveSummary: String = "The technology lane remains constructive but watch power constraints.",
    memoEvidenceSummary: String = "App-owned news plus approved AI Index context both point to power constraints.",
    skillUsageJSON: String = "[]"
) -> Data {
    Data("""
    {
      "id": "msg_analyst",
      "type": "message",
      "role": "assistant",
      "model": "claude-sonnet-4-6",
      "content": [
        {
          "type": "tool_use",
          "id": "toolu_analyst",
          "name": "emit_analyst_synthesis",
          "input": {
            "findingTitle": "Anthropic analyst finding",
            "findingSummary": "Power and capex remain important technology watchpoints.",
            "findingThesis": "AI infrastructure demand remains intact, but deployment timing still depends on power availability.",
            "findingConfidence": 0.72,
            "findingTimeHorizon": "quarterly",
            "memoTitle": "Anthropic analyst memo",
            "memoExecutiveSummary": "\(memoExecutiveSummary)",
            "memoCurrentView": "Monitor AI infrastructure beneficiaries while qualifying timing risk.",
            "memoEvidenceSummary": "\(memoEvidenceSummary)",
            "memoUncertaintySummary": "The timing and magnitude of capex digestion remain uncertain.",
            "memoRecommendedNextStep": "Keep the PM watch focused on deployment, capex, and power availability signals.",
            "suggestedSymbols": ["NVDA", "MSFT"],
            "suggestedTags": ["ai", "power"],
            "skillUsageSummaries": \(skillUsageJSON)
          }
        }
      ],
      "stop_reason": "tool_use"
    }
    """.utf8)
}

private func anthropicAnalystUnsupportedSchemaKeywords(in value: JSONValue) -> [String] {
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
        "minProperties",
        "maxProperties",
        "propertyNames",
        "patternProperties",
        "const",
        "not",
        "anyOf",
        "oneOf",
        "allOf"
    ])
    switch value {
    case .object(let object):
        let local = object.keys.filter { unsupported.contains($0) }
        return local + object.values.flatMap(anthropicAnalystUnsupportedSchemaKeywords)
    case .array(let array):
        return array.flatMap(anthropicAnalystUnsupportedSchemaKeywords)
    case .string, .number, .bool, .null:
        return []
    }
}
