import Foundation
import Testing
@testable import TradingKit

@Test("Scoring engine output is deterministic for fixed inputs")
func scoringEngineDeterministic() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let snapshot = StoreSnapshot(
        build: "test",
        watchlistSymbols: ["AAPL"],
        quotesBySymbol: [
            "AAPL": MarketQuote(
                symbol: "AAPL",
                instrumentType: .equity,
                bidPrice: 100,
                askPrice: 101,
                lastPrice: 101,
                timestamp: "2023-11-14T00:00:00Z"
            )
        ]
    )
    let news = [
        NewsEvent(
            eventId: "evt-1",
            source: "rss_fed",
            title: "AAPL demand outlook improves",
            url: "https://example.com/aapl",
            publishedAt: now.addingTimeInterval(-1800),
            receivedAt: now,
            summary: "AAPL momentum mention",
            rawSymbolHints: ["AAPL"],
            tags: ["macro"],
            payloadVersion: 1
        )
    ]
    let input = SignalScoringInput(
        recentNews: news,
        snapshot: snapshot,
        now: now,
        sourceJobId: "job-1",
        scoringVersion: "v1",
        draftThreshold: 0.5
    )
    let engine = DefaultScoringEngine()
    let first = engine.generateSignals(input: input)
    let second = engine.generateSignals(input: input)
    #expect(first == second)
    #expect(first.count == 1)
    #expect(first.first?.symbols == ["AAPL"])
}

