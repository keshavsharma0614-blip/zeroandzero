import Foundation

public struct AnalystResearchTrustReadablePresentation: Sendable, Equatable {
    public let coverageLabel: String
    public let outsideResearchLabel: String
    public let sourceConstraintLabel: String
    public let postureSummary: String
    public let outsideResearchSummary: String?
    public let sourceConstraintSummary: String?
    public let boundaryNote: String

    public init(
        coverageLabel: String,
        outsideResearchLabel: String,
        sourceConstraintLabel: String,
        postureSummary: String,
        outsideResearchSummary: String?,
        sourceConstraintSummary: String?,
        boundaryNote: String
    ) {
        self.coverageLabel = coverageLabel
        self.outsideResearchLabel = outsideResearchLabel
        self.sourceConstraintLabel = sourceConstraintLabel
        self.postureSummary = postureSummary
        self.outsideResearchSummary = outsideResearchSummary
        self.sourceConstraintSummary = sourceConstraintSummary
        self.boundaryNote = boundaryNote
    }
}

public struct OwnerResearchTrustSummaryPresentation: Sendable, Equatable {
    public let trustLabel: String
    public let trustSummary: String
    public let sourceConstraintSummary: String?
    public let boundaryNote: String

    public init(
        trustLabel: String,
        trustSummary: String,
        sourceConstraintSummary: String?,
        boundaryNote: String
    ) {
        self.trustLabel = trustLabel
        self.trustSummary = trustSummary
        self.sourceConstraintSummary = sourceConstraintSummary
        self.boundaryNote = boundaryNote
    }
}

public func makeAnalystResearchTrustReadablePresentation(
    memo: AnalystMemo,
    linkedEvidenceBundle: AnalystEvidenceBundle? = nil,
    relevantSourceSuggestions: [AnalystSourceAccessSuggestionRecord] = []
) -> AnalystResearchTrustReadablePresentation {
    let refs = linkedEvidenceBundle?.refs ?? []
    let appNewsRefs = refs.filter { $0.sourceKind == .appNews }
    let webRefs = refs.filter { $0.sourceKind == .web }
    let outsideRelations = inferOutsideResearchRelations(
        webRefs: webRefs,
        memoEvidenceSummary: memo.evidenceSummary
    )
    let coverage = classifyCoverage(
        appNewsCount: appNewsRefs.count,
        outsideRelations: outsideRelations,
        hasOutsideRefs: webRefs.isEmpty == false
    )
    let outsideContribution = classifyOutsideContribution(outsideRelations)

    let openSuggestions = relevantSourceSuggestions.filter(\.status.isActive)
    let closedSuggestions = relevantSourceSuggestions.filter { $0.status.isActive == false }

    let postureSummary = makeResearchTrustPostureSummary(
        coverage: coverage,
        appNewsCount: appNewsRefs.count,
        webRefCount: webRefs.count,
        openSuggestionCount: openSuggestions.count
    )

    return AnalystResearchTrustReadablePresentation(
        coverageLabel: coverage.displayTitle,
        outsideResearchLabel: outsideContribution.displayTitle,
        sourceConstraintLabel: sourceConstraintLabel(
            openSuggestions: openSuggestions,
            closedSuggestions: closedSuggestions
        ),
        postureSummary: postureSummary,
        outsideResearchSummary: outsideResearchSummary(
            contribution: outsideContribution,
            outsideRelations: outsideRelations
        ),
        sourceConstraintSummary: sourceConstraintSummary(
            openSuggestions: openSuggestions,
            closedSuggestions: closedSuggestions
        ),
        boundaryNote: "This is a compact PM-facing trust layer derived from app-owned analyst artifacts. External web content remains untrusted evidence only and never instruction truth."
    )
}

