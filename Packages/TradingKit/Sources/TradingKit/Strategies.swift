import Foundation

public struct StrategyContext: Sendable {
    public let snapshots: AsyncStream<StoreSnapshot>

    private let currentSnapshotImpl: @Sendable () async -> StoreSnapshot
    private let submitImpl: @Sendable (OrderIntent) async -> OrderIntentSubmissionResult
    private let sleepImpl: @Sendable (TimeInterval) async -> Void
    private let auditImpl: @Sendable (AuditEventLevel, String, String?, String?, String?) async -> Void
    private let shutdownImpl: @Sendable () async -> Void

    public init(
        snapshots: AsyncStream<StoreSnapshot>,
        currentSnapshot: @escaping @Sendable () async -> StoreSnapshot,
        submit: @escaping @Sendable (OrderIntent) async -> OrderIntentSubmissionResult,
        sleep: @escaping @Sendable (TimeInterval) async -> Void,
        audit: @escaping @Sendable (AuditEventLevel, String, String?, String?, String?) async -> Void,
        shutdown: @escaping @Sendable () async -> Void = {}
    ) {
        self.snapshots = snapshots
        self.currentSnapshotImpl = currentSnapshot
        self.submitImpl = submit
        self.sleepImpl = sleep
        self.auditImpl = audit
        self.shutdownImpl = shutdown
    }

    public func currentSnapshot() async -> StoreSnapshot {
        await currentSnapshotImpl()
    }

    public func submit(_ intent: OrderIntent) async -> OrderIntentSubmissionResult {
        await submitImpl(intent)
    }

    public func sleep(seconds: TimeInterval) async {
        await sleepImpl(seconds)
    }

    public func emitAudit(
        level: AuditEventLevel = .info,
        message: String,
        action: String? = nil,
        symbol: String? = nil,
        orderID: String? = nil
    ) async {
        await auditImpl(level, message, action, symbol, orderID)
    }

    public func shutdown() async {
        await shutdownImpl()
    }
}

public protocol Strategy: Sendable {
    var id: String { get }
    var name: String { get }
    var defaultParameters: [String: JSONValue] { get }

    func run(context: StrategyContext, parameters: [String: JSONValue]) async throws
}

public enum StrategyRunState: String, Sendable, Codable {
    case stopped
    case running
    case error
}

public struct StrategyStatusSnapshot: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let state: StrategyRunState
    public let lastMessage: String?
    public let startTime: String?
    public let parameters: [String: JSONValue]
    public let proposalId: String?
    public let proposalConstraints: StrategyProposalConstraints?

    public init(
        id: String,
        name: String,
        state: StrategyRunState,
        lastMessage: String? = nil,
        startTime: String? = nil,
        parameters: [String: JSONValue] = [:],
        proposalId: String? = nil,
        proposalConstraints: StrategyProposalConstraints? = nil
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.lastMessage = lastMessage
        self.startTime = startTime
        self.parameters = parameters
        self.proposalId = proposalId
        self.proposalConstraints = proposalConstraints
    }
}

public enum StrategyRunnerError: Error, Sendable, Equatable {
    case strategyNotFound(id: String)
    case strategyAlreadyRunning(id: String)

    public var code: String {
        switch self {
        case .strategyNotFound:
            return "strategy_not_found"
        case .strategyAlreadyRunning:
            return "strategy_already_running"
        }
    }

    public var message: String {
        switch self {
        case .strategyNotFound(let id):
            return "Strategy not found: \(id)"
        case .strategyAlreadyRunning(let id):
            return "Strategy already running: \(id)"
        }
    }
}

private struct StrategyState {
    var status: StrategyRunState = .stopped
    var lastMessage: String?
    var startTime: Date?
    var parameters: [String: JSONValue]
    var activeProposalID: String?
    var activeProposalConstraints: StrategyProposalConstraints?

    init(parameters: [String: JSONValue]) {
        self.parameters = parameters
    }
}

