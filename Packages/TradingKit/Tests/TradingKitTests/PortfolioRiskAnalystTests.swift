import Foundation
import Testing
@testable import TradingKit

@Test("Portfolio risk trigger thresholds reflect current risk posture")
func portfolioRiskTriggerThresholdsReflectRiskPosture() {
    let diversifiedSnapshot = makePortfolioRiskSnapshot(
        positions: [
            makePortfolioRiskPosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "30000"),
            makePortfolioRiskPosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "25000"),
            makePortfolioRiskPosition(symbol: "AAPL", qty: "100", side: "long", marketValue: "25000"),
            makePortfolioRiskPosition(symbol: "GOOG", qty: "100", side: "long", marketValue: "20000")
        ]
    )

    let conservative = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: diversifiedSnapshot,
        strategyBrief: PortfolioStrategyBrief(
            objectiveSummary: "Keep concentration tighter.",
            keyThemes: [],
            currentRiskPosture: "Conservative posture with tighter concentration control.",
            materialDevelopments: [],
            nonMaterialDevelopments: [],
            reviewEscalationPosture: "Escalate only when clearly warranted.",
            updatedBy: "pm",
            updateSource: .pmControlPlane,
            createdAt: Date(timeIntervalSince1970: 1_720_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_720_100_000)
        ),
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: [:],
        recentNews: [],
        now: Date(timeIntervalSince1970: 1_720_100_000)
    )
    #expect(conservative.isMaterial)
    #expect(conservative.matches.contains(where: {
        $0.kind == PortfolioRiskTriggerMatch.Kind.singlePositionConcentration && $0.symbol == "NVDA"
    }))

    let aggressive = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: diversifiedSnapshot,
        strategyBrief: PortfolioStrategyBrief(
            objectiveSummary: "Allow more concentration when conviction is high.",
            keyThemes: [],
            currentRiskPosture: "Aggressive and concentrated when conviction is high.",
            materialDevelopments: [],
            nonMaterialDevelopments: [],
            reviewEscalationPosture: "Escalate only when clearly warranted.",
            updatedBy: "pm",
            updateSource: .pmControlPlane,
            createdAt: Date(timeIntervalSince1970: 1_720_100_100),
            updatedAt: Date(timeIntervalSince1970: 1_720_100_100)
        ),
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: [:],
        recentNews: [],
        now: Date(timeIntervalSince1970: 1_720_100_100)
    )
    #expect(aggressive.isMaterial == false)
    #expect(aggressive.summary.contains("quiet"))
}

@Test("Portfolio risk evaluator summarizes concentration, cluster, and long-vs-short posture")
func portfolioRiskEvaluatorSummarizesBookPosture() {
    let snapshot = makePortfolioRiskSnapshot(
        positions: [
            makePortfolioRiskPosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "42000"),
            makePortfolioRiskPosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "28000"),
            makePortfolioRiskPosition(symbol: "QQQ", qty: "100", side: "long", marketValue: "14000"),
            makePortfolioRiskPosition(symbol: "SPY", qty: "100", side: "short", marketValue: "16000")
        ]
    )

    let evaluation = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: snapshot,
        strategyBrief: PortfolioStrategyBrief(
            objectiveSummary: "Keep upside while containing concentration and directional crowding.",
            keyThemes: ["Concentration discipline", "Long-side crowding"],
            currentRiskPosture: "Moderate risk posture with tighter review on concentration and directional imbalance.",
            materialDevelopments: [],
            nonMaterialDevelopments: [],
            reviewEscalationPosture: "Escalate to PM when concentration meaning changes.",
            updatedBy: "pm",
            updateSource: .pmControlPlane,
            createdAt: Date(timeIntervalSince1970: 1_720_100_200),
            updatedAt: Date(timeIntervalSince1970: 1_720_100_200)
        ),
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: [:],
        recentNews: [],
        now: Date(timeIntervalSince1970: 1_720_100_200)
    )

    #expect(evaluation.isMaterial)
    #expect(evaluation.concentrationSummary.contains("Single-name concentration is severe"))
    #expect(evaluation.clusteredRiskSummary.contains("Risk is clustered"))
    #expect(evaluation.longShortSummary.contains("Long-vs-short weighting"))
    #expect(evaluation.bookPostureSummary.contains("Current directional risk is primarily long-side"))
    #expect(evaluation.escalationDisposition >= .pmFollowUpWarranted)
}

