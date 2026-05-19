import Foundation

public enum OpenAICredentialResolutionStatus: String, Sendable, Equatable {
    case ready
    case missingKey = "missing_key"
    case emptyKey = "empty_key"
}

public enum OpenAICredentialResolutionSource: String, Sendable, Equatable {
    case canonicalServiceAccount = "canonical_service_account"
    case canonicalLabelAccount = "canonical_label_account"
    case legacyServiceAccount = "legacy_service_account"
    case legacyLabelAccount = "legacy_label_account"
    case configuredProfileServiceAccount = "configured_profile_service_account"
    case configuredProfileLabelAccount = "configured_profile_label_account"
    case inferred
}

public struct OpenAICredentialResolution: Sendable, Equatable {
    public let status: OpenAICredentialResolutionStatus
    public let apiKey: String?
    public let source: OpenAICredentialResolutionSource?
    public let matchedServiceOrLabel: String?
    public let account: String
    public let summary: String

    public init(
        status: OpenAICredentialResolutionStatus,
        apiKey: String? = nil,
        source: OpenAICredentialResolutionSource? = nil,
        matchedServiceOrLabel: String? = nil,
        account: String,
        summary: String
    ) {
        self.status = status
        self.apiKey = apiKey
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
            return "openai_api_key_missing"
        case .emptyKey:
            return "openai_api_key_empty"
        }
    }

    public var fallbackStatus: String {
        switch status {
        case .ready:
            return "openai_responses"
        case .missingKey:
            return "fallback_missing_openai_key"
        case .emptyKey:
            return "fallback_openai_key_unavailable"
        }
    }
}

public protocol OpenAICredentialResolving: Sendable {
    func resolve() -> OpenAICredentialResolution
}

public final class OpenAIKeychainCredentialResolutionCache: @unchecked Sendable {
    public static let shared = OpenAIKeychainCredentialResolutionCache()

    private let lock = NSLock()
    private var resolution: OpenAICredentialResolution?

    public init() {}

    public func load() -> OpenAICredentialResolution? {
        lock.lock()
        defer { lock.unlock() }
        return resolution
    }

    public func store(_ resolution: OpenAICredentialResolution) {
        guard resolution.status == .ready else {
            return
        }
        lock.lock()
        self.resolution = resolution
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        resolution = nil
        lock.unlock()
    }
}

public struct OpenAIKeychainCredentialResolver: OpenAICredentialResolving, Sendable {
    public static let canonicalService = "open_api_key"
    public static let account = "algo-trading"
    public static let legacyServices = ["openai_api_key"]

    private let keychainProvider: KeychainCredentialsProvider
    private let labelReader: @Sendable (String, String) -> String?
    private let providerSettingsStore: LLMProviderSettingsStore?
    private let cache: OpenAIKeychainCredentialResolutionCache?

    public init(
        keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider(),
        labelReader: @escaping @Sendable (String, String) -> String? = SystemKeyReader.readKey(label:account:),
        providerSettingsStore: LLMProviderSettingsStore? = LLMProviderSettingsStore(),
        cache: OpenAIKeychainCredentialResolutionCache? = .shared
    ) {
        self.keychainProvider = keychainProvider
        self.labelReader = labelReader
        self.providerSettingsStore = providerSettingsStore
        self.cache = cache
    }

    public static func clearSharedCache() {
        OpenAIKeychainCredentialResolutionCache.shared.clear()
    }

    public func resolve() -> OpenAICredentialResolution {
        if let cached = cache?.load() {
            return cached
        }

        for attempt in resolutionAttempts() {
            if let resolution = resolve(
                serviceOrLabel: attempt.serviceOrLabel,
                account: attempt.account,
                source: attempt.source,
                readByLabel: attempt.readByLabel
            ) {
                cache?.store(resolution)
                return resolution
            }
        }

        let firstAttempt = resolutionAttempts().first
        return OpenAICredentialResolution(
            status: .missingKey,
            account: firstAttempt?.account ?? Self.account,
            summary: "No OpenAI API key was found in Keychain for service \(firstAttempt?.serviceOrLabel ?? Self.canonicalService) account \(firstAttempt?.account ?? Self.account)."
        )
    }

