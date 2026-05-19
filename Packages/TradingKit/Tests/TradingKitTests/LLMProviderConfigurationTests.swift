import Foundation
import Testing
@testable import TradingKit

@Test("LLM provider settings seed OpenAI current, OpenAI legacy, and Anthropic profiles")
func llmProviderSettingsSeedProviderProfiles() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let settings = LLMProviderSettings.default(now: now)

    let openAIProfiles = settings.profiles(for: .openAI)
    let openAIMainSettingsProfiles = settings.mainSettingsProfiles(for: .openAI)
    let anthropicProfiles = settings.profiles(for: .anthropic)

    #expect(openAIProfiles.map(\.profileId).contains(LLMCredentialProfile.openAIDefaultProfileID))
    #expect(openAIProfiles.map(\.profileId).contains(LLMCredentialProfile.openAILegacyProfileID))
    #expect(openAIMainSettingsProfiles.map(\.profileId) == [LLMCredentialProfile.openAIDefaultProfileID])
    #expect(settings.profile(id: LLMCredentialProfile.openAILegacyProfileID)?.settingsVisibility == .hiddenMigrationAlias)
    #expect(anthropicProfiles.map(\.profileId) == [LLMCredentialProfile.anthropicDefaultProfileID])
    #expect(settings.profile(id: LLMCredentialProfile.openAIDefaultProfileID)?.keychainService == "open_api_key")
    #expect(settings.profile(id: LLMCredentialProfile.openAIDefaultProfileID)?.keychainAccount == "algo-trading")
    #expect(settings.profile(id: LLMCredentialProfile.openAIDefaultProfileID)?.legacyAliases.contains {
        $0.serviceOrLabel == "openai_api_key" && $0.account == "algo-trading"
    } == true)
    #expect(settings.profile(id: LLMCredentialProfile.anthropicDefaultProfileID)?.keychainService == "anthropic_api_key")
}

@Test("LLM provider settings store persists labels only and not secret values")
func llmProviderSettingsStorePersistsLabelsOnly() throws {
    let root = makeLLMProviderTempDirectory(name: "settings-store")
    let fileURL = root.appendingPathComponent("llm_provider_settings.json")
    let now = Date(timeIntervalSince1970: 1_800_000_100)
    let store = LLMProviderSettingsStore(fileURL: fileURL, now: { now })

    var profile = LLMCredentialProfile.defaultAnthropic(now: now)
    profile.keychainService = "owner.anthropic.service"
    profile.keychainAccount = "owner-account"
    profile.updatedBy = "human owner"
    profile.updateSource = .userEdited
    let saved = try store.upsertProfile(profile)
    #expect(saved.profile(id: profile.profileId)?.keychainService == "owner.anthropic.service")

    let raw = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(raw.contains("owner.anthropic.service"))
    #expect(raw.contains("owner-account"))
    #expect(raw.contains("test-secret") == false)

    let reloaded = try LLMProviderSettingsStore(fileURL: fileURL).loadOrDefault()
    #expect(reloaded.profile(id: profile.profileId)?.keychainAccount == "owner-account")
}

