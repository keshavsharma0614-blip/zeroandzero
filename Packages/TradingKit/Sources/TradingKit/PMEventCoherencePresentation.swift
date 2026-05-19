import Foundation

public enum PMEventActionabilityCategory: String, Codable, Sendable, Equatable, CaseIterable {
    case clarification = "clarification"
    case ownerInformational = "owner_informational"
    case ownerDecisionRequired = "owner_decision_required"
    case benchInternal = "bench_internal"
    case traceabilityOnly = "traceability_only"
}

public struct PMEventCoherencePresentation: Sendable, Equatable {
    public let initiativePosture: PMInitiativePosture
    public let actionabilityCategory: PMEventActionabilityCategory
    public let ownerTitle: String
    public let ownerSummary: String
    public let telegramTitle: String
    public let pmInboxSummary: String
    public let ownerVisible: Bool
    public let traceabilityOnly: Bool

    public init(
        initiativePosture: PMInitiativePosture,
        actionabilityCategory: PMEventActionabilityCategory,
        ownerTitle: String,
        ownerSummary: String,
        telegramTitle: String,
        pmInboxSummary: String,
        ownerVisible: Bool,
        traceabilityOnly: Bool
    ) {
        self.initiativePosture = initiativePosture
        self.actionabilityCategory = actionabilityCategory
        self.ownerTitle = ownerTitle
        self.ownerSummary = ownerSummary
        self.telegramTitle = telegramTitle
        self.pmInboxSummary = pmInboxSummary
        self.ownerVisible = ownerVisible
        self.traceabilityOnly = traceabilityOnly
    }
}

public func makePMEventCoherencePresentation(
    posture: PMInitiativePosture,
    initiativeSummary: String
) -> PMEventCoherencePresentation {
    let reason = pmEventCoherenceReason(from: initiativeSummary)

    switch posture {
    case .clarifyFirst:
        return PMEventCoherencePresentation(
            initiativePosture: posture,
            actionabilityCategory: .clarification,
            ownerTitle: "Clarification",
            ownerSummary: "Clarification needed. \(reason)",
            telegramTitle: "Clarification",
            pmInboxSummary: "Clarification path. Keep this conversational and do not present it like a mature recommendation or owner decision ask.",
            ownerVisible: true,
            traceabilityOnly: false
        )
    case .summarizeAndInform:
        return PMEventCoherencePresentation(
            initiativePosture: posture,
            actionabilityCategory: .ownerInformational,
            ownerTitle: "FYI",
            ownerSummary: "FYI only. \(reason)",
            telegramTitle: "FYI",
            pmInboxSummary: "Informational PM event. Preserve the same FYI meaning here and keep technical traceability secondary.",
            ownerVisible: true,
            traceabilityOnly: false
        )
    case .ownerDecisionRequired:
        return PMEventCoherencePresentation(
            initiativePosture: posture,
            actionabilityCategory: .ownerDecisionRequired,
            ownerTitle: "Decision Required",
            ownerSummary: "Decision required. \(reason)",
            telegramTitle: "Decision required",
            pmInboxSummary: "Decision-required PM event. Preserve the owner ask as the primary meaning and keep traceability secondary.",
            ownerVisible: true,
            traceabilityOnly: false
        )
    case .analystBenchFirst:
        return PMEventCoherencePresentation(
            initiativePosture: posture,
            actionabilityCategory: .benchInternal,
            ownerTitle: "Bench First",
            ownerSummary: "Bench first. \(reason)",
            telegramTitle: "Bench first",
            pmInboxSummary: "Bench-first PM event. This is traceability for PM and operator review, not a fresh owner-facing ask or wake-up.",
            ownerVisible: false,
            traceabilityOnly: true
        )
    case .stayQuiet:
        return PMEventCoherencePresentation(
            initiativePosture: posture,
            actionabilityCategory: .traceabilityOnly,
            ownerTitle: "Internal Only",
            ownerSummary: "Internal only. \(reason)",
            telegramTitle: "Internal only",
            pmInboxSummary: "Internal PM traceability only. No owner-facing action or Telegram outreach is justified from this event as-is.",
            ownerVisible: false,
            traceabilityOnly: true
        )
    }
}

private func pmEventCoherenceReason(from initiativeSummary: String) -> String {
    let trimmed = initiativeSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let separator = trimmed.range(of: ": ") else {
        return trimmed
    }
    let reason = String(trimmed[separator.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    return reason.isEmpty ? trimmed : reason
}
