import Foundation

public enum PMConversationRuntimePathKind: String, Codable, Sendable, CaseIterable {
    case modelBacked = "model_backed"
    case degradedFallback = "degraded_fallback"
}

public enum PMConversationVisibleReplySource: String, Codable, Sendable, CaseIterable {
    case modelReply = "model_reply"
    case deterministicFallback = "deterministic_fallback"
}

public enum PMConversationFallbackTriggerKind: String, Codable, Sendable, CaseIterable {
    case credentialUnavailable = "credential_unavailable"
    case credentialEmpty = "credential_empty"
    case invalidSchema = "invalid_schema"
    case authFailure = "auth_failure"
    case networkFailure = "network_failure"
    case timeout = "timeout"
    case rateLimitOrQuota = "rate_limit_or_quota"
    case invalidRuntime = "invalid_runtime"
    case requestTooLarge = "request_too_large"
    case providerUnavailable = "provider_unavailable"
    case refusal = "refusal"
    case malformedResponse = "malformed_response"
    case internalFailure = "internal_failure"
}

public enum PMConversationActionPlanSource: String, Codable, Sendable, CaseIterable {
    case modelActionPlan = "model_action_plan"
    case modelResolution = "model_resolution"
    case minimalAnswerOnly = "minimal_answer_only"
    // Historical trace values retained for decoding legacy persisted PM messages only.
    case deterministicGovernedEscalation = "deterministic_governed_escalation"
    case deterministicApprovalBridge = "deterministic_approval_bridge"
    case deterministicFallbackResolution = "deterministic_fallback_resolution"
}

public struct PMConversationTrace: Codable, Sendable, Equatable {
    public var pathKind: PMConversationRuntimePathKind
    public var visibleReplySource: PMConversationVisibleReplySource
    public var actionPlanSource: PMConversationActionPlanSource?
    public var structuredOutputSchemaName: String?
    public var structuredOutputSchemaLocallyValidated: Bool?
    public var usedLatestOwnerWorkingPortfolioGrounding: Bool
    public var usedWorkingPortfolioHistoryGrounding: Bool
    public var usedAnalystArtifactGrounding: Bool
    public var usedDetailedHistoryGrounding: Bool
    public var usedRecoveredContextGrounding: Bool
    public var suppressedSyntheticHistoryRecaps: Bool
    public var modelSynthesisAttempted: Bool
    public var modelProducedUsableReply: Bool
    public var visibleReplyModifiedAfterSynthesis: Bool
    public var modelAttemptCount: Int
    public var requestCharacterCount: Int?
    public var requestCompactionLevel: String?
    public var promptBudgetTrace: PMConversationPromptBudgetTrace?
    public var promptProfileTraces: [PMConversationPromptProfileTrace]
    public var providerReturnedContent: Bool?
    public var providerResponseAccepted: Bool?
    public var providerResponseIssueSummary: String?
    public var fallbackTrigger: PMConversationFallbackTriggerKind?
    public var fallbackTriggerWasAllowedRuntimeFailure: Bool?
    public var degradedReason: String?

    public init(
        pathKind: PMConversationRuntimePathKind,
        visibleReplySource: PMConversationVisibleReplySource,
        actionPlanSource: PMConversationActionPlanSource? = nil,
        structuredOutputSchemaName: String? = nil,
        structuredOutputSchemaLocallyValidated: Bool? = nil,
        usedLatestOwnerWorkingPortfolioGrounding: Bool = false,
        usedWorkingPortfolioHistoryGrounding: Bool = false,
        usedAnalystArtifactGrounding: Bool = false,
        usedDetailedHistoryGrounding: Bool = false,
        usedRecoveredContextGrounding: Bool = false,
        suppressedSyntheticHistoryRecaps: Bool = false,
        modelSynthesisAttempted: Bool = false,
        modelProducedUsableReply: Bool = false,
        visibleReplyModifiedAfterSynthesis: Bool = false,
        modelAttemptCount: Int = 0,
        requestCharacterCount: Int? = nil,
        requestCompactionLevel: String? = nil,
        promptBudgetTrace: PMConversationPromptBudgetTrace? = nil,
        promptProfileTraces: [PMConversationPromptProfileTrace] = [],
        providerReturnedContent: Bool? = nil,
        providerResponseAccepted: Bool? = nil,
        providerResponseIssueSummary: String? = nil,
        fallbackTrigger: PMConversationFallbackTriggerKind? = nil,
        fallbackTriggerWasAllowedRuntimeFailure: Bool? = nil,
        degradedReason: String? = nil
    ) {
        self.pathKind = pathKind
        self.visibleReplySource = visibleReplySource
        self.actionPlanSource = actionPlanSource
        self.structuredOutputSchemaName = structuredOutputSchemaName
        self.structuredOutputSchemaLocallyValidated = structuredOutputSchemaLocallyValidated
        self.usedLatestOwnerWorkingPortfolioGrounding = usedLatestOwnerWorkingPortfolioGrounding
        self.usedWorkingPortfolioHistoryGrounding = usedWorkingPortfolioHistoryGrounding
        self.usedAnalystArtifactGrounding = usedAnalystArtifactGrounding
        self.usedDetailedHistoryGrounding = usedDetailedHistoryGrounding
        self.usedRecoveredContextGrounding = usedRecoveredContextGrounding
        self.suppressedSyntheticHistoryRecaps = suppressedSyntheticHistoryRecaps
        self.modelSynthesisAttempted = modelSynthesisAttempted
        self.modelProducedUsableReply = modelProducedUsableReply
        self.visibleReplyModifiedAfterSynthesis = visibleReplyModifiedAfterSynthesis
        self.modelAttemptCount = modelAttemptCount
        self.requestCharacterCount = requestCharacterCount
        self.requestCompactionLevel = requestCompactionLevel
        self.promptBudgetTrace = promptBudgetTrace
        self.promptProfileTraces = promptProfileTraces
        self.providerReturnedContent = providerReturnedContent
        self.providerResponseAccepted = providerResponseAccepted
        self.providerResponseIssueSummary = providerResponseIssueSummary
        self.fallbackTrigger = fallbackTrigger
        self.fallbackTriggerWasAllowedRuntimeFailure = fallbackTriggerWasAllowedRuntimeFailure
        self.degradedReason = degradedReason
    }
}

public struct PMConversationPromptProfileTrace: Codable, Sendable, Equatable {
    public var profile: String
    public var totalPromptCharacterCount: Int
    public var fitsPromptBudget: Bool
    public var lanes: [PMConversationPromptLaneTrace]

    public init(
        profile: String,
        totalPromptCharacterCount: Int,
        fitsPromptBudget: Bool,
        lanes: [PMConversationPromptLaneTrace]
    ) {
        self.profile = profile
        self.totalPromptCharacterCount = totalPromptCharacterCount
        self.fitsPromptBudget = fitsPromptBudget
        self.lanes = lanes
    }
}

public struct PMRuntimeProvenance: Codable, Sendable, Equatable {
    public var configuredProviderKind: LLMProviderKind?
    public var configuredCredentialProfileId: String?
    public var configuredRuntimeIdentifier: String
    public var configuredReasoningMode: AnalystRuntimeReasoningMode?
    public var actualProviderKind: LLMProviderKind?
    public var actualCredentialProfileId: String?
    public var actualRuntimeIdentifier: String
    public var actualReasoningMode: AnalystRuntimeReasoningMode?
    public var usedOpenAI: Bool
    public var synthesisStatus: String
    public var synthesisIssueSummary: String?
    public var launchedAt: Date
    public var conversationTrace: PMConversationTrace?

    public init(
        configuredProviderKind: LLMProviderKind? = .openAI,
        configuredCredentialProfileId: String? = LLMCredentialProfile.openAIDefaultProfileID,
        configuredRuntimeIdentifier: String,
        configuredReasoningMode: AnalystRuntimeReasoningMode? = nil,
        actualProviderKind: LLMProviderKind? = .openAI,
        actualCredentialProfileId: String? = LLMCredentialProfile.openAIDefaultProfileID,
        actualRuntimeIdentifier: String,
        actualReasoningMode: AnalystRuntimeReasoningMode? = nil,
        usedOpenAI: Bool,
        synthesisStatus: String,
        synthesisIssueSummary: String? = nil,
        launchedAt: Date,
        conversationTrace: PMConversationTrace? = nil
    ) {
        self.configuredProviderKind = configuredProviderKind
        self.configuredCredentialProfileId = configuredCredentialProfileId
        self.configuredRuntimeIdentifier = configuredRuntimeIdentifier
        self.configuredReasoningMode = configuredReasoningMode
        self.actualProviderKind = actualProviderKind
        self.actualCredentialProfileId = actualCredentialProfileId
        self.actualRuntimeIdentifier = actualRuntimeIdentifier
        self.actualReasoningMode = actualReasoningMode
        self.usedOpenAI = usedOpenAI
        self.synthesisStatus = synthesisStatus
        self.synthesisIssueSummary = synthesisIssueSummary
        self.launchedAt = launchedAt
        self.conversationTrace = conversationTrace
    }
}

