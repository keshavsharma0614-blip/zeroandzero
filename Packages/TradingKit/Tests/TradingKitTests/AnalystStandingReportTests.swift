import Foundation
import Testing
@testable import TradingKit

@Test("ScheduleStore seeds weekly standing analyst report defaults for the full bench")
func scheduleStoreSeedsWeeklyStandingAnalystReportDefaults() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("standing-report-schedules-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedules = try await store.seedDefaultsIfStoreMissing()
    let standingSchedules = schedules.filter { $0.jobType == .standingAnalystReport }

    #expect(standingSchedules.count == 9)
    #expect(Set(standingSchedules.map(\.scheduleId)) == Set(standingAnalystReportScheduleDefinitions().map(\.scheduleId)))
    #expect(standingSchedules.allSatisfy { $0.enabled })
    #expect(standingSchedules.allSatisfy { $0.trigger.intervalSec == standingAnalystReportDefaultIntervalSec })
    #expect(standingSchedules.allSatisfy { $0.policy.runMode == .periodic })
    #expect(standingSchedules.allSatisfy { $0.policy.startupBehavior == .waitForInterval })
    #expect(standingSchedules.contains { schedule in
        schedule.scheduleId == "standing-report-\(recentNewsStandingAnalystCharterID)"
            && schedule.params["analystTitle"] == .string(recentNewsStandingAnalystTitle)
    })
}

@Test("ScheduleStore seeds missing standing defaults without overwriting existing user-owned cadence choices")
func scheduleStoreSeedsMissingStandingDefaultsWithoutOverwrite() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("standing-report-schedule-protection-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let customSchedule = ScheduledJob(
        scheduleId: "standing-report-bench-sector-technology",
        jobType: .standingAnalystReport,
        enabled: false,
        trigger: ScheduledJobTrigger(intervalSec: standingAnalystReportDefaultIntervalSec * 2),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false,
            startupBehavior: .waitForInterval
        ),
        params: [
            "analystId": .string("bench-sector-technology-analyst"),
            "charterId": .string("bench-sector-technology"),
            "analystTitle": .string("Technology Analyst"),
            "reportKind": .string(AnalystStandingReportKind.standingRecurring.rawValue)
        ]
    )
    _ = try await store.upsert(customSchedule)

    let seeded = try await store.seedMissingDefaults()
    let standingSchedules = seeded.filter { $0.jobType == .standingAnalystReport }
    let protected = try #require(seeded.first(where: { $0.scheduleId == customSchedule.scheduleId }))

    #expect(standingSchedules.count == 9)
    #expect(protected.enabled == false)
    #expect(protected.trigger.intervalSec == standingAnalystReportDefaultIntervalSec * 2)
}

@Test("Standing analyst report store persists completed PM Inbox artifacts predictably")
func standingAnalystReportStorePersistsCompletedArtifactsPredictably() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-store")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let now = Date(timeIntervalSince1970: 1_742_500_000)
    let store = AnalystStandingReportStore(
        reportsDirectory: tempRoot.appendingPathComponent("standing-reports", isDirectory: true),
        now: { now }
    )

    let report = AnalystStandingReport(
        reportId: "standing-report-1",
        analystId: "bench-sector-technology-analyst",
        charterId: "bench-sector-technology",
        scheduleId: "standing-report-bench-sector-technology",
        memoId: "memo-1",
        runtimeProvenance: AnalystRuntimeProvenance(
            intendedPolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5.4",
                reasoningMode: .deliberate,
                policySource: .standingBenchDefault,
                createdAt: now,
                updatedAt: now
            ),
            actualRuntimeIdentifier: "openai_responses[gpt-5.4]",
            actualReasoningMode: .deliberate,
            launchedAt: now
        ),
        title: "Technology Analyst Standing Report",
        summary: "Weekly standing report delivered for Technology Analyst.",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly recurring review delivered on 2025-03-26T00:00:00Z.",
        portfolioScopeSummary: "Covered current portfolio names: NVDA, MSFT.",
        coveredSymbols: ["NVDA", "MSFT"],
        headlineView: "The recurring contract now reserves structured sections for later ranked technology views.",
        portfolioRelevanceSummary: "This sector report is grounded on the current strategy brief and existing technology exposure.",
        openQuestions: ["Which technology names should matter most before the next standing review?"],
        evidenceReferenceSummary: ["Portfolio Strategy Brief: Current Portfolio Strategy Brief"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "long-ideas",
                kind: .longIdeas,
                items: [
                    AnalystStandingReportItem(
                        itemId: "nvda-long",
                        headline: "NVDA remains a candidate",
                        detail: "Placeholder long-candidate slot for later richer sector reporting.",
                        symbol: "NVDA",
                        stance: .long,
                        conviction: 7
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    _ = try await store.upsert(report)
    let loaded = try await store.loadAll()

    #expect(loaded.count == 1)
    #expect(loaded.first?.reportId == "standing-report-1")
    #expect(loaded.first?.deliveryStatus == .pendingPMReview)
    #expect(loaded.first?.kind == .standingRecurring)
    #expect(loaded.first?.coveredSymbols == ["NVDA", "MSFT"])
    #expect(loaded.first?.sections.first?.kind == .longIdeas)
    #expect(loaded.first?.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4]")
}

@Test("Standing analyst report contract round-trips structured fields for sector, macro, and risk reports")
func standingAnalystReportContractSupportsSectorMacroAndRiskPopulation() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-contract")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let now = Date(timeIntervalSince1970: 1_742_510_000)
    let store = AnalystStandingReportStore(
        reportsDirectory: tempRoot.appendingPathComponent("standing-reports", isDirectory: true),
        now: { now }
    )

    let sector = AnalystStandingReport(
        reportId: "sector-report",
        analystId: "bench-sector-technology-analyst",
        charterId: "bench-sector-technology",
        scheduleId: "standing-report-bench-sector-technology",
        memoId: "memo-sector",
        title: "Technology Analyst Standing Report",
        summary: "Weekly technology standing report.",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly recurring review.",
        portfolioScopeSummary: "Covered current portfolio names: NVDA.",
        coveredSymbols: ["NVDA"],
        headlineView: "Technology report headline view.",
        portfolioRelevanceSummary: "Technology posture matters for the current portfolio construction.",
        openQuestions: ["Which technology long should rank first?"],
        evidenceReferenceSummary: ["Portfolio Strategy Brief"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "long-ideas",
                kind: .longIdeas,
                items: [
                    AnalystStandingReportItem(
                        itemId: "nvda",
                        headline: "NVDA",
                        detail: "Later richer sector population will add thesis detail.",
                        symbol: "NVDA",
                        stance: .long,
                        conviction: 8
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "short-ideas",
                kind: .shortIdeas,
                items: [
                    AnalystStandingReportItem(
                        itemId: "weak-soft",
                        headline: "Software basket short placeholder",
                        detail: "Reserved short slot.",
                        stance: .short,
                        conviction: 5
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )
    let macro = AnalystStandingReport(
        reportId: "macro-report",
        analystId: "bench-overlay-macro-international-analyst",
        charterId: "bench-overlay-macro-international",
        scheduleId: "standing-report-bench-overlay-macro-international",
        memoId: "memo-macro",
        title: "Macro and International Analyst Standing Report",
        summary: "Weekly macro standing report.",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly recurring review.",
        portfolioScopeSummary: "Covered portfolio posture across current holdings.",
        coveredSymbols: [],
        headlineView: "Macro report headline view.",
        portfolioRelevanceSummary: "Macro posture matters for gross, hedge, and geographic exposure.",
        openQuestions: ["Which ETF expression fits best?"],
        evidenceReferenceSummary: ["Current holdings snapshot"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "macro-views",
                kind: .macroViews,
                items: [
                    AnalystStandingReportItem(
                        itemId: "macro-view",
                        headline: "Rates sensitivity placeholder",
                        detail: "Reserved macro transmission slot.",
                        stance: .macro,
                        priority: 7
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "etf-ideas",
                kind: .etfIdeas,
                items: [
                    AnalystStandingReportItem(
                        itemId: "etf",
                        headline: "IEF placeholder",
                        detail: "Reserved ETF expression slot.",
                        symbol: "IEF",
                        stance: .etf,
                        conviction: 4
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )
    let risk = AnalystStandingReport(
        reportId: "risk-report",
        analystId: "bench-overlay-portfolio-risk-analyst",
        charterId: "bench-overlay-portfolio-risk",
        scheduleId: "standing-report-bench-overlay-portfolio-risk",
        memoId: "memo-risk",
        title: "Portfolio Risk Analyst Standing Report",
        summary: "Weekly risk standing report.",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly recurring review.",
        portfolioScopeSummary: "Covered current portfolio names: NVDA, MSFT.",
        coveredSymbols: ["NVDA", "MSFT"],
        headlineView: "Risk report headline view.",
        portfolioRelevanceSummary: "Risk posture matters for concentration and downside review.",
        openQuestions: ["Which cluster should the PM stress first?"],
        evidenceReferenceSummary: ["Current risk posture"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "risk-issues",
                kind: .riskIssues,
                items: [
                    AnalystStandingReportItem(
                        itemId: "cluster",
                        headline: "Technology concentration placeholder",
                        detail: "Reserved risk issue slot.",
                        stance: .risk,
                        priority: 8
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    _ = try await store.upsert(sector)
    _ = try await store.upsert(macro)
    _ = try await store.upsert(risk)
    let loaded = try await store.loadAll()

    #expect(loaded.count == 3)
    #expect(loaded.contains(where: { $0.sections.contains(where: { $0.kind == .longIdeas }) }))
    #expect(loaded.contains(where: { $0.sections.contains(where: { $0.kind == .macroViews }) }))
    #expect(loaded.contains(where: { $0.sections.contains(where: { $0.kind == .riskIssues }) }))
}

@Test("Standing analyst report jobs create a distinct PM Inbox review artifact without using ad hoc delegation output")
func standingAnalystReportJobsCreateMemoAndStandingReportArtifact() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-engine")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "tech-nvda",
                title: "NVDA datacenter demand stays firm",
                summary: "technology infrastructure demand remains durable for datacenter semis.",
                symbols: ["NVDA"]
            ),
            makeStandingReportNewsEvent(
                id: "tech-msft",
                title: "MSFT enterprise AI adoption broadens",
                summary: "Enterprise software demand keeps cloud and copilots in focus.",
                symbols: ["MSFT"]
            ),
            makeStandingReportNewsEvent(
                id: "tech-intc",
                title: "INTC manufacturing execution stays in focus",
                summary: "Capital intensity and execution remain central to the turnaround debate.",
                symbols: ["INTC"]
            )
        ],
        newsStore: newsStore
    )
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "sector-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_600_000),
                        summary: "Allowlisted sector benchmark anchor for standing report tests.",
                        snippet: "Allowlisted sector benchmark anchor for standing report tests.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        }
    )
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-sector-technology"
        })
    )

    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: """
            # Current Portfolio Strategy Brief
            ## Objective
            Concentrate in durable compounders with selective technology infrastructure exposure.

            ## Key Themes
            - technology infrastructure
            - Quality compounders
            - Avoid fragile balance sheets
            """,
            objectiveSummary: "Concentrate in durable compounders with selective technology infrastructure exposure.",
            keyThemes: ["technology infrastructure", "Quality compounders", "Avoid fragile balance sheets"],
            currentRiskPosture: "Moderate concentration risk is acceptable when quality and liquidity remain strong.",
            reviewEscalationPosture: "Escalate when sector developments change current exposure decisions.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_600_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_600_000)
        ),
        source: .ui
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000"),
            Position(symbol: "XOM", qty: "5", side: "long", marketValue: "5000")
        ]
    )
    await engine.store.setWatchlistSymbols(["AVGO", "SNOW", "XOM"])
    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .engine)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)

    #expect(completed.status == .succeeded)
    let result = try #require(completed.result?.objectValue)
    let reportID = try #require(result["reportId"]?.stringValue)
    let memoID = try #require(result["memoId"]?.stringValue)

    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first(where: { $0.reportId == reportID }))
    let memos = try await engine.listAnalystMemos()
    let memo = try #require(memos.first(where: { $0.memoId == memoID }))

    #expect(reports.count == 1)
    #expect(memos.count == 1)
    #expect(report.kind == .standingRecurring)
    #expect(report.deliveryStatus == .pendingPMReview)
    #expect(report.scheduleId == schedule.scheduleId)
    #expect(report.memoId == memo.memoId)
    #expect(memo.title.contains("Standing Report"))
    #expect(memo.recommendedNextStep.isEmpty == false)
    #expect(report.reportingWindowSummary.contains("technology review"))
    #expect(report.coveredSymbols == ["NVDA"])
    #expect(report.portfolioScopeSummary.contains("NVDA"))
    #expect(report.portfolioRelevanceSummary.contains("technology infrastructure"))
    #expect(report.headlineView.isEmpty == false)
    #expect(memo.uncertaintySummary.isEmpty == false)
    #expect(memo.runtimeProvenance?.actualRuntimeIdentifier.contains("deterministic_local") == true)
    #expect(report.sections.contains(where: { $0.kind == .materialDevelopments }))
    #expect(report.sections.contains(where: { $0.kind == .longIdeas }))
    #expect(report.sections.contains(where: { section in
        section.kind == .longIdeas && section.items.contains(where: { $0.conviction != nil && $0.symbol != nil })
    }))
    #expect(report.sections.contains(where: { section in
        section.kind == .shortIdeas && section.items.contains(where: { $0.conviction != nil && $0.symbol != nil })
    }))
    #expect(report.evidenceReferenceSummary.contains(where: { $0.contains("Portfolio Strategy Brief") }))
    #expect(report.evidenceReferenceSummary.contains(where: { $0.contains("Recent news:") }))
    #expect(report.sections.contains(where: { $0.kind == .followUp }))
    #expect(try await engine.listPMDelegations().isEmpty)
    await engine.stop()
}

