import Foundation

public enum OwnerSurfaceProjectionBudget {
    public static let visiblePMConversationMessages = 16
    public static let visiblePMConversationMessageCharacters = 2_400
    public static let visibleBackgroundWorkflowCards = 7
}

public enum OwnerBackgroundActivityKind: String, Sendable, Equatable {
    case pmReviewing = "pm_reviewing"
    case analystActivity = "analyst_activity"
    case systemExceptions = "system_exceptions"
}

public struct OwnerBackgroundActivityPresentation: Sendable, Equatable, Identifiable {
    public let activityId: String
    public let kind: OwnerBackgroundActivityKind
    public let title: String
    public let count: Int
    public let summary: String
    public let detail: String
    public let drillDownLabel: String

    public var id: String { activityId }

    public init(
        activityId: String? = nil,
        kind: OwnerBackgroundActivityKind,
        title: String,
        count: Int,
        summary: String,
        detail: String,
        drillDownLabel: String
    ) {
        self.activityId = activityId ?? kind.rawValue
        self.kind = kind
        self.title = title
        self.count = count
        self.summary = summary
        self.detail = detail
        self.drillDownLabel = drillDownLabel
    }
}

public struct OwnerDecisionDeskItemPresentation: Sendable, Equatable, Identifiable {
    public let approvalRequestId: String
    public let title: String
    public let requestTypeTitle: String
    public let initiativePosture: PMInitiativePosture
    public let initiativeSummary: String
    public let coherence: PMEventCoherencePresentation
    public let closure: PMRecommendationClosurePresentation
    public let ownerAsk: String
    public let whyNow: String
    public let recommendation: String?
    public let strategicAlignment: String?
    public let portfolioContextSummary: String?
    public let researchTrustLabel: String?
    public let researchTrustSummary: String?
    public let researchTrustSourceConstraintSummary: String?
    public let supportingEvidence: String?
    public let uncertaintySummary: String?
    public let approvedNextStep: String?
    public let declinedNextStep: String?
    public let moreWorkNextStep: String?
    public let linkedProposalId: String?
    public let linkedCommunicationSummary: String?
    public let routingStatusSummary: String?
    public let boundaryNote: String

    public var id: String { approvalRequestId }

    public init(
        approvalRequestId: String,
        title: String,
        requestTypeTitle: String,
        initiativePosture: PMInitiativePosture,
        initiativeSummary: String,
        coherence: PMEventCoherencePresentation,
        closure: PMRecommendationClosurePresentation,
        ownerAsk: String,
        whyNow: String,
        recommendation: String?,
        strategicAlignment: String?,
        portfolioContextSummary: String?,
        researchTrustLabel: String?,
        researchTrustSummary: String?,
        researchTrustSourceConstraintSummary: String?,
        supportingEvidence: String?,
        uncertaintySummary: String?,
        approvedNextStep: String?,
        declinedNextStep: String?,
        moreWorkNextStep: String?,
        linkedProposalId: String?,
        linkedCommunicationSummary: String?,
        routingStatusSummary: String? = nil,
        boundaryNote: String
    ) {
        self.approvalRequestId = approvalRequestId
        self.title = title
        self.requestTypeTitle = requestTypeTitle
        self.initiativePosture = initiativePosture
        self.initiativeSummary = initiativeSummary
        self.coherence = coherence
        self.closure = closure
        self.ownerAsk = ownerAsk
        self.whyNow = whyNow
        self.recommendation = recommendation
        self.strategicAlignment = strategicAlignment
        self.portfolioContextSummary = portfolioContextSummary
        self.researchTrustLabel = researchTrustLabel
        self.researchTrustSummary = researchTrustSummary
        self.researchTrustSourceConstraintSummary = researchTrustSourceConstraintSummary
        self.supportingEvidence = supportingEvidence
        self.uncertaintySummary = uncertaintySummary
        self.approvedNextStep = approvedNextStep
        self.declinedNextStep = declinedNextStep
        self.moreWorkNextStep = moreWorkNextStep
        self.linkedProposalId = linkedProposalId
        self.linkedCommunicationSummary = linkedCommunicationSummary
        self.routingStatusSummary = routingStatusSummary
        self.boundaryNote = boundaryNote
    }
}

public struct OwnerPMConversationPresentation: Sendable, Equatable {
    public let visibleMessages: [OwnerPMConversationMessagePresentation]
    public let sessionId: String
    public let participantName: String
    public let sessionSummary: String
    public let latestPMMessage: String?
    public let latestOwnerReply: String?
    public let awaitingPMReply: Bool
    public let replyRoutingSummary: String
    public let currentAskTitle: String?
    public let currentAskSummary: String?
    public let currentAskLifecycleSummary: String?
    public let ownerComposerTitle: String
    public let ownerComposerHint: String

    public init(
        visibleMessages: [OwnerPMConversationMessagePresentation],
        sessionId: String,
        participantName: String,
        sessionSummary: String,
        latestPMMessage: String?,
        latestOwnerReply: String?,
        awaitingPMReply: Bool,
        replyRoutingSummary: String,
        currentAskTitle: String?,
        currentAskSummary: String?,
        currentAskLifecycleSummary: String?,
        ownerComposerTitle: String,
        ownerComposerHint: String
    ) {
        self.visibleMessages = visibleMessages
        self.sessionId = sessionId
        self.participantName = participantName
        self.sessionSummary = sessionSummary
        self.latestPMMessage = latestPMMessage
        self.latestOwnerReply = latestOwnerReply
        self.awaitingPMReply = awaitingPMReply
        self.replyRoutingSummary = replyRoutingSummary
        self.currentAskTitle = currentAskTitle
        self.currentAskSummary = currentAskSummary
        self.currentAskLifecycleSummary = currentAskLifecycleSummary
        self.ownerComposerTitle = ownerComposerTitle
        self.ownerComposerHint = ownerComposerHint
    }
}

public struct OwnerPMConversationMessagePresentation: Sendable, Equatable, Identifiable {
    public let messageId: String
    public let speakerLabel: String
    public let body: String
    public let emphasized: Bool

    public var id: String { messageId }

    public init(
        messageId: String,
        speakerLabel: String,
        body: String,
        emphasized: Bool
    ) {
        self.messageId = messageId
        self.speakerLabel = speakerLabel
        self.body = body
        self.emphasized = emphasized
    }
}

public struct OwnerPMSurfaceCoordinationPresentation: Sendable, Equatable {
    public let commandCenterSummary: String
    public let telegramSummary: String
    public let pmInboxSummary: String
    public let runtimeSummary: String

    public init(
        commandCenterSummary: String,
        telegramSummary: String,
        pmInboxSummary: String,
        runtimeSummary: String
    ) {
        self.commandCenterSummary = commandCenterSummary
        self.telegramSummary = telegramSummary
        self.pmInboxSummary = pmInboxSummary
        self.runtimeSummary = runtimeSummary
    }
}

public enum CommandCenterDeskReadinessState: String, Codable, Sendable, Equatable {
    case needsOwnerAttentionNow = "needs_owner_attention_now"
    case pmHandlingInBackground = "pm_handling_in_background"
    case informationalOnly = "informational_only"
    case operationalAttention = "operational_attention"
    case noImmediateActionRequired = "no_immediate_action_required"
}

