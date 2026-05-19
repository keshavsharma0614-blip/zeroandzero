import Foundation

public enum PMInitiativePosture: String, Codable, Sendable, Equatable, CaseIterable {
    case clarifyFirst = "clarify_first"
    case analystBenchFirst = "analyst_bench_first"
    case summarizeAndInform = "summarize_and_inform"
    case ownerDecisionRequired = "owner_decision_required"
    case stayQuiet = "stay_quiet"
}

public struct PMInitiativeAssessment: Sendable, Equatable {
    public let posture: PMInitiativePosture
    public let summary: String

    public init(posture: PMInitiativePosture, summary: String) {
        self.posture = posture
        self.summary = summary
    }
}

public struct PMInitiativeContext: Sendable, Equatable {
    public let needsClarification: Bool
    public let shouldUseAnalystBenchFirst: Bool
    public let ownerDecisionRequired: Bool
    public let shouldStayQuiet: Bool
    public let reason: String?

    public init(
        needsClarification: Bool = false,
        shouldUseAnalystBenchFirst: Bool = false,
        ownerDecisionRequired: Bool = false,
        shouldStayQuiet: Bool = false,
        reason: String? = nil
    ) {
        self.needsClarification = needsClarification
        self.shouldUseAnalystBenchFirst = shouldUseAnalystBenchFirst
        self.ownerDecisionRequired = ownerDecisionRequired
        self.shouldStayQuiet = shouldStayQuiet
        self.reason = reason
    }
}

public func classifyPMInitiativePosture(_ context: PMInitiativeContext) -> PMInitiativeAssessment {
    if context.shouldStayQuiet {
        return PMInitiativeAssessment(
            posture: .stayQuiet,
            summary: initiativeSummary(
                posture: .stayQuiet,
                reason: context.reason,
                fallback: "This stays in background PM work until something materially changes."
            )
        )
    }

    if context.needsClarification {
        return PMInitiativeAssessment(
            posture: .clarifyFirst,
            summary: initiativeSummary(
                posture: .clarifyFirst,
                reason: context.reason,
                fallback: "I need one clearer instruction before I either send this to the bench or bring back a recommendation."
            )
        )
    }

    if context.ownerDecisionRequired {
        return PMInitiativeAssessment(
            posture: .ownerDecisionRequired,
            summary: initiativeSummary(
                posture: .ownerDecisionRequired,
                reason: context.reason,
                fallback: "This is decision-ready and now needs your direction."
            )
        )
    }

    if context.shouldUseAnalystBenchFirst {
        return PMInitiativeAssessment(
            posture: .analystBenchFirst,
            summary: initiativeSummary(
                posture: .analystBenchFirst,
                reason: context.reason,
                fallback: "The analyst bench should sharpen this first so I do not interrupt you with a half-formed read."
            )
        )
    }

    return PMInitiativeAssessment(
        posture: .summarizeAndInform,
        summary: initiativeSummary(
            posture: .summarizeAndInform,
            reason: context.reason,
            fallback: "This is useful context to keep you current, but it does not justify an owner decision yet."
        )
    )
}

public func classifyPMApprovalInitiative(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord? = nil
) -> PMInitiativeAssessment {
    classifyPMInitiativePosture(
        PMInitiativeContext(
            ownerDecisionRequired: request.status == .pending,
            shouldStayQuiet: request.status != .pending,
            reason: nonEmptyPMInitiativeText(request.requestedActionSummary)
                ?? nonEmptyPMInitiativeText(linkedDecision?.ownerAsk)
                ?? nonEmptyPMInitiativeText(request.rationale)
        )
    )
}

public func classifyPMDecisionInitiative(
    decision: PMDecisionRecord,
    linkedApprovalRequest: PMApprovalRequest? = nil,
    linkedDelegation: PMDelegationRecord? = nil,
    linkedMemo: AnalystMemo? = nil,
    linkedCommunicationMessage: PMCommunicationMessage? = nil
) -> PMInitiativeAssessment {
    let ownerDecisionRequired = nonEmptyPMInitiativeText(decision.ownerAsk) != nil
        || linkedApprovalRequest?.status == .pending
    let needsClarification = ownerDecisionRequired == false
        && linkedDelegation == nil
        && linkedMemo == nil
        && decision.decisionType == .other
        && linkedCommunicationMessage?.senderRole == .owner
        && linkedCommunicationMessage?.body.contains("?") == true
    let shouldUseAnalystBenchFirst = ownerDecisionRequired == false
        && needsClarification == false
        && linkedDelegation?.status == .issued

    let reason: String?
    if ownerDecisionRequired {
        reason = nonEmptyPMInitiativeText(decision.ownerAsk)
            ?? nonEmptyPMInitiativeText(linkedApprovalRequest?.requestedActionSummary)
            ?? nonEmptyPMInitiativeText(decision.summary)
    } else if needsClarification {
        reason = nonEmptyPMInitiativeText(linkedCommunicationMessage?.body)
            ?? nonEmptyPMInitiativeText(decision.summary)
    } else if shouldUseAnalystBenchFirst {
        reason = nonEmptyPMInitiativeText(linkedDelegation?.taskingBrief?.whyNow)
            ?? nonEmptyPMInitiativeText(linkedDelegation?.rationale)
            ?? nonEmptyPMInitiativeText(linkedMemo?.uncertaintySummary)
    } else {
        reason = nonEmptyPMInitiativeText(decision.summary)
            ?? nonEmptyPMInitiativeText(linkedMemo?.executiveSummary)
            ?? nonEmptyPMInitiativeText(linkedMemo?.recommendedNextStep)
    }

    return classifyPMInitiativePosture(
        PMInitiativeContext(
            needsClarification: needsClarification,
            shouldUseAnalystBenchFirst: shouldUseAnalystBenchFirst,
            ownerDecisionRequired: ownerDecisionRequired,
            shouldStayQuiet: decision.status != .active,
            reason: reason
        )
    )
}

private func initiativeSummary(
    posture: PMInitiativePosture,
    reason: String?,
    fallback: String
) -> String {
    let resolvedReason = nonEmptyPMInitiativeText(reason) ?? fallback

    switch posture {
    case .clarifyFirst:
        return "Clarify first: \(resolvedReason)"
    case .analystBenchFirst:
        return "Bench first: \(resolvedReason)"
    case .summarizeAndInform:
        return "Summary only: \(resolvedReason)"
    case .ownerDecisionRequired:
        return "Owner decision: \(resolvedReason)"
    case .stayQuiet:
        return "Stay quiet: \(resolvedReason)"
    }
}

private func nonEmptyPMInitiativeText(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false
    else {
        return nil
    }
    return trimmed
}
