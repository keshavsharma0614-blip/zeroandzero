import Foundation

public protocol HTTPDataSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataSessioning {}

public struct FMPKeychainStatusProvider: Sendable {
    public static let service = "fmp.api.key"
    public static let account = "algo-trading"

    private let keychainProvider: KeychainCredentialsProvider

    public init(keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider()) {
        self.keychainProvider = keychainProvider
    }

    public func apiKey() -> String? {
        keychainProvider.readKey(service: Self.service, account: Self.account)
    }

    public func isConfigured() -> Bool {
        guard let apiKey = apiKey() else {
            return false
        }
        return apiKey.isEmpty == false
    }
}

public enum FMPPrototypeEndpointCategory: String, Codable, CaseIterable, Sendable, Equatable {
    case analystEstimates = "analyst_estimates"
    case priceTargetConsensus = "price_target_consensus"
    case earningsTranscript = "earnings_transcript"
    case earningsCalendar = "earnings_calendar"
    case gradesConsensus = "grades_consensus"

    public var displayTitle: String {
        switch self {
        case .analystEstimates:
            return "Analyst Estimates"
        case .priceTargetConsensus:
            return "Price Target Consensus"
        case .earningsTranscript:
            return "Earnings Transcript"
        case .earningsCalendar:
            return "Earnings Calendar"
        case .gradesConsensus:
            return "Grades Consensus"
        }
    }
}

public enum FMPPrototypeOutcome: String, Codable, Sendable, Equatable {
    case successWithUsefulData = "success_with_useful_data"
    case successButEmpty = "success_but_empty"
    case authOrEntitlementFailure = "auth_or_entitlement_failure"
    case transportFailure = "transport_failure"
    case invalidRequestOrSymbolScope = "invalid_request_or_symbol_scope"
    case unexpectedResponseShape = "unexpected_response_shape"
}

public struct FMPPrototypeEndpointRequest: Sendable, Equatable {
    public let category: FMPPrototypeEndpointCategory
    public let path: String
    public let queryItems: [URLQueryItem]
    public let scopeDescription: String

    public init(
        category: FMPPrototypeEndpointCategory,
        path: String,
        queryItems: [URLQueryItem],
        scopeDescription: String
    ) {
        self.category = category
        self.path = path
        self.queryItems = queryItems
        self.scopeDescription = scopeDescription
    }

    public func url(baseURL: URL, apiKey: String) -> URL? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems + [
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        return components?.url
    }
}

public enum FMPPrototypePlan {
    public static func defaultRequests(now: Date) -> [FMPPrototypeEndpointRequest] {
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let fromDate = now
        let toDate = calendar.date(byAdding: .day, value: 14, to: now) ?? now

        return [
            FMPPrototypeEndpointRequest(
                category: .analystEstimates,
                path: "/api/v3/analyst-estimates/AAPL",
                queryItems: [],
                scopeDescription: "AAPL"
            ),
            FMPPrototypeEndpointRequest(
                category: .priceTargetConsensus,
                path: "/api/v4/price-target-consensus",
                queryItems: [
                    URLQueryItem(name: "symbol", value: "MSFT")
                ],
                scopeDescription: "MSFT"
            ),
            FMPPrototypeEndpointRequest(
                category: .earningsTranscript,
                path: "/api/v3/earning_call_transcript/AAPL",
                queryItems: [
                    URLQueryItem(name: "year", value: "2020"),
                    URLQueryItem(name: "quarter", value: "3")
                ],
                scopeDescription: "AAPL Q3 2020"
            ),
            FMPPrototypeEndpointRequest(
                category: .earningsCalendar,
                path: "/api/v3/earning_calendar",
                queryItems: [
                    URLQueryItem(name: "from", value: formatter.string(from: fromDate)),
                    URLQueryItem(name: "to", value: formatter.string(from: toDate))
                ],
                scopeDescription: "\(formatter.string(from: fromDate)) to \(formatter.string(from: toDate))"
            ),
            FMPPrototypeEndpointRequest(
                category: .gradesConsensus,
                path: "/api/v3/grades-consensus/NVDA",
                queryItems: [],
                scopeDescription: "NVDA"
            )
        ]
    }
}

public struct FMPPrototypeEndpointResult: Codable, Sendable, Equatable, Identifiable {
    public var id: String { category.rawValue }

    public let category: FMPPrototypeEndpointCategory
    public let scopeDescription: String
    public let outcome: FMPPrototypeOutcome
    public let httpStatus: Int?
    public let itemCount: Int?
    public let summary: String
    public let observedAt: Date

