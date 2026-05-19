import Foundation
import Testing
@testable import TradingKit

@Test("Recommendation closure mapping distinguishes pending, more-work, declined, routed, and blocked states")
func recommendationClosureMappingDistinguishesLifecycleStates() {
    let now = Date(timeIntervalSince1970: 1_743_000_000)
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Bounded next step",
        summary: "The PM recommends a bounded next step.",
        ownerAsk: "Tell me whether to advance the bounded next step.",
        decisionType: .recommendation,
        status: .active,
        proposalId: "proposal-1",
        createdAt: now,
        updatedAt: now
    )

    let pending = PMApprovalRequest(
        approvalRequestId: "approval-pending",
        pmId: "pm-1",
        subject: "Pending ask",
        rationale: "Owner direction is still needed.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )
    let moreWork = PMApprovalRequest(
        approvalRequestId: "approval-reviewed",
        pmId: "pm-1",
        subject: "More work",
        rationale: "Owner asked for another pass.",
        requestType: .proposalReview,
        status: .resolved,
        decisionId: decision.decisionId,
        ownerResponse: .reviewed,
        ownerRespondedAt: now,
        createdAt: now,
        updatedAt: now
    )
    let declined = PMApprovalRequest(
        approvalRequestId: "approval-declined",
        pmId: "pm-1",
        subject: "Declined ask",
        rationale: "Owner declined.",
        requestType: .proposalReview,
        status: .resolved,
        decisionId: decision.decisionId,
        ownerResponse: .rejected,
        ownerRespondedAt: now,
        createdAt: now,
        updatedAt: now
    )
    let approved = PMApprovalRequest(
        approvalRequestId: "approval-approved",
        pmId: "pm-1",
        subject: "Approved ask",
        rationale: "Owner approved.",
        requestType: .proposalReview,
        status: .resolved,
        decisionId: decision.decisionId,
        proposalId: "proposal-1",
        ownerResponse: .approved,
        ownerRespondedAt: now,
        createdAt: now,
        updatedAt: now
    )

    let routedAssessment = PMExecutionRoutingAssessment(
        approvalRequestId: approved.approvalRequestId,
        decisionId: decision.decisionId,
        proposalId: "proposal-1",
        proposalTitle: "Bounded paper step",
        proposalStatus: .approvedPaper,
        environment: .paper,
        isLiveArmed: false,
        killSwitchEnabled: false,
        status: .routedSuccessfully,
        action: .startProposalExecution,
        summary: "Routed successfully.",
        detail: "Routed through the governed path.",
        blockedReasons: []
    )
    let blockedAssessment = PMExecutionRoutingAssessment(
        approvalRequestId: approved.approvalRequestId,
        decisionId: decision.decisionId,
        proposalId: "proposal-1",
        proposalTitle: "Bounded paper step",
        proposalStatus: .draft,
        environment: .paper,
        isLiveArmed: false,
        killSwitchEnabled: false,
        status: .blockedMissingProposalApproval,
        action: .submitProposalForReview,
        summary: "Proposal review still required.",
        detail: "Waiting on proposal approval.",
        blockedReasons: [.proposalApprovalRequired]
    )

    #expect(makePMRecommendationClosurePresentation(request: pending, linkedDecision: decision).status == .awaitingOwner)
    #expect(makePMRecommendationClosurePresentation(request: moreWork, linkedDecision: decision).status == .moreWorkRequested)
    #expect(makePMRecommendationClosurePresentation(request: declined, linkedDecision: decision).status == .declined)
    #expect(makePMRecommendationClosurePresentation(request: approved, linkedDecision: decision, executionAssessment: routedAssessment).status == .routedOrInProgress)
    #expect(makePMRecommendationClosurePresentation(request: approved, linkedDecision: decision, executionAssessment: blockedAssessment).status == .blockedOrFailed)
}

@Test("Low-signal standing-review requests resolve to background PM review instead of owner-pending")
func lowSignalStandingReviewRequestsResolveToBackgroundPMReview() {
    let now = Date(timeIntervalSince1970: 1_743_000_050)
    let decision = PMDecisionRecord(
        decisionId: "decision-standing-low-signal",
        pmId: "pm-1",
        title: "Standing review escalation: Technology Analyst",
        summary: "No fresh technology headline displaced current construction. This remains monitor-only background PM work.",
        recommendedAction: "Remain monitor-only while the PM tracks technology exposure in the background.",
        ownerAsk: "Review this standing-review synthesis and decide whether you want it to remain monitor-only or have me prepare a separate governed next step.",
        decisionType: .escalation,
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-standing-low-signal",
        pmId: "pm-1",
        subject: "Review standing analyst synthesis: Technology Analyst",
        rationale: "The standing review remains background-only and did not displace the current read.",
        requestedActionSummary: "Review the PM synthesis from this standing-review cycle and decide whether it should remain background-only or advance into a separate governed next step.",
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )

    let requestClosure = makePMRecommendationClosurePresentation(
        request: request,
        linkedDecision: decision
    )
    let decisionClosure = makePMRecommendationClosurePresentation(
        decision: decision,
        linkedApprovalRequest: request
    )
    let requestMemo = makePMApprovalRequestMemoPresentation(
        request: request,
        linkedDecision: decision
    )
    let decisionMemo = makePMDecisionMemoPresentation(
        decision: decision,
        linkedApprovalRequest: request
    )

    #expect(requestClosure.status == .backgroundPMReview)
    #expect(requestClosure.ownerPending == false)
    #expect(requestClosure.pmInboxSummary.contains("background PM work") == true)
    #expect(decisionClosure.status == .backgroundPMReview)
    #expect(requestMemo.requestedAction.contains("background PM review by default") == true)
    #expect(requestMemo.ownerActionMeaning.contains("not currently waiting on the owner") == true)
    #expect(requestMemo.approvedNextStep == nil)
    #expect(decisionMemo.ownerAsk?.contains("background PM review by default") == true)
    #expect(decisionMemo.approvedNextStep == nil)
}