@Test("LLM credential profiles decode older payloads with main Settings visibility")
func llmCredentialProfilesDecodeOlderPayloadsWithMainSettingsVisibility() throws {
    let json = """
    {
      "profileId": "owner-openai",
      "providerKind": "openai",
      "displayName": "Owner OpenAI",
      "authKind": "api_key_keychain",
      "keychainService": "open_api_key",
      "keychainAccount": "algo-trading",
      "legacyAliases": [],
      "enabled": true,
      "updatedBy": "human owner",
      "updateSource": "user_edited",
      "createdAt": "2026-05-10T12:00:00Z",
      "updatedAt": "2026-05-10T12:00:00Z"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let profile = try decoder.decode(LLMCredentialProfile.self, from: Data(json.utf8))
    #expect(profile.settingsVisibility == .main)
    #expect(profile.isVisibleInMainSettings)
}

@Test("LLM keychain resolver reads OpenAI configured, legacy, and Anthropic profiles")
func llmKeychainResolverReadsConfiguredProfiles() {
    struct FakeKeyReader: KeyReading {
        let values: [String: String]

        func readKey(service: String, account: String) -> String? {
            values["\(service)|\(account)"]
        }
    }

    let now = Date(timeIntervalSince1970: 1_800_000_200)
    let resolver = LLMKeychainCredentialResolver(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [
                "open_api_key|algo-trading": "openai-secret",
                "openai_api_key|algo-trading": "legacy-secret",
                "anthropic_api_key|algo-trading": "anthropic-secret"
            ])
        ),
        labelReader: { _, _ in nil }
    )

    let openAI = resolver.resolve(profile: .defaultOpenAI(now: now))
    #expect(openAI.status == .ready)
    #expect(openAI.apiKey == "openai-secret")
    #expect(openAI.matchedServiceOrLabel == "open_api_key")

    var legacyOnlyProfile = LLMCredentialProfile.defaultOpenAI(now: now)
    legacyOnlyProfile.keychainService = "missing-openai"
    let legacy = resolver.resolve(profile: legacyOnlyProfile)
    #expect(legacy.status == .ready)
    #expect(legacy.apiKey == "legacy-secret")
    #expect(legacy.source == .legacyServiceAccount)

    let anthropic = resolver.resolve(profile: .defaultAnthropic(now: now))
    #expect(anthropic.status == .ready)
    #expect(anthropic.apiKey == "anthropic-secret")
    #expect(anthropic.providerKind == .anthropic)

    let missingAnthropicResolver = LLMKeychainCredentialResolver(
        keychainProvider: KeychainCredentialsProvider(keyReader: FakeKeyReader(values: [:])),
        labelReader: { _, _ in nil }
    )
    let missing = missingAnthropicResolver.resolve(profile: .defaultAnthropic(now: now))
    #expect(missing.status == .missingKey)
    #expect(missing.apiKey == nil)
}

@Test("Runtime settings decode legacy payloads as OpenAI provider selections")
func runtimeSettingsDecodeLegacyPayloadsAsOpenAI() throws {
    let json = """
    {
      "settingsId": "current-pm-runtime-settings",
      "runtimeIdentifier": "gpt-5",
      "reasoningMode": "deliberate",
      "updatedBy": "system",
      "updateSource": "system_default",
      "createdAt": "2026-05-05T12:00:00Z",
      "updatedAt": "2026-05-05T12:00:00Z"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let settings = try decoder.decode(PMRuntimeSettings.self, from: Data(json.utf8))
    #expect(settings.providerKind == .openAI)
    #expect(settings.credentialProfileId == LLMCredentialProfile.openAIDefaultProfileID)
    #expect(settings.runtimeIdentifier == "gpt-5")
}

@Test("Engine validates provider-aware runtime settings without claiming unsupported analyst execution")
func engineValidatesProviderAwareRuntimeSettings() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_300)
    let settingsFile = makeLLMProviderTempDirectory(name: "engine-validation")
        .appendingPathComponent("llm_provider_settings.json")
    let providerStore = LLMProviderSettingsStore(fileURL: settingsFile, now: { now })
    let engine = Engine(
        llmProviderSettingsStore: providerStore,
        llmCredentialResolver: StubLLMProviderCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .missingKey,
                apiKey: nil,
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: nil,
                account: "algo-trading",
                summary: "No Anthropic API key was found in Keychain for service anthropic_api_key account algo-trading."
            )
        ),
        openAIKeyStatusProvider: StubLLMProviderOpenAIKeyProvider(
            resolution: OpenAICredentialResolution(
                status: .ready,
                apiKey: "test-openai-key",
                source: .inferred,
                account: "algo-trading",
                summary: "Test OpenAI key resolved."
            )
        )
    )

    let openAIValidation = await engine.validatePMRuntimeCandidate(
        runtimeIdentifier: "gpt-5",
        reasoningMode: .standard,
        providerKind: .openAI,
        credentialProfileId: LLMCredentialProfile.openAIDefaultProfileID
    )
    #expect(openAIValidation.status == .valid)

    let anthropicValidation = await engine.validatePMRuntimeCandidate(
        runtimeIdentifier: "claude-sonnet-4-20250514",
        reasoningMode: .standard,
        providerKind: .anthropic,
        credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID
    )
    #expect(anthropicValidation.status == .invalid)
    #expect(anthropicValidation.category == .unavailable)
    #expect(anthropicValidation.summary.contains("Anthropic") == true)
    #expect(anthropicValidation.summary.contains("No Anthropic API key was found") == true)
}

