import Foundation

public enum PMRecommendationClosureStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case awaitingOwner = "awaiting_owner"
    case backgroundPMReview = "background_pm_review"
    case moreWorkRequested = "more_work_requested"
    case superseded = "superseded"
    case routedOrInProgress = "routed_or_in_progress"
    case completed = "completed"
    case declined = "declined"
    case blockedOrFailed = "blocked_or_failed"
    case closedNoFurtherAction = "closed_no_further_action"
}

public struct PMRecommendationClosurePresentation: Sendable, Equatable {
    public let status: PMRecommendationClosureStatus
    public let title: String
    public let ownerSummary: String
    public let pmInboxSummary: String
    public let ownerPending: Bool
    public let stillCurrent: Bool

    public init(
        status: PMRecommendationClosureStatus,
        title: String,
        ownerSummary: String,
        pmInboxSummary: String,
        ownerPending: Bool,
        stillCurrent: Bool
    ) {
        self.status = status
        self.title = title
        self.ownerSummary = ownerSummary
        self.pmInboxSummary = pmInboxSummary
        self.ownerPending = ownerPending
        self.stillCurrent = stillCurrent
    }
}

public func makePMRecommendationClosurePresentation(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord? = nil,
    executionAssessment: PMExecutionRoutingAssessment? = nil,
    linkedDelegationObservability: PMDelegationObservabilitySummary? = nil
) -> PMRecommendationClosurePresentation {
    makePMRecommendationClosurePresentation(
        status: resolvePMRecommendationClosureStatus(
            request: request,
            linkedDecision: linkedDecision,
            executionAssessment: executionAssessment,
            linkedDelegationObservability: linkedDelegationObservability
        )
    )
}

public func makePMRecommendationClosurePresentation(
    decision: PMDecisionRecord,
    linkedApprovalRequest: PMApprovalRequest? = nil,
    executionAssessment: PMExecutionRoutingAssessment? = nil,
    linkedDelegationObservability: PMDelegationObservabilitySummary? = nil
) -> PMRecommendationClosurePresentation {
    if let linkedApprovalRequest {
        return makePMRecommendationClosurePresentation(
            request: linkedApprovalRequest,
            linkedDecision: decision,
            executionAssessment: executionAssessment,
            linkedDelegationObservability: linkedDelegationObservability
        )
    }

    let status: PMRecommendationClosureStatus
    switch decision.status {
    case .superseded:
        status = .superseded
    case .withdrawn:
        status = .closedNoFurtherAction
    case .active:
        if let linkedApprovalRequest {
            let linkedClosure = makePMRecommendationClosurePresentation(
                request: linkedApprovalRequest,
                linkedDecision: decision,
                executionAssessment: executionAssessment,
                linkedDelegationObservability: linkedDelegationObservability
            )
            status = linkedClosure.status
        } else if standingReviewBackgroundByDefault(decision: decision, linkedApprovalRequest: nil) {
            status = .backgroundPMReview
        } else if nonEmptyClosureText(decision.ownerAsk) != nil {
            status = .awaitingOwner
        } else if let executionAssessment {
            status = statusFromRouting(executionAssessment.status)
        } else if let linkedDelegationObservability {
            status = statusFromDelegation(linkedDelegationObservability)
        } else {
            status = .closedNoFurtherAction
        }
    }

    return makePMRecommendationClosurePresentation(status: status)
}

