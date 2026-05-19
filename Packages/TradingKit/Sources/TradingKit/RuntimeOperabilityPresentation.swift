import Foundation

public enum RuntimeOperabilityState: String, Codable, Sendable, Equatable {
    case configuredNotChecked = "configured_not_checked"
    case primaryHealthy = "primary_healthy"
    case configurationNeedsReview = "configuration_needs_review"
    case configurationInvalid = "configuration_invalid"
    case unavailable
    case authFailure = "auth_failure"
    case networkFailure = "network_failure"
    case fallbackActive = "fallback_active"
}

public struct RuntimeOperabilityPresentation: Sendable, Equatable {
    public let state: RuntimeOperabilityState
    public let configurationLabel: String
    public let operabilityLabel: String
    public let configurationSummary: String
    public let operabilitySummary: String
    public let actualRuntimeSummary: String?
    public let checkedAt: Date?
    public let checkedBy: String?
    public let degradedModeActive: Bool
    public let fallbackActive: Bool
    public let ownerSurfaceSummary: String

    public init(
        state: RuntimeOperabilityState,
        configurationLabel: String,
        operabilityLabel: String,
        configurationSummary: String,
        operabilitySummary: String,
        actualRuntimeSummary: String?,
        checkedAt: Date?,
        checkedBy: String?,
        degradedModeActive: Bool,
        fallbackActive: Bool,
        ownerSurfaceSummary: String
    ) {
        self.state = state
        self.configurationLabel = configurationLabel
        self.operabilityLabel = operabilityLabel
        self.configurationSummary = configurationSummary
        self.operabilitySummary = operabilitySummary
        self.actualRuntimeSummary = actualRuntimeSummary
        self.checkedAt = checkedAt
        self.checkedBy = checkedBy
        self.degradedModeActive = degradedModeActive
        self.fallbackActive = fallbackActive
        self.ownerSurfaceSummary = ownerSurfaceSummary
    }
}

