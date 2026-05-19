import Foundation

public struct StoreEvent: Sendable, Equatable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct StoreEventStreamDiagnostics: Sendable, Equatable {
    public var bufferLimit: Int
    public var yieldedCount: Int
    public var enqueuedCount: Int
    public var droppedCount: Int
    public var terminatedYieldCount: Int
    public var lastDroppedEventName: String?
    public var droppedEventCountsByName: [String: Int]
    public var marketDataRawUpdateCount: Int
    public var marketDataRawUpdateCountsByName: [String: Int]
    public var marketDataUIInvalidationYieldCount: Int
    public var marketDataUIInvalidationCoalescedCount: Int
    public var marketDataUIInvalidationDroppedCount: Int

    public init(
        bufferLimit: Int = 0,
        yieldedCount: Int = 0,
        enqueuedCount: Int = 0,
        droppedCount: Int = 0,
        terminatedYieldCount: Int = 0,
        lastDroppedEventName: String? = nil,
        droppedEventCountsByName: [String: Int] = [:],
        marketDataRawUpdateCount: Int = 0,
        marketDataRawUpdateCountsByName: [String: Int] = [:],
        marketDataUIInvalidationYieldCount: Int = 0,
        marketDataUIInvalidationCoalescedCount: Int = 0,
        marketDataUIInvalidationDroppedCount: Int = 0
    ) {
        self.bufferLimit = bufferLimit
        self.yieldedCount = yieldedCount
        self.enqueuedCount = enqueuedCount
        self.droppedCount = droppedCount
        self.terminatedYieldCount = terminatedYieldCount
        self.lastDroppedEventName = lastDroppedEventName
        self.droppedEventCountsByName = droppedEventCountsByName
        self.marketDataRawUpdateCount = marketDataRawUpdateCount
        self.marketDataRawUpdateCountsByName = marketDataRawUpdateCountsByName
        self.marketDataUIInvalidationYieldCount = marketDataUIInvalidationYieldCount
        self.marketDataUIInvalidationCoalescedCount = marketDataUIInvalidationCoalescedCount
        self.marketDataUIInvalidationDroppedCount = marketDataUIInvalidationDroppedCount
    }
}

public struct AccountSummary: Sendable, Equatable {
    public var id: String
    public var status: String
    public var buyingPower: String
    public var cash: String
    public var equity: String
    public var canShortSellEquities: Bool

    public init(
        id: String,
        status: String,
        buyingPower: String,
        cash: String,
        equity: String,
        canShortSellEquities: Bool
    ) {
        self.id = id
        self.status = status
        self.buyingPower = buyingPower
        self.cash = cash
        self.equity = equity
        self.canShortSellEquities = canShortSellEquities
    }

    public var displayLine: String {
        "Account status=\(status) equity=\(equity) buying_power=\(buyingPower) cash=\(cash)"
    }
}

public struct PositionRow: Sendable, Equatable, Identifiable {
    public let id: String
    public var symbol: String
    public var side: String
    public var qty: String
    public var marketValue: String

    public init(
        id: String,
        symbol: String,
        side: String,
        qty: String,
        marketValue: String
    ) {
        self.id = id
        self.symbol = symbol
        self.side = side
        self.qty = qty
        self.marketValue = marketValue
    }

    public var isShort: Bool {
        if let value = decimal(qty), value < 0 {
            return true
        }
        return side.lowercased() == "short"
    }

    public var directionLabel: String {
        isShort ? "SHORT" : "LONG"
    }

    private func decimal(_ raw: String) -> Decimal? {
        Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
    }
}

public struct OrderRow: Sendable, Equatable, Identifiable {
    public let id: String
    public var instrumentType: InstrumentType
    public var symbol: String
    public var underlyingSymbol: String?
    public var side: String
    public var qty: String
    public var filledQty: String
    public var orderType: String?
    public var limitPrice: String?
    public var status: String
    public var updatedAt: String?
    public var isOpen: Bool

    public init(
        id: String,
        instrumentType: InstrumentType = .equity,
        symbol: String,
        underlyingSymbol: String? = nil,
        side: String,
        qty: String,
        filledQty: String = "0",
        orderType: String? = nil,
        limitPrice: String? = nil,
        status: String,
        updatedAt: String? = nil,
        isOpen: Bool
    ) {
        self.id = id
        self.instrumentType = instrumentType
        self.symbol = symbol
        self.underlyingSymbol = underlyingSymbol
        self.side = side
        self.qty = qty
        self.filledQty = filledQty
        self.orderType = orderType
        self.limitPrice = limitPrice
        self.status = status
        self.updatedAt = updatedAt
        self.isOpen = isOpen
    }

    public var shortID: String {
        String(id.prefix(8))
    }

    public var displayedSymbol: String {
        symbol
    }

    public var instrumentLabel: String {
        instrumentType.shortLabel
    }

    public var canCancel: Bool {
        isOpen
    }

    public var canReplace: Bool {
        isOpen && instrumentType == .equity
    }
}