@Test("Standing analyst Run Now preserves schedule cadence while dispatching a standing report immediately")
func standingAnalystRunNowPreservesScheduleTruth() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-run-now-preserves-schedule")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "tech-run-now-nvda",
                title: "NVDA demand remains firm",
                summary: "Technology demand remains supportive for an immediate standing run.",
                symbols: ["NVDA"]
            ),
            makeStandingReportNewsEvent(
                id: "tech-run-now-intc",
                title: "INTC execution remains under pressure",
                summary: "Execution remains the clearer short-side pressure test.",
                symbols: ["INTC"]
            )
        ],
        newsStore: newsStore
    )
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "run-now-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_612_000),
                        summary: "Allowlisted sector benchmark anchor for standing run-now tests.",
                        snippet: "Allowlisted sector benchmark anchor for standing run-now tests.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        }
    )

    var schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-sector-technology"
        })
    )
    schedule.enabled = false
    schedule.trigger.intervalSec = standingAnalystReportDefaultIntervalSec * 2

    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: """
            # Current Portfolio Strategy Brief
            ## Objective
            Keep technology exposure deliberate while allowing immediate owner-invoked standing reviews.
            """,
            objectiveSummary: "Keep technology exposure deliberate while allowing immediate owner-invoked standing reviews.",
            keyThemes: ["Technology exposure", "Immediate review"],
            currentRiskPosture: "Moderate.",
            reviewEscalationPosture: "Escalate when sector posture changes.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_612_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_612_000)
        ),
        source: .ui
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000")
        ]
    )
    await engine.store.setWatchlistSymbols(["AVGO", "INTC"])

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .ui)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)

    #expect(completed.status == .succeeded)

    let schedules = try await engine.listSchedules()
    let refreshedSchedule = try #require(schedules.first(where: { $0.scheduleId == schedule.scheduleId }))
    #expect(refreshedSchedule.enabled == false)
    #expect(refreshedSchedule.intervalSec == standingAnalystReportDefaultIntervalSec * 2)
    #expect(refreshedSchedule.lastRunAt != nil)
    #expect(refreshedSchedule.nextRunAt != nil)

    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first(where: { $0.scheduleId == schedule.scheduleId }))
    #expect(report.kind == .standingRecurring)
    #expect(report.deliveryStatus == .pendingPMReview)
    #expect(report.title.contains("Standing Report"))
    #expect(try await engine.listPMDelegations().isEmpty)
    await engine.stop()
}

