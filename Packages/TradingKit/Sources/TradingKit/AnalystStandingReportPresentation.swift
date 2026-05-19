import Foundation

private func sanitizeStandingReportText(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return "" }

    let withoutScriptBodies = trimmed.replacingOccurrences(
        of: "(?is)<(script|style)[^>]*>.*?</\\1>",
        with: " ",
        options: .regularExpression
    )
    let withLineBreaks = withoutScriptBodies.replacingOccurrences(
        of: "(?i)<\\s*(br|/p|/div|/li|/tr|/h[1-6])\\s*/?>",
        with: "\n",
        options: .regularExpression
    )
    let withoutTags = withLineBreaks.replacingOccurrences(
        of: "(?is)<[^>]+>",
        with: " ",
        options: .regularExpression
    )

    let decodedEntities = withoutTags
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")

    let collapsedWhitespace = decodedEntities.replacingOccurrences(
        of: "[ \\t\\u{00A0}]+",
        with: " ",
        options: .regularExpression
    )
    let tightenedLineBreaks = collapsedWhitespace.replacingOccurrences(
        of: "[ \\t]*\\n[ \\t]*",
        with: "\n",
        options: .regularExpression
    )
    let collapsedSentences = tightenedLineBreaks.replacingOccurrences(
        of: " {2,}",
        with: " ",
        options: .regularExpression
    )
    let collapsedNewlines = collapsedSentences.replacingOccurrences(
        of: "\\n\\s*\\n+",
        with: "\n\n",
        options: .regularExpression
    )

    return collapsedNewlines.trimmingCharacters(in: .whitespacesAndNewlines)
}

public struct AnalystStandingReportReviewItemPresentation: Sendable, Equatable, Identifiable {
    public let id: String
    public let headline: String
    public let detail: String
    public let symbolSummary: String?
    public let stanceLabel: String
    public let scoreSummary: String?

    public init(
        id: String,
        headline: String,
        detail: String,
        symbolSummary: String?,
        stanceLabel: String,
        scoreSummary: String?
    ) {
        self.id = id
        self.headline = headline
        self.detail = detail
        self.symbolSummary = symbolSummary
        self.stanceLabel = stanceLabel
        self.scoreSummary = scoreSummary
    }
}

public struct AnalystStandingReportReviewSectionPresentation: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: AnalystStandingReportSectionKind
    public let title: String
    public let summary: String?
    public let items: [AnalystStandingReportReviewItemPresentation]

    public init(
        id: String,
        kind: AnalystStandingReportSectionKind,
        title: String,
        summary: String?,
        items: [AnalystStandingReportReviewItemPresentation]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.items = items
    }
}

public struct AnalystStandingReportReviewPresentation: Sendable, Equatable, Identifiable {
    public let reportId: String
    public let reportKindLabel: String
    public let analystTitle: String
    public let cadenceSummary: String
    public let deliverySummary: String
    public let title: String
    public let executiveSummary: String
    public let reportingWindowSummary: String
    public let portfolioScopeSummary: String
    public let headlineView: String
    public let portfolioRelevanceSummary: String
    public let coveredSymbolsSummary: String
    public let openQuestions: [String]
    public let evidenceReferenceSummary: [String]
    public let skillUsageSummary: [String]
    public let detailSections: [AnalystStandingReportReviewSectionPresentation]
    public let recommendedNextStep: String
    public let deliveredAt: Date

    public var id: String { reportId }

    public init(
        reportId: String,
        reportKindLabel: String,
        analystTitle: String,
        cadenceSummary: String,
        deliverySummary: String,
        title: String,
        executiveSummary: String,
        reportingWindowSummary: String,
        portfolioScopeSummary: String,
        headlineView: String,
        portfolioRelevanceSummary: String,
        coveredSymbolsSummary: String,
        openQuestions: [String],
        evidenceReferenceSummary: [String],
        skillUsageSummary: [String],
        detailSections: [AnalystStandingReportReviewSectionPresentation],
        recommendedNextStep: String,
        deliveredAt: Date
    ) {
        self.reportId = reportId
        self.reportKindLabel = reportKindLabel
        self.analystTitle = analystTitle
        self.cadenceSummary = cadenceSummary
        self.deliverySummary = deliverySummary
        self.title = title
        self.executiveSummary = executiveSummary
        self.reportingWindowSummary = reportingWindowSummary
        self.portfolioScopeSummary = portfolioScopeSummary
        self.headlineView = headlineView
        self.portfolioRelevanceSummary = portfolioRelevanceSummary
        self.coveredSymbolsSummary = coveredSymbolsSummary
        self.openQuestions = openQuestions
        self.evidenceReferenceSummary = evidenceReferenceSummary
        self.skillUsageSummary = skillUsageSummary
        self.detailSections = detailSections
        self.recommendedNextStep = recommendedNextStep
        self.deliveredAt = deliveredAt
    }
}

