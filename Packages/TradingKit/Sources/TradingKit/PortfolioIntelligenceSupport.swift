import Foundation

public enum PortfolioEnvironmentKind: String, Sendable, Equatable, Codable {
    case paper
    case live

    public var displayTitle: String {
        switch self {
        case .paper:
            return "Paper Portfolio"
        case .live:
            return "Live Portfolio"
        }
    }
}

public enum PortfolioEnvironmentAvailability: String, Sendable, Equatable, Codable {
    case active
    case unavailable
}

public enum PortfolioPositionSide: String, Sendable, Equatable, Codable {
    case long
    case short
}

public enum PortfolioPositionPriceSource: String, Sendable, Equatable, Codable {
    case marketData = "market_data"
    case brokerPosition = "broker_position"
    case unavailable

    public var displayTitle: String {
        switch self {
        case .marketData:
            return "Market data"
        case .brokerPosition:
            return "Broker position"
        case .unavailable:
            return "Unavailable"
        }
    }
}

public struct PortfolioIntelligenceSnapshot: Sendable, Equatable {
    public let generatedAt: Date
    public let paper: PortfolioEnvironmentSummary
    public let live: PortfolioEnvironmentSummary

    public init(
        generatedAt: Date,
        paper: PortfolioEnvironmentSummary,
        live: PortfolioEnvironmentSummary
    ) {
        self.generatedAt = generatedAt
        self.paper = paper
        self.live = live
    }

    public static func empty(generatedAt: Date = Date()) -> PortfolioIntelligenceSnapshot {
        PortfolioIntelligenceSnapshot(
            generatedAt: generatedAt,
            paper: .unavailable(
                environment: .paper,
                generatedAt: generatedAt,
                reason: "No current paper portfolio data loaded yet."
            ),
            live: .unavailable(
                environment: .live,
                generatedAt: generatedAt,
                reason: "No current live portfolio data loaded. Live starts disarmed and is not inferred from Paper."
            )
        )
    }
}

public enum PortfolioAdvancedMetric: String, Sendable, Equatable, Codable, CaseIterable {
    case alpha
    case beta
    case sharpeRatio = "sharpe_ratio"
    case sortinoRatio = "sortino_ratio"
    case volatility
    case drawdown
    case trackingError = "tracking_error"
    case timeWeightedReturn = "time_weighted_return"
    case attribution

    public var displayTitle: String {
        switch self {
        case .alpha:
            return "Alpha"
        case .beta:
            return "Beta"
        case .sharpeRatio:
            return "Sharpe ratio"
        case .sortinoRatio:
            return "Sortino ratio"
        case .volatility:
            return "Volatility"
        case .drawdown:
            return "Drawdown"
        case .trackingError:
            return "Tracking error"
        case .timeWeightedReturn:
            return "Time-weighted return"
        case .attribution:
            return "Attribution"
        }
    }
}

public enum PortfolioMetricAvailabilityStatus: String, Sendable, Equatable, Codable {
    case available
    case unavailableMissingHistory = "unavailable_missing_history"
    case unavailableMissingBenchmark = "unavailable_missing_benchmark"
    case unavailableMissingRiskFreeRate = "unavailable_missing_risk_free_rate"
    case unavailableInsufficientObservations = "unavailable_insufficient_observations"
    case notYetImplemented = "not_yet_implemented"
}

public struct PortfolioAdvancedMetricReadinessItem: Sendable, Equatable, Identifiable, Codable {
    public var id: String { metric.rawValue }

    public let metric: PortfolioAdvancedMetric
    public let status: PortfolioMetricAvailabilityStatus
    public let reason: String

    public init(
        metric: PortfolioAdvancedMetric,
        status: PortfolioMetricAvailabilityStatus,
        reason: String
    ) {
        self.metric = metric
        self.status = status
        self.reason = reason
    }
}

public struct PortfolioAdvancedMetricReadiness: Sendable, Equatable, Codable {
    public let summary: String
    public let items: [PortfolioAdvancedMetricReadinessItem]

    public init(summary: String, items: [PortfolioAdvancedMetricReadinessItem]) {
        self.summary = summary
        self.items = items
    }