@Test("Standing analyst report generation uses model-backed synthesis when provider and key are available")
func standingAnalystReportGenerationUsesModelBackedSynthesisWhenAvailable() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-openai-backed")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "model-tech-1",
                title: "NVDA demand stays firm",
                summary: "Demand remains strong across the technology infrastructure stack.",
                symbols: ["NVDA", "AVGO"]
            )
        ],
        newsStore: newsStore
    )
    let launchRecorder = LaunchRecorder()
    let now = Date(timeIntervalSince1970: 1_742_640_100)
    let standingBenchRuntimeSettingsStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)
    )
    _ = try await standingBenchRuntimeSettingsStore.upsert(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    let agentSkillStore = AgentSkillStore(
        skillsDirectory: tempRoot.appendingPathComponent("agent-skills", isDirectory: true),
        now: { now }
    )
    _ = try await agentSkillStore.seedMissingDefaultSkills()
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "model-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_640_000),
                        summary: "Charter-governed benchmark context for model-backed standing synthesis.",
                        snippet: "Charter-governed benchmark context for model-backed standing synthesis.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        },
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        agentSkillStore: agentSkillStore,
        standingBenchAnalystRuntimeSettingsStore: standingBenchRuntimeSettingsStore,
        analystWorkerLauncher: StubLauncher(
            recorder: launchRecorder,
            result: AnalystWorkerLaunchResult(
                openAIKeyConfigured: true,
                usedOpenAI: true,
                charterId: "bench-sector-technology",
                taskId: "standing-report-task-standing-report-bench-sector-technology",
                memoId: "memo-standing-tech-1",
                memoTitle: "Technology Analyst Standing Report",
                findingId: "finding-standing-tech-1",
                findingTitle: "Technology standing finding",
                draftedSignalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: AnalystRuntimePolicy(
                        runtimeIdentifier: "gpt-5.4",
                        reasoningMode: .deliberate,
                        policySource: .standingBenchDefault,
                        createdAt: now,
                        updatedAt: now
                    ),
                    actualRuntimeIdentifier: "openai_responses[gpt-5.4]",
                    actualReasoningMode: .deliberate,
                    launchedAt: now
                ),
                externalEvidenceStatus: "ok",
                synthesisStatus: "openai_responses",
                summary: "standing worker completed",
                outputExcerpt: "Model-backed standing summary for Technology Analyst."
            )
        )
    )

    let seededCharters = try await engine.listAnalystCharters()
    var technologyCharter = try #require(seededCharters.first(where: { $0.charterId == "bench-sector-technology" }))
    technologyCharter.skillReferences = [
        AgentSkillReference(
            skillId: AgentSkillSeed.disconfirmingEvidenceChecklistID,
            requirement: .recommended,
            rationale: "Technology standing reports should pressure-test disconfirming evidence.",
            updatedBy: "human owner",
            createdAt: now,
            updatedAt: now
        ),
        AgentSkillReference(
            skillId: AgentSkillSeed.portfolioFitRiskLensID,
            requirement: .recommended,
            rationale: "Technology standing reports should map findings to portfolio fit.",
            updatedBy: "human owner",
            createdAt: now,
            updatedAt: now
        ),
        AgentSkillReference(
            skillId: AgentSkillSeed.sourceQualityCorroborationID,
            requirement: .recommended,
            rationale: "Technology standing reports should classify source quality.",
            updatedBy: "human owner",
            createdAt: now,
            updatedAt: now
        ),
        AgentSkillReference(
            skillId: AgentSkillSeed.longShortCandidatePressureTestID,
            requirement: .required,
            rationale: "Technology standing reports should pressure-test long and short candidate ideas.",
            updatedBy: "human owner",
            createdAt: now,
            updatedAt: now
        )
    ]
    technologyCharter.updatedBy = "human owner"
    technologyCharter.updateSource = .userEdited
    technologyCharter.updatedAt = now
    _ = try await engine.upsertAnalystCharter(technologyCharter, source: .ui)
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-sector-technology"
        })
    )
    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertAnalystEvidenceBundle(
        AnalystEvidenceBundle(
            bundleId: "bundle-standing-tech-1",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            taskId: "standing-report-task-standing-report-bench-sector-technology",
            refs: [
                AnalystEvidenceRef(
                    refId: "news-1",
                    sourceKind: .appNews,
                    sourceIdentifier: "unit_test",
                    url: "https://example.com/model-tech-1",
                    title: "NVDA demand stays firm",
                    observedAt: now,
                    summary: "Baseline event.",
                    freshnessNote: "recent_app_news"
                ),
                AnalystEvidenceRef(
                    refId: "web-1",
                    sourceKind: .web,
                    sourceIdentifier: "model-anchor",
                    url: "https://example.com/bench-sector-technology-analyst",
                    title: "Technology Analyst benchmark overview",
                    observedAt: now,
                    summary: "Supplemental role: This source adds incremental timing, background, or strategic/risk context beyond the app-news baseline.",
                    freshnessNote: "supplemental_public_web_from_app_news:example.com"
                )
            ],
            summary: "Worker reviewed 1 app-news baseline item(s) and 1 supplemental policy-governed external source(s).",
            notes: "App-owned news first with supplemental charter-governed external evidence.",
            createdAt: now,
            updatedAt: now
        ),
        source: .engine
    )
    _ = try await engine.upsertAnalystMemo(
        AnalystMemo(
            memoId: "memo-standing-tech-1",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            taskId: "standing-report-task-standing-report-bench-sector-technology",
            findingId: "finding-standing-tech-1",
            evidenceBundleId: "bundle-standing-tech-1",
            title: "Technology Analyst Standing Report",
            executiveSummary: "Model-backed standing summary for Technology Analyst.",
            currentView: "The PM should keep technology infrastructure strength in active review.",
            evidenceSummary: "App-owned news was primary, with one charter-governed benchmark source adding sector context.",
            uncertaintySummary: "The next earnings cycle can still change the current ranking.",
            recommendedNextStep: "PM should monitor NVDA and AVGO while keeping INTC as the cleaner short-side pressure test.",
            confidence: 0.71,
            runtimeProvenance: AnalystRuntimeProvenance(
                intendedPolicy: AnalystRuntimePolicy(
                    runtimeIdentifier: "gpt-5.4",
                    reasoningMode: .deliberate,
                    policySource: .standingBenchDefault,
                    createdAt: now,
                    updatedAt: now
                ),
                actualRuntimeIdentifier: "openai_responses[gpt-5.4]",
                actualReasoningMode: .deliberate,
                launchedAt: now
            ),
            skillUsageSummaries: [
                AgentSkillUsageSummary(
                    skillId: AgentSkillSeed.longShortCandidatePressureTestID,
                    skillTitle: "Long / Short Candidate Pressure Test",
                    requirement: .required,
                    usage: .applied,
                    usageSummary: "Applied the long/short pressure-test method to NVDA, AVGO, and INTC."
                )
            ],
            createdAt: now,
            updatedAt: now
        ),
        source: .engine
    )
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: "Technology objective.",
            objectiveSummary: "Keep technology infrastructure exposure deliberate.",
            keyThemes: ["technology infrastructure"],
            currentRiskPosture: "Constructive with tighter earnings review.",
            reviewEscalationPosture: "Escalate real posture changes to PM review.",
            updatedBy: "owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_640_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_640_000)
        ),
        source: .ui
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000")
        ]
    )
    await engine.store.setWatchlistSymbols(["AVGO", "INTC"])

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .ui)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)
    #expect(completed.status == .succeeded)

    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first(where: { $0.scheduleId == schedule.scheduleId }))
    let memos = try await engine.listAnalystMemos()
    let memo = try #require(memos.first(where: { $0.memoId == report.memoId }))
    let request = try #require(await launchRecorder.all().first)
    let storedTask = try #require(
        try await engine.listAnalystTasks().first(where: { $0.taskId == "standing-report-task-standing-report-bench-sector-technology" })
    )

    #expect(memo.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4]")
    #expect(memo.runtimeProvenance?.actualReasoningMode == .deliberate)
    #expect(report.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4]")
    #expect(report.runtimeProvenance?.actualReasoningMode == .deliberate)
    #expect(report.summary == "Model-backed standing summary for Technology Analyst.")
    #expect(report.headlineView == "The PM should keep technology infrastructure strength in active review.")
    #expect(report.sections.contains(where: { $0.kind == .longIdeas }))
    #expect(report.sections.contains(where: { $0.kind == .shortIdeas }))
    #expect(report.skillUsageSummaries.first?.skillId == AgentSkillSeed.longShortCandidatePressureTestID)
    #expect(request.intendedRuntimePolicy?.runtimeIdentifier == "gpt-5.4")
    #expect(storedTask.tags.contains("app_news_first"))
    #expect(storedTask.description.contains("Start with"))
    #expect(storedTask.description.contains("Then perform current public-web research unless"))
    #expect(storedTask.description.contains("use the public research to confirm, qualify, or challenge"))
    #expect(storedTask.contextPack?.sharedCurrentTruth.recentNews.map(\.title) == ["NVDA demand stays firm"])
    #expect(storedTask.contextPack?.referencedSkills.map(\.skillId) == [
        AgentSkillSeed.disconfirmingEvidenceChecklistID,
        AgentSkillSeed.portfolioFitRiskLensID,
        AgentSkillSeed.sourceQualityCorroborationID,
        AgentSkillSeed.longShortCandidatePressureTestID
    ])
    #expect(storedTask.contextPack?.referencedSkills.count == 4)
    #expect(storedTask.contextPack?.referencedSkills.first(where: { $0.skillId == AgentSkillSeed.longShortCandidatePressureTestID })?.documentBody?.contains("Long / Short Candidate Pressure Test") == true)
    #expect((storedTask.contextPack?.referencedSkills.contains { $0.skillId == AgentSkillSeed.sourceQualityCorroborationID } ?? false) == true)
    let presentation = try #require(
        makeStandingAnalystReportReviewPresentations(
            reports: [report],
            memos: [memo],
            charters: try await engine.listAnalystCharters()
        ).first
    )
    #expect(presentation.skillUsageSummary.first?.contains("Long / Short Candidate Pressure Test") == true)
    #expect(presentation.skillUsageSummary.first?.contains("Applied") == true)
    await engine.stop()
}

@Test("Standing analyst report generation uses the standing bench runtime setting when no ad hoc override is present")
func standingAnalystReportGenerationUsesStandingBenchRuntimeSetting() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-bench-runtime-setting")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "bench-tech-1",
                title: "technology infrastructure demand held",
                summary: "Demand remained firm across current leaders.",
                symbols: ["NVDA"]
            )
        ],
        newsStore: newsStore
    )
    let launchRecorder = LaunchRecorder()
    let now = Date(timeIntervalSince1970: 1_742_640_100)
    let standingBenchRuntimeSettingsStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)
    )
    _ = try await standingBenchRuntimeSettingsStore.upsert(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: Date(timeIntervalSince1970: 1_742_640_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_640_000)
        )
    )

    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider(resolve: { _ in
            AnalystExternalEvidenceFetchResult(documents: [], issues: [])
        }),
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        standingBenchAnalystRuntimeSettingsStore: standingBenchRuntimeSettingsStore,
        analystWorkerLauncher: StubLauncher(
            recorder: launchRecorder,
            result: AnalystWorkerLaunchResult(
                openAIKeyConfigured: true,
                usedOpenAI: true,
                charterId: "bench-sector-technology",
                taskId: "standing-report-task-standing-report-bench-sector-technology",
                memoId: "memo-standing-tech-runtime",
                memoTitle: "Technology Analyst Standing Report",
                findingId: "finding-standing-tech-runtime",
                findingTitle: "Technology standing finding",
                draftedSignalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: AnalystRuntimePolicy(
                        runtimeIdentifier: "gpt-5.4",
                        reasoningMode: .deliberate,
                        policySource: .standingBenchDefault,
                        createdAt: now,
                        updatedAt: now
                    ),
                    actualRuntimeIdentifier: "openai_responses[gpt-5.4]",
                    actualReasoningMode: .deliberate,
                    launchedAt: now
                ),
                externalEvidenceStatus: "ok",
                synthesisStatus: "openai_responses",
                summary: "standing worker completed",
                outputExcerpt: "Bench runtime summary."
            )
        )
    )

    _ = try await engine.listAnalystCharters()
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-sector-technology"
        })
    )
    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertAnalystEvidenceBundle(
        AnalystEvidenceBundle(
            bundleId: "bundle-standing-tech-runtime",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            taskId: "standing-report-task-standing-report-bench-sector-technology",
            refs: [],
            summary: "Worker reviewed 1 app-news baseline item(s) and 0 supplemental policy-governed external source(s).",
            createdAt: now,
            updatedAt: now
        ),
        source: .engine
    )
    _ = try await engine.upsertAnalystMemo(
        AnalystMemo(
            memoId: "memo-standing-tech-runtime",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            taskId: "standing-report-task-standing-report-bench-sector-technology",
            findingId: "finding-standing-tech-runtime",
            evidenceBundleId: "bundle-standing-tech-runtime",
            title: "Technology Analyst Standing Report",
            executiveSummary: "Bench runtime summary.",
            currentView: "Bench runtime current view.",
            evidenceSummary: "Bench runtime evidence summary.",
            uncertaintySummary: "Bench runtime uncertainty summary.",
            recommendedNextStep: "Bench runtime next step.",
            confidence: 0.66,
            runtimeProvenance: AnalystRuntimeProvenance(
                intendedPolicy: AnalystRuntimePolicy(
                    runtimeIdentifier: "gpt-5.4",
                    reasoningMode: .deliberate,
                    policySource: .standingBenchDefault,
                    createdAt: now,
                    updatedAt: now
                ),
                actualRuntimeIdentifier: "openai_responses[gpt-5.4]",
                actualReasoningMode: .deliberate,
                launchedAt: now
            ),
            createdAt: now,
            updatedAt: now
        ),
        source: .engine
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000")
        ]
    )

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .ui)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)
    #expect(completed.status == .succeeded)

    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first(where: { $0.scheduleId == schedule.scheduleId }))
    let memos = try await engine.listAnalystMemos()
    let memo = try #require(memos.first(where: { $0.memoId == report.memoId }))
    let request = try #require(await launchRecorder.all().first)

    #expect(request.intendedRuntimePolicy?.runtimeIdentifier == "gpt-5.4")
    #expect(memo.runtimeProvenance?.intendedPolicy?.policySource == .standingBenchDefault)
    #expect(memo.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4]")
    #expect(report.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4]")
    await engine.stop()
}

