import Foundation
import Testing
@testable import TradingKit

@Test("PM tasking presentation keeps task brief and follow-up readable")
func pmTaskingPresentationKeepsTaskBriefReadable() {
    let brief = PMTaskingBrief(
        taskObjective: "Challenge the current conclusion.",
        whyNow: "The PM needs a recommendation-ready read before the next owner review.",
        reviewLens: "Disconfirming evidence first.",
        expectedAnswerShape: .recommendationReadySynthesis,
        challengeInstruction: "Look for the strongest contradiction to the current thesis.",
        evidenceExpectation: "Use at least two independent evidence families.",
        disconfirmingEvidenceExpectation: "Show what would make the PM back away from the current thesis.",
        expectedOutputs: ["memo", "finding"],
        revisionReason: "First pass leaned too heavily on confirming evidence."
    )
    let action = PMAnalystFollowUpAction(
        actionId: "follow-up-1",
        actionType: .rerunWithRuntime,
        summary: "Use a stronger runtime and revisit the prior conclusion.",
        requestedCharterId: "bench-sector-technology",
        requestedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: Date(timeIntervalSince1970: 1_720_300_000),
            updatedAt: Date(timeIntervalSince1970: 1_720_300_000)
        ),
        taskingBrief: brief,
        createdAt: Date(timeIntervalSince1970: 1_720_300_000)
    )

    let body = makePMTaskingBriefBody(brief)
    let followUpBody = makePMAnalystFollowUpBody(action)
    let description = makePMTaskDescription(
        baseDescription: "Review the current setup.",
        brief: brief,
        action: action,
        sourceDelegationTitle: "Technology review"
    )

    #expect(body.contains("Objective: Challenge the current conclusion."))
    #expect(body.contains("Why now: The PM needs a recommendation-ready read before the next owner review."))
    #expect(body.contains("Expected answer shape: Recommendation-Ready Synthesis"))
    #expect(body.contains("Disconfirming evidence: Show what would make the PM back away from the current thesis."))
    #expect(body.contains("Expected outputs: memo, finding"))
    #expect(followUpBody.contains("Action: Rerun With Runtime"))
    #expect(followUpBody.contains("Managerial intent: The PM wants the same analyst to reattempt the task under a more suitable runtime or reasoning profile."))
    #expect(followUpBody.contains("Requested runtime: gpt-5 (deliberate reasoning)"))
    #expect(description.contains("PM follow-up on Technology review: Rerun With Runtime. The PM wants the same analyst to reattempt the task under a more suitable runtime or reasoning profile."))
    #expect(description.contains("PM tasking brief:"))
    #expect(description.contains("Requested next step meaning: The same specialist remains responsible, but the new run is explicitly retried under revised runtime conditions."))
}

@Test("PM tasking brief presents selected Agent Skill references")
func pmTaskingBriefPresentsSelectedAgentSkillReferences() throws {
    let now = Date(timeIntervalSince1970: 1_800_002_700)
    let brief = PMTaskingBrief(
        taskObjective: "Review NVDA with selected reusable methods.",
        selectedSkillReferences: [
            AgentSkillTaskReference(
                skillId: AgentSkillSeed.disconfirmingEvidenceChecklistID,
                skillTitle: "Disconfirming Evidence Checklist",
                requirement: .required,
                source: .pmConversation,
                rationale: "Owner asked the PM to request this skill.",
                updatedBy: "pm-1",
                createdAt: now,
                updatedAt: now
            )
        ]
    )

    let body = makePMTaskingBriefBody(brief)
    let encoded = try JSONEncoder().encode(brief)
    let decoded = try JSONDecoder().decode(PMTaskingBrief.self, from: encoded)

    #expect(body.contains("Selected Agent Skills: Disconfirming Evidence Checklist"))
    #expect(body.contains(AgentSkillSeed.disconfirmingEvidenceChecklistID))
    #expect(body.contains("as required from PM Conversation"))
    #expect(decoded.selectedSkillReferences.first?.skillId == AgentSkillSeed.disconfirmingEvidenceChecklistID)
    #expect(decoded.selectedSkillReferences.first?.source == .pmConversation)
}