    private struct ResolutionAttempt {
        let serviceOrLabel: String
        let account: String
        let source: OpenAICredentialResolutionSource
        let readByLabel: Bool
    }

    private func resolutionAttempts() -> [ResolutionAttempt] {
        let settings = (try? providerSettingsStore?.loadOrDefault())
        let profiles = settings?.profiles(for: .openAI).filter(\.enabled) ?? []
        if profiles.isEmpty {
            return Self.defaultResolutionAttempts()
        }

        return profiles.flatMap { profile in
            let primaryServiceSource: OpenAICredentialResolutionSource =
                profile.keychainService == Self.canonicalService && profile.keychainAccount == Self.account
                    ? .canonicalServiceAccount
                    : .configuredProfileServiceAccount
            let primaryLabelSource: OpenAICredentialResolutionSource =
                profile.keychainService == Self.canonicalService && profile.keychainAccount == Self.account
                    ? .canonicalLabelAccount
                    : .configuredProfileLabelAccount
            let primaryAttempts = [
                ResolutionAttempt(
                    serviceOrLabel: profile.keychainService,
                    account: profile.keychainAccount,
                    source: primaryServiceSource,
                    readByLabel: false
                ),
                ResolutionAttempt(
                    serviceOrLabel: profile.keychainService,
                    account: profile.keychainAccount,
                    source: primaryLabelSource,
                    readByLabel: true
                )
            ]
            let aliasAttempts = profile.legacyAliases.map { alias in
                ResolutionAttempt(
                    serviceOrLabel: alias.serviceOrLabel,
                    account: alias.account,
                    source: alias.lookupKind == .serviceAccount ? .legacyServiceAccount : .legacyLabelAccount,
                    readByLabel: alias.lookupKind == .labelAccount
                )
            }
            return primaryAttempts + aliasAttempts
        }
    }

    private static func defaultResolutionAttempts() -> [ResolutionAttempt] {
        [
            ResolutionAttempt(
                serviceOrLabel: canonicalService,
                account: account,
                source: .canonicalServiceAccount,
                readByLabel: false
            ),
            ResolutionAttempt(
                serviceOrLabel: canonicalService,
                account: account,
                source: .canonicalLabelAccount,
                readByLabel: true
            )
        ] + legacyServices.flatMap { legacyService in
            [
                ResolutionAttempt(
                    serviceOrLabel: legacyService,
                    account: account,
                    source: .legacyServiceAccount,
                    readByLabel: false
                ),
                ResolutionAttempt(
                    serviceOrLabel: legacyService,
                    account: account,
                    source: .legacyLabelAccount,
                    readByLabel: true
                )
            ]
        }
    }

    private func resolve(
        serviceOrLabel: String,
        account: String,
        source: OpenAICredentialResolutionSource,
        readByLabel: Bool
    ) -> OpenAICredentialResolution? {
        let rawValue: String?
        if readByLabel {
            rawValue = labelReader(serviceOrLabel, account)
        } else {
            rawValue = keychainProvider.readKey(service: serviceOrLabel, account: account)
        }

        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return OpenAICredentialResolution(
                status: .emptyKey,
                source: source,
                matchedServiceOrLabel: serviceOrLabel,
                account: account,
                summary: "An OpenAI API key item was found in Keychain for \(serviceOrLabel), but its value is empty."
            )
        }

        let qualifier = source == .canonicalServiceAccount || source == .canonicalLabelAccount
            ? "canonical"
            : source == .configuredProfileServiceAccount || source == .configuredProfileLabelAccount
            ? "configured"
            : "legacy"
        return OpenAICredentialResolution(
            status: .ready,
            apiKey: trimmed,
            source: source,
            matchedServiceOrLabel: serviceOrLabel,
            account: account,
            summary: "OpenAI API key resolved from the \(qualifier) Keychain contract for \(serviceOrLabel) account \(account)."
        )
    }
}