@Test("Recent News standing report generation uses the recent-news specialization runtime setting")
func recentNewsStandingReportGenerationUsesSpecializationRuntimeSetting() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-recent-news-runtime-setting")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "recent-news-runtime-1",
                title: "Apple supplier timeline update lands in the baseline",
                summary: "Recent news baseline picked up a timing-sensitive Apple supplier update.",
                symbols: ["AAPL"]
            )
        ],
        newsStore: newsStore
    )
    let launchRecorder = LaunchRecorder()
    let now = Date(timeIntervalSince1970: 1_742_641_100)
    let recentNewsRuntimeSettingsStore = RecentNewsAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false)
    )
    _ = try await recentNewsRuntimeSettingsStore.upsert(
        RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4-mini",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider(resolve: { _ in
            AnalystExternalEvidenceFetchResult(documents: [], issues: [])
        }),
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        recentNewsAnalystRuntimeSettingsStore: recentNewsRuntimeSettingsStore,
        analystWorkerLauncher: StubLauncher(
            recorder: launchRecorder,
            result: AnalystWorkerLaunchResult(
                openAIKeyConfigured: true,
                usedOpenAI: true,
                charterId: recentNewsStandingAnalystCharterID,
                taskId: "standing-report-task-standing-report-\(recentNewsStandingAnalystCharterID)",
                memoId: "memo-standing-recent-news-runtime",
                memoTitle: "Recent News Analyst Standing Report",
                findingId: "finding-standing-recent-news-runtime",
                findingTitle: "Recent news standing finding",
                draftedSignalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: AnalystRuntimePolicy(
                        runtimeIdentifier: "gpt-5.4-mini",
                        reasoningMode: .standard,
                        policySource: .specializationDefault,
                        createdAt: now,
                        updatedAt: now
                    ),
                    actualRuntimeIdentifier: "openai_responses[gpt-5.4-mini]",
                    actualReasoningMode: .standard,
                    launchedAt: now
                ),
                externalEvidenceStatus: "ok",
                synthesisStatus: "openai_responses",
                summary: "recent news worker completed",
                outputExcerpt: "Recent news specialization runtime summary."
            )
        )
    )

    _ = try await engine.listAnalystCharters()
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-\(recentNewsStandingAnalystCharterID)"
        })
    )
    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertAnalystEvidenceBundle(
        AnalystEvidenceBundle(
            bundleId: "bundle-standing-recent-news-runtime",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            taskId: "standing-report-task-standing-report-\(recentNewsStandingAnalystCharterID)",
            refs: [],
            summary: "Worker reviewed 1 app-news baseline item(s).",
            createdAt: now,
            updatedAt: now
        ),
        source: .engine
    )
    _ = try await engine.upsertAnalystMemo(
        AnalystMemo(
            memoId: "memo-standing-recent-news-runtime",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            taskId: "standing-report-task-standing-report-\(recentNewsStandingAnalystCharterID)",
            findingId: "finding-standing-recent-news-runtime",
            evidenceBundleId: "bundle-standing-recent-news-runtime",
            title: "Recent News Analyst Standing Report",
            executiveSummary: "Recent news specialization runtime summary.",
            currentView: "Recent news specialization current view.",
            evidenceSummary: "Recent news specialization evidence summary.",
            uncertaintySummary: "Recent news specialization uncertainty summary.",
            recommendedNextStep: "Recent news specialization next step.",
            confidence: 0.61,
            runtimeProvenance: AnalystRuntimeProvenance(
                intendedPolicy: AnalystRuntimePolicy(
                    runtimeIdentifier: "gpt-5.4-mini",
                    reasoningMode: .standard,
                    policySource: .specializationDefault,
                    createdAt: now,
                    updatedAt: now
                ),
                actualRuntimeIdentifier: "openai_responses[gpt-5.4-mini]",
                actualReasoningMode: .standard,
                launchedAt: now
            ),
            createdAt: now,
            updatedAt: now
        ),
        source: .engine
    )
    await engine.store.setWatchlistSymbols(["AAPL"])

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .ui)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)
    #expect(completed.status == .succeeded)

    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first(where: { $0.scheduleId == schedule.scheduleId }))
    let memos = try await engine.listAnalystMemos()
    let memo = try #require(memos.first(where: { $0.memoId == report.memoId }))
    let request = try #require(await launchRecorder.all().first)

    #expect(request.intendedRuntimePolicy?.runtimeIdentifier == "gpt-5.4-mini")
    #expect(request.intendedRuntimePolicy?.policySource == .specializationDefault)
    #expect(memo.runtimeProvenance?.intendedPolicy?.policySource == .specializationDefault)
    #expect(memo.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4-mini]")
    #expect(report.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4-mini]")
    await engine.stop()
}

@Test("Recent News standing report fails with precise artifact-required blocker when worker returns no memo")
func recentNewsStandingReportMissingMemoFailureIsPrecise() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-recent-news-missing-memo")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "recent-news-missing-memo-1",
                title: "Apple supplier timeline update lands in the baseline",
                summary: "Recent news baseline picked up a timing-sensitive Apple supplier update.",
                symbols: ["AAPL"]
            )
        ],
        newsStore: newsStore
    )
    let launchRecorder = LaunchRecorder()
    let now = Date(timeIntervalSince1970: 1_742_641_150)
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider(resolve: { _ in
            AnalystExternalEvidenceFetchResult(documents: [], issues: [])
        }),
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        analystWorkerLauncher: StubLauncher(
            recorder: launchRecorder,
            result: AnalystWorkerLaunchResult(
                openAIKeyConfigured: true,
                usedOpenAI: true,
                charterId: recentNewsStandingAnalystCharterID,
                taskId: "standing-report-task-standing-report-\(recentNewsStandingAnalystCharterID)",
                memoId: nil,
                memoTitle: nil,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: AnalystRuntimePolicy(
                        runtimeIdentifier: "gpt-5.4-mini",
                        reasoningMode: .standard,
                        policySource: .specializationDefault,
                        createdAt: now,
                        updatedAt: now
                    ),
                    actualRuntimeIdentifier: "openai_responses[gpt-5.4-mini]",
                    actualReasoningMode: .standard,
                    launchedAt: now
                ),
                externalEvidenceStatus: "ok",
                synthesisStatus: "no_memo_output",
                synthesisIssueSummary: "worker completed without persisting memo",
                summary: "recent news worker completed without a memo",
                outputExcerpt: "No memo persisted."
            )
        )
    )

    _ = try await engine.listAnalystCharters()
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-\(recentNewsStandingAnalystCharterID)"
        })
    )
    _ = try await engine.upsertSchedule(schedule, source: .engine)
    await engine.store.setWatchlistSymbols(["AAPL"])

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .ui)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)
    let errorMessage = try #require(completed.error?.message)

    #expect(completed.status == .failed)
    #expect(errorMessage.contains("Recent News Analyst standing report requires a readable AnalystMemo"))
    #expect(errorMessage.contains("worker returned no memoId"))
    #expect(errorMessage.contains("No standing report was created."))
    #expect(errorMessage.contains("standing report worker finished without a readable memo artifact") == false)
    #expect(try await engine.listAnalystStandingReports().isEmpty)
    #expect(try await engine.listAnalystMemos().isEmpty)
    await engine.stop()
}

@Test("Approved source catalog prioritizes app-news-linked sources before generic reference sources")
func approvedSourceCatalogPrioritizesAppNewsLinkedSources() {
    let charter = StandingAnalystBenchSeed().seededCharters(
        now: Date(timeIntervalSince1970: 1_742_640_000)
    ).first(where: { $0.charterId == "bench-sector-technology" })!
    let baselineNews = [
        NewsEvent(
            eventId: "news-app-linked-1",
            source: "rss_ai_sector_feed",
            title: "NVDA demand stays firm",
            url: "https://example.com/app-linked-story",
            publishedAt: Date(timeIntervalSince1970: 1_742_640_000),
            receivedAt: Date(timeIntervalSince1970: 1_742_640_000),
            summary: "Relevant app-owned news baseline item.",
            rawSymbolHints: ["NVDA"],
            tags: ["technology"]
        )
    ]

    let sources = ApprovedAnalystSourceCatalog().sources(for: charter, baselineNews: baselineNews)

    #expect(sources.first?.sourceID == "app-news-linked-news-app-linked-1")
    #expect(sources.contains(where: { $0.sourceID == "stanford-ai-index-report" }))
}

@Test("Sector standing reports propose candidate inclusion ideas when the portfolio has no names in that sector")
func standingAnalystReportJobsHandleNoSectorHoldingsWithCandidateIdeas() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-no-sector-holdings")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "financials-jpm",
                title: "JPM capital markets pipeline improves",
                summary: "Large-cap bank and capital markets momentum stays constructive.",
                symbols: ["JPM"]
            ),
            makeStandingReportNewsEvent(
                id: "financials-nycb",
                title: "NYCB funding repair remains under pressure",
                summary: "Regional-bank funding quality remains a central pressure point.",
                symbols: ["NYCB"]
            )
        ],
        newsStore: newsStore
    )
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "sector-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_610_000),
                        summary: "Allowlisted sector benchmark anchor for standing report tests.",
                        snippet: "Allowlisted sector benchmark anchor for standing report tests.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        }
    )
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-sector-financials"
        })
    )

    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: """
            # Current Portfolio Strategy Brief
            ## Objective
            Balance compounder exposure with selective financials add ideas when balance-sheet quality is strong.
            """,
            objectiveSummary: "Balance compounder exposure with selective financials add ideas when balance-sheet quality is strong.",
            keyThemes: ["Balance-sheet quality", "Selective add ideas"],
            currentRiskPosture: "Keep regional-bank balance-sheet risk bounded.",
            reviewEscalationPosture: "Escalate when sector additions or shorts materially affect current posture.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_610_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_610_000)
        ),
        source: .ui
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000")
        ]
    )
    await engine.store.setWatchlistSymbols(["JPM", "ICE", "NYCB"])

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .engine)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)

    #expect(completed.status == .succeeded)
    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first)

    #expect(report.coveredSymbols.isEmpty)
    #expect(report.portfolioScopeSummary.contains("No current financials holdings"))
    #expect(report.portfolioScopeSummary.contains("JPM"))
    #expect(report.headlineView.isEmpty == false)
    #expect(report.sections.contains(where: { section in
        section.kind == .importantItems && section.items.contains(where: { $0.headline.contains("inclusion candidate") })
    }))
    #expect(report.sections.contains(where: { section in
        section.kind == .longIdeas && section.items.contains(where: { $0.symbol == "JPM" && ($0.conviction ?? 0) >= 6 })
    }))
    #expect(report.sections.contains(where: { section in
        section.kind == .shortIdeas && section.items.contains(where: { $0.symbol == "NYCB" && ($0.conviction ?? 0) >= 5 })
    }))
    await engine.stop()
}

