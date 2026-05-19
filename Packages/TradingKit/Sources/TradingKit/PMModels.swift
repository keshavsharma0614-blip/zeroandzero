import Foundation

public enum PMDelegationStatus: String, Codable, Sendable, CaseIterable {
    case issued
    case completed
    case canceled
}

public enum PMDelegationLastLaunchStatus: String, Codable, Sendable, CaseIterable {
    case running
    case progressing
    case healthy
    case degradedExternalEvidence = "degraded_external_evidence"
    case failed
}

public enum PMDelegationIssueResolutionReason: String, Codable, Sendable, CaseIterable {
    case ownerDismissed = "owner_dismissed"
    case operatorResolved = "operator_resolved"
    case supersededBySuccessfulLaunch = "superseded_by_successful_launch"
}

public struct PMDelegationIssueResolution: Codable, Sendable, Equatable {
    public var resolvedAt: Date
    public var resolvedBy: String
    public var reason: PMDelegationIssueResolutionReason
    public var summary: String
    public var supersededByDelegationId: String?

    public init(
        resolvedAt: Date,
        resolvedBy: String,
        reason: PMDelegationIssueResolutionReason,
        summary: String,
        supersededByDelegationId: String? = nil
    ) {
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.reason = reason
        self.summary = summary
        self.supersededByDelegationId = supersededByDelegationId
    }
}

public struct PMDelegationLastLaunch: Codable, Sendable, Equatable {
    public var launchedAt: Date
    public var status: PMDelegationLastLaunchStatus
    public var summary: String
    public var lastProgressAt: Date?
    public var progressStage: String?
    public var lastIssueSummary: String?
    public var completedAt: Date?

    public init(
        launchedAt: Date,
        status: PMDelegationLastLaunchStatus,
        summary: String,
        lastProgressAt: Date? = nil,
        progressStage: String? = nil,
        lastIssueSummary: String? = nil,
        completedAt: Date? = nil
    ) {
        self.launchedAt = launchedAt
        self.status = status
        self.summary = summary
        self.lastProgressAt = lastProgressAt
        self.progressStage = progressStage
        self.lastIssueSummary = lastIssueSummary
        self.completedAt = completedAt
    }
}

public enum PMDelegationRequestedOutput: String, Codable, Sendable, CaseIterable {
    case finding
    case signal
    case proposalDraft = "proposal_draft"
    case checkpointUpdate = "checkpoint_update"
}

public enum PMDelegationFollowThroughStatus: String, Codable, Sendable, CaseIterable {
    case notRequired = "not_required"
    case pending
    case delivered
    case failed
}

public struct PMDelegationFollowThrough: Codable, Sendable, Equatable {
    public var status: PMDelegationFollowThroughStatus
    public var sourceCommunicationSessionId: String?
    public var sourceCommunicationMessageId: String?
    public var requestedAt: Date?
    public var lastDeliveryAttemptAt: Date?
    public var deliveredMessageId: String?
    public var deliverySummary: String?
    public var failureReason: String?
    public var canonicalBody: String?
    public var canonicalBodyCreatedAt: Date?
    public var telegramDeliveredMessageId: String?
    public var telegramFailureReason: String?
    public var updatedAt: Date

    public init(
        status: PMDelegationFollowThroughStatus,
        sourceCommunicationSessionId: String? = nil,
        sourceCommunicationMessageId: String? = nil,
        requestedAt: Date? = nil,
        lastDeliveryAttemptAt: Date? = nil,
        deliveredMessageId: String? = nil,
        deliverySummary: String? = nil,
        failureReason: String? = nil,
        canonicalBody: String? = nil,
        canonicalBodyCreatedAt: Date? = nil,
        telegramDeliveredMessageId: String? = nil,
        telegramFailureReason: String? = nil,
        updatedAt: Date
    ) {
        self.status = status
        self.sourceCommunicationSessionId = sourceCommunicationSessionId
        self.sourceCommunicationMessageId = sourceCommunicationMessageId
        self.requestedAt = requestedAt
        self.lastDeliveryAttemptAt = lastDeliveryAttemptAt
        self.deliveredMessageId = deliveredMessageId
        self.deliverySummary = deliverySummary
        self.failureReason = failureReason
        self.canonicalBody = canonicalBody
        self.canonicalBodyCreatedAt = canonicalBodyCreatedAt
        self.telegramDeliveredMessageId = telegramDeliveredMessageId
        self.telegramFailureReason = telegramFailureReason
        self.updatedAt = updatedAt
    }
}

public enum PMAnalystExpectedAnswerShape: String, Codable, Sendable, CaseIterable {
    case memoOnly = "memo_only"
    case evidenceBackedAnswer = "evidence_backed_answer"
    case riskView = "risk_view"
    case competingCaseComparison = "competing_case_comparison"
    case recommendationReadySynthesis = "recommendation_ready_synthesis"
    case escalationOnlyConclusion = "escalation_only_conclusion"
    case revisedTake = "revised_take"
}

public struct PMTaskingBrief: Codable, Sendable, Equatable {
    public var taskObjective: String?
    public var whyNow: String?
    public var reviewLens: String?
    public var expectedAnswerShape: PMAnalystExpectedAnswerShape?
    public var challengeInstruction: String?
    public var evidenceExpectation: String?
    public var disconfirmingEvidenceExpectation: String?
    public var researchQuestions: [String]
    public var coverageRequired: Bool
    public var expectedOutputs: [String]
    public var revisionReason: String?
    public var selectedSkillReferences: [AgentSkillTaskReference]

    public init(
        taskObjective: String? = nil,
        whyNow: String? = nil,
        reviewLens: String? = nil,
        expectedAnswerShape: PMAnalystExpectedAnswerShape? = nil,
        challengeInstruction: String? = nil,
        evidenceExpectation: String? = nil,
        disconfirmingEvidenceExpectation: String? = nil,
        researchQuestions: [String] = [],
        coverageRequired: Bool = false,
        expectedOutputs: [String] = [],
        revisionReason: String? = nil,
        selectedSkillReferences: [AgentSkillTaskReference] = []
    ) {
        self.taskObjective = taskObjective
        self.whyNow = whyNow
        self.reviewLens = reviewLens
        self.expectedAnswerShape = expectedAnswerShape
        self.challengeInstruction = challengeInstruction
        self.evidenceExpectation = evidenceExpectation
        self.disconfirmingEvidenceExpectation = disconfirmingEvidenceExpectation
        self.researchQuestions = researchQuestions
        self.coverageRequired = coverageRequired
        self.expectedOutputs = expectedOutputs
        self.revisionReason = revisionReason
        self.selectedSkillReferences = selectedSkillReferences
    }

    private enum CodingKeys: String, CodingKey {
        case taskObjective
        case whyNow
        case reviewLens
        case expectedAnswerShape
        case challengeInstruction
        case evidenceExpectation
        case disconfirmingEvidenceExpectation
        case researchQuestions
        case coverageRequired
        case expectedOutputs
        case revisionReason
        case selectedSkillReferences
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskObjective = try container.decodeIfPresent(String.self, forKey: .taskObjective)
        whyNow = try container.decodeIfPresent(String.self, forKey: .whyNow)
        reviewLens = try container.decodeIfPresent(String.self, forKey: .reviewLens)
        expectedAnswerShape = try container.decodeIfPresent(
            PMAnalystExpectedAnswerShape.self,
            forKey: .expectedAnswerShape
        )
        challengeInstruction = try container.decodeIfPresent(String.self, forKey: .challengeInstruction)
        evidenceExpectation = try container.decodeIfPresent(String.self, forKey: .evidenceExpectation)
        disconfirmingEvidenceExpectation = try container.decodeIfPresent(
            String.self,
            forKey: .disconfirmingEvidenceExpectation
        )
        researchQuestions = try container.decodeIfPresent([String].self, forKey: .researchQuestions) ?? []
        coverageRequired = try container.decodeIfPresent(Bool.self, forKey: .coverageRequired) ?? false
        expectedOutputs = try container.decodeIfPresent([String].self, forKey: .expectedOutputs) ?? []
        revisionReason = try container.decodeIfPresent(String.self, forKey: .revisionReason)
        selectedSkillReferences = try container.decodeIfPresent(
            [AgentSkillTaskReference].self,
            forKey: .selectedSkillReferences
        ) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(taskObjective, forKey: .taskObjective)
        try container.encodeIfPresent(whyNow, forKey: .whyNow)
        try container.encodeIfPresent(reviewLens, forKey: .reviewLens)
        try container.encodeIfPresent(expectedAnswerShape, forKey: .expectedAnswerShape)
        try container.encodeIfPresent(challengeInstruction, forKey: .challengeInstruction)
        try container.encodeIfPresent(evidenceExpectation, forKey: .evidenceExpectation)
        try container.encodeIfPresent(disconfirmingEvidenceExpectation, forKey: .disconfirmingEvidenceExpectation)
        try container.encode(researchQuestions, forKey: .researchQuestions)
        try container.encode(coverageRequired, forKey: .coverageRequired)
        try container.encode(expectedOutputs, forKey: .expectedOutputs)
        try container.encodeIfPresent(revisionReason, forKey: .revisionReason)
        try container.encode(selectedSkillReferences, forKey: .selectedSkillReferences)
    }
}

public enum PMAnalystFollowUpActionType: String, Codable, Sendable, CaseIterable {
    case accept
    case requestRevision = "request_revision"
    case requestStrongerEvidence = "request_stronger_evidence"
    case rerouteToAnalyst = "reroute_to_analyst"
    case rerunWithRuntime = "rerun_with_runtime"
}

public struct PMAnalystFollowUpAction: Codable, Sendable, Equatable, Identifiable {
    public var id: String { actionId }

    public var actionId: String
    public var actionType: PMAnalystFollowUpActionType
    public var summary: String
    public var requestedCharterId: String?
    public var requestedRuntimePolicy: AnalystRuntimePolicy?
    public var taskingBrief: PMTaskingBrief?
    public var createdAt: Date

