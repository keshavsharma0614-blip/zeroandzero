import Foundation
import Testing
@testable import TradingKit

@Test("PM models round-trip deterministically and remain distinct from analyst memory")
func pmModelsRoundTripAndBoundarySemantics() throws {
    let now = Date(timeIntervalSince1970: 1_701_100_000)
    let profile = PMProfile(
        pmId: "pm-primary",
        displayName: "Primary PM",
        roleSummary: "Supervises portfolio policy and specialist workers.",
        createdAt: now,
        updatedAt: now
    )
    let mandate = PMMandate(
        mandateId: "mandate-1",
        pmId: profile.pmId,
        title: "Core mandate",
        objectiveSummary: "Compound capital while preserving approval discipline.",
        scope: "Global multi-strategy paper-first supervision.",
        constraints: ["No autonomous live trading", "Preserve human approval gates"],
        riskBoundaries: ["Respect kill switch", "Respect paper/live mode"],
        successCriteria: ["Traceable decisions", "Bounded risk posture"],
        createdAt: now,
        updatedAt: now
    )
    let instruction = PMInstruction(
        instructionId: "instruction-1",
        pmId: profile.pmId,
        title: "Daily operating stance",
        body: "Prefer analyst delegation for research and keep consequential actions pending review.",
        category: "operating_guidance",
        status: .active,
        effectiveAt: now,
        createdAt: now,
        updatedAt: now
    )
    let note = PMNotebookEntry(
        entryId: "note-1",
        pmId: profile.pmId,
        title: "Interpretation note",
        body: "Remote chat outcomes should be promoted selectively, not stored as raw transcript memory.",
        tags: ["memory", "remote"],
        sourceSummary: "owner guidance",
        createdAt: now,
        updatedAt: now
    )
    let runtimeSettings = PMRuntimeSettings(
        runtimeIdentifier: "gpt-5.4",
        reasoningMode: .deliberate,
        updatedBy: "human owner",
        updateSource: .userEdited,
        createdAt: now,
        updatedAt: now
    )
    let communicationSession = PMCommunicationSession(
        sessionId: "session-1",
        channel: .telegram,
        externalConversationId: "chat-1",
        pmId: profile.pmId,
        participantId: "owner-1",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let communicationMessage = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: communicationSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner-1",
        body: "Please turn this into a bounded decision record.",
        sentAt: now,
        promotion: PMCommunicationPromotion(
            targetType: .decision,
            targetId: "decision-1",
            promotedAt: now
        ),
        conversationResolution: PMConversationResolutionState(
            intentClass: .instruction,
            disposition: .durableChangeProposed,
            workingUnderstandingSummary: "Owner wants the current conversation outcome promoted into a bounded durable PM record.",
            operatingTruthKind: .workingPortfolioDefinition,
            operatingTruthSummary: "Latest conversation-defined working paper portfolio centers on MSFT and NVDA with a cash buffer.",
            operatingTruthBody: "Carry the latest conversation-defined working paper portfolio with MSFT, NVDA, and a cash buffer until further owner revision.",
            pendingAsk: PMConversationPendingAskState(
                kind: .clarification,
                promptSummary: "Should this become a PM instruction or a PM decision?",
                workingUnderstandingSummary: "The PM still needs to resolve the correct durable target.",
                operatingTruthKind: .workingPortfolioDefinition,
                operatingTruthSummary: "Latest working paper portfolio still pending durable routing."
            ),
            sourceMessageIds: ["message-1"]
        ),
        createdAt: now,
        updatedAt: now
    )
    let runtimePolicy = AnalystRuntimePolicy(
        runtimeIdentifier: "gpt-5",
        reasoningMode: .deliberate,
        policySource: .pmDelegationOverride,
        createdAt: now,
        updatedAt: now
    )
    let taskingBrief = PMTaskingBrief(
        taskObjective: "Pressure test the thesis.",
        whyNow: "The PM needs a stronger read before the next owner-facing recommendation.",
        reviewLens: "Disconfirming evidence first.",
        expectedAnswerShape: .competingCaseComparison,
        challengeInstruction: "Assume the current PM read is wrong and look for the strongest contradiction.",
        evidenceExpectation: "Use at least two distinct evidence families.",
        disconfirmingEvidenceExpectation: "State what would invalidate the current thesis.",
        expectedOutputs: ["memo", "finding"],
        revisionReason: "Initial pass leaned too heavily on confirming evidence."
    )
    let delegation = PMDelegationRecord(
        delegationId: "delegation-1",
        pmId: profile.pmId,
        analystId: "macro-analyst",
        charterId: "charter-1",
        taskId: "task-1",
        title: "Research delegation",
        rationale: "Need a durable PM-issued analyst tasking record.",
        taskingBrief: taskingBrief,
        requestedOutputs: [.finding, .signal],
        status: .issued,
        parentDelegationId: "delegation-parent",
        sourceFollowUpActionId: "follow-up-1",
        sourceCommunicationSessionId: "session-1",
        sourceCommunicationMessageId: "message-1",
        runtimePolicyOverride: runtimePolicy,
        lastLaunch: PMDelegationLastLaunch(
            launchedAt: now,
            status: .degradedExternalEvidence,
            summary: "Degraded external evidence: category=http_status host=example.com status=503"
        ),
        lastRuntimeProvenance: AnalystRuntimeProvenance(
            intendedPolicy: runtimePolicy,
            actualRuntimeIdentifier: "deterministic_local",
            launchedAt: now
        ),
        followUpActions: [
            PMAnalystFollowUpAction(
                actionId: "follow-up-1",
                actionType: .rerunWithRuntime,
                summary: "Use a deeper runtime and explicitly challenge the prior conclusion.",
                requestedCharterId: "charter-2",
                requestedRuntimePolicy: runtimePolicy,
                taskingBrief: taskingBrief,
                createdAt: now
            )
        ],
        linkedFindingIDs: ["finding-1"],
        linkedSignalIDs: [],
        linkedProposalIDs: [],
        createdAt: now,
        updatedAt: now
    )
    let approvalRequest = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: profile.pmId,
        subject: "Review bounded strategy change",
        rationale: "PM needs an explicit owner-approved path before the saved strategy brief changes.",
        requestType: .strategyChange,
        status: .resolved,
        decisionId: "decision-1",
        delegationId: delegation.delegationId,
        proposalId: "proposal-1",
        sourceAnalystStrategyFollowUpCandidateId: "candidate-1",
        sourceAnalystStrategyImplicationId: "implication-1",
        sourceAnalystMemoId: "memo-1",
        sourceAnalystEvidenceBundleId: "bundle-1",
        strategyChangePortfolioContext: PMStrategyChangePortfolioContextSnapshot(
            positionCount: 3,
            grossExposure: 55_000,
            netExposure: 35_000,
            longExposure: 45_000,
            shortExposure: 10_000,
            longWeight: 0.8181818182,
            shortWeight: 0.1818181818,
            netWeight: 0.6363636364,
            largestPositionSymbol: "NVDA",
            largestPositionWeight: 0.5454545455,
            capturedAt: now
        ),
        resultingStrategyBriefId: PortfolioStrategyBrief.singletonID,
        ownerResponse: .approved,
        ownerRespondedAt: now,
        createdAt: now,
        updatedAt: now
    )

    let analystTask = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        parentTaskId: "task-parent",
        title: "Research task",
        description: "Analyst task memory remains separate.",
        pmTaskingBrief: taskingBrief,
        status: .queued,
        createdAt: now,
        updatedAt: now
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy

    let roundTrippedProfile = try decoder.decode(PMProfile.self, from: encoder.encode(profile))
    let roundTrippedMandate = try decoder.decode(PMMandate.self, from: encoder.encode(mandate))
    let roundTrippedInstruction = try decoder.decode(PMInstruction.self, from: encoder.encode(instruction))
    let roundTrippedNote = try decoder.decode(PMNotebookEntry.self, from: encoder.encode(note))
    let roundTrippedRuntimeSettings = try decoder.decode(PMRuntimeSettings.self, from: encoder.encode(runtimeSettings))
    let roundTrippedCommunicationSession = try decoder.decode(PMCommunicationSession.self, from: encoder.encode(communicationSession))
    let roundTrippedCommunicationMessage = try decoder.decode(PMCommunicationMessage.self, from: encoder.encode(communicationMessage))
    let roundTrippedDelegation = try decoder.decode(PMDelegationRecord.self, from: encoder.encode(delegation))
    let roundTrippedApprovalRequest = try decoder.decode(PMApprovalRequest.self, from: encoder.encode(approvalRequest))

    #expect(roundTrippedProfile == profile)
    #expect(roundTrippedMandate == mandate)
    #expect(roundTrippedInstruction == instruction)
    #expect(roundTrippedNote == note)
    #expect(roundTrippedRuntimeSettings == runtimeSettings)
    #expect(roundTrippedCommunicationSession == communicationSession)
    #expect(roundTrippedCommunicationMessage == communicationMessage)
    #expect(roundTrippedCommunicationMessage.conversationResolution?.pendingAsk?.promptSummary == "Should this become a PM instruction or a PM decision?")
    #expect(roundTrippedCommunicationMessage.conversationResolution?.operatingTruthKind == .workingPortfolioDefinition)
    #expect(roundTrippedCommunicationMessage.conversationResolution?.operatingTruthBody?.contains("MSFT, NVDA") == true)
    #expect(roundTrippedCommunicationMessage.conversationResolution?.pendingAsk?.operatingTruthSummary?.contains("working paper portfolio") == true)
    #expect(roundTrippedDelegation == delegation)
    #expect(roundTrippedApprovalRequest == approvalRequest)
    #expect(roundTrippedProfile.pmId == mandate.pmId)
    #expect(roundTrippedInstruction.pmId == profile.pmId)
    #expect(roundTrippedNote.pmId == profile.pmId)
    #expect(roundTrippedRuntimeSettings.runtimeIdentifier == "gpt-5.4")
    #expect(roundTrippedRuntimeSettings.reasoningMode == .deliberate)
    #expect(roundTrippedRuntimeSettings.updateSource == .userEdited)
    #expect(roundTrippedNote.body.contains("raw transcript memory"))
    #expect(roundTrippedCommunicationMessage.promotion?.targetType == .decision)
    #expect(roundTrippedCommunicationMessage.sessionId == communicationSession.sessionId)
    #expect(roundTrippedApprovalRequest.ownerResponse == .approved)
    #expect(roundTrippedApprovalRequest.requestType == .strategyChange)
    #expect(roundTrippedApprovalRequest.sourceAnalystStrategyFollowUpCandidateId == "candidate-1")
    #expect(roundTrippedApprovalRequest.sourceAnalystStrategyImplicationId == "implication-1")
    #expect(roundTrippedApprovalRequest.sourceAnalystMemoId == "memo-1")
    #expect(roundTrippedApprovalRequest.sourceAnalystEvidenceBundleId == "bundle-1")
    #expect(roundTrippedApprovalRequest.strategyChangePortfolioContext?.largestPositionSymbol == "NVDA")
    #expect(roundTrippedApprovalRequest.strategyChangePortfolioContext?.longWeight == 0.8181818182)
    #expect(roundTrippedApprovalRequest.strategyChangePortfolioContext?.shortWeight == 0.1818181818)
    #expect(roundTrippedApprovalRequest.resultingStrategyBriefId == PortfolioStrategyBrief.singletonID)
    #expect(roundTrippedDelegation.runtimePolicyOverride?.runtimeIdentifier == "gpt-5")
    #expect(roundTrippedDelegation.lastLaunch?.status == .degradedExternalEvidence)
    #expect(roundTrippedDelegation.lastRuntimeProvenance?.actualRuntimeIdentifier == "deterministic_local")
    #expect(roundTrippedDelegation.requestedOutputs == [.finding, .signal])
    #expect(roundTrippedDelegation.taskingBrief?.reviewLens == "Disconfirming evidence first.")
    #expect(roundTrippedDelegation.taskingBrief?.whyNow == "The PM needs a stronger read before the next owner-facing recommendation.")
    #expect(roundTrippedDelegation.taskingBrief?.expectedAnswerShape == .competingCaseComparison)
    #expect(roundTrippedDelegation.taskingBrief?.disconfirmingEvidenceExpectation == "State what would invalidate the current thesis.")
    #expect(roundTrippedDelegation.parentDelegationId == "delegation-parent")
    #expect(roundTrippedDelegation.sourceFollowUpActionId == "follow-up-1")
    #expect(roundTrippedDelegation.sourceCommunicationSessionId == "session-1")
    #expect(roundTrippedDelegation.sourceCommunicationMessageId == "message-1")
    #expect(roundTrippedDelegation.followUpActions.first?.actionType == .rerunWithRuntime)
    #expect(roundTrippedDelegation.followUpActions.first?.requestedRuntimePolicy?.runtimeIdentifier == "gpt-5")
    #expect(analystTask.parentTaskId == "task-parent")
    #expect(analystTask.pmTaskingBrief?.expectedOutputs == ["memo", "finding"])
    #expect(analystTask.analystId != profile.pmId)
    #expect(analystTask.title != roundTrippedNote.title)
    #expect(roundTrippedCommunicationMessage.body != roundTrippedNote.body)
}