public func makeRuntimeOperabilityPresentation(
    scopeLabel: String,
    runtimeIdentifier: String,
    reasoningMode: AnalystRuntimeReasoningMode?,
    validationStatus: RuntimeValidationRecord?,
    lastKnownGoodRuntime: LastKnownGoodRuntimeRecord?,
    lastFallback: RuntimeFallbackRecord?
) -> RuntimeOperabilityPresentation {
    let configuredRuntimeIdentifier = runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    let reasoning = reasoningMode?.rawValue ?? "default"
    let configuredSummary = "\(configuredRuntimeIdentifier) (\(reasoning) reasoning)"

    if let lastFallback {
        let actualReasoning = lastFallback.fallbackReasoningMode?.rawValue ?? "default"
        let actualRuntimeSummary = "Actual runtime in use: \(lastFallback.fallbackRuntimeIdentifier) (\(actualReasoning) reasoning) via last-known-good fallback."
        let operabilitySummary = "Degraded mode is active. The configured runtime is not currently being used because \(runtimeOperabilityReasonSummary(category: lastFallback.reasonCategory, summary: lastFallback.reasonSummary))."
        return RuntimeOperabilityPresentation(
            state: .fallbackActive,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Fallback Active",
            configurationSummary: validationStatus?.summary ?? "Configured runtime remains saved as \(configuredSummary).",
            operabilitySummary: operabilitySummary,
            actualRuntimeSummary: actualRuntimeSummary,
            checkedAt: validationStatus?.checkedAt ?? lastFallback.occurredAt,
            checkedBy: validationStatus?.checkedBy,
            degradedModeActive: true,
            fallbackActive: true,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Degraded mode active: using last-known-good \(lastFallback.fallbackRuntimeIdentifier) because \(runtimeOperabilityReasonSummary(category: lastFallback.reasonCategory, summary: lastFallback.reasonSummary))."
        )
    }

    guard let validationStatus else {
        return RuntimeOperabilityPresentation(
            state: .configuredNotChecked,
            configurationLabel: "Configured",
            operabilityLabel: "Not Checked",
            configurationSummary: "Configured runtime is \(configuredSummary), but no validation result is recorded yet.",
            operabilitySummary: "No degraded-runtime evidence is recorded, but current operability has not been checked by the app.",
            actualRuntimeSummary: nil,
            checkedAt: nil,
            checkedBy: nil,
            degradedModeActive: false,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). No validation result is recorded yet."
        )
    }

    let checkedAt = validationStatus.checkedAt
    let checkedBy = validationStatus.checkedBy
    switch validationStatus.category {
    case .accepted:
        return RuntimeOperabilityPresentation(
            state: validationStatus.status == .warning ? .configurationNeedsReview : .primaryHealthy,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: validationStatus.status == .warning ? "Needs Review" : "Primary Path Ready",
            configurationSummary: validationStatus.summary,
            operabilitySummary: validationStatus.status == .warning
                ? "The runtime string is syntactically acceptable but outside the app's known runtime families. No degraded-runtime evidence is recorded, but review it before relying on it."
                : "The configured runtime is eligible for the primary provider path under the app's current validation and credential checks. No degraded-runtime evidence is recorded, but this does not by itself prove a successful live provider call.",
            actualRuntimeSummary: nil,
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: false,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). \(validationStatus.status == .warning ? "Configuration needs review before relying on it." : "Configuration passed current validation and credential checks with no degraded-runtime evidence recorded.")"
        )
    case .unknownRuntimeFamily:
        return RuntimeOperabilityPresentation(
            state: .configurationNeedsReview,
            configurationLabel: "Review",
            operabilityLabel: "Needs Review",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The runtime string is syntactically acceptable, but the app does not recognize its family. No degraded-runtime evidence is recorded, but current availability is not confirmed.",
            actualRuntimeSummary: nil,
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: false,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). The configuration is syntactically acceptable but still needs review before relying on it."
        )
    case .invalidFormat:
        let actualRuntimeSummary = lastKnownGoodRuntime.map {
            let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
            return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
        }
        return RuntimeOperabilityPresentation(
            state: .configurationInvalid,
            configurationLabel: "Invalid",
            operabilityLabel: "Primary Path Blocked",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime is not usable in its current form. Correct it before relying on the primary runtime path.",
            actualRuntimeSummary: actualRuntimeSummary,
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). The current configuration is invalid, so the primary runtime path is blocked until you correct it."
        )
    case .invalidSchema:
        let actualRuntimeSummary = lastKnownGoodRuntime.map {
            let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
            return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
        }
        return RuntimeOperabilityPresentation(
            state: .configurationInvalid,
            configurationLabel: "Invalid",
            operabilityLabel: "Invalid Structured Output Schema",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime is reachable, but the PM structured-output schema is invalid for the provider's strict JSON Schema subset. Fix the schema before relying on the primary PM runtime path.",
            actualRuntimeSummary: actualRuntimeSummary,
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is blocked because the PM structured-output schema is invalid for the live provider path."
        )
    case .unavailable:
        return RuntimeOperabilityPresentation(
            state: .unavailable,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Unavailable",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime is currently marked unavailable. Review provider access or choose another runtime before relying on it.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the configured runtime is marked unavailable."
        )
    case .authFailure:
        return RuntimeOperabilityPresentation(
            state: .authFailure,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Auth Or Access Failure",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The runtime check did not fail because of model naming alone. The current issue looks like auth, entitlement, or environment access.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest runtime check hit an auth or access failure."
        )
    case .networkFailure:
        return RuntimeOperabilityPresentation(
            state: .networkFailure,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Network Failure",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The runtime check did not fail because of model naming alone. The current issue looks like a network or transport failure.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest runtime check hit a network failure."
        )
    case .providerFailure:
        return RuntimeOperabilityPresentation(
            state: .unavailable,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Provider Failure",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime is reachable, but the latest live execution failed at the provider layer.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest live execution hit a provider failure."
        )
    case .rateLimitOrQuota:
        return RuntimeOperabilityPresentation(
            state: .unavailable,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Rate Limit / Quota",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime is reachable, but the latest live execution was blocked by rate limiting or quota exhaustion.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest live execution was rate-limited or quota-blocked."
        )
    case .requestTooLarge:
        return RuntimeOperabilityPresentation(
            state: .configurationNeedsReview,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Request Too Large",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime is reachable, but the latest live execution request exceeded the provider/runtime budget. The PM path should retry with a narrower context before falling back.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest live PM request was too large for the runtime/provider path."
        )
    case .malformedResponse:
        return RuntimeOperabilityPresentation(
            state: .configurationNeedsReview,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Malformed Response",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime responded, but the latest live execution returned an unusable structured response.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest live execution returned an unusable response."
        )
    case .refusal:
        return RuntimeOperabilityPresentation(
            state: .configurationNeedsReview,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Refusal / Empty Result",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime responded, but the latest live execution did not produce a usable PM answer.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest live execution returned no usable PM answer."
        )
    case .internalFailure:
        return RuntimeOperabilityPresentation(
            state: .configurationNeedsReview,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: "Internal Failure",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The configured runtime is reachable, but the latest live execution failed inside the PM synthesis path before a usable answer was accepted.",
            actualRuntimeSummary: lastKnownGoodRuntime.map {
                let fallbackReasoning = $0.reasoningMode?.rawValue ?? "default"
                return "No fallback is active right now. Last known good remains \($0.runtimeIdentifier) (\(fallbackReasoning) reasoning)."
            },
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: true,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Current operability is degraded because the latest live execution failed inside the PM synthesis path."
        )
    case .unknown:
        return RuntimeOperabilityPresentation(
            state: validationStatus.status == .invalid ? .configurationInvalid : .configurationNeedsReview,
            configurationLabel: configurationLabel(validationStatus),
            operabilityLabel: validationStatus.status == .invalid ? "Primary Path Blocked" : "Needs Review",
            configurationSummary: validationStatus.summary,
            operabilitySummary: "The app has bounded runtime evidence, but it is not specific enough to classify this runtime path more precisely yet.",
            actualRuntimeSummary: nil,
            checkedAt: checkedAt,
            checkedBy: checkedBy,
            degradedModeActive: validationStatus.status == .invalid,
            fallbackActive: false,
            ownerSurfaceSummary: "\(scopeLabel) runtime preference: \(configuredSummary). Review the latest runtime status in Settings before relying on it."
        )
    }
}