    public static let needsHistory = PortfolioAdvancedMetricReadiness(
        summary: "Advanced risk/performance metrics need portfolio return history, benchmark/risk-free assumptions, enough observations, and consistent valuation timestamps; numeric values are unavailable until those inputs exist.",
        items: [
            PortfolioAdvancedMetricReadinessItem(
                metric: .sharpeRatio,
                status: .unavailableMissingHistory,
                reason: "Needs a portfolio return series, a risk-free-rate assumption, and enough observations."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .alpha,
                status: .unavailableMissingBenchmark,
                reason: "Needs portfolio returns, benchmark returns, and a selected benchmark window."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .drawdown,
                status: .unavailableMissingHistory,
                reason: "Needs portfolio value history across a defined time window."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .attribution,
                status: .notYetImplemented,
                reason: "Needs return history, position contribution history, and attribution grouping before a numeric result is safe."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .beta,
                status: .unavailableMissingBenchmark,
                reason: "Needs portfolio returns and benchmark returns over the same observation window."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .sortinoRatio,
                status: .unavailableMissingHistory,
                reason: "Needs downside-return history and a target/risk-free return assumption."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .volatility,
                status: .unavailableMissingHistory,
                reason: "Needs a clean portfolio return series with enough observations."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .trackingError,
                status: .unavailableMissingBenchmark,
                reason: "Needs portfolio and benchmark excess-return history."
            ),
            PortfolioAdvancedMetricReadinessItem(
                metric: .timeWeightedReturn,
                status: .unavailableMissingHistory,
                reason: "Needs portfolio valuation history and cash-flow-aware return periods."
            )
        ]
    )
}

public struct PortfolioEnvironmentSummary: Sendable, Equatable, Identifiable {
    public var id: String { environment.rawValue }

    public let environment: PortfolioEnvironmentKind
    public let availability: PortfolioEnvironmentAvailability
    public let generatedAt: Date
    public let statusSummary: String
    public let account: PortfolioAccountMetric?
    public let exposure: PortfolioExposureSummary
    public let dataQuality: PortfolioDataQualitySummary
    public let orderActivity: PortfolioOrderActivitySummary
    public let positions: [PortfolioPositionMetric]
    public let advancedMetricReadiness: PortfolioAdvancedMetricReadiness
    public let advancedMetricsNote: String

    public init(
        environment: PortfolioEnvironmentKind,
        availability: PortfolioEnvironmentAvailability,
        generatedAt: Date,
        statusSummary: String,
        account: PortfolioAccountMetric?,
        exposure: PortfolioExposureSummary,
        dataQuality: PortfolioDataQualitySummary,
        orderActivity: PortfolioOrderActivitySummary,
        positions: [PortfolioPositionMetric],
        advancedMetricReadiness: PortfolioAdvancedMetricReadiness = .needsHistory,
        advancedMetricsNote: String
    ) {
        self.environment = environment
        self.availability = availability
        self.generatedAt = generatedAt
        self.statusSummary = statusSummary
        self.account = account
        self.exposure = exposure
        self.dataQuality = dataQuality
        self.orderActivity = orderActivity
        self.positions = positions
        self.advancedMetricReadiness = advancedMetricReadiness
        self.advancedMetricsNote = advancedMetricsNote
    }

    public static func unavailable(
        environment: PortfolioEnvironmentKind,
        generatedAt: Date,
        reason: String
    ) -> PortfolioEnvironmentSummary {
        PortfolioEnvironmentSummary(
            environment: environment,
            availability: .unavailable,
            generatedAt: generatedAt,
            statusSummary: reason,
            account: nil,
            exposure: .empty,
            dataQuality: PortfolioDataQualitySummary(
                accountLoaded: false,
                positionCount: 0,
                pricedPositionCount: 0,
                missingPriceSymbols: [],
                stalePriceSymbols: [],
                summary: reason
            ),
            orderActivity: .empty,
            positions: [],
            advancedMetricReadiness: .needsHistory,
            advancedMetricsNote: "No return, risk, attribution, or drawdown metrics are computed without current environment data and sufficient history."
        )
    }
}

public struct PortfolioAccountMetric: Sendable, Equatable {
    public let accountId: String
    public let status: String
    public let equity: Double?
    public let cash: Double?
    public let buyingPower: Double?

    public init(
        accountId: String,
        status: String,
        equity: Double?,
        cash: Double?,
        buyingPower: Double?
    ) {
        self.accountId = accountId
        self.status = status
        self.equity = equity
        self.cash = cash
        self.buyingPower = buyingPower
    }
}

public struct PortfolioPositionMetric: Sendable, Equatable, Identifiable {
    public var id: String { symbol }

    public let symbol: String
    public let side: PortfolioPositionSide
    public let quantity: Double?
    public let latestPrice: Double?
    public let priceSource: PortfolioPositionPriceSource
    public let priceObservedAt: Date?
    public let marketValueSigned: Double?
    public let marketValueAbsolute: Double?
    public let averageCost: Double?
    public let unrealizedPnL: Double?
    public let dayChange: Double?
    public let weight: Double?
    public let absoluteWeight: Double?
    public let dataQualitySummary: String