public struct AnalystStandingReportReviewSummaryPresentation: Sendable, Equatable, Identifiable {
    public let reportId: String
    public let reportKindLabel: String
    public let analystTitle: String
    public let cadenceSummary: String
    public let deliveryStatus: AnalystStandingReportDeliveryStatus
    public let deliverySummary: String
    public let title: String
    public let executiveSummary: String
    public let reportingWindowSummary: String
    public let portfolioScopeSummary: String
    public let headlineView: String
    public let deliveredAt: Date

    public var id: String { reportId }

    public init(
        reportId: String,
        reportKindLabel: String,
        analystTitle: String,
        cadenceSummary: String,
        deliveryStatus: AnalystStandingReportDeliveryStatus,
        deliverySummary: String,
        title: String,
        executiveSummary: String,
        reportingWindowSummary: String,
        portfolioScopeSummary: String,
        headlineView: String,
        deliveredAt: Date
    ) {
        self.reportId = reportId
        self.reportKindLabel = reportKindLabel
        self.analystTitle = analystTitle
        self.cadenceSummary = cadenceSummary
        self.deliveryStatus = deliveryStatus
        self.deliverySummary = deliverySummary
        self.title = title
        self.executiveSummary = executiveSummary
        self.reportingWindowSummary = reportingWindowSummary
        self.portfolioScopeSummary = portfolioScopeSummary
        self.headlineView = headlineView
        self.deliveredAt = deliveredAt
    }
}

public func standingAnalystReportCadenceSummary(intervalSec: Int) -> String {
    let normalized = max(1, intervalSec)
    if normalized % standingAnalystReportDefaultIntervalSec == 0 {
        let weeks = normalized / standingAnalystReportDefaultIntervalSec
        return weeks == 1 ? "Weekly" : "Every \(weeks) weeks"
    }
    if normalized % 86_400 == 0 {
        let days = normalized / 86_400
        return days == 1 ? "Daily" : "Every \(days) days"
    }
    let hours = max(1, normalized / 3_600)
    return hours == 1 ? "Hourly" : "Every \(hours) hours"
}

private func standingReportScoreSummary(item: AnalystStandingReportItem) -> String? {
    var parts: [String] = []
    if let conviction = item.conviction {
        parts.append("Conviction \(conviction)/10")
    }
    if let priority = item.priority {
        parts.append("Priority \(priority)/10")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " • ")
}

private func standingReportSymbolSummary(item: AnalystStandingReportItem) -> String? {
    guard let symbol = item.symbol?.trimmingCharacters(in: .whitespacesAndNewlines), !symbol.isEmpty else {
        return nil
    }
    return symbol
}

private func standingReportSkillUsageSummaryLines(_ values: [AgentSkillUsageSummary]) -> [String] {
    values
        .prefix(8)
        .map { value in
            let title = sanitizeStandingReportText(value.skillTitle)
            let usage = value.usage.displayTitle
            let requirement = value.requirement.displayTitle
            let summary = sanitizeStandingReportText(value.usageSummary)
            return "\(title) (\(requirement), \(usage)): \(summary)"
        }
}

private func makeStandingAnalystReportReviewSummaryPresentation(
    report: AnalystStandingReport,
    memo: AnalystMemo?,
    charter: AnalystCharter?
) -> AnalystStandingReportReviewSummaryPresentation {
    AnalystStandingReportReviewSummaryPresentation(
        reportId: report.reportId,
        reportKindLabel: "Standing Recurring Report",
        analystTitle: sanitizeStandingReportText(charter?.title ?? report.analystId),
        cadenceSummary: standingAnalystReportCadenceSummary(intervalSec: report.cadenceIntervalSec),
        deliveryStatus: report.deliveryStatus,
        deliverySummary: report.deliveryStatus.displayTitle,
        title: sanitizeStandingReportText(report.title),
        executiveSummary: sanitizeStandingReportText(memo?.executiveSummary ?? report.summary),
        reportingWindowSummary: sanitizeStandingReportText(report.reportingWindowSummary),
        portfolioScopeSummary: sanitizeStandingReportText(report.portfolioScopeSummary),
        headlineView: sanitizeStandingReportText(report.headlineView),
        deliveredAt: report.deliveredToPMInboxAt
    )
}

