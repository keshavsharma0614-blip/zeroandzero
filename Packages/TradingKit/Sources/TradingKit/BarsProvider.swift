import Foundation

public protocol BarsProviding: Sendable {
    func fetchBars(
        symbols: [String],
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        limit: Int?,
        feed: ReplayFeed
    ) async throws -> [Bar]
}

public actor AlpacaBarsProvider: BarsProviding {
    private let environment: Environment
    private let keychainProvider: KeychainCredentialsProvider
    private let session: URLSession
    private let now: @Sendable () -> TimeInterval
    private var rateLimiter: TokenBucketRateLimiter
    private let decoder: JSONDecoder

    public init(
        environment: Environment = .paper,
        keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider(),
        session: URLSession = .shared,
        rateLimiter: TokenBucketRateLimiter? = nil,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.environment = environment
        self.keychainProvider = keychainProvider
        self.session = session
        self.now = now
        self.rateLimiter = rateLimiter ?? TokenBucketRateLimiter(
            capacity: 200,
            refillRatePerSecond: 200.0 / 60.0,
            initialTime: now()
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    public func fetchBars(
        symbols: [String],
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        limit: Int? = nil,
        feed: ReplayFeed = .iex
    ) async throws -> [Bar] {
        let normalizedSymbols = Array(MarketDataSubscriptionSet.normalized(symbols)).sorted()
        guard !normalizedSymbols.isEmpty else {
            throw ReplayError.invalidSymbols
        }
        guard start < end else {
            throw ReplayError.invalidDateRange
        }

        var allBars: [Bar] = []
        for symbol in normalizedSymbols {
            allBars.append(
                contentsOf: try await fetchBarsForSymbol(
                    symbol: symbol,
                    timeframe: timeframe,
                    start: start,
                    end: end,
                    limit: limit,
                    feed: feed
                )
            )
        }

        return allBars.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.symbol < rhs.symbol
            }
            return lhs.timestamp < rhs.timestamp
        }
    }

    private func fetchBarsForSymbol(
        symbol: String,
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        limit: Int?,
        feed: ReplayFeed
    ) async throws -> [Bar] {
        var result: [Bar] = []
        var pageToken: String?

        while true {
            let response = try await requestBarsPage(
                symbol: symbol,
                timeframe: timeframe,
                start: start,
                end: end,
                limit: limit,
                feed: feed,
                pageToken: pageToken
            )
            let bars = response.bars[symbol] ?? []
            result.append(
                contentsOf: bars.compactMap { entry in
                    guard let date = Self.parseISO8601(entry.t) else {
                        return nil
                    }
                    return Bar(
                        symbol: symbol,
                        timeframe: timeframe,
                        timestamp: date,
                        open: entry.o,
                        high: entry.h,
                        low: entry.l,
                        close: entry.c,
                        volume: entry.v
                    )
                }
            )

            pageToken = response.nextPageToken
            if pageToken == nil {
                break
            }
        }

        return result
    }

    private func requestBarsPage(
        symbol: String,
        timeframe: BarTimeframe,
        start: Date,
        end: Date,
        limit: Int?,
        feed: ReplayFeed,
        pageToken: String?
    ) async throws -> AlpacaBarsResponse {
        do {
            try rateLimiter.acquire(at: now())
        } catch RateLimiterError.rateLimited(let retryAfter) {
            throw AlpacaAPIError.localRateLimited(retryAfter: retryAfter)
        } catch {
            throw AlpacaAPIError.transportFailure(message: "Rate limiter failed.")
        }

        guard let credentials = keychainProvider.credentials(for: environment) else {
            throw AlpacaAPIError.missingCredentials(environment: environment)
        }

        var components = URLComponents(
            url: environment.marketDataRESTBaseURL,
            resolvingAgainstBaseURL: false
        )
        components?.path = "/v2/stocks/bars"
        var query: [URLQueryItem] = [
            URLQueryItem(name: "symbols", value: symbol),
            URLQueryItem(name: "timeframe", value: timeframe.rawValue),
            URLQueryItem(name: "start", value: Self.iso8601(start)),
            URLQueryItem(name: "end", value: Self.iso8601(end)),
            URLQueryItem(name: "feed", value: feed.alpacaHistoricalBarsValue),
            URLQueryItem(name: "sort", value: "asc")
        ]
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let pageToken, !pageToken.isEmpty {
            query.append(URLQueryItem(name: "page_token", value: pageToken))
        }
        components?.queryItems = query

        guard let url = components?.url else {
            throw AlpacaAPIError.transportFailure(message: "Unable to construct historical bars URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(credentials.publicKey, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credentials.secretKey, forHTTPHeaderField: "APCA-API-SECRET-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AlpacaAPIError.transportFailure(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlpacaAPIError.transportFailure(message: "Unexpected response type.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapHTTPError(data: data, response: httpResponse)
        }

        do {
            return try decoder.decode(AlpacaBarsResponse.self, from: data)
        } catch {
            throw AlpacaAPIError.decodingFailed(
                httpStatus: httpResponse.statusCode,
                alpacaMessage: nil,
                requestID: httpResponse.value(forHTTPHeaderField: "x-request-id")
            )
        }
    }

    private func mapHTTPError(data: Data, response: HTTPURLResponse) -> AlpacaAPIError {
        let requestID = response.value(forHTTPHeaderField: "x-request-id")
            ?? response.value(forHTTPHeaderField: "apca-request-id")
        let message = (try? decoder.decode(AlpacaBarsErrorPayload.self, from: data))?.message
        if response.statusCode == 429 {
            let retryAfter = TimeInterval(response.value(forHTTPHeaderField: "Retry-After") ?? "")
            return .rateLimited(
                httpStatus: response.statusCode,
                alpacaMessage: message,
                requestID: requestID,
                retryAfter: retryAfter
            )
        }
        return .requestFailed(
            httpStatus: response.statusCode,
            alpacaMessage: message,
            requestID: requestID
        )
    }

    private static func iso8601(_ date: Date) -> String {
        DateCodec.formatISO8601(date)
    }

    private static func parseISO8601(_ raw: String) -> Date? {
        DateCodec.parseISO8601(raw)
    }
}

private struct AlpacaBarsResponse: Decodable, Sendable {
    let bars: [String: [AlpacaBarEntry]]
    let nextPageToken: String?
}

private struct AlpacaBarEntry: Decodable, Sendable {
    let t: String
    let o: Double
    let h: Double
    let l: Double
    let c: Double
    let v: Double
}

private struct AlpacaBarsErrorPayload: Decodable, Sendable {
    let message: String?
}
