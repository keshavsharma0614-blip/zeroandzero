import Foundation
import Testing
@testable import TradingKit

@Test("System key reader blocks SwiftPM test helpers from touching real Keychain secrets")
func systemKeyReaderBlocksSwiftPMTestHelpers() {
    #expect(SystemKeyReader.shouldAllowKeychainRead(
        lookupName: "anthropic_api_key",
        account: "algo-trading",
        processName: "swiftpm-testing-helper",
        arguments: ["--testing-library"],
        environment: [:]
    ) == false)
    #expect(SystemKeyReader.shouldAllowKeychainRead(
        lookupName: "open_api_key",
        account: "algo-trading",
        processName: "TradingKitPackageTests.xctest",
        arguments: ["/tmp/TradingKitPackageTests.xctest"],
        environment: [:]
    ) == false)
    #expect(SystemKeyReader.shouldAllowKeychainRead(
        lookupName: "openai_api_key",
        account: "algo-trading",
        processName: "AlgoTradingMac",
        arguments: ["AlgoTradingMac"],
        environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
    ) == false)
    #expect(SystemKeyReader.shouldAllowKeychainRead(
        lookupName: "anthropic_api_key",
        account: "algo-trading",
        processName: "swiftpm-testing-helper",
        arguments: ["--testing-library"],
        environment: ["ALGO_TRADING_ALLOW_TEST_KEYCHAIN_READ": "1"]
    ) == true)
    #expect(SystemKeyReader.shouldAllowKeychainRead(
        lookupName: "anthropic_api_key",
        account: "algo-trading",
        processName: "AlgoTradingMac",
        arguments: ["AlgoTradingMac"],
        environment: [:]
    ) == true)
    #expect(SystemKeyReader.shouldAllowKeychainRead(
        lookupName: "alpaca.api.key",
        account: "algo-trading/paper",
        processName: "swiftpm-testing-helper",
        arguments: ["--testing-library"],
        environment: [:]
    ) == true)
}

@Test("OpenAI keychain credential resolver reads canonical service and label fallback")
func openAIKeychainCredentialResolverReadsCanonicalAndLabelFallback() {
    struct FakeKeyReader: KeyReading {
        let values: [String: String]

        func readKey(service: String, account: String) -> String? {
            values["\(service)|\(account)"]
        }
    }

    let serviceBacked = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [
                "open_api_key|algo-trading": "service-secret"
            ])
        ),
        labelReader: { _, _ in nil },
        cache: nil
    )
    let serviceResolution = serviceBacked.credentialResolution()
    #expect(serviceResolution.status == .ready)
    #expect(serviceResolution.source == .canonicalServiceAccount)
    #expect(serviceResolution.apiKey == "service-secret")

    let labelBacked = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [:])
        ),
        labelReader: { label, account in
            guard label == "open_api_key", account == "algo-trading" else {
                return nil
            }
            return "label-secret"
        },
        cache: nil
    )
    let labelResolution = labelBacked.credentialResolution()
    #expect(labelResolution.status == .ready)
    #expect(labelResolution.source == .canonicalLabelAccount)
    #expect(labelResolution.apiKey == "label-secret")
}

@Test("OpenAI keychain credential resolver distinguishes empty, missing, and legacy key states")
func openAIKeychainCredentialResolverDistinguishesAvailabilityStates() {
    struct FakeKeyReader: KeyReading {
        let values: [String: String]

        func readKey(service: String, account: String) -> String? {
            values["\(service)|\(account)"]
        }
    }

    let emptyProvider = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [
                "open_api_key|algo-trading": "   "
            ])
        ),
        labelReader: { _, _ in nil },
        cache: nil
    )
    let emptyResolution = emptyProvider.credentialResolution()
    #expect(emptyResolution.status == .emptyKey)
    #expect(emptyResolution.synthesisIssueSummary == "openai_api_key_empty")

    let legacyProvider = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [
                "openai_api_key|algo-trading": "legacy-secret"
            ])
        ),
        labelReader: { _, _ in nil },
        cache: nil
    )
    let legacyResolution = legacyProvider.credentialResolution()
    #expect(legacyResolution.status == .ready)
    #expect(legacyResolution.source == .legacyServiceAccount)
    #expect(legacyResolution.apiKey == "legacy-secret")

    let missingProvider = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [:])
        ),
        labelReader: { _, _ in nil },
        cache: nil
    )
    let missingResolution = missingProvider.credentialResolution()
    #expect(missingResolution.status == .missingKey)
    #expect(missingResolution.synthesisIssueSummary == "openai_api_key_missing")
}

