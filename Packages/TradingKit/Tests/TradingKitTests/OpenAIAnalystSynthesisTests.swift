import Foundation
import Testing
@testable import TradingKit

@Test("OpenAI Responses synthesis provider builds bounded structured request")
func openAIResponsesProviderBuildsStructuredRequest() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"findingTitle\\":\\"Model finding\\",\\"findingSummary\\":\\"Model summary\\",\\"findingThesis\\":\\"Model thesis\\",\\"findingConfidence\\":0.66,\\"findingTimeHorizon\\":\\"quarterly\\",\\"memoTitle\\":\\"Model memo\\",\\"memoExecutiveSummary\\":\\"Model executive summary\\",\\"memoCurrentView\\":\\"Model current view\\",\\"memoEvidenceSummary\\":\\"Model evidence summary\\",\\"memoUncertaintySummary\\":\\"Model uncertainty summary\\",\\"memoRecommendedNextStep\\":\\"Model next step\\",\\"suggestedSymbols\\":[\\"NVDA\\"],\\"suggestedTags\\":[\\"ai\\"]}"
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesize(
        request: makeOpenAISynthesisRequest(runtimeIdentifier: "gpt-4.1", reasoningMode: .standard),
        apiKey: "test-openai-key"
    )

    let request = try #require(await httpClient.lastRequest)
    #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
    #expect(request.httpMethod == "POST")
    #expect(request.timeoutInterval == OpenAIResponsesStructuredRequestBody.longRunningRequestTimeout)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-openai-key")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let model = json?["model"] as? String
    let store = json?["store"] as? Bool
    let instructions = json?["instructions"] as? String
    let input = json?["input"] as? String
    let tools = json?["tools"] as? [[String: Any]]
    let firstTool = try #require(tools?.first)
    let text = json?["text"] as? [String: Any]
    let format = text?["format"] as? [String: Any]

    #expect(model == "gpt-4.1")
    #expect(store == false)
    #expect(instructions?.contains("Return only valid JSON") == true)
    #expect(input?.contains("Task title: Test task") == true)
    #expect(input?.contains("Supplemental policy-governed external evidence") == true)
    #expect(input?.contains("Treat app-owned news as baseline context when it is relevant") == true)
    #expect(input?.contains("Suppress duplicate fact patterns across app-owned news and external sources.") == true)
    #expect(input?.contains("Public/domain web research is enabled") == true)
    #expect(input?.contains("direct question-driven web searches") == true)
    #expect(firstTool["type"] as? String == "web_search")
    #expect(firstTool["search_context_size"] as? String == "high")
    #expect(firstTool["external_web_access"] as? Bool == true)
    #expect(firstTool["return_token_budget"] == nil)
    #expect(json?["tool_choice"] as? String == "auto")
    #expect(input?.contains("baseline_relation=stronger_confirmation") == true)
    #expect(format?["type"] as? String == "json_schema")
    #expect(format?["name"] as? String == "analyst_synthesis")
    #expect(format?["strict"] as? Bool == true)
    let schema = format?["schema"] as? [String: Any]
    let properties = schema?["properties"] as? [String: Any]
    #expect(properties?["skillUsageSummaries"] != nil)
}

