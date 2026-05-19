import Foundation

public enum BarTimeframe: String, Sendable, Codable, CaseIterable {
    case oneMinute = "1Min"
    case fiveMinutes = "5Min"
    case oneDay = "1Day"
}

public struct Bar: Sendable, Codable, Equatable {
    public let symbol: String
    public let timeframe: BarTimeframe
    public let timestamp: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double

    public init(
        symbol: String,
        timeframe: BarTimeframe,
        timestamp: Date,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

public enum ReplaySpeed: String, Sendable, Codable, CaseIterable {
    case fast
    case realtime
}

public enum ReplayFillPolicy: String, Sendable, Codable, CaseIterable {
    case nextOpenMarket = "next_open_market"
}

public struct ReplaySlippageBps: Sendable, Codable, Equatable {
    public let market: Int
    public let limit: Int

    public init(market: Int = 0, limit: Int = 0) {
        self.market = max(0, market)
        self.limit = max(0, limit)
    }
}

public struct ReplaySimulationConfig: Sendable, Codable, Equatable {
    public let simulateTrades: Bool
    public let allowTradingInReplay: Bool
    public let fillPolicy: ReplayFillPolicy
    public let slippageBps: ReplaySlippageBps

    public init(
        simulateTrades: Bool = false,
        allowTradingInReplay: Bool = false,
        fillPolicy: ReplayFillPolicy = .nextOpenMarket,
        slippageBps: ReplaySlippageBps = ReplaySlippageBps()
    ) {
        self.simulateTrades = simulateTrades
        self.allowTradingInReplay = allowTradingInReplay
        self.fillPolicy = fillPolicy
        self.slippageBps = slippageBps
    }

    public static let blocked = ReplaySimulationConfig()
}

public enum ReplayFeed: String, Sendable, Codable, CaseIterable {
    case iex
    case sip
    case test

    public init(marketDataFeed: MarketDataFeed) {
        switch marketDataFeed {
        case .stocksSIP:
            self = .sip
        case .stocksIEX, .test:
            self = .test
        }
    }

    public var alpacaHistoricalBarsValue: String {
        switch self {
        case .iex:
            return "iex"
        case .sip:
            return "sip"
        case .test:
            // Historical stocks bars endpoint accepts feed=iex|sip.
            return "iex"
        }
    }
}

public struct ReplayIngestRequest: Sendable, Codable, Equatable {
    public let symbols: [String]
    public let timeframe: BarTimeframe
    public let start: Date
    public let end: Date
    public let feed: ReplayFeed

    public init(
        symbols: [String],
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        feed: ReplayFeed
    ) {
        self.symbols = symbols
        self.timeframe = timeframe
        self.start = start
        self.end = end
        self.feed = feed
    }
}

public struct ReplayIngestResult: Sendable, Codable, Equatable {
    public let symbols: [String]
    public let timeframe: BarTimeframe
    public let start: Date
    public let end: Date
    public let feed: ReplayFeed
    public let barsIngested: Int

    public init(
        symbols: [String],
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        feed: ReplayFeed,
        barsIngested: Int
    ) {
        self.symbols = symbols
        self.timeframe = timeframe
        self.start = start
        self.end = end
        self.feed = feed
        self.barsIngested = barsIngested
    }
}

public struct ReplayRunRequest: Sendable, Codable, Equatable {
    public let proposalID: String
    public let symbols: [String]
    public let timeframe: BarTimeframe
    public let start: Date
    public let end: Date
    public let speed: ReplaySpeed
    public let autoIngest: Bool
    public let feed: ReplayFeed
    public let simulateTrades: Bool
    public let allowTradingInReplay: Bool
    public let fillPolicy: ReplayFillPolicy
    public let slippageBps: ReplaySlippageBps

    public init(
        proposalID: String,
        symbols: [String],
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        speed: ReplaySpeed,
        autoIngest: Bool,
        feed: ReplayFeed,
        simulateTrades: Bool = false,
        allowTradingInReplay: Bool = false,
        fillPolicy: ReplayFillPolicy = .nextOpenMarket,
        slippageBps: ReplaySlippageBps = ReplaySlippageBps()
    ) {
        self.proposalID = proposalID
        self.symbols = symbols
        self.timeframe = timeframe
        self.start = start
        self.end = end
        self.speed = speed
        self.autoIngest = autoIngest
        self.feed = feed
        self.simulateTrades = simulateTrades
        self.allowTradingInReplay = allowTradingInReplay
        self.fillPolicy = fillPolicy
        self.slippageBps = slippageBps
    }

    private enum CodingKeys: String, CodingKey {
        case proposalID = "proposalId"
        case symbols
        case timeframe
        case start
        case end
        case speed
        case autoIngest
        case feed
        case simulateTrades
        case allowTradingInReplay
        case fillPolicy
        case slippageBps
    }
}

public struct ReplayQuickRequest: Sendable, Codable, Equatable {
    public let proposalID: String
    public let symbols: [String]
    public let timeframe: BarTimeframe
    public let days: Int
    public let end: Date?
    public let speed: ReplaySpeed
    public let autoIngest: Bool
    public let feed: ReplayFeed
    public let simulateTrades: Bool
    public let allowTradingInReplay: Bool
    public let fillPolicy: ReplayFillPolicy
    public let slippageBps: ReplaySlippageBps

    public init(
        proposalID: String,
        symbols: [String],
        timeframe: BarTimeframe,
        days: Int,
        end: Date?,
        speed: ReplaySpeed,
        autoIngest: Bool,
        feed: ReplayFeed,
        simulateTrades: Bool = false,
        allowTradingInReplay: Bool = false,
        fillPolicy: ReplayFillPolicy = .nextOpenMarket,
        slippageBps: ReplaySlippageBps = ReplaySlippageBps()
    ) {
        self.proposalID = proposalID
        self.symbols = symbols
        self.timeframe = timeframe
        self.days = days
        self.end = end
        self.speed = speed
        self.autoIngest = autoIngest
        self.feed = feed
        self.simulateTrades = simulateTrades
        self.allowTradingInReplay = allowTradingInReplay
        self.fillPolicy = fillPolicy
        self.slippageBps = slippageBps
    }

    private enum CodingKeys: String, CodingKey {
        case proposalID = "proposalId"
        case symbols
        case timeframe
        case days
        case end
        case speed
        case autoIngest
        case feed
        case simulateTrades
        case allowTradingInReplay
        case fillPolicy
        case slippageBps
    }
}

public struct ReplayRunResult: Sendable, Codable, Equatable {
    public let runID: String
    public let proposalID: String
    public let barsProcessed: Int
    public let barsIngested: Int
    public let speed: ReplaySpeed
    public let simulateTrades: Bool
    public let fillPolicy: ReplayFillPolicy
    public let slippageBps: ReplaySlippageBps

    public init(
        runID: String,
        proposalID: String,
        barsProcessed: Int,
        barsIngested: Int,
        speed: ReplaySpeed,
        simulateTrades: Bool = false,
        fillPolicy: ReplayFillPolicy = .nextOpenMarket,
        slippageBps: ReplaySlippageBps = ReplaySlippageBps()
    ) {
        self.runID = runID
        self.proposalID = proposalID
        self.barsProcessed = barsProcessed
        self.barsIngested = barsIngested
        self.speed = speed
        self.simulateTrades = simulateTrades
        self.fillPolicy = fillPolicy
        self.slippageBps = slippageBps
    }
}

public enum ReplayRunType: String, Sendable, Codable, Equatable {
    case paper
    case replay
}

public struct ReplayDataSource: Sendable, Codable, Equatable {
    public let provider: String
    public let cache: String
    public let symbols: [String]
    public let timeframe: BarTimeframe
    public let start: Date
    public let end: Date
    public let feed: ReplayFeed

    public init(
        provider: String,
        cache: String,
        symbols: [String],
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        feed: ReplayFeed
    ) {
        self.provider = provider
        self.cache = cache
        self.symbols = symbols
        self.timeframe = timeframe
        self.start = start
        self.end = end
        self.feed = feed
    }
}

public struct ReplaySimulationMetadata: Sendable, Codable, Equatable {
    public let simulateTrades: Bool
    public let allowTradingInReplay: Bool
    public let fillPolicy: ReplayFillPolicy
    public let slippageBps: ReplaySlippageBps

    public init(
        simulateTrades: Bool,
        allowTradingInReplay: Bool,
        fillPolicy: ReplayFillPolicy,
        slippageBps: ReplaySlippageBps
    ) {
        self.simulateTrades = simulateTrades
        self.allowTradingInReplay = allowTradingInReplay
        self.fillPolicy = fillPolicy
        self.slippageBps = slippageBps
    }
}

public struct ReplayQuickWindow: Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum ReplayError: AgentControlError, Sendable, Equatable {
    case invalidSymbols
    case invalidDateRange
    case invalidDays
    case noBarsInCache
    case replayTradingNotEnabled
    case replaySimulationNotEnabled

    public var code: String {
        switch self {
        case .invalidSymbols:
            return "replay_invalid_symbols"
        case .invalidDateRange:
            return "replay_invalid_date_range"
        case .invalidDays:
            return "replay_invalid_days"
        case .noBarsInCache:
            return "replay_no_bars_in_cache"
        case .replayTradingNotEnabled:
            return "replay_trading_not_enabled"
        case .replaySimulationNotEnabled:
            return "replay_simulation_not_enabled"
        }
    }

    public var message: String {
        switch self {
        case .invalidSymbols:
            return "Replay requires at least one symbol."
        case .invalidDateRange:
            return "Replay start time must be earlier than end time."
        case .invalidDays:
            return "Replay quick requires days > 0."
        case .noBarsInCache:
            return "No bars are available in local cache for this replay window."
        case .replayTradingNotEnabled:
            return "Replay trading is disabled in bars-only MVP."
        case .replaySimulationNotEnabled:
            return "Replay trade simulation requires simulateTrades=true and allowTradingInReplay=true."
        }
    }
}

public enum ReplayWindow {
    public static func resolve(
        days: Int,
        end: Date?,
        now: @Sendable () -> Date
    ) throws -> ReplayQuickWindow {
        guard days > 0 else {
            throw ReplayError.invalidDays
        }
        let resolvedEnd = end ?? now()
        let start = resolvedEnd.addingTimeInterval(-Double(days) * 86_400)
        return ReplayQuickWindow(start: start, end: resolvedEnd)
    }
}