public struct CommandCenterDeskReadinessPresentation: Sendable, Equatable {
    public let state: CommandCenterDeskReadinessState
    public let title: String
    public let summary: String
    public let ownerAttentionSummary: String
    public let pmHandlingSummary: String
    public let informationalSummary: String
    public let operationalSummary: String

    public init(
        state: CommandCenterDeskReadinessState,
        title: String,
        summary: String,
        ownerAttentionSummary: String,
        pmHandlingSummary: String,
        informationalSummary: String,
        operationalSummary: String
    ) {
        self.state = state
        self.title = title
        self.summary = summary
        self.ownerAttentionSummary = ownerAttentionSummary
        self.pmHandlingSummary = pmHandlingSummary
        self.informationalSummary = informationalSummary
        self.operationalSummary = operationalSummary
    }
}

public struct StrategyBriefConversationRevisionCandidatePresentation: Sendable, Equatable {
    public let messageId: String
    public let senderLabel: String
    public let messageSummary: String
    public let revisionSuggestion: String

    public init(
        messageId: String,
        senderLabel: String,
        messageSummary: String,
        revisionSuggestion: String
    ) {
        self.messageId = messageId
        self.senderLabel = senderLabel
        self.messageSummary = messageSummary
        self.revisionSuggestion = revisionSuggestion
    }
}

public struct StrategyBriefConversationRevisionCandidateComputation: Sendable, Equatable {
    public let candidate: StrategyBriefConversationRevisionCandidatePresentation?
    public let scannedMessageCount: Int
    public let consideredMessageCount: Int
    public let selectedSessionId: String?
    public let messageScanLimit: Int

    public init(
        candidate: StrategyBriefConversationRevisionCandidatePresentation?,
        scannedMessageCount: Int,
        consideredMessageCount: Int,
        selectedSessionId: String?,
        messageScanLimit: Int
    ) {
        self.candidate = candidate
        self.scannedMessageCount = scannedMessageCount
        self.consideredMessageCount = consideredMessageCount
        self.selectedSessionId = selectedSessionId
        self.messageScanLimit = messageScanLimit
    }
}

public struct PMInboxCommunicationReviewPresentation: Sendable, Equatable {
    public let title: String
    public let summary: String
    public let primaryActionLabel: String
    public let ownerComposeAllowed: Bool

    public init(
        title: String,
        summary: String,
        primaryActionLabel: String,
        ownerComposeAllowed: Bool
    ) {
        self.title = title
        self.summary = summary
        self.primaryActionLabel = primaryActionLabel
        self.ownerComposeAllowed = ownerComposeAllowed
    }
}

public struct PMExerciseArtifactArchiveSummary: Sendable, Equatable {
    public let approvalRequestsArchived: Int
    public let decisionsArchived: Int
    public let delegationsArchived: Int
    public let communicationSessionsClosed: Int

    public var totalAffected: Int {
        approvalRequestsArchived + decisionsArchived + delegationsArchived + communicationSessionsClosed
    }

    public init(
        approvalRequestsArchived: Int,
        decisionsArchived: Int,
        delegationsArchived: Int,
        communicationSessionsClosed: Int
    ) {
        self.approvalRequestsArchived = approvalRequestsArchived
        self.decisionsArchived = decisionsArchived
        self.delegationsArchived = delegationsArchived
        self.communicationSessionsClosed = communicationSessionsClosed
    }
}

public func makeCommandCenterDeskReadinessPresentation(
    snapshot: PMCommandCenterSnapshot,
    decisionItems: [OwnerDecisionDeskItemPresentation],
    runtimeOperability: RuntimeOperabilityPresentation?
) -> CommandCenterDeskReadinessPresentation {
    let ownerAttentionCount = decisionItems.count
    let pmHandlingCount = snapshot.activePMBackgroundCount
        + snapshot.activeAnalystBackgroundCount
    let informationalCount = snapshot.newSignalsCount + snapshot.fyiSignalsCount + snapshot.awaitingProposalCount
    let systemExceptionCount = snapshot.failedDelegationsCount + snapshot.degradedDelegationsCount
    let runtimeDegraded = runtimeOperability?.degradedModeActive == true

    let ownerAttentionSummary: String
    if let firstDecision = decisionItems.first {
        ownerAttentionSummary = countSentence(
            ownerAttentionCount,
            zero: "Nothing is waiting for your decision right now.",
            singular: "1 item needs your decision now. Start with \(firstDecision.title).",
            plural: "\(ownerAttentionCount) items need your decision now. Start with \(firstDecision.title)."
        )
    } else {
        ownerAttentionSummary = "Nothing is waiting for your decision right now."
    }

    let pmHandlingSummary = countSentence(
        pmHandlingCount,
        zero: "PM and analyst workflow are quiet right now.",
        singular: "1 PM or analyst item is already being handled in the background.",
        plural: "\(pmHandlingCount) PM or analyst items are already being handled in the background."
    )

    let informationalSummary = countSentence(
        informationalCount,
        zero: "No new signals or proposal build-up need a quick FYI pass right now.",
        singular: "1 informational update is available without needing action now.",
        plural: "\(informationalCount) informational updates are available without needing action now."
    )

    let operationalSummary: String
    if runtimeDegraded, let runtimeOperability {
        if systemExceptionCount > 0 {
            operationalSummary = "Runtime health is degraded (\(runtimeOperability.operabilityLabel.lowercased())), and \(systemExceptionCount) system issue\(systemExceptionCount == 1 ? "" : "s") also need bounded review."
        } else {
            operationalSummary = "Runtime health is degraded: \(runtimeOperability.operabilityLabel). Review the current runtime path before relying on it."
        }
    } else {
        operationalSummary = countSentence(
            systemExceptionCount,
            zero: "No runtime or system exceptions need review right now.",
            singular: "1 bounded operational issue needs review.",
            plural: "\(systemExceptionCount) bounded operational issues need review."
        )
    }

    let state: CommandCenterDeskReadinessState
    let title: String
    let summary: String

    if ownerAttentionCount > 0 {
        state = .needsOwnerAttentionNow
        title = "Owner Attention Needed"
        summary = "Start with the current PM decision ask. Background handling, FYIs, and operational detail are secondary until that is resolved."
    } else if runtimeDegraded || systemExceptionCount > 0 {
        state = .operationalAttention
        title = "Operational Attention"
        summary = "No owner decision is pending, but runtime or system health needs review before you treat the desk as fully normal."
    } else if pmHandlingCount > 0 {
        state = .pmHandlingInBackground
        title = "PM Handling In Background"
        summary = "No owner decision is pending. PM and analysts are already working the desk, so you can monitor calmly unless something escalates."
    } else if informationalCount > 0 {
        state = .informationalOnly
        title = "Informational Only"
        summary = "Nothing needs your decision right now. The desk mainly has FYI material and light queue build-up."
    } else {
        state = .noImmediateActionRequired
        title = "No Immediate Action Required"
        summary = "The desk is calm right now: no owner ask is pending, no background queue is pressing, and no operational issue is active."
    }

    return CommandCenterDeskReadinessPresentation(
        state: state,
        title: title,
        summary: summary,
        ownerAttentionSummary: ownerAttentionSummary,
        pmHandlingSummary: pmHandlingSummary,
        informationalSummary: informationalSummary,
        operationalSummary: operationalSummary
    )
}

