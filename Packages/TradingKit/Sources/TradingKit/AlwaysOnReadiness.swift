import Foundation

public enum AlwaysOnReadinessStatus: String, Codable, Sendable, Equatable {
    case active
    case recoveringAfterWake = "recovering_after_wake"
    case degraded
    case pausedByHost = "paused_by_host"
    case needsAttention = "needs_attention"

    public var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .recoveringAfterWake:
            return "Recovering after wake"
        case .degraded:
            return "Degraded"
        case .pausedByHost:
            return "Paused by host"
        case .needsAttention:
            return "Needs attention"
        }
    }
}

public enum HostAvailabilityEvent: String, Codable, Sendable, Equatable {
    case engineStart = "engine_start"
    case appBecameActive = "app_became_active"
    case appBecameInactive = "app_became_inactive"
    case appEnteredBackground = "app_entered_background"
    case hostWillSleep = "host_will_sleep"
    case hostDidWake = "host_did_wake"
    case manualRecovery = "manual_recovery"

    public var displayName: String {
        switch self {
        case .engineStart:
            return "engine start"
        case .appBecameActive:
            return "app became active"
        case .appBecameInactive:
            return "app became inactive"
        case .appEnteredBackground:
            return "app entered background"
        case .hostWillSleep:
            return "host will sleep"
        case .hostDidWake:
            return "host wake"
        case .manualRecovery:
            return "manual recovery"
        }
    }
}

public struct AlwaysOnReadinessState: Codable, Sendable, Equatable {
    public var status: AlwaysOnReadinessStatus
    public var summary: String
    public var detail: String
    public var blockers: [String]
    public var lastUpdatedAt: Date
    public var lastLifecycleEvent: HostAvailabilityEvent?
    public var lastRecoveryStartedAt: Date?
    public var lastRecoveryCompletedAt: Date?
    public var lastRecoveryTrigger: HostAvailabilityEvent?

    public init(
        status: AlwaysOnReadinessStatus,
        summary: String,
        detail: String,
        blockers: [String] = [],
        lastUpdatedAt: Date,
        lastLifecycleEvent: HostAvailabilityEvent? = nil,
        lastRecoveryStartedAt: Date? = nil,
        lastRecoveryCompletedAt: Date? = nil,
        lastRecoveryTrigger: HostAvailabilityEvent? = nil
    ) {
        self.status = status
        self.summary = summary
        self.detail = detail
        self.blockers = blockers
        self.lastUpdatedAt = lastUpdatedAt
        self.lastLifecycleEvent = lastLifecycleEvent
        self.lastRecoveryStartedAt = lastRecoveryStartedAt
        self.lastRecoveryCompletedAt = lastRecoveryCompletedAt
        self.lastRecoveryTrigger = lastRecoveryTrigger
    }

    public static func initial(now: Date = Date(timeIntervalSince1970: 0)) -> AlwaysOnReadinessState {
        AlwaysOnReadinessState(
            status: .degraded,
            summary: "Readiness has not been evaluated yet.",
            detail: Self.hostAvailabilityContract,
            lastUpdatedAt: now
        )
    }

    public static let hostAvailabilityContract =
        "Zeroandzero monitors persistently while this Mac is awake, online, and the app is running; sleep, closed-lid suspension, network loss, app quit, or OS suspension can pause active workflows until recovery runs."
}

public struct AlwaysOnReadinessAssessment: Sendable, Equatable {
    public var status: AlwaysOnReadinessStatus
    public var summary: String
    public var detail: String
    public var blockers: [String]

    public init(
        status: AlwaysOnReadinessStatus,
        summary: String,
        detail: String,
        blockers: [String] = []
    ) {
        self.status = status
        self.summary = summary
        self.detail = detail
        self.blockers = blockers
    }
}

public struct MarketDataNoFirstDataRecoveryAssessment: Sendable, Equatable {
    public var shouldRecover: Bool
    public var reason: String?

    public init(shouldRecover: Bool, reason: String? = nil) {
        self.shouldRecover = shouldRecover
        self.reason = reason
    }
}