private func makeStandingAnalystReportReviewPresentation(
    report: AnalystStandingReport,
    memo: AnalystMemo?,
    charter: AnalystCharter?
) -> AnalystStandingReportReviewPresentation {
    let summary = makeStandingAnalystReportReviewSummaryPresentation(
        report: report,
        memo: memo,
        charter: charter
    )
    let detailSections = report.sections.map { section in
        AnalystStandingReportReviewSectionPresentation(
            id: section.sectionId,
            kind: section.kind,
            title: sanitizeStandingReportText(section.title),
            summary: section.summary.map(sanitizeStandingReportText),
            items: section.items.map { item in
                AnalystStandingReportReviewItemPresentation(
                    id: item.itemId,
                    headline: sanitizeStandingReportText(item.headline),
                    detail: sanitizeStandingReportText(item.detail),
                    symbolSummary: standingReportSymbolSummary(item: item),
                    stanceLabel: item.stance.displayTitle,
                    scoreSummary: standingReportScoreSummary(item: item)
                )
            }
        )
    }
    let coveredSymbolsSummary: String
    if report.coveredSymbols.isEmpty {
        coveredSymbolsSummary = "No covered portfolio names were attached to this standing report."
    } else {
        coveredSymbolsSummary = report.coveredSymbols.joined(separator: ", ")
    }
    return AnalystStandingReportReviewPresentation(
        reportId: summary.reportId,
        reportKindLabel: summary.reportKindLabel,
        analystTitle: summary.analystTitle,
        cadenceSummary: summary.cadenceSummary,
        deliverySummary: summary.deliverySummary,
        title: summary.title,
        executiveSummary: summary.executiveSummary,
        reportingWindowSummary: summary.reportingWindowSummary,
        portfolioScopeSummary: summary.portfolioScopeSummary,
        headlineView: summary.headlineView,
        portfolioRelevanceSummary: sanitizeStandingReportText(report.portfolioRelevanceSummary),
        coveredSymbolsSummary: coveredSymbolsSummary,
        openQuestions: report.openQuestions.map(sanitizeStandingReportText),
        evidenceReferenceSummary: report.evidenceReferenceSummary.map(sanitizeStandingReportText),
        skillUsageSummary: standingReportSkillUsageSummaryLines(report.skillUsageSummaries),
        detailSections: detailSections,
        recommendedNextStep: sanitizeStandingReportText(
            memo?.recommendedNextStep ?? "Review this standing report in PM Inbox."
        ),
        deliveredAt: summary.deliveredAt
    )
}

public func makeStandingAnalystReportReviewSummaryPresentations(
    reports: [AnalystStandingReport],
    memos: [AnalystMemo],
    charters: [AnalystCharter]
) -> [AnalystStandingReportReviewSummaryPresentation] {
    let memosByID = Dictionary(uniqueKeysWithValues: memos.map { ($0.memoId, $0) })
    let chartersByID = Dictionary(uniqueKeysWithValues: charters.map { ($0.charterId, $0) })

    return reports.sorted { lhs, rhs in
        if lhs.deliveredToPMInboxAt == rhs.deliveredToPMInboxAt {
            return lhs.reportId < rhs.reportId
        }
        return lhs.deliveredToPMInboxAt > rhs.deliveredToPMInboxAt
    }.map { report in
        makeStandingAnalystReportReviewSummaryPresentation(
            report: report,
            memo: memosByID[report.memoId],
            charter: chartersByID[report.charterId]
        )
    }
}

public func makeStandingAnalystReportReviewPresentations(
    reports: [AnalystStandingReport],
    memos: [AnalystMemo],
    charters: [AnalystCharter]
) -> [AnalystStandingReportReviewPresentation] {
    let memosByID = Dictionary(uniqueKeysWithValues: memos.map { ($0.memoId, $0) })
    let chartersByID = Dictionary(uniqueKeysWithValues: charters.map { ($0.charterId, $0) })

    return reports.sorted { lhs, rhs in
        if lhs.deliveredToPMInboxAt == rhs.deliveredToPMInboxAt {
            return lhs.reportId < rhs.reportId
        }
        return lhs.deliveredToPMInboxAt > rhs.deliveredToPMInboxAt
    }.map { report in
        makeStandingAnalystReportReviewPresentation(
            report: report,
            memo: memosByID[report.memoId],
            charter: chartersByID[report.charterId]
        )
    }
}

public func makeStandingAnalystReportReviewPresentation(
    reportID: String,
    reports: [AnalystStandingReport],
    memos: [AnalystMemo],
    charters: [AnalystCharter]
) -> AnalystStandingReportReviewPresentation? {
    let memosByID = Dictionary(uniqueKeysWithValues: memos.map { ($0.memoId, $0) })
    let chartersByID = Dictionary(uniqueKeysWithValues: charters.map { ($0.charterId, $0) })
    guard let report = reports.first(where: { $0.reportId == reportID }) else {
        return nil
    }
    return makeStandingAnalystReportReviewPresentation(
        report: report,
        memo: memosByID[report.memoId],
        charter: chartersByID[report.charterId]
    )
}

public func makePendingStandingAnalystReportReviewPresentations(
    reports: [AnalystStandingReport],
    memos: [AnalystMemo],
    charters: [AnalystCharter]
) -> [AnalystStandingReportReviewPresentation] {
    makeStandingAnalystReportReviewPresentations(
        reports: reports.filter { $0.deliveryStatus == .pendingPMReview },
        memos: memos,
        charters: charters
    )
}