@Test("Anthropic PM model aliases pass local validation when the configured key is present")
func anthropicPMModelAliasesPassLocalValidationWithReadyKey() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_350)
    let settingsFile = makeLLMProviderTempDirectory(name: "anthropic-pm-model-validation")
        .appendingPathComponent("llm_provider_settings.json")
    let providerStore = LLMProviderSettingsStore(fileURL: settingsFile, now: { now })
    let engine = Engine(
        llmProviderSettingsStore: providerStore,
        llmCredentialResolver: StubLLMProviderCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .ready,
                apiKey: "test-anthropic-key",
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: "anthropic_api_key",
                account: "algo-trading",
                summary: "Anthropic API key resolved from configured service/account."
            )
        )
    )

    for runtimeIdentifier in [
        "claude-sonnet-4-6",
        "claude-opus-4-7",
        "claude-haiku-4-5",
        "claude-haiku-4-5-20251001"
    ] {
        let validation = await engine.validatePMRuntimeCandidate(
            runtimeIdentifier: runtimeIdentifier,
            reasoningMode: .standard,
            providerKind: .anthropic,
            credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID
        )
        #expect(validation.status == .valid, "Expected \(runtimeIdentifier) to validate")
        #expect(validation.category == .accepted)
        #expect(validation.summary.contains("Anthropic runtime identifier passed") == true)
    }
}