@Test("PortfolioStrategyBrief round-trips deterministically and remains distinct from PM notebook memory")
func portfolioStrategyBriefRoundTripsAndPreservesSharedDocumentBoundary() throws {
    let now = Date(timeIntervalSince1970: 1_701_100_025)
    let brief = PortfolioStrategyBrief(
        objectiveSummary: "Preserve capital with an event-aware growth posture focused on core tech and technology platform exposure.",
        keyThemes: ["technology infrastructure exposure", "Event-aware supervision"],
        currentRiskPosture: "Moderate risk with tighter review around earnings, guidance, and SEC event clusters.",
        materialDevelopments: ["guidance changes", "major restructuring", "leadership changes"],
        nonMaterialDevelopments: ["routine office openings", "minor product marketing updates"],
        reviewEscalationPosture: "Escalate bounded portfolio-impact cases to PM review before any owner-facing request.",
        revisionSummary: "Conversation-derived revision tightening event-review posture.",
        sourceCommunicationMessageId: "message-1",
        updatedBy: "pm-primary",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let note = PMNotebookEntry(
        entryId: "note-1",
        pmId: "pm-primary",
        title: "Scratch note",
        body: "Transient interpretation note only.",
        createdAt: now,
        updatedAt: now
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy

    let roundTripped = try decoder.decode(PortfolioStrategyBrief.self, from: encoder.encode(brief))

    #expect(roundTripped == brief)
    #expect(roundTripped.briefId == PortfolioStrategyBrief.singletonID)
    #expect(roundTripped.keyThemes.contains("technology infrastructure exposure"))
    #expect(roundTripped.updateSource == .pmControlPlane)
    #expect(roundTripped.revisionSummary?.contains("tightening event-review posture") == true)
    #expect(roundTripped.sourceCommunicationMessageId == "message-1")
    #expect(roundTripped.objectiveSummary != note.body)
}

@Test("PMRuntimeSettingsStore persists open-string runtime settings and falls back cleanly")
func pmRuntimeSettingsStorePersistsAndDefaults() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-pm-runtime-settings-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let fileURL = root.appendingPathComponent("pm-runtime-settings.json", isDirectory: false)

    let now = Date(timeIntervalSince1970: 1_701_100_050)
    let store = PMRuntimeSettingsStore(
        fileURL: fileURL,
        now: { now }
    )

    let defaultSettings = try await store.loadOrDefault()
    #expect(defaultSettings.settingsId == PMRuntimeSettings.singletonID)
    #expect(defaultSettings.runtimeIdentifier == "gpt-5")
    #expect(defaultSettings.reasoningMode == .deliberate)

    _ = try await store.upsert(
        PMRuntimeSettings(
            runtimeIdentifier: "gpt-next-owner-choice",
            reasoningMode: nil,
            validationStatus: RuntimeValidationRecord(
                status: .valid,
                category: .accepted,
                summary: "Accepted by local validation.",
                checkedAt: now,
                checkedBy: "human owner"
            ),
            executionStatus: RuntimeValidationRecord(
                status: .invalid,
                category: .requestTooLarge,
                summary: "Latest PM conversation execution failed because the request was too large.",
                checkedAt: now.addingTimeInterval(30),
                checkedBy: "pm conversation execution"
            ),
            lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
                runtimeIdentifier: "gpt-next-owner-choice",
                reasoningMode: nil,
                verifiedAt: now,
                summary: "Accepted by local validation."
            ),
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let reloadedStore = PMRuntimeSettingsStore(fileURL: fileURL)
    let reloaded = try await reloadedStore.loadOrDefault()
    #expect(reloaded.settingsId == PMRuntimeSettings.singletonID)
    #expect(reloaded.runtimeIdentifier == "gpt-next-owner-choice")
    #expect(reloaded.reasoningMode == nil)
    #expect(reloaded.updateSource == .userEdited)
    #expect(reloaded.validationStatus?.status == .valid)
    #expect(reloaded.executionStatus?.category == .requestTooLarge)
    #expect(reloaded.lastKnownGoodRuntime?.runtimeIdentifier == "gpt-next-owner-choice")

    try Data(#"{"schemaVersion":2,"settings":{"runtimeIdentifier":"bad"}}"#.utf8).write(to: fileURL)
    let invalidStore = PMRuntimeSettingsStore(fileURL: fileURL)
    let fallback = try await invalidStore.loadOrDefault()
    #expect(fallback.runtimeIdentifier == "gpt-5")
    #expect(await invalidStore.drainLoadDiagnostics().contains { $0.contains("unsupported_schema_version") })
}

@Test("PortfolioStrategyBrief can use one free-form document while still extracting bounded strategy context")
func portfolioStrategyBriefFreeFormDocumentExtraction() {
    let now = Date(timeIntervalSince1970: 1_701_100_030)
    let document = """
    ## Objective
    Compound capital while staying event-aware and approval-disciplined.

    ## Key Themes
    - technology infrastructure
    - Quality large-cap exposure

    ## Current Risk Posture
    Moderate with tighter review around earnings and guidance.

    ## Material Developments
    - guidance changes
    - major restructuring

    ## Usually Not Material
    - routine product marketing

    ## Review Posture
    Escalate to PM review first before any owner-facing ask.
    """

    let brief = PortfolioStrategyBrief(
        title: "Living Strategy Brief",
        documentBody: document,
        objectiveSummary: "",
        currentRiskPosture: "",
        reviewEscalationPosture: "",
        updatedBy: "human owner",
        updateSource: .userEdited,
        createdAt: now,
        updatedAt: now
    ).applyingDocumentExtraction()

    #expect(brief.documentBody == document)
    #expect(brief.objectiveSummary == "Compound capital while staying event-aware and approval-disciplined.")
    #expect(brief.keyThemes == ["technology infrastructure", "Quality large-cap exposure"])
    #expect(brief.currentRiskPosture == "Moderate with tighter review around earnings and guidance.")
    #expect(brief.materialDevelopments == ["guidance changes", "major restructuring"])
    #expect(brief.nonMaterialDevelopments == ["routine product marketing"])
    #expect(brief.reviewEscalationPosture == "Escalate to PM review first before any owner-facing ask.")
}

@Test("PortfolioStrategyBrief store preserves the saved long-form document body across save and reload")
func portfolioStrategyBriefStorePreservesSavedLongFormDocumentBody() async throws {
    let root = makePMTempDirectory(name: "portfolio-strategy-brief-store-long-form")
    let fileURL = root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let now = Date(timeIntervalSince1970: 1_701_100_031)
    let document = """
    ## Objective
    Compound steadily while keeping review discipline explicit.

    ## Key Themes
    - technology infrastructure
    - Concentration discipline

    ## Current Risk Posture
    Stay constructive, but tighten review around catalyst clusters.

    ## Material Developments
    - guidance changes

    ## Usually Not Material
    - routine product events

    ## Review Posture
    Escalate strategy-significant changes first.

    ## Full Brief Appendix
    This appendix is part of the owner-facing strategy document and must remain visible after save and reload.

    The PM should preserve this long-form context instead of collapsing it into derived summary fields.
    """

    let store = PortfolioStrategyBriefStore(fileURL: fileURL, now: { now })
    _ = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Living Strategy Brief",
            documentBody: document,
            objectiveSummary: "",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            revisionSummary: "Owner expanded the long-form operating brief.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let reloadedStore = PortfolioStrategyBriefStore(fileURL: fileURL, now: { now.addingTimeInterval(60) })
    let reloaded = try #require(try await reloadedStore.load())

    #expect(reloaded.documentBody == document)
    #expect(reloaded.primaryDocumentBody == document)
    #expect(reloaded.objectiveSummary == "Compound steadily while keeping review discipline explicit.")
    #expect(reloaded.keyThemes == ["technology infrastructure", "Concentration discipline"])
    #expect(reloaded.revisionSummary == "Owner expanded the long-form operating brief.")
    #expect(reloaded.primaryDocumentBody.contains("## Full Brief Appendix"))
    #expect(reloaded.primaryDocumentBody.contains("must remain visible after save and reload"))
}

@Test("PortfolioStrategyBrief store does not let a later system seed overwrite an existing user-owned brief")
func portfolioStrategyBriefStoreIgnoresSystemSeedOverwrite() async throws {
    let root = makePMTempDirectory(name: "portfolio-strategy-brief-seed-protection")
    let fileURL = root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let now = Date(timeIntervalSince1970: 1_701_100_032)
    let store = PortfolioStrategyBriefStore(fileURL: fileURL, now: { now })

    let saved = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Owner Brief",
            documentBody: """
            ## Objective
            Protect the saved owner strategy.

            ## Review Posture
            Do not replace this without explicit owner action.
            """,
            objectiveSummary: "",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let attemptedSeed = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Seeded Brief",
            documentBody: """
            ## Objective
            Old seeded text that should not replace the current owner brief.
            """,
            objectiveSummary: "",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            updatedBy: "system",
            updateSource: .systemSeed,
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )
    )

    #expect(attemptedSeed.primaryDocumentBody == saved.primaryDocumentBody)
    #expect(attemptedSeed.updateSource == .userEdited)
    #expect(await store.drainLoadDiagnostics().contains { $0.contains("ignored_system_seed_overwrite") })
}

@Test("PortfolioStrategyBrief store preserves the existing saved document body when a later sparse update omits it")
func portfolioStrategyBriefStorePreservesExistingBodyAcrossSparseUpdates() async throws {
    let root = makePMTempDirectory(name: "portfolio-strategy-brief-sparse-update")
    let fileURL = root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let now = Date(timeIntervalSince1970: 1_701_100_033)
    let store = PortfolioStrategyBriefStore(fileURL: fileURL, now: { now })

    let originalDocument = """
    ## Objective
    Keep the real owner-authored long-form brief intact.

    ## Full Brief Appendix
    This body should survive later metadata-only updates.
    """
    _ = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Owner Brief",
            documentBody: originalDocument,
            objectiveSummary: "",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let sparseUpdate = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Owner Brief",
            documentBody: nil,
            objectiveSummary: "Sparse metadata update only.",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            revisionSummary: "PM added a note without replacing the document body.",
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )
    )

    #expect(sparseUpdate.primaryDocumentBody == originalDocument)
    #expect(sparseUpdate.revisionSummary == "PM added a note without replacing the document body.")
    #expect(sparseUpdate.primaryDocumentBody.contains("This body should survive later metadata-only updates."))
}

@Test("PortfolioStrategyBrief durability survives reload and later seeded bootstrap attempts")
func portfolioStrategyBriefDurabilitySurvivesReloadAndLaterSeededBootstrap() async throws {
    let root = makePMTempDirectory(name: "portfolio-strategy-brief-reload-regression-guard")
    let fileURL = root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let createdAt = Date(timeIntervalSince1970: 1_701_100_034)

    let firstStore = PortfolioStrategyBriefStore(fileURL: fileURL, now: { createdAt })
    let savedDocument = """
    ## Objective
    Preserve this saved long-form owner brief across restart-style reloads.

    ## Full Brief Appendix
    This exact body must remain current after later seed/bootstrap activity.
    """
    _ = try await firstStore.upsert(
        PortfolioStrategyBrief(
            title: "Owner Brief",
            documentBody: savedDocument,
            objectiveSummary: "Preserve this saved long-form owner brief across restart-style reloads.",
            currentRiskPosture: "Moderate.",
            reviewEscalationPosture: "Escalate only material changes.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    )

    let reloadedStore = PortfolioStrategyBriefStore(
        fileURL: fileURL,
        now: { createdAt.addingTimeInterval(120) }
    )
    let reloaded = try #require(await reloadedStore.load())
    #expect(reloaded.primaryDocumentBody == savedDocument)

    let afterSeedAttempt = try await reloadedStore.upsert(
        PortfolioStrategyBrief(
            title: "Old Seed",
            documentBody: """
            ## Objective
            Older seeded bootstrap text that must not replace the owner brief.
            """,
            objectiveSummary: "Old seed",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            updatedBy: "system",
            updateSource: .systemSeed,
            createdAt: createdAt.addingTimeInterval(120),
            updatedAt: createdAt.addingTimeInterval(120)
        )
    )
    #expect(afterSeedAttempt.primaryDocumentBody == savedDocument)

    let finalReloadedStore = PortfolioStrategyBriefStore(
        fileURL: fileURL,
        now: { createdAt.addingTimeInterval(240) }
    )
    let finalReloaded = try #require(await finalReloadedStore.load())
    #expect(finalReloaded.primaryDocumentBody == savedDocument)
    #expect(finalReloaded.updateSource == .userEdited)
}

@Test("PortfolioStrategyBriefStore backfills a missing persisted document body without changing the visible brief")
func portfolioStrategyBriefStoreBackfillsMissingPersistedDocumentBody() async throws {
    let root = makePMTempDirectory(name: "portfolio-strategy-brief-document-backfill")
    let fileURL = root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let createdAt = Date(timeIntervalSince1970: 1_701_100_038)

    let legacyJSON = """
    {
      "schemaVersion" : 1,
      "brief" : {
        "briefId" : "\(PortfolioStrategyBrief.singletonID)",
        "title" : "Current Portfolio Strategy Brief",
        "objectiveSummary" : "Legacy objective that still anchors the current visible brief.",
        "keyThemes" : ["technology infrastructure", "Owner durability"],
        "currentRiskPosture" : "Moderate.",
        "materialDevelopments" : ["major change"],
        "nonMaterialDevelopments" : ["minor note"],
        "reviewEscalationPosture" : "Escalate only material changes.",
        "updatedBy" : "legacy system",
        "updateSource" : "\(PortfolioStrategyBriefUpdateSource.pmControlPlane.rawValue)",
        "createdAt" : "\(DateCodec.formatISO8601(createdAt))",
        "updatedAt" : "\(DateCodec.formatISO8601(createdAt))"
      }
    }
    """
    try Data(legacyJSON.utf8).write(to: fileURL)

    let store = PortfolioStrategyBriefStore(fileURL: fileURL, now: { createdAt.addingTimeInterval(120) })
    let loaded = try #require(await store.load())

    #expect(loaded.documentBody?.isEmpty == false)
    #expect(loaded.primaryDocumentBody.contains("Legacy objective that still anchors the current visible brief."))
    #expect(loaded.primaryDocumentBody.contains("## Review Posture"))

    let reloadedStore = PortfolioStrategyBriefStore(fileURL: fileURL, now: { createdAt.addingTimeInterval(240) })
    let reloaded = try #require(await reloadedStore.load())
    #expect(reloaded.documentBody == loaded.documentBody)
    #expect(reloaded.primaryDocumentBody == loaded.primaryDocumentBody)
}

@Test("PortfolioStrategyBriefStore rejects a non-owner stale legacy placeholder brief when a newer owner brief already exists")
func portfolioStrategyBriefStoreRejectsNonOwnerLegacyPlaceholderRegression() async throws {
    let root = makePMTempDirectory(name: "portfolio-strategy-brief-legacy-placeholder-regression")
    let fileURL = root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let createdAt = Date(timeIntervalSince1970: 1_701_100_040)
    let store = PortfolioStrategyBriefStore(fileURL: fileURL, now: { createdAt })

    let ownerDocument = """
    ## Objective
    Keep the actual owner-authored brief current everywhere.

    ## Key Themes
    - Concentration discipline
    - PM-review-first posture

    ## Full Brief Appendix
    This distinctive body must not be replaced by the old starter placeholder.
    """
    _ = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Owner Brief",
            documentBody: ownerDocument,
            objectiveSummary: "Keep the actual owner-authored brief current everywhere.",
            currentRiskPosture: "Moderate.",
            reviewEscalationPosture: "Escalate only material changes.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    )

    let placeholderAttempt = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: """
            ## Example Technology Research Portfolio

            ### 1. Purpose

            This charter defines the strategic foundation, investment principles, portfolio construction philosophy, and operating framework for the Example Technology Research Portfolio.

            This is not a passive thematic portfolio. It is an actively managed, research-intensive example strategy that reviews both opportunity and instability across a technology cycle.

            ### 2. Core Strategic View

            The central research question is how technology adoption and infrastructure constraints may affect the opportunity set over the next 24 months.
            """,
            objectiveSummary: "## Example Technology Research Portfolio",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: createdAt.addingTimeInterval(120),
            updatedAt: createdAt.addingTimeInterval(120)
        )
    )

    #expect(placeholderAttempt.primaryDocumentBody == ownerDocument)
    #expect(await store.drainLoadDiagnostics().contains { $0.contains("ignored_legacy_placeholder_regression") })

    let reloadedStore = PortfolioStrategyBriefStore(fileURL: fileURL, now: { createdAt.addingTimeInterval(240) })
    let reloaded = try #require(await reloadedStore.load())
    #expect(reloaded.primaryDocumentBody == ownerDocument)
    #expect(reloaded.primaryDocumentBody.contains("old starter placeholder") == true)
}

