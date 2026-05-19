import Foundation
import Testing
@testable import TradingKit

@Test("Portfolio Intelligence calculates long, short, gross, and net exposure")
func portfolioIntelligenceCalculatesExposure() throws {
    let now = Date(timeIntervalSince1970: 1_765_000_000)
    let snapshot = StoreSnapshot(
        build: "test",
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "200000",
            cash: "10000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "NVDA", symbol: "NVDA", side: "long", qty: "10", marketValue: "2000"),
            PositionRow(id: "KSS", symbol: "KSS", side: "short", qty: "-50", marketValue: "-700")
        ],
        quotesBySymbol: [
            "NVDA": MarketQuote(symbol: "NVDA", lastPrice: 200, lastTradeTimestamp: "2026-04-29T16:30:00Z"),
            "KSS": MarketQuote(symbol: "KSS", lastPrice: 14, lastTradeTimestamp: "2026-04-29T16:30:00Z")
        ]
    )

    let summary = makePortfolioIntelligenceSnapshot(snapshot: snapshot, generatedAt: now).paper

    #expect(summary.availability == PortfolioEnvironmentAvailability.active)
    #expect(summary.exposure.longMarketValue == 2_000)
    #expect(summary.exposure.shortMarketValue == 700)
    #expect(summary.exposure.grossExposure == 2_700)
    #expect(summary.exposure.netExposure == 1_300)
    #expect(abs((summary.exposure.longWeight ?? 0) - 0.02) < 0.0001)
    #expect(abs((summary.exposure.shortWeight ?? 0) - 0.007) < 0.0001)
    #expect(abs((summary.exposure.cashWeight ?? 0) - 0.10) < 0.0001)

    let visual = summary.riskVisualSummary
    #expect(visual.longExposure == 2_000)
    #expect(visual.shortExposure == 700)
    #expect(visual.grossExposure == 2_700)
    #expect(visual.netExposure == 1_300)
    #expect(visual.exposureSegments.map(\.kind) == [.longExposure, .shortExposure, .cash])
    #expect(abs((visual.exposureSegments.first { $0.kind == .cash }?.portfolioWeight ?? 0) - 0.10) < 0.0001)
    #expect(visual.exposureSegments.allSatisfy { $0.compositionShare >= 0 })
}

@Test("Portfolio Intelligence calculates position weights and concentration")
func portfolioIntelligenceCalculatesWeightsAndConcentration() throws {
    let snapshot = StoreSnapshot(
        build: "test",
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "100000",
            cash: "5000",
            equity: "50000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "AAPL", symbol: "AAPL", side: "long", qty: "20", marketValue: "10000"),
            PositionRow(id: "MSFT", symbol: "MSFT", side: "long", qty: "10", marketValue: "5000"),
            PositionRow(id: "TSLA", symbol: "TSLA", side: "short", qty: "-10", marketValue: "-2500"),
            PositionRow(id: "KSS", symbol: "KSS", side: "short", qty: "-100", marketValue: "-1000")
        ]
    )

    let summary = makePortfolioIntelligenceSnapshot(snapshot: snapshot).paper

    #expect(summary.exposure.largestPositionSymbol == "AAPL")
    #expect(abs((summary.exposure.largestPositionWeight ?? 0) - 0.20) < 0.0001)
    #expect(abs((summary.exposure.topThreeConcentration ?? 0) - 0.35) < 0.0001)
    #expect(Array(summary.positions.map { $0.symbol }.prefix(3)) == ["AAPL", "MSFT", "TSLA"])

    let visual = summary.riskVisualSummary
    #expect(visual.concentration.largestPositionSymbol == "AAPL")
    #expect(abs((visual.concentration.largestPositionWeight ?? 0) - 0.20) < 0.0001)
    #expect(abs((visual.concentration.topThreeConcentration ?? 0) - 0.35) < 0.0001)
    #expect(visual.concentration.level == .elevated)
    #expect(visual.positionBars.first?.symbol == "AAPL")
    #expect(visual.positionBars.contains(where: { $0.symbol == "TSLA" && $0.side == .short }))
}

@Test("Portfolio Intelligence reports missing prices instead of fabricating")
func portfolioIntelligenceReportsMissingPrice() throws {
    let snapshot = StoreSnapshot(
        build: "test",
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "100000",
            cash: "10000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "NYCB", symbol: "NYCB", side: "long", qty: "100", marketValue: "?")
        ]
    )

    let summary = makePortfolioIntelligenceSnapshot(snapshot: snapshot).paper
    let position = try #require(summary.positions.first)

    #expect(position.latestPrice == nil)
    #expect(position.priceSource == .unavailable)
    #expect(position.dataQualitySummary == "Missing price")
    #expect(summary.dataQuality.missingPriceSymbols == ["NYCB"])
    #expect(summary.dataQuality.summary.contains("Missing prices: NYCB"))

    let visual = summary.riskVisualSummary
    let bar = try #require(visual.positionBars.first)
    #expect(bar.symbol == "NYCB")
    #expect(bar.hasUsablePrice == false)
    #expect(bar.relativeBarShare == 0)
    #expect(visual.dataQualityRibbon.status == .warning)
    #expect(visual.dataQualityRibbon.messages.contains(where: { $0.contains("Missing prices: NYCB") }))
}

