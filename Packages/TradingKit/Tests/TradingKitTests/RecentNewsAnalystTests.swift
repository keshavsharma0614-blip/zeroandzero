import Foundation
import Testing
@testable import TradingKit

@Test("Recent news materiality gate stays quiet for non-material portfolio news")
func recentNewsMaterialityGateStaysQuiet() {
    let now = Date(timeIntervalSince1970: 1_720_000_000)
    let evaluation = RecentNewsMaterialityEvaluator.evaluate(
        recentNews: [
            NewsEvent(
                eventId: "news-quiet",
                source: "rss_marketwatch",
                title: "Apple opens a new office in Austin",
                url: "https://example.com/austin",
                publishedAt: now.addingTimeInterval(-300),
                receivedAt: now.addingTimeInterval(-295),
                summary: "A facilities update about office space and staffing logistics only.",
                rawSymbolHints: ["AAPL"],
                tags: ["corporate"],
                payloadVersion: 1
            )
        ],
        positions: [makePositionRow(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")],
        watchlistSymbols: ["AAPL"],
        strategyBrief: nil
    )

    #expect(evaluation.isMaterial == false)
    #expect(evaluation.summary.contains("no_material_impact"))
}

@Test("Recent news materiality gate flags held symbol SEC and guidance cluster")
func recentNewsMaterialityGateFlagsMaterialCluster() {
    let now = Date(timeIntervalSince1970: 1_720_000_500)
    let evaluation = RecentNewsMaterialityEvaluator.evaluate(
        recentNews: [
            NewsEvent(
                eventId: "news-material",
                source: "sec_edgar",
                title: "Apple Inc. filed 8-K",
                url: "https://www.sec.gov/example",
                publishedAt: now.addingTimeInterval(-120),
                receivedAt: now.addingTimeInterval(-118),
                summary: "Guidance update and restructuring details for the current quarter.",
                rawSymbolHints: ["AAPL"],
                tags: ["sec", "8-k"],
                payloadVersion: 1
            )
        ],
        positions: [makePositionRow(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")],
        watchlistSymbols: ["AAPL", "MSFT"],
        strategyBrief: nil
    )

    #expect(evaluation.isMaterial == true)
    #expect(evaluation.impactedHeldSymbols == ["AAPL"])
    #expect(evaluation.candidateMatches.count == 1)
    #expect(evaluation.candidateMatches[0].reasons.contains(where: { $0.contains("high_signal_sec_filing") }))
}

@Test("Recent news materiality clusters repeated same-meaning pickup into one coherent event view")
func recentNewsMaterialityClustersRepeatedPickup() {
    let now = Date(timeIntervalSince1970: 1_720_000_700)
    let evaluation = RecentNewsMaterialityEvaluator.evaluate(
        recentNews: [
            NewsEvent(
                eventId: "news-cluster-1",
                source: "rss_marketwatch",
                title: "Apple cuts guidance after restructuring update",
                url: "https://example.com/cluster-1",
                publishedAt: now.addingTimeInterval(-180),
                receivedAt: now.addingTimeInterval(-175),
                summary: "The company revised guidance and outlined restructuring actions.",
                rawSymbolHints: ["AAPL"],
                tags: ["earnings"],
                payloadVersion: 1
            ),
            NewsEvent(
                eventId: "news-cluster-2",
                source: "alpaca_news",
                title: "Apple guidance cut after restructuring",
                url: "https://example.com/cluster-2",
                publishedAt: now.addingTimeInterval(-120),
                receivedAt: now.addingTimeInterval(-115),
                summary: "Another pickup repeated the same guidance and restructuring read.",
                rawSymbolHints: ["AAPL"],
                tags: ["earnings"],
                payloadVersion: 1
            )
        ],
        positions: [makePositionRow(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")],
        watchlistSymbols: ["AAPL"],
        strategyBrief: nil
    )

    #expect(evaluation.candidateMatches.count == 2)
    #expect(evaluation.eventClusters.count == 1)
    #expect(evaluation.primaryCluster?.eventCount == 2)
    #expect(evaluation.primaryCluster?.novelty == .corroboratingPickup)
    #expect(evaluation.coverageSummary.contains("compacted into one coherent event cluster"))
}

@Test("Recent news materiality keeps watchlist-only single-event cases in monitor posture")
func recentNewsMaterialityKeepsWatchlistOnlySingleEventMonitorOnly() {
    let now = Date(timeIntervalSince1970: 1_720_000_900)
    let evaluation = RecentNewsMaterialityEvaluator.evaluate(
        recentNews: [
            NewsEvent(
                eventId: "watch-monitor-1",
                source: "rss_marketwatch",
                title: "Apple trims guidance after product delay",
                url: "https://example.com/watch-monitor-1",
                publishedAt: now.addingTimeInterval(-120),
                receivedAt: now.addingTimeInterval(-115),
                summary: "A watchlist name disclosed a guidance cut tied to a product-timing delay.",
                rawSymbolHints: ["AAPL"],
                tags: ["earnings"],
                payloadVersion: 1
            )
        ],
        positions: [makePositionRow(symbol: "MSFT", qty: "8", side: "long", marketValue: "8000")],
        watchlistSymbols: ["AAPL", "MSFT"],
        strategyBrief: nil
    )

    #expect(evaluation.candidateMatches.count == 1)
    #expect(evaluation.escalationDisposition == .worthMonitoring)
    #expect(evaluation.isMaterial == false)
}

@Test("Recent news escalation planner keeps duplicate pickup on the same wake-up fingerprint unless meaning changes")
func recentNewsEscalationPlannerKeepsDuplicatePickupStable() {
    let now = Date(timeIntervalSince1970: 1_720_001_100)
    let positions = [makePositionRow(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")]
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Treat guidance changes at held names as material until PM review.",
        keyThemes: ["AI infrastructure"],
        currentRiskPosture: "Moderate with tighter event review.",
        materialDevelopments: ["guidance changes"],
        nonMaterialDevelopments: ["routine office openings"],
        reviewEscalationPosture: "Escalate to PM review first.",
        updatedBy: "pm-1",
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )

    let firstEvaluation = RecentNewsMaterialityEvaluator.evaluate(
        recentNews: [
            NewsEvent(
                eventId: "dup-1",
                source: "rss_marketwatch",
                title: "Apple cuts guidance after restructuring update",
                url: "https://example.com/dup-1",
                publishedAt: now.addingTimeInterval(-300),
                receivedAt: now.addingTimeInterval(-295),
                summary: "The company revised guidance and outlined restructuring actions.",
                rawSymbolHints: ["AAPL"],
                tags: ["earnings"],
                payloadVersion: 1
            )
        ],
        positions: positions,
        watchlistSymbols: ["AAPL"],
        strategyBrief: strategyBrief
    )
    let duplicateEvaluation = RecentNewsMaterialityEvaluator.evaluate(
        recentNews: [
            NewsEvent(
                eventId: "dup-2",
                source: "alpaca_news",
                title: "Apple guidance cut after restructuring",
                url: "https://example.com/dup-2",
                publishedAt: now.addingTimeInterval(-240),
                receivedAt: now.addingTimeInterval(-235),
                summary: "Another pickup repeated the same guidance and restructuring read.",
                rawSymbolHints: ["AAPL"],
                tags: ["earnings"],
                payloadVersion: 1
            )
        ],
        positions: positions,
        watchlistSymbols: ["AAPL"],
        strategyBrief: strategyBrief
    )
    let additiveEvaluation = RecentNewsMaterialityEvaluator.evaluate(
        recentNews: [
            NewsEvent(
                eventId: "dup-3",
                source: "rss_marketwatch",
                title: "Apple investor presentation adds segment margin detail after guidance cut",
                url: "https://example.com/dup-3",
                publishedAt: now.addingTimeInterval(-180),
                receivedAt: now.addingTimeInterval(-175),
                summary: "The investor presentation added margin and segment timing detail beyond the first headline.",
                rawSymbolHints: ["AAPL"],
                tags: ["earnings"],
                payloadVersion: 1
            )
        ],
        positions: positions,
        watchlistSymbols: ["AAPL"],
        strategyBrief: strategyBrief
    )

    let firstPlan = RecentNewsEscalationPlanner.makePlan(
        evaluation: firstEvaluation,
        positions: positions,
        watchlistSymbols: ["AAPL"],
        strategyBrief: strategyBrief
    )
    let duplicatePlan = RecentNewsEscalationPlanner.makePlan(
        evaluation: duplicateEvaluation,
        positions: positions,
        watchlistSymbols: ["AAPL"],
        strategyBrief: strategyBrief
    )
    let additivePlan = RecentNewsEscalationPlanner.makePlan(
        evaluation: additiveEvaluation,
        positions: positions,
        watchlistSymbols: ["AAPL"],
        strategyBrief: strategyBrief
    )

    #expect(firstPlan.delegationId == duplicatePlan.delegationId)
    #expect(additivePlan.delegationId != firstPlan.delegationId)
}

@Test("Recent news analyst job creates no memo or PM escalation when impact is not material")
func recentNewsAnalystJobCreatesNoArtifactsForQuietRun() async throws {
    let tempRoot = makeRecentNewsTempDirectory(name: "recent-news-quiet")
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(
        fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    )
    let reviewStateStore = RecentNewsAnalystReviewStateStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-review-state.json", isDirectory: false)
    )
    let memoryStore = AnalystScopedMemoryStore(
        memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true)
    )
    let runtimeSettingsStore = RecentNewsAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false),
        now: { Date(timeIntervalSince1970: 1_720_001_000) }
    )
    let engine = Engine(
        newsStore: newsStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        recentNewsReviewStateStore: reviewStateStore,
        recentNewsAnalystRuntimeSettingsStore: runtimeSettingsStore,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        replaySleep: { _ in }
    )
    await engine.store.setWatchlistSymbols(["AAPL"])
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try decodePosition(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")
    ])

    _ = try await newsStore.append([
        NewsEvent(
            eventId: "quiet-run",
            source: "rss_marketwatch",
            title: "Apple opens a new office in Austin",
            url: "https://example.com/quiet",
            publishedAt: Date(timeIntervalSince1970: 1_720_001_000),
            receivedAt: Date(timeIntervalSince1970: 1_720_001_005),
            summary: "A facilities update about office space and staffing logistics only.",
            rawSymbolHints: ["AAPL"],
            tags: ["corporate"],
            payloadVersion: 1
        )
    ])

    let job = try await engine.submitJob(
        type: JobType.recentNewsAnalyst,
        parameters: [
            "lookbackMinutes": JSONValue.number(180)
        ],
        source: AuditEventSource.engine
    )
    let completed = try await waitForRecentNewsJob(engine: engine, jobID: job.jobId)

    #expect(completed.status == JobStatus.succeeded)
    #expect(completed.result?.objectValue?["materialImpact"] == JSONValue.bool(false))
    #expect(try await engine.listAnalystMemos().isEmpty)
    #expect(try await engine.listPMDecisions().isEmpty)
    #expect(try await engine.listPMDelegations().isEmpty)
    #expect(await reviewStateStore.load()?.lastReviewedReceivedAt != nil)
    await engine.stop()
}

@Test("Recent news analyst job creates memo and PM escalation for material case")
func recentNewsAnalystJobCreatesMemoAndPMEscalation() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []

        func record(_ request: AnalystWorkerLaunchRequest) {
            requests.append(request)
        }

        func all() -> [AnalystWorkerLaunchRequest] {
            requests
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder
        let memoStore: AnalystMemoStore
        let now: Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            let runtimeProvenance = AnalystRuntimeProvenance(
                intendedPolicy: request.intendedRuntimePolicy,
                actualRuntimeIdentifier: "deterministic_local[\(request.intendedRuntimePolicy?.runtimeIdentifier ?? "deterministic_local")]",
                actualReasoningMode: request.intendedRuntimePolicy?.reasoningMode,
                launchedAt: now
            )
            let memo = AnalystMemo(
                memoId: "memo-recent-news-1",
                analystId: "recent-news-material-impact-analyst",
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: "finding-recent-news-1",
                evidenceBundleId: "bundle-recent-news-1",
                title: "Recent news materiality review: AAPL",
                executiveSummary: "Recent normalized news may have a material impact on AAPL and warrants PM review.",
                currentView: "Current holdings are directly exposed to the triggering news cluster.",
                evidenceSummary: "Primary support comes from recent normalized news and SEC filing metadata tied to AAPL.",
                uncertaintySummary: "This remains a bounded PM-layer review and does not imply execution.",
                recommendedNextStep: "PM should review the memo and decide whether additional follow-up is warranted.",
                confidence: 0.66,
                runtimeProvenance: runtimeProvenance,
                createdAt: now,
                updatedAt: now
            )
            _ = try await memoStore.upsert(memo)

            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                memoId: memo.memoId,
                memoTitle: memo.title,
                findingId: "finding-recent-news-1",
                findingTitle: "Recent news materiality review",
                draftedSignalId: nil,
                runtimeProvenance: runtimeProvenance,
                summary: "memo: \(memo.title)",
                outputExcerpt: memo.executiveSummary
            )
        }
    }

    let tempRoot = makeRecentNewsTempDirectory(name: "recent-news-material")
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let pmProfileStore = PMProfileStore(profilesDirectory: tempRoot.appendingPathComponent("pm-profiles", isDirectory: true))
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystCharterStore = AnalystCharterStore(chartersDirectory: tempRoot.appendingPathComponent("charters", isDirectory: true))
    let analystTaskStore = AnalystTaskStore(tasksDirectory: tempRoot.appendingPathComponent("tasks", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(
        fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    )
    let reviewStateStore = RecentNewsAnalystReviewStateStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-review-state.json", isDirectory: false)
    )
    let memoryStore = AnalystScopedMemoryStore(
        memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true)
    )
    let now = Date(timeIntervalSince1970: 1_720_002_000)
    let runtimeSettingsStore = RecentNewsAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false),
        now: { now }
    )

    _ = try await pmProfileStore.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Supervises analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await runtimeSettingsStore.upsert(
        RecentNewsAnalystRuntimeSettings(
            model: .gpt41Nano,
            reasoningMode: .standard,
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        newsStore: newsStore,
        pmProfileStore: pmProfileStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystCharterStore: analystCharterStore,
        analystTaskStore: analystTaskStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        recentNewsReviewStateStore: reviewStateStore,
        recentNewsAnalystRuntimeSettingsStore: runtimeSettingsStore,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        analystWorkerLauncher: StubLauncher(
            recorder: recorder,
            memoStore: analystMemoStore,
            now: now
        ),
        nowDate: { now },
        replaySleep: { _ in }
    )
    _ = try await strategyBriefStore.upsert(
        PortfolioStrategyBrief(
            objectiveSummary: "Treat guidance changes and major restructuring at held names as portfolio-material until PM review.",
            keyThemes: ["AI infrastructure", "Event-aware supervision"],
            currentRiskPosture: "Moderate risk with tighter review around event-driven repricing.",
            materialDevelopments: ["guidance changes", "major restructuring"],
            nonMaterialDevelopments: ["routine office openings"],
            reviewEscalationPosture: "Escalate to PM review first; do not treat memo output as execution authority.",
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    await engine.store.setWatchlistSymbols(["AAPL"])
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try decodePosition(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")
    ])

    _ = try await newsStore.append([
        NewsEvent(
            eventId: "material-run",
            source: "sec_edgar",
            title: "Apple Inc. filed 8-K",
            url: "https://www.sec.gov/material",
            publishedAt: now.addingTimeInterval(-300),
            receivedAt: now.addingTimeInterval(-295),
            summary: "Guidance update and restructuring details for the current quarter.",
            rawSymbolHints: ["AAPL"],
            tags: ["sec", "8-k"],
            payloadVersion: 1
        )
    ])

    let job = try await engine.submitJob(
        type: JobType.recentNewsAnalyst,
        parameters: [
            "pmId": JSONValue.string("pm-1"),
            "lookbackMinutes": JSONValue.number(180)
        ],
        source: AuditEventSource.engine
    )
    let completed = try await waitForRecentNewsJob(engine: engine, jobID: job.jobId)

    #expect(completed.status == JobStatus.succeeded)
    #expect(completed.result?.objectValue?["materialImpact"] == JSONValue.bool(true))

    let memos = try await engine.listAnalystMemos()
    #expect(memos.count == 1)
    #expect(memos[0].delegationId != nil)

    let decisions = try await engine.listPMDecisions()
    #expect(decisions.count == 1)
    #expect(decisions[0].decisionType == PMDecisionType.escalation)
    #expect(decisions[0].summary.contains("material impact"))
    #expect(decisions[0].recommendedAction?.isEmpty == false)
    #expect(decisions[0].ownerAsk?.contains("Review this change in context") == true)

    let delegations = try await engine.listPMDelegations()
    #expect(delegations.count == 1)
    #expect(delegations[0].requestedOutputs == [PMDelegationRequestedOutput.finding])
    #expect(delegations[0].runtimePolicyOverride?.runtimeIdentifier == "gpt-4.1-nano")
    #expect(delegations[0].runtimePolicyOverride?.policySource == .specializationDefault)

    let requests = await recorder.all()
    #expect(requests.count == 1)
    #expect(requests[0].pmId == "pm-1")
    #expect(requests[0].taskId == delegations[0].taskId)
    #expect(requests[0].intendedRuntimePolicy?.runtimeIdentifier == "gpt-4.1-nano")
    #expect(requests[0].intendedRuntimePolicy?.reasoningMode == .standard)
    let tasks = try await engine.listAnalystTasks()
    #expect(tasks.count == 1)
    #expect(tasks[0].description.contains("Portfolio strategy brief objective: Treat guidance changes"))
    #expect(tasks[0].description.contains("Strategy priorities: Objective: Treat guidance changes"))
    #expect(tasks[0].description.contains("Review posture: Escalate to PM review first"))
    #expect(tasks[0].description.contains("Coverage posture:"))
    #expect(tasks[0].description.contains("Clustered event view:"))
    #expect(tasks[0].description.contains("Escalation posture:"))
    #expect(tasks[0].description.contains("Why now:"))
    #expect(tasks[0].description.contains("Current book posture:"))
    #expect(tasks[0].contextPack?.sharedCurrentTruth.positions.map(\.symbol) == ["AAPL"])
    #expect(tasks[0].contextPack?.sharedCurrentTruth.watchlistSymbols == ["AAPL"])
    #expect(tasks[0].contextPack?.sharedCurrentTruth.portfolioStrategyBrief?.keyThemes == ["AI infrastructure", "Event-aware supervision"])
    #expect(tasks[0].contextPack?.sharedCurrentTruth.portfolioStrategyBrief?.groundingSummary?.contains("Review posture: Escalate to PM review first") == true)
    #expect(tasks[0].contextPack?.sharedCurrentTruth.recentNews.map(\.eventId) == ["material-run"])
    #expect(tasks[0].contextPack?.scopedMemory?.analystId == "recent-news-material-impact-analyst")
    #expect(tasks[0].contextPack?.scopedMemory != nil)
    #expect(await reviewStateStore.load()?.lastReviewedReceivedAt == now.addingTimeInterval(-295))
    await engine.stop()
}

@Test("Recent news standing execution ignores stale seeded charter runtime defaults")
func recentNewsStandingExecutionIgnoresStaleSeededCharterRuntimeDefaults() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []

        func record(_ request: AnalystWorkerLaunchRequest) {
            requests.append(request)
        }

        func all() -> [AnalystWorkerLaunchRequest] {
            requests
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder
        let memoStore: AnalystMemoStore
        let now: Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            let runtimeProvenance = AnalystRuntimeProvenance(
                intendedPolicy: request.intendedRuntimePolicy,
                actualRuntimeIdentifier: "deterministic_local[\(request.intendedRuntimePolicy?.runtimeIdentifier ?? "deterministic_local")]",
                actualReasoningMode: request.intendedRuntimePolicy?.reasoningMode,
                launchedAt: now
            )
            let memo = AnalystMemo(
                memoId: "memo-recent-news-stale-default",
                analystId: recentNewsStandingAnalystID,
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: "finding-recent-news-stale-default",
                title: "Recent News Memo",
                executiveSummary: "Recent normalized news may have a material impact and warrants PM review.",
                currentView: "Current holdings are directly exposed to the triggering news cluster.",
                evidenceSummary: "Primary support comes from recent normalized news and SEC filing metadata tied to AAPL.",
                uncertaintySummary: "This remains a bounded PM-layer review and does not imply execution.",
                recommendedNextStep: "PM should review the memo and decide whether additional follow-up is warranted.",
                confidence: 0.66,
                runtimeProvenance: runtimeProvenance,
                createdAt: now,
                updatedAt: now
            )
            _ = try await memoStore.upsert(memo)
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                memoId: memo.memoId,
                memoTitle: memo.title,
                findingId: "finding-recent-news-stale-default",
                findingTitle: "Recent News Finding",
                draftedSignalId: nil,
                runtimeProvenance: runtimeProvenance,
                summary: "memo: \(memo.title)",
                outputExcerpt: "stub worker completed"
            )
        }
    }

    let tempRoot = makeRecentNewsTempDirectory(name: "recent-news-stale-seeded-runtime")
    let now = Date(timeIntervalSince1970: 1_720_002_500)
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let pmProfileStore = PMProfileStore(profilesDirectory: tempRoot.appendingPathComponent("pm-profiles", isDirectory: true))
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystCharterStore = AnalystCharterStore(chartersDirectory: tempRoot.appendingPathComponent("charters", isDirectory: true))
    let analystTaskStore = AnalystTaskStore(tasksDirectory: tempRoot.appendingPathComponent("tasks", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(
        fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    )
    let reviewStateStore = RecentNewsAnalystReviewStateStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-review-state.json", isDirectory: false)
    )
    let memoryStore = AnalystScopedMemoryStore(
        memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true)
    )
    let runtimeSettingsStore = RecentNewsAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false),
        now: { now }
    )

    _ = try await analystCharterStore.upsert(
        AnalystCharter(
            charterId: recentNewsStandingAnalystCharterID,
            analystId: recentNewsStandingAnalystID,
            title: recentNewsStandingAnalystTitle,
            coverageScope: "Current portfolio holdings and watchlist names reviewed through recent-news materiality analysis.",
            strategyFamily: "standing overlay bench",
            summary: "Legacy seeded runtime default should not survive covered execution.",
            benchRole: .overlay,
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
    _ = try await pmProfileStore.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Supervises analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await runtimeSettingsStore.upsert(
        RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4-mini",
            reasoningMode: .deliberate,
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await strategyBriefStore.upsert(
        PortfolioStrategyBrief(
            objectiveSummary: "Escalate material held-name news for PM review.",
            keyThemes: ["AI infrastructure"],
            currentRiskPosture: "Moderate",
            materialDevelopments: ["guidance changes"],
            nonMaterialDevelopments: ["routine office openings"],
            reviewEscalationPosture: "Escalate to PM review first.",
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        newsStore: newsStore,
        pmProfileStore: pmProfileStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystCharterStore: analystCharterStore,
        analystTaskStore: analystTaskStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        recentNewsReviewStateStore: reviewStateStore,
        recentNewsAnalystRuntimeSettingsStore: runtimeSettingsStore,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        analystWorkerLauncher: StubLauncher(recorder: recorder, memoStore: analystMemoStore, now: now),
        nowDate: { now },
        replaySleep: { _ in }
    )
    await engine.store.setWatchlistSymbols(["AAPL"])
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try decodePosition(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")
    ])
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "material-run-stale-default",
            source: "sec_edgar",
            title: "Apple Inc. filed 8-K",
            url: "https://www.sec.gov/material-stale-default",
            publishedAt: now.addingTimeInterval(-120),
            receivedAt: now.addingTimeInterval(-115),
            summary: "Guidance update and restructuring details for the current quarter.",
            rawSymbolHints: ["AAPL"],
            tags: ["sec", "8-k"],
            payloadVersion: 1
        )
    ])

    let job = try await engine.submitJob(
        type: .recentNewsAnalyst,
        parameters: [
            "pmId": JSONValue.string("pm-1"),
            "lookbackMinutes": JSONValue.number(180)
        ],
        source: .engine
    )
    let completed = try await waitForRecentNewsJob(engine: engine, jobID: job.jobId)

    #expect(completed.status == .succeeded)
    let requests = await recorder.all()
    #expect(requests.count == 1)
    #expect(requests[0].intendedRuntimePolicy?.runtimeIdentifier == "gpt-5.4-mini")
    #expect(requests[0].intendedRuntimePolicy?.reasoningMode == .deliberate)
    #expect(requests[0].intendedRuntimePolicy?.policySource == .specializationDefault)

    let charter = try await engine.getAnalystCharter(id: recentNewsStandingAnalystCharterID)
    #expect(charter.defaultRuntimePolicy == nil)
    await engine.stop()
}

