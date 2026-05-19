import Foundation
import Testing
@testable import TradingKit

@Test("AppSupportPaths keeps one bounded default root per test process")
func appSupportPathsKeepsStablePerProcessTestRoot() {
    AppSupportPaths.resetCachedTestRootForTesting()
    defer { AppSupportPaths.resetCachedTestRootForTesting() }

    let first = AppSupportPaths.rootDirectory()
    let second = AppSupportPaths.rootDirectory()

    #expect(first == second)
    #expect(first.lastPathComponent.contains("-"))
    #expect(first.path.contains("AlgoTradingMacTests"))
}

@Test("AppSupportPaths cleans stale dead-process test roots while preserving live ones")
func appSupportPathsCleansStaleDeadProcessRoots() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("app-support-paths-cleanup-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    let stale = base.appendingPathComponent("111-old", isDirectory: true)
    let live = base.appendingPathComponent("222-live", isDirectory: true)
    try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: live, withIntermediateDirectories: true)

    let root = AppSupportPaths.makeTestRoot(
        baseDirectory: base,
        processIdentifier: 222,
        instanceIdentifier: "current",
        processExists: { $0 == 222 }
    )

    #expect(FileManager.default.fileExists(atPath: stale.path) == false)
    #expect(FileManager.default.fileExists(atPath: live.path))
    #expect(root.lastPathComponent == "222-current")
}

@Test("Engine defaults to paper and disconnected")
func engineDefaults() async {
    let engine = Engine()

    let configuration = await engine.configuration
    let isConnected = await engine.isConnected
    let status = await engine.status

    #expect(configuration.environment == .paper)
    #expect(configuration.marketDataFeed == .stocksIEX)
    #expect(isConnected == false)
    #expect(status == Engine.disconnectedStatus)
}

@Test("Market-data feed diagnostics expose SIP and IEX stream paths")
func marketDataFeedDiagnosticsExposeStreamPaths() {
    #expect(MarketDataFeed.stocksSIP.feedCode == "sip")
    #expect(MarketDataFeed.stocksSIP.websocketPath == "/v2/sip")
    #expect(MarketDataFeed.stocksSIP.diagnosticWebSocketEndpoint == "wss://stream.data.alpaca.markets/v2/sip")
    #expect(MarketDataFeed.stocksIEX.feedCode == "iex")
    #expect(MarketDataFeed.stocksIEX.websocketPath == "/v2/iex")
}

@Test("Stream readiness distinguishes listening from disconnected trade updates")
func streamReadinessDistinguishesTradeUpdateListening() {
    let listening = makeTradeStreamReadinessPresentation(
        connectionState: TradeUpdatesConnectionState.subscribed.rawValue
    )
    #expect(listening.label == "listening")
    #expect(listening.isHealthy)
    #expect(listening.blocker == nil)

    let disconnected = makeTradeStreamReadinessPresentation(
        connectionState: TradeUpdatesConnectionState.disconnected.rawValue
    )
    #expect(disconnected.label == "disconnected")
    #expect(disconnected.isHealthy == false)
    #expect(disconnected.blocker == "Trade-update stream is disconnected.")
}

@Test("Market data readiness distinguishes subscribed awaiting first data from disconnected")
func marketDataReadinessDistinguishesAwaitingFirstData() {
    let subscriptions = MarketDataSubscriptionSet(quotes: ["AAPL"], trades: ["AAPL"])
    let readiness = makeMarketDataStreamReadinessPresentation(
        connectionState: MarketDataConnectionState.subscribed.rawValue,
        desiredMarketData: subscriptions,
        activeMarketData: subscriptions,
        lastMarketDataReceivedAt: nil,
        now: Date(timeIntervalSince1970: 1_779_040_800)
    )

    #expect(readiness.state == "awaiting_first_data")
    #expect(readiness.label == "awaiting first data")
    #expect(readiness.isTransportHealthy)
    #expect(readiness.isFullyHealthy == false)
    #expect(readiness.awaitingFirstData)
    #expect(readiness.blocker?.contains("subscribed and waiting for the first Store market-data event") == true)
    #expect(readiness.blocker?.contains("disconnected") == false)
}

@Test("Always-on readiness does not call subscribed awaiting-first-data market stream disconnected")
func alwaysOnReadinessDoesNotMislabelAwaitingFirstDataAsDisconnected() {
    var snapshot = StoreSnapshot(
        build: "test",
        connectionState: TradeUpdatesConnectionState.subscribed.rawValue,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue
    )
    let subscriptions = MarketDataSubscriptionSet(quotes: ["AAPL"], trades: ["AAPL"])
    snapshot.marketDataDesiredSubscriptions = subscriptions
    snapshot.marketDataSubscriptions = subscriptions

    let readiness = makeAlwaysOnReadinessAssessment(
        isEngineStarted: true,
        alpacaCredentialsReady: true,
        snapshot: snapshot,
        now: Date(timeIntervalSince1970: 1_779_040_800)
    )

    #expect(readiness.status == .degraded)
    #expect(readiness.blockers.contains { $0.contains("subscribed and waiting for the first Store market-data event") })
    #expect(readiness.blockers.contains { $0.contains("Market-data stream is disconnected") } == false)
    #expect(readiness.blockers.contains { $0.contains("Trade-update stream is disconnected") } == false)
}

@Test("Engine switches environment")
func engineEnvironmentSwitch() async {
    let engine = Engine()

    #expect(await engine.environment == .paper)
    await engine.setEnvironment(.live)
    #expect(await engine.environment == .live)
}

@Test("Engine start preflights OpenAI access before later scheduled work can become first touch")
func engineStartPreflightsOpenAIAccess() async {
    final class CountingOpenAIProvider: @unchecked Sendable, OpenAIKeyStatusProviding {
        private let lock = NSLock()
        private var resolutionCount = 0

        func apiKey() -> String? { "test-openai-key" }
        func isConfigured() -> Bool { true }
        func credentialResolution() -> OpenAICredentialResolution {
            lock.lock()
            resolutionCount += 1
            lock.unlock()
            return OpenAICredentialResolution(
                status: .ready,
                apiKey: "test-openai-key",
                source: .inferred,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "Test provider resolved a key."
            )
        }

        func count() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return resolutionCount
        }
    }

    actor PreflightRecorder {
        private(set) var callCount = 0

        func record() {
            callCount += 1
        }

        func count() -> Int {
            callCount
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: PreflightRecorder

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "unused",
                outputExcerpt: "unused"
            )
        }

        func preflightOpenAIKeyAccess() async throws -> Bool {
            await recorder.record()
            return true
        }
    }

    let provider = CountingOpenAIProvider()
    let recorder = PreflightRecorder()
    let rest = MockRESTClient()
    let engine = Engine(
        openAIKeyStatusProvider: provider,
        analystWorkerLauncher: StubLauncher(recorder: recorder),
        restClientFactory: { _ in rest }
    )

    await engine.start()
    await engine.start()
    await engine.stop()

    #expect(provider.count() == 1)
    #expect(await recorder.count() == 1)
}

@Test("Engine start preflights Telegram key access during launch")
func engineStartPreflightsTelegramKeyAccess() async {
    final class StubOpenAIProvider: @unchecked Sendable, OpenAIKeyStatusProviding {
        func apiKey() -> String? { nil }
        func isConfigured() -> Bool { false }
        func credentialResolution() -> OpenAICredentialResolution {
            OpenAICredentialResolution(
                status: .missingKey,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "No key configured."
            )
        }
    }

    final class TelegramKeyReaderRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var telegramReadCount = 0

        func record(service: String, account: String) {
            guard service == TelegramBotKeychainStatusProvider.service,
                  account == TelegramBotKeychainStatusProvider.account else {
                return
            }
            lock.lock()
            telegramReadCount += 1
            lock.unlock()
        }

        func count() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return telegramReadCount
        }
    }

    struct CountingKeyReader: KeyReading {
        let recorder: TelegramKeyReaderRecorder

        func readKey(service: String, account: String) -> String? {
            recorder.record(service: service, account: account)
            if service == TelegramBotKeychainStatusProvider.service,
               account == TelegramBotKeychainStatusProvider.account {
                return "telegram-token"
            }
            return nil
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "unused",
                outputExcerpt: "unused"
            )
        }

        func preflightOpenAIKeyAccess() async throws -> Bool {
            false
        }
    }

    let recorder = TelegramKeyReaderRecorder()
    let keychainProvider = KeychainCredentialsProvider(
        keyReader: CountingKeyReader(recorder: recorder)
    )
    let rest = MockRESTClient()
    let engine = Engine(
        openAIKeyStatusProvider: StubOpenAIProvider(),
        analystWorkerLauncher: StubLauncher(),
        keychainProvider: keychainProvider,
        restClientFactory: { _ in rest }
    )

    await engine.start()
    await engine.stop()

    #expect(recorder.count() >= 1)
}

@Test("Engine start preflights Settings-visible Alpaca credentials during launch")
func engineStartPreflightsSettingsVisibleAlpacaCredentials() async {
    final class StubOpenAIProvider: @unchecked Sendable, OpenAIKeyStatusProviding {
        func apiKey() -> String? { nil }
        func isConfigured() -> Bool { false }
        func credentialResolution() -> OpenAICredentialResolution {
            OpenAICredentialResolution(
                status: .missingKey,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "No key configured."
            )
        }
    }

    final class AlpacaKeyReaderRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var reads: [String] = []

        func record(service: String, account: String) {
            guard service == "alpaca.api.key" ||
                service == "alpaca.secret.key" else {
                return
            }
            lock.lock()
            reads.append("\(service)|\(account)")
            lock.unlock()
        }

        func count(matching expected: String) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return reads.filter { $0 == expected }.count
        }
    }

    struct CountingKeyReader: KeyReading {
        let recorder: AlpacaKeyReaderRecorder

        func readKey(service: String, account: String) -> String? {
            recorder.record(service: service, account: account)
            switch "\(service)|\(account)" {
            case "alpaca.api.key|algo-trading/paper":
                return "paper-public"
            case "alpaca.secret.key|algo-trading/paper":
                return "paper-secret"
            case "alpaca.api.key|algo-trading/live":
                return "live-public"
            case "alpaca.secret.key|algo-trading/live":
                return "live-secret"
            default:
                return nil
            }
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "unused",
                outputExcerpt: "unused"
            )
        }

        func preflightOpenAIKeyAccess() async throws -> Bool {
            false
        }
    }

    let recorder = AlpacaKeyReaderRecorder()
    let keychainProvider = KeychainCredentialsProvider(
        keyReader: CountingKeyReader(recorder: recorder)
    )
    let rest = MockRESTClient()
    let engine = Engine(
        openAIKeyStatusProvider: StubOpenAIProvider(),
        analystWorkerLauncher: StubLauncher(),
        keychainProvider: keychainProvider,
        restClientFactory: { _ in rest }
    )

    await engine.start()
    await engine.start()
    await engine.stop()

    #expect(recorder.count(matching: "alpaca.api.key|algo-trading/paper") >= 1)
    #expect(recorder.count(matching: "alpaca.secret.key|algo-trading/paper") >= 1)
    #expect(recorder.count(matching: "alpaca.api.key|algo-trading/live") >= 1)
    #expect(recorder.count(matching: "alpaca.secret.key|algo-trading/live") >= 1)

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.auditLines.contains { $0.contains("alpaca launch preflight env=paper active=true ready=true") })
    #expect(snapshot.auditLines.contains { $0.contains("alpaca launch preflight env=live active=false ready=true") })
}

@Test("Keychain credential provider session cache avoids duplicate Alpaca reads")
func keychainCredentialProviderSessionCacheAvoidsDuplicateAlpacaReads() {
    final class CountingKeyReader: KeyReading, @unchecked Sendable {
        private let lock = NSLock()
        private var readCounts: [String: Int] = [:]

        func readKey(service: String, account: String) -> String? {
            let key = "\(service)|\(account)"
            lock.lock()
            readCounts[key, default: 0] += 1
            lock.unlock()
            return "present"
        }

        func count(service: String, account: String) -> Int {
            let key = "\(service)|\(account)"
            lock.lock()
            defer { lock.unlock() }
            return readCounts[key, default: 0]
        }
    }

    let keyReader = CountingKeyReader()
    let provider = KeychainCredentialsProvider(keyReader: keyReader)

    #expect(provider.credentials(for: .live) != nil)
    #expect(provider.alpacaCredentialReadiness(for: .live).isReady)
    #expect(provider.credentials(for: .live) != nil)

    #expect(keyReader.count(service: "alpaca.api.key", account: "algo-trading/live") == 1)
    #expect(keyReader.count(service: "alpaca.secret.key", account: "algo-trading/live") == 1)

    provider.clearSessionCache()
    #expect(provider.credentials(for: .live) != nil)
    #expect(keyReader.count(service: "alpaca.api.key", account: "algo-trading/live") == 2)
    #expect(keyReader.count(service: "alpaca.secret.key", account: "algo-trading/live") == 2)
}

@Test("Always-on readiness reports stale connected market data as degraded")
func alwaysOnReadinessReportsStaleConnectedMarketDataAsDegraded() {
    let now = Date(timeIntervalSince1970: 1_700_001_000)
    let subscriptions = MarketDataSubscriptionSet(quotes: ["NVDA"], trades: ["NVDA"])
    let snapshot = StoreSnapshot(
        build: "test",
        marketDataDesiredSubscriptions: subscriptions,
        marketDataSubscriptions: subscriptions,
        lastMarketDataReceivedAt: now.addingTimeInterval(-600),
        connectionState: TradeUpdatesConnectionState.subscribed.rawValue,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue
    )

    let assessment = makeAlwaysOnReadinessAssessment(
        isEngineStarted: true,
        alpacaCredentialsReady: true,
        snapshot: snapshot,
        now: now,
        marketDataStaleAfter: 60
    )

    #expect(assessment.status == .degraded)
    #expect(assessment.blockers.contains { $0.contains("Last market-data event is stale") })
}

@Test("Always-on readiness does not treat stale acknowledged subscriptions as healthy after disconnect")
func alwaysOnReadinessReportsDisconnectedStreamsDespiteAcknowledgedSubscriptions() {
    let now = Date(timeIntervalSince1970: 1_700_001_100)
    let subscriptions = MarketDataSubscriptionSet(quotes: ["NVDA"], trades: ["NVDA"])
    let snapshot = StoreSnapshot(
        build: "test",
        marketDataDesiredSubscriptions: subscriptions,
        marketDataSubscriptions: subscriptions,
        lastMarketDataReceivedAt: now,
        connectionState: TradeUpdatesConnectionState.disconnected.rawValue,
        marketDataConnectionState: MarketDataConnectionState.disconnected.rawValue
    )

    let assessment = makeAlwaysOnReadinessAssessment(
        isEngineStarted: true,
        alpacaCredentialsReady: true,
        snapshot: snapshot,
        now: now,
        marketDataStaleAfter: 60
    )

    #expect(assessment.status == .degraded)
    #expect(assessment.blockers.contains("Trade-update stream is disconnected."))
    #expect(assessment.blockers.contains("Market-data stream is disconnected while symbols are requested."))
}

@Test("Always-on readiness names requested symbols when no Store market data has arrived")
func alwaysOnReadinessReportsRequestedSymbolsWhenNoMarketDataReachedStore() {
    let now = Date(timeIntervalSince1970: 1_700_001_150)
    let subscriptions = MarketDataSubscriptionSet(quotes: ["NVDA", "AAPL"], trades: ["NVDA"])
    let snapshot = StoreSnapshot(
        build: "test",
        marketDataDesiredSubscriptions: subscriptions,
        marketDataSubscriptions: subscriptions,
        lastMarketDataReceivedAt: nil,
        connectionState: TradeUpdatesConnectionState.subscribed.rawValue,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue
    )

    let assessment = makeAlwaysOnReadinessAssessment(
        isEngineStarted: true,
        alpacaCredentialsReady: true,
        snapshot: snapshot,
        now: now,
        marketDataStaleAfter: 60
    )

    #expect(assessment.status == .degraded)
    #expect(assessment.blockers.contains {
        $0.contains("Market-data stream is subscribed and waiting for the first Store market-data event") &&
            $0.contains("AAPL, NVDA")
    })
}

@Test("Always-on readiness distinguishes no first data outside regular market hours")
func alwaysOnReadinessDistinguishesNoFirstDataOutsideMarketHours() throws {
    let now = try #require(DateCodec.parseISO8601("2026-05-10T18:00:00Z"))
    let subscriptions = MarketDataSubscriptionSet(quotes: ["AAPL"], trades: ["AAPL"])
    let snapshot = StoreSnapshot(
        build: "test",
        marketDataDesiredSubscriptions: subscriptions,
        marketDataSubscriptions: subscriptions,
        lastMarketDataReceivedAt: nil,
        connectionState: TradeUpdatesConnectionState.subscribed.rawValue,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue
    )

    let assessment = makeAlwaysOnReadinessAssessment(
        isEngineStarted: true,
        alpacaCredentialsReady: true,
        snapshot: snapshot,
        now: now,
        marketDataStaleAfter: 60
    )

    #expect(assessment.status == .degraded)
    #expect(assessment.blockers.contains { $0.contains("Outside regular US equity market hours") })
}

@Test("No-first-data recovery assessment triggers only for acked active subscriptions in market-data window")
func marketDataNoFirstDataRecoveryAssessmentTriggersForAckedActiveSubscriptions() throws {
    let now = try #require(DateCodec.parseISO8601("2026-05-05T14:45:00Z"))
    let acknowledgedAt = now.addingTimeInterval(-180)
    let subscriptions = MarketDataSubscriptionSet(quotes: ["AAPL", "NVDA"], trades: ["AAPL", "NVDA"])

    let assessment = makeMarketDataNoFirstDataRecoveryAssessment(
        desiredMarketData: subscriptions,
        activeMarketData: subscriptions,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue,
        lastMarketDataReceivedAt: nil,
        lastSubscriptionAcknowledgedAt: acknowledgedAt,
        now: now,
        feed: .stocksIEX,
        lastRecoveryAt: nil,
        recoveryCount: 0,
        maximumRecoveryCount: 3,
        firstAckGrace: 90,
        recoveryMinimumInterval: 300
    )

    #expect(assessment.shouldRecover)
    #expect(assessment.reason?.contains("AAPL, NVDA") == true)
}

@Test("No-first-data recovery assessment does not fire outside market hours or before throttle clears")
func marketDataNoFirstDataRecoveryAssessmentRespectsWindowAndThrottle() throws {
    let afterHours = try #require(DateCodec.parseISO8601("2026-05-05T23:00:00Z"))
    let subscriptions = MarketDataSubscriptionSet(quotes: ["AAPL"], trades: ["AAPL"])

    let outsideWindow = makeMarketDataNoFirstDataRecoveryAssessment(
        desiredMarketData: subscriptions,
        activeMarketData: subscriptions,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue,
        lastMarketDataReceivedAt: nil,
        lastSubscriptionAcknowledgedAt: afterHours.addingTimeInterval(-600),
        now: afterHours,
        feed: .stocksIEX,
        lastRecoveryAt: nil,
        recoveryCount: 0,
        maximumRecoveryCount: 3,
        firstAckGrace: 90,
        recoveryMinimumInterval: 300
    )
    #expect(outsideWindow.shouldRecover == false)

    let testFeedNow = afterHours
    let throttled = makeMarketDataNoFirstDataRecoveryAssessment(
        desiredMarketData: subscriptions,
        activeMarketData: subscriptions,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue,
        lastMarketDataReceivedAt: nil,
        lastSubscriptionAcknowledgedAt: testFeedNow.addingTimeInterval(-600),
        now: testFeedNow,
        feed: .test,
        lastRecoveryAt: testFeedNow.addingTimeInterval(-60),
        recoveryCount: 1,
        maximumRecoveryCount: 3,
        firstAckGrace: 90,
        recoveryMinimumInterval: 300
    )
    #expect(throttled.shouldRecover == false)
}

@Test("Engine throttles market-data-driven readiness recomputation")
func engineThrottlesMarketDataDrivenReadinessRecomputation() async {
    final class MutableClock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Date

        init(_ value: Date) {
            self.value = value
        }

        func set(_ value: Date) {
            lock.lock()
            self.value = value
            lock.unlock()
        }

        func now() -> Date {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    final class CountingKeyReader: KeyReading, @unchecked Sendable {
        private let lock = NSLock()
        private var readCount = 0

        func readKey(service: String, account: String) -> String? {
            lock.lock()
            readCount += 1
            lock.unlock()
            return "present"
        }

        func count() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return readCount
        }
    }

    let clock = MutableClock(Date(timeIntervalSince1970: 1_700_002_000))
    let keyReader = CountingKeyReader()
    let engine = Engine(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: keyReader,
            now: clock.now,
            sessionCache: nil
        ),
        marketDataReadinessPublishMinimumInterval: 60,
        nowDate: clock.now
    )

    await engine.handleMarketDataEvent(.connectionStateChanged(.subscribed))
    let afterConnectionEvent = keyReader.count()

    clock.set(Date(timeIntervalSince1970: 1_700_002_001))
    await engine.handleMarketDataEvent(
        .quote(
            MarketDataQuoteEvent(
                symbol: "NVDA",
                bidPrice: 100,
                askPrice: 101,
                bidSize: 1,
                askSize: 1,
                timestamp: "2026-04-30T13:30:01Z"
            )
        )
    )
    let afterFirstMarketDataEvent = keyReader.count()
    #expect(afterFirstMarketDataEvent > afterConnectionEvent)

    for offset in 2...10 {
        clock.set(Date(timeIntervalSince1970: 1_700_002_000 + TimeInterval(offset)))
        await engine.handleMarketDataEvent(
            .trade(
                MarketDataTradeEvent(
                    symbol: "NVDA",
                    price: 100 + Double(offset),
                    size: 1,
                    timestamp: "2026-04-30T13:30:\(String(format: "%02d", offset))Z"
                )
            )
        )
    }
    #expect(keyReader.count() == afterFirstMarketDataEvent)

    clock.set(Date(timeIntervalSince1970: 1_700_002_062))
    await engine.handleMarketDataEvent(
        .bar(
            MarketDataBarEvent(
                symbol: "NVDA",
                open: 100,
                high: 104,
                low: 99,
                close: 103,
                volume: 10,
                timestamp: "2026-04-30T13:31:02Z"
            )
        )
    )
    #expect(keyReader.count() > afterFirstMarketDataEvent)
}

@Test("Store event stream uses bounded newest buffering while preserving latest snapshot truth")
func storeEventStreamUsesBoundedNewestBufferingWhilePreservingLatestSnapshotTruth() async {
    let store = Store(eventBufferLimit: 3)

    for index in 0..<20 {
        await store.publishMarketQuote(
            MarketDataQuoteEvent(
                symbol: "NVDA",
                bidPrice: 100 + Double(index),
                askPrice: 101 + Double(index),
                bidSize: 1,
                askSize: 1,
                timestamp: "2026-04-30T13:30:\(String(format: "%02d", index))Z"
            )
        )
    }

    let snapshot = await store.snapshot()
    #expect(snapshot.eventStreamDiagnostics.bufferLimit == 3)
    #expect(snapshot.eventStreamDiagnostics.marketDataRawUpdateCount == 20)
    #expect(snapshot.eventStreamDiagnostics.marketDataRawUpdateCountsByName["market_quote"] == 20)
    #expect(snapshot.eventStreamDiagnostics.marketDataUIInvalidationYieldCount == 1)
    #expect(snapshot.eventStreamDiagnostics.marketDataUIInvalidationCoalescedCount == 19)
    #expect(snapshot.eventStreamDiagnostics.yieldedCount == 1)
    #expect(snapshot.eventStreamDiagnostics.droppedCount == 0)
    #expect(snapshot.quotesBySymbol["NVDA"]?.bidPrice == 119)

    var iterator = store.events.makeAsyncIterator()
    var bufferedNames: [String] = []
    for _ in 0..<1 {
        if let event = await iterator.next() {
            bufferedNames.append(event.name)
        }
    }

    #expect(bufferedNames == ["market_data"])
}

@Test("Bounded Store event buffering keeps latest non-market invalidation visible")
func boundedStoreEventBufferingKeepsLatestNonMarketInvalidationVisible() async {
    let store = Store(eventBufferLimit: 3)

    for index in 0..<12 {
        await store.publishMarketTrade(
            MarketDataTradeEvent(
                symbol: "AAPL",
                price: 200 + Double(index),
                size: 1,
                timestamp: "2026-04-30T13:31:\(String(format: "%02d", index))Z"
            )
        )
    }
    await store.setConnectionState(.subscribed)

    let snapshot = await store.snapshot()
    #expect(snapshot.connectionState == TradeUpdatesConnectionState.subscribed.rawValue)
    #expect(snapshot.eventStreamDiagnostics.marketDataRawUpdateCount == 12)
    #expect(snapshot.eventStreamDiagnostics.marketDataUIInvalidationYieldCount == 1)
    #expect(snapshot.eventStreamDiagnostics.marketDataUIInvalidationCoalescedCount == 11)

    var iterator = store.events.makeAsyncIterator()
    var bufferedNames: [String] = []
    for _ in 0..<2 {
        if let event = await iterator.next() {
            bufferedNames.append(event.name)
        }
    }

    #expect(bufferedNames.contains("market_data"))
    #expect(bufferedNames.contains("connection_state"))
}

@Test("Market-data UI invalidation rearms after a snapshot read")
func marketDataUIInvalidationRearmsAfterSnapshotRead() async {
    let store = Store(eventBufferLimit: 10)

    await store.publishMarketQuote(
        MarketDataQuoteEvent(
            symbol: "NVDA",
            bidPrice: 100,
            askPrice: 101,
            bidSize: 1,
            askSize: 1,
            timestamp: "2026-04-30T13:30:00Z"
        )
    )
    _ = await store.snapshot()
    await store.publishMarketTrade(
        MarketDataTradeEvent(
            symbol: "NVDA",
            price: 102,
            size: 1,
            timestamp: "2026-04-30T13:30:01Z"
        )
    )

    let snapshot = await store.snapshot()
    #expect(snapshot.eventStreamDiagnostics.marketDataRawUpdateCount == 2)
    #expect(snapshot.eventStreamDiagnostics.marketDataUIInvalidationYieldCount == 2)
    #expect(snapshot.eventStreamDiagnostics.marketDataUIInvalidationCoalescedCount == 0)
    #expect(snapshot.quotesBySymbol["NVDA"]?.lastPrice == 102)
}

