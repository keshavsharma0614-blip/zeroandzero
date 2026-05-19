import Foundation
import Testing
@testable import TradingKit

@Test("Engine creates approval-ready PM ask from decision without bypassing proposal linkage")
func engineCreatesApprovalReadyAskFromDecision() async throws {
    let root = makePMApprovalActionTempDirectory(name: "pm-approval-action-loop")
    let decisionStore = PMDecisionStore(decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(
        pmDecisionStore: decisionStore,
        pmApprovalRequestStore: approvalStore
    )
    let now = Date(timeIntervalSince1970: 1_742_500_000)

    let storedDecision = try await engine.upsertPMDecision(
        PMDecisionRecord(
            decisionId: "decision-1",
            pmId: "pm-1",
            title: "Trim oversized paper exposure",
            summary: "The PM recommends a bounded paper-only de-risking step after owner review.",
            recommendedAction: "Reduce the oversized paper position through the existing proposal workflow.",
            evidenceSummary: "The recommendation is supported by the latest analyst memo plus current concentration state.",
            ownerAsk: "Approve the PM preparing the next paper-safe proposal review step.",
            approvedNextStepSummary: "If approved, the PM can open the linked paper proposal review path for proposal-1. This still does not approve the proposal or authorize trading.",
            sourceCommunicationMessageId: "message-1",
            decisionType: .recommendation,
            status: .active,
            delegationId: "delegation-1",
            findingId: "finding-1",
            proposalId: "proposal-1",
            createdAt: now,
            updatedAt: now
        )
    )

    let request = try await engine.createPMApprovalRequestFromDecision(decisionId: storedDecision.decisionId)
    let duplicate = try await engine.createPMApprovalRequestFromDecision(decisionId: storedDecision.decisionId)

    #expect(request.approvalRequestId == duplicate.approvalRequestId)
    #expect(request.pmId == storedDecision.pmId)
    #expect(request.decisionId == storedDecision.decisionId)
    #expect(request.delegationId == storedDecision.delegationId)
    #expect(request.findingId == storedDecision.findingId)
    #expect(request.proposalId == storedDecision.proposalId)
    #expect(request.requestType == .proposalReview)
    #expect(request.requestedActionSummary == storedDecision.ownerAsk)
    #expect(request.approvedNextStepSummary == storedDecision.approvedNextStepSummary)
    #expect(request.sourceCommunicationMessageId == storedDecision.sourceCommunicationMessageId)
    #expect(request.status == .pending)
    #expect(request.rejectedNextStepSummary?.contains("more analysis") == true)
    #expect(request.reviewedNextStepSummary?.contains("existing separate approval workflow") == true)
}

@Test("Live order review approval records route blocker when payload is missing")
func liveOrderReviewApprovalRecordsRouteBlockerWhenPayloadIsMissing() async throws {
    let root = makePMApprovalActionTempDirectory(name: "pm-approval-live-order-review-only")
    let decisionStore = PMDecisionStore(decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmDecisionStore: decisionStore,
        pmApprovalRequestStore: approvalStore
    )
    _ = await engine.armLiveTrading()
    let now = Date(timeIntervalSince1970: 1_742_500_050)

    let storedDecision = try await engine.upsertPMDecision(
        PMDecisionRecord(
            decisionId: "decision-live-order-review-only",
            pmId: "pm-1",
            title: "Review Live order instruction",
            summary: "The PM captured a Live order instruction for app review.",
            recommendedAction: "Review the instruction before any governed in-app order path is attempted.",
            ownerAsk: "Approve whether this instruction should advance to the governed in-app order path.",
            sourceCommunicationMessageId: "message-live-order-review-only",
            decisionType: .recommendation,
            status: .active,
            proposalId: "proposal-linked-but-not-routed",
            createdAt: now,
            updatedAt: now
        )
    )
    let request = try await engine.createPMApprovalRequestFromDecision(
        decisionId: storedDecision.decisionId,
        requestType: .liveOrderReview
    )

    let approved = try await engine.respondToPMApprovalRequest(
        requestId: request.approvalRequestId,
        response: .approved,
        source: .ui
    )

    #expect(approved.status == .resolved)
    #expect(approved.ownerResponse == .approved)
    #expect(approved.proposalId == "proposal-linked-but-not-routed")
    #expect(approved.lastExecutionRoutingAssessment?.status == .blockedExecutionPrerequisites)
    #expect(approved.lastExecutionRoutingAssessment?.action == PMExecutionRoutingAction.none)
    #expect(approved.lastExecutionRoutingAssessment?.blockedReasons.contains(.liveOrderReviewPayloadMissing) == true)
}

@Test("Acknowledging completed PM approval request preserves durable history")
func acknowledgingCompletedPMApprovalRequestPreservesDurableHistory() async throws {
    let root = makePMApprovalActionTempDirectory(name: "pm-approval-acknowledge")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(pmApprovalRequestStore: approvalStore)
    let now = Date(timeIntervalSince1970: 1_742_500_075)

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-ack",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner approved and the order reached a terminal lifecycle state.",
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
            liveOrderExecutionLifecycleState: PMLiveOrderReviewExecutionLifecycleState(
                status: .filled,
                summary: "The Live META buy completed.",
                detail: "Filled quantity: 17. Current recorded META position quantity: 17.",
                orderId: "ord-test",
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                quantity: 17,
                filledQuantity: "17",
                positionQuantity: "17",
                openOrderStatus: "filled",
                updatedAt: now
            ),
            createdAt: now,
            updatedAt: now
        )
    )

    let acknowledged = try await engine.acknowledgePMApprovalRequest(
        requestId: "approval-ack",
        acknowledgedBy: "owner",
        source: .ui
    )

    #expect(acknowledged.ownerAcknowledgedAt != nil)
    #expect(acknowledged.ownerAcknowledgedBy == "owner")
    #expect(acknowledged.liveOrderReview?.symbol == "META")
    #expect(acknowledged.liveOrderExecutionLifecycleState?.status == .filled)
    #expect(acknowledged.liveOrderExecutionLifecycleState?.filledQuantity == "17")
}