public func makeOwnerBackgroundActivityPresentations(
    snapshot: PMCommandCenterSnapshot,
    standingReports: [AnalystStandingReport] = [],
    jobs: [JobSummary] = []
) -> [OwnerBackgroundActivityPresentation] {
    let exceptions = snapshot.failedDelegationsCount + snapshot.degradedDelegationsCount
    let pmReviewCount = snapshot.pmReviewQueueCount
    let analystActivityCount = snapshot.activeDelegationsCount + snapshot.activeStandingRunCount
    var cards = makeOwnerWorkflowLifecycleActivityPresentations(
        standingReports: standingReports,
        jobs: jobs
    )
    cards.append(contentsOf: [
        OwnerBackgroundActivityPresentation(
            kind: .pmReviewing,
            title: "PM Reviewing",
            count: pmReviewCount,
            summary: countSentence(
                pmReviewCount,
                zero: "PM does not have active internal review work right now.",
                singular: "PM has 1 item waiting for internal review.",
                plural: "PM has \(pmReviewCount) items waiting for internal review."
            ),
            detail: pmReviewCount == 0
                ? "No PM-internal review queue is active."
                : newestPendingStandingReportDetail(standingReports),
            drillDownLabel: "Open PM Inbox"
        ),
        OwnerBackgroundActivityPresentation(
            kind: .analystActivity,
            title: "Analyst Activity",
            count: analystActivityCount,
            summary: countSentence(
                analystActivityCount,
                zero: "No analyst work is active right now.",
                singular: "1 analyst item is active in the background.",
                plural: "\(analystActivityCount) analyst items are active in the background."
            ),
            detail: analystActivityCount == 0
                ? "No analyst work is in flight."
                : "This includes issued analyst delegations and in-flight standing analyst report runs.",
            drillDownLabel: "Open PM Inbox"
        ),
        OwnerBackgroundActivityPresentation(
            kind: .systemExceptions,
            title: "System Exceptions",
            count: exceptions,
            summary: countSentence(
                exceptions,
                zero: "No system exceptions need review right now.",
                singular: "1 system exception is active.",
                plural: "\(exceptions) system exceptions are active."
            ),
            detail: exceptions == 0
                ? "No degraded or failed worker launches are active."
                : "\(snapshot.failedDelegationsCount) failed and \(snapshot.degradedDelegationsCount) degraded worker issue(s) are active.",
            drillDownLabel: "Open System Control"
        )
    ])
    return Array(cards.prefix(OwnerSurfaceProjectionBudget.visibleBackgroundWorkflowCards))
}

private func makeOwnerWorkflowLifecycleActivityPresentations(
    standingReports: [AnalystStandingReport],
    jobs: [JobSummary]
) -> [OwnerBackgroundActivityPresentation] {
    let ownerVisibleReports = standingReports.filter {
        isExerciseArtifactIdentifier($0.reportId) == false
    }
    let pendingReports = ownerVisibleReports
        .filter { $0.deliveryStatus == .pendingPMReview }
        .sorted(by: standingReportsNewestDeliveryFirst)
    let reviewedReports = ownerVisibleReports
        .filter { $0.deliveryStatus == .reviewedByPM }
        .sorted(by: standingReportsNewestUpdateFirst)
    let activeStandingJobs = jobs
        .filter { $0.type == .standingAnalystReport && ($0.status == .queued || $0.status == .running) }
        .sorted(by: jobSummariesNewestFirst)

    var cards: [OwnerBackgroundActivityPresentation] = []
    if let job = activeStandingJobs.first {
        cards.append(
            OwnerBackgroundActivityPresentation(
                activityId: "standing-report-job-\(job.jobId)",
                kind: .analystActivity,
                title: "Analyst Run Active",
                count: activeStandingJobs.count,
                summary: countSentence(
                    activeStandingJobs.count,
                    zero: "No standing analyst runs are active.",
                    singular: "1 standing analyst run is active.",
                    plural: "\(activeStandingJobs.count) standing analyst runs are active."
                ),
                detail: boundedBackgroundActivityDetail(
                    job.message ?? "Standing analyst report work is currently \(job.status.rawValue)."
                ),
                drillDownLabel: "Open PM Inbox"
            )
        )
    }
    if let pending = pendingReports.first {
        cards.append(
            OwnerBackgroundActivityPresentation(
                activityId: "standing-report-delivered-\(pending.reportId)",
                kind: .analystActivity,
                title: "Analyst Report Delivered",
                count: pendingReports.count,
                summary: "\(pending.title) landed in PM Inbox for PM review.",
                detail: boundedBackgroundActivityDetail(pending.headlineView),
                drillDownLabel: "Open PM Inbox"
            )
        )
        cards.append(
            OwnerBackgroundActivityPresentation(
                activityId: "standing-report-pm-review-\(pending.reportId)",
                kind: .pmReviewing,
                title: "PM Review Pending",
                count: pendingReports.count,
                summary: countSentence(
                    pendingReports.count,
                    zero: "No reports are awaiting PM review.",
                    singular: "PM has 1 standing report to review.",
                    plural: "PM has \(pendingReports.count) standing reports to review."
                ),
                detail: "\(pending.title) remains routine PM workflow until the PM creates an owner-actionable ask.",
                drillDownLabel: "Open PM Inbox"
            )
        )
    }
    if let reviewed = reviewedReports.first {
        cards.append(
            OwnerBackgroundActivityPresentation(
                activityId: "standing-report-pm-reviewed-\(reviewed.reportId)",
                kind: .pmReviewing,
                title: "PM Review Completed",
                count: 1,
                summary: "PM completed background review for \(reviewed.title).",
                detail: boundedBackgroundActivityDetail(reviewed.summary),
                drillDownLabel: "Open PM Inbox"
            )
        )
    }
    return cards
}

private func newestPendingStandingReportDetail(
    _ standingReports: [AnalystStandingReport]
) -> String {
    guard let report = standingReports
        .filter({ $0.deliveryStatus == .pendingPMReview && isExerciseArtifactIdentifier($0.reportId) == false })
        .sorted(by: standingReportsNewestDeliveryFirst)
        .first else {
        return "This reflects standing analyst reports that landed in PM Inbox for PM review."
    }
    return boundedBackgroundActivityDetail("\(report.title): \(report.headlineView)")
}

private func standingReportsNewestDeliveryFirst(
    lhs: AnalystStandingReport,
    rhs: AnalystStandingReport
) -> Bool {
    if lhs.deliveredToPMInboxAt == rhs.deliveredToPMInboxAt {
        return lhs.reportId < rhs.reportId
    }
    return lhs.deliveredToPMInboxAt > rhs.deliveredToPMInboxAt
}

private func standingReportsNewestUpdateFirst(
    lhs: AnalystStandingReport,
    rhs: AnalystStandingReport
) -> Bool {
    if lhs.updatedAt == rhs.updatedAt {
        return lhs.reportId < rhs.reportId
    }
    return lhs.updatedAt > rhs.updatedAt
}