public func makeOwnerResearchTrustSummaryPresentation(
    memo: AnalystMemo,
    linkedEvidenceBundle: AnalystEvidenceBundle? = nil,
    relevantSourceSuggestions: [AnalystSourceAccessSuggestionRecord] = []
) -> OwnerResearchTrustSummaryPresentation {
    let refs = linkedEvidenceBundle?.refs ?? []
    let appNewsRefs = refs.filter { $0.sourceKind == .appNews }
    let webRefs = refs.filter { $0.sourceKind == .web }
    let outsideRelations = inferOutsideResearchRelations(
        webRefs: webRefs,
        memoEvidenceSummary: memo.evidenceSummary
    )
    let coverage = classifyCoverage(
        appNewsCount: appNewsRefs.count,
        outsideRelations: outsideRelations,
        hasOutsideRefs: webRefs.isEmpty == false
    )
    let outsideContribution = classifyOutsideContribution(outsideRelations)
    let openSuggestions = relevantSourceSuggestions.filter(\.status.isActive)

    return OwnerResearchTrustSummaryPresentation(
        trustLabel: ownerTrustLabel(
            coverage: coverage,
            outsideContribution: outsideContribution
        ),
        trustSummary: ownerTrustSummary(
            coverage: coverage,
            outsideContribution: outsideContribution
        ),
        sourceConstraintSummary: ownerSourceConstraintSummary(
            openSuggestions: openSuggestions
        ),
        boundaryNote: "This owner-facing trust summary is derived from app-owned PM and analyst artifacts. Detailed memo/finding/evidence drill-down stays in PM Inbox, and external web content remains evidence only."
    )
}

private enum AnalystResearchCoverageClassification: Sendable, Equatable {
    case appNewsOnly
    case appNewsPlusCorroboratingOutsideResearch
    case appNewsPlusMateriallyAdditiveOutsideResearch
    case outsideResearchWithoutAppNewsBaseline
    case boundedCoverageWithoutNewsOrOutsideResearch

    var displayTitle: String {
        switch self {
        case .appNewsOnly:
            return "App-News Baseline Only"
        case .appNewsPlusCorroboratingOutsideResearch:
            return "App News + Corroborating Outside Research"
        case .appNewsPlusMateriallyAdditiveOutsideResearch:
            return "App News + Materially Additive Outside Research"
        case .outsideResearchWithoutAppNewsBaseline:
            return "Outside Research Without App-News Baseline"
        case .boundedCoverageWithoutNewsOrOutsideResearch:
            return "Bounded Coverage"
        }
    }
}

private enum AnalystOutsideResearchContributionClassification: Sendable, Equatable {
    case noneRecorded
    case mainlyCorroboration
    case strongerConfirmation
    case materiallyAdditiveContext
    case disconfirmingOrQualifying
    case fallbackWithoutAppNewsBaseline

    var displayTitle: String {
        switch self {
        case .noneRecorded:
            return "No supplemental outside research recorded"
        case .mainlyCorroboration:
            return "Mainly corroborating"
        case .strongerConfirmation:
            return "Stronger confirmation"
        case .materiallyAdditiveContext:
            return "Materially additive context"
        case .disconfirmingOrQualifying:
            return "Disconfirming or qualifying"
        case .fallbackWithoutAppNewsBaseline:
            return "Fallback without app-news baseline"
        }
    }
}

private enum AnalystOutsideResearchRelation: Sendable, Equatable {
    case corroboration
    case strongerConfirmation
    case materiallyAdditiveContext
    case disconfirmingOrQualifying
    case fallbackWithoutAppNewsBaseline
}

private func classifyCoverage(
    appNewsCount: Int,
    outsideRelations: [AnalystOutsideResearchRelation],
    hasOutsideRefs: Bool
) -> AnalystResearchCoverageClassification {
    if appNewsCount > 0 {
        if hasOutsideRefs == false && outsideRelations.isEmpty {
            return .appNewsOnly
        }
        if outsideRelations.contains(.materiallyAdditiveContext)
            || outsideRelations.contains(.disconfirmingOrQualifying) {
            return .appNewsPlusMateriallyAdditiveOutsideResearch
        }
        return .appNewsPlusCorroboratingOutsideResearch
    }

    if hasOutsideRefs || outsideRelations.contains(.fallbackWithoutAppNewsBaseline) {
        return .outsideResearchWithoutAppNewsBaseline
    }

    return .boundedCoverageWithoutNewsOrOutsideResearch
}