@Test("PortfolioStrategyBriefStore allows an owner-authored full brief replacement even when it resembles the legacy template")
func portfolioStrategyBriefStoreAllowsOwnerEditedLegacyShapedReplacement() async throws {
    let root = makePMTempDirectory(name: "portfolio-strategy-brief-owner-edited-legacy-shape")
    let fileURL = root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let createdAt = Date(timeIntervalSince1970: 1_701_100_041)
    let store = PortfolioStrategyBriefStore(fileURL: fileURL, now: { createdAt })

    let initialOwnerDocument = """
    ## Objective
    Keep the actual owner-authored brief current everywhere.

    ## Key Themes
    - Concentration discipline
    - PM-review-first posture

    ## Full Brief Appendix
    This distinctive body must not be replaced unless the owner actually saves a new brief.
    """
    _ = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Owner Brief",
            documentBody: initialOwnerDocument,
            objectiveSummary: "Keep the actual owner-authored brief current everywhere.",
            currentRiskPosture: "Moderate.",
            reviewEscalationPosture: "Escalate only material changes.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    )

    let ownerReplacement = """
    ## Example Technology Research Portfolio

    ### 1. Purpose

    This is the owner-authored long-form brief and it should persist exactly as saved, even if it shares headings with the old template.

    ### 2. Core Strategic View

    The central research question is how technology adoption and infrastructure constraints may affect the opportunity set over the next 24 months.

    ### 3. Operating Requirements

    Save the full pasted body exactly as entered by the owner.
    """
    let savedReplacement = try await store.upsert(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: ownerReplacement,
            objectiveSummary: "## Example Technology Research Portfolio",
            currentRiskPosture: "",
            reviewEscalationPosture: "",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: createdAt.addingTimeInterval(120),
            updatedAt: createdAt.addingTimeInterval(120)
        )
    )

    #expect(savedReplacement.primaryDocumentBody == ownerReplacement)
    #expect(await store.drainLoadDiagnostics().contains { $0.contains("ignored_legacy_placeholder_regression") } == false)

    let reloadedStore = PortfolioStrategyBriefStore(fileURL: fileURL, now: { createdAt.addingTimeInterval(240) })
    let reloaded = try #require(await reloadedStore.load())
    #expect(reloaded.primaryDocumentBody == ownerReplacement)
    #expect(reloaded.primaryDocumentBody.contains("owner-authored long-form brief"))
}

@Test("PM delegation observability summary separates launch health, workflow state, and intended runtime")
func pmDelegationObservabilitySummaryReflectsBoundedState() {
    let now = Date(timeIntervalSince1970: 1_701_100_050)
    let charterPolicy = AnalystRuntimePolicy(
        runtimeIdentifier: "gpt-5-mini",
        reasoningMode: .standard,
        policySource: .charterDefault,
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Delegated task",
        description: "Track adoption frictions.",
        status: .inProgress,
        createdAt: now,
        updatedAt: now,
        checkpoint: AnalystTaskCheckpoint(
            checkpointID: "checkpoint-1",
            taskId: "task-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            summary: "Checkpoint updated after delegation launch.",
            linkedEvidenceBundleIDs: ["bundle-1"],
            updatedAt: now.addingTimeInterval(60)
        )
    )
    let delegation = PMDelegationRecord(
        delegationId: "delegation-1",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-1",
        title: "Investigate adoption lag",
        rationale: "Need bounded PM-readable status.",
        requestedOutputs: [.finding, .signal, .checkpointUpdate],
        status: .completed,
        lastLaunch: PMDelegationLastLaunch(
            launchedAt: now.addingTimeInterval(30),
            status: .degradedExternalEvidence,
            summary: "Degraded external evidence: host=example.com category=http_status"
        ),
        linkedFindingIDs: ["finding-1"],
        linkedSignalIDs: ["signal-1"],
        createdAt: now,
        updatedAt: now.addingTimeInterval(60)
    )

    let summary = makePMDelegationObservabilitySummary(
        delegation: delegation,
        charterDefaultRuntimePolicy: charterPolicy,
        task: task
    )

    #expect(summary.launchHealth == .degradedExternalEvidence)
    #expect(summary.executionState == .completed)
    #expect(summary.workflowState == .awaitingDownstreamReview)
    #expect(summary.intendedRuntimePolicy?.runtimeIdentifier == "gpt-5-mini")
    #expect(summary.producedOutputs == [.finding, .signal, .checkpointUpdate])
}

@Test("Delegation observability marks stale launched work distinctly from healthy running work")
func pmDelegationObservabilityMarksStaleProgress() {
    let now = Date(timeIntervalSince1970: 1_744_200_000)
    let delegation = PMDelegationRecord(
        delegationId: "delegation-stale",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Stale run",
        rationale: "Need conservative stale detection.",
        requestedOutputs: [.finding],
        status: .issued,
        lastLaunch: PMDelegationLastLaunch(
            launchedAt: now.addingTimeInterval(-400),
            status: .progressing,
            summary: "Evidence inputs were assembled.",
            lastProgressAt: now.addingTimeInterval(-300),
            progressStage: "evidence_ready"
        ),
        createdAt: now.addingTimeInterval(-500),
        updatedAt: now.addingTimeInterval(-300)
    )

    let summary = makePMDelegationObservabilitySummary(
        delegation: delegation,
        now: now
    )

    #expect(summary.executionState == .stale)
    #expect(summary.progressStage == "evidence_ready")
    #expect(summary.progressSummary == "Evidence inputs were assembled.")
}

@Test("PM command-center snapshot summarizes attention, delegation health, and review counts")
func pmCommandCenterSnapshotSummarizesSupervisoryState() {
    let now = Date(timeIntervalSince1970: 1_701_100_080)
    let charterPolicy = AnalystRuntimePolicy(
        runtimeIdentifier: "gpt-5-mini",
        reasoningMode: .standard,
        policySource: .charterDefault,
        createdAt: now,
        updatedAt: now
    )
    let charter = AnalystCharter(
        charterId: "charter-1",
        analystId: "analyst-1",
        title: "Tech Analyst",
        coverageScope: "US tech",
        strategyFamily: "Long/short",
        summary: "Track platform and technology adoption shifts.",
        duties: ["Produce findings"],
        constraints: ["No trade authority"],
        expectedOutputs: ["finding", "signal"],
        defaultRuntimePolicy: charterPolicy,
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: charter.charterId,
        title: "Check hyperscaler capex",
        description: "Monitor whether deployment cadence is accelerating.",
        status: .inProgress,
        createdAt: now,
        updatedAt: now
    )
    let delegations = [
        PMDelegationRecord(
            delegationId: "delegation-healthy",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: charter.charterId,
            taskId: task.taskId,
            title: "Healthy launch",
            rationale: "Normal analyst run.",
            requestedOutputs: [.finding],
            status: .issued,
            lastLaunch: PMDelegationLastLaunch(
                launchedAt: now,
                status: .healthy,
                summary: "Healthy launch."
            ),
            createdAt: now,
            updatedAt: now
        ),
        PMDelegationRecord(
            delegationId: "delegation-degraded",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: charter.charterId,
            title: "Degraded launch",
            rationale: "External evidence degraded.",
            requestedOutputs: [.finding, .signal],
            status: .issued,
            lastLaunch: PMDelegationLastLaunch(
                launchedAt: now,
                status: .degradedExternalEvidence,
                summary: "Degraded external evidence."
            ),
            linkedFindingIDs: ["finding-1"],
            createdAt: now,
            updatedAt: now
        ),
        PMDelegationRecord(
            delegationId: "delegation-failed",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: charter.charterId,
            title: "Failed launch",
            rationale: "Worker launch failed.",
            requestedOutputs: [.finding],
            status: .completed,
            lastLaunch: PMDelegationLastLaunch(
                launchedAt: now,
                status: .failed,
                summary: "Launch failed."
            ),
            createdAt: now,
            updatedAt: now
        )
    ]
    let approvalRequests = [
        PMApprovalRequest(
            approvalRequestId: "approval-1",
            pmId: "pm-1",
            subject: "Approve exposure reduction",
            rationale: "Risk concentration remains elevated.",
            requestType: .portfolioAction,
            status: .pending,
            createdAt: now,
            updatedAt: now
        ),
        PMApprovalRequest(
            approvalRequestId: "approval-2",
            pmId: "pm-1",
            subject: "Resolved request",
            rationale: "Already handled.",
            requestType: .other,
            status: .resolved,
            createdAt: now,
            updatedAt: now
        )
    ]
    let decisions = [
        PMDecisionRecord(
            decisionId: "decision-1",
            pmId: "pm-1",
            title: "Reduce gross exposure",
            summary: "Prefer lower beta until signal quality improves.",
            decisionType: .recommendation,
            status: .active,
            createdAt: now,
            updatedAt: now
        ),
        PMDecisionRecord(
            decisionId: "decision-2",
            pmId: "pm-1",
            title: "Superseded note",
            summary: "Old guidance.",
            decisionType: .other,
            status: .superseded,
            createdAt: now,
            updatedAt: now
        )
    ]
    let signals = [
        Signal(
            signalId: "signal-owner-review",
            createdAt: now,
            updatedAt: now,
            status: .new,
            symbols: ["AAPL"],
            direction: .bullish,
            horizon: .swing,
            confidence: 0.84,
            score: 0.86,
            positionStatement: "High-conviction setup",
            recommendedAction: .draftProposal,
            evidence: [],
            provenance: SignalProvenance(sourceJobId: nil, scoringVersion: "test")
        ),
        Signal(
            signalId: "signal-new",
            createdAt: now,
            updatedAt: now,
            status: .new,
            symbols: ["AAPL"],
            direction: .bullish,
            horizon: .swing,
            confidence: 0.7,
            score: 0.75,
            positionStatement: "Positive setup",
            recommendedAction: .notifyOnly,
            evidence: [],
            provenance: SignalProvenance(sourceJobId: nil, scoringVersion: "test")
        ),
        Signal(
            signalId: "signal-acked",
            createdAt: now,
            updatedAt: now,
            status: .acknowledged,
            symbols: ["MSFT"],
            direction: .neutral,
            horizon: .swing,
            confidence: 0.6,
            score: 0.62,
            positionStatement: "Reviewed setup",
            recommendedAction: .notifyOnly,
            evidence: [],
            provenance: SignalProvenance(sourceJobId: nil, scoringVersion: "test")
        )
    ]
    let proposals = [
        ProposalRow(
            id: "proposal-draft",
            title: "Draft proposal",
            status: .draft,
            updatedAt: now,
            strategyId: "heartbeat",
            createdBy: "pm"
        ),
        ProposalRow(
            id: "proposal-approved",
            title: "Approved proposal",
            status: .approvedPaper,
            updatedAt: now,
            strategyId: "heartbeat",
            createdBy: "pm"
        )
    ]

    let snapshot = makePMCommandCenterSnapshot(
        delegations: delegations,
        charters: [charter],
        tasks: [task],
        approvalRequests: approvalRequests,
        decisions: decisions,
        signals: signals,
        proposals: proposals
    )

    #expect(snapshot.activeDelegationsCount == 1)
    #expect(snapshot.pendingApprovalRequestsCount == 1)
    #expect(snapshot.activeDecisionCount == 1)
    #expect(snapshot.newSignalsCount == 1)
    #expect(snapshot.fyiSignalsCount == 1)
    #expect(snapshot.awaitingProposalCount == 1)
    #expect(snapshot.degradedDelegationsCount == 1)
    #expect(snapshot.failedDelegationsCount == 1)
}