@Test("Macro and International standing reports stay portfolio relevant and support ETF-capable expressions")
func macroInternationalStandingReportJobsProducePortfolioRelevantOverlayOutput() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-macro-overlay")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "macro-rates",
                title: "Fed speakers keep rates restrictive as Treasury yields drift lower",
                summary: "Rate volatility remains central for long-duration growth exposures.",
                symbols: ["TLT"]
            ),
            makeStandingReportNewsEvent(
                id: "macro-dollar",
                title: "Dollar strength pressures emerging-market risk appetite",
                summary: "FX pressure and international breadth remain sensitive to the dollar move.",
                symbols: ["UUP", "EEM"]
            ),
            makeStandingReportNewsEvent(
                id: "macro-geopolitical",
                title: "Gold and oil react to geopolitical risk premium",
                summary: "Commodity and hedge demand remain active as cross-asset volatility rises.",
                symbols: ["GLD"]
            )
        ],
        newsStore: newsStore
    )
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "macro-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) macro benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_625_000),
                        summary: "Allowlisted macro benchmark anchor for standing report tests.",
                        snippet: "Allowlisted macro benchmark anchor for standing report tests.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        }
    )
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-overlay-macro-international"
        })
    )

    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: """
            # Current Portfolio Strategy Brief
            ## Objective
            Own durable compounders while staying alert to rate, currency, and commodity regimes that can change portfolio posture.
            """,
            objectiveSummary: "Own durable compounders while staying alert to rate, currency, and commodity regimes that can change portfolio posture.",
            keyThemes: ["Rate sensitivity", "International breadth", "Commodity discipline"],
            currentRiskPosture: "Use hedges selectively when macro transmission is cleaner than single-name adjustment.",
            reviewEscalationPosture: "Escalate when macro or international context changes what current holdings mean.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_625_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_625_000)
        ),
        source: .ui
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000"),
            Position(symbol: "JPM", qty: "8", side: "long", marketValue: "9000"),
            Position(symbol: "XOM", qty: "6", side: "long", marketValue: "7000")
        ]
    )
    await engine.store.setWatchlistSymbols(["TLT", "GLD", "EFA", "EEM"])

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .engine)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)

    #expect(completed.status == .succeeded)
    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first)
    let memos = try await engine.listAnalystMemos()
    let memo = try #require(memos.first)

    #expect(report.scheduleId == schedule.scheduleId)
    #expect(report.reportingWindowSummary.contains("macro and international review"))
    #expect(report.portfolioScopeSummary.contains("NVDA"))
    #expect(report.portfolioScopeSummary.contains("JPM"))
    #expect(report.portfolioRelevanceSummary.contains("current strategy objective"))
    #expect(report.portfolioRelevanceSummary.contains("Technology"))
    #expect(report.headlineView.contains("generic market recap") == false)
    #expect(report.headlineView.isEmpty == false)
    #expect(report.sections.contains(where: { $0.kind == .macroViews && $0.items.isEmpty == false }))
    #expect(report.sections.contains(where: { section in
        section.kind == .longIdeas && section.items.contains(where: { $0.symbol == "TLT" && ($0.conviction ?? 0) >= 6 })
    }))
    #expect(report.sections.contains(where: { section in
        section.kind == .shortIdeas && section.items.contains(where: { ($0.symbol == "EEM" || $0.symbol == "UUP") && ($0.conviction ?? 0) >= 5 })
    }))
    #expect(report.sections.contains(where: { section in
        section.kind == .etfIdeas && section.items.contains(where: { $0.symbol == "TLT" && $0.detail.contains("ETF") })
    }))
    #expect(report.evidenceReferenceSummary.contains(where: { $0.contains("Portfolio Strategy Brief") }))
    #expect(report.evidenceReferenceSummary.contains(where: { $0.contains("Recent news:") }))
    #expect(memo.evidenceSummary.contains("App-owned news baseline"))
    #expect(memo.recommendedNextStep.isEmpty == false)
    await engine.stop()
}

@Test("Portfolio Risk standing reports stay portfolio specific and surface PM-attention-worthy issues")
func portfolioRiskStandingReportJobsProducePortfolioSpecificRiskOutput() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-portfolio-risk")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(
                id: "risk-nvda",
                title: "NVDA earnings focus sharpens around datacenter concentration",
                summary: "Execution and valuation sensitivity remain central because NVDA is still the largest position.",
                symbols: ["NVDA"]
            ),
            makeStandingReportNewsEvent(
                id: "risk-msft",
                title: "MSFT enterprise technology demand keeps software concentration in focus",
                summary: "Large-cap technology breadth remains supportive, but the sleeve is still crowded.",
                symbols: ["MSFT"]
            ),
            makeStandingReportNewsEvent(
                id: "risk-jpm",
                title: "JPM funding and credit tone stays firm",
                summary: "Financial exposure remains more stable than the technology cluster.",
                symbols: ["JPM"]
            )
        ],
        newsStore: newsStore
    )
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "risk-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) risk benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_640_000),
                        summary: "Allowlisted risk benchmark anchor for standing report tests.",
                        snippet: "Allowlisted risk benchmark anchor for standing report tests.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        }
    )
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-overlay-portfolio-risk"
        })
    )

    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            documentBody: """
            # Current Portfolio Strategy Brief
            ## Objective
            Concentrate in durable compounders while keeping accidental technology crowding deliberate and reviewable.
            """,
            objectiveSummary: "Concentrate in durable compounders while keeping accidental technology crowding deliberate and reviewable.",
            keyThemes: ["Durable compounders", "Technology crowding discipline", "Credit stability"],
            currentRiskPosture: "Keep concentrated growth exposure deliberate and review correlated technology clustering aggressively.",
            reviewEscalationPosture: "Escalate when single-name concentration or sector clustering could change sizing or hedge posture.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_640_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_640_000)
        ),
        source: .ui
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "20", side: "long", marketValue: "28000"),
            Position(symbol: "MSFT", qty: "10", side: "long", marketValue: "18000"),
            Position(symbol: "JPM", qty: "8", side: "long", marketValue: "9000")
        ]
    )
    await engine.store.setWatchlistSymbols(["AVGO", "META", "JPM"])

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .engine)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)

    #expect(completed.status == .succeeded)
    let reports = try await engine.listAnalystStandingReports()
    let report = try #require(reports.first)
    let memos = try await engine.listAnalystMemos()
    let memo = try #require(memos.first)

    #expect(report.scheduleId == schedule.scheduleId)
    #expect(report.reportingWindowSummary.contains("portfolio-risk review"))
    #expect(report.portfolioScopeSummary.contains("NVDA"))
    #expect(report.portfolioScopeSummary.contains("Technology"))
    #expect(report.coveredSymbols == ["NVDA", "MSFT", "JPM"])
    #expect(report.headlineView.isEmpty == false)
    #expect(report.portfolioRelevanceSummary.contains("current strategy objective"))
    #expect(report.sections.contains(where: { $0.kind == .riskIssues && $0.items.isEmpty == false }))
    #expect(report.sections.contains(where: { $0.kind == .importantItems && $0.items.isEmpty == false }))
    #expect(report.sections.contains(where: { $0.kind == .materialDevelopments && $0.items.isEmpty == false }))
    #expect(report.sections.contains(where: { $0.kind == .followUp && $0.items.count >= 2 }))
    #expect(report.sections.contains(where: { $0.kind == .macroViews }) == false)
    #expect(report.sections.contains(where: { $0.kind == .etfIdeas }) == false)
    #expect(report.sections.contains(where: { section in
        section.kind == .riskIssues && section.items.contains(where: { $0.headline.contains("concentration") || $0.headline.contains("Sector clustering") || $0.headline.contains("Downside scenario") })
    }))
    #expect(report.evidenceReferenceSummary.contains(where: { $0.contains("Portfolio Strategy Brief") }))
    #expect(report.evidenceReferenceSummary.contains(where: { $0.contains("Current holdings snapshot") }))
    #expect(report.evidenceReferenceSummary.contains(where: { $0.contains("Recent news:") }))
    #expect(memo.evidenceSummary.contains("App-owned news baseline"))
    #expect(memo.recommendedNextStep.isEmpty == false)
    await engine.stop()
}

@Test("Portfolio Risk standing reports stay silent when no current portfolio exists")
func portfolioRiskStandingReportJobsSuppressWhenNoPortfolioExists() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-portfolio-risk-no-portfolio")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "risk-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) risk benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_641_000),
                        summary: "Allowlisted risk benchmark anchor for standing report tests.",
                        snippet: "Allowlisted risk benchmark anchor for standing report tests.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        }
    )
    let schedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-overlay-portfolio-risk"
        })
    )

    _ = try await engine.upsertSchedule(schedule, source: .engine)
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            objectiveSummary: "Maintain discipline around concentration and downside if positions exist.",
            keyThemes: ["Risk discipline"],
            currentRiskPosture: "Stay explicit when there is no live book.",
            reviewEscalationPosture: "Do not fabricate a standing risk memo without a portfolio.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_641_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_641_000)
        ),
        source: .ui
    )

    let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .engine)
    let runningJobID = try #require(dispatched.runningJobId)
    let completed = try await waitForStandingReportJob(engine: engine, jobID: runningJobID)

    #expect(completed.status == .succeeded)
    let result = try #require(completed.result?.objectValue)
    #expect(result["reportCreated"]?.boolValue == false)
    #expect(result["summary"]?.stringValue?.contains("skipped Portfolio Risk Analyst") == true)
    #expect(try await engine.listAnalystStandingReports().isEmpty)
    #expect(try await engine.listAnalystMemos().isEmpty)
    await engine.stop()
}