@Test("Portfolio risk evaluator can classify near-threshold posture as worth monitoring without escalation")
func portfolioRiskEvaluatorSupportsWorthMonitoringDisposition() {
    let snapshot = makePortfolioRiskSnapshot(
        positions: [
            makePortfolioRiskPosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "19000"),
            makePortfolioRiskPosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "18000"),
            makePortfolioRiskPosition(symbol: "AAPL", qty: "100", side: "long", marketValue: "17000"),
            makePortfolioRiskPosition(symbol: "GOOG", qty: "100", side: "long", marketValue: "16000"),
            makePortfolioRiskPosition(symbol: "AMZN", qty: "100", side: "long", marketValue: "15000"),
            makePortfolioRiskPosition(symbol: "META", qty: "100", side: "long", marketValue: "15000")
        ]
    )

    let evaluation = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: snapshot,
        strategyBrief: PortfolioStrategyBrief(
            objectiveSummary: "Keep concentration tighter.",
            keyThemes: [],
            currentRiskPosture: "Conservative posture with tighter concentration control.",
            materialDevelopments: [],
            nonMaterialDevelopments: [],
            reviewEscalationPosture: "Escalate only when clearly warranted.",
            updatedBy: "pm",
            updateSource: .pmControlPlane,
            createdAt: Date(timeIntervalSince1970: 1_720_100_300),
            updatedAt: Date(timeIntervalSince1970: 1_720_100_300)
        ),
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: [:],
        recentNews: [],
        now: Date(timeIntervalSince1970: 1_720_100_300)
    )

    #expect(evaluation.matches.isEmpty)
    #expect(evaluation.escalationDisposition == .worthMonitoring)
    #expect(evaluation.isMaterial == false)
    #expect(evaluation.summary.contains("worth_monitoring"))
}

@Test("Portfolio risk trigger detects large move in a concentrated holding from prior review state")
func portfolioRiskTriggerDetectsLargeMoveInConcentratedHolding() {
    let snapshot = makePortfolioRiskSnapshot(
        positions: [
            makePortfolioRiskPosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "24000"),
            makePortfolioRiskPosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "76000")
        ],
        quotes: [
            "NVDA": MarketQuote(symbol: "NVDA", lastPrice: 240),
            "MSFT": MarketQuote(symbol: "MSFT", lastPrice: 380)
        ]
    )

    let evaluation = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: snapshot,
        strategyBrief: nil,
        previousObservedPricesBySymbol: ["NVDA": 200, "MSFT": 378],
        previousObservedWeightsBySymbol: ["NVDA": 0.20, "MSFT": 0.80],
        recentNews: [],
        now: Date(timeIntervalSince1970: 1_720_100_500)
    )

    #expect(evaluation.isMaterial)
    #expect(evaluation.matches.contains(where: {
        $0.kind == PortfolioRiskTriggerMatch.Kind.largeMoveInConcentratedHolding && $0.symbol == "NVDA"
    }))
    #expect(evaluation.rationale.contains("moved 20.0% up"))
    #expect(evaluation.whatChangedSinceReview.contains("NVDA is now up 20.0%"))
}

@Test("Portfolio risk trigger detects concentrated holding entering catalyst window")
func portfolioRiskTriggerDetectsCatalystWindowInConcentratedHolding() {
    let now = Date(timeIntervalSince1970: 1_720_100_700)
    let snapshot = makePortfolioRiskSnapshot(
        positions: [
            makePortfolioRiskPosition(symbol: "AAPL", qty: "100", side: "long", marketValue: "32000"),
            makePortfolioRiskPosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "68000")
        ]
    )
    let evaluation = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: snapshot,
        strategyBrief: nil,
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: ["AAPL": 0.20],
        recentNews: [
            makePortfolioRiskNewsEvent(
                eventId: "news-aapl-earnings",
                symbol: "AAPL",
                title: "Apple scheduled to report earnings next week",
                publishedAt: now.addingTimeInterval(-3_600)
            )
        ],
        now: now
    )

    #expect(evaluation.isMaterial)
    #expect(evaluation.matches.contains(where: {
        $0.kind == PortfolioRiskTriggerMatch.Kind.catalystWindowInConcentratedHolding && $0.symbol == "AAPL"
    }))
    #expect(evaluation.whatChangedSinceReview.contains("catalyst-window headline for AAPL"))
}

