import Foundation

public struct AnalystFindingReadablePresentation: Sendable, Equatable {
    public let title: String
    public let summary: String
    public let thesis: String
    public let symbolsSummary: String?
    public let tagsSummary: String?
    public let statusSummary: String
    public let confidenceSummary: String
    public let timeHorizonSummary: String?
    public let linkedMemoSummary: String?
    public let linkedEvidenceSummary: String?
    public let boundaryNote: String

    public init(
        title: String,
        summary: String,
        thesis: String,
        symbolsSummary: String?,
        tagsSummary: String?,
        statusSummary: String,
        confidenceSummary: String,
        timeHorizonSummary: String?,
        linkedMemoSummary: String?,
        linkedEvidenceSummary: String?,
        boundaryNote: String
    ) {
        self.title = title
        self.summary = summary
        self.thesis = thesis
        self.symbolsSummary = symbolsSummary
        self.tagsSummary = tagsSummary
        self.statusSummary = statusSummary
        self.confidenceSummary = confidenceSummary
        self.timeHorizonSummary = timeHorizonSummary
        self.linkedMemoSummary = linkedMemoSummary
        self.linkedEvidenceSummary = linkedEvidenceSummary
        self.boundaryNote = boundaryNote
    }
}

public struct AnalystEvidenceRefReadablePresentation: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let sourceSummary: String
    public let observedAtSummary: String?
    public let summary: String?

    public init(
        id: String,
        title: String,
        sourceSummary: String,
        observedAtSummary: String?,
        summary: String?
    ) {
        self.id = id
        self.title = title
        self.sourceSummary = sourceSummary
        self.observedAtSummary = observedAtSummary
        self.summary = summary
    }
}

public struct AnalystEvidenceBundleReadablePresentation: Sendable, Equatable {
    public let summary: String
    public let notes: String?
    public let coverageSummary: String
    public let refs: [AnalystEvidenceRefReadablePresentation]
    public let boundaryNote: String

    public init(
        summary: String,
        notes: String?,
        coverageSummary: String,
        refs: [AnalystEvidenceRefReadablePresentation],
        boundaryNote: String
    ) {
        self.summary = summary
        self.notes = notes
        self.coverageSummary = coverageSummary
        self.refs = refs
        self.boundaryNote = boundaryNote
    }
}

public func makeAnalystFindingReadablePresentation(
    _ finding: AnalystFinding,
    linkedMemo: AnalystMemo? = nil,
    linkedEvidenceBundle: AnalystEvidenceBundle? = nil
) -> AnalystFindingReadablePresentation {
    AnalystFindingReadablePresentation(
        title: finding.title,
        summary: finding.summary,
        thesis: finding.thesis,
        symbolsSummary: analystJoinedListSummary(finding.symbols, empty: nil),
        tagsSummary: analystJoinedListSummary(finding.tags, empty: nil),
        statusSummary: finding.status.displayTitle,
        confidenceSummary: analystConfidenceSummary(finding.confidence),
        timeHorizonSummary: finding.timeHorizon?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        linkedMemoSummary: linkedMemo.map { "Memo \($0.memoId)" },
        linkedEvidenceSummary: linkedEvidenceBundle.map { "Evidence bundle \($0.bundleId) • \($0.refs.count) ref\($0.refs.count == 1 ? "" : "s")" },
        boundaryNote: "This is an analyst research finding. It is not a PM decision, owner approval request, signal, proposal, or standing-report artifact."
    )
}

public func makeAnalystEvidenceBundleReadablePresentation(
    _ bundle: AnalystEvidenceBundle
) -> AnalystEvidenceBundleReadablePresentation {
    AnalystEvidenceBundleReadablePresentation(
        summary: bundle.summary,
        notes: bundle.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        coverageSummary: "\(bundle.refs.count) evidence ref\(bundle.refs.count == 1 ? "" : "s")",
        refs: bundle.refs.map(makeAnalystEvidenceRefReadablePresentation),
        boundaryNote: "Evidence refs are provenance anchors for analyst research. They are not owner-facing recommendations or approval artifacts."
    )
}

private func makeAnalystEvidenceRefReadablePresentation(
    _ ref: AnalystEvidenceRef
) -> AnalystEvidenceRefReadablePresentation {
    var sourceParts = [ref.sourceKind.displayTitle]
    if let sourceIdentifier = ref.sourceIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
        sourceParts.append(sourceIdentifier)
    } else if let appEntityID = ref.appEntityID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
        sourceParts.append(appEntityID)
    }

    return AnalystEvidenceRefReadablePresentation(
        id: ref.refId,
        title: ref.title,
        sourceSummary: sourceParts.joined(separator: " • "),
        observedAtSummary: ref.observedAt.map(analystResearchTimestamp),
        summary: ref.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    )
}

private func analystJoinedListSummary(_ values: [String], empty: String?) -> String? {
    let cleaned = values
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    guard cleaned.isEmpty == false else {
        return empty
    }
    return cleaned.joined(separator: ", ")
}

private func analystConfidenceSummary(_ confidence: Double) -> String {
    let percentage = Int((min(max(confidence, 0), 1) * 100).rounded())
    return "\(percentage)%"
}

private func analystResearchTimestamp(_ date: Date) -> String {
    DateCodec.formatISO8601(date)
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