    public init(
        actionId: String,
        actionType: PMAnalystFollowUpActionType,
        summary: String,
        requestedCharterId: String? = nil,
        requestedRuntimePolicy: AnalystRuntimePolicy? = nil,
        taskingBrief: PMTaskingBrief? = nil,
        createdAt: Date
    ) {
        self.actionId = actionId
        self.actionType = actionType
        self.summary = summary
        self.requestedCharterId = requestedCharterId
        self.requestedRuntimePolicy = requestedRuntimePolicy
        self.taskingBrief = taskingBrief
        self.createdAt = createdAt
    }
}

public struct PMDelegationFollowUpRequest: Codable, Sendable, Equatable {
    public var sourceDelegationId: String
    public var actionType: PMAnalystFollowUpActionType
    public var summary: String
    public var requestedCharterId: String?
    public var requestedRuntimePolicy: AnalystRuntimePolicy?
    public var taskingBrief: PMTaskingBrief?

    public init(
        sourceDelegationId: String,
        actionType: PMAnalystFollowUpActionType,
        summary: String,
        requestedCharterId: String? = nil,
        requestedRuntimePolicy: AnalystRuntimePolicy? = nil,
        taskingBrief: PMTaskingBrief? = nil
    ) {
        self.sourceDelegationId = sourceDelegationId
        self.actionType = actionType
        self.summary = summary
        self.requestedCharterId = requestedCharterId
        self.requestedRuntimePolicy = requestedRuntimePolicy
        self.taskingBrief = taskingBrief
    }
}

public struct PMDelegationFollowUpResult: Codable, Sendable, Equatable {
    public var sourceDelegationId: String
    public var sourceFollowUpActionId: String
    public var createdDelegationId: String?
    public var createdTaskId: String?
    public var createdDecisionId: String?
    public var launchResult: AnalystWorkerLaunchResult?

    public init(
        sourceDelegationId: String,
        sourceFollowUpActionId: String,
        createdDelegationId: String? = nil,
        createdTaskId: String? = nil,
        createdDecisionId: String? = nil,
        launchResult: AnalystWorkerLaunchResult? = nil
    ) {
        self.sourceDelegationId = sourceDelegationId
        self.sourceFollowUpActionId = sourceFollowUpActionId
        self.createdDelegationId = createdDelegationId
        self.createdTaskId = createdTaskId
        self.createdDecisionId = createdDecisionId
        self.launchResult = launchResult
    }
}

public struct PMProfile: Codable, Sendable, Equatable, Identifiable {
    public static let primaryPMID = "pm-primary"
    public static let operationalExercisePMID = "pm-operational-exercise"

    public var id: String { pmId }

    public var pmId: String
    public var displayName: String
    public var roleSummary: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        pmId: String,
        displayName: String,
        roleSummary: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.pmId = pmId
        self.displayName = displayName
        self.roleSummary = roleSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func defaultPrimary(now: Date) -> PMProfile {
        PMProfile(
            pmId: PMProfile.primaryPMID,
            displayName: "Primary PM",
            roleSummary: "Primary portfolio manager operating through the app-owned control plane.",
            createdAt: now,
            updatedAt: now
        )
    }
}

public func isOperationalExercisePMID(_ value: String?) -> Bool {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false else {
        return false
    }
    return trimmed == PMProfile.operationalExercisePMID
}

public struct PMMandate: Codable, Sendable, Equatable, Identifiable {
    public var id: String { mandateId }

    public var mandateId: String
    public var pmId: String
    public var title: String
    public var objectiveSummary: String
    public var scope: String
    public var constraints: [String]
    public var riskBoundaries: [String]
    public var successCriteria: [String]
    public var sourceAnalystStrategyFollowUpCandidateId: String?
    public var sourceAnalystStrategyImplicationId: String?
    public var sourceAnalystMemoId: String?
    public var sourceAnalystFindingId: String?
    public var sourceAnalystEvidenceBundleId: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        mandateId: String,
        pmId: String,
        title: String,
        objectiveSummary: String,
        scope: String,
        constraints: [String] = [],
        riskBoundaries: [String] = [],
        successCriteria: [String] = [],
        sourceAnalystStrategyFollowUpCandidateId: String? = nil,
        sourceAnalystStrategyImplicationId: String? = nil,
        sourceAnalystMemoId: String? = nil,
        sourceAnalystFindingId: String? = nil,
        sourceAnalystEvidenceBundleId: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.mandateId = mandateId
        self.pmId = pmId
        self.title = title
        self.objectiveSummary = objectiveSummary
        self.scope = scope
        self.constraints = constraints
        self.riskBoundaries = riskBoundaries
        self.successCriteria = successCriteria
        self.sourceAnalystStrategyFollowUpCandidateId = sourceAnalystStrategyFollowUpCandidateId
        self.sourceAnalystStrategyImplicationId = sourceAnalystStrategyImplicationId
        self.sourceAnalystMemoId = sourceAnalystMemoId
        self.sourceAnalystFindingId = sourceAnalystFindingId
        self.sourceAnalystEvidenceBundleId = sourceAnalystEvidenceBundleId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PMInstructionStatus: String, Codable, Sendable, CaseIterable {
    case active
    case archived
}

public struct PMInstruction: Codable, Sendable, Equatable, Identifiable {
    public var id: String { instructionId }