@Test("Portfolio risk catalyst pickup keeps a stable fingerprint for same-meaning repeated coverage")
func portfolioRiskCatalystPickupKeepsStableFingerprint() {
    let now = Date(timeIntervalSince1970: 1_720_100_750)
    let snapshot = makePortfolioRiskSnapshot(
        positions: [
            makePortfolioRiskPosition(symbol: "AAPL", qty: "100", side: "long", marketValue: "32000"),
            makePortfolioRiskPosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "68000")
        ]
    )

    let first = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: snapshot,
        strategyBrief: nil,
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: ["AAPL": 0.20],
        recentNews: [
            makePortfolioRiskNewsEvent(
                eventId: "news-aapl-earnings-1",
                symbol: "AAPL",
                title: "Apple scheduled to report earnings next week",
                publishedAt: now.addingTimeInterval(-7_200)
            )
        ],
        now: now
    )
    let second = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: snapshot,
        strategyBrief: nil,
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: ["AAPL": 0.20],
        recentNews: [
            makePortfolioRiskNewsEvent(
                eventId: "news-aapl-earnings-2",
                symbol: "AAPL",
                title: "Apple to report earnings next week as guidance focus rises",
                publishedAt: now.addingTimeInterval(-3_600)
            )
        ],
        now: now
    )

    #expect(first.isMaterial)
    #expect(second.isMaterial)
    #expect(first.triggerFingerprint == second.triggerFingerprint)
}

@Test("Portfolio risk catalyst trigger stays quiet without a near-term catalyst headline")
func portfolioRiskTriggerKeepsCatalystWindowQuietWithoutCatalystHeadline() {
    let now = Date(timeIntervalSince1970: 1_720_100_800)
    let snapshot = makePortfolioRiskSnapshot(
        positions: [
            makePortfolioRiskPosition(symbol: "AAPL", qty: "100", side: "long", marketValue: "32000"),
            makePortfolioRiskPosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "68000")
        ]
    )
    let evaluation = PortfolioRiskTriggerEvaluator.evaluate(
        snapshot: snapshot,
        strategyBrief: nil,
        previousObservedPricesBySymbol: [:],
        previousObservedWeightsBySymbol: ["AAPL": 0.20],
        recentNews: [
            makePortfolioRiskNewsEvent(
                eventId: "news-aapl-product",
                symbol: "AAPL",
                title: "Apple expands product rollout",
                publishedAt: now.addingTimeInterval(-3_600)
            )
        ],
        now: now
    )

    #expect(evaluation.matches.contains(where: {
        $0.kind == PortfolioRiskTriggerMatch.Kind.catalystWindowInConcentratedHolding
    }) == false)
}

@Test("Portfolio risk trigger review state store round-trips and supports raw-object fallback")
func portfolioRiskTriggerReviewStateStoreRoundTrips() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("portfolio-risk-trigger-state-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = PortfolioRiskTriggerReviewStateStore(fileURL: fileURL)
    let now = Date(timeIntervalSince1970: 1_720_101_000)
    let saved = try await store.save(
        PortfolioRiskTriggerReviewState(
            lastObservedPricesBySymbol: ["NVDA": 201.5],
            lastObservedWeightsBySymbol: ["NVDA": 0.27],
            activeTriggerFingerprint: "portfolio-risk-trigger-nvda",
            lastReviewedAt: now,
            lastReviewSource: .automaticTrigger,
            lastReviewSummary: "bounded portfolio-risk review",
            lastRunAt: now,
            updatedAt: now
        )
    )
    #expect(saved.activeTriggerFingerprint == "portfolio-risk-trigger-nvda")
    #expect(await store.load()?.lastObservedPricesBySymbol["NVDA"] == 201.5)
    #expect(await store.load()?.lastObservedWeightsBySymbol["NVDA"] == 0.27)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let raw = Data(
        """
        {
          "stateId":"\(PortfolioRiskTriggerReviewState.stateID)",
          "lastObservedPricesBySymbol":{"MSFT":402},
          "activeTriggerFingerprint":null,
          "lastRunAt":"\(formatter.string(from: now))",
          "updatedAt":"\(formatter.string(from: now))"
        }
        """.utf8
    )
    try raw.write(to: fileURL, options: Data.WritingOptions.atomic)

    let reloaded = PortfolioRiskTriggerReviewStateStore(fileURL: fileURL)
    #expect(await reloaded.load()?.lastObservedPricesBySymbol["MSFT"] == 402.0)
    #expect(await reloaded.load()?.lastObservedWeightsBySymbol.isEmpty == true)
    #expect(await reloaded.load()?.lastReviewSource == nil)
}

