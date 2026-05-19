import Foundation

public struct PMReviewMemoSection: Sendable, Equatable, Identifiable {
    public let title: String
    public let body: String

    public var id: String { title }

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public struct PMInboxApprovalRoutingPresentation: Sendable, Equatable {
    public let ownerActionableInCommandCenter: Bool
    public let summary: String
    public let transportSummary: String?
    public let ownerActionControlsVisible: Bool
    public let telegramSendControlVisible: Bool

    public init(
        ownerActionableInCommandCenter: Bool,
        summary: String,
        transportSummary: String?,
        ownerActionControlsVisible: Bool,
        telegramSendControlVisible: Bool
    ) {
        self.ownerActionableInCommandCenter = ownerActionableInCommandCenter
        self.summary = summary
        self.transportSummary = transportSummary
        self.ownerActionControlsVisible = ownerActionControlsVisible
        self.telegramSendControlVisible = telegramSendControlVisible
    }
}

public struct PMApprovalRequestMemoPresentation: Sendable, Equatable {
    public let initiativePosture: PMInitiativePosture
    public let initiativeSummary: String
    public let coherence: PMEventCoherencePresentation
    public let closure: PMRecommendationClosurePresentation
    public let requestedAction: String
    public let whyNow: String
    public let recommendation: String?
    public let strategicAlignment: String?
    public let portfolioContextSummary: String?
    public let evidenceSummary: String?
    public let uncertaintySummary: String?
    public let approvedNextStep: String?
    public let rejectedNextStep: String?
    public let reviewedNextStep: String?
    public let ownerActionMeaning: String
    public let boundaryNote: String
    public let supportingSections: [PMReviewMemoSection]

    public init(
        initiativePosture: PMInitiativePosture,
        initiativeSummary: String,
        coherence: PMEventCoherencePresentation,
        closure: PMRecommendationClosurePresentation,
        requestedAction: String,
        whyNow: String,
        recommendation: String?,
        strategicAlignment: String?,
        portfolioContextSummary: String?,
        evidenceSummary: String?,
        uncertaintySummary: String?,
        approvedNextStep: String?,
        rejectedNextStep: String?,
        reviewedNextStep: String?,
        ownerActionMeaning: String,
        boundaryNote: String,
        supportingSections: [PMReviewMemoSection]
    ) {
        self.initiativePosture = initiativePosture
        self.initiativeSummary = initiativeSummary
        self.coherence = coherence
        self.closure = closure
        self.requestedAction = requestedAction
        self.whyNow = whyNow
        self.recommendation = recommendation
        self.strategicAlignment = strategicAlignment
        self.portfolioContextSummary = portfolioContextSummary
        self.evidenceSummary = evidenceSummary
        self.uncertaintySummary = uncertaintySummary
        self.approvedNextStep = approvedNextStep
        self.rejectedNextStep = rejectedNextStep
        self.reviewedNextStep = reviewedNextStep
        self.ownerActionMeaning = ownerActionMeaning
        self.boundaryNote = boundaryNote
        self.supportingSections = supportingSections
    }
}

public func makePMInboxApprovalRoutingPresentation(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord? = nil,
    telegramParticipantDisplayName: String? = nil
) -> PMInboxApprovalRoutingPresentation {
    let closure = makePMRecommendationClosurePresentation(
        request: request,
        linkedDecision: linkedDecision
    )
    let ownerActionableInCommandCenter = makeOwnerActionableApprovalRequests(
        approvalRequests: [request],
        decisions: linkedDecision.map { [$0] } ?? []
    ).isEmpty == false
    let summary: String
    if closure.status == .backgroundPMReview {
        summary = "This standing-review item remains background PM work by default. Keep it here for traceability and PM judgment unless the PM explicitly escalates a separate owner-facing ask."
    } else if ownerActionableInCommandCenter {
        summary = "This request is currently owner-actionable. Resolve it from Command Center > Your Decisions so the owner-facing desk remains the single place for live action."
    } else {
        summary = "This request remains available here for traceability and memo drill-down only. It is not currently surfaced as a live owner decision in Command Center."
    }

    let transportSummary = telegramParticipantDisplayName.map {
        "Telegram continuation remains transport only. Session target: \($0)."
    }

    return PMInboxApprovalRoutingPresentation(
        ownerActionableInCommandCenter: ownerActionableInCommandCenter,
        summary: summary,
        transportSummary: transportSummary,
        ownerActionControlsVisible: false,
        telegramSendControlVisible: false
    )
}

public struct PMDecisionMemoPresentation: Sendable, Equatable {
    public let initiativePosture: PMInitiativePosture
    public let initiativeSummary: String
    public let coherence: PMEventCoherencePresentation
    public let closure: PMRecommendationClosurePresentation
    public let recommendation: String
    public let whyNow: String
    public let strategicAlignment: String?
    public let recommendedAction: String?
    public let evidenceSummary: String?
    public let uncertaintySummary: String?
    public let ownerAsk: String?
    public let approvedNextStep: String?
    public let boundaryNote: String
    public let relationshipNote: String?
    public let supportingSections: [PMReviewMemoSection]

    public init(
        initiativePosture: PMInitiativePosture,
        initiativeSummary: String,
        coherence: PMEventCoherencePresentation,
        closure: PMRecommendationClosurePresentation,
        recommendation: String,
        whyNow: String,
        strategicAlignment: String?,
        recommendedAction: String?,
        evidenceSummary: String?,
        uncertaintySummary: String?,
        ownerAsk: String?,
        approvedNextStep: String?,
        boundaryNote: String,
        relationshipNote: String?,
        supportingSections: [PMReviewMemoSection]
    ) {
        self.initiativePosture = initiativePosture
        self.initiativeSummary = initiativeSummary
        self.coherence = coherence
        self.closure = closure
        self.recommendation = recommendation
        self.whyNow = whyNow
        self.strategicAlignment = strategicAlignment
        self.recommendedAction = recommendedAction
        self.evidenceSummary = evidenceSummary
        self.uncertaintySummary = uncertaintySummary
        self.ownerAsk = ownerAsk
        self.approvedNextStep = approvedNextStep
        self.boundaryNote = boundaryNote
        self.relationshipNote = relationshipNote
        self.supportingSections = supportingSections
    }
}

public struct RecentNewsWakeUpPresentation: Sendable, Equatable {
    public let isRecentNewsWakeUp: Bool
    public let originLabel: String
    public let rowSummary: String
    public let rowAffectedNames: String?
    public let rowNextStep: String?
    public let whatHappened: String
    public let whyItMatters: String
    public let strategyRelevance: String?
    public let recommendedNextStep: String
    public let pmActionGuidance: String
    public let affectedHoldings: [String]
    public let affectedWatchlistOnly: [String]

