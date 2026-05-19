import Foundation

public struct AnalystStrategyImplicationReadablePresentation: Sendable, Equatable {
    public let implicationLabel: String
    public let implicationSummary: String
    public let whyItMatters: String
    public let candidateStrategyBriefRevisionNote: String?
    public let candidatePMFollowUpSummary: String?
    public let linkedArtifactsSummary: String
    public let boundaryNote: String

    public init(
        implicationLabel: String,
        implicationSummary: String,
        whyItMatters: String,
        candidateStrategyBriefRevisionNote: String?,
        candidatePMFollowUpSummary: String?,
        linkedArtifactsSummary: String,
        boundaryNote: String
    ) {
        self.implicationLabel = implicationLabel
        self.implicationSummary = implicationSummary
        self.whyItMatters = whyItMatters
        self.candidateStrategyBriefRevisionNote = candidateStrategyBriefRevisionNote
        self.candidatePMFollowUpSummary = candidatePMFollowUpSummary
        self.linkedArtifactsSummary = linkedArtifactsSummary
        self.boundaryNote = boundaryNote
    }
}

public func makeAnalystStrategyImplicationReadablePresentation(
    _ implication: AnalystStrategyImplicationRecord
) -> AnalystStrategyImplicationReadablePresentation {
    var linkedArtifacts: [String] = []
    if let memoID = trimmedReadableImplicationText(implication.memoId) {
        linkedArtifacts.append("Memo \(memoID)")
    }
    if let findingID = trimmedReadableImplicationText(implication.findingId) {
        linkedArtifacts.append("Finding \(findingID)")
    }
    if let evidenceBundleID = trimmedReadableImplicationText(implication.evidenceBundleId) {
        linkedArtifacts.append("Evidence bundle \(evidenceBundleID)")
    }
    if let delegationID = trimmedReadableImplicationText(implication.delegationId) {
        linkedArtifacts.append("Delegation \(delegationID)")
    }

    return AnalystStrategyImplicationReadablePresentation(
        implicationLabel: implication.implicationKind.displayTitle,
        implicationSummary: implication.implicationSummary,
        whyItMatters: implication.whyItMatters,
        candidateStrategyBriefRevisionNote: trimmedReadableImplicationText(
            implication.candidateStrategyBriefRevisionNote
        ),
        candidatePMFollowUpSummary: trimmedReadableImplicationText(
            implication.candidatePMFollowUpSummary
        ),
        linkedArtifactsSummary: linkedArtifacts.joined(separator: " • "),
        boundaryNote: "This records PM strategy interpretation of analyst output. It does not change the saved Portfolio Strategy Brief, approve anything, or route execution by itself."
    )
}

private func trimmedReadableImplicationText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false else {
        return nil
    }
    return trimmed
}