@Test("Portfolio risk analyst job stays quiet when no bounded trigger is material")
func portfolioRiskAnalystJobStaysQuiet() async throws {
    let tempRoot = makePortfolioRiskTempDirectory(name: "portfolio-risk-quiet")
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false))
    let reviewStateStore = PortfolioRiskTriggerReviewStateStore(fileURL: tempRoot.appendingPathComponent("portfolio-risk-review-state.json", isDirectory: false))
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true))
    let engine = Engine(
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        portfolioRiskTriggerReviewStateStore: reviewStateStore,
        replaySleep: { _ in }
    )
    await engine.store.applyPositionsRefreshSnapshot(
        positions: [
            try portfolioRiskDecodePosition(symbol: "AAPL", qty: "10", side: "long", marketValue: "9000"),
            try portfolioRiskDecodePosition(symbol: "MSFT", qty: "20", side: "long", marketValue: "11000"),
            try portfolioRiskDecodePosition(symbol: "GOOG", qty: "20", side: "long", marketValue: "10000"),
            try portfolioRiskDecodePosition(symbol: "AMZN", qty: "20", side: "long", marketValue: "10000")
        ],
        account: Account(id: "acct-quiet", equity: "100000")
    )

    let job = try await engine.submitJob(
        type: .portfolioRiskAnalyst,
        parameters: [:],
        source: .engine
    )
    let completed = try await waitForPortfolioRiskJob(engine: engine, jobID: job.jobId)

    #expect(completed.status == .succeeded)
    #expect(completed.result?.objectValue?["materialImpact"] == .bool(false))
    #expect(try await engine.listAnalystMemos().isEmpty)
    #expect(try await engine.listPMDecisions().isEmpty)
    #expect(try await engine.listPMDelegations().isEmpty)
    #expect(await reviewStateStore.load()?.lastRunAt != nil)
    await engine.stop()
}