@Test("Portfolio Intelligence separates active Paper from unavailable Live")
func portfolioIntelligenceSeparatesPaperAndLive() throws {
    let snapshot = StoreSnapshot(
        build: "test",
        isLive: false,
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "100000",
            cash: "100000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: []
    )

    let intelligence = makePortfolioIntelligenceSnapshot(snapshot: snapshot)

    #expect(intelligence.paper.availability == PortfolioEnvironmentAvailability.active)
    #expect(intelligence.paper.dataQuality.summary == "No positions are recorded in this environment.")
    #expect(intelligence.live.availability == .unavailable)
    #expect(intelligence.live.positions.isEmpty)
    #expect(intelligence.live.statusSummary.contains("No current live portfolio data loaded"))
    #expect(intelligence.paper.riskVisualSummary.availability == .active)
    #expect(intelligence.live.riskVisualSummary.availability == .unavailable)
    #expect(intelligence.live.riskVisualSummary.positionBars.isEmpty)
    #expect(intelligence.live.riskVisualSummary.dataQualityRibbon.status == .unavailable)
}

@Test("Portfolio Intelligence keeps advanced history-dependent metrics unavailable")
func portfolioIntelligenceDoesNotFabricateAdvancedMetrics() throws {
    let snapshot = StoreSnapshot(
        build: "test",
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "100000",
            cash: "50000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "NVDA", symbol: "NVDA", side: "long", qty: "10", marketValue: "2000")
        ]
    )

    let position = try #require(makePortfolioIntelligenceSnapshot(snapshot: snapshot).paper.positions.first)

    #expect(position.averageCost == nil)
    #expect(position.unrealizedPnL == nil)
    #expect(position.dayChange == nil)
    let paper = makePortfolioIntelligenceSnapshot(snapshot: snapshot).paper
    #expect(paper.advancedMetricsNote.contains("does not fabricate"))
    #expect(paper.advancedMetricReadiness.items.contains(where: {
        $0.metric == .sharpeRatio && $0.status == .unavailableMissingHistory
    }))
    #expect(paper.advancedMetricReadiness.items.contains(where: {
        $0.metric == .alpha && $0.status == .unavailableMissingBenchmark
    }))
    #expect(paper.advancedMetricReadiness.summary.contains("numeric values are unavailable"))

    let visual = paper.riskVisualSummary
    #expect(visual.advancedMetricReadinessPreview.contains(where: {
        $0.metric == .sharpeRatio && $0.status == .unavailableMissingHistory
    }))
    #expect(visual.advancedMetricReadinessPreview.contains(where: {
        $0.metric == .alpha && $0.status == .unavailableMissingBenchmark
    }))
}

@Test("Portfolio Intelligence PM summary includes shorts and advanced readiness without fabricated values")
func portfolioIntelligencePMSummaryIncludesShortsAndReadiness() throws {
    let now = Date(timeIntervalSince1970: 1_765_000_100)
    let snapshot = StoreSnapshot(
        build: "test",
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "200000",
            cash: "10000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "NVDA", symbol: "NVDA", side: "long", qty: "10", marketValue: "2000"),
            PositionRow(id: "KSS", symbol: "KSS", side: "short", qty: "-50", marketValue: "-700")
        ],
        quotesBySymbol: [
            "NVDA": MarketQuote(symbol: "NVDA", lastPrice: 200, lastTradeTimestamp: "2026-04-29T16:30:00Z"),
            "KSS": MarketQuote(symbol: "KSS", lastPrice: 14, lastTradeTimestamp: "2026-04-29T16:30:00Z")
        ]
    )

    let lines = makePMContextPortfolioIntelligenceSummaryLines(
        makePortfolioIntelligenceSnapshot(snapshot: snapshot, generatedAt: now)
    )

    #expect(lines.contains(where: { $0.contains("Paper Portfolio exposure") && $0.contains("short $700") }))
    #expect(lines.contains(where: { $0.contains("Paper Portfolio shorts") && $0.contains("KSS") }))
    #expect(lines.contains(where: { $0.contains("Sharpe ratio: unavailable_missing_history") }))
    #expect(lines.contains(where: { $0.contains("Alpha: unavailable_missing_benchmark") }))
    #expect(lines.joined(separator: "\n").contains("Sharpe ratio: 1") == false)
    #expect(lines.joined(separator: "\n").contains("Alpha: 1") == false)
}

@Test("Portfolio risk visual model keeps short positions visible")
func portfolioRiskVisualModelKeepsShortPositionsVisible() throws {
    let snapshot = StoreSnapshot(
        build: "test",
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "100000",
            cash: "15000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "NVDA", symbol: "NVDA", side: "long", qty: "20", marketValue: "4000"),
            PositionRow(id: "KSS", symbol: "KSS", side: "short", qty: "-100", marketValue: "-1500")
        ],
        quotesBySymbol: [
            "NVDA": MarketQuote(symbol: "NVDA", lastPrice: 200, lastTradeTimestamp: "2026-04-29T16:30:00Z"),
            "KSS": MarketQuote(symbol: "KSS", lastPrice: 15, lastTradeTimestamp: "2026-04-29T16:30:00Z")
        ]
    )

    let visual = makePortfolioIntelligenceSnapshot(snapshot: snapshot).paper.riskVisualSummary
    let shortBar = try #require(visual.positionBars.first { $0.symbol == "KSS" })

    #expect(shortBar.side == .short)
    #expect(shortBar.tone == .short)
    #expect(shortBar.marketValueSigned == -1_500)
    #expect(shortBar.marketValueAbsolute == 1_500)
    #expect(abs((shortBar.absoluteWeight ?? 0) - 0.015) < 0.0001)
    #expect(shortBar.relativeBarShare > 0)
}