@Test("Recent news analyst uses persisted review watermark to skip stale reruns and process only new news")
func recentNewsAnalystUsesPersistedIncrementalReviewWatermark() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []

        func record(_ request: AnalystWorkerLaunchRequest) {
            requests.append(request)
        }

        func count() -> Int {
            requests.count
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder
        let memoStore: AnalystMemoStore
        let nowProvider: @Sendable () -> Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            let now = nowProvider()
            let delegationID = request.delegationId ?? "recent-news-delegation"
            await recorder.record(request)
            let memo = AnalystMemo(
                memoId: "memo-\(delegationID)",
                analystId: "recent-news-material-impact-analyst",
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: "finding-\(delegationID)",
                evidenceBundleId: "bundle-\(delegationID)",
                title: "Recent news materiality review",
                executiveSummary: "Potentially material recent-news impact warrants PM review.",
                currentView: "The new event is materially relevant to the active portfolio scope.",
                evidenceSummary: "Normalized news directly references a held symbol.",
                uncertaintySummary: "This remains a bounded analyst escalation.",
                recommendedNextStep: "PM should review the memo and decide whether follow-up is required.",
                confidence: 0.62,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: request.intendedRuntimePolicy,
                    actualRuntimeIdentifier: "deterministic_local",
                    actualReasoningMode: request.intendedRuntimePolicy?.reasoningMode,
                    launchedAt: now
                ),
                createdAt: now,
                updatedAt: now
            )
            _ = try await memoStore.upsert(memo)
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                memoId: memo.memoId,
                memoTitle: memo.title,
                findingId: memo.findingId,
                findingTitle: "Recent news materiality review",
                draftedSignalId: nil,
                runtimeProvenance: memo.runtimeProvenance,
                summary: memo.executiveSummary,
                outputExcerpt: memo.executiveSummary
            )
        }
    }

    let tempRoot = makeRecentNewsTempDirectory(name: "recent-news-incremental")
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let pmProfileStore = PMProfileStore(profilesDirectory: tempRoot.appendingPathComponent("pm-profiles", isDirectory: true))
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystCharterStore = AnalystCharterStore(chartersDirectory: tempRoot.appendingPathComponent("charters", isDirectory: true))
    let analystTaskStore = AnalystTaskStore(tasksDirectory: tempRoot.appendingPathComponent("tasks", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let reviewStateStore = RecentNewsAnalystReviewStateStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-review-state.json", isDirectory: false)
    )
    let memoryStore = AnalystScopedMemoryStore(
        memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true)
    )

    let firstNow = Date(timeIntervalSince1970: 1_720_100_000)
    let secondNow = Date(timeIntervalSince1970: 1_720_100_900)
    let thirdNow = Date(timeIntervalSince1970: 1_720_101_800)
    let clock = TestClock(firstNow)

    _ = try await pmProfileStore.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Supervises analyst work.",
            createdAt: firstNow,
            updatedAt: firstNow
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        newsStore: newsStore,
        pmProfileStore: pmProfileStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystCharterStore: analystCharterStore,
        analystTaskStore: analystTaskStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        recentNewsReviewStateStore: reviewStateStore,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        analystWorkerLauncher: StubLauncher(
            recorder: recorder,
            memoStore: analystMemoStore,
            nowProvider: { clock.get() }
        ),
        nowDate: { clock.get() },
        replaySleep: { _ in }
    )
    await engine.store.setWatchlistSymbols(["AAPL"])
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try decodePosition(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")
    ])

    _ = try await newsStore.append([
        NewsEvent(
            eventId: "news-material-1",
            source: "sec_edgar",
            title: "Apple Inc. filed 8-K",
            url: "https://www.sec.gov/material-1",
            publishedAt: firstNow.addingTimeInterval(-600),
            receivedAt: firstNow.addingTimeInterval(-590),
            summary: "Guidance update and restructuring details for the current quarter.",
            rawSymbolHints: ["AAPL"],
            tags: ["sec", "8-k"],
            payloadVersion: 1
        )
    ])

    let firstJob = try await engine.submitJob(
        type: .recentNewsAnalyst,
        parameters: [
            "pmId": .string("pm-1"),
            "lookbackMinutes": .number(180)
        ],
        source: .engine
    )
    let firstCompleted = try await waitForRecentNewsJob(engine: engine, jobID: firstJob.jobId)
    #expect(firstCompleted.result?.objectValue?["materialImpact"] == .bool(true))
    #expect(await recorder.count() == 1)
    #expect((try await engine.listAnalystMemos()).count == 1)

    clock.set(secondNow)
    let secondJob = try await engine.submitJob(
        type: .recentNewsAnalyst,
        parameters: [
            "pmId": .string("pm-1"),
            "lookbackMinutes": .number(180)
        ],
        source: .engine
    )
    let secondCompleted = try await waitForRecentNewsJob(engine: engine, jobID: secondJob.jobId)
    #expect(secondCompleted.result?.objectValue?["materialImpact"] == .bool(false))
    #expect(secondCompleted.result?.objectValue?["newNewsCount"] == .number(0))
    #expect(await recorder.count() == 1)
    #expect((try await engine.listAnalystMemos()).count == 1)
    #expect((try await engine.listPMDecisions()).count == 1)
    #expect((try await engine.listPMDelegations()).count == 1)

    clock.set(thirdNow)
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "news-material-2",
            source: "rss_marketwatch",
            title: "Apple earnings guidance revised after restructuring",
            url: "https://example.com/material-2",
            publishedAt: thirdNow.addingTimeInterval(-120),
            receivedAt: thirdNow.addingTimeInterval(-110),
            summary: "The company updated guidance and outlined restructuring actions that affect the near-term outlook.",
            rawSymbolHints: ["AAPL"],
            tags: ["earnings", "guidance"],
            payloadVersion: 1
        )
    ])

    let thirdJob = try await engine.submitJob(
        type: .recentNewsAnalyst,
        parameters: [
            "pmId": .string("pm-1"),
            "lookbackMinutes": .number(180)
        ],
        source: .engine
    )
    let thirdCompleted = try await waitForRecentNewsJob(engine: engine, jobID: thirdJob.jobId)
    #expect(thirdCompleted.result?.objectValue?["materialImpact"] == .bool(true))
    #expect(thirdCompleted.result?.objectValue?["newNewsCount"] == .number(1))
    #expect(await recorder.count() == 2)
    #expect((try await engine.listAnalystMemos()).count == 2)
    #expect((try await engine.listPMDecisions()).count == 2)
    #expect((try await engine.listPMDelegations()).count == 2)

    let state = try #require(await reviewStateStore.load())
    #expect(state.lastReviewedReceivedAt == thirdNow.addingTimeInterval(-110))
    #expect(state.lastReviewedEventIDsAtWatermark == ["news-material-2"])
    await engine.stop()
}