private func jobSummariesNewestFirst(lhs: JobSummary, rhs: JobSummary) -> Bool {
    if lhs.updatedAt == rhs.updatedAt {
        return lhs.jobId < rhs.jobId
    }
    return lhs.updatedAt > rhs.updatedAt
}

private func boundedBackgroundActivityDetail(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 180 else {
        return trimmed.isEmpty ? "Workflow details are available in PM Inbox." : trimmed
    }
    return String(trimmed.prefix(177)) + "..."
}

public func makeOwnerDecisionDeskPresentations(
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord],
    delegations: [PMDelegationRecord],
    tasks: [AnalystTask],
    findings: [AnalystFinding],
    communicationMessages: [PMCommunicationMessage],
    charters: [AnalystCharter],
    memos: [AnalystMemo],
    strategyBrief: PortfolioStrategyBrief?,
    evidenceBundles: [AnalystEvidenceBundle] = [],
    sourceAccessSuggestions: [AnalystSourceAccessSuggestionRecord] = []
) -> [OwnerDecisionDeskItemPresentation] {
    let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.decisionId, $0) })
    let delegationsByID = Dictionary(uniqueKeysWithValues: delegations.map { ($0.delegationId, $0) })
    let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.taskId, $0) })
    let findingsByID = Dictionary(uniqueKeysWithValues: findings.map { ($0.findingId, $0) })
    let chartersByID = Dictionary(uniqueKeysWithValues: charters.map { ($0.charterId, $0) })
    let ownerActionableRequests = makeOwnerActionableApprovalRequests(
        approvalRequests: approvalRequests,
        decisions: decisions
    )

    return ownerActionableRequests
        .compactMap { request -> OwnerDecisionDeskItemPresentation? in
            let linkedDecision = request.decisionId.flatMap { decisionsByID[$0] }
            let linkedDelegation = request.delegationId.flatMap { delegationsByID[$0] }
            let linkedTask = linkedDelegation?.taskId.flatMap { tasksByID[$0] }
            let linkedFinding = request.findingId.flatMap { findingsByID[$0] }
                ?? linkedDelegation?.linkedFindingIDs.last.flatMap { findingsByID[$0] }
            let linkedMemo = latestAnalystMemoForOwnerDecisionDesk(
                memos: memos,
                request: request,
                linkedDecision: linkedDecision,
                linkedDelegation: linkedDelegation,
                linkedTask: linkedTask,
                linkedFinding: linkedFinding
            )
            let linkedEvidenceBundle = latestAnalystEvidenceBundleForOwnerDecisionDesk(
                evidenceBundles: evidenceBundles,
                request: request,
                linkedMemo: linkedMemo,
                linkedTask: linkedTask,
                linkedFinding: linkedFinding
            )
            let linkedSourceSuggestions = relevantSourceAccessSuggestionsForOwnerDecisionDesk(
                sourceAccessSuggestions: sourceAccessSuggestions,
                request: request,
                linkedMemo: linkedMemo,
                linkedTask: linkedTask,
                linkedFinding: linkedFinding,
                linkedEvidenceBundle: linkedEvidenceBundle
            )
            let ownerTrustSummary = linkedMemo.map { memo in
                makeOwnerResearchTrustSummaryPresentation(
                    memo: memo,
                    linkedEvidenceBundle: linkedEvidenceBundle,
                    relevantSourceSuggestions: linkedSourceSuggestions
                )
            }
            let linkedCommunication = linkedCommunicationMessage(
                for: request,
                messages: communicationMessages
            )
            let linkedDelegationObservability = linkedDelegation.map { delegation in
                makePMDelegationObservabilitySummary(
                    delegation: delegation,
                    charterDefaultRuntimePolicy: chartersByID[delegation.charterId]?.defaultRuntimePolicy,
                    task: linkedTask
                )
            }
            let memo = makePMApprovalRequestMemoPresentation(
                request: request,
                linkedDecision: linkedDecision,
                executionAssessment: request.lastExecutionRoutingAssessment,
                linkedDelegation: linkedDelegation,
                linkedDelegationObservability: linkedDelegationObservability,
                linkedTask: linkedTask,
                linkedFinding: linkedFinding,
                linkedCommunicationMessage: linkedCommunication,
                linkedMemo: linkedMemo,
                strategyBrief: strategyBrief
            )

            return OwnerDecisionDeskItemPresentation(
                approvalRequestId: request.approvalRequestId,
                title: request.subject,
                requestTypeTitle: pmApprovalRequestTypeDisplayTitle(request.requestType),
                initiativePosture: memo.initiativePosture,
                initiativeSummary: memo.initiativeSummary,
                coherence: memo.coherence,
                closure: memo.closure,
                ownerAsk: memo.requestedAction,
                whyNow: memo.whyNow,
                recommendation: memo.recommendation,
                strategicAlignment: memo.strategicAlignment,
                portfolioContextSummary: memo.portfolioContextSummary,
                researchTrustLabel: ownerTrustSummary?.trustLabel,
                researchTrustSummary: ownerTrustSummary?.trustSummary,
                researchTrustSourceConstraintSummary: ownerTrustSummary?.sourceConstraintSummary,
                supportingEvidence: memo.evidenceSummary,
                uncertaintySummary: memo.uncertaintySummary,
                approvedNextStep: memo.approvedNextStep,
                declinedNextStep: memo.rejectedNextStep,
                moreWorkNextStep: memo.reviewedNextStep,
                linkedProposalId: request.proposalId,
                linkedCommunicationSummary: linkedCommunication.map { summarizeOwnerConversationMessage($0.body) },
                routingStatusSummary: ownerDecisionDeskRoutingStatusSummary(for: request),
                boundaryNote: memo.boundaryNote
            )
        }
        .sorted(by: { lhs, rhs in
            guard let lhsRequest = approvalRequests.first(where: { $0.approvalRequestId == lhs.approvalRequestId }),
                  let rhsRequest = approvalRequests.first(where: { $0.approvalRequestId == rhs.approvalRequestId })
            else {
                return lhs.approvalRequestId < rhs.approvalRequestId
            }
            return ownerApprovalRequestsNewestFirst(lhs: lhsRequest, rhs: rhsRequest)
        })
}

public func makeOwnerActionableApprovalRequests(
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord]
) -> [PMApprovalRequest] {
    let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.decisionId, $0) })
    return approvalRequests.filter { request in
        guard isExercisePMApprovalRequest(request) == false else {
            return false
        }
        let linkedDecision = request.decisionId.flatMap { decisionsByID[$0] }
        let closure = makePMRecommendationClosurePresentation(
            request: request,
            linkedDecision: linkedDecision,
            executionAssessment: request.lastExecutionRoutingAssessment
        )
        return closure.ownerPending || shouldSurfaceApprovedLiveOrderReviewRouteStatus(request)
    }
}

