import Darwin
import Foundation
import TradingKit

private struct SmokeOptions {
    var environment: Environment = .paper
    var placeSymbol: String?
    var qty: String = "1"
    var side: OrderSide = .buy
    var type: OrderType = .market
    var limitPrice: String?
}

@main
struct AlpacaSmoke {
    static func main() async {
        let exitCode = await run()
        Darwin.exit(Int32(exitCode))
    }

    private static func run() async -> Int {
        do {
            let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            let keychainProvider = KeychainCredentialsProvider()

            guard keychainProvider.credentials(for: options.environment) != nil else {
                fputs("Missing Keychain credentials for environment: \(options.environment.rawValue).\n", stderr)
                return 2
            }

            let client = AlpacaRESTClient(
                environment: options.environment,
                keychainProvider: keychainProvider
            )

            let account = try await client.fetchAccount()
            printAccountSummary(account)

            if let symbol = options.placeSymbol {
                guard options.environment == .paper else {
                    fputs("Test order placement is disabled for live mode.\n", stderr)
                    return 2
                }

                let request = NewOrderRequest(
                    symbol: symbol,
                    qty: options.qty,
                    side: options.side,
                    type: options.type,
                    timeInForce: .day,
                    limitPrice: options.limitPrice
                )

                let order = try await client.placeOrder(request: request)
                print("Placed paper test order: id=\(order.id) symbol=\(order.symbol ?? symbol) status=\(order.status ?? "unknown")")

                let openOrders = try await client.fetchOpenOrders()
                if openOrders.contains(where: { $0.id == order.id }) {
                    try await client.cancelOrder(orderId: order.id)
                    print("Canceled test order: id=\(order.id)")
                }
            }

            return 0
        } catch {
            if case SmokeExit.normal = error {
                return 0
            }
            fputs("alpaca_smoke failed: \(render(error: error))\n", stderr)
            return 1
        }
    }

    private static func parseOptions(arguments: [String]) throws -> SmokeOptions {
        var options = SmokeOptions()
        var index = 0

        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--help", "-h":
                printUsage()
                throw SmokeExit.normal
            case "--live":
                options.environment = .live
                index += 1
            case "--place-test-order":
                options.placeSymbol = try value(for: arg, arguments: arguments, index: &index)
            case "--qty":
                options.qty = try value(for: arg, arguments: arguments, index: &index)
            case "--side":
                let raw = try value(for: arg, arguments: arguments, index: &index)
                guard let side = OrderSide(rawValue: raw.lowercased()) else {
                    throw SmokeExit.invalidArguments("Invalid --side value: \(raw). Use buy or sell.")
                }
                options.side = side
            case "--type":
                let raw = try value(for: arg, arguments: arguments, index: &index)
                guard let type = OrderType(rawValue: raw.lowercased()) else {
                    throw SmokeExit.invalidArguments("Invalid --type value: \(raw).")
                }
                options.type = type
            case "--limit-price":
                options.limitPrice = try value(for: arg, arguments: arguments, index: &index)
            default:
                throw SmokeExit.invalidArguments("Unknown argument: \(arg)")
            }
        }

        if options.type == .limit && options.limitPrice == nil {
            throw SmokeExit.invalidArguments("--limit-price is required when --type limit is used.")
        }

        return options
    }

    private static func value(for flag: String, arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw SmokeExit.invalidArguments("Missing value for \(flag)")
        }
        let value = arguments[valueIndex]
        index = valueIndex + 1
        return value
    }

    private static func printAccountSummary(_ account: Account) {
        print("Environment account summary")
        print("id: \(account.id)")
        print("status: \(account.status ?? "unknown")")
        print("buying_power: \(account.buyingPower ?? "n/a")")
        print("cash: \(account.cash ?? "n/a")")
    }

    private static func printUsage() {
        print("Usage: swift run alpaca_smoke [--live] [--place-test-order SYMBOL --qty QTY --side buy|sell --type market|limit [--limit-price PRICE]]")
    }

    private static func render(error: Error) -> String {
        if let smokeExit = error as? SmokeExit {
            switch smokeExit {
            case .normal:
                return "finished"
            case .invalidArguments(let message):
                return message
            }
        }

        if let apiError = error as? AlpacaAPIError {
            switch apiError {
            case .missingCredentials(let environment):
                return "Missing credentials for environment: \(environment.rawValue)."
            case .localRateLimited(let retryAfter):
                return "Local rate limiter throttled request. retry_after=\(String(format: "%.2f", retryAfter))s"
            case .rateLimited(let status, let message, let requestID, _):
                return "HTTP \(status) rate-limited. message=\(message ?? "n/a") request_id=\(requestID ?? "n/a")"
            case .requestFailed(let status, let message, let requestID):
                return "HTTP \(status). message=\(message ?? "n/a") request_id=\(requestID ?? "n/a")"
            case .replaceRejected(let status, let message, let requestID):
                return "Replace rejected HTTP \(status). message=\(message ?? "n/a") request_id=\(requestID ?? "n/a")"
            case .decodingFailed(let status, let message, let requestID):
                return "Decoding failure. status=\(status.map(String.init) ?? "n/a") message=\(message ?? "n/a") request_id=\(requestID ?? "n/a")"
            case .transportFailure(let message):
                return "Transport failure: \(message)"
            }
        }

        return error.localizedDescription
    }
}

private enum SmokeExit: Error {
    case normal
    case invalidArguments(String)
}
