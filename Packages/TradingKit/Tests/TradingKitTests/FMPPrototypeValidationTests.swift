import Foundation
import Testing
@testable import TradingKit

private struct TestKeyReader: KeyReading {
    let values: [String: String]

    func readKey(service: String, account: String) -> String? {
        values["\(service)|\(account)"]
    }
}

@Test("FMP keychain status provider reads the configured key without exposing it")
func fmpKeychainStatusProviderReadsConfiguredKey() {
    let provider = FMPKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: TestKeyReader(
                values: [
                    "fmp.api.key|algo-trading": "test-fmp-key"
                ]
            )
        )
    )

    #expect(provider.isConfigured() == true)
    #expect(provider.apiKey() == "test-fmp-key")

    let missing = FMPKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: TestKeyReader(values: [:])
        )
    )
    #expect(missing.isConfigured() == false)
    #expect(missing.apiKey() == nil)
}

@Test("FMP request building uses expected paths and query items")
func fmpRequestBuildingUsesExpectedPaths() throws {
    let baseURL = try #require(URL(string: "https://financialmodelingprep.com"))
    let requests = FMPPrototypePlan.defaultRequests(
        now: Date(timeIntervalSince1970: 1_763_140_800)
    )

    let transcriptURL = try #require(
        requests.first(where: { $0.category == .earningsTranscript })?.url(
            baseURL: baseURL,
            apiKey: "hidden"
        )
    )
    let transcriptComponents = try #require(URLComponents(url: transcriptURL, resolvingAgainstBaseURL: false))
    #expect(transcriptComponents.path == "/api/v3/earning_call_transcript/AAPL")
    #expect(transcriptComponents.queryItems?.contains(URLQueryItem(name: "year", value: "2020")) == true)
    #expect(transcriptComponents.queryItems?.contains(URLQueryItem(name: "quarter", value: "3")) == true)
    #expect(transcriptComponents.queryItems?.contains(URLQueryItem(name: "apikey", value: "hidden")) == true)

    let calendarURL = try #require(
        requests.first(where: { $0.category == .earningsCalendar })?.url(
            baseURL: baseURL,
            apiKey: "hidden"
        )
    )
    let calendarComponents = try #require(URLComponents(url: calendarURL, resolvingAgainstBaseURL: false))
    #expect(calendarComponents.path == "/api/v3/earning_calendar")
    #expect(calendarComponents.queryItems?.contains(where: { $0.name == "from" }) == true)
    #expect(calendarComponents.queryItems?.contains(where: { $0.name == "to" }) == true)
}

@Test("FMP classification maps mocked responses into bounded outcomes")
func fmpClassificationMapsResponsesPredictably() {
    let useful = classifyFMPPrototypeResponse(
        data: Data("[{\"symbol\":\"AAPL\"}]".utf8),
        httpStatus: 200
    )
    #expect(useful.outcome == .successWithUsefulData)
    #expect(useful.itemCount == 1)

    let empty = classifyFMPPrototypeResponse(
        data: Data("[]".utf8),
        httpStatus: 200
    )
    #expect(empty.outcome == .successButEmpty)
    #expect(empty.itemCount == 0)

    let entitlement = classifyFMPPrototypeResponse(
        data: Data("{\"Error Message\":\"Upgrade plan required for premium endpoint.\"}".utf8),
        httpStatus: 403
    )
    #expect(entitlement.outcome == .authOrEntitlementFailure)

    let invalid = classifyFMPPrototypeResponse(
        data: Data("{\"Error Message\":\"Invalid symbol.\"}".utf8),
        httpStatus: 404
    )
    #expect(invalid.outcome == .invalidRequestOrSymbolScope)

    let upstream = classifyFMPPrototypeResponse(
        data: Data(),
        httpStatus: 503
    )
    #expect(upstream.outcome == .transportFailure)

    let unexpected = classifyFMPPrototypeResponse(
        data: Data("42".utf8),
        httpStatus: 200
    )
    #expect(unexpected.outcome == .unexpectedResponseShape)
}

@Test("FMP summary aggregation yields a bounded viability conclusion and call shape")
func fmpSummaryAggregationBehavesPredictably() {
    let requests = [
        FMPPrototypeEndpointRequest(
            category: .analystEstimates,
            path: "/api/v3/analyst-estimates/AAPL",
            queryItems: [],
            scopeDescription: "AAPL"
        ),
        FMPPrototypeEndpointRequest(
            category: .priceTargetConsensus,
            path: "/api/v4/price-target-consensus",
            queryItems: [URLQueryItem(name: "symbol", value: "MSFT")],
            scopeDescription: "MSFT"
        ),
        FMPPrototypeEndpointRequest(
            category: .earningsCalendar,
            path: "/api/v3/earning_calendar",
            queryItems: [
                URLQueryItem(name: "from", value: "2025-11-01"),
                URLQueryItem(name: "to", value: "2025-11-14")
            ],
            scopeDescription: "2025-11-01 to 2025-11-14"
        )
    ]
    let results = [
        FMPPrototypeEndpointResult(
            category: .analystEstimates,
            scopeDescription: "AAPL",
            outcome: .successWithUsefulData,
            httpStatus: 200,
            itemCount: 4,
            summary: "Returned 4 item(s).",
            observedAt: Date(timeIntervalSince1970: 1_763_140_800)
        ),
        FMPPrototypeEndpointResult(
            category: .priceTargetConsensus,
            scopeDescription: "MSFT",
            outcome: .authOrEntitlementFailure,
            httpStatus: 403,
            itemCount: nil,
            summary: "Upgrade plan required.",
            observedAt: Date(timeIntervalSince1970: 1_763_140_801)
        ),
        FMPPrototypeEndpointResult(
            category: .earningsCalendar,
            scopeDescription: "2025-11-01 to 2025-11-14",
            outcome: .successWithUsefulData,
            httpStatus: 200,
            itemCount: 7,
            summary: "Returned 7 item(s).",
            observedAt: Date(timeIntervalSince1970: 1_763_140_802)
        )
    ]

    let summary = FMPPrototypeSummary.make(
        generatedAt: Date(timeIntervalSince1970: 1_763_140_900),
        requests: requests,
        results: results
    )

    #expect(summary.representativeScope.count == 3)
    #expect(summary.callBudgetShape.contains("3*N + 1 + T") == true)
    #expect(summary.viabilityConclusion.contains("partially viable") == true)
}

private struct StubHTTPDataSession: HTTPDataSessioning {
    let response: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await response(request)
    }
}

@Test("FMP prototype client reports missing key without touching the network")
func fmpPrototypeClientFailsCleanlyWhenKeyMissing() async {
    let client = FMPPrototypeClient(
        session: StubHTTPDataSession { _ in
            Issue.record("Session should not be called when the FMP key is missing.")
            throw URLError(.badURL)
        },
        keyStatusProvider: FMPKeychainStatusProvider(
            keychainProvider: KeychainCredentialsProvider(
                keyReader: TestKeyReader(values: [:])
            )
        )
    )

    do {
        _ = try await client.runDefaultValidation()
        Issue.record("Expected missing FMP key error.")
    } catch let error as FMPPrototypeError {
        #expect(error == .missingAPIKey)
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}
