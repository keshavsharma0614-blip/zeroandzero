import Foundation

public actor AlpacaMarketDataStream {
    public nonisolated let events: AsyncStream<MarketDataStreamEvent>

    private let continuation: AsyncStream<MarketDataStreamEvent>.Continuation
    private let keychainProvider: KeychainCredentialsProvider
    private let session: URLSession
    private let backoffPolicy: ExponentialBackoffPolicy
    private let randomUnit: @Sendable () -> Double
    private let sleep: @Sendable (TimeInterval) async -> Void

    private var feed: MarketDataFeed
    private var environment: Environment
    private var state: MarketDataConnectionState = .disconnected
    private var isRunning = false
    private var runnerTask: Task<Void, Never>?
    private var runnerGeneration = 0
    private var socketTask: URLSessionWebSocketTask?

    private var subscriptionsBySource: [String: MarketDataSubscriptionSet] = [:]
    private var desiredSubscriptions: MarketDataSubscriptionSet = .empty
    private var activeSubscriptions: MarketDataSubscriptionSet = .empty
    private var lastStateChangedAt: Date?
    private var lastSuccessMessage: String?
    private var lastErrorCode: Int?
    private var lastErrorMessage: String?
    private var lastSubscriptionAcknowledgedAt: Date?
    private var lastDiagnostic: String?
    private var reconnectRequestCount = 0
    private var lastReconnectReason: String?

    public init(
        environment: Environment = .paper,
        feed: MarketDataFeed = .test,
        keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider(),
        session: URLSession = .shared,
        backoffPolicy: ExponentialBackoffPolicy = ExponentialBackoffPolicy(),
        eventBufferLimit: Int = 2048,
        randomUnit: @escaping @Sendable () -> Double = { Double.random(in: 0 ... 1) },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    ) {
        let boundedEventBufferLimit = max(1, eventBufferLimit)
        var createdContinuation: AsyncStream<MarketDataStreamEvent>.Continuation?
        self.events = AsyncStream(
            MarketDataStreamEvent.self,
            bufferingPolicy: .bufferingNewest(boundedEventBufferLimit)
        ) { continuation in
            createdContinuation = continuation
        }
        guard let createdContinuation else {
            fatalError("Failed to initialize market-data stream continuation")
        }

        self.continuation = createdContinuation
        self.feed = feed
        self.environment = environment
        self.keychainProvider = keychainProvider
        self.session = session
        self.backoffPolicy = backoffPolicy
        self.randomUnit = randomUnit
        self.sleep = sleep
    }

    deinit {
        runnerTask?.cancel()
        socketTask?.cancel(with: .goingAway, reason: nil)
        continuation.finish()
    }

    public func updateFeed(_ feed: MarketDataFeed) {
        guard self.feed != feed else {
            return
        }
        self.feed = feed
        requestReconnect(reason: "feed_changed")
    }

    public func updateEnvironment(_ environment: Environment) {
        guard self.environment != environment else {
            return
        }
        self.environment = environment
        requestReconnect(reason: "environment_changed")
    }

    public func start() {
        guard !isRunning else {
            if runnerTask == nil {
                startRunnerTask()
            }
            return
        }
        isRunning = true
        startRunnerTask()
    }

    public func stop() {
        isRunning = false
        runnerGeneration &+= 1
        runnerTask?.cancel()
        runnerTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        activeSubscriptions = .empty
        lastSubscriptionAcknowledgedAt = nil
        emit(.subscriptionChanged(.empty))
        emitState(.disconnected)
    }

    public func requestReconnect(reason: String) {
        let boundedReason = sanitizeDiagnostic(reason)
        reconnectRequestCount += 1
        lastReconnectReason = boundedReason
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        activeSubscriptions = .empty
        lastSubscriptionAcknowledgedAt = nil
        emit(.subscriptionChanged(.empty))
        emitState(.disconnected)
        emitDiagnostic("market_data reconnect requested: \(boundedReason)")
        guard isRunning else {
            return
        }
        runnerTask?.cancel()
        startRunnerTask()
    }

    public func connectionState() -> MarketDataConnectionState {
        state
    }

    public func currentDesiredSubscriptions() -> MarketDataSubscriptionSet {
        desiredSubscriptions
    }

    public func runtimeSnapshot() -> MarketDataStreamRuntimeSnapshot {
        MarketDataStreamRuntimeSnapshot(
            environment: environment,
            feed: feed,
            endpoint: feed.diagnosticWebSocketEndpoint,
            state: state,
            isRunning: isRunning,
            hasSocketTask: socketTask != nil,
            desiredSubscriptions: desiredSubscriptions,
            activeSubscriptions: activeSubscriptions,
            lastStateChangedAt: lastStateChangedAt,
            lastSuccessMessage: lastSuccessMessage,
            lastErrorCode: lastErrorCode,
            lastErrorMessage: lastErrorMessage,
            lastSubscriptionAcknowledgedAt: lastSubscriptionAcknowledgedAt,
            lastDiagnostic: lastDiagnostic,
            reconnectRequestCount: reconnectRequestCount,
            lastReconnectReason: lastReconnectReason
        )
    }

    private func startRunnerTask() {
        runnerGeneration &+= 1
        let generation = runnerGeneration
        runnerTask = Task { [weak self] in
            await self?.runLoop(generation: generation)
        }
    }

    public func setWatchSymbols(_ symbols: [String]) async {
        let normalized = MarketDataSubscriptionSet.normalized(symbols)
        let split = splitSymbolsByInstrument(normalized)
        setSourceSubscriptions(
            source: "watchlist",
            subscriptions: MarketDataSubscriptionSet(
                quotes: split.equities,
                trades: split.equities,
                optionQuotes: split.options,
                optionTrades: split.options
            )
        )
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    public func subscribeQuotes(
        symbols: [String],
        source: String = "default"
    ) async {
        let split = splitSymbolsByInstrument(MarketDataSubscriptionSet.normalized(symbols))
        var next = subscriptionsBySource[source] ?? .empty
        next.quotes.formUnion(split.equities)
        next.optionQuotes.formUnion(split.options)
        setSourceSubscriptions(source: source, subscriptions: next)
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    public func subscribeTrades(
        symbols: [String],
        source: String = "default"
    ) async {
        let split = splitSymbolsByInstrument(MarketDataSubscriptionSet.normalized(symbols))
        var next = subscriptionsBySource[source] ?? .empty
        next.trades.formUnion(split.equities)
        next.optionTrades.formUnion(split.options)
        setSourceSubscriptions(source: source, subscriptions: next)
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    public func subscribeBars(
        symbols: [String],
        source: String = "default"
    ) async {
        let split = splitSymbolsByInstrument(MarketDataSubscriptionSet.normalized(symbols))
        var next = subscriptionsBySource[source] ?? .empty
        next.bars.formUnion(split.equities)
        next.optionBars.formUnion(split.options)
        setSourceSubscriptions(source: source, subscriptions: next)
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    public func unsubscribeQuotes(
        symbols: [String],
        source: String = "default"
    ) async {
        let split = splitSymbolsByInstrument(MarketDataSubscriptionSet.normalized(symbols))
        var next = subscriptionsBySource[source] ?? .empty
        next.quotes.subtract(split.equities)
        next.optionQuotes.subtract(split.options)
        setSourceSubscriptions(source: source, subscriptions: next)
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    public func unsubscribeTrades(
        symbols: [String],
        source: String = "default"
    ) async {
        let split = splitSymbolsByInstrument(MarketDataSubscriptionSet.normalized(symbols))
        var next = subscriptionsBySource[source] ?? .empty
        next.trades.subtract(split.equities)
        next.optionTrades.subtract(split.options)
        setSourceSubscriptions(source: source, subscriptions: next)
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    public func unsubscribeBars(
        symbols: [String],
        source: String = "default"
    ) async {
        let split = splitSymbolsByInstrument(MarketDataSubscriptionSet.normalized(symbols))
        var next = subscriptionsBySource[source] ?? .empty
        next.bars.subtract(split.equities)
        next.optionBars.subtract(split.options)
        setSourceSubscriptions(source: source, subscriptions: next)
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    public func clearSource(_ source: String) async {
        subscriptionsBySource[source] = nil
        recomputeDesiredSubscriptions()
        await reconcileSubscriptionsIfPossible(forcePublish: true)
    }

    private func runLoop(generation: Int) async {
        var attempt = 0

        while isRunning && generation == runnerGeneration && !Task.isCancelled {
            do {
                try await connectAndAuthenticate()
                attempt = 0
                await reconcileSubscriptionsIfPossible(forcePublish: true)
                try await receiveLoop()
            } catch {
                guard generation == runnerGeneration else {
                    break
                }
                socketTask?.cancel(with: .goingAway, reason: nil)
                socketTask = nil
                activeSubscriptions = .empty
                lastSubscriptionAcknowledgedAt = nil
                lastErrorMessage = sanitizeDiagnostic(error.localizedDescription)
                emit(.subscriptionChanged(.empty))
                emitState(.disconnected)
                emitDiagnostic("market_data reconnect required: \(error.localizedDescription)")
            }

            guard isRunning && generation == runnerGeneration && !Task.isCancelled else {
                break
            }

            let delay = backoffPolicy.delay(attempt: attempt, randomUnit: randomUnit())
            attempt += 1
            emitDiagnostic(String(format: "market_data reconnecting in %.2fs", delay))
            await sleep(delay)
        }

        if generation == runnerGeneration {
            emitState(.disconnected)
        }
    }

    private func connectAndAuthenticate() async throws {
        guard let credentials = keychainProvider.credentials(for: environment)
        else {
            throw AlpacaAPIError.missingCredentials(environment: environment)
        }

        emitState(.connecting)
        emitDiagnostic("market_data connecting feed=\(feed.feedCode) endpoint=\(feed.diagnosticWebSocketEndpoint)")
        let task = session.webSocketTask(with: feed.websocketURL)
        socketTask = task
        activeSubscriptions = .empty
        lastSubscriptionAcknowledgedAt = nil
        emit(.subscriptionChanged(.empty))

        task.resume()
        emitState(.connected)

        try await send(payload: [
            "action": "auth",
            "key": credentials.publicKey,
            "secret": credentials.secretKey
        ])
    }

    private func receiveLoop() async throws {
        while isRunning && !Task.isCancelled {
            guard let socketTask else {
                throw AlpacaAPIError.transportFailure(message: "market_data socket not initialized")
            }

            let message = try await socketTask.receive()
            switch message {
            case .string(let text):
                await handleIncoming(data: Data(text.utf8))
            case .data(let data):
                await handleIncoming(data: data)
            @unknown default:
                emitDiagnostic("market_data received unknown websocket frame")
            }
        }
    }

    private func handleIncoming(data: Data) async {
        let messages = AlpacaMarketDataCodec.decodeMessages(from: data)

        for message in messages {
            switch message {
            case .success(let status):
                lastSuccessMessage = sanitizeDiagnostic(status)
                emitDiagnostic("market_data success feed=\(feed.feedCode): \(status)")
                if status.lowercased().contains("authenticated") {
                    emitState(.authenticated)
                    lastErrorCode = nil
                    lastErrorMessage = nil
                    await reconcileSubscriptionsIfPossible(forcePublish: true)
                }
            case .error(let code, let message):
                let codeSummary = code.map(String.init) ?? "none"
                lastErrorCode = code
                lastErrorMessage = sanitizeDiagnostic(message)
                emitDiagnostic("market_data error feed=\(feed.feedCode) code=\(codeSummary): \(message)")
            case .subscription(let subscribed):
                activeSubscriptions = subscribed
                lastSubscriptionAcknowledgedAt = Date()
                emitState(.subscribed)
                emit(.subscriptionChanged(subscribed))
                lastErrorCode = nil
                lastErrorMessage = nil
                emitDiagnostic("market_data subscription acknowledged feed=\(feed.feedCode)")
            case .quote(let event):
                emit(.quote(event))
            case .trade(let event):
                emit(.trade(event))
            case .bar(let event):
                emit(.bar(event))
            case .unknown(let description):
                emitDiagnostic("market_data unknown payload: \(description)")
            }
        }
    }

    func handleIncomingForTesting(data: Data) async {
        await handleIncoming(data: data)
    }

    private func send(payload: [String: String]) async throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let text = String(data: data, encoding: .utf8) else {
            throw AlpacaAPIError.transportFailure(message: "Failed to encode market-data payload")
        }

        guard let socketTask else {
            throw AlpacaAPIError.transportFailure(message: "market_data socket unavailable")
        }
        try await socketTask.send(.string(text))
    }

    private func send(payload: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let text = String(data: data, encoding: .utf8) else {
            throw AlpacaAPIError.transportFailure(message: "Failed to encode market-data payload")
        }

        guard let socketTask else {
            throw AlpacaAPIError.transportFailure(message: "market_data socket unavailable")
        }
        try await socketTask.send(.string(text))
    }

    private func setSourceSubscriptions(
        source: String,
        subscriptions: MarketDataSubscriptionSet
    ) {
        if subscriptions.isEmpty {
            subscriptionsBySource[source] = nil
        } else {
            subscriptionsBySource[source] = subscriptions
        }
        recomputeDesiredSubscriptions()
    }

    private func recomputeDesiredSubscriptions() {
        var quotes: Set<String> = []
        var trades: Set<String> = []
        var bars: Set<String> = []
        var optionQuotes: Set<String> = []
        var optionTrades: Set<String> = []
        var optionBars: Set<String> = []

        for (_, value) in subscriptionsBySource {
            quotes.formUnion(value.quotes)
            trades.formUnion(value.trades)
            bars.formUnion(value.bars)
            optionQuotes.formUnion(value.optionQuotes)
            optionTrades.formUnion(value.optionTrades)
            optionBars.formUnion(value.optionBars)
        }

        desiredSubscriptions = MarketDataSubscriptionSet(
            quotes: quotes,
            trades: trades,
            bars: bars,
            optionQuotes: optionQuotes,
            optionTrades: optionTrades,
            optionBars: optionBars
        )
        emit(.desiredSubscriptionChanged(desiredSubscriptions))
    }

    private func reconcileSubscriptionsIfPossible(forcePublish: Bool = false) async {
        if forcePublish {
            emit(.desiredSubscriptionChanged(desiredSubscriptions))
        }

        guard state == .authenticated || state == .subscribed else {
            return
        }

        let delta = desiredSubscriptions.diff(from: activeSubscriptions)
        guard !delta.isEmpty else {
            if state != .subscribed, activeSubscriptions.isEmpty == false {
                emitState(.subscribed)
            }
            return
        }

        do {
            if !delta.subscribeQuotes.isEmpty ||
                !delta.subscribeTrades.isEmpty ||
                !delta.subscribeBars.isEmpty ||
                !delta.subscribeOptionQuotes.isEmpty ||
                !delta.subscribeOptionTrades.isEmpty ||
                !delta.subscribeOptionBars.isEmpty {
                try await send(payload: subscriptionPayload(
                    action: "subscribe",
                    quotes: delta.subscribeQuotes,
                    trades: delta.subscribeTrades,
                    bars: delta.subscribeBars,
                    optionQuotes: delta.subscribeOptionQuotes,
                    optionTrades: delta.subscribeOptionTrades,
                    optionBars: delta.subscribeOptionBars
                ))
            }

            if !delta.unsubscribeQuotes.isEmpty ||
                !delta.unsubscribeTrades.isEmpty ||
                !delta.unsubscribeBars.isEmpty ||
                !delta.unsubscribeOptionQuotes.isEmpty ||
                !delta.unsubscribeOptionTrades.isEmpty ||
                !delta.unsubscribeOptionBars.isEmpty {
                try await send(payload: subscriptionPayload(
                    action: "unsubscribe",
                    quotes: delta.unsubscribeQuotes,
                    trades: delta.unsubscribeTrades,
                    bars: delta.unsubscribeBars,
                    optionQuotes: delta.unsubscribeOptionQuotes,
                    optionTrades: delta.unsubscribeOptionTrades,
                    optionBars: delta.unsubscribeOptionBars
                ))
            }
        } catch {
            lastErrorMessage = sanitizeDiagnostic(error.localizedDescription)
            emitDiagnostic("market_data subscription reconcile failed: \(error.localizedDescription)")
            socketTask?.cancel(with: .goingAway, reason: nil)
            return
        }
    }

    private func subscriptionPayload(
        action: String,
        quotes: Set<String>,
        trades: Set<String>,
        bars: Set<String>,
        optionQuotes: Set<String>,
        optionTrades: Set<String>,
        optionBars: Set<String>
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "action": action
        ]
        if !quotes.isEmpty {
            payload["quotes"] = quotes.sorted()
        }
        if !trades.isEmpty {
            payload["trades"] = trades.sorted()
        }
        if !bars.isEmpty {
            payload["bars"] = bars.sorted()
        }
        if !optionQuotes.isEmpty {
            payload["option_quotes"] = optionQuotes.sorted()
        }
        if !optionTrades.isEmpty {
            payload["option_trades"] = optionTrades.sorted()
        }
        if !optionBars.isEmpty {
            payload["option_bars"] = optionBars.sorted()
        }
        return payload
    }

    private func splitSymbolsByInstrument(
        _ symbols: Set<String>
    ) -> (equities: Set<String>, options: Set<String>) {
        var equities: Set<String> = []
        var options: Set<String> = []
        for symbol in symbols {
            switch MarketSymbolClassifier.instrumentType(for: symbol) {
            case .equity:
                equities.insert(symbol)
            case .option:
                options.insert(symbol)
            }
        }
        return (equities, options)
    }

    private func emitState(_ newState: MarketDataConnectionState) {
        state = newState
        lastStateChangedAt = Date()
        emit(.connectionStateChanged(newState))
    }

    private func emitDiagnostic(_ message: String) {
        let sanitized = sanitizeDiagnostic(message)
        lastDiagnostic = sanitized
        emit(.diagnostic(sanitized))
    }

    private func sanitizeDiagnostic(_ message: String) -> String {
        String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
    }

    private func emit(_ event: MarketDataStreamEvent) {
        continuation.yield(event)
    }
}
