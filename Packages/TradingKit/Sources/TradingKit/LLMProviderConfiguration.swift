import Foundation

public enum LLMProviderKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        }
    }

    public var defaultCredentialProfileId: String {
        switch self {
        case .openAI:
            return LLMCredentialProfile.openAIDefaultProfileID
        case .anthropic:
            return LLMCredentialProfile.anthropicDefaultProfileID
        }
    }
}

public enum LLMProviderAuthKind: String, Codable, Sendable, CaseIterable {
    case apiKeyKeychain = "api_key_keychain"
    case officialOAuthDeferred = "official_oauth_deferred"
}

public enum LLMProviderSettingsUpdateSource: String, Codable, Sendable, CaseIterable {
    case systemDefault = "system_default"
    case migration
    case userEdited = "user_edited"
}

public enum LLMCredentialLookupKind: String, Codable, Sendable, CaseIterable {
    case serviceAccount = "service_account"
    case labelAccount = "label_account"
}

public enum LLMCredentialProfileSettingsVisibility: String, Codable, Sendable, CaseIterable {
    case main
    case hiddenMigrationAlias = "hidden_migration_alias"
}

public struct LLMCredentialLegacyAlias: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(lookupKind.rawValue):\(serviceOrLabel):\(account)" }

    public var serviceOrLabel: String
    public var account: String
    public var lookupKind: LLMCredentialLookupKind

    public init(
        serviceOrLabel: String,
        account: String,
        lookupKind: LLMCredentialLookupKind
    ) {
        self.serviceOrLabel = serviceOrLabel
        self.account = account
        self.lookupKind = lookupKind
    }
}

public struct LLMCredentialProfile: Codable, Sendable, Equatable, Identifiable {
    public static let openAIDefaultProfileID = "openai-default"
    public static let openAILegacyProfileID = "openai-legacy-openai-api-key"
    public static let anthropicDefaultProfileID = "anthropic-default"

    public var id: String { profileId }

    public var profileId: String
    public var providerKind: LLMProviderKind
    public var displayName: String
    public var authKind: LLMProviderAuthKind
    public var keychainService: String
    public var keychainAccount: String
    public var legacyAliases: [LLMCredentialLegacyAlias]
    public var enabled: Bool
    public var settingsVisibility: LLMCredentialProfileSettingsVisibility
    public var updatedBy: String
    public var updateSource: LLMProviderSettingsUpdateSource
    public var createdAt: Date
    public var updatedAt: Date

    public var isVisibleInMainSettings: Bool {
        settingsVisibility == .main
    }