    public init(
        isRecentNewsWakeUp: Bool,
        originLabel: String,
        rowSummary: String,
        rowAffectedNames: String?,
        rowNextStep: String?,
        whatHappened: String,
        whyItMatters: String,
        strategyRelevance: String?,
        recommendedNextStep: String,
        pmActionGuidance: String,
        affectedHoldings: [String],
        affectedWatchlistOnly: [String]
    ) {
        self.isRecentNewsWakeUp = isRecentNewsWakeUp
        self.originLabel = originLabel
        self.rowSummary = rowSummary
        self.rowAffectedNames = rowAffectedNames
        self.rowNextStep = rowNextStep
        self.whatHappened = whatHappened
        self.whyItMatters = whyItMatters
        self.strategyRelevance = strategyRelevance
        self.recommendedNextStep = recommendedNextStep
        self.pmActionGuidance = pmActionGuidance
        self.affectedHoldings = affectedHoldings
        self.affectedWatchlistOnly = affectedWatchlistOnly
    }
}

public struct PortfolioRiskWakeUpPresentation: Sendable, Equatable {
    public let isPortfolioRiskWakeUp: Bool
    public let originLabel: String
    public let rowSummary: String
    public let rowAffectedNames: String?
    public let rowNextStep: String?
    public let whatHappened: String
    public let whatChanged: String
    public let whyItMattersNow: String
    public let recommendedNextStep: String
    public let pmActionGuidance: String
    public let affectedHoldings: [String]
    public let affectedWatchlistOnly: [String]

    public init(
        isPortfolioRiskWakeUp: Bool,
        originLabel: String,
        rowSummary: String,
        rowAffectedNames: String?,
        rowNextStep: String?,
        whatHappened: String,
        whatChanged: String,
        whyItMattersNow: String,
        recommendedNextStep: String,
        pmActionGuidance: String,
        affectedHoldings: [String],
        affectedWatchlistOnly: [String]
    ) {
        self.isPortfolioRiskWakeUp = isPortfolioRiskWakeUp
        self.originLabel = originLabel
        self.rowSummary = rowSummary
        self.rowAffectedNames = rowAffectedNames
        self.rowNextStep = rowNextStep
        self.whatHappened = whatHappened
        self.whatChanged = whatChanged
        self.whyItMattersNow = whyItMattersNow
        self.recommendedNextStep = recommendedNextStep
        self.pmActionGuidance = pmActionGuidance
        self.affectedHoldings = affectedHoldings
        self.affectedWatchlistOnly = affectedWatchlistOnly
    }
}

public func pmApprovalRequestTypeDisplayTitle(_ type: PMApprovalRequestType) -> String {
    switch type {
    case .proposalReview:
        return "Proposal Review"
    case .portfolioAction:
        return "Portfolio Action"
    case .liveOrderReview:
        return "Live Order Review"
    case .operatingInstruction:
        return "Operating Instruction"
    case .strategyChange:
        return "Strategy Change"
    case .other:
        return "PM Review"
    }
}

public func pmApprovalRequestStatusDisplayTitle(_ status: PMApprovalRequestStatus) -> String {
    switch status {
    case .pending:
        return "Pending"
    case .resolved:
        return "Resolved"
    case .withdrawn:
        return "Withdrawn"
    case .stale:
        return "Stale"
    }
}

public func pmDecisionTypeDisplayTitle(_ type: PMDecisionType) -> String {
    switch type {
    case .recommendation:
        return "Recommendation"
    case .escalation:
        return "Escalation"
    case .readinessAssessment:
        return "Readiness Assessment"
    case .other:
        return "PM Decision"
    }
}

public func pmDecisionStatusDisplayTitle(_ status: PMDecisionStatus) -> String {
    switch status {
    case .active:
        return "Active"
    case .superseded:
        return "Superseded"
    case .withdrawn:
        return "Withdrawn"
    }
}

public func makePMApprovalRequestMemoPresentation(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord? = nil,
    executionAssessment: PMExecutionRoutingAssessment? = nil,
    linkedDelegation: PMDelegationRecord? = nil,
    linkedDelegationObservability: PMDelegationObservabilitySummary? = nil,
    linkedTask: AnalystTask? = nil,
    linkedFinding: AnalystFinding? = nil,
    linkedCommunicationMessage: PMCommunicationMessage? = nil,
    linkedMemo: AnalystMemo? = nil,
    strategyBrief: PortfolioStrategyBrief? = nil
) -> PMApprovalRequestMemoPresentation {
    var supportingSections: [PMReviewMemoSection] = []
    let initiative = classifyPMApprovalInitiative(
        request: request,
        linkedDecision: linkedDecision
    )
    let coherence = makePMEventCoherencePresentation(
        posture: initiative.posture,
        initiativeSummary: initiative.summary
    )
    let closure = makePMRecommendationClosurePresentation(
        request: request,
        linkedDecision: linkedDecision,
        executionAssessment: executionAssessment,
        linkedDelegationObservability: linkedDelegationObservability
    )
    let backgroundStandingReview = closure.status == .backgroundPMReview

    if let linkedFinding {
        let findingBody = linkedFinding.thesis.isEmpty ? linkedFinding.summary : linkedFinding.thesis
        supportingSections.append(
            PMReviewMemoSection(
                title: "Supporting Finding",
                body: findingBody
            )
        )
    }

    if let checkpointSummary = linkedTask?.checkpoint?.summary ?? linkedTask?.lastCheckpointSummary,
       !checkpointSummary.isEmpty {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Latest Analyst Update",
                body: checkpointSummary
            )
        )
    }

    if let linkedDelegation, let linkedDelegationObservability {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Current Delegation State",
                body: pmDelegationMemoStateText(
                    delegation: linkedDelegation,
                    summary: linkedDelegationObservability
                )
            )
        )
    }

    if let linkedCommunicationMessage {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Related PM/User Communication",
                body: linkedCommunicationMessage.body
            )
        )
    }

    if let liveOrderReview = request.liveOrderReview {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Live Order Review Payload",
                body: pmLiveOrderReviewPayloadText(liveOrderReview)
            )
        )
    }

    if let lifecycle = request.liveOrderExecutionLifecycleState {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Live Order Lifecycle",
                body: pmLiveOrderReviewLifecycleText(lifecycle)
            )
        )
    }

    if let executionAssessment {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Governed Route Status",
                body: pmExecutionRoutingStatusText(executionAssessment)
            )
        )
    }

    let requestedAction = backgroundStandingReview
        ? "This standing-review item remains background PM review by default. Keep it traceable here and only create a separate owner-facing ask if the PM explicitly escalates it."
        : (request.requestedActionSummary
            ?? linkedDecision?.ownerAsk
            ?? pmApprovalRequestRequestedActionText(request.requestType))
    let approvedNextStep = backgroundStandingReview ? nil : request.approvedNextStepSummary
    let rejectedNextStep = backgroundStandingReview ? nil : request.rejectedNextStepSummary
    let reviewedNextStep = backgroundStandingReview ? nil : request.reviewedNextStepSummary
    let ownerActionMeaning = backgroundStandingReview
        ? "This item is not currently waiting on the owner. It remains PM background review unless the PM deliberately routes a separate owner-facing ask into Command Center."
        : pmApprovalRequestOwnerActionMeaning(
            requestType: request.requestType,
            status: request.status,
            ownerResponse: request.ownerResponse,
            approvedNextStep: request.approvedNextStepSummary,
            rejectedNextStep: request.rejectedNextStepSummary,
            reviewedNextStep: request.reviewedNextStepSummary
        )
    let boundaryNote = backgroundStandingReview
        ? "This is standing-review traceability, not a live owner approval path. External downstream approvals, proposal review, trading authority, and safety-state controls remain separate."
        : pmApprovalRequestBoundaryNote(requestType: request.requestType)

    return PMApprovalRequestMemoPresentation(
        initiativePosture: initiative.posture,
        initiativeSummary: initiative.summary,
        coherence: coherence,
        closure: closure,
        requestedAction: requestedAction,
        whyNow: pmWhyNowText(
            rationale: request.rationale,
            recommendationSummary: linkedDecision?.summary,
            linkedMemo: linkedMemo
        ),
        recommendation: pmRecommendationText(
            decision: linkedDecision,
            linkedMemo: linkedMemo
        ),
        strategicAlignment: pmStrategicAlignmentText(
            linkedTask: linkedTask,
            strategyBrief: strategyBrief
        ),
        portfolioContextSummary: pmStrategyChangePortfolioContextText(
            request.strategyChangePortfolioContext
        ),
        evidenceSummary: pmEvidenceSummaryText(
            decision: linkedDecision,
            linkedMemo: linkedMemo
        ),
        uncertaintySummary: pmUncertaintySummaryText(
            linkedMemo: linkedMemo,
            linkedDelegationObservability: linkedDelegationObservability,
            linkedFinding: linkedFinding
        ),
        approvedNextStep: approvedNextStep,
        rejectedNextStep: rejectedNextStep,
        reviewedNextStep: reviewedNextStep,
        ownerActionMeaning: ownerActionMeaning,
        boundaryNote: boundaryNote,
        supportingSections: supportingSections
    )
}