@Test("Acknowledging blocked Live order review preserves route history")
func acknowledgingBlockedLiveOrderReviewPreservesRouteHistory() async throws {
    let root = makePMApprovalActionTempDirectory(name: "pm-approval-blocked-acknowledge")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(pmApprovalRequestStore: approvalStore)
    let now = Date(timeIntervalSince1970: 1_742_500_090)

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-blocked-ack",
            pmId: "pm-1",
            subject: "Approve Live GOOG buy review",
            rationale: "Owner approved a review that later blocked before any order was sent.",
            requestType: .liveOrderReview,
            status: .resolved,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "GOOG",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                notionalAmount: Decimal(5_000),
                environment: .live,
                instructionSummary: "Buy roughly five thousand dollars of GOOG to the nearest share."
            ),
            ownerResponse: .approved,
            ownerRespondedAt: now,
            lastExecutionRoutingAssessment: PMExecutionRoutingAssessment(
                approvalRequestId: "approval-blocked-ack",
                decisionId: nil,
                proposalId: nil,
                proposalTitle: nil,
                proposalStatus: nil,
                environment: .live,
                isLiveArmed: true,
                killSwitchEnabled: false,
                status: .blockedExecutionPrerequisites,
                action: .submitLiveOrderReview,
                summary: "The approved Live order review is blocked because no usable GOOG price is available.",
                detail: "No order has been sent.",
                blockedReasons: [.marketPriceUnavailable]
            ),
            createdAt: now,
            updatedAt: now
        )
    )

    let acknowledged = try await engine.acknowledgePMApprovalRequest(
        requestId: "approval-blocked-ack",
        acknowledgedBy: "owner",
        source: .ui
    )

    #expect(acknowledged.ownerAcknowledgedAt != nil)
    #expect(acknowledged.ownerAcknowledgedBy == "owner")
    #expect(acknowledged.liveOrderReview?.symbol == "GOOG")
    #expect(acknowledged.liveOrderReview?.notionalAmount == Decimal(5_000))
    #expect(acknowledged.lastExecutionRoutingAssessment?.status == .blockedExecutionPrerequisites)
    #expect(acknowledged.lastExecutionRoutingAssessment?.blockedReasons.contains(.marketPriceUnavailable) == true)

    let persisted = try await engine.getPMApprovalRequest(id: "approval-blocked-ack")
    #expect(persisted.approvalRequestId == "approval-blocked-ack")
    #expect(persisted.ownerAcknowledgedAt != nil)
    #expect(persisted.lastExecutionRoutingAssessment?.detail == "No order has been sent.")
}

