import Foundation

public protocol AlpacaRESTServing: Sendable {
    func fetchAccount() async throws -> Account
    func fetchPositions() async throws -> [Position]
    func fetchOpenOrders() async throws -> [Order]
    func fetchAsset(symbol: String) async throws -> Asset
    func fetchOptionContract(symbolOrID: String) async throws -> OptionContract
    func placeOrder(request: NewOrderRequest) async throws -> Order
    func replaceOrder(orderId: String, request: ReplaceOrderRequest) async throws -> Order
    func cancelOrder(orderId: String) async throws
}

public actor AlpacaRESTClient {
    private let environment: Environment
    private let keychainProvider: KeychainCredentialsProvider
    private let session: URLSession
    private let now: @Sendable () -> TimeInterval
    private var rateLimiter: TokenBucketRateLimiter
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

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

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    public func fetchAccount() async throws -> Account {
        let (data, response) = try await sendRequest(path: "/v2/account", method: "GET")
        return try decode(Account.self, from: data, response: response)
    }

    public func fetchPositions() async throws -> [Position] {
        let (data, response) = try await sendRequest(path: "/v2/positions", method: "GET")
        return try decode([Position].self, from: data, response: response)
    }

    public func fetchOpenOrders() async throws -> [Order] {
        let (data, response) = try await sendRequest(
            path: "/v2/orders",
            method: "GET",
            queryItems: [URLQueryItem(name: "status", value: "open")]
        )
        return try decode([Order].self, from: data, response: response)
    }

    public func fetchAsset(symbol: String) async throws -> Asset {
        let normalized = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let (data, response) = try await sendRequest(
            path: "/v2/assets/\(normalized)",
            method: "GET"
        )
        return try decode(Asset.self, from: data, response: response)
    }

    public func fetchOptionContract(symbolOrID: String) async throws -> OptionContract {
        let normalized = symbolOrID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let (data, response) = try await sendRequest(
            path: "/v2/options/contracts/\(normalized)",
            method: "GET"
        )
        return try decode(OptionContract.self, from: data, response: response)
    }

    public func placeOrder(request: NewOrderRequest) async throws -> Order {
        let body = try encoder.encode(request)
        let (data, response) = try await sendRequest(
            path: "/v2/orders",
            method: "POST",
            body: body
        )
        return try decode(Order.self, from: data, response: response)
    }

    public func replaceOrder(orderId: String, request: ReplaceOrderRequest) async throws -> Order {
        let body = try encoder.encode(request)
        do {
            let (data, response) = try await sendRequest(
                path: "/v2/orders/\(orderId)",
                method: "PATCH",
                body: body
            )
            return try decode(Order.self, from: data, response: response)
        } catch let error as AlpacaAPIError {
            if case .requestFailed(let httpStatus, let alpacaMessage, let requestID) = error,
               (400...499).contains(httpStatus) {
                throw AlpacaAPIError.replaceRejected(
                    httpStatus: httpStatus,
                    alpacaMessage: alpacaMessage,
                    requestID: requestID
                )
            }
            throw error
        }
    }

    public func cancelOrder(orderId: String) async throws {
        _ = try await sendRequest(path: "/v2/orders/\(orderId)", method: "DELETE")
    }

    private func sendRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
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

        var components = URLComponents(url: environment.tradingRESTBaseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw AlpacaAPIError.transportFailure(message: "Unable to construct request URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue(credentials.publicKey, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credentials.secretKey, forHTTPHeaderField: "APCA-API-SECRET-KEY")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw AlpacaAPIError.transportFailure(message: error.localizedDescription)
        }

        guard let httpResponse = result.1 as? HTTPURLResponse else {
            throw AlpacaAPIError.transportFailure(message: "Unexpected response type.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapHTTPError(data: result.0, response: httpResponse)
        }

        return (result.0, httpResponse)
    }

    private func mapHTTPError(data: Data, response: HTTPURLResponse) -> AlpacaAPIError {
        let message = parseAlpacaMessage(data: data)
        let requestID = response.value(forHTTPHeaderField: "apca-request-id")
            ?? response.value(forHTTPHeaderField: "x-request-id")

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

    private func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        response: HTTPURLResponse
    ) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AlpacaAPIError.decodingFailed(
                httpStatus: response.statusCode,
                alpacaMessage: parseAlpacaMessage(data: data),
                requestID: response.value(forHTTPHeaderField: "apca-request-id")
            )
        }
    }

    private func parseAlpacaMessage(data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }
        return try? decoder.decode(AlpacaErrorPayload.self, from: data).message
    }
}

extension AlpacaRESTClient: AlpacaRESTServing {}

private struct AlpacaErrorPayload: Decodable {
    let message: String?
}