@Test("Six sector analysts plus macro and risk overlays generate structured standing reports with bounded role-specific behavior")
func sixSectorAnalystsMacroAndRiskGenerateStructuredStandingReportsWithDistinctBehavior() async throws {
    let tempRoot = makeStandingReportTempDirectory(name: "standing-report-six-sector-bench")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let newsStore = NewsStore(
        newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)
    )
    try await appendStandingReportNews(
        [
            makeStandingReportNewsEvent(id: "tech", title: "NVDA AI datacenter demand broadens", summary: "Technology infrastructure demand stays firm.", symbols: ["NVDA"]),
            makeStandingReportNewsEvent(id: "healthcare", title: "LLY obesity demand remains strong", summary: "Healthcare therapeutics leadership remains in focus.", symbols: ["LLY"]),
            makeStandingReportNewsEvent(id: "consumer", title: "COST pricing and traffic stay resilient", summary: "Consumer quality demand remains stable.", symbols: ["COST"]),
            makeStandingReportNewsEvent(id: "industrials", title: "GE aerospace backlog remains firm", summary: "Industrial backlog quality stays supportive.", symbols: ["GE"]),
            makeStandingReportNewsEvent(id: "financials", title: "JPM balance-sheet strength stays in focus", summary: "Large-cap financial quality remains supportive.", symbols: ["JPM"]),
            makeStandingReportNewsEvent(id: "energy", title: "XOM commodity discipline remains central", summary: "Energy cash generation remains in focus.", symbols: ["XOM"]),
            makeStandingReportNewsEvent(id: "macro-rates", title: "Treasury yields ease as Fed path stays in focus", summary: "Rates transmission remains central for growth and financial exposures.", symbols: ["TLT"]),
            makeStandingReportNewsEvent(id: "macro-international", title: "Dollar pressure keeps emerging-market breadth under review", summary: "International breadth remains sensitive to dollar and policy divergence.", symbols: ["EEM", "UUP"])
        ],
        newsStore: newsStore
    )
    let engine = makeStandingReportEngine(
        tempRoot: tempRoot,
        newsStore: newsStore,
        externalEvidenceProvider: StubStandingReportExternalEvidenceProvider { charter in
            AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "sector-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) benchmark overview",
                        observedAt: Date(timeIntervalSince1970: 1_742_620_000),
                        summary: "Allowlisted standing-report benchmark anchor for tests.",
                        snippet: "Allowlisted standing-report benchmark anchor for tests.",
                        provenanceNote: "approved_test_source"
                    )
                ],
                issues: []
            )
        }
    )

    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            Position(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000"),
            Position(symbol: "LLY", qty: "10", side: "long", marketValue: "12000"),
            Position(symbol: "COST", qty: "5", side: "long", marketValue: "4000"),
            Position(symbol: "GE", qty: "8", side: "long", marketValue: "6000"),
            Position(symbol: "JPM", qty: "6", side: "long", marketValue: "5000"),
            Position(symbol: "XOM", qty: "9", side: "long", marketValue: "7000")
        ]
    )
    await engine.store.setWatchlistSymbols(["AVGO", "VRTX", "BKNG", "ETN", "ICE", "SLB", "TLT", "GLD", "EFA", "EEM"])
    _ = try await engine.upsertPortfolioStrategyBrief(
        PortfolioStrategyBrief(
            title: "Current Portfolio Strategy Brief",
            objectiveSummary: "Own durable sector leaders while staying aware of rate, currency, and commodity regimes that change what those holdings mean.",
            keyThemes: ["Durable leaders", "Pressure-test weak balance sheets", "Rate sensitivity", "Commodity discipline"],
            currentRiskPosture: "Keep concentration in sector leaders deliberate rather than accidental.",
            reviewEscalationPosture: "Escalate when sector ranking changes current PM attention priorities.",
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: Date(timeIntervalSince1970: 1_742_620_000),
            updatedAt: Date(timeIntervalSince1970: 1_742_620_000)
        ),
        source: .ui
    )

    let sectorScheduleIDs = [
        "standing-report-bench-sector-technology",
        "standing-report-bench-sector-healthcare-biotech",
        "standing-report-bench-sector-consumer",
        "standing-report-bench-sector-industrials",
        "standing-report-bench-sector-financials",
        "standing-report-bench-sector-energy-materials"
    ]
    for scheduleID in sectorScheduleIDs {
        let schedule = try #require(
            makeStandingAnalystReportDefaultSchedules().first(where: { $0.scheduleId == scheduleID })
        )
        _ = try await engine.upsertSchedule(schedule, source: .engine)
        let dispatched = try await engine.runScheduleNow(id: schedule.scheduleId, source: .engine)
        let jobID = try #require(dispatched.runningJobId)
        let completed = try await waitForStandingReportJob(engine: engine, jobID: jobID)
        #expect(completed.status == .succeeded)
    }

    let reports = try await engine.listAnalystStandingReports()
    #expect(reports.count == 6)
    #expect(reports.allSatisfy { report in
        report.sections.contains(where: { $0.kind == .longIdeas && $0.items.isEmpty == false })
            && report.sections.contains(where: { $0.kind == .shortIdeas && $0.items.isEmpty == false })
            && report.sections.contains(where: { $0.kind == .materialDevelopments })
    })

    let macroSchedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-overlay-macro-international"
        })
    )
    _ = try await engine.upsertSchedule(macroSchedule, source: .engine)
    let macroDispatched = try await engine.runScheduleNow(id: macroSchedule.scheduleId, source: .engine)
    let macroJobID = try #require(macroDispatched.runningJobId)
    let macroCompleted = try await waitForStandingReportJob(engine: engine, jobID: macroJobID)
    #expect(macroCompleted.status == .succeeded)

    let refreshed = try await engine.listAnalystStandingReports()
    let macroReport = try #require(refreshed.first(where: { $0.scheduleId == macroSchedule.scheduleId }))
    #expect(macroReport.sections.contains(where: { $0.kind == .macroViews }))
    #expect(macroReport.sections.contains(where: { $0.kind == .longIdeas && $0.items.isEmpty == false }))
    #expect(macroReport.sections.contains(where: { $0.kind == .shortIdeas && $0.items.isEmpty == false }))
    #expect(macroReport.sections.contains(where: { $0.kind == .etfIdeas && $0.items.isEmpty == false }))
    #expect(macroReport.portfolioRelevanceSummary.contains("current strategy objective"))

    let riskSchedule = try #require(
        makeStandingAnalystReportDefaultSchedules().first(where: {
            $0.scheduleId == "standing-report-bench-overlay-portfolio-risk"
        })
    )
    _ = try await engine.upsertSchedule(riskSchedule, source: .engine)
    let riskDispatched = try await engine.runScheduleNow(id: riskSchedule.scheduleId, source: .engine)
    let riskJobID = try #require(riskDispatched.runningJobId)
    let riskCompleted = try await waitForStandingReportJob(engine: engine, jobID: riskJobID)
    #expect(riskCompleted.status == .succeeded)

    let finalReports = try await engine.listAnalystStandingReports()
    let riskReport = try #require(finalReports.first(where: { $0.scheduleId == riskSchedule.scheduleId }))
    #expect(riskReport.reportingWindowSummary.contains("portfolio-risk review"))
    #expect(riskReport.sections.contains(where: { $0.kind == .riskIssues && $0.items.isEmpty == false }))
    #expect(riskReport.sections.contains(where: { $0.kind == .importantItems && $0.items.isEmpty == false }))
    #expect(riskReport.sections.contains(where: { $0.kind == .followUp && $0.items.isEmpty == false }))
    #expect(riskReport.sections.contains(where: { $0.kind == .etfIdeas }) == false)
    #expect(riskReport.sections.contains(where: { $0.kind == .macroViews }) == false)
    await engine.stop()
}

@Test("Populated sector standing reports remain readable in PM Inbox presentation")
func populatedSectorStandingReportPresentationRemainsReadable() throws {
    let now = Date(timeIntervalSince1970: 1_742_630_000)
    let charter = AnalystCharter(
        charterId: "bench-sector-technology",
        analystId: "bench-sector-technology-analyst",
        title: "Technology Analyst",
        coverageScope: "Technology holdings and watchlist names.",
        strategyFamily: "standing sector bench",
        summary: "Standing technology charter.",
        benchRole: .sector,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-tech-standing",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Technology Analyst Standing Report",
        executiveSummary: "Weekly technology standing review covered NVDA and surfaced AVGO and INTC as the clearest next follow-ups.",
        currentView: "Current technology exposure (NVDA) remains central, with AVGO and INTC as the most actionable next candidates.",
        evidenceSummary: "Grounded on the Portfolio Strategy Brief, current holdings, reporting-window news, and one charter-governed sector source.",
        uncertaintySummary: "Coverage remains bounded to the current sector map and charter-governed evidence.",
        recommendedNextStep: "PM should review whether AVGO merits deeper follow-up before the next standing cycle.",
        confidence: 0.8,
        createdAt: now,
        updatedAt: now
    )
    let report = AnalystStandingReport(
        reportId: "standing-report-tech",
        analystId: charter.analystId,
        charterId: charter.charterId,
        scheduleId: "standing-report-bench-sector-technology",
        memoId: memo.memoId,
        title: memo.title,
        summary: memo.executiveSummary,
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly technology review covering 2025-03-25T00:00:00Z through 2025-04-01T00:00:00Z with 3 relevant news item(s) and 1 charter-governed web source(s).",
        portfolioScopeSummary: "Current technology holdings in scope: NVDA.",
        coveredSymbols: ["NVDA"],
        headlineView: memo.currentView,
        portfolioRelevanceSummary: "Grounded on the current strategy objective and technology infrastructure theme. Current technology exposure includes NVDA.",
        openQuestions: ["Does AVGO add to current exposure or replace it?"],
        evidenceReferenceSummary: ["Portfolio Strategy Brief: Current Portfolio Strategy Brief", "Charter-governed web source: Technology Analyst benchmark overview"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "material",
                kind: .materialDevelopments,
                summary: "Material technology developments are separated from lower-signal flow.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "material-nvda",
                        headline: "NVDA datacenter demand stays firm",
                        detail: "technology infrastructure demand remains durable.",
                        symbol: "NVDA",
                        stance: .neutral,
                        priority: 8
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "longs",
                kind: .longIdeas,
                summary: "Best long candidates.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "long-avgo",
                        headline: "AVGO",
                        detail: "Infrastructure leverage and software mix fit the current brief.",
                        symbol: "AVGO",
                        stance: .long,
                        conviction: 8
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "shorts",
                kind: .shortIdeas,
                summary: "Best short-side pressure tests.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "short-intc",
                        headline: "INTC",
                        detail: "Execution risk and capital intensity remain the clearest short-side pressure test.",
                        symbol: "INTC",
                        stance: .short,
                        conviction: 7
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    let presentation = try #require(
        makeStandingAnalystReportReviewPresentations(
            reports: [report],
            memos: [memo],
            charters: [charter]
        ).first
    )

    #expect(presentation.reportKindLabel == "Standing Recurring Report")
    #expect(presentation.analystTitle == "Technology Analyst")
    #expect(presentation.coveredSymbolsSummary == "NVDA")
    #expect(presentation.detailSections.map(\.title).contains("Material Developments"))
    #expect(presentation.detailSections.map(\.title).contains("Best Long Candidates"))
    #expect(presentation.detailSections.map(\.title).contains("Best Short Candidates"))
    #expect(presentation.detailSections.contains(where: { section in
        section.title == "Best Long Candidates" && section.items.first?.scoreSummary == "Conviction 8/10"
    }))
}

