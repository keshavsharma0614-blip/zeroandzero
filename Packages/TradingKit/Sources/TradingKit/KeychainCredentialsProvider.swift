import Foundation
import LocalAuthentication
import Security

public protocol KeyReading: Sendable {
    func readKey(service: String, account: String) -> String?
}

public final class KeychainCredentialSessionCache: @unchecked Sendable {
    private struct CachedValue {
        var value: String?
    }

    private let lock = NSLock()
    private var values: [String: CachedValue] = [:]

    public init() {}

    public func read(
        service: String,
        account: String,
        loader: () -> String?
    ) -> String? {
        let key = "\(service)\u{1f}\(account)"
        lock.lock()
        if let cached = values[key] {
            lock.unlock()
            return cached.value
        }
        lock.unlock()

        let loaded = loader()

        lock.lock()
        values[key] = CachedValue(value: loaded)
        lock.unlock()

        return loaded
    }

    public func clear() {
        lock.lock()
        values.removeAll()
        lock.unlock()
    }
}

public struct KeychainCredentialsProvider: Sendable {
    private let keyReader: any KeyReading
    private let now: @Sendable () -> Date
    private let sessionCache: KeychainCredentialSessionCache?

    public init(
        keyReader: any KeyReading = SystemKeyReader(),
        now: @escaping @Sendable () -> Date = Date.init,
        sessionCache: KeychainCredentialSessionCache? = KeychainCredentialSessionCache()
    ) {
        self.keyReader = keyReader
        self.now = now
        self.sessionCache = sessionCache
    }

    public func readKey(service: String, account: String) -> String? {
        if let sessionCache {
            return sessionCache.read(service: service, account: account) {
                keyReader.readKey(service: service, account: account)
            }
        }
        return keyReader.readKey(service: service, account: account)
    }

    public func clearSessionCache() {
        sessionCache?.clear()
    }

    public func credentials(for environment: Environment) -> (publicKey: String, secretKey: String)? {
        let publicKey = readKey(
            service: KeychainLocation.publicService,
            account: account(for: environment)
        )
        let secretKey = readKey(
            service: KeychainLocation.secretService,
            account: account(for: environment)
        )

        guard let publicKey, let secretKey else {
            return nil
        }
        return (publicKey: publicKey, secretKey: secretKey)
    }

    public func alpacaCredentialReadiness(for environment: Environment) -> AlpacaCredentialReadiness {
        let publicKeyFound = readKey(
            service: KeychainLocation.publicService,
            account: account(for: environment)
        ) != nil
        let secretKeyFound = readKey(
            service: KeychainLocation.secretService,
            account: account(for: environment)
        ) != nil
        return AlpacaCredentialReadiness(
            environment: environment,
            publicKeyFound: publicKeyFound,
            secretKeyFound: secretKeyFound,
            checkedAt: now()
        )
    }

    public func credentialStatus() -> CredentialsStatus {
        let paperPublic = readKey(
            service: KeychainLocation.publicService,
            account: account(for: .paper)
        ) != nil
        let paperSecret = readKey(
            service: KeychainLocation.secretService,
            account: account(for: .paper)
        ) != nil
        let livePublic = readKey(
            service: KeychainLocation.publicService,
            account: account(for: .live)
        ) != nil
        let liveSecret = readKey(
            service: KeychainLocation.secretService,
            account: account(for: .live)
        ) != nil
        let telegramConfigured = TelegramBotKeychainStatusProvider(
            keychainProvider: self
        ).isConfigured()
        let openAIResolution = OpenAIKeychainCredentialResolver(
            keychainProvider: self
        ).resolve()

        return CredentialsStatus(
            paperPublicFound: paperPublic,
            paperSecretFound: paperSecret,
            livePublicFound: livePublic,
            liveSecretFound: liveSecret,
            telegramConfigured: telegramConfigured,
            openAIConfigured: openAIResolution.isReady,
            openAIStatusSummary: openAIResolution.summary,
            lastChecked: now()
        )
    }

    private func account(for environment: Environment) -> String {
        "algo-trading/\(environment.rawValue)"
    }
}