@Test("Resolved worker launch issues leave delegation history traceable but exit active exception counts")
func resolvedPMDelegationWorkerIssueExitsActiveExceptionCounts() {
    let now = Date(timeIntervalSince1970: 1_801_100_080)
    let charter = AnalystCharter(
        charterId: "charter-1",
        analystId: "analyst-1",
        title: "Tech Analyst",
        coverageScope: "US tech",
        strategyFamily: "Long/short",
        summary: "Track technology.",
        createdAt: now,
        updatedAt: now
    )
    let unresolved = PMDelegationRecord(
        delegationId: "delegation-unresolved",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: charter.charterId,
        title: "Failed launch",
        rationale: "Worker launch failed.",
        requestedOutputs: [.finding],
        status: .issued,
        lastLaunch: PMDelegationLastLaunch(
            launchedAt: now,
            status: .failed,
            summary: "Could not connect to the server."
        ),
        createdAt: now,
        updatedAt: now
    )
    let resolved = PMDelegationRecord(
        delegationId: "delegation-resolved",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: charter.charterId,
        title: "Resolved failed launch",
        rationale: "Old worker launch failed.",
        requestedOutputs: [.finding],
        status: .issued,
        lastLaunch: PMDelegationLastLaunch(
            launchedAt: now,
            status: .failed,
            summary: "Could not connect to the server."
        ),
        issueResolution: PMDelegationIssueResolution(
            resolvedAt: now.addingTimeInterval(60),
            resolvedBy: "owner",
            reason: .ownerDismissed,
            summary: "Superseded by a later successful task."
        ),
        createdAt: now,
        updatedAt: now.addingTimeInterval(60)
    )

    let unresolvedSummary = makePMDelegationObservabilitySummary(delegation: unresolved)
    let resolvedSummary = makePMDelegationObservabilitySummary(delegation: resolved)
    let snapshot = makePMCommandCenterSnapshot(
        delegations: [unresolved, resolved],
        charters: [charter],
        tasks: [],
        approvalRequests: [],
        decisions: [],
        signals: [],
        proposals: []
    )

    #expect(isActivePMDelegationWorkerIssue(delegation: unresolved, summary: unresolvedSummary))
    #expect(isActivePMDelegationWorkerIssue(delegation: resolved, summary: resolvedSummary) == false)
    #expect(resolvedSummary.workflowState == .resolved)
    #expect(snapshot.failedDelegationsCount == 1)
    #expect(snapshot.activeDelegationsCount == 0)
}

@Test("Analyst memo readable presentation keeps owner summary primary and provenance secondary")
func analystMemoReadablePresentationIsSummaryFirst() {
    let now = Date(timeIntervalSince1970: 1_701_200_000)
    let policy = AnalystRuntimePolicy(
        runtimeIdentifier: "gpt-5",
        reasoningMode: .deliberate,
        policySource: .pmDelegationOverride,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-1",
        delegationId: "delegation-1",
        findingId: "finding-1",
        evidenceBundleId: "bundle-1",
        title: "Technology Research Memo",
        executiveSummary: "Power and deployment frictions still cap near-term upside.",
        currentView: "Stay constructive long term but avoid treating the current ramp as frictionless.",
        evidenceSummary: "Recent evidence still points to supply, power, and enterprise adoption friction.",
        uncertaintySummary: "Key external evidence was partial, which lowers confidence.",
        recommendedNextStep: "Keep the thesis open and ask for one follow-up evidence pass before escalating.",
        confidence: 0.64,
        runtimeProvenance: AnalystRuntimeProvenance(
            intendedPolicy: policy,
            actualRuntimeIdentifier: "deterministic_local[gpt-5]",
            actualReasoningMode: .deliberate,
            launchedAt: now
        ),
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystMemoReadablePresentation(memo)

    #expect(presentation.requestedModelSummary == "gpt-5 (deliberate reasoning)")
    #expect(presentation.executionUsedSummary == "Local synthesis profile gpt-5 with deliberate reasoning")
    #expect(presentation.executiveSummary == memo.executiveSummary)
    #expect(presentation.currentView == memo.currentView)
    #expect(presentation.recommendedNextStep == memo.recommendedNextStep)
    #expect(presentation.confidenceSummary == "64%")
    #expect(presentation.detailSections.map(\.title) == [
        "Supporting Evidence",
        "Risks And Uncertainty",
        "Technical Provenance"
    ])
    #expect(presentation.detailSections.last?.body.contains("Delegation: delegation-1") == true)
    #expect(presentation.detailSections.last?.body.contains("Finding: finding-1") == true)
}

@Test("Analyst memo readable presentation surfaces fallback execution honestly")
func analystMemoReadablePresentationSurfacesFallbackExecution() {
    let now = Date(timeIntervalSince1970: 1_743_300_450)
    let policy = AnalystRuntimePolicy(
        runtimeIdentifier: "gpt-5",
        reasoningMode: .deliberate,
        policySource: .pmDelegationOverride,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-fallback",
        analystId: "analyst-1",
        delegationId: "delegation-1",
        findingId: "finding-1",
        title: "Fallback runtime memo",
        executiveSummary: "The memo should make fallback execution visible.",
        currentView: "Bounded fallback execution still produced usable output.",
        evidenceSummary: "Current evidence remains bounded.",
        uncertaintySummary: "Configured runtime did not stay on the primary path.",
        recommendedNextStep: "Review the configured runtime before relying on it again.",
        confidence: 0.58,
        runtimeProvenance: AnalystRuntimeProvenance(
            intendedPolicy: policy,
            actualRuntimeIdentifier: "deterministic_local[gpt-4.1-mini]",
            actualReasoningMode: .standard,
            launchedAt: now
        ),
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystMemoReadablePresentation(memo)

    #expect(
        presentation.executionUsedSummary
            == "Local synthesis profile gpt-4.1-mini with standard reasoning (fallback from gpt-5 (deliberate reasoning))"
    )
    #expect(
        presentation.detailSections.last?.body.contains(
            "Execution used: Local synthesis profile gpt-4.1-mini with standard reasoning (fallback from gpt-5 (deliberate reasoning))"
        ) == true
    )
}

@Test("PM delegation readable presentation stays compact while retaining disclosure details")
func pmDelegationReadablePresentationSupportsProgressiveDisclosure() {
    let now = Date(timeIntervalSince1970: 1_701_200_100)
    let policy = AnalystRuntimePolicy(
        runtimeIdentifier: "gpt-4.1-mini",
        reasoningMode: .standard,
        policySource: .charterDefault,
        createdAt: now,
        updatedAt: now
    )
    let delegation = PMDelegationRecord(
        delegationId: "delegation-1",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-1",
        title: "Recommendation scenario",
        rationale: "Need a readable owner-facing delegation summary.",
        requestedOutputs: [.finding, .signal],
        status: .completed,
        lastLaunch: PMDelegationLastLaunch(
            launchedAt: now,
            status: .degradedExternalEvidence,
            summary: "Degraded external evidence: category=no_approved_sources"
        ),
        lastRuntimeProvenance: AnalystRuntimeProvenance(
            intendedPolicy: policy,
            actualRuntimeIdentifier: "deterministic_local[gpt-4.1-mini]",
            actualReasoningMode: .standard,
            launchedAt: now
        ),
        linkedFindingIDs: ["finding-1"],
        linkedSignalIDs: ["signal-1"],
        linkedProposalIDs: [],
        createdAt: now,
        updatedAt: now
    )
    let summary = PMDelegationObservabilitySummary(
        intendedRuntimePolicy: policy,
        producedOutputs: [.finding, .signal],
        launchHealth: .degradedExternalEvidence,
        executionState: .completed,
        workflowState: .awaitingDownstreamReview
    )

    let presentation = makePMDelegationReadablePresentation(
        delegation: delegation,
        charterTitle: "Technology Research Analyst",
        taskTitle: "Recommendation task",
        observability: summary,
        latestOutputSummary: "Signal signal-1"
    )

    #expect(presentation.subheadline == "Technology Research Analyst • Recommendation task")
    #expect(presentation.outcomeSummary.contains("degraded by external evidence limits"))
    #expect(presentation.outcomeSummary.contains("latest launch completed"))
    #expect(presentation.outcomeSummary.contains("Useful downstream output is available for review."))
    #expect(!presentation.outcomeSummary.contains("Latest PM direction"))
    #expect(presentation.requestedModelSummary == "gpt-4.1-mini (standard reasoning)")
    #expect(presentation.executionUsedSummary == "Local synthesis profile gpt-4.1-mini with standard reasoning")
    #expect(presentation.latestOutputSummary == "Signal signal-1")
    #expect(presentation.detailSections.map { $0.title } == [
        "Delegation Rationale",
        "Latest Launch Summary",
        "Execution Progress",
        "Linked Artifacts"
    ])
}

@Test("PM delegation readable presentation explains latest PM follow-up distinctly")
func pmDelegationReadablePresentationExplainsLatestPMFollowUp() {
    let now = Date(timeIntervalSince1970: 1_701_200_140)
    let delegation = PMDelegationRecord(
        delegationId: "delegation-2",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Technology follow-up",
        rationale: "Need a clearer PM-facing follow-up summary.",
        requestedOutputs: [.finding],
        status: .completed,
        followUpActions: [
            PMAnalystFollowUpAction(
                actionId: "follow-up-1",
                actionType: .requestStrongerEvidence,
                summary: "The direction is plausible, but the proof is still too thin.",
                createdAt: now
            )
        ],
        createdAt: now,
        updatedAt: now
    )
    let summary = PMDelegationObservabilitySummary(
        intendedRuntimePolicy: nil,
        producedOutputs: [],
        launchHealth: .healthy,
        workflowState: .awaitingDownstreamReview
    )

    let presentation = makePMDelegationReadablePresentation(
        delegation: delegation,
        charterTitle: "Technology Analyst",
        taskTitle: "Technology follow-up",
        observability: summary,
        latestOutputSummary: "Memo memo-1"
    )

    #expect(presentation.outcomeSummary.contains("Latest PM direction: The PM wants stronger proof before leaning on the current conclusion."))
    #expect(presentation.detailSections.map(\.title).contains("Latest PM Follow-Up"))
}

@Test("Running job snapshots surface only active work and sort newest first")
func runningJobSnapshotsFilterAndSortActiveWork() {
    let now = Date(timeIntervalSince1970: 1_701_300_000)
    let jobs = [
        JobSummary(
            jobId: "job-complete",
            type: .rssPoll,
            status: .succeeded,
            createdAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-10),
            progress: 1.0,
            message: "done",
            proposalId: nil,
            runId: nil
        ),
        JobSummary(
            jobId: "job-running",
            type: .analystSignals,
            status: .running,
            createdAt: now.addingTimeInterval(-200),
            updatedAt: now.addingTimeInterval(-20),
            progress: 0.4,
            message: "processing latest events",
            proposalId: nil,
            runId: nil
        ),
        JobSummary(
            jobId: "job-queued",
            type: .maintenanceRetention,
            status: .queued,
            createdAt: now.addingTimeInterval(-100),
            updatedAt: now.addingTimeInterval(-5),
            progress: nil,
            message: "queued by scheduler",
            proposalId: nil,
            runId: nil
        )
    ]

    let snapshots = makeRunningJobSnapshots(jobs: jobs)

    #expect(snapshots.count == 2)
    #expect(snapshots.map(\.jobId) == ["job-queued", "job-running"])
    #expect(snapshots.map(\.status) == [.queued, .running])
    #expect(snapshots.first?.summary == "queued by scheduler")
}

@Test("PMProfileStore persists v1 and supports raw v0 fallback with diagnostics")
func pmProfileStoreRoundTripAndDiagnostics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-profiles")
    let store = PMProfileStore(profilesDirectory: tempRoot)
    let now = Date(timeIntervalSince1970: 1_701_100_100)

    _ = try await store.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Owns mandate and supervisory memory.",
            createdAt: now,
            updatedAt: now
        )
    )

    let loaded = try await store.loadAll()
    #expect(loaded.count == 1)
    #expect(loaded.first?.pmId == "pm-1")

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let legacy = PMProfile(
        pmId: "pm-legacy",
        displayName: "Legacy PM",
        roleSummary: "Legacy raw payload.",
        createdAt: now,
        updatedAt: now
    )
    try encoder.encode(legacy).write(to: tempRoot.appendingPathComponent("legacy.json"))
    try Data("{\"schemaVersion\":99,\"profile\":{\"pmId\":\"bad\"}}".utf8)
        .write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("{bad-json}".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let fallbackStore = PMProfileStore(profilesDirectory: tempRoot)
    let allProfiles = try await fallbackStore.loadAll()
    #expect(allProfiles.map(\.pmId).sorted() == ["pm-1", "pm-legacy"])

    let diagnostics = await fallbackStore.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PMMandateStore persists mandates with predictable ordering")
func pmMandateStoreOrdering() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-mandates")
    let store = PMMandateStore(mandatesDirectory: tempRoot)
    let earlier = Date(timeIntervalSince1970: 1_701_100_200)
    let later = Date(timeIntervalSince1970: 1_701_100_300)

    _ = try await store.upsert(
        PMMandate(
            mandateId: "mandate-older",
            pmId: "pm-1",
            title: "Older",
            objectiveSummary: "Older mandate.",
            scope: "Paper supervision",
            createdAt: earlier,
            updatedAt: earlier
        )
    )
    _ = try await store.upsert(
        PMMandate(
            mandateId: "mandate-newer",
            pmId: "pm-1",
            title: "Newer",
            objectiveSummary: "Newer mandate.",
            scope: "Paper supervision",
            createdAt: later,
            updatedAt: later
        )
    )

    let loaded = try await store.loadAll()
    #expect(loaded.map(\.mandateId) == ["mandate-newer", "mandate-older"])
    #expect(loaded.allSatisfy { $0.pmId == "pm-1" })
}