public func isPMApprovalRequestClearableFromActiveDecisions(
    _ request: PMApprovalRequest
) -> Bool {
    guard request.status != .pending,
          request.ownerAcknowledgedAt == nil else {
        return false
    }

    if request.liveOrderExecutionLifecycleState?.status.isTerminal == true {
        return true
    }

    guard request.requestType == .liveOrderReview else {
        return false
    }

    if request.ownerResponse == .rejected || request.ownerResponse == .reviewed {
        return true
    }

    if request.status == .withdrawn || request.status == .stale {
        return true
    }

    guard request.status == .resolved,
          request.ownerResponse == .approved else {
        return false
    }

    guard let assessment = request.lastExecutionRoutingAssessment else {
        return true
    }

    switch assessment.status {
    case .blockedMissingProposalApproval,
         .blockedLiveNotArmed,
         .blockedKillSwitch,
         .blockedEnvironmentMismatch,
         .blockedExecutionPrerequisites,
         .launchFailed,
         .invalidState:
        return true
    case .executableNowPaper,
         .executableNowLive,
         .routedSuccessfully,
         .partiallyRouted:
        return false
    }
}

private func shouldSurfaceApprovedLiveOrderReviewRouteStatus(
    _ request: PMApprovalRequest
) -> Bool {
    guard request.requestType == .liveOrderReview,
          request.status == .resolved,
          request.ownerResponse == .approved else {
        return false
    }
    if request.ownerAcknowledgedAt != nil {
        return false
    }
    if request.liveOrderExecutionLifecycleState?.status.isTerminal == true {
        return false
    }
    guard let assessment = request.lastExecutionRoutingAssessment else {
        return false
    }
    switch assessment.status {
    case .routedSuccessfully:
        return false
    case .executableNowLive,
         .executableNowPaper,
         .blockedMissingProposalApproval,
         .blockedLiveNotArmed,
         .blockedKillSwitch,
         .blockedEnvironmentMismatch,
         .blockedExecutionPrerequisites,
         .partiallyRouted,
         .launchFailed,
         .invalidState:
        return true
    }
}

private func ownerDecisionDeskRoutingStatusSummary(
    for request: PMApprovalRequest
) -> String? {
    if let lifecycle = request.liveOrderExecutionLifecycleState {
        return "Live order lifecycle: \(lifecycle.summary) \(lifecycle.detail)"
    }
    if let assessment = request.lastExecutionRoutingAssessment {
        return ownerDecisionDeskRoutingStatusSummary(assessment)
    }
    guard request.requestType == .liveOrderReview,
          request.status == .resolved,
          request.ownerResponse == .approved else {
        return nil
    }
    return "Approved Live order review: no governed route/preflight result has been recorded yet. No order status is available from this review unless Orders Blotter shows a real Engine order."
}

private func ownerDecisionDeskRoutingStatusSummary(
    _ assessment: PMExecutionRoutingAssessment
) -> String {
    let blocked = assessment.blockedReasons.map(pmExecutionRoutingBlockReasonDescription)
    let blockedText = blocked.isEmpty ? "" : " Blockers: \(blocked.joined(separator: " "))"
    return "\(pmExecutionRoutingStatusDisplayTitle(assessment.status)): \(assessment.summary) \(assessment.detail)\(blockedText)"
}

private func latestAnalystMemoForOwnerDecisionDesk(
    memos: [AnalystMemo],
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord?,
    linkedDelegation: PMDelegationRecord?,
    linkedTask: AnalystTask?,
    linkedFinding: AnalystFinding?
) -> AnalystMemo? {
    memos
        .filter { memo in
            if let delegationID = linkedDelegation?.delegationId ?? request.delegationId, memo.delegationId == delegationID {
                return true
            }
            if let memoID = request.sourceAnalystMemoId, memo.memoId == memoID {
                return true
            }
            if let taskID = linkedTask?.taskId ?? linkedDecision?.taskId, memo.taskId == taskID {
                return true
            }
            if let findingID = linkedFinding?.findingId ?? request.findingId, memo.findingId == findingID {
                return true
            }
            return false
        }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.memoId < rhs.memoId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        .first
}

private func latestAnalystEvidenceBundleForOwnerDecisionDesk(
    evidenceBundles: [AnalystEvidenceBundle],
    request: PMApprovalRequest,
    linkedMemo: AnalystMemo?,
    linkedTask: AnalystTask?,
    linkedFinding: AnalystFinding?
) -> AnalystEvidenceBundle? {
    evidenceBundles
        .filter { bundle in
            if let bundleID = request.sourceAnalystEvidenceBundleId, bundle.bundleId == bundleID {
                return true
            }
            if let bundleID = linkedMemo?.evidenceBundleId, bundle.bundleId == bundleID {
                return true
            }
            if let bundleID = linkedFinding?.evidenceBundleId, bundle.bundleId == bundleID {
                return true
            }
            if let taskID = linkedTask?.taskId, bundle.taskId == taskID {
                return true
            }
            return false
        }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.bundleId < rhs.bundleId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        .first
}

private func relevantSourceAccessSuggestionsForOwnerDecisionDesk(
    sourceAccessSuggestions: [AnalystSourceAccessSuggestionRecord],
    request: PMApprovalRequest,
    linkedMemo: AnalystMemo?,
    linkedTask: AnalystTask?,
    linkedFinding: AnalystFinding?,
    linkedEvidenceBundle: AnalystEvidenceBundle?
) -> [AnalystSourceAccessSuggestionRecord] {
    let filtered = sourceAccessSuggestions.filter { suggestion in
        if suggestion.memoId == linkedMemo?.memoId || suggestion.memoId == request.sourceAnalystMemoId {
            return true
        }
        if suggestion.taskId == linkedTask?.taskId {
            return true
        }
        if suggestion.findingId == linkedFinding?.findingId || suggestion.findingId == request.findingId {
            return true
        }
        if suggestion.evidenceBundleId == linkedEvidenceBundle?.bundleId
            || suggestion.evidenceBundleId == request.sourceAnalystEvidenceBundleId {
            return true
        }
        if suggestion.delegationId == request.delegationId {
            return true
        }
        if suggestion.charterId == linkedMemo?.charterId {
            return true
        }
        return false
    }

    return filtered.sorted { lhs, rhs in
        if lhs.updatedAt == rhs.updatedAt {
            return lhs.suggestionId < rhs.suggestionId
        }
        return lhs.updatedAt > rhs.updatedAt
    }
}

public struct OwnerPMConversationRoutineFilterCache: Sendable {
    private struct Entry: Sendable {
        var senderRole: PMCommunicationSenderRole
        var updatedAt: Date
        var bodyUTF8Count: Int
        var isRoutine: Bool
        var touchedAt: Int
    }

    private var entries: [String: Entry]
    private var generation: Int
    private let limit: Int
    public private(set) var scannedMessageCount: Int

    public init(limit: Int = 2_048) {
        self.entries = [:]
        self.generation = 0
        self.limit = max(16, limit)
        self.scannedMessageCount = 0
    }

    public var entryCount: Int {
        entries.count
    }

    public var entryLimit: Int {
        limit
    }