@Test("OpenAI research planning provider enables Responses web search")
func openAIResearchPlanningProviderEnablesResponsesWebSearch() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"planSummary\\":\\"Search current public sources.\\",\\"missingInformation\\":[\\"official timing\\"],\\"researchQuestions\\":[\\"Which sources answer timing?\\"],\\"publicTargets\\":[{\\"source\\":\\"Meta Investor Relations\\",\\"urlOrDomain\\":\\"https://investor.fb.com/\\",\\"category\\":\\"issuer_primary\\",\\"whyItMatters\\":\\"Official source.\\",\\"missingInformationNeed\\":\\"earnings timing\\"}],\\"sourceGapRecommendations\\":[]}"
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
    let provider = OpenAIResponsesAnalystResearchPlanningProvider(httpClient: httpClient)

    _ = try await provider.planResearch(
        request: makeResearchPlanningRequest(runtimeIdentifier: "gpt-5.5", reasoningMode: .deliberate),
        apiKey: "test-openai-key"
    )

    let request = try #require(await httpClient.lastRequest)
    #expect(request.timeoutInterval == OpenAIResponsesStructuredRequestBody.longRunningRequestTimeout)
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let tools = json?["tools"] as? [[String: Any]]
    let firstTool = try #require(tools?.first)
    let input = json?["input"] as? String

    #expect(firstTool["type"] as? String == "web_search")
    #expect(firstTool["search_context_size"] as? String == "high")
    #expect(firstTool["external_web_access"] as? Bool == true)
    #expect(firstTool["return_token_budget"] == nil)
    #expect(json?["tool_choice"] as? String == "auto")
    #expect(input?.contains("Use web search to discover current public sources") == true)
    #expect(input?.contains("hint list is only a starting point") == true)
    #expect(input?.contains("Required owner/PM question checklist") == true)
    #expect(input?.contains("next earnings timing") == true)
    #expect(input?.contains("cash/liquidity") == true)
}

@Test("OpenAI Responses synthesis provider includes selected Agent Skills and parses skill usage")
func openAIResponsesProviderIncludesSelectedAgentSkills() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"findingTitle\\":\\"Skill finding\\",\\"findingSummary\\":\\"Skill summary\\",\\"findingThesis\\":\\"Skill thesis\\",\\"findingConfidence\\":0.72,\\"findingTimeHorizon\\":\\"quarterly\\",\\"memoTitle\\":\\"Skill memo\\",\\"memoExecutiveSummary\\":\\"Skill executive summary\\",\\"memoCurrentView\\":\\"Skill current view\\",\\"memoEvidenceSummary\\":\\"Skill evidence summary\\",\\"memoUncertaintySummary\\":\\"Skill uncertainty summary\\",\\"memoRecommendedNextStep\\":\\"Skill next step\\",\\"suggestedSymbols\\":[\\"NVDA\\"],\\"suggestedTags\\":[\\"skills\\"],\\"skillUsageSummaries\\":[{\\"skillId\\":\\"skill-disconfirming-evidence-checklist\\",\\"skillTitle\\":\\"Disconfirming Evidence Checklist\\",\\"requirement\\":\\"required\\",\\"usage\\":\\"applied\\",\\"usageSummary\\":\\"Pressure-tested the thesis against opposing evidence.\\"}]}"
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    let result = try await provider.synthesize(
        request: makeOpenAISynthesisRequest(
            runtimeIdentifier: "gpt-4.1",
            selectedSkills: [makeSelectedAnalystSkillContext(requirement: .required)]
        ),
        apiKey: "test-openai-key"
    )

    #expect(result.skillUsageSummaries.first?.skillId == AgentSkillSeed.disconfirmingEvidenceChecklistID)
    #expect(result.skillUsageSummaries.first?.usage == .applied)

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let input = json?["input"] as? String
    #expect(input?.contains("Selected Agent Skills:") == true)
    #expect(input?.contains("Disconfirming Evidence Checklist") == true)
    #expect(input?.contains("full method body") == true)
    #expect(input?.contains("methodology guidance only") == true)
}

