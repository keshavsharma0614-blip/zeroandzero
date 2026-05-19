import Foundation

public struct ReplayClock: Sendable {
    public let speed: ReplaySpeed
    private let sleep: @Sendable (TimeInterval) async -> Void

    public init(
        speed: ReplaySpeed,
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    ) {
        self.speed = speed
        self.sleep = sleep
    }

    public func wait(previous: Date?, current: Date) async {
        guard speed == .realtime,
              let previous
        else {
            return
        }
        let delay = max(0, current.timeIntervalSince(previous))
        await sleep(delay)
    }
}

public struct ReplayRunProgress: Sendable, Equatable {
    public let barsProcessed: Int
    public let symbolsSeen: [String]

    public init(barsProcessed: Int, symbolsSeen: [String]) {
        self.barsProcessed = barsProcessed
        self.symbolsSeen = symbolsSeen
    }
}

public actor ReplayRunner {
    private let clock: ReplayClock

    public init(clock: ReplayClock) {
        self.clock = clock
    }

    public func run(
        bars: [Bar],
        onBar: @escaping @Sendable (Bar) async -> Void
    ) async -> ReplayRunProgress {
        var processed = 0
        var symbolsSeen: Set<String> = []
        var previousTimestamp: Date?

        for bar in bars {
            await clock.wait(previous: previousTimestamp, current: bar.timestamp)
            previousTimestamp = bar.timestamp
            await onBar(bar)
            processed += 1
            symbolsSeen.insert(bar.symbol)
        }

        return ReplayRunProgress(
            barsProcessed: processed,
            symbolsSeen: Array(symbolsSeen).sorted()
        )
    }
}