private func resolvePMRecommendationClosureStatus(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord?,
    executionAssessment: PMExecutionRoutingAssessment?,
    linkedDelegationObservability: PMDelegationObservabilitySummary?
) -> PMRecommendationClosureStatus {
    if linkedDecision?.status == .superseded || request.status == .stale {
        return .superseded
    }

    if linkedDecision?.status == .withdrawn || request.status == .withdrawn {
        return .closedNoFurtherAction
    }

    if standingReviewBackgroundByDefault(
        request: request,
        linkedDecision: linkedDecision
    ) {
        return .backgroundPMReview
    }

    if request.status == .pending {
        return .awaitingOwner
    }

    if let ownerResponse = request.ownerResponse {
        switch ownerResponse {
        case .approved:
            if let liveStatus = request.liveOrderExecutionLifecycleState?.status,
               liveStatus.isTerminal {
                switch liveStatus {
                case .filled:
                    return .completed
                case .blocked, .canceled, .rejected, .expired:
                    return .blockedOrFailed
                case .submitted, .partiallyFilled:
                    return .routedOrInProgress
                }
            }
            if let executionAssessment {
                return statusFromRouting(executionAssessment.status)
            }
            if let linkedDelegationObservability {
                return statusFromDelegation(linkedDelegationObservability)
            }
            return .completed
        case .rejected:
            return .declined
        case .reviewed:
            return .moreWorkRequested
        }
    }

    return .closedNoFurtherAction
}

private func statusFromRouting(_ status: PMExecutionRoutingStatus) -> PMRecommendationClosureStatus {
    switch status {
    case .routedSuccessfully, .executableNowPaper, .executableNowLive:
        return .routedOrInProgress
    case .partiallyRouted:
        return .blockedOrFailed
    case .blockedMissingProposalApproval,
            .blockedLiveNotArmed,
            .blockedKillSwitch,
            .blockedEnvironmentMismatch,
            .blockedExecutionPrerequisites,
            .launchFailed,
            .invalidState:
        return .blockedOrFailed
    }
}

private func statusFromDelegation(_ summary: PMDelegationObservabilitySummary) -> PMRecommendationClosureStatus {
    if summary.launchHealth == .failed {
        return .blockedOrFailed
    }

    switch summary.workflowState {
    case .noOutputsYet, .awaitingDownstreamReview:
        return .routedOrInProgress
    case .resolved:
        return .closedNoFurtherAction
    case .canceled:
        return .closedNoFurtherAction
    }
}

public func makePMRecommendationClosurePresentation(
    status: PMRecommendationClosureStatus
) -> PMRecommendationClosurePresentation {
    switch status {
    case .awaitingOwner:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Waiting on You",
            ownerSummary: "This PM ask is still waiting on your decision.",
            pmInboxSummary: "Owner decision is still pending. Keep this as the active ask until the owner responds or the PM replaces it.",
            ownerPending: true,
            stillCurrent: true
        )
    case .backgroundPMReview:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Background PM Review",
            ownerSummary: "This standing-review item remains in PM background review. No owner action is pending.",
            pmInboxSummary: "This standing-review item remains background PM work. Keep it for traceability and PM follow-up judgment, not as an active owner ask.",
            ownerPending: false,
            stillCurrent: true
        )
    case .moreWorkRequested:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "More Work Requested",
            ownerSummary: "You asked for more work. The prior ask is no longer decision-ready in its old form.",
            pmInboxSummary: "Owner requested more work. Keep the original ask for traceability, but do not present it as still pending approval.",
            ownerPending: false,
            stillCurrent: true
        )
    case .superseded:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Superseded",
            ownerSummary: "A newer PM state replaced this ask. It no longer needs attention.",
            pmInboxSummary: "This recommendation episode has been superseded by later PM state. Preserve it for traceability only.",
            ownerPending: false,
            stillCurrent: false
        )
    case .routedOrInProgress:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Handled By PM",
            ownerSummary: "Your decision is recorded. PM or downstream handling is now in progress.",
            pmInboxSummary: "Owner decision is closed. Downstream routing or handling is now in progress.",
            ownerPending: false,
            stillCurrent: true
        )
    case .completed:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Completed",
            ownerSummary: "This recommendation episode is closed. No further owner action is needed.",
            pmInboxSummary: "This recommendation episode is completed and kept for traceability only.",
            ownerPending: false,
            stillCurrent: true
        )
    case .declined:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Declined",
            ownerSummary: "You declined this ask. It is closed unless the PM brings back a revised recommendation.",
            pmInboxSummary: "Owner declined this PM ask. Keep the decision traceable, but do not present it as an active ask.",
            ownerPending: false,
            stillCurrent: true
        )
    case .blockedOrFailed:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Blocked",
            ownerSummary: "Your decision is recorded, but downstream handling is blocked or failed.",
            pmInboxSummary: "Owner decision is closed. Downstream handling is blocked or failed; preserve the issue without re-opening the original ask.",
            ownerPending: false,
            stillCurrent: true
        )
    case .closedNoFurtherAction:
        return PMRecommendationClosurePresentation(
            status: status,
            title: "Closed",
            ownerSummary: "This recommendation episode no longer requires owner action.",
            pmInboxSummary: "This recommendation episode is closed with no further owner action pending.",
            ownerPending: false,
            stillCurrent: true
        )
    }
}