@Test("Recent news review state store round-trips and falls back cleanly on invalid documents")
func recentNewsReviewStateStoreRoundTripsAndFallsBackCleanly() async throws {
    let fileURL = makeRecentNewsTempDirectory(name: "recent-news-state")
        .appendingPathComponent("recent-news-review-state.json", isDirectory: false)
    let store = RecentNewsAnalystReviewStateStore(fileURL: fileURL)
    let state = RecentNewsAnalystReviewState(
        lastReviewedReceivedAt: Date(timeIntervalSince1970: 1_720_200_000),
        lastReviewedEventIDsAtWatermark: ["news-1", "news-2"],
        lastRunAt: Date(timeIntervalSince1970: 1_720_200_005),
        updatedAt: Date(timeIntervalSince1970: 1_720_200_005)
    )

    _ = try await store.save(state)
    #expect(await store.load() == state)

    let invalidURL = makeRecentNewsTempDirectory(name: "recent-news-state-invalid")
        .appendingPathComponent("recent-news-review-state.json", isDirectory: false)
    try Data("{\"schemaVersion\":2}".utf8).write(to: invalidURL, options: [.atomic])
    let invalidStore = RecentNewsAnalystReviewStateStore(fileURL: invalidURL)
    #expect(await invalidStore.load() == nil)
    #expect(await invalidStore.drainLoadDiagnostics().contains(where: { $0.contains("unsupported_schema_version") }))
}