    public var instructionId: String
    public var pmId: String
    public var title: String
    public var body: String
    public var category: String
    public var status: PMInstructionStatus
    public var effectiveAt: Date?
    public var sourceAnalystStrategyFollowUpCandidateId: String?
    public var sourceAnalystStrategyImplicationId: String?
    public var sourceAnalystMemoId: String?
    public var sourceAnalystFindingId: String?
    public var sourceAnalystEvidenceBundleId: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        instructionId: String,
        pmId: String,
        title: String,
        body: String,
        category: String,
        status: PMInstructionStatus = .active,
        effectiveAt: Date? = nil,
        sourceAnalystStrategyFollowUpCandidateId: String? = nil,
        sourceAnalystStrategyImplicationId: String? = nil,
        sourceAnalystMemoId: String? = nil,
        sourceAnalystFindingId: String? = nil,
        sourceAnalystEvidenceBundleId: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.instructionId = instructionId
        self.pmId = pmId
        self.title = title
        self.body = body
        self.category = category
        self.status = status
        self.effectiveAt = effectiveAt
        self.sourceAnalystStrategyFollowUpCandidateId = sourceAnalystStrategyFollowUpCandidateId
        self.sourceAnalystStrategyImplicationId = sourceAnalystStrategyImplicationId
        self.sourceAnalystMemoId = sourceAnalystMemoId
        self.sourceAnalystFindingId = sourceAnalystFindingId
        self.sourceAnalystEvidenceBundleId = sourceAnalystEvidenceBundleId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PMNotebookEntry: Codable, Sendable, Equatable, Identifiable {
    public var id: String { entryId }

    public var entryId: String
    public var pmId: String
    public var title: String
    public var body: String
    public var tags: [String]
    public var sourceSummary: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        entryId: String,
        pmId: String,
        title: String,
        body: String,
        tags: [String] = [],
        sourceSummary: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.entryId = entryId
        self.pmId = pmId
        self.title = title
        self.body = body
        self.tags = tags
        self.sourceSummary = sourceSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PMInteractionMemoryKind: String, Codable, Sendable, CaseIterable {
    case ownerPreference = "owner_preference"
    case reviewPreference = "review_preference"
    case decisionPattern = "decision_pattern"
    case recurringConcern = "recurring_concern"
    case operatingPreference = "operating_preference"

    public var displayTitle: String {
        switch self {
        case .ownerPreference:
            return "Owner Preference"
        case .reviewPreference:
            return "Review Preference"
        case .decisionPattern:
            return "Decision Pattern"
        case .recurringConcern:
            return "Recurring Concern"
        case .operatingPreference:
            return "Operating Preference"
        }
    }
}

public enum PMInteractionMemoryStatus: String, Codable, Sendable, CaseIterable {
    case active
    case archived
}

public struct PMInteractionMemoryRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String { memoryId }

    public var memoryId: String
    public var pmId: String
    public var kind: PMInteractionMemoryKind
    public var title: String
    public var summary: String
    public var symbols: [String]
    public var themes: [String]
    public var riskPostures: [String]
    public var recommendationTypes: [String]
    public var ownerResponsePatterns: [PMApprovalRequestOwnerResponse]
    public var sourceCommunicationMessageId: String?
    public var sourceDecisionId: String?
    public var sourceApprovalRequestId: String?
    public var sourceStrategyBriefId: String?
    public var sourceAnalystMemoId: String?
    public var status: PMInteractionMemoryStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        memoryId: String,
        pmId: String,
        kind: PMInteractionMemoryKind,
        title: String,
        summary: String,
        symbols: [String] = [],
        themes: [String] = [],
        riskPostures: [String] = [],
        recommendationTypes: [String] = [],
        ownerResponsePatterns: [PMApprovalRequestOwnerResponse] = [],
        sourceCommunicationMessageId: String? = nil,
        sourceDecisionId: String? = nil,
        sourceApprovalRequestId: String? = nil,
        sourceStrategyBriefId: String? = nil,
        sourceAnalystMemoId: String? = nil,
        status: PMInteractionMemoryStatus = .active,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.memoryId = memoryId
        self.pmId = pmId
        self.kind = kind
        self.title = title
        self.summary = summary
        self.symbols = symbols
        self.themes = themes
        self.riskPostures = riskPostures
        self.recommendationTypes = recommendationTypes
        self.ownerResponsePatterns = ownerResponsePatterns
        self.sourceCommunicationMessageId = sourceCommunicationMessageId
        self.sourceDecisionId = sourceDecisionId
        self.sourceApprovalRequestId = sourceApprovalRequestId
        self.sourceStrategyBriefId = sourceStrategyBriefId
        self.sourceAnalystMemoId = sourceAnalystMemoId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PMRuntimeSettingsUpdateSource: String, Codable, Sendable, CaseIterable {
    case userEdited = "user_edited"
    case pmControlPlane = "pm_control_plane"
    case systemDefault = "system_default"
}

public struct PMRuntimeSettings: Codable, Sendable, Equatable, Identifiable {
    public static let singletonID = "current-pm-runtime-settings"

    private enum CodingKeys: String, CodingKey {
        case settingsId
        case providerKind
        case credentialProfileId
        case runtimeIdentifier
        case reasoningMode
        case validationStatus
        case executionStatus
        case lastKnownGoodRuntime
        case lastFallback
        case updatedBy
        case updateSource
        case createdAt
        case updatedAt
    }

    public var id: String { settingsId }

    public var settingsId: String
    public var providerKind: LLMProviderKind
    public var credentialProfileId: String
    public var runtimeIdentifier: String
    public var reasoningMode: AnalystRuntimeReasoningMode?
    public var validationStatus: RuntimeValidationRecord?
    public var executionStatus: RuntimeValidationRecord?
    public var lastKnownGoodRuntime: LastKnownGoodRuntimeRecord?
    public var lastFallback: RuntimeFallbackRecord?
    public var updatedBy: String
    public var updateSource: PMRuntimeSettingsUpdateSource
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        settingsId: String = PMRuntimeSettings.singletonID,
        providerKind: LLMProviderKind = .openAI,
        credentialProfileId: String = LLMCredentialProfile.openAIDefaultProfileID,
        runtimeIdentifier: String,
        reasoningMode: AnalystRuntimeReasoningMode? = nil,
        validationStatus: RuntimeValidationRecord? = nil,
        executionStatus: RuntimeValidationRecord? = nil,
        lastKnownGoodRuntime: LastKnownGoodRuntimeRecord? = nil,
        lastFallback: RuntimeFallbackRecord? = nil,
        updatedBy: String,
        updateSource: PMRuntimeSettingsUpdateSource,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.settingsId = settingsId
        self.providerKind = providerKind
        self.credentialProfileId = credentialProfileId
        self.runtimeIdentifier = runtimeIdentifier
        self.reasoningMode = reasoningMode
        self.validationStatus = validationStatus
        self.executionStatus = executionStatus
        self.lastKnownGoodRuntime = lastKnownGoodRuntime
        self.lastFallback = lastFallback
        self.updatedBy = updatedBy
        self.updateSource = updateSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func `default`(now: Date) -> PMRuntimeSettings {
        PMRuntimeSettings(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            updatedBy: "system",
            updateSource: .systemDefault,
            createdAt: now,
            updatedAt: now
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.settingsId = try container.decodeIfPresent(String.self, forKey: .settingsId) ?? Self.singletonID
        self.providerKind = try container.decodeIfPresent(LLMProviderKind.self, forKey: .providerKind) ?? .openAI
        self.credentialProfileId = try container.decodeIfPresent(String.self, forKey: .credentialProfileId)
            ?? providerKind.defaultCredentialProfileId
        self.runtimeIdentifier = try container.decodeIfPresent(String.self, forKey: .runtimeIdentifier) ?? ""
        self.reasoningMode = try container.decodeIfPresent(AnalystRuntimeReasoningMode.self, forKey: .reasoningMode)
        self.validationStatus = try container.decodeIfPresent(RuntimeValidationRecord.self, forKey: .validationStatus)
        self.executionStatus = try container.decodeIfPresent(RuntimeValidationRecord.self, forKey: .executionStatus)
        self.lastKnownGoodRuntime = try container.decodeIfPresent(LastKnownGoodRuntimeRecord.self, forKey: .lastKnownGoodRuntime)
        self.lastFallback = try container.decodeIfPresent(RuntimeFallbackRecord.self, forKey: .lastFallback)
        self.updatedBy = try container.decodeIfPresent(String.self, forKey: .updatedBy) ?? "system"
        self.updateSource = try container.decodeIfPresent(PMRuntimeSettingsUpdateSource.self, forKey: .updateSource) ?? .systemDefault
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(settingsId, forKey: .settingsId)
        try container.encode(providerKind, forKey: .providerKind)
        try container.encode(credentialProfileId, forKey: .credentialProfileId)
        try container.encode(runtimeIdentifier, forKey: .runtimeIdentifier)
        try container.encodeIfPresent(reasoningMode, forKey: .reasoningMode)
        try container.encodeIfPresent(validationStatus, forKey: .validationStatus)
        try container.encodeIfPresent(executionStatus, forKey: .executionStatus)
        try container.encodeIfPresent(lastKnownGoodRuntime, forKey: .lastKnownGoodRuntime)
        try container.encodeIfPresent(lastFallback, forKey: .lastFallback)
        try container.encode(updatedBy, forKey: .updatedBy)
        try container.encode(updateSource, forKey: .updateSource)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public enum PortfolioStrategyBriefUpdateSource: String, Codable, Sendable, CaseIterable {
    case userEdited = "user_edited"
    case pmControlPlane = "pm_control_plane"
    case conversationDerived = "conversation_derived"
    case systemSeed = "system_seed"
    case strategyFollowUpCandidateApplied = "strategy_follow_up_candidate_applied"
}

public struct PortfolioStrategyBrief: Codable, Sendable, Equatable, Identifiable {
    public static let singletonID = "current-portfolio-strategy-brief"

    public var id: String { briefId }

    public var briefId: String
    public var title: String
    public var documentBody: String?
    public var objectiveSummary: String
    public var keyThemes: [String]
    public var currentRiskPosture: String
    public var materialDevelopments: [String]
    public var nonMaterialDevelopments: [String]
    public var reviewEscalationPosture: String
    public var revisionSummary: String?
    public var sourceCommunicationMessageId: String?
    public var sourceAnalystStrategyFollowUpCandidateId: String?
    public var sourceAnalystStrategyImplicationId: String?
    public var sourceAnalystMemoId: String?
    public var sourceAnalystFindingId: String?
    public var sourceAnalystEvidenceBundleId: String?
    public var updatedBy: String
    public var updateSource: PortfolioStrategyBriefUpdateSource
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        briefId: String = PortfolioStrategyBrief.singletonID,
        title: String = "Current Portfolio Strategy Brief",
        documentBody: String? = nil,
        objectiveSummary: String,
        keyThemes: [String] = [],
        currentRiskPosture: String,
        materialDevelopments: [String] = [],
        nonMaterialDevelopments: [String] = [],
        reviewEscalationPosture: String,
        revisionSummary: String? = nil,
        sourceCommunicationMessageId: String? = nil,
        sourceAnalystStrategyFollowUpCandidateId: String? = nil,
        sourceAnalystStrategyImplicationId: String? = nil,
        sourceAnalystMemoId: String? = nil,
        sourceAnalystFindingId: String? = nil,
        sourceAnalystEvidenceBundleId: String? = nil,
        updatedBy: String,
        updateSource: PortfolioStrategyBriefUpdateSource,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.briefId = briefId
        self.title = title
        self.documentBody = documentBody
        self.objectiveSummary = objectiveSummary
        self.keyThemes = keyThemes
        self.currentRiskPosture = currentRiskPosture
        self.materialDevelopments = materialDevelopments
        self.nonMaterialDevelopments = nonMaterialDevelopments
        self.reviewEscalationPosture = reviewEscalationPosture
        self.revisionSummary = revisionSummary
        self.sourceCommunicationMessageId = sourceCommunicationMessageId
        self.sourceAnalystStrategyFollowUpCandidateId = sourceAnalystStrategyFollowUpCandidateId
        self.sourceAnalystStrategyImplicationId = sourceAnalystStrategyImplicationId
        self.sourceAnalystMemoId = sourceAnalystMemoId
        self.sourceAnalystFindingId = sourceAnalystFindingId
        self.sourceAnalystEvidenceBundleId = sourceAnalystEvidenceBundleId
        self.updatedBy = updatedBy
        self.updateSource = updateSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var renderedDocumentBody: String {
        PortfolioStrategyBriefDocumentSupport.render(self)
    }

    public var primaryDocumentBody: String {
        let document = documentBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return document.isEmpty ? renderedDocumentBody : document
    }

    public func applyingDocumentExtraction() -> PortfolioStrategyBrief {
        PortfolioStrategyBriefDocumentSupport.apply(to: self)
    }

    public static func `default`(now: Date) -> PortfolioStrategyBrief {
        PortfolioStrategyBrief(
            objectiveSummary: "",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            updatedBy: "system",
            updateSource: .systemSeed,
            createdAt: now,
            updatedAt: now
        )
    }
}

private enum PortfolioStrategyBriefDocumentSupport {
    private enum SectionKey: String, CaseIterable {
        case objective
        case keyThemes
        case currentRiskPosture
        case materialDevelopments
        case nonMaterialDevelopments
        case reviewEscalationPosture
    }

    static func render(_ brief: PortfolioStrategyBrief) -> String {
        let renderedSections: [String] = [
            renderTextSection("Objective", brief.objectiveSummary),
            renderListSection("Key Themes", brief.keyThemes),
            renderTextSection("Current Risk Posture", brief.currentRiskPosture),
            renderListSection("Material Developments", brief.materialDevelopments),
            renderListSection("Usually Not Material", brief.nonMaterialDevelopments),
            renderTextSection("Review Posture", brief.reviewEscalationPosture)
        ]

        let joined = renderedSections
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if joined.isEmpty {
            return [
                "## Objective",
                "",
                "## Key Themes",
                "",
                "## Current Risk Posture",
                "",
                "## Material Developments",
                "",
                "## Usually Not Material",
                "",
                "## Review Posture"
            ].joined(separator: "\n")
        }

        return joined
    }

    static func apply(to brief: PortfolioStrategyBrief) -> PortfolioStrategyBrief {
        var updated = brief
        let document = brief.documentBody?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if document.isEmpty {
            updated.documentBody = render(brief)
            return updated
        }

        updated.documentBody = document
        let extracted = extractSections(from: document)

        if let objective = extracted[.objective]?.nilIfEmpty {
            updated.objectiveSummary = objective
        } else {
            updated.objectiveSummary = fallbackObjective(from: document)
        }

        updated.keyThemes = parseList(extracted[.keyThemes] ?? "")
        updated.currentRiskPosture = extracted[.currentRiskPosture]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.materialDevelopments = parseList(extracted[.materialDevelopments] ?? "")
        updated.nonMaterialDevelopments = parseList(extracted[.nonMaterialDevelopments] ?? "")
        updated.reviewEscalationPosture = extracted[.reviewEscalationPosture]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return updated
    }

    private static func renderTextSection(_ title: String, _ value: String) -> String {
        ["## \(title)", value.trimmingCharacters(in: .whitespacesAndNewlines)]
            .joined(separator: "\n")
    }

    private static func renderListSection(_ title: String, _ values: [String]) -> String {
        let list = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .map { "- \($0)" }
            .joined(separator: "\n")
        return ["## \(title)", list].joined(separator: "\n")
    }

    private static func extractSections(from document: String) -> [SectionKey: String] {
        var sections: [SectionKey: [String]] = [:]
        var currentKey: SectionKey?

        for rawLine in document.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let heading = resolveHeading(line) {
                currentKey = heading
                if sections[heading] == nil {
                    sections[heading] = []
                }
                continue
            }

            guard let currentKey else { continue }
            sections[currentKey, default: []].append(rawLine)
        }

        return sections.mapValues { lines in
            lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func resolveHeading(_ line: String) -> SectionKey? {
        let normalized = line
            .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: ":", with: "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "objective", "objective summary":
            return .objective
        case "key themes", "themes", "strategy themes":
            return .keyThemes
        case "current risk posture", "risk posture":
            return .currentRiskPosture
        case "material developments", "what counts as material", "material":
            return .materialDevelopments
        case "usually not material", "non material developments", "non-material developments", "what is not material":
            return .nonMaterialDevelopments
        case "review posture", "review escalation posture", "escalation posture":
            return .reviewEscalationPosture
        default:
            return nil
        }
    }

    private static func parseList(_ body: String) -> [String] {
        body
            .components(separatedBy: .newlines)
            .map {
                $0
                    .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0.isEmpty == false }
    }

    private static func fallbackObjective(from document: String) -> String {
        document
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false && resolveHeading($0) == nil }) ?? ""
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

public enum PMDecisionType: String, Codable, Sendable, CaseIterable {
    case recommendation
    case escalation
    case readinessAssessment = "readiness_assessment"
    case other
}

public enum AnalystStrategyImplicationKind: String, Codable, Sendable, CaseIterable {
    case noCurrentImplication = "no_current_implication"
    case worthMonitoring = "worth_monitoring"
    case strategyFollowUpWarranted = "strategy_follow_up_warranted"
    case candidateStrategyBriefRevision = "candidate_strategy_brief_revision"
    case candidateInstructionOrMandateFollowUp = "candidate_instruction_or_mandate_follow_up"

    public var displayTitle: String {
        switch self {
        case .noCurrentImplication:
            return "No Current Strategy Implication"
        case .worthMonitoring:
            return "Worth Monitoring"
        case .strategyFollowUpWarranted:
            return "Strategy Follow-Up Warranted"
        case .candidateStrategyBriefRevision:
            return "Candidate Strategy Brief Revision"
        case .candidateInstructionOrMandateFollowUp:
            return "Candidate PM Instruction / Mandate Follow-Up"
        }
    }
}

public enum AnalystStrategyFollowUpCandidateKind: String, Codable, Sendable, CaseIterable {
    case monitorOnly = "monitor_only"
    case strategyBriefRevision = "strategy_brief_revision"
    case pmInstructionFollowUp = "pm_instruction_follow_up"
    case pmMandateFollowUp = "pm_mandate_follow_up"

    public var displayTitle: String {
        switch self {
        case .monitorOnly:
            return "Monitor Only"
        case .strategyBriefRevision:
            return "Strategy Brief Revision Candidate"
        case .pmInstructionFollowUp:
            return "PM Instruction Follow-Up Candidate"
        case .pmMandateFollowUp:
            return "PM Mandate Follow-Up Candidate"
        }
    }
}

public enum AnalystStrategyFollowUpCandidateStatus: String, Codable, Sendable, CaseIterable {
    case open
    case monitoring
    case appliedToStrategyBrief = "applied_to_strategy_brief"
    case convertedToInstruction = "converted_to_instruction"
    case convertedToMandate = "converted_to_mandate"
    case dismissed

    public var displayTitle: String {
        switch self {
        case .open:
            return "Open"
        case .monitoring:
            return "Monitoring"
        case .appliedToStrategyBrief:
            return "Applied To Strategy Brief"
        case .convertedToInstruction:
            return "Converted To PM Instruction"
        case .convertedToMandate:
            return "Converted To PM Mandate"
        case .dismissed:
            return "Dismissed"
        }
    }

    public var isActive: Bool {
        switch self {
        case .open, .monitoring:
            return true
        case .appliedToStrategyBrief, .convertedToInstruction, .convertedToMandate, .dismissed:
            return false
        }
    }
}

public struct AnalystStrategyImplicationRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String { implicationId }

    public var implicationId: String
    public var pmId: String
    public var implicationKind: AnalystStrategyImplicationKind
    public var implicationSummary: String
    public var whyItMatters: String
    public var candidateStrategyBriefRevisionNote: String?
    public var candidatePMFollowUpSummary: String?
    public var memoId: String?
    public var findingId: String?
    public var evidenceBundleId: String?
    public var delegationId: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        implicationId: String,
        pmId: String,
        implicationKind: AnalystStrategyImplicationKind,
        implicationSummary: String,
        whyItMatters: String,
        candidateStrategyBriefRevisionNote: String? = nil,
        candidatePMFollowUpSummary: String? = nil,
        memoId: String? = nil,
        findingId: String? = nil,
        evidenceBundleId: String? = nil,
        delegationId: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.implicationId = implicationId
        self.pmId = pmId
        self.implicationKind = implicationKind
        self.implicationSummary = implicationSummary
        self.whyItMatters = whyItMatters
        self.candidateStrategyBriefRevisionNote = candidateStrategyBriefRevisionNote
        self.candidatePMFollowUpSummary = candidatePMFollowUpSummary
        self.memoId = memoId
        self.findingId = findingId
        self.evidenceBundleId = evidenceBundleId
        self.delegationId = delegationId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AnalystStrategyFollowUpCandidateRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String { candidateId }

    public var candidateId: String
    public var implicationId: String
    public var pmId: String
    public var followUpKind: AnalystStrategyFollowUpCandidateKind
    public var status: AnalystStrategyFollowUpCandidateStatus
    public var candidateSummary: String
    public var candidateDetail: String
    public var memoId: String?
    public var findingId: String?
    public var evidenceBundleId: String?
    public var delegationId: String?
    public var appliedStrategyBriefId: String?
    public var convertedInstructionId: String?
    public var convertedMandateId: String?
    public var closedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        candidateId: String,
        implicationId: String,
        pmId: String,
        followUpKind: AnalystStrategyFollowUpCandidateKind,
        status: AnalystStrategyFollowUpCandidateStatus,
        candidateSummary: String,
        candidateDetail: String,
        memoId: String? = nil,
        findingId: String? = nil,
        evidenceBundleId: String? = nil,
        delegationId: String? = nil,
        appliedStrategyBriefId: String? = nil,
        convertedInstructionId: String? = nil,
        convertedMandateId: String? = nil,
        closedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.candidateId = candidateId
        self.implicationId = implicationId
        self.pmId = pmId
        self.followUpKind = followUpKind
        self.status = status
        self.candidateSummary = candidateSummary
        self.candidateDetail = candidateDetail
        self.memoId = memoId
        self.findingId = findingId
        self.evidenceBundleId = evidenceBundleId
        self.delegationId = delegationId
        self.appliedStrategyBriefId = appliedStrategyBriefId
        self.convertedInstructionId = convertedInstructionId
        self.convertedMandateId = convertedMandateId
        self.closedAt = closedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PMDecisionStatus: String, Codable, Sendable, CaseIterable {
    case active
    case superseded
    case withdrawn
}

public struct PMDecisionRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String { decisionId }

    public var decisionId: String
    public var pmId: String
    public var title: String
    public var summary: String
    public var recommendedAction: String?
    public var evidenceSummary: String?
    public var ownerAsk: String?
    public var approvedNextStepSummary: String?
    public var sourceCommunicationMessageId: String?
    public var decisionType: PMDecisionType
    public var status: PMDecisionStatus
    public var delegationId: String?
    public var charterId: String?
    public var taskId: String?
    public var findingId: String?
    public var signalId: String?
    public var proposalId: String?
    public var primaryStandingReportId: String?
    public var standingReportIds: [String]?
    public var standingReviewDisposition: String?
    public var standingReviewAnalystTitles: [String]?
    public var standingReviewAttentionItems: [String]?
    public var standingReviewCandidateLongs: [String]?
    public var standingReviewCandidateShorts: [String]?
    public var standingReviewCandidateThemes: [String]?
    public var standingReviewFollowUpItems: [String]?
    public var runtimeProvenance: PMRuntimeProvenance?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        decisionId: String,
        pmId: String,
        title: String,
        summary: String,
        recommendedAction: String? = nil,
        evidenceSummary: String? = nil,
        ownerAsk: String? = nil,
        approvedNextStepSummary: String? = nil,
        sourceCommunicationMessageId: String? = nil,
        decisionType: PMDecisionType = .recommendation,
        status: PMDecisionStatus = .active,
        delegationId: String? = nil,
        charterId: String? = nil,
        taskId: String? = nil,
        findingId: String? = nil,
        signalId: String? = nil,
        proposalId: String? = nil,
        primaryStandingReportId: String? = nil,
        standingReportIds: [String]? = nil,
        standingReviewDisposition: String? = nil,
        standingReviewAnalystTitles: [String]? = nil,
        standingReviewAttentionItems: [String]? = nil,
        standingReviewCandidateLongs: [String]? = nil,
        standingReviewCandidateShorts: [String]? = nil,
        standingReviewCandidateThemes: [String]? = nil,
        standingReviewFollowUpItems: [String]? = nil,
        runtimeProvenance: PMRuntimeProvenance? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.decisionId = decisionId
        self.pmId = pmId
        self.title = title
        self.summary = summary
        self.recommendedAction = recommendedAction
        self.evidenceSummary = evidenceSummary
        self.ownerAsk = ownerAsk
        self.approvedNextStepSummary = approvedNextStepSummary
        self.sourceCommunicationMessageId = sourceCommunicationMessageId
        self.decisionType = decisionType
        self.status = status
        self.delegationId = delegationId
        self.charterId = charterId
        self.taskId = taskId
        self.findingId = findingId
        self.signalId = signalId
        self.proposalId = proposalId
        self.primaryStandingReportId = primaryStandingReportId
        self.standingReportIds = standingReportIds
        self.standingReviewDisposition = standingReviewDisposition
        self.standingReviewAnalystTitles = standingReviewAnalystTitles
        self.standingReviewAttentionItems = standingReviewAttentionItems
        self.standingReviewCandidateLongs = standingReviewCandidateLongs
        self.standingReviewCandidateShorts = standingReviewCandidateShorts
        self.standingReviewCandidateThemes = standingReviewCandidateThemes
        self.standingReviewFollowUpItems = standingReviewFollowUpItems
        self.runtimeProvenance = runtimeProvenance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PMApprovalRequestType: String, Codable, Sendable, CaseIterable {
    case proposalReview = "proposal_review"
    case portfolioAction = "portfolio_action"
    case liveOrderReview = "live_order_review"
    case operatingInstruction = "operating_instruction"
    case strategyChange = "strategy_change"
    case other
}

public enum PMApprovalRequestStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case resolved
    case withdrawn
    case stale
}

public enum PMApprovalRequestOwnerResponse: String, Codable, Sendable, CaseIterable {
    case approved
    case rejected
    case reviewed
}

public enum PMPaperPortfolioExecutionPendingStatus: String, Codable, Sendable, CaseIterable {
    case waitingForUsablePrices = "waiting_for_usable_prices"
}

public struct PMPaperPortfolioExecutionPendingState: Codable, Sendable, Equatable {
    public var status: PMPaperPortfolioExecutionPendingStatus
    public var missingPriceSymbols: [String]
    public var marketDataSubscriptionSymbols: [String]
    public var automaticRetryEnabled: Bool
    public var lastBlockerSummary: String
    public var lastBlockerDetail: String
    public var lastMarketDataSubscriptionRequestedAt: Date?
    public var lastRetryAttemptedAt: Date?
    public var updatedAt: Date

    public init(
        status: PMPaperPortfolioExecutionPendingStatus,
        missingPriceSymbols: [String],
        marketDataSubscriptionSymbols: [String],
        automaticRetryEnabled: Bool,
        lastBlockerSummary: String,
        lastBlockerDetail: String,
        lastMarketDataSubscriptionRequestedAt: Date? = nil,
        lastRetryAttemptedAt: Date? = nil,
        updatedAt: Date
    ) {
        self.status = status
        self.missingPriceSymbols = missingPriceSymbols
        self.marketDataSubscriptionSymbols = marketDataSubscriptionSymbols
        self.automaticRetryEnabled = automaticRetryEnabled
        self.lastBlockerSummary = lastBlockerSummary
        self.lastBlockerDetail = lastBlockerDetail
        self.lastMarketDataSubscriptionRequestedAt = lastMarketDataSubscriptionRequestedAt
        self.lastRetryAttemptedAt = lastRetryAttemptedAt
        self.updatedAt = updatedAt
    }
}

public enum PMPaperPortfolioExecutionLifecycleStatus: String, Codable, Sendable, CaseIterable {
    case waitingForUsablePrices = "waiting_for_usable_prices"
    case blocked
    case ordersAlreadyRecorded = "orders_already_recorded"
    case submitted
    case partiallySubmitted = "partially_submitted"
    case failed
}

public enum PMPaperPortfolioExecutionOrderPlanStatus: String, Codable, Sendable, CaseIterable {
    case notBuilt = "not_built"
    case blocked
    case waitingForUsablePrices = "waiting_for_usable_prices"
    case ready
    case skippedExistingOrders = "skipped_existing_orders"
    case submitted
    case partiallySubmitted = "partially_submitted"
    case failed
}

public struct PMLiveOrderReviewPayload: Codable, Sendable, Equatable {
    public var symbol: String
    public var side: OrderSide
    public var orderType: OrderType
    public var timeInForce: TimeInForce
    public var quantity: Int?
    public var notionalAmount: Decimal?
    public var limitPrice: Decimal?
    public var environment: Environment
    public var instructionSummary: String?

    public init(
        symbol: String,
        side: OrderSide,
        orderType: OrderType,
        timeInForce: TimeInForce,
        quantity: Int? = nil,
        notionalAmount: Decimal? = nil,
        limitPrice: Decimal? = nil,
        environment: Environment = .live,
        instructionSummary: String? = nil
    ) {
        self.symbol = symbol
        self.side = side
        self.orderType = orderType
        self.timeInForce = timeInForce
        self.quantity = quantity
        self.notionalAmount = notionalAmount
        self.limitPrice = limitPrice
        self.environment = environment
        self.instructionSummary = instructionSummary
    }
}

public enum PMLiveOrderReviewExecutionLifecycleStatus: String, Codable, Sendable, CaseIterable {
    case submitted
    case partiallyFilled = "partially_filled"
    case filled
    case canceled
    case rejected
    case expired
    case blocked
}

public struct PMLiveOrderReviewExecutionLifecycleState: Codable, Sendable, Equatable {
    public var status: PMLiveOrderReviewExecutionLifecycleStatus
    public var summary: String
    public var detail: String
    public var orderId: String?
    public var symbol: String
    public var side: OrderSide
    public var orderType: OrderType
    public var timeInForce: TimeInForce
    public var quantity: Int?
    public var filledQuantity: String?
    public var averageFillPrice: String?
    public var positionQuantity: String?
    public var openOrderStatus: String?
    public var completionFollowThroughMessageId: String?
    public var completionFollowThroughDeliveredAt: Date?
    public var updatedAt: Date

    public init(
        status: PMLiveOrderReviewExecutionLifecycleStatus,
        summary: String,
        detail: String,
        orderId: String? = nil,
        symbol: String,
        side: OrderSide,
        orderType: OrderType,
        timeInForce: TimeInForce,
        quantity: Int? = nil,
        filledQuantity: String? = nil,
        averageFillPrice: String? = nil,
        positionQuantity: String? = nil,
        openOrderStatus: String? = nil,
        completionFollowThroughMessageId: String? = nil,
        completionFollowThroughDeliveredAt: Date? = nil,
        updatedAt: Date
    ) {
        self.status = status
        self.summary = summary
        self.detail = detail
        self.orderId = orderId
        self.symbol = symbol
        self.side = side
        self.orderType = orderType
        self.timeInForce = timeInForce
        self.quantity = quantity
        self.filledQuantity = filledQuantity
        self.averageFillPrice = averageFillPrice
        self.positionQuantity = positionQuantity
        self.openOrderStatus = openOrderStatus
        self.completionFollowThroughMessageId = completionFollowThroughMessageId
        self.completionFollowThroughDeliveredAt = completionFollowThroughDeliveredAt
        self.updatedAt = updatedAt
    }
}

public extension PMLiveOrderReviewExecutionLifecycleStatus {
    var isTerminal: Bool {
        switch self {
        case .filled, .canceled, .rejected, .expired, .blocked:
            return true
        case .submitted, .partiallyFilled:
            return false
        }
    }
}

public struct PMPaperPortfolioExecutionLifecycleState: Codable, Sendable, Equatable {
    public var status: PMPaperPortfolioExecutionLifecycleStatus
    public var orderPlanStatus: PMPaperPortfolioExecutionOrderPlanStatus
    public var summary: String
    public var detail: String
    public var targetSymbols: [String]
    public var missingPriceSymbols: [String]
    public var blockedReasons: [PMExecutionRoutingBlockReason]
    public var lastRouteActionAt: Date?
    public var lastRetryAttemptedAt: Date?
    public var orderAttemptCount: Int
    public var acceptedOrderAttemptCount: Int
    public var failedOrderAttemptCount: Int
    public var updatedAt: Date

    public init(
        status: PMPaperPortfolioExecutionLifecycleStatus,
        orderPlanStatus: PMPaperPortfolioExecutionOrderPlanStatus,
        summary: String,
        detail: String,
        targetSymbols: [String] = [],
        missingPriceSymbols: [String] = [],
        blockedReasons: [PMExecutionRoutingBlockReason] = [],
        lastRouteActionAt: Date? = nil,
        lastRetryAttemptedAt: Date? = nil,
        orderAttemptCount: Int = 0,
        acceptedOrderAttemptCount: Int = 0,
        failedOrderAttemptCount: Int = 0,
        updatedAt: Date
    ) {
        self.status = status
        self.orderPlanStatus = orderPlanStatus
        self.summary = summary
        self.detail = detail
        self.targetSymbols = targetSymbols
        self.missingPriceSymbols = missingPriceSymbols
        self.blockedReasons = blockedReasons
        self.lastRouteActionAt = lastRouteActionAt
        self.lastRetryAttemptedAt = lastRetryAttemptedAt
        self.orderAttemptCount = orderAttemptCount
        self.acceptedOrderAttemptCount = acceptedOrderAttemptCount
        self.failedOrderAttemptCount = failedOrderAttemptCount
        self.updatedAt = updatedAt
    }
}

public struct PMStrategyChangePortfolioContextSnapshot: Codable, Sendable, Equatable {
    public var positionCount: Int
    public var grossExposure: Double
    public var netExposure: Double
    public var longExposure: Double
    public var shortExposure: Double
    public var longWeight: Double
    public var shortWeight: Double
    public var netWeight: Double
    public var largestPositionSymbol: String?
    public var largestPositionWeight: Double?
    public var capturedAt: Date

    public init(
        positionCount: Int,
        grossExposure: Double,
        netExposure: Double,
        longExposure: Double,
        shortExposure: Double,
        longWeight: Double,
        shortWeight: Double,
        netWeight: Double,
        largestPositionSymbol: String? = nil,
        largestPositionWeight: Double? = nil,
        capturedAt: Date
    ) {
        self.positionCount = positionCount
        self.grossExposure = grossExposure
        self.netExposure = netExposure
        self.longExposure = longExposure
        self.shortExposure = shortExposure
        self.longWeight = longWeight
        self.shortWeight = shortWeight
        self.netWeight = netWeight
        self.largestPositionSymbol = largestPositionSymbol
        self.largestPositionWeight = largestPositionWeight
        self.capturedAt = capturedAt
    }
}

public struct PMApprovalRequest: Codable, Sendable, Equatable, Identifiable {
    public var id: String { approvalRequestId }

    public var approvalRequestId: String
    public var pmId: String
    public var subject: String
    public var rationale: String
    public var requestedActionSummary: String?
    public var approvedNextStepSummary: String?
    public var rejectedNextStepSummary: String?
    public var reviewedNextStepSummary: String?
    public var sourceCommunicationMessageId: String?
    public var requestType: PMApprovalRequestType
    public var status: PMApprovalRequestStatus
    public var decisionId: String?
    public var delegationId: String?
    public var findingId: String?
    public var signalId: String?
    public var proposalId: String?
    public var sourceAnalystStrategyFollowUpCandidateId: String?
    public var sourceAnalystStrategyImplicationId: String?
    public var sourceAnalystMemoId: String?
    public var sourceAnalystEvidenceBundleId: String?
    public var strategyChangePortfolioContext: PMStrategyChangePortfolioContextSnapshot?
    public var resultingStrategyBriefId: String?
    public var liveOrderReview: PMLiveOrderReviewPayload?
    public var ownerResponse: PMApprovalRequestOwnerResponse?
    public var ownerRespondedAt: Date?
    public var lastExecutionRoutingAssessment: PMExecutionRoutingAssessment?
    public var liveOrderExecutionLifecycleState: PMLiveOrderReviewExecutionLifecycleState?
    public var paperPortfolioExecutionPendingState: PMPaperPortfolioExecutionPendingState?
    public var paperPortfolioExecutionLifecycleState: PMPaperPortfolioExecutionLifecycleState?
    public var ownerAcknowledgedAt: Date?
    public var ownerAcknowledgedBy: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        approvalRequestId: String,
        pmId: String,
        subject: String,
        rationale: String,
        requestedActionSummary: String? = nil,
        approvedNextStepSummary: String? = nil,
        rejectedNextStepSummary: String? = nil,
        reviewedNextStepSummary: String? = nil,
        sourceCommunicationMessageId: String? = nil,
        requestType: PMApprovalRequestType = .other,
        status: PMApprovalRequestStatus = .pending,
        decisionId: String? = nil,
        delegationId: String? = nil,
        findingId: String? = nil,
        signalId: String? = nil,
        proposalId: String? = nil,
        sourceAnalystStrategyFollowUpCandidateId: String? = nil,
        sourceAnalystStrategyImplicationId: String? = nil,
        sourceAnalystMemoId: String? = nil,
        sourceAnalystEvidenceBundleId: String? = nil,
        strategyChangePortfolioContext: PMStrategyChangePortfolioContextSnapshot? = nil,
        resultingStrategyBriefId: String? = nil,
        liveOrderReview: PMLiveOrderReviewPayload? = nil,
        ownerResponse: PMApprovalRequestOwnerResponse? = nil,
        ownerRespondedAt: Date? = nil,
        lastExecutionRoutingAssessment: PMExecutionRoutingAssessment? = nil,
        liveOrderExecutionLifecycleState: PMLiveOrderReviewExecutionLifecycleState? = nil,
        paperPortfolioExecutionPendingState: PMPaperPortfolioExecutionPendingState? = nil,
        paperPortfolioExecutionLifecycleState: PMPaperPortfolioExecutionLifecycleState? = nil,
        ownerAcknowledgedAt: Date? = nil,
        ownerAcknowledgedBy: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.approvalRequestId = approvalRequestId
        self.pmId = pmId
        self.subject = subject
        self.rationale = rationale
        self.requestedActionSummary = requestedActionSummary
        self.approvedNextStepSummary = approvedNextStepSummary
        self.rejectedNextStepSummary = rejectedNextStepSummary
        self.reviewedNextStepSummary = reviewedNextStepSummary
        self.sourceCommunicationMessageId = sourceCommunicationMessageId
        self.requestType = requestType
        self.status = status
        self.decisionId = decisionId
        self.delegationId = delegationId
        self.findingId = findingId
        self.signalId = signalId
        self.proposalId = proposalId
        self.sourceAnalystStrategyFollowUpCandidateId = sourceAnalystStrategyFollowUpCandidateId
        self.sourceAnalystStrategyImplicationId = sourceAnalystStrategyImplicationId
        self.sourceAnalystMemoId = sourceAnalystMemoId
        self.sourceAnalystEvidenceBundleId = sourceAnalystEvidenceBundleId
        self.strategyChangePortfolioContext = strategyChangePortfolioContext
        self.resultingStrategyBriefId = resultingStrategyBriefId
        self.liveOrderReview = liveOrderReview
        self.ownerResponse = ownerResponse
        self.ownerRespondedAt = ownerRespondedAt
        self.lastExecutionRoutingAssessment = lastExecutionRoutingAssessment
        self.liveOrderExecutionLifecycleState = liveOrderExecutionLifecycleState
        self.paperPortfolioExecutionPendingState = paperPortfolioExecutionPendingState
        self.paperPortfolioExecutionLifecycleState = paperPortfolioExecutionLifecycleState
        self.ownerAcknowledgedAt = ownerAcknowledgedAt
        self.ownerAcknowledgedBy = ownerAcknowledgedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PMCommunicationChannel: String, Codable, Sendable, CaseIterable {
    case inApp = "in_app"
    case telegram
    case genericRemote = "generic_remote"
    case mockTelegram = "mock_telegram"
}

public enum PMCommunicationSessionStatus: String, Codable, Sendable, CaseIterable {
    case active
    case closed
}

public struct PMCommunicationSession: Codable, Sendable, Equatable, Identifiable {
    public var id: String { sessionId }

    public var sessionId: String
    public var channel: PMCommunicationChannel
    public var externalConversationId: String?
    public var pmId: String?
    public var participantId: String?
    public var participantDisplayName: String?
    public var status: PMCommunicationSessionStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        sessionId: String,
        channel: PMCommunicationChannel,
        externalConversationId: String? = nil,
        pmId: String? = nil,
        participantId: String? = nil,
        participantDisplayName: String? = nil,
        status: PMCommunicationSessionStatus = .active,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.sessionId = sessionId
        self.channel = channel
        self.externalConversationId = externalConversationId
        self.pmId = pmId
        self.participantId = participantId
        self.participantDisplayName = participantDisplayName
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PMCommunicationMessageDirection: String, Codable, Sendable, CaseIterable {
    case incoming
    case outgoing
}

public enum PMCommunicationSenderRole: String, Codable, Sendable, CaseIterable {
    case owner
    case pm
    case system
}

public enum PMCommunicationPromotionTargetType: String, Codable, Sendable, CaseIterable {
    case notebookEntry = "notebook_entry"
    case instruction
    case decision
    case approvalRequest = "approval_request"
    case delegation
    case strategyBrief = "strategy_brief"
}

public struct PMCommunicationPromotion: Codable, Sendable, Equatable {
    public var targetType: PMCommunicationPromotionTargetType
    public var targetId: String
    public var promotedAt: Date

    public init(
        targetType: PMCommunicationPromotionTargetType,
        targetId: String,
        promotedAt: Date
    ) {
        self.targetType = targetType
        self.targetId = targetId
        self.promotedAt = promotedAt
    }
}

public enum PMConversationIntentClass: String, Codable, Sendable, CaseIterable {
    case instruction
    case correction
    case confirmation
    case refusal
    case clarification
    case followUpQuestion = "follow_up_question"
    case ambiguous
    case general
}

public enum PMConversationResolutionDisposition: String, Codable, Sendable, CaseIterable {
    case conversationOnly = "conversation_only"
    case workingUnderstandingOnly = "working_understanding_only"
    case durableChangeProposed = "durable_change_proposed"
    case durableApplyNow = "durable_apply_now"
    case clarificationRequired = "clarification_required"
}

public enum PMConversationDurableTargetType: String, Codable, Sendable, CaseIterable {
    case pmInstruction = "pm_instruction"
}

public enum PMConversationInstructionTargetKind: String, Codable, Sendable, CaseIterable {
    case operatingInstruction = "operating_instruction"
    case workingPortfolioDefinition = "working_portfolio_definition"
}

public enum PMConversationOperatingTruthKind: String, Codable, Sendable, CaseIterable {
    case operatingInstruction = "operating_instruction"
    case workingPortfolioDefinition = "working_portfolio_definition"
}

public enum PMConversationPendingAskKind: String, Codable, Sendable, CaseIterable {
    case yesNoConfirmation = "yes_no_confirmation"
    case clarification
}

public struct PMConversationPendingAskState: Codable, Sendable, Equatable {
    public var kind: PMConversationPendingAskKind
    public var promptSummary: String
    public var workingUnderstandingSummary: String?
    public var operatingTruthKind: PMConversationOperatingTruthKind?
    public var operatingTruthSummary: String?
    public var durableTargetType: PMConversationDurableTargetType?
    public var instructionTargetKind: PMConversationInstructionTargetKind?
    public var durableTitle: String?
    public var durableBody: String?

    public init(
        kind: PMConversationPendingAskKind,
        promptSummary: String,
        workingUnderstandingSummary: String? = nil,
        operatingTruthKind: PMConversationOperatingTruthKind? = nil,
        operatingTruthSummary: String? = nil,
        durableTargetType: PMConversationDurableTargetType? = nil,
        instructionTargetKind: PMConversationInstructionTargetKind? = nil,
        durableTitle: String? = nil,
        durableBody: String? = nil
    ) {
        self.kind = kind
        self.promptSummary = promptSummary
        self.workingUnderstandingSummary = workingUnderstandingSummary
        self.operatingTruthKind = operatingTruthKind
        self.operatingTruthSummary = operatingTruthSummary
        self.durableTargetType = durableTargetType
        self.instructionTargetKind = instructionTargetKind
        self.durableTitle = durableTitle
        self.durableBody = durableBody
    }
}

public struct PMConversationResolutionState: Codable, Sendable, Equatable {
    public var intentClass: PMConversationIntentClass
    public var disposition: PMConversationResolutionDisposition
    public var workingUnderstandingSummary: String?
    public var ambiguitySummary: String?
    public var operatingTruthKind: PMConversationOperatingTruthKind?
    public var operatingTruthSummary: String?
    public var operatingTruthBody: String?
    public var pendingAsk: PMConversationPendingAskState?
    public var durableTargetType: PMConversationDurableTargetType?
    public var instructionTargetKind: PMConversationInstructionTargetKind?
    public var durableTitle: String?
    public var durableBody: String?
    public var durableTargetId: String?
    public var sourceMessageIds: [String]

    public init(
        intentClass: PMConversationIntentClass,
        disposition: PMConversationResolutionDisposition,
        workingUnderstandingSummary: String? = nil,
        ambiguitySummary: String? = nil,
        operatingTruthKind: PMConversationOperatingTruthKind? = nil,
        operatingTruthSummary: String? = nil,
        operatingTruthBody: String? = nil,
        pendingAsk: PMConversationPendingAskState? = nil,
        durableTargetType: PMConversationDurableTargetType? = nil,
        instructionTargetKind: PMConversationInstructionTargetKind? = nil,
        durableTitle: String? = nil,
        durableBody: String? = nil,
        durableTargetId: String? = nil,
        sourceMessageIds: [String] = []
    ) {
        self.intentClass = intentClass
        self.disposition = disposition
        self.workingUnderstandingSummary = workingUnderstandingSummary
        self.ambiguitySummary = ambiguitySummary
        self.operatingTruthKind = operatingTruthKind
        self.operatingTruthSummary = operatingTruthSummary
        self.operatingTruthBody = operatingTruthBody
        self.pendingAsk = pendingAsk
        self.durableTargetType = durableTargetType
        self.instructionTargetKind = instructionTargetKind
        self.durableTitle = durableTitle
        self.durableBody = durableBody
        self.durableTargetId = durableTargetId
        self.sourceMessageIds = sourceMessageIds
    }
}

public enum PMConversationActionType: String, Codable, Sendable, CaseIterable {
    case answerOnly = "answer_only"
    case askFollowUp = "ask_follow_up"
    case updateConversationWorkingTruth = "update_conversation_working_truth"
    case updateWatchlistSymbols = "update_watchlist_symbols"
    case upsertPMInstruction = "upsert_pm_instruction"
    case upsertPMMandate = "upsert_pm_mandate"
    case upsertPMNotebookEntry = "upsert_pm_notebook_entry"
    case launchAdHocAnalystDelegation = "launch_ad_hoc_analyst_delegation"
    case updateAnalystCharter = "update_analyst_charter"
    case updateRuntimeSetting = "update_runtime_setting"
    case createPMDecision = "create_pm_decision"
    case createPMApprovalRequest = "create_pm_approval_request"
    case approvePMApprovalRequest = "approve_pm_approval_request"
    case createOrUpdateProposal = "create_or_update_proposal"
    case routeGovernedExecutionNextStep = "route_governed_execution_next_step"
}

public enum PMConversationRuntimeSettingScope: String, Codable, Sendable, CaseIterable {
    case pm
    case recentNewsAnalyst = "recent_news_analyst"
    case standingBench = "standing_bench"
}

public enum PMConversationWatchlistOperation: String, Codable, Sendable, CaseIterable {
    case add
    case remove
}

public struct PMConversationAgentSkillReferenceIntent: Codable, Sendable, Equatable, Identifiable {
    public var id: String { skillId }

    public var skillId: String
    public var requirement: AgentSkillReferenceRequirement
    public var rationale: String?

    public init(
        skillId: String,
        requirement: AgentSkillReferenceRequirement = .recommended,
        rationale: String? = nil
    ) {
        self.skillId = skillId
        self.requirement = requirement
        self.rationale = rationale
    }
}

public struct PMConversationActionIntent: Codable, Sendable, Equatable {
    public var actionType: PMConversationActionType
    public var summary: String
    public var title: String?
    public var body: String?
    public var detail: String?
    public var targetId: String?
    public var charterId: String?
    public var proposalSymbol: String?
    public var proposalSide: OrderSide?
    public var proposalQuantity: Int?
    public var liveOrderSymbol: String?
    public var liveOrderSide: OrderSide?
    public var liveOrderQuantity: Int?
    public var liveOrderNotionalAmount: Decimal?
    public var liveOrderType: OrderType?
    public var liveOrderTimeInForce: TimeInForce?
    public var liveOrderLimitPrice: Decimal?
    public var runtimeSettingScope: PMConversationRuntimeSettingScope?
    public var runtimeIdentifier: String?
    public var reasoningMode: AnalystRuntimeReasoningMode?
    public var requestedOutputs: [PMDelegationRequestedOutput]
    public var decisionType: PMDecisionType?
    public var requestType: PMApprovalRequestType?
    public var instructionTargetKind: PMConversationInstructionTargetKind?
    public var operatingTruthKind: PMConversationOperatingTruthKind?
    public var watchlistOperation: PMConversationWatchlistOperation?
    public var watchlistSymbols: [String]
    public var selectedSkillReferences: [PMConversationAgentSkillReferenceIntent]
    public var sourceMessageIds: [String]

    public init(
        actionType: PMConversationActionType,
        summary: String,
        title: String? = nil,
        body: String? = nil,
        detail: String? = nil,
        targetId: String? = nil,
        charterId: String? = nil,
        proposalSymbol: String? = nil,
        proposalSide: OrderSide? = nil,
        proposalQuantity: Int? = nil,
        liveOrderSymbol: String? = nil,
        liveOrderSide: OrderSide? = nil,
        liveOrderQuantity: Int? = nil,
        liveOrderNotionalAmount: Decimal? = nil,
        liveOrderType: OrderType? = nil,
        liveOrderTimeInForce: TimeInForce? = nil,
        liveOrderLimitPrice: Decimal? = nil,
        runtimeSettingScope: PMConversationRuntimeSettingScope? = nil,
        runtimeIdentifier: String? = nil,
        reasoningMode: AnalystRuntimeReasoningMode? = nil,
        requestedOutputs: [PMDelegationRequestedOutput] = [],
        decisionType: PMDecisionType? = nil,
        requestType: PMApprovalRequestType? = nil,
        instructionTargetKind: PMConversationInstructionTargetKind? = nil,
        operatingTruthKind: PMConversationOperatingTruthKind? = nil,
        watchlistOperation: PMConversationWatchlistOperation? = nil,
        watchlistSymbols: [String] = [],
        selectedSkillReferences: [PMConversationAgentSkillReferenceIntent] = [],
        sourceMessageIds: [String] = []
    ) {
        self.actionType = actionType
        self.summary = summary
        self.title = title
        self.body = body
        self.detail = detail
        self.targetId = targetId
        self.charterId = charterId
        self.proposalSymbol = proposalSymbol
        self.proposalSide = proposalSide
        self.proposalQuantity = proposalQuantity
        self.liveOrderSymbol = liveOrderSymbol
        self.liveOrderSide = liveOrderSide
        self.liveOrderQuantity = liveOrderQuantity
        self.liveOrderNotionalAmount = liveOrderNotionalAmount
        self.liveOrderType = liveOrderType
        self.liveOrderTimeInForce = liveOrderTimeInForce
        self.liveOrderLimitPrice = liveOrderLimitPrice
        self.runtimeSettingScope = runtimeSettingScope
        self.runtimeIdentifier = runtimeIdentifier
        self.reasoningMode = reasoningMode
        self.requestedOutputs = requestedOutputs
        self.decisionType = decisionType
        self.requestType = requestType
        self.instructionTargetKind = instructionTargetKind
        self.operatingTruthKind = operatingTruthKind
        self.watchlistOperation = watchlistOperation
        self.watchlistSymbols = watchlistSymbols
        self.selectedSkillReferences = selectedSkillReferences
        self.sourceMessageIds = sourceMessageIds
    }

    enum CodingKeys: String, CodingKey {
        case actionType
        case summary
        case title
        case body
        case detail
        case targetId
        case charterId
        case proposalSymbol
        case proposalSide
        case proposalQuantity
        case liveOrderSymbol
        case liveOrderSide
        case liveOrderQuantity
        case liveOrderNotionalAmount
        case liveOrderType
        case liveOrderTimeInForce
        case liveOrderLimitPrice
        case runtimeSettingScope
        case runtimeIdentifier
        case reasoningMode
        case requestedOutputs
        case decisionType
        case requestType
        case instructionTargetKind
        case operatingTruthKind
        case watchlistOperation
        case watchlistSymbols
        case selectedSkillReferences
        case sourceMessageIds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        actionType = try container.decode(PMConversationActionType.self, forKey: .actionType)
        summary = try container.decode(String.self, forKey: .summary)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        targetId = try container.decodeIfPresent(String.self, forKey: .targetId)
        charterId = try container.decodeIfPresent(String.self, forKey: .charterId)
        proposalSymbol = try container.decodeIfPresent(String.self, forKey: .proposalSymbol)
        proposalSide = try container.decodeIfPresent(OrderSide.self, forKey: .proposalSide)
        proposalQuantity = try container.decodeIfPresent(Int.self, forKey: .proposalQuantity)
        liveOrderSymbol = try container.decodeIfPresent(String.self, forKey: .liveOrderSymbol)
        liveOrderSide = try container.decodeIfPresent(OrderSide.self, forKey: .liveOrderSide)
        liveOrderQuantity = try container.decodeIfPresent(Int.self, forKey: .liveOrderQuantity)
        liveOrderNotionalAmount = try container.decodeIfPresent(Decimal.self, forKey: .liveOrderNotionalAmount)
        liveOrderType = try container.decodeIfPresent(OrderType.self, forKey: .liveOrderType)
        liveOrderTimeInForce = try container.decodeIfPresent(TimeInForce.self, forKey: .liveOrderTimeInForce)
        liveOrderLimitPrice = try container.decodeIfPresent(Decimal.self, forKey: .liveOrderLimitPrice)
        runtimeSettingScope = try container.decodeIfPresent(
            PMConversationRuntimeSettingScope.self,
            forKey: .runtimeSettingScope
        )
        runtimeIdentifier = try container.decodeIfPresent(String.self, forKey: .runtimeIdentifier)
        reasoningMode = try container.decodeIfPresent(AnalystRuntimeReasoningMode.self, forKey: .reasoningMode)
        requestedOutputs = try container.decodeIfPresent(
            [PMDelegationRequestedOutput].self,
            forKey: .requestedOutputs
        ) ?? []
        decisionType = try container.decodeIfPresent(PMDecisionType.self, forKey: .decisionType)
        requestType = try container.decodeIfPresent(PMApprovalRequestType.self, forKey: .requestType)
        instructionTargetKind = try container.decodeIfPresent(
            PMConversationInstructionTargetKind.self,
            forKey: .instructionTargetKind
        )
        operatingTruthKind = try container.decodeIfPresent(
            PMConversationOperatingTruthKind.self,
            forKey: .operatingTruthKind
        )
        watchlistOperation = try container.decodeIfPresent(
            PMConversationWatchlistOperation.self,
            forKey: .watchlistOperation
        )
        watchlistSymbols = try container.decodeIfPresent([String].self, forKey: .watchlistSymbols) ?? []
        selectedSkillReferences = try container.decodeIfPresent(
            [PMConversationAgentSkillReferenceIntent].self,
            forKey: .selectedSkillReferences
        ) ?? []
        sourceMessageIds = try container.decodeIfPresent([String].self, forKey: .sourceMessageIds) ?? []
    }
}

public struct PMConversationActionPlan: Codable, Sendable, Equatable {
    public var summary: String
    public var actions: [PMConversationActionIntent]

    public init(
        summary: String,
        actions: [PMConversationActionIntent]
    ) {
        self.summary = summary
        self.actions = actions
    }
}

public struct PMCommunicationMessage: Codable, Sendable, Equatable, Identifiable {
    public var id: String { messageId }

    public var messageId: String
    public var sessionId: String
    public var direction: PMCommunicationMessageDirection
    public var senderRole: PMCommunicationSenderRole
    public var senderId: String?
    public var body: String
    public var sentAt: Date
    public var replyToMessageId: String?
    public var promotion: PMCommunicationPromotion?
    public var conversationResolution: PMConversationResolutionState?
    public var conversationActionPlan: PMConversationActionPlan?
    public var runtimeProvenance: PMRuntimeProvenance?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        messageId: String,
        sessionId: String,
        direction: PMCommunicationMessageDirection,
        senderRole: PMCommunicationSenderRole,
        senderId: String? = nil,
        body: String,
        sentAt: Date,
        replyToMessageId: String? = nil,
        promotion: PMCommunicationPromotion? = nil,
        conversationResolution: PMConversationResolutionState? = nil,
        conversationActionPlan: PMConversationActionPlan? = nil,
        runtimeProvenance: PMRuntimeProvenance? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.messageId = messageId
        self.sessionId = sessionId
        self.direction = direction
        self.senderRole = senderRole
        self.senderId = senderId
        self.body = body
        self.sentAt = sentAt
        self.replyToMessageId = replyToMessageId
        self.promotion = promotion
        self.conversationResolution = conversationResolution
        self.conversationActionPlan = conversationActionPlan
        self.runtimeProvenance = runtimeProvenance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PMDelegationRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String { delegationId }

    public var delegationId: String
    public var pmId: String
    public var analystId: String
    public var charterId: String
    public var taskId: String?
    public var title: String
    public var rationale: String
    public var taskingBrief: PMTaskingBrief?
    public var requestedOutputs: [PMDelegationRequestedOutput]
    public var status: PMDelegationStatus
    public var parentDelegationId: String?
    public var sourceFollowUpActionId: String?
    public var sourceCommunicationSessionId: String?
    public var sourceCommunicationMessageId: String?
    public var runtimePolicyOverride: AnalystRuntimePolicy?
    public var lastLaunch: PMDelegationLastLaunch?
    public var lastRuntimeProvenance: AnalystRuntimeProvenance?
    public var issueResolution: PMDelegationIssueResolution?
    public var followThrough: PMDelegationFollowThrough?
    public var followUpActions: [PMAnalystFollowUpAction]
    public var linkedFindingIDs: [String]
    public var linkedSignalIDs: [String]
    public var linkedProposalIDs: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        delegationId: String,
        pmId: String,
        analystId: String,
        charterId: String,
        taskId: String? = nil,
        title: String,
        rationale: String,
        taskingBrief: PMTaskingBrief? = nil,
        requestedOutputs: [PMDelegationRequestedOutput] = [],
        status: PMDelegationStatus = .issued,
        parentDelegationId: String? = nil,
        sourceFollowUpActionId: String? = nil,
        sourceCommunicationSessionId: String? = nil,
        sourceCommunicationMessageId: String? = nil,
        runtimePolicyOverride: AnalystRuntimePolicy? = nil,
        lastLaunch: PMDelegationLastLaunch? = nil,
        lastRuntimeProvenance: AnalystRuntimeProvenance? = nil,
        issueResolution: PMDelegationIssueResolution? = nil,
        followThrough: PMDelegationFollowThrough? = nil,
        followUpActions: [PMAnalystFollowUpAction] = [],
        linkedFindingIDs: [String] = [],
        linkedSignalIDs: [String] = [],
        linkedProposalIDs: [String] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.delegationId = delegationId
        self.pmId = pmId
        self.analystId = analystId
        self.charterId = charterId
        self.taskId = taskId
        self.title = title
        self.rationale = rationale
        self.taskingBrief = taskingBrief
        self.requestedOutputs = requestedOutputs
        self.status = status
        self.parentDelegationId = parentDelegationId
        self.sourceFollowUpActionId = sourceFollowUpActionId
        self.sourceCommunicationSessionId = sourceCommunicationSessionId
        self.sourceCommunicationMessageId = sourceCommunicationMessageId
        self.runtimePolicyOverride = runtimePolicyOverride
        self.lastLaunch = lastLaunch
        self.lastRuntimeProvenance = lastRuntimeProvenance
        self.issueResolution = issueResolution
        self.followThrough = followThrough
        self.followUpActions = followUpActions
        self.linkedFindingIDs = linkedFindingIDs
        self.linkedSignalIDs = linkedSignalIDs
        self.linkedProposalIDs = linkedProposalIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case delegationId
        case pmId
        case analystId
        case charterId
        case taskId
        case title
        case rationale
        case taskingBrief
        case requestedOutputs
        case status
        case parentDelegationId
        case sourceFollowUpActionId
        case sourceCommunicationSessionId
        case sourceCommunicationMessageId
        case runtimePolicyOverride
        case lastLaunch
        case lastRuntimeProvenance
        case issueResolution
        case followThrough
        case followUpActions
        case linkedFindingIDs
        case linkedSignalIDs
        case linkedProposalIDs
        case createdAt
        case updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        delegationId = try container.decode(String.self, forKey: .delegationId)
        pmId = try container.decode(String.self, forKey: .pmId)
        analystId = try container.decode(String.self, forKey: .analystId)
        charterId = try container.decode(String.self, forKey: .charterId)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        title = try container.decode(String.self, forKey: .title)
        rationale = try container.decode(String.self, forKey: .rationale)
        taskingBrief = try container.decodeIfPresent(PMTaskingBrief.self, forKey: .taskingBrief)
        requestedOutputs = try container.decodeIfPresent([PMDelegationRequestedOutput].self, forKey: .requestedOutputs) ?? []
        status = try container.decodeIfPresent(PMDelegationStatus.self, forKey: .status) ?? .issued
        parentDelegationId = try container.decodeIfPresent(String.self, forKey: .parentDelegationId)
        sourceFollowUpActionId = try container.decodeIfPresent(String.self, forKey: .sourceFollowUpActionId)
        sourceCommunicationSessionId = try container.decodeIfPresent(String.self, forKey: .sourceCommunicationSessionId)
        sourceCommunicationMessageId = try container.decodeIfPresent(String.self, forKey: .sourceCommunicationMessageId)
        runtimePolicyOverride = try container.decodeIfPresent(AnalystRuntimePolicy.self, forKey: .runtimePolicyOverride)
        lastLaunch = try container.decodeIfPresent(PMDelegationLastLaunch.self, forKey: .lastLaunch)
        lastRuntimeProvenance = try container.decodeIfPresent(AnalystRuntimeProvenance.self, forKey: .lastRuntimeProvenance)
        issueResolution = try container.decodeIfPresent(PMDelegationIssueResolution.self, forKey: .issueResolution)
        followThrough = try container.decodeIfPresent(PMDelegationFollowThrough.self, forKey: .followThrough)
        followUpActions = try container.decodeIfPresent([PMAnalystFollowUpAction].self, forKey: .followUpActions) ?? []
        linkedFindingIDs = try container.decodeIfPresent([String].self, forKey: .linkedFindingIDs) ?? []
        linkedSignalIDs = try container.decodeIfPresent([String].self, forKey: .linkedSignalIDs) ?? []
        linkedProposalIDs = try container.decodeIfPresent([String].self, forKey: .linkedProposalIDs) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(delegationId, forKey: .delegationId)
        try container.encode(pmId, forKey: .pmId)
        try container.encode(analystId, forKey: .analystId)
        try container.encode(charterId, forKey: .charterId)
        try container.encodeIfPresent(taskId, forKey: .taskId)
        try container.encode(title, forKey: .title)
        try container.encode(rationale, forKey: .rationale)
        try container.encodeIfPresent(taskingBrief, forKey: .taskingBrief)
        try container.encode(requestedOutputs, forKey: .requestedOutputs)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(parentDelegationId, forKey: .parentDelegationId)
        try container.encodeIfPresent(sourceFollowUpActionId, forKey: .sourceFollowUpActionId)
        try container.encodeIfPresent(sourceCommunicationSessionId, forKey: .sourceCommunicationSessionId)
        try container.encodeIfPresent(sourceCommunicationMessageId, forKey: .sourceCommunicationMessageId)
        try container.encodeIfPresent(runtimePolicyOverride, forKey: .runtimePolicyOverride)
        try container.encodeIfPresent(lastLaunch, forKey: .lastLaunch)
        try container.encodeIfPresent(lastRuntimeProvenance, forKey: .lastRuntimeProvenance)
        try container.encodeIfPresent(issueResolution, forKey: .issueResolution)
        try container.encodeIfPresent(followThrough, forKey: .followThrough)
        try container.encode(followUpActions, forKey: .followUpActions)
        try container.encode(linkedFindingIDs, forKey: .linkedFindingIDs)
        try container.encode(linkedSignalIDs, forKey: .linkedSignalIDs)
        try container.encode(linkedProposalIDs, forKey: .linkedProposalIDs)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
