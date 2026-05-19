import Foundation

public struct TradeStreamReadinessPresentation: Sendable, Equatable {
    public let state: String
    public let label: String
    public let isHealthy: Bool
    public let blocker: String?

    public init(
        state: String,
        label: String,
        isHealthy: Bool,
        blocker: String?
    ) {
        self.state = state
        self.label = label
        self.isHealthy = isHealthy
        self.blocker = blocker
    }
}

public struct MarketDataStreamReadinessPresentation: Sendable, Equatable {
    public let state: String
    public let label: String
    public let isTransportHealthy: Bool
    public let isFullyHealthy: Bool
    public let awaitingFirstData: Bool
    public let outsideRegularUSMarketHours: Bool
    public let blocker: String?

    public init(
        state: String,
        label: String,
        isTransportHealthy: Bool,
        isFullyHealthy: Bool,
        awaitingFirstData: Bool,
        outsideRegularUSMarketHours: Bool,
        blocker: String?
    ) {
        self.state = state
        self.label = label
        self.isTransportHealthy = isTransportHealthy
        self.isFullyHealthy = isFullyHealthy
        self.awaitingFirstData = awaitingFirstData
        self.outsideRegularUSMarketHours = outsideRegularUSMarketHours
        self.blocker = blocker
    }
}

public func makeTradeStreamReadinessPresentation(
    connectionState: String,
    lastError: String? = nil
) -> TradeStreamReadinessPresentation {
    let normalized = connectionState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let sanitizedError = lastError?.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercasedError = sanitizedError?.lowercased() ?? ""
    let hasAuthError = lowercasedError.contains("authorization") ||
        lowercasedError.contains("unauthorized") ||
        lowercasedError.contains("forbidden") ||
        lowercasedError.contains("not authenticated")

    switch normalized {
    case TradeUpdatesConnectionState.subscribed.rawValue:
        return TradeStreamReadinessPresentation(
            state: "listening",
            label: "listening",
            isHealthy: true,
            blocker: nil
        )
    case TradeUpdatesConnectionState.authenticated.rawValue:
        if hasAuthError, let sanitizedError, sanitizedError.isEmpty == false {
            return TradeStreamReadinessPresentation(
                state: "auth_failed",
                label: "auth failed",
                isHealthy: false,
                blocker: "Trade-update stream authentication failed: \(sanitizedError)"
            )
        }
        return TradeStreamReadinessPresentation(
            state: normalized,
            label: "authenticated, not listening",
            isHealthy: false,
            blocker: "Trade-update stream is authenticated but not listening to trade_updates yet."
        )
    case TradeUpdatesConnectionState.connected.rawValue:
        if hasAuthError, let sanitizedError, sanitizedError.isEmpty == false {
            return TradeStreamReadinessPresentation(
                state: "auth_failed",
                label: "auth failed",
                isHealthy: false,
                blocker: "Trade-update stream authentication failed: \(sanitizedError)"
            )
        }
        return TradeStreamReadinessPresentation(
            state: normalized,
            label: "connected, auth pending",
            isHealthy: false,
            blocker: "Trade-update stream is connected but not authenticated yet."
        )
    case TradeUpdatesConnectionState.connecting.rawValue:
        return TradeStreamReadinessPresentation(
            state: normalized,
            label: "connecting",
            isHealthy: false,
            blocker: "Trade-update stream is connecting."
        )
    case TradeUpdatesConnectionState.disconnected.rawValue:
        return TradeStreamReadinessPresentation(
            state: normalized,
            label: "disconnected",
            isHealthy: false,
            blocker: "Trade-update stream is disconnected."
        )
    default:
        return TradeStreamReadinessPresentation(
            state: normalized.isEmpty ? "unknown" : normalized,
            label: normalized.isEmpty ? "unknown" : normalized,
            isHealthy: false,
            blocker: "Trade-update stream state is \(normalized.isEmpty ? "unknown" : normalized)."
        )
    }
}