public struct AlpacaCredentialReadiness: Sendable, Equatable {
    public let environment: Environment
    public let publicKeyFound: Bool
    public let secretKeyFound: Bool
    public let checkedAt: Date

    public init(
        environment: Environment,
        publicKeyFound: Bool,
        secretKeyFound: Bool,
        checkedAt: Date
    ) {
        self.environment = environment
        self.publicKeyFound = publicKeyFound
        self.secretKeyFound = secretKeyFound
        self.checkedAt = checkedAt
    }

    public var isReady: Bool {
        publicKeyFound && secretKeyFound
    }
}

public struct SystemKeyReader: KeyReading {
    public enum AuthenticationUIPolicy: Sendable {
        case allowPrompt
        case failIfPromptRequired
    }

    private let authenticationUIPolicy: AuthenticationUIPolicy

    public init(authenticationUIPolicy: AuthenticationUIPolicy = .allowPrompt) {
        self.authenticationUIPolicy = authenticationUIPolicy
    }

    public func readKey(service: String, account: String) -> String? {
        Self.readKey(
            account: account,
            additionalAttributes: [
                kSecAttrService: service
            ],
            authenticationUIPolicy: authenticationUIPolicy
        )
    }

    public static func readKey(label: String, account: String) -> String? {
        readKey(
            account: account,
            additionalAttributes: [
                kSecAttrLabel: label
            ],
            authenticationUIPolicy: .allowPrompt
        )
    }

    public static func readKey(
        label: String,
        account: String,
        authenticationUIPolicy: AuthenticationUIPolicy
    ) -> String? {
        readKey(
            account: account,
            additionalAttributes: [
                kSecAttrLabel: label
            ],
            authenticationUIPolicy: authenticationUIPolicy
        )
    }

    private static func readKey(
        account: String,
        additionalAttributes: [CFString: Any],
        authenticationUIPolicy: AuthenticationUIPolicy
    ) -> String? {
        guard Self.shouldAllowKeychainRead(
            lookupName: Self.lookupName(from: additionalAttributes),
            account: account,
            processName: ProcessInfo.processInfo.processName,
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        ) else {
            return nil
        }

        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ].merging(additionalAttributes) { _, new in new }

        if authenticationUIPolicy == .failIfPromptRequired {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext] = context
            query[kSecUseAuthenticationUI] = kSecUseAuthenticationUIFail
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func shouldAllowProcessKeychainRead(
        processName: String,
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        if environment["ALGO_TRADING_ALLOW_TEST_KEYCHAIN_READ"] == "1" {
            return true
        }

        if environment["XCTestConfigurationFilePath"] != nil {
            return false
        }

        let lowercasedProcessName = processName.lowercased()
        if lowercasedProcessName.contains("swiftpm-testing-helper")
            || lowercasedProcessName.contains("xctest") {
            return false
        }

        if arguments.contains("--testing-library")
            || arguments.contains(where: { $0.lowercased().contains(".xctest") }) {
            return false
        }

        return true
    }

    static func shouldAllowKeychainRead(
        lookupName: String?,
        account: String,
        processName: String,
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        guard Self.isLLMProviderCredentialLookup(lookupName: lookupName, account: account) else {
            return true
        }

        return Self.shouldAllowProcessKeychainRead(
            processName: processName,
            arguments: arguments,
            environment: environment
        )
    }

    private static func lookupName(from attributes: [CFString: Any]) -> String? {
        if let service = attributes[kSecAttrService] as? String {
            return service
        }
        if let label = attributes[kSecAttrLabel] as? String {
            return label
        }
        return nil
    }

    private static func isLLMProviderCredentialLookup(
        lookupName: String?,
        account: String
    ) -> Bool {
        let normalized = [lookupName, account]
            .compactMap(\.self)
            .joined(separator: " ")
            .lowercased()
        return normalized.contains("anthropic")
            || normalized.contains("openai")
            || normalized.contains("open_api")
    }
}

private enum KeychainLocation {
    static let publicService = "alpaca.api.key"
    static let secretService = "alpaca.secret.key"
}