@Test("Store skips content-identical job snapshot publication")
func storeSkipsContentIdenticalJobSnapshotPublication() async {
    let store = Store()
    let timestamp = Date(timeIntervalSince1970: 1_742_920_000)
    let job = JobSummary(
        jobId: "job-1",
        type: .monitor,
        status: .running,
        createdAt: timestamp,
        updatedAt: timestamp,
        progress: 0.5,
        message: "Running",
        proposalId: nil,
        runId: nil
    )

    await store.setJobs([job])
    let afterFirst = await store.snapshot()
    await store.setJobs([job])
    let afterSecond = await store.snapshot()

    #expect(afterSecond.jobs == [job])
    #expect(afterSecond.eventStreamDiagnostics.yieldedCount == afterFirst.eventStreamDiagnostics.yieldedCount)
}

@Test("Agent control status exposes Store event stream diagnostics")
func agentControlStatusExposesStoreEventStreamDiagnostics() async {
    let engine = Engine()

    await engine.store.publishMarketQuote(
        MarketDataQuoteEvent(
            symbol: "NVDA",
            bidPrice: 200,
            askPrice: 201,
            bidSize: 1,
            askSize: 1,
            timestamp: "2026-04-30T13:32:00Z"
        )
    )

    let status = await engine.agentControlStatusJSON()
    guard case .object(let payload) = status,
          case .object(let stream)? = payload["storeEventStream"] else {
        Issue.record("Expected agent-control status to include Store event-stream diagnostics.")
        return
    }

    #expect(stream["bufferLimit"] != nil)
    #expect(stream["yieldedCount"] != nil)
    #expect(stream["enqueuedCount"] != nil)
    #expect(stream["droppedCount"] != nil)
    #expect(stream["terminatedYieldCount"] != nil)
    #expect(stream["lastDroppedEventName"] != nil)
    #expect(stream["droppedEventCountsByName"] != nil)
    #expect(stream["marketDataRawUpdateCount"] != nil)
    #expect(stream["marketDataRawUpdateCountsByName"] != nil)
    #expect(stream["marketDataUIInvalidationYieldCount"] != nil)
    #expect(stream["marketDataUIInvalidationCoalescedCount"] != nil)
    #expect(stream["marketDataUIInvalidationDroppedCount"] != nil)
}

@Test("Agent control status exposes selected and effective market-data feed")
func agentControlStatusExposesSelectedAndEffectiveMarketDataFeed() async throws {
    let engine = Engine(configuration: Configuration(marketDataFeed: .stocksSIP))

    let status = await engine.agentControlStatusJSON()
    let payload = try #require(status.objectValue)
    let feed = try #require(payload["marketDataFeed"]?.objectValue)

    #expect(feed["selected"] == .string(MarketDataFeed.stocksSIP.rawValue))
    #expect(feed["effective"] == .string(MarketDataFeed.stocksSIP.rawValue))
    #expect(feed["feedCode"] == .string("sip"))
    #expect(feed["streamPath"] == .string("/v2/sip"))
    #expect(feed["streamEndpoint"] == .string("wss://stream.data.alpaca.markets/v2/sip"))
    #expect(feed["silentFallback"] == .bool(false))
    #expect(feed["ownerFacingState"] == .string("idle"))
    #expect(feed["ownerFacingLabel"] == .string("idle"))
    #expect(feed["transportHealthy"] == .bool(true))
    #expect(feed["fullyHealthy"] == .bool(true))
    #expect(feed["awaitingFirstData"] == .bool(false))
    #expect(feed["outsideRegularUSMarketHours"] != nil)
    #expect(feed["blocker"] == .null)
    #expect(feed["isRunning"] != nil)
    #expect(feed["hasSocketTask"] != nil)
    #expect(feed["lastErrorMessage"] != nil)
    #expect(feed["reconnectRequestCount"] != nil)

    let tradeStream = try #require(payload["tradeUpdatesStream"]?.objectValue)
    #expect(tradeStream["endpoint"] == .string("wss://paper-api.alpaca.markets/stream"))
    #expect(tradeStream["connectionState"] == .string(TradeUpdatesConnectionState.disconnected.rawValue))
    #expect(tradeStream["ownerFacingState"] == .string("disconnected"))
    #expect(tradeStream["ownerFacingLabel"] == .string("disconnected"))
    #expect(tradeStream["healthy"] == .bool(false))
    #expect(tradeStream["blocker"] == .string("Trade-update stream is disconnected."))
    #expect(tradeStream["lastAuthorizationStatus"] != nil)
    #expect(tradeStream["lastError"] != nil)
}

@Test("Agent control status reconciles runtime stream truth into Store")
func agentControlStatusReconcilesRuntimeStreamTruthIntoStore() async throws {
    let tradeUpdatesStream = AlpacaTradeUpdatesStream(environment: .paper)
    await tradeUpdatesStream.handleIncomingForTesting(data: Data("""
    [
      {"stream":"authorization","data":{"status":"authorized"}},
      {"stream":"listening","data":{"streams":["trade_updates"]}}
    ]
    """.utf8))

    let marketDataStream = AlpacaMarketDataStream(environment: .paper, feed: .test)
    await marketDataStream.setWatchSymbols(["AAPL"])
    await marketDataStream.handleIncomingForTesting(data: Data(#"[{"T":"success","msg":"authenticated"}]"#.utf8))
    await marketDataStream.handleIncomingForTesting(data: Data(#"[{"T":"subscription","quotes":["AAPL"],"trades":["AAPL"]}]"#.utf8))

    let engine = Engine(
        configuration: Configuration(marketDataFeed: .test),
        tradeUpdatesStream: tradeUpdatesStream,
        marketDataStream: marketDataStream
    )

    let status = await engine.agentControlStatusJSON()
    let payload = try #require(status.objectValue)
    let storeSnapshot = await engine.store.snapshot()

    #expect(payload["tradeUpdatesConnectionState"] == .string(TradeUpdatesConnectionState.subscribed.rawValue))
    #expect(payload["marketDataConnectionState"] == .string(MarketDataConnectionState.subscribed.rawValue))
    #expect(storeSnapshot.connectionState == TradeUpdatesConnectionState.subscribed.rawValue)
    #expect(storeSnapshot.marketDataConnectionState == MarketDataConnectionState.subscribed.rawValue)
    #expect(storeSnapshot.marketDataDesiredSubscriptions.quotes == ["AAPL"])
    #expect(storeSnapshot.marketDataSubscriptions.quotes == ["AAPL"])

    let tradeStream = try #require(payload["tradeUpdatesStream"]?.objectValue)
    #expect(tradeStream["ownerFacingState"] == .string("listening"))
    #expect(tradeStream["healthy"] == .bool(true))

    let feed = try #require(payload["marketDataFeed"]?.objectValue)
    #expect(feed["ownerFacingState"] == .string("awaiting_first_data"))
    #expect(feed["ownerFacingLabel"] == .string("awaiting first data"))
    #expect(feed["transportHealthy"] == .bool(true))
    #expect(feed["fullyHealthy"] == .bool(false))
}

@Test("Market-data readiness reports feed auth error before generic subscription pending")
func marketDataReadinessReportsFeedAuthError() {
    let readiness = makeMarketDataStreamReadinessPresentation(
        connectionState: MarketDataConnectionState.authenticated.rawValue,
        desiredMarketData: MarketDataSubscriptionSet(quotes: ["NVDA"], trades: ["NVDA"]),
        activeMarketData: .empty,
        lastMarketDataReceivedAt: nil,
        now: Date(timeIntervalSince1970: 1_779_000_000),
        lastErrorCode: 401,
        lastErrorMessage: "not authenticated"
    )

    #expect(readiness.state == "auth_failed")
    #expect(readiness.label == "auth failed")
    #expect(readiness.blocker?.contains("401") == true)
    #expect(readiness.blocker?.contains("not authenticated") == true)
}

@Test("Market-data readiness reports SIP entitlement error distinctly")
func marketDataReadinessReportsSIPEntitlementError() {
    let readiness = makeMarketDataStreamReadinessPresentation(
        connectionState: MarketDataConnectionState.connected.rawValue,
        desiredMarketData: MarketDataSubscriptionSet(quotes: ["NVDA"], trades: ["NVDA"]),
        activeMarketData: .empty,
        lastMarketDataReceivedAt: nil,
        now: Date(timeIntervalSince1970: 1_779_000_000),
        lastErrorCode: 409,
        lastErrorMessage: "insufficient subscription"
    )

    #expect(readiness.state == "auth_failed")
    #expect(readiness.label == "auth failed")
    #expect(readiness.blocker?.contains("409") == true)
    #expect(readiness.blocker?.contains("insufficient subscription") == true)
}

@Test("Market-data readiness reports subscription request failure distinctly")
func marketDataReadinessReportsSubscriptionRequestError() {
    let readiness = makeMarketDataStreamReadinessPresentation(
        connectionState: MarketDataConnectionState.authenticated.rawValue,
        desiredMarketData: MarketDataSubscriptionSet(quotes: ["NVDA"], trades: ["NVDA"]),
        activeMarketData: .empty,
        lastMarketDataReceivedAt: nil,
        now: Date(timeIntervalSince1970: 1_779_000_000),
        lastErrorCode: 405,
        lastErrorMessage: "symbol limit exceeded"
    )

    #expect(readiness.state == "subscription_failed")
    #expect(readiness.label == "subscription failed")
    #expect(readiness.blocker?.contains("405") == true)
    #expect(readiness.blocker?.contains("symbol limit exceeded") == true)
}

@Test("Agent control status redacts account identifiers")
func agentControlStatusRedactsAccountIdentifiers() async throws {
    let engine = Engine()
    await engine.store.applyStartupSnapshot(
        account: Account(
            id: "acct-sensitive",
            status: "ACTIVE",
            cash: "500",
            buyingPower: "1000"
        ),
        positions: [],
        openOrders: []
    )

    let status = await engine.agentControlStatusJSON()
    let payload = try #require(status.objectValue)
    let account = try #require(payload["account"]?.objectValue)

    #expect(account["id"] == nil)
    #expect(account["accountIdentifierRedacted"] == .bool(true))
    #expect(account["status"] == .string("ACTIVE"))
}

@Test("Agent control status exposes safe build identity and Portfolio Watch live chain diagnostics")
func agentControlStatusExposesBuildIdentityAndPortfolioWatchLiveChainDiagnostics() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("portfolio-watch-status-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let chartWallStore = PortfolioWatchChartWallConfigurationStore(
        fileURL: root.appendingPathComponent("chart-wall.json", isDirectory: false)
    )
    let now = Date(timeIntervalSince1970: 1_777_800_000)
    _ = try await chartWallStore.upsert(
        PortfolioWatchChartWallConfiguration(
            configurationId: "portfolio-watch-status",
            selectedSymbols: ["NVDA", "AAPL"],
            updatedBy: "test",
            updateSource: .ui,
            createdAt: now,
            updatedAt: now
        )
    )
    let engine = Engine(portfolioWatchChartWallConfigurationStore: chartWallStore)
    await engine.store.setWatchlistSymbols(["AAPL", "NVDA"])
    await engine.store.publishMarketDataDesiredSubscription(
        MarketDataSubscriptionSet(quotes: ["AAPL", "NVDA"], trades: ["AAPL", "NVDA"])
    )
    await engine.store.publishMarketDataSubscription(
        MarketDataSubscriptionSet(quotes: ["AAPL", "NVDA"], trades: ["AAPL", "NVDA"])
    )
    await engine.store.publishMarketTrade(
        MarketDataTradeEvent(
            symbol: "NVDA",
            price: 920.25,
            size: 10,
            timestamp: "2026-05-04T14:30:00Z"
        )
    )

    let status = await engine.agentControlStatusJSON()
    let payload = try #require(status.objectValue)
    let buildIdentity = try #require(payload["buildIdentity"]?.objectValue)
    let marketDataRecovery = try #require(payload["marketDataRecovery"]?.objectValue)
    let portfolioWatchRuntime = try #require(payload["portfolioWatchRuntime"]?.objectValue)
    let symbols = try #require(portfolioWatchRuntime["symbols"]?.arrayValue)
    let symbolObjects = symbols.compactMap { value -> [String: JSONValue]? in
        value.objectValue
    }
    let nvda = try #require(symbolObjects.first { object in
        object["symbol"] == JSONValue.string("NVDA")
    })
    let aapl = try #require(symbolObjects.first { object in
        object["symbol"] == JSONValue.string("AAPL")
    })

    #expect(buildIdentity["tradingKitBuildInfo"] == JSONValue.string(Engine.buildInfo))
    #expect(marketDataRecovery["noFirstDataRecoveryCount"] == JSONValue.number(0))
    #expect(marketDataRecovery["lastNoFirstDataRecoveryAt"] == JSONValue.null)
    #expect(marketDataRecovery["lastNoFirstDataRecoveryReason"] == JSONValue.null)
    #expect(marketDataRecovery["firstAckGraceSeconds"] != nil)
    #expect(marketDataRecovery["minimumRecoveryIntervalSeconds"] != nil)
    #expect(buildIdentity["processIdentifier"] != nil)
    #expect(buildIdentity["executablePath"] != nil)
    #expect(portfolioWatchRuntime["selectedSymbols"] == JSONValue.array([.string("NVDA"), .string("AAPL")]))
    #expect(portfolioWatchRuntime["selectedCount"] == JSONValue.number(2))
    #expect(portfolioWatchRuntime["requestedSelectedCount"] == JSONValue.number(2))
    #expect(portfolioWatchRuntime["activeSelectedCount"] == JSONValue.number(2))
    #expect(portfolioWatchRuntime["pricedSelectedCount"] == JSONValue.number(1))
    #expect(portfolioWatchRuntime["activeButNoUsablePriceSymbols"] == JSONValue.array([.string("AAPL")]))
    #expect(nvda["latestPrice"] == JSONValue.number(920.25))
    #expect(nvda["latestPriceSource"] == JSONValue.string("Last Trade"))
    #expect(aapl["latestPrice"] == JSONValue.null)
}

@Test("Agent control status exposes owner-surface runtime diagnostics when registered")
func agentControlStatusExposesOwnerSurfaceRuntimeDiagnosticsWhenRegistered() async {
    let engine = Engine()
    await engine.setOwnerSurfaceRuntimeDiagnosticsProvider {
        .object([
            "strategyBriefCandidate": .object([
                "rebuildCount": .number(1),
                "cacheHitCount": .number(2),
                "scannedMessageCount": .number(3)
            ])
        ])
    }

    let status = await engine.agentControlStatusJSON()
    guard case .object(let payload) = status,
          case .object(let ownerSurfaceRuntime)? = payload["ownerSurfaceRuntime"],
          case .object(let strategyBriefCandidate)? = ownerSurfaceRuntime["strategyBriefCandidate"] else {
        Issue.record("Expected owner-surface runtime diagnostics to be present.")
        return
    }

    #expect(strategyBriefCandidate["rebuildCount"] == .number(1))
    #expect(strategyBriefCandidate["cacheHitCount"] == .number(2))
    #expect(strategyBriefCandidate["scannedMessageCount"] == .number(3))
}

@Test("Agent control status exposes bounded job summary projection diagnostics")
func agentControlStatusExposesBoundedJobSummaryProjectionDiagnostics() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-status-projection-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }

    let jobStore = JobStore(jobsDirectory: jobsDirectory)
    let engine = Engine(jobStore: jobStore)
    let now = Date(timeIntervalSince1970: 1_742_920_000)
    _ = try await jobStore.upsert(
        JobRecord(
            jobId: "running-status",
            type: .monitor,
            createdAt: now,
            updatedAt: now,
            status: .running,
            progress: 0.2,
            message: "Running",
            parameters: [:]
        )
    )
    _ = try await jobStore.upsert(
        JobRecord(
            jobId: "completed-status",
            type: .monitor,
            createdAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-30),
            status: .succeeded,
            progress: 1,
            message: "Done",
            parameters: [:]
        )
    )

    _ = try await engine.listJobs()
    let status = await engine.agentControlStatusJSON()
    guard case .object(let payload) = status,
          case .object(let projection)? = payload["jobSummaryProjection"] else {
        Issue.record("Expected agent-control status to include job summary projection diagnostics.")
        return
    }

    #expect(payload["jobsCount"] == .number(2))
    #expect(payload["visibleJobsCount"] == .number(2))
    #expect(projection["visibleCap"] != nil)
    #expect(projection["visibleCount"] == .number(2))
    #expect(projection["totalJobsCount"] == .number(2))
    #expect(projection["listRequestCount"] != nil)
    #expect(projection["cacheHitCount"] != nil)
    #expect(projection["fullScanCount"] != nil)
    #expect(projection["incrementalUpdateCount"] != nil)
    #expect(projection["lastScannedCount"] != nil)
    #expect(projection["lastOutputCount"] != nil)
    #expect(projection["jobProgressPersistCount"] != nil)
}

@Test("JobRunner progress persistence updates bounded summary diagnostics incrementally")
func jobRunnerProgressPersistenceUpdatesBoundedSummaryDiagnosticsIncrementally() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-runner-progress-diagnostics-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }

    let jobStore = JobStore(jobsDirectory: jobsDirectory)
    let runner = JobRunner(jobStore: jobStore)
    _ = try await runner.listActiveAndRecentSummaries(recentCompletedLimit: 5)
    await runner.configure(
        monitorExecutor: { _, updateProgress in
            await updateProgress(0.5, "Halfway")
            return JobExecutionReport()
        },
        replayBatchExecutor: nil,
        rssPollExecutor: nil,
        newsRetentionExecutor: nil,
        analystSignalsExecutor: nil,
        recentNewsAnalystExecutor: nil,
        portfolioRiskAnalystExecutor: nil,
        maintenanceRetentionExecutor: nil
    )

    let submitted = try await runner.submit(type: .monitor, parameters: [:])
    var finalJob = try await runner.get(jobId: submitted.jobId)
    for _ in 0..<100 where finalJob.status != .succeeded {
        await Task.yield()
        finalJob = try await runner.get(jobId: submitted.jobId)
    }

    let summaries = try await runner.listActiveAndRecentSummaries(recentCompletedLimit: 5)
    let diagnostics = try await runner.summaryProjectionDiagnostics()

    #expect(finalJob.status == .succeeded)
    #expect(summaries.contains { $0.jobId == submitted.jobId && $0.status == .succeeded })
    #expect(diagnostics.fullScanCount == 1)
    #expect(diagnostics.incrementalUpdateCount >= 3)
    #expect(diagnostics.jobProgressPersistCount == 1)
    #expect(diagnostics.lastScannedCount == 1)
}

@Test("PM context carries host availability readiness truth")
func pmContextCarriesHostAvailabilityReadinessTruth() {
    let readiness = AlwaysOnReadinessState(
        status: .pausedByHost,
        summary: "Paused by host sleep or suspension.",
        detail: AlwaysOnReadinessState.hostAvailabilityContract,
        blockers: ["Host sleep or suspension pauses active app workflows until wake/relaunch recovery runs."],
        lastUpdatedAt: Date(timeIntervalSince1970: 1_700_001_000),
        lastLifecycleEvent: .hostWillSleep
    )

    let context = makePMContextPack(
        profiles: [],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: [],
        watchlistSymbols: [],
        approvalRequests: [],
        decisions: [],
        delegations: [],
        analystMemos: [],
        systemReadiness: readiness,
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: Date(timeIntervalSince1970: 1_700_001_001)
    )

    #expect(context.systemReadiness.status == .pausedByHost)
    #expect(context.systemReadiness.blockers.first?.contains("wake/relaunch recovery") == true)
}

@Test("Engine host wake recovery reconnects bounded app workflows and preserves market-data requests")
func engineHostWakeRecoveryReconnectsAndPreservesMarketDataRequests() async {
    final class StubOpenAIProvider: @unchecked Sendable, OpenAIKeyStatusProviding {
        func apiKey() -> String? { nil }
        func isConfigured() -> Bool { false }
        func credentialResolution() -> OpenAICredentialResolution {
            OpenAICredentialResolution(
                status: .missingKey,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "No key configured."
            )
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "unused",
                outputExcerpt: "unused"
            )
        }

        func preflightOpenAIKeyAccess() async throws -> Bool {
            false
        }
    }

    struct EmptyKeyReader: KeyReading {
        func readKey(service: String, account: String) -> String? { nil }
    }

    let rest = MockRESTClient()
    let keychainProvider = KeychainCredentialsProvider(keyReader: EmptyKeyReader())
    let marketDataStream = AlpacaMarketDataStream(
        environment: .paper,
        feed: .test,
        keychainProvider: keychainProvider,
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        }
    )
    let tradeUpdatesStream = AlpacaTradeUpdatesStream(
        environment: .paper,
        keychainProvider: keychainProvider,
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        }
    )
    let engine = Engine(
        configuration: Configuration(marketDataFeed: .test),
        tradeUpdatesStream: tradeUpdatesStream,
        marketDataStream: marketDataStream,
        openAIKeyStatusProvider: StubOpenAIProvider(),
        analystWorkerLauncher: StubLauncher(),
        keychainProvider: keychainProvider,
        restClientFactory: { _ in rest },
        pmPendingPaperExecutionRetrySleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        }
    )

    await engine.start()
    await engine.setWatchSymbols(["nvda"])
    let reconciliationCountBeforeWake = await rest.fetchAccountCallCount()

    await engine.handleHostAvailabilityEvent(.hostWillSleep)
    var snapshot = await engine.store.snapshot()
    #expect(snapshot.alwaysOnReadiness.status == .pausedByHost)

    await engine.handleHostAvailabilityEvent(.hostDidWake)
    snapshot = await engine.store.snapshot()

    #expect(await rest.fetchAccountCallCount() >= reconciliationCountBeforeWake + 1)
    #expect(snapshot.alwaysOnReadiness.lastRecoveryCompletedAt != nil)
    #expect(snapshot.alwaysOnReadiness.status == .needsAttention)
    #expect(await marketDataStream.currentDesiredSubscriptions().quotes == ["NVDA"])

    await engine.stop()
}

@Test("Portfolio Watch chart-wall symbols drive market-data coverage when watchlist is sparse")
func portfolioWatchChartWallSymbolsDriveMarketDataCoverageWhenWatchlistIsSparse() async throws {
    final class StubOpenAIProvider: @unchecked Sendable, OpenAIKeyStatusProviding {
        func apiKey() -> String? { nil }
        func isConfigured() -> Bool { false }
        func credentialResolution() -> OpenAICredentialResolution {
            OpenAICredentialResolution(
                status: .missingKey,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "No key configured."
            )
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "unused",
                outputExcerpt: "unused"
            )
        }

        func preflightOpenAIKeyAccess() async throws -> Bool {
            false
        }
    }

    struct EmptyKeyReader: KeyReading {
        func readKey(service: String, account: String) -> String? { nil }
    }

    let now = Date(timeIntervalSince1970: 1_700_001_500)
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("portfolio-watch-market-data-coverage-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let watchlistPersistence = FileWatchlistPersistence(
        fileURL: root.appendingPathComponent("watchlist.json", isDirectory: false)
    )
    watchlistPersistence.saveWatchlistSymbols(["NVDA"])

    let chartWallStore = PortfolioWatchChartWallConfigurationStore(
        fileURL: root.appendingPathComponent("portfolio_watch_chart_wall.json", isDirectory: false),
        now: { now }
    )
    let selected = ["NVDA", "TSM", "AVGO", "AMZN", "GOOG", "AAPL", "CRWD", "NFLX", "TSLA", "KSS", "NYCB"]
    _ = try await chartWallStore.upsert(
        PortfolioWatchChartWallConfiguration(
            selectedSymbols: selected,
            updatedBy: "owner",
            updateSource: .ui,
            createdAt: now,
            updatedAt: now
        )
    )

    let keychainProvider = KeychainCredentialsProvider(keyReader: EmptyKeyReader())
    let marketDataStream = AlpacaMarketDataStream(
        environment: .paper,
        feed: .test,
        keychainProvider: keychainProvider,
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        }
    )
    let engine = Engine(
        configuration: Configuration(marketDataFeed: .test),
        marketDataStream: marketDataStream,
        watchlistPersistence: watchlistPersistence,
        portfolioWatchChartWallConfigurationStore: chartWallStore,
        openAIKeyStatusProvider: StubOpenAIProvider(),
        analystWorkerLauncher: StubLauncher(),
        keychainProvider: keychainProvider,
        restClientFactory: { _ in MockRESTClient() },
        pmPendingPaperExecutionRetrySleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        ipcPreferredPort: 0
    )

    await engine.start()
    var desired = await marketDataStream.currentDesiredSubscriptions()
    #expect(desired.quotes == Set(selected))
    #expect(desired.trades == Set(selected))

    let updatedSelection = ["NVDA", "AAPL", "MSFT"]
    _ = try await engine.upsertPortfolioWatchChartWallConfiguration(
        PortfolioWatchChartWallConfiguration(
            selectedSymbols: updatedSelection,
            updatedBy: "owner",
            updateSource: .ui,
            createdAt: now,
            updatedAt: now.addingTimeInterval(60)
        )
    )

    desired = await marketDataStream.currentDesiredSubscriptions()
    #expect(desired.quotes == Set(updatedSelection))
    #expect(desired.trades == Set(updatedSelection))

    await engine.stop()
}

