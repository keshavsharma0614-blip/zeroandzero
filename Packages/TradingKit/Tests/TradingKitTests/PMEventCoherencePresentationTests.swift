import Foundation
import Testing
@testable import TradingKit

@Test("The same decision-required PM event keeps one actionability meaning across owner desk, Telegram, and PM Inbox")
func pmEventKeepsOneDecisionRequiredMeaningAcrossSurfaces() {
    let now = Date(timeIntervalSince1970: 1_742_800_000)
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Owner review needed",
        summary: "The PM is ready for an owner decision.",
        recommendedAction: "Advance the bounded next step.",
        ownerAsk: "Tell me whether to advance the bounded next step now.",
        decisionType: .recommendation,
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "The PM has a bounded next step ready.",
        requestedActionSummary: "Tell me whether to advance the bounded next step now.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )

    let memo = makePMApprovalRequestMemoPresentation(
        request: request,
        linkedDecision: decision
    )
    let deskItems = makeOwnerDecisionDeskPresentations(
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
    let telegramPrompt = makeTelegramApprovalRequestPrompt(request: request, memo: memo)

    #expect(memo.coherence.actionabilityCategory == .ownerDecisionRequired)
    #expect(memo.coherence.ownerSummary.contains("Decision required.") == true)
    #expect(deskItems.first?.coherence.actionabilityCategory == .ownerDecisionRequired)
    #expect(deskItems.first?.coherence.ownerTitle == "Decision Required")
    #expect(memo.coherence.pmInboxSummary.contains("Decision-required PM event.") == true)
    #expect(telegramPrompt.contains("Decision required:") == true)
}

@Test("Bench-first and stay-quiet events remain traceability-only and do not become Telegram wake-ups")
func pmEventBenchFirstAndQuietStayTraceabilityOnlyAcrossSurfaces() {
    let benchMemo = PMDecisionMemoPresentation(
        initiativePosture: .analystBenchFirst,
        initiativeSummary: "Bench first: The bench should sharpen this before I interrupt the owner.",
        coherence: makePMEventCoherencePresentation(
            posture: .analystBenchFirst,
            initiativeSummary: "Bench first: The bench should sharpen this before I interrupt the owner."
        ),
        closure: makePMRecommendationClosurePresentation(status: .routedOrInProgress),
        recommendation: "Send this through the bench first.",
        whyNow: "Specialist work would materially sharpen the answer.",
        strategicAlignment: nil,
        recommendedAction: nil,
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: nil,
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )
    let quietMemo = PMDecisionMemoPresentation(
        initiativePosture: .stayQuiet,
        initiativeSummary: "Stay quiet: No stronger owner-facing step is justified.",
        coherence: makePMEventCoherencePresentation(
            posture: .stayQuiet,
            initiativeSummary: "Stay quiet: No stronger owner-facing step is justified."
        ),
        closure: makePMRecommendationClosurePresentation(status: .closedNoFurtherAction),
        recommendation: "Keep this monitor-only.",
        whyNow: "No stronger action is justified.",
        strategicAlignment: nil,
        recommendedAction: nil,
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: nil,
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Internal PM handling",
        summary: "Keep this inside PM workflow for now.",
        decisionType: .recommendation,
        status: .active,
        createdAt: .distantPast,
        updatedAt: .distantPast
    )

    #expect(benchMemo.coherence.traceabilityOnly == true)
    #expect(quietMemo.coherence.traceabilityOnly == true)
    #expect(classifyTelegramDecisionWakeUpClass(decision: decision, memo: benchMemo, recentNewsWakeUp: nil, portfolioRiskWakeUp: nil) == .doNotSendProactively)
    #expect(classifyTelegramDecisionWakeUpClass(decision: decision, memo: quietMemo, recentNewsWakeUp: nil, portfolioRiskWakeUp: nil) == .doNotSendProactively)
    #expect(makeTelegramDecisionPrompt(decision: decision, memo: benchMemo).contains("stays passive in Telegram by default") == true)
    #expect(makeTelegramDecisionPrompt(decision: decision, memo: quietMemo).contains("stays passive in Telegram by default") == true)
}