@Test("Recent news runtime settings store round-trips defaults and rejects unsupported schema")
func recentNewsRuntimeSettingsStoreRoundTripsAndDefaults() async throws {
    let baseNow = Date(timeIntervalSince1970: 1_720_300_000)
    let fileURL = makeRecentNewsTempDirectory(name: "recent-news-runtime")
        .appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false)
    let store = RecentNewsAnalystRuntimeSettingsStore(
        fileURL: fileURL,
        now: { baseNow }
    )

    let defaultSettings = await store.loadOrDefault()
    #expect(defaultSettings.runtimeIdentifier == "gpt-4.1-mini")
    #expect(defaultSettings.reasoningMode == .standard)
    #expect(defaultSettings.validationStatus == nil)

    let updated = try await store.upsert(
        RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: baseNow,
            updatedAt: baseNow
        )
    )
    #expect(updated.runtimeIdentifier == "gpt-5.4")
    #expect(await store.load()?.runtimeIdentifier == "gpt-5.4")

    let reloadedStore = RecentNewsAnalystRuntimeSettingsStore(
        fileURL: fileURL,
        now: { baseNow.addingTimeInterval(60) }
    )
    let reloaded = await reloadedStore.loadOrDefault()
    #expect(reloaded.runtimeIdentifier == "gpt-5.4")
    #expect(reloaded.reasoningMode == .deliberate)

    let invalidURL = makeRecentNewsTempDirectory(name: "recent-news-runtime-invalid")
        .appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false)
    try Data("{\"schemaVersion\":2}".utf8).write(to: invalidURL, options: [.atomic])
    let invalidStore = RecentNewsAnalystRuntimeSettingsStore(fileURL: invalidURL)
    let invalidDefault = await invalidStore.loadOrDefault()
    #expect(invalidDefault.runtimeIdentifier == "gpt-4.1-mini")
    #expect(await invalidStore.drainLoadDiagnostics().contains(where: { $0.contains("unsupported_schema_version") }))

    let legacyURL = makeRecentNewsTempDirectory(name: "recent-news-runtime-legacy")
        .appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false)
    try Data(
        """
        {
          "schemaVersion": 1,
          "settings": {
            "settingsId": "recent-news-analyst-runtime-settings",
            "model": "gpt-4.1",
            "reasoningMode": "standard",
            "updatedBy": "pm-primary",
            "updateSource": "pm_control_plane",
            "createdAt": "2024-07-25T18:40:00Z",
            "updatedAt": "2024-07-25T18:40:00Z"
          }
        }
        """.utf8
    ).write(to: legacyURL, options: [.atomic])
    let legacyStore = RecentNewsAnalystRuntimeSettingsStore(fileURL: legacyURL)
    let legacyLoaded = await legacyStore.loadOrDefault()
    #expect(legacyLoaded.runtimeIdentifier == "gpt-4.1")
    #expect(legacyLoaded.reasoningMode == .standard)
}

