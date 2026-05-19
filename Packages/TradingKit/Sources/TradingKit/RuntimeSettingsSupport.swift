import Foundation

public enum RuntimeValidationStatus: String, Codable, Sendable, CaseIterable {
    case valid
    case warning
    case invalid
}

public enum RuntimeValidationCategory: String, Codable, Sendable, CaseIterable {
    case accepted
    case invalidFormat = "invalid_format"
    case invalidSchema = "invalid_schema"
    case unknownRuntimeFamily = "unknown_runtime_family"
    case unavailable
    case authFailure = "auth_failure"
    case networkFailure = "network_failure"
    case providerFailure = "provider_failure"
    case rateLimitOrQuota = "rate_limit_or_quota"
    case requestTooLarge = "request_too_large"
    case malformedResponse = "malformed_response"
    case refusal
    case internalFailure = "internal_failure"
    case unknown
}

public struct RuntimeValidationRecord: Codable, Sendable, Equatable {
    public var status: RuntimeValidationStatus
    public var category: RuntimeValidationCategory
    public var summary: String
    public var checkedAt: Date
    public var checkedBy: String

    public init(
        status: RuntimeValidationStatus,
        category: RuntimeValidationCategory,
        summary: String,
        checkedAt: Date,
        checkedBy: String
    ) {
        self.status = status
        self.category = category
        self.summary = summary
        self.checkedAt = checkedAt
        self.checkedBy = checkedBy
    }
}

public struct LastKnownGoodRuntimeRecord: Codable, Sendable, Equatable {
    public var providerKind: LLMProviderKind?
    public var credentialProfileId: String?
    public var runtimeIdentifier: String
    public var reasoningMode: AnalystRuntimeReasoningMode?
    public var verifiedAt: Date
    public var summary: String

    public init(
        providerKind: LLMProviderKind? = .openAI,
        credentialProfileId: String? = LLMCredentialProfile.openAIDefaultProfileID,
        runtimeIdentifier: String,
        reasoningMode: AnalystRuntimeReasoningMode? = nil,
        verifiedAt: Date,
        summary: String
    ) {
        self.providerKind = providerKind
        self.credentialProfileId = credentialProfileId
        self.runtimeIdentifier = runtimeIdentifier
        self.reasoningMode = reasoningMode
        self.verifiedAt = verifiedAt
        self.summary = summary
    }
}

public struct RuntimeFallbackRecord: Codable, Sendable, Equatable {
    public var configuredProviderKind: LLMProviderKind?
    public var configuredCredentialProfileId: String?
    public var configuredRuntimeIdentifier: String
    public var configuredReasoningMode: AnalystRuntimeReasoningMode?
    public var fallbackProviderKind: LLMProviderKind?
    public var fallbackCredentialProfileId: String?
    public var fallbackRuntimeIdentifier: String
    public var fallbackReasoningMode: AnalystRuntimeReasoningMode?
    public var reasonCategory: RuntimeValidationCategory
    public var reasonSummary: String
    public var occurredAt: Date

    public init(
        configuredProviderKind: LLMProviderKind? = .openAI,
        configuredCredentialProfileId: String? = LLMCredentialProfile.openAIDefaultProfileID,
        configuredRuntimeIdentifier: String,
        configuredReasoningMode: AnalystRuntimeReasoningMode? = nil,
        fallbackProviderKind: LLMProviderKind? = .openAI,
        fallbackCredentialProfileId: String? = LLMCredentialProfile.openAIDefaultProfileID,
        fallbackRuntimeIdentifier: String,
        fallbackReasoningMode: AnalystRuntimeReasoningMode? = nil,
        reasonCategory: RuntimeValidationCategory,
        reasonSummary: String,
        occurredAt: Date
    ) {
        self.configuredProviderKind = configuredProviderKind
        self.configuredCredentialProfileId = configuredCredentialProfileId
        self.configuredRuntimeIdentifier = configuredRuntimeIdentifier
        self.configuredReasoningMode = configuredReasoningMode
        self.fallbackProviderKind = fallbackProviderKind
        self.fallbackCredentialProfileId = fallbackCredentialProfileId
        self.fallbackRuntimeIdentifier = fallbackRuntimeIdentifier
        self.fallbackReasoningMode = fallbackReasoningMode
        self.reasonCategory = reasonCategory
        self.reasonSummary = reasonSummary
        self.occurredAt = occurredAt
    }
}

public struct ResolvedRuntimeSelection: Sendable, Equatable {
    public var configuredProviderKind: LLMProviderKind
    public var configuredCredentialProfileId: String
    public var configuredRuntimeIdentifier: String
    public var configuredReasoningMode: AnalystRuntimeReasoningMode?
    public var effectiveProviderKind: LLMProviderKind
    public var effectiveCredentialProfileId: String
    public var effectiveRuntimeIdentifier: String
    public var effectiveReasoningMode: AnalystRuntimeReasoningMode?
    public var validation: RuntimeValidationRecord
    public var fallbackApplied: Bool
    public var fallback: RuntimeFallbackRecord?

    public init(
        configuredProviderKind: LLMProviderKind = .openAI,
        configuredCredentialProfileId: String = LLMCredentialProfile.openAIDefaultProfileID,
        configuredRuntimeIdentifier: String,
        configuredReasoningMode: AnalystRuntimeReasoningMode? = nil,
        effectiveProviderKind: LLMProviderKind = .openAI,
        effectiveCredentialProfileId: String = LLMCredentialProfile.openAIDefaultProfileID,
        effectiveRuntimeIdentifier: String,
        effectiveReasoningMode: AnalystRuntimeReasoningMode? = nil,
        validation: RuntimeValidationRecord,
        fallbackApplied: Bool,
        fallback: RuntimeFallbackRecord? = nil
    ) {
        self.configuredProviderKind = configuredProviderKind
        self.configuredCredentialProfileId = configuredCredentialProfileId
        self.configuredRuntimeIdentifier = configuredRuntimeIdentifier
        self.configuredReasoningMode = configuredReasoningMode
        self.effectiveProviderKind = effectiveProviderKind
        self.effectiveCredentialProfileId = effectiveCredentialProfileId
        self.effectiveRuntimeIdentifier = effectiveRuntimeIdentifier
        self.effectiveReasoningMode = effectiveReasoningMode
        self.validation = validation
        self.fallbackApplied = fallbackApplied
        self.fallback = fallback
    }
}

public struct RuntimeCapabilityHint: Sendable, Equatable {
    public let summary: String
    public let detail: String

    public init(summary: String, detail: String) {
        self.summary = summary
        self.detail = detail
    }
}

public func openAIRuntimeCapabilityHint(
    runtimeIdentifier: String,
    reasoningMode: AnalystRuntimeReasoningMode?
) -> RuntimeCapabilityHint? {
    let normalized = runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let reasoningLabel = reasoningMode?.rawValue ?? "default"

    switch normalized {
    case "gpt-5.4":
        return RuntimeCapabilityHint(
            summary: "Model capability hint: `gpt-5.4` currently exposes a 1M-token context window and 128K max output.",
            detail: "Reasoning is set to \(reasoningLabel). The selected reasoning effort changes how much internal reasoning the model may use inside that same window; it does not switch the model onto a separate larger context window."
        )
    case "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5":
        return RuntimeCapabilityHint(
            summary: "Model capability hint: `\(runtimeIdentifier)` currently exposes a 400K-token context window and 128K max output.",
            detail: "Reasoning is set to \(reasoningLabel). The selected reasoning effort changes internal reasoning depth and token usage inside that same window; it does not create a separate context-window tier."
        )
    default:
        return nil
    }
}