func makeOpenAIProviderValidationRecord(
    checkedBy: String,
    now: Date,
    baseValidation: RuntimeValidationRecord,
    credentialResolution: OpenAICredentialResolution
) -> RuntimeValidationRecord {
    guard baseValidation.status != .invalid else {
        return baseValidation
    }

    switch credentialResolution.status {
    case .ready:
        return RuntimeValidationRecord(
            status: baseValidation.status,
            category: baseValidation.category,
            summary: "\(baseValidation.summary) \(credentialResolution.summary) The app can attempt live OpenAI execution for this runtime, but this check does not prove that a live provider request has already succeeded.",
            checkedAt: now,
            checkedBy: checkedBy
        )
    case .missingKey, .emptyKey:
        return RuntimeValidationRecord(
            status: .invalid,
            category: .unavailable,
            summary: "\(baseValidation.summary) \(credentialResolution.summary)",
            checkedAt: now,
            checkedBy: checkedBy
        )
    }
}

func openAIHTTPStatusSummary(_ status: Int) -> String {
    openAIHTTPStatusSummary(status, detail: nil)
}

func openAIHTTPStatusSummary(_ status: Int, detail: String?) -> String {
    let normalizedDetail = detail?
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let loweredDetail = normalizedDetail?.lowercased() ?? ""
    let indicatesInvalidSchema = loweredDetail.contains("invalid_json_schema")
        || loweredDetail.contains("param=text.format.schema")
        || loweredDetail.contains("response_format")
        || loweredDetail.contains("json schema")
    let indicatesOversizedRequest = loweredDetail.contains("context_length")
        || loweredDetail.contains("maximum context")
        || loweredDetail.contains("too many tokens")
        || loweredDetail.contains("input too long")
        || loweredDetail.contains("request too large")
        || loweredDetail.contains("too_large")

    let base: String
    switch status {
    case 401, 403:
        base = "openai_auth_failure_status=\(status)"
    case 404, 422:
        base = "openai_invalid_runtime_status=\(status)"
    case 429:
        base = "openai_rate_limit_or_quota_status=\(status)"
    case 408, 409:
        base = "openai_provider_failure_status=\(status)"
    case 400 where indicatesInvalidSchema:
        base = "openai_invalid_schema_status=\(status)"
    case 400 where indicatesOversizedRequest:
        base = "openai_request_too_large_status=\(status)"
    case 413 where indicatesOversizedRequest:
        base = "openai_request_too_large_status=\(status)"
    case 500..<600:
        base = "openai_provider_failure_status=\(status)"
    default:
        base = "openai_http_status=\(status)"
    }

    guard let normalizedDetail, normalizedDetail.isEmpty == false else {
        return base
    }
    return "\(base) detail=\(openAIResponsesTrimmed(normalizedDetail, limit: 200))"
}

func openAITransportSummary() -> String {
    "openai_network_error"
}

func openAITransportSummary(for error: any Error) -> String {
    if let urlError = error as? URLError {
        return openAITransportSummary(for: urlError.code)
    }

    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
        return openAITransportSummary(for: URLError.Code(rawValue: nsError.code))
    }

    return openAITransportSummary()
}

private func openAITransportSummary(for code: URLError.Code) -> String {
    switch code {
    case .timedOut:
        return "openai_network_error=timed_out"
    case .notConnectedToInternet:
        return "openai_network_error=not_connected_to_internet"
    case .networkConnectionLost:
        return "openai_network_error=connection_lost"
    case .cannotFindHost, .cannotConnectToHost:
        return "openai_network_error=host_unreachable"
    case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
         .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
        return "openai_network_error=tls_failure"
    case .dnsLookupFailed:
        return "openai_network_error=dns_lookup_failed"
    case .cancelled:
        return "openai_network_error=cancelled"
    default:
        return openAITransportSummary()
    }
}