    public mutating func isRoutineStandingReviewMessage(
        _ message: PMCommunicationMessage
    ) -> Bool {
        generation += 1
        let bodyUTF8Count = message.body.utf8.count
        if let entry = entries[message.messageId],
           entry.senderRole == message.senderRole,
           entry.updatedAt == message.updatedAt,
           entry.bodyUTF8Count == bodyUTF8Count {
            entries[message.messageId]?.touchedAt = generation
            return entry.isRoutine
        }

        scannedMessageCount += 1
        let isRoutine = isRoutineStandingReviewConversationMessage(message)
        entries[message.messageId] = Entry(
            senderRole: message.senderRole,
            updatedAt: message.updatedAt,
            bodyUTF8Count: bodyUTF8Count,
            isRoutine: isRoutine,
            touchedAt: generation
        )
        pruneIfNeeded()
        return isRoutine
    }

    public mutating func removeAll() {
        entries.removeAll(keepingCapacity: true)
        generation = 0
        scannedMessageCount = 0
    }

    private mutating func pruneIfNeeded() {
        guard entries.count > limit else {
            return
        }
        let overflow = entries.count - limit
        let keysToRemove = entries
            .sorted { lhs, rhs in
                if lhs.value.touchedAt == rhs.value.touchedAt {
                    return lhs.key < rhs.key
                }
                return lhs.value.touchedAt < rhs.value.touchedAt
            }
            .prefix(overflow)
            .map(\.key)
        for key in keysToRemove {
            entries.removeValue(forKey: key)
        }
    }
}

public struct OwnerPMConversationPresentationComputation: Sendable, Equatable {
    public let presentation: OwnerPMConversationPresentation?
    public let matchingMessageCount: Int
    public let routineFilterScannedMessageCount: Int

    public init(
        presentation: OwnerPMConversationPresentation?,
        matchingMessageCount: Int,
        routineFilterScannedMessageCount: Int
    ) {
        self.presentation = presentation
        self.matchingMessageCount = matchingMessageCount
        self.routineFilterScannedMessageCount = routineFilterScannedMessageCount
    }
}

public func makeOwnerPMConversationPresentationComputation(
    sessions: [PMCommunicationSession],
    messages: [PMCommunicationMessage],
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord] = [],
    routineFilterCache: inout OwnerPMConversationRoutineFilterCache
) -> OwnerPMConversationPresentationComputation {
    let initialRoutineScanCount = routineFilterCache.scannedMessageCount
    let ownerSessions = sessions
        .filter {
            isOwnerFacingPMConversationChannel($0.channel)
                && isExercisePMCommunicationSession($0) == false
        }
        .sorted(by: pmCommunicationSessionsNewestFirst)
    let activeOwnerSessions = ownerSessions.filter { $0.status == .active }
    let inAppOwnerSessions = ownerSessions.filter { $0.channel == .inApp }
    let activeInAppOwnerSessions = inAppOwnerSessions.filter { $0.status == .active }

    guard let session = (
        activeInAppOwnerSessions.first
            ?? inAppOwnerSessions.first
            ?? activeOwnerSessions.first
            ?? ownerSessions.first
    )
    else {
        return OwnerPMConversationPresentationComputation(
            presentation: nil,
            matchingMessageCount: 0,
            routineFilterScannedMessageCount: routineFilterCache.scannedMessageCount - initialRoutineScanCount
        )
    }

    let continuitySessions = ownerSessions.filter { candidate in
        ownerFacingSessionsShareContinuity(candidate, session)
    }
    let continuitySessionIDs = Set(continuitySessions.map(\.sessionId))

    var matchingMessageCount = 0
    var latestMessage: PMCommunicationMessage?
    var latestPMMessage: PMCommunicationMessage?
    var latestOwnerReply: PMCommunicationMessage?
    var visibleMessageCandidates: [PMCommunicationMessage] = []

    for message in messages where continuitySessionIDs.contains(message.sessionId)
        && isExercisePMCommunicationMessage(message) == false
        && (
            message.senderRole != .pm
                || routineFilterCache.isRoutineStandingReviewMessage(message) == false
        ) {
        matchingMessageCount += 1

        if let currentLatest = latestMessage {
            if pmCommunicationMessagesOldestFirst(lhs: currentLatest, rhs: message) {
                latestMessage = message
            }
        } else {
            latestMessage = message
        }

        switch message.senderRole {
        case .pm:
            if let currentLatestPM = latestPMMessage {
                if pmCommunicationMessagesOldestFirst(lhs: currentLatestPM, rhs: message) {
                    latestPMMessage = message
                }
            } else {
                latestPMMessage = message
            }
        case .owner:
            if let currentLatestOwner = latestOwnerReply {
                if pmCommunicationMessagesOldestFirst(lhs: currentLatestOwner, rhs: message) {
                    latestOwnerReply = message
                }
            } else {
                latestOwnerReply = message
            }
        case .system:
            break
        }

        visibleMessageCandidates.append(message)
        if visibleMessageCandidates.count > OwnerSurfaceProjectionBudget.visiblePMConversationMessages {
            visibleMessageCandidates.sort(by: pmCommunicationMessagesOldestFirst)
            visibleMessageCandidates.removeFirst(
                visibleMessageCandidates.count - OwnerSurfaceProjectionBudget.visiblePMConversationMessages
            )
        }
    }

    let visibleMessages = visibleMessageCandidates
        .sorted(by: pmCommunicationMessagesOldestFirst)
        .map {
        OwnerPMConversationMessagePresentation(
            messageId: $0.messageId,
            speakerLabel: ownerConversationSpeakerLabel(for: $0.senderRole),
            body: ownerConversationVisibleMessageBody($0.body),
            emphasized: $0.senderRole == .pm
        )
    }
    let awaitingPMReply = latestMessage?.senderRole == .owner
    let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.decisionId, $0) })
    let currentAsk = approvalRequests
        .filter { isExercisePMApprovalRequest($0) == false }
        .sorted(by: ownerApprovalRequestsNewestFirst)
        .first { request in
            let linkedDecision = request.decisionId.flatMap { decisionsByID[$0] }
            let closure = makePMRecommendationClosurePresentation(
                request: request,
                linkedDecision: linkedDecision
            )
            return closure.ownerPending
                && shouldSurfaceStandingReviewOwnerDecision(
                    request: request,
                    linkedDecision: linkedDecision
                )
        }
    let currentAskClosure = currentAsk.map { request in
        makePMRecommendationClosurePresentation(
            request: request,
            linkedDecision: request.decisionId.flatMap { decisionsByID[$0] }
        )
    }
    let ownerComposerTitle = currentAsk == nil ? "Start A New Ask" : "Reply To PM"
    let ownerComposerHint = currentAsk == nil
        ? "Ask the PM for research, clarification, follow-up work, or a fresh review."
        : "You can answer the current PM ask or give the PM more direction."

    return OwnerPMConversationPresentationComputation(
        presentation: OwnerPMConversationPresentation(
            visibleMessages: visibleMessages,
            sessionId: session.sessionId,
            participantName: "PM",
            sessionSummary: ownerPMConversationSessionSummary(
                messageCount: matchingMessageCount,
                channels: continuitySessions.map(\.channel)
            ),
            latestPMMessage: latestPMMessage.map { summarizeOwnerConversationMessage($0.body) },
            latestOwnerReply: latestOwnerReply.map { summarizeOwnerConversationMessage($0.body) },
            awaitingPMReply: awaitingPMReply,
            replyRoutingSummary: ownerPMConversationReplyRoutingSummary(
                channels: continuitySessions.map(\.channel)
            ),
            currentAskTitle: currentAsk?.subject,
            currentAskSummary: currentAsk?.requestedActionSummary ?? currentAsk?.rationale,
            currentAskLifecycleSummary: currentAskClosure?.ownerSummary,
            ownerComposerTitle: ownerComposerTitle,
            ownerComposerHint: ownerComposerHint
        ),
        matchingMessageCount: matchingMessageCount,
        routineFilterScannedMessageCount: routineFilterCache.scannedMessageCount - initialRoutineScanCount
    )
}

