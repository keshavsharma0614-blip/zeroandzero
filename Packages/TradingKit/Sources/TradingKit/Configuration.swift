public enum Environment: String, CaseIterable, Codable, Sendable {
    case paper
    case live
}

public struct Configuration: Equatable, Codable, Sendable {
    public var environment: Environment
    public var marketDataFeed: MarketDataFeed
    public var refreshPositionsOnFill: Bool

    public init(
        environment: Environment = .paper,
        marketDataFeed: MarketDataFeed = .stocksIEX,
        refreshPositionsOnFill: Bool = true
    ) {
        self.environment = environment
        self.marketDataFeed = marketDataFeed
        self.refreshPositionsOnFill = refreshPositionsOnFill
    }
}