private func nonEmptyClosureText(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false
    else {
        return nil
    }
    return trimmed
}

func isStandingReviewOwnerDecisionRequest(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord?
) -> Bool {
    let subject = request.subject.lowercased()
    if subject.hasPrefix("review standing analyst synthesis:") {
        return true
    }

    let title = linkedDecision?.title.lowercased() ?? ""
    return title.hasPrefix("standing review escalation:")
}

func shouldSurfaceStandingReviewOwnerDecision(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord?
) -> Bool {
    guard isStandingReviewOwnerDecisionRequest(
        request: request,
        linkedDecision: linkedDecision
    ) else {
        return true
    }

    let signalText = [
        linkedDecision?.recommendedAction,
        linkedDecision?.summary,
        request.rationale
    ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .joined(separator: " ")
        .lowercased()

    let lowSignalPhrases = [
        "no fresh",
        "no material",
        "no meaningful",
        "no action",
        "no governed next step",
        "worth monitoring",
        "monitor-only",
        "background-only",
        "candidate worth considering",
        "remain background",
        "remain monitor",
        "did not displace"
    ]
    if lowSignalPhrases.contains(where: { signalText.contains($0) }) {
        return false
    }

    let actionPhrases = [
        "reduce",
        "trim",
        "hedge",
        "rebalance",
        "rotate",
        "exit",
        "de-risk",
        "change posture",
        "change exposure",
        "adjust sizing",
        "raise cash",
        "cut exposure",
        "increase exposure",
        "owner decision"
    ]
    return actionPhrases.contains(where: { signalText.contains($0) })
}

func standingReviewBackgroundByDefault(
    request: PMApprovalRequest,
    linkedDecision: PMDecisionRecord?
) -> Bool {
    guard request.status == .pending else {
        return false
    }
    return isStandingReviewOwnerDecisionRequest(
        request: request,
        linkedDecision: linkedDecision
    ) && shouldSurfaceStandingReviewOwnerDecision(
        request: request,
        linkedDecision: linkedDecision
    ) == false
}

func standingReviewBackgroundByDefault(
    decision: PMDecisionRecord,
    linkedApprovalRequest: PMApprovalRequest?
) -> Bool {
    guard decision.status == .active else {
        return false
    }

    if let linkedApprovalRequest {
        return standingReviewBackgroundByDefault(
            request: linkedApprovalRequest,
            linkedDecision: decision
        )
    }

    let title = decision.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard title.hasPrefix("standing review escalation:") else {
        return false
    }

    let signalText = [
        decision.recommendedAction,
        decision.summary
    ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .joined(separator: " ")
        .lowercased()

    let lowSignalPhrases = [
        "no fresh",
        "no material",
        "no meaningful",
        "no action",
        "no governed next step",
        "worth monitoring",
        "monitor-only",
        "background-only",
        "candidate worth considering",
        "remain background",
        "remain monitor",
        "did not displace"
    ]
    if lowSignalPhrases.contains(where: { signalText.contains($0) }) {
        return true
    }

    let actionPhrases = [
        "reduce",
        "trim",
        "hedge",
        "rebalance",
        "rotate",
        "exit",
        "de-risk",
        "change posture",
        "change exposure",
        "adjust sizing",
        "raise cash",
        "cut exposure",
        "increase exposure",
        "owner decision"
    ]
    return actionPhrases.contains(where: { signalText.contains($0) }) == false
}