@Test("Portfolio risk analyst job escalates material trigger once and suppresses duplicate rerun")
func portfolioRiskAnalystJobEscalatesMaterialTriggerOnce() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []
        func record(_ request: AnalystWorkerLaunchRequest) { requests.append(request) }
        func all() -> [AnalystWorkerLaunchRequest] { requests }
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
                memoId: "memo-portfolio-risk-1",
                analystId: "bench-overlay-portfolio-risk-analyst",
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: "finding-portfolio-risk-1",
                evidenceBundleId: "bundle-portfolio-risk-1",
                title: "Portfolio risk review: NVDA",
                executiveSummary: "Bounded portfolio-risk trigger conditions crossed threshold and warrant PM review.",
                currentView: "NVDA is a concentrated holding under the current portfolio posture.",
                evidenceSummary: "Primary support comes from app-owned portfolio state and bounded trigger evaluation.",
                uncertaintySummary: "This remains an advisory PM-layer overlay review.",
                recommendedNextStep: "PM should review whether the trigger stays monitor-only or needs deeper overlay follow-up.",
                confidence: 0.7,
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
                findingId: "finding-portfolio-risk-1",
                findingTitle: "Portfolio risk review",
                draftedSignalId: nil,
                runtimeProvenance: runtimeProvenance,
                summary: "memo: \(memo.title)",
                outputExcerpt: memo.executiveSummary
            )
        }
    }

    let tempRoot = makePortfolioRiskTempDirectory(name: "portfolio-risk-material")
    let pmProfileStore = PMProfileStore(profilesDirectory: tempRoot.appendingPathComponent("pm-profiles", isDirectory: true))
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystCharterStore = AnalystCharterStore(chartersDirectory: tempRoot.appendingPathComponent("charters", isDirectory: true))
    let analystTaskStore = AnalystTaskStore(tasksDirectory: tempRoot.appendingPathComponent("tasks", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false))
    let reviewStateStore = PortfolioRiskTriggerReviewStateStore(fileURL: tempRoot.appendingPathComponent("portfolio-risk-review-state.json", isDirectory: false))
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_720_102_000)

    _ = try await pmProfileStore.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Supervises analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await strategyBriefStore.upsert(
        PortfolioStrategyBrief(
            objectiveSummary: "Keep concentration breaches visible for PM review.",
            keyThemes: ["Concentration discipline"],
            currentRiskPosture: "Moderate risk posture with tighter review on oversized single-name exposure.",
            materialDevelopments: ["single-name concentration"],
            nonMaterialDevelopments: ["small incremental sizing"],
            reviewEscalationPosture: "Escalate to PM review first; no direct execution authority.",
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        newsStore: NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true)),
        pmProfileStore: pmProfileStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystCharterStore: analystCharterStore,
        analystTaskStore: analystTaskStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        portfolioRiskTriggerReviewStateStore: reviewStateStore,
        analystWorkerLauncher: StubLauncher(recorder: recorder, memoStore: analystMemoStore, now: now),
        nowDate: { now },
        replaySleep: { _ in }
    )
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try portfolioRiskDecodePosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "35000"),
        try portfolioRiskDecodePosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "15000")
    ])

    let firstJob = try await engine.submitJob(
        type: .portfolioRiskAnalyst,
        parameters: ["pmId": .string("pm-1")],
        source: .engine
    )
    let firstCompleted = try await waitForPortfolioRiskJob(engine: engine, jobID: firstJob.jobId)

    #expect(firstCompleted.status == .succeeded)
    #expect(firstCompleted.result?.objectValue?["materialImpact"] == .bool(true))
    #expect(firstCompleted.result?.objectValue?["escalated"] == .bool(true))
    #expect(await recorder.all().count == 1)
    #expect(try await engine.listAnalystMemos().count == 1)
    #expect(try await engine.listPMDecisions().count == 1)
    #expect(try await engine.listPMDelegations().count == 1)
    let tasks = try await engine.listAnalystTasks()
    let escalatedTask = try #require(tasks.first(where: { $0.taskId.hasPrefix("portfolio-risk-task-") }))
    #expect(escalatedTask.description.contains("Coverage posture:"))
    #expect(escalatedTask.description.contains("Concentration posture:"))
    #expect(escalatedTask.description.contains("Clustered risk view:"))
    #expect(escalatedTask.description.contains("Long-vs-short posture:"))
    #expect(escalatedTask.description.contains("Escalation posture:"))
    #expect(escalatedTask.description.contains("Risk framework guidance:"))
    #expect(escalatedTask.description.contains("gross exposure, net exposure, long exposure, short exposure"))
    #expect(escalatedTask.description.contains("20-25% in a moderate posture"))
    #expect(escalatedTask.description.contains("Why now:"))
    #expect(escalatedTask.description.contains("Current book posture:"))

    let secondJob = try await engine.submitJob(
        type: .portfolioRiskAnalyst,
        parameters: ["pmId": .string("pm-1")],
        source: .engine
    )
    let secondCompleted = try await waitForPortfolioRiskJob(engine: engine, jobID: secondJob.jobId)

    #expect(secondCompleted.status == .succeeded)
    #expect(secondCompleted.result?.objectValue?["duplicateSuppressed"] == .bool(true))
    #expect(await recorder.all().count == 1)
    #expect(try await engine.listAnalystMemos().count == 1)
    #expect(try await engine.listPMDecisions().count == 1)
    #expect(try await engine.listPMDelegations().count == 1)
    #expect(await reviewStateStore.load()?.activeTriggerFingerprint != nil)
    await engine.stop()
}