    public init(
        profileId: String,
        providerKind: LLMProviderKind,
        displayName: String,
        authKind: LLMProviderAuthKind = .apiKeyKeychain,
        keychainService: String,
        keychainAccount: String,
        legacyAliases: [LLMCredentialLegacyAlias] = [],
        enabled: Bool = true,
        settingsVisibility: LLMCredentialProfileSettingsVisibility = .main,
        updatedBy: String,
        updateSource: LLMProviderSettingsUpdateSource,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.profileId = profileId
        self.providerKind = providerKind
        self.displayName = displayName
        self.authKind = authKind
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
        self.legacyAliases = legacyAliases
        self.enabled = enabled
        self.settingsVisibility = settingsVisibility
        self.updatedBy = updatedBy
        self.updateSource = updateSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case profileId
        case providerKind
        case displayName
        case authKind
        case keychainService
        case keychainAccount
        case legacyAliases
        case enabled
        case settingsVisibility
        case updatedBy
        case updateSource
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileId = try container.decode(String.self, forKey: .profileId)
        providerKind = try container.decode(LLMProviderKind.self, forKey: .providerKind)
        displayName = try container.decode(String.self, forKey: .displayName)
        authKind = try container.decode(LLMProviderAuthKind.self, forKey: .authKind)
        keychainService = try container.decode(String.self, forKey: .keychainService)
        keychainAccount = try container.decode(String.self, forKey: .keychainAccount)
        legacyAliases = try container.decodeIfPresent([LLMCredentialLegacyAlias].self, forKey: .legacyAliases) ?? []
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        settingsVisibility = try container.decodeIfPresent(
            LLMCredentialProfileSettingsVisibility.self,
            forKey: .settingsVisibility
        ) ?? .main
        updatedBy = try container.decode(String.self, forKey: .updatedBy)
        updateSource = try container.decode(LLMProviderSettingsUpdateSource.self, forKey: .updateSource)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public static func defaultOpenAI(now: Date) -> LLMCredentialProfile {
        LLMCredentialProfile(
            profileId: openAIDefaultProfileID,
            providerKind: .openAI,
            displayName: "OpenAI default",
            keychainService: OpenAIKeychainCredentialResolver.canonicalService,
            keychainAccount: OpenAIKeychainCredentialResolver.account,
            legacyAliases: OpenAIKeychainCredentialResolver.legacyServices.flatMap { legacyService in
                [
                    LLMCredentialLegacyAlias(
                        serviceOrLabel: legacyService,
                        account: OpenAIKeychainCredentialResolver.account,
                        lookupKind: .serviceAccount
                    ),
                    LLMCredentialLegacyAlias(
                        serviceOrLabel: legacyService,
                        account: OpenAIKeychainCredentialResolver.account,
                        lookupKind: .labelAccount
                    )
                ]
            },
            updatedBy: "system",
            updateSource: .migration,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func legacyOpenAI(now: Date) -> LLMCredentialProfile {
        LLMCredentialProfile(
            profileId: openAILegacyProfileID,
            providerKind: .openAI,
            displayName: "OpenAI legacy alias",
            keychainService: OpenAIKeychainCredentialResolver.legacyServices.first ?? "openai_api_key",
            keychainAccount: OpenAIKeychainCredentialResolver.account,
            enabled: true,
            settingsVisibility: .hiddenMigrationAlias,
            updatedBy: "system",
            updateSource: .migration,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func defaultAnthropic(now: Date) -> LLMCredentialProfile {
        LLMCredentialProfile(
            profileId: anthropicDefaultProfileID,
            providerKind: .anthropic,
            displayName: "Anthropic default",
            keychainService: "anthropic_api_key",
            keychainAccount: "algo-trading",
            updatedBy: "system",
            updateSource: .systemDefault,
            createdAt: now,
            updatedAt: now
        )
    }
}

public struct LLMProviderSettings: Codable, Sendable, Equatable, Identifiable {
    public static let singletonID = "llm-provider-settings"

    public var id: String { settingsId }

    public var settingsId: String
    public var credentialProfiles: [LLMCredentialProfile]
    public var updatedBy: String
    public var updateSource: LLMProviderSettingsUpdateSource
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        settingsId: String = LLMProviderSettings.singletonID,
        credentialProfiles: [LLMCredentialProfile],
        updatedBy: String,
        updateSource: LLMProviderSettingsUpdateSource,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.settingsId = settingsId
        self.credentialProfiles = credentialProfiles
        self.updatedBy = updatedBy
        self.updateSource = updateSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func `default`(now: Date) -> LLMProviderSettings {
        LLMProviderSettings(
            credentialProfiles: [
                .defaultOpenAI(now: now),
                .legacyOpenAI(now: now),
                .defaultAnthropic(now: now)
            ],
            updatedBy: "system",
            updateSource: .migration,
            createdAt: now,
            updatedAt: now
        )
    }

    public func profile(id profileId: String) -> LLMCredentialProfile? {
        credentialProfiles.first { $0.profileId == profileId }
    }

    public func profiles(for providerKind: LLMProviderKind) -> [LLMCredentialProfile] {
        credentialProfiles
            .filter { $0.providerKind == providerKind }
            .sorted { lhs, rhs in
                if lhs.profileId == providerKind.defaultCredentialProfileId {
                    return true
                }
                if rhs.profileId == providerKind.defaultCredentialProfileId {
                    return false
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    public var mainSettingsCredentialProfiles: [LLMCredentialProfile] {
        credentialProfiles.filter(\.isVisibleInMainSettings)
    }

    public func mainSettingsProfiles(for providerKind: LLMProviderKind) -> [LLMCredentialProfile] {
        profiles(for: providerKind).filter(\.isVisibleInMainSettings)
    }
}

public enum LLMCredentialResolutionStatus: String, Codable, Sendable, CaseIterable {
    case ready
    case missingKey = "missing_key"
    case emptyKey = "empty_key"
    case disabled
    case unsupportedAuth = "unsupported_auth"
}

public enum LLMCredentialResolutionSource: String, Codable, Sendable, CaseIterable {
    case configuredServiceAccount = "configured_service_account"
    case configuredLabelAccount = "configured_label_account"
    case legacyServiceAccount = "legacy_service_account"
    case legacyLabelAccount = "legacy_label_account"
}

public struct LLMCredentialResolution: Sendable, Equatable {
    public var status: LLMCredentialResolutionStatus
    public var apiKey: String?
    public var profileId: String
    public var providerKind: LLMProviderKind
    public var source: LLMCredentialResolutionSource?
    public var matchedServiceOrLabel: String?
    public var account: String
    public var summary: String

    public init(
        status: LLMCredentialResolutionStatus,
        apiKey: String? = nil,
        profileId: String,
        providerKind: LLMProviderKind,
        source: LLMCredentialResolutionSource? = nil,
        matchedServiceOrLabel: String? = nil,
        account: String,
        summary: String
    ) {
        self.status = status
        self.apiKey = apiKey
        self.profileId = profileId
        self.providerKind = providerKind
        self.source = source
        self.matchedServiceOrLabel = matchedServiceOrLabel
        self.account = account
        self.summary = summary
    }

    public var isReady: Bool {
        status == .ready
    }

    public var synthesisIssueSummary: String? {
        switch status {
        case .ready:
            return nil
        case .missingKey:
            return "\(providerKind.rawValue)_api_key_missing"
        case .emptyKey:
            return "\(providerKind.rawValue)_api_key_empty"
        case .disabled:
            return "\(providerKind.rawValue)_credential_profile_disabled"
        case .unsupportedAuth:
            return "\(providerKind.rawValue)_credential_auth_unsupported"
        }
    }

    public var fallbackStatus: String {
        switch status {
        case .ready:
            return "\(providerKind.rawValue)_ready"
        case .missingKey:
            return "fallback_missing_\(providerKind.rawValue)_key"
        case .emptyKey, .disabled, .unsupportedAuth:
            return "fallback_\(providerKind.rawValue)_key_unavailable"
        }
    }
}

public struct LLMCredentialReadiness: Codable, Sendable, Equatable {
    public var status: LLMCredentialResolutionStatus
    public var profileId: String
    public var providerKind: LLMProviderKind
    public var matchedServiceOrLabel: String?
    public var account: String
    public var summary: String
    public var checkedAt: Date

    public init(
        status: LLMCredentialResolutionStatus,
        profileId: String,
        providerKind: LLMProviderKind,
        matchedServiceOrLabel: String? = nil,
        account: String,
        summary: String,
        checkedAt: Date
    ) {
        self.status = status
        self.profileId = profileId
        self.providerKind = providerKind
        self.matchedServiceOrLabel = matchedServiceOrLabel
        self.account = account
        self.summary = summary
        self.checkedAt = checkedAt
    }

    public init(resolution: LLMCredentialResolution, checkedAt: Date) {
        self.init(
            status: resolution.status,
            profileId: resolution.profileId,
            providerKind: resolution.providerKind,
            matchedServiceOrLabel: resolution.matchedServiceOrLabel,
            account: resolution.account,
            summary: resolution.summary,
            checkedAt: checkedAt
        )
    }

    public var isReady: Bool {
        status == .ready
    }
}

public protocol LLMCredentialResolving: Sendable {
    func resolve(profile: LLMCredentialProfile) -> LLMCredentialResolution
}

public struct LLMKeychainCredentialResolver: LLMCredentialResolving, Sendable {
    private let keychainProvider: KeychainCredentialsProvider
    private let labelReader: @Sendable (String, String) -> String?

    public init(
        keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider(),
        labelReader: @escaping @Sendable (String, String) -> String? = SystemKeyReader.readKey(label:account:)
    ) {
        self.keychainProvider = keychainProvider
        self.labelReader = labelReader
    }

    public func resolve(profile: LLMCredentialProfile) -> LLMCredentialResolution {
        guard profile.enabled else {
            return LLMCredentialResolution(
                status: .disabled,
                profileId: profile.profileId,
                providerKind: profile.providerKind,
                account: profile.keychainAccount,
                summary: "\(profile.displayName) is disabled."
            )
        }

        guard profile.authKind == .apiKeyKeychain else {
            return LLMCredentialResolution(
                status: .unsupportedAuth,
                profileId: profile.profileId,
                providerKind: profile.providerKind,
                account: profile.keychainAccount,
                summary: "\(profile.displayName) uses an auth mode that is recorded for future support but not available for live execution in this app."
            )
        }

        let attempts: [(String, String, LLMCredentialResolutionSource, LLMCredentialLookupKind)] = [
            (profile.keychainService, profile.keychainAccount, .configuredServiceAccount, .serviceAccount),
            (profile.keychainService, profile.keychainAccount, .configuredLabelAccount, .labelAccount)
        ] + profile.legacyAliases.map { alias in
            let source: LLMCredentialResolutionSource = alias.lookupKind == .serviceAccount
                ? .legacyServiceAccount
                : .legacyLabelAccount
            return (alias.serviceOrLabel, alias.account, source, alias.lookupKind)
        }

        for attempt in attempts {
            if let resolution = resolveAttempt(
                profile: profile,
                serviceOrLabel: attempt.0,
                account: attempt.1,
                source: attempt.2,
                lookupKind: attempt.3
            ) {
                return resolution
            }
        }

        return LLMCredentialResolution(
            status: .missingKey,
            profileId: profile.profileId,
            providerKind: profile.providerKind,
            account: profile.keychainAccount,
            summary: "No \(profile.providerKind.displayName) API key was found in Keychain for service \(profile.keychainService) account \(profile.keychainAccount)."
        )
    }

    private func resolveAttempt(
        profile: LLMCredentialProfile,
        serviceOrLabel: String,
        account: String,
        source: LLMCredentialResolutionSource,
        lookupKind: LLMCredentialLookupKind
    ) -> LLMCredentialResolution? {
        let rawValue: String?
        switch lookupKind {
        case .serviceAccount:
            rawValue = keychainProvider.readKey(service: serviceOrLabel, account: account)
        case .labelAccount:
            rawValue = labelReader(serviceOrLabel, account)
        }

        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return LLMCredentialResolution(
                status: .emptyKey,
                profileId: profile.profileId,
                providerKind: profile.providerKind,
                source: source,
                matchedServiceOrLabel: serviceOrLabel,
                account: account,
                summary: "\(profile.providerKind.displayName) Keychain item \(serviceOrLabel) account \(account) exists but its value is empty."
            )
        }

        return LLMCredentialResolution(
            status: .ready,
            apiKey: trimmed,
            profileId: profile.profileId,
            providerKind: profile.providerKind,
            source: source,
            matchedServiceOrLabel: serviceOrLabel,
            account: account,
            summary: "\(profile.providerKind.displayName) API key resolved from Keychain service/label \(serviceOrLabel) account \(account)."
        )
    }
}

public enum LLMProviderSettingsStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
    case profileNotFound(id: String)
}

public final class LLMProviderSettingsStore: @unchecked Sendable {
    private struct PersistedProviderSettingsV1: Codable {
        let schemaVersion: Int
        let settings: LLMProviderSettings
    }

    private struct PersistedProviderSettingsProbe: Decodable {
        let schemaVersion: Int?
    }

    private let lock = NSLock()
    private let fileManager: FileManager
    private let fileURL: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var settings: LLMProviderSettings?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("settings", isDirectory: true)
            .appendingPathComponent("llm_provider_settings.json", isDirectory: false)
        self.now = now
    }

    public func loadOrDefault() throws -> LLMProviderSettings {
        lock.lock()
        defer { lock.unlock() }
        try loadIfNeededLocked()
        return settings ?? .default(now: now())
    }

    public func load() throws -> LLMProviderSettings? {
        lock.lock()
        defer { lock.unlock() }
        try loadIfNeededLocked()
        return settings
    }

    @discardableResult
    public func upsert(_ settings: LLMProviderSettings) throws -> LLMProviderSettings {
        lock.lock()
        defer { lock.unlock() }
        try loadIfNeededLocked()
        let existing = self.settings
        var updated = normalized(settings, existing: existing)
        updated.createdAt = existing?.createdAt ?? settings.createdAt
        updated.updatedAt = now()
        self.settings = updated
        try persistLocked(updated)
        return updated
    }

    @discardableResult
    public func upsertProfile(_ profile: LLMCredentialProfile) throws -> LLMProviderSettings {
        lock.lock()
        defer { lock.unlock() }
        try loadIfNeededLocked()
        var current = settings ?? .default(now: now())
        var profiles = current.credentialProfiles.filter { $0.profileId != profile.profileId }
        var updatedProfile = profile
        updatedProfile.updatedAt = now()
        profiles.append(updatedProfile)
        current.credentialProfiles = profiles
        current.updatedBy = updatedProfile.updatedBy
        current.updateSource = updatedProfile.updateSource
        current.updatedAt = now()
        let normalizedSettings = normalized(current, existing: settings)
        settings = normalizedSettings
        try persistLocked(normalizedSettings)
        return normalizedSettings
    }

    public func fileLocation() -> URL {
        fileURL
    }

    public func drainLoadDiagnostics() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeededLocked() throws {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: fileURL.path) else {
            settings = nil
            return
        }

        do {
            settings = try Self.decodeSettings(from: Data(contentsOf: fileURL))
        } catch let error as LLMProviderSettingsStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append("llm provider settings skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)")
            case .invalidDocument:
                loadDiagnostics.append("llm provider settings skipped file=\(fileURL.lastPathComponent) code=invalid_document")
            case .profileNotFound:
                loadDiagnostics.append("llm provider settings skipped file=\(fileURL.lastPathComponent) code=profile_not_found")
            }
            settings = nil
        } catch {
            loadDiagnostics.append("llm provider settings skipped file=\(fileURL.lastPathComponent) code=io_failure")
            settings = nil
        }
    }

    private func persistLocked(_ settings: LLMProviderSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try makeProviderSettingsEncoder().encode(
            PersistedProviderSettingsV1(schemaVersion: 1, settings: settings)
        )
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func normalized(
        _ raw: LLMProviderSettings,
        existing: LLMProviderSettings?
    ) -> LLMProviderSettings {
        let now = now()
        let defaults = LLMProviderSettings.default(now: now)
        var profilesByID = Dictionary(uniqueKeysWithValues: defaults.credentialProfiles.map { ($0.profileId, $0) })
        for profile in raw.credentialProfiles {
            var normalizedProfile = profile
            normalizedProfile.profileId = normalizedID(profile.profileId, fallback: UUID().uuidString.lowercased())
            normalizedProfile.displayName = normalizedLabel(profile.displayName, fallback: profile.providerKind.displayName)
            normalizedProfile.keychainService = normalizedLabel(profile.keychainService, fallback: profilesByID[profile.profileId]?.keychainService ?? "")
            normalizedProfile.keychainAccount = normalizedLabel(profile.keychainAccount, fallback: profilesByID[profile.profileId]?.keychainAccount ?? "")
            if normalizedProfile.profileId == LLMCredentialProfile.openAILegacyProfileID {
                normalizedProfile.settingsVisibility = .hiddenMigrationAlias
            }
            normalizedProfile.updatedBy = normalizedLabel(profile.updatedBy, fallback: "unknown")
            profilesByID[normalizedProfile.profileId] = normalizedProfile
        }

        var updated = raw
        updated.settingsId = LLMProviderSettings.singletonID
        updated.credentialProfiles = profilesByID.values.sorted { lhs, rhs in
            if lhs.providerKind.rawValue == rhs.providerKind.rawValue {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.providerKind.rawValue < rhs.providerKind.rawValue
        }
        updated.createdAt = existing?.createdAt ?? raw.createdAt
        updated.updatedBy = normalizedLabel(raw.updatedBy, fallback: "unknown")
        return updated
    }

    private static func decodeSettings(from data: Data) throws -> LLMProviderSettings {
        let decoder = makeProviderSettingsDecoder()
        if let probe = try? decoder.decode(PersistedProviderSettingsProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw LLMProviderSettingsStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedProviderSettingsV1.self, from: data).settings
            } catch {
                throw LLMProviderSettingsStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(LLMProviderSettings.self, from: data)
        } catch {
            throw LLMProviderSettingsStoreError.invalidDocument
        }
    }
}

private func normalizedID(_ raw: String, fallback: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
}

private func normalizedLabel(_ raw: String, fallback: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
}

private func makeProviderSettingsEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}

private func makeProviderSettingsDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}