@Test("Approved pending paper execution re-requests price recovery subscriptions after host wake")
func approvedPendingPaperExecutionRequestsPriceRecoveryAfterHostWake() async throws {
    final class StubOpenAIProvider: @unchecked Sendable, OpenAIKeyStatusProviding {
        func apiKey() -> String? { nil }
        func isConfigured() -> Bool { false }
        func credentialResolution() -> OpenAICredentialResolution {
            OpenAICredentialResolution(
                status: .missingKey,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "No key configured."
            )
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "unused",
                outputExcerpt: "unused"
            )
        }

        func preflightOpenAIKeyAccess() async throws -> Bool {
            false
        }
    }

    struct EmptyKeyReader: KeyReading {
        func readKey(service: String, account: String) -> String? { nil }
    }

    let now = Date(timeIntervalSince1970: 1_700_002_000)
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("approved-pending-wake-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let keychainProvider = KeychainCredentialsProvider(keyReader: EmptyKeyReader())
    let marketDataStream = AlpacaMarketDataStream(
        environment: .paper,
        feed: .test,
        keychainProvider: keychainProvider,
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        }
    )
    let engine = Engine(
        configuration: Configuration(marketDataFeed: .test),
        marketDataStream: marketDataStream,
        watchlistPersistence: FileWatchlistPersistence(
            fileURL: root.appendingPathComponent("watchlist.json", isDirectory: false)
        ),
        pmApprovalRequestStore: PMApprovalRequestStore(
            approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true)
        ),
        openAIKeyStatusProvider: StubOpenAIProvider(),
        analystWorkerLauncher: StubLauncher(),
        keychainProvider: keychainProvider,
        restClientFactory: { _ in MockRESTClient() },
        pmPendingPaperExecutionRetryDebounceWindow: 60,
        pmPendingPaperExecutionRetrySleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        }
    )

    let request = PMApprovalRequest(
        approvalRequestId: "approval-pending-prices",
        pmId: "pm-1",
        subject: "Review PM recommendation: execute the current working paper portfolio",
        rationale: "Owner approved initial paper establishment.",
        requestType: .portfolioAction,
        status: .resolved,
        ownerResponse: .approved,
        ownerRespondedAt: now,
        paperPortfolioExecutionPendingState: PMPaperPortfolioExecutionPendingState(
            status: .waitingForUsablePrices,
            missingPriceSymbols: ["NVDA", "AAPL"],
            marketDataSubscriptionSymbols: ["NVDA", "AAPL"],
            automaticRetryEnabled: true,
            lastBlockerSummary: "Missing usable prices.",
            lastBlockerDetail: "Missing usable prices for NVDA, AAPL.",
            updatedAt: now
        ),
        createdAt: now,
        updatedAt: now
    )
    _ = try await engine.upsertPMApprovalRequest(request, source: .system)

    await engine.start()
    await engine.handleHostAvailabilityEvent(.hostDidWake)

    var subscriptions = await marketDataStream.currentDesiredSubscriptions()
    for _ in 0..<50 where !Set(subscriptions.quotes).isSuperset(of: ["AAPL", "NVDA"]) {
        try? await Task.sleep(nanoseconds: 20_000_000)
        subscriptions = await marketDataStream.currentDesiredSubscriptions()
    }
    #expect(Set(subscriptions.quotes).isSuperset(of: ["AAPL", "NVDA"]))

    await engine.stop()
}

@Test("Operational schedule job types stay explicit and exclude maintenance retention")
func operationalScheduleJobTypesStayStable() {
    #expect(
        JobType.operationalScheduleControllableCases == [
            .monitor,
            .replayBatch,
            .rssPoll,
            .newsRetention,
            .analystSignals,
            .standingAnalystReport,
            .recentNewsAnalyst,
            .portfolioRiskAnalyst
        ]
    )
    #expect(JobType.operationalScheduleControllableCases.contains(.maintenanceRetention) == false)
}

@Test("Engine placeOrder maps valid market order request")
func enginePlaceOrderMarketMapping() async throws {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    let orderID = try await engine.placeOrder(
        symbol: " aapl ",
        qty: 1,
        side: .buy,
        type: .market
    )

    #expect(orderID == "ord-test-1")
    #expect(await mockREST.placeOrderCallCount() == 1)

    let request = await mockREST.lastPlacedOrder()
    #expect(request?.symbol == "AAPL")
    #expect(request?.qty == "1")
    #expect(request?.side == .buy)
    #expect(request?.type == .market)
    #expect(request?.limitPrice == nil)
    #expect(request?.timeInForce == .day)
}

@Test("Engine placeOrder rejects limit orders without limit price")
func enginePlaceOrderLimitRequiresPrice() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .limit
        )
        Issue.record("Expected limit-order validation error for missing limit price.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .limitPriceRequired)
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("Engine placeOrder returns typed validation errors for invalid inputs")
func enginePlaceOrderValidationErrors() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.placeOrder(
            symbol: " ",
            qty: 1,
            side: .buy,
            type: .market
        )
        Issue.record("Expected empty-symbol validation error.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .emptySymbol)
    } catch {
        Issue.record("Unexpected error type for empty symbol: \(error)")
    }

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 0,
            side: .buy,
            type: .market
        )
        Issue.record("Expected invalid-quantity validation error.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .invalidQuantity)
    } catch {
        Issue.record("Unexpected error type for quantity: \(error)")
    }

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .limit,
            limitPrice: 0
        )
        Issue.record("Expected invalid-limit-price validation error.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .invalidLimitPrice)
    } catch {
        Issue.record("Unexpected error type for limit price: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("Engine placeOrder calls REST once per submission")
func enginePlaceOrderCallCount() async throws {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    _ = try await engine.placeOrder(
        symbol: "AAPL",
        qty: 1,
        side: .buy,
        type: .market
    )
    _ = try await engine.placeOrder(
        symbol: "MSFT",
        qty: 2,
        side: .sell,
        type: .limit,
        limitPrice: Decimal(string: "300.50"),
        timeInForce: .gtc
    )

    #expect(await mockREST.placeOrderCallCount() == 2)
    let last = await mockREST.lastPlacedOrder()
    #expect(last?.symbol == "MSFT")
    #expect(last?.timeInForce == .gtc)
}

@Test("Engine placeOrder maps bracket request payload")
func enginePlaceOrderBracketMapping() async throws {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    _ = try await engine.placeOrder(
        symbol: "AAPL",
        qty: 1,
        side: .buy,
        type: .limit,
        limitPrice: Decimal(string: "190"),
        bracket: BracketOrderInput(
            takeProfitLimitPrice: Decimal(string: "194")!,
            stopLossStopPrice: Decimal(string: "188")!,
            stopLossLimitPrice: Decimal(string: "187.5")!
        )
    )

    #expect(await mockREST.placeOrderCallCount() == 1)
    let request = await mockREST.lastPlacedOrder()
    #expect(request?.orderClass == .bracket)
    #expect(request?.takeProfit?.limitPrice == "194")
    #expect(request?.stopLoss?.stopPrice == "188")
    #expect(request?.stopLoss?.limitPrice == "187.5")
}

@Test("Engine placeOrder maps valid option market order request")
func enginePlaceOrderOptionMarketMapping() async throws {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    let orderID = try await engine.placeOrder(
        instrumentType: .option,
        symbol: " aapl240119c00190000 ",
        qty: 2,
        side: .buy,
        type: .market,
        timeInForce: .day
    )

    #expect(orderID == "ord-test-1")
    let request = await mockREST.lastPlacedOrder()
    #expect(request?.instrumentType == .option)
    #expect(request?.symbol == "AAPL240119C00190000")
    #expect(request?.qty == "2")
    #expect(request?.orderClass == nil)
    #expect(request?.takeProfit == nil)
    #expect(request?.stopLoss == nil)
}

@Test("Engine placeOrder requires limit price for option limit order")
func enginePlaceOrderOptionLimitRequiresPrice() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.placeOrder(
            instrumentType: .option,
            symbol: "AAPL240119C00190000",
            qty: 1,
            side: .buy,
            type: .limit,
            timeInForce: .day
        )
        Issue.record("Expected limit-order validation error for missing option limit price.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .limitPriceRequired)
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("NewOrderRequest encoder keeps equity-only fields out of option payload")
func newOrderRequestOptionEncodingIsolation() throws {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let equity = NewOrderRequest(
        instrumentType: .equity,
        symbol: "AAPL",
        qty: "1",
        side: .buy,
        type: .limit,
        timeInForce: .day,
        limitPrice: "190",
        orderClass: .bracket,
        takeProfit: TakeProfitRequest(limitPrice: "194"),
        stopLoss: StopLossRequest(stopPrice: "188")
    )
    let option = NewOrderRequest(
        instrumentType: .option,
        symbol: "AAPL240119C00190000",
        qty: "1",
        side: .buy,
        type: .limit,
        timeInForce: .day,
        limitPrice: "1.25",
        orderClass: .bracket,
        takeProfit: TakeProfitRequest(limitPrice: "2.00"),
        stopLoss: StopLossRequest(stopPrice: "0.80")
    )

    let equityJSON = try JSONSerialization.jsonObject(with: encoder.encode(equity)) as? [String: Any]
    let optionJSON = try JSONSerialization.jsonObject(with: encoder.encode(option)) as? [String: Any]

    #expect(equityJSON?["order_class"] as? String == "bracket")
    #expect(equityJSON?["take_profit"] != nil)
    #expect(equityJSON?["stop_loss"] != nil)
    #expect(optionJSON?["order_class"] == nil)
    #expect(optionJSON?["take_profit"] == nil)
    #expect(optionJSON?["stop_loss"] == nil)
}

@Test("Engine sell with no position triggers short preflight checks")
func engineShortSellPreflightPath() async throws {
    let mockREST = MockRESTClient()
    await mockREST.setAccount(
        Account(
            id: "acct-short-ok",
            status: "ACTIVE",
            cash: "5000",
            buyingPower: "10000",
            equity: "5000",
            multiplier: "2"
        )
    )
    await mockREST.setAsset(symbol: "AAPL", shortable: true)

    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    _ = try await engine.placeOrder(
        symbol: "AAPL",
        qty: 1,
        side: .sell,
        type: .market
    )

    #expect(await mockREST.fetchAccountCallCount() == 1)
    #expect(await mockREST.fetchAssetCallCount() == 1)
    #expect(await mockREST.placeOrderCallCount() == 1)
}

@Test("Engine blocks short sell when equity is below 2000")
func engineShortBlockedByAccount() async {
    let mockREST = MockRESTClient()
    await mockREST.setAccount(
        Account(
            id: "acct-short-blocked",
            status: "ACTIVE",
            cash: "1000",
            buyingPower: "1000",
            equity: "1500",
            multiplier: "1"
        )
    )

    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .sell,
            type: .market
        )
        Issue.record("Expected short-sell block for low-equity account.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .shortNotAllowedByAccount)
    } catch {
        Issue.record("Unexpected error for short-account preflight: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("Engine blocks short sell when symbol is not shortable")
func engineShortBlockedByAsset() async {
    let mockREST = MockRESTClient()
    await mockREST.setAccount(
        Account(
            id: "acct-short-ok",
            status: "ACTIVE",
            cash: "5000",
            buyingPower: "10000",
            equity: "5000",
            multiplier: "2"
        )
    )
    await mockREST.setAsset(symbol: "AAPL", shortable: false)

    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .sell,
            type: .market
        )
        Issue.record("Expected short-sell block for non-shortable symbol.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .symbolNotShortable)
    } catch {
        Issue.record("Unexpected error for shortable preflight: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("Engine placeOrder rejects invalid bracket relation for buy limit orders")
func enginePlaceOrderBracketRelationValidation() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .limit,
            limitPrice: Decimal(string: "190"),
            bracket: BracketOrderInput(
                takeProfitLimitPrice: Decimal(string: "189")!,
                stopLossStopPrice: Decimal(string: "191")!
            )
        )
        Issue.record("Expected invalid bracket relation validation error.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .invalidBracketRelation)
    } catch {
        Issue.record("Unexpected error type for bracket relation: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("Engine replaceOrder validates and maps request")
func engineReplaceOrderValidationAndMapping() async throws {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    let replacementID = try await engine.replaceOrder(
        orderID: " ord-open-1 ",
        qty: 3,
        limitPrice: Decimal(string: "191.25")
    )

    #expect(replacementID == "ord-replace-1")
    #expect(await mockREST.replaceOrderCallCount() == 1)
    let invocation = await mockREST.lastReplaceInvocation()
    #expect(invocation?.orderId == "ord-open-1")
    #expect(invocation?.request.qty == "3")
    #expect(invocation?.request.limitPrice == "191.25")
}

@Test("Engine replaceOrder requires at least one changed field")
func engineReplaceOrderRequiresChanges() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.replaceOrder(orderID: "ord-open-1")
        Issue.record("Expected replace validation error when no changes were provided.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .replaceRequiresChanges)
    } catch {
        Issue.record("Unexpected error type for replace validation: \(error)")
    }

    #expect(await mockREST.replaceOrderCallCount() == 0)
}

@Test("Environment maps to Alpaca trading REST base URLs")
func environmentBaseURLs() {
    #expect(Environment.paper.tradingRESTBaseURL.absoluteString == "https://paper-api.alpaca.markets")
    #expect(Environment.live.tradingRESTBaseURL.absoluteString == "https://api.alpaca.markets")
}

@Test("Store snapshot starts with build info")
func storeSnapshotBuild() async {
    let store = Store()
    let snapshot = await store.snapshot()

    #expect(snapshot.build == Engine.buildInfo)
    #expect(snapshot.lastEventName == nil)
}

@Test("Store projects startup reconciliation snapshots")
func storeProjectsStartupReconciliation() async {
    let store = Store()
    let account = Account(
        id: "acct-1",
        status: "ACTIVE",
        cash: "1000",
        buyingPower: "2000"
    )
    let positions = [
        Position(symbol: "AAPL", qty: "2", side: "long", marketValue: "380")
    ]
    let openOrders = [
        Order(
            id: "ord-open-1",
            clientOrderId: "c1",
            symbol: "AAPL",
            qty: "1",
            side: "buy",
            type: "limit",
            timeInForce: "day",
            status: "new"
        )
    ]

    await store.applyStartupSnapshot(
        account: account,
        positions: positions,
        openOrders: openOrders
    )

    let snapshot = await store.snapshot()
    #expect(snapshot.lastEventName == "startup_reconciliation")
    #expect(snapshot.accountSummary?.id == "acct-1")
    #expect(snapshot.positions.count == 1)
    #expect(snapshot.openOrders.count == 1)
    #expect(snapshot.ordersByID["ord-open-1"]?.status == "new")
    #expect(snapshot.auditLines.count == 1)
}

@Test("Store formats short positions with negative qty and SHORT label")
func storeShortPositionFormatting() async {
    let store = Store()
    let account = Account(
        id: "acct-1",
        status: "ACTIVE",
        cash: "1000",
        buyingPower: "2000",
        equity: "3000",
        multiplier: "2"
    )
    let positions = [
        Position(symbol: "AAPL", qty: "2", side: "short", marketValue: "-380")
    ]

    await store.applyStartupSnapshot(
        account: account,
        positions: positions,
        openOrders: []
    )

    let snapshot = await store.snapshot()
    #expect(snapshot.positions.count == 1)
    #expect(snapshot.positions[0].qty == "-2")
    #expect(snapshot.positions[0].directionLabel == "SHORT")
    #expect(snapshot.positions[0].isShort == true)
}

@Test("Store projects positions refresh snapshot from REST")
func storeProjectsPositionsRefreshSnapshot() async {
    let store = Store()
    let account = Account(
        id: "acct-1",
        status: "ACTIVE",
        cash: "1500",
        buyingPower: "3000",
        equity: "3200",
        multiplier: "2"
    )

    await store.applyStartupSnapshot(
        account: account,
        positions: [
            Position(symbol: "AAPL", qty: "1", side: "long", marketValue: "190")
        ],
        openOrders: []
    )

    await store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "AAPL", qty: "2", side: "long", marketValue: "380"),
            Position(symbol: "TSLA", qty: "-1", side: "short", marketValue: "-200")
        ],
        account: Account(
            id: "acct-1",
            status: "ACTIVE",
            cash: "1200",
            buyingPower: "2800",
            equity: "3100",
            multiplier: "2"
        )
    )

    let snapshot = await store.snapshot()
    #expect(snapshot.lastEventName == "positions_refresh")
    #expect(snapshot.positions.count == 2)
    #expect(snapshot.positions.first(where: { $0.symbol == "AAPL" })?.qty == "2")
    #expect(snapshot.positions.first(where: { $0.symbol == "TSLA" })?.directionLabel == "SHORT")
    #expect(snapshot.accountSummary?.cash == "1200")
}

@Test("Store projects filled and canceled trade updates")
func storeProjectsTradeUpdate() async {
    let store = Store()
    let filledJSON = """
    {"stream":"trade_updates","data":{"event":"fill","timestamp":"2024-01-01T00:00:00Z","order":{"id":"ord-1","symbol":"AAPL","side":"buy","qty":"1","filled_qty":"1","filled_avg_price":"190.12","status":"filled"}}}
    """
    let canceledJSON = """
    {"stream":"trade_updates","data":{"event":"canceled","timestamp":"2024-01-01T00:01:00Z","order":{"id":"ord-2","symbol":"MSFT","side":"sell","qty":"1","filled_qty":"0","status":"canceled"}}}
    """

    for message in AlpacaTradeUpdatesCodec.decodeMessages(from: Data(filledJSON.utf8)) {
        if case .tradeUpdate(let event) = message {
            await store.publishTradeUpdate(event)
        }
    }
    for message in AlpacaTradeUpdatesCodec.decodeMessages(from: Data(canceledJSON.utf8)) {
        if case .tradeUpdate(let event) = message {
            await store.publishTradeUpdate(event)
        }
    }
    let snapshot = await store.snapshot()

    #expect(snapshot.lastEventName == "trade_update")
    #expect(snapshot.ordersByID["ord-1"]?.status == "filled")
    #expect(snapshot.ordersByID["ord-1"]?.isOpen == false)
    #expect(snapshot.ordersByID["ord-2"]?.status == "canceled")
    #expect(snapshot.ordersByID["ord-2"]?.isOpen == false)
    #expect(snapshot.openOrders.isEmpty)
    #expect(snapshot.lastTradeUpdateSummary?.contains("order_id=ord-2") == true)
    #expect(snapshot.auditLines.count == 2)
}

@Test("Engine schedules exactly one debounced positions refresh for fill updates")
func enginePositionsRefreshDebouncedSingleFill() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        positionsRefreshDebounceWindow: 2,
        positionsRefreshMaxFrequency: 5,
        positionsRefreshNow: { clock.now() },
        positionsRefreshSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "fill", orderID: "ord-fill-1", symbol: "AAPL")
    )
    #expect(await mockREST.fetchPositionsCallCount() == 0)

    for _ in 0..<40 where !(await sleeper.hasPendingWaiter()) {
        await settleAsyncWork()
    }
    await sleeper.advance(by: 2)
    await settleAsyncWork()
    for _ in 0..<200 where await mockREST.fetchPositionsCallCount() < 1 {
        await settleAsyncWork()
    }
    #expect(await mockREST.fetchPositionsCallCount() == 1)
}

@Test("Engine coalesces multiple fills inside debounce window into one positions refresh")
func enginePositionsRefreshCoalescesWithinDebounce() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        positionsRefreshDebounceWindow: 2,
        positionsRefreshMaxFrequency: 5,
        positionsRefreshNow: { clock.now() },
        positionsRefreshSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "fill", orderID: "ord-fill-1", symbol: "AAPL")
    )
    for _ in 0..<40 where !(await sleeper.hasPendingWaiter()) {
        await settleAsyncWork()
    }
    await sleeper.advance(by: 1)
    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "partial_fill", orderID: "ord-fill-2", symbol: "AAPL")
    )

    for _ in 0..<40 where !(await sleeper.hasPendingWaiter()) {
        await settleAsyncWork()
    }
    await sleeper.advance(by: 1)
    await settleAsyncWork()
    #expect(await mockREST.fetchPositionsCallCount() == 0)

    await sleeper.advance(by: 1)
    await settleAsyncWork()
    for _ in 0..<40 where await mockREST.fetchPositionsCallCount() < 1 {
        await settleAsyncWork()
    }
    #expect(await mockREST.fetchPositionsCallCount() == 1)
}

@Test("Engine runs multiple refreshes for fills separated beyond debounce window")
func enginePositionsRefreshMultipleWindows() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        positionsRefreshDebounceWindow: 2,
        positionsRefreshMaxFrequency: 5,
        positionsRefreshNow: { clock.now() },
        positionsRefreshSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "fill", orderID: "ord-fill-1", symbol: "AAPL")
    )
    await sleeper.advance(by: 2)
    await settleAsyncWork()
    #expect(await mockREST.fetchPositionsCallCount() == 1)

    await sleeper.advance(by: 4)
    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "fill", orderID: "ord-fill-2", symbol: "AAPL")
    )
    await sleeper.advance(by: 2)
    await settleAsyncWork()
    await sleeper.advance(by: 0.1)
    await settleAsyncWork()
    #expect(await mockREST.fetchPositionsCallCount() == 2)
}

@Test("Engine stop cancels pending debounced positions refresh")
func enginePositionsRefreshCancelsOnStop() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        positionsRefreshDebounceWindow: 2,
        positionsRefreshMaxFrequency: 5,
        positionsRefreshNow: { clock.now() },
        positionsRefreshSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "fill", orderID: "ord-fill-1", symbol: "AAPL")
    )
    await engine.stop()

    await sleeper.advance(by: 3)
    await settleAsyncWork()
    #expect(await mockREST.fetchPositionsCallCount() == 0)
}

@Test("DebouncedRefresher coalesces triggers into one run")
func debouncedRefresherCoalesces() async {
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let counter = Counter()
    let refresher = DebouncedRefresher(
        debounceWindow: 1,
        minIntervalBetweenRuns: 3,
        now: { clock.now() },
        sleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await refresher.trigger {
        await counter.increment()
    }
    await waitForCondition { await sleeper.hasPendingWaiter() }
    await sleeper.advance(by: 0.5)
    await refresher.trigger {
        await counter.increment()
    }
    await waitForCondition { await sleeper.hasPendingWaiter() }

    await sleeper.advance(by: 0.5)
    await settleAsyncWork()
    #expect(await counter.value() == 0)

    await sleeper.advance(by: 0.5)
    await settleAsyncWork()
    #expect(await counter.value() == 1)
}

@Test("DebouncedRefresher enforces minimum interval between runs")
func debouncedRefresherMinInterval() async {
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let counter = Counter()
    let refresher = DebouncedRefresher(
        debounceWindow: 1,
        minIntervalBetweenRuns: 3,
        now: { clock.now() },
        sleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await refresher.trigger {
        await counter.increment()
    }
    await sleeper.advance(by: 1)
    await settleAsyncWork()
    #expect(await counter.value() == 1)

    await refresher.trigger {
        await counter.increment()
    }
    await sleeper.advance(by: 1)
    await settleAsyncWork()
    #expect(await counter.value() == 1)

    await sleeper.advance(by: 2)
    await settleAsyncWork()
    #expect(await counter.value() == 2)
}

@Test("DebouncedRefresher cancel prevents execution")
func debouncedRefresherCancelPreventsRun() async {
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let counter = Counter()
    let refresher = DebouncedRefresher(
        debounceWindow: 1,
        minIntervalBetweenRuns: 3,
        now: { clock.now() },
        sleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await refresher.trigger {
        await counter.increment()
    }
    await refresher.cancel()
    await settleAsyncWork()
    #expect(await sleeper.hasPendingWaiter() == false)
    await sleeper.advance(by: 2)
    await settleAsyncWork()

    #expect(await counter.value() == 0)
}

@Test("DebouncedRefresher instances run independently")
func debouncedRefresherInstancesIndependent() async {
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let aCounter = Counter()
    let bCounter = Counter()

    let a = DebouncedRefresher(
        debounceWindow: 1,
        minIntervalBetweenRuns: 3,
        now: { clock.now() },
        sleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )
    let b = DebouncedRefresher(
        debounceWindow: 2,
        minIntervalBetweenRuns: 3,
        now: { clock.now() },
        sleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await a.trigger {
        await aCounter.increment()
    }
    await b.trigger {
        await bCounter.increment()
    }

    await sleeper.advance(by: 1)
    for _ in 0..<40 where await aCounter.value() < 1 {
        await settleAsyncWork()
    }
    #expect(await aCounter.value() == 1)
    #expect(await bCounter.value() == 0)

    await sleeper.advance(by: 1)
    for _ in 0..<40 where await bCounter.value() < 1 {
        await settleAsyncWork()
    }
    #expect(await aCounter.value() == 1)
    #expect(await bCounter.value() == 1)
}

@Test("Engine schedules exactly one debounced open-orders refresh for cancel updates")
func engineOpenOrdersRefreshDebouncedSingleCancel() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        openOrdersRefreshDebounceWindow: 1,
        openOrdersRefreshMaxFrequency: 3,
        openOrdersRefreshNow: { clock.now() },
        openOrdersRefreshSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(
            event: "canceled",
            orderID: "ord-open-1",
            symbol: "AAPL",
            status: "canceled"
        )
    )
    #expect(await mockREST.fetchOpenOrdersCallCount() == 0)

    await sleeper.advance(by: 1)
    await settleAsyncWork()

    #expect(await mockREST.fetchOpenOrdersCallCount() == 1)
}

@Test("Engine coalesces multiple open-orders refresh triggers inside debounce window")
func engineOpenOrdersRefreshCoalescesWithinDebounce() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        openOrdersRefreshDebounceWindow: 1,
        openOrdersRefreshMaxFrequency: 3,
        openOrdersRefreshNow: { clock.now() },
        openOrdersRefreshSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "new", orderID: "ord-open-1", symbol: "AAPL", status: "new")
    )
    await sleeper.advance(by: 0.5)
    await engine.processTradeUpdate(
        makeTradeUpdateEvent(event: "pending_new", orderID: "ord-open-1", symbol: "AAPL", status: "pending_new")
    )

    await sleeper.advance(by: 0.5)
    await settleAsyncWork()
    #expect(await mockREST.fetchOpenOrdersCallCount() == 0)

    await sleeper.advance(by: 0.5)
    await settleAsyncWork()
    #expect(await mockREST.fetchOpenOrdersCallCount() == 1)
}

@Test("Engine runs multiple open-orders refreshes for triggers spaced beyond debounce window")
func engineOpenOrdersRefreshMultipleWindows() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        openOrdersRefreshDebounceWindow: 1,
        openOrdersRefreshMaxFrequency: 3,
        openOrdersRefreshNow: { clock.now() },
        openOrdersRefreshSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(
            event: "canceled",
            orderID: "ord-open-1",
            symbol: "AAPL",
            status: "canceled"
        )
    )
    await sleeper.advance(by: 1)
    await settleAsyncWork()
    #expect(await mockREST.fetchOpenOrdersCallCount() == 1)

    await sleeper.advance(by: 3)
    await engine.processTradeUpdate(
        makeTradeUpdateEvent(
            event: "replaced",
            orderID: "ord-open-1",
            symbol: "AAPL",
            status: "replaced"
        )
    )
    await sleeper.advance(by: 1)
    await settleAsyncWork()
    #expect(await mockREST.fetchOpenOrdersCallCount() == 2)
}

