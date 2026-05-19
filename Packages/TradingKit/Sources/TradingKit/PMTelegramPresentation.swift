import Foundation

public enum TelegramPMInboundIntent: Sendable, Equatable {
    case ownerApprovalResponse(PMApprovalRequestOwnerResponse)
}

public func parseTelegramPMInboundIntent(_ text: String) -> TelegramPMInboundIntent? {
    let normalized = telegramIntentNormalizedText(text)
    guard normalized.isEmpty == false else { return nil }

    switch normalized {
    case "approve":
        return .ownerApprovalResponse(.approved)
    case "decline":
        return .ownerApprovalResponse(.rejected)
    case "more work":
        return .ownerApprovalResponse(.reviewed)
    default:
        break
    }

    return nil
}

public func makeTelegramApprovalRequestPrompt(
    request: PMApprovalRequest,
    memo: PMApprovalRequestMemoPresentation
) -> String {
    var lines: [String] = []
    let recommendation = telegramBoundedLine(memo.recommendation ?? memo.requestedAction, maxLength: 180)
    let whyNow = telegramBoundedLine(memo.whyNow, maxLength: 180)

    lines.append("\(memo.coherence.telegramTitle): \(telegramBoundedLine(memo.requestedAction, maxLength: 180))")
    lines.append("Recommendation: \(recommendation)")
    lines.append("Why now: \(whyNow)")

    if request.requestType == .liveOrderReview {
        lines.append("Live order approval happens in Command Center > Your Decisions on the Mac. From Telegram, you can reply Decline or More Work. No Live order is sent from Telegram approval.")
    } else {
        lines.append("Reply with exactly: Approve, Decline, or More Work.")
    }

    if request.requestType != .liveOrderReview,
       let approved = memo.approvedNextStep {
        lines.append("If approved: \(telegramBoundedLine(approved, maxLength: 180))")
    }

    if request.requestType == .strategyChange {
        lines.append("The saved strategy brief stays unchanged unless you explicitly approve here.")
    } else if request.requestType == .liveOrderReview {
        lines.append("Telegram is transport only. Review happens in the app; Live orders still require the governed order path and local authentication.")
    } else if request.proposalId != nil {
        lines.append("This records PM review only. Proposal and trading gates stay separate.")
    }

    return lines.joined(separator: "\n")
}

public func makeTelegramLiveOrderReviewApprovalBlockedAcknowledgement() -> String {
    "Live order approval must be completed in Command Center > Your Decisions on the Mac. I left the Live order review pending. No order was sent."
}

public func makeTelegramDecisionPrompt(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation
) -> String {
    switch memo.coherence.actionabilityCategory {
    case .clarification:
        return makeTelegramClarificationPrompt(decision: decision, memo: memo)
    case .ownerInformational:
        return makeTelegramInformationalPrompt(decision: decision, memo: memo)
    case .ownerDecisionRequired:
        break
    case .benchInternal, .traceabilityOnly:
        return makeTelegramPassiveNotificationGuidance(
            decision: decision,
            memo: memo
        )
    }

    var lines: [String] = []
    lines.append("\(memo.coherence.telegramTitle): \(telegramBoundedLine(memo.ownerAsk ?? memo.recommendation, maxLength: 180))")
    lines.append("Recommendation: \(telegramBoundedLine(memo.recommendation, maxLength: 180))")
    lines.append("Why now: \(telegramBoundedLine(memo.whyNow, maxLength: 180))")

    if let ownerAsk = memo.ownerAsk {
        lines.append("Next step: \(telegramBoundedLine(ownerAsk, maxLength: 160))")
    } else if let recommendedAction = memo.recommendedAction {
        lines.append("Next step: \(telegramBoundedLine(recommendedAction, maxLength: 160))")
    } else if let approvedNextStep = memo.approvedNextStep {
        lines.append("Next step: \(telegramBoundedLine(approvedNextStep, maxLength: 160))")
    } else {
        lines.append("Next step: Ask for more detail, support, uncertainty, strategy fit, or next-step impact if needed.")
    }

    if decision.proposalId != nil {
        lines.append("Any proposal or trading step stays behind the existing app review and safety gates.")
    }

    return lines.joined(separator: "\n")
}

