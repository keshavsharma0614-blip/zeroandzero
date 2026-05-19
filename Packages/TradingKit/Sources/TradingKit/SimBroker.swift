import Foundation

public enum SimOrderStatus: String, Sendable, Codable, Equatable {
    case new
    case open
    case partiallyFilled = "partially_filled"
    case filled
    case canceled
    case rejected
    case replaced
    case expired
}

public struct SimOrder: Sendable, Equatable {
    public let orderID: String
    public let submittedAt: Date
    public let symbol: String
    public let side: OrderSide
    public let type: OrderType
    public let limitPrice: Decimal?
    public let timeInForce: TimeInForce
    public let qty: Decimal
    public var filledQty: Decimal
    public var status: SimOrderStatus
    public let source: String?

    public init(
        orderID: String,
        submittedAt: Date,
        symbol: String,
        side: OrderSide,
        type: OrderType,
        limitPrice: Decimal?,
        timeInForce: TimeInForce,
        qty: Decimal,
        filledQty: Decimal = 0,
        status: SimOrderStatus = .new,
        source: String? = nil
    ) {
        self.orderID = orderID
        self.submittedAt = submittedAt
        self.symbol = symbol
        self.side = side
        self.type = type
        self.limitPrice = limitPrice
        self.timeInForce = timeInForce
        self.qty = qty
        self.filledQty = filledQty
        self.status = status
        self.source = source
    }

    public var remainingQty: Decimal {
        max(0, qty - filledQty)
    }

    public var isOpen: Bool {
        switch status {
        case .new, .open, .partiallyFilled:
            return remainingQty > 0
        default:
            return false
        }
    }
}

public struct SimBrokerPositionSnapshot: Sendable, Equatable {
    public let symbol: String
    public let qty: Decimal
    public let avgCost: Decimal
    public let markPrice: Decimal

    public init(symbol: String, qty: Decimal, avgCost: Decimal, markPrice: Decimal) {
        self.symbol = symbol
        self.qty = qty
        self.avgCost = avgCost
        self.markPrice = markPrice
    }
}

public struct SimBrokerAccountSnapshot: Sendable, Equatable {
    public let cash: Decimal
    public let equity: Decimal
    public let realizedPnL: Decimal
    public let unrealizedPnL: Decimal
    public let netPnL: Decimal
    public let positions: [SimBrokerPositionSnapshot]

    public init(
        cash: Decimal,
        equity: Decimal,
        realizedPnL: Decimal,
        unrealizedPnL: Decimal,
        netPnL: Decimal,
        positions: [SimBrokerPositionSnapshot]
    ) {
        self.cash = cash
        self.equity = equity
        self.realizedPnL = realizedPnL
        self.unrealizedPnL = unrealizedPnL
        self.netPnL = netPnL
        self.positions = positions
    }
}

public struct SimBrokerSubmission: Sendable, Equatable {
    public let result: OrderIntentSubmissionResult
    public let events: [TradeUpdateEvent]
    public let accountSnapshot: SimBrokerAccountSnapshot

    public init(
        result: OrderIntentSubmissionResult,
        events: [TradeUpdateEvent],
        accountSnapshot: SimBrokerAccountSnapshot
    ) {
        self.result = result
        self.events = events
        self.accountSnapshot = accountSnapshot
    }
}

public struct SimBrokerTickResult: Sendable, Equatable {
    public let events: [TradeUpdateEvent]
    public let accountSnapshot: SimBrokerAccountSnapshot

    public init(events: [TradeUpdateEvent], accountSnapshot: SimBrokerAccountSnapshot) {
        self.events = events
        self.accountSnapshot = accountSnapshot
    }
}

private struct SimPosition: Sendable, Equatable {
    var qty: Decimal
    var avgCost: Decimal
}