@Test("PM approval-request memo presentation surfaces action semantics and linked communication")
func pmApprovalRequestMemoPresentationSurfacesActionSemantics() {
    let now = Date(timeIntervalSince1970: 1_742_500_100)
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Protect core technology exposure while keeping incremental risk tightly controlled.",
        keyThemes: ["technology platform leadership", "earnings sensitivity"],
        currentRiskPosture: "Hold core winners, but tighten review around earnings and concentration changes.",
        reviewEscalationPosture: "Escalate strategy-relevant changes to the owner promptly.",
        updatedBy: "pm-1",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Recommendation to prepare a paper proposal review",
        summary: "The PM recommends preparing a separate paper proposal review step.",
        recommendedAction: "Prepare a bounded paper proposal review, not an execution approval.",
        evidenceSummary: "Linked analyst evidence and current portfolio context support the recommendation.",
        ownerAsk: "Approve the PM moving this into the paper proposal review path.",
        approvedNextStepSummary: "If approved, the PM can move the linked proposal into the next separate paper-safe review step.",
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "The PM wants a bounded owner decision before moving to the separate paper proposal workflow.",
        requestedActionSummary: "Decide whether the PM should move the linked recommendation into the next paper-safe proposal review step.",
        approvedNextStepSummary: "If approved, the PM can move the linked proposal into the next separate paper-safe review step.",
        rejectedNextStepSummary: "If rejected, the PM should leave the recommendation unapproved and either request more analysis or keep the current stance.",
        reviewedNextStepSummary: "If marked reviewed, the PM records acknowledgment while the proposal remains behind its separate approval path.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: decision.decisionId,
        proposalId: "proposal-1",
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Review sizing and catalyst risk",
        description: "Review the current recommendation. Portfolio strategy brief objective: Protect core technology exposure while keeping incremental risk tightly controlled. Strategy themes: technology platform leadership; earnings sensitivity. Current risk posture: Hold core winners, but tighten review around earnings and concentration changes. Review posture: Escalate strategy-relevant changes to the owner promptly.",
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let memoRecord = AnalystMemo(
        memoId: "memo-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: task.taskId,
        delegationId: "delegation-1",
        pmId: "pm-1",
        findingId: nil,
        title: "Sizing review",
        executiveSummary: "The current setup justifies a bounded next step rather than immediate escalation.",
        currentView: "A small paper-safe review step is warranted now, but only after owner review.",
        evidenceSummary: "Position concentration and near-term catalyst risk are the main support for taking a bounded next step.",
        uncertaintySummary: "The thesis is directionally solid, but the upcoming catalyst window could still change the timing and size of the best response.",
        recommendedNextStep: "Open a bounded paper proposal review if the owner agrees.",
        confidence: 0.69,
        runtimeProvenance: nil,
        createdAt: now,
        updatedAt: now
    )
    let message = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: "session-1",
        direction: .outgoing,
        senderRole: .pm,
        senderId: "pm-1",
        body: "I recommend a paper-only next step. Please review before anything moves forward.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let memo = makePMApprovalRequestMemoPresentation(
        request: request,
        linkedDecision: decision,
        linkedTask: task,
        linkedCommunicationMessage: message,
        linkedMemo: memoRecord,
        strategyBrief: strategyBrief
    )

    #expect(memo.requestedAction == request.requestedActionSummary)
    #expect(memo.initiativePosture == .ownerDecisionRequired)
    #expect(memo.initiativeSummary.contains("Owner decision:") == true)
    #expect(memo.coherence.actionabilityCategory == .ownerDecisionRequired)
    #expect(memo.coherence.ownerSummary.contains("Decision required.") == true)
    #expect(memo.closure.status == .awaitingOwner)
    #expect(memo.recommendation == decision.recommendedAction)
    #expect(memo.strategicAlignment?.contains("Current strategy objective") == true)
    #expect(memo.evidenceSummary == decision.evidenceSummary)
    #expect(memo.uncertaintySummary == memoRecord.uncertaintySummary)
    #expect(memo.approvedNextStep == request.approvedNextStepSummary)
    #expect(memo.rejectedNextStep == request.rejectedNextStepSummary)
    #expect(memo.reviewedNextStep == request.reviewedNextStepSummary)
    #expect(memo.ownerActionMeaning.contains("Your response tells the PM") == true)
    #expect(memo.supportingSections.contains { $0.title == "Related PM/User Communication" && $0.body.contains("paper-only next step") })
    #expect(memo.boundaryNote.contains("does not approve proposals"))
}