public struct StoreSnapshot: Sendable, Equatable {
    public var build: String
    public var lastEventName: String?
    public var isLive: Bool
    public var isArmedForLiveTrading: Bool
    public var armingSessionID: String?
    public var killSwitchEnabled: Bool
    public var accountSummary: AccountSummary?
    public var positions: [PositionRow]
    public var ordersByID: [String: OrderRow]
    public var openOrders: [OrderRow]
    public var watchlistSymbols: [String]
    public var marketDataDesiredSubscriptions: MarketDataSubscriptionSet
    public var marketDataSubscriptions: MarketDataSubscriptionSet
    public var quotesBySymbol: [String: MarketQuote]
    public var optionQuotesBySymbol: [String: MarketQuote]
    public var auditLines: [String]
    public var structuredAuditEvents: [AuditEvent]
    public var lastTradeUpdateSummary: String?
    public var lastMarketDataSummary: String?
    public var lastOptionsMarketDataSummary: String?
    public var lastMarketDataReceivedAt: Date?
    public var lastMarketDataReceivedSymbol: String?
    public var connectionState: String
    public var marketDataConnectionState: String
    public var tradeUpdatesLastDiagnostic: String?
    public var tradeUpdatesLastError: String?
    public var marketDataLastDiagnostic: String?
    public var marketDataLastErrorCode: Int?
    public var marketDataLastErrorMessage: String?
    public var alwaysOnReadiness: AlwaysOnReadinessState
    public var strategies: [StrategyStatusSnapshot]
    public var jobs: [JobSummary]
    public var schedules: [ScheduledJobSummary]
    public var notifications: [JobNotification]
    public var rssFeedSummary: RSSFeedSummary
    public var recentNews: [NewsEvent]
    public var signals: [Signal]
    public var newsIngestStatus: NewsIngestStatus
    public var ipcStatus: IPCServerStatus
    public var proposals: [ProposalRow]
    public var proposalRunSummariesByProposalID: [String: [PaperRunRecordSummary]]
    public var eventStreamDiagnostics: StoreEventStreamDiagnostics

    public init(
        build: String,
        lastEventName: String? = nil,
        isLive: Bool = false,
        isArmedForLiveTrading: Bool = false,
        armingSessionID: String? = nil,
        killSwitchEnabled: Bool = false,
        accountSummary: AccountSummary? = nil,
        positions: [PositionRow] = [],
        ordersByID: [String: OrderRow] = [:],
        openOrders: [OrderRow] = [],
        watchlistSymbols: [String] = [],
        marketDataDesiredSubscriptions: MarketDataSubscriptionSet = .empty,
        marketDataSubscriptions: MarketDataSubscriptionSet = .empty,
        quotesBySymbol: [String: MarketQuote] = [:],
        optionQuotesBySymbol: [String: MarketQuote] = [:],
        auditLines: [String] = [],
        structuredAuditEvents: [AuditEvent] = [],
        lastTradeUpdateSummary: String? = nil,
        lastMarketDataSummary: String? = nil,
        lastOptionsMarketDataSummary: String? = nil,
        lastMarketDataReceivedAt: Date? = nil,
        lastMarketDataReceivedSymbol: String? = nil,
        connectionState: String = TradeUpdatesConnectionState.disconnected.rawValue,
        marketDataConnectionState: String = MarketDataConnectionState.disconnected.rawValue,
        tradeUpdatesLastDiagnostic: String? = nil,
        tradeUpdatesLastError: String? = nil,
        marketDataLastDiagnostic: String? = nil,
        marketDataLastErrorCode: Int? = nil,
        marketDataLastErrorMessage: String? = nil,
        alwaysOnReadiness: AlwaysOnReadinessState = .initial(),
        strategies: [StrategyStatusSnapshot] = [],
        jobs: [JobSummary] = [],
        schedules: [ScheduledJobSummary] = [],
        notifications: [JobNotification] = [],
        rssFeedSummary: RSSFeedSummary = RSSFeedSummary(),
        recentNews: [NewsEvent] = [],
        signals: [Signal] = [],
        newsIngestStatus: NewsIngestStatus = NewsIngestStatus(),
        ipcStatus: IPCServerStatus = .stopped(),
        proposals: [ProposalRow] = [],
        proposalRunSummariesByProposalID: [String: [PaperRunRecordSummary]] = [:],
        eventStreamDiagnostics: StoreEventStreamDiagnostics = StoreEventStreamDiagnostics()
    ) {
        self.build = build
        self.lastEventName = lastEventName
        self.isLive = isLive
        self.isArmedForLiveTrading = isArmedForLiveTrading
        self.armingSessionID = armingSessionID
        self.killSwitchEnabled = killSwitchEnabled
        self.accountSummary = accountSummary
        self.positions = positions
        self.ordersByID = ordersByID
        self.openOrders = openOrders
        self.watchlistSymbols = watchlistSymbols
        self.marketDataDesiredSubscriptions = marketDataDesiredSubscriptions
        self.marketDataSubscriptions = marketDataSubscriptions
        self.quotesBySymbol = quotesBySymbol
        self.optionQuotesBySymbol = optionQuotesBySymbol
        self.auditLines = auditLines
        self.structuredAuditEvents = structuredAuditEvents
        self.lastTradeUpdateSummary = lastTradeUpdateSummary
        self.lastMarketDataSummary = lastMarketDataSummary
        self.lastOptionsMarketDataSummary = lastOptionsMarketDataSummary
        self.lastMarketDataReceivedAt = lastMarketDataReceivedAt
        self.lastMarketDataReceivedSymbol = lastMarketDataReceivedSymbol
        self.connectionState = connectionState
        self.marketDataConnectionState = marketDataConnectionState
        self.tradeUpdatesLastDiagnostic = tradeUpdatesLastDiagnostic
        self.tradeUpdatesLastError = tradeUpdatesLastError
        self.marketDataLastDiagnostic = marketDataLastDiagnostic
        self.marketDataLastErrorCode = marketDataLastErrorCode
        self.marketDataLastErrorMessage = marketDataLastErrorMessage
        self.alwaysOnReadiness = alwaysOnReadiness
        self.strategies = strategies
        self.jobs = jobs
        self.schedules = schedules
        self.notifications = notifications
        self.rssFeedSummary = rssFeedSummary
        self.recentNews = recentNews
        self.signals = signals
        self.newsIngestStatus = newsIngestStatus
        self.ipcStatus = ipcStatus
        self.proposals = proposals
        self.proposalRunSummariesByProposalID = proposalRunSummariesByProposalID
        self.eventStreamDiagnostics = eventStreamDiagnostics
    }

