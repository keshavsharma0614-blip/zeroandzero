import Foundation
import Testing
@testable import TradingKit

@Test("Runtime operability distinguishes healthy configuration from degraded fallback")
func runtimeOperabilityDistinguishesHealthyAndFallbackStates() {
    let now = Date(timeIntervalSince1970: 1_743_300_000)

    let healthy = makeRuntimeOperabilityPresentation(
        scopeLabel: "PM",
        runtimeIdentifier: "gpt-5-mini",
        reasoningMode: .standard,
        validationStatus: RuntimeValidationRecord(
            status: .valid,
            category: .accepted,
            summary: "Runtime identifier passed the app's bounded local validation policy.",
            checkedAt: now,
            checkedBy: "human owner"
        ),
        lastKnownGoodRuntime: nil,
        lastFallback: nil
    )

    #expect(healthy.state == .primaryHealthy)
    #expect(healthy.configurationLabel == "Valid")
    #expect(healthy.operabilityLabel == "Primary Path Ready")
    #expect(healthy.degradedModeActive == false)
    #expect(healthy.fallbackActive == false)
    #expect(healthy.ownerSurfaceSummary.contains("no degraded-runtime evidence") == true)

    let fallback = makeRuntimeOperabilityPresentation(
        scopeLabel: "PM",
        runtimeIdentifier: "bad runtime!",
        reasoningMode: .deliberate,
        validationStatus: RuntimeValidationRecord(
            status: .invalid,
            category: .invalidFormat,
            summary: "Runtime identifier can use letters, numbers, hyphen, underscore, period, and colon only.",
            checkedAt: now,
            checkedBy: "human owner"
        ),
        lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
            runtimeIdentifier: "gpt-5-mini",
            reasoningMode: .standard,
            verifiedAt: now,
            summary: "Previously resolved successfully."
        ),
        lastFallback: RuntimeFallbackRecord(
            configuredRuntimeIdentifier: "bad runtime!",
            configuredReasoningMode: .deliberate,
            fallbackRuntimeIdentifier: "gpt-5-mini",
            fallbackReasoningMode: .standard,
            reasonCategory: .invalidFormat,
            reasonSummary: "Runtime identifier can use letters, numbers, hyphen, underscore, period, and colon only.",
            occurredAt: now
        )
    )

    #expect(fallback.state == .fallbackActive)
    #expect(fallback.operabilityLabel == "Fallback Active")
    #expect(fallback.degradedModeActive == true)
    #expect(fallback.fallbackActive == true)
    #expect(fallback.actualRuntimeSummary?.contains("gpt-5-mini") == true)
    #expect(fallback.ownerSurfaceSummary.contains("Degraded mode active") == true)
}

@Test("Runtime operability distinguishes unavailable, auth failure, and network failure")
func runtimeOperabilitySeparatesProviderFailureClasses() {
    let now = Date(timeIntervalSince1970: 1_743_300_100)

    let unavailable = makeRuntimeOperabilityPresentation(
        scopeLabel: "PM",
        runtimeIdentifier: "gpt-5",
        reasoningMode: .standard,
        validationStatus: RuntimeValidationRecord(
            status: .invalid,
            category: .unavailable,
            summary: "Runtime is not currently available to this app.",
            checkedAt: now,
            checkedBy: "runtime health check"
        ),
        lastKnownGoodRuntime: nil,
        lastFallback: nil
    )
    let authFailure = makeRuntimeOperabilityPresentation(
        scopeLabel: "PM",
        runtimeIdentifier: "gpt-5",
        reasoningMode: .standard,
        validationStatus: RuntimeValidationRecord(
            status: .invalid,
            category: .authFailure,
            summary: "OpenAI authentication failed for the current environment.",
            checkedAt: now,
            checkedBy: "runtime health check"
        ),
        lastKnownGoodRuntime: nil,
        lastFallback: nil
    )
    let networkFailure = makeRuntimeOperabilityPresentation(
        scopeLabel: "PM",
        runtimeIdentifier: "gpt-5",
        reasoningMode: .standard,
        validationStatus: RuntimeValidationRecord(
            status: .invalid,
            category: .networkFailure,
            summary: "Network request failed before the runtime could be checked.",
            checkedAt: now,
            checkedBy: "runtime health check"
        ),
        lastKnownGoodRuntime: nil,
        lastFallback: nil
    )

    #expect(unavailable.state == .unavailable)
    #expect(unavailable.operabilityLabel == "Unavailable")
    #expect(authFailure.state == .authFailure)
    #expect(authFailure.operabilityLabel == "Auth Or Access Failure")
    #expect(networkFailure.state == .networkFailure)
    #expect(networkFailure.operabilityLabel == "Network Failure")
}