public func makeMarketDataNoFirstDataRecoveryAssessment(
    desiredMarketData: MarketDataSubscriptionSet,
    activeMarketData: MarketDataSubscriptionSet,
    marketDataConnectionState: String,
    lastMarketDataReceivedAt: Date?,
    lastSubscriptionAcknowledgedAt: Date?,
    now: Date,
    feed: MarketDataFeed,
    lastRecoveryAt: Date?,
    recoveryCount: Int,
    maximumRecoveryCount: Int,
    firstAckGrace: TimeInterval,
    recoveryMinimumInterval: TimeInterval
) -> MarketDataNoFirstDataRecoveryAssessment {
    guard desiredMarketData.isEmpty == false else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }
    guard marketDataConnectionState == MarketDataConnectionState.subscribed.rawValue else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }
    guard desiredMarketData.diff(from: activeMarketData).isEmpty else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }
    guard lastMarketDataReceivedAt == nil else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }
    guard feed == .test || isRegularUSMarketDataRecoveryWindow(now) else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }
    guard recoveryCount < maximumRecoveryCount else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }
    guard let lastSubscriptionAcknowledgedAt else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }

    let ackAge = now.timeIntervalSince(lastSubscriptionAcknowledgedAt)
    guard ackAge >= firstAckGrace else {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }
    if let lastRecoveryAt,
       now.timeIntervalSince(lastRecoveryAt) < recoveryMinimumInterval {
        return MarketDataNoFirstDataRecoveryAssessment(shouldRecover: false)
    }

    return MarketDataNoFirstDataRecoveryAssessment(
        shouldRecover: true,
        reason: "No Store market-data event arrived \(readinessDurationSummary(ackAge)) after active subscription acknowledgement for requested symbols: \(readinessRequestedMarketDataSymbolSummary(desiredMarketData))."
    )
}

public func makeAlwaysOnReadinessAssessment(
    isEngineStarted: Bool,
    alpacaCredentialsReady: Bool,
    snapshot: StoreSnapshot,
    now: Date,
    marketDataStaleAfter: TimeInterval = 15 * 60
) -> AlwaysOnReadinessAssessment {
    var blockers: [String] = []

    if isEngineStarted == false {
        blockers.append("Engine is not running, so active monitoring and recovery workflows are paused.")
    }

    if alpacaCredentialsReady == false {
        blockers.append("Active-environment Alpaca credentials are not ready.")
    }

    if isEngineStarted {
        let tradeReadiness = makeTradeStreamReadinessPresentation(
            connectionState: snapshot.connectionState,
            lastError: snapshot.tradeUpdatesLastError
        )
        if tradeReadiness.isHealthy == false,
           let blocker = tradeReadiness.blocker {
            blockers.append(blocker)
        }
    }

    let desiredMarketData = snapshot.marketDataDesiredSubscriptions
    if isEngineStarted,
       desiredMarketData.isEmpty == false {
        let marketDataReadiness = makeMarketDataStreamReadinessPresentation(
            connectionState: snapshot.marketDataConnectionState,
            desiredMarketData: desiredMarketData,
            activeMarketData: snapshot.marketDataSubscriptions,
            lastMarketDataReceivedAt: snapshot.lastMarketDataReceivedAt,
            now: now,
            lastErrorCode: snapshot.marketDataLastErrorCode,
            lastErrorMessage: snapshot.marketDataLastErrorMessage,
            staleAfter: marketDataStaleAfter
        )
        if marketDataReadiness.isFullyHealthy == false,
           let blocker = marketDataReadiness.blocker {
            blockers.append(blocker)
        }
    }

    if blockers.isEmpty {
        return AlwaysOnReadinessAssessment(
            status: .active,
            summary: "Active while this Mac is awake, online, and the app is running.",
            detail: AlwaysOnReadinessState.hostAvailabilityContract,
            blockers: []
        )
    }

    let status: AlwaysOnReadinessStatus = alpacaCredentialsReady ? .degraded : .needsAttention
    return AlwaysOnReadinessAssessment(
        status: status,
        summary: status == .needsAttention
            ? "Needs attention before active monitoring is healthy."
            : "Monitoring is degraded; recovery has not reached fully healthy app-owned truth.",
        detail: AlwaysOnReadinessState.hostAvailabilityContract,
        blockers: blockers
    )
}

public func isRegularUSMarketDataRecoveryWindow(_ now: Date) -> Bool {
    guard let eastern = TimeZone(identifier: "America/New_York") else {
        return false
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = eastern
    let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
    guard let weekday = components.weekday,
          let hour = components.hour,
          let minute = components.minute,
          (2 ... 6).contains(weekday)
    else {
        return false
    }
    let minuteOfDay = hour * 60 + minute
    return minuteOfDay >= (9 * 60 + 30) && minuteOfDay <= (16 * 60 + 5)
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
    let rounded = max(0, Int(seconds.rounded()))
    if rounded < 60 {
        return "\(rounded)s"
    }
    let minutes = rounded / 60
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
