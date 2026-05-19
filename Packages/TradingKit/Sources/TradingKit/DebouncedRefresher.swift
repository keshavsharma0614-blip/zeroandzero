import Foundation

public enum DebouncedRefresherLifecycleEvent: Sendable, Equatable {
    case scheduled
    case ran
    case canceled
}

public actor DebouncedRefresher {
    private let debounceWindow: TimeInterval
    private let minIntervalBetweenRuns: TimeInterval
    private let now: @Sendable () -> TimeInterval
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let onLifecycle: (@Sendable (DebouncedRefresherLifecycleEvent) async -> Void)?

    private var lastRunAt: TimeInterval?
    private var nextRunAt: TimeInterval?
    private var pendingAction: (@Sendable () async -> Void)?
    private var runnerTask: Task<Void, Never>?

    public init(
        debounceWindow: TimeInterval = 1,
        minIntervalBetweenRuns: TimeInterval = 3,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        },
        onLifecycle: (@Sendable (DebouncedRefresherLifecycleEvent) async -> Void)? = nil
    ) {
        self.debounceWindow = max(0, debounceWindow)
        self.minIntervalBetweenRuns = max(0, minIntervalBetweenRuns)
        self.now = now
        self.sleep = sleep
        self.onLifecycle = onLifecycle
    }

    public func trigger(action: @escaping @Sendable () async -> Void) async {
        let current = now()
        let debounceReadyAt = current + debounceWindow
        let minIntervalReadyAt = lastRunAt.map { $0 + minIntervalBetweenRuns } ?? current
        let desiredRunAt = max(debounceReadyAt, minIntervalReadyAt)

        if let nextRunAt {
            self.nextRunAt = max(nextRunAt, desiredRunAt)
        } else {
            self.nextRunAt = desiredRunAt
        }

        pendingAction = action
        await emit(.scheduled)
        ensureRunner()
    }

    public func cancel() async {
        // Clear scheduling state and cancel any sleeping runner immediately so
        // tests and engine teardown do not leak debounce tasks past shutdown.
        nextRunAt = nil
        pendingAction = nil
        let task = runnerTask
        runnerTask = nil
        task?.cancel()
        if let task {
            await task.value
        }
        await emit(.canceled)
    }

    private func ensureRunner() {
        guard runnerTask == nil else {
            return
        }
        runnerTask = Task { [self] in
            await runLoop()
        }
    }

    private func runLoop() async {
        defer {
            runnerTask = nil
        }

        while !Task.isCancelled {
            guard let deadline = nextRunAt else {
                return
            }

            let delay = max(0, deadline - now())
            await sleep(delay)
            guard !Task.isCancelled else {
                return
            }

            guard let latestDeadline = nextRunAt else {
                continue
            }
            let current = now()
            if current + 0.000_001 < latestDeadline {
                continue
            }

            nextRunAt = nil
            let action = pendingAction
            pendingAction = nil
            lastRunAt = current

            if let action {
                await action()
                await emit(.ran)
            }
        }
    }

    private func emit(_ event: DebouncedRefresherLifecycleEvent) async {
        guard let onLifecycle else {
            return
        }
        await onLifecycle(event)
    }
}
