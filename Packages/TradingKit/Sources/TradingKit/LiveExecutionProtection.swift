import Foundation
import LocalAuthentication

public enum LocalUserPresenceAuthorizationStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case success
    case canceled
    case failed
    case unavailable
    case systemError
}

public enum LocalUserPresenceOperation: String, Codable, Sendable, Equatable {
    case liveOrderSubmission
    case liveOrderReplacement
    case disableLiveExecutionProtection
    case testLiveExecutionProtection
}

public struct LocalUserPresenceChallenge: Sendable, Equatable {
    public let operation: LocalUserPresenceOperation
    public let localizedReason: String
    public let safeContextSummary: String

    public init(
        operation: LocalUserPresenceOperation,
        localizedReason: String,
        safeContextSummary: String
    ) {
        self.operation = operation
        self.localizedReason = localizedReason
        self.safeContextSummary = safeContextSummary
    }
}

public struct LocalUserPresenceAuthorizationResult: Codable, Sendable, Equatable {
    public let status: LocalUserPresenceAuthorizationStatus
    public let summary: String
    public let checkedAt: Date

    public init(
        status: LocalUserPresenceAuthorizationStatus,
        summary: String,
        checkedAt: Date
    ) {
        self.status = status
        self.summary = summary
        self.checkedAt = checkedAt
    }

    public var authorized: Bool {
        status == .success
    }

    public static func success(
        summary: String = "Local macOS authentication succeeded.",
        checkedAt: Date = Date()
    ) -> LocalUserPresenceAuthorizationResult {
        LocalUserPresenceAuthorizationResult(
            status: .success,
            summary: summary,
            checkedAt: checkedAt
        )
    }
}

public protocol LocalUserPresenceAuthorizing: Sendable {
    func authorize(
        challenge: LocalUserPresenceChallenge
    ) async -> LocalUserPresenceAuthorizationResult
}

public final class MacLocalAuthenticationAuthorizer: LocalUserPresenceAuthorizing, @unchecked Sendable {
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public func authorize(
        challenge: LocalUserPresenceChallenge
    ) async -> LocalUserPresenceAuthorizationResult {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Mac Password"
        context.touchIDAuthenticationAllowableReuseDuration = 0

        var availabilityError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &availabilityError) else {
            return LocalUserPresenceAuthorizationResult(
                status: .unavailable,
                summary: Self.summary(
                    prefix: "Local macOS authentication is unavailable",
                    error: availabilityError
                ),
                checkedAt: now()
            )
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: challenge.localizedReason
            ) { success, error in
                let status: LocalUserPresenceAuthorizationStatus
                let summary: String
                if success {
                    status = .success
                    summary = "Local macOS authentication succeeded."
                } else {
                    status = Self.status(for: error)
                    summary = Self.summary(prefix: "Local macOS authentication did not authorize the request", error: error)
                }
                continuation.resume(
                    returning: LocalUserPresenceAuthorizationResult(
                        status: status,
                        summary: summary,
                        checkedAt: self.now()
                    )
                )
            }
        }
    }

    private static func status(for error: Error?) -> LocalUserPresenceAuthorizationStatus {
        guard let error else {
            return .failed
        }
        let nsError = error as NSError
        guard nsError.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: nsError.code)
        else {
            return .systemError
        }
        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return .canceled
        case .authenticationFailed, .userFallback:
            return .failed
        case .biometryNotAvailable,
             .biometryNotEnrolled,
             .biometryLockout,
             .biometryDisconnected,
             .biometryNotPaired,
             .passcodeNotSet,
             .notInteractive,
             .companionNotAvailable:
            return .unavailable
        default:
            return .systemError
        }
    }

    private static func summary(prefix: String, error: Error?) -> String {
        guard let error else {
            return "\(prefix)."
        }
        let nsError = error as NSError
        if nsError.domain == LAError.errorDomain,
           let code = LAError.Code(rawValue: nsError.code) {
            return "\(prefix): \(readableLAErrorCode(code))."
        }
        return "\(prefix): system_error."
    }

    private static func readableLAErrorCode(_ code: LAError.Code) -> String {
        switch code {
        case .userCancel:
            return "user_canceled"
        case .appCancel:
            return "app_canceled"
        case .systemCancel:
            return "system_canceled"
        case .authenticationFailed:
            return "authentication_failed"
        case .userFallback:
            return "fallback_unavailable"
        case .biometryNotAvailable:
            return "biometry_not_available"
        case .biometryNotEnrolled:
            return "biometry_not_enrolled"
        case .biometryLockout:
            return "biometry_locked"
        case .biometryDisconnected:
            return "biometry_disconnected"
        case .biometryNotPaired:
            return "biometry_not_paired"
        case .passcodeNotSet:
            return "passcode_not_set"
        case .notInteractive:
            return "not_interactive"
        case .companionNotAvailable:
            return "companion_not_available"
        default:
            return "system_error"
        }
    }
}