@Test("Store reconciles open-orders snapshot for canceled and replacement IDs")
func storeOpenOrdersReconciliation() async {
    let store = Store()
    await store.applyStartupSnapshot(
        account: Account(id: "acct-1", status: "ACTIVE", cash: "1000", buyingPower: "2000"),
        positions: [],
        openOrders: [
            Order(
                id: "ord-old",
                symbol: "AAPL",
                qty: "1",
                side: "buy",
                type: "limit",
                timeInForce: "day",
                status: "new"
            )
        ]
    )

    await store.reconcileOpenOrdersSnapshot([])
    var snapshot = await store.snapshot()
    #expect(snapshot.openOrders.isEmpty)
    #expect(snapshot.ordersByID["ord-old"]?.isOpen == false)

    await store.reconcileOpenOrdersSnapshot([
        Order(
            id: "ord-new",
            symbol: "AAPL",
            qty: "1",
            side: "buy",
            type: "limit",
            timeInForce: "day",
            status: "new"
        )
    ])
    snapshot = await store.snapshot()
    #expect(snapshot.ordersByID["ord-old"]?.isOpen == false)
    #expect(snapshot.openOrders.count == 1)
    #expect(snapshot.openOrders.first?.id == "ord-new")
}

@Test("Live not armed blocks place and replace")
func engineLiveNotArmedBlocksPlaceAndReplace() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST }
    )

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .market,
            source: "test-live-not-armed"
        )
        Issue.record("Expected live-not-armed error for placeOrder.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .liveTradingNotArmed)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    do {
        _ = try await engine.replaceOrder(
            orderID: "ord-1",
            qty: 2,
            source: "test-live-not-armed"
        )
        Issue.record("Expected live-not-armed error for replaceOrder.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .liveTradingNotArmed)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
    #expect(await mockREST.replaceOrderCallCount() == 0)
}

@Test("Kill switch blocks live place orders")
func engineKillSwitchBlocksPlace() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST },
        newArmingSessionID: { "session-1" }
    )

    _ = await engine.armLiveTrading()
    await engine.setKillSwitchEnabled(true)

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .market,
            source: "test-kill-switch",
            armingSessionID: "session-1"
        )
        Issue.record("Expected kill-switch error for live placeOrder.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .tradingDisabledByKillSwitch)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("Cancel remains allowed while live is disarmed or kill switch enabled")
func engineCancelAllowedWhileDisarmed() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST }
    )

    await engine.cancelOrder(orderID: "ord-cancel-safe")
    #expect(await mockREST.cancelOrderCallCount() == 1)

    _ = await engine.armLiveTrading()
    await engine.setKillSwitchEnabled(true)
    await engine.cancelOrder(orderID: "ord-cancel-safe-2")
    #expect(await mockREST.cancelOrderCallCount() == 2)
}

@Test("Live execution protection settings default off, persist on, and corrupt fallback is conservative")
func liveExecutionProtectionSettingsPersistence() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("live-execution-protection-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let fileURL = root.appendingPathComponent("settings.json")
    let clock = TestDateClock(start: Date(timeIntervalSince1970: 1_000))
    let store = LiveExecutionProtectionSettingsStore(
        fileURL: fileURL,
        now: { clock.now() }
    )

    let defaultSettings = await store.loadOrDefault()
    #expect(defaultSettings.localUserPresenceRequiredForLiveOrders == false)

    let enabled = defaultSettings.updating(
        required: true,
        updatedBy: "test",
        updateSource: .ui,
        now: clock.advance(by: 10)
    )
    _ = try await store.upsert(enabled)

    let reloadedStore = LiveExecutionProtectionSettingsStore(
        fileURL: fileURL,
        now: { clock.now() }
    )
    let reloaded = await reloadedStore.loadOrDefault()
    #expect(reloaded.localUserPresenceRequiredForLiveOrders == true)

    let corruptURL = root.appendingPathComponent("corrupt.json")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: corruptURL)
    let corruptStore = LiveExecutionProtectionSettingsStore(
        fileURL: corruptURL,
        now: { clock.now() }
    )
    let corruptFallback = await corruptStore.loadOrDefault()
    #expect(corruptFallback.localUserPresenceRequiredForLiveOrders == true)
    #expect(await corruptStore.drainLoadDiagnostics().isEmpty == false)
}

@Test("Disable live execution protection requires successful local user presence")
func liveExecutionProtectionDisableRequiresAuthSuccess() async {
    let auth = TestLocalUserPresenceAuthorizer(results: [
        LocalUserPresenceAuthorizationResult(
            status: .canceled,
            summary: "Canceled",
            checkedAt: Date(timeIntervalSince1970: 1_000)
        ),
        .success(checkedAt: Date(timeIntervalSince1970: 1_001))
    ])
    let store = LiveExecutionProtectionSettingsStore(
        fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("live-execution-disable-\(UUID().uuidString).json")
    )
    let engine = Engine(
        liveExecutionProtectionSettingsStore: store,
        localUserPresenceAuthorizer: auth
    )

    let enableResult = await engine.setLiveExecutionProtectionRequired(true, source: .ui)
    #expect(enableResult.applied == true)
    #expect(enableResult.authorizationResult == nil)

    let canceledDisable = await engine.setLiveExecutionProtectionRequired(false, source: .ui)
    #expect(canceledDisable.applied == false)
    #expect(canceledDisable.settings.localUserPresenceRequiredForLiveOrders == true)
    #expect(canceledDisable.authorizationResult?.status == .canceled)

    let successfulDisable = await engine.setLiveExecutionProtectionRequired(false, source: .ui)
    #expect(successfulDisable.applied == true)
    #expect(successfulDisable.settings.localUserPresenceRequiredForLiveOrders == false)
    #expect(successfulDisable.authorizationResult?.status == .success)
    #expect(await auth.challengeCount() == 2)
    #expect((await auth.challenges()).allSatisfy { $0.operation == .disableLiveExecutionProtection })
}

@Test("Paper orders do not require local auth when live execution protection is enabled")
func paperOrdersIgnoreLiveExecutionProtection() async throws {
    let mockREST = MockRESTClient()
    let auth = TestLocalUserPresenceAuthorizer(results: [])
    let engine = Engine(
        restClientFactory: { _ in mockREST },
        liveExecutionProtectionSettingsStore: LiveExecutionProtectionSettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("paper-local-auth-\(UUID().uuidString).json")
        ),
        localUserPresenceAuthorizer: auth
    )
    _ = await engine.setLiveExecutionProtectionRequired(true, source: .ui)

    _ = try await engine.placeOrder(
        symbol: "AAPL",
        qty: 1,
        side: .buy,
        type: .market
    )
    _ = try await engine.replaceOrder(orderID: "ord-open-1", qty: 2)
    await engine.cancelOrder(orderID: "ord-open-1")

    #expect(await auth.challengeCount() == 0)
    #expect(await mockREST.placeOrderCallCount() == 1)
    #expect(await mockREST.replaceOrderCallCount() == 1)
    #expect(await mockREST.cancelOrderCallCount() == 1)
}

@Test("Live NEW and REPLACE require local auth when protection is enabled")
func liveNewAndReplaceRequireLocalAuth() async throws {
    let mockREST = MockRESTClient()
    let auth = TestLocalUserPresenceAuthorizer(results: [
        .success(checkedAt: Date(timeIntervalSince1970: 1_000)),
        .success(checkedAt: Date(timeIntervalSince1970: 1_001))
    ])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST },
        liveExecutionProtectionSettingsStore: LiveExecutionProtectionSettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("live-local-auth-success-\(UUID().uuidString).json")
        ),
        localUserPresenceAuthorizer: auth,
        newArmingSessionID: { "session-1" }
    )
    _ = await engine.armLiveTrading()
    _ = await engine.setLiveExecutionProtectionRequired(true, source: .ui)

    _ = try await engine.placeOrder(
        symbol: "AAPL",
        qty: 1,
        side: .buy,
        type: .market,
        armingSessionID: "session-1"
    )
    _ = try await engine.replaceOrder(
        orderID: "ord-open-1",
        qty: 2,
        armingSessionID: "session-1"
    )

    #expect(await auth.challengeCount() == 2)
    let challenges = await auth.challenges()
    #expect(challenges.map(\.operation) == [.liveOrderSubmission, .liveOrderReplacement])
    #expect(challenges[0].localizedReason.contains("AAPL"))
    #expect(challenges[0].localizedReason.lowercased().contains("account") == false)
    #expect(challenges[0].localizedReason.lowercased().contains("secret") == false)
    #expect(await mockREST.placeOrderCallCount() == 1)
    #expect(await mockREST.replaceOrderCallCount() == 1)
}

@Test("Live local auth cancel failure and unavailable block before REST")
func liveLocalAuthFailuresBlockBeforeREST() async {
    let statuses: [LocalUserPresenceAuthorizationStatus] = [
        .canceled,
        .failed,
        .unavailable,
        .systemError
    ]
    let expectedErrors: [ManualOrderValidationError] = [
        .localUserPresenceCanceled,
        .localUserPresenceFailed,
        .localUserPresenceUnavailable,
        .localUserPresenceSystemError
    ]

    for (status, expectedError) in zip(statuses, expectedErrors) {
        let mockREST = MockRESTClient()
        let auth = TestLocalUserPresenceAuthorizer(results: [
            LocalUserPresenceAuthorizationResult(
                status: status,
                summary: status.rawValue,
                checkedAt: Date(timeIntervalSince1970: 1_000)
            )
        ])
        let engine = Engine(
            configuration: Configuration(environment: .live),
            restClientFactory: { _ in mockREST },
            liveExecutionProtectionSettingsStore: LiveExecutionProtectionSettingsStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("live-local-auth-\(status.rawValue)-\(UUID().uuidString).json")
            ),
            localUserPresenceAuthorizer: auth,
            newArmingSessionID: { "session-1" }
        )
        _ = await engine.armLiveTrading()
        _ = await engine.setLiveExecutionProtectionRequired(true, source: .ui)

        do {
            _ = try await engine.placeOrder(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market,
                armingSessionID: "session-1"
            )
            Issue.record("Expected local auth block for \(status.rawValue).")
        } catch let error as ManualOrderValidationError {
            #expect(error == expectedError)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await mockREST.placeOrderCallCount() == 0)
    }
}

@Test("Existing live safety gates block without prompting local auth")
func existingLiveSafetyGatesBlockBeforeLocalAuthPrompt() async {
    let mockREST = MockRESTClient()
    let auth = TestLocalUserPresenceAuthorizer(results: [.success()])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST },
        liveExecutionProtectionSettingsStore: LiveExecutionProtectionSettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("live-local-auth-existing-gates-\(UUID().uuidString).json")
        ),
        localUserPresenceAuthorizer: auth,
        newArmingSessionID: { "session-1" }
    )
    _ = await engine.setLiveExecutionProtectionRequired(true, source: .ui)

    do {
        _ = try await engine.placeOrder(symbol: "AAPL", qty: 1, side: .buy, type: .market)
        Issue.record("Expected live-not-armed block.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .liveTradingNotArmed)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(await auth.challengeCount() == 0)
    #expect(await mockREST.placeOrderCallCount() == 0)
}

@Test("Live CANCEL remains allowed when local auth protection is enabled")
func liveCancelAllowedWithLocalAuthProtectionEnabled() async {
    let mockREST = MockRESTClient()
    let auth = TestLocalUserPresenceAuthorizer(results: [])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST },
        liveExecutionProtectionSettingsStore: LiveExecutionProtectionSettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("live-cancel-local-auth-\(UUID().uuidString).json")
        ),
        localUserPresenceAuthorizer: auth
    )
    _ = await engine.setLiveExecutionProtectionRequired(true, source: .ui)

    await engine.cancelOrder(orderID: "ord-cancel-still-safe")
    #expect(await auth.challengeCount() == 0)
    #expect(await mockREST.cancelOrderCallCount() == 1)
}

@Test("Live auth does not create a broad reusable authorization cache")
func liveLocalAuthPromptsPerSubmission() async throws {
    let mockREST = MockRESTClient()
    let auth = TestLocalUserPresenceAuthorizer(results: [
        .success(checkedAt: Date(timeIntervalSince1970: 1_000)),
        .success(checkedAt: Date(timeIntervalSince1970: 1_001))
    ])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST },
        liveExecutionProtectionSettingsStore: LiveExecutionProtectionSettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("live-no-auth-cache-\(UUID().uuidString).json")
        ),
        localUserPresenceAuthorizer: auth,
        newArmingSessionID: { "session-1" }
    )
    _ = await engine.armLiveTrading()
    _ = await engine.setLiveExecutionProtectionRequired(true, source: .ui)

    _ = try await engine.placeOrder(symbol: "AAPL", qty: 1, side: .buy, type: .market, armingSessionID: "session-1")
    _ = try await engine.placeOrder(symbol: "MSFT", qty: 1, side: .buy, type: .market, armingSessionID: "session-1")

    #expect(await auth.challengeCount() == 2)
    #expect(await mockREST.placeOrderCallCount() == 2)
}

@Test("PM confirmed app truth explains live execution local-auth protection")
func pmConfirmedTruthExplainsLiveExecutionProtection() {
    let enabled = LiveExecutionProtectionSettings.default(now: Date())
        .updating(required: true, updatedBy: "test", updateSource: .ui, now: Date())

    let line = liveExecutionProtectionConfirmedAppTruthLine(settings: enabled)
    #expect(line.contains("enabled"))
    #expect(line.contains("Live NEW/REPLACE"))
    #expect(line.contains("Paper trading is unaffected"))
    #expect(line.contains("CANCEL remains available"))
    #expect(line.contains("disabling the protection requires local macOS authentication"))
}

@Test("Blocked live order logs are rate-limited to avoid spam")
func engineBlockedAuditRateLimited() async {
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let store = Store()
    let engine = Engine(
        configuration: Configuration(environment: .live),
        store: store,
        restClientFactory: { _ in mockREST },
        now: { clock.now() },
        blockedAuditWindow: 30
    )

    for _ in 0..<3 {
        do {
            _ = try await engine.placeOrder(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market,
                source: "agent-1"
            )
            Issue.record("Expected live-not-armed block.")
        } catch let error as ManualOrderValidationError {
            #expect(error == .liveTradingNotArmed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    var snapshot = await store.snapshot()
    let firstWindowLines = snapshot.auditLines.filter {
        $0.contains("order blocked reason=live_not_armed source=agent-1")
    }
    #expect(firstWindowLines.count == 1)

    _ = clock.advance(by: 31)
    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .market,
            source: "agent-1"
        )
        Issue.record("Expected live-not-armed block after window.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .liveTradingNotArmed)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    snapshot = await store.snapshot()
    let allLines = snapshot.auditLines.filter {
        $0.contains("order blocked reason=live_not_armed source=agent-1")
    }
    #expect(allLines.count == 2)
    #expect(allLines.last?.contains("suppressed=2") == true)
}

@Test("Arming session id changes on arm/disarm and stale session is blocked")
func engineArmingSessionRotationAndStaleSessionBlock() async {
    let mockREST = MockRESTClient()
    let sequence = SessionIDSequence(values: ["session-A", "session-B"])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST },
        newArmingSessionID: { sequence.next() }
    )

    let sessionA = await engine.armLiveTrading()
    #expect(sessionA == "session-A")

    do {
        _ = try await engine.placeOrder(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .market,
            source: "agent-session-test",
            armingSessionID: "stale-session"
        )
        Issue.record("Expected stale arming session block.")
    } catch let error as ManualOrderValidationError {
        #expect(error == .staleArmingSession)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    await engine.disarmLiveTrading()
    let sessionB = await engine.armLiveTrading()
    #expect(sessionB == "session-B")
    #expect(sessionA != sessionB)
}

@Test("Store projects option order rows with OPT label and underlying")
func storeProjectsOptionOrderRows() async {
    let store = Store()
    let optionNewJSON = """
    {"stream":"trade_updates","data":{"event":"new","timestamp":"2024-01-01T00:00:00Z","order":{"id":"ord-opt-1","symbol":"AAPL240119C00190000","asset_class":"option","side":"buy","qty":"1","filled_qty":"0","status":"new"}}}
    """

    for message in AlpacaTradeUpdatesCodec.decodeMessages(from: Data(optionNewJSON.utf8)) {
        if case .tradeUpdate(let event) = message {
            await store.publishTradeUpdate(event)
        }
    }

    let snapshot = await store.snapshot()
    let row = snapshot.ordersByID["ord-opt-1"]
    #expect(row?.instrumentType == .option)
    #expect(row?.instrumentLabel == "OPT")
    #expect(row?.displayedSymbol == "AAPL240119C00190000")
    #expect(row?.underlyingSymbol == "AAPL")
    #expect(row?.canReplace == false)
}

@Test("Store keeps blotter consistent across replace old/new order IDs")
func storeProjectsReplaceFlow() async {
    let store = Store()
    let replacedOldJSON = """
    {"stream":"trade_updates","data":{"event":"replaced","timestamp":"2024-01-01T00:02:00Z","order":{"id":"ord-old","symbol":"AAPL","side":"buy","qty":"1","filled_qty":"0","status":"replaced"}}}
    """
    let newOrderJSON = """
    {"stream":"trade_updates","data":{"event":"new","timestamp":"2024-01-01T00:02:01Z","order":{"id":"ord-new","symbol":"AAPL","side":"buy","qty":"2","filled_qty":"0","status":"new"}}}
    """

    for message in AlpacaTradeUpdatesCodec.decodeMessages(from: Data(replacedOldJSON.utf8)) {
        if case .tradeUpdate(let event) = message {
            await store.publishTradeUpdate(event)
        }
    }
    for message in AlpacaTradeUpdatesCodec.decodeMessages(from: Data(newOrderJSON.utf8)) {
        if case .tradeUpdate(let event) = message {
            await store.publishTradeUpdate(event)
        }
    }

    let snapshot = await store.snapshot()
    #expect(snapshot.ordersByID["ord-old"]?.status == "replaced")
    #expect(snapshot.ordersByID["ord-old"]?.isOpen == false)
    #expect(snapshot.ordersByID["ord-new"]?.status == "new")
    #expect(snapshot.ordersByID["ord-new"]?.isOpen == true)
    #expect(snapshot.openOrders.count == 1)
    #expect(snapshot.openOrders.first?.id == "ord-new")
}

@Test("CredentialsStatus marks found flags and timestamp")
func credentialsStatusComputation() {
    let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let provider = KeychainCredentialsProvider(
        keyReader: MockKeyReader(
            values: [
                "alpaca.api.key|algo-trading/paper": "paper-public",
                "alpaca.secret.key|algo-trading/paper": "paper-secret",
                "alpaca.api.key|algo-trading/live": "live-public",
                "telegram.api.key|algo-trading": "telegram-bot-token",
                "open_api_key|algo-trading": "openai-api-key"
            ]
        ),
        now: { checkedAt }
    )

    let status = provider.credentialStatus()
    #expect(status.paperPublicFound == true)
    #expect(status.paperSecretFound == true)
    #expect(status.paperKeysFound == true)
    #expect(status.livePublicFound == true)
    #expect(status.liveSecretFound == false)
    #expect(status.liveKeysFound == false)
    #expect(status.telegramConfigured == true)
    #expect(status.openAIConfigured == true)
    #expect(status.openAIStatusSummary?.contains("OpenAI API key resolved") == true)
    #expect(status.lastChecked == checkedAt)
}

@Test("Credentials lookup returns nil when one key is missing")
func credentialsLookupMissingSecret() {
    let provider = KeychainCredentialsProvider(
        keyReader: MockKeyReader(
            values: [
                "alpaca.api.key|algo-trading/live": "live-public"
            ]
        )
    )

    #expect(provider.credentials(for: .live) == nil)
}

@Test("Alpaca credential readiness reports active environment without exposing secrets")
func alpacaCredentialReadinessReportsPresenceOnly() {
    let checkedAt = Date(timeIntervalSince1970: 1_700_000_100)
    let provider = KeychainCredentialsProvider(
        keyReader: MockKeyReader(
            values: [
                "alpaca.api.key|algo-trading/paper": "paper-public"
            ]
        ),
        now: { checkedAt }
    )

    let readiness = provider.alpacaCredentialReadiness(for: .paper)
    #expect(readiness.environment == .paper)
    #expect(readiness.publicKeyFound == true)
    #expect(readiness.secretKeyFound == false)
    #expect(readiness.isReady == false)
    #expect(readiness.checkedAt == checkedAt)
}

@Test("Alpaca API errors provide bounded user-readable diagnostics")
func alpacaAPIErrorDescriptionsStayBounded() {
    let missing = AlpacaAPIError.missingCredentials(environment: .paper)
    #expect(missing.localizedDescription.contains("Missing Alpaca credentials for paper environment"))

    let failed = AlpacaAPIError.requestFailed(
        httpStatus: 403,
        alpacaMessage: "not authorized",
        requestID: "req-123"
    )
    #expect(failed.localizedDescription.contains("status=403"))
    #expect(failed.localizedDescription.contains("not authorized"))
    #expect(failed.localizedDescription.contains("req-123"))
}

@Test("Token bucket allows burst up to capacity then throttles")
func rateLimiterBurstAndThrottle() throws {
    var limiter = TokenBucketRateLimiter(
        capacity: 2,
        refillRatePerSecond: 1,
        initialTime: 0
    )

    try limiter.acquire(at: 0)
    try limiter.acquire(at: 0)

    do {
        try limiter.acquire(at: 0)
        Issue.record("Expected limiter to throttle when no tokens remain.")
    } catch RateLimiterError.rateLimited(let retryAfter) {
        #expect(abs(retryAfter - 1) < 0.0001)
    }
}

@Test("Token bucket refills deterministically with controllable time")
func rateLimiterDeterministicRefill() throws {
    var limiter = TokenBucketRateLimiter(
        capacity: 3,
        refillRatePerSecond: 2,
        initialTime: 10
    )

    try limiter.acquire(tokens: 3, at: 10)

    do {
        try limiter.acquire(tokens: 1, at: 10.25)
        Issue.record("Expected limiter to throttle before enough refill occurred.")
    } catch RateLimiterError.rateLimited(let retryAfter) {
        #expect(abs(retryAfter - 0.25) < 0.0001)
    }

    try limiter.acquire(tokens: 1, at: 10.5)
    let available = limiter.snapshot(at: 11.0)
    #expect(abs(available - 1) < 0.0001)
}

@Test("Exponential backoff produces deterministic bounded delays")
func backoffDeterministic() {
    let policy = ExponentialBackoffPolicy(baseDelay: 1, maxDelay: 8, jitterFactor: 0.25)

    let attempt0 = policy.delay(attempt: 0, randomUnit: 0.5)
    let attempt3 = policy.delay(attempt: 3, randomUnit: 0.5)
    let clamped = policy.delay(attempt: 10, randomUnit: 0.5)

    #expect(abs(attempt0 - 1) < 0.0001)
    #expect(abs(attempt3 - 8) < 0.0001)
    #expect(abs(clamped - 8) < 0.0001)
}

@Test("Trade updates codec decodes authorization/listening/trade_update payloads")
func tradeUpdatesDecode() {
    let authorizationJSON = """
    {"stream":"authorization","data":{"action":"authenticate","status":"authorized"}}
    """
    let listeningJSON = """
    {"stream":"listening","data":{"streams":["trade_updates"]}}
    """
    let tradeUpdateJSON = """
    {"stream":"trade_updates","data":{"event":"fill","timestamp":"2024-01-01T00:00:00Z","order":{"id":"ord-123","symbol":"AAPL","side":"buy","qty":"1","filled_qty":"1","filled_avg_price":"190.12","status":"filled"}}}
    """

    let messages = AlpacaTradeUpdatesCodec.decodeMessages(from: Data(authorizationJSON.utf8))
    #expect(messages == [.authorization(status: "authorized")])

    let listeningMessages = AlpacaTradeUpdatesCodec.decodeMessages(from: Data(listeningJSON.utf8))
    #expect(listeningMessages == [.listening(streams: ["trade_updates"])])

    let tradeMessages = AlpacaTradeUpdatesCodec.decodeMessages(from: Data(tradeUpdateJSON.utf8))
    #expect(tradeMessages.count == 1)
    if case .tradeUpdate(let update) = tradeMessages[0] {
        #expect(update.event == "fill")
        #expect(update.orderID == "ord-123")
        #expect(update.symbol == "AAPL")
        #expect(update.filledQty == "1")
    } else {
        Issue.record("Expected trade update message.")
    }
}

@Test("Market data subscription diff reconciles desired and current sets")
func marketDataSubscriptionDiff() {
    let current = MarketDataSubscriptionSet(
        quotes: ["AAPL", "MSFT"],
        trades: ["AAPL"],
        bars: ["SPY"],
        optionQuotes: ["AAPL240119C00190000"],
        optionTrades: ["AAPL240119C00190000"]
    )
    let desired = MarketDataSubscriptionSet(
        quotes: ["MSFT", "NVDA"],
        trades: ["AAPL", "TSLA"],
        bars: [],
        optionQuotes: ["AAPL240119C00190000", "MSFT240119P00350000"],
        optionTrades: []
    )

    let delta = desired.diff(from: current)
    #expect(delta.subscribeQuotes == ["NVDA"])
    #expect(delta.unsubscribeQuotes == ["AAPL"])
    #expect(delta.subscribeTrades == ["TSLA"])
    #expect(delta.unsubscribeTrades.isEmpty)
    #expect(delta.subscribeBars.isEmpty)
    #expect(delta.unsubscribeBars == ["SPY"])
    #expect(delta.subscribeOptionQuotes == ["MSFT240119P00350000"])
    #expect(delta.unsubscribeOptionQuotes.isEmpty)
    #expect(delta.subscribeOptionTrades.isEmpty)
    #expect(delta.unsubscribeOptionTrades == ["AAPL240119C00190000"])
}

@Test("Market data stream publishes requested subscriptions without marking them active before Alpaca ack")
func marketDataStreamDoesNotMarkDesiredSubscriptionsActiveBeforeAck() async {
    let stream = AlpacaMarketDataStream(environment: .paper, feed: .test)
    var iterator = stream.events.makeAsyncIterator()

    await stream.setWatchSymbols(["AAPL"])

    let first = await iterator.next()
    let second = await iterator.next()
    let events = [first, second].compactMap { $0 }

    #expect(events.contains {
        if case .desiredSubscriptionChanged(let desired) = $0 {
            return desired.quotes == ["AAPL"] && desired.trades == ["AAPL"]
        }
        return false
    })
    #expect(events.contains {
        if case .subscriptionChanged = $0 {
            return true
        }
        return false
    } == false)
}

