import Foundation
import Testing
@testable import TradingKit

@Test("Owner decision desk only surfaces pending non-exercise asks")
func ownerDecisionDeskShowsOnlyOwnerActionableItems() {
    let now = Date(timeIntervalSince1970: 1_742_700_000)
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Keep the portfolio tilted toward high-conviction compounders while keeping concentration risk disciplined.",
        keyThemes: ["quality growth", "concentration discipline"],
        currentRiskPosture: "Stay constructive, but tighten review around concentration changes.",
        reviewEscalationPosture: "Escalate meaningful posture changes quickly.",
        updatedBy: "pm-1",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Review bounded next step",
        summary: "The PM recommends a bounded paper-safe next step.",
        recommendedAction: "Move into the next separate paper-safe review step.",
        evidenceSummary: "Analyst evidence supports the bounded recommendation.",
        ownerAsk: "Approve the PM opening the next bounded step.",
        approvedNextStepSummary: "If approved, the PM can move into the next separate paper-safe review step.",
        sourceCommunicationMessageId: "message-1",
        delegationId: "delegation-1",
        taskId: "task-1",
        createdAt: now,
        updatedAt: now
    )
    let pending = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "A bounded owner decision is needed now.",
        requestedActionSummary: "Decide whether the PM should proceed.",
        approvedNextStepSummary: "If approved, the PM can proceed to the next separate step.",
        sourceCommunicationMessageId: "message-1",
        requestType: .proposalReview,
        status: .pending,
        decisionId: decision.decisionId,
        delegationId: "delegation-1",
        createdAt: now,
        updatedAt: now
    )
    let resolved = PMApprovalRequest(
        approvalRequestId: "approval-2",
        pmId: "pm-1",
        subject: "Old resolved request",
        rationale: "Already handled.",
        requestType: .other,
        status: .resolved,
        createdAt: now.addingTimeInterval(-60),
        updatedAt: now.addingTimeInterval(-60)
    )
    let exercise = PMApprovalRequest(
        approvalRequestId: "exercise-approval-request-1",
        pmId: "pm-operational-exercise",
        subject: "Exercise review",
        rationale: "Exercise-only owner review.",
        requestType: .proposalReview,
        status: .pending,
        createdAt: now.addingTimeInterval(60),
        updatedAt: now.addingTimeInterval(60)
    )
    let message = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: "pm-user-in-app-default",
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "Please review the bounded next step.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Next step review",
        description: "Review the next step. Portfolio strategy brief objective: Keep the portfolio tilted toward high-conviction compounders while keeping concentration risk disciplined. Strategy themes: quality growth; concentration discipline. Current risk posture: Stay constructive, but tighten review around concentration changes.",
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let delegation = PMDelegationRecord(
        delegationId: "delegation-1",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: task.taskId,
        title: "Review next step",
        rationale: "Need a current read before owner review.",
        requestedOutputs: [.finding],
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: task.taskId,
        delegationId: delegation.delegationId,
        pmId: "pm-1",
        title: "Owner review support memo",
        executiveSummary: "A bounded next step is justified, but concentration still warrants care.",
        currentView: "Advance only one step and keep the owner directly in the loop.",
        evidenceSummary: "Current concentration and catalyst posture support a measured next step.",
        uncertaintySummary: "The direction is clear, but timing and sizing still deserve caution.",
        recommendedNextStep: "Advance to the next bounded step only if the owner agrees.",
        confidence: 0.68,
        createdAt: now,
        updatedAt: now
    )

    let items = makeOwnerDecisionDeskPresentations(
        approvalRequests: [resolved, exercise, pending],
        decisions: [decision],
        delegations: [delegation],
        tasks: [task],
        findings: [],
        communicationMessages: [message],
        charters: [],
        memos: [memo],
        strategyBrief: strategyBrief
    )

    #expect(items.count == 1)
    #expect(items.first?.approvalRequestId == pending.approvalRequestId)
    #expect(items.first?.title == pending.subject)
    #expect(items.first?.initiativePosture == .ownerDecisionRequired)
    #expect(items.first?.initiativeSummary.contains("Owner decision:") == true)
    #expect(items.first?.coherence.actionabilityCategory == .ownerDecisionRequired)
    #expect(items.first?.coherence.ownerTitle == "Decision Required")
    #expect(items.first?.closure.status == .awaitingOwner)
    #expect(items.first?.ownerAsk == pending.requestedActionSummary)
    #expect(items.first?.strategicAlignment?.contains("Current strategy objective") == true)
    #expect(items.first?.uncertaintySummary == memo.uncertaintySummary)
    #expect(items.first?.linkedCommunicationSummary?.contains("bounded next step") == true)
}

@Test("Owner-actionable approval filtering matches standing-review suppression")
func ownerActionableApprovalFilteringMatchesStandingReviewSuppression() {
    let now = Date(timeIntervalSince1970: 1_742_700_001)
    let standingDecision = PMDecisionRecord(
        decisionId: "decision-standing-1",
        pmId: "pm-1",
        title: "Standing review escalation: Technology Analyst",
        summary: "The current synthesis is worth monitoring only.",
        recommendedAction: "Remain monitor-only until something materially changes.",
        createdAt: now,
        updatedAt: now
    )
    let suppressedStandingRequest = PMApprovalRequest(
        approvalRequestId: "approval-standing-1",
        pmId: "pm-1",
        subject: "Review standing analyst synthesis: Technology Analyst",
        rationale: "The latest standing review is background-only and should remain monitor-only.",
        status: .pending,
        decisionId: standingDecision.decisionId,
        createdAt: now,
        updatedAt: now
    )
    let realOwnerRequest = PMApprovalRequest(
        approvalRequestId: "approval-real-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "A bounded owner decision is needed now.",
        requestedActionSummary: "Decide whether the PM should proceed.",
        status: .pending,
        createdAt: now.addingTimeInterval(1),
        updatedAt: now.addingTimeInterval(1)
    )

    let actionable = makeOwnerActionableApprovalRequests(
        approvalRequests: [suppressedStandingRequest, realOwnerRequest],
        decisions: [standingDecision]
    )

    #expect(actionable.map(\.approvalRequestId) == ["approval-real-1"])
}

@Test("Owner decision desk surfaces pending Live order review and clears rejected review")
func ownerDecisionDeskSurfacesPendingLiveOrderReviewAndClearsRejectedReview() {
    let now = Date(timeIntervalSince1970: 1_742_700_010)
    let decision = PMDecisionRecord(
        decisionId: "decision-live-order-review-meta",
        pmId: "pm-1",
        title: "Live order review: Buy META ~$10,000 market Day",
        summary: "Review-only instruction: buy approximately $10,000 of META, market order, Day time-in-force.",
        recommendedAction: "Surface the Live order instruction for owner review before any governed order route.",
        ownerAsk: "Approve whether this instruction should advance to the governed in-app order path.",
        sourceCommunicationMessageId: "message-live-order-review-meta",
        decisionType: .recommendation,
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let pending = PMApprovalRequest(
        approvalRequestId: "approval-live-order-review-meta",
        pmId: "pm-1",
        subject: "Approve Live META buy review",
        rationale: "Review-only Live instruction: buy approximately $10,000 of META, market order, Day time-in-force. No order has been submitted.",
        requestedActionSummary: "Review the META Live buy instruction before any governed route, preflight, or LocalAuthentication boundary.",
        approvedNextStepSummary: "If approved, the app may advance to the governed in-app route; Live NEW/REPLACE still requires final local authentication when enabled.",
        rejectedNextStepSummary: "If declined, no order is routed or placed.",
        sourceCommunicationMessageId: "message-live-order-review-meta",
        requestType: .liveOrderReview,
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )
    let rejected = PMApprovalRequest(
        approvalRequestId: "approval-live-order-review-rejected",
        pmId: "pm-1",
        subject: "Approve Live AAPL buy review",
        rationale: "Previously declined review-only Live instruction.",
        requestType: .liveOrderReview,
        status: .resolved,
        ownerResponse: .rejected,
        ownerRespondedAt: now.addingTimeInterval(60),
        createdAt: now.addingTimeInterval(-60),
        updatedAt: now.addingTimeInterval(60)
    )
    let message = PMCommunicationMessage(
        messageId: "message-live-order-review-meta",
        sessionId: "pm-user-in-app-default",
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Buy META, about ten thousand dollars, market order, Day.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let items = makeOwnerDecisionDeskPresentations(
        approvalRequests: [rejected, pending],
        decisions: [decision],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [message],
        charters: [],
        memos: [],
        strategyBrief: nil
    )

    #expect(items.count == 1)
    #expect(items.first?.approvalRequestId == pending.approvalRequestId)
    #expect(items.first?.requestTypeTitle == "Live Order Review")
    #expect(items.first?.ownerAsk.contains("META Live buy instruction") == true)
    #expect(items.first?.ownerAsk.contains("LocalAuthentication") == true)
    #expect(items.first?.declinedNextStep == "If declined, no order is routed or placed.")
    #expect(items.first?.boundaryNote.contains("governed Engine route") == true)
    #expect(items.first?.boundaryNote.contains("LocalAuthentication") == true)
}

@Test("PM event coherence maps postures into stable cross-surface actionability")
func pmEventCoherenceMapsPosturesIntoStableActionability() {
    let clarify = makePMEventCoherencePresentation(
        posture: .clarifyFirst,
        initiativeSummary: "Clarify first: Narrow the request before escalating."
    )
    let bench = makePMEventCoherencePresentation(
        posture: .analystBenchFirst,
        initiativeSummary: "Bench first: Use specialist work before interrupting the owner."
    )
    let summary = makePMEventCoherencePresentation(
        posture: .summarizeAndInform,
        initiativeSummary: "Summary only: Useful context, but not a decision ask."
    )
    let decision = makePMEventCoherencePresentation(
        posture: .ownerDecisionRequired,
        initiativeSummary: "Owner decision: The next step is ready for direction now."
    )
    let quiet = makePMEventCoherencePresentation(
        posture: .stayQuiet,
        initiativeSummary: "Stay quiet: No stronger owner-facing step is justified."
    )

    #expect(clarify.actionabilityCategory == .clarification)
    #expect(clarify.ownerVisible == true)
    #expect(clarify.traceabilityOnly == false)
    #expect(bench.actionabilityCategory == .benchInternal)
    #expect(bench.ownerVisible == false)
    #expect(bench.traceabilityOnly == true)
    #expect(summary.actionabilityCategory == .ownerInformational)
    #expect(summary.ownerTitle == "FYI")
    #expect(decision.actionabilityCategory == .ownerDecisionRequired)
    #expect(decision.ownerTitle == "Decision Required")
    #expect(quiet.actionabilityCategory == .traceabilityOnly)
    #expect(quiet.ownerVisible == false)
    #expect(quiet.pmInboxSummary.contains("Internal PM traceability only.") == true)
}

@Test("Owner decision desk surfaces strategy-change requests with compact portfolio context")
func ownerDecisionDeskSurfacesStrategyChangeRequestsWithPortfolioContext() {
    let now = Date(timeIntervalSince1970: 1_742_700_025)
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Keep the portfolio tilted toward high-conviction compounders while tightening review around strategic posture changes.",
        keyThemes: ["quality growth", "event-aware review"],
        currentRiskPosture: "Moderate risk with explicit owner review for strategic shifts.",
        reviewEscalationPosture: "Escalate bounded strategy changes through owner approval.",
        updatedBy: "human owner",
        updateSource: .userEdited,
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-strategy-1",
        pmId: "pm-1",
        subject: "Review PM-proposed strategy change: Tighten event-risk posture",
        rationale: "Recent analyst work suggests the saved strategy brief should tighten event-risk review before the next earnings cluster.",
        requestedActionSummary: "Decide whether to approve this bounded change to the saved Portfolio Strategy Brief.",
        approvedNextStepSummary: "If approved, the app updates the saved Portfolio Strategy Brief through the explicit owner-approved strategy-change path.",
        rejectedNextStepSummary: "If declined, the saved Portfolio Strategy Brief stays unchanged.",
        reviewedNextStepSummary: "If you ask for more work, the saved Portfolio Strategy Brief stays unchanged while the PM keeps the candidate open.",
        requestType: .strategyChange,
        status: .pending,
        delegationId: "delegation-1",
        findingId: "finding-1",
        sourceAnalystStrategyFollowUpCandidateId: "candidate-1",
        sourceAnalystStrategyImplicationId: "implication-1",
        sourceAnalystMemoId: "memo-1",
        sourceAnalystEvidenceBundleId: "bundle-1",
        strategyChangePortfolioContext: PMStrategyChangePortfolioContextSnapshot(
            positionCount: 3,
            grossExposure: 55_000,
            netExposure: 35_000,
            longExposure: 45_000,
            shortExposure: 10_000,
            longWeight: 0.8181818182,
            shortWeight: 0.1818181818,
            netWeight: 0.6363636364,
            largestPositionSymbol: "NVDA",
            largestPositionWeight: 0.5454545455,
            capturedAt: now
        ),
        createdAt: now,
        updatedAt: now
    )

    let items = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [],
        strategyBrief: strategyBrief
    )

    #expect(items.count == 1)
    #expect(items.first?.requestTypeTitle == "Strategy Change")
    #expect(items.first?.ownerAsk == request.requestedActionSummary)
    #expect(items.first?.portfolioContextSummary?.contains("Current portfolio risk metrics") == true)
    #expect(items.first?.portfolioContextSummary?.contains("Current long-vs-short weighting") == true)
    #expect(items.first?.portfolioContextSummary?.contains("NVDA") == true)
    #expect(items.first?.approvedNextStep?.contains("owner-approved strategy-change path") == true)
    #expect(items.first?.boundaryNote.contains("saved Portfolio Strategy Brief changes only if you explicitly approve") == true)
}