    public init(
        category: FMPPrototypeEndpointCategory,
        scopeDescription: String,
        outcome: FMPPrototypeOutcome,
        httpStatus: Int?,
        itemCount: Int?,
        summary: String,
        observedAt: Date
    ) {
        self.category = category
        self.scopeDescription = scopeDescription
        self.outcome = outcome
        self.httpStatus = httpStatus
        self.itemCount = itemCount
        self.summary = summary
        self.observedAt = observedAt
    }
}

public struct FMPPrototypeSummary: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let representativeScope: [String]
    public let results: [FMPPrototypeEndpointResult]
    public let viabilityConclusion: String
    public let callBudgetShape: String

    public init(
        generatedAt: Date,
        representativeScope: [String],
        results: [FMPPrototypeEndpointResult],
        viabilityConclusion: String,
        callBudgetShape: String
    ) {
        self.generatedAt = generatedAt
        self.representativeScope = representativeScope
        self.results = results
        self.viabilityConclusion = viabilityConclusion
        self.callBudgetShape = callBudgetShape
    }

    public static func make(
        generatedAt: Date,
        requests: [FMPPrototypeEndpointRequest],
        results: [FMPPrototypeEndpointResult]
    ) -> FMPPrototypeSummary {
        FMPPrototypeSummary(
            generatedAt: generatedAt,
            representativeScope: requests.map { "\($0.category.displayTitle): \($0.scopeDescription)" },
            results: results,
            viabilityConclusion: viabilityConclusion(for: results),
            callBudgetShape: roughCallBudgetShape()
        )
    }

    public static func viabilityConclusion(for results: [FMPPrototypeEndpointResult]) -> String {
        let usefulCount = results.filter { $0.outcome == .successWithUsefulData }.count
        let blockedCount = results.filter { $0.outcome == .authOrEntitlementFailure }.count

        if usefulCount >= 4 && blockedCount == 0 {
            return "Current FMP access appears viable for a first symbol-scoped Tier 1 prototype."
        }

        if usefulCount >= 2 && blockedCount <= 2 {
            return "Current FMP access appears partially viable for a first symbol-scoped Tier 1 prototype, but some targeted categories likely need paid access or further validation."
        }

        return "Current FMP access does not yet look sufficient for the targeted Tier 1 prototype without plan changes or a different source."
    }

    public static func roughCallBudgetShape() -> String {
        "A bounded symbol-scoped prototype is roughly 3*N + 1 + T calls per refresh cycle, where N is the holdings/watchlist symbol count for estimates, targets, and grades, and T is the smaller subset needing transcript lookups."
    }
}

public enum FMPPrototypeError: Error, Sendable, Equatable {
    case missingAPIKey
    case invalidRequest
}

private enum FMPPayloadInspection: Equatable {
    case array(count: Int)
    case object(count: Int)
    case message(String)
    case empty
    case invalidJSON
}

public func classifyFMPPrototypeResponse(
    data: Data,
    httpStatus: Int
) -> (outcome: FMPPrototypeOutcome, itemCount: Int?, summary: String) {
    let inspection = inspectFMPPayload(data: data)
    let vendorMessage: String? = {
        if case .message(let message) = inspection {
            return message
        }
        return nil
    }()

    if let vendorMessage,
       let outcome = classifyFMPMessage(vendorMessage) {
        return (outcome, nil, boundedSummary(vendorMessage))
    }

    switch httpStatus {
    case 200...299:
        switch inspection {
        case .array(let count):
            if count > 0 {
                return (.successWithUsefulData, count, "Returned \(count) item(s).")
            }
            return (.successButEmpty, 0, "Request succeeded but returned no rows.")
        case .object(let count):
            if count > 0 {
                return (.successWithUsefulData, 1, "Returned a non-empty object payload.")
            }
            return (.successButEmpty, 0, "Request succeeded but returned an empty object payload.")
        case .empty:
            return (.successButEmpty, 0, "Request succeeded with an empty response body.")
        case .message(let message):
            return (.unexpectedResponseShape, nil, boundedSummary(message))
        case .invalidJSON:
            return (.unexpectedResponseShape, nil, "Request succeeded but the response shape was not recognized.")
        }
    case 400, 404, 422:
        return (.invalidRequestOrSymbolScope, nil, boundedSummary(vendorMessage ?? "The request scope or symbol was rejected."))
    case 401, 402, 403, 429:
        return (.authOrEntitlementFailure, nil, boundedSummary(vendorMessage ?? "The request appears blocked by authentication, entitlement, or plan limits."))
    case 500...599:
        return (.transportFailure, nil, boundedSummary(vendorMessage ?? "The upstream service failed while handling the request."))
    default:
        return (.transportFailure, nil, boundedSummary(vendorMessage ?? "The request failed with an unexpected HTTP status."))
    }
}