@Test("Market data stream retries desired subscription reconciliation after Alpaca auth ack")
func marketDataStreamRetriesDesiredSubscriptionsAfterAuthAck() async {
    let stream = AlpacaMarketDataStream(environment: .paper, feed: .test)
    var iterator = stream.events.makeAsyncIterator()

    await stream.setWatchSymbols(["NVDA"])
    _ = await iterator.next()
    _ = await iterator.next()

    await stream.handleIncomingForTesting(data: Data(#"[{"T":"success","msg":"authenticated"}]"#.utf8))

    let authEvent = await iterator.next()
    let desiredEvent = await iterator.next()
    let diagnosticEvent = await iterator.next()
    let events = [authEvent, desiredEvent, diagnosticEvent].compactMap { $0 }

    #expect(events.contains {
        if case .connectionStateChanged(.authenticated) = $0 {
            return true
        }
        return false
    })
    #expect(events.contains {
        if case .desiredSubscriptionChanged(let desired) = $0 {
            return desired.quotes == ["NVDA"] && desired.trades == ["NVDA"]
        }
        return false
    })
    #expect(events.contains {
        if case .subscriptionChanged = $0 {
            return true
        }
        return false
    } == false)
}

@Test("Market data stream reconnect request clears stale active subscription truth")
func marketDataStreamReconnectRequestClearsActiveSubscriptions() async {
    let stream = AlpacaMarketDataStream(environment: .paper, feed: .test)
    var iterator = stream.events.makeAsyncIterator()

    await stream.handleIncomingForTesting(data: Data(#"[{"T":"success","msg":"authenticated"}]"#.utf8))
    _ = await iterator.next()
    _ = await iterator.next()
    await stream.handleIncomingForTesting(data: Data(#"[{"T":"subscription","quotes":["AAPL"],"trades":["AAPL"]}]"#.utf8))
    _ = await iterator.next()
    _ = await iterator.next()

    await stream.requestReconnect(reason: "no_first_data")

    var events: [MarketDataStreamEvent] = []
    for _ in 0..<5 {
        if let event = await iterator.next() {
            events.append(event)
        }
    }

    #expect(events.contains {
        if case .subscriptionChanged(let active) = $0 {
            return active.isEmpty
        }
        return false
    })
    #expect(events.contains {
        if case .connectionStateChanged(.disconnected) = $0 {
            return true
        }
        return false
    })
}

@Test("Trade updates environment change requests immediate reconnect and reports live endpoint")
func tradeUpdatesEnvironmentChangeRequestsReconnect() async {
    final class NilKeyReader: KeyReading, @unchecked Sendable {
        func readKey(service: String, account: String) -> String? { nil }
    }

    let provider = KeychainCredentialsProvider(
        keyReader: NilKeyReader(),
        sessionCache: nil
    )
    let stream = AlpacaTradeUpdatesStream(
        environment: .paper,
        keychainProvider: provider,
        backoffPolicy: ExponentialBackoffPolicy(baseDelay: 60, maxDelay: 60, jitterFactor: 0),
        sleep: { delay in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    )

    await stream.start()
    await stream.updateEnvironment(.live)
    let snapshot = await stream.runtimeSnapshot()
    await stream.stop()

    #expect(snapshot.environment == .live)
    #expect(snapshot.endpoint == "wss://api.alpaca.markets/stream")
    #expect(snapshot.reconnectRequestCount == 1)
    #expect(snapshot.lastReconnectReason == "environment_changed")
    #expect(snapshot.isRunning)
}

@Test("Market data feed switch requests immediate reconnect and reports SIP endpoint without IEX fallback")
func marketDataFeedSwitchRequestsReconnectAndReportsSIPEndpoint() async {
    final class NilKeyReader: KeyReading, @unchecked Sendable {
        func readKey(service: String, account: String) -> String? { nil }
    }

    let provider = KeychainCredentialsProvider(
        keyReader: NilKeyReader(),
        sessionCache: nil
    )
    let stream = AlpacaMarketDataStream(
        environment: .live,
        feed: .stocksIEX,
        keychainProvider: provider,
        backoffPolicy: ExponentialBackoffPolicy(baseDelay: 60, maxDelay: 60, jitterFactor: 0),
        sleep: { delay in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    )

    await stream.start()
    await stream.updateFeed(.stocksSIP)
    let snapshot = await stream.runtimeSnapshot()
    await stream.stop()

    #expect(snapshot.feed == .stocksSIP)
    #expect(snapshot.endpoint == "wss://stream.data.alpaca.markets/v2/sip")
    #expect(snapshot.reconnectRequestCount == 1)
    #expect(snapshot.lastReconnectReason == "feed_changed")
    #expect(snapshot.isRunning)
}

@Test("Market data codec decodes batched quote and trade messages")
func marketDataCodecDecode() {
    let batchedJSON = """
    [
      {"T":"q","S":"AAPL","bp":190.1,"ap":190.3,"bs":2,"as":3,"t":"2024-01-01T00:00:00Z"},
      {"T":"t","S":"AAPL","p":190.2,"s":100,"t":"2024-01-01T00:00:01Z"}
    ]
    """

    let decoded = AlpacaMarketDataCodec.decodeMessages(from: Data(batchedJSON.utf8))
    #expect(decoded.count == 2)

    if case .quote(let quote) = decoded[0] {
        #expect(quote.symbol == "AAPL")
        #expect(quote.bidPrice == 190.1)
        #expect(quote.askPrice == 190.3)
    } else {
        Issue.record("Expected first market-data message to decode as quote.")
    }

    if case .trade(let trade) = decoded[1] {
        #expect(trade.symbol == "AAPL")
        #expect(trade.price == 190.2)
        #expect(trade.size == 100)
    } else {
        Issue.record("Expected second market-data message to decode as trade.")
    }
}

@Test("Market symbol classifier separates equity and option symbols")
func marketSymbolClassifier() {
    #expect(MarketSymbolClassifier.instrumentType(for: "AAPL") == .equity)
    #expect(MarketSymbolClassifier.instrumentType(for: " AAPL240119C00190000 ") == .option)
}

@Test("Market data codec decodes option quote/trade fixture messages")
func marketDataCodecDecodeOptions() {
    let batchedJSON = """
    [
      {"T":"oq","S":"AAPL240119C00190000","bp":1.2,"ap":1.4,"bs":12,"as":10,"t":"2024-01-01T00:00:00Z"},
      {"T":"ot","S":"AAPL240119C00190000","p":1.3,"s":2,"t":"2024-01-01T00:00:01Z"}
    ]
    """

    let decoded = AlpacaMarketDataCodec.decodeMessages(from: Data(batchedJSON.utf8))
    #expect(decoded.count == 2)

    if case .quote(let quote) = decoded[0] {
        #expect(quote.symbol == "AAPL240119C00190000")
        #expect(quote.instrumentType == .option)
        #expect(quote.bidPrice == 1.2)
        #expect(quote.askPrice == 1.4)
    } else {
        Issue.record("Expected first options market-data message to decode as quote.")
    }

    if case .trade(let trade) = decoded[1] {
        #expect(trade.symbol == "AAPL240119C00190000")
        #expect(trade.instrumentType == .option)
        #expect(trade.price == 1.3)
        #expect(trade.size == 2)
    } else {
        Issue.record("Expected second options market-data message to decode as trade.")
    }
}

@Test("Store projects latest quote per symbol")
func storeProjectsMarketQuote() async {
    let store = Store()

    await store.setWatchlistSymbols(["AAPL"])
    await store.publishMarketQuote(
        MarketDataQuoteEvent(
            symbol: "AAPL",
            bidPrice: 190.10,
            askPrice: 190.30,
            bidSize: 2,
            askSize: 3,
            timestamp: "2024-01-01T00:00:00Z"
        )
    )

    let snapshot = await store.snapshot()
    #expect(snapshot.watchlistSymbols == ["AAPL"])
    #expect(snapshot.quotesBySymbol["AAPL"]?.bidPrice == 190.10)
    #expect(snapshot.quotesBySymbol["AAPL"]?.askPrice == 190.30)
    #expect(snapshot.lastMarketDataSummary?.contains("symbol=AAPL") == true)
}

@Test("Store distinguishes requested market-data subscriptions from acknowledged active subscriptions")
func storeProjectsDesiredAndActiveMarketDataSubscriptionTruth() async {
    let now = Date(timeIntervalSince1970: 1_700_000_200)
    let store = Store(now: { now })

    await store.publishMarketDataDesiredSubscription(
        MarketDataSubscriptionSet(quotes: ["NVDA"], trades: ["NVDA"])
    )

    var snapshot = await store.snapshot()
    #expect(snapshot.marketDataDesiredSubscriptions.quotes == ["NVDA"])
    #expect(snapshot.marketDataSubscriptions.isEmpty)
    #expect(snapshot.lastMarketDataReceivedAt == nil)

    await store.publishMarketDataSubscription(
        MarketDataSubscriptionSet(quotes: ["NVDA"])
    )
    await store.publishMarketTrade(
        MarketDataTradeEvent(
            symbol: "NVDA",
            price: 902.5,
            size: 100,
            timestamp: "2026-03-17T14:31:00Z"
        )
    )

    snapshot = await store.snapshot()
    #expect(snapshot.marketDataSubscriptions.quotes == ["NVDA"])
    #expect(snapshot.lastMarketDataReceivedAt == now)
    #expect(snapshot.lastMarketDataReceivedSymbol == "NVDA")
    #expect(snapshot.quotesBySymbol["NVDA"]?.lastPrice == 902.5)
}

@Test("Store projects latest option quote per symbol")
func storeProjectsOptionsMarketQuote() async {
    let store = Store()

    await store.setWatchlistSymbols(["AAPL240119C00190000"])
    await store.publishMarketQuote(
        MarketDataQuoteEvent(
            symbol: "AAPL240119C00190000",
            instrumentType: .option,
            bidPrice: 1.20,
            askPrice: 1.40,
            bidSize: 12,
            askSize: 10,
            timestamp: "2024-01-01T00:00:00Z"
        )
    )

    let snapshot = await store.snapshot()
    #expect(snapshot.watchlistSymbols == ["AAPL240119C00190000"])
    #expect(snapshot.optionQuotesBySymbol["AAPL240119C00190000"]?.instrumentType == .option)
    #expect(snapshot.optionQuotesBySymbol["AAPL240119C00190000"]?.bidPrice == 1.20)
    #expect(snapshot.optionQuotesBySymbol["AAPL240119C00190000"]?.askPrice == 1.40)
    #expect(snapshot.lastOptionsMarketDataSummary?.contains("instrument=OPT") == true)
}

@Test("StrategyRunner start/stop/status transitions")
func strategyRunnerTransitions() async throws {
    let strategy = HoldingStrategy()
    let runner = StrategyRunner(
        strategies: [strategy]
    )

    let context = makeStrategyContext()
    let started = try await runner.start(
        id: strategy.id,
        params: ["flag": .bool(true)],
        context: context
    )
    #expect(started.state == .running)
    #expect(started.parameters["flag"] == .bool(true))

    let running = await runner.statuses().first(where: { $0.id == strategy.id })
    #expect(running?.state == .running)

    _ = try await runner.stop(id: strategy.id)
    let stopped = await runner.statuses().first(where: { $0.id == strategy.id })
    #expect(stopped?.state == .stopped)
}

@Test("HeartbeatStrategy emits audit events")
func heartbeatStrategyEmitsAudit() async {
    let strategy = HeartbeatStrategy(intervalSec: 0.05)
    let audits = AuditCollector()
    let context = StrategyContext(
        snapshots: AsyncStream { continuation in
            continuation.yield(StoreSnapshot(build: "test"))
            continuation.finish()
        },
        currentSnapshot: {
            StoreSnapshot(build: "test")
        },
        submit: { _ in
            .success(orderID: nil, message: "not-used")
        },
        sleep: { _ in
            await Task.yield()
        },
        audit: { _, _, _, _, _ in
            await audits.increment()
        }
    )

    let task = Task {
        try await strategy.run(context: context, parameters: ["intervalSec": .number(0.05)])
    }

    await Task.yield()
    await Task.yield()
    task.cancel()
    _ = await task.result

    #expect(await audits.value() > 0)
}

@Test("ProposalStore supports create update and list")
func proposalStoreCreateUpdateList() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-store-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let clock = TestDateClock(start: Date(timeIntervalSince1970: 1_700_000_000))
    let store = ProposalStore(
        proposalsDirectory: tempDirectory,
        now: { clock.now() }
    )

    let original = makeProposal(
        proposalID: "proposal-1",
        status: .draft
    )
    let created = try await store.upsertProposal(original)
    #expect(created.proposalId == "proposal-1")

    _ = clock.advance(by: 60)
    var updatedInput = created
    updatedInput.summary = "Updated summary"
    let updated = try await store.upsertProposal(updatedInput)

    #expect(updated.createdAt == created.createdAt)
    #expect(updated.updatedAt > created.updatedAt)
    #expect(updated.summary == "Updated summary")

    let listed = try await store.listProposals()
    #expect(listed.count == 1)
    #expect(listed.first?.proposalId == "proposal-1")
}

@Test("ProposalStore loads legacy v0 JSON proposal files")
func proposalStoreLoadsLegacyV0ProposalJSON() async throws {
    let proposalsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-store-v0-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: proposalsDirectory) }
    try FileManager.default.createDirectory(at: proposalsDirectory, withIntermediateDirectories: true)

    let fixtureData = try loadLegacyProposalFixtureData()
    let legacyFile = proposalsDirectory
        .appendingPathComponent("legacy-proposal")
        .appendingPathExtension("json")
    try fixtureData.write(to: legacyFile, options: [.atomic])

    let store = ProposalStore(proposalsDirectory: proposalsDirectory)
    let proposals = try await store.listProposals()
    #expect(proposals.count == 1)
    #expect(proposals.first?.strategyId == "heartbeat")
    #expect(proposals.first?.originatingSignalId == nil)
}

@Test("ProposalStore skips unknown schema versions with predictable diagnostics")
func proposalStoreUnknownSchemaVersionDiagnostic() async throws {
    let proposalsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-store-unknown-schema-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: proposalsDirectory) }
    try FileManager.default.createDirectory(at: proposalsDirectory, withIntermediateDirectories: true)

    let fileURL = proposalsDirectory
        .appendingPathComponent("unknown-schema")
        .appendingPathExtension("json")
    let payload = """
    {
      "schemaVersion": 99,
      "proposal": {}
    }
    """
    let data = try #require(payload.data(using: .utf8))
    try data.write(to: fileURL, options: [.atomic])

    let store = ProposalStore(proposalsDirectory: proposalsDirectory)
    let proposals = try await store.listProposals()
    #expect(proposals.isEmpty)

    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.contains("code=unsupported_schema_version") == true)
    #expect(diagnostics.first?.contains("version=99") == true)
}

@Test("Proposal approval transitions persist reviewer and notes")
func proposalApprovalTransitions() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-approval-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let store = ProposalStore(proposalsDirectory: tempDirectory)
    let proposal = makeProposal(proposalID: "proposal-2", status: .proposed)
    _ = try await store.upsertProposal(proposal)

    let approved = try await store.setStatus(
        id: "proposal-2",
        status: .approvedPaper,
        reviewedBy: "human",
        notes: "Looks safe for paper."
    )

    #expect(approved.approval.status == .approvedPaper)
    #expect(approved.approval.reviewedBy == "human")
    #expect(approved.approval.reviewNotes == "Looks safe for paper.")
    #expect(approved.approval.reviewedAt != nil)
}

@Test("Engine start-from-proposal blocks when proposal is not approved")
func engineStartFromProposalBlockedWhenNotApproved() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-gate-block-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let proposalStore = ProposalStore(proposalsDirectory: tempDirectory)
    let proposal = makeProposal(
        proposalID: "proposal-3",
        status: .proposed
    )
    _ = try await proposalStore.upsertProposal(proposal)

    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        restClientFactory: { _ in MockRESTClient() }
    )

    do {
        _ = try await engine.startStrategyFromProposal(proposalID: "proposal-3")
        Issue.record("Expected strategy_not_approved_for_paper error.")
    } catch let error as StrategyProposalExecutionError {
        #expect(error == .strategyNotApprovedForPaper(proposalId: "proposal-3"))
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}

@Test("Engine start-from-proposal allows approved paper proposal and carries constraints")
func engineStartFromProposalApprovedPaper() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-gate-allow-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let proposalStore = ProposalStore(proposalsDirectory: tempDirectory)
    let proposal = makeProposal(
        proposalID: "proposal-4",
        status: .approvedPaper,
        parameters: ["intervalSec": .number(0.2)]
    )
    _ = try await proposalStore.upsertProposal(proposal)

    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        restClientFactory: { _ in MockRESTClient() }
    )

    let status = try await engine.startStrategyFromProposal(proposalID: "proposal-4")
    #expect(status.state == .running)
    #expect(status.id == "heartbeat")
    #expect(status.proposalId == "proposal-4")
    #expect(status.proposalConstraints == proposal.constraints)

    _ = try await engine.stopStrategy(id: "heartbeat")
}

@Test("PaperRunStore supports create list get and export")
func paperRunStoreCreateListGetExport() async throws {
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("paper-runs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: runsDirectory) }

    let store = PaperRunStore(runsDirectory: runsDirectory)
    let record = makePaperRunRecord(
        runID: "run-1",
        proposalID: "proposal-run-store-1"
    )

    _ = try await store.createRun(record)
    let summaries = try await store.listRuns(proposalId: "proposal-run-store-1")
    #expect(summaries.count == 1)
    #expect(summaries.first?.runId == "run-1")

    let fetched = try await store.getRun(runId: "run-1")
    #expect(fetched.proposalId == "proposal-run-store-1")
    #expect(fetched.strategyId == "heartbeat")

    let exported = try await store.exportRunJSON(runId: "run-1")
    #expect(exported.contains("\"runId\""))
    #expect(exported.contains("\"proposalId\""))
}

@Test("PaperRunStore loads legacy v0 JSON run files")
func paperRunStoreLoadsLegacyV0RunJSON() async throws {
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("paper-runs-v0-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: runsDirectory) }
    try FileManager.default.createDirectory(at: runsDirectory, withIntermediateDirectories: true)

    let record = makePaperRunRecord(
        runID: "legacy-run-1",
        proposalID: "proposal-legacy-run-1"
    )
    let legacyData = try legacyStoreJSONEncoder().encode(record)
    let fileURL = runsDirectory
        .appendingPathComponent(record.runId)
        .appendingPathExtension("json")
    try legacyData.write(to: fileURL, options: [.atomic])

    let store = PaperRunStore(runsDirectory: runsDirectory)
    let summaries = try await store.listRuns(proposalId: "proposal-legacy-run-1")
    #expect(summaries.count == 1)
    #expect(summaries.first?.runId == "legacy-run-1")
}

@Test("PaperRunStore skips unknown schema versions with predictable diagnostics")
func paperRunStoreUnknownSchemaVersionDiagnostic() async throws {
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("paper-runs-unknown-schema-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: runsDirectory) }
    try FileManager.default.createDirectory(at: runsDirectory, withIntermediateDirectories: true)

    let fileURL = runsDirectory
        .appendingPathComponent("unknown-schema")
        .appendingPathExtension("json")
    let payload = """
    {
      "schemaVersion": 42,
      "run": {}
    }
    """
    let data = try #require(payload.data(using: .utf8))
    try data.write(to: fileURL, options: [.atomic])

    let store = PaperRunStore(runsDirectory: runsDirectory)
    let runs = try await store.listRuns(proposalId: "proposal-does-not-matter")
    #expect(runs.isEmpty)

    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.contains("code=unsupported_schema_version") == true)
    #expect(diagnostics.first?.contains("version=42") == true)
}

@Test("Watchlist persistence loads legacy v0 symbols array")
func watchlistPersistenceLoadsLegacyV0Symbols() throws {
    let watchlistURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("watchlist-v0-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: watchlistURL) }

    let payload = """
    ["msft", "aapl", "msft"]
    """
    let data = try #require(payload.data(using: .utf8))
    try data.write(to: watchlistURL, options: [.atomic])

    let persistence = FileWatchlistPersistence(fileURL: watchlistURL)
    #expect(persistence.loadWatchlistSymbols() == ["AAPL", "MSFT"])
}

@Test("Watchlist persistence loads v1 schema wrapper")
func watchlistPersistenceLoadsSchemaV1() throws {
    let watchlistURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("watchlist-v1-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: watchlistURL) }

    let payload = """
    {
      "schemaVersion": 1,
      "symbols": ["msft", "aapl", "msft"]
    }
    """
    let data = try #require(payload.data(using: .utf8))
    try data.write(to: watchlistURL, options: [.atomic])

    let persistence = FileWatchlistPersistence(fileURL: watchlistURL)
    #expect(persistence.loadWatchlistSymbols() == ["AAPL", "MSFT"])
}

@Test("Watchlist persistence reports unsupported schema versions predictably")
func watchlistPersistenceUnsupportedSchemaVersion() throws {
    let payload = """
    {
      "schemaVersion": 7,
      "symbols": ["AAPL"]
    }
    """
    let data = try #require(payload.data(using: .utf8))
    do {
        _ = try FileWatchlistPersistence.decodeSymbols(from: data)
        Issue.record("Expected unsupported schema version error.")
    } catch let error as WatchlistPersistenceError {
        #expect(error == .unsupportedSchemaVersion(7))
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}

@Test("JobStore persists schema v1 and loads legacy v0 records")
func jobStorePersistsV1AndLoadsLegacyV0() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-v1-v0-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }

    let store = JobStore(jobsDirectory: jobsDirectory)
    let job = JobRecord(
        jobId: "job-v1",
        type: .monitor,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_001),
        status: .queued,
        progress: 0,
        message: "Queued",
        parameters: ["intervalSec": .number(2)]
    )
    _ = try await store.upsert(job)

    let persistedURL = jobsDirectory
        .appendingPathComponent("job-v1")
        .appendingPathExtension("json")
    let persistedData = try Data(contentsOf: persistedURL)
    let persisted = try JSONDecoder().decode(JSONValue.self, from: persistedData)
    let persistedObject = try #require(persisted.objectValue)
    #expect(persistedObject["schemaVersion"] == .number(1))

    let legacy = JobRecord(
        jobId: "job-v0",
        type: .monitor,
        createdAt: Date(timeIntervalSince1970: 1_700_000_100),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
        status: .succeeded,
        progress: 1,
        message: "Done",
        parameters: ["intervalSec": .number(1)]
    )
    let legacyURL = jobsDirectory
        .appendingPathComponent("job-v0")
        .appendingPathExtension("json")
    let legacyData = try legacyStoreJSONEncoder().encode(legacy)
    try legacyData.write(to: legacyURL, options: [.atomic])

    let reloaded = JobStore(jobsDirectory: jobsDirectory)
    let loaded = try await reloaded.loadAll()
    let ids = Set(loaded.map(\.jobId))
    #expect(ids.contains("job-v1"))
    #expect(ids.contains("job-v0"))
}

@Test("JobStore skips unknown schema versions with diagnostics")
func jobStoreUnknownSchemaDiagnostic() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-unknown-schema-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }
    try FileManager.default.createDirectory(at: jobsDirectory, withIntermediateDirectories: true)

    let payload = """
    {
      "schemaVersion": 99,
      "job": {}
    }
    """
    let fileURL = jobsDirectory
        .appendingPathComponent("unknown-schema")
        .appendingPathExtension("json")
    try #require(payload.data(using: .utf8)).write(to: fileURL, options: [.atomic])

    let store = JobStore(jobsDirectory: jobsDirectory)
    let loaded = try await store.loadAll()
    #expect(loaded.isEmpty)

    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.contains("code=unsupported_schema_version") == true)
    #expect(diagnostics.first?.contains("version=99") == true)
}

@Test("JobStore active and recent summaries stay output-bounded with large completed history")
func jobStoreActiveAndRecentSummariesStayBoundedWithLargeCompletedHistory() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-active-recent-bounded-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }

    try FileManager.default.createDirectory(at: jobsDirectory, withIntermediateDirectories: true)
    let now = Date(timeIntervalSince1970: 1_742_920_000)
    let encoder = legacyStoreJSONEncoder()
    let completedCount = 15_000
    for index in 0..<completedCount {
        try writeLegacyJobRecord(
            JobRecord(
                jobId: String(format: "completed-%05d", index),
                type: .standingAnalystReport,
                createdAt: now.addingTimeInterval(Double(-10_000 - index)),
                updatedAt: now.addingTimeInterval(Double(-10_000 - index)),
                status: .succeeded,
                progress: 1.0,
                message: "Historical completed job \(index)",
                parameters: [:]
            ),
            jobsDirectory: jobsDirectory,
            encoder: encoder
        )
    }

    try writeLegacyJobRecord(
        JobRecord(
            jobId: "running-current",
            type: .standingAnalystReport,
            createdAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-10),
            status: .running,
            progress: 0.4,
            message: "Running",
            parameters: [:]
        ),
        jobsDirectory: jobsDirectory,
        encoder: encoder
    )
    try writeLegacyJobRecord(
        JobRecord(
            jobId: "queued-current",
            type: .maintenanceRetention,
            createdAt: now.addingTimeInterval(-30),
            updatedAt: now.addingTimeInterval(-5),
            status: .queued,
            progress: nil,
            message: "Queued",
            parameters: [:]
        ),
        jobsDirectory: jobsDirectory,
        encoder: encoder
    )

    let store = JobStore(jobsDirectory: jobsDirectory)
    let bounded = try await store.listActiveAndRecentSummaries(recentCompletedLimit: 5)
    let initialDiagnostics = try await store.summaryProjectionDiagnostics()

    #expect(try await store.count() == completedCount + 2)
    #expect(bounded.count == 7)
    #expect(bounded.contains { $0.jobId == "running-current" })
    #expect(bounded.contains { $0.jobId == "queued-current" })
    #expect(bounded.filter { $0.status == .succeeded }.count == 5)
    #expect(bounded.contains { $0.jobId == "completed-00000" })
    #expect(bounded.contains { $0.jobId == "completed-00004" })
    #expect(bounded.contains { $0.jobId == "completed-00005" } == false)
    #expect(initialDiagnostics.fullScanCount == 1)
    #expect(initialDiagnostics.incrementalUpdateCount == 0)
    #expect(initialDiagnostics.lastScannedCount == completedCount + 2)
    #expect(initialDiagnostics.visibleCount == 7)

    var running = try #require(try await store.get(id: "running-current"))
    running.progress = 0.55
    running.message = "Still running"
    running.updatedAt = now.addingTimeInterval(-1)
    _ = try await store.upsert(running)

    let afterProgress = try await store.listActiveAndRecentSummaries(recentCompletedLimit: 5)
    let progressDiagnostics = try await store.summaryProjectionDiagnostics()

    #expect(afterProgress.count == 7)
    #expect(afterProgress.contains { $0.jobId == "running-current" && $0.progress == 0.55 })
    #expect(progressDiagnostics.fullScanCount == 1)
    #expect(progressDiagnostics.incrementalUpdateCount == 1)
    #expect(progressDiagnostics.cacheHitCount >= 1)
    #expect(progressDiagnostics.lastScannedCount == 1)
    #expect(try await store.get(id: "completed-14999") != nil)
    let durableFileCount = try FileManager.default.contentsOfDirectory(
        at: jobsDirectory,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension.lowercased() == "json" }
    .count
    #expect(durableFileCount == completedCount + 2)
}