@Test("Portfolio risk analyst re-wakes when concentration severity worsens materially")
func portfolioRiskAnalystReWakesWhenConcentrationSeverityWorsens() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []
        func record(_ request: AnalystWorkerLaunchRequest) { requests.append(request) }
        func all() -> [AnalystWorkerLaunchRequest] { requests }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder
        let memoStore: AnalystMemoStore
        let now: Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            let runtimeProvenance = AnalystRuntimeProvenance(
                actualRuntimeIdentifier: "deterministic_local",
                launchedAt: now
            )
            let memo = AnalystMemo(
                memoId: "memo-\(request.delegationId ?? UUID().uuidString)",
                analystId: "bench-overlay-portfolio-risk-analyst",
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                title: "Portfolio risk review",
                executiveSummary: "Bounded portfolio-risk trigger conditions crossed threshold and warrant PM review.",
                currentView: "Portfolio Risk sees concentration that now needs PM attention.",
                evidenceSummary: "Primary support comes from app-owned portfolio state and bounded trigger evaluation.",
                uncertaintySummary: "This remains an advisory PM-layer overlay review.",
                recommendedNextStep: "Review whether the exposure now needs another overlay follow-up.",
                confidence: 0.7,
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
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                runtimeProvenance: runtimeProvenance,
                summary: "memo: \(memo.title)",
                outputExcerpt: memo.executiveSummary
            )
        }
    }

    let tempRoot = makePortfolioRiskTempDirectory(name: "portfolio-risk-rewake")
    let now = Date(timeIntervalSince1970: 1_720_103_000)
    let pmProfileStore = PMProfileStore(profilesDirectory: tempRoot.appendingPathComponent("pm-profiles", isDirectory: true))
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystCharterStore = AnalystCharterStore(chartersDirectory: tempRoot.appendingPathComponent("charters", isDirectory: true))
    let analystTaskStore = AnalystTaskStore(tasksDirectory: tempRoot.appendingPathComponent("tasks", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false))
    let reviewStateStore = PortfolioRiskTriggerReviewStateStore(fileURL: tempRoot.appendingPathComponent("portfolio-risk-review-state.json", isDirectory: false))
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true))

    _ = try await pmProfileStore.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Supervises analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await strategyBriefStore.upsert(
        PortfolioStrategyBrief(
            objectiveSummary: "Keep concentration breaches visible for PM review.",
            currentRiskPosture: "Moderate risk posture with tighter review on oversized single-name exposure.",
            reviewEscalationPosture: "Escalate to PM review first; no direct execution authority.",
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        pmProfileStore: pmProfileStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystCharterStore: analystCharterStore,
        analystTaskStore: analystTaskStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        portfolioRiskTriggerReviewStateStore: reviewStateStore,
        analystWorkerLauncher: StubLauncher(recorder: recorder, memoStore: analystMemoStore, now: now),
        nowDate: { now },
        replaySleep: { _ in }
    )

    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try portfolioRiskDecodePosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "30000"),
        try portfolioRiskDecodePosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "70000")
    ])
    let firstJob = try await engine.submitJob(
        type: .portfolioRiskAnalyst,
        parameters: ["pmId": .string("pm-1")],
        source: .engine
    )
    let firstCompleted = try await waitForPortfolioRiskJob(engine: engine, jobID: firstJob.jobId)
    #expect(firstCompleted.result?.objectValue?["escalated"] == .bool(true))
    #expect(await recorder.all().count == 1)

    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try portfolioRiskDecodePosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "42000"),
        try portfolioRiskDecodePosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "58000")
    ])
    let secondJob = try await engine.submitJob(
        type: .portfolioRiskAnalyst,
        parameters: ["pmId": .string("pm-1")],
        source: .engine
    )
    let secondCompleted = try await waitForPortfolioRiskJob(engine: engine, jobID: secondJob.jobId)

    #expect(secondCompleted.result?.objectValue?["escalated"] == .bool(true))
    #expect(secondCompleted.result?.objectValue?["duplicateSuppressed"] != JSONValue.bool(true))
    #expect(await recorder.all().count == 2)
    #expect(try await engine.listPMDecisions().count == 2)
    await engine.stop()
}