@Test("PMInstructionStore updates existing instruction instead of duplicating it")
func pmInstructionStoreUpsertReplacesExisting() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-instructions")
    let now = Date(timeIntervalSince1970: 1_701_100_400)
    let timestamps = LockedDateSequence([now, now.addingTimeInterval(60)])
    let store = PMInstructionStore(instructionsDirectory: tempRoot, now: { timestamps.next() })

    _ = try await store.upsert(
        PMInstruction(
            instructionId: "instruction-1",
            pmId: "pm-1",
            title: "Original",
            body: "Original guidance.",
            category: "risk",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )
    let updated = try await store.upsert(
        PMInstruction(
            instructionId: "instruction-1",
            pmId: "pm-1",
            title: "Updated",
            body: "Updated guidance.",
            category: "risk",
            status: .archived,
            createdAt: now,
            updatedAt: now
        )
    )

    let loaded = try await store.loadAll()
    #expect(loaded.count == 1)
    #expect(loaded.first?.title == "Updated")
    #expect(loaded.first?.status == .archived)
    #expect(updated.createdAt == now)
    #expect(updated.updatedAt == now.addingTimeInterval(60))
}

@Test("PMNotebookStore persists notes and handles unsupported schema or corrupt files predictably")
func pmNotebookStoreRoundTripAndDiagnostics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-notebook")
    let store = PMNotebookStore(notebookDirectory: tempRoot)
    let now = Date(timeIntervalSince1970: 1_701_100_500)

    _ = try await store.upsert(
        PMNotebookEntry(
            entryId: "note-1",
            pmId: "pm-1",
            title: "First note",
            body: "Promote durable decisions, not raw transcript history.",
            tags: ["memory"],
            createdAt: now,
            updatedAt: now
        )
    )

    try Data("{\"schemaVersion\":42,\"entry\":{\"entryId\":\"bad\"}}".utf8)
        .write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("not-json".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let reload = PMNotebookStore(notebookDirectory: tempRoot)
    let entries = try await reload.loadAll()
    #expect(entries.count == 1)
    #expect(entries.first?.pmId == "pm-1")
    #expect(entries.first?.tags == ["memory"])

    let diagnostics = await reload.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PMDelegationStore persists delegations with runtime policy override and resilient diagnostics")
func pmDelegationStoreRoundTripAndDiagnostics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-delegations")
    let store = PMDelegationStore(delegationsDirectory: tempRoot)
    let now = Date(timeIntervalSince1970: 1_701_100_600)

    _ = try await store.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            taskId: "task-1",
            title: "Delegation title",
            rationale: "Run a bounded analyst task under PM control.",
            requestedOutputs: [.finding, .signal],
            status: .issued,
            runtimePolicyOverride: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5-mini",
                reasoningMode: .standard,
                policySource: .pmDelegationOverride,
                createdAt: now,
                updatedAt: now
            ),
            lastRuntimeProvenance: AnalystRuntimeProvenance(
                intendedPolicy: AnalystRuntimePolicy(
                    runtimeIdentifier: "gpt-5-mini",
                    reasoningMode: .standard,
                    policySource: .pmDelegationOverride,
                    createdAt: now,
                    updatedAt: now
                ),
                actualRuntimeIdentifier: "deterministic_local",
                launchedAt: now
            ),
            issueResolution: PMDelegationIssueResolution(
                resolvedAt: now.addingTimeInterval(120),
                resolvedBy: "owner",
                reason: .ownerDismissed,
                summary: "Owner dismissed the stale worker failure from active surfaces; durable history remains.",
                supersededByDelegationId: "delegation-successor"
            ),
            linkedFindingIDs: [],
            linkedSignalIDs: [],
            linkedProposalIDs: [],
            createdAt: now,
            updatedAt: now
        )
    )

    try Data("{\"schemaVersion\":42,\"delegation\":{\"delegationId\":\"bad\"}}".utf8)
        .write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("not-json".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let reload = PMDelegationStore(delegationsDirectory: tempRoot)
    let delegations = try await reload.loadAll()
    #expect(delegations.count == 1)
    #expect(delegations.first?.pmId == "pm-1")
    #expect(delegations.first?.charterId == "charter-1")
    #expect(delegations.first?.runtimePolicyOverride?.policySource == .pmDelegationOverride)
    #expect(delegations.first?.lastRuntimeProvenance?.actualRuntimeIdentifier == "deterministic_local")
    #expect(delegations.first?.requestedOutputs == [.finding, .signal])
    #expect(delegations.first?.issueResolution?.reason == .ownerDismissed)
    #expect(delegations.first?.issueResolution?.supersededByDelegationId == "delegation-successor")

    let diagnostics = await reload.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PMDecisionStore persists decisions with linked context and resilient diagnostics")
func pmDecisionStoreRoundTripAndDiagnostics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-decisions")
    let store = PMDecisionStore(decisionsDirectory: tempRoot)
    let now = Date(timeIntervalSince1970: 1_701_100_700)

    _ = try await store.upsert(
        PMDecisionRecord(
            decisionId: "decision-1",
            pmId: "pm-1",
            title: "Reduce exposure recommendation",
            summary: "Recommend reducing exposure until analyst confidence improves.",
            decisionType: .recommendation,
            status: .active,
            delegationId: "delegation-1",
            charterId: "charter-1",
            taskId: "task-1",
            findingId: "finding-1",
            signalId: "signal-1",
            proposalId: "proposal-1",
            createdAt: now,
            updatedAt: now
        )
    )

    try Data("{\"schemaVersion\":42,\"decision\":{\"decisionId\":\"bad\"}}".utf8)
        .write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("not-json".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let reload = PMDecisionStore(decisionsDirectory: tempRoot)
    let decisions = try await reload.loadAll()
    #expect(decisions.count == 1)
    #expect(decisions.first?.pmId == "pm-1")
    #expect(decisions.first?.delegationId == "delegation-1")
    #expect(decisions.first?.proposalId == "proposal-1")

    let diagnostics = await reload.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PMApprovalRequestStore persists approval requests with predictable ordering and boundaries")
func pmApprovalRequestStoreOrderingAndBoundarySemantics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-approval-requests")
    let store = PMApprovalRequestStore(approvalRequestsDirectory: tempRoot)
    let earlier = Date(timeIntervalSince1970: 1_701_100_800)
    let later = Date(timeIntervalSince1970: 1_701_100_900)

    _ = try await store.upsert(
        PMApprovalRequest(
            approvalRequestId: "approval-older",
            pmId: "pm-1",
            subject: "Review defensive reduction",
            rationale: "Need a human decision before routing a related proposal.",
            requestType: .proposalReview,
            status: .pending,
            decisionId: "decision-1",
            delegationId: "delegation-1",
            signalId: "signal-1",
            proposalId: "proposal-1",
            createdAt: earlier,
            updatedAt: earlier
        )
    )
    _ = try await store.upsert(
        PMApprovalRequest(
            approvalRequestId: "approval-newer",
            pmId: "pm-1",
            subject: "Review rebalance timing",
            rationale: "Need a bounded approval-ready record distinct from proposal approval state.",
            requestType: .portfolioAction,
            status: .resolved,
            decisionId: "decision-2",
            delegationId: "delegation-2",
            proposalId: nil,
            ownerResponse: .reviewed,
            ownerRespondedAt: later,
            createdAt: later,
            updatedAt: later
        )
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let legacy = PMApprovalRequest(
        approvalRequestId: "approval-legacy",
        pmId: "pm-1",
        subject: "Legacy review record",
        rationale: "Raw-object fallback should remain safe for PM-layer review metadata.",
        requestType: .other,
        status: .resolved,
        decisionId: "decision-legacy",
        ownerResponse: .approved,
        ownerRespondedAt: later.addingTimeInterval(30),
        createdAt: later.addingTimeInterval(30),
        updatedAt: later.addingTimeInterval(30)
    )
    try encoder.encode(legacy).write(to: tempRoot.appendingPathComponent("legacy.json"))
    try Data("{\"schemaVersion\":42,\"approvalRequest\":{\"approvalRequestId\":\"bad\"}}".utf8)
        .write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("not-json".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let reload = PMApprovalRequestStore(approvalRequestsDirectory: tempRoot)
    let loaded = try await reload.loadAll()
    #expect(loaded.map(\.approvalRequestId) == ["approval-newer", "approval-older", "approval-legacy"])
    #expect(loaded.allSatisfy { $0.pmId == "pm-1" })
    let newer = try #require(loaded.first(where: { $0.approvalRequestId == "approval-newer" }))
    let older = try #require(loaded.first(where: { $0.approvalRequestId == "approval-older" }))
    let legacyLoaded = try #require(loaded.first(where: { $0.approvalRequestId == "approval-legacy" }))
    #expect(newer.ownerResponse == .reviewed)
    #expect(newer.ownerRespondedAt == later)
    #expect(newer.proposalId == nil)
    #expect(older.proposalId == "proposal-1")
    #expect(legacyLoaded.ownerResponse == .approved)

    let diagnostics = await reload.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PortfolioStrategyBriefStore persists singleton brief with fallback decode and bounded diagnostics")
func portfolioStrategyBriefStoreRoundTripAndDiagnostics() async throws {
    let tempRoot = makePMTempDirectory(name: "portfolio-strategy-brief")
    let fileURL = tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    let store = PortfolioStrategyBriefStore(fileURL: fileURL)
    let now = Date(timeIntervalSince1970: 1_701_100_950)

    _ = try await store.upsert(
        PortfolioStrategyBrief(
            objectiveSummary: "Preserve capital while compounding through event-aware tech exposure.",
            keyThemes: ["technology infrastructure", "Earnings sensitivity"],
            currentRiskPosture: "Moderate risk with tighter review around major corporate events.",
            materialDevelopments: ["guidance changes", "major restructuring"],
            nonMaterialDevelopments: ["routine office openings", "minor conference appearances"],
            reviewEscalationPosture: "Escalate potentially material developments to PM review, then decide whether owner review is warranted.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let persisted = try await store.load()
    let persistedBrief = try #require(persisted)
    #expect(persistedBrief.objectiveSummary.contains("event-aware tech exposure"))
    #expect((persistedBrief.documentBody ?? "").contains("## Objective"))
    #expect(persistedBrief.revisionSummary == nil)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let legacy = PortfolioStrategyBrief(
        objectiveSummary: "Legacy fallback brief.",
        keyThemes: ["Legacy"],
        currentRiskPosture: "Legacy risk posture.",
        materialDevelopments: ["earnings surprises"],
        nonMaterialDevelopments: ["office updates"],
        reviewEscalationPosture: "Legacy review posture.",
        updatedBy: "pm-legacy",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    try encoder.encode(legacy).write(to: fileURL)

    let reloadLegacy = PortfolioStrategyBriefStore(fileURL: fileURL)
    let legacyLoaded = try await reloadLegacy.loadOrDefault()
    #expect(legacyLoaded.objectiveSummary == "Legacy fallback brief.")
    #expect(legacyLoaded.updateSource == .pmControlPlane)
    #expect(legacyLoaded.revisionSummary == nil)

    try Data("{\"schemaVersion\":42,\"brief\":{\"briefId\":\"bad\"}}".utf8).write(to: fileURL)
    let reloadUnknown = PortfolioStrategyBriefStore(fileURL: fileURL)
    let fallback = try await reloadUnknown.loadOrDefault()
    #expect(fallback.briefId == PortfolioStrategyBrief.singletonID)
    let unknownDiagnostics = await reloadUnknown.drainLoadDiagnostics()
    #expect(unknownDiagnostics.contains { $0.contains("unsupported_schema_version") })

    try Data("not-json".utf8).write(to: fileURL)
    let reloadCorrupt = PortfolioStrategyBriefStore(fileURL: fileURL)
    let corruptFallback = try await reloadCorrupt.loadOrDefault()
    #expect(corruptFallback.briefId == PortfolioStrategyBrief.singletonID)
    let corruptDiagnostics = await reloadCorrupt.drainLoadDiagnostics()
    #expect(corruptDiagnostics.contains { $0.contains("invalid_document") })
}

@Test("PMCommunicationSessionStore persists sessions with fallback decode and bounded diagnostics")
func pmCommunicationSessionStoreRoundTripAndDiagnostics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-communication-sessions")
    let store = PMCommunicationSessionStore(sessionsDirectory: tempRoot)
    let now = Date(timeIntervalSince1970: 1_701_101_000)

    _ = try await store.upsert(
        PMCommunicationSession(
            sessionId: "session-1",
            channel: .mockTelegram,
            externalConversationId: "chat-1",
            pmId: "pm-1",
            participantId: "owner-1",
            participantDisplayName: "Owner",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let legacy = PMCommunicationSession(
        sessionId: "session-legacy",
        channel: .genericRemote,
        externalConversationId: "chat-legacy",
        pmId: "pm-1",
        participantId: "owner-legacy",
        participantDisplayName: "Legacy Owner",
        status: .closed,
        createdAt: now,
        updatedAt: now
    )
    try encoder.encode(legacy).write(to: tempRoot.appendingPathComponent("legacy.json"))
    try Data("{\"schemaVersion\":42,\"session\":{\"sessionId\":\"bad\"}}".utf8)
        .write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("not-json".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let reload = PMCommunicationSessionStore(sessionsDirectory: tempRoot)
    let sessions = try await reload.loadAll()
    #expect(sessions.map(\.sessionId).sorted() == ["session-1", "session-legacy"])
    #expect(sessions.contains { $0.channel == .mockTelegram })

    let diagnostics = await reload.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PMCommunicationMessageStore persists messages with promotion linkage and predictable ordering")
func pmCommunicationMessageStoreOrderingAndBoundarySemantics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-communication-messages")
    let store = PMCommunicationMessageStore(messagesDirectory: tempRoot)
    let earlier = Date(timeIntervalSince1970: 1_701_101_100)
    let later = Date(timeIntervalSince1970: 1_701_101_200)

    _ = try await store.upsert(
        PMCommunicationMessage(
            messageId: "message-older",
            sessionId: "session-1",
            direction: .incoming,
            senderRole: .owner,
            senderId: "owner-1",
            body: "Older communication record.",
            sentAt: earlier,
            createdAt: earlier,
            updatedAt: earlier
        )
    )
    _ = try await store.upsert(
        PMCommunicationMessage(
            messageId: "message-newer",
            sessionId: "session-1",
            direction: .outgoing,
            senderRole: .pm,
            senderId: "pm-1",
            body: "Promoted this into a durable PM approval request.",
            sentAt: later,
            promotion: PMCommunicationPromotion(
                targetType: .approvalRequest,
                targetId: "approval-1",
                promotedAt: later
            ),
            conversationResolution: PMConversationResolutionState(
                intentClass: .confirmation,
                disposition: .durableApplyNow,
                workingUnderstandingSummary: "Owner confirmed the current bounded PM instruction path.",
                operatingTruthKind: .operatingInstruction,
                operatingTruthSummary: "Carry the bounded operating instruction forward until superseded.",
                operatingTruthBody: "Carry the bounded operating instruction forward until superseded.",
                durableTargetType: .pmInstruction,
                instructionTargetKind: .operatingInstruction,
                durableTitle: "Bounded PM instruction",
                durableBody: "Carry the bounded operating instruction forward until superseded.",
                durableTargetId: "instruction-1",
                sourceMessageIds: ["message-newer"]
            ),
            createdAt: later,
            updatedAt: later
        )
    )

    let loaded = try await store.loadAll()
    #expect(loaded.map(\.messageId) == ["message-newer", "message-older"])
    #expect(loaded.first?.promotion?.targetType == .approvalRequest)
    #expect(loaded.first?.conversationResolution?.durableTargetId == "instruction-1")
    #expect(loaded.first?.conversationResolution?.operatingTruthSummary == "Carry the bounded operating instruction forward until superseded.")
    #expect(loaded.last?.promotion == nil)
}

@Test("PMInteractionMemoryStore persists durable retrieved interaction memory with source linkage and resilient diagnostics")
func pmInteractionMemoryStoreRoundTripAndDiagnostics() async throws {
    let tempRoot = makePMTempDirectory(name: "pm-interaction-memory")
    let store = PMInteractionMemoryStore(interactionMemoryDirectory: tempRoot)
    let now = Date(timeIntervalSince1970: 1_701_101_250)

    _ = try await store.upsert(
        PMInteractionMemoryRecord(
            memoryId: "memory-1",
            pmId: "pm-1",
            kind: .ownerPreference,
            title: "Macro review before international changes",
            summary: "The owner prefers macro review before international allocation changes.",
            symbols: ["EFA"],
            themes: ["international", "macro"],
            riskPostures: ["Moderate"],
            recommendationTypes: [PMApprovalRequestType.portfolioAction.rawValue],
            ownerResponsePatterns: [.reviewed],
            sourceCommunicationMessageId: "message-1",
            sourceApprovalRequestId: "approval-1",
            createdAt: now,
            updatedAt: now
        )
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let legacy = PMInteractionMemoryRecord(
        memoryId: "memory-legacy",
        pmId: "pm-1",
        kind: .reviewPreference,
        title: "Concise memos",
        summary: "Keep memos concise.",
        sourceDecisionId: "decision-1",
        createdAt: now.addingTimeInterval(-10),
        updatedAt: now.addingTimeInterval(-10)
    )
    try encoder.encode(legacy).write(to: tempRoot.appendingPathComponent("legacy.json"))
    try Data("{\"schemaVersion\":42,\"memory\":{\"memoryId\":\"bad\"}}".utf8)
        .write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("not-json".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let reload = PMInteractionMemoryStore(interactionMemoryDirectory: tempRoot)
    let loaded = try await reload.loadAll()
    #expect(loaded.map(\.memoryId) == ["memory-1", "memory-legacy"])
    #expect(loaded.first?.sourceCommunicationMessageId == "message-1")
    #expect(loaded.first?.sourceApprovalRequestId == "approval-1")
    #expect(loaded.first?.themes == ["international", "macro"])

    let diagnostics = await reload.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PM approval-request memo presentation is summary-first and keeps technical context secondary")
func pmApprovalRequestMemoPresentationIsOwnerFacing() {
    let now = Date(timeIntervalSince1970: 1_701_101_300)
    let request = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review the PM recommendation",
        rationale: "The PM wants a bounded review outcome before any further proposal handling.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: "decision-1",
        delegationId: "delegation-1",
        findingId: "finding-1",
        createdAt: now,
        updatedAt: now
    )
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Recommendation to keep proposal pending",
        summary: "The PM recommends holding execution until the owner reviews the current evidence quality.",
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "technology adoption check",
        description: "Review current findings.",
        status: .completed,
        createdAt: now,
        updatedAt: now,
        lastCheckpointSummary: "Latest analyst update confirms the thesis but notes degraded external sourcing."
    )
    let finding = AnalystFinding(
        findingId: "finding-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-1",
        title: "Adoption remains intact",
        summary: "Adoption evidence remains positive.",
        thesis: "The thesis remains intact, but source quality was partially degraded during the latest run.",
        symbols: ["NVDA"],
        tags: ["ai"],
        status: .open,
        confidence: 0.71,
        timeHorizon: "quarterly",
        evidenceBundleId: "bundle-1",
        createdAt: now,
        updatedAt: now,
        linkedSignalId: nil,
        linkedProposalId: nil,
    )
    let delegation = PMDelegationRecord(
        delegationId: "delegation-1",
        pmId: "pm-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        taskId: "task-1",
        title: "Check technology adoption",
        rationale: "Need a current read before owner review.",
        requestedOutputs: [.finding],
        status: .completed,
        lastLaunch: PMDelegationLastLaunch(
            launchedAt: now,
            status: .degradedExternalEvidence,
            summary: "Degraded external evidence: no approved sources"
        ),
        createdAt: now,
        updatedAt: now
    )
    let delegationSummary = PMDelegationObservabilitySummary(
        intendedRuntimePolicy: nil,
        producedOutputs: [.finding],
        launchHealth: .degradedExternalEvidence,
        workflowState: .awaitingDownstreamReview
    )

    let memo = makePMApprovalRequestMemoPresentation(
        request: request,
        linkedDecision: decision,
        linkedDelegation: delegation,
        linkedDelegationObservability: delegationSummary,
        linkedTask: task,
        linkedFinding: finding
    )

    #expect(memo.requestedAction.contains("Decide"))
    #expect(memo.whyNow == request.rationale)
    #expect(memo.recommendation == decision.summary)
    #expect(memo.uncertaintySummary?.contains("degraded") == true)
    #expect(memo.closure.status == .awaitingOwner)
    #expect(memo.ownerActionMeaning.contains("Your response tells the PM"))
    #expect(memo.boundaryNote.contains("does not approve proposals"))
    #expect(memo.supportingSections.map { $0.title } == ["Supporting Finding", "Latest Analyst Update", "Current Delegation State"])
    #expect(memo.supportingSections.contains { $0.body.contains("degraded external evidence") })
    #expect(memo.requestedAction.contains("decision-1") == false)
}

@Test("PM decision memo presentation keeps recommendation readable and technical linkage secondary")
func pmDecisionMemoPresentationUsesReadableSupport() {
    let now = Date(timeIntervalSince1970: 1_701_101_400)
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Recommendation to defer approval",
        summary: "The PM recommends deferring approval until the owner reviews the latest evidence quality.",
        decisionType: .recommendation,
        status: .active,
        delegationId: "delegation-1",
        createdAt: now,
        updatedAt: now
    )
    let request = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review PM recommendation",
        rationale: "Owner review is needed because the latest analyst run was degraded.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: decision.decisionId,
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-1",
        analystId: "analyst-1",
        charterId: "charter-1",
        title: "Quality check",
        description: "Check source quality.",
        status: .completed,
        createdAt: now,
        updatedAt: now,
        lastCheckpointSummary: "Analyst confirmed the core thesis and flagged degraded external evidence."
    )
    let memo = makePMDecisionMemoPresentation(
        decision: decision,
        linkedApprovalRequest: request,
        linkedDelegation: nil,
        linkedDelegationObservability: nil,
        linkedTask: task,
        linkedFinding: nil
    )

    #expect(memo.recommendation == decision.summary)
    #expect(memo.whyNow == request.rationale)
    #expect(memo.closure.status == .awaitingOwner)
    #expect(memo.relationshipNote == "Linked PM approval request: Owner decision is still pending. Keep this as the active ask until the owner responds or the PM replaces it.")
    #expect(memo.boundaryNote.contains("separate review and safety gates"))
    #expect(memo.supportingSections.map { $0.title } == ["Related Approval Request", "Latest Analyst Update"])
}

@Test("Recent News Analyst wake-up presentation stays PM-readable and surfaces affected names plus strategy relevance")
func recentNewsWakeUpPresentationSurfacesAffectedNamesAndStrategyContext() {
    let now = Date(timeIntervalSince1970: 1_710_000_000)
    let decision = PMDecisionRecord(
        decisionId: "recent-news-decision-1",
        pmId: "pm-1",
        title: "Recent News Analyst escalation: AAPL, NVDA",
        summary: "Recent normalized news may materially affect the current portfolio context. PM should review before any downstream action.",
        decisionType: .escalation,
        status: .active,
        delegationId: "recent-news-delegation-1",
        taskId: "recent-news-task-1",
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "recent-news-task-1",
        analystId: "recent-news-material-impact-analyst",
        charterId: "charter-recent-news",
        title: "Recent news materiality review: AAPL, NVDA",
        description: "Review recent normalized news for potentially material portfolio impact. Held positions in scope: AAPL LONG qty 10 market value 10000. Watchlist context: NVDA. Portfolio strategy brief objective: Protect core large-cap technology exposure while reacting quickly to guidance changes. Strategy themes: technology platform concentration; earnings sensitivity. Current risk posture: Keep high-conviction holdings, but escalate guidance and restructuring changes quickly. Review posture: Escalate to PM first; owner review only if the PM believes the strategy stance may need to change. Materiality trigger: Guidance and restructuring news may change the current portfolio risk posture. Triggering news: [SEC EDGAR] Apple Inc. filed 8-K (direct_holding_exposure, high_signal_sec_filing) | [Alpaca News] NVIDIA supplier commentary tightens infrastructure capacity outlook (material_keywords=guidance). If the impact is not strong enough for escalation, keep the conclusion bounded and explicit.",
        status: .completed,
        createdAt: now,
        updatedAt: now,
        symbols: ["AAPL", "NVDA"],
        tags: ["recent-news-analyst", "portfolio-material-impact"]
    )
    let memo = AnalystMemo(
        memoId: "memo-1",
        analystId: task.analystId,
        charterId: task.charterId,
        taskId: task.taskId,
        delegationId: decision.delegationId,
        pmId: decision.pmId,
        findingId: "finding-1",
        evidenceBundleId: "bundle-1",
        title: "Recent news materiality review: AAPL, NVDA",
        executiveSummary: "Recent normalized filing and supplier-capacity news may affect the portfolio's current large-cap technology exposure. This memo records a potentially material recent-news case for PM review and stays separate from trading, proposal approval, and safety-state changes.",
        currentView: "The cluster may matter because guidance and restructuring developments could alter current risk posture for held and watched AI names. Confidence is currently 74 percent and remains bounded by event-driven uncertainty.",
        evidenceSummary: "Primary support comes from recent normalized app-owned news.",
        uncertaintySummary: "The effect on current holdings may still depend on follow-up facts.",
        recommendedNextStep: "PM should review this recent-news memo, decide whether the guidance and restructuring signal warrants follow-up, and keep any downstream proposal or trading decision behind the existing separate approval gates. The current review posture is: Escalate to PM first; owner review only if the PM believes the strategy stance may need to change.",
        confidence: 0.74,
        createdAt: now,
        updatedAt: now
    )
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Protect core large-cap technology exposure while reacting quickly to guidance changes.",
        keyThemes: ["technology platform concentration", "earnings sensitivity"],
        currentRiskPosture: "Keep high-conviction holdings, but escalate guidance and restructuring changes quickly.",
        materialDevelopments: ["guidance changes", "restructuring"],
        nonMaterialDevelopments: ["routine conference appearances"],
        reviewEscalationPosture: "Escalate to PM first; owner review only if the stance may need to change.",
        updatedBy: "pm-1",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let positions = [
        PositionRow(id: "pos-aapl", symbol: "AAPL", side: "long", qty: "10", marketValue: "10000")
    ]

    let presentation = makeRecentNewsWakeUpPresentation(
        decision: decision,
        linkedTask: task,
        linkedMemo: memo,
        positions: positions,
        watchlistSymbols: ["AAPL", "NVDA", "MSFT"],
        strategyBrief: strategyBrief
    )

    #expect(presentation.isRecentNewsWakeUp)
    #expect(presentation.originLabel == "Recent News Analyst")
    #expect(presentation.whatHappened.contains("Apple Inc. filed 8-K"))
    #expect(presentation.affectedHoldings == ["AAPL"])
    #expect(presentation.affectedWatchlistOnly == ["NVDA"])
    #expect(presentation.rowAffectedNames == "Holdings: AAPL • Watchlist only: NVDA")
    #expect(presentation.whyItMatters.contains("Guidance and restructuring news"))
    #expect(presentation.strategyRelevance?.contains("Current strategy objective") == true)
    #expect(presentation.strategyRelevance?.contains("Risk posture") == true)
    #expect(presentation.recommendedNextStep.contains("keep any downstream proposal or trading decision behind the existing separate approval gates"))
    #expect(presentation.pmActionGuidance.contains("not proposal approval"))
}

@Test("Portfolio Risk wake-up presentation stays PM-readable and surfaces what changed now")
func portfolioRiskWakeUpPresentationSurfacesWhatChangedAndNextStep() {
    let now = Date(timeIntervalSince1970: 1_720_200_000)
    let decision = PMDecisionRecord(
        decisionId: "portfolio-risk-decision-1",
        pmId: "pm-1",
        title: "Portfolio risk trigger: NVDA",
        summary: "Portfolio Risk sees a bounded risk change that now warrants PM attention.",
        decisionType: .escalation,
        status: .active,
        delegationId: "portfolio-risk-delegation-1",
        charterId: "bench-overlay-portfolio-risk",
        taskId: "portfolio-risk-task-1",
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "portfolio-risk-task-1",
        analystId: "bench-overlay-portfolio-risk-analyst",
        charterId: "bench-overlay-portfolio-risk",
        title: "Portfolio risk review: NVDA",
        description: "Review bounded portfolio-risk trigger conditions for potential PM escalation. Held positions in scope: NVDA 31.0% of exposure; MSFT 18.0% of exposure. Watchlist context: NVDA, AVGO. Portfolio strategy brief objective: Preserve upside while keeping concentrated event risk visible to the PM. Current risk posture: Moderate risk posture with tighter review on oversized single-name exposure. Review posture: Escalate to PM review first; no direct execution authority. Coverage posture: App-owned portfolio posture set the baseline risk read; recent normalized news added catalyst-window context. Concentration posture: Single-name concentration breached threshold: NVDA is 31.0% of exposure versus a 25.0% posture threshold. Clustered risk view: Risk is concentrated across a two-name cluster (NVDA, MSFT) at 49.0% of exposure. Long-vs-short posture: Long-vs-short weighting is 100.0% long / 0.0% short (net +100.0%). Current directional risk is primarily long-side. Escalation posture: PM follow-up warranted. Why now: What changed now: NVDA is now 31.0% of exposure versus 24.0% at the prior review anchor. Concentration moved above the bounded threshold and now requires PM review. Current book posture: Single-name concentration breached threshold plus long-side directional skew. Risk trigger: Portfolio Risk trigger conditions crossed bounded thresholds. NVDA is now 31.0% of current portfolio exposure, up from 24.0% at the prior review anchor. What changed since prior review: NVDA is now 31.0% of exposure versus 24.0% at the prior review anchor. Triggering conditions: single_position_concentration for NVDA. Prior portfolio-risk review anchor: NVDA 24.0% of exposure at the last PM-requested review. The last review anchor came from an ad hoc PM-invoked Portfolio Risk review. This is a bounded Portfolio Risk overlay review. Do not approve trading, proposals, or safety-state changes.",
        status: .completed,
        createdAt: now,
        updatedAt: now,
        symbols: ["NVDA", "AVGO"],
        tags: ["portfolio-risk-analyst", "portfolio-risk-trigger"]
    )
    let memo = AnalystMemo(
        memoId: "memo-risk-1",
        analystId: task.analystId,
        charterId: task.charterId,
        taskId: task.taskId,
        delegationId: decision.delegationId,
        pmId: decision.pmId,
        title: "Portfolio risk review: NVDA",
        executiveSummary: "NVDA now represents an oversized exposure under the current posture and the PM should review it now.",
        currentView: "The position has become more concentrated since the prior review anchor.",
        evidenceSummary: "Primary support comes from app-owned exposure state and the bounded trigger evaluator.",
        uncertaintySummary: "This remains an advisory PM-layer overlay review.",
        recommendedNextStep: "Review the memo, decide whether the exposure stays monitor-only, and keep any downstream proposal or trading decision behind the existing separate approval gates.",
        confidence: 0.76,
        createdAt: now,
        updatedAt: now
    )
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Preserve upside while keeping concentrated event risk visible to the PM.",
        keyThemes: ["single-name concentration", "event-aware supervision"],
        currentRiskPosture: "Moderate risk posture with tighter review on oversized single-name exposure.",
        materialDevelopments: ["single-name concentration"],
        nonMaterialDevelopments: ["small incremental sizing"],
        reviewEscalationPosture: "Escalate to PM review first; no direct execution authority.",
        updatedBy: "pm-1",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let positions = [
        PositionRow(id: "pos-nvda", symbol: "NVDA", side: "long", qty: "10", marketValue: "31000")
    ]

    let presentation = makePortfolioRiskWakeUpPresentation(
        decision: decision,
        linkedTask: task,
        linkedMemo: memo,
        positions: positions,
        watchlistSymbols: ["NVDA", "AVGO"],
        strategyBrief: strategyBrief
    )

    #expect(presentation.isPortfolioRiskWakeUp)
    #expect(presentation.originLabel == "Portfolio Risk Analyst")
    #expect(presentation.whatHappened.contains("NVDA"))
    #expect(presentation.whatChanged.contains("31.0%"))
    #expect(presentation.whyItMattersNow.contains("What changed now"))
    #expect(presentation.whyItMattersNow.contains("Concentration moved above the bounded threshold"))
    #expect(presentation.recommendedNextStep.contains("keep any downstream proposal or trading decision behind the existing separate approval gates"))
    #expect(presentation.pmActionGuidance.contains("not proposal approval"))
    #expect(presentation.affectedHoldings == ["NVDA"])
    #expect(presentation.affectedWatchlistOnly == ["AVGO"])
    #expect(presentation.rowAffectedNames == "Holdings: NVDA • Watchlist only: AVGO")
}

@Test("PM bench routing presentation surfaces sector versus overlay guidance and prior continuity")
func pmBenchRoutingPresentationSurfacesRolesAndContinuity() throws {
    let now = Date(timeIntervalSince1970: 1_710_500_000)
    let charters = StandingAnalystBenchSeed().seededCharters(now: now)
    let technology = try #require(charters.first(where: { $0.charterId == "bench-sector-technology" }))
    let macro = try #require(charters.first(where: { $0.charterId == "bench-overlay-macro-international" }))
    let risk = try #require(charters.first(where: { $0.charterId == "bench-overlay-portfolio-risk" }))

    let task = AnalystTask(
        taskId: "task-tech-1",
        analystId: technology.analystId,
        charterId: technology.charterId,
        title: "Review semiconductor guidance",
        description: "Determine whether technology infrastructure guidance revisions change the current sector view.",
        status: .queued,
        createdAt: now,
        updatedAt: now,
        symbols: ["NVDA", "AMD"],
        contextPack: AnalystContextPack(
            sharedCurrentTruth: AnalystSharedCurrentTruth(
                positions: [],
                watchlistSymbols: ["NVDA", "AMD"],
                portfolioStrategyBrief: nil,
                recentNews: [],
                pmMandates: [],
                pmInstructions: []
            ),
            scopedMemory: AnalystScopedMemorySnapshot(
                memoryId: technology.analystId,
                analystId: technology.analystId,
                charterId: technology.charterId,
                trackedSymbols: ["AMD", "NVDA"],
                trackedThemes: ["ai infrastructure", "guidance risk"],
                openQuestions: ["Does margin guidance alter position sizing assumptions?"],
                recentMemos: [],
                recentFindings: [],
                updatedAt: now
            ),
            assembledAt: now
        )
    )
    let finding = AnalystFinding(
        findingId: "finding-tech-1",
        analystId: technology.analystId,
        charterId: technology.charterId,
        taskId: task.taskId,
        title: "Guidance reset changed the sector interpretation",
        summary: "Tracked guidance revisions across technology infrastructure names now warrant deeper PM review.",
        thesis: "The technology bench analyst already has continuity on technology infrastructure and guidance risk.",
        symbols: ["NVDA"],
        tags: ["ai infrastructure", "guidance risk"],
        status: .open,
        confidence: 0.67,
        timeHorizon: "medium-term",
        evidenceBundleId: "bundle-1",
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-tech-1",
        analystId: technology.analystId,
        charterId: technology.charterId,
        taskId: task.taskId,
        findingId: finding.findingId,
        evidenceBundleId: finding.evidenceBundleId,
        title: "Technology sector view",
        executiveSummary: "technology infrastructure guidance revisions need a refreshed PM read.",
        currentView: "The sector analyst already has continuity on the tracked names and themes.",
        evidenceSummary: "Recent guidance and capex signals are mixed.",
        uncertaintySummary: "More work is needed on second-order demand effects.",
        recommendedNextStep: "Route a bounded follow-up memo if PM wants deeper company-specific review.",
        confidence: 0.64,
        createdAt: now,
        updatedAt: now
    )

    let sections = makePMBenchRoutingSections(
        charters: [macro, risk, technology],
        tasks: [task],
        findings: [finding],
        memos: [memo]
    )

    #expect(sections.map { $0.id } == ["sector", "overlay"])
    #expect(sections.first?.helperText.contains("company, industry, or sector") == true)
    #expect(sections.last?.helperText.contains("cuts across sectors") == true)

    let technologyPresentation = try #require(
        sections.flatMap { $0.candidates }.first(where: { $0.charterId == technology.charterId })
    )
    #expect(technologyPresentation.roleTitle == "Sector Analyst")
    #expect(technologyPresentation.routingHint.contains("company, industry, or sector"))
    #expect(technologyPresentation.sharedContextSummary.contains("positions, watchlist, portfolio strategy, recent news"))
    #expect(technologyPresentation.continuitySummary.contains("Prior work: 1 memo, 1 finding, 1 task."))
    #expect(technologyPresentation.continuitySummary.contains("Tracked symbols: AMD, NVDA."))
    #expect(technologyPresentation.continuitySummary.contains("Standing themes: ai infrastructure, guidance risk."))
    #expect(technologyPresentation.followUpHint?.contains("Macro and International") == true)
    #expect(technologyPresentation.hasContinuity)

    let macroPresentation = try #require(
        sections.flatMap { $0.candidates }.first(where: { $0.charterId == macro.charterId })
    )
    #expect(macroPresentation.roleTitle == "Overlay Analyst")
    #expect(macroPresentation.routingHint.contains("rates, policy, currency, geopolitical, or international"))
    #expect(macroPresentation.continuitySummary.contains("No analyst-specific continuity is recorded yet."))
    #expect(macroPresentation.hasContinuity == false)

    let riskPresentation = try #require(
        sections.flatMap { $0.candidates }.first(where: { $0.charterId == risk.charterId })
    )
    #expect(riskPresentation.roleTitle == "Overlay Analyst")
    #expect(riskPresentation.routingHint.contains("concentration, correlation, event clustering, or strategy-fragility"))
}

@Test("Owner shell hierarchy defaults to command center and keeps PM Inbox advanced")
func ownerShellHierarchyDefaultsToCommandCenterAndKeepsPMInboxAdvanced() {
    #expect(OwnerPrimarySurface.allCases.map(\.rawValue) == [
        "Command Center",
        "Portfolio Watch",
        "News",
        "System Control"
    ])
    #expect(OwnerAdvancedSurface.allCases.contains(.pmInbox))
    #expect(OwnerAdvancedSurface.allCases.contains(.signals))
    #expect(OwnerAdvancedSurface.allCases.contains(.proposals))
    #expect(OwnerAdvancedSurface.allCases.contains { $0.rawValue == "News" } == false)
}

@Test("Owner attention presentation distinguishes user action from PM and analyst workflow")
func ownerAttentionPresentationDistinguishesUserActionFromInternalWorkflow() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 2,
        pendingApprovalRequestsCount: 1,
        ownerActionableApprovalCount: 1,
        activeDecisionCount: 4,
        pmReviewQueueCount: 2,
        newSignalsCount: 3,
        awaitingProposalCount: 2,
        degradedDelegationsCount: 1,
        failedDelegationsCount: 1
    )

    let cards = makeOwnerAttentionCardPresentations(snapshot: snapshot)

    #expect(cards.map(\.kind) == [
        .userActionNeeded,
        .pmReviewing,
        .analystActivity,
        .systemExceptions
    ])
    #expect(cards.first?.title == "Your Review")
    #expect(cards.first?.summary == "1 item is waiting for your decision.")
    #expect(cards.first?.detail.contains("Command Center > Your Decisions") == true)
    #expect(cards.first?.drillDownLabel == "Open Command Center")
    #expect(cards[1].title == "PM Reviewing")
    #expect(cards[1].summary == "2 items are under PM review.")
    #expect(cards[1].detail.contains("standing analyst reports") == true)
    #expect(cards[2].title == "Analyst Activity")
    #expect(cards[2].summary == "2 analyst items are active.")
    #expect(cards[3].title == "System Exceptions")
    #expect(cards[3].summary == "2 system issues need review.")
    #expect(cards[3].detail.contains("failed") == true)
    #expect(cards[3].drillDownLabel == "Open System Control")
}

