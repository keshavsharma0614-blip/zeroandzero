import Foundation

public struct PlaceOrderIntent: Sendable, Equatable {
    public var instrumentType: InstrumentType
    public var symbol: String
    public var qty: Int
    public var side: OrderSide
    public var type: OrderType
    public var limitPrice: Decimal?
    public var timeInForce: TimeInForce
    public var bracket: BracketOrderInput?

    public init(
        instrumentType: InstrumentType = .equity,
        symbol: String,
        qty: Int,
        side: OrderSide,
        type: OrderType,
        limitPrice: Decimal? = nil,
        timeInForce: TimeInForce = .day,
        bracket: BracketOrderInput? = nil
    ) {
        self.instrumentType = instrumentType
        self.symbol = symbol
        self.qty = qty
        self.side = side
        self.type = type
        self.limitPrice = limitPrice
        self.timeInForce = timeInForce
        self.bracket = bracket
    }
}

public struct ReplaceOrderIntent: Sendable, Equatable {
    public var orderID: String
    public var qty: Int?
    public var limitPrice: Decimal?

    public init(
        orderID: String,
        qty: Int? = nil,
        limitPrice: Decimal? = nil
    ) {
        self.orderID = orderID
        self.qty = qty
        self.limitPrice = limitPrice
    }
}

public enum OrderIntent: Sendable, Equatable {
    case place(PlaceOrderIntent)
    case replace(ReplaceOrderIntent)
    case cancel(orderID: String)
}

public struct OrderIntentSubmissionResult: Sendable, Equatable {
    public let accepted: Bool
    public let orderID: String?
    public let errorCode: String?
    public let message: String

    public init(
        accepted: Bool,
        orderID: String? = nil,
        errorCode: String? = nil,
        message: String
    ) {
        self.accepted = accepted
        self.orderID = orderID
        self.errorCode = errorCode
        self.message = message
    }

    public static func success(orderID: String?, message: String) -> Self {
        Self(accepted: true, orderID: orderID, message: message)
    }

    public static func failure(code: String, message: String) -> Self {
        Self(accepted: false, errorCode: code, message: message)
    }
}