@Test("Owner decision desk surfaces compact research grounding summary for analyst-backed recommendations")
func ownerDecisionDeskSurfacesCompactResearchGroundingSummary() {
    let now = Date(timeIntervalSince1970: 1_742_700_040)
    let decision = PMDecisionRecord(
        decisionId: "decision-research-grounding-1",
        pmId: "pm-1",
        title: "Review bounded recommendation",
        summary: "A bounded recommendation is ready for owner review.",
        evidenceSummary: "Analyst work supports this bounded recommendation.",
        ownerAsk: "Review this recommendation now.",
        delegationId: "delegation-research-1",
        taskId: "task-research-1",
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-research-grounding-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "Analyst synthesis now supports a bounded next step.",
        requestedActionSummary: "Decide whether this recommendation should proceed.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: decision.decisionId,
        delegationId: "delegation-research-1",
        sourceAnalystMemoId: "memo-research-1",
        sourceAnalystEvidenceBundleId: "bundle-research-1",
        createdAt: now,
        updatedAt: now
    )
    let delegation = PMDelegationRecord(
        delegationId: "delegation-research-1",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-research-1",
        title: "Support recommendation",
        rationale: "Need bounded analyst support before owner ask.",
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-research-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Recommendation support",
        description: "Use app news as baseline and add bounded outside corroboration.",
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-research-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-research-1",
        delegationId: delegation.delegationId,
        pmId: "pm-1",
        evidenceBundleId: "bundle-research-1",
        title: "Support memo",
        executiveSummary: "The recommendation is supported with bounded corroboration.",
        currentView: "The thesis is unchanged.",
        evidenceSummary: "Outside evidence provided stronger confirmation while staying supplemental.",
        uncertaintySummary: "Timing remains sensitive.",
        recommendedNextStep: "Proceed only with owner agreement.",
        confidence: 0.66,
        createdAt: now,
        updatedAt: now
    )
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-research-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-research-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-1",
                sourceKind: .appNews,
                sourceIdentifier: "news-1",
                title: "App news baseline",
                observedAt: now,
                summary: "Baseline event context."
            ),
            AnalystEvidenceRef(
                refId: "ref-web-1",
                sourceKind: .web,
                sourceIdentifier: "issuer-site",
                title: "Issuer page",
                observedAt: now,
                summary: "Supplemental role: This source confirms the app-news baseline with stronger or more primary sourcing and adds only limited extra detail."
            )
        ],
        summary: "App news plus corroborating outside confirmation.",
        createdAt: now,
        updatedAt: now
    )

    let items = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [decision],
        delegations: [delegation],
        tasks: [task],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [memo],
        strategyBrief: nil,
        evidenceBundles: [bundle]
    )

    #expect(items.count == 1)
    #expect(items.first?.researchTrustLabel == "Grounding: Outside research corroborated the baseline")
    #expect(items.first?.researchTrustSummary?.contains("corroborate or strengthen the baseline") == true)
    #expect(items.first?.researchTrustSourceConstraintSummary == nil)
}

@Test("Owner decision desk trust summary surfaces source constraints compactly when relevant")
func ownerDecisionDeskTrustSummarySurfacesSourceConstraints() {
    let now = Date(timeIntervalSince1970: 1_742_700_041)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-research-constraints-1",
        pmId: "pm-1",
        subject: "Review PM recommendation with constrained sources",
        rationale: "Outside context improved the read but one source remains restricted.",
        requestedActionSummary: "Decide whether to proceed with this bounded recommendation.",
        requestType: .other,
        status: .pending,
        delegationId: "delegation-research-constraints-1",
        sourceAnalystMemoId: "memo-research-constraints-1",
        sourceAnalystEvidenceBundleId: "bundle-research-constraints-1",
        createdAt: now,
        updatedAt: now
    )
    let delegation = PMDelegationRecord(
        delegationId: "delegation-research-constraints-1",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-research-constraints-1",
        title: "Constrained recommendation support",
        rationale: "Need bounded source-aware analyst support.",
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-research-constraints-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Constrained recommendation support",
        description: "Capture incremental context and source limits.",
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-research-constraints-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-research-constraints-1",
        delegationId: delegation.delegationId,
        pmId: "pm-1",
        evidenceBundleId: "bundle-research-constraints-1",
        title: "Constrained support memo",
        executiveSummary: "Outside context improved the recommendation.",
        currentView: "Use the current read with bounded confidence.",
        evidenceSummary: "Supplemental role: This source adds incremental timing, background, or strategic/risk context beyond the app-news baseline.",
        uncertaintySummary: "One key source remains restricted.",
        recommendedNextStep: "Proceed with explicit confidence bounds.",
        confidence: 0.58,
        createdAt: now,
        updatedAt: now
    )
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-research-constraints-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-research-constraints-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-1",
                sourceKind: .appNews,
                sourceIdentifier: "news-1",
                title: "App news baseline",
                observedAt: now,
                summary: "Baseline event context."
            ),
            AnalystEvidenceRef(
                refId: "ref-web-1",
                sourceKind: .web,
                sourceIdentifier: "industry-source",
                title: "Industry source",
                observedAt: now,
                summary: "Supplemental role: This source adds incremental timing, background, or strategic/risk context beyond the app-news baseline."
            )
        ],
        summary: "Additive outside context.",
        createdAt: now,
        updatedAt: now
    )
    let openSuggestion = AnalystSourceAccessSuggestionRecord(
        suggestionId: "suggestion-open-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-research-constraints-1",
        memoId: "memo-research-constraints-1",
        evidenceBundleId: "bundle-research-constraints-1",
        delegationId: "delegation-research-constraints-1",
        requestedSource: "Issuer investor relations archive",
        requestedDomain: "investor.example.com",
        whyItMatters: "Would improve primary-source confirmation.",
        limitation: .restrictedByPolicy,
        recommendedNextStep: .allowByCharterUpdate,
        status: .open,
        createdAt: now,
        updatedAt: now
    )

    let items = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [],
        delegations: [delegation],
        tasks: [task],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [memo],
        strategyBrief: nil,
        evidenceBundles: [bundle],
        sourceAccessSuggestions: [openSuggestion]
    )

    #expect(items.count == 1)
    #expect(items.first?.researchTrustLabel == "Grounding: Outside research materially improved the read")
    #expect(items.first?.researchTrustSummary?.contains("materially improved timing, context, or strategic/risk interpretation") == true)
    #expect(items.first?.researchTrustSourceConstraintSummary?.contains("Important sources are still constrained") == true)
    #expect(items.first?.researchTrustSourceConstraintSummary?.contains("restricted") == true)
}

@Test("Owner background activity stays separate from owner decisions")
func ownerBackgroundActivityIsSeparated() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 3,
        pendingApprovalRequestsCount: 2,
        activeDecisionCount: 4,
        newSignalsCount: 1,
        awaitingProposalCount: 2,
        degradedDelegationsCount: 1,
        failedDelegationsCount: 1
    )

    let background = makeOwnerBackgroundActivityPresentations(snapshot: snapshot)
    let recent = makeOwnerRecentChangePresentations(snapshot: snapshot)

    #expect(background.count == 3)
    #expect(background.contains { $0.kind == .pmReviewing })
    #expect(background.contains { $0.kind == .analystActivity })
    #expect(background.contains { $0.kind == .systemExceptions })
    #expect(recent.count == 2)
    #expect(recent.contains { $0.title == "Signals" })
    #expect(recent.contains { $0.title == "Proposals" })
}

@Test("Owner background activity reflects standing run activity and PM review backlog truthfully")
func ownerBackgroundActivityReflectsStandingRunTruth() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 0,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 0,
        activeStandingRunCount: 1,
        pendingStandingReportReviewCount: 2,
        newSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    let background = makeOwnerBackgroundActivityPresentations(snapshot: snapshot)
    let pmReview = background.first { $0.kind == .pmReviewing }
    let analystActivity = background.first { $0.kind == .analystActivity }

    #expect(pmReview?.count == 2)
    #expect(pmReview?.summary.contains("2 items waiting for internal review") == true)
    #expect(pmReview?.detail.contains("standing analyst reports") == true)
    #expect(analystActivity?.count == 1)
    #expect(analystActivity?.summary.contains("1 analyst item is active") == true)
    #expect(analystActivity?.detail.contains("standing analyst report runs") == true)
}

@Test("Owner background count excludes durable PM decision history from active PM work")
func ownerBackgroundCountExcludesHistoricalPMDecisionCount() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 0,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 285,
        activeStandingRunCount: 0,
        pendingStandingReportReviewCount: 0,
        pmReviewQueueCount: 0,
        newSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    #expect(snapshot.activeAnalystBackgroundCount == 0)
    #expect(snapshot.activePMBackgroundCount == 0)

    let readiness = makeCommandCenterDeskReadinessPresentation(
        snapshot: snapshot,
        decisionItems: [],
        runtimeOperability: nil
    )

    #expect(readiness.pmHandlingSummary == "PM and analyst workflow are quiet right now.")
}