public func makeRuntimeOperabilityPresentation(
    pmRuntimeSettings: PMRuntimeSettings?
) -> RuntimeOperabilityPresentation? {
    guard let pmRuntimeSettings else { return nil }
    let effectiveStatus: RuntimeValidationRecord?
    if let executionStatus = pmRuntimeSettings.executionStatus {
        if let validationStatus = pmRuntimeSettings.validationStatus {
            if executionStatus.category != .accepted {
                effectiveStatus = executionStatus
            } else if validationStatus.category != .accepted {
                effectiveStatus = validationStatus
            } else {
                effectiveStatus = executionStatus.checkedAt >= validationStatus.checkedAt
                    ? executionStatus
                    : validationStatus
            }
        } else {
            effectiveStatus = executionStatus
        }
    } else {
        effectiveStatus = pmRuntimeSettings.validationStatus
    }
    return makeRuntimeOperabilityPresentation(
        scopeLabel: "PM",
        runtimeIdentifier: pmRuntimeSettings.runtimeIdentifier,
        reasoningMode: pmRuntimeSettings.reasoningMode,
        validationStatus: effectiveStatus,
        lastKnownGoodRuntime: pmRuntimeSettings.lastKnownGoodRuntime,
        lastFallback: pmRuntimeSettings.lastFallback
    )
}

public func makeRuntimeOperabilityPresentation(
    recentNewsAnalystRuntimeSettings: RecentNewsAnalystRuntimeSettings?
) -> RuntimeOperabilityPresentation? {
    guard let recentNewsAnalystRuntimeSettings else { return nil }
    return makeRuntimeOperabilityPresentation(
        scopeLabel: "Recent News Analyst",
        runtimeIdentifier: recentNewsAnalystRuntimeSettings.runtimeIdentifier,
        reasoningMode: recentNewsAnalystRuntimeSettings.reasoningMode,
        validationStatus: recentNewsAnalystRuntimeSettings.validationStatus,
        lastKnownGoodRuntime: recentNewsAnalystRuntimeSettings.lastKnownGoodRuntime,
        lastFallback: recentNewsAnalystRuntimeSettings.lastFallback
    )
}

public func makeRuntimeOperabilityPresentation(
    standingBenchAnalystRuntimeSettings: StandingBenchAnalystRuntimeSettings?
) -> RuntimeOperabilityPresentation? {
    guard let standingBenchAnalystRuntimeSettings else { return nil }
    return makeRuntimeOperabilityPresentation(
        scopeLabel: "Standing Bench Analysts",
        runtimeIdentifier: standingBenchAnalystRuntimeSettings.runtimeIdentifier,
        reasoningMode: standingBenchAnalystRuntimeSettings.reasoningMode,
        validationStatus: standingBenchAnalystRuntimeSettings.validationStatus,
        lastKnownGoodRuntime: standingBenchAnalystRuntimeSettings.lastKnownGoodRuntime,
        lastFallback: standingBenchAnalystRuntimeSettings.lastFallback
    )
}

private func configurationLabel(_ validationStatus: RuntimeValidationRecord?) -> String {
    guard let validationStatus else { return "Configured" }
    switch validationStatus.status {
    case .valid:
        return "Valid"
    case .warning:
        return "Review"
    case .invalid:
        return "Invalid"
    }
}

private func runtimeOperabilityReasonSummary(
    category: RuntimeValidationCategory,
    summary: String
) -> String {
    switch category {
    case .invalidFormat:
        return summary.lowercased()
    case .invalidSchema:
        return "the live PM structured-output schema is invalid"
    case .unknownRuntimeFamily:
        return "the configured runtime still needs review: \(summary.lowercased())"
    case .unavailable:
        return "the configured runtime is marked unavailable"
    case .authFailure:
        return "the latest runtime check hit an auth or access failure"
    case .networkFailure:
        return "the latest runtime check hit a network failure"
    case .providerFailure:
        return "the latest live execution hit a provider failure"
    case .rateLimitOrQuota:
        return "the latest live execution was rate-limited or quota-blocked"
    case .requestTooLarge:
        return "the latest live execution request was too large"
    case .malformedResponse:
        return "the latest live execution returned an unusable response"
    case .refusal:
        return "the latest live execution returned no usable PM answer"
    case .internalFailure:
        return "the latest live execution failed inside the PM runtime"
    case .accepted:
        return summary.lowercased()
    case .unknown:
        return "the app only has bounded runtime evidence right now"
    }
}
