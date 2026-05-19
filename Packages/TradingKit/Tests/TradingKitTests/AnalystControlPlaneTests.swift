import Foundation
import Testing
@testable import TradingKit

@Test("Engine analyst interfaces round-trip charters findings evidence and news")
func engineAnalystInterfacesRoundTrip() async throws {
    let root = makeAnalystTempDirectory(name: "engine-analyst-control-plane")
    let chartersDirectory = root.appendingPathComponent("charters", isDirectory: true)
    let tasksDirectory = root.appendingPathComponent("tasks", isDirectory: true)
    let findingsDirectory = root.appendingPathComponent("findings", isDirectory: true)
    let evidenceDirectory = root.appendingPathComponent("evidence", isDirectory: true)
    let memosDirectory = root.appendingPathComponent("memos", isDirectory: true)
    let sourceSuggestionsDirectory = root.appendingPathComponent("source-access-suggestions", isDirectory: true)
    let newsDirectory = root.appendingPathComponent("news", isDirectory: true)

    let charterStore = AnalystCharterStore(chartersDirectory: chartersDirectory)
    let taskStore = AnalystTaskStore(tasksDirectory: tasksDirectory)
    let findingStore = AnalystFindingStore(findingsDirectory: findingsDirectory)
    let evidenceStore = AnalystEvidenceBundleStore(evidenceDirectory: evidenceDirectory)
    let memoStore = AnalystMemoStore(memosDirectory: memosDirectory)
    let sourceSuggestionStore = AnalystSourceAccessSuggestionStore(suggestionsDirectory: sourceSuggestionsDirectory)
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: root.appendingPathComponent("memory", isDirectory: true))
    let newsStore = NewsStore(newsDirectory: newsDirectory)

    let now = Date(timeIntervalSince1970: 1_700_200_000)
    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "charter-1",
            analystId: "macro-analyst",
            title: "Macro Charter",
            coverageScope: "US macro",
            strategyFamily: "swing",
            summary: "Review macro catalysts.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await taskStore.upsert(
        AnalystTask(
            taskId: "task-1",
            analystId: "macro-analyst",
            charterId: "charter-1",
            title: "Review Fed",
            description: "Summarize rate implications.",
            status: .queued,
            createdAt: now,
            updatedAt: now,
            symbols: ["AAPL"],
            tags: ["macro"]
        )
    )
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "news-1",
            source: "alpaca_news",
            title: "Fed headline",
            url: "https://example.com/fed",
            publishedAt: now,
            receivedAt: now,
            summary: "Policy language shifted.",
            rawSymbolHints: ["AAPL"],
            tags: ["macro"],
            payloadVersion: 1
        )
    ])

    let engine = Engine(
        newsStore: newsStore,
        analystCharterStore: charterStore,
        analystSourceAccessSuggestionStore: sourceSuggestionStore,
        analystTaskStore: taskStore,
        analystFindingStore: findingStore,
        analystEvidenceBundleStore: evidenceStore,
        analystMemoStore: memoStore,
        analystScopedMemoryStore: memoryStore
    )

    let charters = try await engine.listAnalystCharters()
    #expect(charters.count == 10)
    #expect(charters.contains { $0.charterId == "charter-1" })
    #expect(charters.filter { $0.benchRole == AnalystBenchRole.sector }.count == 6)
    #expect(charters.filter { $0.benchRole == AnalystBenchRole.overlay }.count == 3)

    let updatedCharter = try await engine.upsertAnalystCharter(
        AnalystCharter(
            charterId: "charter-2",
            analystId: "macro-analyst",
            title: "Macro Charter 2",
            coverageScope: "US macro plus AI",
            strategyFamily: "swing",
            summary: "Second charter for IPC upsert path.",
            createdAt: now,
            updatedAt: now
        )
    )
    #expect(updatedCharter.charterId == "charter-2")

    let task = try await engine.getAnalystTask(id: "task-1")
    #expect(task.charterId == "charter-1")

    let updatedTask = try await engine.upsertAnalystTask(
        AnalystTask(
            taskId: "task-2",
            analystId: "macro-analyst",
            charterId: "charter-1",
            title: "Checkpointed task",
            description: "Durable checkpoint path",
            status: .inProgress,
            createdAt: now,
            updatedAt: now,
            checkpoint: AnalystTaskCheckpoint(
                checkpointID: "checkpoint-1",
                taskId: "task-2",
                analystId: "macro-analyst",
                charterId: "charter-1",
                summary: "Checkpoint summary",
                nextPlannedAction: "Review more evidence",
                openQuestions: ["What would refute the thesis?"],
                linkedEvidenceBundleIDs: [],
                updatedAt: now
            )
        )
    )
    #expect(updatedTask.checkpoint?.summary == "Checkpoint summary")
    #expect(updatedTask.lastCheckpointSummary == "Checkpoint summary")

    let bundle = try await engine.upsertAnalystEvidenceBundle(
        AnalystEvidenceBundle(
            bundleId: "bundle-1",
            analystId: "macro-analyst",
            taskId: "task-1",
            refs: [
                AnalystEvidenceRef(
                    refId: "e1",
                    sourceKind: .appNews,
                    sourceIdentifier: "news-1",
                    appEntityID: "news-1",
                    title: "Fed headline",
                    observedAt: now,
                    summary: "Policy language shifted."
                )
            ],
            summary: "Macro evidence bundle",
            createdAt: now,
            updatedAt: now
        )
    )

    let finding = try await engine.upsertAnalystFinding(
        AnalystFinding(
            findingId: "finding-1",
            analystId: "macro-analyst",
            taskId: "task-1",
            title: "Rates pressure easing",
            summary: "Macro pressure may be easing.",
            thesis: "Large-cap tech may benefit.",
            symbols: ["AAPL"],
            tags: ["macro"],
            status: .open,
            confidence: 0.72,
            timeHorizon: "swing",
            evidenceBundleId: bundle.bundleId,
            createdAt: now,
            updatedAt: now
        )
    )

    let findings = try await engine.listAnalystFindings()
    #expect(findings.map { $0.findingId } == [finding.findingId])
    #expect(findings.first?.evidenceBundleId == bundle.bundleId)
    let bundles = try await engine.listAnalystEvidenceBundles()
    #expect(bundles.map { $0.bundleId } == [bundle.bundleId])
    let fetchedBundle = try await engine.getAnalystEvidenceBundle(id: bundle.bundleId)
    #expect(fetchedBundle.summary == "Macro evidence bundle")

    let memo = try await engine.upsertAnalystMemo(
        AnalystMemo(
            memoId: "memo-1",
            analystId: "macro-analyst",
            charterId: "charter-1",
            taskId: "task-1",
            findingId: finding.findingId,
            evidenceBundleId: bundle.bundleId,
            title: "Rates pressure easing",
            executiveSummary: "Macro pressure appears to be easing.",
            currentView: "Constructive but bounded.",
            evidenceSummary: "Recent app news supports the constructive read.",
            uncertaintySummary: "Further evidence is needed to confirm durability.",
            recommendedNextStep: "Use this memo for PM review.",
            confidence: 0.72,
            createdAt: now,
            updatedAt: now
        )
    )
    let memos = try await engine.listAnalystMemos()
    #expect(memos.map { $0.memoId } == [memo.memoId])
    #expect(memos.first?.findingId == finding.findingId)

    let suggestion = try await engine.upsertAnalystSourceAccessSuggestion(
        AnalystSourceAccessSuggestionRecord(
            suggestionId: "source-gap-1",
            analystId: "macro-analyst",
            charterId: "charter-1",
            taskId: "task-1",
            memoId: memo.memoId,
            findingId: finding.findingId,
            evidenceBundleId: bundle.bundleId,
            requestedSource: "ECB speeches",
            requestedDomain: "ecb.europa.eu",
            siteName: "European Central Bank",
            whyItMatters: "Primary-source macro context would improve recurring rate work.",
            affectedTaskSummary: "Summarize rate implications.",
            limitation: .unsupportedByTooling,
            recommendedNextStep: .improveToolingSupport,
            createdAt: now,
            updatedAt: now
        ),
        source: AuditEventSource.engine
    )
    let sourceSuggestions = try await engine.listAnalystSourceAccessSuggestions()
    #expect(sourceSuggestions.map { $0.suggestionId } == [suggestion.suggestionId])
    let fetchedSuggestion = try await engine.getAnalystSourceAccessSuggestion(id: suggestion.suggestionId)
    #expect(fetchedSuggestion.requestedSource == "ECB speeches")
    #expect(fetchedSuggestion.memoId == memo.memoId)
    #expect(fetchedSuggestion.findingId == finding.findingId)
    #expect(fetchedSuggestion.evidenceBundleId == bundle.bundleId)

    let signal = try await engine.draftSignalFromAnalystFinding(id: finding.findingId)
    #expect(signal.originatingFindingId == finding.findingId)
    #expect(signal.provenance.analystId == "macro-analyst")
    #expect(signal.provenance.charterId == "charter-1")
    #expect(signal.provenance.taskId == "task-1")
    #expect(signal.provenance.sourceEvidenceBundleId == bundle.bundleId)

    let refreshedFinding = try await engine.getAnalystFinding(id: finding.findingId)
    #expect(refreshedFinding.linkedSignalId == signal.signalId)

    let lowConfidenceFinding = try await engine.upsertAnalystFinding(
        AnalystFinding(
            findingId: "finding-low-confidence",
            analystId: "macro-analyst",
            taskId: "task-1",
            title: "Rates pressure monitor",
            summary: "Macro pressure may be easing, but confidence is low.",
            thesis: "Monitor-only read for PM review.",
            symbols: ["AAPL"],
            tags: ["macro"],
            status: .open,
            confidence: 0.34,
            timeHorizon: "swing",
            evidenceBundleId: bundle.bundleId,
            createdAt: now,
            updatedAt: now
        )
    )
    let lowConfidenceSignal = try await engine.draftSignalFromAnalystFinding(id: lowConfidenceFinding.findingId)
    #expect(lowConfidenceSignal.originatingFindingId == lowConfidenceFinding.findingId)
    #expect(lowConfidenceSignal.confidence == 0.34)
    #expect(lowConfidenceSignal.recommendedAction == .notifyOnly)
    #expect(lowConfidenceSignal.direction == .neutral)

    let news = try await engine.listNews(limit: 10)
    #expect(news.map { $0.eventId } == ["news-1"])
}