public func classifyTelegramDecisionWakeUpClass(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation,
    recentNewsWakeUp: RecentNewsWakeUpPresentation?,
    portfolioRiskWakeUp: PortfolioRiskWakeUpPresentation?
) -> TelegramPMWakeUpClass {
    if decision.status != .active {
        return .doNotSendProactively
    }
    if memo.initiativePosture == .ownerDecisionRequired,
       let ownerAsk = memo.ownerAsk,
       ownerAsk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
        return .importantWakeUp
    }
    if recentNewsWakeUp?.isRecentNewsWakeUp == true || portfolioRiskWakeUp?.isPortfolioRiskWakeUp == true {
        return .importantWakeUp
    }
    if decision.decisionType == .escalation || decision.decisionType == .readinessAssessment {
        return .quietInfo
    }
    if memo.initiativePosture == .analystBenchFirst || memo.initiativePosture == .stayQuiet {
        return .doNotSendProactively
    }
    if memo.initiativePosture == .clarifyFirst {
        return .conversationReply
    }
    return .doNotSendProactively
}

public func makeTelegramDecisionNotificationPrompt(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation,
    wakeUpClass: TelegramPMWakeUpClass,
    recentNewsWakeUp: RecentNewsWakeUpPresentation?,
    portfolioRiskWakeUp: PortfolioRiskWakeUpPresentation?
) -> String {
    switch wakeUpClass {
    case .approvalRequired:
        return makeTelegramDecisionPrompt(decision: decision, memo: memo)
    case .importantWakeUp:
        return makeTelegramImportantWakeUpPrompt(
            decision: decision,
            memo: memo,
            recentNewsWakeUp: recentNewsWakeUp,
            portfolioRiskWakeUp: portfolioRiskWakeUp
        )
    case .quietInfo:
        return makeTelegramQuietInfoPrompt(
            decision: decision,
            memo: memo,
            recentNewsWakeUp: recentNewsWakeUp,
            portfolioRiskWakeUp: portfolioRiskWakeUp
        )
    case .conversationReply:
        return makeTelegramDecisionPrompt(decision: decision, memo: memo)
    case .doNotSendProactively:
        return makeTelegramPassiveNotificationGuidance(
            decision: decision,
            memo: memo
        )
    }
}

public func makeTelegramApprovalResponseAcknowledgement(
    response: PMApprovalRequestOwnerResponse,
    request: PMApprovalRequest,
    approvalMemo: PMApprovalRequestMemoPresentation?
) -> String {
    switch response {
    case .approved:
        let nextStep = approvalMemo?.approvedNextStep
            ?? request.approvedNextStepSummary
            ?? "I will continue the bounded next PM step while proposal, trading, and safety gates stay separate."
        return [
            "Approve recorded.",
            "Next: \(telegramBoundedLine(nextStep, maxLength: 180))"
        ].joined(separator: "\n")
    case .rejected:
        let nextStep = approvalMemo?.rejectedNextStep
            ?? request.rejectedNextStepSummary
            ?? "I will leave this recommendation unapproved and not advance it unless the case changes."
        return [
            "Decline recorded.",
            "Next: \(telegramBoundedLine(nextStep, maxLength: 180))"
        ].joined(separator: "\n")
    case .reviewed:
        let nextStep = approvalMemo?.reviewedNextStep
            ?? request.reviewedNextStepSummary
            ?? "I will treat this as a request for more work without changing authority or execution posture."
        return [
            "More Work recorded.",
            "Next: \(telegramBoundedLine(nextStep, maxLength: 180))"
        ].joined(separator: "\n")
    }
}

public func makeTelegramAmbiguousApprovalGuidance() -> String {
    [
        "I need a single open PM ask before I can record Approve, Decline, or More Work.",
        "Ask me to restate the current PM request or open Command Center for the full decision desk."
    ].joined(separator: "\n")
}