@Test("Ad hoc Portfolio Risk review refreshes the automatic trigger anchor and suppresses stale re-wake")
func portfolioRiskAdHocReviewRefreshesAutomaticTriggerAnchor() async throws {
    struct StubLauncher: AnalystWorkerLaunching {
        let memoStore: AnalystMemoStore
        let now: Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            let runtimeProvenance = AnalystRuntimeProvenance(
                actualRuntimeIdentifier: "deterministic_local",
                launchedAt: now
            )
            let memo = AnalystMemo(
                memoId: "memo-manual-risk-review",
                analystId: "bench-overlay-portfolio-risk-analyst",
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                title: "Portfolio risk review: manual",
                executiveSummary: "Portfolio Risk completed an ad hoc PM-requested review.",
                currentView: "The same bounded concentration issue remains in scope for PM review.",
                evidenceSummary: "Primary support comes from app-owned positions and bounded trigger evaluation.",
                uncertaintySummary: "This remains advisory only.",
                recommendedNextStep: "Keep monitoring unless something materially changes.",
                confidence: 0.72,
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
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                runtimeProvenance: runtimeProvenance,
                summary: "memo: \(memo.title)",
                outputExcerpt: memo.executiveSummary
            )
        }
    }

    let tempRoot = makePortfolioRiskTempDirectory(name: "portfolio-risk-manual-anchor")
    let now = Date(timeIntervalSince1970: 1_720_104_000)
    let pmProfileStore = PMProfileStore(profilesDirectory: tempRoot.appendingPathComponent("pm-profiles", isDirectory: true))
    let pmDelegationStore = PMDelegationStore(delegationsDirectory: tempRoot.appendingPathComponent("pm-delegations", isDirectory: true))
    let pmDecisionStore = PMDecisionStore(decisionsDirectory: tempRoot.appendingPathComponent("pm-decisions", isDirectory: true))
    let analystCharterStore = AnalystCharterStore(chartersDirectory: tempRoot.appendingPathComponent("charters", isDirectory: true))
    let analystTaskStore = AnalystTaskStore(tasksDirectory: tempRoot.appendingPathComponent("tasks", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: tempRoot.appendingPathComponent("memos", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(fileURL: tempRoot.appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false))
    let reviewStateStore = PortfolioRiskTriggerReviewStateStore(fileURL: tempRoot.appendingPathComponent("portfolio-risk-review-state.json", isDirectory: false))
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: tempRoot.appendingPathComponent("memory", isDirectory: true))

    _ = try await pmProfileStore.upsert(
        PMProfile(
            pmId: "pm-1",
            displayName: "Primary PM",
            roleSummary: "Supervises analyst work.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await strategyBriefStore.upsert(
        PortfolioStrategyBrief(
            objectiveSummary: "Keep concentration breaches visible for PM review.",
            currentRiskPosture: "Moderate risk posture with tighter review on oversized single-name exposure.",
            reviewEscalationPosture: "Escalate to PM review first; no direct execution authority.",
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )

    let portfolioRiskCharter = AnalystCharter(
        charterId: "bench-overlay-portfolio-risk",
        analystId: "bench-overlay-portfolio-risk-analyst",
        title: "Portfolio Risk Analyst",
        coverageScope: "Cross-portfolio overlay risk review.",
        strategyFamily: "standing overlay bench",
        summary: "Bounded portfolio-risk overlay analyst.",
        benchRole: .overlay,
        duties: ["Review bounded concentration and event risk."],
        constraints: ["No trade authority"],
        expectedOutputs: ["finding", "memo"],
        allowedSources: ["app-owned state"],
        createdAt: now,
        updatedAt: now
    )
    _ = try await analystCharterStore.upsert(portfolioRiskCharter)

    let manualTask = AnalystTask(
        taskId: "manual-portfolio-risk-task",
        analystId: portfolioRiskCharter.analystId,
        charterId: portfolioRiskCharter.charterId,
        title: "Manual portfolio risk review",
        description: "Review bounded portfolio-risk trigger conditions for potential PM escalation.",
        status: .queued,
        createdAt: now,
        updatedAt: now,
        symbols: ["NVDA"]
    )
    _ = try await analystTaskStore.upsert(manualTask)
    _ = try await pmDelegationStore.upsert(
        PMDelegationRecord(
            delegationId: "manual-risk-review-1",
            pmId: "pm-1",
            analystId: portfolioRiskCharter.analystId,
            charterId: portfolioRiskCharter.charterId,
            taskId: manualTask.taskId,
            title: manualTask.title,
            rationale: "PM wants an ad hoc overlay risk review.",
            requestedOutputs: [.finding],
            status: .issued,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(
        pmProfileStore: pmProfileStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDecisionStore: pmDecisionStore,
        pmDelegationStore: pmDelegationStore,
        analystCharterStore: analystCharterStore,
        analystTaskStore: analystTaskStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: memoryStore,
        portfolioRiskTriggerReviewStateStore: reviewStateStore,
        analystWorkerLauncher: StubLauncher(memoStore: analystMemoStore, now: now),
        nowDate: { now },
        replaySleep: { _ in }
    )
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try portfolioRiskDecodePosition(symbol: "NVDA", qty: "100", side: "long", marketValue: "35000"),
        try portfolioRiskDecodePosition(symbol: "MSFT", qty: "100", side: "long", marketValue: "65000")
    ])

    _ = try await engine.launchAnalystWorkerForPMDelegation(
        delegationID: "manual-risk-review-1",
        source: AuditEventSource.ui
    )
    let anchoredState = try #require(await reviewStateStore.load())
    #expect(anchoredState.lastReviewSource == .pmInvocation)
    #expect(anchoredState.lastReviewSummary?.contains("ad hoc PM-invoked") == true)
    #expect(anchoredState.activeTriggerFingerprint != nil)

    let autoJob = try await engine.submitJob(
        type: JobType.portfolioRiskAnalyst,
        parameters: ["pmId": JSONValue.string("pm-1")],
        source: AuditEventSource.engine
    )
    let completed = try await waitForPortfolioRiskJob(engine: engine, jobID: autoJob.jobId)

    #expect(completed.result?.objectValue?["duplicateSuppressed"] == JSONValue.bool(true))
    #expect(try await engine.listAnalystMemos().count == 1)
    #expect(try await engine.listPMDecisions().isEmpty)
    #expect(try await engine.listPMDelegations().count == 1)
    await engine.stop()
}

@Test("ScheduleStore seeds disabled portfolio risk analyst default schedule")
func scheduleStoreSeedsDisabledPortfolioRiskAnalystDefaultSchedule() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("schedule-store-portfolio-risk-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedules = try await store.seedDefaultsIfStoreMissing()
    let schedule = try #require(schedules.first(where: { $0.jobType == .portfolioRiskAnalyst }))
    #expect(schedule.scheduleId == "default-portfolio-risk-analyst")
    #expect(schedule.enabled == false)
    #expect(schedule.trigger.intervalSec == 900)
    #expect(schedule.policy.startupBehavior == .waitForInterval)
}

private func waitForPortfolioRiskJob(
    engine: Engine,
    jobID: String,
    retries: Int = 1_200
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

private func makePortfolioRiskTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePortfolioRiskPosition(symbol: String, qty: String, side: String, marketValue: String) -> PositionRow {
    PositionRow(id: symbol, symbol: symbol, side: side, qty: qty, marketValue: marketValue)
}

private func portfolioRiskDecodePosition(symbol: String, qty: String, side: String, marketValue: String) throws -> Position {
    try JSONDecoder().decode(
        Position.self,
        from: Data(
            """
            {"symbol":"\(symbol)","qty":"\(qty)","side":"\(side)","marketValue":"\(marketValue)"}
            """.utf8
        )
    )
}

private func makePortfolioRiskSnapshot(
    positions: [PositionRow],
    quotes: [String: MarketQuote] = [:]
) -> StoreSnapshot {
    StoreSnapshot(
        build: "test",
        positions: positions,
        quotesBySymbol: quotes
    )
}

private func makePortfolioRiskNewsEvent(
    eventId: String,
    symbol: String,
    title: String,
    publishedAt: Date,
    summary: String? = nil
) -> NewsEvent {
    NewsEvent(
        eventId: eventId,
        source: "test",
        title: title,
        publishedAt: publishedAt,
        receivedAt: publishedAt,
        summary: summary,
        rawSymbolHints: [symbol]
    )
}