private func classifyOutsideContribution(
    _ relations: [AnalystOutsideResearchRelation]
) -> AnalystOutsideResearchContributionClassification {
    if relations.contains(.disconfirmingOrQualifying) {
        return .disconfirmingOrQualifying
    }
    if relations.contains(.materiallyAdditiveContext) {
        return .materiallyAdditiveContext
    }
    if relations.contains(.strongerConfirmation) {
        return .strongerConfirmation
    }
    if relations.contains(.corroboration) {
        return .mainlyCorroboration
    }
    if relations.contains(.fallbackWithoutAppNewsBaseline) {
        return .fallbackWithoutAppNewsBaseline
    }
    return .noneRecorded
}

private func ownerTrustLabel(
    coverage: AnalystResearchCoverageClassification,
    outsideContribution: AnalystOutsideResearchContributionClassification
) -> String {
    switch coverage {
    case .appNewsOnly:
        return "Grounding: App-news baseline only"
    case .appNewsPlusCorroboratingOutsideResearch:
        return "Grounding: Outside research corroborated the baseline"
    case .appNewsPlusMateriallyAdditiveOutsideResearch:
        switch outsideContribution {
        case .disconfirmingOrQualifying:
            return "Grounding: Outside research materially qualified the read"
        default:
            return "Grounding: Outside research materially improved the read"
        }
    case .outsideResearchWithoutAppNewsBaseline:
        return "Grounding: Outside-only bounded fallback"
    case .boundedCoverageWithoutNewsOrOutsideResearch:
        return "Grounding: Bounded coverage only"
    }
}

private func ownerTrustSummary(
    coverage: AnalystResearchCoverageClassification,
    outsideContribution: AnalystOutsideResearchContributionClassification
) -> String {
    switch coverage {
    case .appNewsOnly:
        return "This recommendation is mainly grounded on app-owned news and bounded internal context, without recorded supplemental outside-source expansion."
    case .appNewsPlusCorroboratingOutsideResearch:
        return "Outside sources were used mainly to corroborate or strengthen the baseline rather than to change the core read."
    case .appNewsPlusMateriallyAdditiveOutsideResearch:
        switch outsideContribution {
        case .disconfirmingOrQualifying:
            return "At least one outside source materially qualified or challenged the baseline interpretation."
        case .materiallyAdditiveContext:
            return "Outside sources materially improved timing, context, or strategic/risk interpretation beyond the baseline."
        case .strongerConfirmation:
            return "Outside sources materially improved confidence through stronger primary confirmation."
        default:
            return "Outside sources materially improved the recommendation beyond app-news-only coverage."
        }
    case .outsideResearchWithoutAppNewsBaseline:
        return "The covered path relied on bounded outside-source fallback because a normal app-news baseline was not available."
    case .boundedCoverageWithoutNewsOrOutsideResearch:
        return "Only research coverage notes are available for this recommendation in the covered artifact path."
    }
}

private func ownerSourceConstraintSummary(
    openSuggestions: [AnalystSourceAccessSuggestionRecord]
) -> String? {
    guard openSuggestions.isEmpty == false else {
        return nil
    }

    let restrictedCount = openSuggestions.filter { $0.limitation == .restrictedByPolicy }.count
    let unsupportedCount = openSuggestions.filter { $0.limitation == .unsupportedByTooling }.count
    let inaccessibleCount = openSuggestions.filter { $0.limitation == .inaccessible }.count

    var parts: [String] = []
    if restrictedCount > 0 {
        parts.append("\(restrictedCount) restricted")
    }
    if unsupportedCount > 0 {
        parts.append("\(unsupportedCount) unsupported")
    }
    if inaccessibleCount > 0 {
        parts.append("\(inaccessibleCount) inaccessible")
    }

    if parts.isEmpty {
        return "Important sources are still missing or constrained in this covered recommendation path."
    }
    return "Important sources are still constrained (\(parts.joined(separator: ", "))); treat confidence as bounded until those gaps are resolved."
}