@Test("Runtime operability presents invalid structured-output schema distinctly")
func runtimeOperabilityPresentsInvalidSchemaDistinctly() {
    let now = Date(timeIntervalSince1970: 1_746_100_000)
    let invalidSchema = makeRuntimeOperabilityPresentation(
        scopeLabel: "PM",
        runtimeIdentifier: "gpt-5.4",
        reasoningMode: .standard,
        validationStatus: RuntimeValidationRecord(
            status: .invalid,
            category: .invalidSchema,
            summary: "Latest PM conversation execution failed: invalid_schema schema_name=pm_conversation_reply schema_path=schema.properties.resolution required_mismatch.",
            checkedAt: now,
            checkedBy: "pm conversation execution"
        ),
        lastKnownGoodRuntime: nil,
        lastFallback: nil
    )

    #expect(invalidSchema.state == .configurationInvalid)
    #expect(invalidSchema.operabilityLabel == "Invalid Structured Output Schema")
    #expect(invalidSchema.ownerSurfaceSummary.contains("structured-output schema") == true)
}

@Test("PM, recent news, and standing bench runtime settings share the same operability philosophy")
func pmAndRecentNewsRuntimeSettingsShareOperabilityPhilosophy() {
    let now = Date(timeIntervalSince1970: 1_743_300_200)
    let validation = RuntimeValidationRecord(
        status: .warning,
        category: .unknownRuntimeFamily,
        summary: "Runtime identifier is syntactically acceptable but outside the app's known runtime families.",
        checkedAt: now,
        checkedBy: "human owner"
    )

    let pmPresentation = makeRuntimeOperabilityPresentation(
        pmRuntimeSettings: PMRuntimeSettings(
            runtimeIdentifier: "future-model-x",
            reasoningMode: .standard,
            validationStatus: validation,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    let recentNewsPresentation = makeRuntimeOperabilityPresentation(
        recentNewsAnalystRuntimeSettings: RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "future-model-x",
            reasoningMode: .standard,
            validationStatus: validation,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    let standingBenchPresentation = makeRuntimeOperabilityPresentation(
        standingBenchAnalystRuntimeSettings: StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "future-model-x",
            reasoningMode: .standard,
            validationStatus: validation,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    #expect(pmPresentation?.state == .configurationNeedsReview)
    #expect(recentNewsPresentation?.state == .configurationNeedsReview)
    #expect(standingBenchPresentation?.state == .configurationNeedsReview)
    #expect(pmPresentation?.configurationLabel == "Review")
    #expect(recentNewsPresentation?.configurationLabel == "Review")
    #expect(standingBenchPresentation?.configurationLabel == "Review")
}

@Test("PM runtime operability presentation prefers the latest live execution truth over stale healthy preflight state")
func pmRuntimeOperabilityPresentationPrefersLiveExecutionTruth() {
    let now = Date(timeIntervalSince1970: 1_746_002_200)
    let presentation = makeRuntimeOperabilityPresentation(
        pmRuntimeSettings: PMRuntimeSettings(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            validationStatus: RuntimeValidationRecord(
                status: .valid,
                category: .accepted,
                summary: "Configuration passed current validation and credential checks.",
                checkedAt: now,
                checkedBy: "human owner"
            ),
            executionStatus: RuntimeValidationRecord(
                status: .invalid,
                category: .requestTooLarge,
                summary: "Latest PM conversation execution for gpt-5 failed: openai_request_too_large_status=400 detail=code=context_length_exceeded.",
                checkedAt: now.addingTimeInterval(60),
                checkedBy: "pm conversation execution"
            ),
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    #expect(presentation?.operabilityLabel == "Request Too Large")
    #expect(presentation?.ownerSurfaceSummary.contains("latest live PM request was too large") == true)
}

@Test("OpenAI runtime capability hints surface model context window separately from reasoning effort")
func openAIRuntimeCapabilityHintsSurfaceContextWindowTruth() {
    let flagship = openAIRuntimeCapabilityHint(
        runtimeIdentifier: "gpt-5.4",
        reasoningMode: .deliberate
    )
    let smaller = openAIRuntimeCapabilityHint(
        runtimeIdentifier: "gpt-5",
        reasoningMode: .standard
    )

    #expect(flagship?.summary.contains("1M-token context window") == true)
    #expect(flagship?.detail.contains("does not switch the model onto a separate larger context window") == true)
    #expect(smaller?.summary.contains("400K-token context window") == true)
    #expect(smaller?.detail.contains("does not create a separate context-window tier") == true)
}