@Test("Engine monitor job transitions queued-running-succeeded with finite ticks")
func engineMonitorJobFiniteTicks() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-monitor-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        jobStore: JobStore(jobsDirectory: jobsDirectory),
        replaySleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    let submitted = try await engine.submitJob(
        type: .monitor,
        parameters: [
            "intervalSec": .number(1),
            "maxTicks": .number(3),
            "threshold": .number(1_000)
        ]
    )

    await settleAsyncWork()
    var current = try await engine.getJob(jobID: submitted.jobId)
    for _ in 0..<200 where current.status != .succeeded {
        if await sleeper.hasPendingWaiter() {
            await sleeper.advance(by: 1)
        }
        await settleAsyncWork()
        current = try await engine.getJob(jobID: submitted.jobId)
    }

    #expect(current.status == .succeeded)
    #expect(current.progress == 1)
    #expect(current.message?.contains("Monitor tick") == true || current.message == "Completed")
    await engine.stop()
}

@Test("Engine indefinite monitor job throttles progress persistence")
func engineIndefiniteMonitorJobThrottlesProgressPersistence() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-monitor-throttled-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let engine = Engine(
        jobStore: JobStore(jobsDirectory: jobsDirectory),
        replaySleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    let submitted = try await engine.submitJob(
        type: .monitor,
        parameters: [
            "intervalSec": .number(1),
            "threshold": .number(1_000)
        ]
    )

    await settleAsyncWork()
    for _ in 0..<10 {
        if await sleeper.hasPendingWaiter() {
            await sleeper.advance(by: 1)
        }
        await settleAsyncWork()
    }

    let current = try await engine.getJob(jobID: submitted.jobId)
    let status = await engine.agentControlStatusJSON()
    guard case .object(let payload) = status,
          case .object(let projection)? = payload["jobSummaryProjection"],
          case .number(let progressPersistCount)? = projection["jobProgressPersistCount"] else {
        Issue.record("Expected agent-control status to include job progress persistence diagnostics.")
        await engine.stop()
        return
    }

    #expect(current.status == .running)
    #expect(current.message == "Monitor tick 1")
    #expect(progressPersistCount == 1)

    _ = try await engine.cancelJob(jobID: submitted.jobId)
    await engine.stop()
}

@Test("Engine monitor job cancel transitions to canceled")
func engineMonitorJobCancel() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobs-cancel-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }
    let engine = Engine(jobStore: JobStore(jobsDirectory: jobsDirectory))

    let submitted = try await engine.submitJob(
        type: .monitor,
        parameters: [
            "intervalSec": .number(10),
            "threshold": .number(1_000)
        ]
    )
    await settleAsyncWork()

    let canceled = try await engine.cancelJob(jobID: submitted.jobId)
    #expect(canceled.status == .canceled)

    let fetched = try await engine.getJob(jobID: submitted.jobId)
    #expect(fetched.status == .canceled)
    await engine.stop()
}

@Test("Engine proposal-backed run records metrics and final status")
func engineProposalRunRecordsMetrics() async throws {
    let proposalDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-run-metrics-\(UUID().uuidString)", isDirectory: true)
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("run-metrics-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: proposalDirectory)
        try? FileManager.default.removeItem(at: runsDirectory)
    }

    let proposalStore = ProposalStore(proposalsDirectory: proposalDirectory)
    let runStore = PaperRunStore(runsDirectory: runsDirectory)
    let mockREST = MockRESTClient()
    let proposalID = "proposal-run-metrics-1"
    _ = try await proposalStore.upsertProposal(
        makeProposal(
            proposalID: proposalID,
            status: .approvedPaper,
            parameters: ["intervalSec": .number(0.2)]
        )
    )

    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        paperRunStore: runStore,
        restClientFactory: { _ in mockREST }
    )

    _ = try await engine.startStrategyFromProposal(proposalID: proposalID)

    let result = await engine.submitOrderIntent(
        .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.heartbeat"
    )
    #expect(result.accepted == true)
    guard let orderID = result.orderID else {
        Issue.record("Expected order ID on accepted strategy intent.")
        throw StrategyRunnerError.strategyNotFound(id: "heartbeat")
    }

    await engine.processTradeUpdate(
        makeTradeUpdateEvent(
            event: "fill",
            orderID: orderID,
            symbol: "AAPL",
            status: "filled",
            filledQty: "1"
        ),
        allowRESTRepairs: false
    )
    _ = try await engine.stopStrategy(id: "heartbeat")

    let summaries = try await engine.listRuns(proposalID: proposalID)
    #expect(summaries.count == 1)
    guard let runSummary = summaries.first else {
        Issue.record("Missing run summary.")
        throw StrategyRunnerError.strategyNotFound(id: "heartbeat")
    }

    let run = try await engine.getRun(runID: runSummary.runId)
    #expect(run.status == .stopped)
    #expect(run.endedAt != nil)
    #expect(run.metrics.orderIntentsSubmitted == 1)
    #expect(run.metrics.ordersAccepted == 1)
    #expect(run.metrics.ordersRejected == 0)
    #expect(run.metrics.fillsCount == 1)
    #expect(run.metrics.partialFillsCount == 0)
    #expect(run.metrics.totalFilledQty == Decimal(string: "1"))
    #expect(run.metrics.symbolsTraded.contains("AAPL"))
    await engine.stop()
}

@Test("Engine persists final run record on stop when debounced persistence is pending")
func engineRunFinalPersistOnStopWithDebounce() async throws {
    let proposalDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-run-final-\(UUID().uuidString)", isDirectory: true)
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("run-final-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: proposalDirectory)
        try? FileManager.default.removeItem(at: runsDirectory)
    }

    let proposalStore = ProposalStore(proposalsDirectory: proposalDirectory)
    let runStore = PaperRunStore(runsDirectory: runsDirectory)
    let mockREST = MockRESTClient()
    let clock = TestClock()
    let sleeper = TestSleeper(clock: clock)
    let proposalID = "proposal-run-final-1"
    _ = try await proposalStore.upsertProposal(
        makeProposal(
            proposalID: proposalID,
            status: .approvedPaper,
            parameters: ["intervalSec": .number(0.2)]
        )
    )

    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        paperRunStore: runStore,
        restClientFactory: { _ in mockREST },
        paperRunPersistDebounceWindow: 100,
        paperRunPersistMaxFrequency: 100,
        paperRunPersistNow: { clock.now() },
        paperRunPersistSleep: { delay in
            await sleeper.sleep(for: delay)
        }
    )

    _ = try await engine.startStrategyFromProposal(proposalID: proposalID)
    let result = await engine.submitOrderIntent(
        .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.heartbeat"
    )
    #expect(result.accepted == true)

    _ = try await engine.stopStrategy(id: "heartbeat")

    let reloadedStore = PaperRunStore(runsDirectory: runsDirectory)
    let summaries = try await reloadedStore.listRuns(proposalId: proposalID)
    #expect(summaries.count == 1)
    guard let runID = summaries.first?.runId else {
        Issue.record("Missing persisted run.")
        throw StrategyRunnerError.strategyNotFound(id: "heartbeat")
    }
    let persisted = try await reloadedStore.getRun(runId: runID)
    #expect(persisted.status == .stopped)
    #expect(persisted.endedAt != nil)
    #expect(persisted.metrics.orderIntentsSubmitted == 1)
    #expect(persisted.metrics.ordersAccepted == 1)
    await engine.stop()
}

@Test("BarsCache upsert/query ordering is deterministic and duplicate timestamps are updated")
func barsCacheUpsertAndQueryOrdering() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("bars-cache-\(UUID().uuidString)", isDirectory: true)
    let dbURL = tempDirectory.appendingPathComponent("bars.sqlite", isDirectory: false)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let cache = BarsCache(databaseURL: dbURL)
    let base = Date(timeIntervalSince1970: 1_700_100_000)
    _ = try await cache.upsertBars([
        makeBar(symbol: "MSFT", timestamp: base.addingTimeInterval(60), close: 400.5),
        makeBar(symbol: "AAPL", timestamp: base, close: 190.1),
        makeBar(symbol: "AAPL", timestamp: base.addingTimeInterval(60), close: 191.1),
        makeBar(symbol: "MSFT", timestamp: base, close: 399.9)
    ])
    _ = try await cache.upsertBars([
        makeBar(symbol: "AAPL", timestamp: base.addingTimeInterval(60), close: 191.7)
    ])

    let queried = try await cache.queryBars(
        symbols: ["MSFT", "AAPL"],
        timeframe: .oneMinute,
        start: base,
        end: base.addingTimeInterval(60)
    )

    #expect(queried.count == 4)
    #expect(queried[0].symbol == "AAPL")
    #expect(queried[1].symbol == "MSFT")
    #expect(queried[2].symbol == "AAPL")
    #expect(queried[3].symbol == "MSFT")
    #expect(abs(queried[2].close - 191.7) < 0.0001)
    await cache.close()
}

@Test("ReplayRunner processes bars and reports barsProcessed with unique symbols")
func replayRunnerProcessesBars() async {
    let base = Date(timeIntervalSince1970: 1_700_200_000)
    let bars = [
        makeBar(symbol: "AAPL", timestamp: base, close: 190.0),
        makeBar(symbol: "MSFT", timestamp: base.addingTimeInterval(60), close: 401.0),
        makeBar(symbol: "AAPL", timestamp: base.addingTimeInterval(120), close: 191.0)
    ]
    let runner = ReplayRunner(clock: ReplayClock(speed: .fast))
    let collector = ReplayBarCollector()

    let progress = await runner.run(bars: bars) { bar in
        await collector.append(bar.symbol)
    }

    #expect(progress.barsProcessed == 3)
    #expect(progress.symbolsSeen == ["AAPL", "MSFT"])
    #expect(await collector.values().count == 3)
}

@Test("Replay quick window computes deterministic start/end with injected clock")
func replayQuickWindowComputation() throws {
    let now = Date(timeIntervalSince1970: 1_700_300_000)
    let resolved = try ReplayWindow.resolve(days: 5, end: nil, now: { now })
    #expect(resolved.end == now)
    #expect(resolved.start == now.addingTimeInterval(-5 * 86_400))

    let explicitEnd = Date(timeIntervalSince1970: 1_700_400_000)
    let explicit = try ReplayWindow.resolve(days: 2, end: explicitEnd, now: { now })
    #expect(explicit.end == explicitEnd)
    #expect(explicit.start == explicitEnd.addingTimeInterval(-2 * 86_400))
}

@Test("Engine replay run blocks when proposal is not approved")
func engineReplayRunBlockedWhenProposalNotApproved() async throws {
    let proposalDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-replay-gate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: proposalDirectory) }

    let proposalStore = ProposalStore(proposalsDirectory: proposalDirectory)
    _ = try await proposalStore.upsertProposal(
        makeProposal(
            proposalID: "proposal-replay-blocked",
            status: .proposed
        )
    )

    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        restClientFactory: { _ in MockRESTClient() }
    )

    do {
        _ = try await engine.replayRun(
            proposalID: "proposal-replay-blocked",
            symbols: ["AAPL"],
            timeframe: .oneMinute,
            start: Date(timeIntervalSince1970: 1_700_500_000),
            end: Date(timeIntervalSince1970: 1_700_500_120),
            speed: .fast,
            autoIngest: false,
            feed: .iex
        )
        Issue.record("Expected strategy_not_approved_for_paper for replay run.")
    } catch let error as StrategyProposalExecutionError {
        #expect(error == .strategyNotApprovedForPaper(proposalId: "proposal-replay-blocked"))
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}

@Test("Replay mode blocks order submissions and increments riskBlocks")
func engineReplayRunBlocksOrderSubmissions() async throws {
    let proposalDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-replay-risk-\(UUID().uuidString)", isDirectory: true)
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("run-replay-risk-\(UUID().uuidString)", isDirectory: true)
    let barsDBDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("bars-replay-risk-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: proposalDirectory)
        try? FileManager.default.removeItem(at: runsDirectory)
        try? FileManager.default.removeItem(at: barsDBDirectory)
    }

    let proposalStore = ProposalStore(proposalsDirectory: proposalDirectory)
    let runStore = PaperRunStore(runsDirectory: runsDirectory)
    let barsCache = BarsCache(
        databaseURL: barsDBDirectory.appendingPathComponent("bars.sqlite", isDirectory: false)
    )
    let baseTimestamp = TimeInterval(1_700_600_000)
    let replayBars = (0..<20).map { index in
        makeBar(
            symbol: "AAPL",
            timestamp: Date(timeIntervalSince1970: baseTimestamp + Double(index)),
            close: 190.0 + Double(index) * 0.1
        )
    }
    _ = try await barsCache.upsertBars(replayBars)

    _ = try await proposalStore.upsertProposal(
        makeProposal(
            proposalID: "proposal-replay-risk-1",
            status: .approvedPaper,
            parameters: ["intervalSec": .number(60)]
        )
    )

    let gate = ReplayGate()
    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        paperRunStore: runStore,
        barsCache: barsCache,
        restClientFactory: { _ in MockRESTClient() },
        replaySleep: { delay in
            await gate.sleep(for: delay)
        }
    )

    let replayTask = Task {
        try await engine.replayRun(
            proposalID: "proposal-replay-risk-1",
            symbols: ["AAPL"],
            timeframe: .oneMinute,
            start: Date(timeIntervalSince1970: baseTimestamp),
            end: Date(timeIntervalSince1970: baseTimestamp + 19),
            speed: .realtime,
            autoIngest: false,
            feed: .iex
        )
    }

    var replayPausedBetweenBars = false
    for _ in 0..<200 {
        if await gate.hasPendingWaiter() {
            replayPausedBetweenBars = true
            break
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(replayPausedBetweenBars == true)

    let blocked = await engine.submitOrderIntent(
        .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.heartbeat"
    )
    #expect(blocked.accepted == false)
    #expect(blocked.errorCode == ReplayError.replayTradingNotEnabled.code)

    await gate.open()
    await settleAsyncWork()
    let replayResult = try await replayTask.value
    #expect(replayResult.barsProcessed == 20)

    let summaries = try await engine.listRuns(proposalID: "proposal-replay-risk-1")
    #expect(summaries.count == 1)
    guard let runID = summaries.first?.runId else {
        Issue.record("Expected replay run summary.")
        throw StrategyRunnerError.strategyNotFound(id: "heartbeat")
    }
    let run = try await engine.getRun(runID: runID)
    #expect(run.runType == .replay)
    #expect(run.metrics.barsProcessed == 20)
    #expect(run.metrics.orderIntentsSubmitted == 1)
    #expect(run.metrics.ordersRejected == 1)
    #expect(run.metrics.riskBlocks == 1)
    await engine.stop()
    await barsCache.close()
}

@Test("SimBroker fills market buy at next bar open")
func simBrokerMarketBuyFillsAtNextBarOpen() async {
    let start = Date(timeIntervalSince1970: 1_701_000_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true
        ),
        initialCash: Decimal(10_000),
        initialTime: start,
        orderIDGenerator: { "sim-mkt-1" }
    )

    let submission = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 2,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.test"
    )
    #expect(submission.result.accepted == true)
    #expect(submission.result.orderID == "sim-mkt-1")

    let firstBar = makeBar(
        symbol: "AAPL",
        timestamp: start,
        open: 100,
        high: 101,
        low: 99,
        close: 100
    )
    let firstTick = await broker.processBar(firstBar)
    #expect(firstTick.events.isEmpty)

    let secondBar = makeBar(
        symbol: "AAPL",
        timestamp: start.addingTimeInterval(60),
        open: 101,
        high: 102,
        low: 100,
        close: 101
    )
    let secondTick = await broker.processBar(secondBar)
    #expect(secondTick.events.count == 1)
    #expect(secondTick.events.first?.event == "fill")
    #expect(secondTick.events.first?.orderID == "sim-mkt-1")
    #expect(secondTick.events.first?.filledAvgPrice == "101")
    #expect(abs(decimalToDouble(secondTick.accountSnapshot.cash) - 9_798) < 0.0001)
}

@Test("SimBroker fills limit buy when bar low crosses limit")
func simBrokerLimitBuyFillsOnLowCross() async {
    let start = Date(timeIntervalSince1970: 1_701_100_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true
        ),
        initialCash: Decimal(10_000),
        initialTime: start,
        orderIDGenerator: { "sim-lmt-buy-1" }
    )

    let submission = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .limit,
                limitPrice: Decimal(95)
            )
        ),
        source: "strategy.test"
    )
    #expect(submission.result.accepted == true)

    let noFill = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 98,
            high: 99,
            low: 96,
            close: 97
        )
    )
    #expect(noFill.events.isEmpty)

    let fill = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(120),
            open: 96,
            high: 97,
            low: 94,
            close: 95
        )
    )
    #expect(fill.events.count == 1)
    #expect(fill.events.first?.event == "fill")
    #expect(fill.events.first?.filledAvgPrice == "95")
}

@Test("SimBroker fills limit sell when bar high crosses limit")
func simBrokerLimitSellFillsOnHighCross() async {
    let start = Date(timeIntervalSince1970: 1_701_200_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true
        ),
        initialCash: Decimal(10_000),
        initialTime: start,
        orderIDGenerator: { "sim-lmt-sell-1" }
    )

    let submission = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .sell,
                type: .limit,
                limitPrice: Decimal(110)
            )
        ),
        source: "strategy.test"
    )
    #expect(submission.result.accepted == true)

    let noFill = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 108,
            high: 109,
            low: 107,
            close: 108
        )
    )
    #expect(noFill.events.isEmpty)

    let fill = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(120),
            open: 108,
            high: 111,
            low: 107,
            close: 110
        )
    )
    #expect(fill.events.count == 1)
    #expect(fill.events.first?.event == "fill")
    #expect(fill.events.first?.filledAvgPrice == "110")
    #expect(fill.accountSnapshot.positions.count == 1)
    #expect(fill.accountSnapshot.positions.first?.qty == Decimal(-1))
}

@Test("SimBroker cancel prevents fill on later bars")
func simBrokerCancelPreventsFill() async {
    let start = Date(timeIntervalSince1970: 1_701_300_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true
        ),
        initialCash: Decimal(10_000),
        initialTime: start,
        orderIDGenerator: { "sim-cancel-1" }
    )

    let submission = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .limit,
                limitPrice: Decimal(95)
            )
        ),
        source: "strategy.test"
    )
    guard let orderID = submission.result.orderID else {
        Issue.record("Expected order ID for cancel test.")
        return
    }

    let cancel = await broker.submit(
        intent: .cancel(orderID: orderID),
        source: "strategy.test"
    )
    #expect(cancel.result.accepted == true)
    #expect(cancel.events.count == 1)
    #expect(cancel.events.first?.event == "canceled")

    let tick = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 96,
            high: 97,
            low: 90,
            close: 95
        )
    )
    #expect(tick.events.isEmpty)
}

@Test("SimBroker replace updates limit and changes fill timing")
func simBrokerReplaceChangesFillTiming() async {
    let start = Date(timeIntervalSince1970: 1_701_400_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true
        ),
        initialCash: Decimal(10_000),
        initialTime: start,
        orderIDGenerator: { UUID().uuidString }
    )

    let submission = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .limit,
                limitPrice: Decimal(90)
            )
        ),
        source: "strategy.test"
    )
    guard let originalOrderID = submission.result.orderID else {
        Issue.record("Expected order ID for replace test.")
        return
    }

    let preReplaceTick = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 98,
            high: 99,
            low: 95,
            close: 97
        )
    )
    #expect(preReplaceTick.events.isEmpty)

    let replace = await broker.submit(
        intent: .replace(
            ReplaceOrderIntent(
                orderID: originalOrderID,
                limitPrice: Decimal(97)
            )
        ),
        source: "strategy.test"
    )
    #expect(replace.result.accepted == true)
    #expect(replace.events.count == 2)
    #expect(replace.events[0].event == "replaced")
    #expect(replace.events[1].event == "new")

    let fillTick = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(120),
            open: 98,
            high: 100,
            low: 96,
            close: 99
        )
    )
    #expect(fillTick.events.count == 1)
    #expect(fillTick.events.first?.event == "fill")
    #expect(fillTick.events.first?.orderID == replace.result.orderID)
    #expect(fillTick.events.first?.filledAvgPrice == "97")
}

@Test("SimBroker applies slippage bps deterministically for market and limit fills")
func simBrokerSlippageAppliedDeterministically() async {
    let start = Date(timeIntervalSince1970: 1_701_450_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true,
            slippageBps: ReplaySlippageBps(market: 10, limit: 10)
        ),
        initialCash: Decimal(10_000),
        initialTime: start
    )

    let marketBuy = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.test"
    )
    #expect(marketBuy.result.accepted == true)

    let marketFillTick = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 100,
            high: 101,
            low: 99,
            close: 100
        )
    )
    #expect(marketFillTick.events.count == 1)
    let marketPrice = Decimal(string: marketFillTick.events[0].filledAvgPrice ?? "")
    #expect(abs(decimalToDouble(marketPrice ?? 0) - 100.1) < 0.0001)

    let limitSell = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .sell,
                type: .limit,
                limitPrice: Decimal(110)
            )
        ),
        source: "strategy.test"
    )
    #expect(limitSell.result.accepted == true)

    let limitFillTick = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(120),
            open: 112,
            high: 113,
            low: 111,
            close: 112
        )
    )
    #expect(limitFillTick.events.count == 1)
    let limitPrice = Decimal(string: limitFillTick.events[0].filledAvgPrice ?? "")
    #expect(abs(decimalToDouble(limitPrice ?? 0) - 111.888) < 0.0001)
}

@Test("SimBroker computes realized PnL for buy then sell round trip")
func simBrokerRealizedPnLRoundTrip() async {
    let start = Date(timeIntervalSince1970: 1_701_500_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true
        ),
        initialCash: Decimal(10_000),
        initialTime: start,
        orderIDGenerator: { UUID().uuidString }
    )

    _ = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.test"
    )
    _ = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 100,
            high: 101,
            low: 99,
            close: 100
        )
    )

    _ = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .sell,
                type: .market
            )
        ),
        source: "strategy.test"
    )
    let sellTick = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(120),
            open: 110,
            high: 111,
            low: 109,
            close: 110
        )
    )
    #expect(sellTick.events.count == 1)

    let snapshot = await broker.snapshot()
    #expect(abs(decimalToDouble(snapshot.realizedPnL) - 10) < 0.0001)
    #expect(abs(decimalToDouble(snapshot.unrealizedPnL) - 0) < 0.0001)
    #expect(abs(decimalToDouble(snapshot.netPnL) - 10) < 0.0001)
    #expect(snapshot.positions.isEmpty)
}

@Test("SimBroker computes unrealized PnL using latest bar close")
func simBrokerUnrealizedPnLUsesLastClose() async {
    let start = Date(timeIntervalSince1970: 1_701_600_000)
    let broker = SimBroker(
        simulation: ReplaySimulationConfig(
            simulateTrades: true,
            allowTradingInReplay: true
        ),
        initialCash: Decimal(10_000),
        initialTime: start,
        orderIDGenerator: { "sim-unrealized-1" }
    )

    _ = await broker.submit(
        intent: .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 2,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.test"
    )
    _ = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 100,
            high: 101,
            low: 99,
            close: 100
        )
    )
    _ = await broker.processBar(
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(120),
            open: 104,
            high: 106,
            low: 103,
            close: 105
        )
    )

    let snapshot = await broker.snapshot()
    #expect(abs(decimalToDouble(snapshot.realizedPnL) - 0) < 0.0001)
    #expect(abs(decimalToDouble(snapshot.unrealizedPnL) - 10) < 0.0001)
    #expect(abs(decimalToDouble(snapshot.netPnL) - 10) < 0.0001)
}