private func inferOutsideResearchRelations(
    webRefs: [AnalystEvidenceRef],
    memoEvidenceSummary: String
) -> [AnalystOutsideResearchRelation] {
    let refRelations = webRefs.compactMap { relation(from: $0.summary) }
    if refRelations.isEmpty == false {
        return refRelations
    }

    if let summaryRelation = relation(from: memoEvidenceSummary) {
        return [summaryRelation]
    }

    return []
}

private func relation(from text: String?) -> AnalystOutsideResearchRelation? {
    guard let text else {
        return nil
    }
    let normalized = text
        .lowercased()
        .replacingOccurrences(of: "\n", with: " ")

    if normalized.contains("qualifies or challenges the app-news baseline")
        || normalized.contains("disconfirming evidence")
        || normalized.contains("introduced disconfirming or qualifying context") {
        return .disconfirmingOrQualifying
    }
    if normalized.contains("adds incremental timing, background, or strategic/risk context")
        || normalized.contains("added incremental context") {
        return .materiallyAdditiveContext
    }
    if normalized.contains("stronger or more primary sourcing")
        || normalized.contains("provided stronger confirmation") {
        return .strongerConfirmation
    }
    if normalized.contains("mostly repeats the app-news fact pattern")
        || normalized.contains("compacted into corroboration")
        || normalized.contains("mostly repeated the same fact pattern") {
        return .corroboration
    }
    if normalized.contains("bounded fallback evidence anchor") {
        return .fallbackWithoutAppNewsBaseline
    }
    return nil
}

private func makeResearchTrustPostureSummary(
    coverage: AnalystResearchCoverageClassification,
    appNewsCount: Int,
    webRefCount: Int,
    openSuggestionCount: Int
) -> String {
    let sourceConstraintClause: String
    if openSuggestionCount > 0 {
        sourceConstraintClause = " There are \(openSuggestionCount) open source-gap item\(openSuggestionCount == 1 ? "" : "s") that may constrain completeness."
    } else {
        sourceConstraintClause = ""
    }

    switch coverage {
    case .appNewsOnly:
        return "This memo rests on the app-news baseline only, with no recorded supplemental outside research for added confirmation or context.\(sourceConstraintClause)"
    case .appNewsPlusCorroboratingOutsideResearch:
        return "This memo starts from \(appNewsCount) app-news evidence item\(appNewsCount == 1 ? "" : "s") and uses \(webRefCount) outside source\(webRefCount == 1 ? "" : "s") mainly to corroborate or strengthen that baseline.\(sourceConstraintClause)"
    case .appNewsPlusMateriallyAdditiveOutsideResearch:
        return "This memo starts from \(appNewsCount) app-news evidence item\(appNewsCount == 1 ? "" : "s") and uses \(webRefCount) outside source\(webRefCount == 1 ? "" : "s") to add material context, qualification, or sharper confirmation beyond the baseline.\(sourceConstraintClause)"
    case .outsideResearchWithoutAppNewsBaseline:
        return "This memo relied on bounded outside research because the usual app-news baseline was unavailable in the covered path.\(sourceConstraintClause)"
    case .boundedCoverageWithoutNewsOrOutsideResearch:
        return "This memo has only bounded coverage notes recorded in durable analyst artifacts, without a normal app-news baseline or supplemental outside web evidence.\(sourceConstraintClause)"
    }
}