public func makePMDecisionMemoPresentation(
    decision: PMDecisionRecord,
    linkedApprovalRequest: PMApprovalRequest? = nil,
    executionAssessment: PMExecutionRoutingAssessment? = nil,
    linkedDelegation: PMDelegationRecord? = nil,
    linkedDelegationObservability: PMDelegationObservabilitySummary? = nil,
    linkedTask: AnalystTask? = nil,
    linkedFinding: AnalystFinding? = nil,
    linkedCommunicationMessage: PMCommunicationMessage? = nil,
    linkedMemo: AnalystMemo? = nil,
    strategyBrief: PortfolioStrategyBrief? = nil
) -> PMDecisionMemoPresentation {
    var supportingSections: [PMReviewMemoSection] = []
    let initiative = classifyPMDecisionInitiative(
        decision: decision,
        linkedApprovalRequest: linkedApprovalRequest,
        linkedDelegation: linkedDelegation,
        linkedMemo: linkedMemo,
        linkedCommunicationMessage: linkedCommunicationMessage
    )
    let coherence = makePMEventCoherencePresentation(
        posture: initiative.posture,
        initiativeSummary: initiative.summary
    )
    let closure = makePMRecommendationClosurePresentation(
        decision: decision,
        linkedApprovalRequest: linkedApprovalRequest,
        executionAssessment: executionAssessment,
        linkedDelegationObservability: linkedDelegationObservability
    )
    let backgroundStandingReview = closure.status == .backgroundPMReview

    if let linkedApprovalRequest {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Related Approval Request",
                body: linkedApprovalRequest.rationale
            )
        )
    }

    if let linkedFinding {
        let findingBody = linkedFinding.thesis.isEmpty ? linkedFinding.summary : linkedFinding.thesis
        supportingSections.append(
            PMReviewMemoSection(
                title: "Supporting Finding",
                body: findingBody
            )
        )
    }

    if let checkpointSummary = linkedTask?.checkpoint?.summary ?? linkedTask?.lastCheckpointSummary,
       !checkpointSummary.isEmpty {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Latest Analyst Update",
                body: checkpointSummary
            )
        )
    }

    if let linkedCommunicationMessage {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Related PM/User Communication",
                body: linkedCommunicationMessage.body
            )
        )
    }

    if let linkedDelegation, let linkedDelegationObservability {
        supportingSections.append(
            PMReviewMemoSection(
                title: "Current Delegation State",
                body: pmDelegationMemoStateText(
                    delegation: linkedDelegation,
                    summary: linkedDelegationObservability
                )
            )
        )
    }

    return PMDecisionMemoPresentation(
        initiativePosture: initiative.posture,
        initiativeSummary: initiative.summary,
        coherence: coherence,
        closure: closure,
        recommendation: pmDecisionRecommendationText(
            decision: decision,
            linkedMemo: linkedMemo
        ),
        whyNow: pmWhyNowText(
            rationale: linkedApprovalRequest?.rationale,
            recommendationSummary: decision.summary,
            linkedMemo: linkedMemo
        ),
        strategicAlignment: pmStrategicAlignmentText(
            linkedTask: linkedTask,
            strategyBrief: strategyBrief
        ),
        recommendedAction: decision.recommendedAction,
        evidenceSummary: pmEvidenceSummaryText(
            decision: decision,
            linkedMemo: linkedMemo
        ),
        uncertaintySummary: pmUncertaintySummaryText(
            linkedMemo: linkedMemo,
            linkedDelegationObservability: linkedDelegationObservability,
            linkedFinding: linkedFinding
        ),
        ownerAsk: backgroundStandingReview
            ? "This standing-review item remains background PM review by default. Keep it traceable here and only create a separate owner-facing ask if the PM explicitly escalates it."
            : decision.ownerAsk,
        approvedNextStep: backgroundStandingReview ? nil : decision.approvedNextStepSummary,
        boundaryNote: "This is a PM recommendation memo. Proposal approval, trade authorization, and safety-state changes still follow separate review and safety gates.",
        relationshipNote: pmDecisionRelationshipText(
            linkedApprovalRequest,
            closure: linkedApprovalRequest.map {
                makePMRecommendationClosurePresentation(
                    request: $0,
                    linkedDecision: decision,
                    executionAssessment: executionAssessment,
                    linkedDelegationObservability: linkedDelegationObservability
                )
            }
        ),
        supportingSections: supportingSections
    )
}