    public init(
        symbol: String,
        side: PortfolioPositionSide,
        quantity: Double?,
        latestPrice: Double?,
        priceSource: PortfolioPositionPriceSource,
        priceObservedAt: Date?,
        marketValueSigned: Double?,
        marketValueAbsolute: Double?,
        averageCost: Double?,
        unrealizedPnL: Double?,
        dayChange: Double?,
        weight: Double?,
        absoluteWeight: Double?,
        dataQualitySummary: String
    ) {
        self.symbol = symbol
        self.side = side
        self.quantity = quantity
        self.latestPrice = latestPrice
        self.priceSource = priceSource
        self.priceObservedAt = priceObservedAt
        self.marketValueSigned = marketValueSigned
        self.marketValueAbsolute = marketValueAbsolute
        self.averageCost = averageCost
        self.unrealizedPnL = unrealizedPnL
        self.dayChange = dayChange
        self.weight = weight
        self.absoluteWeight = absoluteWeight
        self.dataQualitySummary = dataQualitySummary
    }
}

public struct PortfolioExposureSummary: Sendable, Equatable {
    public let longMarketValue: Double
    public let shortMarketValue: Double
    public let grossExposure: Double
    public let netExposure: Double
    public let longWeight: Double?
    public let shortWeight: Double?
    public let cashWeight: Double?
    public let largestPositionSymbol: String?
    public let largestPositionWeight: Double?
    public let topThreeConcentration: Double?

    public init(
        longMarketValue: Double,
        shortMarketValue: Double,
        grossExposure: Double,
        netExposure: Double,
        longWeight: Double?,
        shortWeight: Double?,
        cashWeight: Double?,
        largestPositionSymbol: String?,
        largestPositionWeight: Double?,
        topThreeConcentration: Double?
    ) {
        self.longMarketValue = longMarketValue
        self.shortMarketValue = shortMarketValue
        self.grossExposure = grossExposure
        self.netExposure = netExposure
        self.longWeight = longWeight
        self.shortWeight = shortWeight
        self.cashWeight = cashWeight
        self.largestPositionSymbol = largestPositionSymbol
        self.largestPositionWeight = largestPositionWeight
        self.topThreeConcentration = topThreeConcentration
    }

    public static let empty = PortfolioExposureSummary(
        longMarketValue: 0,
        shortMarketValue: 0,
        grossExposure: 0,
        netExposure: 0,
        longWeight: nil,
        shortWeight: nil,
        cashWeight: nil,
        largestPositionSymbol: nil,
        largestPositionWeight: nil,
        topThreeConcentration: nil
    )
}

public struct PortfolioDataQualitySummary: Sendable, Equatable {
    public let accountLoaded: Bool
    public let positionCount: Int
    public let pricedPositionCount: Int
    public let missingPriceSymbols: [String]
    public let stalePriceSymbols: [String]
    public let summary: String

    public init(
        accountLoaded: Bool,
        positionCount: Int,
        pricedPositionCount: Int,
        missingPriceSymbols: [String],
        stalePriceSymbols: [String],
        summary: String
    ) {
        self.accountLoaded = accountLoaded
        self.positionCount = positionCount
        self.pricedPositionCount = pricedPositionCount
        self.missingPriceSymbols = missingPriceSymbols
        self.stalePriceSymbols = stalePriceSymbols
        self.summary = summary
    }
}

public struct PortfolioOrderActivitySummary: Sendable, Equatable {
    public let openOrderCount: Int
    public let recentFilledOrderCount: Int
    public let latestOpenOrderSummary: String?
    public let lifecycleSummary: String?
    public let lifecycleDetail: String?

    public init(
        openOrderCount: Int,
        recentFilledOrderCount: Int,
        latestOpenOrderSummary: String?,
        lifecycleSummary: String?,
        lifecycleDetail: String?
    ) {
        self.openOrderCount = openOrderCount
        self.recentFilledOrderCount = recentFilledOrderCount
        self.latestOpenOrderSummary = latestOpenOrderSummary
        self.lifecycleSummary = lifecycleSummary
        self.lifecycleDetail = lifecycleDetail
    }

    public static let empty = PortfolioOrderActivitySummary(
        openOrderCount: 0,
        recentFilledOrderCount: 0,
        latestOpenOrderSummary: nil,
        lifecycleSummary: nil,
        lifecycleDetail: nil
    )
}

public enum PortfolioRiskVisualTone: String, Sendable, Equatable, Codable {
    case long
    case short
    case cash
    case neutral
    case warning
    case unavailable
}

public enum PortfolioExposureSegmentKind: String, Sendable, Equatable, Codable {
    case longExposure = "long_exposure"
    case shortExposure = "short_exposure"
    case cash

    public var displayTitle: String {
        switch self {
        case .longExposure:
            return "Long"
        case .shortExposure:
            return "Short"
        case .cash:
            return "Cash"
        }
    }
}

public struct PortfolioExposureVisualSegment: Sendable, Equatable, Identifiable, Codable {
    public var id: String { kind.rawValue }

    public let kind: PortfolioExposureSegmentKind
    public let amount: Double
    public let portfolioWeight: Double?
    public let compositionShare: Double
    public let tone: PortfolioRiskVisualTone