@Test("Live order review memo presentation surfaces payload and route status")
func liveOrderReviewMemoPresentationSurfacesPayloadAndRouteStatus() {
    let now = Date(timeIntervalSince1970: 1_742_500_150)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-live-order-route-status",
        pmId: "pm-1",
        subject: "Approve Live review",
        rationale: "Review-only Live order instruction.",
        requestedActionSummary: "Approve or reject the Live order review.",
        requestType: .liveOrderReview,
        status: .resolved,
        liveOrderReview: PMLiveOrderReviewPayload(
            symbol: "META",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            quantity: 1,
            environment: .live,
            instructionSummary: "Owner reviewed the direct Live order instruction."
        ),
        ownerResponse: .approved,
        ownerRespondedAt: now.addingTimeInterval(30),
        lastExecutionRoutingAssessment: PMExecutionRoutingAssessment(
            approvalRequestId: "approval-live-order-route-status",
            decisionId: nil,
            proposalId: nil,
            proposalTitle: nil,
            proposalStatus: nil,
            environment: .live,
            isLiveArmed: true,
            killSwitchEnabled: false,
            status: .blockedExecutionPrerequisites,
            action: .submitLiveOrderReview,
            summary: "The approved Live order review was blocked because local authentication was canceled.",
            detail: "No order was sent.",
            blockedReasons: [.localAuthenticationBlocked]
        ),
        createdAt: now,
        updatedAt: now.addingTimeInterval(30)
    )

    let memo = makePMApprovalRequestMemoPresentation(
        request: request,
        linkedDecision: nil,
        executionAssessment: request.lastExecutionRoutingAssessment,
        linkedTask: nil,
        linkedCommunicationMessage: nil,
        linkedMemo: nil,
        strategyBrief: nil
    )

    #expect(memo.supportingSections.contains { $0.title == "Live Order Review Payload" && $0.body.contains("Symbol META") })
    #expect(memo.supportingSections.contains { $0.title == "Governed Route Status" && $0.body.contains("local authentication was canceled") })
    #expect(memo.supportingSections.contains { $0.title == "Governed Route Status" && $0.body.contains("Local macOS authentication") })
}

