import Foundation

public enum MarketDataFeed: String, CaseIterable, Codable, Equatable, Sendable {
    case test
    case stocksIEX
    case stocksSIP

    public var displayName: String {
        switch self {
        case .test:
            return "Test"
        case .stocksIEX:
            return "Stocks IEX"
        case .stocksSIP:
            return "Stocks SIP"
        }
    }

    public var feedCode: String {
        switch self {
        case .test:
            return "test"
        case .stocksIEX:
            return "iex"
        case .stocksSIP:
            return "sip"
        }
    }

    public var websocketPath: String {
        websocketURL.path
    }

    public var diagnosticWebSocketEndpoint: String {
        guard let host = websocketURL.host else {
            return websocketPath
        }
        return "\(websocketURL.scheme ?? "wss")://\(host)\(websocketURL.path)"
    }

    var websocketURL: URL {
        switch self {
        case .test:
            return URL(string: "wss://stream.data.alpaca.markets/v2/test")!
        case .stocksIEX:
            return URL(string: "wss://stream.data.alpaca.markets/v2/iex")!
        case .stocksSIP:
            return URL(string: "wss://stream.data.alpaca.markets/v2/sip")!
        }
    }
}

public enum MarketSymbolClassifier {
    public static func instrumentType(for symbol: String) -> InstrumentType {
        let normalized = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalized.isEmpty else {
            return .equity
        }
        return OptionContractSymbol.parse(normalized) == nil ? .equity : .option
    }
}

public enum MarketDataConnectionState: String, Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case authenticated
    case subscribed
}

public struct MarketDataStreamRuntimeSnapshot: Equatable, Sendable {
    public var environment: Environment
    public var feed: MarketDataFeed
    public var endpoint: String
    public var state: MarketDataConnectionState
    public var isRunning: Bool
    public var hasSocketTask: Bool
    public var desiredSubscriptions: MarketDataSubscriptionSet
    public var activeSubscriptions: MarketDataSubscriptionSet
    public var lastStateChangedAt: Date?
    public var lastSuccessMessage: String?
    public var lastErrorCode: Int?
    public var lastErrorMessage: String?
    public var lastSubscriptionAcknowledgedAt: Date?
    public var lastDiagnostic: String?
    public var reconnectRequestCount: Int
    public var lastReconnectReason: String?

    public init(
        environment: Environment,
        feed: MarketDataFeed,
        endpoint: String,
        state: MarketDataConnectionState,
        isRunning: Bool,
        hasSocketTask: Bool,
        desiredSubscriptions: MarketDataSubscriptionSet,
        activeSubscriptions: MarketDataSubscriptionSet,
        lastStateChangedAt: Date? = nil,
        lastSuccessMessage: String? = nil,
        lastErrorCode: Int? = nil,
        lastErrorMessage: String? = nil,
        lastSubscriptionAcknowledgedAt: Date? = nil,
        lastDiagnostic: String? = nil,
        reconnectRequestCount: Int = 0,
        lastReconnectReason: String? = nil
    ) {
        self.environment = environment
        self.feed = feed
        self.endpoint = endpoint
        self.state = state
        self.isRunning = isRunning
        self.hasSocketTask = hasSocketTask
        self.desiredSubscriptions = desiredSubscriptions
        self.activeSubscriptions = activeSubscriptions
        self.lastStateChangedAt = lastStateChangedAt
        self.lastSuccessMessage = lastSuccessMessage
        self.lastErrorCode = lastErrorCode
        self.lastErrorMessage = lastErrorMessage
        self.lastSubscriptionAcknowledgedAt = lastSubscriptionAcknowledgedAt
        self.lastDiagnostic = lastDiagnostic
        self.reconnectRequestCount = reconnectRequestCount
        self.lastReconnectReason = lastReconnectReason
    }
}

public struct MarketDataSubscriptionSet: Equatable, Sendable {
    public var quotes: Set<String>
    public var trades: Set<String>
    public var bars: Set<String>
    public var optionQuotes: Set<String>
    public var optionTrades: Set<String>
    public var optionBars: Set<String>

    public init(
        quotes: Set<String> = [],
        trades: Set<String> = [],
        bars: Set<String> = [],
        optionQuotes: Set<String> = [],
        optionTrades: Set<String> = [],
        optionBars: Set<String> = []
    ) {
        self.quotes = Self.normalized(quotes)
        self.trades = Self.normalized(trades)
        self.bars = Self.normalized(bars)
        self.optionQuotes = Self.normalized(optionQuotes)
        self.optionTrades = Self.normalized(optionTrades)
        self.optionBars = Self.normalized(optionBars)
    }