public func makeRecentNewsWakeUpPresentation(
    decision: PMDecisionRecord,
    linkedTask: AnalystTask?,
    linkedMemo: AnalystMemo?,
    positions: [PositionRow],
    watchlistSymbols: [String],
    strategyBrief: PortfolioStrategyBrief?
) -> RecentNewsWakeUpPresentation {
    let isRecentNewsWakeUp = recentNewsWakeUpDecision(
        decision: decision,
        linkedTask: linkedTask
    )
    guard isRecentNewsWakeUp else {
        let summary = leadingSentence(in: linkedMemo?.executiveSummary ?? decision.summary)
        return RecentNewsWakeUpPresentation(
            isRecentNewsWakeUp: false,
            originLabel: "PM Decision",
            rowSummary: summary,
            rowAffectedNames: nil,
            rowNextStep: nil,
            whatHappened: summary,
            whyItMatters: leadingSentence(in: linkedMemo?.currentView ?? decision.summary),
            strategyRelevance: nil,
            recommendedNextStep: linkedMemo?.recommendedNextStep ?? "Review the PM decision and linked analyst context before taking any separate downstream action.",
            pmActionGuidance: "This remains a PM-layer decision artifact. Proposal approval, trade authorization, and safety-state changes still follow separate controls.",
            affectedHoldings: [],
            affectedWatchlistOnly: []
        )
    }

    let context = linkedTask.flatMap { recentNewsTaskContext(from: $0.description) }
    let impactedSymbols = Array(
        Set((linkedTask?.symbols ?? []).map(normalizedRecentNewsSymbol(_:)))
    )
    .filter { $0.isEmpty == false }
    .sorted()
    let heldSymbols = Set(positions.map { normalizedRecentNewsSymbol($0.symbol) })
    let watchSymbols = Set(watchlistSymbols.map(normalizedRecentNewsSymbol(_:)))
    let affectedHoldings = impactedSymbols.filter { heldSymbols.contains($0) }
    let affectedWatchlistOnly = impactedSymbols.filter { watchSymbols.contains($0) && heldSymbols.contains($0) == false }
    let namesSummary = recentNewsAffectedNamesSummary(
        impactedSymbols: impactedSymbols,
        affectedHoldings: affectedHoldings,
        affectedWatchlistOnly: affectedWatchlistOnly
    )

    let whatHappened = nonEmptyRecentNewsText(context?.triggeringNewsSummary)
        ?? leadingSentence(in: linkedMemo?.executiveSummary ?? decision.summary)
    let whyItMatters = nonEmptyRecentNewsText(context?.whyNowSummary)
        ?? nonEmptyRecentNewsText(context?.materialityTrigger)
        ?? leadingSentence(in: linkedMemo?.currentView ?? decision.summary)
    let strategyRelevance = makeRecentNewsStrategyRelevanceText(
        context: context,
        strategyBrief: strategyBrief
    )
    let recommendedNextStep = nonEmptyRecentNewsText(linkedMemo?.recommendedNextStep)
        ?? nonEmptyRecentNewsText(context?.reviewPosture)
        ?? "Review the memo, decide whether to monitor only or request further analyst follow-up, and keep any downstream action behind the existing separate approval gates."

    return RecentNewsWakeUpPresentation(
        isRecentNewsWakeUp: true,
        originLabel: "Recent News Analyst",
        rowSummary: whatHappened,
        rowAffectedNames: namesSummary,
        rowNextStep: compactRecentNewsNextStep(recommendedNextStep),
        whatHappened: whatHappened,
        whyItMatters: whyItMatters,
        strategyRelevance: strategyRelevance,
        recommendedNextStep: recommendedNextStep,
        pmActionGuidance: "Review the memo, decide whether this stays monitor-only, warrants another analyst task, or justifies a separate owner-facing PM review. This wake-up is not proposal approval, trade authorization, or a safety-state change.",
        affectedHoldings: affectedHoldings,
        affectedWatchlistOnly: affectedWatchlistOnly
    )
}

public func makePortfolioRiskWakeUpPresentation(
    decision: PMDecisionRecord,
    linkedTask: AnalystTask?,
    linkedMemo: AnalystMemo?,
    positions: [PositionRow],
    watchlistSymbols: [String],
    strategyBrief: PortfolioStrategyBrief?
) -> PortfolioRiskWakeUpPresentation {
    let isPortfolioRiskWakeUp = portfolioRiskWakeUpDecision(
        decision: decision,
        linkedTask: linkedTask
    )
    guard isPortfolioRiskWakeUp else {
        let summary = leadingSentence(in: linkedMemo?.executiveSummary ?? decision.summary)
        return PortfolioRiskWakeUpPresentation(
            isPortfolioRiskWakeUp: false,
            originLabel: "PM Decision",
            rowSummary: summary,
            rowAffectedNames: nil,
            rowNextStep: nil,
            whatHappened: summary,
            whatChanged: leadingSentence(in: linkedMemo?.currentView ?? decision.summary),
            whyItMattersNow: summary,
            recommendedNextStep: linkedMemo?.recommendedNextStep ?? "Review the PM decision and linked analyst context before taking any separate downstream action.",
            pmActionGuidance: "This remains a PM-layer decision artifact. Proposal approval, trade authorization, and safety-state changes still follow separate controls.",
            affectedHoldings: [],
            affectedWatchlistOnly: []
        )
    }

    let context = linkedTask.flatMap { portfolioRiskTaskPresentationContext(from: $0.description) }
    let impactedSymbols = Array(
        Set((linkedTask?.symbols ?? []).map(normalizedRecentNewsSymbol(_:)))
    )
    .filter { $0.isEmpty == false }
    .sorted()
    let heldSymbols = Set(positions.map { normalizedRecentNewsSymbol($0.symbol) })
    let watchSymbols = Set(watchlistSymbols.map(normalizedRecentNewsSymbol(_:)))
    let affectedHoldings = impactedSymbols.filter { heldSymbols.contains($0) }
    let affectedWatchlistOnly = impactedSymbols.filter { watchSymbols.contains($0) && heldSymbols.contains($0) == false }
    let namesSummary = recentNewsAffectedNamesSummary(
        impactedSymbols: impactedSymbols,
        affectedHoldings: affectedHoldings,
        affectedWatchlistOnly: affectedWatchlistOnly
    )

    let whatHappened = nonEmptyRecentNewsText(context?.riskTrigger)
        ?? leadingSentence(in: linkedMemo?.executiveSummary ?? decision.summary)
    let whatChanged = nonEmptyRecentNewsText(context?.whatChangedSinceReview)
        ?? leadingSentence(in: linkedMemo?.currentView ?? decision.summary)
    let whyItMattersNow = makePortfolioRiskWhyItMattersNow(
        context: context,
        strategyBrief: strategyBrief,
        positions: positions,
        impactedSymbols: impactedSymbols
    )
    let recommendedNextStep = nonEmptyRecentNewsText(linkedMemo?.recommendedNextStep)
        ?? "Review the memo, decide whether the trigger stays monitor-only, warrants deeper overlay follow-up, or justifies a separate owner-facing PM review while keeping all downstream action behind the existing approval gates."

    return PortfolioRiskWakeUpPresentation(
        isPortfolioRiskWakeUp: true,
        originLabel: "Portfolio Risk Analyst",
        rowSummary: whatHappened,
        rowAffectedNames: namesSummary,
        rowNextStep: compactRecentNewsNextStep(recommendedNextStep),
        whatHappened: whatHappened,
        whatChanged: whatChanged,
        whyItMattersNow: whyItMattersNow,
        recommendedNextStep: recommendedNextStep,
        pmActionGuidance: "Review the memo, decide whether this stays monitor-only, warrants deeper overlay follow-up, or needs a separate owner-facing PM review. This wake-up is not proposal approval, trade authorization, or a safety-state change.",
        affectedHoldings: affectedHoldings,
        affectedWatchlistOnly: affectedWatchlistOnly
    )
}