@Test("SignalStore supports v0 fallback and resilient diagnostics")
func signalStoreLegacyAndDiagnostics() async throws {
    let tempRoot = makeTempDirectory(name: "signal-store")
    let store = SignalStore(signalsDirectory: tempRoot)

    let legacy = Signal(
        signalId: "sig-legacy",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_001),
        status: .new,
        symbols: ["AAPL"],
        direction: .bullish,
        horizon: .intraday,
        confidence: 0.6,
        score: 0.6,
        positionStatement: "Legacy signal",
        recommendedAction: .notifyOnly,
        evidence: [],
        provenance: SignalProvenance(sourceJobId: "job-1", scoringVersion: "v1")
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let legacyData = try encoder.encode(legacy)
    try legacyData.write(to: tempRoot.appendingPathComponent("legacy.json"))

    let unknown = """
    {"schemaVersion":99,"signal":{"signalId":"sig-unknown"}}
    """
    try Data(unknown.utf8).write(to: tempRoot.appendingPathComponent("unknown.json"))
    try Data("{bad-json}".utf8).write(to: tempRoot.appendingPathComponent("corrupt.json"))

    let signals = try await store.loadAll()
    #expect(signals.count == 1)
    #expect(signals.first?.signalId == "sig-legacy")
    #expect(signals.first?.linkedProposalId == nil)

    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("PM and owner surfaces suppress clearly stale placeholder testing signals without deleting live ones")
func pmOwnerSurfaceSignalSuppressionStaysNarrow() {
    let now = Date(timeIntervalSince1970: 1_775_000_000)
    let staleTestingSignal = Signal(
        signalId: "sig-finding-1",
        createdAt: now.addingTimeInterval(-60 * 24 * 60 * 60),
        updatedAt: now,
        status: .new,
        symbols: ["AAPL"],
        direction: .bullish,
        horizon: .swing,
        confidence: 0.72,
        score: 0.72,
        positionStatement: "Large-cap tech may benefit.",
        recommendedAction: .notifyOnly,
        evidence: [],
        provenance: SignalProvenance(
            sourceJobId: "analyst.finding_draft",
            scoringVersion: "analyst-finding-v1",
            analystId: "macro-analyst",
            charterId: "charter-1",
            taskId: "task-1",
            sourceFindingId: "finding-1",
            sourceEvidenceBundleId: "bundle-1"
        ),
        originatingFindingId: "finding-1"
    )
    let liveSignal = Signal(
        signalId: "sig-live-1",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["NVDA"],
        direction: .bullish,
        horizon: .swing,
        confidence: 0.81,
        score: 0.81,
        positionStatement: "technology infrastructure demand remains constructive.",
        recommendedAction: .notifyOnly,
        evidence: [],
        provenance: SignalProvenance(
            sourceJobId: "analyst.finding_draft",
            scoringVersion: "analyst-finding-v1",
            analystId: "technology-analyst",
            charterId: "charter-technology-research",
            taskId: "task-42",
            sourceFindingId: "finding-tech-42",
            sourceEvidenceBundleId: "bundle-tech-42"
        ),
        originatingFindingId: "finding-tech-42"
    )

    #expect(isSuppressedPMTestingSignal(staleTestingSignal, now: now))
    #expect(isSuppressedPMTestingSignal(liveSignal, now: now) == false)

    let snapshot = makePMCommandCenterSnapshot(
        delegations: [],
        charters: [],
        tasks: [],
        approvalRequests: [],
        decisions: [],
        standingReports: [],
        jobs: [],
        signals: [staleTestingSignal, liveSignal],
        proposals: []
    )
    #expect(snapshot.newSignalsCount == 0)
    #expect(snapshot.fyiSignalsCount == 1)
}

@Test("Signal actionability separates proposal candidates from notify-only FYI alerts")
func signalActionabilitySeparatesReviewFromFYI() {
    let now = Date(timeIntervalSince1970: 1_775_000_100)
    let proposalCandidate = Signal(
        signalId: "sig-proposal-candidate",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["NVDA"],
        direction: .bullish,
        horizon: .swing,
        confidence: 0.84,
        score: 0.88,
        positionStatement: "Directional high-confidence signal.",
        recommendedAction: .draftProposal,
        evidence: [],
        provenance: SignalProvenance(sourceJobId: "analyst_signals", scoringVersion: "v1")
    )
    let notifyOnly = Signal(
        signalId: "sig-notify-only",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["AAPL"],
        direction: .neutral,
        horizon: .swing,
        confidence: 0.42,
        score: 0.42,
        positionStatement: "Neutral low-confidence background item.",
        recommendedAction: .notifyOnly,
        evidence: [],
        provenance: SignalProvenance(sourceJobId: "analyst.finding_draft", scoringVersion: "v1")
    )
    let acknowledged = Signal(
        signalId: "sig-ack",
        createdAt: now,
        updatedAt: now,
        status: .acknowledged,
        symbols: ["MSFT"],
        direction: .bullish,
        horizon: .swing,
        confidence: 0.91,
        score: 0.91,
        positionStatement: "Already reviewed.",
        recommendedAction: .draftProposal,
        evidence: [],
        provenance: SignalProvenance(sourceJobId: "analyst_signals", scoringVersion: "v1")
    )

    #expect(proposalCandidate.actionability == .proposalCandidate)
    #expect(proposalCandidate.countsAsOwnerFacingSignalReview)
    #expect(notifyOnly.actionability == .notifyOnly)
    #expect(notifyOnly.countsAsOwnerFacingSignalReview == false)
    #expect(notifyOnly.countsAsFYIResearchAlert)
    #expect(acknowledged.actionability == .closed)
    #expect(acknowledged.countsAsOwnerFacingSignalReview == false)

    let snapshot = makePMCommandCenterSnapshot(
        delegations: [],
        charters: [],
        tasks: [],
        approvalRequests: [],
        decisions: [],
        signals: [proposalCandidate, notifyOnly, acknowledged],
        proposals: []
    )
    #expect(snapshot.newSignalsCount == 1)
    #expect(snapshot.fyiSignalsCount == 1)
}

@Test("Signal readable lineage resolves linked task finding and evidence labels")
func signalReadableLineageResolvesLinkedArtifacts() {
    let now = Date(timeIntervalSince1970: 1_775_000_200)
    let charter = AnalystCharter(
        charterId: "charter-tech",
        analystId: "technology-analyst",
        title: "Technology Analyst",
        coverageScope: "Technology",
        strategyFamily: "equity",
        summary: "Technology coverage",
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-tech-nvda",
        analystId: "technology-analyst",
        charterId: charter.charterId,
        title: "Technology Analyst NVDA review",
        description: "Review NVDA.",
        status: .completed,
        createdAt: now,
        updatedAt: now,
        symbols: ["NVDA"]
    )
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-nvda",
        analystId: "technology-analyst",
        charterId: charter.charterId,
        taskId: task.taskId,
        refs: [
            AnalystEvidenceRef(
                refId: "ref-1",
                sourceKind: .appNews,
                title: "NVDA official update",
                observedAt: now,
                summary: "Primary source context."
            )
        ],
        summary: "Evidence bundle summary.",
        createdAt: now,
        updatedAt: now
    )
    let finding = AnalystFinding(
        findingId: "finding-nvda",
        analystId: "technology-analyst",
        charterId: charter.charterId,
        taskId: task.taskId,
        title: "NVDA finding",
        summary: "Name-specific confirmation remains incomplete.",
        thesis: "Constructive but not decisive.",
        symbols: ["NVDA"],
        confidence: 0.42,
        evidenceBundleId: bundle.bundleId,
        createdAt: now,
        updatedAt: now
    )
    let signal = Signal(
        signalId: "sig-nvda",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["NVDA"],
        direction: .neutral,
        horizon: .swing,
        confidence: 0.42,
        score: 0.42,
        positionStatement: "Neutral NVDA signal.",
        recommendedAction: .notifyOnly,
        evidence: [],
        provenance: SignalProvenance(
            sourceJobId: "analyst.finding_draft",
            scoringVersion: "v1",
            analystId: "technology-analyst",
            charterId: charter.charterId,
            taskId: task.taskId,
            sourceFindingId: finding.findingId,
            sourceEvidenceBundleId: bundle.bundleId
        ),
        originatingFindingId: finding.findingId
    )

    let presentation = makeSignalLineageReadablePresentation(
        signal: signal,
        charters: [charter],
        tasks: [task],
        findings: [finding],
        evidenceBundles: [bundle]
    )

    #expect(presentation?.charterLabel == "Technology Analyst")
    #expect(presentation?.taskLabel.contains("Technology Analyst NVDA review") == true)
    #expect(presentation?.findingLabel.contains("NVDA finding") == true)
    #expect(presentation?.evidenceLabel.contains("NVDA official update") == true)
    #expect(presentation?.technicalRefs.contains(where: { $0.value == "task-tech-nvda" }) == true)
}

