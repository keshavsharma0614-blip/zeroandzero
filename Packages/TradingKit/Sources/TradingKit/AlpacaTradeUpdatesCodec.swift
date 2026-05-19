import Foundation

public enum AlpacaTradeUpdatesCodec {
    public static func decodeMessages(from data: Data) -> [TradeUpdatesInboundMessage] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let envelopes = try? decoder.decode([Envelope].self, from: data) {
            return envelopes.flatMap(decodeEnvelope)
        }
        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            return decodeEnvelope(envelope)
        }
        return [.unknown(description: "Unable to decode websocket payload.")]
    }

    private static func decodeEnvelope(_ envelope: Envelope) -> [TradeUpdatesInboundMessage] {
        if let t = envelope.t?.lowercased(), t == "error" || t == "subscription_error" {
            return [.error(message: envelope.msg ?? "Stream error")]
        }
        if let t = envelope.t?.lowercased(), t == "success" {
            return [.success(message: envelope.msg ?? "success")]
        }

        switch envelope.stream?.lowercased() {
        case "authorization":
            if let status = envelope.data?.status {
                return [.authorization(status: status)]
            }
        case "listening":
            return [.listening(streams: envelope.data?.streams ?? [])]
        case "trade_updates":
            guard let data = envelope.data,
                  let eventName = data.event,
                  let order = data.order,
                  let orderID = order.id
            else {
                return [.unknown(description: "trade_updates payload missing required fields.")]
            }
            let update = TradeUpdateEvent(
                event: eventName,
                orderID: orderID,
                symbol: order.symbol,
                assetClass: order.assetClass,
                underlyingSymbol: order.underlyingSymbol,
                side: order.side,
                qty: order.qty,
                filledQty: order.filledQty,
                filledAvgPrice: order.filledAvgPrice,
                timestamp: data.timestamp,
                orderStatus: order.status
            )
            return [.tradeUpdate(update)]
        default:
            break
        }

        if let status = envelope.data?.status {
            return [.authorization(status: status)]
        }
        if let msg = envelope.msg {
            return [.success(message: msg)]
        }
        return [.unknown(description: "Unhandled websocket message shape.")]
    }
}

private struct Envelope: Decodable {
    let stream: String?
    let data: EnvelopeData?
    let t: String?
    let msg: String?
    let message: String?
}

private struct EnvelopeData: Decodable {
    let status: String?
    let action: String?
    let streams: [String]?
    let event: String?
    let timestamp: String?
    let order: OrderData?
}

private struct OrderData: Decodable {
    let id: String?
    let symbol: String?
    let assetClass: String?
    let underlyingSymbol: String?
    let side: String?
    let qty: String?
    let filledQty: String?
    let filledAvgPrice: String?
    let status: String?
}