    public init(
        kind: PortfolioExposureSegmentKind,
        amount: Double,
        portfolioWeight: Double?,
        compositionShare: Double,
        tone: PortfolioRiskVisualTone
    ) {
        self.kind = kind
        self.amount = amount
        self.portfolioWeight = portfolioWeight
        self.compositionShare = compositionShare
        self.tone = tone
    }
}

public enum PortfolioConcentrationLevel: String, Sendable, Equatable, Codable {
    case unavailable
    case moderate
    case elevated
    case high

    public var displayTitle: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .moderate:
            return "Moderate"
        case .elevated:
            return "Elevated"
        case .high:
            return "High"
        }
    }
}

public struct PortfolioConcentrationVisualSummary: Sendable, Equatable, Codable {
    public let largestPositionSymbol: String?
    public let largestPositionWeight: Double?
    public let topThreeConcentration: Double?
    public let level: PortfolioConcentrationLevel
    public let summary: String

    public init(
        largestPositionSymbol: String?,
        largestPositionWeight: Double?,
        topThreeConcentration: Double?,
        level: PortfolioConcentrationLevel,
        summary: String
    ) {
        self.largestPositionSymbol = largestPositionSymbol
        self.largestPositionWeight = largestPositionWeight
        self.topThreeConcentration = topThreeConcentration
        self.level = level
        self.summary = summary
    }
}

public struct PortfolioPositionWeightVisual: Sendable, Equatable, Identifiable, Codable {
    public var id: String { symbol }

    public let symbol: String
    public let side: PortfolioPositionSide
    public let quantity: Double?
    public let latestPrice: Double?
    public let priceSource: PortfolioPositionPriceSource
    public let marketValueSigned: Double?
    public let marketValueAbsolute: Double?
    public let signedWeight: Double?
    public let absoluteWeight: Double?
    public let relativeBarShare: Double
    public let hasUsablePrice: Bool
    public let dataQualitySummary: String
    public let tone: PortfolioRiskVisualTone

    public init(
        symbol: String,
        side: PortfolioPositionSide,
        quantity: Double?,
        latestPrice: Double?,
        priceSource: PortfolioPositionPriceSource,
        marketValueSigned: Double?,
        marketValueAbsolute: Double?,
        signedWeight: Double?,
        absoluteWeight: Double?,
        relativeBarShare: Double,
        hasUsablePrice: Bool,
        dataQualitySummary: String,
        tone: PortfolioRiskVisualTone
    ) {
        self.symbol = symbol
        self.side = side
        self.quantity = quantity
        self.latestPrice = latestPrice
        self.priceSource = priceSource
        self.marketValueSigned = marketValueSigned
        self.marketValueAbsolute = marketValueAbsolute
        self.signedWeight = signedWeight
        self.absoluteWeight = absoluteWeight
        self.relativeBarShare = relativeBarShare
        self.hasUsablePrice = hasUsablePrice
        self.dataQualitySummary = dataQualitySummary
        self.tone = tone
    }
}

public enum PortfolioDataQualityRibbonStatus: String, Sendable, Equatable, Codable {
    case clean
    case warning
    case unavailable
}

public struct PortfolioDataQualityRibbon: Sendable, Equatable, Codable {
    public let status: PortfolioDataQualityRibbonStatus
    public let title: String
    public let messages: [String]

    public init(status: PortfolioDataQualityRibbonStatus, title: String, messages: [String]) {
        self.status = status
        self.title = title
        self.messages = messages
    }
}

public struct PortfolioRiskVisualSummary: Sendable, Equatable, Codable {
    public let availability: PortfolioEnvironmentAvailability
    public let longExposure: Double
    public let shortExposure: Double
    public let grossExposure: Double
    public let netExposure: Double
    public let cashWeight: Double?
    public let exposureSegments: [PortfolioExposureVisualSegment]
    public let concentration: PortfolioConcentrationVisualSummary
    public let positionBars: [PortfolioPositionWeightVisual]
    public let dataQualityRibbon: PortfolioDataQualityRibbon
    public let advancedMetricReadinessPreview: [PortfolioAdvancedMetricReadinessItem]

    public init(
        availability: PortfolioEnvironmentAvailability,
        longExposure: Double,
        shortExposure: Double,
        grossExposure: Double,
        netExposure: Double,
        cashWeight: Double?,
        exposureSegments: [PortfolioExposureVisualSegment],
        concentration: PortfolioConcentrationVisualSummary,
        positionBars: [PortfolioPositionWeightVisual],
        dataQualityRibbon: PortfolioDataQualityRibbon,
        advancedMetricReadinessPreview: [PortfolioAdvancedMetricReadinessItem]
    ) {
        self.availability = availability
        self.longExposure = longExposure
        self.shortExposure = shortExposure
        self.grossExposure = grossExposure
        self.netExposure = netExposure
        self.cashWeight = cashWeight
        self.exposureSegments = exposureSegments
        self.concentration = concentration
        self.positionBars = positionBars
        self.dataQualityRibbon = dataQualityRibbon
        self.advancedMetricReadinessPreview = advancedMetricReadinessPreview
    }
}