@Test("Concrete standing-review escalation stays owner-routed when the recommendation is genuinely action-worthy")
func concreteStandingReviewEscalationStaysOwnerRouted() {
    let now = Date(timeIntervalSince1970: 1_743_000_060)
    let decision = PMDecisionRecord(
        decisionId: "decision-standing-actionable",
        pmId: "pm-1",
        title: "Standing review escalation: Portfolio Risk Analyst",
        summary: "Reduce NVDA concentration before the next catalyst window. The current posture warrants an explicit owner decision.",
        recommendedAction: "Reduce NVDA concentration before the next catalyst window.",
        ownerAsk: "Review this standing-review synthesis and decide whether you want it to remain monitor-only or have me prepare a separate governed next step.",
        decisionType: .escalation,
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-standing-actionable",
        pmId: "pm-1",
        subject: "Review standing analyst synthesis: Portfolio Risk Analyst",
        rationale: "Standing analyst review surfaced an owner-relevant issue. Most important: Reduce NVDA concentration before the next catalyst window.",
        requestedActionSummary: "Review the PM synthesis from this standing-review cycle and decide whether it should remain background-only or advance into a separate governed next step.",
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )

    let requestClosure = makePMRecommendationClosurePresentation(
        request: request,
        linkedDecision: decision
    )
    let routingPresentation = makePMInboxApprovalRoutingPresentation(
        request: request,
        linkedDecision: decision
    )

    #expect(requestClosure.status == .awaitingOwner)
    #expect(requestClosure.ownerPending == true)
    #expect(routingPresentation.ownerActionableInCommandCenter == true)
}

@Test("Superseded requests stay traceable but do not remain owner-pending")
func supersededRequestsDoNotRemainOwnerPending() {
    let now = Date(timeIntervalSince1970: 1_743_000_100)
    let supersededDecision = PMDecisionRecord(
        decisionId: "decision-superseded",
        pmId: "pm-1",
        title: "Old recommendation",
        summary: "This recommendation was replaced.",
        ownerAsk: "Approve the old step.",
        decisionType: .recommendation,
        status: .superseded,
        createdAt: now,
        updatedAt: now
    )
    let stalePendingRequest = PMApprovalRequest(
        approvalRequestId: "approval-old",
        pmId: "pm-1",
        subject: "Old ask",
        rationale: "This was overtaken by a newer recommendation.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: supersededDecision.decisionId,
        createdAt: now,
        updatedAt: now
    )

    let closure = makePMRecommendationClosurePresentation(
        request: stalePendingRequest,
        linkedDecision: supersededDecision
    )
    let ownerDeskItems = makeOwnerDecisionDeskPresentations(
        approvalRequests: [stalePendingRequest],
        decisions: [supersededDecision],
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: [],
        charters: [],
        memos: [],
        strategyBrief: nil
    )

    #expect(closure.status == .superseded)
    #expect(closure.ownerPending == false)
    #expect(closure.stillCurrent == false)
    #expect(ownerDeskItems.isEmpty)
}

@Test("Owner conversation only surfaces genuinely pending asks")
func ownerConversationOnlySurfacesGenuinelyPendingAsk() {
    let now = Date(timeIntervalSince1970: 1_743_000_200)
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
        body: "I replaced the old recommendation and will return with a better-scoped ask.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )
    let supersededDecision = PMDecisionRecord(
        decisionId: "decision-old",
        pmId: "pm-1",
        title: "Old recommendation",
        summary: "Old recommendation.",
        ownerAsk: "Approve the old path.",
        decisionType: .recommendation,
        status: .superseded,
        createdAt: now,
        updatedAt: now
    )
    let oldPendingRequest = PMApprovalRequest(
        approvalRequestId: "approval-old",
        pmId: "pm-1",
        subject: "Old pending ask",
        rationale: "This should no longer look active.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: supersededDecision.decisionId,
        createdAt: now,
        updatedAt: now
    )

    let conversation = makeOwnerPMConversationPresentation(
        sessions: [session],
        messages: [pmMessage],
        approvalRequests: [oldPendingRequest],
        decisions: [supersededDecision]
    )

    #expect(conversation?.currentAskTitle == nil)
    #expect(conversation?.currentAskLifecycleSummary == nil)
    #expect(conversation?.ownerComposerTitle == "Start A New Ask")
}

@Test("Decision memo keeps more-work closures traceable without implying the ask is still pending")
func decisionMemoShowsMoreWorkClosureWithoutPendingMeaning() {
    let now = Date(timeIntervalSince1970: 1_743_000_300)
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Recommendation after first pass",
        summary: "The PM recommends a bounded next step.",
        ownerAsk: "Tell me whether to advance the bounded next step.",
        decisionType: .recommendation,
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review bounded next step",
        rationale: "The first recommendation was directionally useful but needed more work.",
        requestType: .proposalReview,
        status: .resolved,
        decisionId: decision.decisionId,
        ownerResponse: .reviewed,
        ownerRespondedAt: now,
        createdAt: now,
        updatedAt: now
    )

    let memo = makePMDecisionMemoPresentation(
        decision: decision,
        linkedApprovalRequest: request
    )

    #expect(memo.closure.status == .moreWorkRequested)
    #expect(memo.relationshipNote == "Linked PM approval request: Owner requested more work. Keep the original ask for traceability, but do not present it as still pending approval.")
}