private func outsideResearchSummary(
    contribution: AnalystOutsideResearchContributionClassification,
    outsideRelations: [AnalystOutsideResearchRelation]
) -> String? {
    guard outsideRelations.isEmpty == false else {
        return nil
    }

    let corroborationCount = outsideRelations.filter { $0 == .corroboration }.count
    let strongerCount = outsideRelations.filter { $0 == .strongerConfirmation }.count
    let additiveCount = outsideRelations.filter { $0 == .materiallyAdditiveContext }.count
    let disconfirmingCount = outsideRelations.filter { $0 == .disconfirmingOrQualifying }.count

    switch contribution {
    case .noneRecorded:
        return nil
    case .mainlyCorroboration:
        return "Outside research mostly restated the same event pattern, so it should be read as corroboration rather than as a second thesis."
    case .strongerConfirmation:
        var parts = ["Outside research mainly improved confirmation quality rather than changing the thesis."]
        if strongerCount > 0 {
            parts.append("\(strongerCount) source\(strongerCount == 1 ? "" : "s") provided stronger or more primary confirmation.")
        }
        if corroborationCount > 0 {
            parts.append("\(corroborationCount) additional overlapping source\(corroborationCount == 1 ? "" : "s") remained compacted as corroboration.")
        }
        return parts.joined(separator: " ")
    case .materiallyAdditiveContext:
        var parts = ["Outside research materially improved the answer by adding timing, background, or strategic/risk context beyond app news."]
        if additiveCount > 0 {
            parts.append("\(additiveCount) source\(additiveCount == 1 ? "" : "s") added that incremental context.")
        }
        if strongerCount > 0 {
            parts.append("\(strongerCount) also strengthened confirmation quality.")
        }
        return parts.joined(separator: " ")
    case .disconfirmingOrQualifying:
        var parts = ["At least one outside source qualified or challenged the baseline read, so the memo should be read as more than simple corroboration."]
        if disconfirmingCount > 0 {
            parts.append("\(disconfirmingCount) source\(disconfirmingCount == 1 ? "" : "s") introduced disconfirming or qualifying context.")
        }
        if additiveCount > 0 {
            parts.append("\(additiveCount) additional source\(additiveCount == 1 ? "" : "s") also added incremental context.")
        }
        return parts.joined(separator: " ")
    case .fallbackWithoutAppNewsBaseline:
        return "Outside research acted as a bounded fallback because no normal app-news baseline was available for this run."
    }
}

private func sourceConstraintLabel(
    openSuggestions: [AnalystSourceAccessSuggestionRecord],
    closedSuggestions: [AnalystSourceAccessSuggestionRecord]
) -> String {
    if openSuggestions.isEmpty == false {
        return "Important sources are still missing or constrained"
    }
    if closedSuggestions.isEmpty == false {
        return "No active source gaps remain"
    }
    return "No relevant source gaps recorded"
}

private func sourceConstraintSummary(
    openSuggestions: [AnalystSourceAccessSuggestionRecord],
    closedSuggestions: [AnalystSourceAccessSuggestionRecord]
) -> String? {
    if openSuggestions.isEmpty == false {
        let limitationCounts = Dictionary(grouping: openSuggestions, by: \.limitation)
            .map { limitation, grouped in
                "\(grouped.count) \(limitation.readableTitle)"
            }
            .sorted()
            .joined(separator: ", ")

        let examples = openSuggestions.prefix(2).map(sourceSuggestionReadableName(_:)).joined(separator: ", ")
        var summary = "Research completeness is still constrained by \(openSuggestions.count) open source-gap item\(openSuggestions.count == 1 ? "" : "s")"
        if limitationCounts.isEmpty == false {
            summary += " (\(limitationCounts))"
        }
        if examples.isEmpty == false {
            summary += ". Example: \(examples)."
        } else {
            summary += "."
        }
        return summary
    }

    if closedSuggestions.isEmpty == false {
        return "\(closedSuggestions.count) related source suggestion\(closedSuggestions.count == 1 ? " has" : "s have") already been closed through bounded PM review."
    }

    return nil
}

private func sourceSuggestionReadableName(_ suggestion: AnalystSourceAccessSuggestionRecord) -> String {
    let preferredValue = [
        suggestion.siteName,
        suggestion.requestedDomain,
        suggestion.requestedSource
    ]
        .compactMap { value -> String? in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  trimmed.isEmpty == false else {
                return nil
            }
            return trimmed
        }
        .first

    if let preferredValue {
        return "\(preferredValue) [\(suggestion.limitation.readableTitle)]"
    }
    return suggestion.limitation.readableTitle
}

private extension AnalystSourceAccessSuggestionLimitation {
    var readableTitle: String {
        rawValue.replacingOccurrences(of: "_", with: " ")
    }
}