@Test("PM follow-up guidance distinguishes managerial choices")
func pmFollowUpGuidanceDistinguishesManagerialChoices() {
    let revision = makePMAnalystFollowUpGuidance(.requestRevision)
    let strongerEvidence = makePMAnalystFollowUpGuidance(.requestStrongerEvidence)
    let reroute = makePMAnalystFollowUpGuidance(.rerouteToAnalyst)
    let rerun = makePMAnalystFollowUpGuidance(.rerunWithRuntime)

    #expect(revision.managerialIntent.contains("same line of work tightened"))
    #expect(strongerEvidence.managerialIntent.contains("stronger proof"))
    #expect(reroute.managerialIntent.contains("different specialist"))
    #expect(rerun.managerialIntent.contains("same analyst"))
    #expect(revision.nextStepMeaning != strongerEvidence.nextStepMeaning)
    #expect(reroute.nextStepMeaning.contains("another charter"))
    #expect(rerun.useCase.contains("stronger runtime"))
}

@Test("Engine PM follow-up creates child delegation and preserves runtime lineage")
func enginePMFollowUpCreatesChildDelegationAndLaunchesIt() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []
        func record(_ request: AnalystWorkerLaunchRequest) { requests.append(request) }
        func all() -> [AnalystWorkerLaunchRequest] { requests }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder
        let now: Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            let runtimeProvenance = AnalystRuntimeProvenance(
                intendedPolicy: request.intendedRuntimePolicy,
                actualRuntimeIdentifier: "deterministic_local[\(request.intendedRuntimePolicy?.runtimeIdentifier ?? "deterministic_local")]",
                actualReasoningMode: request.intendedRuntimePolicy?.reasoningMode,
                launchedAt: now
            )
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                memoId: "memo-follow-up-1",
                memoTitle: "Follow-up memo",
                findingId: "finding-follow-up-1",
                findingTitle: "Follow-up finding",
                draftedSignalId: nil,
                draftedProposalId: nil,
                runtimeProvenance: runtimeProvenance,
                summary: "follow-up launched",
                outputExcerpt: "Follow-up completed."
            )
        }
    }

    let root = makePMTaskingTempDirectory(name: "pm-follow-up-launch")
    let pmProfiles = PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true))
    let pmDelegations = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let pmDecisions = PMDecisionStore(decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true))
    let newsStore = NewsStore(newsDirectory: root.appendingPathComponent("news", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(fileURL: root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false))
    let charters = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let tasks = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: root.appendingPathComponent("memory", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_720_301_000)

    _ = try await pmProfiles.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Delegates analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await charters.upsert(
        AnalystCharter(
            charterId: "bench-sector-technology",
            analystId: "tech-analyst",
            title: "Technology",
            coverageScope: "Technology equities",
            strategyFamily: "long-only",
            summary: "Technology review",
            defaultRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-4.1",
                reasoningMode: .standard,
                policySource: .charterDefault,
                createdAt: now,
                updatedAt: now
            ),
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await charters.upsert(
        AnalystCharter(
            charterId: "bench-overlay-macro",
            analystId: "macro-analyst",
            title: "Macro and International",
            coverageScope: "Macro overlay",
            strategyFamily: "overlay",
            summary: "Macro review",
            defaultRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-4.1-mini",
                reasoningMode: .standard,
                policySource: .charterDefault,
                createdAt: now,
                updatedAt: now
            ),
            createdAt: now,
            updatedAt: now
        )
    )

    let sourceTask = AnalystTask(
        taskId: "task-1",
        analystId: "tech-analyst",
        charterId: "bench-sector-technology",
        title: "Initial review",
        description: "Review whether the current technology setup still holds.",
        pmTaskingBrief: PMTaskingBrief(
            taskObjective: "Pressure test the long thesis.",
            reviewLens: "Start with the bear case."
        ),
        status: .completed,
        createdAt: now,
        updatedAt: now
    )
    _ = try await tasks.upsert(sourceTask)
    _ = try await pmDelegations.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "tech-analyst",
            charterId: "bench-sector-technology",
            taskId: "task-1",
            title: "Technology review",
            rationale: "Initial PM-issued analyst review.",
            taskingBrief: sourceTask.pmTaskingBrief,
            requestedOutputs: [.finding],
            status: .completed,
            runtimePolicyOverride: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-4.1",
                reasoningMode: .standard,
                policySource: .pmDelegationOverride,
                createdAt: now,
                updatedAt: now
            ),
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        newsStore: newsStore,
        pmProfileStore: pmProfiles,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisions,
        pmDelegationStore: pmDelegations,
        analystCharterStore: charters,
        analystTaskStore: tasks,
        analystScopedMemoryStore: memoryStore,
        analystWorkerLauncher: StubLauncher(recorder: recorder, now: now)
    )

    let result = try await engine.submitPMDelegationFollowUp(
        PMDelegationFollowUpRequest(
            sourceDelegationId: "delegation-1",
            actionType: .rerunWithRuntime,
            summary: "Rerun this with a stronger runtime and explicitly challenge the original thesis.",
            requestedRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                policySource: .pmDelegationOverride,
                createdAt: now,
                updatedAt: now
            ),
            taskingBrief: PMTaskingBrief(
                taskObjective: "Challenge the current thesis.",
                whyNow: "Owner review may follow if the evidence materially changes.",
                reviewLens: "Disconfirming evidence first.",
                expectedAnswerShape: .evidenceBackedAnswer,
                challengeInstruction: "Assume the prior analyst read is wrong.",
                evidenceExpectation: "Use both app-owned context and external evidence.",
                disconfirmingEvidenceExpectation: "Spell out what would invalidate the current read.",
                expectedOutputs: ["memo", "finding"],
                revisionReason: "Prior pass was too confirmatory."
            )
        )
    )

    #expect(result.createdDelegationId != nil)
    #expect(result.createdTaskId != nil)
    #expect(result.createdDecisionId == nil)
    #expect(result.launchResult?.delegationId == result.createdDelegationId)

    let source = try await engine.getPMDelegation(id: "delegation-1")
    let child = try await engine.getPMDelegation(id: try #require(result.createdDelegationId))
    let childTask = try await engine.getAnalystTask(id: try #require(result.createdTaskId))
    let requests = await recorder.all()

    #expect(source.followUpActions.count == 1)
    #expect(source.followUpActions.first?.actionType == .rerunWithRuntime)
    #expect(child.parentDelegationId == "delegation-1")
    #expect(child.sourceFollowUpActionId == source.followUpActions.first?.actionId)
    #expect(child.runtimePolicyOverride?.runtimeIdentifier == "gpt-5")
    #expect(childTask.parentTaskId == "task-1")
    #expect(childTask.pmTaskingBrief?.reviewLens == "Disconfirming evidence first.")
    #expect(childTask.pmTaskingBrief?.whyNow == "Owner review may follow if the evidence materially changes.")
    #expect(childTask.pmTaskingBrief?.expectedAnswerShape == .evidenceBackedAnswer)
    #expect(childTask.description.contains("PM tasking brief:"))
    #expect(childTask.description.contains("Expected answer shape: Evidence-Backed Answer"))
    #expect(child.rationale.contains("Requested runtime: gpt-5 (deliberate reasoning)."))
    #expect(child.rationale.contains("same specialist remains responsible"))
    #expect(requests.count == 1)
    #expect(requests.first?.intendedRuntimePolicy?.runtimeIdentifier == "gpt-5")
    #expect(requests.first?.delegationId == child.delegationId)
}

@Test("PM follow-up on seeded standing charter ignores stale charter runtime defaults")
func enginePMFollowUpOnSeededStandingCharterIgnoresStaleCharterDefaults() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []
        func record(_ request: AnalystWorkerLaunchRequest) { requests.append(request) }
        func all() -> [AnalystWorkerLaunchRequest] { requests }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder
        let now: Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                memoId: "memo-follow-up-seeded-default",
                memoTitle: "Follow-up memo",
                findingId: "finding-follow-up-seeded-default",
                findingTitle: "Follow-up finding",
                draftedSignalId: nil,
                draftedProposalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: request.intendedRuntimePolicy,
                    actualRuntimeIdentifier: "deterministic_local[\(request.intendedRuntimePolicy?.runtimeIdentifier ?? "deterministic_local")]",
                    actualReasoningMode: request.intendedRuntimePolicy?.reasoningMode,
                    launchedAt: now
                ),
                summary: "follow-up launched",
                outputExcerpt: "Follow-up completed."
            )
        }
    }

    let root = makePMTaskingTempDirectory(name: "pm-follow-up-seeded-default")
    let pmProfiles = PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true))
    let pmDelegations = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let pmDecisions = PMDecisionStore(decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true))
    let newsStore = NewsStore(newsDirectory: root.appendingPathComponent("news", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(fileURL: root.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false))
    let charters = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let tasks = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: root.appendingPathComponent("memory", isDirectory: true))
    let runtimeSettingsStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: root.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)
    )
    let now = Date(timeIntervalSince1970: 1_720_301_500)

    _ = try await runtimeSettingsStore.upsert(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4-mini",
            reasoningMode: .deliberate,
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmProfiles.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Delegates analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await charters.upsert(
        AnalystCharter(
            charterId: "bench-sector-technology",
            analystId: "tech-analyst",
            title: "Technology",
            coverageScope: "Technology equities",
            strategyFamily: "standing sector bench",
            summary: "Technology review",
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
    _ = try await tasks.upsert(
        AnalystTask(
            taskId: "task-1",
            analystId: "tech-analyst",
            charterId: "bench-sector-technology",
            title: "Initial review",
            description: "Review the setup.",
            status: .completed,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmDelegations.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "tech-analyst",
            charterId: "bench-sector-technology",
            taskId: "task-1",
            title: "Technology review",
            rationale: "Initial PM-issued analyst review.",
            requestedOutputs: [.finding],
            status: .completed,
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        newsStore: newsStore,
        pmProfileStore: pmProfiles,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisions,
        pmDelegationStore: pmDelegations,
        analystCharterStore: charters,
        analystTaskStore: tasks,
        analystScopedMemoryStore: memoryStore,
        standingBenchAnalystRuntimeSettingsStore: runtimeSettingsStore,
        analystWorkerLauncher: StubLauncher(recorder: recorder, now: now)
    )

    let result = try await engine.submitPMDelegationFollowUp(
        PMDelegationFollowUpRequest(
            sourceDelegationId: "delegation-1",
            actionType: .requestRevision,
            summary: "Tighten this pass and keep the current specialist."
        )
    )

    let child = try await engine.getPMDelegation(id: try #require(result.createdDelegationId))
    let requests = await recorder.all()

    #expect(child.runtimePolicyOverride?.runtimeIdentifier == "gpt-5.4-mini")
    #expect(child.runtimePolicyOverride?.reasoningMode == .deliberate)
    #expect(child.runtimePolicyOverride?.policySource == .standingBenchDefault)
    #expect(requests.count == 1)
    #expect(requests.first?.intendedRuntimePolicy?.runtimeIdentifier == "gpt-5.4-mini")
    #expect(requests.first?.intendedRuntimePolicy?.policySource == .standingBenchDefault)
}

@Test("Engine PM accept follow-up records a decision without creating child delegation")
func enginePMAcceptFollowUpRecordsDecisionOnly() async throws {
    let root = makePMTaskingTempDirectory(name: "pm-follow-up-accept")
    let pmProfiles = PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true))
    let pmDelegations = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let pmDecisions = PMDecisionStore(decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true))
    let charters = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let tasks = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_720_302_000)

    _ = try await pmProfiles.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Delegates analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await charters.upsert(
        AnalystCharter(
            charterId: "bench-sector-technology",
            analystId: "tech-analyst",
            title: "Technology",
            coverageScope: "Technology equities",
            strategyFamily: "long-only",
            summary: "Technology review",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await tasks.upsert(
        AnalystTask(
            taskId: "task-1",
            analystId: "tech-analyst",
            charterId: "bench-sector-technology",
            title: "Initial review",
            description: "Review the setup.",
            status: .completed,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmDelegations.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "tech-analyst",
            charterId: "bench-sector-technology",
            taskId: "task-1",
            title: "Technology review",
            rationale: "Initial PM-issued analyst review.",
            requestedOutputs: [.finding],
            status: .completed,
            linkedFindingIDs: ["finding-1"],
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(
        pmProfileStore: pmProfiles,
        pmDecisionStore: pmDecisions,
        pmDelegationStore: pmDelegations,
        analystCharterStore: charters,
        analystTaskStore: tasks
    )

    let result = try await engine.submitPMDelegationFollowUp(
        PMDelegationFollowUpRequest(
            sourceDelegationId: "delegation-1",
            actionType: .accept,
            summary: "Current output is sufficient for the PM layer."
        )
    )

    #expect(result.createdDelegationId == nil)
    #expect(result.createdTaskId == nil)
    #expect(result.createdDecisionId != nil)

    let decisions = try await engine.listPMDecisions()
    let source = try await engine.getPMDelegation(id: "delegation-1")

    #expect(decisions.count == 1)
    #expect(decisions.first?.delegationId == "delegation-1")
    #expect(source.followUpActions.count == 1)
    #expect(source.followUpActions.first?.actionType == .accept)
    #expect(try await engine.listPMDelegations().count == 1)
}

private func makePMTaskingTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