@Test("Anthropic PM runtime save does not inherit OpenAI fallback or analyst unsupported status")
func anthropicPMRuntimeSaveStaysPMScopedAndProviderSpecific() async throws {
    let root = makeLLMProviderTempDirectory(name: "anthropic-pm-save")
    let now = Date(timeIntervalSince1970: 1_800_000_360)
    let pmStore = PMRuntimeSettingsStore(fileURL: root.appendingPathComponent("pm-runtime-settings.json"))
    let providerStore = LLMProviderSettingsStore(
        fileURL: root.appendingPathComponent("llm-provider-settings.json"),
        now: { now }
    )
    let engine = Engine(
        pmRuntimeSettingsStore: pmStore,
        llmProviderSettingsStore: providerStore,
        llmCredentialResolver: StubLLMProviderCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .ready,
                apiKey: "test-anthropic-key",
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: "anthropic_api_key",
                account: "algo-trading",
                summary: "Anthropic API key resolved from configured service/account."
            )
        )
    )

    _ = try await engine.upsertPMRuntimeSettings(
        PMRuntimeSettings(
            providerKind: .openAI,
            credentialProfileId: LLMCredentialProfile.openAIDefaultProfileID,
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .standard,
            validationStatus: RuntimeValidationRecord(
                status: .valid,
                category: .accepted,
                summary: "OpenAI runtime was previously valid.",
                checkedAt: now,
                checkedBy: "human owner"
            ),
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let savedAnthropic = try await engine.upsertPMRuntimeSettings(
        PMRuntimeSettings(
            providerKind: .anthropic,
            credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
            runtimeIdentifier: "claude-sonnet-4-6",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now.addingTimeInterval(60)
        )
    )

    #expect(savedAnthropic.validationStatus?.status == .valid)
    #expect(savedAnthropic.validationStatus?.category == .accepted)
    #expect(savedAnthropic.validationStatus?.summary.contains("analyst execution is not implemented") == false)
    #expect(savedAnthropic.lastFallback == nil)
    #expect(savedAnthropic.lastKnownGoodRuntime?.providerKind == .anthropic)
    #expect(savedAnthropic.lastKnownGoodRuntime?.runtimeIdentifier == "claude-sonnet-4-6")

    let presentation = try #require(makeRuntimeOperabilityPresentation(pmRuntimeSettings: savedAnthropic))
    #expect(presentation.configurationLabel == "Valid")
    #expect(presentation.operabilityLabel == "Primary Path Ready")
    #expect(presentation.operabilitySummary.contains("OpenAI") == false)
    #expect(presentation.actualRuntimeSummary == nil)
}

@Test("Loading a stale invalid Anthropic PM record revalidates through the PM-supported path")
func staleInvalidAnthropicPMRuntimeRevalidatesOnLoad() async throws {
    let root = makeLLMProviderTempDirectory(name: "anthropic-pm-stale-invalid")
    let now = Date(timeIntervalSince1970: 1_800_000_365)
    let pmStore = PMRuntimeSettingsStore(
        fileURL: root.appendingPathComponent("pm-runtime-settings.json"),
        now: { now }
    )
    let providerStore = LLMProviderSettingsStore(
        fileURL: root.appendingPathComponent("llm-provider-settings.json"),
        now: { now }
    )
    let staleRecord = PMRuntimeSettings(
        providerKind: .anthropic,
        credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
        runtimeIdentifier: "claude-sonnet-4-6",
        reasoningMode: .standard,
        validationStatus: RuntimeValidationRecord(
            status: .invalid,
            category: .unavailable,
            summary: "Anthropic runtime identifier passed the app's bounded local validation policy. Anthropic API key resolved from Keychain service/label anthropic_api_key account algo-trading. Anthropic is configurable for this runtime setting, but live Anthropic analyst execution is not implemented yet for this path.",
            checkedAt: now.addingTimeInterval(-120),
            checkedBy: "human owner"
        ),
        lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
            providerKind: .openAI,
            credentialProfileId: LLMCredentialProfile.openAIDefaultProfileID,
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .standard,
            verifiedAt: now.addingTimeInterval(-300),
            summary: "Prior OpenAI runtime."
        ),
        updatedBy: "human owner",
        updateSource: .userEdited,
        createdAt: now.addingTimeInterval(-600),
        updatedAt: now.addingTimeInterval(-120)
    )
    _ = try await pmStore.upsert(staleRecord)

    let engine = Engine(
        pmRuntimeSettingsStore: PMRuntimeSettingsStore(
            fileURL: root.appendingPathComponent("pm-runtime-settings.json"),
            now: { now }
        ),
        llmProviderSettingsStore: providerStore,
        llmCredentialResolver: StubLLMProviderCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .ready,
                apiKey: "test-anthropic-key",
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: "anthropic_api_key",
                account: "algo-trading",
                summary: "Anthropic API key resolved from configured service/account."
            )
        )
    )

    let loaded = try await engine.getPMRuntimeSettings()

    #expect(loaded.validationStatus?.status == .valid)
    #expect(loaded.validationStatus?.category == .accepted)
    #expect(loaded.validationStatus?.summary.contains("analyst execution is not implemented") == false)
    #expect(loaded.lastFallback == nil)
    #expect(loaded.lastKnownGoodRuntime?.providerKind == .anthropic)
    #expect(loaded.lastKnownGoodRuntime?.runtimeIdentifier == "claude-sonnet-4-6")
    let presentation = try #require(makeRuntimeOperabilityPresentation(pmRuntimeSettings: loaded))
    #expect(presentation.configurationLabel == "Valid")
    #expect(presentation.operabilityLabel == "Primary Path Ready")
}