@Test("Recent news runtime resolves invalid configured runtime through last-known-good fallback")
func recentNewsRuntimeFallbackRemainsExplicit() async throws {
    let now = Date(timeIntervalSince1970: 1_720_300_500)
    let tempRoot = makeRecentNewsTempDirectory(name: "recent-news-runtime-fallback")
    let runtimeSettingsStore = RecentNewsAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("recent-news-runtime-settings.json", isDirectory: false),
        now: { now }
    )
    _ = try await runtimeSettingsStore.upsert(
        RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-4.1-mini",
            reasoningMode: .standard,
            validationStatus: RuntimeValidationRecord(
                status: .valid,
                category: .accepted,
                summary: "Locally accepted.",
                checkedAt: now,
                checkedBy: "pm-1"
            ),
            lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
                runtimeIdentifier: "gpt-4.1-mini",
                reasoningMode: .standard,
                verifiedAt: now,
                summary: "Locally accepted."
            ),
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(recentNewsAnalystRuntimeSettingsStore: runtimeSettingsStore)

    _ = try await engine.upsertRecentNewsAnalystRuntimeSettings(
        RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "bad runtime!",
            reasoningMode: .standard,
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now.addingTimeInterval(1)
        )
    )

    let resolution = try await engine.resolveRecentNewsAnalystRuntimeSelectionForExecution()
    #expect(resolution.fallbackApplied == true)
    #expect(resolution.effectiveRuntimeIdentifier == "gpt-4.1-mini")
    #expect(resolution.validation.status == .invalid)

    let resolved = try await engine.getRecentNewsAnalystRuntimeSettings()
    #expect(resolved.validationStatus?.status == .invalid)
    #expect(resolved.lastFallback?.fallbackRuntimeIdentifier == "gpt-4.1-mini")
}

