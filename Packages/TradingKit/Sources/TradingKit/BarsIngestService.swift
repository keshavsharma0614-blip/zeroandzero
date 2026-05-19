import Foundation

public actor BarsIngestService {
    private let barsProvider: any BarsProviding
    private let barsCache: BarsCache

    public init(
        barsProvider: any BarsProviding,
        barsCache: BarsCache
    ) {
        self.barsProvider = barsProvider
        self.barsCache = barsCache
    }

    public func ingest(_ request: ReplayIngestRequest) async throws -> ReplayIngestResult {
        let bars = try await barsProvider.fetchBars(
            symbols: request.symbols,
            timeframe: request.timeframe,
            start: request.start,
            end: request.end,
            limit: nil,
            feed: request.feed
        )
        let ingested = try await barsCache.upsertBars(bars)
        return ReplayIngestResult(
            symbols: Array(MarketDataSubscriptionSet.normalized(request.symbols)).sorted(),
            timeframe: request.timeframe,
            start: request.start,
            end: request.end,
            feed: request.feed,
            barsIngested: ingested
        )
    }
}