public extension PortfolioEnvironmentSummary {
    var riskVisualSummary: PortfolioRiskVisualSummary {
        makePortfolioRiskVisualSummary(self)
    }
}

public func makePortfolioIntelligenceSnapshot(
    snapshot: StoreSnapshot,
    paperEstablishmentExecution: PMPaperPortfolioExecutionLifecycleState? = nil,
    generatedAt: Date = Date(),
    stalePriceInterval: TimeInterval = 15 * 60
) -> PortfolioIntelligenceSnapshot {
    let activeEnvironment: PortfolioEnvironmentKind = snapshot.isLive ? .live : .paper
    let activeSummary = makePortfolioEnvironmentSummary(
        environment: activeEnvironment,
        snapshot: snapshot,
        paperEstablishmentExecution: activeEnvironment == .paper ? paperEstablishmentExecution : nil,
        generatedAt: generatedAt,
        stalePriceInterval: stalePriceInterval
    )

    let inactivePaper = PortfolioEnvironmentSummary.unavailable(
        environment: .paper,
        generatedAt: generatedAt,
        reason: "No current paper portfolio data loaded while the app is showing Live environment truth."
    )
    let inactiveLive = PortfolioEnvironmentSummary.unavailable(
        environment: .live,
        generatedAt: generatedAt,
        reason: "No current live portfolio data loaded. Live starts disarmed and is not inferred from Paper."
    )

    return PortfolioIntelligenceSnapshot(
        generatedAt: generatedAt,
        paper: activeEnvironment == .paper ? activeSummary : inactivePaper,
        live: activeEnvironment == .live ? activeSummary : inactiveLive
    )
}

public func makePortfolioRiskVisualSummary(_ summary: PortfolioEnvironmentSummary) -> PortfolioRiskVisualSummary {
    let cashAmount = max(summary.account?.cash ?? 0, 0)
    let compositionDenominator = summary.exposure.longMarketValue
        + summary.exposure.shortMarketValue
        + cashAmount
    let exposureSegments: [PortfolioExposureVisualSegment] = [
        PortfolioExposureVisualSegment(
            kind: .longExposure,
            amount: summary.exposure.longMarketValue,
            portfolioWeight: summary.exposure.longWeight,
            compositionShare: portfolioCompositionShare(
                amount: summary.exposure.longMarketValue,
                denominator: compositionDenominator
            ),
            tone: .long
        ),
        PortfolioExposureVisualSegment(
            kind: .shortExposure,
            amount: summary.exposure.shortMarketValue,
            portfolioWeight: summary.exposure.shortWeight,
            compositionShare: portfolioCompositionShare(
                amount: summary.exposure.shortMarketValue,
                denominator: compositionDenominator
            ),
            tone: .short
        ),
        PortfolioExposureVisualSegment(
            kind: .cash,
            amount: cashAmount,
            portfolioWeight: summary.exposure.cashWeight,
            compositionShare: portfolioCompositionShare(
                amount: cashAmount,
                denominator: compositionDenominator
            ),
            tone: .cash
        )
    ]

    let maxPositionWeight = summary.positions
        .compactMap(\.absoluteWeight)
        .max() ?? 0
    let positionBars = summary.positions.map { position in
        let absoluteWeight = position.absoluteWeight
        let barShare: Double
        if maxPositionWeight > 0, let absoluteWeight {
            barShare = min(max(absoluteWeight / maxPositionWeight, 0), 1)
        } else {
            barShare = 0
        }
        return PortfolioPositionWeightVisual(
            symbol: position.symbol,
            side: position.side,
            quantity: position.quantity,
            latestPrice: position.latestPrice,
            priceSource: position.priceSource,
            marketValueSigned: position.marketValueSigned,
            marketValueAbsolute: position.marketValueAbsolute,
            signedWeight: position.weight,
            absoluteWeight: position.absoluteWeight,
            relativeBarShare: barShare,
            hasUsablePrice: position.latestPrice != nil,
            dataQualitySummary: position.dataQualitySummary,
            tone: position.side == .short ? .short : .long
        )
    }

    return PortfolioRiskVisualSummary(
        availability: summary.availability,
        longExposure: summary.exposure.longMarketValue,
        shortExposure: summary.exposure.shortMarketValue,
        grossExposure: summary.exposure.grossExposure,
        netExposure: summary.exposure.netExposure,
        cashWeight: summary.exposure.cashWeight,
        exposureSegments: exposureSegments,
        concentration: portfolioConcentrationVisualSummary(summary.exposure),
        positionBars: positionBars,
        dataQualityRibbon: portfolioDataQualityRibbon(summary),
        advancedMetricReadinessPreview: Array(summary.advancedMetricReadiness.items.prefix(4))
    )
}