@Test("PM signal truth summary grounds signal readback on app-owned actionability")
func pmSignalTruthSummaryGroundsReadback() {
    let now = Date(timeIntervalSince1970: 1_775_000_300)
    let signal = Signal(
        signalId: "sig-fyi",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["NVDA"],
        direction: .neutral,
        horizon: .swing,
        confidence: 0.42,
        score: 0.42,
        positionStatement: "Neutral low-confidence analyst-originated signal.",
        recommendedAction: .notifyOnly,
        evidence: [],
        provenance: SignalProvenance(sourceJobId: "analyst.finding_draft", scoringVersion: "v1")
    )

    let lines = makePMConversationSignalTruthSummary(
        ask: "What are these new signals and are any actionable?",
        signals: [signal],
        now: now
    )

    #expect(lines.joined(separator: "\n").contains("FYI/monitor-only/PM-review"))
    #expect(lines.joined(separator: "\n").contains("actionability=notify_only"))
    #expect(lines.joined(separator: "\n").contains("not owner decisions"))
}

@Test("analyst_signals job creates deduped signals and drafts proposals without approval")
func analystSignalsJobTickDraftsProposal() async throws {
    let tempRoot = makeTempDirectory(name: "analyst-signals-job")
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let proposalStore = ProposalStore(proposalsDirectory: tempRoot.appendingPathComponent("proposals", isDirectory: true))
    let signalStore = SignalStore(signalsDirectory: tempRoot.appendingPathComponent("signals", isDirectory: true))
    let jobStore = JobStore(jobsDirectory: tempRoot.appendingPathComponent("jobs", isDirectory: true))

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "evt-1",
            source: "rss_fed",
            title: "AAPL breaks higher on policy headline",
            url: "https://example.com/aapl",
            publishedAt: now,
            receivedAt: now,
            summary: "AAPL momentum mention",
            rawSymbolHints: ["AAPL"],
            tags: ["macro"],
            payloadVersion: 1
        )
    ])

    let engine = Engine(
        newsStore: newsStore,
        signalStore: signalStore,
        proposalStore: proposalStore,
        jobStore: jobStore,
        nowDate: { now }
    )

    let params: [String: JSONValue] = [
        "maxTicks": .number(2),
        "pollIntervalSec": .number(1),
        "lookbackMinutes": .number(240),
        "minScoreThreshold": .number(0),
        "mode": .string("draft_proposals"),
        "strategyIdForDrafts": .string("heartbeat")
    ]
    let job = try await engine.submitJob(
        type: JobType.analystSignals,
        parameters: params,
        source: AuditEventSource.engine
    )
    let finished = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(finished.status == JobStatus.succeeded)

    let signals = try await engine.listSignals(limit: 10)
    #expect(signals.count == 1)
    let signal = try #require(signals.first)
    #expect(signal.draftedProposalId != nil)
    #expect(signal.linkedProposalId == signal.draftedProposalId)

    let proposalID = try #require(signal.draftedProposalId)
    let proposal = try await engine.getProposal(id: proposalID)
    #expect(proposal?.approval.status == .draft)
    #expect(proposal?.originatingSignalId == signal.signalId)
    await engine.stop()
}