@Test("PM can add an open source suggestion to preferred sources through the charter path")
func engineAppliesSourceSuggestionToPreferredSources() async throws {
    let root = makeAnalystTempDirectory(name: "engine-source-suggestion-preferred")
    let now = Date(timeIntervalSince1970: 1_744_700_000)
    let charterStore = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let suggestionStore = AnalystSourceAccessSuggestionStore(
        suggestionsDirectory: root.appendingPathComponent("source-access-suggestions", isDirectory: true)
    )

    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "charter-macro",
            analystId: "macro-analyst",
            title: "Macro Charter",
            coverageScope: "Macro",
            strategyFamily: "swing",
            summary: "Review macro catalysts.",
            documentBody: "# Analyst Charter\n\nUser-owned charter body.",
            revisionSummary: "Existing charter note.",
            sourcePolicy: AnalystSourcePolicy(
                reputableWebResearchAllowed: false,
                preferredSources: ["ecb.europa.eu"],
                restrictedSources: ["rumor.example"]
            ),
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await suggestionStore.upsert(
        AnalystSourceAccessSuggestionRecord(
            suggestionId: "source-gap-preferred",
            analystId: "macro-analyst",
            charterId: "charter-macro",
            requestedSource: "ECB speeches",
            requestedDomain: "ecb.europa.eu",
            whyItMatters: "Primary-source macro commentary improves recurring rate analysis.",
            limitation: .unsupportedByTooling,
            recommendedNextStep: .addAsPreferredSource,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(
        analystCharterStore: charterStore,
        analystSourceAccessSuggestionStore: suggestionStore
    )

    let updatedSuggestion = try await engine.applyAnalystSourceAccessSuggestionAction(
        suggestionId: "source-gap-preferred",
        action: .addToPreferredSources,
        updatedBy: "pm-1",
        source: .engine
    )

    #expect(updatedSuggestion.status == .addedToPreferredSources)
    #expect(updatedSuggestion.resolvedCharterId == "charter-macro")
    #expect(updatedSuggestion.appliedPolicyEntry == "ecb.europa.eu")
    #expect(updatedSuggestion.resolvedBy == "pm-1")
    #expect(updatedSuggestion.closedAt != nil)

    let updatedCharter = try await engine.getAnalystCharter(id: "charter-macro")
    #expect(updatedCharter.sourcePolicy.reputableWebResearchAllowed == true)
    #expect(updatedCharter.sourcePolicy.preferredSources == ["ecb.europa.eu"])
    #expect(updatedCharter.sourcePolicy.restrictedSources == ["rumor.example"])
    #expect(updatedCharter.primaryDocumentBody == "# Analyst Charter\n\nUser-owned charter body.")
    #expect(updatedCharter.revisionSummary == "Source policy update from analyst suggestion: added preferred source ecb.europa.eu.")
    #expect(updatedCharter.updatedBy == "pm-1")
    #expect(updatedCharter.updateSource == .sourceSuggestionAction)
}

@Test("PM can add an open source suggestion to restricted sources and remove duplicate preferred entries")
func engineAppliesSourceSuggestionToRestrictedSources() async throws {
    let root = makeAnalystTempDirectory(name: "engine-source-suggestion-restricted")
    let now = Date(timeIntervalSince1970: 1_744_700_100)
    let charterStore = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let suggestionStore = AnalystSourceAccessSuggestionStore(
        suggestionsDirectory: root.appendingPathComponent("source-access-suggestions", isDirectory: true)
    )

    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "charter-tech",
            analystId: "tech-analyst",
            title: "Technology Charter",
            coverageScope: "Technology",
            strategyFamily: "sector",
            summary: "Review tech catalysts.",
            sourcePolicy: AnalystSourcePolicy(
                reputableWebResearchAllowed: true,
                preferredSources: ["badsource.example", "sec.gov"],
                restrictedSources: ["legacy-blocked.example"]
            ),
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await suggestionStore.upsert(
        AnalystSourceAccessSuggestionRecord(
            suggestionId: "source-gap-restricted",
            analystId: "tech-analyst",
            charterId: "charter-tech",
            requestedSource: "badsource.example",
            requestedDomain: "badsource.example",
            whyItMatters: "This domain keeps surfacing but should stay blocked.",
            limitation: .restrictedByPolicy,
            recommendedNextStep: .keepRestricted,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(
        analystCharterStore: charterStore,
        analystSourceAccessSuggestionStore: suggestionStore
    )

    let updatedSuggestion = try await engine.applyAnalystSourceAccessSuggestionAction(
        suggestionId: "source-gap-restricted",
        action: .addToRestrictedSources,
        updatedBy: "pm-2",
        source: .engine
    )

    #expect(updatedSuggestion.status == .addedToRestrictedSources)
    #expect(updatedSuggestion.appliedPolicyEntry == "badsource.example")

    let updatedCharter = try await engine.getAnalystCharter(id: "charter-tech")
    #expect(updatedCharter.sourcePolicy.preferredSources == ["sec.gov"])
    #expect(updatedCharter.sourcePolicy.restrictedSources == ["legacy-blocked.example", "badsource.example"])
    #expect(updatedCharter.updateSource == .sourceSuggestionAction)
}

@Test("PM can dismiss a source suggestion without changing charter policy")
func engineDismissesSourceSuggestionWithoutPolicyChange() async throws {
    let root = makeAnalystTempDirectory(name: "engine-source-suggestion-dismiss")
    let now = Date(timeIntervalSince1970: 1_744_700_200)
    let charterStore = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let suggestionStore = AnalystSourceAccessSuggestionStore(
        suggestionsDirectory: root.appendingPathComponent("source-access-suggestions", isDirectory: true)
    )

    let charter = AnalystCharter(
        charterId: "charter-consumer",
        analystId: "consumer-analyst",
        title: "Consumer Charter",
        coverageScope: "Consumer",
        strategyFamily: "sector",
        summary: "Review consumer catalysts.",
        sourcePolicy: AnalystSourcePolicy(
            reputableWebResearchAllowed: true,
            preferredSources: ["sec.gov"],
            restrictedSources: ["rumor.example"]
        ),
        createdAt: now,
        updatedAt: now
    )
    _ = try await charterStore.upsert(charter)
    _ = try await suggestionStore.upsert(
        AnalystSourceAccessSuggestionRecord(
            suggestionId: "source-gap-dismiss",
            analystId: "consumer-analyst",
            charterId: "charter-consumer",
            requestedSource: "paywalled.example",
            requestedDomain: "paywalled.example",
            whyItMatters: "Could help, but not enough to change policy.",
            limitation: .inaccessible,
            recommendedNextStep: .keepRestricted,
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(
        analystCharterStore: charterStore,
        analystSourceAccessSuggestionStore: suggestionStore
    )

    let updatedSuggestion = try await engine.applyAnalystSourceAccessSuggestionAction(
        suggestionId: "source-gap-dismiss",
        action: .dismiss,
        updatedBy: "pm-3",
        source: .engine
    )

    #expect(updatedSuggestion.status == .dismissed)
    #expect(updatedSuggestion.appliedPolicyEntry == nil)
    #expect(updatedSuggestion.resolutionSummary == "Dismissed without changing charter source policy.")

    let unchangedCharter = try await engine.getAnalystCharter(id: "charter-consumer")
    #expect(unchangedCharter.sourcePolicy == charter.sourcePolicy)
    #expect(unchangedCharter.updateSource == charter.updateSource)
}

@Test("Source suggestion readable presentation stays bounded for open and closed states")
func sourceSuggestionReadablePresentationReflectsLifecycleTruth() {
    let now = Date(timeIntervalSince1970: 1_744_700_300)
    let open = AnalystSourceAccessSuggestionRecord(
        suggestionId: "source-gap-open",
        analystId: "macro-analyst",
        requestedSource: "ecb.europa.eu",
        whyItMatters: "Primary-source macro context would help.",
        limitation: .unsupportedByTooling,
        recommendedNextStep: .improveToolingSupport,
        createdAt: now,
        updatedAt: now
    )
    let closed = AnalystSourceAccessSuggestionRecord(
        suggestionId: "source-gap-closed",
        analystId: "macro-analyst",
        charterId: "charter-macro",
        memoId: "memo-1",
        requestedSource: "ecb.europa.eu",
        requestedDomain: "ecb.europa.eu",
        whyItMatters: "Primary-source macro context would help.",
        limitation: .restrictedByPolicy,
        recommendedNextStep: .allowByCharterUpdate,
        status: .addedToPreferredSources,
        resolvedBy: "pm-1",
        resolvedCharterId: "charter-macro",
        appliedPolicyEntry: "ecb.europa.eu",
        resolutionSummary: "Added ecb.europa.eu to preferred sources for Macro Charter.",
        closedAt: now.addingTimeInterval(60),
        createdAt: now,
        updatedAt: now.addingTimeInterval(60)
    )

    let openPresentation = makeAnalystSourceAccessSuggestionReadablePresentation(open)
    #expect(openPresentation.statusLabel == "Open")
    #expect(openPresentation.resultSummary.contains("No charter source-policy change") == true)

    let closedPresentation = makeAnalystSourceAccessSuggestionReadablePresentation(closed)
    #expect(closedPresentation.statusLabel == "Added To Preferred Sources")
    #expect(closedPresentation.resultSummary == "Added ecb.europa.eu to preferred sources for Macro Charter.")
    #expect(closedPresentation.linkedArtifactsSummary == "Memo memo-1")
    #expect(closedPresentation.boundaryNote.contains("untrusted evidence only") == true)
}

@Test("Engine seeds standing analyst bench deterministically without duplicates")
func engineSeedsStandingAnalystBench() async throws {
    let root = makeAnalystTempDirectory(name: "engine-standing-bench")
    let charterStore = AnalystCharterStore(
        chartersDirectory: root.appendingPathComponent("charters", isDirectory: true)
    )
    let engine = Engine(analystCharterStore: charterStore)

    let firstLoad = try await engine.listAnalystCharters()
    let secondLoad = try await engine.listAnalystCharters()

    #expect(firstLoad.count == 9)
    #expect(secondLoad.count == 9)
    #expect(Set(firstLoad.map(\.charterId)).count == 9)
    #expect(firstLoad.filter { $0.benchRole == .sector }.count == 6)
    #expect(firstLoad.filter { $0.benchRole == .overlay }.count == 3)
    #expect(firstLoad.contains { $0.title == recentNewsStandingAnalystTitle && $0.benchRole == .overlay })
    #expect(firstLoad.contains { $0.title == "Macro and International Analyst" && $0.benchRole == .overlay })
    #expect(firstLoad.contains { $0.title == "Portfolio Risk Analyst" && $0.summary.contains("PM-invokable now") })
    #expect(firstLoad.allSatisfy { $0.primaryDocumentBody.contains("# Analyst Charter") })
    #expect(firstLoad.contains { $0.charterId == "bench-sector-technology" && $0.primaryDocumentBody.contains("Technology Sector Analyst") })
}

@Test("Engine backfills document bodies for untouched legacy standing bench charters without overwriting later edits")
func engineBackfillsLegacyStandingBenchDocumentBodies() async throws {
    let root = makeAnalystTempDirectory(name: "engine-standing-bench-backfill")
    let charterStore = AnalystCharterStore(
        chartersDirectory: root.appendingPathComponent("charters", isDirectory: true)
    )
    let now = Date(timeIntervalSince1970: 1_744_400_000)
    let seededCharters = StandingAnalystBenchSeed().seededCharters(now: now)
    var untouchedLegacy = try #require(seededCharters.first(where: { $0.charterId == "bench-sector-technology" }))
    untouchedLegacy.documentBody = nil
    untouchedLegacy.summary = "Older placeholder summary that should not continue winning once the standing bench is reseeded."
    untouchedLegacy.duties = ["These will be provided by the PM"]
    untouchedLegacy.constraints = ["No auto-trade."]
    untouchedLegacy.expectedOutputs = ["Legacy placeholder output."]
    untouchedLegacy.allowedSources = []
    untouchedLegacy.updatedBy = "unknown"
    untouchedLegacy.updateSource = .engine
    var userEdited = try #require(seededCharters.first(where: { $0.charterId == "bench-sector-consumer" }))
    userEdited.documentBody = "# Analyst Charter\n\nUser-owned consumer charter body."
    userEdited.updatedBy = "human owner"
    userEdited.updateSource = .userEdited
    userEdited.updatedAt = now.addingTimeInterval(300)

    _ = try await charterStore.upsert(untouchedLegacy)
    _ = try await charterStore.upsert(userEdited)

    let engine = Engine(analystCharterStore: charterStore)
    let charters = try await engine.listAnalystCharters()

    let refreshedTechnology = try #require(charters.first(where: { $0.charterId == "bench-sector-technology" }))
    #expect(refreshedTechnology.primaryDocumentBody.contains("Technology Sector Analyst"))
    #expect(refreshedTechnology.documentBody?.contains("Technology Sector Analyst") == true)
    #expect(refreshedTechnology.primaryDocumentBody.contains("Core Responsibilities"))
    #expect(refreshedTechnology.primaryDocumentBody.contains("### Source Policy And Research Conduct"))
    #expect(refreshedTechnology.sourcePolicy.reputableWebResearchAllowed == true)
    #expect(refreshedTechnology.updatedBy == "unknown")
    #expect(refreshedTechnology.updateSource == .engine)

    let preservedConsumer = try #require(charters.first(where: { $0.charterId == "bench-sector-consumer" }))
    #expect(preservedConsumer.primaryDocumentBody.contains("# Analyst Charter\n\nUser-owned consumer charter body."))
    #expect(preservedConsumer.primaryDocumentBody.contains("### Source Policy And Research Conduct"))
    #expect(preservedConsumer.updatedBy == "human owner")
    #expect(preservedConsumer.updateSource == .userEdited)
}

@Test("Engine backfills risk framework guidance for untouched legacy Portfolio Risk charters without clobbering user-edited bodies")
func engineBackfillsPortfolioRiskGuidanceWithoutClobberingUserBody() async throws {
    let root = makeAnalystTempDirectory(name: "engine-portfolio-risk-guidance-backfill")
    let charterStore = AnalystCharterStore(
        chartersDirectory: root.appendingPathComponent("charters", isDirectory: true)
    )
    let now = Date(timeIntervalSince1970: 1_744_401_000)
    let seededCharters = StandingAnalystBenchSeed().seededCharters(now: now)

    var untouchedRisk = try #require(seededCharters.first(where: { $0.charterId == "bench-overlay-portfolio-risk" }))
    untouchedRisk.documentBody = untouchedRisk.primaryDocumentBody.replacingOccurrences(
        of: "\n\n" + StandingAnalystBenchSeed.portfolioRiskMetricsAndCalculationGuidanceSection(),
        with: ""
    )
    untouchedRisk.updatedBy = "engine"
    untouchedRisk.updateSource = .engine

    var userEditedRisk = untouchedRisk
    userEditedRisk.documentBody = """
    # Analyst Charter

    User-owned Portfolio Risk body.

    ### Source Policy And Research Conduct

    User-owned source policy text.
    """
    userEditedRisk.updatedBy = "human owner"
    userEditedRisk.updateSource = .userEdited
    userEditedRisk.updatedAt = now.addingTimeInterval(300)

    _ = try await charterStore.upsert(untouchedRisk)

    let backfillEngine = Engine(analystCharterStore: charterStore)
    let backfilled = try await backfillEngine.listAnalystCharters()
    let refreshedRisk = try #require(backfilled.first(where: { $0.charterId == "bench-overlay-portfolio-risk" }))
    #expect(refreshedRisk.primaryDocumentBody.contains("### Risk Metrics And Calculation Guidance"))
    #expect(refreshedRisk.primaryDocumentBody.contains("gross exposure, net exposure, long exposure, short exposure"))
    #expect(refreshedRisk.primaryDocumentBody.contains("20-25% in a moderate posture"))

    _ = try await charterStore.upsert(userEditedRisk)
    let preservedEngine = Engine(analystCharterStore: charterStore)
    let preserved = try await preservedEngine.listAnalystCharters()
    let preservedRisk = try #require(preserved.first(where: { $0.charterId == "bench-overlay-portfolio-risk" }))
    #expect(preservedRisk.primaryDocumentBody.contains("User-owned Portfolio Risk body."))
    #expect(preservedRisk.primaryDocumentBody.contains("### Risk Metrics And Calculation Guidance") == false)
    #expect(preservedRisk.updatedBy == "human owner")
    #expect(preservedRisk.updateSource == .userEdited)
}

@Test("Engine assembles bench analyst context pack from shared current truth plus scoped memory")
func engineBuildsBenchAnalystContextPack() async throws {
    let root = makeAnalystTempDirectory(name: "engine-context-pack")
    let newsStore = NewsStore(newsDirectory: root.appendingPathComponent("news", isDirectory: true))
    let pmMandateStore = PMMandateStore(mandatesDirectory: root.appendingPathComponent("pm-mandates", isDirectory: true))
    let pmInstructionStore = PMInstructionStore(instructionsDirectory: root.appendingPathComponent("pm-instructions", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(
        fileURL: root.appendingPathComponent("portfolio-strategy-brief.json", isDirectory: false)
    )
    let analystTaskStore = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let analystFindingStore = AnalystFindingStore(findingsDirectory: root.appendingPathComponent("findings", isDirectory: true))
    let analystMemoStore = AnalystMemoStore(memosDirectory: root.appendingPathComponent("memos", isDirectory: true))
    let analystScopedMemoryStore = AnalystScopedMemoryStore(memoryDirectory: root.appendingPathComponent("memory", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_720_400_000)

    _ = try await pmMandateStore.upsert(
        PMMandate(
            mandateId: "mandate-1",
            pmId: "pm-1",
            title: "Protect downside",
            objectiveSummary: "Keep event-driven losses bounded.",
            scope: "Core holdings",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmInstructionStore.upsert(
        PMInstruction(
            instructionId: "instruction-1",
            pmId: "pm-1",
            title: "Escalate guidance changes",
            body: "Escalate guidance changes at held names to PM review.",
            category: "review",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await strategyBriefStore.upsert(
        PortfolioStrategyBrief(
            objectiveSummary: "Compound through quality technology exposure while staying event-aware.",
            keyThemes: ["technology infrastructure", "earnings quality"],
            currentRiskPosture: "Moderate with tighter review around event-driven repricing.",
            materialDevelopments: ["guidance changes", "major restructurings"],
            nonMaterialDevelopments: ["routine office updates"],
            reviewEscalationPosture: "Escalate to PM review before owner-facing escalation.",
            updatedBy: "pm-1",
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await analystTaskStore.upsert(
        AnalystTask(
            taskId: "task-1",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            title: "Review AAPL event risk",
            description: "Track event-driven changes for AAPL.",
            status: .inProgress,
            createdAt: now,
            updatedAt: now,
            symbols: ["AAPL"],
            tags: ["technology"],
            checkpoint: AnalystTaskCheckpoint(
                checkpointID: "checkpoint-1",
                taskId: "task-1",
                analystId: "bench-sector-technology-analyst",
                charterId: "bench-sector-technology",
                summary: "Prior review checkpoint",
                nextPlannedAction: "Wait for guidance update",
                openQuestions: ["What would change the hardware demand view?"],
                updatedAt: now
            )
        )
    )
    _ = try await analystFindingStore.upsert(
        AnalystFinding(
            findingId: "finding-1",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            taskId: "task-1",
            title: "technology demand still intact",
            summary: "Demand remains healthy but event risk is elevated.",
            thesis: "Technology exposure remains constructive but event-driven.",
            symbols: ["AAPL"],
            tags: ["technology", "technology-infrastructure"],
            status: .open,
            confidence: 0.64,
            timeHorizon: "swing",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await analystMemoStore.upsert(
        AnalystMemo(
            memoId: "memo-1",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            taskId: "task-1",
            findingId: "finding-1",
            title: "Technology memo",
            executiveSummary: "Constructive but watch the next guidance cycle.",
            currentView: "Demand remains solid.",
            evidenceSummary: "Recent app news is constructive.",
            uncertaintySummary: "Guidance still matters.",
            recommendedNextStep: "Keep PM informed.",
            confidence: 0.64,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "news-1",
            source: "sec_edgar",
            title: "Apple Inc. filed 8-K",
            url: "https://www.sec.gov/example-1",
            publishedAt: now.addingTimeInterval(-120),
            receivedAt: now.addingTimeInterval(-110),
            summary: "Guidance update and restructuring details.",
            rawSymbolHints: ["AAPL"],
            tags: ["sec", "8-k"],
            payloadVersion: 1
        )
    ])

    let engine = Engine(
        newsStore: newsStore,
        pmMandateStore: pmMandateStore,
        pmInstructionStore: pmInstructionStore,
        portfolioStrategyBriefStore: strategyBriefStore,
        analystTaskStore: analystTaskStore,
        analystFindingStore: analystFindingStore,
        analystMemoStore: analystMemoStore,
        analystScopedMemoryStore: analystScopedMemoryStore,
        nowDate: { now }
    )
    await engine.store.setWatchlistSymbols(["AAPL", "MSFT"])
    await engine.store.applyPositionsRefreshSnapshot(positions: [
        try decodePosition(symbol: "AAPL", qty: "10", side: "long", marketValue: "10000")
    ])

    let pack = try await engine.buildBenchAnalystContextPack(
        charterID: "bench-sector-technology",
        pmID: "pm-1",
        recentNewsLimit: 5
    )

    #expect(pack.sharedCurrentTruth.positions.map(\.symbol) == ["AAPL"])
    #expect(pack.sharedCurrentTruth.watchlistSymbols == ["AAPL", "MSFT"])
    #expect(pack.sharedCurrentTruth.portfolioStrategyBrief?.objectiveSummary == "Compound through quality technology exposure while staying event-aware.")
    #expect(pack.sharedCurrentTruth.portfolioStrategyBrief?.strategicPriorities?.contains(where: { $0.contains("Objective: Compound through quality technology exposure while staying event-aware.") }) == true)
    #expect(pack.sharedCurrentTruth.portfolioStrategyBrief?.groundingSummary?.contains("Risk posture: Moderate with tighter review around event-driven repricing.") == true)
    #expect(pack.sharedCurrentTruth.portfolioStrategyBrief?.updatedBy == "pm-1")
    #expect(pack.sharedCurrentTruth.portfolioStrategyBrief?.updateSource == .pmControlPlane)
    #expect(pack.sharedCurrentTruth.recentNews.map(\.eventId) == ["news-1"])
    #expect(pack.sharedCurrentTruth.pmMandates.map(\.mandateId) == ["mandate-1"])
    #expect(pack.sharedCurrentTruth.pmInstructions.map(\.instructionId) == ["instruction-1"])
    #expect(pack.scopedMemory?.analystId == "bench-sector-technology-analyst")
    #expect(pack.scopedMemory?.trackedSymbols == ["AAPL"])
    #expect(pack.scopedMemory?.trackedThemes.contains("technology-infrastructure") == true)
    #expect(pack.scopedMemory?.recentMemos.map(\.artifactId) == ["memo-1"])
    #expect(pack.scopedMemory?.recentFindings.map(\.artifactId) == ["finding-1"])
}

@Test("Engine scoped memory stays isolated between standing bench analysts")
func engineScopedMemoryStaysIsolatedAcrossBenchAnalysts() async throws {
    let root = makeAnalystTempDirectory(name: "engine-memory-isolation")
    let taskStore = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let findingStore = AnalystFindingStore(findingsDirectory: root.appendingPathComponent("findings", isDirectory: true))
    let memoStore = AnalystMemoStore(memosDirectory: root.appendingPathComponent("memos", isDirectory: true))
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: root.appendingPathComponent("memory", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_720_401_000)

    let engine = Engine(
        analystTaskStore: taskStore,
        analystFindingStore: findingStore,
        analystMemoStore: memoStore,
        analystScopedMemoryStore: memoryStore,
        nowDate: { now }
    )

    _ = try await engine.upsertAnalystTask(
        AnalystTask(
            taskId: "tech-task",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            title: "Tech task",
            description: "Review tech names.",
            status: .inProgress,
            createdAt: now,
            updatedAt: now,
            symbols: ["AAPL"],
            checkpoint: AnalystTaskCheckpoint(
                checkpointID: "tech-checkpoint",
                taskId: "tech-task",
                analystId: "bench-sector-technology-analyst",
                charterId: "bench-sector-technology",
                summary: "Tech checkpoint",
                nextPlannedAction: "Wait",
                openQuestions: ["What changes the technology demand read?"],
                updatedAt: now
            )
        )
    )
    _ = try await engine.upsertAnalystTask(
        AnalystTask(
            taskId: "risk-task",
            analystId: "bench-overlay-portfolio-risk-analyst",
            charterId: "bench-overlay-portfolio-risk",
            title: "Risk task",
            description: "Review risk clustering.",
            status: .inProgress,
            createdAt: now,
            updatedAt: now,
            symbols: ["XLF"],
            checkpoint: AnalystTaskCheckpoint(
                checkpointID: "risk-checkpoint",
                taskId: "risk-task",
                analystId: "bench-overlay-portfolio-risk-analyst",
                charterId: "bench-overlay-portfolio-risk",
                summary: "Risk checkpoint",
                nextPlannedAction: "Wait",
                openQuestions: ["Where is concentration risk rising?"],
                updatedAt: now
            )
        )
    )

    let techMemory = try #require(await memoryStore.getByAnalystID("bench-sector-technology-analyst"))
    let riskMemory = try #require(await memoryStore.getByAnalystID("bench-overlay-portfolio-risk-analyst"))

    #expect(techMemory.trackedSymbols == ["AAPL"])
    #expect(riskMemory.trackedSymbols == ["XLF"])
    #expect(techMemory.openQuestions == ["What changes the technology demand read?"])
    #expect(riskMemory.openQuestions == ["Where is concentration risk rising?"])
}

private func makeAnalystTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test("Engine launches analyst worker once with explicit charter and task identity")
func engineLaunchesAnalystWorkerOnce() async throws {
    actor LaunchRecorder {
        var requests: [AnalystWorkerLaunchRequest] = []

        func record(_ request: AnalystWorkerLaunchRequest) {
            requests.append(request)
        }

        func all() -> [AnalystWorkerLaunchRequest] {
            requests
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: "finding-1",
                findingTitle: "Adoption friction persists",
                draftedSignalId: request.draftSignal ? "sig-1" : nil,
                runtimeProvenance: request.intendedRuntimePolicy.map {
                    AnalystRuntimeProvenance(
                        intendedPolicy: $0,
                        actualRuntimeIdentifier: "deterministic_local",
                        launchedAt: Date(timeIntervalSince1970: 1_700_000_000)
                    )
                },
                summary: "finding: Adoption friction persists",
                outputExcerpt: "finding_id: finding-1"
            )
        }
    }

    let recorder = LaunchRecorder()
    let engine = Engine(
        analystWorkerLauncher: StubLauncher(recorder: recorder)
    )

    let result = try await engine.launchAnalystWorkerOnce(
        charterID: "charter-1",
        taskID: "task-1",
        draftSignal: true
    )

    #expect(result.charterId == "charter-1")
    #expect(result.taskId == "task-1")
    #expect(result.draftedSignalId == "sig-1")

    let requests = await recorder.all()
    #expect(requests == [
        AnalystWorkerLaunchRequest(
            charterId: "charter-1",
            taskId: "task-1",
            draftSignal: true
        )
    ])
}

@Test("Engine preflights and refreshes stale IPC metadata before real worker launch")
func enginePreflightsAndRefreshesStaleIPCMetadataBeforeWorkerLaunch() async throws {
    actor LaunchRecorder {
        private(set) var requests: [AnalystWorkerLaunchRequest] = []

        func record(_ request: AnalystWorkerLaunchRequest) {
            requests.append(request)
        }
    }

    struct IPCRequiredLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder
        var requiresAppIPCServer: Bool { true }

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "ok",
                outputExcerpt: "ok"
            )
        }
    }

    let root = makeAnalystControlPlaneTempDirectory(name: "worker-ipc-preflight")
    let runtimeStore = AgentControlRuntimeInfoStore(
        fileURL: root.appendingPathComponent("ipc.json", isDirectory: false)
    )
    let recorder = LaunchRecorder()
    let engine = Engine(
        analystWorkerLauncher: IPCRequiredLauncher(recorder: recorder),
        ipcPreferredPort: 0,
        ipcRuntimeInfoStore: runtimeStore
    )

    do {
        _ = try await engine.launchAnalystWorkerOnce(charterID: "charter-1")
        let firstRuntime = try runtimeStore.load()
        #expect(firstRuntime.port > 0)

        try runtimeStore.save(
            AgentControlRuntimeInfo(host: "127.0.0.1", port: 1, token: "stale-token")
        )
        _ = try await engine.launchAnalystWorkerOnce(charterID: "charter-1")
        let refreshedRuntime = try runtimeStore.load()

        #expect(refreshedRuntime.port > 0)
        #expect(refreshedRuntime.port != 1)
        #expect(refreshedRuntime.token != "stale-token")
        #expect(await recorder.requests.count == 2)
    } catch {
        await engine.stop()
        throw error
    }

    await engine.stop()
}

@Test("Engine launches analyst worker from PM delegation with resolved runtime policy and updates provenance")
func engineLaunchesAnalystWorkerFromDelegation() async throws {
    actor LaunchRecorder {
        var requests: [AnalystWorkerLaunchRequest] = []

        func record(_ request: AnalystWorkerLaunchRequest) {
            requests.append(request)
        }

        func all() -> [AnalystWorkerLaunchRequest] {
            requests
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: "finding-1",
                findingTitle: "Delegated finding",
                draftedSignalId: request.draftSignal ? "sig-1" : nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: request.intendedRuntimePolicy,
                    actualRuntimeIdentifier: "deterministic_local",
                    launchedAt: Date(timeIntervalSince1970: 1_701_400_100)
                ),
                summary: "finding: Delegated finding",
                outputExcerpt: "finding_id: finding-1"
            )
        }
    }

    let root = makeAnalystControlPlaneTempDirectory(name: "pm-delegation-launch")
    let pmProfiles = PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true))
    let pmDelegations = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let charters = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let tasks = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let newsStore = NewsStore(newsDirectory: root.appendingPathComponent("news", isDirectory: true))
    let strategyBriefStore = PortfolioStrategyBriefStore(
        fileURL: root.appendingPathComponent("portfolio-strategy-brief.json", isDirectory: false)
    )
    let memoryStore = AnalystScopedMemoryStore(memoryDirectory: root.appendingPathComponent("memory", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_701_400_000)

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
            charterId: "charter-1",
            analystId: "analyst-1",
            title: "Tech Charter",
            coverageScope: "Technology",
            strategyFamily: "long-short",
            summary: "Track technology adoption.",
            defaultRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                policySource: .charterDefault,
                createdAt: now,
                updatedAt: now
            ),
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await tasks.upsert(
        AnalystTask(
            taskId: "task-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            title: "Task",
            description: "Check timing.",
            status: .queued,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmDelegations.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            taskId: "task-1",
            title: "Delegate research",
            rationale: "Need attributable launch.",
            requestedOutputs: [.finding, .signal],
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        newsStore: newsStore,
        pmProfileStore: pmProfiles,
        portfolioStrategyBriefStore: strategyBriefStore,
        pmDelegationStore: pmDelegations,
        analystCharterStore: charters,
        analystTaskStore: tasks,
        analystScopedMemoryStore: memoryStore,
        analystWorkerLauncher: StubLauncher(recorder: recorder)
    )

    let result = try await engine.launchAnalystWorkerForPMDelegation(
        delegationID: "delegation-1",
        draftSignal: true
    )

    #expect(result.delegationId == "delegation-1")
    #expect(result.pmId == "pm-1")
    #expect(result.runtimeProvenance?.intendedPolicy?.runtimeIdentifier == "gpt-5")

    let requests = await recorder.all()
    #expect(requests == [
        AnalystWorkerLaunchRequest(
            charterId: "charter-1",
            taskId: "task-1",
            delegationId: "delegation-1",
            pmId: "pm-1",
            intendedRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                policySource: .charterDefault,
                createdAt: now,
                updatedAt: now
            ),
            draftSignal: true
        )
    ])

    let updatedDelegation = try await engine.getPMDelegation(id: "delegation-1")
    #expect(updatedDelegation.status == PMDelegationStatus.completed)
    #expect(updatedDelegation.lastLaunch?.status == PMDelegationLastLaunchStatus.healthy)
    #expect(updatedDelegation.linkedFindingIDs == ["finding-1"])
    #expect(updatedDelegation.linkedSignalIDs == ["sig-1"])
    #expect(updatedDelegation.lastRuntimeProvenance?.actualRuntimeIdentifier == "deterministic_local")
}

@Test("Engine delegation launch ignores stale seeded standing charter runtime defaults")
func engineDelegationLaunchIgnoresStaleSeededStandingCharterRuntimeDefaults() async throws {
    actor LaunchRecorder {
        var requests: [AnalystWorkerLaunchRequest] = []

        func record(_ request: AnalystWorkerLaunchRequest) {
            requests.append(request)
        }

        func all() -> [AnalystWorkerLaunchRequest] {
            requests
        }
    }

    struct StubLauncher: AnalystWorkerLaunching {
        let recorder: LaunchRecorder

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            await recorder.record(request)
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                findingId: "finding-1",
                findingTitle: "Delegated finding",
                draftedSignalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: request.intendedRuntimePolicy,
                    actualRuntimeIdentifier: "deterministic_local",
                    launchedAt: Date(timeIntervalSince1970: 1_700_000_000)
                ),
                summary: "finding: Delegated finding",
                outputExcerpt: "finding_id: finding-1"
            )
        }
    }

    let root = makeAnalystControlPlaneTempDirectory(name: "delegation-launch-seeded-default")
    let now = Date(timeIntervalSince1970: 1_720_111_000)
    let pmProfiles = PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true))
    let pmDelegations = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let charters = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let tasks = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let runtimeSettingsStore = StandingBenchAnalystRuntimeSettingsStore(
        fileURL: root.appendingPathComponent("standing-bench-runtime-settings.json", isDirectory: false)
    )

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
            roleSummary: "Owns analyst launches.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await charters.upsert(
        AnalystCharter(
            charterId: "bench-sector-technology",
            analystId: "bench-sector-technology-analyst",
            title: "Technology Analyst",
            coverageScope: "Technology coverage",
            strategyFamily: "standing sector bench",
            summary: "Legacy seeded runtime should be ignored.",
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
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            title: "Task",
            description: "Check timing.",
            status: .queued,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmDelegations.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            taskId: "task-1",
            title: "Delegate research",
            rationale: "Need attributable launch.",
            requestedOutputs: [.finding],
            createdAt: now,
            updatedAt: now
        )
    )

    let recorder = LaunchRecorder()
    let engine = Engine(
        pmProfileStore: pmProfiles,
        pmDelegationStore: pmDelegations,
        analystCharterStore: charters,
        analystTaskStore: tasks,
        standingBenchAnalystRuntimeSettingsStore: runtimeSettingsStore,
        analystWorkerLauncher: StubLauncher(recorder: recorder)
    )

    _ = try await engine.launchAnalystWorkerForPMDelegation(delegationID: "delegation-1")

    let requests = await recorder.all()
    #expect(requests.count == 1)
    #expect(requests[0].intendedRuntimePolicy?.runtimeIdentifier == "gpt-5.4-mini")
    #expect(requests[0].intendedRuntimePolicy?.reasoningMode == .deliberate)
    #expect(requests[0].intendedRuntimePolicy?.policySource == .standingBenchDefault)
}