@Test("Owner background activity projects standing analyst delivery and PM review completion lifecycle")
func ownerBackgroundActivityProjectsStandingReportLifecycleTruth() {
    let now = Date(timeIntervalSince1970: 1_742_700_196)
    let pending = AnalystStandingReport(
        reportId: "standing-report-pending-1",
        analystId: "bench-sector-technology-analyst",
        charterId: "bench-sector-technology",
        scheduleId: "standing-report-bench-sector-technology",
        memoId: "memo-pending-1",
        title: "Technology Analyst Standing Report",
        summary: "Technology report delivered to PM Inbox.",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly review.",
        portfolioScopeSummary: "Covered current names: NVDA.",
        coveredSymbols: ["NVDA"],
        headlineView: "NVDA concentration needs PM review before the next catalyst window.",
        portfolioRelevanceSummary: "Relevant to current technology exposure.",
        openQuestions: [],
        evidenceReferenceSummary: [],
        sections: [],
        deliveredToPMInboxAt: now.addingTimeInterval(-120),
        createdAt: now.addingTimeInterval(-120),
        updatedAt: now.addingTimeInterval(-120)
    )
    let reviewed = AnalystStandingReport(
        reportId: "standing-report-reviewed-1",
        deliveryStatus: .reviewedByPM,
        analystId: "bench-overlay-macro-international-analyst",
        charterId: "bench-overlay-macro-international",
        scheduleId: "standing-report-bench-overlay-macro-international",
        memoId: "memo-reviewed-1",
        title: "Macro and International Analyst Standing Report",
        summary: "PM completed background review and kept the result monitor-only.",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly review.",
        portfolioScopeSummary: "Covered macro overlays.",
        headlineView: "Dollar and rates backdrop remained monitor-only.",
        portfolioRelevanceSummary: "Relevant to broad portfolio risk.",
        deliveredToPMInboxAt: now.addingTimeInterval(-600),
        createdAt: now.addingTimeInterval(-600),
        updatedAt: now.addingTimeInterval(-60)
    )
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 0,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 0,
        activeStandingRunCount: 1,
        pendingStandingReportReviewCount: 1,
        newSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    let background = makeOwnerBackgroundActivityPresentations(
        snapshot: snapshot,
        standingReports: [reviewed, pending],
        jobs: [
            JobSummary(
                jobId: "job-standing-1",
                type: .standingAnalystReport,
                status: .running,
                createdAt: now.addingTimeInterval(-30),
                updatedAt: now.addingTimeInterval(-5),
                progress: 0.45,
                message: "Preparing standing analyst report",
                proposalId: nil,
                runId: nil
            )
        ]
    )

    #expect(background.count == OwnerSurfaceProjectionBudget.visibleBackgroundWorkflowCards)
    #expect(background.first?.title == "Analyst Run Active")
    #expect(background.contains { $0.title == "Analyst Report Delivered" && $0.summary.contains("Technology Analyst") })
    #expect(background.contains { $0.title == "PM Review Pending" && $0.detail.contains("routine PM workflow") })
    #expect(background.contains { $0.title == "PM Reviewing" && $0.detail.contains("Technology Analyst") })
    #expect(background.contains { $0.title == "PM Review Completed" && $0.summary.contains("Macro and International Analyst") })

    let completedOnly = makeOwnerBackgroundActivityPresentations(
        snapshot: PMCommandCenterSnapshot(
            activeDelegationsCount: 0,
            pendingApprovalRequestsCount: 0,
            activeDecisionCount: 0,
            activeStandingRunCount: 0,
            pendingStandingReportReviewCount: 0,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        ),
        standingReports: [reviewed],
        jobs: []
    )

    #expect(completedOnly.first?.title == "PM Review Completed")
    #expect(completedOnly.first?.count == 1)
    #expect(completedOnly.first?.summary.contains("Macro and International Analyst") == true)
    #expect(completedOnly.contains {
        $0.title == "PM Reviewing"
            && $0.count == 0
            && $0.detail.contains("No PM-internal review queue is active.")
    })

    var historicalReviewedReports: [AnalystStandingReport] = []
    for index in 0..<25 {
        let secondsOffset = TimeInterval(-1_000 - index)
        historicalReviewedReports.append(AnalystStandingReport(
            reportId: "standing-report-reviewed-historical-\(index)",
            deliveryStatus: .reviewedByPM,
            analystId: "bench-sector-consumer-analyst",
            charterId: "bench-sector-consumer",
            scheduleId: "standing-report-bench-sector-consumer",
            memoId: "memo-reviewed-historical-\(index)",
            title: "Consumer Analyst Standing Report",
            summary: "Historical PM-reviewed standing report \(index).",
            cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
            reportingWindowSummary: "Weekly review.",
            portfolioScopeSummary: "Covered consumer names.",
            headlineView: "Historical consumer report.",
            portfolioRelevanceSummary: "Historical context.",
            deliveredToPMInboxAt: now.addingTimeInterval(secondsOffset),
            createdAt: now.addingTimeInterval(secondsOffset),
            updatedAt: now.addingTimeInterval(secondsOffset + 100)
        ))
    }
    let historicalCompleted = makeOwnerBackgroundActivityPresentations(
        snapshot: PMCommandCenterSnapshot(
            activeDelegationsCount: 0,
            pendingApprovalRequestsCount: 0,
            activeDecisionCount: 0,
            activeStandingRunCount: 0,
            pendingStandingReportReviewCount: 0,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        ),
        standingReports: historicalReviewedReports + [reviewed],
        jobs: []
    )

    #expect(historicalCompleted.first?.title == "PM Review Completed")
    #expect(historicalCompleted.first?.count == 1)
    #expect(historicalCompleted.allSatisfy { $0.count != historicalReviewedReports.count + 1 })
}

@Test("Owner PM conversation failure notes stay visible and clear the misleading waiting state")
func ownerPMConversationFailureNotesStayVisible() {
    let now = Date(timeIntervalSince1970: 1_742_700_050)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let ownerMessage = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Please review the strategy brief and reply here.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let systemNote = PMCommunicationMessage(
        messageId: "message-2",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .system,
        body: "Your message was recorded, but the PM reply could not be completed: Telegram delivery failed.",
        sentAt: now.addingTimeInterval(1),
        replyToMessageId: ownerMessage.messageId,
        createdAt: now.addingTimeInterval(1),
        updatedAt: now.addingTimeInterval(1)
    )

    let presentation = makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: [ownerMessage, systemNote],
        approvalRequests: []
    )

    #expect(presentation?.awaitingPMReply == false)
    #expect(presentation?.visibleMessages.last?.speakerLabel == "System")
    #expect(presentation?.visibleMessages.last?.body.contains("could not be completed") == true)
}

@Test("Command Center desk readiness prioritizes pending owner decisions above everything else")
func commandCenterDeskReadinessPrioritizesPendingOwnerDecisions() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 2,
        pendingApprovalRequestsCount: 1,
        activeDecisionCount: 3,
        newSignalsCount: 2,
        awaitingProposalCount: 1,
        degradedDelegationsCount: 1,
        failedDelegationsCount: 0
    )
    let decisionItem = OwnerDecisionDeskItemPresentation(
        approvalRequestId: "approval-1",
        title: "Review PM recommendation",
        requestTypeTitle: "Proposal Review",
        initiativePosture: .ownerDecisionRequired,
        initiativeSummary: "Owner decision: Review the current PM ask now.",
        coherence: makePMEventCoherencePresentation(
            posture: .ownerDecisionRequired,
            initiativeSummary: "Owner decision: Review the current PM ask now."
        ),
        closure: PMRecommendationClosurePresentation(
            status: .awaitingOwner,
            title: "Awaiting Owner",
            ownerSummary: "Still waiting on you.",
            pmInboxSummary: "Owner response pending.",
            ownerPending: true,
            stillCurrent: true
        ),
        ownerAsk: "Approve or decline the bounded next step.",
        whyNow: "A decision is ready.",
        recommendation: "Proceed carefully.",
        strategicAlignment: nil,
        portfolioContextSummary: nil,
        researchTrustLabel: nil,
        researchTrustSummary: nil,
        researchTrustSourceConstraintSummary: nil,
        supportingEvidence: nil,
        uncertaintySummary: nil,
        approvedNextStep: nil,
        declinedNextStep: nil,
        moreWorkNextStep: nil,
        linkedProposalId: nil,
        linkedCommunicationSummary: nil,
        boundaryNote: "Boundary unchanged."
    )
    let runtime = makeRuntimeOperabilityPresentation(
        pmRuntimeSettings: PMRuntimeSettings(
            runtimeIdentifier: "bad runtime!",
            reasoningMode: .standard,
            validationStatus: RuntimeValidationRecord(
                status: .invalid,
                category: .invalidFormat,
                summary: "Runtime identifier can use letters, numbers, hyphen, underscore, period, and colon only.",
                checkedAt: Date(timeIntervalSince1970: 1_743_400_000),
                checkedBy: "human owner"
            ),
            lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
                runtimeIdentifier: "gpt-5-mini",
                reasoningMode: .standard,
                verifiedAt: Date(timeIntervalSince1970: 1_743_400_000),
                summary: "Previously verified."
            ),
            lastFallback: RuntimeFallbackRecord(
                configuredRuntimeIdentifier: "bad runtime!",
                configuredReasoningMode: .standard,
                fallbackRuntimeIdentifier: "gpt-5-mini",
                fallbackReasoningMode: .standard,
                reasonCategory: .invalidFormat,
                reasonSummary: "Runtime identifier can use letters, numbers, hyphen, underscore, period, and colon only.",
                occurredAt: Date(timeIntervalSince1970: 1_743_400_000)
            ),
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_743_400_000),
            updatedAt: Date(timeIntervalSince1970: 1_743_400_000)
        )
    )

    let presentation = makeCommandCenterDeskReadinessPresentation(
        snapshot: snapshot,
        decisionItems: [decisionItem],
        runtimeOperability: runtime
    )

    #expect(presentation.state == CommandCenterDeskReadinessState.needsOwnerAttentionNow)
    #expect(presentation.title == "Owner Attention Needed")
    #expect(presentation.ownerAttentionSummary.contains("Review PM recommendation") == true)
    #expect(presentation.operationalSummary.contains("Runtime health is degraded") == true)
}

@Test("Command Center desk readiness surfaces operational attention when no owner decision is pending")
func commandCenterDeskReadinessSurfacesOperationalAttention() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 1,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 1,
        newSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 1,
        failedDelegationsCount: 1
    )
    let runtime = makeRuntimeOperabilityPresentation(
        pmRuntimeSettings: PMRuntimeSettings(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .standard,
            validationStatus: RuntimeValidationRecord(
                status: .invalid,
                category: .networkFailure,
                summary: "Network request failed before the runtime could be checked.",
                checkedAt: Date(timeIntervalSince1970: 1_743_400_100),
                checkedBy: "runtime health check"
            ),
            updatedBy: "system",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_743_400_100),
            updatedAt: Date(timeIntervalSince1970: 1_743_400_100)
        )
    )

    let presentation = makeCommandCenterDeskReadinessPresentation(
        snapshot: snapshot,
        decisionItems: [],
        runtimeOperability: runtime
    )

    #expect(presentation.state == .operationalAttention)
    #expect(presentation.summary.contains("No owner decision is pending") == true)
    #expect(presentation.operationalSummary.contains("network failure") == true)
}

@Test("Command Center desk readiness can represent PM-handled background work without false urgency")
func commandCenterDeskReadinessRepresentsBackgroundHandling() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 2,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 2,
        pmReviewQueueCount: 2,
        newSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    let presentation = makeCommandCenterDeskReadinessPresentation(
        snapshot: snapshot,
        decisionItems: [],
        runtimeOperability: makeRuntimeOperabilityPresentation(
            pmRuntimeSettings: PMRuntimeSettings(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .standard,
                validationStatus: RuntimeValidationRecord(
                    status: .valid,
                    category: .accepted,
                    summary: "Runtime identifier passed the app's bounded local validation policy.",
                    checkedAt: Date(timeIntervalSince1970: 1_743_400_200),
                    checkedBy: "human owner"
                ),
                updatedBy: "human owner",
                updateSource: .userEdited,
                createdAt: Date(timeIntervalSince1970: 1_743_400_200),
                updatedAt: Date(timeIntervalSince1970: 1_743_400_200)
            )
        )
    )

    #expect(presentation.state == .pmHandlingInBackground)
    #expect(presentation.summary.contains("No owner decision is pending") == true)
    #expect(presentation.pmHandlingSummary.contains("4 PM or analyst items") == true)
    #expect(presentation.operationalSummary.contains("No runtime or system exceptions") == true)
}

