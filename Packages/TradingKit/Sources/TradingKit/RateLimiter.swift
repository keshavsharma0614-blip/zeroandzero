import Foundation

public enum RateLimiterError: Error, Equatable, Sendable {
    case rateLimited(retryAfter: TimeInterval)
}

public struct TokenBucketRateLimiter: Sendable {
    public let capacity: Double
    public let refillRatePerSecond: Double

    private var availableTokens: Double
    private var lastRefillTime: TimeInterval

    public init(
        capacity: Double,
        refillRatePerSecond: Double,
        initialTime: TimeInterval,
        initialTokens: Double? = nil
    ) {
        precondition(capacity > 0, "Rate limiter capacity must be > 0.")
        precondition(refillRatePerSecond > 0, "Refill rate must be > 0.")

        self.capacity = capacity
        self.refillRatePerSecond = refillRatePerSecond
        self.lastRefillTime = initialTime
        self.availableTokens = min(max(initialTokens ?? capacity, 0), capacity)
    }

    public mutating func acquire(tokens: Double = 1, at time: TimeInterval) throws {
        precondition(tokens > 0, "Requested tokens must be > 0.")
        refill(at: time)

        guard availableTokens >= tokens else {
            let deficit = tokens - availableTokens
            let retryAfter = deficit / refillRatePerSecond
            throw RateLimiterError.rateLimited(retryAfter: retryAfter)
        }

        availableTokens -= tokens
    }

    public mutating func snapshot(at time: TimeInterval) -> Double {
        refill(at: time)
        return availableTokens
    }

    private mutating func refill(at time: TimeInterval) {
        guard time > lastRefillTime else {
            return
        }
        let elapsed = time - lastRefillTime
        let refilled = elapsed * refillRatePerSecond
        availableTokens = min(capacity, availableTokens + refilled)
        lastRefillTime = time
    }
}
