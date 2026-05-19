import Foundation

public enum AlpacaMarketDataCodec {
    public static func decodeMessages(from data: Data) -> [MarketDataInboundMessage] {
        guard !data.isEmpty else {
            return [.unknown(description: "Empty market-data payload")]
        }

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            return [.unknown(description: "Unable to decode market-data JSON payload")]
        }

        let objects: [[String: Any]]
        if let array = parsed as? [[String: Any]] {
            objects = array
        } else if let object = parsed as? [String: Any] {
            objects = [object]
        } else {
            return [.unknown(description: "Unsupported market-data JSON shape")]
        }

        var messages: [MarketDataInboundMessage] = []
        for object in objects {
            messages.append(decode(object: object))
        }
        return messages
    }

    private static func decode(object: [String: Any]) -> MarketDataInboundMessage {
        let type = (stringValue(object["T"]) ?? stringValue(object["t"]) ?? "").lowercased()

        switch type {
        case "success":
            return .success(message: stringValue(object["msg"]) ?? "success")
        case "error", "subscription_error":
            let code = intValue(object["code"])
            return .error(code: code, message: stringValue(object["msg"]) ?? "stream error")
        case "subscription":
            return .subscription(
                MarketDataSubscriptionSet(
                    quotes: setValue(object["quotes"]),
                    trades: setValue(object["trades"]),
                    bars: setValue(object["bars"]),
                    optionQuotes: setValue(
                        object["option_quotes"] ??
                            object["options_quotes"] ??
                            object["optionsQuotes"]
                    ),
                    optionTrades: setValue(
                        object["option_trades"] ??
                            object["options_trades"] ??
                            object["optionsTrades"]
                    ),
                    optionBars: setValue(
                        object["option_bars"] ??
                            object["options_bars"] ??
                            object["optionsBars"]
                    )
                )
            )
        case "q", "oq":
            guard let symbol = normalizedSymbol(object["S"]) else {
                return .unknown(description: "Quote payload missing symbol")
            }
            let instrumentType: InstrumentType = (type == "oq")
                ? .option
                : MarketSymbolClassifier.instrumentType(for: symbol)
            return .quote(
                MarketDataQuoteEvent(
                    symbol: symbol,
                    instrumentType: instrumentType,
                    bidPrice: doubleValue(object["bp"]),
                    askPrice: doubleValue(object["ap"]),
                    bidSize: doubleValue(object["bs"]),
                    askSize: doubleValue(object["as"]),
                    timestamp: stringValue(object["t"])
                )
            )
        case "t", "ot":
            guard let symbol = normalizedSymbol(object["S"]) else {
                return .unknown(description: "Trade payload missing symbol")
            }
            let instrumentType: InstrumentType = (type == "ot")
                ? .option
                : MarketSymbolClassifier.instrumentType(for: symbol)
            return .trade(
                MarketDataTradeEvent(
                    symbol: symbol,
                    instrumentType: instrumentType,
                    price: doubleValue(object["p"]),
                    size: doubleValue(object["s"]),
                    timestamp: stringValue(object["t"])
                )
            )
        case "b", "ob":
            guard let symbol = normalizedSymbol(object["S"]) else {
                return .unknown(description: "Bar payload missing symbol")
            }
            let instrumentType: InstrumentType = (type == "ob")
                ? .option
                : MarketSymbolClassifier.instrumentType(for: symbol)
            return .bar(
                MarketDataBarEvent(
                    symbol: symbol,
                    instrumentType: instrumentType,
                    open: doubleValue(object["o"]),
                    high: doubleValue(object["h"]),
                    low: doubleValue(object["l"]),
                    close: doubleValue(object["c"]),
                    volume: doubleValue(object["v"]),
                    timestamp: stringValue(object["t"])
                )
            )
        default:
            return .unknown(description: "Unhandled market-data type: \(type)")
        }
    }

    private static func normalizedSymbol(_ value: Any?) -> String? {
        let symbol = stringValue(value)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let symbol, !symbol.isEmpty else {
            return nil
        }
        return symbol
    }

    private static func setValue(_ value: Any?) -> Set<String> {
        if let raw = value as? [String] {
            return MarketDataSubscriptionSet.normalized(raw)
        }
        if let raw = value as? [Any] {
            return MarketDataSubscriptionSet.normalized(
                Set(raw.compactMap { stringValue($0) })
            )
        }
        return []
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = stringValue(value), let parsed = Int(string) {
            return parsed
        }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = stringValue(value), let parsed = Double(string) {
            return parsed
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String {
            return value
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}