@Test("Owner recent highlights use explicit drill-down labels and plain PM wording")
func ownerRecentHighlightsUseExplicitLabels() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 1,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 3,
        newSignalsCount: 2,
        awaitingProposalCount: 1,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    let changes = makeOwnerRecentChangePresentations(snapshot: snapshot)

    #expect(changes.map(\.title) == ["Signals", "Proposals"])
    #expect(changes[0].drillDownLabel == "Open Signals")
    #expect(changes[1].drillDownLabel == "Open Proposals")
}

@Test("System exception follow-through groups feed and worker issues in plain language")
func ownerSystemExceptionFollowThroughGroupsCategories() {
    let snapshot = PMCommandCenterSnapshot(
        activeDelegationsCount: 0,
        pendingApprovalRequestsCount: 0,
        activeDecisionCount: 0,
        newSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 1,
        failedDelegationsCount: 2
    )

    let categories = makeOwnerSystemExceptionCategoryPresentations(
        snapshot: snapshot,
        tradeConnectionState: "authenticated",
        marketDataConnectionState: "disconnected",
        workerLinkConnected: false
    )

    #expect(categories.map(\.title) == [
        "Feed Issues",
        "Worker / Launch Issues",
        "Other System Issues"
    ])
    #expect(categories[0].count == 1)
    #expect(categories[0].summary == "Market-data feed is not fully connected yet.")
    #expect(categories[1].count == 4)
    #expect(categories[1].summary.contains("worker link unavailable") == true)
    #expect(categories[1].summary.contains("2 failed launches") == true)
    #expect(categories[1].summary.contains("1 degraded launch") == true)
    #expect(categories[2].count == 0)
}

