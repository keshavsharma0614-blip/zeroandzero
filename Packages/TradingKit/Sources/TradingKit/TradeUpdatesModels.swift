import Foundation

public enum TradeUpdatesConnectionState: String, Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case authenticated
    case subscribed
}

public struct TradeUpdatesStreamRuntimeSnapshot: Equatable, Sendable {
    public var environment: Environment
    public var endpoint: String
    public var state: TradeUpdatesConnectionState
    public var isRunning: Bool
    public var hasSocketTask: Bool
    public var lastStateChangedAt: Date?
    public var lastAuthorizationStatus: String?
    public var lastListeningStreams: [String]
    public var lastDiagnostic: String?
    public var lastError: String?
    public var reconnectRequestCount: Int
    public var lastReconnectReason: String?

    public init(
        environment: Environment,
        endpoint: String,
        state: TradeUpdatesConnectionState,
        isRunning: Bool,
        hasSocketTask: Bool,
        lastStateChangedAt: Date? = nil,
        lastAuthorizationStatus: String? = nil,
        lastListeningStreams: [String] = [],
        lastDiagnostic: String? = nil,
        lastError: String? = nil,
        reconnectRequestCount: Int = 0,
        lastReconnectReason: String? = nil
    ) {
        self.environment = environment
        self.endpoint = endpoint
        self.state = state
        self.isRunning = isRunning
        self.hasSocketTask = hasSocketTask
        self.lastStateChangedAt = lastStateChangedAt
        self.lastAuthorizationStatus = lastAuthorizationStatus
        self.lastListeningStreams = lastListeningStreams
        self.lastDiagnostic = lastDiagnostic
        self.lastError = lastError
        self.reconnectRequestCount = reconnectRequestCount
        self.lastReconnectReason = lastReconnectReason
    }
}

public struct TradeUpdateEvent: Equatable, Sendable {
    public let event: String
    public let orderID: String
    public let symbol: String?
    public let assetClass: String?
    public let underlyingSymbol: String?
    public let side: String?
    public let qty: String?
    public let filledQty: String?
    public let filledAvgPrice: String?
    public let timestamp: String?
    public let orderStatus: String?

    public init(
        event: String,
        orderID: String,
        symbol: String?,
        assetClass: String? = nil,
        underlyingSymbol: String? = nil,
        side: String?,
        qty: String?,
        filledQty: String?,
        filledAvgPrice: String?,
        timestamp: String?,
        orderStatus: String?
    ) {
        self.event = event
        self.orderID = orderID
        self.symbol = symbol
        self.assetClass = assetClass
        self.underlyingSymbol = underlyingSymbol
        self.side = side
        self.qty = qty
        self.filledQty = filledQty
        self.filledAvgPrice = filledAvgPrice
        self.timestamp = timestamp
        self.orderStatus = orderStatus
    }

    public var instrumentTypeHint: InstrumentType? {
        if assetClass?.lowercased() == InstrumentType.option.rawValue {
            return .option
        }
        if let symbol, OptionContractSymbol.parse(symbol) != nil {
            return .option
        }
        if assetClass != nil || symbol != nil {
            return .equity
        }
        return nil
    }

    public var inferredUnderlyingSymbol: String? {
        if let underlyingSymbol,
           !underlyingSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return underlyingSymbol
        }
        guard let symbol else {
            return nil
        }
        return OptionContractSymbol.parse(symbol)?.underlyingSymbol
    }
}

public enum TradeUpdatesInboundMessage: Equatable, Sendable {
    case authorization(status: String)
    case listening(streams: [String])
    case tradeUpdate(TradeUpdateEvent)
    case success(message: String)
    case error(message: String)
    case unknown(description: String)
}

public enum TradeUpdatesStreamEvent: Equatable, Sendable {
    case connectionStateChanged(TradeUpdatesConnectionState)
    case tradeUpdate(TradeUpdateEvent)
    case diagnostic(String)
}
