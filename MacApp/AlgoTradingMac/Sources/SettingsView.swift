import SwiftUI
import TradingKit

private enum PMReasoningModeSelection: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case standard = "Standard"
    case deliberate = "Deliberate"

    var id: String { rawValue }

    var reasoningMode: AnalystRuntimeReasoningMode? {
        switch self {
        case .default:
            return nil
        case .standard:
            return .standard
        case .deliberate:
            return .deliberate
        }
    }

    init(reasoningMode: AnalystRuntimeReasoningMode?) {
        switch reasoningMode {
        case .standard:
            self = .standard
        case .deliberate:
            self = .deliberate
        case nil:
            self = .default
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var providerProfileServiceFields: [String: String] = [:]
    @State private var providerProfileAccountFields: [String: String] = [:]
    @State private var providerProfileFeedbackById: [String: String] = [:]
    @State private var pmProviderKind: LLMProviderKind = .openAI
    @State private var pmCredentialProfileId: String = LLMCredentialProfile.openAIDefaultProfileID
    @State private var pmRuntimeIdentifier: String = ""
    @State private var pmReasoningModeSelection: PMReasoningModeSelection = .deliberate
    @State private var pmRuntimeSettingsFeedback: String?
    @State private var pmRuntimeValidationPreview: RuntimeValidationRecord?
    @State private var recentNewsAnalystProviderKind: LLMProviderKind = .openAI
    @State private var recentNewsAnalystCredentialProfileId: String = LLMCredentialProfile.openAIDefaultProfileID
    @State private var recentNewsAnalystRuntimeIdentifier: String = ""
    @State private var recentNewsAnalystReasoningModeSelection: PMReasoningModeSelection = .standard
    @State private var standingBenchAnalystProviderKind: LLMProviderKind = .openAI
    @State private var standingBenchAnalystCredentialProfileId: String = LLMCredentialProfile.openAIDefaultProfileID
    @State private var standingBenchAnalystRuntimeIdentifier: String = ""
    @State private var standingBenchAnalystReasoningModeSelection: PMReasoningModeSelection = .standard
    @State private var builtInNewsFeedback: String?
    @State private var recentNewsAnalystRuntimeFeedback: String?
    @State private var recentNewsAnalystRuntimeValidationPreview: RuntimeValidationRecord?
    @State private var standingBenchAnalystRuntimeFeedback: String?
    @State private var standingBenchAnalystRuntimeValidationPreview: RuntimeValidationRecord?
    @State private var liveExecutionProtectionFeedback: String?

    var body: some View {
        Form {
            Section("Environment") {
                Picker("Environment", selection: $appModel.selectedEnvironment) {
                    Text("Paper").tag(TradingEnvironment.paper)
                    Text("Live").tag(TradingEnvironment.live)
                }
                .pickerStyle(.segmented)
                Text("Live arming, disarming, and kill-switch controls now live in System Control so day-to-day execution posture stays out of Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            liveExecutionProtectionSection

            Section("Market Data Feed") {
                Picker("Market Data Feed", selection: $appModel.selectedMarketDataFeed) {
                    ForEach(TradingMarketDataFeed.allCases, id: \.self) { feed in
                        Text(feed.displayName).tag(feed)
                    }
                }
                .pickerStyle(.segmented)
                Text("Default owner-facing market data posture now starts on Stocks IEX.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("UI") {
                Toggle(
                    "Show Advanced Tabs (PM Inbox/Signals/Proposals/Jobs/Logs)",
                    isOn: $appModel.showAdvancedTabs
                )
                Text("When off, the app stays focused on Command Center, Portfolio Watch, News, and System Control. PM Inbox and other raw operator surfaces stay hidden until you explicitly turn them on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Built-in News Sources") {
                Toggle(
                    "Enable Alpaca News ingest",
                    isOn: Binding(
                        get: { appModel.alpacaNewsIngestEnabled },
                        set: { enabled in
                            Task { @MainActor in
                                builtInNewsFeedback = await appModel.setAlpacaNewsIngestEnabled(enabled)
                            }
                        }
                    )
                )

                Text("Built-in sources are platform-integrated. Alpaca News is not managed as an editable RSS URL.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let builtInNewsFeedback, !builtInNewsFeedback.isEmpty {
                    Text(builtInNewsFeedback)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("LLM Providers") {
                Text("Configure provider credential lookup profiles here. Secrets stay in macOS Keychain; the app stores only service/account labels and readiness summaries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("API-compatible Keychain credentials are supported now. Consumer subscription sign-in through browser sessions is unsupported unless a provider exposes an official app auth flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Migration-only legacy aliases are resolved through the default provider profile and hidden from this main list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let profiles = (appModel.llmProviderSettings ?? LLMProviderSettings.default(now: Date()))
                    .mainSettingsCredentialProfiles
                ForEach(profiles) { profile in
                    providerCredentialProfileEditor(profile)
                }
            }

            Section("PM Runtime") {
                Text("Configure the PM's durable runtime preference here. This is the owner-facing model setting for the PM itself, distinct from analyst runtime defaults and delegation overrides.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let settings = appModel.pmRuntimeSettings {
                    let updateSourceLabel = settings.updateSource.rawValue.replacingOccurrences(of: "_", with: " ")
                    Text("Last updated by \(settings.updatedBy) via \(updateSourceLabel) on \(settings.updatedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Provider", selection: $pmProviderKind) {
                    ForEach(LLMProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: pmProviderKind) { provider in
                    pmCredentialProfileId = defaultCredentialProfileId(for: provider)
                }

                credentialProfilePicker(
                    providerKind: pmProviderKind,
                    selection: $pmCredentialProfileId
                )

                TextField("Model identifier", text: $pmRuntimeIdentifier)
                    .textFieldStyle(.roundedBorder)

                Picker("Reasoning", selection: $pmReasoningModeSelection) {
                    ForEach(PMReasoningModeSelection.allCases) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                if let capabilityHint = openAIRuntimeCapabilityHint(
                    runtimeIdentifier: pmRuntimeIdentifier,
                    reasoningMode: pmReasoningModeSelection.reasoningMode
                ), pmProviderKind == .openAI {
                    Text(capabilityHint.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(capabilityHint.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if pmProviderKind == .anthropic {
                    Text("Anthropic PM conversation execution uses the Messages API when a configured Keychain profile is present. Extended/adaptive thinking controls remain deferred until a provider-capability slice can wire them without exposing raw thinking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let presentation = makeRuntimeOperabilityPresentation(
                    pmRuntimeSettings: appModel.pmRuntimeSettings
                ) {
                    runtimeOperabilitySummary(presentation)
                }
                if let lastKnownGood = appModel.pmRuntimeSettings?.lastKnownGoodRuntime {
                    Text("Last known good: \(lastKnownGood.runtimeIdentifier) (\((lastKnownGood.reasoningMode ?? .standard).rawValue) reasoning), verified \(lastKnownGood.verifiedAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let fallback = appModel.pmRuntimeSettings?.lastFallback {
                    Text("Last fallback: configured \(fallback.configuredRuntimeIdentifier) -> \(fallback.fallbackRuntimeIdentifier) because \(fallback.reasonSummary)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("Use an open model string so you can adopt newer PM runtimes later without waiting for a hardcoded app update.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("This setting does not change analyst runtime defaults, delegation overrides, approval gates, or execution safety.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Validation is bounded and local to the app's runtime naming policy. It reduces obvious typos, but it does not silently guarantee live provider availability.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Validate PM Runtime") {
                        validatePMRuntimeSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Save PM Runtime") {
                        savePMRuntimeSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let pmRuntimeValidationPreview {
                    Text("Preview: \(pmRuntimeValidationPreview.summary)")
                        .font(.caption)
                        .foregroundStyle(validationColor(pmRuntimeValidationPreview))
                }
                if let pmRuntimeSettingsFeedback, !pmRuntimeSettingsFeedback.isEmpty {
                    Text(pmRuntimeSettingsFeedback)
                        .font(.footnote)
                        .foregroundStyle(feedbackColor(feedback: pmRuntimeSettingsFeedback, preview: pmRuntimeValidationPreview))
                }
            }

            Section("Recent News Analyst Runtime") {
                Text("Configure the durable runtime preference for the Recent News Analyst. This setting now uses the same future-flexible open-string model philosophy as the PM while staying distinct from PM runtime settings and delegation overrides.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let settings = appModel.recentNewsAnalystRuntimeSettings {
                    let updateSourceLabel = settings.updateSource.rawValue.replacingOccurrences(of: "_", with: " ")
                    Text("Last updated by \(settings.updatedBy) via \(updateSourceLabel) on \(settings.updatedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Provider", selection: $recentNewsAnalystProviderKind) {
                    ForEach(LLMProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: recentNewsAnalystProviderKind) { provider in
                    recentNewsAnalystCredentialProfileId = defaultCredentialProfileId(for: provider)
                }

                credentialProfilePicker(
                    providerKind: recentNewsAnalystProviderKind,
                    selection: $recentNewsAnalystCredentialProfileId
                )

                TextField("Runtime identifier", text: $recentNewsAnalystRuntimeIdentifier)
                    .textFieldStyle(.roundedBorder)

                Picker("Reasoning", selection: $recentNewsAnalystReasoningModeSelection) {
                    ForEach(PMReasoningModeSelection.allCases) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                if let presentation = makeRuntimeOperabilityPresentation(
                    recentNewsAnalystRuntimeSettings: appModel.recentNewsAnalystRuntimeSettings
                ) {
                    runtimeOperabilitySummary(presentation)
                }
                if let lastKnownGood = appModel.recentNewsAnalystRuntimeSettings?.lastKnownGoodRuntime {
                    Text("Last known good: \(lastKnownGood.runtimeIdentifier) (\((lastKnownGood.reasoningMode ?? .standard).rawValue) reasoning), verified \(lastKnownGood.verifiedAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let fallback = appModel.recentNewsAnalystRuntimeSettings?.lastFallback {
                    Text("Last fallback: configured \(fallback.configuredRuntimeIdentifier) -> \(fallback.fallbackRuntimeIdentifier) because \(fallback.reasonSummary)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("Use an open runtime string here so the scheduled analyst is not trapped behind a stale fixed model list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if recentNewsAnalystProviderKind == .anthropic {
                    Text("Anthropic Recent News Analyst execution uses the Messages API when a configured Keychain profile is present. Standard reasoning is supported for strict structured report output; extended/adaptive thinking controls remain deferred until a provider-compatible analyst contract is in place.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Validation is bounded and local. It catches obvious format issues and flags unknown runtime families without freezing this setting to today's menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Validate Runtime") {
                        validateRecentNewsAnalystRuntimeSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Save Runtime Setting") {
                        saveRecentNewsAnalystRuntimeSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let recentNewsAnalystRuntimeValidationPreview {
                    Text("Preview: \(recentNewsAnalystRuntimeValidationPreview.summary)")
                        .font(.caption)
                        .foregroundStyle(validationColor(recentNewsAnalystRuntimeValidationPreview))
                }
                if let recentNewsAnalystRuntimeFeedback, !recentNewsAnalystRuntimeFeedback.isEmpty {
                    Text(recentNewsAnalystRuntimeFeedback)
                        .font(.footnote)
                        .foregroundStyle(
                            feedbackColor(
                                feedback: recentNewsAnalystRuntimeFeedback,
                                preview: recentNewsAnalystRuntimeValidationPreview
                            )
                        )
                }
            }

            Section("Standing Bench Analyst Runtime") {
                Text("Configure the durable default runtime preference for the normal standing bench analysts. This setting stays separate from the higher-frequency Recent News Analyst and does not override explicit PM ad hoc runtime choices.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let settings = appModel.standingBenchAnalystRuntimeSettings {
                    let updateSourceLabel = settings.updateSource.rawValue.replacingOccurrences(of: "_", with: " ")
                    Text("Last updated by \(settings.updatedBy) via \(updateSourceLabel) on \(settings.updatedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Provider", selection: $standingBenchAnalystProviderKind) {
                    ForEach(LLMProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: standingBenchAnalystProviderKind) { provider in
                    standingBenchAnalystCredentialProfileId = defaultCredentialProfileId(for: provider)
                }

                credentialProfilePicker(
                    providerKind: standingBenchAnalystProviderKind,
                    selection: $standingBenchAnalystCredentialProfileId
                )

                TextField("Runtime identifier", text: $standingBenchAnalystRuntimeIdentifier)
                    .textFieldStyle(.roundedBorder)

                Picker("Reasoning", selection: $standingBenchAnalystReasoningModeSelection) {
                    ForEach(PMReasoningModeSelection.allCases) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                if let presentation = makeRuntimeOperabilityPresentation(
                    standingBenchAnalystRuntimeSettings: appModel.standingBenchAnalystRuntimeSettings
                ) {
                    runtimeOperabilitySummary(presentation)
                }
                if let lastKnownGood = appModel.standingBenchAnalystRuntimeSettings?.lastKnownGoodRuntime {
                    Text("Last known good: \(lastKnownGood.runtimeIdentifier) (\((lastKnownGood.reasoningMode ?? .standard).rawValue) reasoning), verified \(lastKnownGood.verifiedAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let fallback = appModel.standingBenchAnalystRuntimeSettings?.lastFallback {
                    Text("Last fallback: configured \(fallback.configuredRuntimeIdentifier) -> \(fallback.fallbackRuntimeIdentifier) because \(fallback.reasonSummary)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("This owner setting becomes the default for the standing sector and overlay bench analysts unless a narrower PM override or specialization-specific setting applies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if standingBenchAnalystProviderKind == .anthropic {
                    Text("Anthropic standing-bench analyst execution uses the Messages API when a configured Keychain profile is present. Standard reasoning is supported for strict structured report output; extended/adaptive thinking controls remain deferred until a provider-compatible analyst contract is in place.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Validate Runtime") {
                        validateStandingBenchAnalystRuntimeSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Save Runtime Setting") {
                        saveStandingBenchAnalystRuntimeSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let standingBenchAnalystRuntimeValidationPreview {
                    Text("Preview: \(standingBenchAnalystRuntimeValidationPreview.summary)")
                        .font(.caption)
                        .foregroundStyle(validationColor(standingBenchAnalystRuntimeValidationPreview))
                }
                if let standingBenchAnalystRuntimeFeedback, !standingBenchAnalystRuntimeFeedback.isEmpty {
                    Text(standingBenchAnalystRuntimeFeedback)
                        .font(.footnote)
                        .foregroundStyle(
                            feedbackColor(
                                feedback: standingBenchAnalystRuntimeFeedback,
                                preview: standingBenchAnalystRuntimeValidationPreview
                            )
                        )
                }
            }

            Section("Keychain Status") {
                statusLine(label: "Paper public", found: appModel.keyStatus.paperPublicFound)
                statusLine(label: "Paper secret", found: appModel.keyStatus.paperSecretFound)
                statusLine(label: "Paper keys", found: appModel.keyStatus.paperKeysFound)
                Divider()
                statusLine(label: "Live public", found: appModel.keyStatus.livePublicFound)
                statusLine(label: "Live secret", found: appModel.keyStatus.liveSecretFound)
                statusLine(label: "Live keys", found: appModel.keyStatus.liveKeysFound)
                Divider()
                statusLine(label: "Telegram", found: appModel.keyStatus.telegramConfigured)
                statusLine(
                    label: "OpenAI",
                    found: appModel.keyStatus.openAIConfigured,
                    summary: appModel.keyStatus.openAIStatusSummary
                )

                if let lastChecked = appModel.keyStatus.lastChecked {
                    Text("Last checked: \(lastChecked.formatted(date: .abbreviated, time: .standard))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Re-check Keychain") {
                        appModel.refreshKeychainStatus(forceRefresh: true)
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                }
            }

        }
        .formStyle(.grouped)
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
        .task {
            appModel.ensureKeychainStatusLoaded()
            _ = await appModel.refreshLLMProviderSettings()
            loadProviderProfileEditors(from: appModel.llmProviderSettings)
            _ = await appModel.refreshAlpacaNewsIngestEnabled()
            liveExecutionProtectionFeedback = await appModel.refreshLiveExecutionProtectionSettings()
            pmRuntimeSettingsFeedback = await appModel.refreshPMRuntimeSettings()
            loadPMRuntimeSettingsEditor(from: appModel.pmRuntimeSettings)
            recentNewsAnalystRuntimeFeedback = await appModel.refreshRecentNewsAnalystRuntimeSettings()
            loadRecentNewsAnalystRuntimeSettingsEditor(from: appModel.recentNewsAnalystRuntimeSettings)
            standingBenchAnalystRuntimeFeedback = await appModel.refreshStandingBenchAnalystRuntimeSettings()
            loadStandingBenchAnalystRuntimeSettingsEditor(from: appModel.standingBenchAnalystRuntimeSettings)
        }
        .onChange(of: appModel.pmRuntimeSettings) { settings in
            loadPMRuntimeSettingsEditor(from: settings)
        }
        .onChange(of: appModel.llmProviderSettings) { settings in
            loadProviderProfileEditors(from: settings)
        }
        .onChange(of: appModel.recentNewsAnalystRuntimeSettings) { settings in
            loadRecentNewsAnalystRuntimeSettingsEditor(from: settings)
        }
        .onChange(of: appModel.standingBenchAnalystRuntimeSettings) { settings in
            loadStandingBenchAnalystRuntimeSettingsEditor(from: settings)
        }
    }

    private var liveExecutionProtectionSection: some View {
        Section("Live Execution Protection") {
            Toggle(
                "Require Touch ID / Mac password for Live order submission",
                isOn: liveExecutionProtectionBinding
            )

            Text("This adds a final local macOS authentication gate before Live NEW/REPLACE order submission. It does not replace PM approval, proposal approval, Live arming, or kill-switch protections. Paper trading is unaffected. CANCEL remains available for risk reduction.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(appModel.liveExecutionProtectionDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Test Local Authentication") {
                Task { @MainActor in
                    liveExecutionProtectionFeedback = await appModel.testLiveExecutionLocalAuthentication()
                }
            }

            if let result = appModel.liveExecutionProtectionLastAuthResult {
                Text("Last local-auth check: \(result.status.rawValue). \(result.summary)")
                    .font(.caption)
                    .foregroundStyle(result.authorized ? Color.secondary : Color.orange)
            }

            if let liveExecutionProtectionFeedback, !liveExecutionProtectionFeedback.isEmpty {
                Text(liveExecutionProtectionFeedback)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var liveExecutionProtectionBinding: Binding<Bool> {
        Binding(
            get: { appModel.liveExecutionProtectionRequired },
            set: { required in
                Task { @MainActor in
                    liveExecutionProtectionFeedback = await appModel.setLiveExecutionProtectionRequired(required)
                }
            }
        )
    }

    @ViewBuilder
    private func providerCredentialProfileEditor(_ profile: LLMCredentialProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.headline)
                    Text("\(profile.providerKind.displayName) - \(profile.authKind.rawValue.replacingOccurrences(of: "_", with: " "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(profile.enabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(profile.enabled ? .green : .orange)
            }

            TextField(
                "Keychain service",
                text: Binding(
                    get: { providerProfileServiceFields[profile.profileId] ?? profile.keychainService },
                    set: { providerProfileServiceFields[profile.profileId] = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                "Keychain account",
                text: Binding(
                    get: { providerProfileAccountFields[profile.profileId] ?? profile.keychainAccount },
                    set: { providerProfileAccountFields[profile.profileId] = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)

            if profile.legacyAliases.isEmpty == false {
                Text("Legacy aliases: \(profile.legacyAliases.map { "\($0.serviceOrLabel) / \($0.account)" }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let readiness = appModel.llmCredentialReadinessByProfileId[profile.profileId] {
                Text("\(readiness.providerKind.displayName): \(readiness.summary)")
                    .font(.caption)
                    .foregroundStyle(readiness.isReady ? .green : .orange)
                Text("Checked \(readiness.checkedAt.formatted(date: .abbreviated, time: .shortened)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Check Keychain") {
                    Task { @MainActor in
                        providerProfileFeedbackById[profile.profileId] = await appModel.checkLLMCredentialProfile(
                            profileId: profile.profileId
                        )
                    }
                }
                .buttonStyle(.bordered)

                Button("Save Profile") {
                    saveCredentialProfile(profile)
                }
                .buttonStyle(.borderedProminent)
            }

            if let feedback = providerProfileFeedbackById[profile.profileId], feedback.isEmpty == false {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(feedback.hasPrefix("Saved") ? .green : .red)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func credentialProfilePicker(
        providerKind: LLMProviderKind,
        selection: Binding<String>
    ) -> some View {
        let profiles = (appModel.llmProviderSettings?.mainSettingsProfiles(for: providerKind) ?? [])
        if profiles.isEmpty {
            Text("No credential profile is configured for \(providerKind.displayName).")
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            Picker("Credential Profile", selection: selection) {
                ForEach(profiles) { profile in
                    Text(profile.displayName).tag(profile.profileId)
                }
            }
        }
    }

    private func defaultCredentialProfileId(for providerKind: LLMProviderKind) -> String {
        appModel.llmProviderSettings?.mainSettingsProfiles(for: providerKind).first?.profileId
            ?? providerKind.defaultCredentialProfileId
    }

    private func loadProviderProfileEditors(from settings: LLMProviderSettings?) {
        let settings = settings ?? LLMProviderSettings.default(now: Date())
        for profile in settings.credentialProfiles {
            providerProfileServiceFields[profile.profileId] = profile.keychainService
            providerProfileAccountFields[profile.profileId] = profile.keychainAccount
        }
    }

    private func saveCredentialProfile(_ profile: LLMCredentialProfile) {
        var updated = profile
        updated.keychainService = providerProfileServiceFields[profile.profileId] ?? profile.keychainService
        updated.keychainAccount = providerProfileAccountFields[profile.profileId] ?? profile.keychainAccount
        updated.updatedBy = "human owner"
        updated.updateSource = .userEdited
        updated.updatedAt = Date()

        Task { @MainActor in
            let feedback = await appModel.upsertLLMCredentialProfile(updated)
            providerProfileFeedbackById[profile.profileId] = feedback ?? "Saved \(profile.displayName)."
            if feedback == nil {
                _ = await appModel.checkLLMCredentialProfile(profileId: profile.profileId)
            }
        }
    }

    private func statusLine(label: String, found: Bool, summary: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(found ? "✅" : "❌")
            }
            if let summary, summary.isEmpty == false {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savePMRuntimeSettings() {
        let existing = appModel.pmRuntimeSettings ?? PMRuntimeSettings.default(now: Date())
        let settings = PMRuntimeSettings(
            settingsId: existing.settingsId,
            providerKind: pmProviderKind,
            credentialProfileId: pmCredentialProfileId,
            runtimeIdentifier: pmRuntimeIdentifier,
            reasoningMode: pmReasoningModeSelection.reasoningMode,
            validationStatus: existing.validationStatus,
            lastKnownGoodRuntime: existing.lastKnownGoodRuntime,
            lastFallback: existing.lastFallback,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )

        Task { @MainActor in
            pmRuntimeValidationPreview = nil
            pmRuntimeSettingsFeedback = await appModel.upsertPMRuntimeSettings(settings)
            if pmRuntimeSettingsFeedback == nil {
                pmRuntimeSettingsFeedback = "Saved PM runtime setting."
                loadPMRuntimeSettingsEditor(from: appModel.pmRuntimeSettings)
            }
        }
    }

    private func loadPMRuntimeSettingsEditor(from settings: PMRuntimeSettings?) {
        let settings = settings ?? PMRuntimeSettings.default(now: Date())
        pmProviderKind = settings.providerKind
        pmCredentialProfileId = settings.credentialProfileId
        pmRuntimeIdentifier = settings.runtimeIdentifier
        pmReasoningModeSelection = PMReasoningModeSelection(reasoningMode: settings.reasoningMode)
        pmRuntimeValidationPreview = nil
    }

    private func validatePMRuntimeSettings() {
        Task { @MainActor in
            let validation = await appModel.validatePMRuntimeCandidate(
                runtimeIdentifier: pmRuntimeIdentifier,
                reasoningMode: pmReasoningModeSelection.reasoningMode,
                providerKind: pmProviderKind,
                credentialProfileId: pmCredentialProfileId
            )
            pmRuntimeValidationPreview = validation
            pmRuntimeSettingsFeedback = validation.summary
        }
    }

    private func saveRecentNewsAnalystRuntimeSettings() {
        let existing = appModel.recentNewsAnalystRuntimeSettings ?? RecentNewsAnalystRuntimeSettings.default(now: Date())
        let now = Date()
        let settings = RecentNewsAnalystRuntimeSettings(
            settingsId: existing.settingsId,
            providerKind: recentNewsAnalystProviderKind,
            credentialProfileId: recentNewsAnalystCredentialProfileId,
            runtimeIdentifier: recentNewsAnalystRuntimeIdentifier,
            reasoningMode: recentNewsAnalystReasoningModeSelection.reasoningMode,
            validationStatus: existing.validationStatus,
            lastKnownGoodRuntime: existing.lastKnownGoodRuntime,
            lastFallback: existing.lastFallback,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: existing.createdAt,
            updatedAt: now
        )

        Task { @MainActor in
            recentNewsAnalystRuntimeValidationPreview = nil
            recentNewsAnalystRuntimeFeedback = await appModel.upsertRecentNewsAnalystRuntimeSettings(settings)
            if recentNewsAnalystRuntimeFeedback == nil {
                recentNewsAnalystRuntimeFeedback = "Saved Recent News Analyst runtime setting."
                loadRecentNewsAnalystRuntimeSettingsEditor(from: appModel.recentNewsAnalystRuntimeSettings)
            }
        }
    }

    private func loadRecentNewsAnalystRuntimeSettingsEditor(from settings: RecentNewsAnalystRuntimeSettings?) {
        let settings = settings ?? RecentNewsAnalystRuntimeSettings.default(now: Date())
        recentNewsAnalystProviderKind = settings.providerKind
        recentNewsAnalystCredentialProfileId = settings.credentialProfileId
        recentNewsAnalystRuntimeIdentifier = settings.runtimeIdentifier
        recentNewsAnalystReasoningModeSelection = PMReasoningModeSelection(reasoningMode: settings.reasoningMode)
        recentNewsAnalystRuntimeValidationPreview = nil
    }

    private func validateRecentNewsAnalystRuntimeSettings() {
        Task { @MainActor in
            let validation = await appModel.validateRecentNewsAnalystRuntimeCandidate(
                runtimeIdentifier: recentNewsAnalystRuntimeIdentifier,
                reasoningMode: recentNewsAnalystReasoningModeSelection.reasoningMode,
                providerKind: recentNewsAnalystProviderKind,
                credentialProfileId: recentNewsAnalystCredentialProfileId
            )
            recentNewsAnalystRuntimeValidationPreview = validation
            recentNewsAnalystRuntimeFeedback = validation.summary
        }
    }

    private func saveStandingBenchAnalystRuntimeSettings() {
        let existing = appModel.standingBenchAnalystRuntimeSettings ?? StandingBenchAnalystRuntimeSettings.default(now: Date())
        let now = Date()
        let settings = StandingBenchAnalystRuntimeSettings(
            settingsId: existing.settingsId,
            providerKind: standingBenchAnalystProviderKind,
            credentialProfileId: standingBenchAnalystCredentialProfileId,
            runtimeIdentifier: standingBenchAnalystRuntimeIdentifier,
            reasoningMode: standingBenchAnalystReasoningModeSelection.reasoningMode,
            validationStatus: existing.validationStatus,
            lastKnownGoodRuntime: existing.lastKnownGoodRuntime,
            lastFallback: existing.lastFallback,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: existing.createdAt,
            updatedAt: now
        )

        Task { @MainActor in
            standingBenchAnalystRuntimeValidationPreview = nil
            standingBenchAnalystRuntimeFeedback = await appModel.upsertStandingBenchAnalystRuntimeSettings(settings)
            if standingBenchAnalystRuntimeFeedback == nil {
                standingBenchAnalystRuntimeFeedback = "Saved standing bench runtime setting."
                loadStandingBenchAnalystRuntimeSettingsEditor(from: appModel.standingBenchAnalystRuntimeSettings)
            }
        }
    }

    private func loadStandingBenchAnalystRuntimeSettingsEditor(from settings: StandingBenchAnalystRuntimeSettings?) {
        let settings = settings ?? StandingBenchAnalystRuntimeSettings.default(now: Date())
        standingBenchAnalystProviderKind = settings.providerKind
        standingBenchAnalystCredentialProfileId = settings.credentialProfileId
        standingBenchAnalystRuntimeIdentifier = settings.runtimeIdentifier
        standingBenchAnalystReasoningModeSelection = PMReasoningModeSelection(reasoningMode: settings.reasoningMode)
        standingBenchAnalystRuntimeValidationPreview = nil
    }

    private func validateStandingBenchAnalystRuntimeSettings() {
        Task { @MainActor in
            let validation = await appModel.validateStandingBenchAnalystRuntimeCandidate(
                runtimeIdentifier: standingBenchAnalystRuntimeIdentifier,
                reasoningMode: standingBenchAnalystReasoningModeSelection.reasoningMode,
                providerKind: standingBenchAnalystProviderKind,
                credentialProfileId: standingBenchAnalystCredentialProfileId
            )
            standingBenchAnalystRuntimeValidationPreview = validation
            standingBenchAnalystRuntimeFeedback = validation.summary
        }
    }

    @ViewBuilder
    private func runtimeOperabilitySummary(_ presentation: RuntimeOperabilityPresentation) -> some View {
        Text("Configuration: \(presentation.configurationLabel) - \(presentation.configurationSummary)")
            .font(.caption)
            .foregroundStyle(runtimeOperabilityColor(presentation))
        Text("Operability: \(presentation.operabilityLabel) - \(presentation.operabilitySummary)")
            .font(.caption)
            .foregroundStyle(runtimeOperabilityColor(presentation))
        if let actualRuntimeSummary = presentation.actualRuntimeSummary {
            Text(actualRuntimeSummary)
                .font(.caption)
                .foregroundStyle(presentation.degradedModeActive ? .orange : .secondary)
        }
        if let checkedAt = presentation.checkedAt {
            let checkedBy = presentation.checkedBy ?? "the app"
            Text("Last checked by \(checkedBy) on \(checkedAt.formatted(date: .abbreviated, time: .shortened)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func runtimeOperabilityColor(_ presentation: RuntimeOperabilityPresentation) -> Color {
        switch presentation.state {
        case .primaryHealthy:
            return .green
        case .configuredNotChecked, .configurationNeedsReview:
            return .orange
        case .fallbackActive:
            return .orange
        case .configurationInvalid, .unavailable, .authFailure, .networkFailure:
            return .red
        }
    }

    private func validationColor(_ validation: RuntimeValidationRecord) -> Color {
        switch validation.status {
        case .valid:
            return .green
        case .warning:
            return .orange
        case .invalid:
            return .red
        }
    }

    private func feedbackColor(
        feedback: String,
        preview: RuntimeValidationRecord?
    ) -> Color {
        if feedback.hasPrefix("Saved") {
            return .green
        }
        if let preview {
            return validationColor(preview)
        }
        return .red
    }
}