    public static let empty = MarketDataSubscriptionSet()

    public var isEmpty: Bool {
        quotes.isEmpty &&
            trades.isEmpty &&
            bars.isEmpty &&
            optionQuotes.isEmpty &&
            optionTrades.isEmpty &&
            optionBars.isEmpty
    }

    public func diff(from current: MarketDataSubscriptionSet) -> MarketDataSubscriptionDelta {
        MarketDataSubscriptionDelta(
            subscribeQuotes: quotes.subtracting(current.quotes),
            unsubscribeQuotes: current.quotes.subtracting(quotes),
            subscribeTrades: trades.subtracting(current.trades),
            unsubscribeTrades: current.trades.subtracting(trades),
            subscribeBars: bars.subtracting(current.bars),
            unsubscribeBars: current.bars.subtracting(bars),
            subscribeOptionQuotes: optionQuotes.subtracting(current.optionQuotes),
            unsubscribeOptionQuotes: current.optionQuotes.subtracting(optionQuotes),
            subscribeOptionTrades: optionTrades.subtracting(current.optionTrades),
            unsubscribeOptionTrades: current.optionTrades.subtracting(optionTrades),
            subscribeOptionBars: optionBars.subtracting(current.optionBars),
            unsubscribeOptionBars: current.optionBars.subtracting(optionBars)
        )
    }

    public static func normalized(_ symbols: [String]) -> Set<String> {
        normalized(Set(symbols))
    }

    public static func normalized(_ symbols: Set<String>) -> Set<String> {
        Set(symbols.compactMap { symbol in
            let trimmed = symbol
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return trimmed.isEmpty ? nil : trimmed
        })
    }
}

public struct MarketDataSubscriptionDelta: Equatable, Sendable {
    public let subscribeQuotes: Set<String>
    public let unsubscribeQuotes: Set<String>
    public let subscribeTrades: Set<String>
    public let unsubscribeTrades: Set<String>
    public let subscribeBars: Set<String>
    public let unsubscribeBars: Set<String>
    public let subscribeOptionQuotes: Set<String>
    public let unsubscribeOptionQuotes: Set<String>
    public let subscribeOptionTrades: Set<String>
    public let unsubscribeOptionTrades: Set<String>
    public let subscribeOptionBars: Set<String>
    public let unsubscribeOptionBars: Set<String>

    public init(
        subscribeQuotes: Set<String> = [],
        unsubscribeQuotes: Set<String> = [],
        subscribeTrades: Set<String> = [],
        unsubscribeTrades: Set<String> = [],
        subscribeBars: Set<String> = [],
        unsubscribeBars: Set<String> = [],
        subscribeOptionQuotes: Set<String> = [],
        unsubscribeOptionQuotes: Set<String> = [],
        subscribeOptionTrades: Set<String> = [],
        unsubscribeOptionTrades: Set<String> = [],
        subscribeOptionBars: Set<String> = [],
        unsubscribeOptionBars: Set<String> = []
    ) {
        self.subscribeQuotes = MarketDataSubscriptionSet.normalized(subscribeQuotes)
        self.unsubscribeQuotes = MarketDataSubscriptionSet.normalized(unsubscribeQuotes)
        self.subscribeTrades = MarketDataSubscriptionSet.normalized(subscribeTrades)
        self.unsubscribeTrades = MarketDataSubscriptionSet.normalized(unsubscribeTrades)
        self.subscribeBars = MarketDataSubscriptionSet.normalized(subscribeBars)
        self.unsubscribeBars = MarketDataSubscriptionSet.normalized(unsubscribeBars)
        self.subscribeOptionQuotes = MarketDataSubscriptionSet.normalized(subscribeOptionQuotes)
        self.unsubscribeOptionQuotes = MarketDataSubscriptionSet.normalized(unsubscribeOptionQuotes)
        self.subscribeOptionTrades = MarketDataSubscriptionSet.normalized(subscribeOptionTrades)
        self.unsubscribeOptionTrades = MarketDataSubscriptionSet.normalized(unsubscribeOptionTrades)
        self.subscribeOptionBars = MarketDataSubscriptionSet.normalized(subscribeOptionBars)
        self.unsubscribeOptionBars = MarketDataSubscriptionSet.normalized(unsubscribeOptionBars)
    }