@Test("Standing bench runtime settings store round-trips defaults and rejects unsupported schema")
func standingBenchRuntimeSettingsStoreRoundTripsAndDefaults() async throws {
    let baseNow = Date(timeIntervalSince1970: 1_720_300_000)
    let fileURL = makeRecentNewsTempDirectory(name: "standing-bench-runtime")
        .appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)
    let store = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: fileURL,
        now: { baseNow }
    )

    let defaultSettings = await store.loadOrDefault()
    #expect(defaultSettings.runtimeIdentifier == "gpt-4.1")
    #expect(defaultSettings.reasoningMode == .standard)
    #expect(defaultSettings.validationStatus == nil)

    let updated = try await store.upsert(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: baseNow,
            updatedAt: baseNow
        )
    )
    #expect(updated.runtimeIdentifier == "gpt-5.4")
    #expect(await store.load()?.runtimeIdentifier == "gpt-5.4")

    let reloadedStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: fileURL,
        now: { baseNow.addingTimeInterval(60) }
    )
    let reloaded = await reloadedStore.loadOrDefault()
    #expect(reloaded.runtimeIdentifier == "gpt-5.4")
    #expect(reloaded.reasoningMode == .deliberate)

    let invalidURL = makeRecentNewsTempDirectory(name: "standing-bench-runtime-invalid")
        .appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)
    try Data("{\"schemaVersion\":2}".utf8).write(to: invalidURL, options: [.atomic])
    let invalidStore = StandingBenchAnalystRuntimeSettingsStore(fileURL: invalidURL)
    let invalidDefault = await invalidStore.loadOrDefault()
    #expect(invalidDefault.runtimeIdentifier == "gpt-4.1")
    #expect(await invalidStore.drainLoadDiagnostics().contains(where: { $0.contains("unsupported_schema_version") }))
}