@Test("Command Center desk readiness can represent informational-only days")
func commandCenterDeskReadinessRepresentsInformationalOnlyDay() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 0,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 0,
        newSignalsCount: 2,
        awaitingProposalCount: 1,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    let presentation = makeCommandCenterDeskReadinessPresentation(
        snapshot: snapshot,
        decisionItems: [],
        runtimeOperability: nil
    )

    #expect(presentation.state == .informationalOnly)
    #expect(presentation.informationalSummary.contains("3 informational updates") == true)
    #expect(presentation.ownerAttentionSummary == "Nothing is waiting for your decision right now.")
}

@Test("Command Center desk readiness can represent a calm no-action-required desk")
func commandCenterDeskReadinessRepresentsCalmDesk() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 0,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 0,
        newSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    let presentation = makeCommandCenterDeskReadinessPresentation(
        snapshot: snapshot,
        decisionItems: [],
        runtimeOperability: makeRuntimeOperabilityPresentation(
            pmRuntimeSettings: PMRuntimeSettings(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .standard,
                validationStatus: RuntimeValidationRecord(
                    status: .valid,
                    category: .accepted,
                    summary: "Runtime identifier passed the app's bounded local validation policy.",
                    checkedAt: Date(timeIntervalSince1970: 1_743_400_300),
                    checkedBy: "human owner"
                ),
                updatedBy: "human owner",
                updateSource: .userEdited,
                createdAt: Date(timeIntervalSince1970: 1_743_400_300),
                updatedAt: Date(timeIntervalSince1970: 1_743_400_300)
            )
        )
    )

    #expect(presentation.state == .noImmediateActionRequired)
    #expect(presentation.title == "No Immediate Action Required")
    #expect(presentation.summary.contains("desk is calm") == true)
}

@Test("Owner PM conversation presentation ignores exercise sessions and surfaces current ask")
func ownerConversationPresentationPrefersRealInAppSession() {
    let now = Date(timeIntervalSince1970: 1_742_700_100)
    let realSession = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let exerciseSession = PMCommunicationSession(
        sessionId: "pm-user-in-app-pm-operational-exercise",
        channel: .inApp,
        pmId: PMProfile.operationalExercisePMID,
        participantId: "owner",
        participantDisplayName: "Exercise Owner",
        status: .active,
        createdAt: now.addingTimeInterval(10),
        updatedAt: now.addingTimeInterval(10)
    )
    let realPMMessage = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: realSession.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "Please review the current PM recommendation.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let realOwnerMessage = PMCommunicationMessage(
        messageId: "message-2",
        sessionId: realSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Understood. Show me the next step.",
        sentAt: now.addingTimeInterval(20),
        createdAt: now.addingTimeInterval(20),
        updatedAt: now.addingTimeInterval(20)
    )
    let exerciseMessage = PMCommunicationMessage(
        messageId: "exercise-pm-message-1",
        sessionId: exerciseSession.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-operational-exercise",
        body: "Exercise-only PM note.",
        sentAt: now.addingTimeInterval(30),
        createdAt: now.addingTimeInterval(30),
        updatedAt: now.addingTimeInterval(30)
    )
    let pending = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "Owner review is needed.",
        requestedActionSummary: "Approve or decline the bounded next step.",
        requestType: .proposalReview,
        status: .pending,
        createdAt: now,
        updatedAt: now
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [exerciseSession, realSession],
        messages: [exerciseMessage, realPMMessage, realOwnerMessage],
        approvalRequests: [pending]
    )

    #expect(conversation?.sessionId == realSession.sessionId)
    #expect(conversation?.latestPMMessage?.contains("current PM recommendation") == true)
    #expect(conversation?.latestOwnerReply?.contains("Show me the next step") == true)
    #expect(conversation?.visibleMessages.count == 2)
    #expect(conversation?.visibleMessages.last?.speakerLabel == "You")
    #expect(conversation?.awaitingPMReply == true)
    #expect(conversation?.sessionSummary == "2 messages • In App")
    #expect(conversation?.replyRoutingSummary.contains("stay in the app by default") == true)
    #expect(conversation?.currentAskTitle == pending.subject)
    #expect(conversation?.currentAskLifecycleSummary == "This PM ask is still waiting on your decision.")
    #expect(conversation?.ownerComposerTitle == "Reply To PM")
    #expect(conversation?.ownerComposerHint.contains("more direction") == true)
}

@Test("Owner PM conversation presentation merges Telegram and in-app history into one owner-facing continuity view")
func ownerConversationPresentationMergesTelegramAndInAppHistory() {
    let now = Date(timeIntervalSince1970: 1_742_700_125)
    let inAppSession = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now.addingTimeInterval(30),
        updatedAt: now.addingTimeInterval(30)
    )
    let telegramSession = PMCommunicationSession(
        sessionId: "pm-user-telegram-chat-testchatownersenda",
        channel: .telegram,
        externalConversationId: "667788",
        pmId: "pm-1",
        participantId: "8899",
        participantDisplayName: "@owneruser",
        status: .active,
        createdAt: now,
        updatedAt: now.addingTimeInterval(20)
    )
    let telegramOwnerMessage = PMCommunicationMessage(
        messageId: "telegram-owner-1",
        sessionId: telegramSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Here is my current proposed paper portfolio. Long positions: NVDA, TSM, AVGO. Short positions: NYCB, KSS.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let telegramPMReply = PMCommunicationMessage(
        messageId: "telegram-pm-1",
        sessionId: telegramSession.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "Understood. I’m carrying that forward as the current working paper portfolio.",
        sentAt: now.addingTimeInterval(5),
        replyToMessageId: telegramOwnerMessage.messageId,
        createdAt: now.addingTimeInterval(5),
        updatedAt: now.addingTimeInterval(5)
    )
    let inAppOwnerMessage = PMCommunicationMessage(
        messageId: "in-app-owner-1",
        sessionId: inAppSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "What are the analyst conviction levels on the short positions?",
        sentAt: now.addingTimeInterval(30),
        createdAt: now.addingTimeInterval(30),
        updatedAt: now.addingTimeInterval(30)
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [telegramSession, inAppSession],
        messages: [telegramOwnerMessage, telegramPMReply, inAppOwnerMessage],
        approvalRequests: []
    )

    #expect(conversation?.sessionId == inAppSession.sessionId)
    #expect(conversation?.visibleMessages.count == 3)
    #expect(conversation?.visibleMessages.first?.messageId == telegramOwnerMessage.messageId)
    #expect(conversation?.visibleMessages.last?.messageId == inAppOwnerMessage.messageId)
    #expect(conversation?.sessionSummary == "3 messages • In App + Telegram")
    #expect(conversation?.replyRoutingSummary.contains("includes Telegram-carried turns") == true)
    #expect(conversation?.replyRoutingSummary.contains("stay in the app by default") == true)
    #expect(conversation?.awaitingPMReply == true)
}

@Test("Owner PM conversation presentation keeps Telegram continuity despite legacy PM id mismatch")
func ownerConversationPresentationKeepsTelegramContinuityDespiteLegacyPMIDMismatch() {
    let now = Date(timeIntervalSince1970: 1_742_700_128)
    let inAppSession = PMCommunicationSession(
        sessionId: "pm-user-in-app-primary",
        channel: .inApp,
        pmId: "pm-primary",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now.addingTimeInterval(20),
        updatedAt: now.addingTimeInterval(20)
    )
    let telegramSession = PMCommunicationSession(
        sessionId: "pm-user-telegram-chat-testchatownersenda",
        channel: .telegram,
        externalConversationId: "667788",
        pmId: "pm-legacy",
        participantId: "8899",
        participantDisplayName: "@owneruser",
        status: .active,
        createdAt: now,
        updatedAt: now.addingTimeInterval(10)
    )
    let telegramOwnerMessage = PMCommunicationMessage(
        messageId: "telegram-owner-legacy-pm",
        sessionId: telegramSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "8899",
        body: "What was the last Recent News Analyst report you reviewed?",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let telegramPMReply = PMCommunicationMessage(
        messageId: "telegram-pm-legacy-pm",
        sessionId: telegramSession.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-legacy",
        body: "I found the latest reviewed Recent News Analyst report.",
        sentAt: now.addingTimeInterval(5),
        replyToMessageId: telegramOwnerMessage.messageId,
        createdAt: now.addingTimeInterval(5),
        updatedAt: now.addingTimeInterval(5)
    )
    let inAppOwnerMessage = PMCommunicationMessage(
        messageId: "in-app-owner-after-legacy-telegram",
        sessionId: inAppSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Thanks.",
        sentAt: now.addingTimeInterval(20),
        createdAt: now.addingTimeInterval(20),
        updatedAt: now.addingTimeInterval(20)
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [inAppSession, telegramSession],
        messages: [telegramOwnerMessage, telegramPMReply, inAppOwnerMessage],
        approvalRequests: []
    )

    #expect(conversation?.sessionId == inAppSession.sessionId)
    #expect(conversation?.visibleMessages.map(\.messageId) == [
        telegramOwnerMessage.messageId,
        telegramPMReply.messageId,
        inAppOwnerMessage.messageId
    ])
    #expect(conversation?.sessionSummary == "3 messages • In App + Telegram")
    #expect(conversation?.replyRoutingSummary.contains("includes Telegram-carried turns") == true)
}

@Test("Owner PM conversation presentation surfaces Telegram-only owner exchanges")
func ownerConversationPresentationSurfacesTelegramOnlyHistory() {
    let now = Date(timeIntervalSince1970: 1_742_700_130)
    let telegramSession = PMCommunicationSession(
        sessionId: "pm-user-telegram-chat-testchatownersenda",
        channel: .telegram,
        externalConversationId: "667788",
        pmId: "pm-1",
        participantId: "8899",
        participantDisplayName: "@owneruser",
        status: .active,
        createdAt: now,
        updatedAt: now.addingTimeInterval(5)
    )
    let ownerMessage = PMCommunicationMessage(
        messageId: "telegram-owner-2",
        sessionId: telegramSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "8899",
        body: "Can you see this Telegram continuation in Command Center?",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let pmReply = PMCommunicationMessage(
        messageId: "telegram-pm-2",
        sessionId: telegramSession.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "Yes. This is still the app-owned PM conversation, carried over Telegram.",
        sentAt: now.addingTimeInterval(5),
        replyToMessageId: ownerMessage.messageId,
        createdAt: now.addingTimeInterval(5),
        updatedAt: now.addingTimeInterval(5)
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [telegramSession],
        messages: [ownerMessage, pmReply],
        approvalRequests: []
    )

    #expect(conversation?.sessionId == telegramSession.sessionId)
    #expect(conversation?.visibleMessages.map(\.messageId) == [ownerMessage.messageId, pmReply.messageId])
    #expect(conversation?.sessionSummary == "2 messages • Telegram")
    #expect(conversation?.replyRoutingSummary.contains("includes Telegram-carried turns") == true)
    #expect(conversation?.awaitingPMReply == false)
}

@Test("Owner PM conversation presentation supports owner-initiated asks without pending approval")
func ownerConversationPresentationSupportsOwnerInitiatedPath() {
    let now = Date(timeIntervalSince1970: 1_742_700_150)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let pmMessage = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: session.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "I have no pending ask right now, but I am available for a new review.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: [pmMessage],
        approvalRequests: []
    )

    #expect(conversation?.currentAskTitle == nil)
    #expect(conversation?.ownerComposerTitle == "Start A New Ask")
    #expect(conversation?.ownerComposerHint.contains("Ask the PM") == true)
    #expect(conversation?.visibleMessages.count == 1)
    #expect(conversation?.visibleMessages.first?.speakerLabel == "PM")
    #expect(conversation?.awaitingPMReply == false)
}