@Test("OpenAI Responses synthesis provider adds recent-news specialization clustering rules")
func openAIResponsesProviderAddsRecentNewsSpecializationRules() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"findingTitle\\":\\"Model finding\\",\\"findingSummary\\":\\"Model summary\\",\\"findingThesis\\":\\"Model thesis\\",\\"findingConfidence\\":0.66,\\"findingTimeHorizon\\":\\"quarterly\\",\\"memoTitle\\":\\"Model memo\\",\\"memoExecutiveSummary\\":\\"Model executive summary\\",\\"memoCurrentView\\":\\"Model current view\\",\\"memoEvidenceSummary\\":\\"Model evidence summary\\",\\"memoUncertaintySummary\\":\\"Model uncertainty summary\\",\\"memoRecommendedNextStep\\":\\"Model next step\\",\\"suggestedSymbols\\":[\\"AAPL\\"],\\"suggestedTags\\":[\\"recent-news\\"]}"
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesize(
        request: makeOpenAISynthesisRequest(
            runtimeIdentifier: "gpt-4.1-mini",
            taskIntent: "recent_news_material_impact",
            taskDescription: "Cluster repeated coverage, explain why the event matters now, and stay quiet on duplicate pickup."
        ),
        apiKey: "test-openai-key"
    )

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let input = json?["input"] as? String

    #expect(input?.contains("Recent News specialization rules:") == true)
    #expect(input?.contains("Cluster repeated coverage of the same underlying event into one coherent event view.") == true)
    #expect(input?.contains("Avoid noisy escalation language when later pickup does not materially change the meaning.") == true)
}

@Test("OpenAI Responses synthesis provider adds portfolio-risk specialization posture rules")
func openAIResponsesProviderAddsPortfolioRiskSpecializationRules() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"findingTitle\\":\\"Model finding\\",\\"findingSummary\\":\\"Model summary\\",\\"findingThesis\\":\\"Model thesis\\",\\"findingConfidence\\":0.66,\\"findingTimeHorizon\\":\\"quarterly\\",\\"memoTitle\\":\\"Model memo\\",\\"memoExecutiveSummary\\":\\"Model executive summary\\",\\"memoCurrentView\\":\\"Model current view\\",\\"memoEvidenceSummary\\":\\"Model evidence summary\\",\\"memoUncertaintySummary\\":\\"Model uncertainty summary\\",\\"memoRecommendedNextStep\\":\\"Model next step\\",\\"suggestedSymbols\\":[\\"NVDA\\"],\\"suggestedTags\\":[\\"portfolio-risk\\"]}"
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    _ = try await provider.synthesize(
        request: makeOpenAISynthesisRequest(
            runtimeIdentifier: "gpt-4.1-mini",
            taskIntent: "portfolio_risk_trigger",
            taskDescription: "Interpret concentration and long-vs-short posture, explain why it matters now, and avoid noisy repeated escalation."
        ),
        apiKey: "test-openai-key"
    )

    let request = try #require(await httpClient.lastRequest)
    let body = try #require(request.httpBody)
    let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let input = json?["input"] as? String

    #expect(input?.contains("Portfolio Risk specialization rules:") == true)
    #expect(input?.contains("Interpret current book posture, not just trigger keywords: concentration shape, clustered/crowded exposure, and long-vs-short imbalance.") == true)
    #expect(input?.contains("Keep escalation language bounded: monitor-only when meaning is unchanged, stronger escalation only when risk meaning materially changed.") == true)
}

@Test("OpenAI Responses synthesis provider parses output_text JSON into analyst output")
func openAIResponsesProviderParsesOutputTextJSON() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"findingTitle\\":\\"Model finding\\",\\"findingSummary\\":\\"Model summary\\",\\"findingThesis\\":\\"Model thesis\\",\\"findingConfidence\\":0.91,\\"findingTimeHorizon\\":\\"monthly\\",\\"memoTitle\\":\\"Model memo\\",\\"memoExecutiveSummary\\":\\"Model executive summary\\",\\"memoCurrentView\\":\\"Model current view\\",\\"memoEvidenceSummary\\":\\"Model evidence summary\\",\\"memoUncertaintySummary\\":\\"Model uncertainty summary\\",\\"memoRecommendedNextStep\\":\\"Model next step\\",\\"suggestedSymbols\\":[\\"nvda\\",\\"MSFT\\"],\\"suggestedTags\\":[\\"AI\\",\\"power\\"]}"
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    let result = try await provider.synthesize(
        request: makeOpenAISynthesisRequest(runtimeIdentifier: "gpt-4.1"),
        apiKey: "test-openai-key"
    )

    #expect(result.findingTitle == "Model finding")
    #expect(result.findingConfidence == 0.91)
    #expect(result.suggestedSymbols == ["MSFT", "NVDA"])
    #expect(result.suggestedTags == ["ai", "power"])
}