public func makeMarketDataStreamReadinessPresentation(
    connectionState: String,
    desiredMarketData: MarketDataSubscriptionSet,
    activeMarketData: MarketDataSubscriptionSet,
    lastMarketDataReceivedAt: Date?,
    now: Date,
    lastErrorCode: Int? = nil,
    lastErrorMessage: String? = nil,
    staleAfter: TimeInterval = 15 * 60
) -> MarketDataStreamReadinessPresentation {
    let normalized = connectionState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let outsideRegularHours = isRegularUSMarketDataRecoveryWindow(now) == false
    let sanitizedErrorMessage = lastErrorMessage?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercasedErrorMessage = sanitizedErrorMessage?.lowercased() ?? ""
    let hasFeedAuthError = lastErrorCode == 401 ||
        lastErrorCode == 402 ||
        lastErrorCode == 403 ||
        lastErrorCode == 409 ||
        lowercasedErrorMessage.contains("not authenticated") ||
        lowercasedErrorMessage.contains("auth failed") ||
        lowercasedErrorMessage.contains("unauthorized") ||
        lowercasedErrorMessage.contains("forbidden") ||
        lowercasedErrorMessage.contains("insufficient subscription") ||
        lowercasedErrorMessage.contains("subscription does not permit")
    let hasSubscriptionRequestError = lastErrorCode == 405 ||
        lowercasedErrorMessage.contains("symbol limit exceeded")

    guard desiredMarketData.isEmpty == false else {
        return MarketDataStreamReadinessPresentation(
            state: "idle",
            label: "idle",
            isTransportHealthy: true,
            isFullyHealthy: true,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: nil
        )
    }

    if hasFeedAuthError {
        let codeText = lastErrorCode.map { " code \($0)" } ?? ""
        let messageText = sanitizedErrorMessage.map { ": \($0)" } ?? "."
        return MarketDataStreamReadinessPresentation(
            state: "auth_failed",
            label: "auth failed",
            isTransportHealthy: normalized != MarketDataConnectionState.disconnected.rawValue,
            isFullyHealthy: false,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: "Market-data feed authentication failed\(codeText)\(messageText)"
        )
    }

    if hasSubscriptionRequestError {
        let codeText = lastErrorCode.map { " code \($0)" } ?? ""
        let messageText = sanitizedErrorMessage.map { ": \($0)" } ?? "."
        return MarketDataStreamReadinessPresentation(
            state: "subscription_failed",
            label: "subscription failed",
            isTransportHealthy: normalized != MarketDataConnectionState.disconnected.rawValue,
            isFullyHealthy: false,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: "Market-data subscription request failed\(codeText)\(messageText)"
        )
    }

    switch normalized {
    case MarketDataConnectionState.subscribed.rawValue:
        let missingAcknowledgedCoverage = desiredMarketData.diff(from: activeMarketData)
        if missingAcknowledgedCoverage.isEmpty == false {
            return MarketDataStreamReadinessPresentation(
                state: "subscription_pending",
                label: "subscription pending",
                isTransportHealthy: true,
                isFullyHealthy: false,
                awaitingFirstData: false,
                outsideRegularUSMarketHours: outsideRegularHours,
                blocker: "Market-data stream is subscribed, but some requested subscriptions are not acknowledged yet."
            )
        }
        guard let lastMarketDataReceivedAt else {
            var blocker = "Market-data stream is subscribed and waiting for the first Store market-data event for requested symbols: \(readinessRequestedMarketDataSymbolSummary(desiredMarketData))."
            if outsideRegularHours {
                blocker += " Outside regular US equity market hours, first-event confirmation may require the next market session."
            }
            return MarketDataStreamReadinessPresentation(
                state: "awaiting_first_data",
                label: "awaiting first data",
                isTransportHealthy: true,
                isFullyHealthy: false,
                awaitingFirstData: true,
                outsideRegularUSMarketHours: outsideRegularHours,
                blocker: blocker
            )
        }
        let age = now.timeIntervalSince(lastMarketDataReceivedAt)
        if age > staleAfter {
            return MarketDataStreamReadinessPresentation(
                state: "stale",
                label: "stale",
                isTransportHealthy: true,
                isFullyHealthy: false,
                awaitingFirstData: false,
                outsideRegularUSMarketHours: outsideRegularHours,
                blocker: "Last market-data event is stale (\(readinessDurationSummary(age)) old)."
            )
        }
        return MarketDataStreamReadinessPresentation(
            state: "healthy",
            label: "healthy",
            isTransportHealthy: true,
            isFullyHealthy: true,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: nil
        )
    case MarketDataConnectionState.authenticated.rawValue:
        return MarketDataStreamReadinessPresentation(
            state: normalized,
            label: "authenticated, subscription pending",
            isTransportHealthy: true,
            isFullyHealthy: false,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: "Market-data stream is authenticated, but requested subscriptions are not acknowledged yet."
        )
    case MarketDataConnectionState.connected.rawValue:
        return MarketDataStreamReadinessPresentation(
            state: normalized,
            label: "connected, auth pending",
            isTransportHealthy: true,
            isFullyHealthy: false,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: "Market-data stream is connected, but feed authentication has not completed."
        )
    case MarketDataConnectionState.connecting.rawValue:
        return MarketDataStreamReadinessPresentation(
            state: normalized,
            label: "connecting",
            isTransportHealthy: false,
            isFullyHealthy: false,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: "Market-data stream is connecting."
        )
    case MarketDataConnectionState.disconnected.rawValue:
        return MarketDataStreamReadinessPresentation(
            state: normalized,
            label: "disconnected",
            isTransportHealthy: false,
            isFullyHealthy: false,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: "Market-data stream is disconnected while symbols are requested."
        )
    default:
        return MarketDataStreamReadinessPresentation(
            state: normalized.isEmpty ? "unknown" : normalized,
            label: normalized.isEmpty ? "unknown" : normalized,
            isTransportHealthy: false,
            isFullyHealthy: false,
            awaitingFirstData: false,
            outsideRegularUSMarketHours: outsideRegularHours,
            blocker: "Market-data stream state is \(normalized.isEmpty ? "unknown" : normalized) while symbols are requested."
        )
    }
}

private func readinessRequestedMarketDataSymbolSummary(
    _ subscriptions: MarketDataSubscriptionSet
) -> String {
    let symbols = subscriptions.quotes
        .union(subscriptions.trades)
        .union(subscriptions.bars)
        .sorted()
    guard symbols.isEmpty == false else { return "none" }
    let visible = symbols.prefix(8).joined(separator: ", ")
    let remaining = symbols.count - min(symbols.count, 8)
    if remaining > 0 {
        return "\(visible), +\(remaining) more"
    }
    return visible
}

private func readinessDurationSummary(_ seconds: TimeInterval) -> String {
    let bounded = max(0, Int(seconds.rounded()))
    if bounded < 60 {
        return "\(bounded)s"
    }
    let minutes = bounded / 60
    if minutes < 60 {
        return "\(minutes)m"
    }
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    if remainingMinutes == 0 {
        return "\(hours)h"
    }
    return "\(hours)h \(remainingMinutes)m"
}