@Test("draftProposalFromSignal links signal proposal and proposal origin fields")
func draftProposalFromSignalLinksTraceability() async throws {
    let tempRoot = makeTempDirectory(name: "signal-proposal-link")
    let proposalStore = ProposalStore(proposalsDirectory: tempRoot.appendingPathComponent("proposals", isDirectory: true))
    let signalStore = SignalStore(signalsDirectory: tempRoot.appendingPathComponent("signals", isDirectory: true))

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let engine = Engine(
        signalStore: signalStore,
        proposalStore: proposalStore,
        nowDate: { now }
    )

    let signal = Signal(
        signalId: "sig-link",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["AAPL"],
        direction: .bullish,
        horizon: .intraday,
        confidence: 0.8,
        score: 0.8,
        positionStatement: "AAPL momentum signal",
        recommendedAction: .draftProposal,
        evidence: [
            SignalEvidenceRef(type: .news, id: "evt-1", url: nil, title: "AAPL momentum", summary: nil, timestamp: now)
        ],
        provenance: SignalProvenance(sourceJobId: "job-1", scoringVersion: "v1")
    )
    _ = try await signalStore.upsert(signal)

    let proposal = try await engine.draftProposalFromSignal(
        id: signal.signalId,
        strategyID: "heartbeat",
        source: AuditEventSource.ui
    )

    #expect(proposal.originatingSignalId == signal.signalId)

    let storedSignal = try await engine.getSignal(id: signal.signalId)
    #expect(storedSignal.draftedProposalId == proposal.proposalId)
    #expect(storedSignal.linkedProposalId == proposal.proposalId)
    await engine.stop()
}