    public var isEmpty: Bool {
        subscribeQuotes.isEmpty &&
            unsubscribeQuotes.isEmpty &&
            subscribeTrades.isEmpty &&
            unsubscribeTrades.isEmpty &&
            subscribeBars.isEmpty &&
            unsubscribeBars.isEmpty &&
            subscribeOptionQuotes.isEmpty &&
            unsubscribeOptionQuotes.isEmpty &&
            subscribeOptionTrades.isEmpty &&
            unsubscribeOptionTrades.isEmpty &&
            subscribeOptionBars.isEmpty &&
            unsubscribeOptionBars.isEmpty
    }
}

public struct MarketQuote: Equatable, Sendable {
    public let symbol: String
    public var instrumentType: InstrumentType
    public var bidPrice: Double?
    public var askPrice: Double?
    public var lastPrice: Double?
    public var timestamp: String?
    public var lastQuoteTimestamp: String?
    public var lastTradeTimestamp: String?
    public var lastBarTimestamp: String?

    public init(
        symbol: String,
        instrumentType: InstrumentType = .equity,
        bidPrice: Double? = nil,
        askPrice: Double? = nil,
        lastPrice: Double? = nil,
        timestamp: String? = nil,
        lastQuoteTimestamp: String? = nil,
        lastTradeTimestamp: String? = nil,
        lastBarTimestamp: String? = nil
    ) {
        self.symbol = symbol
        self.instrumentType = instrumentType
        self.bidPrice = bidPrice
        self.askPrice = askPrice
        self.lastPrice = lastPrice
        self.timestamp = timestamp
        self.lastQuoteTimestamp = lastQuoteTimestamp
        self.lastTradeTimestamp = lastTradeTimestamp
        self.lastBarTimestamp = lastBarTimestamp
    }
}

public struct MarketDataQuoteEvent: Equatable, Sendable {
    public let symbol: String
    public let instrumentType: InstrumentType
    public let bidPrice: Double?
    public let askPrice: Double?
    public let bidSize: Double?
    public let askSize: Double?
    public let timestamp: String?

    public init(
        symbol: String,
        instrumentType: InstrumentType? = nil,
        bidPrice: Double?,
        askPrice: Double?,
        bidSize: Double?,
        askSize: Double?,
        timestamp: String?
    ) {
        self.symbol = symbol
        self.instrumentType = instrumentType ?? MarketSymbolClassifier.instrumentType(for: symbol)
        self.bidPrice = bidPrice
        self.askPrice = askPrice
        self.bidSize = bidSize
        self.askSize = askSize
        self.timestamp = timestamp
    }
}

public struct MarketDataTradeEvent: Equatable, Sendable {
    public let symbol: String
    public let instrumentType: InstrumentType
    public let price: Double?
    public let size: Double?
    public let timestamp: String?

    public init(
        symbol: String,
        instrumentType: InstrumentType? = nil,
        price: Double?,
        size: Double?,
        timestamp: String?
    ) {
        self.symbol = symbol
        self.instrumentType = instrumentType ?? MarketSymbolClassifier.instrumentType(for: symbol)
        self.price = price
        self.size = size
        self.timestamp = timestamp
    }
}

public struct MarketDataBarEvent: Equatable, Sendable {
    public let symbol: String
    public let instrumentType: InstrumentType
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let close: Double?
    public let volume: Double?
    public let timestamp: String?

    public init(
        symbol: String,
        instrumentType: InstrumentType? = nil,
        open: Double?,
        high: Double?,
        low: Double?,
        close: Double?,
        volume: Double?,
        timestamp: String?
    ) {
        self.symbol = symbol
        self.instrumentType = instrumentType ?? MarketSymbolClassifier.instrumentType(for: symbol)
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.timestamp = timestamp
    }
}

public enum MarketDataInboundMessage: Equatable, Sendable {
    case success(message: String)
    case error(code: Int?, message: String)
    case subscription(MarketDataSubscriptionSet)
    case quote(MarketDataQuoteEvent)
    case trade(MarketDataTradeEvent)
    case bar(MarketDataBarEvent)
    case unknown(description: String)
}

public enum MarketDataStreamEvent: Equatable, Sendable {
    case connectionStateChanged(MarketDataConnectionState)
    case desiredSubscriptionChanged(MarketDataSubscriptionSet)
    case subscriptionChanged(MarketDataSubscriptionSet)
    case quote(MarketDataQuoteEvent)
    case trade(MarketDataTradeEvent)
    case bar(MarketDataBarEvent)
    case diagnostic(String)
}