private func pmApprovalRequestRequestedActionText(_ type: PMApprovalRequestType) -> String {
    switch type {
    case .proposalReview:
        return "Decide whether the PM should move this recommendation into the next separate paper-safe proposal step."
    case .portfolioAction:
        return "Decide whether the PM should advance this portfolio recommendation, hold it back, or send it back for more work."
    case .liveOrderReview:
        return "Review the PM-captured Live order instruction in the app. Approval advances it into the governed in-app route; submission still requires successful preflight and local authentication when enabled."
    case .operatingInstruction:
        return "Decide whether the PM should act on this operating instruction or leave the current posture unchanged."
    case .strategyChange:
        return "Decide whether to approve this bounded PM-proposed change to the saved Portfolio Strategy Brief."
    case .other:
        return "Decide whether the PM should advance this recommendation, hold it back, or send it back for more work."
    }
}

private func pmLiveOrderReviewPayloadText(_ payload: PMLiveOrderReviewPayload) -> String {
    var parts: [String] = [
        "Symbol \(payload.symbol)",
        "side \(payload.side.rawValue)",
        "type \(payload.orderType.rawValue)",
        "time-in-force \(payload.timeInForce.rawValue.uppercased())",
        "environment \(payload.environment.rawValue)"
    ]
    if let quantity = payload.quantity {
        parts.append("quantity \(quantity)")
    }
    if let notional = payload.notionalAmount {
        parts.append("notional \(pmStrategyChangeCurrencyText(NSDecimalNumber(decimal: notional).doubleValue))")
    }
    if let limitPrice = payload.limitPrice {
        parts.append("limit \(pmStrategyChangeCurrencyText(NSDecimalNumber(decimal: limitPrice).doubleValue))")
    }
    if let instructionSummary = payload.instructionSummary {
        parts.append("instruction: \(instructionSummary)")
    }
    return "Machine-readable order review: \(parts.joined(separator: "; ")). No order is sent by creating this review."
}

private func pmLiveOrderReviewLifecycleText(
    _ lifecycle: PMLiveOrderReviewExecutionLifecycleState
) -> String {
    var parts: [String] = [
        "Status \(lifecycle.status.rawValue)",
        lifecycle.summary,
        lifecycle.detail
    ]
    if let quantity = lifecycle.quantity {
        parts.append("quantity \(quantity)")
    }
    if let filledQuantity = lifecycle.filledQuantity {
        parts.append("filled \(filledQuantity)")
    }
    if let averageFillPrice = lifecycle.averageFillPrice {
        parts.append("average fill \(averageFillPrice)")
    }
    if let positionQuantity = lifecycle.positionQuantity {
        parts.append("current position quantity \(positionQuantity)")
    }
    if let openOrderStatus = lifecycle.openOrderStatus {
        parts.append("order status \(openOrderStatus)")
    }
    if lifecycle.completionFollowThroughMessageId != nil {
        parts.append("PM completion follow-through delivered")
    }
    return parts.joined(separator: " ")
}

private func pmExecutionRoutingStatusText(_ assessment: PMExecutionRoutingAssessment) -> String {
    let blocked = assessment.blockedReasons.map(pmExecutionRoutingBlockReasonDescription)
    let blockedText = blocked.isEmpty ? "" : " Blockers: \(blocked.joined(separator: " "))"
    return "\(pmExecutionRoutingStatusDisplayTitle(assessment.status)): \(assessment.summary) \(assessment.detail)\(blockedText)"
}

private func pmApprovalRequestOwnerActionMeaning(
    requestType: PMApprovalRequestType,
    status: PMApprovalRequestStatus,
    ownerResponse: PMApprovalRequestOwnerResponse?,
    approvedNextStep: String?,
    rejectedNextStep: String?,
    reviewedNextStep: String?
) -> String {
    if let ownerResponse {
        switch ownerResponse {
        case .approved:
            return approvedNextStep
                ?? "You have already approved this PM request. That records agreement with the PM's recommendation, but execution authority still stays behind the existing separate gates."
        case .rejected:
            return rejectedNextStep
                ?? "You have already declined this PM request. That records disagreement at the PM layer without canceling or approving any separate proposal or trading workflow automatically."
        case .reviewed:
            return reviewedNextStep
                ?? "You have already asked for more work on this PM request. That records the need for follow-up without granting further authority."
        }
    }

    switch status {
    case .pending:
        switch requestType {
        case .proposalReview:
            return "Your response tells the PM whether to advance, stop, or rework the recommendation. Proposal approval, execution, and safety posture still remain separate."
        case .liveOrderReview:
            return "Your response tells the PM whether this Live order instruction should advance to the governed in-app order path. Approval may start the route immediately, but it does not bypass order preflight, kill switch/arming checks, or Touch ID / Mac password when required."
        case .portfolioAction, .operatingInstruction, .other:
            return "Your response tells the PM whether to advance, stop, or rework the recommendation. It does not authorize trading or change safety posture."
        case .strategyChange:
            return "Your response tells the PM whether this bounded strategy change should update the saved Portfolio Strategy Brief. The brief stays unchanged unless you explicitly approve it through this app-owned path."
        }
    case .resolved, .withdrawn, .stale:
        return "This PM-layer request is no longer pending owner action."
    }
}