private func makePortfolioEnvironmentSummary(
    environment: PortfolioEnvironmentKind,
    snapshot: StoreSnapshot,
    paperEstablishmentExecution: PMPaperPortfolioExecutionLifecycleState?,
    generatedAt: Date,
    stalePriceInterval: TimeInterval
) -> PortfolioEnvironmentSummary {
    let account = snapshot.accountSummary.map { summary in
        PortfolioAccountMetric(
            accountId: summary.id,
            status: summary.status,
            equity: portfolioIntelligenceDouble(summary.equity),
            cash: portfolioIntelligenceDouble(summary.cash),
            buyingPower: portfolioIntelligenceDouble(summary.buyingPower)
        )
    }
    let equity = account?.equity
    let cash = account?.cash

    let rawPositionMetrics = snapshot.positions.map { row in
        makePortfolioPositionMetric(
            row: row,
            snapshot: snapshot,
            equity: equity,
            generatedAt: generatedAt,
            stalePriceInterval: stalePriceInterval
        )
    }
    let denominator = portfolioIntelligenceWeightDenominator(
        equity: equity,
        positions: rawPositionMetrics
    )
    let positionMetrics = rawPositionMetrics.map { metric in
        guard let denominator, denominator > 0,
              let signed = metric.marketValueSigned,
              let absolute = metric.marketValueAbsolute else {
            return metric
        }
        return PortfolioPositionMetric(
            symbol: metric.symbol,
            side: metric.side,
            quantity: metric.quantity,
            latestPrice: metric.latestPrice,
            priceSource: metric.priceSource,
            priceObservedAt: metric.priceObservedAt,
            marketValueSigned: metric.marketValueSigned,
            marketValueAbsolute: metric.marketValueAbsolute,
            averageCost: metric.averageCost,
            unrealizedPnL: metric.unrealizedPnL,
            dayChange: metric.dayChange,
            weight: signed / denominator,
            absoluteWeight: absolute / denominator,
            dataQualitySummary: metric.dataQualitySummary
        )
    }
    .sorted { lhs, rhs in
        let lhsWeight = lhs.absoluteWeight ?? -1
        let rhsWeight = rhs.absoluteWeight ?? -1
        if lhsWeight == rhsWeight {
            return lhs.symbol < rhs.symbol
        }
        return lhsWeight > rhsWeight
    }

    let longMarketValue = positionMetrics.reduce(0.0) { partial, metric in
        guard metric.side == .long else { return partial }
        return partial + (metric.marketValueAbsolute ?? 0)
    }
    let shortMarketValue = positionMetrics.reduce(0.0) { partial, metric in
        guard metric.side == .short else { return partial }
        return partial + (metric.marketValueAbsolute ?? 0)
    }
    let grossExposure = longMarketValue + shortMarketValue
    let netExposure = longMarketValue - shortMarketValue
    let largest = positionMetrics.first(where: { ($0.absoluteWeight ?? 0) > 0 })
    let topThreeConcentration = positionMetrics
        .prefix(3)
        .compactMap(\.absoluteWeight)
        .reduce(0, +)
    let exposure = PortfolioExposureSummary(
        longMarketValue: longMarketValue,
        shortMarketValue: shortMarketValue,
        grossExposure: grossExposure,
        netExposure: netExposure,
        longWeight: denominator.flatMap { $0 > 0 ? longMarketValue / $0 : nil },
        shortWeight: denominator.flatMap { $0 > 0 ? shortMarketValue / $0 : nil },
        cashWeight: {
            guard let cash, let denominator, denominator > 0 else { return nil }
            return cash / denominator
        }(),
        largestPositionSymbol: largest?.symbol,
        largestPositionWeight: largest?.absoluteWeight,
        topThreeConcentration: positionMetrics.isEmpty ? nil : topThreeConcentration
    )

    let missingPriceSymbols = positionMetrics
        .filter { $0.latestPrice == nil }
        .map(\.symbol)
        .sorted()
    let stalePriceSymbols = positionMetrics
        .filter { metric in
            guard metric.priceSource == .marketData,
                  let observedAt = metric.priceObservedAt else {
                return false
            }
            return generatedAt.timeIntervalSince(observedAt) > stalePriceInterval
        }
        .map(\.symbol)
        .sorted()
    let dataQuality = PortfolioDataQualitySummary(
        accountLoaded: account != nil,
        positionCount: positionMetrics.count,
        pricedPositionCount: positionMetrics.filter { $0.latestPrice != nil }.count,
        missingPriceSymbols: missingPriceSymbols,
        stalePriceSymbols: stalePriceSymbols,
        summary: portfolioDataQualitySummary(
            accountLoaded: account != nil,
            positionCount: positionMetrics.count,
            missingPriceSymbols: missingPriceSymbols,
            stalePriceSymbols: stalePriceSymbols
        )
    )
    let orderActivity = PortfolioOrderActivitySummary(
        openOrderCount: snapshot.openOrders.count,
        recentFilledOrderCount: snapshot.ordersByID.values.filter { $0.status.lowercased() == "filled" }.count,
        latestOpenOrderSummary: latestOpenOrderSummary(snapshot.openOrders),
        lifecycleSummary: paperEstablishmentExecution?.summary,
        lifecycleDetail: paperEstablishmentExecution?.detail
    )

    return PortfolioEnvironmentSummary(
        environment: environment,
        availability: .active,
        generatedAt: generatedAt,
        statusSummary: portfolioEnvironmentStatusSummary(
            account: account,
            positions: positionMetrics,
            dataQuality: dataQuality
        ),
        account: account,
        exposure: exposure,
        dataQuality: dataQuality,
        orderActivity: orderActivity,
        positions: positionMetrics,
        advancedMetricReadiness: .needsHistory,
        advancedMetricsNote: "Advanced return/risk metrics such as TWR, Sharpe, drawdown, beta, volatility, and attribution need sufficient historical portfolio value and benchmark history; this panel does not fabricate them."
    )
}