@Test("Engine delegation launch failure persists bounded failed launch status for PM observability")
func engineDelegationLaunchFailurePersistsLastLaunchFailure() async throws {
    struct FailingLauncher: AnalystWorkerLaunching {
        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            throw AnalystWorkerLaunchError.workerExited(
                code: 1,
                summary: "launch failed: runtime unavailable"
            )
        }
    }

    let root = makeAnalystControlPlaneTempDirectory(name: "pm-delegation-launch-failure")
    let pmProfiles = PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true))
    let pmDelegations = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let charters = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_701_400_500)

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
            charterId: "charter-1",
            analystId: "analyst-1",
            title: "Tech Charter",
            coverageScope: "Technology",
            strategyFamily: "long-short",
            summary: "Track technology adoption.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmDelegations.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            title: "Delegate failed research",
            rationale: "Need bounded failure state.",
            requestedOutputs: [.finding],
            createdAt: now,
            updatedAt: now
        )
    )

    let engine = Engine(
        pmProfileStore: pmProfiles,
        pmDelegationStore: pmDelegations,
        analystCharterStore: charters,
        analystWorkerLauncher: FailingLauncher()
    )

    await #expect(throws: AnalystWorkerLaunchError.workerExited(
        code: 1,
        summary: "launch failed: runtime unavailable"
    )) {
        try await engine.launchAnalystWorkerForPMDelegation(delegationID: "delegation-1")
    }

    let updatedDelegation = try await engine.getPMDelegation(id: "delegation-1")
    #expect(updatedDelegation.lastLaunch?.status == .failed)
    #expect(updatedDelegation.lastLaunch?.summary == "Analyst worker exited unsuccessfully: launch failed: runtime unavailable")
    #expect(updatedDelegation.linkedFindingIDs.isEmpty)
}