private func pmApprovalRequestBoundaryNote(requestType: PMApprovalRequestType) -> String {
    switch requestType {
    case .strategyChange:
        return "This records your review of the PM's strategy-change request. The saved Portfolio Strategy Brief changes only if you explicitly approve through this app-owned path. It does not approve proposals, authorize trades, or change live/paper, arming, or kill-switch controls."
    case .liveOrderReview:
        return "This records review of a PM-captured Live order instruction. Approval advances only through the governed Engine route. It does not authorize Telegram as an approval surface, change live/paper, arm Live, bypass the kill switch, or bypass the final LocalAuthentication gate for Live NEW/REPLACE orders."
    case .proposalReview, .portfolioAction, .operatingInstruction, .other:
        return "This records your review of the PM's request. It does not approve proposals, authorize trades, or change live/paper, arming, or kill-switch controls."
    }
}

private func pmStrategyChangePortfolioContextText(
    _ snapshot: PMStrategyChangePortfolioContextSnapshot?
) -> String? {
    guard let snapshot else {
        return nil
    }

    var parts: [String] = []
    parts.append("Current portfolio risk metrics: gross exposure \(pmStrategyChangeCurrencyText(snapshot.grossExposure)); net exposure \(pmStrategyChangeSignedPercentText(snapshot.netWeight)); \(pmStrategyChangeLargestPositionText(snapshot)).")
    parts.append("Current long-vs-short weighting: \(pmStrategyChangePercentText(snapshot.longWeight)) long / \(pmStrategyChangePercentText(snapshot.shortWeight)) short across \(snapshot.positionCount) positions.")
    return parts.joined(separator: " ")
}

private func pmStrategyChangeLargestPositionText(
    _ snapshot: PMStrategyChangePortfolioContextSnapshot
) -> String {
    guard let symbol = snapshot.largestPositionSymbol,
          let weight = snapshot.largestPositionWeight else {
        return "largest single-name concentration unavailable"
    }
    return "largest single-name concentration \(symbol) \(pmStrategyChangePercentText(weight))"
}

private func pmStrategyChangePercentText(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "0%"
}

private func pmStrategyChangeSignedPercentText(_ value: Double) -> String {
    let absolute = pmStrategyChangePercentText(abs(value))
    if value > 0 {
        return "+\(absolute)"
    }
    if value < 0 {
        return "-\(absolute)"
    }
    return absolute
}

private func pmStrategyChangeCurrencyText(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "$0"
}

private func pmDecisionRelationshipText(
    _ linkedApprovalRequest: PMApprovalRequest?,
    closure: PMRecommendationClosurePresentation?
) -> String? {
    guard let linkedApprovalRequest else {
        return nil
    }

    if let closure {
        return "Linked PM approval request: \(closure.pmInboxSummary)"
    }

    switch linkedApprovalRequest.status {
    case .pending:
        return "This PM recommendation currently has a pending PM approval request."
    case .resolved:
        return "This PM recommendation has a resolved PM approval request on record."
    case .withdrawn:
        return "This PM recommendation is linked to a withdrawn PM approval request."
    case .stale:
        return "This PM recommendation is linked to a stale PM approval request."
    }
}

private func pmDelegationMemoStateText(
    delegation: PMDelegationRecord,
    summary: PMDelegationObservabilitySummary
) -> String {
    var parts: [String] = []

    switch summary.launchHealth {
    case .notLaunched:
        parts.append("No analyst launch has been recorded yet.")
    case .healthy:
        parts.append("The latest analyst launch completed normally.")
    case .degradedExternalEvidence:
        parts.append("The latest analyst launch completed with degraded external evidence.")
    case .failed:
        parts.append("The latest analyst launch failed.")
    }

    switch summary.workflowState {
    case .noOutputsYet:
        parts.append("No downstream output has been recorded yet.")
    case .awaitingDownstreamReview:
        parts.append("Useful downstream output is available for review.")
    case .resolved:
        parts.append("The worker issue has been resolved or dismissed from active owner surfaces; history remains traceable.")
    case .canceled:
        parts.append("The delegation is canceled.")
    }

    if delegation.status == .completed {
        parts.append("The delegation itself is marked completed.")
    }

    return parts.joined(separator: " ")
}

private func pmRecommendationText(
    decision: PMDecisionRecord?,
    linkedMemo: AnalystMemo?
) -> String? {
    if let recommendedAction = nonEmptyRecentNewsText(decision?.recommendedAction) {
        return recommendedAction
    }
    if let currentView = nonEmptyRecentNewsText(linkedMemo?.currentView) {
        return currentView
    }
    return nonEmptyRecentNewsText(decision?.summary)
}

private func pmDecisionRecommendationText(
    decision: PMDecisionRecord,
    linkedMemo: AnalystMemo?
) -> String {
    pmRecommendationText(decision: decision, linkedMemo: linkedMemo)
        ?? decision.summary
}

private func pmWhyNowText(
    rationale: String?,
    recommendationSummary: String?,
    linkedMemo: AnalystMemo?
) -> String {
    if let rationale = nonEmptyRecentNewsText(rationale) {
        return rationale
    }
    if let executiveSummary = nonEmptyRecentNewsText(linkedMemo?.executiveSummary) {
        return executiveSummary
    }
    return recommendationSummary ?? "The PM believes this is the right time to act on the current recommendation."
}

private func pmEvidenceSummaryText(
    decision: PMDecisionRecord?,
    linkedMemo: AnalystMemo?
) -> String? {
    if let evidenceSummary = nonEmptyRecentNewsText(decision?.evidenceSummary) {
        return evidenceSummary
    }
    return nonEmptyRecentNewsText(linkedMemo?.evidenceSummary)
}

private func pmUncertaintySummaryText(
    linkedMemo: AnalystMemo?,
    linkedDelegationObservability: PMDelegationObservabilitySummary?,
    linkedFinding: AnalystFinding?
) -> String? {
    if let uncertainty = nonEmptyRecentNewsText(linkedMemo?.uncertaintySummary) {
        return uncertainty
    }
    if linkedDelegationObservability?.launchHealth == .degradedExternalEvidence {
        return "The direction is usable, but evidence quality is partially degraded. More analyst work could improve confidence before any broader step."
    }
    if let linkedFinding, linkedFinding.confidence < 0.6 {
        return "Confidence is still moderate. More analyst work could improve conviction before a broader step."
    }
    return nil
}