@Test("OpenAI keychain credential resolver reuses a cached ready resolution within one process session")
func openAIKeychainCredentialResolverCachesReadyResolution() {
    final class CountingKeyReader: KeyReading, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var readCount = 0

        func readKey(service: String, account: String) -> String? {
            lock.lock()
            readCount += 1
            lock.unlock()
            guard service == "open_api_key", account == "algo-trading" else {
                return nil
            }
            return "cached-secret"
        }
    }

    final class LabelCounter: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var readCount = 0

        func read(label: String, account: String) -> String? {
            lock.lock()
            readCount += 1
            lock.unlock()
            return nil
        }
    }

    let keyReader = CountingKeyReader()
    let labelCounter = LabelCounter()
    let cache = OpenAIKeychainCredentialResolutionCache()
    let provider = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(keyReader: keyReader),
        labelReader: labelCounter.read(label:account:),
        cache: cache
    )

    let first = provider.credentialResolution()
    let second = provider.credentialResolution()

    #expect(first.status == .ready)
    #expect(second.status == .ready)
    #expect(first.apiKey == "cached-secret")
    #expect(second.apiKey == "cached-secret")
    #expect(keyReader.readCount == 1)
    #expect(labelCounter.readCount == 0)
}

@Test("OpenAI provider validation and error summaries stay bounded and specific")
func openAIProviderValidationAndErrorSummariesRemainSpecific() async {
    let readyProvider = StubRuntimeOpenAIKeyProvider(
        resolution: OpenAICredentialResolution(
            status: .ready,
            apiKey: "test-openai-key",
            source: .inferred,
            account: OpenAIKeychainCredentialResolver.account,
            summary: "Test provider resolved a key."
        )
    )
    let readyEngine = Engine(openAIKeyStatusProvider: readyProvider)
    let readyValidation = await readyEngine.validatePMRuntimeCandidate(
        runtimeIdentifier: "gpt-5",
        reasoningMode: .standard,
        checkedBy: "human owner"
    )
    #expect(readyValidation.status == .valid)
    #expect(readyValidation.summary.contains("attempt live OpenAI execution") == true)

    let missingProvider = StubRuntimeOpenAIKeyProvider(
        resolution: OpenAICredentialResolution(
            status: .missingKey,
            account: OpenAIKeychainCredentialResolver.account,
            summary: "No OpenAI API key was found in Keychain for service open_api_key account algo-trading."
        )
    )
    let missingEngine = Engine(openAIKeyStatusProvider: missingProvider)
    let missingValidation = await missingEngine.validateRecentNewsAnalystRuntimeCandidate(
        runtimeIdentifier: "gpt-5-mini",
        reasoningMode: .standard,
        checkedBy: "human owner"
    )
    #expect(missingValidation.status == .invalid)
    #expect(missingValidation.category == .unavailable)
    #expect(missingValidation.summary.contains("No OpenAI API key was found in Keychain") == true)

    #expect(openAITransportSummary() == "openai_network_error")
    #expect(openAITransportSummary(for: URLError(.timedOut)) == "openai_network_error=timed_out")
    #expect(openAITransportSummary(for: URLError(.notConnectedToInternet)) == "openai_network_error=not_connected_to_internet")
    #expect(openAIHTTPStatusSummary(401) == "openai_auth_failure_status=401")
    #expect(openAIHTTPStatusSummary(422) == "openai_invalid_runtime_status=422")
    #expect(openAIHTTPStatusSummary(429) == "openai_rate_limit_or_quota_status=429")
    #expect(openAIHTTPStatusSummary(503) == "openai_provider_failure_status=503")
    let invalidSchemaSummary = openAIHTTPStatusSummary(
        400,
        detail: "code=invalid_json_schema type=invalid_request_error param=text.format.schema message=Invalid schema for response_format 'pm_conversation_reply': In context=('properties','resolution','properties'), ..."
    )
    #expect(invalidSchemaSummary.contains("openai_invalid_schema_status=400") == true)
    #expect(invalidSchemaSummary.contains("code=invalid_json_schema") == true)
    #expect(invalidSchemaSummary.contains("param=text.format.schema") == true)
}

private struct StubRuntimeOpenAIKeyProvider: OpenAIKeyStatusProviding {
    let resolution: OpenAICredentialResolution

    func apiKey() -> String? {
        resolution.apiKey
    }

    func isConfigured() -> Bool {
        resolution.isReady
    }

    func credentialResolution() -> OpenAICredentialResolution {
        resolution
    }
}
