import Foundation

public struct Account: Decodable, Sendable {
    public let id: String
    public let status: String?
    public let cash: String?
    public let buyingPower: String?
    public let equity: String?
    public let multiplier: String?

    public init(
        id: String,
        status: String? = nil,
        cash: String? = nil,
        buyingPower: String? = nil,
        equity: String? = nil,
        multiplier: String? = nil
    ) {
        self.id = id
        self.status = status
        self.cash = cash
        self.buyingPower = buyingPower
        self.equity = equity
        self.multiplier = multiplier
    }

    public var canShortSellEquities: Bool {
        if let equityValue = decimal(equity), equityValue < 2_000 {
            return false
        }

        if let multiplierValue = decimal(multiplier), multiplierValue > 1 {
            return true
        }

        if let buyingPowerValue = decimal(buyingPower),
           let equityValue = decimal(equity),
           equityValue > 0,
           buyingPowerValue > equityValue {
            return true
        }

        // Conservative fallback:
        // if equity is known and below threshold, short is disabled (handled above).
        // otherwise allow and rely on broker-side rejection as final authority.
        return true
    }

    private func decimal(_ raw: String?) -> Decimal? {
        guard let raw else {
            return nil
        }
        return Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
    }
}

public struct Position: Decodable, Sendable {
    public let symbol: String?
    public let qty: String?
    public let side: String?
    public let marketValue: String?
}

public struct Order: Decodable, Sendable {
    public let id: String
    public let clientOrderId: String?
    public let symbol: String?
    public let assetClass: String?
    public let underlyingSymbol: String?
    public let qty: String?
    public let limitPrice: String?
    public let side: String?
    public let type: String?
    public let timeInForce: String?
    public let status: String?
    public let orderClass: String?
    public let parentOrderId: String?

    public init(
        id: String,
        clientOrderId: String? = nil,
        symbol: String? = nil,
        assetClass: String? = nil,
        underlyingSymbol: String? = nil,
        qty: String? = nil,
        limitPrice: String? = nil,
        side: String? = nil,
        type: String? = nil,
        timeInForce: String? = nil,
        status: String? = nil,
        orderClass: String? = nil,
        parentOrderId: String? = nil
    ) {
        self.id = id
        self.clientOrderId = clientOrderId
        self.symbol = symbol
        self.assetClass = assetClass
        self.underlyingSymbol = underlyingSymbol
        self.qty = qty
        self.limitPrice = limitPrice
        self.side = side
        self.type = type
        self.timeInForce = timeInForce
        self.status = status
        self.orderClass = orderClass
        self.parentOrderId = parentOrderId
    }
}

public enum InstrumentType: String, Codable, Sendable, CaseIterable {
    case equity
    case option

    public var shortLabel: String {
        switch self {
        case .equity:
            return "EQ"
        case .option:
            return "OPT"
        }
    }
}

public struct Asset: Decodable, Sendable, Equatable {
    public let symbol: String
    public let tradable: Bool?
    public let marginable: Bool?
    public let shortable: Bool?

    public init(
        symbol: String,
        tradable: Bool? = nil,
        marginable: Bool? = nil,
        shortable: Bool? = nil
    ) {
        self.symbol = symbol
        self.tradable = tradable
        self.marginable = marginable
        self.shortable = shortable
    }
}

public struct OptionContract: Decodable, Sendable, Equatable {
    public let id: String?
    public let symbol: String
    public let underlyingSymbol: String?
    public let expirationDate: String?
    public let strikePrice: String?
    public let type: String?
    public let style: String?
    public let status: String?
    public let tradable: Bool?

    public init(
        id: String? = nil,
        symbol: String,
        underlyingSymbol: String? = nil,
        expirationDate: String? = nil,
        strikePrice: String? = nil,
        type: String? = nil,
        style: String? = nil,
        status: String? = nil,
        tradable: Bool? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.underlyingSymbol = underlyingSymbol
        self.expirationDate = expirationDate
        self.strikePrice = strikePrice
        self.type = type
        self.style = style
        self.status = status
        self.tradable = tradable
    }
}