private func pmStrategicAlignmentText(
    linkedTask: AnalystTask?,
    strategyBrief: PortfolioStrategyBrief?
) -> String? {
    let taskDescription = linkedTask?.description ?? ""
    let objective = recentNewsTaskContextValue(prefix: "Portfolio strategy brief objective:", from: taskDescription)
        ?? nonEmptyRecentNewsText(strategyBrief?.objectiveSummary)
    let riskPosture = recentNewsTaskContextValue(prefix: "Current risk posture:", from: taskDescription)
        ?? nonEmptyRecentNewsText(strategyBrief?.currentRiskPosture)
    let themes = recentNewsTaskContextValue(prefix: "Strategy themes:", from: taskDescription)
        ?? nonEmptyRecentNewsText(strategyBrief?.keyThemes.joined(separator: "; "))

    var parts: [String] = []
    if let objective {
        parts.append("Current strategy objective: \(objective)")
    }
    if let riskPosture {
        parts.append("Current risk posture: \(riskPosture)")
    }
    if let themes, themes.isEmpty == false {
        parts.append("Current strategic focus: \(themes)")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " ")
}

private struct RecentNewsTaskPresentationContext: Sendable, Equatable {
    let heldPositionsSummary: String?
    let watchlistSummary: String?
    let strategyObjective: String?
    let strategyThemes: String?
    let riskPosture: String?
    let coveragePosture: String?
    let clusteredEventView: String?
    let escalationPosture: String?
    let whyNowSummary: String?
    let bookPostureSummary: String?
    let materialityTrigger: String?
    let triggeringNewsSummary: String?
    let reviewPosture: String?
}

private struct PortfolioRiskTaskPresentationContext: Sendable, Equatable {
    let heldPositionsSummary: String?
    let watchlistSummary: String?
    let strategyObjective: String?
    let strategyThemes: String?
    let riskPosture: String?
    let reviewPosture: String?
    let coveragePosture: String?
    let concentrationPosture: String?
    let clusteredRiskView: String?
    let longShortPosture: String?
    let escalationPosture: String?
    let whyNowSummary: String?
    let bookPostureSummary: String?
    let riskTrigger: String?
    let whatChangedSinceReview: String?
    let triggeringConditions: String?
    let priorReviewAnchor: String?
    let priorReviewSource: String?
}

private func recentNewsWakeUpDecision(
    decision: PMDecisionRecord,
    linkedTask: AnalystTask?
) -> Bool {
    if linkedTask?.tags.contains("recent-news-analyst") == true {
        return true
    }
    let title = decision.title.lowercased()
    if title.contains("recent news analyst escalation") || title.contains("recent news") {
        return true
    }
    return (decision.taskId ?? "").contains("recent-news-task")
        || (decision.delegationId ?? "").contains("recent-news-delegation")
}

private func portfolioRiskWakeUpDecision(
    decision: PMDecisionRecord,
    linkedTask: AnalystTask?
) -> Bool {
    if linkedTask?.tags.contains("portfolio-risk-analyst") == true
        || linkedTask?.tags.contains("portfolio-risk-trigger") == true {
        return true
    }
    let title = decision.title.lowercased()
    if title.contains("portfolio risk trigger") || title.contains("portfolio risk review") {
        return true
    }
    return (decision.taskId ?? "").contains("portfolio-risk-task")
        || (decision.delegationId ?? "").contains("portfolio-risk-delegation")
}

private func recentNewsTaskContext(from description: String) -> RecentNewsTaskPresentationContext {
    RecentNewsTaskPresentationContext(
        heldPositionsSummary: recentNewsTaskContextValue(prefix: "Held positions in scope:", from: description),
        watchlistSummary: recentNewsTaskContextValue(prefix: "Watchlist context:", from: description),
        strategyObjective: recentNewsTaskContextValue(prefix: "Portfolio strategy brief objective:", from: description),
        strategyThemes: recentNewsTaskContextValue(prefix: "Strategy themes:", from: description),
        riskPosture: recentNewsTaskContextValue(prefix: "Current risk posture:", from: description),
        coveragePosture: recentNewsTaskContextValue(prefix: "Coverage posture:", from: description),
        clusteredEventView: recentNewsTaskContextValue(prefix: "Clustered event view:", from: description),
        escalationPosture: recentNewsTaskContextValue(prefix: "Escalation posture:", from: description),
        whyNowSummary: recentNewsTaskContextValue(prefix: "Why now:", from: description),
        bookPostureSummary: recentNewsTaskContextValue(prefix: "Current book posture:", from: description),
        materialityTrigger: recentNewsTaskContextValue(prefix: "Materiality trigger:", from: description),
        triggeringNewsSummary: recentNewsTaskContextValue(prefix: "Triggering news:", from: description),
        reviewPosture: recentNewsTaskContextValue(prefix: "Review posture:", from: description)
    )
}

private func portfolioRiskTaskPresentationContext(from description: String) -> PortfolioRiskTaskPresentationContext {
    PortfolioRiskTaskPresentationContext(
        heldPositionsSummary: recentNewsTaskContextValue(prefix: "Held positions in scope:", from: description),
        watchlistSummary: recentNewsTaskContextValue(prefix: "Watchlist context:", from: description),
        strategyObjective: recentNewsTaskContextValue(prefix: "Portfolio strategy brief objective:", from: description),
        strategyThemes: recentNewsTaskContextValue(prefix: "Strategy themes:", from: description),
        riskPosture: recentNewsTaskContextValue(prefix: "Current risk posture:", from: description),
        reviewPosture: recentNewsTaskContextValue(prefix: "Review posture:", from: description),
        coveragePosture: recentNewsTaskContextValue(prefix: "Coverage posture:", from: description),
        concentrationPosture: recentNewsTaskContextValue(prefix: "Concentration posture:", from: description),
        clusteredRiskView: recentNewsTaskContextValue(prefix: "Clustered risk view:", from: description),
        longShortPosture: recentNewsTaskContextValue(prefix: "Long-vs-short posture:", from: description),
        escalationPosture: recentNewsTaskContextValue(prefix: "Escalation posture:", from: description),
        whyNowSummary: recentNewsTaskContextValue(prefix: "Why now:", from: description),
        bookPostureSummary: recentNewsTaskContextValue(prefix: "Current book posture:", from: description),
        riskTrigger: recentNewsTaskContextValue(prefix: "Risk trigger:", from: description),
        whatChangedSinceReview: recentNewsTaskContextValue(prefix: "What changed since prior review:", from: description),
        triggeringConditions: recentNewsTaskContextValue(prefix: "Triggering conditions:", from: description),
        priorReviewAnchor: recentNewsTaskContextValue(prefix: "Prior portfolio-risk review anchor:", from: description),
        priorReviewSource: recentNewsTaskContextValue(prefix: "The last review anchor came from", from: description)
    )
}