@Test("Owner PM conversation presentation keeps visible thread entries and shows waiting state for owner-initiated asks")
func ownerConversationPresentationShowsVisibleThreadAndWaitingState() {
    let now = Date(timeIntervalSince1970: 1_742_700_155)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let ownerMessage = PMCommunicationMessage(
        messageId: "message-owner-1",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: """
        Please read the current Portfolio Strategy Brief and send back questions, comments,
        and any revision note you think is worth considering.
        """,
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: [ownerMessage],
        approvalRequests: []
    )

    #expect(conversation?.visibleMessages.count == 1)
    #expect(conversation?.visibleMessages.first?.speakerLabel == "You")
    #expect(conversation?.visibleMessages.first?.body.contains("Portfolio Strategy Brief") == true)
    #expect(conversation?.awaitingPMReply == true)
    #expect(conversation?.latestPMMessage == nil)
}

@Test("Owner PM conversation presentation keeps a materially larger visible scrollback window")
func ownerConversationPresentationKeepsLargerVisibleScrollbackWindow() {
    let now = Date(timeIntervalSince1970: 1_742_700_155)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let messages: [PMCommunicationMessage] = (0..<20).map { index in
        PMCommunicationMessage(
            messageId: "message-\(index)",
            sessionId: session.sessionId,
            direction: index.isMultiple(of: 2) ? .incoming : .outgoing,
            senderRole: index.isMultiple(of: 2) ? .owner : .pm,
            senderId: index.isMultiple(of: 2) ? "owner" : "pm-1",
            body: "Visible scrollback message \(index)",
            sentAt: now.addingTimeInterval(Double(index)),
            createdAt: now.addingTimeInterval(Double(index)),
            updatedAt: now.addingTimeInterval(Double(index))
        )
    }

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: messages,
        approvalRequests: []
    )

    #expect(conversation?.visibleMessages.count == OwnerSurfaceProjectionBudget.visiblePMConversationMessages)
    #expect(conversation?.visibleMessages.first?.messageId == "message-4")
    #expect(conversation?.visibleMessages.last?.messageId == "message-19")
}

@Test("Owner PM conversation presentation stays bounded with large same-owner history")
func ownerConversationPresentationStaysBoundedWithLargeHistory() {
    let now = Date(timeIntervalSince1970: 1_742_700_155)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let largeBody = String(repeating: "large-owner-history-body ", count: 80)
    let messages: [PMCommunicationMessage] = (0..<10_000).map { index in
        let role: PMCommunicationSenderRole = index.isMultiple(of: 2) ? .owner : .pm
        return PMCommunicationMessage(
            messageId: String(format: "message-%05d", index),
            sessionId: session.sessionId,
            direction: role == .owner ? .incoming : .outgoing,
            senderRole: role,
            senderId: role == .owner ? "owner" : "pm-1",
            body: "message \(index) \(largeBody)",
            sentAt: now.addingTimeInterval(Double(index)),
            createdAt: now.addingTimeInterval(Double(index)),
            updatedAt: now.addingTimeInterval(Double(index))
        )
    }

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: messages,
        approvalRequests: []
    )

    #expect(conversation?.sessionSummary == "10000 messages • In App")
    #expect(conversation?.visibleMessages.count == OwnerSurfaceProjectionBudget.visiblePMConversationMessages)
    #expect(conversation?.visibleMessages.first?.messageId == "message-09984")
    #expect(conversation?.visibleMessages.last?.messageId == "message-09999")
    #expect(conversation?.latestPMMessage?.contains("9999") == true)
    #expect(conversation?.latestOwnerReply?.contains("9998") == true)
    #expect(conversation?.visibleMessages.contains(where: { $0.messageId == "message-00000" }) == false)
}

@Test("Owner PM conversation visible message bodies are capped for Command Center layout")
func ownerConversationPresentationCapsVisibleMessageBodiesForCommandCenter() throws {
    let now = Date(timeIntervalSince1970: 1_742_700_155)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let longPMBody = String(repeating: "Long PM message body with report-like detail. ", count: 200)
    let message = PMCommunicationMessage(
        messageId: "message-long-pm",
        sessionId: session.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: longPMBody,
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let conversation = try #require(makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: [message],
        approvalRequests: []
    ))
    let visibleBody = try #require(conversation.visibleMessages.first?.body)

    #expect(visibleBody.count <= OwnerSurfaceProjectionBudget.visiblePMConversationMessageCharacters)
    #expect(visibleBody.contains("Shortened for Command Center"))
    #expect(visibleBody.contains("Full message remains in PM Inbox"))
    #expect(visibleBody.count < longPMBody.count)
}

@Test("Owner PM conversation presentation filters routine standing review lifecycle chatter")
func ownerConversationPresentationFiltersRoutineStandingReviewChatter() {
    let now = Date(timeIntervalSince1970: 1_742_700_156)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let routineWake = PMCommunicationMessage(
        messageId: "message-pm-1",
        sessionId: session.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "I woke on app open and found 3 standing analyst reports already awaiting PM review.\n\nThese remain standing-review artifacts, not proposals, so the next step is PM review or bounded follow-up rather than approval routing.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let ownerMessage = PMCommunicationMessage(
        messageId: "message-owner-1",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Please summarize what changed in the watchlist.",
        sentAt: now.addingTimeInterval(15),
        createdAt: now.addingTimeInterval(15),
        updatedAt: now.addingTimeInterval(15)
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: [routineWake, ownerMessage],
        approvalRequests: []
    )

    #expect(conversation?.visibleMessages.count == 1)
    #expect(conversation?.visibleMessages.first?.speakerLabel == "You")
    #expect(conversation?.visibleMessages.first?.body == ownerMessage.body)
}

@Test("Owner PM conversation routine filter cache avoids rescanning unchanged routine PM messages")
func ownerConversationRoutineFilterCacheAvoidsRescanningUnchangedRoutineMessages() {
    let now = Date(timeIntervalSince1970: 1_742_700_156)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let routineWake = PMCommunicationMessage(
        messageId: "message-pm-routine",
        sessionId: session.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "I woke on app open and found 2 standing analyst reports already awaiting PM review.\n\nThese remain standing-review artifacts, not proposals, so the next step is PM review or bounded follow-up rather than approval routing.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let ownerMessage = PMCommunicationMessage(
        messageId: "message-owner-1",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Please summarize what changed in the watchlist.",
        sentAt: now.addingTimeInterval(15),
        createdAt: now.addingTimeInterval(15),
        updatedAt: now.addingTimeInterval(15)
    )

    var cache = OwnerPMConversationRoutineFilterCache()
    let first = makeOwnerPMConversationPresentationComputation(
        sessions: [session],
        messages: [routineWake, ownerMessage],
        approvalRequests: [],
        routineFilterCache: &cache
    )
    let second = makeOwnerPMConversationPresentationComputation(
        sessions: [session],
        messages: [routineWake, ownerMessage],
        approvalRequests: [],
        routineFilterCache: &cache
    )
    let updatedRoutineWake = PMCommunicationMessage(
        messageId: routineWake.messageId,
        sessionId: routineWake.sessionId,
        direction: routineWake.direction,
        senderRole: routineWake.senderRole,
        senderId: routineWake.senderId,
        body: routineWake.body,
        sentAt: routineWake.sentAt,
        createdAt: routineWake.createdAt,
        updatedAt: now.addingTimeInterval(30)
    )
    let third = makeOwnerPMConversationPresentationComputation(
        sessions: [session],
        messages: [updatedRoutineWake, ownerMessage],
        approvalRequests: [],
        routineFilterCache: &cache
    )

    #expect(first.routineFilterScannedMessageCount == 1)
    #expect(cache.entryCount == 1)
    #expect(cache.entryLimit == 2_048)
    #expect(first.matchingMessageCount == 1)
    #expect(first.presentation?.visibleMessages.count == 1)
    #expect(second.routineFilterScannedMessageCount == 0)
    #expect(cache.entryCount == 1)
    #expect(second.presentation == first.presentation)
    #expect(third.routineFilterScannedMessageCount == 1)
    #expect(cache.entryCount == 1)
    cache.removeAll()
    #expect(cache.entryCount == 0)
    #expect(third.presentation?.visibleMessages.first?.messageId == ownerMessage.messageId)
}

@Test("Owner decision desk suppresses low-signal standing review escalation asks")
func ownerDecisionDeskSuppressesLowSignalStandingReviewEscalations() {
    let now = Date(timeIntervalSince1970: 1_742_700_157)
    let decision = PMDecisionRecord(
        decisionId: "decision-standing-review-1",
        pmId: "pm-1",
        title: "Standing review escalation: Portfolio Risk Analyst",
        summary: "Key issues: No fresh risk-relevant headline displaced current construction. This recommendation came out of quiet PM standing-review work.",
        recommendedAction: "No fresh risk-relevant headline displaced current construction",
        evidenceSummary: "Standing review cycle covered one report from Portfolio Risk Analyst.",
        ownerAsk: "Review this standing-review synthesis and decide whether you want it to remain monitor-only or have me prepare a separate governed next step.",
        approvedNextStepSummary: "If approved, the PM can prepare the next bounded step separately.",
        decisionType: .escalation,
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-standing-review-1",
        pmId: "pm-1",
        subject: "Review standing analyst synthesis: Portfolio Risk Analyst",
        rationale: "Standing analyst review surfaced an owner-relevant issue across 1 reviewed report. Most important: No fresh risk-relevant headline displaced current construction.",
        requestedActionSummary: "Review the PM synthesis from this standing-review cycle and decide whether it should remain background-only or advance into a separate governed next step.",
        approvedNextStepSummary: "If approved, the PM can prepare the next bounded step separately.",
        rejectedNextStepSummary: "If declined, the PM will keep the outcome in background PM work.",
        reviewedNextStepSummary: "If you ask for more work, the PM will keep monitoring the standing bench output.",
        requestType: .other,
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )

    let items = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [decision],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [],
        strategyBrief: nil
    )
    let conversation = makeOwnerPMConversationPresentation(
        sessions: [
            PMCommunicationSession(
                sessionId: "pm-user-in-app-default",
                channel: .inApp,
                pmId: "pm-1",
                participantId: "owner",
                participantDisplayName: "Owner",
                status: .active,
                createdAt: now,
                updatedAt: now
            )
        ],
        messages: [],
        approvalRequests: [request],
        decisions: [decision]
    )

    #expect(items.isEmpty)
    #expect(conversation?.currentAskTitle == nil)
}

@Test("PM initiative policy keeps clarify, bench-first, summary, owner-decision, and quiet postures distinct")
func pmInitiativePolicyClassificationStaysDistinct() {
    let clarify = classifyPMInitiativePosture(
        PMInitiativeContext(
            needsClarification: true,
            reason: "The owner request is still ambiguous."
        )
    )
    let benchFirst = classifyPMInitiativePosture(
        PMInitiativeContext(
            shouldUseAnalystBenchFirst: true,
            reason: "The analyst bench should tighten the downside case first."
        )
    )
    let summary = classifyPMInitiativePosture(
        PMInitiativeContext(
            reason: "The PM can answer directly from current context."
        )
    )
    let ownerDecision = classifyPMInitiativePosture(
        PMInitiativeContext(
            ownerDecisionRequired: true,
            reason: "The next step is decision-ready."
        )
    )
    let quiet = classifyPMInitiativePosture(
        PMInitiativeContext(
            shouldStayQuiet: true,
            reason: "This is still background PM work."
        )
    )

    #expect(clarify.posture == .clarifyFirst)
    #expect(benchFirst.posture == .analystBenchFirst)
    #expect(summary.posture == .summarizeAndInform)
    #expect(ownerDecision.posture == .ownerDecisionRequired)
    #expect(quiet.posture == .stayQuiet)
}