public enum OrderSide: String, Codable, Sendable {
    case buy
    case sell
}

public enum OrderType: String, Codable, Sendable {
    case market
    case limit
    case stop
    case stopLimit = "stop_limit"
}

public enum TimeInForce: String, Codable, Sendable {
    case day
    case gtc
    case opg
    case cls
    case ioc
    case fok
}

public enum OrderClass: String, Codable, Sendable {
    case simple
    case bracket
}

public struct TakeProfitRequest: Codable, Sendable {
    public let limitPrice: String

    public init(limitPrice: String) {
        self.limitPrice = limitPrice
    }
}

public struct StopLossRequest: Codable, Sendable {
    public let stopPrice: String
    public let limitPrice: String?

    public init(
        stopPrice: String,
        limitPrice: String? = nil
    ) {
        self.stopPrice = stopPrice
        self.limitPrice = limitPrice
    }
}

public struct NewOrderRequest: Encodable, Sendable {
    public let instrumentType: InstrumentType
    public let symbol: String
    public let qty: String
    public let side: OrderSide
    public let type: OrderType
    public let timeInForce: TimeInForce
    public let limitPrice: String?
    public let stopPrice: String?
    public let clientOrderId: String?
    public let orderClass: OrderClass?
    public let takeProfit: TakeProfitRequest?
    public let stopLoss: StopLossRequest?

    public init(
        instrumentType: InstrumentType = .equity,
        symbol: String,
        qty: String,
        side: OrderSide,
        type: OrderType,
        timeInForce: TimeInForce = .day,
        limitPrice: String? = nil,
        stopPrice: String? = nil,
        clientOrderId: String? = nil,
        orderClass: OrderClass? = nil,
        takeProfit: TakeProfitRequest? = nil,
        stopLoss: StopLossRequest? = nil
    ) {
        self.instrumentType = instrumentType
        self.symbol = symbol
        self.qty = qty
        self.side = side
        self.type = type
        self.timeInForce = timeInForce
        self.limitPrice = limitPrice
        self.stopPrice = stopPrice
        self.clientOrderId = clientOrderId
        self.orderClass = orderClass
        self.takeProfit = takeProfit
        self.stopLoss = stopLoss
    }

    enum CodingKeys: String, CodingKey {
        case symbol
        case qty
        case side
        case type
        case timeInForce
        case limitPrice
        case stopPrice
        case clientOrderId
        case orderClass
        case takeProfit
        case stopLoss
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(qty, forKey: .qty)
        try container.encode(side, forKey: .side)
        try container.encode(type, forKey: .type)
        try container.encode(timeInForce, forKey: .timeInForce)
        try container.encodeIfPresent(limitPrice, forKey: .limitPrice)
        try container.encodeIfPresent(clientOrderId, forKey: .clientOrderId)

        if instrumentType == .equity {
            try container.encodeIfPresent(stopPrice, forKey: .stopPrice)
            try container.encodeIfPresent(orderClass, forKey: .orderClass)
            try container.encodeIfPresent(takeProfit, forKey: .takeProfit)
            try container.encodeIfPresent(stopLoss, forKey: .stopLoss)
        }
    }
}

public struct ReplaceOrderRequest: Encodable, Sendable {
    public let qty: String?
    public let limitPrice: String?

    public init(
        qty: String? = nil,
        limitPrice: String? = nil
    ) {
        self.qty = qty
        self.limitPrice = limitPrice
    }
}

public extension Order {
    var instrumentType: InstrumentType {
        if assetClass?.lowercased() == InstrumentType.option.rawValue {
            return .option
        }
        if let symbol, OptionContractSymbol.parse(symbol) != nil {
            return .option
        }
        return .equity
    }

    var inferredUnderlyingSymbol: String? {
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