public func makeOwnerPMConversationPresentation(
    sessions: [PMCommunicationSession],
    messages: [PMCommunicationMessage],
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord] = []
) -> OwnerPMConversationPresentation? {
    var routineFilterCache = OwnerPMConversationRoutineFilterCache()
    return makeOwnerPMConversationPresentationComputation(
        sessions: sessions,
        messages: messages,
        approvalRequests: approvalRequests,
        decisions: decisions,
        routineFilterCache: &routineFilterCache
    ).presentation
}

public func makeOwnerPMSurfaceCoordinationPresentation(
    telegramStatus: TelegramBridgeStatus,
    runtimeSettings: PMRuntimeSettings?
) -> OwnerPMSurfaceCoordinationPresentation {
    let telegramSummary: String
    if telegramStatus.allowlistedOwnerChatId?.isEmpty == false {
        telegramSummary = "Telegram continues the same PM relationship remotely over the owner-only route."
    } else if telegramStatus.tokenConfigured {
        telegramSummary = "Telegram is available for remote continuation once the owner route is bound."
    } else {
        telegramSummary = "Telegram remote continuation is not configured yet."
    }

    let runtimeSummary: String
    if let runtimeSettings {
        runtimeSummary = makeRuntimeOperabilityPresentation(
            pmRuntimeSettings: runtimeSettings
        )?.ownerSurfaceSummary
            ?? "PM runtime preference follows the current app-owned default until you change it in Settings."
    } else {
        runtimeSummary = "PM runtime preference follows the current app-owned default until you change it in Settings."
    }

    return OwnerPMSurfaceCoordinationPresentation(
        commandCenterSummary: "Command Center is the main owner desk for PM conversation, recommendations, and decisions.",
        telegramSummary: telegramSummary,
        pmInboxSummary: "PM Inbox stays advanced and traceability-focused: communication log, promotion, workflow detail, and auditability.",
        runtimeSummary: runtimeSummary
    )
}

public func makePMInboxCommunicationReviewPresentation(
    sessionCount: Int
) -> PMInboxCommunicationReviewPresentation {
    if sessionCount == 0 {
        return PMInboxCommunicationReviewPresentation(
            title: "No Communication Log Yet",
            summary: "Start the owner-facing PM conversation from Command Center. Telegram continues that same relationship remotely, while PM Inbox keeps the deeper communication log and promotion tools.",
            primaryActionLabel: "Open Command Center",
            ownerComposeAllowed: false
        )
    }

    return PMInboxCommunicationReviewPresentation(
        title: "Communication Log",
        summary: "Use Command Center when you want to talk to the PM. Telegram is the remote continuation of that same PM relationship. PM Inbox stays focused on communication review, auditability, and promotion.",
        primaryActionLabel: "Open Command Center",
        ownerComposeAllowed: false
    )
}

public func makeStrategyBriefConversationRevisionCandidatePresentation(
    sessions: [PMCommunicationSession],
    messages: [PMCommunicationMessage],
    messageScanLimit: Int = 160
) -> StrategyBriefConversationRevisionCandidatePresentation? {
    makeStrategyBriefConversationRevisionCandidateComputation(
        sessions: sessions,
        messages: messages,
        messageScanLimit: messageScanLimit
    ).candidate
}

public func makeStrategyBriefConversationRevisionCandidateComputation(
    sessions: [PMCommunicationSession],
    messages: [PMCommunicationMessage],
    messageScanLimit: Int = 160
) -> StrategyBriefConversationRevisionCandidateComputation {
    let boundedLimit = max(1, messageScanLimit)
    var selectedSession: PMCommunicationSession?
    for session in sessions
    where session.channel == .inApp && isExercisePMCommunicationSession(session) == false {
        guard let existing = selectedSession else {
            selectedSession = session
            continue
        }
        if pmCommunicationSessionsNewestFirst(lhs: session, rhs: existing) {
            selectedSession = session
        }
    }

    guard let session = selectedSession else {
        return StrategyBriefConversationRevisionCandidateComputation(
            candidate: nil,
            scannedMessageCount: 0,
            consideredMessageCount: 0,
            selectedSessionId: nil,
            messageScanLimit: boundedLimit
        )
    }

    var scannedMessageCount = 0
    var consideredMessageCount = 0
    var preferredMessage: PMCommunicationMessage?
    for message in messages.reversed() where message.sessionId == session.sessionId {
        guard isExercisePMCommunicationMessage(message) == false else {
            continue
        }
        consideredMessageCount += 1
        if message.senderRole == .pm {
            scannedMessageCount += 1
            if isStrategyBriefRevisionEligibleMessage(message.body) {
                preferredMessage = message
                break
            }
        }
        if consideredMessageCount >= boundedLimit {
            break
        }
    }

    guard let message = preferredMessage else {
        return StrategyBriefConversationRevisionCandidateComputation(
            candidate: nil,
            scannedMessageCount: scannedMessageCount,
            consideredMessageCount: consideredMessageCount,
            selectedSessionId: session.sessionId,
            messageScanLimit: boundedLimit
        )
    }

    let senderLabel: String
    let revisionPrefix: String
    switch message.senderRole {
    case .owner:
        senderLabel = "Owner instruction"
        revisionPrefix = "Conversation-derived revision from owner instruction"
    case .pm:
        senderLabel = "Optional PM revision note"
        revisionPrefix = "Conversation-derived PM revision note"
    case .system:
        senderLabel = "System note"
        revisionPrefix = "Conversation-derived revision"
    }

    let summary = summarizeOwnerConversationMessage(message.body)
    let candidate = StrategyBriefConversationRevisionCandidatePresentation(
        messageId: message.messageId,
        senderLabel: senderLabel,
        messageSummary: summary,
        revisionSuggestion: "\(revisionPrefix): \(summary)"
    )
    return StrategyBriefConversationRevisionCandidateComputation(
        candidate: candidate,
        scannedMessageCount: scannedMessageCount,
        consideredMessageCount: consideredMessageCount,
        selectedSessionId: session.sessionId,
        messageScanLimit: boundedLimit
    )
}

public func countActivePMExerciseArtifacts(
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord],
    delegations: [PMDelegationRecord],
    communicationSessions: [PMCommunicationSession]
) -> Int {
    approvalRequests.filter { isExercisePMApprovalRequest($0) && $0.status == .pending }.count
        + decisions.filter { isExercisePMDecision($0) && $0.status == .active }.count
        + delegations.filter { isExercisePMDelegation($0) && $0.status == .issued }.count
        + communicationSessions.filter { isExercisePMCommunicationSession($0) && $0.status == .active }.count
}