@Test("draftProposalFromAnalystSignal preserves analyst lineage and leaves approval in draft")
func draftProposalFromAnalystSignalPreservesLineage() async throws {
    let tempRoot = makeTempDirectory(name: "analyst-signal-proposal-link")
    let proposalStore = ProposalStore(proposalsDirectory: tempRoot.appendingPathComponent("proposals", isDirectory: true))
    let signalStore = SignalStore(signalsDirectory: tempRoot.appendingPathComponent("signals", isDirectory: true))

    let now = Date(timeIntervalSince1970: 1_700_000_100)
    let engine = Engine(
        signalStore: signalStore,
        proposalStore: proposalStore,
        nowDate: { now }
    )

    let signal = Signal(
        signalId: "sig-analyst-link",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["NVDA"],
        direction: .bullish,
        horizon: .swing,
        confidence: 0.82,
        score: 0.82,
        positionStatement: "Bullish long setup for technology infrastructure demand.",
        recommendedAction: .draftProposal,
        evidence: [
            SignalEvidenceRef(type: .finding, id: "finding-1", url: nil, title: "technology demand persists", summary: "Demand remains resilient.", timestamp: now)
        ],
        provenance: SignalProvenance(
            sourceJobId: "analyst.finding_draft",
            scoringVersion: "analyst-finding-v1",
            analystId: "technology-research-analyst",
            charterId: "charter-technology-research",
            taskId: "task-42",
            sourceFindingId: "finding-1",
            sourceEvidenceBundleId: "bundle-1"
        ),
        originatingFindingId: "finding-1"
    )
    _ = try await signalStore.upsert(signal)

    let proposal = try await engine.draftProposalFromAnalystSignal(
        id: signal.signalId,
        strategyID: "heartbeat",
        source: .ui
    )

    let lineage = try #require(proposal.analystLineage)
    #expect(proposal.originatingSignalId == signal.signalId)
    #expect(proposal.approval.status == .draft)
    #expect(lineage.analystId == "technology-research-analyst")
    #expect(lineage.charterId == "charter-technology-research")
    #expect(lineage.taskId == "task-42")
    #expect(lineage.originatingFindingId == "finding-1")
    #expect(lineage.sourceEvidenceBundleId == "bundle-1")

    let storedSignal = try await engine.getSignal(id: signal.signalId)
    #expect(storedSignal.draftedProposalId == proposal.proposalId)
    #expect(storedSignal.linkedProposalId == proposal.proposalId)
    await engine.stop()
}

@Test("draftProposalFromAnalystSignal rejects non-analyst signals")
func draftProposalFromAnalystSignalRejectsNonAnalystSignal() async throws {
    let tempRoot = makeTempDirectory(name: "non-analyst-signal-proposal-link")
    let proposalStore = ProposalStore(proposalsDirectory: tempRoot.appendingPathComponent("proposals", isDirectory: true))
    let signalStore = SignalStore(signalsDirectory: tempRoot.appendingPathComponent("signals", isDirectory: true))

    let now = Date(timeIntervalSince1970: 1_700_000_200)
    let engine = Engine(
        signalStore: signalStore,
        proposalStore: proposalStore,
        nowDate: { now }
    )

    let signal = Signal(
        signalId: "sig-market-link",
        createdAt: now,
        updatedAt: now,
        status: .new,
        symbols: ["SPY"],
        direction: .bullish,
        horizon: .intraday,
        confidence: 0.8,
        score: 0.8,
        positionStatement: "Market strength remains constructive.",
        recommendedAction: .draftProposal,
        evidence: [],
        provenance: SignalProvenance(sourceJobId: "monitor", scoringVersion: "market-v1")
    )
    _ = try await signalStore.upsert(signal)

    await #expect(throws: AnalystSignalProposalDraftError.ineligibleSignal(id: signal.signalId, reason: "signal is missing analyst provenance")) {
        try await engine.draftProposalFromAnalystSignal(id: signal.signalId, strategyID: "heartbeat", source: .ui)
    }
    await engine.stop()
}

private func waitForJobCompletion(
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

private func makeTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