@Test("Replay simulated run fills one market order and records replay PnL")
func engineReplayRunSimulatesTrades() async throws {
    let proposalDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-replay-sim-\(UUID().uuidString)", isDirectory: true)
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("run-replay-sim-\(UUID().uuidString)", isDirectory: true)
    let barsDBDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("bars-replay-sim-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: proposalDirectory)
        try? FileManager.default.removeItem(at: runsDirectory)
        try? FileManager.default.removeItem(at: barsDBDirectory)
    }

    let proposalStore = ProposalStore(proposalsDirectory: proposalDirectory)
    let runStore = PaperRunStore(runsDirectory: runsDirectory)
    let barsCache = BarsCache(
        databaseURL: barsDBDirectory.appendingPathComponent("bars.sqlite", isDirectory: false)
    )
    let baseTimestamp = TimeInterval(1_701_700_000)
    _ = try await barsCache.upsertBars([
        makeBar(
            symbol: "AAPL",
            timestamp: Date(timeIntervalSince1970: baseTimestamp),
            open: 100,
            high: 101,
            low: 99,
            close: 100
        ),
        makeBar(
            symbol: "AAPL",
            timestamp: Date(timeIntervalSince1970: baseTimestamp + 1),
            open: 101,
            high: 102,
            low: 100,
            close: 101
        ),
        makeBar(
            symbol: "AAPL",
            timestamp: Date(timeIntervalSince1970: baseTimestamp + 2),
            open: 102,
            high: 103,
            low: 101,
            close: 102
        )
    ])

    _ = try await proposalStore.upsertProposal(
        makeProposal(
            proposalID: "proposal-replay-sim-1",
            status: .approvedPaper,
            parameters: ["intervalSec": .number(60)]
        )
    )

    let gate = ReplayGate()
    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        paperRunStore: runStore,
        barsCache: barsCache,
        restClientFactory: { _ in MockRESTClient() },
        replaySleep: { delay in
            await gate.sleep(for: delay)
        }
    )

    let replayTask = Task {
        try await engine.replayRun(
            proposalID: "proposal-replay-sim-1",
            symbols: ["AAPL"],
            timeframe: .oneMinute,
            start: Date(timeIntervalSince1970: baseTimestamp),
            end: Date(timeIntervalSince1970: baseTimestamp + 2),
            speed: .realtime,
            autoIngest: false,
            feed: .iex,
            simulateTrades: true,
            allowTradingInReplay: true
        )
    }

    var runID: String?
    for _ in 0..<200 {
        let summaries = try await engine.listRuns(proposalID: "proposal-replay-sim-1")
        if let first = summaries.first {
            runID = first.runId
            break
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    guard let runID else {
        Issue.record("Expected replay run to be created.")
        throw StrategyRunnerError.strategyNotFound(id: "heartbeat")
    }

    var replayPausedBetweenBars = false
    for _ in 0..<200 {
        if await gate.hasPendingWaiter() {
            replayPausedBetweenBars = true
            break
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(replayPausedBetweenBars == true)

    let submission = await engine.submitOrderIntent(
        .place(
            PlaceOrderIntent(
                symbol: "AAPL",
                qty: 1,
                side: .buy,
                type: .market
            )
        ),
        source: "strategy.heartbeat"
    )
    #expect(submission.accepted == true)

    await gate.open()
    await settleAsyncWork()
    let result = try await replayTask.value
    #expect(result.simulateTrades == true)
    #expect(result.fillPolicy == .nextOpenMarket)
    #expect(result.barsProcessed == 3)

    let run = try await engine.getRun(runID: runID)
    #expect(run.runType == .replay)
    #expect(run.startedAt == Date(timeIntervalSince1970: baseTimestamp))
    #expect(run.endedAt == Date(timeIntervalSince1970: baseTimestamp + 2))
    #expect(run.metrics.orderIntentsSubmitted == 1)
    #expect(run.metrics.ordersAccepted == 1)
    #expect(run.metrics.ordersRejected == 0)
    #expect(run.metrics.fillsCount == 1)
    #expect(run.metrics.totalFilledQty == Decimal(1))
    #expect(run.metrics.riskBlocks == 0)
    #expect(run.metrics.startingCash != nil)
    #expect(run.metrics.endingCash != nil)
    #expect(run.metrics.startingEquity != nil)
    #expect(run.metrics.endingEquity != nil)
    #expect(run.metrics.realizedPnL != nil)
    #expect(run.metrics.unrealizedPnL != nil)
    #expect(run.metrics.netPnL != nil)
    #expect(run.replaySimulation?.simulateTrades == true)
    await engine.stop()
    await barsCache.close()
}

@Test("Replay run remains deterministic for same bars and config")
func replayRunDeterministicForSameInputs() async throws {
    let proposalDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("proposal-replay-deterministic-\(UUID().uuidString)", isDirectory: true)
    let runsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("run-replay-deterministic-\(UUID().uuidString)", isDirectory: true)
    let barsDBDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("bars-replay-deterministic-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: proposalDirectory)
        try? FileManager.default.removeItem(at: runsDirectory)
        try? FileManager.default.removeItem(at: barsDBDirectory)
    }

    let proposalStore = ProposalStore(proposalsDirectory: proposalDirectory)
    let runStore = PaperRunStore(runsDirectory: runsDirectory)
    let barsCache = BarsCache(
        databaseURL: barsDBDirectory.appendingPathComponent("bars.sqlite", isDirectory: false)
    )
    let start = Date(timeIntervalSince1970: 1_701_800_000)
    let end = start.addingTimeInterval(180)

    _ = try await barsCache.upsertBars([
        makeBar(
            symbol: "AAPL",
            timestamp: start,
            open: 100,
            high: 101,
            low: 99,
            close: 100
        ),
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(60),
            open: 101,
            high: 102,
            low: 100,
            close: 101
        ),
        makeBar(
            symbol: "AAPL",
            timestamp: start.addingTimeInterval(120),
            open: 102,
            high: 103,
            low: 101,
            close: 102
        ),
        makeBar(
            symbol: "AAPL",
            timestamp: end,
            open: 103,
            high: 104,
            low: 102,
            close: 103
        )
    ])

    _ = try await proposalStore.upsertProposal(
        makeProposal(
            proposalID: "proposal-replay-deterministic-1",
            strategyID: "heartbeat",
            status: .approvedPaper,
            parameters: ["intervalSec": .number(60)]
        )
    )

    let engine = Engine(
        configuration: Configuration(environment: .paper),
        proposalStore: proposalStore,
        paperRunStore: runStore,
        barsCache: barsCache,
        restClientFactory: { _ in MockRESTClient() }
    )

    let firstResult = try await engine.replayRun(
        proposalID: "proposal-replay-deterministic-1",
        symbols: ["AAPL"],
        timeframe: .oneMinute,
        start: start,
        end: end,
        speed: .fast,
        autoIngest: false,
        feed: .iex,
        simulateTrades: true,
        allowTradingInReplay: true,
        fillPolicy: .nextOpenMarket,
        slippageBps: ReplaySlippageBps(market: 0, limit: 0)
    )
    let firstRun = try await engine.getRun(runID: firstResult.runID)

    let secondResult = try await engine.replayRun(
        proposalID: "proposal-replay-deterministic-1",
        symbols: ["AAPL"],
        timeframe: .oneMinute,
        start: start,
        end: end,
        speed: .fast,
        autoIngest: false,
        feed: .iex,
        simulateTrades: true,
        allowTradingInReplay: true,
        fillPolicy: .nextOpenMarket,
        slippageBps: ReplaySlippageBps(market: 0, limit: 0)
    )
    let secondRun = try await engine.getRun(runID: secondResult.runID)

    #expect(firstRun.startedAt == start)
    #expect(secondRun.startedAt == start)
    #expect(firstRun.endedAt == end)
    #expect(secondRun.endedAt == end)

    #expect(firstRun.metrics.barsProcessed == 4)
    #expect(secondRun.metrics.barsProcessed == 4)
    #expect(firstRun.metrics.orderIntentsSubmitted == 0)
    #expect(secondRun.metrics.orderIntentsSubmitted == 0)
    #expect(firstRun.metrics.ordersAccepted == 0)
    #expect(secondRun.metrics.ordersAccepted == 0)
    #expect(firstRun.metrics.fillsCount == 0)
    #expect(secondRun.metrics.fillsCount == 0)
    #expect(firstRun.metrics.totalFilledQty == Decimal(0))
    #expect(secondRun.metrics.totalFilledQty == Decimal(0))

    #expect(abs(decimalToDouble(firstRun.metrics.endingCash ?? 0) - 100_000) < 0.0001)
    #expect(abs(decimalToDouble(secondRun.metrics.endingCash ?? 0) - 100_000) < 0.0001)
    #expect(abs(decimalToDouble(firstRun.metrics.endingEquity ?? 0) - 100_000) < 0.0001)
    #expect(abs(decimalToDouble(secondRun.metrics.endingEquity ?? 0) - 100_000) < 0.0001)
    #expect(abs(decimalToDouble(firstRun.metrics.unrealizedPnL ?? 0) - 0) < 0.0001)
    #expect(abs(decimalToDouble(secondRun.metrics.unrealizedPnL ?? 0) - 0) < 0.0001)
    #expect(abs(decimalToDouble(firstRun.metrics.netPnL ?? 0) - 0) < 0.0001)
    #expect(abs(decimalToDouble(secondRun.metrics.netPnL ?? 0) - 0) < 0.0001)
    await engine.stop()
    await barsCache.close()
}

@Test("Safety gates block strategy order intents when disarmed or kill switch enabled")
func safetyGatesBlockStrategyIntents() async {
    let mockREST = MockRESTClient()
    let engine = Engine(
        configuration: Configuration(environment: .live),
        restClientFactory: { _ in mockREST },
        newArmingSessionID: { "session-1" }
    )

    let placeIntent = OrderIntent.place(
        PlaceOrderIntent(
            symbol: "AAPL",
            qty: 1,
            side: .buy,
            type: .market
        )
    )

    let disarmedResult = await engine.submitOrderIntent(
        placeIntent,
        source: "strategy.heartbeat"
    )
    #expect(disarmedResult.accepted == false)
    #expect(disarmedResult.errorCode == "live_trading_not_armed")
    #expect(await mockREST.placeOrderCallCount() == 0)

    _ = await engine.armLiveTrading()
    await engine.setKillSwitchEnabled(true)
    let killSwitchResult = await engine.submitOrderIntent(
        placeIntent,
        source: "strategy.heartbeat"
    )
    #expect(killSwitchResult.accepted == false)
    #expect(killSwitchResult.errorCode == "trading_disabled_by_kill_switch")
    #expect(await mockREST.placeOrderCallCount() == 0)
    await engine.stop()
}

@Test("IPC router routes and validates JSON requests")
func ipcRouterRoutesRequests() async throws {
    let probe = RouterProbe()
    let sampleRun = PaperRunRecord(
        runId: "run-1",
        proposalId: "proposal-1",
        strategyId: "heartbeat",
        startedAt: Date(timeIntervalSince1970: 1_700_000_010),
        endedAt: Date(timeIntervalSince1970: 1_700_000_030),
        status: .stopped,
        stopReason: "user_stop",
        environment: .paper,
        parametersSnapshot: ["intervalSec": .number(2)],
        constraintsSnapshot: StrategyProposalConstraints(
            maxOrdersPerMinute: 5,
            maxNotionalPerOrder: Decimal(string: "1000")!
        ),
        metrics: PaperRunMetrics(
            orderIntentsSubmitted: 1,
            ordersAccepted: 1,
            fillsCount: 1,
            totalFilledQty: Decimal(string: "1")!,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_030)
        )
    )
    let router = AgentControlRouter(
        authToken: "token-123",
        handlers: .init(
            status: {
                .object(["state": .string("ok")])
            },
            strategies: {
                [
                    StrategyStatusSnapshot(
                        id: "heartbeat",
                        name: "Heartbeat",
                        state: .stopped,
                        parameters: ["intervalSec": .number(2)]
                    )
                ]
            },
            startStrategy: { id, params in
                await probe.recordStart(id: id, params: params)
                return StrategyStatusSnapshot(
                    id: id,
                    name: id,
                    state: .running,
                    parameters: params
                )
            },
            startStrategyFromProposal: { proposalID in
                await probe.recordStartFromProposal(proposalID: proposalID)
                return StrategyStatusSnapshot(
                    id: "heartbeat",
                    name: "Heartbeat",
                    state: .running,
                    parameters: [:],
                    proposalId: proposalID
                )
            },
            stopStrategy: { id in
                StrategyStatusSnapshot(
                    id: id,
                    name: id,
                    state: .stopped
                )
            },
            setStrategyParams: { id, params in
                StrategyStatusSnapshot(
                    id: id,
                    name: id,
                    state: .stopped,
                    parameters: params
                )
            },
            proposals: {
                [
                    ProposalRow(
                        id: "proposal-1",
                        title: "Heartbeat paper test",
                        status: .proposed,
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                        strategyId: "heartbeat",
                        createdBy: "agentctl"
                    )
                ]
            },
            proposal: { id in
                guard id == "proposal-1" else {
                    return nil
                }
                return makeProposal(
                    proposalID: "proposal-1",
                    status: .proposed
                )
            },
            upsertProposal: { proposal in
                proposal
            },
            submitProposal: { _ in
                throw ProposalStoreError.proposalNotFound(id: "missing")
            },
            approveProposalPaper: { _, _, _ in
                throw ProposalStoreError.proposalNotFound(id: "missing")
            },
            denyProposalPaper: { _, _, _ in
                throw ProposalStoreError.proposalNotFound(id: "missing")
            },
            listRuns: { proposalID in
                proposalID == "proposal-1" ? [sampleRun.summary] : []
            },
            getRun: { runID in
                guard runID == "run-1" else {
                    throw PaperRunStoreError.runNotFound(id: runID)
                }
                return sampleRun
            },
            exportRun: { runID in
                guard runID == "run-1" else {
                    throw PaperRunStoreError.runNotFound(id: runID)
                }
                return "{\"runId\":\"run-1\"}"
            },
            listJobs: {
                [
                    JobSummary(
                        jobId: "job-1",
                        type: .monitor,
                        status: .running,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_005),
                        progress: 0.4,
                        message: "Running",
                        proposalId: nil,
                        runId: nil
                    )
                ]
            },
            getJob: { jobID in
                guard jobID == "job-1" else {
                    throw JobStoreError.jobNotFound(id: jobID)
                }
                return JobRecord(
                    jobId: "job-1",
                    type: .monitor,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_005),
                    status: .running,
                    progress: 0.4,
                    message: "Running",
                    parameters: ["intervalSec": .number(2)]
                )
            },
            submitJob: { type, params in
                JobRecord(
                    jobId: "job-submitted-1",
                    type: type,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    status: .queued,
                    progress: 0,
                    message: "Queued",
                    parameters: params
                )
            },
            cancelJob: { jobID in
                JobRecord(
                    jobId: jobID,
                    type: .monitor,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010),
                    status: .canceled,
                    progress: 0.1,
                    message: "Canceled",
                    parameters: [:]
                )
            },
            listSchedules: {
                [
                    ScheduledJobSummary(
                        schedule: ScheduledJob(
                            scheduleId: "schedule-1",
                            jobType: .monitor,
                            enabled: true,
                            trigger: ScheduledJobTrigger(intervalSec: 5),
                            policy: ScheduledJobPolicy(
                                runMode: .alwaysOn,
                                restartOnAppLaunch: true,
                                maxRuntimeSec: nil,
                                allowOverlap: false
                            ),
                            params: [:],
                            nextRunAt: nil,
                            runningJobId: "job-1"
                        )
                    )
                ]
            },
            getSchedule: { scheduleID in
                guard scheduleID == "schedule-1" else {
                    return nil
                }
                return ScheduledJob(
                    scheduleId: "schedule-1",
                    jobType: .monitor,
                    enabled: true,
                    trigger: ScheduledJobTrigger(intervalSec: 5),
                    policy: ScheduledJobPolicy(
                        runMode: .alwaysOn,
                        restartOnAppLaunch: true,
                        maxRuntimeSec: nil,
                        allowOverlap: false
                    ),
                    params: [:],
                    nextRunAt: nil,
                    runningJobId: "job-1"
                )
            },
            upsertSchedule: { schedule in
                ScheduledJobSummary(schedule: schedule)
            },
            removeSchedule: { id in
                if id != "schedule-1" {
                    throw ScheduleStoreError.scheduleNotFound(id: id)
                }
            },
            setScheduleEnabled: { id, enabled in
                guard id == "schedule-1" else {
                    throw ScheduleStoreError.scheduleNotFound(id: id)
                }
                return ScheduledJobSummary(
                    schedule: ScheduledJob(
                        scheduleId: id,
                        jobType: .monitor,
                        enabled: enabled,
                        trigger: ScheduledJobTrigger(intervalSec: 5),
                        policy: ScheduledJobPolicy(
                            runMode: .alwaysOn,
                            restartOnAppLaunch: true,
                            maxRuntimeSec: nil,
                            allowOverlap: false
                        ),
                        params: [:],
                        nextRunAt: nil,
                        runningJobId: enabled ? "job-1" : nil
                    )
                )
            },
            runScheduleNow: { id in
                guard id == "schedule-1" else {
                    throw ScheduleStoreError.scheduleNotFound(id: id)
                }
                return ScheduledJobSummary(
                    schedule: ScheduledJob(
                        scheduleId: id,
                        jobType: .monitor,
                        enabled: true,
                        trigger: ScheduledJobTrigger(intervalSec: 5),
                        policy: ScheduledJobPolicy(
                            runMode: .alwaysOn,
                            restartOnAppLaunch: true,
                            maxRuntimeSec: nil,
                            allowOverlap: false
                        ),
                        params: [:],
                        nextRunAt: nil,
                        runningJobId: "job-2"
                    )
                )
            },
            getRetentionPolicy: {
                RetentionPolicy.default
            },
            updateRetentionPolicy: { policy in
                policy.normalized()
            },
            runMaintenance: { dryRun, cutoff in
                var parameters: [String: JSONValue] = ["dryRun": .bool(dryRun)]
                if let cutoff {
                    parameters["jobTelemetryCleanupBefore"] = .string(DateCodec.formatISO8601(cutoff))
                }
                return JobRecord(
                    jobId: "job-maintenance-1",
                    type: .maintenanceRetention,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_020),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_020),
                    status: .queued,
                    progress: 0,
                    message: "Queued",
                    parameters: parameters
                )
            },
            lastMaintenance: {
                JobSummary(
                    jobId: "job-maintenance-1",
                    type: .maintenanceRetention,
                    status: .succeeded,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_050),
                    progress: 1,
                    message: "Completed",
                    proposalId: nil,
                    runId: nil
                )
            },
            listRSSFeeds: {
                [
                    RSSFeed(
                        id: "feed-1",
                        name: "Fed",
                        url: "https://example.com/fed.xml",
                        enabled: true,
                        pollIntervalSec: 300,
                        tags: ["macro"]
                    )
                ]
            },
            addRSSFeed: { feed in
                feed
            },
            updateRSSFeed: { feed in
                feed
            },
            removeRSSFeed: { _ in },
            listNews: { _, _ in
                [
                    NewsEvent(
                        eventId: "event-1",
                        source: "rss_fed",
                        title: "Fed headline",
                        url: "https://example.com/article",
                        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                        receivedAt: Date(timeIntervalSince1970: 1_700_000_010),
                        summary: "Summary",
                        rawSymbolHints: [],
                        tags: ["macro"],
                        payloadVersion: 1
                    )
                ]
            },
            listPMProfiles: {
                [
                    PMProfile(
                        pmId: "pm-primary",
                        displayName: "Primary PM",
                        roleSummary: "Supervises durable PM mandate and notes.",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMProfile: { pmID in
                guard pmID == "pm-primary" else {
                    throw PMProfileStoreError.profileNotFound(id: pmID)
                }
                return PMProfile(
                    pmId: "pm-primary",
                    displayName: "Primary PM",
                    roleSummary: "Supervises durable PM mandate and notes.",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMProfile: { profile in
                profile
            },
            listPMMandates: {
                [
                    PMMandate(
                        mandateId: "mandate-1",
                        pmId: "pm-primary",
                        title: "Core mandate",
                        objectiveSummary: "Compound capital with human approval gates.",
                        scope: "Cross-asset supervision",
                        constraints: ["No autonomous live trading"],
                        riskBoundaries: ["Respect kill switch"],
                        successCriteria: ["Auditability"],
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMMandate: { mandateID in
                guard mandateID == "mandate-1" else {
                    throw PMMandateStoreError.mandateNotFound(id: mandateID)
                }
                return PMMandate(
                    mandateId: "mandate-1",
                    pmId: "pm-primary",
                    title: "Core mandate",
                    objectiveSummary: "Compound capital with human approval gates.",
                    scope: "Cross-asset supervision",
                    constraints: ["No autonomous live trading"],
                    riskBoundaries: ["Respect kill switch"],
                    successCriteria: ["Auditability"],
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMMandate: { mandate in
                mandate
            },
            listPMInstructions: {
                [
                    PMInstruction(
                        instructionId: "instruction-1",
                        pmId: "pm-primary",
                        title: "Standing guidance",
                        body: "Preserve durable PM memory in app-owned records.",
                        category: "operating_guidance",
                        status: .active,
                        effectiveAt: Date(timeIntervalSince1970: 1_700_000_005),
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMInstruction: { instructionID in
                guard instructionID == "instruction-1" else {
                    throw PMInstructionStoreError.instructionNotFound(id: instructionID)
                }
                return PMInstruction(
                    instructionId: "instruction-1",
                    pmId: "pm-primary",
                    title: "Standing guidance",
                    body: "Preserve durable PM memory in app-owned records.",
                    category: "operating_guidance",
                    status: .active,
                    effectiveAt: Date(timeIntervalSince1970: 1_700_000_005),
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMInstruction: { instruction in
                instruction
            },
            listPMNotebookEntries: {
                [
                    PMNotebookEntry(
                        entryId: "note-1",
                        pmId: "pm-primary",
                        title: "Working note",
                        body: "Remote communication outcomes should be promoted, not stored as transcript memory.",
                        tags: ["memory", "pm"],
                        sourceSummary: "owner guidance",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMNotebookEntry: { entryID in
                guard entryID == "note-1" else {
                    throw PMNotebookStoreError.entryNotFound(id: entryID)
                }
                return PMNotebookEntry(
                    entryId: "note-1",
                    pmId: "pm-primary",
                    title: "Working note",
                    body: "Remote communication outcomes should be promoted, not stored as transcript memory.",
                    tags: ["memory", "pm"],
                    sourceSummary: "owner guidance",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMNotebookEntry: { entry in
                entry
            },
            getPortfolioStrategyBrief: {
                PortfolioStrategyBrief(
                    objectiveSummary: "Keep event-driven portfolio reviews bounded and app-owned.",
                    currentRiskPosture: "Moderate risk posture.",
                    reviewEscalationPosture: "PM review first.",
                    updatedBy: "pm-primary",
                    updateSource: .pmControlPlane,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPortfolioStrategyBrief: { brief in
                brief
            },
            listPMDecisions: {
                [
                    PMDecisionRecord(
                        decisionId: "decision-1",
                        pmId: "pm-primary",
                        title: "Escalate proposal review",
                        summary: "PM recommends a bounded human review step.",
                        decisionType: .escalation,
                        status: .active,
                        delegationId: "delegation-1",
                        signalId: "sig-1",
                        proposalId: "proposal-1",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMDecision: { decisionID in
                guard decisionID == "decision-1" else {
                    throw PMDecisionStoreError.decisionNotFound(id: decisionID)
                }
                return PMDecisionRecord(
                    decisionId: "decision-1",
                    pmId: "pm-primary",
                    title: "Escalate proposal review",
                    summary: "PM recommends a bounded human review step.",
                    decisionType: .escalation,
                    status: .active,
                    delegationId: "delegation-1",
                    signalId: "sig-1",
                    proposalId: "proposal-1",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMDecision: { decision in
                decision
            },
            listPMApprovalRequests: {
                [
                    PMApprovalRequest(
                        approvalRequestId: "approval-1",
                        pmId: "pm-primary",
                        subject: "Review proposal readiness",
                        rationale: "Need a durable PM-layer approval-ready record.",
                        requestType: .proposalReview,
                        status: .pending,
                        decisionId: "decision-1",
                        delegationId: "delegation-1",
                        proposalId: "proposal-1",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMApprovalRequest: { approvalRequestID in
                guard approvalRequestID == "approval-1" else {
                    throw PMApprovalRequestStoreError.approvalRequestNotFound(id: approvalRequestID)
                }
                return PMApprovalRequest(
                    approvalRequestId: "approval-1",
                    pmId: "pm-primary",
                    subject: "Review proposal readiness",
                    rationale: "Need a durable PM-layer approval-ready record.",
                    requestType: .proposalReview,
                    status: .pending,
                    decisionId: "decision-1",
                    delegationId: "delegation-1",
                    proposalId: "proposal-1",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMApprovalRequest: { approvalRequest in
                approvalRequest
            },
            listPMCommunicationSessions: {
                [
                    PMCommunicationSession(
                        sessionId: "session-1",
                        channel: .mockTelegram,
                        externalConversationId: "chat-1",
                        pmId: "pm-primary",
                        participantId: "owner-1",
                        participantDisplayName: "Owner",
                        status: .active,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMCommunicationSession: { sessionID in
                guard sessionID == "session-1" else {
                    throw PMCommunicationSessionStoreError.sessionNotFound(id: sessionID)
                }
                return PMCommunicationSession(
                    sessionId: "session-1",
                    channel: .mockTelegram,
                    externalConversationId: "chat-1",
                    pmId: "pm-primary",
                    participantId: "owner-1",
                    participantDisplayName: "Owner",
                    status: .active,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMCommunicationSession: { session in
                session
            },
            listPMCommunicationMessages: {
                [
                    PMCommunicationMessage(
                        messageId: "message-1",
                        sessionId: "session-1",
                        direction: .incoming,
                        senderRole: .owner,
                        senderId: "owner-1",
                        body: "Please review the proposal tomorrow.",
                        sentAt: Date(timeIntervalSince1970: 1_700_000_005),
                        promotion: PMCommunicationPromotion(
                            targetType: .approvalRequest,
                            targetId: "approval-1",
                            promotedAt: Date(timeIntervalSince1970: 1_700_000_010)
                        ),
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMCommunicationMessage: { messageID in
                guard messageID == "message-1" else {
                    throw PMCommunicationMessageStoreError.messageNotFound(id: messageID)
                }
                return PMCommunicationMessage(
                    messageId: "message-1",
                    sessionId: "session-1",
                    direction: .incoming,
                    senderRole: .owner,
                    senderId: "owner-1",
                    body: "Please review the proposal tomorrow.",
                    sentAt: Date(timeIntervalSince1970: 1_700_000_005),
                    promotion: PMCommunicationPromotion(
                        targetType: .approvalRequest,
                        targetId: "approval-1",
                        promotedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    ),
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMCommunicationMessage: { message in
                message
            },
            listPMDelegations: {
                [
                    PMDelegationRecord(
                        delegationId: "delegation-1",
                        pmId: "pm-primary",
                        analystId: "macro-analyst",
                        charterId: "charter-1",
                        taskId: "task-1",
                        title: "Review Fed task",
                        rationale: "PM requested attributable analyst work.",
                        requestedOutputs: [.finding],
                        status: .issued,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getPMDelegation: { delegationID in
                guard delegationID == "delegation-1" else {
                    throw PMDelegationStoreError.delegationNotFound(id: delegationID)
                }
                return PMDelegationRecord(
                    delegationId: "delegation-1",
                    pmId: "pm-primary",
                    analystId: "macro-analyst",
                    charterId: "charter-1",
                    taskId: "task-1",
                    title: "Review Fed task",
                    rationale: "PM requested attributable analyst work.",
                    requestedOutputs: [.finding],
                    status: .issued,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertPMDelegation: { delegation in
                delegation
            },
            launchPMDelegation: { delegationID, draftSignal, draftProposal in
                AnalystWorkerLaunchResult(
                    charterId: "charter-1",
                    taskId: "task-1",
                    delegationId: delegationID,
                    pmId: "pm-primary",
                    findingId: "finding-1",
                    findingTitle: "Delegated finding",
                    draftedSignalId: draftSignal ? "sig-1" : nil,
                    draftedProposalId: draftProposal ? "proposal-1" : nil,
                    runtimeProvenance: AnalystRuntimeProvenance(
                        intendedPolicy: AnalystRuntimePolicy(
                            runtimeIdentifier: "gpt-5",
                            reasoningMode: .deliberate,
                            policySource: .pmDelegationOverride,
                            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
                        ),
                        actualRuntimeIdentifier: "deterministic_local",
                        launchedAt: Date(timeIntervalSince1970: 1_700_000_000)
                    ),
                    summary: "finding: Delegated finding",
                    outputExcerpt: "finding_id: finding-1"
                )
            },
            listAnalystCharters: {
                [
                    AnalystCharter(
                        charterId: "charter-1",
                        analystId: "macro-analyst",
                        title: "Macro Charter",
                        coverageScope: "US macro",
                        strategyFamily: "swing",
                        summary: "Review macro catalysts.",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                    )
                ]
            },
            getAnalystCharter: { charterID in
                guard charterID == "charter-1" else {
                    throw AnalystCharterStoreError.charterNotFound(id: charterID)
                }
                return AnalystCharter(
                    charterId: "charter-1",
                    analystId: "macro-analyst",
                    title: "Macro Charter",
                    coverageScope: "US macro",
                    strategyFamily: "swing",
                    summary: "Review macro catalysts.",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_010)
                )
            },
            upsertAnalystCharter: { charter in
                charter
            },
            listAnalystTasks: {
                [
                    AnalystTask(
                        taskId: "task-1",
                        analystId: "macro-analyst",
                        charterId: "charter-1",
                        title: "Review Fed",
                        description: "Summarize latest tone shift.",
                        status: .inProgress,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_020)
                    )
                ]
            },
            getAnalystTask: { taskID in
                guard taskID == "task-1" else {
                    throw AnalystTaskStoreError.taskNotFound(id: taskID)
                }
                return AnalystTask(
                    taskId: "task-1",
                    analystId: "macro-analyst",
                    charterId: "charter-1",
                    title: "Review Fed",
                    description: "Summarize latest tone shift.",
                    status: .inProgress,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_020)
                )
            },
            upsertAnalystTask: { task in
                task
            },
            listAnalystFindings: {
                [
                    AnalystFinding(
                        findingId: "finding-1",
                        analystId: "macro-analyst",
                        taskId: "task-1",
                        title: "Rates pressure easing",
                        summary: "Macro pressure may be easing.",
                        thesis: "Large-cap tech may benefit.",
                        status: .open,
                        confidence: 0.7,
                        evidenceBundleId: "bundle-1",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
                    )
                ]
            },
            getAnalystFinding: { findingID in
                guard findingID == "finding-1" else {
                    throw AnalystFindingStoreError.findingNotFound(id: findingID)
                }
                return AnalystFinding(
                    findingId: "finding-1",
                    analystId: "macro-analyst",
                    taskId: "task-1",
                    title: "Rates pressure easing",
                    summary: "Macro pressure may be easing.",
                    thesis: "Large-cap tech may benefit.",
                    status: .open,
                    confidence: 0.7,
                    evidenceBundleId: "bundle-1",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
                )
            },
            listAnalystMemos: {
                [
                    AnalystMemo(
                        memoId: "memo-1",
                        analystId: "macro-analyst",
                        charterId: "charter-1",
                        taskId: "task-1",
                        delegationId: "delegation-1",
                        pmId: "pm-primary",
                        findingId: "finding-1",
                        evidenceBundleId: "bundle-1",
                        title: "Rates pressure easing",
                        executiveSummary: "Macro pressure appears to be easing, supporting a more constructive near-term view.",
                        currentView: "The view is constructive but still bounded by uncertainty.",
                        evidenceSummary: "Recent app-owned evidence points to easing pressure.",
                        uncertaintySummary: "Further confirmation is needed before stronger escalation.",
                        recommendedNextStep: "Use this memo as support for PM review.",
                        confidence: 0.7,
                        runtimeProvenance: nil,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
                    )
                ]
            },
            getAnalystMemo: { memoID in
                guard memoID == "memo-1" else {
                    throw AnalystMemoStoreError.memoNotFound(id: memoID)
                }
                return AnalystMemo(
                    memoId: "memo-1",
                    analystId: "macro-analyst",
                    charterId: "charter-1",
                    taskId: "task-1",
                    delegationId: "delegation-1",
                    pmId: "pm-primary",
                    findingId: "finding-1",
                    evidenceBundleId: "bundle-1",
                    title: "Rates pressure easing",
                    executiveSummary: "Macro pressure appears to be easing, supporting a more constructive near-term view.",
                    currentView: "The view is constructive but still bounded by uncertainty.",
                    evidenceSummary: "Recent app-owned evidence points to easing pressure.",
                    uncertaintySummary: "Further confirmation is needed before stronger escalation.",
                    recommendedNextStep: "Use this memo as support for PM review.",
                    confidence: 0.7,
                    runtimeProvenance: nil,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
                )
            },
            upsertAnalystEvidenceBundle: { bundle in
                bundle
            },
            upsertAnalystMemo: { memo in
                memo
            },
            upsertAnalystFinding: { finding in
                finding
            },
            draftSignalFromAnalystFinding: { findingID in
                Signal(
                    signalId: "sig-\(findingID)",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_030),
                    status: .new,
                    symbols: ["AAPL"],
                    direction: .bullish,
                    horizon: .swing,
                    confidence: 0.7,
                    score: 0.7,
                    positionStatement: "Large-cap tech may benefit.",
                    recommendedAction: .notifyOnly,
                    evidence: [
                        SignalEvidenceRef(
                            type: .finding,
                            id: findingID,
                            title: "Rates pressure easing",
                            summary: "Macro pressure may be easing.",
                            timestamp: Date(timeIntervalSince1970: 1_700_000_030)
                        )
                    ],
                    provenance: SignalProvenance(
                        sourceJobId: "analyst.finding_draft",
                        scoringVersion: "analyst-finding-v1",
                        analystId: "macro-analyst",
                        charterId: "charter-1",
                        taskId: "task-1",
                        sourceFindingId: findingID,
                        sourceEvidenceBundleId: "bundle-1"
                    ),
                    originatingFindingId: findingID
                )
            },
            draftProposalFromAnalystSignal: { signalID, strategyID in
                StrategyProposal(
                    proposalId: "proposal-\(signalID)",
                    createdBy: "analyst-job",
                    title: "Proposal for \(signalID)",
                    summary: "Drafted from analyst signal",
                    strategyId: strategyID,
                    parameters: [:],
                    constraints: StrategyProposalConstraints(
                        maxOrdersPerMinute: 5,
                        maxNotionalPerOrder: 1000
                    ),
                    testPlan: StrategyProposalTestPlan(
                        durationMinutes: 60,
                        successMetrics: ["signal_alignment"],
                        stopConditions: ["manual_stop"]
                    ),
                    rationale: "Analyst signal rationale",
                    originatingSignalId: signalID
                )
            },
            listSignals: { _, _ in
                []
            },
            getSignal: { id in
                throw SignalStoreError.signalNotFound(id: id)
            },
            acknowledgeSignal: { id in
                throw SignalStoreError.signalNotFound(id: id)
            },
            archiveSignal: { id in
                throw SignalStoreError.signalNotFound(id: id)
            },
            replayIngest: { request in
                ReplayIngestResult(
                    symbols: request.symbols,
                    timeframe: request.timeframe,
                    start: request.start,
                    end: request.end,
                    feed: request.feed,
                    barsIngested: 3
                )
            },
            replayRun: { request in
                ReplayRunResult(
                    runID: "replay-run-1",
                    proposalID: request.proposalID,
                    barsProcessed: 3,
                    barsIngested: 3,
                    speed: request.speed
                )
            },
            replayQuick: { request in
                ReplayRunResult(
                    runID: "replay-run-quick-1",
                    proposalID: request.proposalID,
                    barsProcessed: 3,
                    barsIngested: 3,
                    speed: request.speed
                )
            },
            armLive: {
                "session-1"
            },
            disarmLive: {},
            setKillSwitch: { _ in }
        )
    )

    let unauthorized = await router.handle(
        IPCServerRequest(method: "GET", path: "/status", headers: [:], body: Data())
    )
    #expect(unauthorized.statusCode == 401)

    let statusResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/status",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let statusEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: statusResponse.body)
    #expect(statusEnvelope.ok == true)

    let body = try JSONEncoder().encode(
        JSONValue.object([
            "id": .string("heartbeat"),
            "params": .object(["intervalSec": .number(2)])
        ])
    )
    let startResponse = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/strategy/start",
            headers: ["x-agent-token": "token-123"],
            body: body
        )
    )
    let startEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: startResponse.body)
    #expect(startEnvelope.ok == true)
    #expect(await probe.startedID() == "heartbeat")

    let proposalsResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/proposals",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let proposalsEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: proposalsResponse.body)
    #expect(proposalsEnvelope.ok == true)

    let proposalResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/proposal?id=proposal-1",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let proposalEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: proposalResponse.body)
    #expect(proposalEnvelope.ok == true)

    let startFromProposalBody = try JSONEncoder().encode(
        JSONValue.object(["proposalId": .string("proposal-1")])
    )
    let startFromProposalResponse = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/strategy/start-from-proposal",
            headers: ["x-agent-token": "token-123"],
            body: startFromProposalBody
        )
    )
    let startFromProposalEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: startFromProposalResponse.body)
    #expect(startFromProposalEnvelope.ok == true)
    #expect(await probe.startedProposalID() == "proposal-1")

    let runsResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/runs?proposalId=proposal-1",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let runsEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: runsResponse.body)
    #expect(runsEnvelope.ok == true)

    let runResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/run?id=run-1",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let runEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: runResponse.body)
    #expect(runEnvelope.ok == true)

    let runExportBody = try JSONEncoder().encode(
        JSONValue.object(["runId": .string("run-1")])
    )
    let runExportResponse = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/run/export",
            headers: ["x-agent-token": "token-123"],
            body: runExportBody
        )
    )
    let runExportEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: runExportResponse.body)
    #expect(runExportEnvelope.ok == true)

    let jobsResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/jobs",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let jobsEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: jobsResponse.body)
    #expect(jobsEnvelope.ok == true)

    let jobResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/job?id=job-1",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let jobEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: jobResponse.body)
    #expect(jobEnvelope.ok == true)

    let submitJobBody = try JSONEncoder().encode(
        JSONValue.object([
            "type": .string("monitor"),
            "params": .object([
                "intervalSec": .number(2)
            ])
        ])
    )
    let submitJobResponse = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/jobs/submit",
            headers: ["x-agent-token": "token-123"],
            body: submitJobBody
        )
    )
    let submitJobEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: submitJobResponse.body)
    #expect(submitJobEnvelope.ok == true)

    let cancelJobBody = try JSONEncoder().encode(
        JSONValue.object(["jobId": .string("job-1")])
    )
    let cancelJobResponse = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/job/cancel",
            headers: ["x-agent-token": "token-123"],
            body: cancelJobBody
        )
    )
    let cancelJobEnvelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: cancelJobResponse.body)
    #expect(cancelJobEnvelope.ok == true)
}

private func loadLegacyProposalFixtureData(filePath: String = #filePath) throws -> Data {
    let fileURL = URL(fileURLWithPath: filePath)
    let repositoryRoot = fileURL
        .deletingLastPathComponent() // TradingKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // TradingKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
    let fixtureURL = repositoryRoot
        .appendingPathComponent("docs", isDirectory: true)
        .appendingPathComponent("verification", isDirectory: true)
        .appendingPathComponent("proposal.sample.json", isDirectory: false)

    if let data = try? Data(contentsOf: fixtureURL) {
        return data
    }

    // Fallback for environments where docs fixtures are unavailable in test sandbox.
    let embedded = """
    {
      "proposalId": "legacy-proposal-fixture",
      "createdAt": "2026-02-28T00:00:00Z",
      "updatedAt": "2026-02-28T00:00:00Z",
      "createdBy": "research-agent",
      "title": "Heartbeat fixture",
      "summary": "Legacy proposal fixture fallback",
      "strategyId": "heartbeat",
      "parameters": { "intervalSec": 2 },
      "scope": { "symbols": ["FAKEPACA"], "watchlistReference": null },
      "intendedEnvironmentPaperOnly": true,
      "constraints": {
        "maxOrdersPerMinute": 0,
        "maxNotionalPerOrder": 0,
        "maxDailyNotional": null,
        "allowShort": false,
        "allowOptions": false
      },
      "testPlan": {
        "durationMinutes": 1,
        "successMetrics": ["heartbeat ticks visible in audit log"],
        "stopConditions": ["manual stop"]
      },
      "rationale": "Fallback fixture",
      "metadata": {},
      "approval": {
        "status": "draft",
        "reviewedBy": null,
        "reviewedAt": null,
        "reviewNotes": ""
      },
      "runResult": null
    }
    """
    return try #require(embedded.data(using: .utf8))
}

private func legacyStoreJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: date))
    }
    return encoder
}

private func writeLegacyJobRecord(
    _ job: JobRecord,
    jobsDirectory: URL,
    encoder: JSONEncoder
) throws {
    let fileURL = jobsDirectory
        .appendingPathComponent(job.jobId)
        .appendingPathExtension("json")
    let data = try encoder.encode(job)
    try data.write(to: fileURL, options: [.atomic])
}

private func makeProposal(
    proposalID: String = UUID().uuidString,
    strategyID: String = "heartbeat",
    status: StrategyProposalStatus = .draft,
    parameters: [String: JSONValue] = ["intervalSec": .number(1.0)]
) -> StrategyProposal {
    StrategyProposal(
        proposalId: proposalID,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        createdBy: "research-agent",
        title: "Heartbeat paper test",
        summary: "Validate heartbeat wiring in paper mode.",
        strategyId: strategyID,
        parameters: parameters,
        scope: StrategyProposalScope(symbols: ["AAPL"]),
        intendedEnvironmentPaperOnly: true,
        constraints: StrategyProposalConstraints(
            maxOrdersPerMinute: 5,
            maxNotionalPerOrder: Decimal(string: "1000")!,
            maxDailyNotional: Decimal(string: "5000"),
            allowShort: false,
            allowOptions: false
        ),
        testPlan: StrategyProposalTestPlan(
            durationMinutes: 30,
            successMetrics: ["No crashes", "Audit heartbeat ticks"],
            stopConditions: ["Excess errors"]
        ),
        rationale: "Baseline strategy validation",
        approval: StrategyProposalApproval(status: status)
    )
}

private func makePaperRunRecord(
    runID: String = UUID().uuidString,
    proposalID: String = "proposal-1"
) -> PaperRunRecord {
    PaperRunRecord(
        runId: runID,
        proposalId: proposalID,
        strategyId: "heartbeat",
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        endedAt: Date(timeIntervalSince1970: 1_700_000_060),
        status: .stopped,
        stopReason: "user_stop",
        environment: .paper,
        parametersSnapshot: ["intervalSec": .number(2)],
        constraintsSnapshot: StrategyProposalConstraints(
            maxOrdersPerMinute: 5,
            maxNotionalPerOrder: Decimal(string: "1000")!,
            maxDailyNotional: Decimal(string: "5000"),
            allowShort: false,
            allowOptions: false
        ),
        metrics: PaperRunMetrics(
            orderIntentsSubmitted: 1,
            ordersAccepted: 1,
            ordersRejected: 0,
            fillsCount: 1,
            partialFillsCount: 0,
            totalFilledQty: Decimal(string: "1")!,
            symbolsTraded: ["AAPL"],
            riskBlocks: 0,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_060),
            netPnL: Decimal(string: "0")
        )
    )
}

private func makeBar(
    symbol: String,
    timeframe: BarTimeframe = .oneMinute,
    timestamp: Date,
    close: Double
) -> Bar {
    Bar(
        symbol: symbol,
        timeframe: timeframe,
        timestamp: timestamp,
        open: close - 0.5,
        high: close + 0.5,
        low: close - 1.0,
        close: close,
        volume: 100
    )
}

private func makeBar(
    symbol: String,
    timeframe: BarTimeframe = .oneMinute,
    timestamp: Date,
    open: Double,
    high: Double,
    low: Double,
    close: Double,
    volume: Double = 100
) -> Bar {
    Bar(
        symbol: symbol,
        timeframe: timeframe,
        timestamp: timestamp,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume
    )
}

private func decimalToDouble(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}

private func makeTradeUpdateEvent(
    event: String,
    orderID: String,
    symbol: String,
    status: String? = nil,
    filledQty: String? = nil
) -> TradeUpdateEvent {
    let resolvedStatus: String
    if let status {
        resolvedStatus = status
    } else {
        resolvedStatus = event == "partial_fill" ? "partially_filled" : "filled"
    }

    let resolvedFilledQty: String?
    if let filledQty {
        resolvedFilledQty = filledQty
    } else if resolvedStatus == "partially_filled" || resolvedStatus == "partially-filled" {
        resolvedFilledQty = "0.5"
    } else {
        resolvedFilledQty = "1"
    }

    return TradeUpdateEvent(
        event: event,
        orderID: orderID,
        symbol: symbol,
        side: "buy",
        qty: "1",
        filledQty: resolvedFilledQty,
        filledAvgPrice: "190.1",
        timestamp: "2024-01-01T00:00:00Z",
        orderStatus: resolvedStatus
    )
}

private func makeStrategyContext() -> StrategyContext {
    StrategyContext(
        snapshots: AsyncStream { continuation in
            continuation.yield(StoreSnapshot(build: "test"))
            continuation.finish()
        },
        currentSnapshot: {
            StoreSnapshot(build: "test")
        },
        submit: { _ in
            .success(orderID: nil, message: "ok")
        },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: 1_000_000)
        },
        audit: { _, _, _, _, _ in
        }
    )
}

private func settleAsyncWork() async {
    await Task.yield()
    await Task.yield()
    await Task.yield()
}

private func waitForCondition(
    attempts: Int = 20,
    _ condition: @escaping @Sendable () async -> Bool
) async {
    for _ in 0..<attempts {
        if await condition() {
            return
        }
        await settleAsyncWork()
    }
}

private actor Counter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private actor AuditCollector {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private actor ReplayBarCollector {
    private var symbols: [String] = []

    func append(_ symbol: String) {
        symbols.append(symbol)
    }

    func values() -> [String] {
        symbols
    }
}

private actor ReplayGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for delay: TimeInterval) async {
        guard delay > 0 else {
            return
        }
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }

    func hasPendingWaiter() -> Bool {
        !waiters.isEmpty
    }
}

private actor RouterProbe {
    private var started: String?
    private var startedProposal: String?

    func recordStart(id: String, params _: [String: JSONValue]) {
        started = id
    }

    func recordStartFromProposal(proposalID: String) {
        startedProposal = proposalID
    }

    func startedID() -> String? {
        started
    }

    func startedProposalID() -> String? {
        startedProposal
    }
}

private struct HoldingStrategy: Strategy {
    let id = "holding"
    let name = "Holding"
    let defaultParameters: [String: JSONValue] = [:]

    func run(context: StrategyContext, parameters _: [String: JSONValue]) async throws {
        while !Task.isCancelled {
            await context.sleep(seconds: 0.1)
        }
    }
}

private final class SessionIDSequence: @unchecked Sendable {
    private let queue = DispatchQueue(label: "tradingkit.test.session-sequence")
    private var values: [String]

    init(values: [String]) {
        self.values = values
    }

    func next() -> String {
        queue.sync {
            if values.isEmpty {
                return UUID().uuidString
            }
            return values.removeFirst()
        }
    }
}

private final class TestDateClock: @unchecked Sendable {
    private let queue = DispatchQueue(label: "tradingkit.test.date-clock")
    private var currentDate: Date

    init(start: Date) {
        currentDate = start
    }

    func now() -> Date {
        queue.sync { currentDate }
    }

    @discardableResult
    func advance(by seconds: TimeInterval) -> Date {
        queue.sync {
            currentDate = currentDate.addingTimeInterval(seconds)
            return currentDate
        }
    }
}

private final class TestClock: @unchecked Sendable {
    private let queue = DispatchQueue(label: "tradingkit.test.clock")
    private var currentTime: TimeInterval = 0

    func now() -> TimeInterval {
        queue.sync { currentTime }
    }

    @discardableResult
    func advance(by delta: TimeInterval) -> TimeInterval {
        queue.sync {
            currentTime += delta
            return currentTime
        }
    }
}

private actor TestLocalUserPresenceAuthorizer: LocalUserPresenceAuthorizing {
    private var queuedResults: [LocalUserPresenceAuthorizationResult]
    private var recordedChallenges: [LocalUserPresenceChallenge] = []

    init(results: [LocalUserPresenceAuthorizationResult]) {
        queuedResults = results
    }

    func authorize(
        challenge: LocalUserPresenceChallenge
    ) async -> LocalUserPresenceAuthorizationResult {
        recordedChallenges.append(challenge)
        if queuedResults.isEmpty {
            return LocalUserPresenceAuthorizationResult(
                status: .systemError,
                summary: "No queued test authorization result.",
                checkedAt: Date(timeIntervalSince1970: 0)
            )
        }
        return queuedResults.removeFirst()
    }

    func challengeCount() -> Int {
        recordedChallenges.count
    }

    func challenges() -> [LocalUserPresenceChallenge] {
        recordedChallenges
    }
}

private actor TestSleeper {
    private struct Waiter {
        let id: UUID
        let deadline: TimeInterval
        let continuation: CheckedContinuation<Void, Never>
    }

    private let clock: TestClock
    private var waiters: [Waiter] = []

    init(clock: TestClock) {
        self.clock = clock
    }

    func sleep(for delay: TimeInterval) async {
        let clampedDelay = max(0, delay)
        guard clampedDelay > 0 else {
            return
        }
        let deadline = clock.now() + clampedDelay
        let waiterID = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Cancellation can arrive before the continuation is stored.
                // In that case, resume immediately instead of parking forever.
                guard !Task.isCancelled else {
                    continuation.resume()
                    return
                }
                waiters.append(
                    Waiter(
                        id: waiterID,
                        deadline: deadline,
                        continuation: continuation
                    )
                )
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: waiterID)
            }
        }
    }

    func advance(by delta: TimeInterval) {
        let now = clock.advance(by: delta)
        var remaining: [Waiter] = []
        for waiter in waiters {
            if waiter.deadline <= now {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
    }

    func hasPendingWaiter() -> Bool {
        !waiters.isEmpty
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume()
    }
}

private struct MockKeyReader: KeyReading {
    let values: [String: String]

    func readKey(service: String, account: String) -> String? {
        values["\(service)|\(account)"]
    }
}

private actor MockRESTClient: AlpacaRESTServing {
    private var accountState = Account(
        id: "acct-1",
        status: "ACTIVE",
        cash: "1000",
        buyingPower: "2000",
        equity: "3000",
        multiplier: "2"
    )
    private var positionsState: [Position] = []
    private var openOrdersState: [Order] = []
    private var assetsBySymbol: [String: Asset] = [:]
    private var optionContractsBySymbol: [String: OptionContract] = [:]
    private var fetchAccountInvocations = 0
    private var fetchPositionsInvocations = 0
    private var fetchOpenOrdersInvocations = 0
    private var fetchAssetInvocations = 0
    private var placeOrderInvocations = 0
    private var placedOrders: [NewOrderRequest] = []
    private var replaceOrderInvocations = 0
    private var replaceInvocations: [(orderId: String, request: ReplaceOrderRequest)] = []
    private var cancelOrderInvocations = 0

    func fetchAccount() async throws -> Account {
        fetchAccountInvocations += 1
        return accountState
    }

    func fetchPositions() async throws -> [Position] {
        fetchPositionsInvocations += 1
        return positionsState
    }

    func fetchOpenOrders() async throws -> [Order] {
        fetchOpenOrdersInvocations += 1
        return openOrdersState
    }

    func fetchAsset(symbol: String) async throws -> Asset {
        fetchAssetInvocations += 1
        let normalized = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return assetsBySymbol[normalized]
            ?? Asset(
                symbol: normalized,
                tradable: true,
                marginable: true,
                shortable: true
            )
    }

    func fetchOptionContract(symbolOrID: String) async throws -> OptionContract {
        let normalized = symbolOrID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if let cached = optionContractsBySymbol[normalized] {
            return cached
        }
        return OptionContract(
            id: "opt-\(normalized)",
            symbol: normalized,
            underlyingSymbol: OptionContractSymbol.parse(normalized)?.underlyingSymbol
        )
    }

    func placeOrder(request: NewOrderRequest) async throws -> Order {
        placeOrderInvocations += 1
        placedOrders.append(request)
        return Order(
            id: "ord-test-\(placeOrderInvocations)",
            clientOrderId: nil,
            symbol: request.symbol,
            qty: request.qty,
            side: request.side.rawValue,
            type: request.type.rawValue,
            timeInForce: request.timeInForce.rawValue,
            status: "new"
        )
    }

    func replaceOrder(orderId: String, request: ReplaceOrderRequest) async throws -> Order {
        replaceOrderInvocations += 1
        replaceInvocations.append((orderId: orderId, request: request))
        return Order(
            id: "ord-replace-\(replaceOrderInvocations)",
            symbol: "AAPL",
            qty: request.qty ?? "1",
            limitPrice: request.limitPrice,
            side: "buy",
            type: "limit",
            timeInForce: "day",
            status: "new"
        )
    }

    func cancelOrder(orderId: String) async throws {
        cancelOrderInvocations += 1
    }

    func setAccount(_ account: Account) {
        accountState = account
    }

    func setPositions(_ positions: [Position]) {
        positionsState = positions
    }

    func setOpenOrders(_ openOrders: [Order]) {
        openOrdersState = openOrders
    }

    func setAsset(
        symbol: String,
        tradable: Bool? = true,
        marginable: Bool? = true,
        shortable: Bool? = true
    ) {
        let normalized = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        assetsBySymbol[normalized] = Asset(
            symbol: normalized,
            tradable: tradable,
            marginable: marginable,
            shortable: shortable
        )
    }

    func setOptionContract(_ contract: OptionContract) {
        let normalized = contract.symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        optionContractsBySymbol[normalized] = contract
    }

    func placeOrderCallCount() -> Int {
        placeOrderInvocations
    }

    func fetchAccountCallCount() -> Int {
        fetchAccountInvocations
    }

    func fetchAssetCallCount() -> Int {
        fetchAssetInvocations
    }

    func fetchPositionsCallCount() -> Int {
        fetchPositionsInvocations
    }

    func fetchOpenOrdersCallCount() -> Int {
        fetchOpenOrdersInvocations
    }

    func lastPlacedOrder() -> NewOrderRequest? {
        placedOrders.last
    }

    func replaceOrderCallCount() -> Int {
        replaceOrderInvocations
    }

    func cancelOrderCallCount() -> Int {
        cancelOrderInvocations
    }

    func lastReplaceInvocation() -> (orderId: String, request: ReplaceOrderRequest)? {
        replaceInvocations.last
    }
}