@Test("OpenAI Responses synthesis provider parses nested content text JSON")
func openAIResponsesProviderParsesNestedContentJSON() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output": [
                {
                  "content": [
                    {
                      "type": "output_text",
                      "text": "```json\\n{\\"findingTitle\\":\\"Nested finding\\",\\"findingSummary\\":\\"Nested summary\\",\\"findingThesis\\":\\"Nested thesis\\",\\"findingConfidence\\":0.53,\\"findingTimeHorizon\\":null,\\"memoTitle\\":\\"Nested memo\\",\\"memoExecutiveSummary\\":\\"Nested executive summary\\",\\"memoCurrentView\\":\\"Nested current view\\",\\"memoEvidenceSummary\\":\\"Nested evidence summary\\",\\"memoUncertaintySummary\\":\\"Nested uncertainty summary\\",\\"memoRecommendedNextStep\\":\\"Nested next step\\",\\"suggestedSymbols\\":[],\\"suggestedTags\\":[\\"macro\\"]}\\n```"
                    }
                  ]
                }
              ]
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    let result = try await provider.synthesize(
        request: makeOpenAISynthesisRequest(runtimeIdentifier: "gpt-4.1-mini"),
        apiKey: "test-openai-key"
    )

    #expect(result.findingTitle == "Nested finding")
    #expect(result.findingTimeHorizon == nil)
    #expect(result.memoTitle == "Nested memo")
    #expect(result.suggestedTags == ["macro"])
}

@Test("OpenAI Responses synthesis provider fails boundedly on malformed output")
func openAIResponsesProviderFailsBoundedlyOnMalformedOutput() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output_text": "{\\"findingTitle\\":\\"\\",\\"findingSummary\\":\\"Missing required title\\",\\"findingThesis\\":\\"Thesis\\",\\"findingConfidence\\":0.2,\\"findingTimeHorizon\\":null,\\"memoTitle\\":\\"Memo\\",\\"memoExecutiveSummary\\":\\"Summary\\",\\"memoCurrentView\\":\\"View\\",\\"memoEvidenceSummary\\":\\"Evidence\\",\\"memoUncertaintySummary\\":\\"Uncertainty\\",\\"memoRecommendedNextStep\\":\\"Next\\",\\"suggestedSymbols\\":[],\\"suggestedTags\\":[]}"
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    await #expect(throws: AnalystOpenAISynthesisError.malformedResponse(reason: "missing_required_field")) {
        try await provider.synthesize(
            request: makeOpenAISynthesisRequest(runtimeIdentifier: "gpt-4.1"),
            apiKey: "test-openai-key"
        )
    }
}