private func recentNewsTaskContextValue(prefix: String, from description: String) -> String? {
    guard let range = description.range(of: prefix) else {
        return nil
    }
    let remainder = description[range.upperBound...]
    let terminators = [
        " Held positions in scope:",
        " Watchlist context:",
        " Portfolio strategy brief objective:",
        " Strategy themes:",
        " Current risk posture:",
        " Material developments:",
        " Usually not material:",
        " Review posture:",
        " Coverage posture:",
        " Clustered event view:",
        " Escalation posture:",
        " Why now:",
        " Current book posture:",
        " Concentration posture:",
        " Clustered risk view:",
        " Long-vs-short posture:",
        " Materiality trigger:",
        " Triggering news:",
        " Risk trigger:",
        " What changed since prior review:",
        " Triggering conditions:",
        " Prior portfolio-risk review anchor:",
        " The last review anchor came from",
        " If the impact is not strong enough"
    ]
    let suffixRange = terminators
        .compactMap { remainder.range(of: $0) }
        .min(by: { $0.lowerBound < $1.lowerBound })
    let value = suffixRange.map { String(remainder[..<$0.lowerBound]) } ?? String(remainder)
    return nonEmptyRecentNewsText(value)
}

private func makeRecentNewsStrategyRelevanceText(
    context: RecentNewsTaskPresentationContext?,
    strategyBrief: PortfolioStrategyBrief?
) -> String? {
    let objective = nonEmptyRecentNewsText(context?.strategyObjective)
        ?? nonEmptyRecentNewsText(strategyBrief?.objectiveSummary)
    let riskPosture = nonEmptyRecentNewsText(context?.riskPosture)
        ?? nonEmptyRecentNewsText(strategyBrief?.currentRiskPosture)
    let themes = nonEmptyRecentNewsText(context?.strategyThemes)
        ?? {
            let joined = strategyBrief?.keyThemes.joined(separator: "; ")
            return nonEmptyRecentNewsText(joined)
        }()

    var parts: [String] = []
    if let objective {
        parts.append("Current strategy objective: \(objective)")
    }
    if let riskPosture {
        parts.append("Risk posture: \(riskPosture)")
    }
    if let themes {
        parts.append("Relevant themes: \(themes)")
    }

    guard parts.isEmpty == false else {
        return nil
    }
    return parts.joined(separator: " ")
}

private func makePortfolioRiskWhyItMattersNow(
    context: PortfolioRiskTaskPresentationContext?,
    strategyBrief: PortfolioStrategyBrief?,
    positions: [PositionRow],
    impactedSymbols: [String]
) -> String {
    if let whyNow = nonEmptyRecentNewsText(context?.whyNowSummary) {
        return whyNow
    }

    let heldContext: String
    if let held = nonEmptyRecentNewsText(context?.heldPositionsSummary) {
        heldContext = "Held positions in scope: \(held)"
    } else if impactedSymbols.isEmpty == false {
        let matching = positions.filter { impactedSymbols.contains(normalizedRecentNewsSymbol($0.symbol)) }
        if matching.isEmpty {
            heldContext = "No current held-position summary was attached."
        } else {
            heldContext = "Held positions in scope: \(matching.map { "\($0.symbol) qty \($0.qty) market value \($0.marketValue)" }.joined(separator: "; "))"
        }
    } else {
        heldContext = "No current held-position summary was attached."
    }

    let riskPosture = nonEmptyRecentNewsText(context?.riskPosture)
        ?? nonEmptyRecentNewsText(strategyBrief?.currentRiskPosture)
    let objective = nonEmptyRecentNewsText(context?.strategyObjective)
        ?? nonEmptyRecentNewsText(strategyBrief?.objectiveSummary)
    let conditions = nonEmptyRecentNewsText(context?.triggeringConditions)
    let priorReview = nonEmptyRecentNewsText(context?.priorReviewAnchor)
    let concentration = nonEmptyRecentNewsText(context?.concentrationPosture)
    let clustered = nonEmptyRecentNewsText(context?.clusteredRiskView)
    let longShort = nonEmptyRecentNewsText(context?.longShortPosture)
    let escalation = nonEmptyRecentNewsText(context?.escalationPosture)

    var parts: [String] = [heldContext]
    if let riskPosture {
        parts.append("Risk posture: \(riskPosture)")
    }
    if let objective {
        parts.append("Current strategy objective: \(objective)")
    }
    if let conditions {
        parts.append("Trigger conditions: \(conditions)")
    }
    if let concentration {
        parts.append("Concentration posture: \(concentration)")
    }
    if let clustered {
        parts.append("Clustered risk view: \(clustered)")
    }
    if let longShort {
        parts.append("Long-vs-short posture: \(longShort)")
    }
    if let escalation {
        parts.append("Escalation posture: \(escalation)")
    }
    if let priorReview {
        parts.append("Prior review anchor: \(priorReview)")
    }
    return parts.joined(separator: " ")
}

private func recentNewsAffectedNamesSummary(
    impactedSymbols: [String],
    affectedHoldings: [String],
    affectedWatchlistOnly: [String]
) -> String? {
    var parts: [String] = []
    if affectedHoldings.isEmpty == false {
        parts.append("Holdings: \(affectedHoldings.joined(separator: ", "))")
    }
    if affectedWatchlistOnly.isEmpty == false {
        parts.append("Watchlist only: \(affectedWatchlistOnly.joined(separator: ", "))")
    }
    if parts.isEmpty, impactedSymbols.isEmpty == false {
        parts.append("Impacted names: \(impactedSymbols.joined(separator: ", "))")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " • ")
}

private func compactRecentNewsNextStep(_ text: String) -> String {
    leadingSentence(in: text)
}

private func leadingSentence(in text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else {
        return trimmed
    }
    if let range = trimmed.range(of: ". ") {
        return String(trimmed[..<range.lowerBound]) + "."
    }
    return trimmed.hasSuffix(".") ? trimmed : trimmed + "."
}

private func normalizedRecentNewsSymbol(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
}

private func nonEmptyRecentNewsText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
        return nil
    }
    return trimmed
}