@Test("Standing analyst report presentation strips raw HTML into readable PM-facing text")
func standingAnalystReportPresentationSanitizesHTML() throws {
    let now = Date(timeIntervalSince1970: 1_742_631_000)
    let charter = AnalystCharter(
        charterId: "bench-sector-industrials",
        analystId: "bench-sector-industrials-analyst",
        title: "Industrials Analyst",
        coverageScope: "Industrials",
        strategyFamily: "standing sector bench",
        summary: "Standing industrials charter.",
        benchRole: .sector,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-industrials-html",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Industrials Analyst Standing Report",
        executiveSummary: "<div><strong>Readable</strong> industrials review &amp; follow-up.</div>",
        currentView: "<p>CAT matters now.<br>GE looks less urgent.</p>",
        evidenceSummary: "Grounded on PM inputs.",
        uncertaintySummary: "Bounded.",
        recommendedNextStep: "<p>PM should review CAT first.</p>",
        confidence: 0.7,
        createdAt: now,
        updatedAt: now
    )
    let report = AnalystStandingReport(
        reportId: "standing-report-industrials-html",
        analystId: charter.analystId,
        charterId: charter.charterId,
        scheduleId: "standing-report-bench-sector-industrials",
        memoId: memo.memoId,
        title: "<h1>Industrials Analyst Standing Report</h1>",
        summary: "<html><body><p>Readable summary</p></body></html>",
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "<p>Weekly industrials review.</p>",
        portfolioScopeSummary: "<div>Current industrial holdings: CAT.</div>",
        coveredSymbols: ["CAT"],
        headlineView: "<div><span>CAT matters now.</span><span> GE looks less urgent.</span></div>",
        portfolioRelevanceSummary: "<p>Industrials posture stays tied to current construction.</p>",
        openQuestions: ["<p>Does CAT still rank first?</p>"],
        evidenceReferenceSummary: ["<a href=\"https://example.com\">Charter-governed source</a>"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "material-html",
                kind: .materialDevelopments,
                summary: "<p>Material items only.</p>",
                items: [
                    AnalystStandingReportItem(
                        itemId: "html-item",
                        headline: "<strong>CAT backlog remains firm</strong>",
                        detail: "<div>Backlog and pricing remain supportive.<br><em>No raw tags should leak.</em></div>",
                        symbol: "CAT",
                        stance: .neutral,
                        priority: 7
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    let presentation = try #require(
        makeStandingAnalystReportReviewPresentations(
            reports: [report],
            memos: [memo],
            charters: [charter]
        ).first
    )

    #expect(presentation.title == "Industrials Analyst Standing Report")
    #expect(presentation.executiveSummary == "Readable industrials review & follow-up.")
    #expect(presentation.reportingWindowSummary == "Weekly industrials review.")
    #expect(presentation.headlineView == "CAT matters now. GE looks less urgent.")
    #expect(presentation.openQuestions == ["Does CAT still rank first?"])
    #expect(presentation.evidenceReferenceSummary == ["Charter-governed source"])
    #expect(presentation.detailSections.first?.items.first?.headline == "CAT backlog remains firm")
    #expect(presentation.detailSections.first?.items.first?.detail == "Backlog and pricing remain supportive.\nNo raw tags should leak.")
    #expect(presentation.executiveSummary.contains("<") == false)
    #expect(presentation.detailSections.first?.items.first?.detail.contains("<") == false)
}

@Test("Populated Macro and International standing reports remain readable in PM Inbox presentation")
func populatedMacroStandingReportPresentationRemainsReadable() throws {
    let now = Date(timeIntervalSince1970: 1_742_635_000)
    let charter = AnalystCharter(
        charterId: "bench-overlay-macro-international",
        analystId: "bench-overlay-macro-international-analyst",
        title: "Macro and International Analyst",
        coverageScope: "Macro, international, cross-asset, and ETF-aware overlay work.",
        strategyFamily: "standing overlay bench",
        summary: "Standing macro charter.",
        benchRole: .overlay,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-macro-standing",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Macro and International Analyst Standing Report",
        executiveSummary: "Weekly macro review tied current portfolio posture to TLT, EEM, and GLD as the clearest overlay expressions.",
        currentView: "The current portfolio remains sensitive to rates, dollar strength, and commodity volatility rather than a generic market recap.",
        evidenceSummary: "Grounded on the Portfolio Strategy Brief, current holdings, reporting-window macro news, and one charter-governed macro source.",
        uncertaintySummary: "The overlay remains bounded to rates, FX, commodity, and international-breadth themes.",
        recommendedNextStep: "PM should review whether TLT is the cleanest overlay expression before the next standing cycle.",
        confidence: 0.8,
        createdAt: now,
        updatedAt: now
    )
    let report = AnalystStandingReport(
        reportId: "standing-report-macro",
        analystId: charter.analystId,
        charterId: charter.charterId,
        scheduleId: "standing-report-bench-overlay-macro-international",
        memoId: memo.memoId,
        title: memo.title,
        summary: memo.executiveSummary,
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly macro and international review covering 2025-03-25T00:00:00Z through 2025-04-01T00:00:00Z with 3 relevant news item(s) and 1 charter-governed web source(s).",
        portfolioScopeSummary: "Current portfolio names in scope: NVDA, JPM, XOM. Current holdings span sectors: Technology, Financials, Energy/Materials.",
        coveredSymbols: ["NVDA", "JPM", "XOM"],
        headlineView: memo.currentView,
        portfolioRelevanceSummary: "Grounded on the current strategy objective and rate-sensitivity theme. Holdings map into Technology, Financials, and Energy/Materials, so macro transmission stays tied to current posture.",
        openQuestions: ["Is TLT the cleaner expression than adjusting a single-name holding?"],
        evidenceReferenceSummary: ["Portfolio Strategy Brief: Current Portfolio Strategy Brief", "Charter-governed web source: Macro and International Analyst macro benchmark overview"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "macro-views",
                kind: .macroViews,
                summary: "Transmission mechanisms that matter now.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "macro-rates",
                        headline: "Rates and duration transmission",
                        detail: "Cooling yields matter because they change the meaning of current growth and financial exposure.",
                        stance: .macro,
                        priority: 8
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "longs",
                kind: .longIdeas,
                summary: "Best long-side macro expressions.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "long-tlt",
                        headline: "TLT duration relief expression",
                        detail: "TLT isolates the rates view better than adding another long-duration single-name.",
                        symbol: "TLT",
                        stance: .long,
                        conviction: 8
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "etfs",
                kind: .etfIdeas,
                summary: "ETF expressions where appropriate.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "etf-gld",
                        headline: "GLD inflation or geopolitical hedge",
                        detail: "GLD is the cleaner hedge than choosing one miner.",
                        symbol: "GLD",
                        stance: .etf,
                        conviction: 7
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    let presentation = try #require(
        makeStandingAnalystReportReviewPresentations(
            reports: [report],
            memos: [memo],
            charters: [charter]
        ).first
    )

    #expect(presentation.reportKindLabel == "Standing Recurring Report")
    #expect(presentation.analystTitle == "Macro and International Analyst")
    #expect(presentation.coveredSymbolsSummary == "NVDA, JPM, XOM")
    #expect(presentation.detailSections.map(\.title).contains("Macro And International Views"))
    #expect(presentation.detailSections.map(\.title).contains("Best Long Candidates"))
    #expect(presentation.detailSections.map(\.title).contains("ETF Or Cross-Asset Ideas"))
    #expect(presentation.detailSections.contains(where: { section in
        section.title == "ETF Or Cross-Asset Ideas" && section.items.first?.scoreSummary == "Conviction 7/10"
    }))
}

@Test("Populated Portfolio Risk standing reports remain readable in PM Inbox presentation and distinct from ad hoc task output")
func populatedPortfolioRiskStandingReportPresentationStaysDistinctFromAdHocTaskOutput() throws {
    let now = Date(timeIntervalSince1970: 1_742_600_000)
    let charter = AnalystCharter(
        charterId: "bench-overlay-portfolio-risk",
        analystId: "bench-overlay-portfolio-risk-analyst",
        title: "Portfolio Risk Analyst",
        coverageScope: "Portfolio risk",
        strategyFamily: "standing overlay bench",
        summary: "Standing risk charter.",
        benchRole: .overlay,
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-standing-risk",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Portfolio Risk Analyst Standing Report",
        executiveSummary: "Weekly standing report delivered for Portfolio Risk Analyst with concentration and clustering issues ranked for PM attention.",
        currentView: "NVDA concentration and Technology clustering matter more than lower-signal monitoring noise in the current portfolio.",
        evidenceSummary: "Grounded on the Portfolio Strategy Brief, current holdings, risk-relevant reporting-window news, and one charter-governed risk source.",
        uncertaintySummary: "The overlay remains bounded to concentration, clustering, vulnerability, and downside-scenario analysis rather than a full risk engine.",
        recommendedNextStep: "PM should review whether NVDA sizing or Technology cluster monitoring needs to change before the next standing cycle.",
        confidence: 0.8,
        createdAt: now,
        updatedAt: now
    )
    let report = AnalystStandingReport(
        reportId: "standing-report-risk",
        analystId: charter.analystId,
        charterId: charter.charterId,
        scheduleId: "standing-report-bench-overlay-portfolio-risk",
        memoId: memo.memoId,
        title: memo.title,
        summary: memo.executiveSummary,
        cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
        reportingWindowSummary: "Weekly portfolio-risk review covering 2025-03-25T00:00:00Z through 2025-04-01T00:00:00Z with 2 materially relevant news item(s) and 1 charter-governed web source(s).",
        portfolioScopeSummary: "Current portfolio risk scope is anchored on holdings NVDA 56%, MSFT 28%, JPM 16%. Sector clustering in scope: Technology 84%, Financials 16%.",
        coveredSymbols: ["NVDA", "MSFT", "JPM"],
        headlineView: memo.currentView,
        portfolioRelevanceSummary: "Grounded on the current strategy objective and technology crowding discipline. Largest single-name exposure is NVDA at 56%. Largest sector cluster is Technology at 84%.",
        openQuestions: ["Does NVDA sizing still fit the intended concentration posture?", "Should Technology be treated as a cluster that needs explicit hedge review?"],
        evidenceReferenceSummary: ["Portfolio Strategy Brief: Current Portfolio Strategy Brief", "Current holdings snapshot: NVDA 56%, MSFT 28%, JPM 16%", "Charter-governed web source: Portfolio Risk Analyst risk benchmark overview"],
        sections: [
            AnalystStandingReportSection(
                sectionId: "important-items",
                kind: .importantItems,
                summary: "The top PM-attention-worthy risk issues are separated from lower-signal monitoring points.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "important-nvda",
                        headline: "Single-name concentration: NVDA",
                        detail: "NVDA represents 56% of current portfolio exposure, making it a first-order PM risk review item rather than a background holding.",
                        symbol: "NVDA",
                        stance: .risk,
                        priority: 9
                    )
                ]
            ),
            AnalystStandingReportSection(
                sectionId: "risk-issues",
                kind: .riskIssues,
                summary: "Concentration, clustering, vulnerability, and downside scenarios are ranked for PM review.",
                items: [
                    AnalystStandingReportItem(
                        itemId: "risk-item",
                        headline: "Single-name concentration: NVDA",
                        detail: "NVDA represents 56% of current portfolio exposure, making it a first-order PM risk review item rather than a background holding.",
                        symbol: "NVDA",
                        stance: .risk,
                        priority: 9
                    ),
                    AnalystStandingReportItem(
                        itemId: "risk-cluster",
                        headline: "Sector clustering: Technology",
                        detail: "Technology accounts for 84% of current portfolio exposure, so correlated downside could matter more than any single headline in that sleeve.",
                        stance: .risk,
                        priority: 8
                    )
                ]
            )
        ],
        deliveredToPMInboxAt: now,
        createdAt: now,
        updatedAt: now
    )

    let presentations = makeStandingAnalystReportReviewPresentations(
        reports: [report],
        memos: [memo],
        charters: [charter]
    )
    let presentation = try #require(presentations.first)

    #expect(presentation.reportKindLabel == "Standing Recurring Report")
    #expect(presentation.deliverySummary == "Pending PM review in PM Inbox")
    #expect(presentation.analystTitle == "Portfolio Risk Analyst")
    #expect(presentation.executiveSummary.contains("concentration and clustering"))
    #expect(presentation.recommendedNextStep.contains("NVDA sizing") || presentation.recommendedNextStep.contains("Technology cluster"))
    #expect(presentation.reportingWindowSummary.contains("portfolio-risk review"))
    #expect(presentation.portfolioScopeSummary.contains("NVDA"))
    #expect(presentation.coveredSymbolsSummary == "NVDA, MSFT, JPM")
    #expect(presentation.detailSections.map(\.title).contains("Risk Issues"))
    #expect(presentation.detailSections.map(\.title).contains("What Looks Important"))
    #expect(presentation.detailSections.contains(where: { section in
        section.title == "Risk Issues" && section.items.first?.scoreSummary == "Priority 9/10"
    }))
}