public struct PMConversationOpenAISynthesisRequest: Sendable, Equatable {
    public let runtimeIdentifier: String
    public let reasoningMode: AnalystRuntimeReasoningMode?
    public let plannerMode: String
    public let sessionChannel: String
    public let ownerMessageBody: String
    public let strategyObjective: String?
    public let strategyThemes: [String]
    public let currentRiskPosture: String?
    public let reviewEscalationPosture: String?
    public let recentConversationSummary: [String]
    public let confirmedAppTruthSummary: [String]
    public let latestOwnerWorkingPortfolioUpdateSummary: [String]
    public let workingPortfolioDefinitionSummary: [String]
    public let proposedTruthUpdateSummary: [String]
    public let standingCandidateSummary: [String]
    public let analystArtifactSummary: [String]
    public let conversationFragmentSummary: [String]
    public let detailedCommunicationHistorySummary: [String]
    public let activeConversationStateSummary: [String]
    public let recoveredContextSummary: [String]
    public let analystCharterDocumentSummary: [String]
    public let operatingContextSummary: [String]

    public init(
        runtimeIdentifier: String,
        reasoningMode: AnalystRuntimeReasoningMode?,
        plannerMode: String,
        sessionChannel: String,
        ownerMessageBody: String,
        strategyObjective: String? = nil,
        strategyThemes: [String] = [],
        currentRiskPosture: String? = nil,
        reviewEscalationPosture: String? = nil,
        recentConversationSummary: [String] = [],
        confirmedAppTruthSummary: [String] = [],
        latestOwnerWorkingPortfolioUpdateSummary: [String] = [],
        workingPortfolioDefinitionSummary: [String] = [],
        proposedTruthUpdateSummary: [String] = [],
        standingCandidateSummary: [String] = [],
        analystArtifactSummary: [String] = [],
        conversationFragmentSummary: [String] = [],
        detailedCommunicationHistorySummary: [String] = [],
        activeConversationStateSummary: [String] = [],
        recoveredContextSummary: [String] = [],
        analystCharterDocumentSummary: [String] = [],
        operatingContextSummary: [String] = []
    ) {
        self.runtimeIdentifier = runtimeIdentifier
        self.reasoningMode = reasoningMode
        self.plannerMode = plannerMode
        self.sessionChannel = sessionChannel
        self.ownerMessageBody = ownerMessageBody
        self.strategyObjective = strategyObjective
        self.strategyThemes = strategyThemes
        self.currentRiskPosture = currentRiskPosture
        self.reviewEscalationPosture = reviewEscalationPosture
        self.recentConversationSummary = recentConversationSummary
        self.confirmedAppTruthSummary = confirmedAppTruthSummary
        self.latestOwnerWorkingPortfolioUpdateSummary = latestOwnerWorkingPortfolioUpdateSummary
        self.workingPortfolioDefinitionSummary = workingPortfolioDefinitionSummary
        self.proposedTruthUpdateSummary = proposedTruthUpdateSummary
        self.standingCandidateSummary = standingCandidateSummary
        self.analystArtifactSummary = analystArtifactSummary
        self.conversationFragmentSummary = conversationFragmentSummary
        self.detailedCommunicationHistorySummary = detailedCommunicationHistorySummary
        self.activeConversationStateSummary = activeConversationStateSummary
        self.recoveredContextSummary = recoveredContextSummary
        self.analystCharterDocumentSummary = analystCharterDocumentSummary
        self.operatingContextSummary = operatingContextSummary
    }
}

public struct PMConversationPromptLaneTrace: Codable, Sendable, Equatable {
    public var lane: String
    public var itemCount: Int
    public var characterCount: Int
    public var priority: String

    public init(
        lane: String,
        itemCount: Int,
        characterCount: Int,
        priority: String
    ) {
        self.lane = lane
        self.itemCount = itemCount
        self.characterCount = characterCount
        self.priority = priority
    }
}

public struct PMConversationPromptBudgetTrace: Codable, Sendable, Equatable {
    public var totalPromptCharacterCount: Int
    public var promptCharacterBudget: Int
    public var reservedOutputCharacterBudget: Int
    public var totalContextWindowCharacterBudget: Int
    public var lanes: [PMConversationPromptLaneTrace]

    public init(
        totalPromptCharacterCount: Int,
        promptCharacterBudget: Int,
        reservedOutputCharacterBudget: Int,
        totalContextWindowCharacterBudget: Int,
        lanes: [PMConversationPromptLaneTrace]
    ) {
        self.totalPromptCharacterCount = totalPromptCharacterCount
        self.promptCharacterBudget = promptCharacterBudget
        self.reservedOutputCharacterBudget = reservedOutputCharacterBudget
        self.totalContextWindowCharacterBudget = totalContextWindowCharacterBudget
        self.lanes = lanes
    }
}

public struct PMConversationPromptBudgetPolicy: Sendable, Equatable {
    public let totalContextWindowCharacterBudget: Int
    public let reservedOutputCharacterBudget: Int

    public init(
        totalContextWindowCharacterBudget: Int,
        reservedOutputCharacterBudget: Int
    ) {
        self.totalContextWindowCharacterBudget = totalContextWindowCharacterBudget
        self.reservedOutputCharacterBudget = reservedOutputCharacterBudget
    }

    public var promptCharacterBudget: Int {
        max(0, totalContextWindowCharacterBudget - reservedOutputCharacterBudget)
    }

    public static let runtimeDefault = PMConversationPromptBudgetPolicy(
        totalContextWindowCharacterBudget: 24_000,
        reservedOutputCharacterBudget: 6_000
    )

    public static func recommended(
        runtimeIdentifier: String,
        reasoningMode: AnalystRuntimeReasoningMode?
    ) -> PMConversationPromptBudgetPolicy {
        let normalized = runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let elevatedReasoning = reasoningMode == .deliberate

        switch normalized {
        case "gpt-5.4":
            return PMConversationPromptBudgetPolicy(
                totalContextWindowCharacterBudget: 120_000,
                reservedOutputCharacterBudget: elevatedReasoning ? 32_000 : 24_000
            )
        case "gpt-5", "gpt-5.4-mini", "gpt-5.4-nano":
            return PMConversationPromptBudgetPolicy(
                totalContextWindowCharacterBudget: 64_000,
                reservedOutputCharacterBudget: elevatedReasoning ? 24_000 : 18_000
            )
        default:
            return elevatedReasoning
                ? PMConversationPromptBudgetPolicy(
                    totalContextWindowCharacterBudget: 32_000,
                    reservedOutputCharacterBudget: 10_000
                )
                : .runtimeDefault
        }
    }
}

public struct PMConversationOpenAISynthesisOutput: Codable, Sendable, Equatable {
    public var replyBody: String
    public var actionPlan: PMConversationActionPlan?
    public var resolution: PMConversationResolutionState?

    public init(
        replyBody: String,
        actionPlan: PMConversationActionPlan? = nil,
        resolution: PMConversationResolutionState? = nil
    ) {
        self.replyBody = replyBody
        self.actionPlan = actionPlan
        self.resolution = resolution
    }

    func validated() throws -> PMConversationOpenAISynthesisOutput {
        let trimmed = replyBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw PMOpenAISynthesisError.malformedResponse(reason: "missing_reply_body")
        }
        return PMConversationOpenAISynthesisOutput(
            replyBody: trimmed,
            actionPlan: actionPlan,
            resolution: resolution
        )
    }
}

public struct PMStandingReviewOpenAISynthesisRequest: Sendable, Equatable {
    public struct ReportContext: Sendable, Equatable {
        public let title: String
        public let summary: String
        public let headlineView: String
        public let portfolioRelevanceSummary: String
        public let openQuestions: [String]
        public let sections: [String]

        public init(
            title: String,
            summary: String,
            headlineView: String,
            portfolioRelevanceSummary: String,
            openQuestions: [String],
            sections: [String]
        ) {
            self.title = title
            self.summary = summary
            self.headlineView = headlineView
            self.portfolioRelevanceSummary = portfolioRelevanceSummary
            self.openQuestions = openQuestions
            self.sections = sections
        }
    }

    public let runtimeIdentifier: String
    public let reasoningMode: AnalystRuntimeReasoningMode?
    public let strategyObjective: String?
    public let currentRiskPosture: String?
    public let reviewEscalationPosture: String?
    public let noPortfolio: Bool
    public let analystTitles: [String]
    public let attentionItems: [String]
    public let candidateLongs: [String]
    public let candidateShorts: [String]
    public let candidateThemes: [String]
    public let followUpItems: [String]
    public let reports: [ReportContext]