private func makePortfolioPositionMetric(
    row: PositionRow,
    snapshot: StoreSnapshot,
    equity: Double?,
    generatedAt: Date,
    stalePriceInterval: TimeInterval
) -> PortfolioPositionMetric {
    let symbol = row.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let quantity = portfolioIntelligenceDouble(row.qty)
    let side: PortfolioPositionSide = row.isShort ? .short : .long
    let quote = snapshot.quotesBySymbol[symbol] ?? snapshot.optionQuotesBySymbol[symbol]
    let resolvedMarketValue = portfolioResolvedMarketValue(row: row, quantity: quantity, quote: quote)
    let marketDataPrice = resolvePortfolioWatchLiveValue(from: quote)
    let brokerPrice = brokerPositionPrice(marketValue: resolvedMarketValue.absolute, quantity: quantity)
    let latestPrice = marketDataPrice?.price ?? brokerPrice
    let source: PortfolioPositionPriceSource = {
        if marketDataPrice != nil {
            return .marketData
        }
        if brokerPrice != nil {
            return .brokerPosition
        }
        return .unavailable
    }()
    let observedAt = marketDataPrice?.observedAt
    let dataQuality: String = {
        guard latestPrice != nil else {
            return "Missing price"
        }
        if source == .marketData,
           let observedAt,
           generatedAt.timeIntervalSince(observedAt) > stalePriceInterval {
            return "Stale market data"
        }
        return source == .marketData ? "Fresh market data" : "Broker position price"
    }()

    return PortfolioPositionMetric(
        symbol: symbol,
        side: side,
        quantity: quantity,
        latestPrice: latestPrice,
        priceSource: source,
        priceObservedAt: observedAt,
        marketValueSigned: resolvedMarketValue.signed,
        marketValueAbsolute: resolvedMarketValue.absolute,
        averageCost: nil,
        unrealizedPnL: nil,
        dayChange: nil,
        weight: equity.flatMap { denominator in
            guard denominator > 0, let signed = resolvedMarketValue.signed else { return nil }
            return signed / denominator
        },
        absoluteWeight: equity.flatMap { denominator in
            guard denominator > 0, let absolute = resolvedMarketValue.absolute else { return nil }
            return absolute / denominator
        },
        dataQualitySummary: dataQuality
    )
}

private func portfolioResolvedMarketValue(
    row: PositionRow,
    quantity: Double?,
    quote: MarketQuote?
) -> (signed: Double?, absolute: Double?) {
    if let raw = portfolioIntelligenceDouble(row.marketValue) {
        let absolute = abs(raw)
        let signed = row.isShort ? -absolute : absolute
        return (signed, absolute)
    }

    guard let quantity, quantity != 0,
          let price = resolvePortfolioWatchLiveValue(from: quote)?.price,
          price > 0 else {
        return (nil, nil)
    }
    let absolute = abs(quantity) * price
    let signed = row.isShort ? -absolute : absolute
    return (signed, absolute)
}

private func brokerPositionPrice(marketValue: Double?, quantity: Double?) -> Double? {
    guard let marketValue, marketValue > 0,
          let quantity, quantity != 0 else {
        return nil
    }
    return marketValue / abs(quantity)
}

private func portfolioIntelligenceWeightDenominator(
    equity: Double?,
    positions: [PortfolioPositionMetric]
) -> Double? {
    if let equity, equity > 0 {
        return equity
    }
    let gross = positions.compactMap(\.marketValueAbsolute).reduce(0, +)
    return gross > 0 ? gross : nil
}

private func portfolioDataQualitySummary(
    accountLoaded: Bool,
    positionCount: Int,
    missingPriceSymbols: [String],
    stalePriceSymbols: [String]
) -> String {
    guard accountLoaded else {
        return "Account data is not loaded for this environment."
    }
    guard positionCount > 0 else {
        return "No positions are recorded in this environment."
    }
    if missingPriceSymbols.isEmpty == false {
        return "Missing prices: \(missingPriceSymbols.joined(separator: ", "))."
    }
    if stalePriceSymbols.isEmpty == false {
        return "Stale prices: \(stalePriceSymbols.joined(separator: ", "))."
    }
    return "All recorded positions have usable price truth."
}