@Test("Engine delegation launch records running progress before terminal completion")
func engineDelegationLaunchPersistsProgressState() async throws {
    actor LaunchGate {
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            if isOpen {
                return
            }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func resume() {
            isOpen = true
            for waiter in waiters {
                waiter.resume()
            }
            waiters.removeAll()
        }
    }

    struct ProgressLauncher: AnalystWorkerLaunching {
        let started: LaunchGate
        let gate: LaunchGate
        let launchedAt: Date

        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            try await runOnce(request: request, onProgress: nil)
        }

        func runOnce(
            request: AnalystWorkerLaunchRequest,
            onProgress: (@Sendable (AnalystWorkerProgressUpdate) -> Void)?
        ) async throws -> AnalystWorkerLaunchResult {
            await started.resume()
            onProgress?(
                AnalystWorkerProgressUpdate(
                    reportedAt: Date(),
                    stage: "context_resolved",
                    summary: "Current charter, task, and app-owned context were resolved."
                )
            )
            await gate.wait()
            return AnalystWorkerLaunchResult(
                charterId: request.charterId,
                taskId: request.taskId,
                delegationId: request.delegationId,
                pmId: request.pmId,
                memoId: "memo-1",
                memoTitle: "Memo",
                findingId: "finding-1",
                findingTitle: "Finding",
                draftedSignalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: request.intendedRuntimePolicy,
                    actualRuntimeIdentifier: "openai_responses[gpt-5]",
                    actualReasoningMode: .deliberate,
                    launchedAt: launchedAt
                ),
                summary: "Worker completed.",
                outputExcerpt: "bounded excerpt"
            )
        }
    }

    let root = makeAnalystControlPlaneTempDirectory(name: "pm-delegation-launch-progress")
    let pmProfiles = PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true))
    let pmDelegations = PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true))
    let charters = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let tasks = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let now = Date()

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
            charterId: "charter-1",
            analystId: "analyst-1",
            title: "Tech Charter",
            coverageScope: "Technology",
            strategyFamily: "long-short",
            summary: "Track technology adoption.",
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await tasks.upsert(
        AnalystTask(
            taskId: "task-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            title: "Task",
            description: "Track bounded progress.",
            status: .queued,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await pmDelegations.upsert(
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "analyst-1",
            charterId: "charter-1",
            taskId: "task-1",
            title: "Track progress",
            rationale: "Need truthful running state.",
            requestedOutputs: [.finding],
            createdAt: now,
            updatedAt: now
        )
    )

    let started = LaunchGate()
    let gate = LaunchGate()
    let engine = Engine(
        pmProfileStore: pmProfiles,
        pmDelegationStore: pmDelegations,
        analystCharterStore: charters,
        analystTaskStore: tasks,
        analystWorkerLauncher: ProgressLauncher(
            started: started,
            gate: gate,
            launchedAt: now.addingTimeInterval(1)
        )
    )

    let launchTask = Task {
        try await engine.launchAnalystWorkerForPMDelegation(delegationID: "delegation-1")
    }

    await started.wait()

    let pollDeadline = Date().addingTimeInterval(2)
    var inFlightDelegation = try #require(await pmDelegations.get(id: "delegation-1"))
    while inFlightDelegation.lastLaunch?.progressStage != "context_resolved",
          Date() < pollDeadline {
        try await Task.sleep(nanoseconds: 20_000_000)
        inFlightDelegation = try #require(await pmDelegations.get(id: "delegation-1"))
    }

    #expect(inFlightDelegation.status == .issued)
    #expect(inFlightDelegation.lastLaunch?.status == .progressing)
    #expect(inFlightDelegation.lastLaunch?.progressStage == "context_resolved")
    #expect(inFlightDelegation.lastLaunch?.summary == "Current charter, task, and app-owned context were resolved.")
    #expect(inFlightDelegation.lastLaunch?.completedAt == nil)

    await gate.resume()
    let result = try await launchTask.value
    #expect(result.delegationId == "delegation-1")

    let completedDelegation = try #require(await pmDelegations.get(id: "delegation-1"))
    #expect(completedDelegation.status == .completed)
    #expect(completedDelegation.lastLaunch?.status == .healthy)
    #expect(completedDelegation.lastLaunch?.progressStage == "completed")
    #expect(completedDelegation.lastLaunch?.completedAt != nil)
}

@Test("Engine analyst worker launch failures keep bounded operator detail")
func engineAnalystWorkerLaunchFailureKeepsBoundedDetail() async {
    struct FailingLauncher: AnalystWorkerLaunching {
        func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
            throw AnalystWorkerLaunchError.workerExited(
                code: 1,
                summary: "external evidence degraded: category=http_status host=aiindex.stanford.edu status=503 detail=non_success_status"
            )
        }
    }

    let engine = Engine(analystWorkerLauncher: FailingLauncher())

    await #expect(throws: AnalystWorkerLaunchError.workerExited(
        code: 1,
        summary: "external evidence degraded: category=http_status host=aiindex.stanford.edu status=503 detail=non_success_status"
    )) {
        try await engine.launchAnalystWorkerOnce(
            charterID: "charter-1",
            taskID: "task-1",
            draftSignal: false
        )
    }

    let message = AnalystWorkerLaunchError.workerExited(
        code: 1,
        summary: "external evidence degraded: category=http_status host=aiindex.stanford.edu status=503 detail=non_success_status"
    ).localizedDescription
    #expect(message.contains("external evidence degraded"))
    #expect(message.contains("host=aiindex.stanford.edu"))
}

private func makeAnalystControlPlaneTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
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
