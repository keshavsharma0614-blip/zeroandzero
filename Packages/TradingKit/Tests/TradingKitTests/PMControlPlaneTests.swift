import Foundation
import Testing
@testable import TradingKit

@Test("Engine PM interfaces round-trip profiles mandates instructions notebook entries decisions approval requests communications and delegations")
func enginePMInterfacesRoundTrip() async throws {
    let root = makePMControlPlaneTempDirectory(name: "pm-engine-control-plane")
    let profilesDirectory = root.appendingPathComponent("profiles", isDirectory: true)
    let mandatesDirectory = root.appendingPathComponent("mandates", isDirectory: true)
    let instructionsDirectory = root.appendingPathComponent("instructions", isDirectory: true)
    let notebookDirectory = root.appendingPathComponent("notebook", isDirectory: true)
    let pmRuntimeSettingsFile = root.appendingPathComponent("pm-runtime-settings.json", isDirectory: false)
    let portfolioStrategyBriefFile = root.appendingPathComponent("portfolio-strategy-brief.json", isDirectory: false)
    let decisionsDirectory = root.appendingPathComponent("decisions", isDirectory: true)
    let approvalRequestsDirectory = root.appendingPathComponent("approval-requests", isDirectory: true)
    let communicationSessionsDirectory = root.appendingPathComponent("communication-sessions", isDirectory: true)
    let communicationMessagesDirectory = root.appendingPathComponent("communication-messages", isDirectory: true)
    let delegationsDirectory = root.appendingPathComponent("delegations", isDirectory: true)
    let analystStrategyImplicationsDirectory = root.appendingPathComponent("analyst-strategy-implications", isDirectory: true)
    let analystStrategyFollowUpCandidatesDirectory = root.appendingPathComponent("analyst-strategy-follow-up-candidates", isDirectory: true)
    let charterDirectory = root.appendingPathComponent("charters", isDirectory: true)
    let taskDirectory = root.appendingPathComponent("tasks", isDirectory: true)
    let recentNewsRuntimeSettingsFile = root.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false)
    let standingBenchRuntimeSettingsFile = root.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)

    let profileStore = PMProfileStore(profilesDirectory: profilesDirectory)
    let mandateStore = PMMandateStore(mandatesDirectory: mandatesDirectory)
    let instructionStore = PMInstructionStore(instructionsDirectory: instructionsDirectory)
    let notebookStore = PMNotebookStore(notebookDirectory: notebookDirectory)
    let pmRuntimeSettingsStore = PMRuntimeSettingsStore(fileURL: pmRuntimeSettingsFile)
    let portfolioStrategyBriefStore = PortfolioStrategyBriefStore(fileURL: portfolioStrategyBriefFile)
    let decisionStore = PMDecisionStore(decisionsDirectory: decisionsDirectory)
    let approvalRequestStore = PMApprovalRequestStore(approvalRequestsDirectory: approvalRequestsDirectory)
    let communicationSessionStore = PMCommunicationSessionStore(sessionsDirectory: communicationSessionsDirectory)
    let communicationMessageStore = PMCommunicationMessageStore(messagesDirectory: communicationMessagesDirectory)
    let delegationStore = PMDelegationStore(delegationsDirectory: delegationsDirectory)
    let analystStrategyImplicationStore = AnalystStrategyImplicationStore(
        implicationsDirectory: analystStrategyImplicationsDirectory
    )
    let analystStrategyFollowUpCandidateStore = AnalystStrategyFollowUpCandidateStore(
        candidatesDirectory: analystStrategyFollowUpCandidatesDirectory
    )
    let charterStore = AnalystCharterStore(chartersDirectory: charterDirectory)
    let taskStore = AnalystTaskStore(tasksDirectory: taskDirectory)
    let recentNewsRuntimeSettingsStore = RecentNewsAnalystRuntimeSettingsStore(fileURL: recentNewsRuntimeSettingsFile)
    let standingBenchRuntimeSettingsStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: standingBenchRuntimeSettingsFile
    )

    let now = Date(timeIntervalSince1970: 1_701_200_000)
    _ = try await profileStore.upsert(
        PMProfile(
            pmId: "pm-primary",
            displayName: "Primary PM",
            roleSummary: "Owns durable portfolio-management mandate and supervisory memory.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "charter-1",
            analystId: "tech-analyst",
            title: "Tech charter",
            coverageScope: "Technology equities",
            strategyFamily: "long-short",
            summary: "Review technology adoption-related swings.",
            expectedOutputs: ["finding", "signal"],
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await taskStore.upsert(
        AnalystTask(
            taskId: "task-1",
            analystId: "tech-analyst",
            charterId: "charter-1",
            title: "Review technology adoption task",
            description: "Track whether enterprise adoption timing is slipping.",
            status: .queued,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(
        pmProfileStore: profileStore,
        pmMandateStore: mandateStore,
        pmInstructionStore: instructionStore,
        pmNotebookStore: notebookStore,
        pmRuntimeSettingsStore: pmRuntimeSettingsStore,
        portfolioStrategyBriefStore: portfolioStrategyBriefStore,
        analystStrategyImplicationStore: analystStrategyImplicationStore,
        analystStrategyFollowUpCandidateStore: analystStrategyFollowUpCandidateStore,
        pmDecisionStore: decisionStore,
        pmApprovalRequestStore: approvalRequestStore,
        pmCommunicationSessionStore: communicationSessionStore,
        pmCommunicationMessageStore: communicationMessageStore,
        pmDelegationStore: delegationStore,
        analystCharterStore: charterStore,
        analystTaskStore: taskStore,
        recentNewsAnalystRuntimeSettingsStore: recentNewsRuntimeSettingsStore,
        standingBenchAnalystRuntimeSettingsStore: standingBenchRuntimeSettingsStore
    )

    let profiles = try await engine.listPMProfiles()
    #expect(profiles.map(\.pmId) == ["pm-primary"])

    let mandate = try await engine.upsertPMMandate(
        PMMandate(
            mandateId: "mandate-1",
            pmId: "pm-primary",
            title: "Core portfolio mandate",
            objectiveSummary: "Compound capital while preserving human approval for consequential actions.",
            scope: "Cross-asset paper-first supervision.",
            constraints: ["No autonomous live trading"],
            riskBoundaries: ["Respect kill switch"],
            successCriteria: ["Auditability"],
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(mandate.pmId == "pm-primary")

    let instruction = try await engine.upsertPMInstruction(
        PMInstruction(
            instructionId: "instruction-1",
            pmId: "pm-primary",
            title: "Standing operating guidance",
            body: "Delegate research to specialists and preserve action gating.",
            category: "operating_guidance",
            status: .active,
            effectiveAt: now,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(instruction.pmId == "pm-primary")

    let note = try await engine.upsertPMNotebookEntry(
        PMNotebookEntry(
            entryId: "note-1",
            pmId: "pm-primary",
            title: "Interpretation note",
            body: "Promote durable instructions from owner interactions instead of treating chat transcripts as memory.",
            tags: ["memory", "owner"],
            sourceSummary: "owner guidance",
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(note.pmId == "pm-primary")

    let fetchedMandate = try await engine.getPMMandate(id: "mandate-1")
    #expect(fetchedMandate.title == "Core portfolio mandate")

    let instructions = try await engine.listPMInstructions()
    #expect(instructions.map(\.instructionId) == ["instruction-1"])

    let notebookEntries = try await engine.listPMNotebookEntries()
    #expect(notebookEntries.map(\.entryId) == ["note-1"])
    #expect(notebookEntries.first?.tags == ["memory", "owner"])

    let decision = try await engine.upsertPMDecision(
        PMDecisionRecord(
            decisionId: "decision-1",
            pmId: "pm-primary",
            title: "Escalate proposal review",
            summary: "PM recommends escalating the proposal to a bounded human review step.",
            decisionType: .escalation,
            status: .active,
            charterId: "charter-1",
            taskId: "task-1",
            signalId: "signal-1",
            proposalId: "proposal-1",
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(decision.pmId == "pm-primary")
    #expect(decision.proposalId == "proposal-1")

    let approvalRequest = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-1",
            pmId: "pm-primary",
            subject: "Approve bounded paper proposal review",
            rationale: "Need an app-owned PM-layer request that does not bypass proposal approval semantics.",
            requestType: .proposalReview,
            status: .pending,
            decisionId: "decision-1",
            delegationId: "delegation-1",
            signalId: "signal-1",
            proposalId: "proposal-1",
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(approvalRequest.pmId == "pm-primary")
    #expect(approvalRequest.decisionId == "decision-1")

    let resolvedApprovalRequest = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-1",
            pmId: "pm-primary",
            subject: "Approve bounded paper proposal review",
            rationale: "Owner reviewed the PM-layer request without changing proposal approval semantics.",
            requestType: .proposalReview,
            status: .pending,
            decisionId: "decision-1",
            delegationId: "delegation-1",
            signalId: "signal-1",
            proposalId: "proposal-1",
            ownerResponse: .approved,
            ownerRespondedAt: now.addingTimeInterval(60),
            createdAt: now,
            updatedAt: now.addingTimeInterval(60)
        )
    )
    #expect(resolvedApprovalRequest.status == .resolved)
    #expect(resolvedApprovalRequest.ownerResponse == .approved)

    let communicationSession = try await engine.upsertPMCommunicationSession(
        PMCommunicationSession(
            sessionId: "session-1",
            channel: .mockTelegram,
            externalConversationId: "chat-1",
            pmId: "pm-primary",
            participantId: "owner-1",
            participantDisplayName: "Owner",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(communicationSession.pmId == "pm-primary")
    #expect(communicationSession.externalConversationId == "chat-1")

    let communicationMessage = try await engine.upsertPMCommunicationMessage(
        PMCommunicationMessage(
            messageId: "message-1",
            sessionId: "session-1",
            direction: .incoming,
            senderRole: .owner,
            senderId: "owner-1",
            body: "Please hold the proposal until we have more evidence.",
            sentAt: now,
            promotion: PMCommunicationPromotion(
                targetType: .decision,
                targetId: "decision-1",
                promotedAt: now
            ),
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(communicationMessage.sessionId == "session-1")
    #expect(communicationMessage.promotion?.targetType == .decision)

    let delegation = try await engine.upsertPMDelegation(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-primary",
            analystId: "placeholder-analyst",
            charterId: "charter-1",
            taskId: "task-1",
            title: "Review technology adoption task",
            rationale: "PM needs an attributable analyst delegation with runtime policy.",
            requestedOutputs: [.finding, .signal],
            status: .issued,
            runtimePolicyOverride: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                policySource: .pmDelegationOverride,
                createdAt: now,
                updatedAt: now
            ),
            linkedFindingIDs: [],
            linkedSignalIDs: [],
            linkedProposalIDs: [],
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(delegation.pmId == "pm-primary")
    #expect(delegation.charterId == "charter-1")
    #expect(delegation.analystId == "tech-analyst")
    #expect(delegation.runtimePolicyOverride?.policySource == .pmDelegationOverride)

    let implication = try await engine.upsertAnalystStrategyImplication(
        AnalystStrategyImplicationRecord(
            implicationId: "implication-1",
            pmId: "pm-primary",
            implicationKind: .candidateStrategyBriefRevision,
            implicationSummary: "This analyst memo implies the current strategy brief should tighten near-term earnings posture.",
            whyItMatters: "Recent analyst evidence suggests the existing strategy brief understates event-risk posture into the next earnings cluster.",
            candidateStrategyBriefRevisionNote: "Add a brief note that earnings-sensitive names require tighter PM review before owner escalation.",
            memoId: "memo-1",
            findingId: "finding-1",
            evidenceBundleId: "bundle-1",
            delegationId: "delegation-1",
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    #expect(implication.pmId == "pm-primary")
    #expect(implication.implicationKind == .candidateStrategyBriefRevision)
    #expect(implication.memoId == "memo-1")

    let followUpCandidate = try await engine.upsertAnalystStrategyFollowUpCandidate(
        AnalystStrategyFollowUpCandidateRecord(
            candidateId: "candidate-1",
            implicationId: implication.implicationId,
            pmId: "pm-primary",
            followUpKind: .strategyBriefRevision,
            status: .open,
            candidateSummary: "Queue a candidate Strategy Brief tightening around earnings-event review.",
            candidateDetail: "Keep this separate from the actual brief until the PM explicitly applies a real brief update.",
            memoId: nil,
            findingId: nil,
            evidenceBundleId: nil,
            delegationId: nil,
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    #expect(followUpCandidate.implicationId == implication.implicationId)
    #expect(followUpCandidate.followUpKind == .strategyBriefRevision)
    #expect(followUpCandidate.memoId == "memo-1")

    let fetchedFollowUpCandidate = try await engine.getAnalystStrategyFollowUpCandidate(id: "candidate-1")
    #expect(fetchedFollowUpCandidate.candidateSummary.contains("Strategy Brief tightening") == true)

    let listedFollowUpCandidates = try await engine.listAnalystStrategyFollowUpCandidates()
    #expect(listedFollowUpCandidates.map(\.candidateId) == ["candidate-1"])
    #expect(listedFollowUpCandidates.first?.status == .open)

    let defaultBrief = try await engine.getPortfolioStrategyBrief()
    #expect(defaultBrief.briefId == PortfolioStrategyBrief.singletonID)

    let briefAfterImplication = try await engine.getPortfolioStrategyBrief()
    #expect(briefAfterImplication.briefId == PortfolioStrategyBrief.singletonID)
    #expect(briefAfterImplication.primaryDocumentBody == defaultBrief.primaryDocumentBody)
    #expect(briefAfterImplication.objectiveSummary == defaultBrief.objectiveSummary)

    let appliedCandidate = try await engine.applyAnalystStrategyFollowUpCandidateToStrategyBrief(
        candidateId: "candidate-1",
        updatedBy: "Primary PM",
        source: .system
    )
    #expect(appliedCandidate.status == .appliedToStrategyBrief)
    #expect(appliedCandidate.appliedStrategyBriefId == PortfolioStrategyBrief.singletonID)

    let briefAfterApply = try await engine.getPortfolioStrategyBrief()
    #expect(briefAfterApply.updateSource == .strategyFollowUpCandidateApplied)
    #expect(briefAfterApply.sourceAnalystStrategyFollowUpCandidateId == "candidate-1")
    #expect(briefAfterApply.sourceAnalystStrategyImplicationId == "implication-1")
    #expect(briefAfterApply.primaryDocumentBody.contains("Applied Strategy Follow-Up") == true)
    #expect(briefAfterApply.primaryDocumentBody.contains("Queue a candidate Strategy Brief tightening around earnings-event review.") == true)

    let instructionCandidate = try await engine.upsertAnalystStrategyFollowUpCandidate(
        AnalystStrategyFollowUpCandidateRecord(
            candidateId: "candidate-2",
            implicationId: implication.implicationId,
            pmId: "pm-primary",
            followUpKind: .pmInstructionFollowUp,
            status: .open,
            candidateSummary: "Create a PM instruction to tighten earnings-event review posture.",
            candidateDetail: "Keep earnings-sensitive names under tighter PM review before owner-facing escalation.",
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    let convertedInstructionCandidate = try await engine.convertAnalystStrategyFollowUpCandidateToInstruction(
        candidateId: instructionCandidate.candidateId,
        source: .system
    )
    #expect(convertedInstructionCandidate.status == .convertedToInstruction)
    #expect(convertedInstructionCandidate.convertedInstructionId != nil)
    let convertedInstruction = try await engine.getPMInstruction(id: try #require(convertedInstructionCandidate.convertedInstructionId))
    #expect(convertedInstruction.sourceAnalystStrategyFollowUpCandidateId == instructionCandidate.candidateId)
    #expect(convertedInstruction.sourceAnalystStrategyImplicationId == implication.implicationId)
    #expect(convertedInstruction.sourceAnalystFindingId == "finding-1")

    let mandateCandidate = try await engine.upsertAnalystStrategyFollowUpCandidate(
        AnalystStrategyFollowUpCandidateRecord(
            candidateId: "candidate-3",
            implicationId: implication.implicationId,
            pmId: "pm-primary",
            followUpKind: .pmMandateFollowUp,
            status: .open,
            candidateSummary: "Create a PM mandate follow-up for earnings-event risk review.",
            candidateDetail: "Maintain a bounded mandate around event-aware PM supervision for earnings-sensitive names.",
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    let convertedMandateCandidate = try await engine.convertAnalystStrategyFollowUpCandidateToMandate(
        candidateId: mandateCandidate.candidateId,
        source: .system
    )
    #expect(convertedMandateCandidate.status == .convertedToMandate)
    #expect(convertedMandateCandidate.convertedMandateId != nil)
    let convertedMandate = try await engine.getPMMandate(id: try #require(convertedMandateCandidate.convertedMandateId))
    #expect(convertedMandate.sourceAnalystStrategyFollowUpCandidateId == mandateCandidate.candidateId)
    #expect(convertedMandate.sourceAnalystStrategyImplicationId == implication.implicationId)
    #expect(convertedMandate.sourceAnalystEvidenceBundleId == "bundle-1")

    let refreshedContextPack = try await engine.assemblePMContextPack(pmId: "pm-primary")
    #expect(refreshedContextPack.sharedPortfolioTruth.strategyBrief?.updateSource == .strategyFollowUpCandidateApplied)
    #expect(refreshedContextPack.activeInstructions.map(\.instructionId).contains(convertedInstruction.instructionId) == true)
    #expect(refreshedContextPack.mandates.map(\.mandateId).contains(convertedMandate.mandateId) == true)
    #expect(
        refreshedContextPack.activeInstructions.contains(where: {
            $0.sourceAnalystStrategyFollowUpCandidateId == instructionCandidate.candidateId
        })
    )
    #expect(
        refreshedContextPack.mandates.contains(where: {
            $0.sourceAnalystStrategyFollowUpCandidateId == mandateCandidate.candidateId
        })
    )

    let dismissedCandidate = try await engine.upsertAnalystStrategyFollowUpCandidate(
        AnalystStrategyFollowUpCandidateRecord(
            candidateId: "candidate-4",
            implicationId: implication.implicationId,
            pmId: "pm-primary",
            followUpKind: .monitorOnly,
            status: .dismissed,
            candidateSummary: "No further PM follow-up is needed right now.",
            candidateDetail: "Keep this closed without applying or converting it.",
            closedAt: now,
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    #expect(dismissedCandidate.status == .dismissed)
    #expect(dismissedCandidate.closedAt != nil)

    let defaultPMRuntime = try await engine.getPMRuntimeSettings()
    #expect(defaultPMRuntime.settingsId == PMRuntimeSettings.singletonID)
    #expect(defaultPMRuntime.runtimeIdentifier == "gpt-5")
    #expect(defaultPMRuntime.reasoningMode == .deliberate)

    let updatedPMRuntime = try await engine.upsertPMRuntimeSettings(
        PMRuntimeSettings(
            runtimeIdentifier: "gpt-owner-next",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(updatedPMRuntime.runtimeIdentifier == "gpt-owner-next")
    #expect(updatedPMRuntime.reasoningMode == .standard)
    #expect(updatedPMRuntime.updateSource == .userEdited)

    let updatedBrief = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            objectiveSummary: "Preserve capital through bounded event-aware supervision.",
            keyThemes: ["technology infrastructure", "Earnings sensitivity"],
            currentRiskPosture: "Moderate risk posture with tighter review around earnings and SEC event clusters.",
            materialDevelopments: ["guidance changes", "major restructuring"],
            nonMaterialDevelopments: ["routine office openings"],
            reviewEscalationPosture: "Escalate potentially material cases to PM review before any owner-facing request.",
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(updatedBrief.updatedBy == "pm-primary")
    #expect(updatedBrief.materialDevelopments.contains("guidance changes"))

    let fetchedBrief = try await engine.getPortfolioStrategyBrief()
    #expect(fetchedBrief.objectiveSummary.contains("event-aware supervision"))
    #expect(fetchedBrief.updateSource == .pmControlPlane)

    let freeformBody = """
    STRATEGY_BRIEF_LIVE_TRACE_2026_03_29_ALPHA_9174

    This is a live root-cause trace brief.
    It is intentionally non-template and should not be re-rendered into the old Objective / Key Themes placeholder structure.
    End marker: STRATEGY_BRIEF_LIVE_TRACE_2026_03_29_ALPHA_9174
    """
    let freeformBrief = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: freeformBody,
            objectiveSummary: "",
            keyThemes: [],
            currentRiskPosture: "",
            materialDevelopments: [],
            nonMaterialDevelopments: [],
            reviewEscalationPosture: "",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(freeformBrief.primaryDocumentBody == freeformBody)

    let summaryOnlyControlPlaneUpdate = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            objectiveSummary: "The example portfolio question is how technology adoption may affect market dynamics over the next 24 months.",
            keyThemes: ["technology infrastructure buildout", "Semiconductor demand", "Enterprise software beneficiaries"],
            currentRiskPosture: "Moderate risk posture with active long/short re-underwriting around earnings and financing sensitivity.",
            materialDevelopments: ["inference demand acceleration", "hyperscaler capex revisions"],
            nonMaterialDevelopments: ["routine product refreshes"],
            reviewEscalationPosture: "Escalate materially strategy-relevant developments to PM review.",
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(summaryOnlyControlPlaneUpdate.primaryDocumentBody == freeformBody)
    #expect(summaryOnlyControlPlaneUpdate.objectiveSummary == "STRATEGY_BRIEF_LIVE_TRACE_2026_03_29_ALPHA_9174")
    #expect(summaryOnlyControlPlaneUpdate.updateSource == .pmControlPlane)

    let fetchedPMRuntime = try await engine.getPMRuntimeSettings()
    #expect(fetchedPMRuntime.runtimeIdentifier == "gpt-owner-next")
    #expect(fetchedPMRuntime.reasoningMode == .standard)

    let defaultRecentNewsRuntime = try await engine.getRecentNewsAnalystRuntimeSettings()
    #expect(defaultRecentNewsRuntime.settingsId == RecentNewsAnalystRuntimeSettings.singletonID)
    #expect(defaultRecentNewsRuntime.runtimeIdentifier == "gpt-4.1-mini")
    #expect(defaultRecentNewsRuntime.runtimeIdentifier != fetchedPMRuntime.runtimeIdentifier)

    let updatedRecentNewsRuntime = try await engine.upsertRecentNewsAnalystRuntimeSettings(
        RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-4.1-nano",
            reasoningMode: .standard,
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(updatedRecentNewsRuntime.runtimeIdentifier == "gpt-4.1-nano")
    #expect(updatedRecentNewsRuntime.reasoningMode == .standard)

    let fetchedRecentNewsRuntime = try await engine.getRecentNewsAnalystRuntimeSettings()
    #expect(fetchedRecentNewsRuntime.runtimeIdentifier == "gpt-4.1-nano")
    #expect(fetchedRecentNewsRuntime.updateSource == .pmControlPlane)

    let defaultStandingBenchRuntime = try await engine.getStandingBenchAnalystRuntimeSettings()
    #expect(defaultStandingBenchRuntime.settingsId == StandingBenchAnalystRuntimeSettings.singletonID)
    #expect(defaultStandingBenchRuntime.runtimeIdentifier == "gpt-4.1")
    #expect(defaultStandingBenchRuntime.reasoningMode == .standard)
    #expect(defaultStandingBenchRuntime.runtimeIdentifier != defaultRecentNewsRuntime.runtimeIdentifier)

    let updatedStandingBenchRuntime = try await engine.upsertStandingBenchAnalystRuntimeSettings(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(updatedStandingBenchRuntime.runtimeIdentifier == "gpt-5.4")
    #expect(updatedStandingBenchRuntime.reasoningMode == .deliberate)

    let fetchedStandingBenchRuntime = try await engine.getStandingBenchAnalystRuntimeSettings()
    #expect(fetchedStandingBenchRuntime.runtimeIdentifier == "gpt-5.4")
    #expect(fetchedStandingBenchRuntime.updateSource == .pmControlPlane)

    let fetchedDelegation = try await engine.getPMDelegation(id: "delegation-1")
    #expect(fetchedDelegation.taskId == "task-1")

    let fetchedDecision = try await engine.getPMDecision(id: "decision-1")
    #expect(fetchedDecision.signalId == "signal-1")

    let decisions = try await engine.listPMDecisions()
    #expect(decisions.map(\.decisionId) == ["decision-1"])

    let fetchedApprovalRequest = try await engine.getPMApprovalRequest(id: "approval-1")
    #expect(fetchedApprovalRequest.proposalId == "proposal-1")
    #expect(fetchedApprovalRequest.ownerResponse == .approved)
    #expect(fetchedApprovalRequest.status == .resolved)

    let approvalRequests = try await engine.listPMApprovalRequests()
    #expect(approvalRequests.map(\.approvalRequestId) == ["approval-1"])

    let fetchedCommunicationSession = try await engine.getPMCommunicationSession(id: "session-1")
    #expect(fetchedCommunicationSession.participantDisplayName == "Owner")

    let communicationSessions = try await engine.listPMCommunicationSessions()
    #expect(communicationSessions.map(\.sessionId) == ["session-1"])

    let fetchedCommunicationMessage = try await engine.getPMCommunicationMessage(id: "message-1")
    #expect(fetchedCommunicationMessage.promotion?.targetId == "decision-1")

    let communicationMessages = try await engine.listPMCommunicationMessages()
    #expect(communicationMessages.map(\.messageId) == ["message-1"])

    let delegations = try await engine.listPMDelegations()
    #expect(delegations.map(\.delegationId) == ["delegation-1"])
    #expect(delegations.first?.requestedOutputs == [.finding, .signal])

    let fetchedImplication = try await engine.getAnalystStrategyImplication(id: "implication-1")
    #expect(fetchedImplication.candidateStrategyBriefRevisionNote?.contains("earnings-sensitive names") == true)
    #expect(fetchedImplication.delegationId == "delegation-1")

    let implications = try await engine.listAnalystStrategyImplications()
    #expect(implications.map(\.implicationId) == ["implication-1"])
}

@Test("Engine PM runtime validation and last-known-good fallback remain bounded and explicit")
func enginePMRuntimeValidationAndFallback() async throws {
    let root = makePMControlPlaneTempDirectory(name: "pm-runtime-validation")
    let pmRuntimeSettingsFile = root.appendingPathComponent("pm-runtime-settings.json", isDirectory: false)
    let pmRuntimeSettingsStore = PMRuntimeSettingsStore(fileURL: pmRuntimeSettingsFile)
    let readyProvider = StubPMRuntimeOpenAIKeyProvider(
        resolution: OpenAICredentialResolution(
            status: .ready,
            apiKey: "test-openai-key",
            source: .inferred,
            account: OpenAIKeychainCredentialResolver.account,
            summary: "Test provider resolved a key."
        )
    )
    let engine = Engine(
        pmRuntimeSettingsStore: pmRuntimeSettingsStore,
        openAIKeyStatusProvider: readyProvider
    )

    let now = Date(timeIntervalSince1970: 1_720_900_000)
    let valid = await engine.validatePMRuntimeCandidate(
        runtimeIdentifier: "gpt-5-mini",
        reasoningMode: .standard,
        checkedBy: "human owner"
    )
    #expect(valid.status == .valid)

    let savedValid = try await engine.upsertPMRuntimeSettings(
        PMRuntimeSettings(
            runtimeIdentifier: "gpt-5-mini",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(savedValid.lastKnownGoodRuntime?.runtimeIdentifier == "gpt-5-mini")
    #expect(savedValid.validationStatus?.status == .valid)

    let savedInvalid = try await engine.upsertPMRuntimeSettings(
        PMRuntimeSettings(
            runtimeIdentifier: "bad runtime!",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: savedValid.createdAt,
            updatedAt: now.addingTimeInterval(10)
        )
    )
    #expect(savedInvalid.validationStatus?.status == .invalid)
    #expect(savedInvalid.lastKnownGoodRuntime?.runtimeIdentifier == "gpt-5-mini")

    let resolution = try await engine.resolvePMRuntimeSelectionForExecution()
    #expect(resolution.fallbackApplied == true)
    #expect(resolution.effectiveRuntimeIdentifier == "gpt-5-mini")
    #expect(resolution.validation.status == .invalid)

    let fetched = try await engine.getPMRuntimeSettings()
    #expect(fetched.lastFallback?.fallbackRuntimeIdentifier == "gpt-5-mini")
    #expect(fetched.lastFallback?.configuredRuntimeIdentifier == "bad runtime!")
}

private struct StubPMRuntimeOpenAIKeyProvider: OpenAIKeyStatusProviding {
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

@Test("PM runtime resolution ignores stale seeded standing charter defaults")
func enginePMRuntimeResolutionIgnoresSeededStandingCharterDefaults() async throws {
    let root = makePMControlPlaneTempDirectory(name: "pm-runtime-ignores-seeded-charters")
    let pmRuntimeSettingsStore = PMRuntimeSettingsStore(
        fileURL: root.appendingPathComponent("pm-runtime-settings.json", isDirectory: false)
    )
    let charterStore = AnalystCharterStore(
        chartersDirectory: root.appendingPathComponent("charters", isDirectory: true)
    )
    let engine = Engine(
        pmRuntimeSettingsStore: pmRuntimeSettingsStore,
        analystCharterStore: charterStore
    )
    let now = Date(timeIntervalSince1970: 1_720_900_500)

    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "bench-sector-technology",
            analystId: "bench-sector-technology-analyst",
            title: "Technology Analyst",
            coverageScope: "Technology equities",
            strategyFamily: "standing sector bench",
            summary: "Legacy seeded runtime default should not influence PM runtime selection.",
            benchRole: .sector,
            defaultRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-4.1",
                reasoningMode: .standard,
                policySource: .charterDefault,
                createdAt: now,
                updatedAt: now
            ),
            updatedBy: "legacy",
            updateSource: .systemSeed,
            createdAt: now,
            updatedAt: now
        )
    )

    _ = try await engine.upsertPMRuntimeSettings(
        PMRuntimeSettings(
            runtimeIdentifier: "gpt-5.4-mini",
            reasoningMode: .deliberate,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let resolution = try await engine.resolvePMRuntimeSelectionForExecution()
    #expect(resolution.effectiveRuntimeIdentifier == "gpt-5.4-mini")
    #expect(resolution.effectiveReasoningMode == .deliberate)
    #expect(resolution.fallbackApplied == false)
}

@Test("PM strategy-change routing requires explicit owner approval and carries compact portfolio context")
func pmStrategyChangeRoutingRequiresExplicitOwnerApprovalAndCarriesPortfolioContext() async throws {
    let engine = makePMStrategyRoutingEngine(name: "pm-strategy-change-routing-approval")
    let now = Date(timeIntervalSince1970: 1_743_800_000)

    _ = try await engine.upsertPMProfile(
        PMProfile(
            pmId: "pm-primary",
            displayName: "Primary PM",
            roleSummary: "Owns bounded strategy review and owner routing.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertAnalystCharter(
        AnalystCharter(
            charterId: "charter-1",
            analystId: "risk-analyst",
            title: "Portfolio Risk Analyst",
            coverageScope: "Portfolio risk posture",
            strategyFamily: "long-short",
            summary: "Pressure test current portfolio risk posture.",
            expectedOutputs: ["finding", "memo"],
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    _ = try await engine.upsertAnalystTask(
        AnalystTask(
            taskId: "task-1",
            analystId: "risk-analyst",
            charterId: "charter-1",
            title: "Review event-risk posture",
            description: "Assess whether the current strategy brief understates event-risk posture.",
            status: .completed,
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    _ = try await engine.upsertPMDelegation(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-primary",
            analystId: "risk-analyst",
            charterId: "charter-1",
            taskId: "task-1",
            title: "Review event-risk posture",
            rationale: "Need a bounded owner-reviewable strategic read before any strategy-brief change.",
            requestedOutputs: [.finding],
            status: .completed,
            createdAt: now,
            updatedAt: now
        )
    )
    let implication = try await engine.upsertAnalystStrategyImplication(
        AnalystStrategyImplicationRecord(
            implicationId: "implication-1",
            pmId: "pm-primary",
            implicationKind: .candidateStrategyBriefRevision,
            implicationSummary: "The analyst memo implies the saved strategy brief should tighten event-risk review.",
            whyItMatters: "Current concentration and earnings timing argue for a bounded strategic tightening before the next owner-facing escalation.",
            candidateStrategyBriefRevisionNote: "Tighten event-risk review language around earnings-sensitive concentration.",
            memoId: "memo-1",
            findingId: "finding-1",
            evidenceBundleId: "bundle-1",
            delegationId: "delegation-1",
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    let candidate = try await engine.upsertAnalystStrategyFollowUpCandidate(
        AnalystStrategyFollowUpCandidateRecord(
            candidateId: "candidate-1",
            implicationId: implication.implicationId,
            pmId: "pm-primary",
            followUpKind: .strategyBriefRevision,
            status: .open,
            candidateSummary: "Tighten event-risk review before the next earnings cluster.",
            candidateDetail: "Keep the saved brief unchanged until the owner explicitly approves this bounded strategy change.",
            memoId: "memo-1",
            findingId: "finding-1",
            evidenceBundleId: "bundle-1",
            delegationId: "delegation-1",
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try decodePMControlPlanePosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "30000"),
        try decodePMControlPlanePosition(symbol: "MSFT", qty: "50", side: "long", marketValue: "15000"),
        try decodePMControlPlanePosition(symbol: "IWM", qty: "-80", side: "short", marketValue: "-10000")
    ])

    let initialBrief = try await engine.getPortfolioStrategyBrief()
    let routedRequest = try await engine.routeAnalystStrategyFollowUpCandidateToOwnerApproval(
        candidateId: candidate.candidateId,
        source: .system
    )
    let portfolioContext = try #require(routedRequest.strategyChangePortfolioContext)

    #expect(routedRequest.requestType == .strategyChange)
    #expect(routedRequest.status == .pending)
    #expect(routedRequest.subject.contains("PM-proposed strategy change") == true)
    #expect(routedRequest.sourceAnalystStrategyFollowUpCandidateId == candidate.candidateId)
    #expect(routedRequest.sourceAnalystStrategyImplicationId == implication.implicationId)
    #expect(routedRequest.sourceAnalystMemoId == "memo-1")
    #expect(routedRequest.sourceAnalystEvidenceBundleId == "bundle-1")
    #expect(routedRequest.findingId == "finding-1")
    #expect(routedRequest.delegationId == "delegation-1")
    #expect(portfolioContext.positionCount == 3)
    #expect(portfolioContext.grossExposure == 55_000)
    #expect(portfolioContext.longExposure == 45_000)
    #expect(portfolioContext.shortExposure == 10_000)
    #expect(portfolioContext.netExposure == 35_000)
    #expect(abs(portfolioContext.longWeight - 0.8181818182) < 0.0001)
    #expect(abs(portfolioContext.shortWeight - 0.1818181818) < 0.0001)
    #expect(abs(portfolioContext.netWeight - 0.6363636364) < 0.0001)
    #expect(portfolioContext.largestPositionSymbol == "NVDA")
    #expect(abs((portfolioContext.largestPositionWeight ?? 0) - 0.5454545455) < 0.0001)

    let dedupedRequest = try await engine.routeAnalystStrategyFollowUpCandidateToOwnerApproval(
        candidateId: candidate.candidateId,
        source: .system
    )
    #expect(dedupedRequest.approvalRequestId == routedRequest.approvalRequestId)

    let briefBeforeApproval = try await engine.getPortfolioStrategyBrief()
    #expect(briefBeforeApproval.primaryDocumentBody == initialBrief.primaryDocumentBody)
    #expect(briefBeforeApproval.updateSource == initialBrief.updateSource)

    let approvedRequest = try await engine.respondToPMApprovalRequest(
        requestId: routedRequest.approvalRequestId,
        response: .approved,
        source: .system
    )
    let appliedCandidate = try await engine.getAnalystStrategyFollowUpCandidate(id: candidate.candidateId)
    let updatedBrief = try await engine.getPortfolioStrategyBrief()
    let contextPack = try await engine.assemblePMContextPack(pmId: "pm-primary")

    #expect(approvedRequest.status == .resolved)
    #expect(approvedRequest.ownerResponse == .approved)
    #expect(approvedRequest.resultingStrategyBriefId == PortfolioStrategyBrief.singletonID)
    #expect(appliedCandidate.status == .appliedToStrategyBrief)
    #expect(appliedCandidate.appliedStrategyBriefId == PortfolioStrategyBrief.singletonID)
    #expect(updatedBrief.sourceAnalystStrategyFollowUpCandidateId == candidate.candidateId)
    #expect(updatedBrief.sourceAnalystStrategyImplicationId == implication.implicationId)
    #expect(updatedBrief.updateSource == .strategyFollowUpCandidateApplied)
    #expect(updatedBrief.revisionSummary?.contains("owner-approved strategy change") == true)
    #expect(updatedBrief.primaryDocumentBody.contains(candidate.candidateSummary) == true)
    #expect(contextPack.sharedPortfolioTruth.strategyBrief?.revisionSummary?.contains("owner-approved strategy change") == true)
}

@Test("Strategy-change review responses leave the brief unchanged until approval and record decline cleanly")
func strategyChangeReviewResponsesLeaveBriefUnchangedUntilApprovalAndRecordDecline() async throws {
    let engine = makePMStrategyRoutingEngine(name: "pm-strategy-change-routing-decline")
    let now = Date(timeIntervalSince1970: 1_743_800_050)

    _ = try await engine.upsertPMProfile(
        PMProfile(
            pmId: "pm-primary",
            displayName: "Primary PM",
            roleSummary: "Owns bounded strategy review and owner routing.",
            createdAt: now,
            updatedAt: now
        )
    )
    let implication = try await engine.upsertAnalystStrategyImplication(
        AnalystStrategyImplicationRecord(
            implicationId: "implication-1",
            pmId: "pm-primary",
            implicationKind: .candidateStrategyBriefRevision,
            implicationSummary: "The analyst memo implies the saved strategy brief should tighten event-risk review.",
            whyItMatters: "Current concentration and event timing justify an explicit owner review before any saved strategy change.",
            candidateStrategyBriefRevisionNote: "Tighten event-risk review language around earnings-sensitive concentration.",
            memoId: "memo-1",
            findingId: "finding-1",
            evidenceBundleId: "bundle-1",
            delegationId: "delegation-1",
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )
    let candidate = try await engine.upsertAnalystStrategyFollowUpCandidate(
        AnalystStrategyFollowUpCandidateRecord(
            candidateId: "candidate-1",
            implicationId: implication.implicationId,
            pmId: "pm-primary",
            followUpKind: .strategyBriefRevision,
            status: .open,
            candidateSummary: "Tighten event-risk review before the next earnings cluster.",
            candidateDetail: "Keep the saved brief unchanged until the owner explicitly approves this bounded strategy change.",
            memoId: "memo-1",
            findingId: "finding-1",
            evidenceBundleId: "bundle-1",
            delegationId: "delegation-1",
            createdAt: now,
            updatedAt: now
        ),
        source: .system
    )

    let initialBrief = try await engine.getPortfolioStrategyBrief()
    let reviewedRequest = try await engine.routeAnalystStrategyFollowUpCandidateToOwnerApproval(
        candidateId: candidate.candidateId,
        source: .system
    )
    let reviewedResponse = try await engine.respondToPMApprovalRequest(
        requestId: reviewedRequest.approvalRequestId,
        response: .reviewed,
        source: .system
    )

    #expect(reviewedResponse.status == .resolved)
    #expect(reviewedResponse.ownerResponse == .reviewed)
    #expect(reviewedResponse.resultingStrategyBriefId == nil)
    #expect((try await engine.getAnalystStrategyFollowUpCandidate(id: candidate.candidateId)).status == .open)
    #expect((try await engine.getPortfolioStrategyBrief()).primaryDocumentBody == initialBrief.primaryDocumentBody)

    let declinedRequest = try await engine.routeAnalystStrategyFollowUpCandidateToOwnerApproval(
        candidateId: candidate.candidateId,
        source: .system
    )
    #expect(declinedRequest.approvalRequestId != reviewedRequest.approvalRequestId)

    let declinedResponse = try await engine.respondToPMApprovalRequest(
        requestId: declinedRequest.approvalRequestId,
        response: .rejected,
        source: .system
    )
    let dismissedCandidate = try await engine.getAnalystStrategyFollowUpCandidate(id: candidate.candidateId)
    let unchangedBrief = try await engine.getPortfolioStrategyBrief()

    #expect(declinedResponse.status == .resolved)
    #expect(declinedResponse.ownerResponse == .rejected)
    #expect(declinedResponse.resultingStrategyBriefId == nil)
    #expect(dismissedCandidate.status == .dismissed)
    #expect(dismissedCandidate.closedAt != nil)
    #expect(unchangedBrief.primaryDocumentBody == initialBrief.primaryDocumentBody)
    #expect(unchangedBrief.sourceAnalystStrategyFollowUpCandidateId == initialBrief.sourceAnalystStrategyFollowUpCandidateId)
}

private func makePMControlPlaneTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePMStrategyRoutingEngine(name: String) -> Engine {
    let root = makePMControlPlaneTempDirectory(name: name)
    let profilesDirectory = root.appendingPathComponent("profiles", isDirectory: true)
    let mandatesDirectory = root.appendingPathComponent("mandates", isDirectory: true)
    let instructionsDirectory = root.appendingPathComponent("instructions", isDirectory: true)
    let notebookDirectory = root.appendingPathComponent("notebook", isDirectory: true)
    let pmRuntimeSettingsFile = root.appendingPathComponent("pm-runtime-settings.json", isDirectory: false)
    let portfolioStrategyBriefFile = root.appendingPathComponent("portfolio-strategy-brief.json", isDirectory: false)
    let decisionsDirectory = root.appendingPathComponent("decisions", isDirectory: true)
    let approvalRequestsDirectory = root.appendingPathComponent("approval-requests", isDirectory: true)
    let communicationSessionsDirectory = root.appendingPathComponent("communication-sessions", isDirectory: true)
    let communicationMessagesDirectory = root.appendingPathComponent("communication-messages", isDirectory: true)
    let delegationsDirectory = root.appendingPathComponent("delegations", isDirectory: true)
    let analystStrategyImplicationsDirectory = root.appendingPathComponent("analyst-strategy-implications", isDirectory: true)
    let analystStrategyFollowUpCandidatesDirectory = root.appendingPathComponent("analyst-strategy-follow-up-candidates", isDirectory: true)
    let charterDirectory = root.appendingPathComponent("charters", isDirectory: true)
    let taskDirectory = root.appendingPathComponent("tasks", isDirectory: true)
    let recentNewsRuntimeSettingsFile = root.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false)

    return Engine(
        pmProfileStore: PMProfileStore(profilesDirectory: profilesDirectory),
        pmMandateStore: PMMandateStore(mandatesDirectory: mandatesDirectory),
        pmInstructionStore: PMInstructionStore(instructionsDirectory: instructionsDirectory),
        pmNotebookStore: PMNotebookStore(notebookDirectory: notebookDirectory),
        pmRuntimeSettingsStore: PMRuntimeSettingsStore(fileURL: pmRuntimeSettingsFile),
        portfolioStrategyBriefStore: PortfolioStrategyBriefStore(fileURL: portfolioStrategyBriefFile),
        analystStrategyImplicationStore: AnalystStrategyImplicationStore(
            implicationsDirectory: analystStrategyImplicationsDirectory
        ),
        analystStrategyFollowUpCandidateStore: AnalystStrategyFollowUpCandidateStore(
            candidatesDirectory: analystStrategyFollowUpCandidatesDirectory
        ),
        pmDecisionStore: PMDecisionStore(decisionsDirectory: decisionsDirectory),
        pmApprovalRequestStore: PMApprovalRequestStore(approvalRequestsDirectory: approvalRequestsDirectory),
        pmCommunicationSessionStore: PMCommunicationSessionStore(sessionsDirectory: communicationSessionsDirectory),
        pmCommunicationMessageStore: PMCommunicationMessageStore(messagesDirectory: communicationMessagesDirectory),
        pmDelegationStore: PMDelegationStore(delegationsDirectory: delegationsDirectory),
        analystCharterStore: AnalystCharterStore(chartersDirectory: charterDirectory),
        analystTaskStore: AnalystTaskStore(tasksDirectory: taskDirectory),
        recentNewsAnalystRuntimeSettingsStore: RecentNewsAnalystRuntimeSettingsStore(fileURL: recentNewsRuntimeSettingsFile)
    )
}

private func decodePMControlPlanePosition(
    symbol: String,
    qty: String,
    side: String,
    marketValue: String
) throws -> Position {
    let payload = """
    {
      "symbol": "\(symbol)",
      "qty": "\(qty)",
      "side": "\(side)",
      "market_value": "\(marketValue)"
    }
    """
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(Position.self, from: Data(payload.utf8))
}