@Test("Standing bench runtime resolves invalid configured runtime through last-known-good fallback")
func standingBenchRuntimeFallbackRemainsExplicit() async throws {
    let now = Date(timeIntervalSince1970: 1_720_300_500)
    let tempRoot = makeRecentNewsTempDirectory(name: "standing-bench-runtime-fallback")
    let runtimeSettingsStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false),
        now: { now }
    )
    _ = try await runtimeSettingsStore.upsert(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            validationStatus: RuntimeValidationRecord(
                status: .valid,
                category: .accepted,
                summary: "Locally accepted.",
                checkedAt: now,
                checkedBy: "pm-1"
            ),
            lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
                runtimeIdentifier: "gpt-4.1",
                reasoningMode: .standard,
                verifiedAt: now,
                summary: "Locally accepted."
            ),
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(standingBenchAnalystRuntimeSettingsStore: runtimeSettingsStore)

    _ = try await engine.upsertStandingBenchAnalystRuntimeSettings(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "bad runtime!",
            reasoningMode: .standard,
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now.addingTimeInterval(1)
        )
    )

    let resolution = try await engine.resolveStandingBenchAnalystRuntimeSelectionForExecution()
    #expect(resolution.fallbackApplied == true)
    #expect(resolution.effectiveRuntimeIdentifier == "gpt-4.1")
    #expect(resolution.validation.status == .invalid)

    let resolved = try await engine.getStandingBenchAnalystRuntimeSettings()
    #expect(resolved.validationStatus?.status == .invalid)
    #expect(resolved.lastFallback?.fallbackRuntimeIdentifier == "gpt-4.1")
}

@Test("Standing bench runtime keeps newer owner setting when stale control-plane overwrite arrives")
func standingBenchRuntimeRejectsStaleControlPlaneOverwrite() async throws {
    let now = Date(timeIntervalSince1970: 1_720_301_000)
    let tempRoot = makeRecentNewsTempDirectory(name: "standing-bench-runtime-owner-protection")
    let runtimeSettingsStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: tempRoot.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false),
        now: { now }
    )
    let engine = Engine(standingBenchAnalystRuntimeSettingsStore: runtimeSettingsStore)

    let ownerUpdated = try await engine.upsertStandingBenchAnalystRuntimeSettings(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "human-owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(ownerUpdated.runtimeIdentifier == "gpt-5.4")
    #expect(ownerUpdated.updateSource == .userEdited)

    let protected = try await engine.upsertStandingBenchAnalystRuntimeSettings(
        StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            updatedBy: "pm-primary",
            updateSource: .pmControlPlane,
            createdAt: now.addingTimeInterval(-600),
            updatedAt: now.addingTimeInterval(-600)
        )
    )

    #expect(protected.runtimeIdentifier == "gpt-5.4")
    #expect(protected.reasoningMode == .deliberate)
    #expect(protected.updateSource == .userEdited)

    let fetched = try await engine.getStandingBenchAnalystRuntimeSettings()
    #expect(fetched.runtimeIdentifier == "gpt-5.4")
    #expect(fetched.reasoningMode == .deliberate)
    #expect(fetched.updateSource == .userEdited)
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ initial: Date) {
        value = initial
    }

    func get() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Date) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}

@Test("ScheduleStore seeds disabled recent news analyst default schedule")
func scheduleStoreSeedsRecentNewsAnalystDefaultSchedule() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("recent-news-schedule-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedules = try await store.seedDefaultsIfStoreMissing()
    let schedule = try #require(schedules.first(where: { $0.scheduleId == "default-recent-news-analyst" }))

    #expect(schedule.jobType == .recentNewsAnalyst)
    #expect(schedule.enabled == false)
    #expect(schedule.trigger.intervalSec == 900)
    #expect(schedule.policy.runMode == .periodic)
    #expect(schedule.params["runtimeId"] == nil)
    #expect(schedule.params["reasoningMode"] == nil)
}

@Test("Recent news materiality task produces portfolio-aware memo without external-evidence noise")
func recentNewsMaterialityTaskProducesPortfolioAwareMemo() async throws {
    let now = Date(timeIntervalSince1970: 1_720_003_000)
    let charter = AnalystCharter(
        charterId: "recent-news-material-impact-analyst",
        analystId: "recent-news-material-impact-analyst",
        title: "Recent News Material-Impact Analyst",
        coverageScope: "Portfolio",
        strategyFamily: "portfolio supervision",
        summary: "Review recent normalized news for material portfolio impact.",
        allowedSources: ["app_news", "app_positions", "app_watchlist", "no_external_evidence_required"],
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "recent-news-task-1",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Recent news materiality review: AAPL",
        description: "Review recent normalized news for potentially material portfolio impact.",
        status: .queued,
        createdAt: now,
        updatedAt: now,
        symbols: ["AAPL"],
        tags: ["recent-news-analyst", "portfolio-material-impact", "task-recommendation"],
        contextPack: AnalystContextPack(
            sharedCurrentTruth: AnalystSharedCurrentTruth(
                positions: [
                    AnalystPositionContext(
                        symbol: "AAPL",
                        directionLabel: "LONG",
                        quantity: "10",
                        marketValue: "10000"
                    )
                ],
                watchlistSymbols: ["AAPL", "MSFT"],
                portfolioStrategyBrief: AnalystStrategyBriefContext(
                    title: "Current Portfolio Strategy Brief",
                    objectiveSummary: "Treat guidance changes at held names as material until PM review.",
                    keyThemes: ["AI infrastructure"],
                    currentRiskPosture: "Moderate with tighter event review.",
                    materialDevelopments: ["guidance changes"],
                    nonMaterialDevelopments: ["routine office openings"],
                    reviewEscalationPosture: "Escalate to PM review first.",
                    updatedAt: now
                ),
                recentNews: [
                    AnalystNewsContextItem(
                        eventId: "news-1",
                        title: "Apple Inc. filed 8-K",
                        source: "sec_edgar",
                        publishedAt: now.addingTimeInterval(10),
                        symbolHints: ["AAPL"],
                        summary: "Guidance update and restructuring details."
                    )
                ],
                pmMandates: [],
                pmInstructions: []
            ),
            scopedMemory: AnalystScopedMemorySnapshot(
                memoryId: "recent-news-material-impact-analyst",
                analystId: "recent-news-material-impact-analyst",
                charterId: charter.charterId,
                trackedSymbols: ["AAPL"],
                trackedThemes: ["guidance"],
                openQuestions: ["Does the guidance change alter the next quarter setup?"],
                recentMemos: [],
                recentFindings: [],
                updatedAt: now
            ),
            assembledAt: now
        )
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-1",
                source: "sec_edgar",
                title: "Apple Inc. filed 8-K",
                url: "https://www.sec.gov/news-1",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Guidance update and restructuring details.",
                rawSymbolHints: ["AAPL"],
                tags: ["sec", "8-k"],
                payloadVersion: 1
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { now.addingTimeInterval(20) }
    )

    let summary = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        pmID: "pm-1",
        newsLimit: 5
    )

    #expect(summary.memoId.isEmpty == false)
    #expect(summary.externalEvidenceIssueCount == 0)

    let memos = await fixture.memos()
    #expect(memos.count == 1)
    #expect(memos[0].executiveSummary.contains("potentially material"))
    #expect(memos[0].currentView.contains("AAPL LONG qty 10"))
    #expect(memos[0].currentView.contains("guidance"))
    #expect(memos[0].recommendedNextStep.contains("does not authorize trading") == false)
    #expect(memos[0].recommendedNextStep.contains("approval gates"))
    #expect(memos[0].recommendedNextStep.contains("guidance change alter the next quarter setup"))
}