public struct LiveExecutionProtectionSettings: Codable, Sendable, Equatable, Identifiable {
    public static let singletonID = "live-execution-protection"

    public var id: String { settingsId }

    public var settingsId: String
    public var localUserPresenceRequiredForLiveOrders: Bool
    public var updatedBy: String
    public var updateSource: AuditEventSource
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        settingsId: String = Self.singletonID,
        localUserPresenceRequiredForLiveOrders: Bool,
        updatedBy: String,
        updateSource: AuditEventSource,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.settingsId = settingsId
        self.localUserPresenceRequiredForLiveOrders = localUserPresenceRequiredForLiveOrders
        self.updatedBy = updatedBy
        self.updateSource = updateSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func `default`(now: Date) -> LiveExecutionProtectionSettings {
        LiveExecutionProtectionSettings(
            localUserPresenceRequiredForLiveOrders: false,
            updatedBy: "system",
            updateSource: .system,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func conservativeFallback(now: Date) -> LiveExecutionProtectionSettings {
        LiveExecutionProtectionSettings(
            localUserPresenceRequiredForLiveOrders: true,
            updatedBy: "system",
            updateSource: .system,
            createdAt: now,
            updatedAt: now
        )
    }

    public func updating(
        required: Bool,
        updatedBy: String,
        updateSource: AuditEventSource,
        now: Date
    ) -> LiveExecutionProtectionSettings {
        LiveExecutionProtectionSettings(
            settingsId: Self.singletonID,
            localUserPresenceRequiredForLiveOrders: required,
            updatedBy: updatedBy,
            updateSource: updateSource,
            createdAt: createdAt,
            updatedAt: now
        )
    }
}

public struct LiveExecutionProtectionUpdateResult: Sendable, Equatable {
    public let settings: LiveExecutionProtectionSettings
    public let authorizationResult: LocalUserPresenceAuthorizationResult?
    public let applied: Bool
    public let summary: String
}

public actor LiveExecutionProtectionSettingsStore {
    private struct PersistedSettingsV1: Codable {
        let schemaVersion: Int
        let settings: LiveExecutionProtectionSettings
    }

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var settings: LiveExecutionProtectionSettings?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("settings", isDirectory: true)
            .appendingPathComponent("live_execution_protection.json", isDirectory: false)
        self.now = now
    }

    public func loadOrDefault() -> LiveExecutionProtectionSettings {
        loadIfNeeded()
        return settings ?? .default(now: now())
    }

    public func fileLocation() -> URL {
        fileURL
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    @discardableResult
    public func upsert(_ newSettings: LiveExecutionProtectionSettings) throws -> LiveExecutionProtectionSettings {
        loadIfNeeded()
        let existing = settings
        var updated = newSettings
        updated.settingsId = LiveExecutionProtectionSettings.singletonID
        updated.createdAt = existing?.createdAt ?? newSettings.createdAt
        updated.updatedAt = now()
        settings = updated
        try persist(updated)
        return updated
    }

    private func loadIfNeeded() {
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
        } catch let error as LiveExecutionProtectionSettingsStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append("live execution protection settings skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)")
            case .invalidDocument:
                loadDiagnostics.append("live execution protection settings skipped file=\(fileURL.lastPathComponent) code=invalid_document")
            }
            settings = .conservativeFallback(now: now())
        } catch {
            loadDiagnostics.append("live execution protection settings skipped file=\(fileURL.lastPathComponent) code=io_failure")
            settings = .conservativeFallback(now: now())
        }
    }

    private func persist(_ settings: LiveExecutionProtectionSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try Self.makeEncoder().encode(
            PersistedSettingsV1(schemaVersion: 1, settings: settings)
        )
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private static func decodeSettings(from data: Data) throws -> LiveExecutionProtectionSettings {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(SchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw LiveExecutionProtectionSettingsStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedSettingsV1.self, from: data).settings
            } catch {
                throw LiveExecutionProtectionSettingsStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(LiveExecutionProtectionSettings.self, from: data)
        } catch {
            throw LiveExecutionProtectionSettingsStoreError.invalidDocument
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return decoder
    }
}

public enum LiveExecutionProtectionSettingsStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public func liveExecutionProtectionConfirmedAppTruthLine(
    settings: LiveExecutionProtectionSettings
) -> String {
    let state = settings.localUserPresenceRequiredForLiveOrders ? "enabled" : "disabled"
    return "Confirmed Live execution local-auth protection in app truth: \(state). When enabled, this Mac requires Touch ID or Mac password immediately before Live NEW/REPLACE order submission; Paper trading is unaffected; CANCEL remains available for risk reduction; disabling the protection requires local macOS authentication."
}

public func liveOrderSubmissionChallenge(
    symbol: String,
    side: OrderSide,
    orderType: OrderType,
    qty: Int
) -> LocalUserPresenceChallenge {
    let safeSymbol = safeChallengeToken(symbol.uppercased(), fallback: "symbol")
    let safeSide = side.rawValue.lowercased()
    let safeType = orderType.rawValue.lowercased()
    let safeQty = max(qty, 0)
    let reason = "Authorize Live \(safeSide) \(safeType) order submission for \(safeQty) \(safeSymbol)."
    return LocalUserPresenceChallenge(
        operation: .liveOrderSubmission,
        localizedReason: reason,
        safeContextSummary: "live_new symbol=\(safeSymbol) side=\(safeSide) type=\(safeType) qty=\(safeQty)"
    )
}

public func liveOrderReplacementChallenge(orderID: String) -> LocalUserPresenceChallenge {
    let safeID = shortSafeChallengeIdentifier(orderID)
    let reason = "Authorize Live order replacement for order \(safeID)."
    return LocalUserPresenceChallenge(
        operation: .liveOrderReplacement,
        localizedReason: reason,
        safeContextSummary: "live_replace order_id=\(safeID)"
    )
}

public func disableLiveExecutionProtectionChallenge() -> LocalUserPresenceChallenge {
    LocalUserPresenceChallenge(
        operation: .disableLiveExecutionProtection,
        localizedReason: "Authorize disabling local macOS authentication for Live order submission.",
        safeContextSummary: "disable_live_execution_protection"
    )
}

public func testLiveExecutionProtectionChallenge() -> LocalUserPresenceChallenge {
    LocalUserPresenceChallenge(
        operation: .testLiveExecutionProtection,
        localizedReason: "Test local macOS authentication for Live execution protection.",
        safeContextSummary: "test_live_execution_protection"
    )
}

private func safeChallengeToken(_ raw: String, fallback: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
    let filtered = raw.unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "_"
    }
    let collapsed = String(filtered)
        .trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
    if collapsed.isEmpty {
        return fallback
    }
    return String(collapsed.prefix(24))
}

private func shortSafeChallengeIdentifier(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else {
        return "unknown"
    }
    return String(safeChallengeToken(trimmed, fallback: "order").prefix(12))
}