public actor SimBroker {
    private let simulation: ReplaySimulationConfig
    private let orderIDPrefix: String
    private let customOrderIDGenerator: (@Sendable () -> String)?
    private let isoFormatter: ISO8601DateFormatter

    private var nextGeneratedOrderSequence: Int = 1
    private var now: Date
    private var cash: Decimal
    private var realizedPnL: Decimal = 0
    private var ordersByID: [String: SimOrder] = [:]
    private var positionsBySymbol: [String: SimPosition] = [:]
    private var lastCloseBySymbol: [String: Decimal] = [:]

    public init(
        simulation: ReplaySimulationConfig,
        initialCash: Decimal,
        initialTime: Date,
        orderIDPrefix: String = "sim-order",
        orderIDGenerator: (@Sendable () -> String)? = nil
    ) {
        self.simulation = simulation
        self.orderIDPrefix = orderIDPrefix
        self.customOrderIDGenerator = orderIDGenerator
        self.now = initialTime
        self.cash = initialCash

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFormatter = formatter
    }

    public func setCurrentTime(_ timestamp: Date) {
        now = timestamp
    }

    public func submit(intent: OrderIntent, source: String?) -> SimBrokerSubmission {
        let output: (OrderIntentSubmissionResult, [TradeUpdateEvent])
        switch intent {
        case .place(let place):
            output = submitPlace(place, source: source)
        case .cancel(let orderID):
            output = submitCancel(orderID: orderID)
        case .replace(let replace):
            output = submitReplace(replace)
        }
        return SimBrokerSubmission(
            result: output.0,
            events: output.1,
            accountSnapshot: markToMarketSnapshot()
        )
    }

    public func processBar(_ bar: Bar) -> SimBrokerTickResult {
        now = bar.timestamp
        lastCloseBySymbol[bar.symbol] = decimal(bar.close)

        let openOrders = ordersByID.values
            .filter { $0.isOpen && $0.symbol == bar.symbol && $0.submittedAt < bar.timestamp }
            .sorted { lhs, rhs in
                if lhs.submittedAt == rhs.submittedAt {
                    return lhs.orderID < rhs.orderID
                }
                return lhs.submittedAt < rhs.submittedAt
            }

        var events: [TradeUpdateEvent] = []
        for order in openOrders {
            guard let fillPrice = fillPriceIfTriggered(order: order, bar: bar) else {
                continue
            }
            events.append(fillOrder(orderID: order.orderID, fillPrice: fillPrice))
        }

        return SimBrokerTickResult(
            events: events,
            accountSnapshot: markToMarketSnapshot()
        )
    }

    public func finalize(endTime: Date) -> SimBrokerTickResult {
        now = endTime
        let openDayOrders = ordersByID.values
            .filter { $0.isOpen && $0.timeInForce == .day }
            .sorted { $0.orderID < $1.orderID }

        var events: [TradeUpdateEvent] = []
        for order in openDayOrders {
            var current = order
            current.status = .expired
            ordersByID[current.orderID] = current
            events.append(
                tradeUpdate(
                    event: "canceled",
                    order: current,
                    status: .expired
                )
            )
        }

        return SimBrokerTickResult(
            events: events,
            accountSnapshot: markToMarketSnapshot()
        )
    }

    public func snapshot() -> SimBrokerAccountSnapshot {
        markToMarketSnapshot()
    }

    private func submitPlace(
        _ place: PlaceOrderIntent,
        source: String?
    ) -> (OrderIntentSubmissionResult, [TradeUpdateEvent]) {
        let symbol = normalizedSymbol(place.symbol)
        guard !symbol.isEmpty else {
            let rejectedOrder = buildRejectedOrder(symbol: "?", side: place.side, type: place.type, qty: Decimal(place.qty), source: source)
            return (
                .failure(code: "sim_invalid_symbol", message: "Symbol is required."),
                [tradeUpdate(event: "rejected", order: rejectedOrder, status: .rejected)]
            )
        }
        guard place.qty > 0 else {
            let rejectedOrder = buildRejectedOrder(symbol: symbol, side: place.side, type: place.type, qty: 0, source: source)
            return (
                .failure(code: "sim_invalid_quantity", message: "Quantity must be > 0."),
                [tradeUpdate(event: "rejected", order: rejectedOrder, status: .rejected)]
            )
        }
        guard place.instrumentType == .equity else {
            let rejectedOrder = buildRejectedOrder(symbol: symbol, side: place.side, type: place.type, qty: Decimal(place.qty), source: source)
            return (
                .failure(code: "sim_unsupported_instrument", message: "Replay simulation supports equities only."),
                [tradeUpdate(event: "rejected", order: rejectedOrder, status: .rejected)]
            )
        }
        guard place.type == .market || place.type == .limit else {
            let rejectedOrder = buildRejectedOrder(symbol: symbol, side: place.side, type: place.type, qty: Decimal(place.qty), source: source)
            return (
                .failure(code: "sim_unsupported_order_type", message: "Replay simulation supports market and limit orders."),
                [tradeUpdate(event: "rejected", order: rejectedOrder, status: .rejected)]
            )
        }
        if place.type == .limit {
            guard let limitPrice = place.limitPrice, limitPrice > 0 else {
                let rejectedOrder = buildRejectedOrder(symbol: symbol, side: place.side, type: place.type, qty: Decimal(place.qty), source: source)
                return (
                    .failure(code: "sim_limit_price_required", message: "Limit price is required for limit orders."),
                    [tradeUpdate(event: "rejected", order: rejectedOrder, status: .rejected)]
                )
            }
            if limitPrice <= 0 {
                let rejectedOrder = buildRejectedOrder(symbol: symbol, side: place.side, type: place.type, qty: Decimal(place.qty), source: source)
                return (
                    .failure(code: "sim_invalid_limit_price", message: "Limit price must be > 0."),
                    [tradeUpdate(event: "rejected", order: rejectedOrder, status: .rejected)]
                )
            }
        }

        let orderID = nextOrderID()
        var order = SimOrder(
            orderID: orderID,
            submittedAt: now,
            symbol: symbol,
            side: place.side,
            type: place.type,
            limitPrice: place.limitPrice,
            timeInForce: place.timeInForce,
            qty: Decimal(place.qty),
            filledQty: 0,
            status: .new,
            source: source
        )
        order.status = .open
        ordersByID[orderID] = order

        return (
            .success(orderID: orderID, message: "Sim order accepted."),
            [tradeUpdate(event: "new", order: order, status: .new)]
        )
    }

    private func submitCancel(orderID: String) -> (OrderIntentSubmissionResult, [TradeUpdateEvent]) {
        guard var order = ordersByID[orderID], order.isOpen else {
            return (
                .failure(code: "sim_order_not_open", message: "Order is not open."),
                []
            )
        }
        order.status = .canceled
        ordersByID[orderID] = order
        return (
            .success(orderID: orderID, message: "Sim cancel accepted."),
            [tradeUpdate(event: "canceled", order: order, status: .canceled)]
        )
    }

    private func submitReplace(_ replace: ReplaceOrderIntent) -> (OrderIntentSubmissionResult, [TradeUpdateEvent]) {
        guard var oldOrder = ordersByID[replace.orderID], oldOrder.isOpen else {
            return (
                .failure(code: "sim_order_not_open", message: "Order is not open."),
                []
            )
        }

        if replace.qty == nil && replace.limitPrice == nil {
            return (
                .failure(code: "sim_replace_requires_changes", message: "Provide qty and/or limit price."),
                []
            )
        }
        if let qty = replace.qty, qty <= 0 {
            return (
                .failure(code: "sim_invalid_quantity", message: "Quantity must be > 0."),
                []
            )
        }
        if let limitPrice = replace.limitPrice, limitPrice <= 0 {
            return (
                .failure(code: "sim_invalid_limit_price", message: "Limit price must be > 0."),
                []
            )
        }

        oldOrder.status = .replaced
        ordersByID[oldOrder.orderID] = oldOrder

        let replacementID = nextOrderID()
        var replacement = SimOrder(
            orderID: replacementID,
            submittedAt: now,
            symbol: oldOrder.symbol,
            side: oldOrder.side,
            type: oldOrder.type,
            limitPrice: replace.limitPrice ?? oldOrder.limitPrice,
            timeInForce: oldOrder.timeInForce,
            qty: Decimal(replace.qty ?? Int(NSDecimalNumber(decimal: oldOrder.qty).intValue)),
            filledQty: 0,
            status: .new,
            source: oldOrder.source
        )
        replacement.status = .open
        ordersByID[replacementID] = replacement

        return (
            .success(orderID: replacementID, message: "Sim replace accepted."),
            [
                tradeUpdate(event: "replaced", order: oldOrder, status: .replaced),
                tradeUpdate(event: "new", order: replacement, status: .new)
            ]
        )
    }

    private func fillPriceIfTriggered(order: SimOrder, bar: Bar) -> Decimal? {
        switch simulation.fillPolicy {
        case .nextOpenMarket:
            // Deterministic policy:
            // - market fills at next eligible bar open
            // - limit buy fills when bar.low <= limit at min(limit, bar.open)
            // - limit sell fills when bar.high >= limit at max(limit, bar.open)
            switch order.type {
            case .market:
                return adjustedFillPrice(base: decimal(bar.open), side: order.side, bps: simulation.slippageBps.market)
            case .limit:
                guard let limitPrice = order.limitPrice else {
                    return nil
                }
                let low = decimal(bar.low)
                let high = decimal(bar.high)
                let open = decimal(bar.open)
                switch order.side {
                case .buy:
                    guard low <= limitPrice else {
                        return nil
                    }
                    let base = min(limitPrice, open)
                    return adjustedFillPrice(base: base, side: order.side, bps: simulation.slippageBps.limit)
                case .sell:
                    guard high >= limitPrice else {
                        return nil
                    }
                    let base = max(limitPrice, open)
                    return adjustedFillPrice(base: base, side: order.side, bps: simulation.slippageBps.limit)
                }
            default:
                return nil
            }
        }
    }

    private func adjustedFillPrice(base: Decimal, side: OrderSide, bps: Int) -> Decimal {
        guard bps > 0 else {
            return base
        }
        let factor = Decimal(bps) / 10_000
        switch side {
        case .buy:
            return base * (1 + factor)
        case .sell:
            return base * (1 - factor)
        }
    }

    private func fillOrder(orderID: String, fillPrice: Decimal) -> TradeUpdateEvent {
        guard var order = ordersByID[orderID] else {
            return TradeUpdateEvent(
                event: "rejected",
                orderID: orderID,
                symbol: nil,
                side: nil,
                qty: nil,
                filledQty: nil,
                filledAvgPrice: nil,
                timestamp: isoFormatter.string(from: now),
                orderStatus: "rejected"
            )
        }

        let fillQty = order.remainingQty
        applyFill(
            symbol: order.symbol,
            side: order.side,
            qty: fillQty,
            price: fillPrice
        )

        order.filledQty += fillQty
        order.status = .filled
        ordersByID[orderID] = order

        return tradeUpdate(event: "fill", order: order, status: .filled, filledAvgPrice: fillPrice)
    }

    private func applyFill(symbol: String, side: OrderSide, qty: Decimal, price: Decimal) {
        guard qty > 0 else {
            return
        }
        var position = positionsBySymbol[symbol] ?? SimPosition(qty: 0, avgCost: 0)

        switch side {
        case .buy:
            cash -= qty * price
            if position.qty >= 0 {
                let totalCost = (position.avgCost * position.qty) + (price * qty)
                position.qty += qty
                position.avgCost = position.qty == 0 ? 0 : totalCost / position.qty
            } else {
                let shortAbs = -position.qty
                let covered = min(qty, shortAbs)
                realizedPnL += (position.avgCost - price) * covered
                let remainingBuy = qty - covered
                position.qty += qty
                if position.qty < 0 {
                    // Still short; avgCost unchanged.
                } else if position.qty == 0 {
                    position.avgCost = 0
                } else {
                    position.avgCost = remainingBuy > 0 ? price : position.avgCost
                }
            }
        case .sell:
            cash += qty * price
            if position.qty <= 0 {
                let shortAbs = -position.qty
                let totalProceeds = (position.avgCost * shortAbs) + (price * qty)
                position.qty -= qty
                let nextShortAbs = -position.qty
                position.avgCost = nextShortAbs == 0 ? 0 : totalProceeds / nextShortAbs
            } else {
                let closed = min(qty, position.qty)
                realizedPnL += (price - position.avgCost) * closed
                let remainingSell = qty - closed
                position.qty -= qty
                if position.qty > 0 {
                    // Still long; avgCost unchanged.
                } else if position.qty == 0 {
                    position.avgCost = 0
                } else {
                    position.avgCost = remainingSell > 0 ? price : position.avgCost
                }
            }
        }

        if position.qty == 0 {
            positionsBySymbol[symbol] = nil
        } else {
            positionsBySymbol[symbol] = position
        }
    }

    private func markToMarketSnapshot() -> SimBrokerAccountSnapshot {
        let sortedSymbols = positionsBySymbol.keys.sorted()
        var snapshots: [SimBrokerPositionSnapshot] = []
        var unrealized: Decimal = 0
        var marketValue: Decimal = 0

        for symbol in sortedSymbols {
            guard let position = positionsBySymbol[symbol] else {
                continue
            }
            let mark = lastCloseBySymbol[symbol] ?? position.avgCost
            let qty = position.qty
            marketValue += qty * mark

            if qty > 0 {
                unrealized += (mark - position.avgCost) * qty
            } else if qty < 0 {
                unrealized += (position.avgCost - mark) * (-qty)
            }

            snapshots.append(
                SimBrokerPositionSnapshot(
                    symbol: symbol,
                    qty: qty,
                    avgCost: position.avgCost,
                    markPrice: mark
                )
            )
        }

        let equity = cash + marketValue
        let net = realizedPnL + unrealized
        return SimBrokerAccountSnapshot(
            cash: cash,
            equity: equity,
            realizedPnL: realizedPnL,
            unrealizedPnL: unrealized,
            netPnL: net,
            positions: snapshots
        )
    }

    private func tradeUpdate(
        event: String,
        order: SimOrder,
        status: SimOrderStatus,
        filledAvgPrice: Decimal? = nil
    ) -> TradeUpdateEvent {
        TradeUpdateEvent(
            event: event,
            orderID: order.orderID,
            symbol: order.symbol,
            side: order.side.rawValue,
            qty: decimalString(order.qty),
            filledQty: decimalString(order.filledQty),
            filledAvgPrice: filledAvgPrice.map(decimalString),
            timestamp: isoFormatter.string(from: now),
            orderStatus: status.rawValue
        )
    }

    private func buildRejectedOrder(
        symbol: String,
        side: OrderSide,
        type: OrderType,
        qty: Decimal,
        source: String?
    ) -> SimOrder {
        SimOrder(
            orderID: nextOrderID(),
            submittedAt: now,
            symbol: symbol,
            side: side,
            type: type,
            limitPrice: nil,
            timeInForce: .day,
            qty: qty,
            filledQty: 0,
            status: .rejected,
            source: source
        )
    }

    private func normalizedSymbol(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(format: "%.10f", value), locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func nextOrderID() -> String {
        if let customOrderIDGenerator {
            return customOrderIDGenerator()
        }
        let value = "\(orderIDPrefix)-\(nextGeneratedOrderSequence)"
        nextGeneratedOrderSequence += 1
        return value
    }
}
