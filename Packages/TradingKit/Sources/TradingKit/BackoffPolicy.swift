import Foundation

public struct ExponentialBackoffPolicy: Sendable {
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let jitterFactor: Double

    public init(
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        jitterFactor: Double = 0.25
    ) {
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.jitterFactor = max(0, min(jitterFactor, 1))
    }

    public func delay(
        attempt: Int,
        randomUnit: Double
    ) -> TimeInterval {
        let safeAttempt = max(0, attempt)
        let multiplier = pow(2, Double(safeAttempt))
        let unclamped = baseDelay * multiplier
        let clamped = min(unclamped, maxDelay)

        let boundedRandom = min(max(randomUnit, 0), 1)
        let centered = (boundedRandom * 2) - 1
        let jitter = clamped * jitterFactor * centered
        return max(0, clamped + jitter)
    }
}