public actor FMPPrototypeClient {
    private let session: any HTTPDataSessioning
    private let keyStatusProvider: FMPKeychainStatusProvider
    private let baseURL: URL
    private let now: @Sendable () -> Date

    public init(
        session: any HTTPDataSessioning = URLSession.shared,
        keyStatusProvider: FMPKeychainStatusProvider = FMPKeychainStatusProvider(),
        baseURL: URL = URL(string: "https://financialmodelingprep.com")!,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        self.keyStatusProvider = keyStatusProvider
        self.baseURL = baseURL
        self.now = now
    }

    public func runDefaultValidation() async throws -> FMPPrototypeSummary {
        try await runValidation(requests: FMPPrototypePlan.defaultRequests(now: now()))
    }

    public func runValidation(
        requests: [FMPPrototypeEndpointRequest]
    ) async throws -> FMPPrototypeSummary {
        guard let apiKey = keyStatusProvider.apiKey(), apiKey.isEmpty == false else {
            throw FMPPrototypeError.missingAPIKey
        }

        let generatedAt = now()
        var results: [FMPPrototypeEndpointResult] = []
        results.reserveCapacity(requests.count)

        for request in requests {
            results.append(await runProbe(request, apiKey: apiKey))
        }

        return FMPPrototypeSummary.make(
            generatedAt: generatedAt,
            requests: requests,
            results: results
        )
    }

    private func runProbe(
        _ request: FMPPrototypeEndpointRequest,
        apiKey: String
    ) async -> FMPPrototypeEndpointResult {
        let observedAt = now()

        guard let url = request.url(baseURL: baseURL, apiKey: apiKey) else {
            return FMPPrototypeEndpointResult(
                category: request.category,
                scopeDescription: request.scopeDescription,
                outcome: .invalidRequestOrSymbolScope,
                httpStatus: nil,
                itemCount: nil,
                summary: "The probe could not construct a valid request URL for the selected scope.",
                observedAt: observedAt
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("AlgoTradingMac FMP prototype validation", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                return FMPPrototypeEndpointResult(
                    category: request.category,
                    scopeDescription: request.scopeDescription,
                    outcome: .transportFailure,
                    httpStatus: nil,
                    itemCount: nil,
                    summary: "The probe received a non-HTTP response.",
                    observedAt: observedAt
                )
            }

            let classified = classifyFMPPrototypeResponse(
                data: data,
                httpStatus: httpResponse.statusCode
            )
            return FMPPrototypeEndpointResult(
                category: request.category,
                scopeDescription: request.scopeDescription,
                outcome: classified.outcome,
                httpStatus: httpResponse.statusCode,
                itemCount: classified.itemCount,
                summary: classified.summary,
                observedAt: observedAt
            )
        } catch {
            return FMPPrototypeEndpointResult(
                category: request.category,
                scopeDescription: request.scopeDescription,
                outcome: .transportFailure,
                httpStatus: nil,
                itemCount: nil,
                summary: boundedSummary(error.localizedDescription),
                observedAt: observedAt
            )
        }
    }
}

private func inspectFMPPayload(data: Data) -> FMPPayloadInspection {
    guard data.isEmpty == false else {
        return .empty
    }

    do {
        let object = try JSONSerialization.jsonObject(with: data)
        if let array = object as? [Any] {
            return .array(count: array.count)
        }
        if let dictionary = object as? [String: Any] {
            if let message = ["Error Message", "error", "Error", "message"]
                .compactMap({ dictionary[$0] as? String })
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               message.isEmpty == false {
                return .message(message)
            }
            return .object(count: dictionary.count)
        }
        return .invalidJSON
    } catch {
        return .invalidJSON
    }
}

private func classifyFMPMessage(_ message: String) -> FMPPrototypeOutcome? {
    let normalized = message.lowercased()

    if normalized.contains("premium")
        || normalized.contains("upgrade")
        || normalized.contains("subscription")
        || normalized.contains("forbidden")
        || normalized.contains("unauthorized")
        || normalized.contains("api key")
        || normalized.contains("limit reached")
        || normalized.contains("too many requests") {
        return .authOrEntitlementFailure
    }

    if normalized.contains("invalid")
        || normalized.contains("not found")
        || normalized.contains("missing")
        || normalized.contains("quarter")
        || normalized.contains("year")
        || normalized.contains("symbol")
        || normalized.contains("date") {
        return .invalidRequestOrSymbolScope
    }

    return nil
}

private func boundedSummary(_ value: String) -> String {
    let collapsed = value
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return String(collapsed.prefix(180))
}
