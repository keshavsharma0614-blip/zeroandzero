import Darwin
import Foundation
import TradingKit

private struct Options {
    var environment: Environment = .paper
    var listenOnly = false
    var placeSymbol: String?
    var qty: String = "1"
    var side: OrderSide = .buy
    var type: OrderType = .market
    var limitPrice: String?
    var timeoutSeconds: TimeInterval = 20
    var allowLiveOrderPlacement = false
}

private actor Collector {
    private(set) var firstTradeUpdate: TradeUpdateEvent?
    private(set) var lastState: TradeUpdatesConnectionState = .disconnected

    func record(_ event: TradeUpdatesStreamEvent) {
        switch event {
        case .connectionStateChanged(let state):
            lastState = state
        case .tradeUpdate(let update):
            if firstTradeUpdate == nil {
                firstTradeUpdate = update
            }
        case .diagnostic:
            break
        }
    }

    func hasTradeUpdate() -> Bool {
        firstTradeUpdate != nil
    }

    func isSubscribed() -> Bool {
        lastState == .subscribed
    }
}

@main
struct AlpacaTradeUpdatesSmoke {
    static func main() async {
        let code = await run()
        Darwin.exit(Int32(code))
    }

    private static func run() async -> Int {
        do {
            let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))

            if options.environment == .live,
               options.placeSymbol != nil,
               !options.allowLiveOrderPlacement {
                throw SmokeError.invalidArguments("Live order placement requires --i-understand-live.")
            }

            let provider = KeychainCredentialsProvider()
            guard provider.credentials(for: options.environment) != nil else {
                throw SmokeError.runtime("Missing Keychain credentials for \(options.environment.rawValue).")
            }

            let stream = AlpacaTradeUpdatesStream(
                environment: options.environment,
                keychainProvider: provider
            )

            let collector = Collector()
            let listenTask = Task {
                for await event in stream.events {
                    await collector.record(event)
                    print(render(event: event))
                }
            }

            await stream.start()

            if let symbol = options.placeSymbol {
                let rest = AlpacaRESTClient(
                    environment: options.environment,
                    keychainProvider: provider
                )

                let subscribed = await waitForSubscribed(collector: collector, timeout: 10)
                if !subscribed {
                    print("warning: stream not yet subscribed; continuing with test order")
                }

                let request = NewOrderRequest(
                    symbol: symbol,
                    qty: options.qty,
                    side: options.side,
                    type: options.type,
                    timeInForce: .day,
                    limitPrice: options.limitPrice
                )

                let order = try await rest.placeOrder(request: request)
                print("placed order id=\(order.id) symbol=\(order.symbol ?? symbol) status=\(order.status ?? "unknown")")

                do {
                    try await rest.cancelOrder(orderId: order.id)
                    print("cancel requested order_id=\(order.id)")
                } catch {
                    print("cancel skipped order_id=\(order.id) reason=\(error.localizedDescription)")
                }
            }

            let received = await waitForTradeUpdate(collector: collector, timeout: options.timeoutSeconds)
            await stream.stop()
            listenTask.cancel()

            if received {
                print("success: received at least one trade_update event")
                return 0
            }
            print("failure: no trade_update received within \(options.timeoutSeconds)s")
            return 3
        } catch {
            if case SmokeError.help = error {
                return 0
            }
            fputs("alpaca_trade_updates_smoke failed: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func parseOptions(arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--help", "-h":
                printUsage()
                throw SmokeError.help
            case "--live":
                options.environment = .live
                index += 1
            case "--listen-only":
                options.listenOnly = true
                index += 1
            case "--place-test-order":
                options.placeSymbol = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--qty":
                options.qty = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--side":
                let value = try nextValue(for: arg, arguments: arguments, index: &index)
                guard let side = OrderSide(rawValue: value.lowercased()) else {
                    throw SmokeError.invalidArguments("Invalid --side value \(value)")
                }
                options.side = side
            case "--type":
                let value = try nextValue(for: arg, arguments: arguments, index: &index)
                guard let type = OrderType(rawValue: value.lowercased()) else {
                    throw SmokeError.invalidArguments("Invalid --type value \(value)")
                }
                options.type = type
            case "--limit-price":
                options.limitPrice = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--timeout":
                let value = try nextValue(for: arg, arguments: arguments, index: &index)
                guard let timeout = TimeInterval(value), timeout > 0 else {
                    throw SmokeError.invalidArguments("Invalid --timeout value \(value)")
                }
                options.timeoutSeconds = timeout
            case "--i-understand-live":
                options.allowLiveOrderPlacement = true
                index += 1
            default:
                throw SmokeError.invalidArguments("Unknown argument \(arg)")
            }
        }

        if options.placeSymbol == nil {
            options.listenOnly = true
        }
        if options.listenOnly && options.placeSymbol != nil {
            throw SmokeError.invalidArguments("--listen-only cannot be combined with --place-test-order")
        }
        if options.type == .limit && options.limitPrice == nil {
            throw SmokeError.invalidArguments("--limit-price required for --type limit")
        }

        return options
    }

    private static func nextValue(for flag: String, arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw SmokeError.invalidArguments("Missing value for \(flag)")
        }
        let value = arguments[valueIndex]
        index = valueIndex + 1
        return value
    }

    private static func waitForSubscribed(collector: Collector, timeout: TimeInterval) async -> Bool {
        let start = Date().timeIntervalSince1970
        while Date().timeIntervalSince1970 - start < timeout {
            if await collector.isSubscribed() {
                return true
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }

    private static func waitForTradeUpdate(collector: Collector, timeout: TimeInterval) async -> Bool {
        let start = Date().timeIntervalSince1970
        while Date().timeIntervalSince1970 - start < timeout {
            if await collector.hasTradeUpdate() {
                return true
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }

    private static func render(event: TradeUpdatesStreamEvent) -> String {
        switch event {
        case .connectionStateChanged(let state):
            return "state=\(state.rawValue)"
        case .tradeUpdate(let update):
            var parts: [String] = [
                "trade_update",
                "event=\(update.event)",
                "order_id=\(update.orderID)"
            ]
            if let symbol = update.symbol {
                parts.append("symbol=\(symbol)")
            }
            if let status = update.orderStatus {
                parts.append("status=\(status)")
            }
            if let filledQty = update.filledQty {
                parts.append("filled_qty=\(filledQty)")
            }
            return parts.joined(separator: " ")
        case .diagnostic(let message):
            return "diagnostic=\(message)"
        }
    }

    private static func printUsage() {
        print("Usage: swift run alpaca_trade_updates_smoke [--live] [--listen-only] [--timeout 20]")
        print("       swift run alpaca_trade_updates_smoke --place-test-order AAPL --qty 1 --side buy --type market")
        print("       swift run alpaca_trade_updates_smoke --live --place-test-order AAPL --i-understand-live")
    }
}

private enum SmokeError: LocalizedError {
    case help
    case invalidArguments(String)
    case runtime(String)

    var errorDescription: String? {
        switch self {
        case .help:
            return "help"
        case .invalidArguments(let msg):
            return msg
        case .runtime(let msg):
            return msg
        }
    }
}