@Test("PM decision initiative uses bench-first and summary-only postures without over-escalating")
func pmDecisionInitiativePrefersBenchFirstAndSummaryOnlyWhenAppropriate() {
    let now = Date(timeIntervalSince1970: 1_742_700_260)
    let activeDelegation = PMDelegationRecord(
        delegationId: "delegation-1",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Downside challenge",
        rationale: "The analyst bench should pressure-test the downside first.",
        status: .issued,
        createdAt: now,
        updatedAt: now
    )
    let benchFirst = classifyPMDecisionInitiative(
        decision: PMDecisionRecord(
            decisionId: "decision-1",
            pmId: "pm-1",
            title: "Still under analyst review",
            summary: "The PM is waiting on a tighter downside read.",
            decisionType: .recommendation,
            status: .active,
            delegationId: activeDelegation.delegationId,
            createdAt: now,
            updatedAt: now
        ),
        linkedDelegation: activeDelegation
    )
    let summaryOnly = classifyPMDecisionInitiative(
        decision: PMDecisionRecord(
            decisionId: "decision-2",
            pmId: "pm-1",
            title: "Background PM summary",
            summary: "Useful background context, but not owner-decision material yet.",
            decisionType: .readinessAssessment,
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )

    #expect(benchFirst.posture == .analystBenchFirst)
    #expect(benchFirst.summary.contains("Bench first:") == true)
    #expect(summaryOnly.posture == .summarizeAndInform)
    #expect(summaryOnly.summary.contains("Summary only:") == true)
}

@Test("Strategy brief revision candidate presentation prefers real owner conversation input")
func strategyBriefRevisionCandidatePresentationUsesPMReplyAndKeepsOwnerAskDistinct() {
    let now = Date(timeIntervalSince1970: 1_742_700_175)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let ownerMessage = PMCommunicationMessage(
        messageId: "message-owner-1",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Tighten the brief around downside review and make earnings risk more explicit.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let pmMessage = PMCommunicationMessage(
        messageId: "message-pm-1",
        sessionId: session.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "I can revise the strategy brief to reflect that change.",
        sentAt: now.addingTimeInterval(10),
        createdAt: now.addingTimeInterval(10),
        updatedAt: now.addingTimeInterval(10)
    )

    let candidate = makeStrategyBriefConversationRevisionCandidatePresentation(
        sessions: [session],
        messages: [pmMessage, ownerMessage]
    )

    #expect(candidate?.messageId == pmMessage.messageId)
    #expect(candidate?.senderLabel == "Optional PM revision note")
    #expect(candidate?.messageSummary.contains("revise the strategy brief") == true)
    #expect(candidate?.revisionSuggestion.contains("Conversation-derived PM revision note") == true)
    #expect(candidate?.messageSummary.contains("earnings risk more explicit") == false)
}

@Test("Strategy brief revision candidate does not treat owner-only asks as a PM revision note")
func strategyBriefRevisionCandidatePresentationRequiresPMReply() {
    let now = Date(timeIntervalSince1970: 1_742_700_180)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let ownerMessage = PMCommunicationMessage(
        messageId: "message-owner-2",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Please question the brief and suggest any updates you think matter.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let candidate = makeStrategyBriefConversationRevisionCandidatePresentation(
        sessions: [session],
        messages: [ownerMessage]
    )

    #expect(candidate == nil)
}

@Test("Strategy brief revision candidate ignores unrelated PM replies")
func strategyBriefRevisionCandidatePresentationRequiresBriefFocusedPMReply() {
    let now = Date(timeIntervalSince1970: 1_742_700_190)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let pmMessage = PMCommunicationMessage(
        messageId: "message-pm-2",
        sessionId: session.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "I agree with the current risk posture and will keep monitoring catalysts.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let candidate = makeStrategyBriefConversationRevisionCandidatePresentation(
        sessions: [session],
        messages: [pmMessage]
    )

    #expect(candidate == nil)
}

@Test("Strategy brief revision candidate scan is bounded to recent messages")
func strategyBriefRevisionCandidateScanIsBoundedToRecentMessages() {
    let now = Date(timeIntervalSince1970: 1_742_700_200)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let oldEligible = PMCommunicationMessage(
        messageId: "message-pm-old",
        sessionId: session.sessionId,
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "I can revise the portfolio strategy brief based on that older observation.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    var recentMessages: [PMCommunicationMessage] = []
    for index in 0..<25 {
        let timestamp = now.addingTimeInterval(Double(index + 1))
        recentMessages.append(PMCommunicationMessage(
            messageId: "message-pm-recent-\(index)",
            sessionId: session.sessionId,
            direction: .outgoing,
            senderRole: .pm,
            senderId: "pm-1",
            body: "I will keep monitoring catalysts \(index).",
            sentAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp
        ))
    }

    let computation = makeStrategyBriefConversationRevisionCandidateComputation(
        sessions: [session],
        messages: [oldEligible] + recentMessages,
        messageScanLimit: 10
    )

    #expect(computation.candidate == nil)
    #expect(computation.scannedMessageCount == 10)
    #expect(computation.consideredMessageCount == 10)
    #expect(computation.messageScanLimit == 10)
}

@Test("Strategy brief revision candidate finds latest eligible PM message inside budget")
func strategyBriefRevisionCandidateFindsLatestEligibleMessageInsideBudget() {
    let now = Date(timeIntervalSince1970: 1_742_700_210)
    let session = PMCommunicationSession(
        sessionId: "pm-user-in-app-default",
        channel: .inApp,
        pmId: "pm-1",
        participantId: "owner",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    var messages: [PMCommunicationMessage] = []
    for index in 0..<8 {
        let timestamp = now.addingTimeInterval(Double(index))
        let body = index == 6
            ? "I would update the strategy brief to add a sharper short-risk review checkpoint."
            : "I will keep monitoring catalysts \(index)."
        messages.append(PMCommunicationMessage(
            messageId: "message-pm-\(index)",
            sessionId: session.sessionId,
            direction: .outgoing,
            senderRole: .pm,
            senderId: "pm-1",
            body: body,
            sentAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp
        ))
    }

    let computation = makeStrategyBriefConversationRevisionCandidateComputation(
        sessions: [session],
        messages: messages,
        messageScanLimit: 10
    )

    #expect(computation.candidate?.messageId == "message-pm-6")
    #expect(computation.scannedMessageCount == 2)
    #expect(computation.consideredMessageCount == 2)
}

@Test("PM Inbox communication presentation stays drill-down only")
func pmInboxCommunicationPresentationDemotesOwnerCompose() {
    let empty = makePMInboxCommunicationReviewPresentation(sessionCount: 0)
    #expect(empty.title == "No Communication Log Yet")
    #expect(empty.primaryActionLabel == "Open Command Center")
    #expect(empty.ownerComposeAllowed == false)
    #expect(empty.summary.contains("Telegram") == true)

    let populated = makePMInboxCommunicationReviewPresentation(sessionCount: 2)
    #expect(populated.title == "Communication Log")
    #expect(populated.summary.contains("Command Center") == true)
    #expect(populated.summary.contains("Telegram") == true)
    #expect(populated.ownerComposeAllowed == false)
}

@Test("PM Inbox approval routing presentation stays read-only and routes owner action back to Command Center")
func pmInboxApprovalRoutingPresentationStaysReadOnly() {
    let now = Date(timeIntervalSince1970: 1_742_700_205)
    let pendingRequest = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "A bounded owner decision is needed now.",
        requestedActionSummary: "Approve or decline the next bounded step.",
        status: .pending,
        createdAt: now,
        updatedAt: now
    )

    let presentation = makePMInboxApprovalRoutingPresentation(
        request: pendingRequest,
        telegramParticipantDisplayName: "Owner Telegram"
    )

    #expect(presentation.ownerActionableInCommandCenter == true)
    #expect(presentation.summary.contains("Command Center > Your Decisions") == true)
    #expect(presentation.transportSummary?.contains("transport only") == true)
    #expect(presentation.ownerActionControlsVisible == false)
    #expect(presentation.telegramSendControlVisible == false)
}

@Test("PM Inbox routing presentation treats low-signal standing-review asks as background PM work")
func pmInboxApprovalRoutingPresentationDemotesBackgroundStandingReview() {
    let now = Date(timeIntervalSince1970: 1_742_700_206)
    let decision = PMDecisionRecord(
        decisionId: "decision-standing-background",
        pmId: "pm-1",
        title: "Standing review escalation: Technology Analyst",
        summary: "No fresh technology headline displaced current construction. This remains background-only.",
        recommendedAction: "Remain monitor-only while the PM tracks it in the background.",
        ownerAsk: "Review this standing-review synthesis and decide whether you want it to remain monitor-only or have me prepare a separate governed next step.",
        decisionType: .escalation,
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-standing-background",
        pmId: "pm-1",
        subject: "Review standing analyst synthesis: Technology Analyst",
        rationale: "The standing review remains background-only and did not displace the current read.",
        requestedActionSummary: "Review the PM synthesis from this standing-review cycle and decide whether it should remain background-only or advance into a separate governed next step.",
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )

    let presentation = makePMInboxApprovalRoutingPresentation(
        request: request,
        linkedDecision: decision,
        telegramParticipantDisplayName: "Owner Telegram"
    )

    #expect(presentation.ownerActionableInCommandCenter == false)
    #expect(presentation.summary.contains("background PM work by default") == true)
    #expect(presentation.ownerActionControlsVisible == false)
    #expect(presentation.telegramSendControlVisible == false)
}

@Test("Owner PM surface coordination keeps Command Center primary and PM Inbox advanced")
func ownerPMSurfaceCoordinationPresentationClarifiesRoles() {
    let presentation = makeOwnerPMSurfaceCoordinationPresentation(
        telegramStatus: TelegramBridgeStatus(
            tokenConfigured: true,
            allowlistedOwnerChatId: "testchatpresentation"
        ),
        runtimeSettings: PMRuntimeSettings(
            runtimeIdentifier: "gpt-owner-next",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_700_200),
            updatedAt: Date(timeIntervalSince1970: 1_742_700_200)
        )
    )

    #expect(presentation.commandCenterSummary.contains("main owner desk") == true)
    #expect(presentation.telegramSummary.contains("owner-only route") == true)
    #expect(presentation.pmInboxSummary.contains("advanced") == true)
    #expect(presentation.runtimeSummary.contains("gpt-owner-next") == true)
    #expect(presentation.runtimeSummary.contains("standard reasoning") == true)
}

@Test("Owner PM surface coordination makes degraded fallback explicit")
func ownerPMSurfaceCoordinationPresentationExplainsDegradedRuntime() {
    let now = Date(timeIntervalSince1970: 1_743_300_300)
    let presentation = makeOwnerPMSurfaceCoordinationPresentation(
        telegramStatus: TelegramBridgeStatus(tokenConfigured: true),
        runtimeSettings: PMRuntimeSettings(
            runtimeIdentifier: "bad runtime!",
            reasoningMode: .deliberate,
            validationStatus: RuntimeValidationRecord(
                status: .invalid,
                category: .invalidFormat,
                summary: "Runtime identifier can use letters, numbers, hyphen, underscore, period, and colon only.",
                checkedAt: now,
                checkedBy: "human owner"
            ),
            lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
                runtimeIdentifier: "gpt-5-mini",
                reasoningMode: .standard,
                verifiedAt: now,
                summary: "Previously resolved successfully."
            ),
            lastFallback: RuntimeFallbackRecord(
                configuredRuntimeIdentifier: "bad runtime!",
                configuredReasoningMode: .deliberate,
                fallbackRuntimeIdentifier: "gpt-5-mini",
                fallbackReasoningMode: .standard,
                reasonCategory: .invalidFormat,
                reasonSummary: "Runtime identifier can use letters, numbers, hyphen, underscore, period, and colon only.",
                occurredAt: now
            ),
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    #expect(presentation.runtimeSummary.contains("Degraded mode active") == true)
    #expect(presentation.runtimeSummary.contains("gpt-5-mini") == true)
}

@Test("Temporary advanced navigation opens only the requested drill-down surface")
func temporaryAdvancedNavigationOpensOnlyRequestedSurface() {
    #expect(
        makeVisibleOwnerAdvancedSurfaces(
            persistentPreferenceEnabled: false,
            temporarilyOpenedSurface: .pmInbox
        ) == [.pmInbox]
    )
    #expect(
        makeVisibleOwnerAdvancedSurfaces(
            persistentPreferenceEnabled: false,
            temporarilyOpenedSurface: .jobs
        ) == [.jobs]
    )
    #expect(
        makeVisibleOwnerAdvancedSurfaces(
            persistentPreferenceEnabled: false,
            temporarilyOpenedSurface: nil
        ).isEmpty
    )
}

@Test("Persistent advanced-tab preference keeps the full advanced surface set visible")
func persistentAdvancedPreferenceShowsFullAdvancedSurfaceSet() {
    #expect(
        makeVisibleOwnerAdvancedSurfaces(
            persistentPreferenceEnabled: true,
            temporarilyOpenedSurface: .logsAudit
        ) == OwnerAdvancedSurface.allCases
    )
}

