import Foundation
import Testing
@testable import TradingKit

@Test("Standing report list summaries stay compact while selected detail keeps full drill-down")
func standingReportSummaryPresentationDefersDetailConstruction() {
    let now = Date(timeIntervalSince1970: 1_775_190_550)
    let charter = AnalystCharter(
        charterId: "bench-sector-technology",
        analystId: "bench-sector-technology-analyst",
        title: "Technology Analyst",
        coverageScope: "Technology",
        strategyFamily: "standing sector bench",
        summary: "Technology standing coverage.",
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-1",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Technology memo",
        executiveSummary: "Executive summary from the memo.",
        currentView: "Current view",
        evidenceSummary: "Evidence summary",
        uncertaintySummary: "Uncertainty summary",
        recommendedNextStep: "Review the most actionable names.",
        confidence: 0.73,
        createdAt: now,
        updatedAt: now
    )
    let report = AnalystStandingReport(
        reportId: "report-1",
        analystId: charter.analystId,
        charterId: charter.charterId,
        scheduleId: "standing-report-bench-sector-technology",
        memoId: memo.memoId,
        title: "Technology weekly standing report",
        summary: "Fallback report summary",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly reporting window",
        portfolioScopeSummary: "Covered portfolio names: NVDA, MSFT.",
        coveredSymbols: ["NVDA", "MSFT"],
        headlineView: "AI infrastructure demand stayed resilient this week.",
        portfolioRelevanceSummary: "This matters for current long-side inclusion work.",
        openQuestions: ["Which name matters most before the next review?"],
        evidenceReferenceSummary: ["Portfolio Strategy Brief"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "important-items",
                kind: .importantItems,
                items: [
                    AnalystStandingReportItem(
                        itemId: "nvda",
                        headline: "Most actionable long-side inclusion candidate: NVDA",
                        detail: "Reserved detail for the selected report drill-down.",
                        symbol: "NVDA",
                        stance: .long,
                        conviction: 8
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "open-questions",
                kind: .followUp,
                items: [
                    AnalystStandingReportItem(
                        itemId: "question-1",
                        headline: "What would invalidate the thesis?",
                        detail: "Selected detail should keep this readable.",
                        stance: .neutral,
                        priority: 6
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    let summaries = makeStandingAnalystReportReviewSummaryPresentations(
        reports: [report],
        memos: [memo],
        charters: [charter]
    )

    #expect(summaries.count == 1)
    #expect(summaries.first?.reportId == report.reportId)
    #expect(summaries.first?.title == report.title)
    #expect(summaries.first?.executiveSummary == memo.executiveSummary)
    #expect(summaries.first?.headlineView == report.headlineView)
    #expect(summaries.first?.deliveryStatus == .pendingPMReview)

    let detail = makeStandingAnalystReportReviewPresentation(
        reportID: report.reportId,
        reports: [report],
        memos: [memo],
        charters: [charter]
    )

    #expect(detail?.reportId == report.reportId)
    #expect(detail?.detailSections.count == 2)
    #expect(detail?.detailSections.first?.items.count == 1)
    #expect(detail?.recommendedNextStep == memo.recommendedNextStep)
    #expect(detail?.portfolioRelevanceSummary == report.portfolioRelevanceSummary)
}

@Test("Standing report summaries keep newest-first order and pending status for PM Inbox list gating")
func standingReportSummaryPresentationKeepsNewestFirstOrder() {
    let now = Date(timeIntervalSince1970: 1_775_190_550)
    let older = AnalystStandingReport(
        reportId: "report-old",
        deliveryStatus: .reviewedByPM,
        analystId: "bench-sector-technology-analyst",
        charterId: "bench-sector-technology",
        scheduleId: "standing-report-bench-sector-technology",
        memoId: "memo-old",
        title: "Older report",
        summary: "Older summary",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Older window",
        portfolioScopeSummary: "Older scope",
        headlineView: "Older headline",
        portfolioRelevanceSummary: "Older relevance",
        deliveredToPMInboxAt: now.addingTimeInterval(-600),
        createdAt: now.addingTimeInterval(-600),
        updatedAt: now.addingTimeInterval(-600)
    )
    let newer = AnalystStandingReport(
        reportId: "report-new",
        analystId: "bench-sector-technology-analyst",
        charterId: "bench-sector-technology",
        scheduleId: "standing-report-bench-sector-technology",
        memoId: "memo-new",
        title: "Newer report",
        summary: "Newer summary",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Newer window",
        portfolioScopeSummary: "Newer scope",
        headlineView: "Newer headline",
        portfolioRelevanceSummary: "Newer relevance",
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    let summaries = makeStandingAnalystReportReviewSummaryPresentations(
        reports: [older, newer],
        memos: [],
        charters: []
    )

    #expect(summaries.map(\.reportId) == ["report-new", "report-old"])
    #expect(summaries.first?.deliveryStatus == .pendingPMReview)
    #expect(summaries.last?.deliveryStatus == .reviewedByPM)
}