@Test("Anthropic analyst runtimes validate as supported when a configured key is ready")
func anthropicAnalystRuntimesValidateAsSupportedWithReadyKey() async throws {
    let root = makeLLMProviderTempDirectory(name: "anthropic-analyst-supported")
    let now = Date(timeIntervalSince1970: 1_800_000_370)
    let providerStore = LLMProviderSettingsStore(
        fileURL: root.appendingPathComponent("llm-provider-settings.json"),
        now: { now }
    )
    let engine = Engine(
        recentNewsAnalystRuntimeSettingsStore: RecentNewsAnalystRuntimeSettingsStore(
            fileURL: root.appendingPathComponent("recent-news-runtime-settings.json"),
            now: { now }
        ),
        standingBenchAnalystRuntimeSettingsStore: StandingBenchAnalystRuntimeSettingsStore(
            fileURL: root.appendingPathComponent("standing-bench-runtime-settings.json"),
            now: { now }
        ),
        llmProviderSettingsStore: providerStore,
        llmCredentialResolver: StubLLMProviderCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .ready,
                apiKey: "test-anthropic-key",
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: "anthropic_api_key",
                account: "algo-trading",
                summary: "Anthropic API key resolved from configured service/account."
            )
        )
    )

    let savedRecentNews = try await engine.upsertRecentNewsAnalystRuntimeSettings(
        RecentNewsAnalystRuntimeSettings(
            providerKind: .anthropic,
            credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
            runtimeIdentifier: "claude-sonnet-4-6",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    let savedStandingBench = try await engine.upsertStandingBenchAnalystRuntimeSettings(
        StandingBenchAnalystRuntimeSettings(
            providerKind: .anthropic,
            credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
            runtimeIdentifier: "claude-sonnet-4-6",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    #expect(savedRecentNews.validationStatus?.status == .valid)
    #expect(savedRecentNews.validationStatus?.category == .accepted)
    #expect(savedRecentNews.validationStatus?.summary.contains("analyst execution is not implemented") == false)
    #expect(savedRecentNews.validationStatus?.summary.contains("Anthropic Messages API execution") == true)
    #expect(savedRecentNews.lastKnownGoodRuntime?.providerKind == .anthropic)
    #expect(savedRecentNews.lastKnownGoodRuntime?.runtimeIdentifier == "claude-sonnet-4-6")
    #expect(savedStandingBench.validationStatus?.status == .valid)
    #expect(savedStandingBench.validationStatus?.category == .accepted)
    #expect(savedStandingBench.validationStatus?.summary.contains("analyst execution is not implemented") == false)
    #expect(savedStandingBench.validationStatus?.summary.contains("Anthropic Messages API execution") == true)
    #expect(savedStandingBench.lastKnownGoodRuntime?.providerKind == .anthropic)
    #expect(savedStandingBench.lastKnownGoodRuntime?.runtimeIdentifier == "claude-sonnet-4-6")
}

@Test("Invalid Anthropic PM model id fails local validation precisely")
func invalidAnthropicPMModelIdFailsLocalValidation() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_380)
    let providerStore = LLMProviderSettingsStore(
        fileURL: makeLLMProviderTempDirectory(name: "anthropic-invalid-id").appendingPathComponent("llm-provider-settings.json"),
        now: { now }
    )
    let engine = Engine(
        llmProviderSettingsStore: providerStore,
        llmCredentialResolver: StubLLMProviderCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .ready,
                apiKey: "test-anthropic-key",
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: "anthropic_api_key",
                account: "algo-trading",
                summary: "Anthropic API key resolved from configured service/account."
            )
        )
    )

    let validation = await engine.validatePMRuntimeCandidate(
        runtimeIdentifier: "claude-fake-model",
        reasoningMode: .standard,
        providerKind: .anthropic,
        credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID
    )
    #expect(validation.status == .invalid)
    #expect(validation.category == .invalidFormat)
    #expect(validation.summary.contains("recognized Claude API model id or alias") == true)
}

private struct StubLLMProviderOpenAIKeyProvider: OpenAIKeyStatusProviding {
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

private struct StubLLMProviderCredentialResolver: LLMCredentialResolving {
    let resolution: LLMCredentialResolution

    func resolve(profile: LLMCredentialProfile) -> LLMCredentialResolution {
        LLMCredentialResolution(
            status: resolution.status,
            apiKey: resolution.apiKey,
            profileId: profile.profileId,
            providerKind: profile.providerKind,
            source: resolution.source,
            matchedServiceOrLabel: resolution.matchedServiceOrLabel,
            account: resolution.account,
            summary: resolution.summary
        )
    }
}

private func makeLLMProviderTempDirectory(name: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
