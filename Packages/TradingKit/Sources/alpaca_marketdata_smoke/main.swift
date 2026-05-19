import Darwin
import Foundation
import TradingKit

private struct Options {
    var environment: Environment = .paper
    var feed: MarketDataFeed = .test
    var symbols: [String] = ["FAKEPACA"]
    var optionsMode = false
    var symbolsProvided = false
    var timeoutSeconds: TimeInterval = 30
}

private actor Collector {
    private(set) var hasMarketEvent = false
    private(set) var connectionLimitExceeded = false
    private(set) var missingEntitlement = false

    func record(_ event: MarketDataStreamEvent) {
        switch event {
        case .quote, .trade, .bar:
            hasMarketEvent = true
        case .diagnostic(let message):
            let normalized = message.lowercased()
            if normalized.contains("connection limit") {
                connectionLimitExceeded = true
            }
            if normalized.contains("entitlement") ||
                normalized.contains("not authorized") ||
                normalized.contains("forbidden") ||
                normalized.contains("insufficient") {
                missingEntitlement = true
            }
        case .connectionStateChanged, .desiredSubscriptionChanged, .subscriptionChanged:
            break
        }
    }
}

@main
struct AlpacaMarketDataSmoke {
    static func main() async {
        let code = await run()
        Darwin.exit(Int32(code))
    }

    private static func run() async -> Int {
        do {
            let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            let keychainProvider = KeychainCredentialsProvider()

            guard keychainProvider.credentials(for: options.environment) != nil else {
                throw SmokeError.runtime("Missing Keychain credentials for \(options.environment.rawValue).")
            }

            let stream = AlpacaMarketDataStream(
                environment: options.environment,
                feed: options.feed,
                keychainProvider: keychainProvider
            )

            let collector = Collector()
            let listener = Task {
                for await event in stream.events {
                    await collector.record(event)
                    print(render(event: event))
                }
            }

            await stream.subscribeQuotes(symbols: options.symbols, source: "smoke")
            await stream.subscribeTrades(symbols: options.symbols, source: "smoke")
            await stream.start()

            let received = await waitForMarketEvent(
                collector: collector,
                timeout: options.timeoutSeconds
            )
            let connectionLimitExceeded = await collector.connectionLimitExceeded
            let missingEntitlement = await collector.missingEntitlement

            await stream.stop()
            listener.cancel()

            if connectionLimitExceeded {
                print("failure: connection limit exceeded for this market-data endpoint; close other clients and retry")
                return 4
            }
            if options.optionsMode && missingEntitlement {
                print("failure: options market-data entitlement missing or insufficient for requested feed/symbols")
                return 5
            }
            if received {
                print("success: received at least one market-data event")
                return 0
            }
            print("failure: no market-data events received within \(options.timeoutSeconds)s")
            return 3
        } catch {
            if case SmokeError.help = error {
                return 0
            }
            fputs("alpaca_marketdata_smoke failed: \(error.localizedDescription)\n", stderr)
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
            case "--stocks-iex":
                options.feed = .stocksIEX
                if options.symbols == ["FAKEPACA"] {
                    options.symbols = ["AAPL"]
                }
                index += 1
            case "--stocks-sip":
                options.feed = .stocksSIP
                if options.symbols == ["FAKEPACA"] {
                    options.symbols = ["AAPL"]
                }
                index += 1
            case "--options":
                options.optionsMode = true
                if options.feed == .test {
                    options.feed = .stocksIEX
                }
                index += 1
            case "--symbols":
                let raw = try nextValue(for: arg, arguments: arguments, index: &index)
                let parsed = raw
                    .split(separator: ",")
                    .map { String($0) }
                let normalized = Array(MarketDataSubscriptionSet.normalized(parsed)).sorted()
                guard !normalized.isEmpty else {
                    throw SmokeError.invalidArguments("--symbols must include at least one symbol")
                }
                options.symbols = normalized
                options.symbolsProvided = true
            case "--timeout":
                let raw = try nextValue(for: arg, arguments: arguments, index: &index)
                guard let timeout = TimeInterval(raw), timeout > 0 else {
                    throw SmokeError.invalidArguments("Invalid --timeout value \(raw)")
                }
                options.timeoutSeconds = timeout
            default:
                throw SmokeError.invalidArguments("Unknown argument \(arg)")
            }
        }