public actor StrategyRunner {
    private let onStatusesChanged: @Sendable ([StrategyStatusSnapshot]) async -> Void
    private let nowDate: @Sendable () -> Date

    private var strategiesByID: [String: any Strategy] = [:]
    private var stateByID: [String: StrategyState] = [:]
    private var tasksByID: [String: Task<Void, Never>] = [:]

    public init(
        strategies: [any Strategy] = [],
        onStatusesChanged: @escaping @Sendable ([StrategyStatusSnapshot]) async -> Void = { _ in },
        nowDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.onStatusesChanged = onStatusesChanged
        self.nowDate = nowDate

        for strategy in strategies {
            strategiesByID[strategy.id] = strategy
            stateByID[strategy.id] = StrategyState(parameters: strategy.defaultParameters)
        }
    }

    deinit {
        let tasks = Array(tasksByID.values)
        tasksByID.removeAll()
        for task in tasks {
            task.cancel()
        }
    }

    public func register(_ strategy: any Strategy) async {
        strategiesByID[strategy.id] = strategy
        if stateByID[strategy.id] == nil {
            stateByID[strategy.id] = StrategyState(parameters: strategy.defaultParameters)
        }
        await emitStatusesChanged()
    }

    public func statuses() -> [StrategyStatusSnapshot] {
        makeStatusesSnapshot()
    }

    @discardableResult
    public func start(
        id: String,
        params: [String: JSONValue]? = nil,
        context: StrategyContext,
        proposalID: String? = nil,
        proposalConstraints: StrategyProposalConstraints? = nil
    ) async throws -> StrategyStatusSnapshot {
        guard let strategy = strategiesByID[id] else {
            throw StrategyRunnerError.strategyNotFound(id: id)
        }

        guard tasksByID[id] == nil else {
            throw StrategyRunnerError.strategyAlreadyRunning(id: id)
        }

        var state = stateByID[id] ?? StrategyState(parameters: strategy.defaultParameters)
        if let params {
            state.parameters = params
        }
        state.status = .running
        state.startTime = nowDate()
        state.lastMessage = "started"
        state.activeProposalID = proposalID
        state.activeProposalConstraints = proposalConstraints
        stateByID[id] = state
        await emitStatusesChanged()

        let parameters = state.parameters

        let task = Task { [weak self] in
            do {
                try await strategy.run(context: context, parameters: parameters)
                await context.shutdown()
                await self?.handleCompletion(strategyID: id, error: nil)
            } catch {
                await context.shutdown()
                if error is CancellationError {
                    await self?.handleCompletion(strategyID: id, error: nil)
                } else {
                    await self?.handleCompletion(strategyID: id, error: error)
                }
            }
        }

        tasksByID[id] = task
        return makeStatusSnapshot(id: id)
    }

    @discardableResult
    public func stop(id: String) async throws -> StrategyStatusSnapshot {
        guard strategiesByID[id] != nil else {
            throw StrategyRunnerError.strategyNotFound(id: id)
        }

        if let task = tasksByID.removeValue(forKey: id) {
            task.cancel()
            await task.value
        }

        var state = stateByID[id] ?? StrategyState(parameters: [:])
        state.status = .stopped
        state.startTime = nil
        state.lastMessage = "stopped"
        state.activeProposalID = nil
        state.activeProposalConstraints = nil
        stateByID[id] = state
        await emitStatusesChanged()

        return makeStatusSnapshot(id: id)
    }

    @discardableResult
    public func setParameters(
        id: String,
        params: [String: JSONValue]
    ) async throws -> StrategyStatusSnapshot {
        guard let strategy = strategiesByID[id] else {
            throw StrategyRunnerError.strategyNotFound(id: id)
        }

        var state = stateByID[id] ?? StrategyState(parameters: strategy.defaultParameters)
        state.parameters = params
        state.lastMessage = tasksByID[id] == nil
            ? "parameters updated"
            : "parameters updated (applies next run)"
        stateByID[id] = state
        await emitStatusesChanged()

        return makeStatusSnapshot(id: id)
    }

    public func stopAll() async {
        let running = Array(tasksByID)
        tasksByID.removeAll()
        for (_, task) in running {
            task.cancel()
        }
        for (_, task) in running {
            await task.value
        }

        let ids = running.map(\.key)
        for id in ids {
            if var state = stateByID[id] {
                state.status = .stopped
                state.startTime = nil
                state.lastMessage = "stopped"
                state.activeProposalID = nil
                state.activeProposalConstraints = nil
                stateByID[id] = state
            }
        }
        await emitStatusesChanged()
    }

    private func handleCompletion(strategyID: String, error: Error?) async {
        tasksByID[strategyID] = nil
        guard var state = stateByID[strategyID] else {
            await emitStatusesChanged()
            return
        }

        state.startTime = nil
        state.activeProposalID = nil
        state.activeProposalConstraints = nil
        if let error {
            state.status = .error
            state.lastMessage = error.localizedDescription
        } else {
            state.status = .stopped
            if state.lastMessage == "started" {
                state.lastMessage = "completed"
            }
        }

        stateByID[strategyID] = state
        await emitStatusesChanged()
    }

    private func emitStatusesChanged() async {
        await onStatusesChanged(makeStatusesSnapshot())
    }

    private func makeStatusesSnapshot() -> [StrategyStatusSnapshot] {
        strategiesByID.keys.sorted().map { makeStatusSnapshot(id: $0) }
    }

    private func makeStatusSnapshot(id: String) -> StrategyStatusSnapshot {
        let strategy = strategiesByID[id]
        let state = stateByID[id]

        return StrategyStatusSnapshot(
            id: id,
            name: strategy?.name ?? id,
            state: state?.status ?? .stopped,
            lastMessage: state?.lastMessage,
            startTime: state?.startTime.map(Self.iso8601String),
            parameters: state?.parameters ?? strategy?.defaultParameters ?? [:],
            proposalId: state?.activeProposalID,
            proposalConstraints: state?.activeProposalConstraints
        )
    }

    private static func iso8601String(_ date: Date) -> String {
        DateCodec.formatISO8601(date)
    }
}