private func makeStandingReportTempDirectory(name: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private struct StubStandingReportExternalEvidenceProvider: ExternalAnalystEvidenceProviding {
    let resolve: @Sendable (AnalystCharter) -> AnalystExternalEvidenceFetchResult

    func fetchEvidence(
        for charter: AnalystCharter,
        task: AnalystTask,
        baselineNews: [NewsEvent],
        plannedSources: [ApprovedAnalystSourceDefinition]
    ) async -> AnalystExternalEvidenceFetchResult {
        _ = task
        _ = baselineNews
        _ = plannedSources
        return resolve(charter)
    }
}

private struct StubOpenAIKeyProvider: OpenAIKeyStatusProviding {
    let configured: Bool
    let value: String?

    func isConfigured() -> Bool { configured }
    func apiKey() -> String? { value }
}

private actor LaunchRecorder {
    private(set) var requests: [AnalystWorkerLaunchRequest] = []

    func record(_ request: AnalystWorkerLaunchRequest) {
        requests.append(request)
    }

    func all() -> [AnalystWorkerLaunchRequest] {
        requests
    }
}

private struct StubLauncher: AnalystWorkerLaunching {
    let recorder: LaunchRecorder
    let result: AnalystWorkerLaunchResult

    func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
        await recorder.record(request)
        return result
    }
}

private struct PersistingStubLauncher: AnalystWorkerLaunching {
    let memoStore: AnalystMemoStore
    let now: Date

    func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
        let runtimeProvenance = AnalystRuntimeProvenance(
            intendedPolicy: request.intendedRuntimePolicy,
            actualRuntimeIdentifier: "deterministic_local[\(request.intendedRuntimePolicy?.runtimeIdentifier ?? "deterministic_local")]",
            actualReasoningMode: request.intendedRuntimePolicy?.reasoningMode,
            launchedAt: now
        )
        let memoID = "memo-\((request.taskId ?? request.charterId).replacingOccurrences(of: " ", with: "-"))"
        let memo = AnalystMemo(
            memoId: memoID,
            analystId: request.charterId + "-analyst",
            charterId: request.charterId,
            taskId: request.taskId,
            findingId: "finding-\(request.charterId)",
            title: "Stub Standing Report",
            executiveSummary: "Stub standing summary for \(request.charterId).",
            currentView: "Stub standing current view for \(request.charterId).",
            evidenceSummary: "App-owned news baseline reviewed before any supplemental outside research.",
            uncertaintySummary: "Stub standing uncertainty summary.",
            recommendedNextStep: "Keep monitoring the standing cycle.",
            confidence: 0.55,
            runtimeProvenance: runtimeProvenance,
            createdAt: now,
            updatedAt: now
        )
        _ = try await memoStore.upsert(memo)
        return AnalystWorkerLaunchResult(
            openAIKeyConfigured: request.intendedRuntimePolicy != nil,
            usedOpenAI: false,
            charterId: request.charterId,
            taskId: request.taskId,
            memoId: memo.memoId,
            memoTitle: memo.title,
            findingId: memo.findingId,
            findingTitle: "Stub standing finding",
            draftedSignalId: nil,
            runtimeProvenance: runtimeProvenance,
            synthesisStatus: "deterministic_local",
            summary: "stub worker completed",
            outputExcerpt: memo.executiveSummary
        )
    }
}

private func makeStandingReportEngine(
    tempRoot: URL,
    newsStore: NewsStore,
    externalEvidenceProvider: any ExternalAnalystEvidenceProviding,
    openAIKeyStatusProvider: any OpenAIKeyStatusProviding = StubOpenAIKeyProvider(configured: false, value: nil),
    agentSkillStore: AgentSkillStore? = nil,
    standingBenchAnalystRuntimeSettingsStore: StandingBenchAnalystRuntimeSettingsStore? = nil,
    recentNewsAnalystRuntimeSettingsStore: RecentNewsAnalystRuntimeSettingsStore? = nil,
    analystWorkerLauncher: (any AnalystWorkerLaunching)? = nil
) -> Engine {
    let fixedNow = Date(timeIntervalSince1970: 1_742_640_100)
    let scheduleStore = ScheduleStore(
        fileURL: tempRoot.appendingPathComponent("schedules.json", isDirectory: false)
    )
    let jobStore = JobStore(
        jobsDirectory: tempRoot.appendingPathComponent("jobs", isDirectory: true)
    )
    let charterStore = AnalystCharterStore(
        chartersDirectory: tempRoot.appendingPathComponent("charters", isDirectory: true)
    )
    let delegationStore = PMDelegationStore(
        delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true)
    )
    let memoStore = AnalystMemoStore(
        memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true)
    )
    let standingReportStore = AnalystStandingReportStore(
        reportsDirectory: tempRoot.appendingPathComponent("standing-reports", isDirectory: true)
    )
    let strategyBriefStore = PortfolioStrategyBriefStore(
        fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    )
    let resolvedStandingBenchRuntimeSettingsStore =
        standingBenchAnalystRuntimeSettingsStore
        ?? StandingBenchAnalystRuntimeSettingsStore(
            fileURL: tempRoot.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)
        )
    let resolvedRecentNewsRuntimeSettingsStore =
        recentNewsAnalystRuntimeSettingsStore
        ?? RecentNewsAnalystRuntimeSettingsStore(
            fileURL: tempRoot.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false)
        )
    let resolvedLauncher = analystWorkerLauncher ?? PersistingStubLauncher(
        memoStore: memoStore,
        now: fixedNow
    )
    return Engine(
        newsStore: newsStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        agentSkillStore: agentSkillStore ?? AgentSkillStore(
            skillsDirectory: tempRoot.appendingPathComponent("agent-skills", isDirectory: true),
            now: { fixedNow }
        ),
        pmDelegationStore: delegationStore,
        analystCharterStore: charterStore,
        analystMemoStore: memoStore,
        analystStandingReportStore: standingReportStore,
        recentNewsAnalystRuntimeSettingsStore: resolvedRecentNewsRuntimeSettingsStore,
        standingBenchAnalystRuntimeSettingsStore: resolvedStandingBenchRuntimeSettingsStore,
        openAIKeyStatusProvider: openAIKeyStatusProvider,
        analystExternalEvidenceProvider: externalEvidenceProvider,
        analystWorkerLauncher: resolvedLauncher,
        jobStore: jobStore,
        scheduleStore: scheduleStore,
        now: { fixedNow.timeIntervalSince1970 },
        nowDate: { fixedNow },
        replaySleep: { _ in }
    )
}

private func appendStandingReportNews(
    _ events: [NewsEvent],
    newsStore: NewsStore
) async throws {
    _ = try await newsStore.append(events)
}

private func makeStandingReportNewsEvent(
    id: String,
    title: String,
    summary: String,
    symbols: [String],
    publishedAt: Date = Date(timeIntervalSince1970: 1_742_600_000)
) -> NewsEvent {
    NewsEvent(
        eventId: id,
        source: "unit_test",
        title: title,
        url: "https://example.com/\(id)",
        publishedAt: publishedAt,
        receivedAt: publishedAt,
        summary: summary,
        rawSymbolHints: symbols,
        tags: ["standing_report_test"]
    )
}

private func waitForStandingReportJob(
    engine: Engine,
    jobID: String
) async throws -> JobRecord {
    for _ in 0..<80 {
        let job = try await engine.getJob(jobID: jobID)
        switch job.status {
        case .queued, .running:
            try? await Task.sleep(nanoseconds: 50_000_000)
        default:
            return job
        }
    }
    return try await engine.getJob(jobID: jobID)
}