private func waitForRecentNewsJob(
    engine: Engine,
    jobID: String,
    retries: Int = 40
) async throws -> JobRecord {
    for _ in 0..<retries {
        let job = try await engine.getJob(jobID: jobID)
        if job.status == .succeeded || job.status == .failed || job.status == .canceled {
            return job
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    return try await engine.getJob(jobID: jobID)
}

private func makeRecentNewsTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePositionRow(symbol: String, qty: String, side: String, marketValue: String) -> PositionRow {
    PositionRow(
        id: symbol,
        symbol: symbol,
        side: side,
        qty: qty,
        marketValue: marketValue
    )
}

private func decodePosition(symbol: String, qty: String, side: String, marketValue: String) throws -> Position {
    try JSONDecoder().decode(
        Position.self,
        from: Data(
            """
            {"symbol":"\(symbol)","qty":"\(qty)","side":"\(side)","marketValue":"\(marketValue)"}
            """.utf8
        )
    )
}

private struct StubOpenAIKeyProvider: OpenAIKeyStatusProviding {
    let configured: Bool
    let value: String?

    init(configured: Bool, value: String? = nil) {
        self.configured = configured
        self.value = value
    }

    func isConfigured() -> Bool {
        configured
    }

    func apiKey() -> String? {
        value
    }
}

private struct StubExternalEvidenceProvider: ExternalAnalystEvidenceProviding {
    let result: AnalystExternalEvidenceFetchResult

    init(documents: [ExternalAnalystEvidenceDocument]) {
        self.result = AnalystExternalEvidenceFetchResult(documents: documents)
    }

    func fetchEvidence(
        for charter: AnalystCharter,
        task: AnalystTask,
        baselineNews: [NewsEvent],
        plannedSources: [ApprovedAnalystSourceDefinition]
    ) async -> AnalystExternalEvidenceFetchResult {
        _ = charter
        _ = task
        _ = baselineNews
        _ = plannedSources
        return result
    }
}

private actor AnalystWorkerFixture: AnalystControlPlaneClient {
    private var storedCharters: [AnalystCharter]
    private var storedTasks: [AnalystTask]
    private var storedNews: [NewsEvent]
    private var storedBundles: [AnalystEvidenceBundle]
    private var storedMemos: [AnalystMemo]
    private var storedFindings: [AnalystFinding]
    private var storedSourceAccessSuggestions: [AnalystSourceAccessSuggestionRecord]
    private var storedSignals: [Signal]

    init(
        initialCharters: [AnalystCharter] = [],
        initialTasks: [AnalystTask] = [],
        initialNews: [NewsEvent] = [],
        initialBundles: [AnalystEvidenceBundle] = [],
        initialMemos: [AnalystMemo] = [],
        initialFindings: [AnalystFinding] = [],
        initialSourceAccessSuggestions: [AnalystSourceAccessSuggestionRecord] = [],
        initialSignals: [Signal] = []
    ) {
        self.storedCharters = initialCharters
        self.storedTasks = initialTasks
        self.storedNews = initialNews
        self.storedBundles = initialBundles
        self.storedMemos = initialMemos
        self.storedFindings = initialFindings
        self.storedSourceAccessSuggestions = initialSourceAccessSuggestions
        self.storedSignals = initialSignals
    }

    func listCharters() async throws -> [AnalystCharter] { storedCharters }

    func upsertCharter(_ charter: AnalystCharter) async throws -> AnalystCharter {
        if let index = storedCharters.firstIndex(where: { $0.charterId == charter.charterId }) {
            storedCharters[index] = charter
        } else {
            storedCharters.append(charter)
        }
        return charter
    }

    func listSourceAccessSuggestions() async throws -> [AnalystSourceAccessSuggestionRecord] {
        storedSourceAccessSuggestions
    }

    func upsertSourceAccessSuggestion(_ suggestion: AnalystSourceAccessSuggestionRecord) async throws -> AnalystSourceAccessSuggestionRecord {
        if let index = storedSourceAccessSuggestions.firstIndex(where: { $0.suggestionId == suggestion.suggestionId }) {
            storedSourceAccessSuggestions[index] = suggestion
        } else {
            storedSourceAccessSuggestions.append(suggestion)
        }
        return suggestion
    }

    func listTasks() async throws -> [AnalystTask] { storedTasks }

    func getTask(id: String) async throws -> AnalystTask {
        guard let task = storedTasks.first(where: { $0.taskId == id }) else {
            throw AnalystTaskStoreError.taskNotFound(id: id)
        }
        return task
    }

    func upsertTask(_ task: AnalystTask) async throws -> AnalystTask {
        if let index = storedTasks.firstIndex(where: { $0.taskId == task.taskId }) {
            storedTasks[index] = task
        } else {
            storedTasks.append(task)
        }
        return task
    }

    func listMemos() async throws -> [AnalystMemo] { storedMemos }

    func getMemo(id: String) async throws -> AnalystMemo {
        guard let memo = storedMemos.first(where: { $0.memoId == id }) else {
            throw AnalystMemoStoreError.memoNotFound(id: id)
        }
        return memo
    }

    func listNews(limit: Int, since: Date?) async throws -> [NewsEvent] {
        storedNews
            .filter { event in
                guard let since else { return true }
                return event.publishedAt >= since
            }
            .prefix(max(1, limit))
            .map { $0 }
    }

    func upsertEvidenceBundle(_ bundle: AnalystEvidenceBundle) async throws -> AnalystEvidenceBundle {
        if let index = storedBundles.firstIndex(where: { $0.bundleId == bundle.bundleId }) {
            storedBundles[index] = bundle
        } else {
            storedBundles.append(bundle)
        }
        return bundle
    }

    func upsertMemo(_ memo: AnalystMemo) async throws -> AnalystMemo {
        if let index = storedMemos.firstIndex(where: { $0.memoId == memo.memoId }) {
            storedMemos[index] = memo
        } else {
            storedMemos.append(memo)
        }
        return memo
    }

    func upsertFinding(_ finding: AnalystFinding) async throws -> AnalystFinding {
        if let index = storedFindings.firstIndex(where: { $0.findingId == finding.findingId }) {
            storedFindings[index] = finding
        } else {
            storedFindings.append(finding)
        }
        return finding
    }

    func draftSignalFromFinding(id: String) async throws -> Signal {
        throw AnalystFindingStoreError.findingNotFound(id: id)
    }

    func draftProposalFromSignal(id: String, strategyID: String) async throws -> StrategyProposal {
        _ = strategyID
        throw SignalStoreError.signalNotFound(id: id)
    }

    func memos() -> [AnalystMemo] { storedMemos }
}
