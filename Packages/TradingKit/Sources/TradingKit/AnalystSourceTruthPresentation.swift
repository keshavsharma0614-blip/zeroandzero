import Foundation

public struct AnalystSourceTruthPresentation: Sendable, Equatable {
    public let summary: String
    public let primarySources: [String]
    public let weakSupportSummary: String?

    public init(
        summary: String,
        primarySources: [String],
        weakSupportSummary: String?
    ) {
        self.summary = summary
        self.primarySources = primarySources
        self.weakSupportSummary = weakSupportSummary
    }
}

public func makeAnalystSourceTruthPresentation(
    memo: AnalystMemo?,
    linkedEvidenceBundle: AnalystEvidenceBundle?,
    fallbackEvidenceReferences: [String] = []
) -> AnalystSourceTruthPresentation? {
    guard let memo else {
        return nil
    }

    let bundleRefs = linkedEvidenceBundle?.refs ?? []
    let appNewsRefs = bundleRefs.filter { $0.sourceKind == .appNews }
    let webRefs = bundleRefs.filter { $0.sourceKind == .web }
    let materialWebRefs = webRefs.filter { webRefIsMaterialSupport($0) }
    let weakWebRefs = webRefs.filter { webRefIsMaterialSupport($0) == false }
    let trust = makeAnalystResearchTrustReadablePresentation(
        memo: memo,
        linkedEvidenceBundle: linkedEvidenceBundle
    )

    var primarySources: [String] = []
    if appNewsRefs.isEmpty == false {
        primarySources.append(
            "App-owned recent news: \(appNewsRefs.prefix(3).map(\.title).joined(separator: " | "))"
        )
    }
    if materialWebRefs.isEmpty == false {
        primarySources.append(
            "Supplemental outside research: \(materialWebRefs.prefix(3).map(sourceTruthReadableLine(for:)).joined(separator: " | "))"
        )
    }

    let weakSupportSummary: String?
    if weakWebRefs.isEmpty == false && materialWebRefs.isEmpty {
        weakSupportSummary = "Recorded outside research was mostly generic corroboration or reference context rather than material support: \(weakWebRefs.prefix(2).map(\.title).joined(separator: " | "))."
    } else if bundleRefs.isEmpty {
        weakSupportSummary = firstNonEmptySourceTruthText([
            memo.evidenceSummary,
            "No durable primary source refs were attached to this analyst artifact."
        ])
    } else {
        weakSupportSummary = nil
    }

    if bundleRefs.isEmpty, fallbackEvidenceReferences.isEmpty == false {
        let fallback = fallbackStandingSourceTruth(
            trustSummary: trust.postureSummary,
            references: fallbackEvidenceReferences
        )
        return AnalystSourceTruthPresentation(
            summary: fallback.summary,
            primarySources: fallback.primarySources,
            weakSupportSummary: fallback.weakSupportSummary
        )
    }

    let summary = trust.postureSummary
    if summary.isEmpty && primarySources.isEmpty && weakSupportSummary == nil {
        return nil
    }

    return AnalystSourceTruthPresentation(
        summary: summary,
        primarySources: primarySources,
        weakSupportSummary: weakSupportSummary
    )
}

private func sourceTruthReadableLine(for ref: AnalystEvidenceRef) -> String {
    let origin: String
    let freshnessNote = ref.freshnessNote?.lowercased() ?? ""
    if freshnessNote.contains("supplemental_public_web_from_app_news") {
        origin = "linked from app news"
    } else if freshnessNote.contains("charter_preferred") || freshnessNote.contains("discovered_page") {
        origin = "charter-governed web research"
    } else {
        origin = "outside research"
    }
    return "\(ref.title) (\(origin))"
}

private func webRefIsMaterialSupport(_ ref: AnalystEvidenceRef) -> Bool {
    let title = ref.title.lowercased()
    let summary = ref.summary?.lowercased() ?? ""

    if summary.contains("compacted into corroboration")
        || summary.contains("mostly repeats the app-news fact pattern")
        || summary.contains("mostly repeated the same fact pattern") {
        return false
    }

    if summary.contains("adds incremental timing, background, or strategic/risk context")
        || summary.contains("provided stronger confirmation")
        || summary.contains("stronger or more primary sourcing")
        || summary.contains("qualifies or challenges the app-news baseline")
        || summary.contains("introduced disconfirming or qualifying context") {
        return true
    }

    let genericTitleHints = [
        "stanford ai index",
        "macro seminar",
        "cepr seminar",
        "cepr workshop",
        "conference announcement",
        "benchmark overview"
    ]
    if genericTitleHints.contains(where: { title.contains($0) }) {
        return false
    }

    return true
}

private func firstNonEmptySourceTruthText(_ values: [String?]) -> String? {
    for value in values {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty == false {
            return trimmed
        }
    }
    return nil
}

private func fallbackStandingSourceTruth(
    trustSummary: String,
    references: [String]
) -> (summary: String, primarySources: [String], weakSupportSummary: String?) {
    let cleaned = references.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    let primarySources = cleaned.filter { reference in
        let lowered = reference.lowercased()
        if lowered.contains("stanford ai index") || lowered.contains("macro seminar") {
            return false
        }
        if lowered.contains("cepr seminar") || lowered.contains("cepr workshop") || lowered.contains("conference announcement") {
            return false
        }
        return lowered.hasPrefix("recent news:")
            || lowered.hasPrefix("current holdings snapshot:")
            || lowered.hasPrefix("portfolio strategy brief:")
            || lowered.hasPrefix("current ")
    }
    let weakReferences = cleaned.filter { reference in
        let lowered = reference.lowercased()
        return lowered.contains("stanford ai index")
            || lowered.contains("macro seminar")
            || lowered.contains("cepr seminar")
            || lowered.contains("cepr workshop")
            || lowered.contains("conference announcement")
            || lowered.contains("benchmark overview")
    }
    let weakSupportSummary: String?
    if weakReferences.isEmpty == false && primarySources.isEmpty {
        weakSupportSummary = "Recorded support stayed generic in this standing artifact: \(weakReferences.prefix(2).joined(separator: " | "))."
    } else if weakReferences.isEmpty == false {
        weakSupportSummary = "Outside support in this standing artifact stayed generic or reference-like rather than materially report-shaping: \(weakReferences.prefix(2).joined(separator: " | "))."
    } else {
        weakSupportSummary = nil
    }
    return (
        summary: trustSummary.isEmpty ? "This standing artifact is grounded on the app-owned sources recorded directly on the report." : trustSummary,
        primarySources: primarySources,
        weakSupportSummary: weakSupportSummary
    )
}