@Test("System-control storage presentation maps raw buckets into plain language")
func systemControlStoragePresentationMapsRawBucketsIntoPlainLanguage() {
    let summary = StorageFootprintSummary(
        rootPath: "/tmp/app",
        auditBytes: 1_024,
        newsBytes: 2_048,
        jobsBytes: 3_072,
        runsBytes: 4_096,
        barsCacheBytes: 5_120,
        capturedAt: Date(timeIntervalSince1970: 1_720_500_000)
    )

    let categories = makePlainEnglishStorageCategoryPresentations(summary)

    #expect(categories.map(\.title) == [
        "Activity History",
        "News Archive",
        "Job History",
        "Run History",
        "Market Data Cache"
    ])
    #expect(categories.first?.detail.contains("history") == true)
    #expect(categories.last?.bytes == 5_120)
}

@Test("Old job telemetry cleanup presentation is aggregate-only and dry-run first")
func oldJobTelemetryCleanupPresentationIsAggregateOnlyAndDryRunFirst() {
    let job = JobRecord(
        jobId: "maintenance-job-1",
        type: .maintenanceRetention,
        status: .succeeded,
        result: .object([
            "dryRun": .bool(true),
            "areas": .array([
                .object([
                    "area": .string("jobs"),
                    "dryRun": .bool(true),
                    "details": .object([
                        "cleanupKind": .string("job_telemetry"),
                        "cutoff": .string("2026-04-29T00:00:00Z"),
                        "cutoffSource": .string("explicit"),
                        "scannedCount": .number(12_995),
                        "eligibleCount": .number(12_257),
                        "protectedCount": .number(738),
                        "skippedDecodeErrorCount": .number(0),
                        "skippedLinkedProtectedCount": .number(361),
                        "estimatedBytesReclaimable": .number(23_487_000),
                        "appliedCount": .number(0),
                        "appliedBytes": .number(0),
                        "candidateCountByStatus": .object([
                            "succeeded": .number(10_000),
                            "failed": .number(2_000),
                            "canceled": .number(257)
                        ]),
                        "candidateCountByType": .object([
                            "rss_poll": .number(9_000),
                            "portfolio_risk_analyst": .number(2_500),
                            "recent_news_analyst": .number(757)
                        ]),
                        "oldestCandidateTimestamp": .string("2026-01-10T00:00:00Z"),
                        "newestCandidateTimestamp": .string("2026-04-28T23:59:00Z"),
                        "safetyExclusions": .array([
                            .string("queued/running jobs"),
                            .string("schedule running jobs"),
                            .string("linked PM/analyst/proposal/run artifacts")
                        ])
                    ])
                ])
            ])
        ])
    )

    let presentation = makeOldJobTelemetryCleanupPresentation(from: job)

    #expect(presentation?.dryRun == true)
    #expect(presentation?.cutoffSource == "explicit")
    #expect(presentation?.scannedCount == 12_995)
    #expect(presentation?.eligibleCount == 12_257)
    #expect(presentation?.protectedCount == 738)
    #expect(presentation?.skippedLinkedProtectedCount == 361)
    #expect(presentation?.estimatedBytesReclaimable == 23_487_000)
    #expect(presentation?.canApplyAfterPreview == true)
    #expect(presentation?.deletionStateNote == "No files deleted yet.")
    #expect(presentation?.candidateCountByStatus.first?.label == "succeeded")
    #expect(presentation?.candidateCountByType.first?.label == "rss_poll")
    #expect(presentation?.safetyExclusions.contains("schedule running jobs") == true)
}