private func makeTelegramImportantWakeUpPrompt(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation,
    recentNewsWakeUp: RecentNewsWakeUpPresentation?,
    portfolioRiskWakeUp: PortfolioRiskWakeUpPresentation?
) -> String {
    let lead = telegramWakeUpLead(
        recentNewsWakeUp: recentNewsWakeUp,
        portfolioRiskWakeUp: portfolioRiskWakeUp,
        quiet: false
    )

    let headline = recentNewsWakeUp?.isRecentNewsWakeUp == true || portfolioRiskWakeUp?.isPortfolioRiskWakeUp == true
        ? lead
        : memo.coherence.telegramTitle

    var lines = [
        "\(headline): \(telegramBoundedLine(memo.recommendation, maxLength: 180))",
        "Why now: \(telegramBoundedLine(memo.whyNow, maxLength: 180))"
    ]

    if let ownerAsk = memo.ownerAsk {
        lines.append("Action now: \(telegramBoundedLine(ownerAsk, maxLength: 170))")
    } else if let recommendedAction = memo.recommendedAction {
        lines.append("Action now: \(telegramBoundedLine(recommendedAction, maxLength: 170))")
    } else {
        lines.append("Action now: No immediate owner response is required.")
    }

    if decision.proposalId != nil {
        lines.append("Any proposal or trading step stays behind the existing app review and safety gates.")
    }

    return lines.joined(separator: "\n")
}

private func makeTelegramQuietInfoPrompt(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation,
    recentNewsWakeUp: RecentNewsWakeUpPresentation?,
    portfolioRiskWakeUp: PortfolioRiskWakeUpPresentation?
) -> String {
    let lead = telegramWakeUpLead(
        recentNewsWakeUp: recentNewsWakeUp,
        portfolioRiskWakeUp: portfolioRiskWakeUp,
        quiet: true
    )

    let headline = recentNewsWakeUp?.isRecentNewsWakeUp == true || portfolioRiskWakeUp?.isPortfolioRiskWakeUp == true
        ? lead
        : memo.coherence.telegramTitle

    var lines = [
        "\(headline): \(telegramBoundedLine(memo.recommendation, maxLength: 180))",
        "Why it matters: \(telegramBoundedLine(memo.whyNow, maxLength: 180))",
        "No immediate action is needed. Ask for detail, support, uncertainty, strategy fit, or what changed if useful."
    ]

    if decision.proposalId != nil {
        lines.append("Proposal and trading gates remain separate.")
    }

    return lines.joined(separator: "\n")
}

private func makeTelegramPassiveNotificationGuidance(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation
) -> String {
    let summary = memo.ownerAsk ?? memo.recommendedAction ?? decision.summary
    return [
        "\(memo.coherence.telegramTitle): this PM item stays passive in Telegram by default.",
        "Summary: \(telegramBoundedLine(summary, maxLength: 180))"
    ].joined(separator: "\n")
}

private func makeTelegramClarificationPrompt(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation
) -> String {
    let ask = memo.ownerAsk ?? memo.recommendedAction ?? decision.summary
    return [
        "\(memo.coherence.telegramTitle): \(telegramBoundedLine(ask, maxLength: 180))",
        "Why now: \(telegramBoundedLine(memo.whyNow, maxLength: 180))",
        "Reply with the narrower point you want me to resolve before I escalate or send this to the bench."
    ].joined(separator: "\n")
}

private func makeTelegramInformationalPrompt(
    decision: PMDecisionRecord,
    memo: PMDecisionMemoPresentation
) -> String {
    let summary = memo.recommendedAction ?? decision.summary
    return [
        "\(memo.coherence.telegramTitle): \(telegramBoundedLine(summary, maxLength: 180))",
        "Why now: \(telegramBoundedLine(memo.whyNow, maxLength: 180))",
        "No immediate action is needed. Ask for more detail, support, uncertainty, strategy fit, or what changed if useful."
    ].joined(separator: "\n")
}

private func telegramWakeUpLead(
    recentNewsWakeUp: RecentNewsWakeUpPresentation?,
    portfolioRiskWakeUp: PortfolioRiskWakeUpPresentation?,
    quiet: Bool
) -> String {
    if recentNewsWakeUp?.isRecentNewsWakeUp == true {
        return quiet ? "Quiet recent-news PM update" : "Important recent-news PM update"
    }
    if portfolioRiskWakeUp?.isPortfolioRiskWakeUp == true {
        return quiet ? "Quiet portfolio-risk PM update" : "Important portfolio-risk PM update"
    }
    return quiet ? "Quiet PM update" : "Important PM update"
}

private func telegramIntentNormalizedText(_ raw: String) -> String {
    raw
        .lowercased()
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func telegramBoundedLine(_ raw: String, maxLength: Int) -> String {
    let trimmed = raw
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > maxLength else { return trimmed }

    let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
    let prefix = String(trimmed[..<index])
    if let lastSpace = prefix.lastIndex(of: " ") {
        return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
    return prefix + "..."
}