@Test("PM decision memo presentation keeps owner ask and next paper-safe step explicit")
func pmDecisionMemoPresentationSurfacesActionLoopFields() {
    let now = Date(timeIntervalSince1970: 1_742_500_200)
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Protect core holdings while only escalating when the risk/reward has moved enough to matter.",
        keyThemes: ["concentration discipline"],
        currentRiskPosture: "Tighten review when concentration and catalysts line up.",
        reviewEscalationPosture: "Escalate material changes quickly, otherwise stay patient.",
        updatedBy: "pm-1",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Recommendation to route into paper proposal review",
        summary: "The PM recommends a bounded paper-safe next step.",
        recommendedAction: "Move to the next separate paper proposal review step if the owner agrees.",
        evidenceSummary: "The recommendation is supported by recent analyst findings and PM communication.",
        ownerAsk: "Approve the PM opening the next paper-safe proposal review step.",
        approvedNextStepSummary: "If approved, the PM can proceed to the linked proposal review path without approving execution.",
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review paper-safe next step",
        rationale: "The PM is asking for a bounded owner decision before proceeding.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Paper-safe next step review",
        description: "Review the bounded next step. Portfolio strategy brief objective: Protect core holdings while only escalating when the risk/reward has moved enough to matter. Strategy themes: concentration discipline. Current risk posture: Tighten review when concentration and catalysts line up. Review posture: Escalate material changes quickly, otherwise stay patient.",
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    let memoRecord = AnalystMemo(
        memoId: "memo-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: task.taskId,
        delegationId: "delegation-1",
        pmId: "pm-1",
        findingId: nil,
        title: "Paper-safe review",
        executiveSummary: "The setup supports a bounded next step now, but it is still worth keeping the owner directly in the loop.",
        currentView: "Advance to the next paper-safe review step only if the owner agrees.",
        evidenceSummary: "Recent analyst work and current portfolio posture both support a measured next step.",
        uncertaintySummary: "The recommendation is actionable now, but more analysis could still improve sizing confidence.",
        recommendedNextStep: "Prepare the next paper-safe review if the owner approves.",
        confidence: 0.72,
        runtimeProvenance: nil,
        createdAt: now,
        updatedAt: now
    )
    let message = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: "session-1",
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner",
        body: "Show me the exact next paper-safe step before moving forward.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let memo = makePMDecisionMemoPresentation(
        decision: decision,
        linkedApprovalRequest: request,
        linkedTask: task,
        linkedCommunicationMessage: message,
        linkedMemo: memoRecord,
        strategyBrief: strategyBrief
    )

    #expect(memo.recommendation == decision.recommendedAction)
    #expect(memo.initiativePosture == .ownerDecisionRequired)
    #expect(memo.initiativeSummary.contains("Owner decision:") == true)
    #expect(memo.coherence.actionabilityCategory == .ownerDecisionRequired)
    #expect(memo.coherence.pmInboxSummary.contains("Decision-required PM event.") == true)
    #expect(memo.closure.status == .awaitingOwner)
    #expect(memo.whyNow == request.rationale)
    #expect(memo.strategicAlignment?.contains("Current risk posture") == true)
    #expect(memo.recommendedAction == decision.recommendedAction)
    #expect(memo.evidenceSummary == decision.evidenceSummary)
    #expect(memo.uncertaintySummary == memoRecord.uncertaintySummary)
    #expect(memo.ownerAsk == decision.ownerAsk)
    #expect(memo.approvedNextStep == decision.approvedNextStepSummary)
    #expect(memo.relationshipNote == "Linked PM approval request: Owner decision is still pending. Keep this as the active ask until the owner responds or the PM replaces it.")
    #expect(memo.supportingSections.contains { $0.title == "Related PM/User Communication" && $0.body.contains("exact next paper-safe step") })
    #expect(memo.boundaryNote.contains("separate review and safety gates"))
}

private func makePMApprovalActionTempDirectory(name: String) -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests", isDirectory: true)
        .appendingPathComponent(name + "-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
