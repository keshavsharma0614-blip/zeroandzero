import Foundation

public struct AnalystStrategyFollowUpCandidateReadablePresentation: Sendable, Equatable {
    public let kindLabel: String
    public let statusLabel: String
    public let candidateSummary: String
    public let candidateDetail: String
    public let linkedArtifactsSummary: String
    public let resultSummary: String
    public let closureSummary: String
    public let boundaryNote: String

    public init(
        kindLabel: String,
        statusLabel: String,
        candidateSummary: String,
        candidateDetail: String,
        linkedArtifactsSummary: String,
        resultSummary: String,
        closureSummary: String,
        boundaryNote: String
    ) {
        self.kindLabel = kindLabel
        self.statusLabel = statusLabel
        self.candidateSummary = candidateSummary
        self.candidateDetail = candidateDetail
        self.linkedArtifactsSummary = linkedArtifactsSummary
        self.resultSummary = resultSummary
        self.closureSummary = closureSummary
        self.boundaryNote = boundaryNote
    }
}

public func makeAnalystStrategyFollowUpCandidateReadablePresentation(
    _ candidate: AnalystStrategyFollowUpCandidateRecord
) -> AnalystStrategyFollowUpCandidateReadablePresentation {
    let linkedArtifacts = [
        trimmedReadableStrategyFollowUpText(candidate.memoId).map { "Memo \($0)" },
        trimmedReadableStrategyFollowUpText(candidate.findingId).map { "Finding \($0)" },
        trimmedReadableStrategyFollowUpText(candidate.evidenceBundleId).map { "Evidence bundle \($0)" },
        trimmedReadableStrategyFollowUpText(candidate.delegationId).map { "Delegation \($0)" }
    ]
        .compactMap { $0 }
        .joined(separator: " • ")

    let resultSummary: String
    let closureSummary: String
    let boundaryNote: String
    switch candidate.status {
    case .open:
        resultSummary = "No durable strategic change has been recorded yet."
        closureSummary = "This candidate is still open and awaiting an explicit PM/user action."
        boundaryNote = "This records a bounded PM strategy follow-up candidate. It does not change the saved Portfolio Strategy Brief, create a PM instruction or mandate by itself, approve anything, or route execution."
    case .monitoring:
        resultSummary = "Monitoring continues without a durable strategy, instruction, or mandate change."
        closureSummary = "This candidate remains under bounded PM monitoring rather than closing into another durable artifact."
        boundaryNote = "This remains a bounded PM follow-up state. It does not change the saved Portfolio Strategy Brief, create a PM instruction or mandate by itself, approve anything, or route execution."
    case .appliedToStrategyBrief:
        resultSummary = "Result: the Portfolio Strategy Brief was updated through the explicit owner-approved strategy-change path."
        closureSummary = "This candidate closed by updating the current durable Strategy Brief rather than remaining open."
        boundaryNote = "The saved Portfolio Strategy Brief changed only because the user explicitly approved the bounded strategy-change request in the app-owned path. This candidate did not auto-edit strategy truth."
    case .convertedToInstruction:
        resultSummary = "Result: a durable PM instruction was created from this candidate."
        closureSummary = "This candidate closed by converting into a PM instruction that future PM and analyst context can reuse."
        boundaryNote = "This conversion created a PM-owned instruction artifact. It did not auto-edit the saved Portfolio Strategy Brief, approve anything, or route execution."
    case .convertedToMandate:
        resultSummary = "Result: a durable PM mandate was created from this candidate."
        closureSummary = "This candidate closed by converting into a PM mandate that future PM and analyst context can reuse."
        boundaryNote = "This conversion created a PM-owned mandate artifact. It did not auto-edit the saved Portfolio Strategy Brief, approve anything, or route execution."
    case .dismissed:
        resultSummary = "Result: dismissed with no Strategy Brief change and no new PM instruction or mandate."
        closureSummary = "This candidate closed without changing durable strategy truth or creating another PM-owned artifact."
        boundaryNote = "Dismissal keeps the traceability record while leaving the saved Portfolio Strategy Brief, PM instructions, and PM mandates unchanged."
    }

    return AnalystStrategyFollowUpCandidateReadablePresentation(
        kindLabel: candidate.followUpKind.displayTitle,
        statusLabel: candidate.status.displayTitle,
        candidateSummary: candidate.candidateSummary,
        candidateDetail: candidate.candidateDetail,
        linkedArtifactsSummary: linkedArtifacts.isEmpty ? "No linked analyst artifacts recorded." : linkedArtifacts,
        resultSummary: resultSummary,
        closureSummary: closureSummary,
        boundaryNote: boundaryNote
    )
}

private func trimmedReadableStrategyFollowUpText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false else {
        return nil
    }
    return trimmed
}