    public init(
        runtimeIdentifier: String,
        reasoningMode: AnalystRuntimeReasoningMode?,
        strategyObjective: String? = nil,
        currentRiskPosture: String? = nil,
        reviewEscalationPosture: String? = nil,
        noPortfolio: Bool,
        analystTitles: [String],
        attentionItems: [String],
        candidateLongs: [String],
        candidateShorts: [String],
        candidateThemes: [String],
        followUpItems: [String],
        reports: [ReportContext]
    ) {
        self.runtimeIdentifier = runtimeIdentifier
        self.reasoningMode = reasoningMode
        self.strategyObjective = strategyObjective
        self.currentRiskPosture = currentRiskPosture
        self.reviewEscalationPosture = reviewEscalationPosture
        self.noPortfolio = noPortfolio
        self.analystTitles = analystTitles
        self.attentionItems = attentionItems
        self.candidateLongs = candidateLongs
        self.candidateShorts = candidateShorts
        self.candidateThemes = candidateThemes
        self.followUpItems = followUpItems
        self.reports = reports
    }
}

public struct PMStandingReviewOpenAISynthesisOutput: Codable, Sendable, Equatable {
    public var disposition: String
    public var summary: String
    public var recommendedAction: String

    public init(
        disposition: String,
        summary: String,
        recommendedAction: String
    ) {
        self.disposition = disposition
        self.summary = summary
        self.recommendedAction = recommendedAction
    }

    func validated() throws -> PMStandingReviewOpenAISynthesisOutput {
        let disposition = disposition.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let recommendedAction = recommendedAction.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = Set([
            "informational_no_action",
            "worth_monitoring",
            "follow_up_analyst_work_warranted",
            "owner_attention_recommended",
            "candidate_ideas_worth_considering"
        ])
        guard allowed.contains(disposition),
              summary.isEmpty == false,
              recommendedAction.isEmpty == false else {
            throw PMOpenAISynthesisError.malformedResponse(reason: "invalid_standing_review_output")
        }
        return PMStandingReviewOpenAISynthesisOutput(
            disposition: disposition,
            summary: summary,
            recommendedAction: recommendedAction
        )
    }
}

public enum PMOpenAISynthesisError: Error, Sendable, Equatable {
    case transport
    case transportDetail(String)
    case invalidSchema(reason: String)
    case httpStatus(Int, responseSummary: String?)
    case invalidResponse
    case refusal
    case malformedResponse(reason: String)
    case providerTransport(provider: LLMProviderKind)
    case providerHTTPStatus(provider: LLMProviderKind, status: Int, responseSummary: String?)
    case providerInvalidResponse(provider: LLMProviderKind)
    case providerMalformedResponse(provider: LLMProviderKind, reason: String)
    case providerUnsupportedCapability(provider: LLMProviderKind, reason: String)

    public var boundedSummary: String {
        switch self {
        case .transport:
            return openAITransportSummary()
        case .transportDetail(let summary):
            return summary.isEmpty ? openAITransportSummary() : summary
        case .invalidSchema(let reason):
            return "openai_invalid_schema \(reason)"
        case .httpStatus(let status, let responseSummary):
            return openAIHTTPStatusSummary(status, detail: responseSummary)
        case .invalidResponse:
            return "openai_invalid_response"
        case .refusal:
            return "openai_refusal"
        case .malformedResponse(let reason):
            return "openai_malformed_response=\(reason)"
        case .providerTransport(let provider):
            return "\(provider.rawValue)_network_error"
        case .providerHTTPStatus(let provider, let status, let responseSummary):
            switch provider {
            case .openAI:
                return openAIHTTPStatusSummary(status, detail: responseSummary)
            case .anthropic:
                return anthropicHTTPStatusSummary(status, detail: responseSummary)
            }
        case .providerInvalidResponse(let provider):
            return "\(provider.rawValue)_invalid_response"
        case .providerMalformedResponse(let provider, let reason):
            return "\(provider.rawValue)_malformed_response=\(reason)"
        case .providerUnsupportedCapability(let provider, let reason):
            return "\(provider.rawValue)_unsupported_capability=\(reason)"
        }
    }

    public var providerReturnedContent: Bool {
        switch self {
        case .transport, .transportDetail, .providerTransport:
            return false
        case .invalidSchema, .providerUnsupportedCapability:
            return false
        case .httpStatus(_, let responseSummary):
            return responseSummary != nil
        case .providerHTTPStatus(_, _, let responseSummary):
            return responseSummary != nil
        case .invalidResponse, .providerInvalidResponse:
            return false
        case .refusal, .malformedResponse, .providerMalformedResponse:
            return true
        }
    }

    public var providerResponseAccepted: Bool {
        false
    }

    public var retryableAfterContextCompaction: Bool {
        switch self {
        case .invalidSchema:
            return false
        case .httpStatus(let status, let responseSummary):
            guard status == 400 || status == 413 else { return false }
            let summary = (responseSummary ?? "").lowercased()
            return summary.contains("context_length")
                || summary.contains("maximum context")
                || summary.contains("too many tokens")
                || summary.contains("input too long")
                || summary.contains("request too large")
                || summary.contains("too_large")
        case .providerHTTPStatus(_, let status, let responseSummary):
            guard status == 400 || status == 413 else { return false }
            let summary = (responseSummary ?? "").lowercased()
            return summary.contains("context_length")
                || summary.contains("maximum context")
                || summary.contains("too many tokens")
                || summary.contains("input too long")
                || summary.contains("request too large")
                || summary.contains("too_large")
                || summary.contains("request_too_large")
        default:
            return false
        }
    }
}