@Test("Active exercise artifact counting ignores already archived exercise records")
func activeExerciseArtifactCountingIgnoresArchivedState() {
    let now = Date(timeIntervalSince1970: 1_742_700_175)
    let count = countActivePMExerciseArtifacts(
        approvalRequests: [
            PMApprovalRequest(
                approvalRequestId: "exercise-approval-1",
                pmId: "pm-operational-exercise",
                subject: "Pending exercise ask",
                rationale: "Exercise",
                status: .pending,
                createdAt: now,
                updatedAt: now
            ),
            PMApprovalRequest(
                approvalRequestId: "exercise-approval-2",
                pmId: "pm-operational-exercise",
                subject: "Archived exercise ask",
                rationale: "Exercise",
                status: .stale,
                createdAt: now,
                updatedAt: now
            )
        ],
        decisions: [
            PMDecisionRecord(
                decisionId: "exercise-decision-1",
                pmId: "pm-operational-exercise",
                title: "Active exercise decision",
                summary: "Exercise",
                status: .active,
                createdAt: now,
                updatedAt: now
            ),
            PMDecisionRecord(
                decisionId: "exercise-decision-2",
                pmId: "pm-operational-exercise",
                title: "Withdrawn exercise decision",
                summary: "Exercise",
                status: .withdrawn,
                createdAt: now,
                updatedAt: now
            )
        ],
        delegations: [
            PMDelegationRecord(
                delegationId: "exercise-delegation-1",
                pmId: "pm-operational-exercise",
                analystId: "analyst-1",
                charterId: "charter-1",
                title: "Issued exercise delegation",
                rationale: "Exercise",
                status: .issued,
                createdAt: now,
                updatedAt: now
            ),
            PMDelegationRecord(
                delegationId: "exercise-delegation-2",
                pmId: "pm-operational-exercise",
                analystId: "analyst-1",
                charterId: "charter-1",
                title: "Canceled exercise delegation",
                rationale: "Exercise",
                status: .canceled,
                createdAt: now,
                updatedAt: now
            )
        ],
        communicationSessions: [
            PMCommunicationSession(
                sessionId: "exercise-session-1",
                channel: .inApp,
                pmId: "pm-operational-exercise",
                participantId: "owner-exercise",
                participantDisplayName: "Exercise Owner",
                status: .active,
                createdAt: now,
                updatedAt: now
            ),
            PMCommunicationSession(
                sessionId: "exercise-session-2",
                channel: .inApp,
                pmId: "pm-operational-exercise",
                participantId: "owner-exercise",
                participantDisplayName: "Exercise Owner",
                status: .closed,
                createdAt: now,
                updatedAt: now
            )
        ]
    )

    #expect(count == 4)
}

@Test("PM command center snapshot excludes exercise artifact counts")
func pmCommandCenterSnapshotExcludesExerciseArtifacts() {
    let now = Date(timeIntervalSince1970: 1_742_700_190)
    let snapshot = makePMCommandCenterSnapshot(
        delegations: [
            PMDelegationRecord(
                delegationId: "delegation-1",
                pmId: "pm-1",
                analystId: "analyst-1",
                charterId: "charter-1",
                title: "Real delegation",
                rationale: "Real work",
                status: .issued,
                createdAt: now,
                updatedAt: now
            ),
            PMDelegationRecord(
                delegationId: "exercise-delegation-1",
                pmId: "pm-operational-exercise",
                analystId: "analyst-1",
                charterId: "charter-1",
                title: "Exercise delegation",
                rationale: "Exercise work",
                status: .issued,
                createdAt: now,
                updatedAt: now
            )
        ],
        charters: [],
        tasks: [],
        approvalRequests: [
            PMApprovalRequest(
                approvalRequestId: "approval-1",
                pmId: "pm-1",
                subject: "Real request",
                rationale: "Real work",
                status: .pending,
                createdAt: now,
                updatedAt: now
            ),
            PMApprovalRequest(
                approvalRequestId: "exercise-approval-1",
                pmId: "pm-operational-exercise",
                subject: "Exercise request",
                rationale: "Exercise work",
                status: .pending,
                createdAt: now,
                updatedAt: now
            )
        ],
        decisions: [
            PMDecisionRecord(
                decisionId: "decision-1",
                pmId: "pm-1",
                title: "Real decision",
                summary: "Real work",
                status: .active,
                createdAt: now,
                updatedAt: now
            ),
            PMDecisionRecord(
                decisionId: "exercise-decision-1",
                pmId: "pm-operational-exercise",
                title: "Exercise decision",
                summary: "Exercise work",
                status: .active,
                createdAt: now,
                updatedAt: now
            )
        ],
        signals: [],
        proposals: []
    )

    #expect(snapshot.activeDelegationsCount == 1)
    #expect(snapshot.pendingApprovalRequestsCount == 1)
    #expect(snapshot.ownerActionableApprovalCount == 1)
    #expect(snapshot.activeDecisionCount == 1)
    #expect(snapshot.pmReviewQueueCount == 0)
}

@Test("PM command center snapshot separates owner-visible decisions from raw pending approval records")
func pmCommandCenterSnapshotSeparatesOwnerVisibleDecisionTruth() {
    let now = Date(timeIntervalSince1970: 1_742_700_191)
    let standingDecision = PMDecisionRecord(
        decisionId: "decision-standing-1",
        pmId: "pm-1",
        title: "Standing review escalation: Portfolio Risk Analyst",
        summary: "This is worth monitoring but no governed next step is justified.",
        recommendedAction: "Remain monitor-only while the PM tracks it in the background.",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let standingRequest = PMApprovalRequest(
        approvalRequestId: "approval-standing-1",
        pmId: "pm-1",
        subject: "Review standing analyst synthesis: Portfolio Risk Analyst",
        rationale: "The standing review remains background-only and did not displace the current read.",
        status: .pending,
        decisionId: standingDecision.decisionId,
        createdAt: now,
        updatedAt: now
    )
    let realOwnerRequest = PMApprovalRequest(
        approvalRequestId: "approval-real-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "A bounded owner decision is needed now.",
        status: .pending,
        createdAt: now.addingTimeInterval(1),
        updatedAt: now.addingTimeInterval(1)
    )

    let snapshot = makePMCommandCenterSnapshot(
        delegations: [],
        charters: [],
        tasks: [],
        approvalRequests: [standingRequest, realOwnerRequest],
        decisions: [standingDecision],
        signals: [],
        proposals: []
    )

    #expect(snapshot.pendingApprovalRequestsCount == 2)
    #expect(snapshot.ownerActionableApprovalCount == 1)
    #expect(snapshot.activeDecisionCount == 1)
    #expect(snapshot.pmReviewQueueCount == 0)
}

@Test("PM command center snapshot includes standing report review backlog and active standing runs")
func pmCommandCenterSnapshotIncludesStandingReportTruth() {
    let now = Date(timeIntervalSince1970: 1_742_700_195)
    let snapshot = makePMCommandCenterSnapshot(
        delegations: [],
        charters: [],
        tasks: [],
        approvalRequests: [],
        decisions: [],
        standingReports: [
            AnalystStandingReport(
                reportId: "standing-report-1",
                analystId: "bench-sector-technology-analyst",
                charterId: "bench-sector-technology",
                scheduleId: "standing-report-bench-sector-technology",
                memoId: "memo-1",
                title: "Technology Analyst Standing Report",
                summary: "Delivered to PM Inbox.",
                cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
                reportingWindowSummary: "Weekly review.",
                portfolioScopeSummary: "Covered current names: NVDA.",
                coveredSymbols: ["NVDA"],
                headlineView: "Technology update.",
                portfolioRelevanceSummary: "Relevant to current technology exposure.",
                openQuestions: [],
                evidenceReferenceSummary: [],
                sections: [],
                deliveredToPMInboxAt: now,
                createdAt: now,
                updatedAt: now
            )
        ],
        jobs: [
            JobSummary(
                jobId: "job-1",
                type: .standingAnalystReport,
                status: .running,
                createdAt: now,
                updatedAt: now,
                progress: 0.5,
                message: "Running standing analyst report",
                proposalId: nil,
                runId: nil
            )
        ],
        signals: [],
        proposals: []
    )

    #expect(snapshot.pendingStandingReportReviewCount == 1)
    #expect(snapshot.pmReviewQueueCount == 1)
    #expect(snapshot.activeStandingRunCount == 1)
}

@Test("Owner-surface job projections stay bounded with large completed job history")
func ownerSurfaceJobProjectionsStayBoundedWithLargeCompletedHistory() {
    let now = Date(timeIntervalSince1970: 1_742_700_196)
    let completedJobs: [JobSummary] = (0..<12_000).map { index in
        JobSummary(
            jobId: String(format: "completed-%05d", index),
            type: .standingAnalystReport,
            status: .succeeded,
            createdAt: now.addingTimeInterval(Double(-20_000 - index)),
            updatedAt: now.addingTimeInterval(Double(-20_000 - index)),
            progress: 1.0,
            message: "Historical completed job \(index)",
            proposalId: nil,
            runId: nil
        )
    }
    let runningJobs = [
        JobSummary(
            jobId: "running-standing",
            type: .standingAnalystReport,
            status: .running,
            createdAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-10),
            progress: 0.5,
            message: "Current standing analyst report",
            proposalId: nil,
            runId: nil
        ),
        JobSummary(
            jobId: "queued-maintenance",
            type: .maintenanceRetention,
            status: .queued,
            createdAt: now.addingTimeInterval(-30),
            updatedAt: now.addingTimeInterval(-5),
            progress: nil,
            message: "Queued maintenance",
            proposalId: nil,
            runId: nil
        )
    ]
    let jobs = completedJobs + runningJobs

    let runningSnapshots = makeRunningJobSnapshots(jobs: jobs)
    let commandSnapshot = makePMCommandCenterSnapshot(
        delegations: [],
        charters: [],
        tasks: [],
        approvalRequests: [],
        decisions: [],
        standingReports: [],
        jobs: jobs,
        signals: [],
        proposals: []
    )

    #expect(runningSnapshots.map(\.jobId) == ["queued-maintenance", "running-standing"])
    #expect(runningSnapshots.allSatisfy { $0.status == .queued || $0.status == .running })
    #expect(commandSnapshot.activeStandingRunCount == 1)
}