    public var tradingEnabled: Bool {
        if !isLive {
            return true
        }
        return isArmedForLiveTrading && !killSwitchEnabled
    }
}

public actor Store {
    public nonisolated let events: AsyncStream<StoreEvent>

    private let continuation: AsyncStream<StoreEvent>.Continuation
    private var snapshotValue: StoreSnapshot
    private let auditLineCap: Int
    private let structuredAuditCap: Int
    private let notificationCap: Int
    private let eventBufferLimit: Int
    private var eventStreamDiagnostics: StoreEventStreamDiagnostics
    private var marketDataUIInvalidationPending = false
    private var auditSink: (any AuditEventPersisting)?
    private let now: @Sendable () -> Date

    public init(
        initialBuild: String = Engine.buildInfo,
        auditLineCap: Int = 400,
        structuredAuditCap: Int = 200,
        notificationCap: Int = 100,
        eventBufferLimit: Int = 4096,
        auditSink: (any AuditEventPersisting)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let boundedEventBufferLimit = max(1, eventBufferLimit)
        var createdContinuation: AsyncStream<StoreEvent>.Continuation?
        self.events = AsyncStream(
            StoreEvent.self,
            bufferingPolicy: .bufferingNewest(boundedEventBufferLimit)
        ) { continuation in
            createdContinuation = continuation
        }
        guard let createdContinuation else {
            fatalError("Failed to initialize store event stream continuation.")
        }
        self.continuation = createdContinuation
        self.snapshotValue = StoreSnapshot(build: initialBuild)
        self.auditLineCap = max(10, auditLineCap)
        self.structuredAuditCap = max(10, structuredAuditCap)
        self.notificationCap = max(10, notificationCap)
        self.eventBufferLimit = boundedEventBufferLimit
        self.eventStreamDiagnostics = StoreEventStreamDiagnostics(bufferLimit: boundedEventBufferLimit)
        self.auditSink = auditSink
        self.now = now
    }

    deinit {
        continuation.finish()
    }

    public func publish(_ event: StoreEvent) {
        yieldEvent(event)
    }

    public func applyStartupSnapshot(
        account: Account,
        positions: [Position],
        openOrders: [Order]
    ) {
        snapshotValue.lastEventName = "startup_reconciliation"
        snapshotValue.accountSummary = map(account: account)
        snapshotValue.positions = positions.map(map(position:))
        snapshotValue.ordersByID = Dictionary(
            uniqueKeysWithValues: openOrders.map { order in
                let row = map(order: order)
                return (row.id, row)
            }
        )
        refreshOpenOrders()

        appendAudit("startup reconciliation account_status=\(account.status ?? "unknown") positions=\(positions.count) open_orders=\(openOrders.count)")
        yieldEvent(named: "startup_reconciliation")
    }

    public func applyPositionsRefreshSnapshot(
        positions: [Position],
        account: Account? = nil
    ) {
        snapshotValue.lastEventName = "positions_refresh"
        if let account {
            snapshotValue.accountSummary = map(account: account)
        }
        snapshotValue.positions = positions.map(map(position:))
        yieldEvent(named: "positions_refresh")
    }

    public func reconcileOpenOrdersSnapshot(_ openOrders: [Order]) {
        snapshotValue.lastEventName = "open_orders_refresh"

        var openOrderIDs = Set<String>()
        for order in openOrders {
            let row = map(order: order)
            openOrderIDs.insert(row.id)
            snapshotValue.ordersByID[row.id] = row
        }

        let existingIDs = Array(snapshotValue.ordersByID.keys)
        for orderID in existingIDs where !openOrderIDs.contains(orderID) {
            guard var existing = snapshotValue.ordersByID[orderID],
                  existing.isOpen
            else {
                continue
            }

            existing.isOpen = false
            if isOpenStatus(existing.status) {
                existing.status = "closed"
            }
            snapshotValue.ordersByID[orderID] = existing
        }

        refreshOpenOrders()
        yieldEvent(named: "open_orders_refresh")
    }

    public func recordSubmittedOrder(_ order: Order) {
        snapshotValue.lastEventName = "order_submitted"
        let row = map(order: order)
        snapshotValue.ordersByID[row.id] = row
        refreshOpenOrders()
        yieldEvent(named: "order_submitted")
    }

    public func setConnectionState(_ state: TradeUpdatesConnectionState) {
        snapshotValue.lastEventName = "connection_state"
        snapshotValue.connectionState = state.rawValue
        yieldEvent(named: "connection_state")
    }

    public func setTradingSafetyState(
        isLive: Bool,
        isArmedForLiveTrading: Bool,
        armingSessionID: String?,
        killSwitchEnabled: Bool
    ) {
        snapshotValue.lastEventName = "trading_safety_state"
        snapshotValue.isLive = isLive
        snapshotValue.isArmedForLiveTrading = isArmedForLiveTrading
        snapshotValue.armingSessionID = armingSessionID
        snapshotValue.killSwitchEnabled = killSwitchEnabled
        yieldEvent(named: "trading_safety_state")
    }

    public func setWatchlistSymbols(_ symbols: [String]) {
        snapshotValue.lastEventName = "watchlist_updated"
        snapshotValue.watchlistSymbols = Array(MarketDataSubscriptionSet.normalized(symbols)).sorted()
        yieldEvent(named: "watchlist_updated")
    }

    public func setMarketDataConnectionState(_ state: MarketDataConnectionState) {
        snapshotValue.lastEventName = "market_data_connection_state"
        snapshotValue.marketDataConnectionState = state.rawValue
        yieldEvent(named: "market_data_connection_state")
    }

    public func setStreamRuntimeDiagnostics(
        tradeUpdatesLastDiagnostic: String?,
        tradeUpdatesLastError: String?,
        marketDataLastDiagnostic: String?,
        marketDataLastErrorCode: Int?,
        marketDataLastErrorMessage: String?
    ) {
        snapshotValue.lastEventName = "stream_runtime_diagnostics"
        snapshotValue.tradeUpdatesLastDiagnostic = tradeUpdatesLastDiagnostic
        snapshotValue.tradeUpdatesLastError = tradeUpdatesLastError
        snapshotValue.marketDataLastDiagnostic = marketDataLastDiagnostic
        snapshotValue.marketDataLastErrorCode = marketDataLastErrorCode
        snapshotValue.marketDataLastErrorMessage = marketDataLastErrorMessage
        yieldEvent(named: "stream_runtime_diagnostics")
    }

    public func setAlwaysOnReadiness(_ readiness: AlwaysOnReadinessState) {
        snapshotValue.lastEventName = "always_on_readiness"
        snapshotValue.alwaysOnReadiness = readiness
        yieldEvent(named: "always_on_readiness")
    }

    public func setStrategyStatuses(_ statuses: [StrategyStatusSnapshot]) {
        snapshotValue.lastEventName = "strategy_statuses"
        snapshotValue.strategies = statuses.sorted { lhs, rhs in lhs.id < rhs.id }
        yieldEvent(named: "strategy_statuses")
    }

    public func setJobs(_ jobs: [JobSummary]) {
        let sortedJobs = jobs.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.jobId < rhs.jobId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        guard snapshotValue.jobs != sortedJobs else {
            return
        }
        snapshotValue.lastEventName = "jobs"
        snapshotValue.jobs = sortedJobs
        yieldEvent(named: "jobs")
    }

    public func setSchedules(_ schedules: [ScheduledJobSummary]) {
        snapshotValue.lastEventName = "schedules"
        snapshotValue.schedules = schedules.sorted { lhs, rhs in
            if lhs.jobType == rhs.jobType {
                return lhs.scheduleId < rhs.scheduleId
            }
            return lhs.jobType.rawValue < rhs.jobType.rawValue
        }
        yieldEvent(named: "schedules")
    }

    public func setRSSFeeds(
        _ feeds: [RSSFeed],
        lastPollStatus: String? = nil
    ) {
        snapshotValue.lastEventName = "rss_feeds"
        let enabled = feeds.filter(\.enabled).count
        let disabled = max(0, feeds.count - enabled)
        snapshotValue.rssFeedSummary = RSSFeedSummary(
            enabledCount: enabled,
            disabledCount: disabled,
            lastPollStatus: lastPollStatus ?? snapshotValue.rssFeedSummary.lastPollStatus
        )
        yieldEvent(named: "rss_feeds")
    }

    public func setRecentNews(_ events: [NewsEvent]) {
        let sorted = events.sorted { lhs, rhs in
            if lhs.publishedAt == rhs.publishedAt {
                return lhs.eventId > rhs.eventId
            }
            return lhs.publishedAt > rhs.publishedAt
        }
        guard snapshotValue.recentNews != sorted else {
            return
        }
        snapshotValue.lastEventName = "news_events"
        snapshotValue.recentNews = sorted
        yieldEvent(named: "news_events")
    }

    public func setNewsIngestStatus(_ status: NewsIngestStatus) {
        snapshotValue.lastEventName = "news_ingest_status"
        snapshotValue.newsIngestStatus = status
        yieldEvent(named: "news_ingest_status")
    }

    public func setSignals(_ signals: [Signal]) {
        snapshotValue.lastEventName = "signals"
        snapshotValue.signals = signals.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.signalId < rhs.signalId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        yieldEvent(named: "signals")
    }

    public func setIPCStatus(_ status: IPCServerStatus) {
        snapshotValue.lastEventName = "ipc_status"
        snapshotValue.ipcStatus = status
        yieldEvent(named: "ipc_status")
    }

    public func setProposals(_ proposals: [ProposalRow]) {
        snapshotValue.lastEventName = "proposals"
        snapshotValue.proposals = proposals.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.id < rhs.id
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        yieldEvent(named: "proposals")
    }

    public func setProposalRuns(
        proposalID: String,
        runs: [PaperRunRecordSummary]
    ) {
        snapshotValue.lastEventName = "proposal_runs"
        snapshotValue.proposalRunSummariesByProposalID[proposalID] = runs.sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt {
                return lhs.runId < rhs.runId
            }
            return lhs.startedAt > rhs.startedAt
        }
        yieldEvent(named: "proposal_runs")
    }

    public func setAuditSink(_ sink: (any AuditEventPersisting)?) {
        auditSink = sink
    }

    public func enableDefaultAuditPersistenceIfNeeded() {
        guard auditSink == nil else {
            return
        }
        auditSink = JSONLAuditEventSink()
    }

    public func publishMarketDataSubscription(_ subscriptions: MarketDataSubscriptionSet) {
        snapshotValue.lastEventName = "market_data_subscription"
        snapshotValue.marketDataSubscriptions = subscriptions
        snapshotValue.lastMarketDataSummary = marketDataSubscriptionSummary(subscriptions)
        yieldEvent(named: "market_data_subscription")
    }

    public func publishMarketDataDesiredSubscription(_ subscriptions: MarketDataSubscriptionSet) {
        snapshotValue.lastEventName = "market_data_desired_subscription"
        snapshotValue.marketDataDesiredSubscriptions = subscriptions
        yieldEvent(named: "market_data_desired_subscription")
    }

    public func publishMarketQuote(_ event: MarketDataQuoteEvent) {
        snapshotValue.lastEventName = "market_quote"
        snapshotValue.lastMarketDataReceivedAt = now()
        snapshotValue.lastMarketDataReceivedSymbol = event.symbol

        var quote = quoteStore(for: event.instrumentType)[event.symbol]
            ?? MarketQuote(symbol: event.symbol, instrumentType: event.instrumentType)
        quote.instrumentType = event.instrumentType
        quote.bidPrice = event.bidPrice ?? quote.bidPrice
        quote.askPrice = event.askPrice ?? quote.askPrice
        quote.lastQuoteTimestamp = event.timestamp ?? quote.lastQuoteTimestamp
        quote.timestamp = event.timestamp ?? quote.timestamp

        updateQuoteStore(for: event.instrumentType, symbol: event.symbol, quote: quote)
        let summary = marketQuoteSummary(event)
        updateMarketSummary(for: event.instrumentType, summary: summary)
        yieldMarketDataUIInvalidation(rawEventName: "market_quote")
    }

    public func publishMarketTrade(_ event: MarketDataTradeEvent) {
        snapshotValue.lastEventName = "market_trade"
        snapshotValue.lastMarketDataReceivedAt = now()
        snapshotValue.lastMarketDataReceivedSymbol = event.symbol

        var quote = quoteStore(for: event.instrumentType)[event.symbol]
            ?? MarketQuote(symbol: event.symbol, instrumentType: event.instrumentType)
        quote.instrumentType = event.instrumentType
        quote.lastPrice = event.price ?? quote.lastPrice
        quote.lastTradeTimestamp = event.timestamp ?? quote.lastTradeTimestamp
        quote.timestamp = event.timestamp ?? quote.timestamp
        updateQuoteStore(for: event.instrumentType, symbol: event.symbol, quote: quote)

        let summary = marketTradeSummary(event)
        updateMarketSummary(for: event.instrumentType, summary: summary)
        yieldMarketDataUIInvalidation(rawEventName: "market_trade")
    }

    public func publishMarketBar(_ event: MarketDataBarEvent) {
        snapshotValue.lastEventName = "market_bar"
        snapshotValue.lastMarketDataReceivedAt = now()
        snapshotValue.lastMarketDataReceivedSymbol = event.symbol

        var quote = quoteStore(for: event.instrumentType)[event.symbol]
            ?? MarketQuote(symbol: event.symbol, instrumentType: event.instrumentType)
        quote.instrumentType = event.instrumentType
        quote.lastPrice = event.close ?? quote.lastPrice
        quote.lastBarTimestamp = event.timestamp ?? quote.lastBarTimestamp
        quote.timestamp = event.timestamp ?? quote.timestamp
        updateQuoteStore(for: event.instrumentType, symbol: event.symbol, quote: quote)

        let summary = marketBarSummary(event)
        updateMarketSummary(for: event.instrumentType, summary: summary)
        yieldMarketDataUIInvalidation(rawEventName: "market_bar")
    }

    public func markCancelRequested(orderID: String) {
        if var order = snapshotValue.ordersByID[orderID] {
            order.status = "cancel_requested"
            snapshotValue.ordersByID[orderID] = order
            refreshOpenOrders()
        }
        appendAudit(
            "cancel requested order_id=\(orderID)",
            source: .engine,
            orderID: orderID,
            action: "cancel_request"
        )
        snapshotValue.lastEventName = "cancel_requested"
        yieldEvent(named: "cancel_requested")
    }

    public func publishTradeUpdate(_ event: TradeUpdateEvent) {
        snapshotValue.lastEventName = "trade_update"

        var row = snapshotValue.ordersByID[event.orderID]
            ?? OrderRow(
                id: event.orderID,
                instrumentType: event.instrumentTypeHint ?? .equity,
                symbol: event.symbol ?? "?",
                underlyingSymbol: event.inferredUnderlyingSymbol,
                side: event.side ?? "?",
                qty: event.qty ?? "?",
                filledQty: event.filledQty ?? "0",
                orderType: nil,
                limitPrice: nil,
                status: event.orderStatus ?? event.event,
                updatedAt: event.timestamp,
                isOpen: isOpenStatus(event.orderStatus ?? event.event)
            )
        let previousFilled = decimalValue(row.filledQty) ?? 0

        if let symbol = event.symbol {
            row.symbol = symbol
        }
        if let instrumentType = event.instrumentTypeHint {
            row.instrumentType = instrumentType
        }
        if let underlyingSymbol = event.inferredUnderlyingSymbol {
            row.underlyingSymbol = underlyingSymbol
        }
        if let side = event.side {
            row.side = side
        }
        if let qty = event.qty {
            row.qty = qty
        }
        if let filledQty = event.filledQty {
            row.filledQty = filledQty
        }

        let status = event.orderStatus ?? event.event
        row.status = status
        row.isOpen = isOpenStatus(status)
        row.updatedAt = event.timestamp ?? row.updatedAt

        snapshotValue.ordersByID[event.orderID] = row
        refreshOpenOrders()
        applyPositionUpdateFromTradeUpdate(
            event: event,
            previousFilledQty: previousFilled,
            newFilledQty: decimalValue(row.filledQty) ?? previousFilled
        )

        let summary = tradeUpdateSummary(event)
        snapshotValue.lastTradeUpdateSummary = summary
        appendAudit(summary, source: .engine, orderID: event.orderID, symbol: event.symbol, action: "trade_update")
        yieldEvent(named: "trade_update")
    }

    public func publishDiagnostic(
        _ message: String,
        source: AuditEventSource = .engine,
        level: AuditEventLevel = .info,
        strategyID: String? = nil,
        orderID: String? = nil,
        symbol: String? = nil,
        action: String? = nil,
        errorCode: String? = nil
    ) {
        snapshotValue.lastEventName = "diagnostic"
        appendAudit(
            message,
            source: source,
            level: level,
            strategyID: strategyID,
            orderID: orderID,
            symbol: symbol,
            action: action,
            errorCode: errorCode
        )
        yieldEvent(named: "diagnostic")
    }

    public func publishNotification(
        source: String,
        message: String,
        jobId: String? = nil,
        symbol: String? = nil,
        score: Double? = nil
    ) {
        snapshotValue.lastEventName = "notification"
        let notification = JobNotification(
            timestamp: Self.iso8601String(now()),
            source: source,
            message: message,
            jobId: jobId,
            symbol: symbol,
            score: score
        )
        snapshotValue.notifications.append(notification)
        let overflow = snapshotValue.notifications.count - notificationCap
        if overflow > 0 {
            snapshotValue.notifications.removeFirst(overflow)
        }
        yieldEvent(named: "notification")
    }

    public func snapshot() -> StoreSnapshot {
        var snapshot = snapshotValue
        snapshot.eventStreamDiagnostics = eventStreamDiagnostics
        marketDataUIInvalidationPending = false
        return snapshot
    }

    private func yieldEvent(named name: String) {
        yieldEvent(StoreEvent(name: name))
    }

    private func yieldMarketDataUIInvalidation(rawEventName: String) {
        eventStreamDiagnostics.marketDataRawUpdateCount += 1
        eventStreamDiagnostics.marketDataRawUpdateCountsByName[rawEventName, default: 0] += 1
        guard marketDataUIInvalidationPending == false else {
            eventStreamDiagnostics.marketDataUIInvalidationCoalescedCount += 1
            return
        }
        marketDataUIInvalidationPending = true
        eventStreamDiagnostics.marketDataUIInvalidationYieldCount += 1
        yieldEvent(StoreEvent(name: "market_data"), updatesLastEventName: false)
    }

    private func yieldEvent(
        _ event: StoreEvent,
        updatesLastEventName: Bool = true
    ) {
        if updatesLastEventName {
            snapshotValue.lastEventName = event.name
        }
        eventStreamDiagnostics.yieldedCount += 1
        let result = continuation.yield(event)
        switch result {
        case .enqueued:
            eventStreamDiagnostics.enqueuedCount += 1
        case .dropped(let droppedEvent):
            eventStreamDiagnostics.droppedCount += 1
            eventStreamDiagnostics.lastDroppedEventName = droppedEvent.name
            eventStreamDiagnostics.droppedEventCountsByName[droppedEvent.name, default: 0] += 1
            if droppedEvent.name == "market_data" {
                eventStreamDiagnostics.marketDataUIInvalidationDroppedCount += 1
            }
        case .terminated:
            eventStreamDiagnostics.terminatedYieldCount += 1
        @unknown default:
            break
        }
    }

    private func map(account: Account) -> AccountSummary {
        AccountSummary(
            id: account.id,
            status: account.status ?? "?",
            buyingPower: account.buyingPower ?? "?",
            cash: account.cash ?? "?",
            equity: account.equity ?? "?",
            canShortSellEquities: account.canShortSellEquities
        )
    }

    private func map(position: Position) -> PositionRow {
        let symbol = position.symbol ?? "?"
        let normalized = normalizePositionQuantity(
            qty: position.qty,
            side: position.side
        )
        return PositionRow(
            id: symbol,
            symbol: symbol,
            side: normalized.side,
            qty: normalized.qty,
            marketValue: position.marketValue ?? "?"
        )
    }

    private func map(order: Order) -> OrderRow {
        let status = order.status ?? "unknown"
        return OrderRow(
            id: order.id,
            instrumentType: order.instrumentType,
            symbol: order.symbol ?? "?",
            underlyingSymbol: order.inferredUnderlyingSymbol,
            side: order.side ?? "?",
            qty: order.qty ?? "?",
            orderType: order.type,
            limitPrice: order.limitPrice,
            status: status,
            isOpen: isOpenStatus(status)
        )
    }

    private func refreshOpenOrders() {
        snapshotValue.openOrders = snapshotValue.ordersByID.values
            .filter(\.isOpen)
            .sorted { lhs, rhs in
                if lhs.symbol == rhs.symbol {
                    return lhs.id < rhs.id
                }
                return lhs.symbol < rhs.symbol
            }
    }

    private func appendAudit(
        _ line: String,
        source: AuditEventSource = .engine,
        level: AuditEventLevel = .info,
        strategyID: String? = nil,
        orderID: String? = nil,
        symbol: String? = nil,
        action: String? = nil,
        errorCode: String? = nil
    ) {
        snapshotValue.auditLines.append(line)
        let overflow = snapshotValue.auditLines.count - auditLineCap
        if overflow > 0 {
            snapshotValue.auditLines.removeFirst(overflow)
        }

        let environment: Environment = snapshotValue.isLive ? .live : .paper
        let event = AuditEvent(
            timestamp: Self.iso8601String(now()),
            source: source,
            level: level,
            message: line,
            env: environment,
            strategyId: strategyID,
            orderId: orderID,
            symbol: symbol,
            action: action,
            errorCode: errorCode
        )
        snapshotValue.structuredAuditEvents.append(event)
        let structuredOverflow = snapshotValue.structuredAuditEvents.count - structuredAuditCap
        if structuredOverflow > 0 {
            snapshotValue.structuredAuditEvents.removeFirst(structuredOverflow)
        }

        if let auditSink {
            Task {
                await auditSink.append(event)
            }
        }
    }

    private func tradeUpdateSummary(_ event: TradeUpdateEvent) -> String {
        var parts: [String] = []
        parts.append("event=\(event.event)")
        parts.append("order_id=\(event.orderID)")
        if let instrumentType = event.instrumentTypeHint {
            parts.append("instrument=\(instrumentType.shortLabel)")
        }
        if let symbol = event.symbol {
            parts.append("symbol=\(symbol)")
        }
        if let status = event.orderStatus {
            parts.append("status=\(status)")
        }
        if let filledQty = event.filledQty {
            parts.append("filled_qty=\(filledQty)")
        }
        if let filledAvgPrice = event.filledAvgPrice {
            parts.append("filled_avg_price=\(filledAvgPrice)")
        }
        return parts.joined(separator: " ")
    }

    private func marketDataSubscriptionSummary(_ subscriptions: MarketDataSubscriptionSet) -> String {
        "market_data subscriptions quotes=\(subscriptions.quotes.count) trades=\(subscriptions.trades.count) bars=\(subscriptions.bars.count) option_quotes=\(subscriptions.optionQuotes.count) option_trades=\(subscriptions.optionTrades.count) option_bars=\(subscriptions.optionBars.count)"
    }

    private func marketQuoteSummary(_ event: MarketDataQuoteEvent) -> String {
        var parts: [String] = ["quote", "instrument=\(event.instrumentType.shortLabel)", "symbol=\(event.symbol)"]
        if let bid = event.bidPrice {
            parts.append("bid=\(bid)")
        }
        if let ask = event.askPrice {
            parts.append("ask=\(ask)")
        }
        return parts.joined(separator: " ")
    }

    private func marketTradeSummary(_ event: MarketDataTradeEvent) -> String {
        var parts: [String] = ["trade", "instrument=\(event.instrumentType.shortLabel)", "symbol=\(event.symbol)"]
        if let price = event.price {
            parts.append("price=\(price)")
        }
        if let size = event.size {
            parts.append("size=\(size)")
        }
        return parts.joined(separator: " ")
    }

    private func marketBarSummary(_ event: MarketDataBarEvent) -> String {
        var parts: [String] = ["bar", "instrument=\(event.instrumentType.shortLabel)", "symbol=\(event.symbol)"]
        if let close = event.close {
            parts.append("close=\(close)")
        }
        return parts.joined(separator: " ")
    }

    private func quoteStore(for instrumentType: InstrumentType) -> [String: MarketQuote] {
        switch instrumentType {
        case .equity:
            return snapshotValue.quotesBySymbol
        case .option:
            return snapshotValue.optionQuotesBySymbol
        }
    }

    private func updateQuoteStore(
        for instrumentType: InstrumentType,
        symbol: String,
        quote: MarketQuote
    ) {
        switch instrumentType {
        case .equity:
            snapshotValue.quotesBySymbol[symbol] = quote
        case .option:
            snapshotValue.optionQuotesBySymbol[symbol] = quote
        }
    }

    private func updateMarketSummary(
        for instrumentType: InstrumentType,
        summary: String
    ) {
        snapshotValue.lastMarketDataSummary = summary
        if instrumentType == .option {
            snapshotValue.lastOptionsMarketDataSummary = summary
        }
    }

    private func applyPositionUpdateFromTradeUpdate(
        event: TradeUpdateEvent,
        previousFilledQty: Decimal,
        newFilledQty: Decimal
    ) {
        guard let symbol = event.symbol,
              let side = event.side?.lowercased(),
              side == "buy" || side == "sell"
        else {
            return
        }

        let delta = newFilledQty - previousFilledQty
        guard delta != 0 else {
            return
        }

        let signedDelta: Decimal = (side == "buy") ? delta : -delta
        if let index = snapshotValue.positions.firstIndex(where: { $0.symbol == symbol }) {
            var row = snapshotValue.positions[index]
            let currentQty = positionQuantityDecimal(row)
            let nextQty = currentQty + signedDelta
            if nextQty == 0 {
                snapshotValue.positions.remove(at: index)
            } else {
                row.qty = decimalString(nextQty)
                row.side = nextQty < 0 ? "short" : "long"
                snapshotValue.positions[index] = row
            }
        } else {
            guard signedDelta != 0 else {
                return
            }
            snapshotValue.positions.append(
                PositionRow(
                    id: symbol,
                    symbol: symbol,
                    side: signedDelta < 0 ? "short" : "long",
                    qty: decimalString(signedDelta),
                    marketValue: "?"
                )
            )
            snapshotValue.positions.sort { $0.symbol < $1.symbol }
        }
    }

    private func normalizePositionQuantity(
        qty: String?,
        side: String?
    ) -> (qty: String, side: String) {
        let rawQty = qty ?? "0"
        guard var numeric = decimalValue(rawQty) else {
            return (qty: rawQty, side: side ?? "?")
        }

        let normalizedSide = (side ?? "").lowercased()
        if normalizedSide == "short", numeric > 0 {
            numeric *= -1
        }
        if normalizedSide == "long", numeric < 0 {
            numeric *= -1
        }

        let displaySide: String
        if numeric < 0 {
            displaySide = "short"
        } else if numeric > 0 {
            displaySide = "long"
        } else {
            displaySide = side ?? "flat"
        }
        return (qty: decimalString(numeric), side: displaySide)
    }

    private func positionQuantityDecimal(_ row: PositionRow) -> Decimal {
        guard var value = decimalValue(row.qty) else {
            return 0
        }
        if row.side.lowercased() == "short", value > 0 {
            value *= -1
        }
        return value
    }

    private func decimalValue(_ raw: String?) -> Decimal? {
        guard let raw else {
            return nil
        }
        return Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func isOpenStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        let closed: Set<String> = [
            "filled",
            "canceled",
            "cancelled",
            "rejected",
            "expired",
            "done_for_day",
            "replaced",
            "stopped",
            "suspended"
        ]
        return !closed.contains(normalized)
    }

    private static func iso8601String(_ date: Date) -> String {
        DateCodec.formatISO8601(date)
    }
}