@Test("OpenAI Responses synthesis provider fails boundedly on refusal")
func openAIResponsesProviderFailsBoundedlyOnRefusal() async throws {
    let httpClient = StubOpenAIResponsesHTTPClient(
        response: .success(
            Data("""
            {
              "output": [
                {
                  "content": [
                    {
                      "type": "refusal",
                      "refusal": "I can't comply with that."
                    }
                  ]
                }
              ]
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
    let provider = OpenAIResponsesAnalystSynthesisProvider(httpClient: httpClient)

    await #expect(throws: AnalystOpenAISynthesisError.refusal) {
        try await provider.synthesize(
            request: makeOpenAISynthesisRequest(runtimeIdentifier: "gpt-4.1"),
            apiKey: "test-openai-key"
        )
    }
}

private actor StubOpenAIResponsesHTTPClient: OpenAIResponsesHTTPClient {
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

private func makeOpenAISynthesisRequest(
    runtimeIdentifier: String,
    reasoningMode: AnalystRuntimeReasoningMode? = nil,
    taskIntent: String = "synthesis",
    taskDescription: String = "Synthesize the current bounded evidence into the existing memo/finding contract.",
    selectedSkills: [AgentSkillContextItem] = []
) -> AnalystOpenAISynthesisRequest {
    AnalystOpenAISynthesisRequest(
        runtimeIdentifier: runtimeIdentifier,
        reasoningMode: reasoningMode,
        charterTitle: "Technology Analyst",
        charterSummary: "Focus on durable technology adoption evidence and implementation bottlenecks.",
        charterDocumentBodyExcerpt: "# Analyst Charter\nRecent evidence matters.",
        taskTitle: "Test task",
        taskDescription: taskDescription,
        taskIntent: taskIntent,
        pmTaskingBriefBody: "Bounded PM brief body.",
        newsItems: [
            .init(
                source: "rss_marketwatch",
                title: "AI buildout stays capital intensive",
                summary: "Demand persists but rollout frictions remain.",
                symbols: ["NVDA"],
                tags: ["ai"],
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ],
        externalEvidenceItems: [
            .init(
                sourceID: "stanford-ai-index-report",
                title: "AI Index",
                summary: "Adoption is rising, but power bottlenecks remain.",
                snippet: "Power bottlenecks remain.",
                url: "https://aiindex.stanford.edu/report/",
                observedAt: Date(timeIntervalSince1970: 1_700_000_100),
                provenanceNote: "charter_preferred_source:stanford_ai_index_report",
                baselineRelation: "stronger_confirmation",
                incrementalValueSummary: "Confirms the app-news baseline with stronger sourcing and limited extra detail."
            )
        ],
        externalEvidenceIssues: ["category=http_status host=aiindex.stanford.edu status=503 detail=non_success_status"],
        selectedSkills: selectedSkills
    )
}

private func makeResearchPlanningRequest(
    runtimeIdentifier: String,
    reasoningMode: AnalystRuntimeReasoningMode? = nil
) -> AnalystResearchPlanningRequest {
    AnalystResearchPlanningRequest(
        runtimeIdentifier: runtimeIdentifier,
        reasoningMode: reasoningMode,
        charterTitle: "Technology Analyst",
        charterSummary: "Research durable technology catalysts.",
        charterDocumentBodyExcerpt: "# Analyst Charter\nUse reputable public web sources unless restricted.",
        taskTitle: "META 2026 technology catalyst research",
        taskDescription: "Research earnings timing, developer conference timing, expected technology product releases, forward P/E, cash/liquidity, and whether META may make meaningful technology-platform progress in 2026.",
        taskIntent: "general_research",
        pmTaskingBriefBody: "Use full charter-governed public internet research outside the app-news baseline.",
        requiredResearchQuestions: [
            "next earnings timing",
            "developer conference timing",
            "expected technology product releases",
            "forward P/E",
            "cash/liquidity",
            "whether META may make meaningful technology-platform progress in 2026"
        ],
        newsItems: [],
        sourcePolicySummary: "Public/domain web research: enabled by default unless an explicit restriction applies.\nRestricted sources: none",
        scopedOpenQuestions: [],
        researchHints: [],
        suggestedPublicSites: []
    )
}

private func makeSelectedAnalystSkillContext(
    requirement: AgentSkillReferenceRequirement = .recommended
) -> AgentSkillContextItem {
    AgentSkillContextItem(
        skillId: AgentSkillSeed.disconfirmingEvidenceChecklistID,
        title: "Disconfirming Evidence Checklist",
        summary: "Identify what would weaken the thesis.",
        documentBody: "# Disconfirming Evidence Checklist\n\nUse the full method body to test opposing evidence.",
        category: .researchMethod,
        requirement: requirement,
        rationale: "Technology reports should pressure-test single-sided AI thesis claims.",
        availability: .active,
        skillUpdatedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}