        if options.feed == .test, options.symbols.isEmpty {
            options.symbols = ["FAKEPACA"]
        }
        if options.optionsMode {
            guard options.symbolsProvided else {
                throw SmokeError.invalidArguments("--options requires --symbols with OCC contract symbol(s)")
            }
        }

        return options
    }

    private static func nextValue(
        for flag: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw SmokeError.invalidArguments("Missing value for \(flag)")
        }
        let value = arguments[valueIndex]
        index = valueIndex + 1
        return value
    }

    private static func waitForMarketEvent(
        collector: Collector,
        timeout: TimeInterval
    ) async -> Bool {
        let start = Date().timeIntervalSince1970
        while Date().timeIntervalSince1970 - start < timeout {
            if await collector.connectionLimitExceeded {
                return false
            }
            if await collector.missingEntitlement {
                return false
            }
            if await collector.hasMarketEvent {
                return true
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }

    private static func render(event: MarketDataStreamEvent) -> String {
        switch event {
        case .connectionStateChanged(let state):
            return "state=\(state.rawValue)"
        case .desiredSubscriptionChanged(let subscriptions):
            return "desired_subscriptions quotes=\(subscriptions.quotes.sorted()) trades=\(subscriptions.trades.sorted()) bars=\(subscriptions.bars.sorted()) option_quotes=\(subscriptions.optionQuotes.sorted()) option_trades=\(subscriptions.optionTrades.sorted()) option_bars=\(subscriptions.optionBars.sorted())"
        case .subscriptionChanged(let subscriptions):
            return "subscriptions quotes=\(subscriptions.quotes.sorted()) trades=\(subscriptions.trades.sorted()) bars=\(subscriptions.bars.sorted()) option_quotes=\(subscriptions.optionQuotes.sorted()) option_trades=\(subscriptions.optionTrades.sorted()) option_bars=\(subscriptions.optionBars.sorted())"
        case .quote(let quote):
            var parts: [String] = ["quote", "instrument=\(quote.instrumentType.shortLabel)", "symbol=\(quote.symbol)"]
            if let bid = quote.bidPrice {
                parts.append("bid=\(bid)")
            }
            if let ask = quote.askPrice {
                parts.append("ask=\(ask)")
            }
            return parts.joined(separator: " ")
        case .trade(let trade):
            var parts: [String] = ["trade", "instrument=\(trade.instrumentType.shortLabel)", "symbol=\(trade.symbol)"]
            if let price = trade.price {
                parts.append("price=\(price)")
            }
            if let size = trade.size {
                parts.append("size=\(size)")
            }
            return parts.joined(separator: " ")
        case .bar(let bar):
            var parts: [String] = ["bar", "instrument=\(bar.instrumentType.shortLabel)", "symbol=\(bar.symbol)"]
            if let close = bar.close {
                parts.append("close=\(close)")
            }
            return parts.joined(separator: " ")
        case .diagnostic(let message):
            return "diagnostic=\(message)"
        }
    }

    private static func printUsage() {
        print("Usage: swift run alpaca_marketdata_smoke [--timeout 30]")
        print("       swift run alpaca_marketdata_smoke --stocks-iex --symbols AAPL,MSFT --timeout 30")
        print("       swift run alpaca_marketdata_smoke --options --symbols AAPL240119C00190000 --timeout 30")
        print("       swift run alpaca_marketdata_smoke --live --stocks-iex --symbols AAPL")
        print("Default mode uses test stream with symbol FAKEPACA.")
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
        case .invalidArguments(let message):
            return message
        case .runtime(let message):
            return message
        }
    }
}
