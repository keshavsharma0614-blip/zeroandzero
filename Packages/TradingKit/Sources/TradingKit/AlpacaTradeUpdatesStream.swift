import Foundation

public actor AlpacaTradeUpdatesStream {
    public nonisolated let events: AsyncStream<TradeUpdatesStreamEvent>

    private let continuation: AsyncStream<TradeUpdatesStreamEvent>.Continuation
    private let keychainProvider: KeychainCredentialsProvider
    private let session: URLSession
    private let backoffPolicy: ExponentialBackoffPolicy
    private let randomUnit: @Sendable () -> Double
    private let sleep: @Sendable (TimeInterval) async -> Void

    private var environment: Environment
    private var state: TradeUpdatesConnectionState = .disconnected
    private var isRunning = false
    private var runnerTask: Task<Void, Never>?
    private var runnerGeneration = 0
    private var socketTask: URLSessionWebSocketTask?
    private var lastStateChangedAt: Date?
    private var lastAuthorizationStatus: String?
    private var lastListeningStreams: [String] = []
    private var lastDiagnostic: String?
    private var lastError: String?
    private var reconnectRequestCount = 0
    private var lastReconnectReason: String?

    public init(
        environment: Environment = .paper,
        keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider(),
        session: URLSession = .shared,
        backoffPolicy: ExponentialBackoffPolicy = ExponentialBackoffPolicy(),
        randomUnit: @escaping @Sendable () -> Double = { Double.random(in: 0...1) },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    ) {
        var createdContinuation: AsyncStream<TradeUpdatesStreamEvent>.Continuation?
        self.events = AsyncStream { continuation in
            createdContinuation = continuation
        }
        guard let createdContinuation else {
            fatalError("Failed to initialize trade update stream continuation.")
        }
        self.continuation = createdContinuation
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
        emitState(.disconnected)
    }

    public func connectionState() -> TradeUpdatesConnectionState {
        state
    }

    public func requestReconnect(reason: String) {
        let boundedReason = sanitizeDiagnostic(reason)
        reconnectRequestCount += 1
        lastReconnectReason = boundedReason
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        emitState(.disconnected)
        emitDiagnostic("trade_updates reconnect requested: \(boundedReason)")
        guard isRunning else {
            return
        }
        runnerTask?.cancel()
        startRunnerTask()
    }

    public func runtimeSnapshot() -> TradeUpdatesStreamRuntimeSnapshot {
        TradeUpdatesStreamRuntimeSnapshot(
            environment: environment,
            endpoint: endpointURL(for: environment).absoluteString,
            state: state,
            isRunning: isRunning,
            hasSocketTask: socketTask != nil,
            lastStateChangedAt: lastStateChangedAt,
            lastAuthorizationStatus: lastAuthorizationStatus,
            lastListeningStreams: lastListeningStreams,
            lastDiagnostic: lastDiagnostic,
            lastError: lastError,
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

    private func runLoop(generation: Int) async {
        var attempt = 0

        while isRunning && generation == runnerGeneration && !Task.isCancelled {
            do {
                try await connectAndAuthenticate()
                attempt = 0
                try await receiveLoop()
            } catch {
                guard generation == runnerGeneration else {
                    break
                }
                socketTask?.cancel(with: .goingAway, reason: nil)
                socketTask = nil
                lastError = sanitizeDiagnostic(error.localizedDescription)
                emitState(.disconnected)
                emitDiagnostic("trade_updates reconnect required: \(error.localizedDescription)")
            }

            guard isRunning && generation == runnerGeneration && !Task.isCancelled else {
                break
            }

            let delay = backoffPolicy.delay(attempt: attempt, randomUnit: randomUnit())
            attempt += 1
            emitDiagnostic(String(format: "trade_updates reconnecting in %.2fs", delay))
            await sleep(delay)
        }

        if generation == runnerGeneration {
            emitState(.disconnected)
        }
    }

    private func connectAndAuthenticate() async throws {
        guard let credentials = keychainProvider.credentials(for: environment) else {
            throw AlpacaAPIError.missingCredentials(environment: environment)
        }

        emitState(.connecting)
        let task = session.webSocketTask(with: endpointURL(for: environment))
        socketTask = task
        task.resume()
        emitState(.connected)

        let authPayload: [String: String] = [
            "action": "auth",
            "key": credentials.publicKey,
            "secret": credentials.secretKey
        ]
        try await send(payload: authPayload)
    }

    private func receiveLoop() async throws {
        while isRunning && !Task.isCancelled {
            guard let socketTask else {
                throw AlpacaAPIError.transportFailure(message: "trade_updates socket not initialized")
            }

            let message = try await socketTask.receive()
            switch message {
            case .string(let text):
                await handleIncoming(data: Data(text.utf8))
            case .data(let data):
                await handleIncoming(data: data)
            @unknown default:
                emitDiagnostic("trade_updates received unknown websocket frame")
            }
        }
    }

    private func handleIncoming(data: Data) async {
        let messages = AlpacaTradeUpdatesCodec.decodeMessages(from: data)
        for message in messages {
            switch message {
            case .authorization(let status):
                lastAuthorizationStatus = status
                emitDiagnostic("trade_updates authorization status: \(status)")
                if status.lowercased() == "authorized" || status.lowercased() == "authenticated" {
                    emitState(.authenticated)
                    lastError = nil
                    do {
                        try await sendListenRequest()
                    } catch {
                        lastError = sanitizeDiagnostic(error.localizedDescription)
                        emitDiagnostic("trade_updates listen request failed: \(error.localizedDescription)")
                    }
                } else {
                    lastError = "authorization \(status)"
                }
            case .listening(let streams):
                lastListeningStreams = streams
                emitDiagnostic("trade_updates listening: \(streams.joined(separator: ","))")
                if streams.contains("trade_updates") {
                    emitState(.subscribed)
                    lastError = nil
                } else {
                    lastError = "listen acknowledgement missing trade_updates"
                }
            case .tradeUpdate(let event):
                emit(.tradeUpdate(event))
            case .success(let message):
                emitDiagnostic("trade_updates success: \(message)")
            case .error(let message):
                lastError = sanitizeDiagnostic(message)
                emitDiagnostic("trade_updates error: \(message)")
            case .unknown(let description):
                emitDiagnostic("trade_updates unknown payload: \(description)")
            }
        }
    }

    func handleIncomingForTesting(data: Data) async {
        await handleIncoming(data: data)
    }

    private func sendListenRequest() async throws {
        let listenPayload: [String: Any] = [
            "action": "listen",
            "data": [
                "streams": ["trade_updates"]
            ]
        ]
        try await sendAny(payload: listenPayload)
    }

    private func send(payload: [String: String]) async throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let text = String(data: data, encoding: .utf8) else {
            throw AlpacaAPIError.transportFailure(message: "Failed to encode auth payload")
        }
        guard let socketTask else {
            throw AlpacaAPIError.transportFailure(message: "trade_updates socket unavailable")
        }
        try await socketTask.send(.string(text))
    }

    private func sendAny(payload: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let text = String(data: data, encoding: .utf8) else {
            throw AlpacaAPIError.transportFailure(message: "Failed to encode websocket payload")
        }
        guard let socketTask else {
            throw AlpacaAPIError.transportFailure(message: "trade_updates socket unavailable")
        }
        try await socketTask.send(.string(text))
    }

    private func endpointURL(for environment: Environment) -> URL {
        switch environment {
        case .paper:
            return URL(string: "wss://paper-api.alpaca.markets/stream")!
        case .live:
            return URL(string: "wss://api.alpaca.markets/stream")!
        }
    }

    private func emitState(_ newState: TradeUpdatesConnectionState) {
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

    private func emit(_ event: TradeUpdatesStreamEvent) {
        continuation.yield(event)
    }
}