public struct HeartbeatStrategy: Strategy {
    public let id: String = "heartbeat"
    public let name: String = "Heartbeat"
    public let defaultParameters: [String: JSONValue]

    public init(intervalSec: TimeInterval = 5) {
        defaultParameters = [
            "intervalSec": .number(max(0.2, intervalSec))
        ]
    }

    public func run(context: StrategyContext, parameters: [String: JSONValue]) async throws {
        let interval = max(0.2, parameters["intervalSec"]?.doubleValue ?? 5)

        while !Task.isCancelled {
            await context.emitAudit(
                message: "heartbeat tick interval_sec=\(interval)",
                action: "heartbeat"
            )
            await context.sleep(seconds: interval)
        }
    }
}

public enum StrategyExecutionError: Error, Sendable, LocalizedError {
    case disabled
    case liveNotAllowed
    case submitRejected(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .disabled:
            return "Strategy trading is disabled by parameters."
        case .liveNotAllowed:
            return "This strategy only runs in paper mode."
        case .submitRejected(_, let message):
            return message
        }
    }
}

public struct PaperOneShotTestOrderStrategy: Strategy {
    public let id: String = "paper_oneshot"
    public let name: String = "Paper One Shot"
    public let defaultParameters: [String: JSONValue] = [
        "enableTrading": .bool(false),
        "symbol": .string("AAPL"),
        "qty": .number(1),
        "side": .string("buy"),
        "type": .string("market")
    ]

    public init() {}

    public func run(context: StrategyContext, parameters: [String: JSONValue]) async throws {
        let tradingEnabled = parameters["enableTrading"]?.boolValue ?? false
        guard tradingEnabled else {
            await context.emitAudit(
                level: .warning,
                message: "paper_oneshot skipped because enableTrading=false",
                action: "paper_oneshot"
            )
            throw StrategyExecutionError.disabled
        }

        let snapshot = await context.currentSnapshot()
        guard !snapshot.isLive else {
            await context.emitAudit(
                level: .warning,
                message: "paper_oneshot blocked in live environment",
                action: "paper_oneshot"
            )
            throw StrategyExecutionError.liveNotAllowed
        }

        let symbol = parameters["symbol"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? "AAPL"
        let qty = max(1, parameters["qty"]?.intValue ?? 1)
        let side: OrderSide = (parameters["side"]?.stringValue?.lowercased() == "sell") ? .sell : .buy
        let type: OrderType = (parameters["type"]?.stringValue?.lowercased() == "limit") ? .limit : .market

        let intent = PlaceOrderIntent(
            instrumentType: .equity,
            symbol: symbol,
            qty: qty,
            side: side,
            type: type,
            limitPrice: nil,
            timeInForce: .day,
            bracket: nil
        )

        await context.emitAudit(
            message: "paper_oneshot submitting one order symbol=\(symbol) qty=\(qty) side=\(side.rawValue)",
            action: "paper_oneshot",
            symbol: symbol
        )
        let result = await context.submit(.place(intent))

        guard result.accepted else {
            throw StrategyExecutionError.submitRejected(
                code: result.errorCode ?? "submit_failed",
                message: result.message
            )
        }
    }
}