@Test("Analyst strategy implication presentation keeps strategy traceability bounded and separate from strategy truth")
func analystStrategyImplicationPresentationKeepsStrategyTraceabilityBounded() {
    let now = Date(timeIntervalSince1970: 1_744_000_000)
    let implication = AnalystStrategyImplicationRecord(
        implicationId: "implication-1",
        pmId: "pm-primary",
        implicationKind: .candidateStrategyBriefRevision,
        implicationSummary: "The analyst memo suggests the strategy brief should tighten near-term earnings review posture.",
        whyItMatters: "Current analyst output points to event-risk concentration that the saved strategy brief does not currently spell out explicitly.",
        candidateStrategyBriefRevisionNote: "Consider adding an explicit note about tighter PM review into earnings clusters.",
        candidatePMFollowUpSummary: nil,
        memoId: "memo-1",
        findingId: "finding-1",
        evidenceBundleId: "bundle-1",
        delegationId: "delegation-1",
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystStrategyImplicationReadablePresentation(implication)

    #expect(presentation.implicationLabel == "Candidate Strategy Brief Revision")
    #expect(presentation.implicationSummary.contains("strategy brief should tighten") == true)
    #expect(presentation.whyItMatters.contains("saved strategy brief") == true)
    #expect(presentation.candidateStrategyBriefRevisionNote?.contains("earnings clusters") == true)
    #expect(presentation.candidatePMFollowUpSummary == nil)
    #expect(
        presentation.linkedArtifactsSummary
            == "Memo memo-1 • Finding finding-1 • Evidence bundle bundle-1 • Delegation delegation-1"
    )
    #expect(presentation.boundaryNote.contains("does not change the saved Portfolio Strategy Brief") == true)
    #expect(presentation.boundaryNote.contains("approve anything") == true)
}

@Test("Analyst strategy implication presentation omits empty optional follow-up blocks")
func analystStrategyImplicationPresentationOmitsEmptyOptionalBlocks() {
    let now = Date(timeIntervalSince1970: 1_744_000_120)
    let implication = AnalystStrategyImplicationRecord(
        implicationId: "implication-2",
        pmId: "pm-primary",
        implicationKind: .worthMonitoring,
        implicationSummary: "The memo is relevant enough to keep monitoring but not enough to revise strategy.",
        whyItMatters: "There is a bounded watch item, but no present strategy-brief change case.",
        candidateStrategyBriefRevisionNote: "   ",
        candidatePMFollowUpSummary: "\n",
        memoId: "memo-2",
        findingId: nil,
        evidenceBundleId: nil,
        delegationId: nil,
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystStrategyImplicationReadablePresentation(implication)

    #expect(presentation.implicationLabel == "Worth Monitoring")
    #expect(presentation.candidateStrategyBriefRevisionNote == nil)
    #expect(presentation.candidatePMFollowUpSummary == nil)
    #expect(presentation.linkedArtifactsSummary == "Memo memo-2")
}

@Test("Analyst strategy follow-up candidate presentation stays bounded and distinct from strategy truth")
func analystStrategyFollowUpCandidatePresentationStaysBounded() {
    let now = Date(timeIntervalSince1970: 1_744_000_240)
    let candidate = AnalystStrategyFollowUpCandidateRecord(
        candidateId: "candidate-1",
        implicationId: "implication-1",
        pmId: "pm-primary",
        followUpKind: .strategyBriefRevision,
        status: .open,
        candidateSummary: "Queue a strategy brief tightening around earnings-event review posture.",
        candidateDetail: "This should remain a candidate revision until the PM explicitly applies a real brief update.",
        memoId: "memo-1",
        findingId: "finding-1",
        evidenceBundleId: "bundle-1",
        delegationId: "delegation-1",
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystStrategyFollowUpCandidateReadablePresentation(candidate)

    #expect(presentation.kindLabel == "Strategy Brief Revision Candidate")
    #expect(presentation.statusLabel == "Open")
    #expect(presentation.candidateSummary.contains("earnings-event review posture") == true)
    #expect(
        presentation.linkedArtifactsSummary
            == "Memo memo-1 • Finding finding-1 • Evidence bundle bundle-1 • Delegation delegation-1"
    )
    #expect(presentation.resultSummary == "No durable strategic change has been recorded yet.")
    #expect(presentation.closureSummary.contains("still open") == true)
    #expect(presentation.boundaryNote.contains("does not change the saved Portfolio Strategy Brief") == true)
    #expect(presentation.boundaryNote.contains("create a PM instruction or mandate by itself") == true)
}

@Test("Closed strategy follow-up candidate presentation states the resulting strategic change truthfully")
func closedAnalystStrategyFollowUpCandidatePresentationStatesResultTruthfully() {
    let now = Date(timeIntervalSince1970: 1_744_000_640)
    let appliedCandidate = AnalystStrategyFollowUpCandidateRecord(
        candidateId: "candidate-applied",
        implicationId: "implication-1",
        pmId: "pm-primary",
        followUpKind: .strategyBriefRevision,
        status: .appliedToStrategyBrief,
        candidateSummary: "Tighten event-review posture in the strategy brief.",
        candidateDetail: "Apply the current bounded revision through the explicit path.",
        appliedStrategyBriefId: PortfolioStrategyBrief.singletonID,
        closedAt: now,
        createdAt: now,
        updatedAt: now
    )
    let dismissedCandidate = AnalystStrategyFollowUpCandidateRecord(
        candidateId: "candidate-dismissed",
        implicationId: "implication-2",
        pmId: "pm-primary",
        followUpKind: .monitorOnly,
        status: .dismissed,
        candidateSummary: "No further follow-up is needed.",
        candidateDetail: "Keep it closed with no durable strategy change.",
        closedAt: now,
        createdAt: now,
        updatedAt: now
    )

    let appliedPresentation = makeAnalystStrategyFollowUpCandidateReadablePresentation(appliedCandidate)
    let dismissedPresentation = makeAnalystStrategyFollowUpCandidateReadablePresentation(dismissedCandidate)

    #expect(appliedPresentation.resultSummary.contains("explicit owner-approved strategy-change path") == true)
    #expect(appliedPresentation.closureSummary.contains("current durable Strategy Brief") == true)
    #expect(appliedPresentation.boundaryNote.contains("user explicitly approved") == true)

    #expect(dismissedPresentation.resultSummary.contains("no Strategy Brief change") == true)
    #expect(dismissedPresentation.closureSummary.contains("without changing durable strategy truth") == true)
    #expect(dismissedPresentation.boundaryNote.contains("leaving the saved Portfolio Strategy Brief") == true)
}

@Test("Analyst strategy follow-up candidate status keeps active and closed states distinguishable")
func analystStrategyFollowUpCandidateStatusKeepsLifecycleBounded() {
    #expect(AnalystStrategyFollowUpCandidateStatus.open.isActive == true)
    #expect(AnalystStrategyFollowUpCandidateStatus.monitoring.isActive == true)
    #expect(AnalystStrategyFollowUpCandidateStatus.appliedToStrategyBrief.isActive == false)
    #expect(AnalystStrategyFollowUpCandidateStatus.convertedToInstruction.isActive == false)
    #expect(AnalystStrategyFollowUpCandidateStatus.convertedToMandate.isActive == false)
    #expect(AnalystStrategyFollowUpCandidateStatus.dismissed.isActive == false)
}

private func makePMTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private final class LockedDateSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Date]
    private var index = 0

    init(_ values: [Date]) {
        self.values = values
    }

    func next() -> Date {
        lock.lock()
        defer { lock.unlock() }
        guard !values.isEmpty else { return Date(timeIntervalSince1970: 0) }
        let value = values[min(index, values.count - 1)]
        index += 1
        return value
    }
}
