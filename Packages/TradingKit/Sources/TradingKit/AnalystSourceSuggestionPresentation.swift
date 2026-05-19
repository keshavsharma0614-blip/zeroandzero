import Foundation

public struct AnalystSourceAccessSuggestionReadablePresentation: Sendable, Equatable {
    public let statusLabel: String
    public let limitationLabel: String
    public let nextStepLabel: String
    public let linkedArtifactsSummary: String
    public let resultSummary: String
    public let closureSummary: String
    public let boundaryNote: String

    public init(
        statusLabel: String,
        limitationLabel: String,
        nextStepLabel: String,
        linkedArtifactsSummary: String,
        resultSummary: String,
        closureSummary: String,
        boundaryNote: String
    ) {
        self.statusLabel = statusLabel
        self.limitationLabel = limitationLabel
        self.nextStepLabel = nextStepLabel
        self.linkedArtifactsSummary = linkedArtifactsSummary
        self.resultSummary = resultSummary
        self.closureSummary = closureSummary
        self.boundaryNote = boundaryNote
    }
}

public func makeAnalystSourceAccessSuggestionReadablePresentation(
    _ suggestion: AnalystSourceAccessSuggestionRecord
) -> AnalystSourceAccessSuggestionReadablePresentation {
    let linkedArtifacts = [
        trimmedReadableSourceSuggestionText(suggestion.memoId).map { "Memo \($0)" },
        trimmedReadableSourceSuggestionText(suggestion.findingId).map { "Finding \($0)" },
        trimmedReadableSourceSuggestionText(suggestion.evidenceBundleId).map { "Evidence bundle \($0)" },
        trimmedReadableSourceSuggestionText(suggestion.delegationId).map { "Delegation \($0)" }
    ]
        .compactMap { $0 }
        .joined(separator: " • ")

    let resultSummary: String
    let closureSummary: String
    switch suggestion.status {
    case .open:
        resultSummary = "No charter source-policy change has been recorded yet."
        closureSummary = "This source suggestion is still open and awaiting an explicit PM action."
    case .addedToPreferredSources:
        resultSummary = suggestion.resolutionSummary
            ?? "Result: added to the linked charter's preferred sources."
        closureSummary = "This suggestion closed by updating bounded charter source policy."
    case .addedToRestrictedSources:
        resultSummary = suggestion.resolutionSummary
            ?? "Result: added to the linked charter's restricted sources."
        closureSummary = "This suggestion closed by updating bounded charter source policy."
    case .dismissed:
        resultSummary = suggestion.resolutionSummary
            ?? "Result: dismissed with no charter source-policy change."
        closureSummary = "This suggestion closed without changing the durable charter source-policy truth."
    case .reviewed:
        resultSummary = suggestion.resolutionSummary
            ?? "Result: reviewed in a legacy closure state."
        closureSummary = "This legacy suggestion record is no longer open."
    case .closed:
        resultSummary = suggestion.resolutionSummary
            ?? "Result: closed in a legacy terminal state."
        closureSummary = "This legacy suggestion record is no longer open."
    }

    return AnalystSourceAccessSuggestionReadablePresentation(
        statusLabel: suggestion.status.displayTitle,
        limitationLabel: suggestion.limitation.rawValue.replacingOccurrences(of: "_", with: " "),
        nextStepLabel: suggestion.recommendedNextStep.rawValue.replacingOccurrences(of: "_", with: " "),
        linkedArtifactsSummary: linkedArtifacts.isEmpty ? "No linked analyst artifacts recorded." : linkedArtifacts,
        resultSummary: resultSummary,
        closureSummary: closureSummary,
        boundaryNote: "This is a bounded source-governance artifact only. Source-policy actions update charter guidance explicitly, but external web content remains untrusted evidence only and never instruction truth."
    )
}

private func trimmedReadableSourceSuggestionText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false else {
        return nil
    }
    return trimmed
}