public func isExercisePMApprovalRequest(_ request: PMApprovalRequest) -> Bool {
    isExerciseArtifactIdentifier(request.approvalRequestId) || request.pmId == "pm-operational-exercise"
}

public func isExercisePMDecision(_ decision: PMDecisionRecord) -> Bool {
    isExerciseArtifactIdentifier(decision.decisionId) || decision.pmId == "pm-operational-exercise"
}

public func isExercisePMDelegation(_ delegation: PMDelegationRecord) -> Bool {
    isExerciseArtifactIdentifier(delegation.delegationId)
        || delegation.pmId == "pm-operational-exercise"
        || delegation.taskId.map(isExerciseArtifactIdentifier(_:)) == true
}

public func isExercisePMCommunicationSession(_ session: PMCommunicationSession) -> Bool {
    isExerciseArtifactIdentifier(session.sessionId)
        || session.pmId == PMProfile.operationalExercisePMID
        || session.participantId == "owner-exercise"
}

public func isExercisePMCommunicationMessage(_ message: PMCommunicationMessage) -> Bool {
    isExerciseArtifactIdentifier(message.messageId)
        || isExerciseArtifactIdentifier(message.sessionId)
        || message.senderId == "owner-exercise"
        || message.senderId == "pm-operational-exercise"
}

public func isExerciseArtifactIdentifier(_ value: String) -> Bool {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .hasPrefix("exercise-")
}

private func linkedCommunicationMessage(
    for request: PMApprovalRequest,
    messages: [PMCommunicationMessage]
) -> PMCommunicationMessage? {
    if let messageID = request.sourceCommunicationMessageId {
        return messages.first(where: { $0.messageId == messageID })
    }
    return messages.first(where: {
        $0.promotion?.targetType == .approvalRequest && $0.promotion?.targetId == request.approvalRequestId
    })
}

private func summarizeOwnerConversationMessage(_ body: String) -> String {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 140 else {
        return trimmed
    }
    return String(trimmed.prefix(137)) + "..."
}

private func isOwnerFacingPMConversationChannel(_ channel: PMCommunicationChannel) -> Bool {
    switch channel {
    case .inApp, .telegram, .mockTelegram:
        return true
    case .genericRemote:
        return false
    }
}

private func ownerFacingSessionsShareContinuity(
    _ lhs: PMCommunicationSession,
    _ rhs: PMCommunicationSession
) -> Bool {
    guard isOwnerFacingPMConversationChannel(lhs.channel),
          isOwnerFacingPMConversationChannel(rhs.channel) else {
        return false
    }

    return true
}

private func ownerPMConversationSessionSummary(
    messageCount: Int,
    channels: [PMCommunicationChannel]
) -> String {
    let channelSummary = ownerPMConversationChannelSummary(channels)
    return "\(messageCount) message\(messageCount == 1 ? "" : "s") • \(channelSummary)"
}

private func ownerPMConversationReplyRoutingSummary(
    channels: [PMCommunicationChannel]
) -> String {
    if ownerPMConversationContainsTelegram(channels) {
        return "This Command Center history includes Telegram-carried turns for the same PM relationship. Messages you send here stay in the app by default, while Telegram-started replies still route back through Telegram."
    }

    return "This Command Center history is the main app-owned PM conversation. Messages you send here stay in the app by default."
}

private func ownerPMConversationChannelSummary(
    _ channels: [PMCommunicationChannel]
) -> String {
    var orderedLabels: [String] = []
    for channel in channels {
        let label: String
        switch channel {
        case .inApp:
            label = "In App"
        case .telegram, .mockTelegram:
            label = "Telegram"
        case .genericRemote:
            label = "Remote"
        }
        if orderedLabels.contains(label) == false {
            orderedLabels.append(label)
        }
    }

    if orderedLabels.isEmpty {
        return "In App"
    }
    if orderedLabels.count == 1 {
        return orderedLabels[0]
    }
    return orderedLabels.joined(separator: " + ")
}

private func ownerPMConversationContainsTelegram(
    _ channels: [PMCommunicationChannel]
) -> Bool {
    channels.contains { channel in
        channel == .telegram || channel == .mockTelegram
    }
}

private func ownerConversationVisibleMessageBody(_ body: String) -> String {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    let maxCharacters = OwnerSurfaceProjectionBudget.visiblePMConversationMessageCharacters
    guard trimmed.count > maxCharacters else {
        return trimmed
    }

    let truncationNote = "\n\n[Shortened for Command Center. Full message remains in PM Inbox and durable history.]"
    let prefixLimit = max(0, maxCharacters - truncationNote.count)
    return String(trimmed.prefix(prefixLimit))
        .trimmingCharacters(in: .whitespacesAndNewlines) + truncationNote
}

private func isRoutineStandingReviewConversationMessage(
    _ message: PMCommunicationMessage
) -> Bool {
    guard message.senderRole == .pm else {
        return false
    }
    let normalized = message.body.lowercased()
    return normalized.contains("i woke on app open and found")
        || normalized.contains("picking it up for pm review now")
        || normalized.contains("i completed the current standing-review cycle")
        || normalized.contains("standing-review artifacts, not proposals")
}

private func ownerConversationSpeakerLabel(for role: PMCommunicationSenderRole) -> String {
    switch role {
    case .owner:
        return "You"
    case .pm:
        return "PM"
    case .system:
        return "System"
    }
}

private func isStrategyBriefRevisionEligibleMessage(_ body: String) -> Bool {
    let normalized = body.lowercased()
    let mentionsBrief = normalized.contains("portfolio strategy brief")
        || normalized.contains("strategy brief")
        || (normalized.contains("brief") && normalized.contains("strategy"))
    let mentionsRevisionIntent = normalized.contains("revise")
        || normalized.contains("revision")
        || normalized.contains("update")
        || normalized.contains("question")
        || normalized.contains("comment")
        || normalized.contains("document")
    return mentionsBrief && mentionsRevisionIntent
}

private func pmCommunicationSessionsNewestFirst(lhs: PMCommunicationSession, rhs: PMCommunicationSession) -> Bool {
    if lhs.updatedAt == rhs.updatedAt {
        return lhs.sessionId < rhs.sessionId
    }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmCommunicationMessagesOldestFirst(lhs: PMCommunicationMessage, rhs: PMCommunicationMessage) -> Bool {
    if lhs.sentAt == rhs.sentAt {
        return lhs.messageId < rhs.messageId
    }
    return lhs.sentAt < rhs.sentAt
}

private func ownerApprovalRequestsNewestFirst(lhs: PMApprovalRequest, rhs: PMApprovalRequest) -> Bool {
    if lhs.createdAt == rhs.createdAt {
        return lhs.approvalRequestId < rhs.approvalRequestId
    }
    return lhs.createdAt > rhs.createdAt
}

private func countSentence(
    _ count: Int,
    zero: String,
    singular: String,
    plural: String
) -> String {
    switch count {
    case 0:
        return zero
    case 1:
        return singular
    default:
        return plural
    }
}