public protocol PMOpenAISynthesisProviding: Sendable {
    func synthesizeConversationReply(
        request: PMConversationOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMConversationOpenAISynthesisOutput

    func synthesizeStandingReview(
        request: PMStandingReviewOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMStandingReviewOpenAISynthesisOutput
}

public struct OpenAIResponsesPMSynthesisProvider: PMOpenAISynthesisProviding {
    private let httpClient: any OpenAIResponsesHTTPClient
    private let endpoint: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        httpClient: any OpenAIResponsesHTTPClient = URLSessionOpenAIResponsesHTTPClient(),
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!
    ) {
        self.httpClient = httpClient
        self.endpoint = endpoint
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func synthesizeConversationReply(
        request: PMConversationOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMConversationOpenAISynthesisOutput {
        let body = makeRequestBody(
            model: request.runtimeIdentifier,
            reasoningMode: request.reasoningMode,
            schemaName: "pm_conversation_reply",
            schema: conversationSchema(),
            prompt: conversationPromptText(from: request),
            instructions: """
            You are the PM inside an app-owned control plane. Produce a bounded owner-facing reply grounded only in the provided app context. Do not invent execution, approval, or trade authority. Do not imply external research or portfolio facts not present in the prompt. Return only valid JSON matching the required schema.
            """
        )
        return try await synthesize(
            requestBody: body,
            apiKey: apiKey,
            decodeAs: PMConversationOpenAISynthesisOutput.self
        ).validated()
    }

    public func synthesizeStandingReview(
        request: PMStandingReviewOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMStandingReviewOpenAISynthesisOutput {
        let body = makeRequestBody(
            model: request.runtimeIdentifier,
            reasoningMode: request.reasoningMode,
            schemaName: "pm_standing_review",
            schema: standingReviewSchema(),
            prompt: standingReviewPromptText(from: request),
            instructions: """
            You are the PM reviewing standing analyst output inside an app-owned control plane. Use the supplied analyst summaries, strategy posture, and risk posture to form one bounded PM conclusion. Keep governance boundaries intact: no direct execution authority, no approval bypass, and no safety-state changes. Return only valid JSON matching the required schema.
            """
        )
        return try await synthesize(
            requestBody: body,
            apiKey: apiKey,
            decodeAs: PMStandingReviewOpenAISynthesisOutput.self
        ).validated()
    }

    private func synthesize<T: Decodable>(
        requestBody: OpenAIResponsesStructuredRequestBody,
        apiKey: String,
        decodeAs: T.Type
    ) async throws -> T {
        do {
            try validateOpenAIResponsesStructuredSchema(requestBody.text.format.schema)
        } catch let error as OpenAIResponsesStructuredSchemaValidationError {
            throw PMOpenAISynthesisError.invalidSchema(
                reason: "schema_name=\(requestBody.text.format.name) \(error.boundedSummary)"
            )
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = OpenAIResponsesStructuredRequestBody.longRunningRequestTimeout
        urlRequest.httpBody = try encoder.encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: urlRequest)
        } catch {
            throw PMOpenAISynthesisError.transportDetail(openAITransportSummary(for: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw PMOpenAISynthesisError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PMOpenAISynthesisError.httpStatus(
                http.statusCode,
                responseSummary: openAIResponsesHTTPErrorSummary(from: data)
            )
        }
        let envelope = try decoder.decode(OpenAIResponsesStructuredEnvelope.self, from: data)
        if openAIResponsesContainsRefusal(in: envelope) {
            throw PMOpenAISynthesisError.refusal
        }
        guard let structuredText = openAIResponsesExtractStructuredText(from: envelope) else {
            throw PMOpenAISynthesisError.malformedResponse(reason: "missing_output_text")
        }
        let normalizedText = openAIResponsesStripJSONCodeFences(from: structuredText)
        return try decoder.decode(T.self, from: Data(normalizedText.utf8))
    }

    private func makeRequestBody(
        model: String,
        reasoningMode: AnalystRuntimeReasoningMode?,
        schemaName: String,
        schema: JSONValue,
        prompt: String,
        instructions: String
    ) -> OpenAIResponsesStructuredRequestBody {
        OpenAIResponsesStructuredRequestBody(
            model: model,
            store: false,
            instructions: instructions,
            input: prompt,
            reasoning: makeReasoningRequest(for: model, reasoningMode: reasoningMode),
            text: .init(
                format: .init(
                    type: "json_schema",
                    name: schemaName,
                    strict: true,
                    schema: openAIResponsesStrictCompatibleSchema(schema)
                )
            )
        )
    }

    private func makeReasoningRequest(
        for runtimeIdentifier: String,
        reasoningMode: AnalystRuntimeReasoningMode?
    ) -> OpenAIResponsesStructuredRequestBody.ReasoningRequest? {
        guard runtimeIdentifier.lowercased().contains("gpt-5"),
              let reasoningMode else {
            return nil
        }
        return OpenAIResponsesStructuredRequestBody.ReasoningRequest(
            effort: reasoningMode == .deliberate ? "medium" : "low"
        )
    }

    private func conversationPromptText(from request: PMConversationOpenAISynthesisRequest) -> String {
        makePMConversationPromptText(from: request)
    }

    private func standingReviewPromptText(from request: PMStandingReviewOpenAISynthesisRequest) -> String {
        makePMStandingReviewPromptText(from: request)
    }

    private func conversationSchema() -> JSONValue {
        pmConversationSchema()
    }

    private func standingReviewSchema() -> JSONValue {
        pmStandingReviewSchema()
    }
}

private struct PMConversationPromptRenderedLane {
    let lane: String
    let title: String
    let priority: String
    let itemCount: Int
    let body: String
}

private struct PMConversationPromptComposition {
    let promptText: String
    let laneTraces: [PMConversationPromptLaneTrace]
}

private func makePMConversationPromptRenderedLane(
    lane: String,
    title: String,
    values: [String],
    itemLimit: Int,
    itemCharacterLimit: Int,
    priority: String
) -> PMConversationPromptRenderedLane {
    let trimmedValues = Array(values.prefix(itemLimit)).map {
        "- \(openAIResponsesTrimmed($0, limit: itemCharacterLimit))"
    }
    return PMConversationPromptRenderedLane(
        lane: lane,
        title: title,
        priority: priority,
        itemCount: trimmedValues.count,
        body: trimmedValues.isEmpty ? "- none" : trimmedValues.joined(separator: "\n")
    )
}

private func makePMConversationPromptComposition(
    from request: PMConversationOpenAISynthesisRequest
) -> PMConversationPromptComposition {
        let historyHeavyIntent = request.detailedCommunicationHistorySummary.isEmpty == false
        let strategyThemes = request.strategyThemes.isEmpty ? "(none recorded)" : request.strategyThemes.prefix(6).joined(separator: ", ")
        let renderedLanes: [PMConversationPromptRenderedLane] = [
            makePMConversationPromptRenderedLane(
                lane: "analyst_artifacts",
                title: "Available analyst report artifacts and full analyst report document context for this ask",
                values: request.analystArtifactSummary,
                itemLimit: 28,
                itemCharacterLimit: 240_000,
                priority: "highest_current_app_report_truth"
            ),
            makePMConversationPromptRenderedLane(
                lane: "recent_conversation",
                title: "Exact recent conversation text",
                values: request.recentConversationSummary,
                itemLimit: historyHeavyIntent ? 18 : 24,
                itemCharacterLimit: historyHeavyIntent ? 320 : 260,
                priority: "highest"
            ),
            makePMConversationPromptRenderedLane(
                lane: "confirmed_app_truth",
                title: "Confirmed app truth",
                values: request.confirmedAppTruthSummary,
                itemLimit: 18,
                itemCharacterLimit: 420,
                priority: "high"
            ),
            makePMConversationPromptRenderedLane(
                lane: "latest_owner_working_portfolio",
                title: "Reserved current-turn working portfolio grounding",
                values: request.latestOwnerWorkingPortfolioUpdateSummary,
                itemLimit: 2,
                itemCharacterLimit: 320,
                priority: "highest"
            ),
            makePMConversationPromptRenderedLane(
                lane: "working_portfolio_definition",
                title: "Latest conversation-owned working portfolio definition (separate from confirmed holdings)",
                values: request.workingPortfolioDefinitionSummary,
                itemLimit: 2,
                itemCharacterLimit: 280,
                priority: "high"
            ),
            makePMConversationPromptRenderedLane(
                lane: "proposed_truth_updates",
                title: "User-confirmed proposed updates",
                values: request.proposedTruthUpdateSummary,
                itemLimit: 2,
                itemCharacterLimit: 260,
                priority: "compact_first"
            ),
            makePMConversationPromptRenderedLane(
                lane: "standing_candidates",
                title: "Standing-review candidate ideas (not current holdings)",
                values: request.standingCandidateSummary,
                itemLimit: 3,
                itemCharacterLimit: 220,
                priority: "compact_first"
            ),
            makePMConversationPromptRenderedLane(
                lane: "conversation_fragments",
                title: "Conversation fragments and recovered continuity (not app truth by themselves)",
                values: request.conversationFragmentSummary,
                itemLimit: 2,
                itemCharacterLimit: 220,
                priority: "compact_first"
            ),
            makePMConversationPromptRenderedLane(
                lane: "detailed_history",
                title: "Detailed communication-log bodies relevant to this ask",
                values: request.detailedCommunicationHistorySummary,
                itemLimit: historyHeavyIntent ? 3 : 2,
                itemCharacterLimit: historyHeavyIntent ? 900 : 600,
                priority: "targeted"
            ),
            makePMConversationPromptRenderedLane(
                lane: "active_conversation_state",
                title: "Active conversation state and unresolved PM asks",
                values: request.activeConversationStateSummary,
                itemLimit: 3,
                itemCharacterLimit: 240,
                priority: "high"
            ),
            makePMConversationPromptRenderedLane(
                lane: "recovered_context",
                title: "Recovered app-owned memory and log context",
                values: request.recoveredContextSummary,
                itemLimit: 3,
                itemCharacterLimit: 320,
                priority: "compact_first"
            ),
            makePMConversationPromptRenderedLane(
                lane: "analyst_charter_documents",
                title: "Relevant current analyst charter documents (app-owned charter truth)",
                values: request.analystCharterDocumentSummary,
                itemLimit: 2,
                itemCharacterLimit: 1_800,
                priority: "targeted_high"
            ),
            makePMConversationPromptRenderedLane(
                lane: "operating_context",
                title: "Current app-owned operating context",
                values: request.operatingContextSummary,
                itemLimit: 6,
                itemCharacterLimit: 180,
                priority: "conditional"
            )
        ]

        let laneTraces = renderedLanes.map { lane in
            PMConversationPromptLaneTrace(
                lane: lane.lane,
                itemCount: lane.itemCount,
                characterCount: lane.body.count,
                priority: lane.priority
            )
        }

        let promptText = """
        Produce one substantive PM reply to the owner.

        Runtime requested: \(request.runtimeIdentifier)
        Reasoning mode: \(request.reasoningMode?.rawValue ?? "standard")
        Planner mode: \(request.plannerMode)
        Latest ingress channel (routing metadata only): \(request.sessionChannel)

        Owner message:
        \(openAIResponsesTrimmed(request.ownerMessageBody, limit: 1_200))

        Strategy objective:
        \(request.strategyObjective.map { openAIResponsesTrimmed($0, limit: 360) } ?? "(none recorded)")

        Strategy themes:
        \(strategyThemes)

        Current risk posture:
        \(request.currentRiskPosture.map { openAIResponsesTrimmed($0, limit: 320) } ?? "(none recorded)")

        PM review posture:
        \(request.reviewEscalationPosture.map { openAIResponsesTrimmed($0, limit: 320) } ?? "(none recorded)")

        \(renderedLanes.map { "\($0.title):\n\($0.body)" }.joined(separator: "\n\n"))

        Hidden bounded action catalog:
        - `answer_only`: reply naturally with no hidden side effect beyond the reply itself.
        - `ask_follow_up`: ask one targeted follow-up question when genuine ambiguity remains.
        - `update_conversation_working_truth`: update conversation-owned working truth such as the latest proposed paper portfolio or current operating assumption.
        - `update_watchlist_symbols`: add or remove explicit symbols from the app-owned watchlist / Portfolio Watch selection through the safe app path.
        - `upsert_pm_instruction`: create or update one bounded PM instruction that remains separate from holdings or execution truth.
        - `upsert_pm_mandate`: create or update one bounded PM mandate when the owner is clearly updating PM operating direction.
        - `upsert_pm_notebook_entry`: record one bounded notebook entry for PM memory or traceability.
        - `launch_ad_hoc_analyst_delegation`: create and launch one bounded analyst delegation through the existing external worker path only when a valid app-owned analyst/charter target is selected.
        - `update_analyst_charter`: update one bounded analyst charter through the app-owned charter store.
        - `update_runtime_setting`: update one bounded PM or analyst runtime setting through the existing app-owned settings stores.
        - `create_pm_decision`: create one bounded PM decision artifact.
        - `create_pm_approval_request`: create one bounded PM approval request artifact that still preserves approval governance.
        - `approve_pm_approval_request`: record the owner's explicit approval on an existing PM approval request before any later governed routing step.
        - `create_or_update_proposal`: create or update one bounded governed proposal draft only when the prompt provides enough grounded detail for the existing proposal path.
        - `route_governed_execution_next_step`: route an already-governed next step only through the existing approval/proposal/execution path, including the first-class paper-portfolio establishment order-submission path when deterministic app-owned preconditions are satisfied.

        Reply rules:
        - Answer the latest owner ask directly.
        - Keep the tone concise, professional, and PM-like.
        - If `Planner mode` is `analyst_follow_through_synthesis`, synthesize the completed analyst result in your own PM judgment. Treat the analyst memo, question coverage, and source summary as app-owned context for your reasoning, not as a script or content to dump back. Decide what matters for the owner, write a compact executive brief, include only the key answers/gaps/source caveats you judge important, and point to PM Inbox / Recent Analyst Activity for the full report. Use `answer_only`; do not create new workflow actions from a completed follow-through synthesis.
        - You are the owner-facing interpreter of normal PM/User meaning. The app will not keyword-match the owner's raw wording to decide approval, execution, refusal, hold-off, or working-truth updates for you.
        - If owner intent is ambiguous, choose `ask_follow_up` and ask one concise clarification instead of guessing.
        - If owner intent is clear, choose the hidden bounded actions that represent that meaning; deterministic app code will validate, apply, govern, or block those actions after you emit them.
        - When the ask is about research, strategy, or risk posture, provide real reasoning rather than a canned acknowledgment.
        - Treat the latest owner turn as the highest-priority conversational signal for the current reply.
        - When the owner refers to prior discussion, notebook memory, or communication logs, use the recovered app-owned context if it is relevant.
        - Treat Telegram and in-app owner messages as one PM relationship when they refer to the same owner conversation. Channel is routing metadata, not a separate source of conversational truth by itself.
        - Use active recent-conversation context first for ordinary conversation continuity. For analyst report, latest-reviewed report, detailed-supporting-section, material-article, signal, support-list, or candidate-detail asks, read the current full analyst report document context before prior chat recaps or prior PM replies.
        - If a `Specific communication entry body window` is provided, treat that exact PM/User entry pair or exact bounded thread as the primary source for the answer.
        - When a communication-history question includes detailed communication-log bodies, do not answer only from continuity summaries if the log bodies are the more relevant source.
        - When a `Specific communication entry body window` is present, do not blend unrelated conversation fragments, standing-review ideas, or later recap messages into the answer unless the owner explicitly asks for that merge.
        - If both a later PM summary-style reply and an earlier more specific PM/User message body are present, prefer the more specific message body.
        - If a prior PM reply includes old renderer-style scaffolding, extract the substantive portfolio, decision, or correction content and keep that scaffolding out of the new visible answer.
        - Do not claim you lack notebook or communication-log access when recovered app-owned context is already provided.
        - Interpret any current-turn working portfolio update directly from the Owner message and provided context. If the owner is actually updating conversation-owned working truth, represent that with `update_conversation_working_truth` and the `resolution` operating-truth fields.
        - Do not let older recovered portfolio reconstructions, continuity summaries, or recap messages override a newer owner correction that you have interpreted from the latest turn.
        - If the latest owner turn supplies a current proposed portfolio and asks a follow-up analytical question, first treat that list as current working context in your reply, then answer the follow-up question actually asked; include the working-truth action/resolution only when the owner is updating that state.
        - Treat `Available analyst report artifacts and full analyst report document context for this ask` as app-owned report reading material from analyst-created standing reports, linked analyst memos, linked evidence, PM review/treatment records, and analyst report lane indexes. The app is not composing the answer for you; it is giving you durable analyst report artifacts to read. When the owner references a report, latest reviewed report, detailed supporting section, section title, candidate content, material articles, support lists, or short/long candidate sections, read the `FULL_ANALYST_REPORT_DOCUMENTS`, `FULL_ANALYST_REPORT_DOCUMENT`, `FULL_REPORT_LINKED_MEMO_AND_EVIDENCE`, and `FULL_REPORT_SECTION` entries before relying on summary-only recaps or recent conversation. Prior PM replies may be stale; do not let an older PM answer override current report detail.
        - If `FULL_REPORT_LINKED_MEMO_AND_EVIDENCE` includes a linked analyst memo or evidence bundle, treat that as full analyst report body available to you. Do not describe the report as missing, merely skeletal, not deep, summary-only, or unavailable just because the standing-report section shell is sparse or scaffolded. State any actual source limitations precisely, but answer from the full memo/evidence content that is present.
        - For asks like "what material articles or signals did it contain?", "can you see the detailed supporting section?", or "what were the short candidates?", answer from concrete fields in `FULL_REPORT_LINKED_MEMO_AND_EVIDENCE` and `FULL_REPORT_SECTION` first. Name the actual report title/timestamp and the concrete material/support/detail entries you can see. If those fields are absent, say exactly which full-report fields are missing instead of giving a generic summary.
        - Use analyst report dates exactly as provided. Do not invent reporting windows, date ranges, review times, or report titles. If a `Report title to use` or `Reporting window to use` field is present, copy that meaning exactly; if it is missing or empty, do not fabricate one.
        - Treat `FULL_REPORT_PM_REVIEW_TREATMENT_METADATA` as PM review metadata only. It can explain PM disposition, but it must not erase article titles, signals, candidate lists, or report details visible in the linked analyst memo/evidence and report sections.
        - If a full analyst report says the PM treatment is monitor-only, no further owner action, or not portfolio-changing, do not let that treatment erase concrete material/support entries in the same report. For material-article/signal asks, distinguish the report's concrete listed articles/signals from the PM's no-action or monitor-only conclusion.
        - Treat analyst report lane indexes as app-owned retrieval context, not deterministic user-intent classification. Use LLM reasoning over the owner's latest message and the lane index to choose the relevant analyst lane or lanes. If the owner names or clearly implies a lane, answer from that lane's reviewed/report artifact when available, or say no matching artifact exists for that lane; do not substitute another analyst as the answer to a named-lane request.
        - Owner wording such as "latest from our Recent News Analyst" or "what did the Recent News Analyst say" should be treated as a request to read that analyst lane's latest app-owned report artifact when one is provided, even if the owner did not use the exact phrase "report you reviewed."
        - Distinguish summary-only evidence from full report detail when both matter. If a summary omits short candidates but a retrieved detail section lists them, say that plainly.
        - If the owner uses cross-channel or adjacent-session wording such as "these positions" or "the short side", resolve that naturally against the current working context and the supplied recent analyst artifacts rather than acting as if Telegram and the app are separate PM relationships.
        - If the available analyst artifacts are partial or insufficient, say that plainly in natural PM language and answer from the best grounded subset instead of repeating portfolio restatement or recap text.
        - Treat confirmed app truth as the highest-priority source for holdings, portfolio state, watchlist state, and stored operating truth.
        - For owner asks about "signals", "new signals", "research alerts", or signal actionability, answer from confirmed app signal truth when provided. Distinguish owner-review/proposal-candidate signals from FYI, monitor-only, PM-review, notify-only, neutral, or low-confidence signals. Do not infer trades or owner decisions from notify-only signals, and explain acknowledge/archive as cleanup of active surfaces while preserving traceability.
        - Treat Portfolio Intelligence inside confirmed app truth as the current app-owned portfolio risk snapshot. Use its Paper versus Live labels, exposure metrics, holdings, shorts, order counts, and data-quality flags when the owner asks about current portfolio state or risk.
        - Treat Portfolio Watch live-data truth inside confirmed app truth as the current owner-facing live-pricing/readiness state. For Portfolio Watch, paper-portfolio, app-status, PM-desk, or data-quality-caveat questions, mention requested vs active subscriptions, usable Store prices, waiting-for-first-update symbols, and last Store quote/trade/bar receipt when those facts are provided.
        - Do not treat subscribed or active market-data subscriptions as proof of usable prices. If Portfolio Watch says no Store market-data event has arrived or selected cards are waiting for first update, state that caveat plainly alongside holdings/exposure.
        - Treat Live execution local-auth protection inside confirmed app truth as a final local macOS safety gate. When enabled, this Mac requires Touch ID or the Mac password before Live NEW/REPLACE order submission; Telegram approval, PM approval, proposal approval, live arming, and kill-switch state cannot bypass it. Paper trading is unaffected, and CANCEL remains available for risk reduction.
        - Telegram is transport only, and Command Center PM conversation is still not a final order gate. A direct Live order instruction through Telegram or Command Center may create a bounded in-app PM approval/review item, ask for missing details, or report an exact blocker, but it must not be treated as final Live approval or order submission.
        - For a new direct Live order instruction, require enough owner-provided detail for a reviewable Alpaca order instruction: symbol, side, quantity or notional, order type, and time-in-force. Supported direct-review order types are market or limit; a limit order also requires a positive limit price. Equity market/limit reviews can use DAY or GTC when the owner specifies them, and owner wording like "opened for today" or "for today" means DAY. If any required field is missing or ambiguous, use `ask_follow_up` and do not claim in-app approval or Touch ID is waiting.
        - If the owner gives a notional equity instruction such as "$10,000 to the nearest share", preserve that as `liveOrderNotionalAmount` plus the order type/time-in-force instead of inventing a share count. The app-owned route will convert notional market orders to nearest whole shares only if Store has a current usable symbol price; otherwise it must surface a price blocker after owner approval. If the owner gives an exact share quantity, populate `liveOrderQuantity`.
        - If the Live order instruction is complete enough to review but no existing governed proposal/order artifact is linked, create a `create_pm_decision` plus `create_pm_approval_request` with `requestType` = `live_order_review`. On the `create_pm_approval_request` action, populate the machine-readable Live order fields: `liveOrderSymbol`, `liveOrderSide`, `liveOrderType`, `liveOrderTimeInForce`, and either `liveOrderQuantity` or `liveOrderNotionalAmount`; use `liveOrderLimitPrice` for limit orders. The visible reply may say the review item is in Command Center > Your Decisions, but it must not say the order is submitted or that Touch ID/Mac password is currently waiting.
        - Do not use `approve_pm_approval_request` or `route_governed_execution_next_step` for a brand-new direct Live order instruction through Telegram or Command Center unless there is an existing exact pending app-owned approval request in context and the owner's latest turn is explicitly responding to that request. The app-owned route remains separate from conversation transport.
        - Do not drop short positions when discussing portfolio risk. If Portfolio Intelligence lists shorts, name the short sleeve and use the provided signed market value / absolute weight / short exposure truth.
        - Do not invent alpha, beta, Sharpe, Sortino, volatility, drawdown, tracking error, time-weighted return, attribution, or benchmark-relative numbers. If advanced metric readiness says those metrics need history, benchmark, risk-free-rate, cash-flow, or observation inputs, explain that limitation plainly and use available foundational metrics instead.
        - Treat confirmed system readiness as app-owned operational truth. Do not imply Zeroandzero is a generic 24/7 cloud daemon; active monitoring requires this Mac to be awake, online, and the app running, with recovery/reconciliation after wake or relaunch.
        - If the owner asks whether the system monitored overnight, through sleep, or while the laptop was closed, answer from confirmed readiness truth. Distinguish active, recovering, degraded, paused-by-host, and needs-attention states in ordinary language.
        - If readiness blockers are provided, name the concrete blocker instead of saying the app was simply waiting in the background.
        - If the owner asks where paper-portfolio establishment or execution stands, answer from the confirmed paper-establishment execution lifecycle first. Do not rely only on absence of orders/holdings when app truth includes approval, pending retry, missing prices, or a missing execution-state blocker.
        - If the owner asks for the latest initial paper portfolio or working portfolio structure, answer from the latest conversation-owned working portfolio definition when one is provided, even if it came from conversation-state truth rather than a separately promoted durable instruction.
        - Treat the latest explicit user correction to a conversation-owned working portfolio or operating assumption as the current version unless real ambiguity remains.
        - Treat user-confirmed proposed updates as newer than older conflicting conversation fragments, and aggressively supersede older conversation-owned working assumptions when the owner has clearly updated them.
        - Treat standing-review candidate ideas as candidate/watchlist context only, never as confirmed holdings or portfolio truth unless confirmed app truth says so.
        - Treat conversation fragments and continuity excerpts as context only, not as validated app truth.
        - Treat active conversation state as first-class context for the current owner conversation, including the PM's own recent replies and any still-unresolved PM asks or confirmations.
        - If the latest owner turn is a clear yes/no answer to a recent PM confirmation question, bind it to that question instead of acting like the thread was lost.
        - If confirmed app truth is absent or incomplete, do not let that crowd out the natural answer. Answer from the conversation-owned working definition first and only add a brief plain-language qualifier if it materially helps.
        - Treat `Relevant current analyst charter documents` as the current app-owned AnalystCharter truth for the named charter. PM instructions, notebook entries, conversation memories, and prior PM claims may describe requested charter changes, but they are not proof that the canonical charter body changed.
        - If the owner asks whether a charter contains a rule, answer from the provided current charter body/excerpt and explicit charter-presence flags. Do not infer implementation from an active PM instruction alone.
        - Always produce one hidden bounded `actionPlan` that matches the reply.
        - Keep the hidden `actionPlan` separate from the visible reply body.
        - Use the smallest set of actions needed. Prefer `answer_only` when no state or workflow change is needed.
        - Use `ask_follow_up` only when genuine ambiguity remains after reading the provided conversation and app context.
        - Do not assume the app will repair a missing consequential action from the owner's raw wording. If approval, refusal, execution routing, or a working-truth update is intended, put that intent in the structured `actionPlan` and `resolution`.
        - If the owner asks you to add or remove symbols from the watchlist or Portfolio Watch list and the symbols are explicit or recoverable from provided app-owned context, use `update_watchlist_symbols` with `watchlistOperation` and `watchlistSymbols`. Do not visibly promise a watchlist change unless you emit that action.
        - If the owner asks you to modify an analyst charter and the target charter is clear from app-owned context, use `update_analyst_charter` with bounded update text. Do not visibly promise a charter change unless you emit that action.
        - If the owner explicitly asks you to have, ask, send, or put an analyst on a research/review task, and a standing/ad hoc analyst route broadly fits, use `launch_ad_hoc_analyst_delegation` with the exact app-owned charter id. Do not answer with "I'll put this to the analyst" while emitting `answer_only`.
        - Existing analyst memos, findings, standing reports, and prior follow-through messages are context for a fresh analyst-tasking request, not substitutes for it. Use `answer_only` from prior artifacts only when the owner asks for status, readback, explanation, or prior results; do not treat old artifacts as completion of a new "have an analyst research..." instruction.
        - If the owner asks about a possible portfolio addition, removal, or thesis change and the current context suggests fresh analyst evidence would materially help, you may choose `launch_ad_hoc_analyst_delegation` and tell the owner naturally that you are starting ad hoc analyst research.
        - When choosing `launch_ad_hoc_analyst_delegation` or `update_analyst_charter`, populate `charterId` with the exact durable charter id from `Current app-owned operating context`, not just the human-readable title.
        - Do not promise a lookup, ad hoc research delegation, or analyst work unless your hidden action plan selects an actual app-owned analyst/charter id. If at least one standing analyst broadly fits the domain, choose the closest valid analyst lane rather than asking for a bespoke route. Use `ask_follow_up` only when several plausible analyst targets are materially ambiguous or none fits at all, and say no analyst task has launched yet.
        - Analyst research breadth is governed by the selected Analyst Charter's source restrictions, not by hidden topical routes or bespoke source workflows. Once you select a valid analyst/charter target, do not further narrow analyst research activity except to honor that charter, the owner's current task instructions, and hard app governance.
        - Analysts may use ordinary domain-relevant public sources for discovery, corroboration, context, and primary-source pursuit unless the selected charter/source policy, owner/task wording, or hard app governance expressly restricts the source set.
        - Primary/official sources are preferred but not exclusive unless the owner explicitly asks for official-only or primary-only research, or the selected charter itself restricts the work. Reputable secondary/domain sources may be requested for discovery, corroboration, and context by default, with clear source-tier labeling.
        - For SEC filer identification, 13F holdings extraction, asset-manager holdings review, or similar public research, pick the closest valid analyst lane rather than requiring a bespoke 13F route. If Financials Analyst is available, it is normally appropriate for asset-manager / filings work; for other domains, choose the analyst whose charter best covers the domain and let that charter's source restrictions govern the research. If the hidden action cannot resolve an actual app-owned analyst/charter id, say no analyst task has launched yet and ask the owner which existing analyst/charter should handle it; do not describe that as a research-capability limit.
        - Do not offer to "proceed" by inventing a new analyst identity when the app has not provided one. Conversation wording can request analyst work, but the hidden action still needs an exact app-owned charterId.
        - When the owner asks an analyst to use or apply named Agent Skills, choose `launch_ad_hoc_analyst_delegation` when analyst work is requested and populate `selectedSkillReferences` with exact active Agent Skill ids from `AGENT_SKILLS_LIBRARY_INDEX`, the desired requirement (`available`, `recommended`, or `required`), and a short rationale. This is task-specific and must not mutate Analyst Charters unless the owner explicitly asks for a charter edit.
        - Do not invent skill ids or skill bodies. If a requested skill is not in the active library index, ask a follow-up or explain the blocker rather than routing a fake skill.
        - Treat selected skills as methodology guidance only; selected skills do not grant source access, tool access, proposal authority, approval authority, execution authority, or trading authority.
        - Treat analyst confidence scores and low-confidence findings as evidence for PM judgment, uncertainty framing, and possible follow-up. They are not deterministic blockers by themselves; do not suppress a PM answer or recommendation solely because confidence is low.
        - Use `create_or_update_proposal` when a bounded governed proposal draft or revision is the best next step.
        - When creating a new bounded single-name paper proposal, populate `proposalSymbol` with the exact ticker, `proposalSide` with `buy` or `sell`, and `proposalQuantity` when you have a clear bounded quantity. Use `targetId` only when you are updating an existing proposal id from app-owned context.
        - If proposal drafting is part of the next governed step, prefer ordering hidden actions as proposal first, then decision, then approval request, then approval-response recording, then execution routing if that later route is truly ready.
        - Do not emit `create_pm_approval_request` by itself for a new governed paper-establishment step. If no pending PM approval ask already exists, pair it with a concrete `create_pm_decision` or a resolvable existing `targetId` so the app can durably create the approval artifact.
        - Do not visibly claim an in-app approval, Your Decisions item, route-to-execution step, Touch ID step, Mac password step, or order-ready state unless the hidden action plan creates or resolves the corresponding app-owned approval/routing object. If the hidden action is missing or blocked, say the blocker plainly.
        - Use `approve_pm_approval_request` only when the owner has already given clear approval or a clear "place it now / move forward now" instruction for an existing PM approval ask. Populate `targetId` with the exact approval-request id from app-owned context when you have it.
        - Use `route_governed_execution_next_step` only when the next step should be checked or routed through the existing governed path. Populate `targetId` with the exact approval-request id from app-owned context when you have it.
        - If the owner asks to establish or place the current initial paper-portfolio trades and app truth still shows no confirmed holdings or executed establishment trades, do not answer as though background confirmation is merely pending.
        - In that paper-establishment case, either ask one bounded follow-up if real ambiguity remains, or choose the hidden governed actions needed to surface the owner approval step before any proposal or execution routing.
        - When the owner explicitly says to execute or place the trades required to implement the current proposed paper portfolio, treat that as real execution intent rather than status context. If that instruction is explicit enough to approve the next governed paper step, include the approval-response and routing actions needed to test the real blocker or route.
        - If a pending PM approval ask for that same paper-establishment step is already present in app-owned context and the latest owner turn clearly says to place the trades now / move forward now, treat that as real owner approval intent rather than passive status context. In that case, prefer `approve_pm_approval_request`, then any truly needed proposal/routing actions, and do not say implementation is underway unless routing really ran.
        - If app-owned context says approval was already recorded and the same paper-establishment step is now blocked only on missing prices or active retry state, do not create another approval ask for that same step. Answer from the recorded blocked-or-retrying execution state instead.
        - If the app has enough grounded information to submit the paper-establishment orders, do not describe that as merely "captured" or "routed forward." The visible reply should stay compatible with the real app-owned outcome: orders submitted, partially submitted, or blocked for a specific reason.
        - Deterministic app-owned logic will validate and apply the hidden actions after you choose them, so choose the action that best matches the owner's meaning rather than narrating routing logic in the visible reply.
        - Populate the structured `resolution` object for every reply.
        - Use `resolution.intentClass` to classify the latest owner turn as instruction, correction, confirmation, refusal, clarification, follow_up_question, ambiguous, or general.
        - Use `resolution.disposition` to say whether the outcome stays conversation-only, updates only working understanding, proposes a durable change, applies one bounded durable change now, or still requires clarification.
        - When the reply captures or updates user-owned working portfolio or operating truth, populate `resolution.operatingTruthKind`, `resolution.operatingTruthSummary`, and `resolution.operatingTruthBody` so later PM replies can retrieve the latest conversation-owned version without requiring a separate apply step.
        - The only durable target you may route directly in this schema is `pm_instruction`, and only for bounded PM operating instructions or working portfolio definitions that stay separate from confirmed holdings/app truth.
        - Never use a conversation-derived durable instruction to claim actual holdings, executed trades, or confirmed portfolio state.
        - If the reply asks a new yes/no confirmation or clarification question, populate `resolution.pendingAsk` so later owner turns can bind to it cleanly, and include `pendingAsk.operatingTruthKind` / `pendingAsk.operatingTruthSummary` when the open loop is about reconstructing or confirming a working portfolio definition.
        - Keep approval, execution, and transport semantics unchanged.
        - Keep internal labels such as confirmed app truth, standing-review memory, conversation continuity, working-understanding, pending ask, or recovered context out of the visible reply unless you restate the distinction in ordinary owner-facing language because it materially helps.
        - Do not mention OpenAI, APIs, or runtime plumbing in the body.
        """
        return PMConversationPromptComposition(
            promptText: promptText,
            laneTraces: laneTraces
        )
}

func makePMConversationPromptText(from request: PMConversationOpenAISynthesisRequest) -> String {
    makePMConversationPromptComposition(from: request).promptText
}

func pmConversationPromptCharacterCount(for request: PMConversationOpenAISynthesisRequest) -> Int {
    makePMConversationPromptComposition(from: request).promptText.count
}

func pmConversationPromptBudgetTrace(
    for request: PMConversationOpenAISynthesisRequest,
    policy: PMConversationPromptBudgetPolicy = .runtimeDefault
) -> PMConversationPromptBudgetTrace {
    let composition = makePMConversationPromptComposition(from: request)
    return PMConversationPromptBudgetTrace(
        totalPromptCharacterCount: composition.promptText.count,
        promptCharacterBudget: policy.promptCharacterBudget,
        reservedOutputCharacterBudget: policy.reservedOutputCharacterBudget,
        totalContextWindowCharacterBudget: policy.totalContextWindowCharacterBudget,
        lanes: composition.laneTraces
    )
}

func makePMStandingReviewPromptText(from request: PMStandingReviewOpenAISynthesisRequest) -> String {
        let reportBlock = request.reports.prefix(4).map { report in
            let openQuestions = report.openQuestions.isEmpty ? "none" : report.openQuestions.prefix(3).joined(separator: " | ")
            let sections = report.sections.isEmpty ? "none" : report.sections.prefix(5).joined(separator: " | ")
            return """
            - title=\(openAIResponsesTrimmed(report.title, limit: 180))
              summary=\(openAIResponsesTrimmed(report.summary, limit: 220))
              headline=\(openAIResponsesTrimmed(report.headlineView, limit: 220))
              portfolio_relevance=\(openAIResponsesTrimmed(report.portfolioRelevanceSummary, limit: 220))
              open_questions=\(openQuestions)
              section_signals=\(sections)
            """
        }.joined(separator: "\n")
        return """
        Produce one bounded PM standing-review conclusion.

        Runtime requested: \(request.runtimeIdentifier)
        Reasoning mode: \(request.reasoningMode?.rawValue ?? "standard")
        No current portfolio attached: \(request.noPortfolio ? "yes" : "no")

        Strategy objective:
        \(request.strategyObjective.map { openAIResponsesTrimmed($0, limit: 500) } ?? "(none recorded)")

        Current risk posture:
        \(request.currentRiskPosture.map { openAIResponsesTrimmed($0, limit: 500) } ?? "(none recorded)")

        PM review posture:
        \(request.reviewEscalationPosture.map { openAIResponsesTrimmed($0, limit: 500) } ?? "(none recorded)")

        Analysts covered:
        \(request.analystTitles.joined(separator: ", "))

        Attention items:
        \(request.attentionItems.isEmpty ? "- none" : request.attentionItems.prefix(5).map { "- \(openAIResponsesTrimmed($0, limit: 220))" }.joined(separator: "\n"))

        Candidate longs:
        \(request.candidateLongs.isEmpty ? "- none" : request.candidateLongs.prefix(5).map { "- \(openAIResponsesTrimmed($0, limit: 220))" }.joined(separator: "\n"))

        Candidate shorts / hedges:
        \(request.candidateShorts.isEmpty ? "- none" : request.candidateShorts.prefix(5).map { "- \(openAIResponsesTrimmed($0, limit: 220))" }.joined(separator: "\n"))

        Candidate themes:
        \(request.candidateThemes.isEmpty ? "- none" : request.candidateThemes.prefix(5).map { "- \(openAIResponsesTrimmed($0, limit: 220))" }.joined(separator: "\n"))

        Follow-up items:
        \(request.followUpItems.isEmpty ? "- none" : request.followUpItems.prefix(5).map { "- \(openAIResponsesTrimmed($0, limit: 220))" }.joined(separator: "\n"))

        Report contexts:
        \(reportBlock)

        Disposition rules:
        - Use exactly one disposition enum from the schema.
        - `informational_no_action` means the PM should close the cycle with no further action.
        - `worth_monitoring` means monitor only, no owner escalation.
        - `follow_up_analyst_work_warranted` means stay in PM background review and consider bounded analyst follow-up.
        - `candidate_ideas_worth_considering` means candidate/watchlist construction ideas are present but still not owner-facing.
        - `owner_attention_recommended` means the review genuinely crossed the owner-attention threshold and should enter the existing governed owner path.
        - Keep the conclusion bounded and evidence-led.
        """
}

private func pmSchemaString() -> JSONValue {
    .object(["type": .string("string")])
}

private func pmSchemaInteger(minimum: Int? = nil) -> JSONValue {
    var object: [String: JSONValue] = ["type": .string("integer")]
    if let minimum {
        object["minimum"] = .number(Double(minimum))
    }
    return .object(object)
}

private func pmSchemaNumber(minimum: Double? = nil) -> JSONValue {
    var object: [String: JSONValue] = ["type": .string("number")]
    if let minimum {
        object["minimum"] = .number(minimum)
    }
    return .object(object)
}

private func pmSchemaArray(items: JSONValue) -> JSONValue {
    .object([
        "type": .string("array"),
        "items": items
    ])
}

private func pmSchemaNullable(_ schema: JSONValue) -> JSONValue {
    .object([
        "anyOf": .array([
            schema,
            .object(["type": .string("null")])
        ])
    ])
}

private func pmSchemaStrictObject(_ properties: [String: JSONValue]) -> JSONValue {
    .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object(properties),
        "required": .array(properties.keys.sorted().map(JSONValue.string))
    ])
}

private func pmSchemaEnum<T: CaseIterable>(_ type: T.Type) -> JSONValue where T: RawRepresentable, T.RawValue == String {
    .object([
        "type": .string("string"),
        "enum": .array(type.allCases.map { .string($0.rawValue) })
    ])
}

private func pmSchemaEnumValues(_ values: [String]) -> JSONValue {
    .object([
        "type": .string("string"),
        "enum": .array(values.map(JSONValue.string))
    ])
}

func pmConversationSchema() -> JSONValue {
    let selectedSkillReferenceProperties: [String: JSONValue] = [
        "skillId": pmSchemaString(),
        "requirement": pmSchemaEnum(AgentSkillReferenceRequirement.self),
        "rationale": pmSchemaNullable(pmSchemaString())
    ]

    let actionIntentProperties: [String: JSONValue] = [
        "actionType": pmSchemaEnum(PMConversationActionType.self),
        "summary": pmSchemaString(),
        "title": pmSchemaNullable(pmSchemaString()),
        "body": pmSchemaNullable(pmSchemaString()),
        "detail": pmSchemaNullable(pmSchemaString()),
        "targetId": pmSchemaNullable(pmSchemaString()),
        "charterId": pmSchemaNullable(pmSchemaString()),
        "proposalSymbol": pmSchemaNullable(pmSchemaString()),
        "proposalSide": pmSchemaNullable(pmSchemaEnumValues(["buy", "sell"])),
        "proposalQuantity": pmSchemaNullable(pmSchemaInteger(minimum: 1)),
        "liveOrderSymbol": pmSchemaNullable(pmSchemaString()),
        "liveOrderSide": pmSchemaNullable(pmSchemaEnumValues(["buy", "sell"])),
        "liveOrderQuantity": pmSchemaNullable(pmSchemaInteger(minimum: 1)),
        "liveOrderNotionalAmount": pmSchemaNullable(pmSchemaNumber(minimum: 0.01)),
        "liveOrderType": pmSchemaNullable(pmSchemaEnumValues(["market", "limit"])),
        "liveOrderTimeInForce": pmSchemaNullable(pmSchemaEnumValues(["day", "gtc"])),
        "liveOrderLimitPrice": pmSchemaNullable(pmSchemaNumber(minimum: 0.01)),
        "runtimeSettingScope": pmSchemaNullable(pmSchemaEnum(PMConversationRuntimeSettingScope.self)),
        "runtimeIdentifier": pmSchemaNullable(pmSchemaString()),
        "reasoningMode": pmSchemaNullable(pmSchemaEnum(AnalystRuntimeReasoningMode.self)),
        "requestedOutputs": pmSchemaArray(items: pmSchemaEnum(PMDelegationRequestedOutput.self)),
        "decisionType": pmSchemaNullable(pmSchemaEnum(PMDecisionType.self)),
        "requestType": pmSchemaNullable(pmSchemaEnum(PMApprovalRequestType.self)),
        "instructionTargetKind": pmSchemaNullable(pmSchemaEnum(PMConversationInstructionTargetKind.self)),
        "operatingTruthKind": pmSchemaNullable(pmSchemaEnum(PMConversationOperatingTruthKind.self)),
        "watchlistOperation": pmSchemaNullable(pmSchemaEnum(PMConversationWatchlistOperation.self)),
        "watchlistSymbols": pmSchemaArray(items: pmSchemaString()),
        "selectedSkillReferences": pmSchemaArray(items: pmSchemaStrictObject(selectedSkillReferenceProperties)),
        "sourceMessageIds": pmSchemaArray(items: pmSchemaString())
    ]

    let pendingAskProperties: [String: JSONValue] = [
        "kind": pmSchemaEnum(PMConversationPendingAskKind.self),
        "promptSummary": pmSchemaString(),
        "workingUnderstandingSummary": pmSchemaNullable(pmSchemaString()),
        "operatingTruthKind": pmSchemaNullable(pmSchemaEnum(PMConversationOperatingTruthKind.self)),
        "operatingTruthSummary": pmSchemaNullable(pmSchemaString()),
        "durableTargetType": pmSchemaNullable(pmSchemaEnum(PMConversationDurableTargetType.self)),
        "instructionTargetKind": pmSchemaNullable(pmSchemaEnum(PMConversationInstructionTargetKind.self)),
        "durableTitle": pmSchemaNullable(pmSchemaString()),
        "durableBody": pmSchemaNullable(pmSchemaString())
    ]

    let resolutionProperties: [String: JSONValue] = [
        "intentClass": pmSchemaEnum(PMConversationIntentClass.self),
        "disposition": pmSchemaEnum(PMConversationResolutionDisposition.self),
        "workingUnderstandingSummary": pmSchemaNullable(pmSchemaString()),
        "ambiguitySummary": pmSchemaNullable(pmSchemaString()),
        "operatingTruthKind": pmSchemaNullable(pmSchemaEnum(PMConversationOperatingTruthKind.self)),
        "operatingTruthSummary": pmSchemaNullable(pmSchemaString()),
        "operatingTruthBody": pmSchemaNullable(pmSchemaString()),
        "pendingAsk": pmSchemaNullable(pmSchemaStrictObject(pendingAskProperties)),
        "durableTargetType": pmSchemaNullable(pmSchemaEnum(PMConversationDurableTargetType.self)),
        "instructionTargetKind": pmSchemaNullable(pmSchemaEnum(PMConversationInstructionTargetKind.self)),
        "durableTitle": pmSchemaNullable(pmSchemaString()),
        "durableBody": pmSchemaNullable(pmSchemaString()),
        "sourceMessageIds": pmSchemaArray(items: pmSchemaString())
    ]

    return pmSchemaStrictObject([
        "replyBody": pmSchemaString(),
        "actionPlan": pmSchemaNullable(
            pmSchemaStrictObject([
                "summary": pmSchemaString(),
                "actions": pmSchemaArray(items: pmSchemaStrictObject(actionIntentProperties))
            ])
        ),
        "resolution": pmSchemaNullable(pmSchemaStrictObject(resolutionProperties))
    ])
}

private func pmStandingReviewSchema() -> JSONValue {
    .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object([
            "disposition": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("informational_no_action"),
                    .string("worth_monitoring"),
                    .string("follow_up_analyst_work_warranted"),
                    .string("owner_attention_recommended"),
                    .string("candidate_ideas_worth_considering")
                ])
            ]),
            "summary": .object(["type": .string("string")]),
            "recommendedAction": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("disposition"),
            .string("summary"),
            .string("recommendedAction")
        ])
    ])
}