@Test("Engine archives only exercise PM artifacts")
func engineArchivesOnlyExerciseArtifacts() async throws {
    let root = makeOwnerDecisionDeskTempDirectory(name: "pm-exercise-cleanup")
    let decisionStore = PMDecisionStore(decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let delegationStore = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let sessionStore = PMCommunicationSessionStore(sessionsDirectory: root.appendingPathComponent("sessions", isDirectory: true))
    let charterStore = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let engine = Engine(
        pmDecisionStore: decisionStore,
        pmApprovalRequestStore: approvalStore,
        pmCommunicationSessionStore: sessionStore,
        pmDelegationStore: delegationStore,
        analystCharterStore: charterStore
    )
    let now = Date(timeIntervalSince1970: 1_742_700_200)

    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "charter-1",
            analystId: "analyst-1",
            title: "Test Analyst",
            coverageScope: "Test coverage",
            strategyFamily: "general",
            summary: "Test charter",
            createdAt: now,
            updatedAt: now
        )
    )

    _ = try await engine.upsertPMDecision(
        PMDecisionRecord(
            decisionId: "exercise-decision-1",
            pmId: "pm-operational-exercise",
            title: "Exercise decision",
            summary: "Exercise only.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMDecision(
        PMDecisionRecord(
            decisionId: "decision-1",
            pmId: "pm-1",
            title: "Real decision",
            summary: "Keep this.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "exercise-approval-request-1",
            pmId: "pm-operational-exercise",
            subject: "Exercise request",
            rationale: "Exercise only.",
            status: .pending,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-1",
            pmId: "pm-1",
            subject: "Real request",
            rationale: "Keep this.",
            status: .pending,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMDelegation(
        PMDelegationRecord(
            delegationId: "exercise-delegation-1",
            pmId: "pm-operational-exercise",
            analystId: "analyst-1",
            charterId: "charter-1",
            title: "Exercise delegation",
            rationale: "Exercise only.",
            requestedOutputs: [.finding],
            status: .issued,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMDelegation(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            title: "Real delegation",
            rationale: "Keep this.",
            requestedOutputs: [.finding],
            status: .issued,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMCommunicationSession(
        PMCommunicationSession(
            sessionId: "exercise-session-1",
            channel: .inApp,
            pmId: "pm-operational-exercise",
            participantId: "owner-exercise",
            participantDisplayName: "Exercise Owner",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMCommunicationSession(
        PMCommunicationSession(
            sessionId: "pm-user-in-app-default",
            channel: .inApp,
            pmId: "pm-1",
            participantId: "owner",
            participantDisplayName: "Owner",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )

    let summary = try await engine.archivePMExerciseArtifacts()
    let decisions = try await engine.listPMDecisions()
    let requests = try await engine.listPMApprovalRequests()
    let delegations = try await engine.listPMDelegations()
    let sessions = try await engine.listPMCommunicationSessions()

    #expect(summary.totalAffected == 4)
    #expect(decisions.first(where: { $0.decisionId == "exercise-decision-1" })?.status == .withdrawn)
    #expect(decisions.first(where: { $0.decisionId == "decision-1" })?.status == .active)
    #expect(requests.first(where: { $0.approvalRequestId == "exercise-approval-request-1" })?.status == .stale)
    #expect(requests.first(where: { $0.approvalRequestId == "approval-1" })?.status == .pending)
    #expect(delegations.first(where: { $0.delegationId == "exercise-delegation-1" })?.status == .canceled)
    #expect(delegations.first(where: { $0.delegationId == "delegation-1" })?.status == .issued)
    #expect(sessions.first(where: { $0.sessionId == "exercise-session-1" })?.status == .closed)
    #expect(sessions.first(where: { $0.sessionId == "pm-user-in-app-default" })?.status == .active)
}

@Test("Approved Live order review with blocked route remains visible with route status")
func approvedLiveOrderReviewWithBlockedRouteRemainsVisibleWithRouteStatus() throws {
    let now = Date(timeIntervalSince1970: 1_742_600_000)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-live-route-blocked",
        pmId: "pm-1",
        subject: "Approve Live META buy review",
        rationale: "Owner asked to review a Live META order.",
        requestedActionSummary: "Review a Live META market order.",
        requestType: .liveOrderReview,
        status: .resolved,
        liveOrderReview: PMLiveOrderReviewPayload(
            symbol: "META",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            notionalAmount: Decimal(10_000),
            instructionSummary: "Buy roughly ten thousand dollars of META to the nearest share."
        ),
        ownerResponse: .approved,
        ownerRespondedAt: now,
        lastExecutionRoutingAssessment: PMExecutionRoutingAssessment(
            approvalRequestId: "approval-live-route-blocked",
            decisionId: nil,
            proposalId: nil,
            proposalTitle: nil,
            proposalStatus: nil,
            environment: .live,
            isLiveArmed: true,
            killSwitchEnabled: false,
            status: .blockedExecutionPrerequisites,
            action: .submitLiveOrderReview,
            summary: "The approved Live order review is waiting for a usable META price before it can size whole shares.",
            detail: "No order has been sent.",
            blockedReasons: [.marketPriceUnavailable]
        ),
        createdAt: now,
        updatedAt: now
    )

    let presentations = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [],
        strategyBrief: nil
    )

    let item = try #require(presentations.first)
    #expect(item.approvalRequestId == "approval-live-route-blocked")
    #expect(item.closure.status == PMRecommendationClosureStatus.blockedOrFailed)
    #expect(item.closure.ownerPending == false)
    #expect(item.routingStatusSummary?.contains("waiting for a usable META price") == true)
    #expect(item.routingStatusSummary?.contains("No order has been sent") == true)
    #expect(isPMApprovalRequestClearableFromActiveDecisions(request))
    #expect(makeOwnerActionableApprovalRequests(approvalRequests: [request], decisions: []).count == 1)
}

@Test("Pending Live order review remains approve or decline only")
func pendingLiveOrderReviewRemainsApproveOrDeclineOnly() throws {
    let now = Date(timeIntervalSince1970: 1_742_600_050)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-live-pending",
        pmId: "pm-1",
        subject: "Approve Live GOOG buy review",
        rationale: "Owner asked to review a Live GOOG order.",
        requestedActionSummary: "Review a Live GOOG market order.",
        requestType: .liveOrderReview,
        status: .pending,
        liveOrderReview: PMLiveOrderReviewPayload(
            symbol: "GOOG",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            notionalAmount: Decimal(5_000),
            instructionSummary: "Buy roughly five thousand dollars of GOOG to the nearest share."
        ),
        createdAt: now,
        updatedAt: now
    )

    let presentations = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [],
        strategyBrief: nil
    )

    let item = try #require(presentations.first)
    #expect(item.approvalRequestId == "approval-live-pending")
    #expect(item.closure.ownerPending)
    #expect(isPMApprovalRequestClearableFromActiveDecisions(request) == false)
    #expect(makeOwnerActionableApprovalRequests(approvalRequests: [request], decisions: []).count == 1)
}

@Test("Approved Live order review with no route result does not remain an active owner decision")
func approvedLiveOrderReviewWithNoRouteResultDoesNotRemainActiveOwnerDecision() throws {
    let now = Date(timeIntervalSince1970: 1_742_600_100)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-live-route-missing",
        pmId: "pm-1",
        subject: "Approve Live META buy review",
        rationale: "Owner asked to review a Live META order.",
        requestedActionSummary: "Review a Live META market order.",
        requestType: .liveOrderReview,
        status: .resolved,
        liveOrderReview: PMLiveOrderReviewPayload(
            symbol: "META",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            notionalAmount: Decimal(10_000),
            instructionSummary: "Buy roughly ten thousand dollars of META to the nearest share."
        ),
        ownerResponse: .approved,
        ownerRespondedAt: now,
        createdAt: now,
        updatedAt: now
    )

    let presentations = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [],
        strategyBrief: nil
    )

    #expect(presentations.isEmpty)
}

@Test("Filled Live order review exits active Your Decisions while retaining lifecycle trace")
func filledLiveOrderReviewLeavesActiveYourDecisionsWhileRetainingLifecycleTrace() throws {
    let now = Date(timeIntervalSince1970: 1_742_600_200)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-live-filled",
        pmId: "pm-1",
        subject: "Approve Live META buy review",
        rationale: "Owner asked to review a Live META order.",
        requestedActionSummary: "Review a Live META market order.",
        requestType: .liveOrderReview,
        status: .resolved,
        liveOrderReview: PMLiveOrderReviewPayload(
            symbol: "META",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            quantity: 17
        ),
        ownerResponse: .approved,
        ownerRespondedAt: now,
        lastExecutionRoutingAssessment: PMExecutionRoutingAssessment(
            approvalRequestId: "approval-live-filled",
            decisionId: nil,
            proposalId: nil,
            proposalTitle: nil,
            proposalStatus: nil,
            environment: .live,
            isLiveArmed: true,
            killSwitchEnabled: false,
            status: .routedSuccessfully,
            action: .submitLiveOrderReview,
            summary: "The approved Live order review was routed through the Engine order path.",
            detail: "Engine accepted the Live order submission attempt.",
            blockedReasons: []
        ),
        liveOrderExecutionLifecycleState: PMLiveOrderReviewExecutionLifecycleState(
            status: .filled,
            summary: "The Live META buy completed.",
            detail: "Filled quantity: 17. Current recorded META position quantity: 17.",
            orderId: "ord-redacted",
            symbol: "META",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            quantity: 17,
            filledQuantity: "17",
            averageFillPrice: "598.86",
            positionQuantity: "17",
            openOrderStatus: "filled",
            completionFollowThroughMessageId: "pm-message-completion",
            completionFollowThroughDeliveredAt: now,
            updatedAt: now
        ),
        createdAt: now,
        updatedAt: now
    )

    let presentations = makeOwnerDecisionDeskPresentations(
        approvalRequests: [request],
        decisions: [],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [],
        strategyBrief: nil
    )

    #expect(presentations.isEmpty)
    #expect(makeOwnerActionableApprovalRequests(approvalRequests: [request], decisions: []).isEmpty)

    let memo = makePMApprovalRequestMemoPresentation(
        request: request,
        linkedDecision: nil,
        executionAssessment: request.lastExecutionRoutingAssessment,
        linkedTask: nil,
        linkedCommunicationMessage: nil,
        linkedMemo: nil,
        strategyBrief: nil
    )
    #expect(memo.closure.status == .completed)
    #expect(memo.supportingSections.contains { $0.title == "Live Order Lifecycle" && $0.body.contains("Status filled") })
    #expect(memo.supportingSections.contains { $0.title == "Live Order Lifecycle" && $0.body.contains("PM completion follow-through delivered") })
}

@Test("Acknowledged blocked Live order review exits active Your Decisions but preserves request")
func acknowledgedBlockedLiveOrderReviewLeavesActiveYourDecisionsButPreservesRequest() throws {
    let now = Date(timeIntervalSince1970: 1_742_600_250)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-live-blocked-acknowledged",
        pmId: "pm-1",
        subject: "Approve Live META buy review",
        rationale: "Owner asked to review a Live META order.",
        requestType: .liveOrderReview,
        status: .resolved,
        liveOrderReview: PMLiveOrderReviewPayload(
            symbol: "META",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            notionalAmount: Decimal(10_000)
        ),
        ownerResponse: .approved,
        ownerRespondedAt: now,
        lastExecutionRoutingAssessment: PMExecutionRoutingAssessment(
            approvalRequestId: "approval-live-blocked-acknowledged",
            decisionId: nil,
            proposalId: nil,
            proposalTitle: nil,
            proposalStatus: nil,
            environment: .live,
            isLiveArmed: true,
            killSwitchEnabled: false,
            status: .blockedExecutionPrerequisites,
            action: .submitLiveOrderReview,
            summary: "The approved Live order review is waiting for a usable META price before it can size whole shares.",
            detail: "No order has been sent.",
            blockedReasons: [.marketPriceUnavailable]
        ),
        ownerAcknowledgedAt: now.addingTimeInterval(60),
        ownerAcknowledgedBy: "owner",
        createdAt: now,
        updatedAt: now
    )

    #expect(makeOwnerActionableApprovalRequests(approvalRequests: [request], decisions: []).isEmpty)
    #expect(request.ownerAcknowledgedAt != nil)

    let snapshot = makePMCommandCenterSnapshot(
        delegations: [],
        charters: [],
        tasks: [],
        approvalRequests: [request],
        decisions: [],
        signals: [],
        proposals: []
    )
    #expect(snapshot.ownerActionableApprovalCount == 0)
    #expect(snapshot.pendingApprovalRequestsCount == 0)
}

private func makeOwnerDecisionDeskTempDirectory(name: String) -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests", isDirectory: true)
        .appendingPathComponent(name + "-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