private func portfolioEnvironmentStatusSummary(
    account: PortfolioAccountMetric?,
    positions: [PortfolioPositionMetric],
    dataQuality: PortfolioDataQualitySummary
) -> String {
    guard let account else {
        return dataQuality.summary
    }
    if positions.isEmpty {
        return "\(account.status) account loaded with no recorded positions."
    }
    return "\(account.status) account loaded with \(positions.count) position\(positions.count == 1 ? "" : "s"). \(dataQuality.summary)"
}

private func latestOpenOrderSummary(_ openOrders: [OrderRow]) -> String? {
    guard let order = openOrders.sorted(by: { lhs, rhs in
        if lhs.symbol == rhs.symbol {
            return lhs.id < rhs.id
        }
        return lhs.symbol < rhs.symbol
    }).first else {
        return nil
    }
    return "\(order.symbol) \(order.side.uppercased()) \(order.qty) \(order.orderType ?? "order") \(order.status)"
}

private func portfolioCompositionShare(amount: Double, denominator: Double) -> Double {
    guard denominator > 0, amount > 0 else {
        return 0
    }
    return min(max(amount / denominator, 0), 1)
}

private func portfolioConcentrationVisualSummary(
    _ exposure: PortfolioExposureSummary
) -> PortfolioConcentrationVisualSummary {
    guard let largestWeight = exposure.largestPositionWeight,
          let topThree = exposure.topThreeConcentration else {
        return PortfolioConcentrationVisualSummary(
            largestPositionSymbol: exposure.largestPositionSymbol,
            largestPositionWeight: exposure.largestPositionWeight,
            topThreeConcentration: exposure.topThreeConcentration,
            level: .unavailable,
            summary: "Concentration is unavailable until position weights are available."
        )
    }

    let level: PortfolioConcentrationLevel
    if largestWeight >= 0.25 || topThree >= 0.60 {
        level = .high
    } else if largestWeight >= 0.15 || topThree >= 0.40 {
        level = .elevated
    } else {
        level = .moderate
    }

    let largestText = exposure.largestPositionSymbol.map { "\($0) is the largest position." }
        ?? "Largest position is unavailable."
    return PortfolioConcentrationVisualSummary(
        largestPositionSymbol: exposure.largestPositionSymbol,
        largestPositionWeight: exposure.largestPositionWeight,
        topThreeConcentration: exposure.topThreeConcentration,
        level: level,
        summary: "\(largestText) Top-three concentration is \(portfolioIntelligencePercentText(topThree))."
    )
}

private func portfolioDataQualityRibbon(_ summary: PortfolioEnvironmentSummary) -> PortfolioDataQualityRibbon {
    if summary.availability == .unavailable {
        return PortfolioDataQualityRibbon(
            status: .unavailable,
            title: "Portfolio data unavailable",
            messages: [summary.statusSummary]
        )
    }

    var messages: [String] = []
    if summary.dataQuality.accountLoaded == false {
        messages.append("Account data is not loaded.")
    }
    if summary.dataQuality.missingPriceSymbols.isEmpty == false {
        messages.append("Missing prices: \(summary.dataQuality.missingPriceSymbols.joined(separator: ", ")).")
    }
    if summary.dataQuality.stalePriceSymbols.isEmpty == false {
        messages.append("Stale prices: \(summary.dataQuality.stalePriceSymbols.joined(separator: ", ")).")
    }
    if let lifecycleSummary = summary.orderActivity.lifecycleSummary {
        messages.append(lifecycleSummary)
    }
    if messages.isEmpty {
        messages.append(summary.dataQuality.summary)
    }

    let status: PortfolioDataQualityRibbonStatus = {
        if summary.dataQuality.accountLoaded == false ||
            summary.dataQuality.missingPriceSymbols.isEmpty == false ||
            summary.dataQuality.stalePriceSymbols.isEmpty == false {
            return .warning
        }
        return .clean
    }()

    return PortfolioDataQualityRibbon(
        status: status,
        title: status == .clean ? "Data quality clean" : "Data quality needs attention",
        messages: messages
    )
}

private func portfolioIntelligencePercentText(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 1
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private func portfolioIntelligenceDouble(_ raw: String?) -> Double? {
    guard var cleaned = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
          cleaned.isEmpty == false,
          cleaned != "?" else {
        return nil
    }
    var negative = false
    if cleaned.hasPrefix("("), cleaned.hasSuffix(")") {
        negative = true
        cleaned.removeFirst()
        cleaned.removeLast()
    }
    cleaned = cleaned
        .replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: "%", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value = Double(cleaned) else {
        return nil
    }
    return negative ? -value : value
}
