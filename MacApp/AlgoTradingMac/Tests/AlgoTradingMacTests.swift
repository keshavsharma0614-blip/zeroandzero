import XCTest
import TradingKit
@testable import AlgoTradingMac

final class AlgoTradingMacTests: XCTestCase {
    private var contentViewPath: String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let appRoot = testsDirectory.deletingLastPathComponent()
        return appRoot.appendingPathComponent("Sources/ContentView.swift").path
    }

    private var ownerSurfacePanelsPath: String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let appRoot = testsDirectory.deletingLastPathComponent()
        return appRoot.appendingPathComponent("Sources/OwnerSurfacePanels.swift").path
    }

    private var settingsViewPath: String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let appRoot = testsDirectory.deletingLastPathComponent()
        return appRoot.appendingPathComponent("Sources/SettingsView.swift").path
    }

    private var memoryDiagnosticsScriptPath: String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let appRoot = testsDirectory.deletingLastPathComponent()
        let repoRoot = appRoot.deletingLastPathComponent().deletingLastPathComponent()
        return repoRoot.appendingPathComponent("scripts/collect_algo_memory_diagnostics.sh").path
    }

    private func sourceIndex(of needle: String, in source: String, file: StaticString = #filePath, line: UInt = #line) -> String.Index {
        guard let index = source.range(of: needle)?.lowerBound else {
            XCTFail("Missing source fragment: \(needle)", file: file, line: line)
            return source.startIndex
        }
        return index
    }

    private func sourceSlice(
        from startNeedle: String,
        to endNeedle: String,
        in source: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        guard let startRange = source.range(of: startNeedle) else {
            XCTFail("Missing source fragment: \(startNeedle)", file: file, line: line)
            return source
        }
        guard let endRange = source.range(
            of: endNeedle,
            range: startRange.lowerBound..<source.endIndex
        ) else {
            XCTFail("Missing source fragment: \(endNeedle)", file: file, line: line)
            return String(source[startRange.lowerBound...])
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    func testTradingKitEngineIsDisconnectedByDefault() async {
        let engine = Engine(configuration: Configuration(environment: .paper))
        let status = await engine.status
        XCTAssertEqual(status, Engine.disconnectedStatus)
    }

    func testStrategyBriefEditorPresentationPrefersPersistedDocumentBody() {
        let document = """
        ## Objective
        Keep the owner-facing brief truthful.

        ## Full Brief Appendix
        Preserve this long-form body exactly as saved.
        """
        let state = StrategyBriefEditorPresentationState(
            brief: PortfolioStrategyBrief(
                title: "Current Portfolio Strategy Brief",
                documentBody: document,
                objectiveSummary: "Keep the owner-facing brief truthful.",
                currentRiskPosture: "Moderate.",
                reviewEscalationPosture: "Escalate material changes.",
                revisionSummary: "Revision metadata stays separate.",
                updatedBy: "human owner",
                updateSource: .userEdited,
                createdAt: Date(timeIntervalSince1970: 1_742_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_742_000_010)
            )
        )

        XCTAssertEqual(state.briefTitle, "Current Portfolio Strategy Brief")
        XCTAssertEqual(state.briefBody, document)
        XCTAssertEqual(state.revisionSummary, "Revision metadata stays separate.")
        XCTAssertFalse(state.briefBody.contains("Revision metadata stays separate."))
        XCTAssertTrue(state.briefBody.contains("## Full Brief Appendix"))
    }

    func testStrategyBriefEditorPresentationTracksFullDocumentViewerStateDeterministically() {
        let longFormBody = Array(repeating: "Long-form paragraph for multi-page viewing.", count: 40)
            .joined(separator: "\n\n")
        var state = StrategyBriefEditorPresentationState(
            briefTitle: "Living Strategy Brief",
            briefBody: longFormBody,
            revisionSummary: "Keep the long-form viewer deterministic."
        )

        XCTAssertFalse(state.isFullDocumentPresented)
        state.presentFullDocument()
        XCTAssertTrue(state.isFullDocumentPresented)
        XCTAssertEqual(state.briefBody, longFormBody)

        state.dismissFullDocument()
        XCTAssertFalse(state.isFullDocumentPresented)
        XCTAssertEqual(state.briefBody, longFormBody)
    }

    func testStrategyBriefEditorPresentationDoesNotInjectDefaultPlaceholderBodyWhenNothingIsLoadedYet() {
        let state = StrategyBriefEditorPresentationState(brief: nil)

        XCTAssertEqual(state.briefTitle, "")
        XCTAssertEqual(state.briefBody, "")
        XCTAssertEqual(state.revisionSummary, "")
        XCTAssertFalse(state.isFullDocumentPresented)
    }

    func testAnalystCharterEditorPresentationPrefersPersistedDocumentBody() {
        let document = """
        # Analyst Charter
        ## Role
        Technology Sector Analyst

        ## Mission
        Preserve this long-form charter body exactly as saved.
        """
        let state = AnalystCharterEditorPresentationState(
            charter: AnalystCharter(
                charterId: "bench-sector-technology",
                analystId: "bench-sector-technology-analyst",
                title: "Technology Analyst",
                coverageScope: "Technology",
                strategyFamily: "standing sector bench",
                summary: "Standing technology charter.",
                documentBody: document,
                revisionSummary: "Revision metadata stays separate.",
                benchRole: .sector,
                updatedBy: "human owner",
                updateSource: .userEdited,
                createdAt: Date(timeIntervalSince1970: 1_742_100_000),
                updatedAt: Date(timeIntervalSince1970: 1_742_100_010)
            )
        )

        XCTAssertEqual(state.charterTitle, "Technology Analyst")
        XCTAssertEqual(state.charterBody, document)
        XCTAssertEqual(state.revisionSummary, "Revision metadata stays separate.")
        XCTAssertFalse(state.charterBody.contains("Revision metadata stays separate."))
        XCTAssertTrue(state.charterBody.contains("Technology Sector Analyst"))
    }

    func testAnalystCharterEditorPresentationTracksFullDocumentViewerStateDeterministically() {
        let longFormBody = Array(repeating: "Long-form charter paragraph for multi-page viewing.", count: 40)
            .joined(separator: "\n\n")
        var state = AnalystCharterEditorPresentationState(
            charterTitle: "Portfolio Risk Analyst",
            charterBody: longFormBody,
            revisionSummary: "Keep the long-form charter viewer deterministic."
        )

        XCTAssertFalse(state.isFullDocumentPresented)
        state.presentFullDocument()
        XCTAssertTrue(state.isFullDocumentPresented)
        XCTAssertEqual(state.charterBody, longFormBody)

        state.dismissFullDocument()
        XCTAssertFalse(state.isFullDocumentPresented)
        XCTAssertEqual(state.charterBody, longFormBody)
    }

    func testAgentSkillEditorPresentationPrefersPersistedDocumentBody() {
        let document = """
        # Custom Method

        ## Purpose
        Keep methodology reusable and bounded.
        """
        let state = AgentSkillEditorPresentationState(
            skill: AgentSkillRecord(
                skillId: "skill-custom-method",
                title: "Custom Method",
                summary: "Owner-authored method.",
                documentBody: document,
                category: .custom,
                tags: ["custom", "method"],
                status: .active,
                revisionSummary: "Revision metadata stays separate.",
                updatedBy: "human owner",
                updateSource: .ownerUI,
                createdAt: Date(timeIntervalSince1970: 1_742_200_000),
                updatedAt: Date(timeIntervalSince1970: 1_742_200_010)
            )
        )

        XCTAssertEqual(state.title, "Custom Method")
        XCTAssertEqual(state.summary, "Owner-authored method.")
        XCTAssertEqual(state.documentBody, document)
        XCTAssertEqual(state.category, .custom)
        XCTAssertEqual(state.tags, "custom, method")
        XCTAssertEqual(state.status, .active)
        XCTAssertEqual(state.revisionSummary, "Revision metadata stays separate.")
    }

    func testAnalystStandingScheduleEditorPresentationDefaultsToWeeklyCadence() {
        let presentation = StandingAnalystReportSchedulePresentation(
            scheduleId: "standing-report-bench-sector-technology",
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            analystTitle: "Technology Analyst",
            coverageScope: "Technology",
            benchRole: .sector,
            enabled: true,
            intervalSec: standingAnalystReportDefaultIntervalSec,
            nextRunAt: nil,
            lastRunAt: nil,
            lastRunSummary: nil
        )

        let state = AnalystStandingScheduleEditorState(presentation: presentation)

        XCTAssertTrue(state.enabled)
        XCTAssertEqual(state.intervalValue, 1)
        XCTAssertEqual(state.intervalUnit, .weeks)
        XCTAssertEqual(state.cadenceSummary, "Weekly")
    }

    func testAnalystStandingScheduleEditorPresentationPreservesCustomCadenceDeterministically() {
        var state = AnalystStandingScheduleEditorState(
            enabled: false,
            intervalValue: 2,
            intervalUnit: .weeks
        )

        XCTAssertFalse(state.enabled)
        XCTAssertEqual(state.intervalSec, standingAnalystReportDefaultIntervalSec * 2)
        XCTAssertEqual(state.cadenceSummary, "Every 2 weeks")

        state.intervalValue = 3
        state.intervalUnit = .days

        XCTAssertEqual(state.intervalSec, 3 * 86_400)
        XCTAssertEqual(state.cadenceSummary, "Every 3 days")
    }

    func testRecentNewsAnalystAppearsInOverlayBenchCharterAndScheduleControls() {
        let now = Date(timeIntervalSince1970: 1_744_500_000)
        let charters = StandingAnalystBenchSeed().seededCharters(now: now)
        let sections = makeOwnerFacingStandingAnalystBenchSections(charters: charters)
        let overlaySection = sections.first(where: { $0.id == "overlay" })

        XCTAssertNotNil(overlaySection)
        XCTAssertTrue(overlaySection?.charters.contains(where: {
            $0.charterId == recentNewsStandingAnalystCharterID
                && $0.title == recentNewsStandingAnalystTitle
                && $0.benchRole == .overlay
        }) == true)

        let schedulePresentations = makeStandingAnalystReportSchedulePresentations(
            charters: charters,
            schedules: makeStandingAnalystReportDefaultSchedules().map(ScheduledJobSummary.init(schedule:))
        )
        XCTAssertTrue(schedulePresentations.contains(where: {
            $0.charterId == recentNewsStandingAnalystCharterID
                && $0.analystTitle == recentNewsStandingAnalystTitle
                && $0.benchRole == .overlay
        }))
    }

    func testOwnerFacingPanelsRemoveReloadAffordancesAndExposeStandingRunNow() throws {
        let source = try String(contentsOfFile: ownerSurfacePanelsPath, encoding: .utf8)

        XCTAssertFalse(source.contains("Reload Strategy Brief"))
        XCTAssertFalse(source.contains("Reload Charters"))
        XCTAssertFalse(source.contains("Reload Charter"))
        XCTAssertFalse(source.contains("Reload Stored Charter"))
        XCTAssertFalse(source.contains("Reload Standing Schedules"))
        XCTAssertFalse(source.contains("Reload Schedule"))
        XCTAssertTrue(source.contains("Button(\"Run Now\")"))
    }

    func testCommandCenterRemovesTopChromeAndConversationInstructions() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertFalse(source.contains("OwnerSurfaceSection(\n                    title: \"Command Center\""))
        XCTAssertFalse(source.contains("OwnerSurfaceSection(title: \"Desk Now\")"))
        XCTAssertFalse(source.contains("Use this as the default owner-facing PM desk."))
        XCTAssertFalse(source.contains("Ask the PM for a review, follow-up, clarification, or a new piece of work."))
        XCTAssertFalse(source.contains("No in-app PM conversation is active yet."))
    }

    func testCommandCenterConversationComposeUsesLargerLayoutAndAutoScrollsToLatest() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("private let conversationBottomAnchorID = \"owner-pm-conversation-bottom\""))
        XCTAssertTrue(source.contains("ScrollViewReader { scrollProxy in"))
        XCTAssertTrue(source.contains(".id(conversationBottomAnchorID)"))
        XCTAssertTrue(source.contains("scrollConversationToLatest("))
        XCTAssertTrue(source.contains(".frame(minHeight: 320, maxHeight: 520)"))
        XCTAssertTrue(source.contains(".font(.system(size: 17))"))
        XCTAssertTrue(source.contains(".frame(minHeight: 220)"))
        XCTAssertTrue(source.contains("Button(inFlight ? \"Sending...\" : \"Send To PM\")"))
    }

    func testCommandCenterConversationHistoryEnablesTextSelectionForCopying() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let conversationSection = sourceSlice(
            from: "OwnerSurfaceSection(title: \"Conversation With PM\")",
            to: "CommandCenterStrategyBriefSection(",
            in: source
        )

        XCTAssertTrue(conversationSection.contains(".textSelection(.enabled)"))
    }

    func testCommandCenterExposesResearchSignalReviewWithoutAdvancedTabs() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let commandCenterSection = sourceSlice(
            from: "researchSignalsSection(snapshot: snapshot)",
            to: "OwnerSurfaceSection(title: \"Conversation With PM\")",
            in: source
        )

        XCTAssertTrue(source.contains("OwnerSurfaceSection(title: \"Research Signals\")"))
        XCTAssertTrue(source.contains("Acknowledge FYI Alerts"))
        XCTAssertTrue(source.contains("Open Signals"))
        XCTAssertTrue(source.contains("updateResearchSignal(signalID: signal.signalId, archive: false)"))
        XCTAssertTrue(source.contains("updateResearchSignal(signalID: signal.signalId, archive: true)"))
        XCTAssertTrue(commandCenterSection.contains("researchSignalsSection(snapshot: snapshot)"))
    }

    func testSignalOwnerFacingTextSeparatesFYIAlertsFromDecisionCounts() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("ownerDecisionTopBarValue("))
        XCTAssertTrue(source.contains("signal review"))
        XCTAssertTrue(source.contains("FYI alert"))
        XCTAssertTrue(source.contains("Notify-only, neutral, or low-confidence signals do not count as owner decisions."))
        XCTAssertFalse(source.contains("\\(snapshot.ownerActionableApprovalCount) pending • \\(snapshot.newSignalsCount) new signals"))
    }

    func testSignalDetailUsesReadableLineageByDefault() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let signalLineageSection = sourceSlice(
            from: "private struct AnalystSignalLineageSection",
            to: "private struct AnalystProposalBadge",
            in: source
        )

        XCTAssertTrue(source.contains("SignalLineageReadablePresentation"))
        XCTAssertTrue(source.contains("makeSignalLineageReadablePresentation("))
        XCTAssertTrue(source.contains("DisclosureGroup(\"Technical IDs\")"))
        XCTAssertFalse(source.contains("AnalystSignalLineageSection(lineage:"))
        XCTAssertFalse(signalLineageSection.contains("Text(lineage.taskId ?? \"-\")"))
        XCTAssertFalse(signalLineageSection.contains("Text(lineage.findingId ?? \"-\")"))
        XCTAssertFalse(signalLineageSection.contains("Text(lineage.evidenceBundleId ?? \"-\")"))
    }

    func testOwnerConversationSendPathSurfacesOwnerMessageBeforeAsyncReplyFinishes() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("upsertLocalPMCommunicationMessage(ownerMessage)"))
        XCTAssertTrue(source.contains("Task { @MainActor in"))
        XCTAssertTrue(source.contains("await finishPMConversationReply("))
        XCTAssertTrue(source.contains("func hasVisiblePMConversationMessage("))
        XCTAssertTrue(source.contains("func hasVisiblePMConversationReply("))
    }

    func testAnalystSourceSuggestionReviewIncludesBoundedPMActionControlsAndClosedStateSurfacing() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Open Source Suggestions"))
        XCTAssertTrue(source.contains("Recently Closed Source Suggestions"))
        XCTAssertTrue(source.contains("GroupBox(\"PM Source-Policy Actions\")"))
        XCTAssertTrue(source.contains("Button(\"Add To Preferred Sources\")"))
        XCTAssertTrue(source.contains("Button(\"Add To Restricted Sources\")"))
        XCTAssertTrue(source.contains("Button(\"Dismiss\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Resolution\")"))
    }

    func testAnalystOperationsSurfaceShowsExecutionLifecycleTruth() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Execution State:"))
        XCTAssertTrue(source.contains("Execution Stage:"))
        XCTAssertTrue(source.contains("Last Progress:"))
        XCTAssertTrue(source.contains("summary.executionState.rawValue"))
    }

    func testOwnerFacingPanelsCollapseStrategyBriefAndExposeCloseControls() throws {
        let source = try String(contentsOfFile: ownerSurfacePanelsPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Button(\"Open Brief\")"))
        XCTAssertTrue(source.contains("Button(\"Close\")"))
        XCTAssertFalse(source.contains("Keep the standing portfolio strategy as one living document."))
        XCTAssertFalse(source.contains("Current Strategy Brief Document"))
    }

    func testPMInboxMakesStandingReviewTruthExplicit() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("summaryPill(label: \"Standing Reviews\""))
        XCTAssertFalse(source.contains("summaryPill(label: \"PM Review Queue\""))
        XCTAssertFalse(source.contains("OwnerSurfaceSection(title: \"PM Review Queue\")"))
        XCTAssertFalse(source.contains("Button(\"Record PM Review Summary\")"))
        XCTAssertFalse(source.contains("title: \"Standing Reports Awaiting Review\""))
        XCTAssertFalse(source.contains("No standing analyst reports are currently awaiting PM review."))
        XCTAssertFalse(source.contains("No standing analyst reports have landed in PM Inbox yet."))
    }

    func testMainNavigationPromotesNewsOutsideAdvancedTabs() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let tabViewStart = sourceIndex(of: "TabView(selection: $selectedTab) {", in: source)
        let tabViewEnd = sourceIndex(of: "        }\n        .frame(minWidth: 900, minHeight: 560)", in: source)
        let tabSource = String(source[tabViewStart..<tabViewEnd])

        XCTAssertTrue(tabSource.contains("NewsView()"))
        XCTAssertTrue(tabSource.contains(".tag(MainTab.news)"))
        XCTAssertFalse(tabSource.contains("if visibleAdvancedSurfaces.contains(.news)"))

        let portfolioWatch = sourceIndex(of: "MarketWatchView()", in: tabSource)
        let newsView = sourceIndex(of: "NewsView()", in: tabSource)
        let systemControl = sourceIndex(of: "SystemControlView(selectedTab: $selectedTab)", in: tabSource)
        XCTAssertLessThan(portfolioWatch, newsView)
        XCTAssertLessThan(newsView, systemControl)
    }

    func testSystemControlStorageCleanupIsProminentAndDryRunFirst() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let systemControlSource = sourceSlice(
            from: "struct SystemControlView: View {",
            to: "struct AlgoControlCenterView: View {",
            in: source
        )
        let systemControlBody = sourceSlice(
            from: "var body: some View {",
            to: "private var selectedScheduleSummary",
            in: systemControlSource
        )

        let storagePanel = sourceIndex(of: "maintenancePanel", in: systemControlBody)
        let safetyPanel = sourceIndex(of: "safetyPanel", in: systemControlBody)
        XCTAssertLessThan(storagePanel, safetyPanel)

        XCTAssertTrue(systemControlSource.contains("Storage & Cleanup Summary"))
        XCTAssertTrue(systemControlSource.contains("Old Job Telemetry"))
        XCTAssertTrue(systemControlSource.contains("Preview Old Job Cleanup"))
        XCTAssertTrue(systemControlSource.contains("Delete Eligible Old Jobs"))
        XCTAssertTrue(systemControlSource.contains("Delete Eligible Job Records"))
        XCTAssertTrue(systemControlSource.contains("Advanced Retention Settings"))
        XCTAssertTrue(systemControlSource.contains("runOldJobCleanup(dryRun: true)"))
        XCTAssertTrue(systemControlSource.contains("runOldJobCleanup(dryRun: false)"))
        XCTAssertTrue(systemControlSource.contains("jobTelemetryCleanupBefore: cutoff"))
        XCTAssertTrue(systemControlSource.contains("showOldJobCleanupApplyConfirmation"))
        XCTAssertTrue(systemControlSource.contains("oldJobCleanupCanApply"))
        XCTAssertTrue(systemControlSource.contains("fullRetentionPreviewCompleted == false"))
        XCTAssertFalse(systemControlSource.contains("Button(\"Run Cleanup\")"))
        XCTAssertFalse(systemControlSource.contains("Run Maintenance Now (Apply)"))
    }

    func testPMInboxReordersHighPriorityReviewSectionsAheadOfContextSections() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let reviewDeskStart = sourceIndex(of: "private func reviewDeskDetailView() -> some View {", in: source)
        let reviewDeskEnd = sourceIndex(of: "private var pmWorkingContextGroup: some View {", in: source)
        let reviewDeskSource = String(source[reviewDeskStart..<reviewDeskEnd])

        let recentNewsReview = sourceIndex(of: "recentNewsReviewGroup", in: reviewDeskSource)
        let recentAnalystActivity = sourceIndex(of: "title: \"Recent Analyst Activity\"", in: reviewDeskSource)
        let approvalRequests = sourceIndex(of: "approvalRequestReviewGroup", in: reviewDeskSource)
        let recentDecisions = sourceIndex(of: "decisionReviewGroup", in: reviewDeskSource)
        let workingContext = sourceIndex(of: "pmWorkingContextGroup", in: reviewDeskSource)
        let backgroundSummaries = sourceIndex(of: "pmBackgroundReviewSummaryGroup", in: reviewDeskSource)
        let communicationLog = sourceIndex(of: "pmUserCommunicationGroup", in: reviewDeskSource)

        XCTAssertLessThan(recentNewsReview, recentAnalystActivity)
        XCTAssertLessThan(recentAnalystActivity, workingContext)
        XCTAssertLessThan(approvalRequests, backgroundSummaries)
        XCTAssertLessThan(recentDecisions, communicationLog)
    }

    func testPMInboxSourceIncludesDedicatedRecentNewsReviewSection() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("title: \"Recent News Review\""))
        XCTAssertTrue(source.contains("High-frequency Recent News Analyst cycles stay together here with PM treatment"))
        XCTAssertTrue(source.contains("PMInboxRecentNewsReviewRow"))
    }

    func testRecentNewsReviewSourceShowsCombinedAnalystAndPMDetailSections() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("GroupBox(\"Brief Combined Summary\")"))
        XCTAssertTrue(source.contains("title: \"Supplemental sources checked:\""))
        XCTAssertTrue(source.contains("title: \"PM action:\""))
        XCTAssertTrue(source.contains("title: \"PM runtime:\""))
        XCTAssertTrue(source.contains("GroupBox(\"Recent News Analyst Run\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Material Sources And Support\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Recent News Analyst Runtime\")"))
        XCTAssertTrue(source.contains("technicalDetailsButton(isExpanded: $decisionDetailsExpanded)"))
        XCTAssertTrue(source.contains("if decisionDetailsExpanded {"))
        XCTAssertTrue(source.contains("title: recentNewsWakeUp.isRecentNewsWakeUp ? \"Recent News Review Detail\" : \"PM Decision Detail\""))
    }

    func testAppModelRefreshesKeychainStatusAfterStartupAndSupportsExplicitRefresh() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let startIfNeededStart = sourceIndex(of: "func startIfNeeded() {", in: source)
        let startIfNeededEnd = sourceIndex(of: "func refreshKeychainStatus(forceRefresh: Bool = false) {", in: source)
        let startIfNeededSource = String(source[startIfNeededStart..<startIfNeededEnd])

        XCTAssertTrue(startIfNeededSource.contains("refreshKeychainStatus()"))
        XCTAssertTrue(startIfNeededSource.range(of: "await engine.start()")!.lowerBound < startIfNeededSource.range(of: "refreshKeychainStatus()")!.lowerBound)
        XCTAssertTrue(source.contains("func refreshKeychainStatus(forceRefresh: Bool = false) {"))
        XCTAssertTrue(source.contains("OpenAIKeychainCredentialResolver.clearSharedCache()"))
        XCTAssertTrue(source.contains("func ensureKeychainStatusLoaded() {"))
        XCTAssertTrue(source.contains("refreshKeychainStatus(forceRefresh: true)"))
    }

    func testOwnerEnvironmentFeedPreferenceStorePersistsLiveAndSIPWithoutArmingState() throws {
        let suiteName = "OwnerEnvironmentFeedPreferenceStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertEqual(OwnerEnvironmentFeedPreferenceStore.loadEnvironment(defaults: defaults), .paper)
        XCTAssertEqual(OwnerEnvironmentFeedPreferenceStore.loadMarketDataFeed(defaults: defaults), .stocksIEX)

        OwnerEnvironmentFeedPreferenceStore.saveEnvironment(.live, defaults: defaults)
        OwnerEnvironmentFeedPreferenceStore.saveMarketDataFeed(.stocksSIP, defaults: defaults)

        XCTAssertEqual(OwnerEnvironmentFeedPreferenceStore.loadEnvironment(defaults: defaults), .live)
        XCTAssertEqual(OwnerEnvironmentFeedPreferenceStore.loadMarketDataFeed(defaults: defaults), .stocksSIP)
        XCTAssertNil(defaults.object(forKey: "isArmedForLiveTrading"))
        XCTAssertNil(defaults.object(forKey: "armingSessionID"))
    }

    func testLiveArmedHealthyBannerSeverityIsHealthyAndMentionsGovernedOrderPath() {
        let readiness = AlwaysOnReadinessState(
            status: .active,
            summary: "Active while this Mac is awake, online, and the app is running.",
            detail: AlwaysOnReadinessState.hostAvailabilityContract,
            blockers: [],
            lastUpdatedAt: Date(timeIntervalSince1970: 1_779_120_000)
        )

        XCTAssertEqual(
            makeLiveSafetyBannerSeverity(
                selectedEnvironment: .live,
                isArmedForLiveTrading: true,
                killSwitchEnabled: false,
                readinessStatus: readiness.status
            ),
            .healthy
        )
        XCTAssertEqual(
            makeLiveSafetyStatusDetail(
                selectedEnvironment: .live,
                isArmedForLiveTrading: true,
                killSwitchEnabled: false,
                alwaysOnReadiness: readiness
            ),
            "Live is armed and app-owned readiness is healthy. Live NEW/REPLACE still requires the governed order path and local authentication when enabled."
        )
    }

    func testLiveBannerSeverityNamesBlockersAndKeepsBlockedStatesRed() {
        let degraded = AlwaysOnReadinessState(
            status: .degraded,
            summary: "Monitoring is degraded.",
            detail: AlwaysOnReadinessState.hostAvailabilityContract,
            blockers: ["Trade-update stream is disconnected."],
            lastUpdatedAt: Date(timeIntervalSince1970: 1_779_120_010)
        )

        XCTAssertEqual(
            makeLiveSafetyBannerSeverity(
                selectedEnvironment: .live,
                isArmedForLiveTrading: true,
                killSwitchEnabled: false,
                readinessStatus: degraded.status
            ),
            .degraded
        )
        XCTAssertEqual(
            makeLiveSafetyStatusDetail(
                selectedEnvironment: .live,
                isArmedForLiveTrading: true,
                killSwitchEnabled: false,
                alwaysOnReadiness: degraded
            ),
            "Live is armed; green requires readiness to clear: Trade-update stream is disconnected."
        )

        XCTAssertEqual(
            makeLiveSafetyBannerSeverity(
                selectedEnvironment: .live,
                isArmedForLiveTrading: false,
                killSwitchEnabled: false,
                readinessStatus: .active
            ),
            .blocked
        )
        XCTAssertEqual(
            makeLiveSafetyBannerSeverity(
                selectedEnvironment: .live,
                isArmedForLiveTrading: true,
                killSwitchEnabled: true,
                readinessStatus: .active
            ),
            .blocked
        )
        XCTAssertEqual(
            makeLiveSafetyBannerSeverity(
                selectedEnvironment: .paper,
                isArmedForLiveTrading: true,
                killSwitchEnabled: false,
                readinessStatus: .active
            ),
            .hidden
        )
    }

    func testCommandCenterTopBarUsesStreamLabelsAndActiveBackgroundCounts() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let topBarSource = sourceSlice(
            from: "private var commandCenterTopBar: some View {",
            to: "private func commandCenterChip(title: String, value: String) -> some View {",
            in: source
        )

        XCTAssertTrue(topBarSource.contains("ForEach(appModel.commandCenterTopBarChips)"))
        XCTAssertTrue(source.contains("tradeStreamOwnerFacingLabel: tradeReadiness.label"))
        XCTAssertTrue(source.contains("marketDataOwnerFacingLabel: marketDataReadiness.label"))
        XCTAssertTrue(source.contains("pmCommandCenterSnapshot.activeAnalystBackgroundCount"))
        XCTAssertTrue(source.contains("pmCommandCenterSnapshot.activePMBackgroundCount"))
        XCTAssertFalse(topBarSource.contains("snapshot.activeDecisionCount) PM"))
    }

    func testAppModelStartupStagesConversationLoadsBeforeDeferredRefreshes() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let startIfNeededStart = sourceIndex(of: "func startIfNeeded() {", in: source)
        let startIfNeededEnd = sourceIndex(of: "func refreshKeychainStatus(forceRefresh: Bool = false) {", in: source)
        let startIfNeededSource = String(source[startIfNeededStart..<startIfNeededEnd])

        XCTAssertTrue(startIfNeededSource.contains("await runStartupConversationReadyRefreshes()"))
        XCTAssertTrue(startIfNeededSource.contains("await self?.runDeferredStartupRefreshes()"))

        let criticalStart = sourceIndex(of: "private func runStartupConversationReadyRefreshes() async {", in: source)
        let criticalEnd = sourceIndex(of: "private func runDeferredStartupRefreshes() async {", in: source)
        let criticalSource = String(source[criticalStart..<criticalEnd])

        XCTAssertTrue(criticalSource.contains("await refreshSnapshotFromStore()"))
        XCTAssertTrue(criticalSource.contains("refreshPMCommunicationMessages(refreshContextPack: false)"))
        XCTAssertTrue(criticalSource.contains("refreshTelegramBridgeStatus()"))
        XCTAssertTrue(criticalSource.contains("startTelegramBridgePollingLoopIfNeeded()"))
    }

    func testPMInboxSelectionRetentionDefaultsToCollapsedState() {
        XCTAssertNil(makePMInboxRetainedSelection(currentSelectionID: nil, availableIDs: ["a", "b"]))
        XCTAssertNil(makePMInboxRetainedSelection(currentSelectionID: "missing", availableIDs: ["a", "b"]))
        XCTAssertEqual(makePMInboxRetainedSelection(currentSelectionID: "b", availableIDs: ["a", "b"]), "b")
    }

    func testPMInboxRecentAnalystActivityItemsPreferRecentDurableAnalystArtifactsAndStayBoundedToFive() {
        let baseDate = Date(timeIntervalSince1970: 1_744_000_000)
        let charter = AnalystCharter(
            charterId: "charter-tech",
            analystId: "technology_analyst",
            title: "Technology Analyst",
            coverageScope: "Technology sector",
            strategyFamily: "Sector standing review",
            summary: "Find candidate ideas",
            constraints: [],
            createdAt: baseDate,
            updatedAt: baseDate
        )
        let memo0 = AnalystMemo(
            memoId: "memo-0",
            analystId: "technology_analyst",
            charterId: charter.charterId,
            title: "Memo 0",
            executiveSummary: "Memo summary 0",
            currentView: "Current view 0",
            evidenceSummary: "Evidence 0",
            uncertaintySummary: "Uncertainty 0",
            recommendedNextStep: "Next step 0",
            confidence: 0.7,
            createdAt: baseDate,
            updatedAt: baseDate.addingTimeInterval(300)
        )
        let memo1 = AnalystMemo(
            memoId: "memo-1",
            analystId: "technology_analyst",
            charterId: charter.charterId,
            title: "Memo 1",
            executiveSummary: "Memo summary 1",
            currentView: "Current view 1",
            evidenceSummary: "Evidence 1",
            uncertaintySummary: "Uncertainty 1",
            recommendedNextStep: "Next step 1",
            confidence: 0.7,
            createdAt: baseDate.addingTimeInterval(1),
            updatedAt: baseDate.addingTimeInterval(301)
        )
        let memo2 = AnalystMemo(
            memoId: "memo-2",
            analystId: "technology_analyst",
            charterId: charter.charterId,
            delegationId: "delegation-2",
            title: "Memo 2",
            executiveSummary: "Memo summary 2",
            currentView: "Current view 2",
            evidenceSummary: "Evidence 2",
            uncertaintySummary: "Uncertainty 2",
            recommendedNextStep: "Next step 2",
            confidence: 0.7,
            createdAt: baseDate.addingTimeInterval(2),
            updatedAt: baseDate.addingTimeInterval(250)
        )
        let memos = [memo0, memo1, memo2]

        let report0 = AnalystStandingReport(
            reportId: "report-0",
            deliveryStatus: .pendingPMReview,
            analystId: "technology_analyst",
            charterId: charter.charterId,
            scheduleId: "schedule-0",
            memoId: memo0.memoId,
            title: "Standing report 0",
            summary: "Standing summary 0",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Candidate idea 0",
            portfolioRelevanceSummary: "Relevance 0",
            deliveredToPMInboxAt: baseDate.addingTimeInterval(200),
            createdAt: baseDate.addingTimeInterval(200),
            updatedAt: baseDate.addingTimeInterval(300)
        )
        let report1 = AnalystStandingReport(
            reportId: "report-1",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: charter.charterId,
            scheduleId: "schedule-1",
            memoId: memo1.memoId,
            title: "Standing report 1",
            summary: "Standing summary 1",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Candidate idea 1",
            portfolioRelevanceSummary: "Relevance 1",
            deliveredToPMInboxAt: baseDate.addingTimeInterval(201),
            createdAt: baseDate.addingTimeInterval(201),
            updatedAt: baseDate.addingTimeInterval(301)
        )
        let report2 = AnalystStandingReport(
            reportId: "report-2",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: charter.charterId,
            scheduleId: "schedule-2",
            memoId: memo0.memoId,
            title: "Standing report 2",
            summary: "Standing summary 2",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Candidate idea 2",
            portfolioRelevanceSummary: "Relevance 2",
            deliveredToPMInboxAt: baseDate.addingTimeInterval(120),
            createdAt: baseDate.addingTimeInterval(202),
            updatedAt: baseDate.addingTimeInterval(302)
        )
        let report3 = AnalystStandingReport(
            reportId: "report-3",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: charter.charterId,
            scheduleId: "schedule-3",
            memoId: memo1.memoId,
            title: "Standing report 3",
            summary: "Standing summary 3",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Candidate idea 3",
            portfolioRelevanceSummary: "Relevance 3",
            deliveredToPMInboxAt: baseDate.addingTimeInterval(121),
            createdAt: baseDate.addingTimeInterval(203),
            updatedAt: baseDate.addingTimeInterval(303)
        )
        let reports = [report0, report1, report2, report3]

        let delegation0 = PMDelegationRecord(
            delegationId: "delegation-0",
            pmId: "pm",
            analystId: "technology_analyst",
            charterId: charter.charterId,
            title: "Delegation 0",
            rationale: "Delegation rationale 0",
            createdAt: baseDate.addingTimeInterval(50),
            updatedAt: baseDate.addingTimeInterval(400)
        )
        let delegation1 = PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm",
            analystId: "technology_analyst",
            charterId: charter.charterId,
            title: "Delegation 1",
            rationale: "Delegation rationale 1",
            createdAt: baseDate.addingTimeInterval(51),
            updatedAt: baseDate.addingTimeInterval(401)
        )
        let delegation2 = PMDelegationRecord(
            delegationId: "delegation-2",
            pmId: "pm",
            analystId: "technology_analyst",
            charterId: charter.charterId,
            title: "Delegation 2",
            rationale: "Delegation rationale 2",
            createdAt: baseDate.addingTimeInterval(52),
            updatedAt: baseDate.addingTimeInterval(52)
        )
        let delegations = [delegation0, delegation1, delegation2]
        let standingReportSummaries = makeStandingAnalystReportReviewSummaryPresentations(
            reports: reports,
            memos: memos,
            charters: [charter]
        )

        let items = makePMInboxRecentAnalystActivityItems(
            standingReportSummaries: standingReportSummaries,
            reports: reports,
            memos: memos,
            charters: [charter],
            delegations: delegations
        )

        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.first?.kind, .standingReport)
        XCTAssertEqual(items.first?.headline, "Standing report 3")
        XCTAssertEqual(items.map(\.kind), [.standingReport, .standingReport, .standingReport, .standingReport, .analystMemo])
        XCTAssertEqual(items.last?.headline, "Memo 2")
        XCTAssertFalse(items.contains(where: { $0.kind == .delegation }))
    }

    func testPMInboxRecentAnalystActivityItemsExcludeRecentNewsChurnFromGeneralLane() {
        let now = Date(timeIntervalSince1970: 1_744_350_000)
        let technologyCharter = AnalystCharter(
            charterId: "charter-tech",
            analystId: "technology_analyst",
            title: "Technology Analyst",
            coverageScope: "Technology",
            strategyFamily: "Standing bench",
            summary: "Technology summary",
            constraints: [],
            createdAt: now,
            updatedAt: now
        )
        let recentNewsCharter = AnalystCharter(
            charterId: recentNewsStandingAnalystCharterID,
            analystId: recentNewsStandingAnalystID,
            title: recentNewsStandingAnalystTitle,
            coverageScope: "Recent news",
            strategyFamily: "Recent news",
            summary: "Recent news summary",
            constraints: [],
            createdAt: now,
            updatedAt: now
        )
        let technologyMemo = AnalystMemo(
            memoId: "memo-tech",
            analystId: "technology_analyst",
            charterId: technologyCharter.charterId,
            delegationId: "delegation-tech",
            title: "Technology memo",
            executiveSummary: "Technology summary",
            currentView: "Technology view",
            evidenceSummary: "Technology evidence",
            uncertaintySummary: "Technology uncertainty",
            recommendedNextStep: "Technology next step",
            confidence: 0.7,
            createdAt: now,
            updatedAt: now.addingTimeInterval(20)
        )
        let recentNewsMemo = AnalystMemo(
            memoId: "memo-news",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            delegationId: "recent-news-delegation-1",
            title: "Recent News Analyst memo",
            executiveSummary: "Recent news summary",
            currentView: "Recent news view",
            evidenceSummary: "Recent news evidence",
            uncertaintySummary: "Recent news uncertainty",
            recommendedNextStep: "Recent news next step",
            confidence: 0.8,
            createdAt: now.addingTimeInterval(5),
            updatedAt: now.addingTimeInterval(30)
        )

        let items = makePMInboxRecentAnalystActivityItems(
            standingReportSummaries: [],
            reports: [],
            memos: [technologyMemo, recentNewsMemo],
            charters: [technologyCharter, recentNewsCharter],
            delegations: []
        )

        XCTAssertEqual(items.map(\.headline), ["Technology memo"])
    }

    func testRecentNewsReviewDecisionsPreferNewestRecentNewsCycles() {
        let now = Date(timeIntervalSince1970: 1_744_360_000)
        let olderTask = AnalystTask(
            taskId: "recent-news-task-older",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            title: "Older recent news task",
            description: "Older description",
            status: .completed,
            createdAt: now,
            updatedAt: now,
            symbols: ["NVDA"],
            tags: ["recent-news-analyst"]
        )
        let newerTask = AnalystTask(
            taskId: "recent-news-task-newer",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            title: "Newer recent news task",
            description: "Newer description",
            status: .completed,
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60),
            symbols: ["MSFT"],
            tags: ["recent-news-analyst"]
        )
        let recentNewsOlder = PMDecisionRecord(
            decisionId: "decision-news-older",
            pmId: "pm-1",
            title: "Recent News Analyst escalation: NVDA",
            summary: "Older recent-news escalation",
            charterId: recentNewsStandingAnalystCharterID,
            taskId: olderTask.taskId,
            createdAt: now.addingTimeInterval(90),
            updatedAt: now.addingTimeInterval(90)
        )
        let recentNewsNewer = PMDecisionRecord(
            decisionId: "decision-news-newer",
            pmId: "pm-1",
            title: "Recent News Analyst escalation: MSFT",
            summary: "Newer recent-news escalation",
            charterId: recentNewsStandingAnalystCharterID,
            taskId: newerTask.taskId,
            createdAt: now.addingTimeInterval(180),
            updatedAt: now.addingTimeInterval(180)
        )
        let generalDecision = PMDecisionRecord(
            decisionId: "decision-general",
            pmId: "pm-1",
            title: "Technology follow-up",
            summary: "General decision",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(240),
            updatedAt: now.addingTimeInterval(240)
        )

        let decisions = makeRecentNewsReviewDecisionsForPMInbox(
            decisions: [generalDecision, recentNewsOlder, recentNewsNewer],
            tasks: [olderTask, newerTask],
            delegations: []
        )

        XCTAssertEqual(decisions.map(\.decisionId), ["decision-news-newer", "decision-news-older"])
    }

    func testRecentNewsReviewSummaryPresentationCarriesAnalystSupportRuntimeAndPMTreatment() {
        let now = Date(timeIntervalSince1970: 1_744_365_000)
        let runtimePolicy = AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.4-mini",
            reasoningMode: .deliberate,
            policySource: .specializationDefault,
            createdAt: now,
            updatedAt: now
        )
        let runtimeProvenance = AnalystRuntimeProvenance(
            intendedPolicy: runtimePolicy,
            actualRuntimeIdentifier: "openai_responses[gpt-5.4-mini]",
            actualReasoningMode: .deliberate,
            launchedAt: now
        )
        let task = AnalystTask(
            taskId: "recent-news-task-1",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            title: "Recent news materiality review",
            description: "Triggering news: FDA accepted the updated filing for NVDA supplier tooling. Why now: The filing timing could shift near-term sentiment for names already in scope. Review posture: Keep PM monitoring active.",
            status: .completed,
            createdAt: now,
            updatedAt: now,
            symbols: ["NVDA"],
            tags: ["recent-news-analyst"]
        )
        let memo = AnalystMemo(
            memoId: "memo-news-1",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            delegationId: "recent-news-delegation-1",
            evidenceBundleId: "bundle-news-1",
            title: "Recent News Analyst memo",
            executiveSummary: "FDA filing progress is the material development for NVDA-adjacent tooling.",
            currentView: "The update matters because it could tighten near-term sentiment for NVDA-linked suppliers already on the watchlist.",
            evidenceSummary: "Grounded in app-owned news plus a company filing.",
            uncertaintySummary: "The read stays bounded until the company confirms shipment timing.",
            recommendedNextStep: "Keep the cycle in PM monitoring and verify follow-through on the filing timeline.",
            confidence: 0.74,
            runtimeProvenance: runtimeProvenance,
            createdAt: now,
            updatedAt: now.addingTimeInterval(30)
        )
        let evidenceBundle = AnalystEvidenceBundle(
            bundleId: "bundle-news-1",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            refs: [
                AnalystEvidenceRef(
                    refId: "ref-app-news",
                    sourceKind: .appNews,
                    appEntityID: "news-1",
                    title: "FDA filing update hits NVDA supply chain names",
                    observedAt: now,
                    summary: "App-owned recent news highlighted the timing change."
                ),
                AnalystEvidenceRef(
                    refId: "ref-web",
                    sourceKind: .web,
                    sourceIdentifier: "issuer release",
                    title: "Issuer filing confirms updated review timing",
                    observedAt: now,
                    summary: "Adds incremental timing, background, or strategic/risk context beyond the baseline.",
                    freshnessNote: "supplemental_public_web_from_app_news"
                )
            ],
            summary: "Bounded recent-news support for the filing update.",
            notes: "Primary filing timing is the key support.",
            createdAt: now,
            updatedAt: now
        )
        let decision = PMDecisionRecord(
            decisionId: "decision-news-1",
            pmId: "pm-1",
            title: "Recent News Analyst escalation: NVDA supply-chain filing",
            summary: "PM is keeping this in monitor-only posture for now.",
            delegationId: "recent-news-delegation-1",
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )

        let detail = makePMInboxRecentNewsReviewDetailPresentation(
            decision: decision,
            linkedTask: task,
            linkedMemo: memo,
            linkedEvidenceBundle: evidenceBundle,
            linkedDelegation: nil,
            positions: [],
            watchlistSymbols: ["NVDA"],
            strategyBrief: nil
        )
        let summary = makePMInboxRecentNewsReviewSummaryPresentation(
            detail: detail,
            pmTreatmentSummary: "Worth monitoring in PM background review.",
            affectedNames: "Watchlist only: NVDA",
            nextStep: "Keep PM monitoring active."
        )

        XCTAssertEqual(summary.analystSummary, "FDA accepted the updated filing for NVDA supplier tooling.")
        XCTAssertEqual(summary.pmTreatmentSummary, "Worth monitoring in PM background review.")
        XCTAssertEqual(summary.affectedNames, "Watchlist only: NVDA")
        XCTAssertTrue(summary.analystSupportSummary?.contains("App-owned recent news") == true)
        XCTAssertTrue(summary.analystRuntimeSummary.contains("OpenAI Responses model gpt-5.4-mini"))
    }

    func testRecentNewsReviewDetailPresentationIncludesAnalystSourceRuntimeAndCaveatTruth() {
        let now = Date(timeIntervalSince1970: 1_744_366_000)
        let runtimePolicy = AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .standard,
            policySource: .specializationDefault,
            createdAt: now,
            updatedAt: now
        )
        let runtimeProvenance = AnalystRuntimeProvenance(
            intendedPolicy: runtimePolicy,
            actualRuntimeIdentifier: "deterministic_local_fallback[gpt-5.4]",
            actualReasoningMode: .standard,
            launchedAt: now
        )
        let task = AnalystTask(
            taskId: "recent-news-task-2",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            title: "Recent news materiality review",
            description: "Triggering news: Energy inventory data and OPEC guidance landed together. Why now: The combined update could alter near-term Energy / Materials interpretation. Review posture: Decide whether another analyst pass is warranted.",
            status: .completed,
            createdAt: now,
            updatedAt: now,
            symbols: ["XOM", "CVX"],
            tags: ["recent-news-analyst"]
        )
        let memo = AnalystMemo(
            memoId: "memo-news-2",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            evidenceBundleId: "bundle-news-2",
            title: "Recent News Analyst memo",
            executiveSummary: "The energy update cluster is material enough for PM attention.",
            currentView: "The current view stays bounded because inventory and policy signals are directionally aligned but not fully confirming.",
            evidenceSummary: "Grounded in app-owned energy headlines and OPEC commentary.",
            uncertaintySummary: "Commodity follow-through remains uncertain until price action confirms the policy signal.",
            recommendedNextStep: "Keep monitoring the cluster and request follow-up only if price action confirms the shift.",
            confidence: 0.68,
            runtimeProvenance: runtimeProvenance,
            createdAt: now,
            updatedAt: now.addingTimeInterval(45)
        )
        let evidenceBundle = AnalystEvidenceBundle(
            bundleId: "bundle-news-2",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            refs: [
                AnalystEvidenceRef(
                    refId: "ref-app-news-2",
                    sourceKind: .appNews,
                    sourceIdentifier: "rss_marketwatch_rss",
                    appEntityID: "news-2",
                    title: "OPEC guidance lands alongside inventory draw",
                    observedAt: now,
                    summary: "App-owned recent news identified the clustered event."
                ),
                AnalystEvidenceRef(
                    refId: "ref-web-2",
                    sourceKind: .web,
                    sourceIdentifier: "Axios",
                    url: "https://www.axios.com/2026/04/07/energy-producers",
                    title: "Axios follow-up on energy producers",
                    observedAt: now,
                    summary: "Supplemental source confirms how producers framed the update."
                )
            ],
            summary: "Energy cluster support bundle.",
            createdAt: now,
            updatedAt: now
        )
        let decision = PMDecisionRecord(
            decisionId: "decision-news-2",
            pmId: "pm-1",
            title: "Recent News Analyst escalation: Energy cluster",
            summary: "PM kept the cycle in bounded monitoring.",
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            createdAt: now.addingTimeInterval(90),
            updatedAt: now.addingTimeInterval(90)
        )

        let detail = makePMInboxRecentNewsReviewDetailPresentation(
            decision: decision,
            linkedTask: task,
            linkedMemo: memo,
            linkedEvidenceBundle: evidenceBundle,
            linkedDelegation: nil,
            positions: [PositionRow(id: "position-xom", symbol: "XOM", side: "long", qty: "10", marketValue: "950")],
            watchlistSymbols: ["CVX"],
            strategyBrief: nil,
            rssFeeds: [
                RSSFeed(
                    id: "rss-marketwatch",
                    name: "MarketWatch RSS",
                    url: "https://www.marketwatch.com/rss",
                    enabled: true,
                    pollIntervalSec: 300,
                    tags: []
                )
            ]
        )

        XCTAssertTrue(detail.analystFindingSummary.contains("Energy inventory data and OPEC guidance"))
        XCTAssertEqual(
            detail.analystMaterialDevelopments,
            ["OPEC guidance lands alongside inventory draw (MarketWatch RSS)"]
        )
        XCTAssertTrue(detail.analystCurrentView.contains("directionally aligned"))
        XCTAssertTrue(detail.analystMaterialSourceSummary?.contains("App-owned recent news") == true)
        XCTAssertEqual(detail.analystSupplementalSourcesReviewed, ["Axios"])
        XCTAssertTrue(detail.sourceTruth?.primarySources.first?.contains("OPEC guidance lands alongside inventory draw") == true)
        XCTAssertTrue(detail.executionTruth.executionUsedSummary.contains("Local synthesis fallback profile gpt-5.4"))
        XCTAssertEqual(detail.affectedHoldings, ["XOM"])
        XCTAssertEqual(detail.affectedWatchlistOnly, ["CVX"])
        XCTAssertTrue(detail.analystUncertaintySummary?.contains("Commodity follow-through remains uncertain") == true)
    }

    func testRecentNewsReviewDetailPresentationPreservesOpenAIRuntimeTruthWhenMemoRecordsWorkerBackedRun() {
        let now = Date(timeIntervalSince1970: 1_744_367_000)
        let runtimePolicy = AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.4-mini",
            reasoningMode: .standard,
            policySource: .specializationDefault,
            createdAt: now,
            updatedAt: now
        )
        let runtimeProvenance = AnalystRuntimeProvenance(
            intendedPolicy: runtimePolicy,
            actualRuntimeIdentifier: "openai_responses[gpt-5.4-mini]",
            actualReasoningMode: .standard,
            launchedAt: now
        )
        let task = AnalystTask(
            taskId: "recent-news-task-3",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            title: "Recent news materiality review",
            description: "Triggering news: Supply-chain software demand commentary broadened. Why now: The reporting cluster may reshape near-term Technology monitoring. Review posture: Decide whether another analyst pass is warranted.",
            status: .completed,
            createdAt: now,
            updatedAt: now,
            symbols: ["MSFT"],
            tags: ["recent-news-analyst"]
        )
        let memo = AnalystMemo(
            memoId: "memo-news-3",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            title: "Recent News Analyst memo",
            executiveSummary: "The technology demand cluster is worth bounded PM monitoring.",
            currentView: "Signals are interesting but still need confirmation from management commentary.",
            evidenceSummary: "Grounded in app-owned recent news and supplemental reporting.",
            uncertaintySummary: "Need more confirmation from company disclosures.",
            recommendedNextStep: "Keep the theme in PM background review unless filings confirm the shift.",
            confidence: 0.7,
            runtimeProvenance: runtimeProvenance,
            createdAt: now,
            updatedAt: now.addingTimeInterval(30)
        )
        let decision = PMDecisionRecord(
            decisionId: "decision-news-3",
            pmId: "pm-1",
            title: "Recent News Analyst escalation: technology demand cluster",
            summary: "PM is keeping the cycle in bounded monitoring.",
            charterId: recentNewsStandingAnalystCharterID,
            taskId: task.taskId,
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )

        let detail = makePMInboxRecentNewsReviewDetailPresentation(
            decision: decision,
            linkedTask: task,
            linkedMemo: memo,
            linkedEvidenceBundle: nil,
            linkedDelegation: nil,
            positions: [],
            watchlistSymbols: ["MSFT"],
            strategyBrief: nil
        )

        XCTAssertTrue(detail.executionTruth.executionUsedSummary.contains("OpenAI Responses model gpt-5.4-mini"))
        XCTAssertTrue(detail.executionTruth.summary.contains("OpenAI Responses API-backed worker path"))
    }

    func testRecentNewsReviewDetailPresentationUsesStandingReportLinkageForOpenAIRuntimeTruth() {
        let now = Date(timeIntervalSince1970: 1_744_367_800)
        let runtimePolicy = AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            policySource: .charterDefault,
            createdAt: now,
            updatedAt: now
        )
        let runtimeProvenance = AnalystRuntimeProvenance(
            intendedPolicy: runtimePolicy,
            actualRuntimeIdentifier: "openai_responses[gpt-4.1]",
            actualReasoningMode: .standard,
            launchedAt: now
        )
        let memo = AnalystMemo(
            memoId: "memo-news-standing-1",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            title: "Recent News Analyst memo",
            executiveSummary: "Recent app-news and supplemental checks support bounded PM monitoring.",
            currentView: "The cluster is worth background PM attention while remaining uncertainty-aware.",
            evidenceSummary: "App news stayed primary, with supplemental checks recorded in the bundle.",
            uncertaintySummary: "Need follow-through confirmation.",
            recommendedNextStep: "Keep the issue in PM monitoring until the next cycle.",
            confidence: 0.71,
            runtimeProvenance: runtimeProvenance,
            createdAt: now,
            updatedAt: now.addingTimeInterval(30)
        )
        let standingReport = AnalystStandingReport(
            reportId: "standing-report-recent-news-1",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            scheduleId: "default-recent-news-analyst",
            memoId: memo.memoId,
            runtimeProvenance: runtimeProvenance,
            title: "Recent News Update",
            summary: "Bounded update.",
            cadenceIntervalSec: 3600,
            reportingWindowSummary: "Last hour",
            portfolioScopeSummary: "Watchlist",
            headlineView: "Recent news update",
            portfolioRelevanceSummary: "Bounded PM attention",
            deliveredToPMInboxAt: now.addingTimeInterval(45),
            createdAt: now.addingTimeInterval(45),
            updatedAt: now.addingTimeInterval(45)
        )
        let decision = PMDecisionRecord(
            decisionId: "decision-news-standing-1",
            pmId: "pm-1",
            title: "Standing review conclusion: Recent News Update",
            summary: "PM kept the cycle in bounded monitoring.",
            charterId: recentNewsStandingAnalystCharterID,
            primaryStandingReportId: standingReport.reportId,
            standingReportIds: [standingReport.reportId],
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )

        let detail = makePMInboxRecentNewsReviewDetailPresentation(
            decision: decision,
            linkedTask: nil,
            linkedMemo: nil,
            linkedEvidenceBundle: nil,
            linkedDelegation: nil,
            positions: [],
            watchlistSymbols: [],
            strategyBrief: nil,
            linkedStandingReport: standingReport
        )

        XCTAssertTrue(detail.executionTruth.executionUsedSummary.contains("OpenAI Responses model gpt-4.1"))
        XCTAssertTrue(detail.executionTruth.summary.contains("worker-backed OpenAI Responses execution"))
    }

    func testRecentNewsReviewDetailPresentationUsesReadableSupplementalSourceLabelsFromRecordedHosts() {
        let now = Date(timeIntervalSince1970: 1_744_368_000)
        let evidenceBundle = AnalystEvidenceBundle(
            bundleId: "bundle-news-sources-1",
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            refs: [
                AnalystEvidenceRef(
                    refId: "ref-web-nyse",
                    sourceKind: .web,
                    sourceIdentifier: "planned-source-source-https-nyse-com",
                    url: "https://www.nyse.com/news/issuer-update",
                    title: "NYSE issuer update",
                    observedAt: now
                ),
                AnalystEvidenceRef(
                    refId: "ref-web-cftc",
                    sourceKind: .web,
                    sourceIdentifier: "planned-source-source-https-cftc-gov",
                    url: "https://www.cftc.gov/PressRoom/PressReleases/1234",
                    title: "CFTC release",
                    observedAt: now.addingTimeInterval(5)
                )
            ],
            summary: "Supplemental source checks.",
            createdAt: now,
            updatedAt: now
        )
        let decision = PMDecisionRecord(
            decisionId: "decision-news-sources-1",
            pmId: "pm-1",
            title: "Recent News Analyst escalation: supplemental source labels",
            summary: "PM kept the cycle in bounded monitoring.",
            charterId: recentNewsStandingAnalystCharterID,
            createdAt: now.addingTimeInterval(10),
            updatedAt: now.addingTimeInterval(10)
        )

        let detail = makePMInboxRecentNewsReviewDetailPresentation(
            decision: decision,
            linkedTask: nil,
            linkedMemo: nil,
            linkedEvidenceBundle: evidenceBundle,
            linkedDelegation: nil,
            positions: [],
            watchlistSymbols: [],
            strategyBrief: nil
        )

        XCTAssertEqual(detail.analystSupplementalSourcesReviewed, ["NYSE", "CFTC"])
    }

    func testRecentPMDecisionsCanUseBroaderAnalystScopeThanVisibleFiveRows() {
        let now = Date(timeIntervalSince1970: 1_744_370_000)
        let visibleActivity = (0..<5).map { index in
            PMInboxRecentAnalystActivityItem(
                id: "standing:visible-\(index)",
                kind: .standingReport,
                analystTitle: "Technology Analyst",
                timestamp: now.addingTimeInterval(TimeInterval(500 - index)),
                headline: "Visible \(index)",
                summary: "Summary \(index)",
                linkedStandingReportID: "report-visible-\(index)",
                linkedMemoID: "memo-visible-\(index)",
                linkedDelegationID: nil
            )
        }
        let scopeOnlyActivity = PMInboxRecentAnalystActivityItem(
            id: "standing:scope-only",
            kind: .standingReport,
            analystTitle: "Technology Analyst",
            timestamp: now.addingTimeInterval(10),
            headline: "Scope only activity",
            summary: "Scope only summary",
            linkedStandingReportID: "report-scope",
            linkedMemoID: "memo-scope",
            linkedDelegationID: nil
        )
        let scopeItems = visibleActivity + [scopeOnlyActivity]
        let reports = visibleActivity.enumerated().map { index, _ in
            AnalystStandingReport(
                reportId: "report-visible-\(index)",
                deliveryStatus: .reviewedByPM,
                analystId: "technology_analyst",
                charterId: "charter-visible-\(index)",
                scheduleId: "schedule-visible-\(index)",
                memoId: "memo-visible-\(index)",
                title: "Visible report \(index)",
                summary: "Visible summary \(index)",
                cadenceIntervalSec: 604_800,
                reportingWindowSummary: "This week",
                portfolioScopeSummary: "No current portfolio",
                headlineView: "Visible headline \(index)",
                portfolioRelevanceSummary: "Visible relevance \(index)",
                deliveredToPMInboxAt: now,
                createdAt: now,
                updatedAt: now
            )
        } + [
            AnalystStandingReport(
                reportId: "report-scope",
                deliveryStatus: .reviewedByPM,
                analystId: "technology_analyst",
                charterId: "charter-scope",
                scheduleId: "schedule-scope",
                memoId: "memo-scope",
                title: "Scope report",
                summary: "Scope summary",
                cadenceIntervalSec: 604_800,
                reportingWindowSummary: "This week",
                portfolioScopeSummary: "No current portfolio",
                headlineView: "Scope headline",
                portfolioRelevanceSummary: "Scope relevance",
                deliveredToPMInboxAt: now,
                createdAt: now,
                updatedAt: now
            )
        ]
        let freshScopedDecision = PMDecisionRecord(
            decisionId: "decision-scope",
            pmId: "pm-1",
            title: "Scope-linked PM follow-up",
            summary: "Scope summary",
            charterId: "charter-scope",
            createdAt: now.addingTimeInterval(120),
            updatedAt: now.addingTimeInterval(120)
        )

        let decisions = makeRecentPMDecisionsForReview(
            decisions: [freshScopedDecision],
            recentAnalystActivityItems: scopeItems,
            reports: reports,
            memos: [],
            delegations: []
        )

        XCTAssertEqual(decisions.map(\.decisionId), ["decision-scope"])
    }

    func testPMInboxDecisionCorrelationPresentationSurfacesRecentAnalystContext() {
        let now = Date(timeIntervalSince1970: 1_744_305_000)
        let memo = AnalystMemo(
            memoId: "memo-1",
            analystId: "technology_analyst",
            charterId: "charter-tech",
            title: "Technology memo",
            executiveSummary: "Summary",
            currentView: "Current view",
            evidenceSummary: "Evidence",
            uncertaintySummary: "Uncertainty",
            recommendedNextStep: "Next step",
            confidence: 0.8,
            createdAt: now,
            updatedAt: now
        )
        let report = AnalystStandingReport(
            reportId: "report-1",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: "charter-tech",
            scheduleId: "schedule-tech",
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
            title: "Technology weekly standing report",
            summary: "Standing summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Fresh candidate work arrived.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work.",
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let recentActivity = PMInboxRecentAnalystActivityItem(
            id: "standing:report-1",
            kind: .standingReport,
            analystTitle: "Technology Analyst",
            timestamp: now,
            headline: "Technology weekly standing report",
            summary: "Fresh candidate work arrived.",
            linkedStandingReportID: "report-1",
            linkedMemoID: "memo-1",
            linkedDelegationID: nil
        )
        let decision = PMDecisionRecord(
            decisionId: "decision-1",
            pmId: "pm-1",
            title: "Monitor follow-up",
            summary: "Stay on watch.",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(120),
            updatedAt: now.addingTimeInterval(120)
        )

        let presentation = makePMInboxDecisionCorrelationPresentation(
            decision: decision,
            recentAnalystActivityItems: [recentActivity],
            reports: [report],
            memos: [memo],
            delegations: []
        )

        XCTAssertEqual(presentation.decisionTimestamp, decision.updatedAt)
        XCTAssertEqual(
            presentation.relatedActivityDescription,
            "Following Technology Analyst standing report: Technology weekly standing report"
        )
        XCTAssertEqual(presentation.relatedActivityTimestamp, recentActivity.timestamp)
    }

    func testPMInboxDecisionCorrelationPresentationPrefersExplicitStandingReportLinkage() {
        let now = Date(timeIntervalSince1970: 1_744_305_100)
        let technologyReport = AnalystStandingReport(
            reportId: "report-tech",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: "charter-tech",
            scheduleId: "schedule-tech",
            memoId: "memo-tech",
            title: "Technology weekly standing report",
            summary: "Technology summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Fresh technology work arrived.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work.",
            deliveredToPMInboxAt: now.addingTimeInterval(60),
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )
        let healthcareReport = AnalystStandingReport(
            reportId: "report-health",
            deliveryStatus: .reviewedByPM,
            analystId: "healthcare_analyst",
            charterId: "charter-health",
            scheduleId: "schedule-health",
            memoId: "memo-health",
            title: "Healthcare standing report",
            summary: "Healthcare summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Fresh healthcare work arrived.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work.",
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let recentActivity = [
            PMInboxRecentAnalystActivityItem(
                id: "standing:report-tech",
                kind: .standingReport,
                analystTitle: "Technology Analyst",
                timestamp: technologyReport.updatedAt,
                headline: technologyReport.title,
                summary: technologyReport.headlineView,
                linkedStandingReportID: technologyReport.reportId,
                linkedMemoID: technologyReport.memoId,
                linkedDelegationID: nil
            ),
            PMInboxRecentAnalystActivityItem(
                id: "standing:report-health",
                kind: .standingReport,
                analystTitle: "Healthcare Analyst",
                timestamp: healthcareReport.updatedAt,
                headline: healthcareReport.title,
                summary: healthcareReport.headlineView,
                linkedStandingReportID: healthcareReport.reportId,
                linkedMemoID: healthcareReport.memoId,
                linkedDelegationID: nil
            )
        ]
        let decision = PMDecisionRecord(
            decisionId: "decision-health",
            pmId: "pm-1",
            title: "Healthcare follow-up",
            summary: "Use the healthcare result.",
            charterId: "charter-health",
            primaryStandingReportId: "report-health",
            standingReportIds: ["report-health"],
            createdAt: now.addingTimeInterval(120),
            updatedAt: now.addingTimeInterval(120)
        )

        let presentation = makePMInboxDecisionCorrelationPresentation(
            decision: decision,
            recentAnalystActivityItems: recentActivity,
            reports: [technologyReport, healthcareReport],
            memos: [],
            delegations: []
        )

        XCTAssertEqual(
            presentation.relatedActivityDescription,
            "Following Healthcare Analyst standing report: Healthcare standing report"
        )
        XCTAssertEqual(presentation.relatedActivityTimestamp, healthcareReport.updatedAt)
    }

    func testPMInboxRecentAnalystActivityDetailPresentationStaysReadableAndCarriesPMTreatment() {
        let now = Date(timeIntervalSince1970: 1_744_100_000)
        let runtimePolicy = AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            policySource: .standingBenchDefault,
            createdAt: now,
            updatedAt: now
        )
        let item = PMInboxRecentAnalystActivityItem(
            id: "standing:report-1",
            kind: .standingReport,
            analystTitle: "Technology Analyst",
            timestamp: now,
            headline: "Technology weekly standing report",
            summary: "technology infrastructure demand stayed resilient this week.",
            linkedStandingReportID: "report-1",
            linkedMemoID: "memo-1",
            linkedDelegationID: "delegation-1"
        )
        let memo = AnalystMemo(
            memoId: "memo-1",
            analystId: "technology_analyst",
            charterId: "charter-tech",
            delegationId: "delegation-1",
            title: "Technology memo",
            executiveSummary: "Executive summary",
            currentView: "Stay constructive on technology demand, but keep position sizing disciplined.",
            evidenceSummary: "Demand commentary and supplier checks stayed supportive.",
            uncertaintySummary: "Near-term timing still depends on guidance cadence.",
            recommendedNextStep: "Keep this in PM monitoring unless positioning changes.",
            confidence: 0.72,
            createdAt: now,
            updatedAt: now
        )
        let report = AnalystStandingReport(
            reportId: "report-1",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: "charter-tech",
            scheduleId: "schedule-tech",
            memoId: "memo-1",
            runtimeProvenance: AnalystRuntimeProvenance(
                intendedPolicy: runtimePolicy,
                actualRuntimeIdentifier: "openai_responses[gpt-5.4]",
                actualReasoningMode: .deliberate,
                launchedAt: now
            ),
            title: "Technology weekly standing report",
            summary: "Standing summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "technology infrastructure demand stayed resilient this week.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work while the portfolio is light in-sector.",
            openQuestions: ["Does guidance confirm the demand trend next week?"],
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let delegation = PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "technology_analyst",
            charterId: "charter-tech",
            title: "Review technology candidates",
            rationale: "Refresh candidate context for the next PM review cycle.",
            status: .completed,
            createdAt: now,
            updatedAt: now
        )
        let evidenceBundle = AnalystEvidenceBundle(
            bundleId: "bundle-1",
            analystId: "technology_analyst",
            refs: [
                AnalystEvidenceRef(
                    refId: "news-1",
                    sourceKind: .appNews,
                    sourceIdentifier: "news-1",
                    title: "Semiconductor demand stayed resilient",
                    observedAt: now,
                    summary: "Baseline event."
                )
            ],
            summary: "Source bundle",
            createdAt: now,
            updatedAt: now
        )
        var memoWithEvidence = memo
        memoWithEvidence.evidenceBundleId = evidenceBundle.bundleId

        let detail = makePMInboxRecentAnalystActivityDetailPresentation(
            item: item,
            reports: [report],
            memos: [memoWithEvidence],
            evidenceBundles: [evidenceBundle],
            delegations: [delegation]
        )

        XCTAssertEqual(detail.activityType, "Standing Report")
        XCTAssertEqual(detail.headline, "Technology weekly standing report")
        XCTAssertEqual(detail.conclusion, "technology infrastructure demand stayed resilient this week.")
        XCTAssertEqual(detail.pmTreatment, "Reviewed and closed by PM")
        XCTAssertEqual(detail.nextStep, "Keep this in PM monitoring unless positioning changes.")
        XCTAssertTrue(detail.supportingContext?.contains("Portfolio relevance: Useful for candidate inclusion work") == true)
        XCTAssertTrue(detail.sourceTruth?.primarySources.contains(where: { $0.contains("App-owned recent news") }) == true)
        XCTAssertEqual(detail.executionTruth.requestedOrConfiguredSummary, "gpt-5.4 (deliberate reasoning)")
        XCTAssertEqual(detail.executionTruth.executionUsedSummary, "OpenAI Responses model gpt-5.4 with deliberate reasoning")
        XCTAssertTrue(detail.executionTruth.summary.contains("worker-backed OpenAI Responses execution"))
    }

    func testPMInboxRecentAnalystExecutionTruthReflectsOpenAIWorkerRunsWhenProvenanceExists() {
        let now = Date(timeIntervalSince1970: 1_744_200_000)
        let item = PMInboxRecentAnalystActivityItem(
            id: "memo:memo-1",
            kind: .analystMemo,
            analystTitle: "Technology Analyst",
            timestamp: now,
            headline: "Ad hoc memo",
            summary: "The analyst pressure-tested two candidates.",
            linkedStandingReportID: nil,
            linkedMemoID: "memo-1",
            linkedDelegationID: "delegation-1"
        )
        let runtimePolicy = AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        )
        let memo = AnalystMemo(
            memoId: "memo-1",
            analystId: "technology_analyst",
            charterId: "charter-tech",
            delegationId: "delegation-1",
            title: "Ad hoc memo",
            executiveSummary: "Executive summary",
            currentView: "Stay selective, but keep two names on the active watchlist.",
            evidenceSummary: "Channel checks and product-cycle work both improved.",
            uncertaintySummary: "The next earnings print still matters.",
            recommendedNextStep: "Keep the pair in PM monitoring.",
            confidence: 0.68,
            runtimeProvenance: AnalystRuntimeProvenance(
                intendedPolicy: runtimePolicy,
                actualRuntimeIdentifier: "openai_responses[gpt-5.4]",
                actualReasoningMode: .deliberate,
                launchedAt: now
            ),
            createdAt: now,
            updatedAt: now
        )
        let delegation = PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: "pm-1",
            analystId: "technology_analyst",
            charterId: "charter-tech",
            title: "Review technology candidates",
            rationale: "Refresh candidate context.",
            status: .completed,
            createdAt: now,
            updatedAt: now
        )

        let detail = makePMInboxRecentAnalystActivityDetailPresentation(
            item: item,
            reports: [],
            memos: [memo],
            evidenceBundles: [],
            delegations: [delegation]
        )

        XCTAssertEqual(detail.executionTruth.requestedOrConfiguredSummary, "gpt-5.4 (deliberate reasoning)")
        XCTAssertEqual(detail.executionTruth.executionUsedSummary, "OpenAI Responses model gpt-5.4 with deliberate reasoning")
        XCTAssertTrue(detail.executionTruth.summary.contains("OpenAI Responses API-backed worker path"))
        XCTAssertEqual(detail.linkedMemoPresentation?.executionUsedSummary, "OpenAI Responses model gpt-5.4 with deliberate reasoning")
    }

    func testReadableNewsSourceLabelUsesActualRSSFeedNameWhenAvailable() {
        let event = NewsEvent(
            eventId: "news-1",
            source: "rss_cepr_workshops_announcements",
            title: "Future conference item",
            publishedAt: Date(timeIntervalSince1970: 1_744_200_500),
            receivedAt: Date(timeIntervalSince1970: 1_744_200_500)
        )
        let feeds = [
            RSSFeed(
                id: "feed-1",
                name: "CEPR Workshops Announcements",
                url: "https://example.com/rss"
            )
        ]

        let label = readableNewsSourceLabel(for: event, rssFeeds: feeds)

        XCTAssertEqual(label, "CEPR Workshops Announcements")
    }

    func testRecentPMDecisionsPreferCurrentAnalystCycleOverStaleHistory() {
        let now = Date(timeIntervalSince1970: 1_744_300_000)
        let report = AnalystStandingReport(
            reportId: "report-1",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: "charter-tech",
            scheduleId: "schedule-tech",
            memoId: "memo-1",
            title: "Technology weekly standing report",
            summary: "Standing summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Fresh candidate work arrived.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work.",
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let recentActivity = PMInboxRecentAnalystActivityItem(
            id: "standing:report-1",
            kind: .standingReport,
            analystTitle: "Technology Analyst",
            timestamp: now,
            headline: "Technology weekly standing report",
            summary: "Fresh candidate work arrived.",
            linkedStandingReportID: "report-1",
            linkedMemoID: "memo-1",
            linkedDelegationID: nil
        )
        let staleDecision = PMDecisionRecord(
            decisionId: "decision-stale",
            pmId: "pm-1",
            title: "Older standing-review escalation",
            summary: "Old summary",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(-4_000),
            updatedAt: now.addingTimeInterval(-4_000)
        )
        let freshDecision = PMDecisionRecord(
            decisionId: "decision-fresh",
            pmId: "pm-1",
            title: "Current-cycle follow-up",
            summary: "Fresh summary",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )
        let unrelatedFreshDecision = PMDecisionRecord(
            decisionId: "decision-unrelated",
            pmId: "pm-1",
            title: "Fresh but unrelated",
            summary: "Unrelated summary",
            charterId: "charter-energy",
            createdAt: now.addingTimeInterval(120),
            updatedAt: now.addingTimeInterval(120)
        )

        let decisions = makeRecentPMDecisionsForReview(
            decisions: [unrelatedFreshDecision, freshDecision, staleDecision],
            recentAnalystActivityItems: [recentActivity],
            reports: [report],
            memos: [],
            delegations: []
        )

        XCTAssertEqual(decisions.map(\.decisionId), ["decision-fresh"])
    }

    func testRecentPMDecisionsStayNewestFirstWithinCurrentCycleWhenInputOrderIsStale() {
        let now = Date(timeIntervalSince1970: 1_744_300_500)
        let report = AnalystStandingReport(
            reportId: "report-1",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: "charter-tech",
            scheduleId: "schedule-tech",
            memoId: "memo-1",
            title: "Technology weekly standing report",
            summary: "Standing summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Fresh candidate work arrived.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work.",
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let recentActivity = PMInboxRecentAnalystActivityItem(
            id: "standing:report-1",
            kind: .standingReport,
            analystTitle: "Technology Analyst",
            timestamp: now,
            headline: "Technology weekly standing report",
            summary: "Fresh candidate work arrived.",
            linkedStandingReportID: "report-1",
            linkedMemoID: "memo-1",
            linkedDelegationID: nil
        )
        let earlierDecision = PMDecisionRecord(
            decisionId: "decision-earlier",
            pmId: "pm-1",
            title: "Earlier current-cycle handling",
            summary: "Earlier summary",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )
        let latestDecision = PMDecisionRecord(
            decisionId: "decision-latest",
            pmId: "pm-1",
            title: "Latest current-cycle handling",
            summary: "Latest summary",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(180),
            updatedAt: now.addingTimeInterval(180)
        )

        let decisions = makeRecentPMDecisionsForReview(
            decisions: [earlierDecision, latestDecision],
            recentAnalystActivityItems: [recentActivity],
            reports: [report],
            memos: [],
            delegations: []
        )

        XCTAssertEqual(decisions.map(\.decisionId), ["decision-latest", "decision-earlier"])
    }

    func testRecentPMDecisionsBackfillFreshUnlinkedClosuresAfterLinkedCurrentCycleDecision() {
        let now = Date(timeIntervalSince1970: 1_744_301_000)
        let technologyReport = AnalystStandingReport(
            reportId: "report-tech",
            deliveryStatus: .reviewedByPM,
            analystId: "technology_analyst",
            charterId: "charter-tech",
            scheduleId: "schedule-tech",
            memoId: "memo-tech",
            title: "Technology weekly standing report",
            summary: "Standing summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Fresh technology work arrived.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work.",
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let financialsReport = AnalystStandingReport(
            reportId: "report-fin",
            deliveryStatus: .reviewedByPM,
            analystId: "financials_analyst",
            charterId: "charter-fin",
            scheduleId: "schedule-fin",
            memoId: "memo-fin",
            title: "Financials weekly standing report",
            summary: "Standing summary",
            cadenceIntervalSec: 604_800,
            reportingWindowSummary: "This week",
            portfolioScopeSummary: "No current portfolio",
            headlineView: "Fresh financials work arrived.",
            portfolioRelevanceSummary: "Useful for candidate inclusion work.",
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let recentActivity = [
            PMInboxRecentAnalystActivityItem(
                id: "standing:report-tech",
                kind: .standingReport,
                analystTitle: "Technology Analyst",
                timestamp: now,
                headline: "Technology weekly standing report",
                summary: "Fresh technology work arrived.",
                linkedStandingReportID: "report-tech",
                linkedMemoID: "memo-tech",
                linkedDelegationID: nil
            ),
            PMInboxRecentAnalystActivityItem(
                id: "standing:report-fin",
                kind: .standingReport,
                analystTitle: "Financials Analyst",
                timestamp: now,
                headline: "Financials weekly standing report",
                summary: "Fresh financials work arrived.",
                linkedStandingReportID: "report-fin",
                linkedMemoID: "memo-fin",
                linkedDelegationID: nil
            )
        ]
        let linkedDecision = PMDecisionRecord(
            decisionId: "decision-linked",
            pmId: "pm-1",
            title: "Linked follow-up",
            summary: "Linked summary",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )
        let freshCombinedClosure = PMDecisionRecord(
            decisionId: "decision-combined",
            pmId: "pm-1",
            title: "Combined closure",
            summary: "Combined summary",
            createdAt: now.addingTimeInterval(90),
            updatedAt: now.addingTimeInterval(90)
        )

        let decisions = makeRecentPMDecisionsForReview(
            decisions: [linkedDecision, freshCombinedClosure],
            recentAnalystActivityItems: recentActivity,
            reports: [technologyReport, financialsReport],
            memos: [],
            delegations: []
        )

        XCTAssertEqual(decisions.map(\.decisionId), ["decision-combined", "decision-linked"])
    }

    func testRecentPMDecisionsUseExplicitStandingReportIdentityForExactTopFiveOrdering() {
        let now = Date(timeIntervalSince1970: 1_744_301_500)
        let reports = (0..<5).map { index in
            AnalystStandingReport(
                reportId: "report-\(index)",
                deliveryStatus: .reviewedByPM,
                analystId: "analyst-\(index)",
                charterId: "charter-\(index)",
                scheduleId: "schedule-\(index)",
                memoId: "memo-\(index)",
                title: "Report \(index)",
                summary: "Summary \(index)",
                cadenceIntervalSec: 604_800,
                reportingWindowSummary: "This week",
                portfolioScopeSummary: "No current portfolio",
                headlineView: "Headline \(index)",
                portfolioRelevanceSummary: "Relevance \(index)",
                deliveredToPMInboxAt: now.addingTimeInterval(TimeInterval(index)),
                createdAt: now.addingTimeInterval(TimeInterval(index)),
                updatedAt: now.addingTimeInterval(TimeInterval(index))
            )
        }
        let recentActivity = reports.reversed().map { report in
            PMInboxRecentAnalystActivityItem(
                id: "standing:\(report.reportId)",
                kind: .standingReport,
                analystTitle: report.title,
                timestamp: report.updatedAt,
                headline: report.title,
                summary: report.headlineView,
                linkedStandingReportID: report.reportId,
                linkedMemoID: report.memoId,
                linkedDelegationID: nil
            )
        }
        let freshDecisions = reports.enumerated().map { index, report in
            PMDecisionRecord(
                decisionId: "decision-\(index)",
                pmId: "pm-1",
                title: "Decision \(index)",
                summary: "Summary \(index)",
                charterId: report.charterId,
                primaryStandingReportId: report.reportId,
                standingReportIds: [report.reportId],
                createdAt: report.updatedAt.addingTimeInterval(60),
                updatedAt: report.updatedAt.addingTimeInterval(60)
            )
        }
        let staleDecision = PMDecisionRecord(
            decisionId: "decision-stale",
            pmId: "pm-1",
            title: "Stale decision",
            summary: "Old summary",
            charterId: "charter-older",
            createdAt: now.addingTimeInterval(-3_600),
            updatedAt: now.addingTimeInterval(-3_600)
        )

        let decisions = makeRecentPMDecisionsForReview(
            decisions: [staleDecision] + freshDecisions.shuffled(),
            recentAnalystActivityItems: recentActivity.shuffled(),
            reports: reports.shuffled(),
            memos: [],
            delegations: []
        )

        XCTAssertEqual(
            decisions.map(\.decisionId),
            ["decision-4", "decision-3", "decision-2", "decision-1", "decision-0"]
        )
    }

    func testPMInboxPMExecutionTruthDoesNotClaimOpenAIUsageFromConfigurationAlone() {
        let now = Date(timeIntervalSince1970: 1_744_400_000)
        let truth = makePMInboxPMExecutionTruthPresentation(
            runtimeSettings: PMRuntimeSettings(
                runtimeIdentifier: "gpt-5.4",
                reasoningMode: .deliberate,
                validationStatus: RuntimeValidationRecord(
                    status: .valid,
                    category: .accepted,
                    summary: "Accepted by bounded validation.",
                    checkedAt: now,
                    checkedBy: "pm-runtime-check"
                ),
                updatedBy: "user",
                updateSource: .userEdited,
                createdAt: now,
                updatedAt: now
            )
        )

        XCTAssertEqual(truth.requestedOrConfiguredSummary, "gpt-5.4 (deliberate reasoning)")
        XCTAssertEqual(truth.executionUsedSummary, "App-owned deterministic PM review logic")
        XCTAssertTrue(truth.summary.contains("does not prove an OpenAI API request"))
    }

    func testPMInboxPMExecutionTruthReflectsRecordedOpenAIRuntimeProvenance() {
        let now = Date(timeIntervalSince1970: 1_744_400_010)
        let truth = makePMInboxPMExecutionTruthPresentation(
            runtimeSettings: PMRuntimeSettings(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                updatedBy: "owner",
                updateSource: .userEdited,
                createdAt: now,
                updatedAt: now
            ),
            runtimeProvenance: PMRuntimeProvenance(
                configuredRuntimeIdentifier: "gpt-5",
                configuredReasoningMode: .deliberate,
                actualRuntimeIdentifier: "openai_responses[gpt-5]",
                actualReasoningMode: .deliberate,
                usedOpenAI: true,
                synthesisStatus: "openai_responses",
                launchedAt: now
            )
        )

        XCTAssertEqual(truth.requestedOrConfiguredSummary, "gpt-5 (deliberate reasoning)")
        XCTAssertEqual(truth.executionUsedSummary, "OpenAI Responses model gpt-5 with deliberate reasoning")
        XCTAssertTrue(truth.summary.contains("records real OpenAI Responses execution"))
    }

    func testPMInboxAnalystFallbackExecutionTruthSurfacesMissingKeyReason() {
        let truth = makePMInboxAnalystExecutionTruthPresentation(
            item: PMInboxRecentAnalystActivityItem(
                id: "memo:memo-1",
                kind: .analystMemo,
                analystTitle: "Technology Analyst",
                timestamp: Date(timeIntervalSince1970: 1_744_400_100),
                headline: "Technology memo",
                summary: "Summary",
                linkedStandingReportID: nil,
                linkedMemoID: "memo-1",
                linkedDelegationID: "delegation-1"
            ),
            linkedReport: nil,
            linkedMemo: nil,
            linkedDelegation: PMDelegationRecord(
                delegationId: "delegation-1",
                pmId: "pm-1",
                analystId: "analyst-1",
                charterId: "charter-tech",
                title: "Technology follow-up",
                rationale: "Review current positioning.",
                lastLaunch: PMDelegationLastLaunch(
                    launchedAt: Date(timeIntervalSince1970: 1_744_400_090),
                    status: .healthy,
                    summary: "Local deterministic fallback: OpenAI API key missing for this run.",
                    lastIssueSummary: "openai_api_key_missing",
                    completedAt: Date(timeIntervalSince1970: 1_744_400_095)
                ),
                lastRuntimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: AnalystRuntimePolicy(
                        runtimeIdentifier: "gpt-5.4",
                        reasoningMode: .deliberate,
                        policySource: .pmDelegationOverride,
                        createdAt: Date(timeIntervalSince1970: 1_744_400_000),
                        updatedAt: Date(timeIntervalSince1970: 1_744_400_000)
                    ),
                    actualRuntimeIdentifier: "deterministic_local_fallback[gpt-5.4]",
                    actualReasoningMode: .deliberate,
                    launchedAt: Date(timeIntervalSince1970: 1_744_400_090)
                ),
                createdAt: Date(timeIntervalSince1970: 1_744_400_000),
                updatedAt: Date(timeIntervalSince1970: 1_744_400_100)
            )
        )

        XCTAssertEqual(truth.requestedOrConfiguredSummary, "gpt-5.4 (deliberate reasoning)")
        XCTAssertTrue(truth.executionUsedSummary.contains("Local synthesis fallback profile gpt-5.4"))
        XCTAssertTrue(truth.summary.contains("no OpenAI API key was available in the app Keychain"))
    }

    func testRecentPMDecisionsIncludeStandingReviewClosureConclusionsForCurrentCycle() {
        let now = Date(timeIntervalSince1970: 1_744_500_000)
        let report = AnalystStandingReport(
            reportId: "report-1",
            analystId: "analyst-1",
            charterId: "charter-tech",
            scheduleId: "schedule-1",
            memoId: "memo-1",
            title: "Technology standing report",
            summary: "Summary",
            cadenceIntervalSec: 86_400,
            reportingWindowSummary: "Window",
            portfolioScopeSummary: "Scope",
            coveredSymbols: ["NVDA"],
            headlineView: "Headline",
            portfolioRelevanceSummary: "Relevance",
            openQuestions: [],
            evidenceReferenceSummary: [],
            sections: [],
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
        let recentActivity = PMInboxRecentAnalystActivityItem(
            id: "standing:report-1",
            kind: .standingReport,
            analystTitle: "Technology Analyst",
            timestamp: now,
            headline: "Technology weekly standing report",
            summary: "Fresh candidate work arrived.",
            linkedStandingReportID: "report-1",
            linkedMemoID: "memo-1",
            linkedDelegationID: nil
        )
        let closureDecision = PMDecisionRecord(
            decisionId: "decision-closure",
            pmId: "pm-1",
            title: "Standing review conclusion: Technology Analyst",
            summary: "Disposition: No action warranted.",
            charterId: "charter-tech",
            createdAt: now.addingTimeInterval(60),
            updatedAt: now.addingTimeInterval(60)
        )

        let decisions = makeRecentPMDecisionsForReview(
            decisions: [closureDecision],
            recentAnalystActivityItems: [recentActivity],
            reports: [report],
            memos: [],
            delegations: []
        )

        XCTAssertEqual(decisions.map(\.decisionId), ["decision-closure"])
    }

    func testPMInboxOwnerReachThresholdPresentationUsesQualitativePolicyContext() {
        let presentation = makePMInboxOwnerReachThresholdPresentation(
            memo: PMDecisionMemoPresentation(
                initiativePosture: .ownerDecisionRequired,
                initiativeSummary: "Owner decision: The PM believes this needs explicit owner direction now.",
                coherence: PMEventCoherencePresentation(
                    initiativePosture: .ownerDecisionRequired,
                    actionabilityCategory: .ownerDecisionRequired,
                    ownerTitle: "Decision Required",
                    ownerSummary: "Decision required.",
                    telegramTitle: "Decision required",
                    pmInboxSummary: "Decision-required PM event. Preserve the owner ask as the primary meaning and keep traceability secondary.",
                    ownerVisible: true,
                    traceabilityOnly: false
                ),
                closure: PMRecommendationClosurePresentation(
                    status: .awaitingOwner,
                    title: "Waiting on You",
                    ownerSummary: "Waiting on you.",
                    pmInboxSummary: "Owner decision is still pending.",
                    ownerPending: true,
                    stillCurrent: true
                ),
                recommendation: "Reduce exposure.",
                whyNow: "Why now",
                strategicAlignment: nil,
                recommendedAction: "Reduce exposure.",
                evidenceSummary: nil,
                uncertaintySummary: nil,
                ownerAsk: "Confirm whether to reduce exposure.",
                approvedNextStep: nil,
                boundaryNote: "Boundary note",
                relationshipNote: nil,
                supportingSections: []
            )
        )

        XCTAssertEqual(presentation.thresholdTitle, "Owner-relevant strategic concern")
        XCTAssertEqual(presentation.initiativeTitle, "Owner decision required")
        XCTAssertEqual(presentation.routingTitle, "Owner decision required")
        XCTAssertTrue(presentation.thresholdSummary.contains("justify a direct owner-facing decision"))
        XCTAssertTrue(presentation.routingSummary.contains("Decision-required PM event"))
    }

    func testPMInboxRecentPMDecisionPresentationUsesVisibleTimeAndAnalystContext() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Text(\"Updated \\(displayDate(correlation.decisionTimestamp))\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Time and analyst context\")"))
        XCTAssertTrue(source.contains("Decision recorded \\(displayDate(correlation.decisionTimestamp))."))
        XCTAssertTrue(source.contains("Following \\(item.analystTitle) \\(item.kind.rawValue.lowercased()): \\(item.headline)"))
        XCTAssertTrue(source.contains("GroupBox(\"PM owner-reach threshold\")"))
        XCTAssertTrue(source.contains("OwnerReadableFactLine("))
        XCTAssertTrue(source.contains("title: \"Current threshold:\""))
        XCTAssertTrue(source.contains("title: \"Initiative posture:\""))
        XCTAssertTrue(source.contains("title: \"Routing:\""))
    }

    func testPMInboxReviewDetailUsesExplicitCloseControls() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("pmInboxSelectedDetailSection("))
        XCTAssertTrue(source.contains("title: \"Recent Analyst Activity Detail\""))
        XCTAssertTrue(source.contains("title: \"Approval Request Detail\""))
        XCTAssertTrue(source.contains("title: recentNewsWakeUp.isRecentNewsWakeUp ? \"Recent News Review Detail\" : \"PM Decision Detail\""))
        XCTAssertTrue(source.contains("title: \"Communication Session Detail\""))
        XCTAssertTrue(source.contains("title: \"Conversation Entry Detail\""))
        XCTAssertTrue(source.contains("Button(\"Close\")"))
        XCTAssertTrue(source.contains("Select a recent analyst activity row to open its readable summary and PM treatment."))
        XCTAssertTrue(source.contains("Select an approval request to open the PM memo and supporting context."))
        XCTAssertTrue(source.contains("Select a PM decision to open its recommendation memo and traceability."))
        XCTAssertTrue(source.contains("Select a communication session to open its durable log and related traceability."))
        XCTAssertTrue(source.contains("Select a conversation entry to open its full detail and promotion context."))
    }

    func testPMInboxRemovesOpaqueReviewUtilityButtonsAndUsesPlainEnglishDefaultDetails() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertFalse(source.contains("Button(\"Refresh PM Review\")"))
        XCTAssertFalse(source.contains("Button(\"Clear Exercise Artifacts\")"))
        XCTAssertTrue(source.contains("memoSection(\"What happened\""))
        XCTAssertTrue(source.contains("memoSection(\"Why this matters now\""))
        XCTAssertTrue(source.contains("memoSection(\"What the PM recommends\""))
        XCTAssertTrue(source.contains("memoSection(\"What this means for you\""))
        XCTAssertTrue(source.contains("memoSection(\"What the PM concluded\""))
        XCTAssertTrue(source.contains("memoSection(\"Why\""))
        XCTAssertTrue(source.contains("memoSection(\"Why now\""))
        XCTAssertTrue(source.contains("memoSection(\"Next step / status\""))
        XCTAssertTrue(source.contains("supportingDetailsButton(isExpanded: $approvalRequestSupportingDetailsExpanded)"))
        XCTAssertFalse(source.contains("supportingDetailsButton(isExpanded: $decisionSupportingDetailsExpanded)"))
        XCTAssertFalse(source.contains("decisionSupportingDetailsExpanded"))
        XCTAssertTrue(source.contains("GroupBox(\"Supporting Traceability\")"))
    }

    func testPMInboxSurfacesQuietBackgroundReviewSummariesSeparatelyFromConversation() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("title: \"Background PM Review Summaries\""))
        XCTAssertTrue(source.contains("Closed standing-review cycles stay here as compact internal summaries."))
        XCTAssertTrue(source.contains("Recent closed PM review cycles"))
        XCTAssertTrue(source.contains("not direct PM/User conversation turns"))
    }

    func testPMInboxAnalystDrillDownKeepsMemoPrimaryAndResearchSecondary() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("GroupBox(\"Latest Analyst Memo\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Research Coverage And Trust\")"))
        XCTAssertTrue(source.contains("OwnerReadableFactLine(title: \"Coverage:\""))
        XCTAssertTrue(source.contains("OwnerReadableFactLine(title: \"Outside Research:\""))
        XCTAssertTrue(source.contains("OwnerReadableFactLine(title: \"Source Constraints:\""))
        XCTAssertTrue(source.contains("Text(\"Outside Research Added\")"))
        XCTAssertTrue(source.contains("Text(\"Source Coverage Limits\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Strategy Implication\")"))
        XCTAssertTrue(source.contains("GroupBox(\"PM Strategy Follow-Up Actions\")"))
        XCTAssertTrue(source.contains("Button(\"Create Brief Revision Candidate\")"))
        XCTAssertTrue(source.contains("Button(\"Create Instruction Candidate\")"))
        XCTAssertTrue(source.contains("Button(\"Create Mandate Candidate\")"))
        XCTAssertTrue(source.contains("Button(\"Mark Monitor-Only\")"))
        XCTAssertTrue(source.contains("No strategy implication recorded yet."))
        XCTAssertTrue(source.contains("Candidate Strategy Brief Revision"))
        XCTAssertTrue(source.contains("This captures PM strategy interpretation of analyst output. It does not edit the saved Portfolio Strategy Brief by itself."))
        XCTAssertTrue(source.contains("DisclosureGroup(\"Linked Analyst Finding\")"))
        XCTAssertTrue(source.contains("DisclosureGroup(\"Linked Evidence Bundle\")"))
        XCTAssertTrue(source.contains("Text(\"Research Evidence\")"))
        XCTAssertTrue(source.contains("Text(presentation.boundaryNote)"))
    }

    func testPMInboxAnalystSurfaceShowsCompactSourceAccessSuggestions() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("GroupBox(\"Source Access Suggestions\")"))
        XCTAssertTrue(source.contains("Analyst source-access suggestions stay here as compact research-governance review items."))
        XCTAssertTrue(source.contains("Requested Source:"))
        XCTAssertTrue(source.contains("Recommended Next Step"))
        XCTAssertTrue(source.contains("Open Source Suggestions"))
        XCTAssertTrue(source.contains("Recently Closed Source Suggestions"))
        XCTAssertTrue(source.contains("Text(presentation.boundaryNote)"))
    }

    func testPMInboxAnalystSurfaceShowsCompactStrategyFollowUpCandidateQueue() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("GroupBox(\"Strategy Follow-Up Candidates\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Recent Strategic Changes\")"))
        XCTAssertTrue(source.contains("if recentStrategicChangeCandidates.isEmpty == false"))
        XCTAssertTrue(source.contains("Open Strategy Follow-Up Candidates"))
        XCTAssertTrue(source.contains("Recently Closed Strategy Follow-Up Candidates"))
        XCTAssertTrue(source.contains("No strategy follow-up candidates are currently open or recorded."))
        XCTAssertTrue(source.contains("Button(\"Route To User Strategy Review\")"))
        XCTAssertTrue(source.contains("Button(\"Open Pending User Strategy Review\")"))
        XCTAssertTrue(source.contains("Button(\"Convert To PM Instruction\")"))
        XCTAssertTrue(source.contains("Button(\"Convert To PM Mandate\")"))
        XCTAssertTrue(source.contains("Button(\"Dismiss Candidate\")"))
        XCTAssertTrue(source.contains("Button(\"Reopen Candidate\")"))
        XCTAssertTrue(source.contains("GroupBox(candidate.status.isActive ? \"Current Outcome\" : \"Closure Result\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Resulting PM Artifact\")"))
        XCTAssertTrue(source.contains("The saved Portfolio Strategy Brief remains unchanged until the user edits it directly or explicitly approves a routed strategy-change request through the app-owned owner-review path."))
        XCTAssertTrue(source.contains("A Strategy Brief change only happens when the user edits the brief directly or explicitly approves a routed strategy-change request."))
        XCTAssertTrue(source.contains("Current Portfolio Context"))
    }

    func testPMInboxRecentAnalystActivitySectionUsesDurableAnalystArtifactsInsteadOfDelegationOnlyFallback() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("makePMInboxRecentAnalystActivityItems("))
        XCTAssertTrue(source.contains("standingReportSummaries: standingReportSummaries"))
        XCTAssertTrue(source.contains("memos: appModel.analystMemos"))
        XCTAssertTrue(source.contains("delegations: appModel.pmDelegations"))
        XCTAssertTrue(source.contains("No recent analyst activity summaries are available yet."))
        XCTAssertFalse(source.contains("No PM delegations recorded yet."))
    }

    func testPMInboxRecentAnalystActivityCanOpenLinkedStandingReportDetailAndSurfaceExecutionTruth() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let linkedViewStart = sourceIndex(of: "private struct LinkedStandingAnalystReportDocumentView", in: source)
        let linkedViewEnd = source.range(
            of: "private struct PMInboxApprovalRequestReviewSection: View",
            range: linkedViewStart..<source.endIndex
        )?.lowerBound ?? source.endIndex
        let linkedViewSource = String(source[linkedViewStart..<linkedViewEnd])

        XCTAssertTrue(source.contains("private var selectedRecentAnalystLinkedStandingReportPresentation"))
        XCTAssertTrue(source.contains("@State private var selectedRecentAnalystLinkedStandingReportID"))
        XCTAssertTrue(source.contains("makeStandingAnalystReportReviewPresentation("))
        XCTAssertTrue(source.contains("GroupBox(\"Linked Standing Report\")"))
        XCTAssertTrue(source.contains("LinkedStandingAnalystReportDocumentView("))
        XCTAssertTrue(source.contains("GroupBox(\"Primary Sources And Support\")"))
        XCTAssertTrue(source.contains("GroupBox(\"Execution Truth\")"))
        XCTAssertTrue(source.contains("OwnerReadableFactLine("))
        XCTAssertTrue(source.contains("title: \"Requested/Configured:\""))
        XCTAssertTrue(source.contains("selectedRecentAnalystLinkedStandingReportID = linkedStandingReportID"))
        XCTAssertTrue(linkedViewSource.contains("GroupBox(\"Detailed Supporting Sections\")"))
        XCTAssertFalse(linkedViewSource.contains("GroupBox(\"PM Triage\")"))
        XCTAssertFalse(source.contains("No standing analyst reports are awaiting PM review right now, but you can still inspect the linked standing report detail opened from Recent Analyst Activity."))
        XCTAssertTrue(source.contains("The covered PM review and PM Inbox decision path still uses app-owned deterministic PM logic"))
    }

    func testPMInboxReviewPathCachesSummaryProjectionAndGatesItToVisibleReviewTab() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("@State private var reviewProjection = PMInboxReviewProjection()"))
        XCTAssertTrue(source.contains("private var shouldMaintainReviewProjection: Bool"))
        XCTAssertTrue(source.contains("guard shouldMaintainReviewProjection else"))
        XCTAssertTrue(source.contains("reviewProjection = makePMInboxReviewProjection("))
        XCTAssertTrue(source.contains("reviewProjection = PMInboxReviewProjection()"))
    }

    func testPMInboxDefaultOpenPathUsesBoundedReviewRefreshAndDefersProposalPrefetch() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("feedbackMessage = await appModel.refreshPMInboxReviewData()"))
        XCTAssertTrue(source.contains("case .proposals, .runs:"))
        XCTAssertTrue(source.contains("hasPrefetchedProposalRuns"))
        XCTAssertFalse(source.contains(".onAppear {\n            bootstrapSelections()\n            Task { @MainActor in\n                await prefetchProposalRuns()"))
    }

    func testSettingsExposeSeparateStandingBenchRuntimeAlongsideRecentNewsRuntime() throws {
        let source = try String(contentsOfFile: settingsViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Section(\"Recent News Analyst Runtime\")"))
        XCTAssertTrue(source.contains("Section(\"Standing Bench Analyst Runtime\")"))
        XCTAssertTrue(source.contains("refreshStandingBenchAnalystRuntimeSettings"))
        XCTAssertTrue(source.contains("upsertStandingBenchAnalystRuntimeSettings"))
        XCTAssertTrue(source.contains("validateStandingBenchAnalystRuntimeSettings"))
        XCTAssertTrue(source.contains("standingBenchAnalystRuntimeIdentifier"))
        XCTAssertTrue(source.contains("standingBenchAnalystRuntimeFeedback"))
        XCTAssertTrue(source.contains(".onChange(of: appModel.standingBenchAnalystRuntimeSettings)"))
        XCTAssertFalse(source.contains("Reload Runtime Setting"))
        XCTAssertFalse(source.contains("Reload PM Runtime"))
    }

    func testLatestRuntimeSettingsValueKeepsNewerStandingBenchRecordWhenRefreshReturnsStaleData() {
        let stale = Date(timeIntervalSince1970: 1_744_900_000)
        let fresh = stale.addingTimeInterval(120)
        let current = StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: stale,
            updatedAt: fresh
        )
        let incoming = StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            updatedBy: "system",
            updateSource: .systemDefault,
            createdAt: stale,
            updatedAt: stale
        )

        let resolved = latestRuntimeSettingsValue(
            current: current,
            incoming: incoming,
            updatedAt: \.updatedAt
        )

        XCTAssertEqual(resolved.runtimeIdentifier, "gpt-5.4")
        XCTAssertEqual(resolved.reasoningMode, .deliberate)
    }

    func testLatestRuntimeSettingsValueKeepsNewerRecentNewsRecordWhenRefreshReturnsStaleData() {
        let stale = Date(timeIntervalSince1970: 1_744_910_000)
        let fresh = stale.addingTimeInterval(120)
        let current = RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4-mini",
            reasoningMode: .standard,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: stale,
            updatedAt: fresh
        )
        let incoming = RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-4.1-mini",
            reasoningMode: .standard,
            updatedBy: "system",
            updateSource: .systemDefault,
            createdAt: stale,
            updatedAt: stale
        )

        let resolved = latestRuntimeSettingsValue(
            current: current,
            incoming: incoming,
            updatedAt: \.updatedAt
        )

        XCTAssertEqual(resolved.runtimeIdentifier, "gpt-5.4-mini")
    }

    func testLatestRuntimeSettingsValueKeepsCurrentRecordWhenTimestampsTie() {
        let tied = Date(timeIntervalSince1970: 1_744_920_000)
        let current = StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5.4",
            reasoningMode: .deliberate,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: tied,
            updatedAt: tied
        )
        let incoming = StandingBenchAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            updatedBy: "system",
            updateSource: .systemDefault,
            createdAt: tied,
            updatedAt: tied
        )

        let resolved = latestRuntimeSettingsValue(
            current: current,
            incoming: incoming,
            updatedAt: \.updatedAt
        )

        XCTAssertEqual(resolved.runtimeIdentifier, "gpt-5.4")
        XCTAssertEqual(resolved.updateSource, .userEdited)
    }

    func testSettingsKeychainStatusShowsTelegramAndOpenAI() throws {
        let source = try String(contentsOfFile: settingsViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Section(\"Keychain Status\")"))
        XCTAssertTrue(source.contains("statusLine(label: \"Telegram\""))
        XCTAssertTrue(source.contains("statusLine("))
        XCTAssertTrue(source.contains("label: \"OpenAI\""))
        XCTAssertTrue(source.contains("appModel.keyStatus.openAIStatusSummary"))
    }

    func testSettingsExposeProviderAwareLLMConfiguration() throws {
        let source = try String(contentsOfFile: settingsViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Section(\"LLM Providers\")"))
        XCTAssertTrue(source.contains("providerProfileServiceFields"))
        XCTAssertTrue(source.contains("Check Keychain"))
        XCTAssertTrue(source.contains("Save Profile"))
        XCTAssertTrue(source.contains("mainSettingsCredentialProfiles"))
        XCTAssertTrue(source.contains("mainSettingsProfiles(for: providerKind)"))
        XCTAssertTrue(source.contains("Migration-only legacy aliases are resolved through the default provider profile"))
        XCTAssertTrue(source.contains("Picker(\"Provider\""))
        XCTAssertTrue(source.contains("credentialProfilePicker("))
        XCTAssertTrue(source.contains("pmProviderKind"))
        XCTAssertTrue(source.contains("recentNewsAnalystProviderKind"))
        XCTAssertTrue(source.contains("standingBenchAnalystProviderKind"))
        XCTAssertTrue(source.contains("Anthropic PM conversation execution uses the Messages API"))
        XCTAssertTrue(source.contains("Anthropic standing-bench analyst execution uses the Messages API"))
        XCTAssertTrue(source.contains("Anthropic Recent News Analyst execution uses the Messages API"))
        XCTAssertTrue(source.contains("Secrets stay in macOS Keychain"))
    }

    func testSystemControlShowsFeedAndLiveReadinessDiagnostics() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("liveSafetyStatusDetail"))
        XCTAssertTrue(source.contains("Configured Feed"))
        XCTAssertTrue(source.contains("Feed Verify"))
        XCTAssertTrue(source.contains("diagnosticWebSocketEndpoint"))
        XCTAssertTrue(source.contains("GridRow { Text(\"Readiness\"); Text(appModel.alwaysOnReadiness.summary) }"))
    }

    func testPortfolioWatchWallEditorPreservesSparseWallSelection() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("selectionEditorRows"))
        XCTAssertTrue(source.contains("makePortfolioWatchChartWallSelectionEditorRows"))
        XCTAssertTrue(source.contains("portfolioWatchChartWallOrderedSelectionForSave"))
        XCTAssertTrue(source.contains("Wall only"))
        XCTAssertFalse(source.contains("let orderedSelection = appModel.watchlistSymbols.filter { draftedSelection.contains($0) }"))
    }

    func testSettingsExposeLiveExecutionProtectionLocalAuthControls() throws {
        let settingsSource = try String(contentsOfFile: settingsViewPath, encoding: .utf8)
        let contentSource = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(settingsSource.contains("Section(\"Live Execution Protection\")"))
        XCTAssertTrue(settingsSource.contains("Require Touch ID / Mac password for Live order submission"))
        XCTAssertTrue(settingsSource.contains("Test Local Authentication"))
        XCTAssertTrue(settingsSource.contains("setLiveExecutionProtectionRequired"))
        XCTAssertTrue(settingsSource.contains("testLiveExecutionLocalAuthentication"))
        XCTAssertTrue(contentSource.contains("liveExecutionProtectionSettings"))
        XCTAssertTrue(contentSource.contains("Live Auth Gate"))
        XCTAssertTrue(contentSource.contains("Cancel Path"))
        XCTAssertTrue(contentSource.contains("refreshLiveExecutionProtectionSettings"))
    }

    func testCommandCenterAgentSkillsLibraryIsAfterAnalystChartersAndCollapsedByDefault() throws {
        let contentSource = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let panelSource = try String(contentsOfFile: ownerSurfacePanelsPath, encoding: .utf8)

        let commandCenterSource = sourceSlice(
            from: "struct CommandCenterHomeView: View {",
            to: "struct PMInboxView: View {",
            in: contentSource
        )

        let chartersIndex = sourceIndex(of: "CommandCenterAnalystChartersSection()", in: commandCenterSource)
        let skillsIndex = sourceIndex(of: "CommandCenterAgentSkillsLibrarySection()", in: commandCenterSource)
        let schedulesIndex = sourceIndex(of: "CommandCenterAnalystStandingSchedulesSection()", in: commandCenterSource)

        XCTAssertLessThan(chartersIndex, skillsIndex)
        XCTAssertLessThan(skillsIndex, schedulesIndex)
        XCTAssertTrue(panelSource.contains("struct CommandCenterAgentSkillsLibrarySection: View"))
        XCTAssertTrue(panelSource.contains("@State private var isAgentSkillsLibraryExpanded = false"))
        XCTAssertTrue(panelSource.contains("DisclosureGroup(isExpanded: $isAgentSkillsLibraryExpanded)"))
        XCTAssertTrue(panelSource.contains("title: \"Agent Skills Library\""))
    }

    func testSystemControlAndPMInboxExposeWorkerIssueResolutionThroughAppModelPath() throws {
        let contentSource = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(contentSource.contains("func resolvePMDelegationWorkerIssue("))
        XCTAssertTrue(contentSource.contains("func resolveActivePMDelegationWorkerIssues() async -> String?"))
        XCTAssertTrue(contentSource.contains("engine.resolvePMDelegationWorkerIssue("))
        XCTAssertTrue(contentSource.contains("engine.resolveActivePMDelegationWorkerIssues("))
        XCTAssertTrue(contentSource.contains("Button(\"Resolve Failed Worker Issues\")"))
        XCTAssertTrue(contentSource.contains("Button(\"Mark Worker Issue Resolved\")"))
        XCTAssertTrue(contentSource.contains("isActivePMDelegationWorkerIssue("))
        XCTAssertTrue(contentSource.contains("keeping delegation history and audit traceability"))
    }

    func testCommandCenterAgentSkillsEditorUsesAppModelPathsAndIncludesRequiredFields() throws {
        let contentSource = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let panelSource = try String(contentsOfFile: ownerSurfacePanelsPath, encoding: .utf8)
        let skillSectionSource = sourceSlice(
            from: "struct CommandCenterAgentSkillsLibrarySection: View {",
            to: "struct CommandCenterAnalystStandingSchedulesSection: View {",
            in: panelSource
        )

        XCTAssertTrue(contentSource.contains("@Published private(set) var agentSkills: [AgentSkillRecord] = []"))
        XCTAssertTrue(contentSource.contains("func refreshAgentSkills() async -> String?"))
        XCTAssertTrue(contentSource.contains("func upsertAgentSkill(_ skill: AgentSkillRecord) async -> String?"))
        XCTAssertTrue(contentSource.contains("func archiveAgentSkill(skillId: String) async -> String?"))
        XCTAssertTrue(contentSource.contains("event.name == \"agent_skill_updated\""))
        XCTAssertTrue(skillSectionSource.contains("appModel.upsertAgentSkill(skill)"))
        XCTAssertTrue(skillSectionSource.contains("appModel.archiveAgentSkill(skillId: skill.skillId)"))
        XCTAssertTrue(skillSectionSource.contains("TextField(\"Skill Title\""))
        XCTAssertTrue(skillSectionSource.contains("TextField(\"Summary\""))
        XCTAssertTrue(skillSectionSource.contains("Picker(\"Category\""))
        XCTAssertTrue(skillSectionSource.contains("TextField(\"Tags (comma-separated)\""))
        XCTAssertTrue(skillSectionSource.contains("TextEditor(text: $editorState.documentBody)"))
        XCTAssertFalse(skillSectionSource.contains("Data(contentsOf:"))
        XCTAssertFalse(skillSectionSource.contains(".write(to:"))
    }

    func testAnalystCharterEditorExposesAgentSkillReferencesThroughAppModelPath() throws {
        let panelSource = try String(contentsOfFile: ownerSurfacePanelsPath, encoding: .utf8)
        let charterSectionSource = sourceSlice(
            from: "struct CommandCenterAnalystChartersSection: View {",
            to: "struct AnalystCharterEditorPresentationState: Equatable {",
            in: panelSource
        )
        let editorStateSource = sourceSlice(
            from: "struct AnalystCharterEditorPresentationState: Equatable {",
            to: "private struct AnalystCharterFullDocumentSheet: View {",
            in: panelSource
        )

        XCTAssertTrue(charterSectionSource.contains("Attached Agent Skills"))
        XCTAssertTrue(charterSectionSource.contains("Attach Skill"))
        XCTAssertTrue(charterSectionSource.contains("\\(editorState.skillReferences.count) attached"))
        XCTAssertTrue(charterSectionSource.contains("\\(availableSkillsForAttachment.count) available"))
        XCTAssertTrue(charterSectionSource.contains("AgentSkillReferenceRequirement.allCases"))
        XCTAssertTrue(charterSectionSource.contains("attachSelectedSkill()"))
        XCTAssertTrue(charterSectionSource.contains("removeSkillReference(skillId:"))
        XCTAssertTrue(charterSectionSource.contains("charter.skillReferences = editorState.makeSkillReferences"))
        XCTAssertTrue(charterSectionSource.contains("appModel.upsertAnalystCharter(charter)"))
        XCTAssertTrue(charterSectionSource.contains("appModel.refreshAgentSkills()"))
        XCTAssertLessThan(
            sourceIndex(of: "Picker(\"Attach Skill\"", in: charterSectionSource),
            sourceIndex(of: "ForEach($editorState.skillReferences)", in: charterSectionSource)
        )
        XCTAssertFalse(charterSectionSource.contains("availableSkillsForAttachment.prefix(2)"))
        XCTAssertFalse(charterSectionSource.contains("editorState.skillReferences.prefix(2)"))
        XCTAssertTrue(editorStateSource.contains("skillReferences: [AgentSkillReferenceEditorState]"))
        XCTAssertTrue(editorStateSource.contains("makeSkillReferences(updatedBy:"))
        XCTAssertFalse(charterSectionSource.contains("Data(contentsOf:"))
        XCTAssertFalse(charterSectionSource.contains(".write(to:"))
    }

    func testAnalystCharterEditorStatePreservesAllFourSeededSkillReferences() {
        let now = Date(timeIntervalSince1970: 1_800_002_510)
        let state = AnalystCharterEditorPresentationState(
            skillReferences: [
                AgentSkillReferenceEditorState(
                    skillId: AgentSkillSeed.disconfirmingEvidenceChecklistID,
                    requirement: .recommended,
                    rationale: "Disconfirming work.",
                    createdAt: now,
                    updatedAt: now
                ),
                AgentSkillReferenceEditorState(
                    skillId: AgentSkillSeed.portfolioFitRiskLensID,
                    requirement: .required,
                    rationale: "Portfolio fit.",
                    createdAt: now,
                    updatedAt: now
                ),
                AgentSkillReferenceEditorState(
                    skillId: AgentSkillSeed.sourceQualityCorroborationID,
                    requirement: .recommended,
                    rationale: "Source quality.",
                    createdAt: now,
                    updatedAt: now
                ),
                AgentSkillReferenceEditorState(
                    skillId: AgentSkillSeed.longShortCandidatePressureTestID,
                    requirement: .available,
                    rationale: "Pressure test.",
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )

        let references = state.makeSkillReferences(updatedBy: "human owner", now: now.addingTimeInterval(60))

        XCTAssertEqual(references.map(\.skillId), [
            AgentSkillSeed.disconfirmingEvidenceChecklistID,
            AgentSkillSeed.portfolioFitRiskLensID,
            AgentSkillSeed.sourceQualityCorroborationID,
            AgentSkillSeed.longShortCandidatePressureTestID
        ])
        XCTAssertEqual(references.map(\.requirement), [.recommended, .required, .recommended, .available])
    }

    func testStandingReportEventRefreshesMemosAlongsideReports() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let controlSource = sourceSlice(
            from: "private func handleControlStoreEvent(_ event: StoreEvent) async {",
            to: "private func refreshSnapshotFromStore(",
            in: source
        )

        XCTAssertTrue(controlSource.contains("if event.name == \"analyst_standing_report_upserted\""))
        XCTAssertTrue(controlSource.contains("_ = await refreshAnalystMemos()"))
        XCTAssertTrue(controlSource.contains("_ = await refreshAnalystStandingReports()"))
        XCTAssertTrue(controlSource.contains("if event.name == \"pm_standing_review_cycle_closed\""))
        XCTAssertTrue(controlSource.contains("_ = await refreshAnalystTasks()"))
        XCTAssertTrue(controlSource.contains("_ = await refreshPMDelegations()"))
    }

    func testPMCommunicationEventsRefreshConversationProjectionWithoutFullSnapshot() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let controlSource = sourceSlice(
            from: "private func handleControlStoreEvent(_ event: StoreEvent) async {",
            to: "private func refreshSnapshotFromStore(",
            in: source
        )
        let refreshScopeSource = sourceSlice(
            from: "private func refreshScope(for event: StoreEvent) -> StoreSnapshotRefreshScope {",
            to: "    private func refreshPortfolioIntelligenceSnapshotFromStore() async {",
            in: source
        )

        XCTAssertTrue(controlSource.contains("event.name == \"pm_communication_session_upserted\""))
        XCTAssertTrue(controlSource.contains("_ = await refreshPMCommunicationSessions()"))
        XCTAssertTrue(controlSource.contains("event.name == \"pm_communication_message_upserted\""))
        XCTAssertTrue(controlSource.contains("_ = await refreshPMCommunicationMessages()"))
        XCTAssertTrue(refreshScopeSource.contains("\"pm_communication_session_upserted\""))
        XCTAssertTrue(refreshScopeSource.contains("\"pm_communication_message_upserted\""))
        XCTAssertTrue(refreshScopeSource.contains("return .diagnostic"))
    }

    func testPortfolioWatchChartWallEventRefreshesVisibleConfiguration() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let controlSource = sourceSlice(
            from: "private func handleControlStoreEvent(_ event: StoreEvent) async {",
            to: "private func refreshSnapshotFromStore(",
            in: source
        )

        XCTAssertTrue(controlSource.contains("event.name == \"portfolio_watch_chart_wall_updated\""))
        XCTAssertTrue(controlSource.contains("_ = await refreshPortfolioWatchChartWallConfiguration()"))
    }

    func testPortfolioWatchChartWallConfigurationLoadsBeforeStartupSnapshotRender() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let startupSource = sourceSlice(
            from: "private func runStartupConversationReadyRefreshes() async {",
            to: "private func runDeferredStartupRefreshes() async {",
            in: source
        )

        let chartWallLoad = sourceIndex(of: "_ = await refreshPortfolioWatchChartWallConfiguration()", in: startupSource)
        let snapshotRefresh = sourceIndex(of: "await refreshSnapshotFromStore()", in: startupSource)

        XCTAssertLessThan(chartWallLoad, snapshotRefresh)
    }

    func testPortfolioWatchRendersPortfolioIntelligenceFoundation() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let viewSource = sourceSlice(
            from: "struct MarketWatchView: View {",
            to: "struct CommandCenterHomeView: View {",
            in: source
        )

        XCTAssertTrue(viewSource.contains("portfolioIntelligenceSection"))
        XCTAssertTrue(viewSource.contains("Portfolio Intelligence"))
        XCTAssertTrue(viewSource.contains("portfolioEnvironmentPanel("))
        XCTAssertTrue(viewSource.contains("appModel.portfolioIntelligenceSnapshot.paper"))
        XCTAssertTrue(viewSource.contains("appModel.portfolioIntelligenceSnapshot.live"))
        XCTAssertTrue(viewSource.contains("Advanced return and risk metrics stay blank"))
        XCTAssertTrue(viewSource.contains("Risk And Exposure"))
        XCTAssertTrue(viewSource.contains("Long / Short / Cash"))
        XCTAssertTrue(viewSource.contains("Concentration"))
        XCTAssertTrue(viewSource.contains("Position Weight Bars"))
        XCTAssertTrue(viewSource.contains("portfolioDataQualityRibbon"))
    }

    func testAppModelCoalescesHighFrequencyMarketDataRefreshes() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let subscribeStart = sourceIndex(of: "private func subscribeToStoreEvents()", in: source)
        let subscribeEnd = source.range(
            of: "private func refreshSnapshotFromStore() async {",
            range: subscribeStart..<source.endIndex
        )?.lowerBound ?? source.endIndex
        let subscribeSource = String(source[subscribeStart..<subscribeEnd])

        XCTAssertTrue(source.contains("private actor StoreEventRefreshCoalescer"))
        XCTAssertTrue(source.contains("private enum StoreEventSubscriptionRunner"))
        XCTAssertTrue(source.contains("isHighFrequencyMarketDataStoreEventName(event.name)"))
        XCTAssertTrue(source.contains("case \"market_data\", \"market_quote\", \"market_trade\", \"market_bar\""))
        XCTAssertTrue(subscribeSource.contains("StoreEventSubscriptionRunner.run"))
        XCTAssertTrue(subscribeSource.contains("receiveMarketData"))
        XCTAssertTrue(source.contains("private func performMarketDataSnapshotRefresh() async"))
        XCTAssertFalse(source.contains("requestCoalescedMarketDataSnapshotRefresh"))
        XCTAssertFalse(source.contains("coalescedMarketDataRefreshTask"))
        XCTAssertTrue(source.contains("private static let marketDataUIRefreshIntervalNanoseconds"))
        XCTAssertTrue(source.contains("private func refreshSnapshotFromStore("))
        XCTAssertTrue(source.contains("scope: StoreSnapshotRefreshScope,"))
        XCTAssertTrue(source.contains("reason: String"))
        XCTAssertTrue(source.contains("case .marketData:"))
        XCTAssertTrue(source.contains("assignIfChanged"))
    }

    func testAppModelUsesConnectivityScopeForReadinessAndSubscriptionEvents() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let scopeSource = sourceSlice(
            from: "private func refreshScope(for event: StoreEvent) -> StoreSnapshotRefreshScope {",
            to: "    private func refreshPortfolioIntelligenceSnapshotFromStore() async {",
            in: source
        )

        XCTAssertTrue(scopeSource.contains("\"market_data_connection_state\""))
        XCTAssertTrue(scopeSource.contains("\"market_data_subscription\""))
        XCTAssertTrue(scopeSource.contains("\"market_data_desired_subscription\""))
        XCTAssertTrue(scopeSource.contains("\"always_on_readiness\""))
        XCTAssertTrue(scopeSource.contains("return .connectivity"))
        XCTAssertTrue(scopeSource.contains("\"diagnostic\""))
        XCTAssertTrue(scopeSource.contains("return .diagnostic"))
    }

    func testTelegramPollingSkipsCommunicationRefreshWhenNoMessagesChanged() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let pollSource = sourceSlice(
            from: "func pollTelegramBridgeUpdates() async -> String? {",
            to: "    private func startTelegramBridgePollingLoopIfNeeded() {",
            in: source
        )

        XCTAssertTrue(pollSource.contains("let result = try await engine.pollTelegramUpdates"))
        XCTAssertTrue(pollSource.contains("let communicationChanged = telegramPollChangedPMCommunication(result)"))
        XCTAssertTrue(pollSource.contains("if communicationChanged"))
        XCTAssertTrue(pollSource.contains("_ = await refreshPMCommunicationSessions()"))
        XCTAssertTrue(pollSource.contains("_ = await refreshPMCommunicationMessages()"))
        XCTAssertTrue(pollSource.contains("result.statusRefreshRecommended"))
        XCTAssertTrue(pollSource.contains("refreshTelegramBridgeStatusFromPollingIfNeeded"))
        XCTAssertFalse(pollSource.contains("_ = await refreshTelegramBridgeStatus()"))
        XCTAssertTrue(pollSource.contains("result.ingestedMessageCount > 0"))
        XCTAssertTrue(pollSource.contains("result.approvalResponseCount > 0"))
        XCTAssertTrue(pollSource.contains("result.clarificationReplyCount > 0"))
    }

    func testTelegramPollingLoopDoesNotPreflightKeychainStatusEachInterval() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let loopSource = sourceSlice(
            from: "private func startTelegramBridgePollingLoopIfNeeded() {",
            to: "    func refreshPMContextPack() async -> String? {",
            in: source
        )

        XCTAssertTrue(loopSource.contains("_ = await self.pollTelegramBridgeUpdates()"))
        XCTAssertFalse(loopSource.contains("let status = await engine.telegramBridgeStatus()"))
        XCTAssertFalse(loopSource.contains("guard status.tokenConfigured else { continue }"))
    }

    func testCommandCenterBodyUsesPrecomputedOwnerSurfaceProjections() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let commandCenterSource = sourceSlice(
            from: "struct CommandCenterHomeView: View {",
            to: "    private func ownerDecisionCard",
            in: source
        )

        XCTAssertTrue(commandCenterSource.contains("let snapshot = appModel.pmCommandCenterSnapshot"))
        XCTAssertTrue(commandCenterSource.contains("let decisionItems = appModel.ownerDecisionDeskItems"))
        XCTAssertTrue(commandCenterSource.contains("let backgroundCards = appModel.ownerBackgroundActivityCards"))
        XCTAssertTrue(commandCenterSource.contains("let recentChanges = appModel.ownerRecentChangePresentations"))
        XCTAssertTrue(commandCenterSource.contains("let conversation = appModel.ownerPMConversationPresentation"))
        XCTAssertFalse(commandCenterSource.contains("makeOwnerDecisionDeskPresentations("))
        XCTAssertFalse(commandCenterSource.contains("makeOwnerPMConversationPresentation("))
        XCTAssertFalse(commandCenterSource.contains("makePMCommandCenterSnapshot("))
        XCTAssertFalse(commandCenterSource.contains("makeRunningJobSnapshots("))
    }

    func testCommandCenterTerminalLiveReviewsUseSharedClearAction() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let ownerDecisionCardSource = sourceSlice(
            from: "private func ownerDecisionCard(_ item: OwnerDecisionDeskItemPresentation) -> some View {",
            to: "    private func isClearablePMApprovalRequest",
            in: source
        )
        let commandCenterClearHelper = sourceSlice(
            from: "private func isClearablePMApprovalRequest(_ request: PMApprovalRequest) -> Bool {",
            to: "    private func acknowledgeOwnerDecision(request: PMApprovalRequest) {",
            in: source
        )
        let pmInboxClearHelper = sourceSlice(
            from: "struct PMInboxView: View {",
            to: "    private func applyOwnerReview",
            in: source
        )

        XCTAssertTrue(ownerDecisionCardSource.contains("ownerConversationActionButton(\"Clear From Decisions\""))
        XCTAssertTrue(ownerDecisionCardSource.contains("acknowledgeOwnerDecision(request: request)"))
        XCTAssertTrue(commandCenterClearHelper.contains("isPMApprovalRequestClearableFromActiveDecisions(request)"))
        XCTAssertTrue(pmInboxClearHelper.contains("isPMApprovalRequestClearableFromActiveDecisions(request)"))
        XCTAssertTrue(source.contains("func acknowledgePMApprovalRequest("))
    }

    func testMarketDataSnapshotDoesNotRebuildOwnerSurfaceProjections() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let marketDataSource = sourceSlice(
            from: "private func applyMarketDataSnapshot(_ snapshot: StoreSnapshot) {",
            to: "private func applyConnectivitySnapshot(_ snapshot: StoreSnapshot) {",
            in: source
        )
        let connectivitySource = sourceSlice(
            from: "private func applyConnectivitySnapshot(_ snapshot: StoreSnapshot) {",
            to: "private func assignIfChanged<Value: Equatable>",
            in: source
        )
        let fullSource = sourceSlice(
            from: "private func applyFullSnapshot(_ snapshot: StoreSnapshot, reason: String) async {",
            to: "private func applyMarketDataSnapshot(_ snapshot: StoreSnapshot) {",
            in: source
        )

        XCTAssertFalse(marketDataSource.contains("rebuildOwnerSurfaceProjections"))
        XCTAssertFalse(connectivitySource.contains("rebuildOwnerSurfaceProjections"))
        XCTAssertTrue(fullSource.contains("rebuildOwnerSurfaceProjections(reason: reason)"))
        XCTAssertTrue(source.contains("@Published private(set) var ownerPMConversationPresentation"))
        XCTAssertTrue(source.contains("private func rebuildOwnerSurfaceProjections(reason: String = \"direct\")"))
    }

    func testIdleControlEventsUseNarrowSnapshotScopes() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let refreshScopeSource = sourceSlice(
            from: "private func refreshScope(for event: StoreEvent) -> StoreSnapshotRefreshScope {",
            to: "private func refreshPortfolioIntelligenceSnapshotFromStore() async {",
            in: source
        )
        let jobsSource = sourceSlice(
            from: "private func applyJobsSnapshot(_ snapshot: StoreSnapshot, reason: String) async {",
            to: "private func applySchedulesSnapshot(_ snapshot: StoreSnapshot) {",
            in: source
        )
        let newsSource = sourceSlice(
            from: "private func applyNewsSnapshot(_ snapshot: StoreSnapshot) {",
            to: "private func applyStrategyStatusSnapshot(_ snapshot: StoreSnapshot) {",
            in: source
        )

        XCTAssertTrue(refreshScopeSource.contains("case \"jobs\":\n            return .jobs"))
        XCTAssertTrue(refreshScopeSource.contains("case \"rss_feeds\", \"news_events\", \"news_ingest_status\":\n            return .news"))
        XCTAssertTrue(refreshScopeSource.contains("case \"proposal_runs\":\n            return .proposalRuns"))
        XCTAssertTrue(refreshScopeSource.contains("\"notification\""))
        XCTAssertTrue(refreshScopeSource.contains("return .diagnostic"))
        XCTAssertTrue(jobsSource.contains("rebuildJobScopedOwnerSurfaceProjections(reason: reason)"))
        XCTAssertFalse(jobsSource.contains("rebuildCommandCenterProjection(reason: reason)"))
        XCTAssertFalse(jobsSource.contains("rebuildOwnerSurfaceProjections"))
        XCTAssertFalse(jobsSource.contains("makeOwnerPMConversationPresentation"))
        XCTAssertFalse(newsSource.contains("rebuildOwnerSurfaceProjections"))
        XCTAssertFalse(newsSource.contains("makeOwnerPMConversationPresentation"))
        XCTAssertTrue(source.contains("appModelFullSnapshotApplyByEvent"))
        XCTAssertTrue(source.contains("appModelSnapshotApplyCountByScope"))
        XCTAssertTrue(source.contains("pmConversationPresentationCacheHitCount"))
        XCTAssertTrue(source.contains("\"portfolioWatchVisible\": portfolioWatchVisibleRuntimeDiagnosticsJSON()"))
        XCTAssertTrue(source.contains("\"pmConversationVisible\": pmConversationVisibleRuntimeDiagnosticsJSON()"))
        XCTAssertTrue(source.contains("\"jobScopedProjectionRefreshCount\""))
        XCTAssertTrue(source.contains("private func rebuildJobScopedOwnerSurfaceProjections(reason: String)"))
        XCTAssertTrue(source.contains("private func portfolioWatchVisibleRuntimeDiagnosticsJSON() -> JSONValue"))
        XCTAssertTrue(source.contains("private func pmConversationVisibleRuntimeDiagnosticsJSON() -> JSONValue"))
        XCTAssertTrue(source.contains("\"telegramVisibleMessageCount\""))
        XCTAssertTrue(source.contains("\"effectiveSelectedSymbols\""))
        XCTAssertTrue(source.contains("diagnosticDateJSON"))
    }

    func testStrategyBriefCandidateIsCachedOutsideSwiftUIBody() throws {
        let contentSource = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let panelsSource = try String(contentsOfFile: ownerSurfacePanelsPath, encoding: .utf8)
        let strategySectionSource = sourceSlice(
            from: "struct CommandCenterStrategyBriefSection: View {",
            to: "struct StrategyBriefEditorPresentationState",
            in: panelsSource
        )

        XCTAssertTrue(contentSource.contains("@Published private(set) var strategyBriefRevisionCandidate"))
        XCTAssertTrue(contentSource.contains("private func rebuildStrategyBriefRevisionCandidateIfNeeded()"))
        XCTAssertTrue(contentSource.contains("makeStrategyBriefConversationRevisionCandidateComputation("))
        XCTAssertTrue(contentSource.contains("strategyBriefRevisionCandidateCacheHitCount"))
        XCTAssertTrue(contentSource.contains("strategyBriefRevisionCandidateScannedMessageCount"))
        XCTAssertTrue(contentSource.contains("ownerSurfaceRuntimeDiagnosticsJSON()"))
        XCTAssertTrue(contentSource.contains("CommandCenterStrategyBriefSection(\n                    revisionCandidate: appModel.strategyBriefRevisionCandidate"))
        XCTAssertTrue(strategySectionSource.contains("let revisionCandidate: StrategyBriefConversationRevisionCandidatePresentation?"))
        XCTAssertFalse(strategySectionSource.contains("makeStrategyBriefConversationRevisionCandidatePresentation("))
        XCTAssertFalse(strategySectionSource.contains("makeStrategyBriefConversationRevisionCandidateComputation("))
    }

    func testMemoryDiagnosticsScriptCapturesShortWindowRSSAndSafeCounts() throws {
        let source = try String(contentsOfFile: memoryDiagnosticsScriptPath, encoding: .utf8)

        XCTAssertTrue(source.contains("RSS_SAMPLE_COUNT"))
        XCTAssertTrue(source.contains("--duration-minutes"))
        XCTAssertTrue(source.contains("--interval-seconds"))
        XCTAssertTrue(source.contains("--exclude-first-samples"))
        XCTAssertTrue(source.contains("--app-support-root"))
        XCTAssertTrue(source.contains("--scenario-label"))
        XCTAssertTrue(source.contains("--pid"))
        XCTAssertTrue(source.contains("rss_samples.csv"))
        XCTAssertTrue(source.contains("rss_slope.txt"))
        XCTAssertTrue(source.contains("memory_classification.txt"))
        XCTAssertTrue(source.contains("vmmap_start_summary.txt"))
        XCTAssertTrue(source.contains("status_counts.txt"))
        XCTAssertTrue(source.contains("diagnostic_context.txt"))
        XCTAssertTrue(source.contains("allocation_attribution_next_steps.txt"))
        XCTAssertTrue(source.contains("TRADINGKIT_APP_SUPPORT_ROOT=\"$APP_SUPPORT_ROOT\" swift run alpaca_agentctl status"))
        XCTAssertTrue(source.contains("xcrun xctrace record --template \"Allocations\""))
        XCTAssertTrue(source.contains("MallocStackLogging=1"))
        XCTAssertTrue(source.contains("physicalFootprintSlopeMBPerMinute"))
        XCTAssertTrue(source.contains("vmAllocateDeltaMB"))
        XCTAssertTrue(source.contains("mallocSmallDirtyDeltaMB"))
        XCTAssertTrue(source.contains("json_start = raw.find(\"{\")"))
        XCTAssertTrue(source.contains("jobsCount="))
        XCTAssertTrue(source.contains("buildTradingKitInfo="))
        XCTAssertTrue(source.contains("buildProcessIdentifier="))
        XCTAssertTrue(source.contains("buildBundleIdentifier="))
        XCTAssertTrue(source.contains("visibleJobsCount="))
        XCTAssertTrue(source.contains("jobSummaryProjectionFullScanCount="))
        XCTAssertTrue(source.contains("jobSummaryProjectionIncrementalUpdateCount="))
        XCTAssertTrue(source.contains("jobSummaryProjectionLastScannedCount="))
        XCTAssertTrue(source.contains("jobProgressPersistCount="))
        XCTAssertTrue(source.contains("newsCleanupRequestCount="))
        XCTAssertTrue(source.contains("newsCleanupFullScanCount="))
        XCTAssertTrue(source.contains("newsCleanupSkippedNoSourceChangeCount="))
        XCTAssertTrue(source.contains("newsKnownEventIDLoadDecodedLineCount="))
        XCTAssertTrue(source.contains("newsListRecentDecodedLineCount="))
        XCTAssertTrue(source.contains("newsPurgeRSSSourcesDecodedLineCount="))
        XCTAssertTrue(source.contains("watchlistCount="))
        XCTAssertTrue(source.contains("desiredMarketDataSubscriptionCount="))
        XCTAssertTrue(source.contains("storeEventDroppedCount="))
        XCTAssertTrue(source.contains("portfolioWatchSelectedCount="))
        XCTAssertTrue(source.contains("portfolioWatchRequestedSelectedCount="))
        XCTAssertTrue(source.contains("portfolioWatchActiveSelectedCount="))
        XCTAssertTrue(source.contains("portfolioWatchPricedSelectedCount="))
        XCTAssertTrue(source.contains("portfolioWatchVisibleCardCount="))
        XCTAssertTrue(source.contains("portfolioWatchVisiblePricedCardCount="))
        XCTAssertTrue(source.contains("portfolioWatchActiveButNoUsablePriceSymbols="))
        XCTAssertTrue(source.contains("pmConversationTelegramVisibleMessageCount="))
        XCTAssertTrue(source.contains("storeEventEnqueuedCount="))
        XCTAssertTrue(source.contains("storeMarketDataRawUpdateCount="))
        XCTAssertTrue(source.contains("storeMarketDataUIInvalidationYieldCount="))
        XCTAssertTrue(source.contains("storeMarketDataUIInvalidationCoalescedCount="))
        XCTAssertTrue(source.contains("storeMarketDataUIInvalidationDroppedCount="))
        XCTAssertTrue(source.contains("telegramPollCount="))
        XCTAssertTrue(source.contains("telegramNoChangePollCount="))
        XCTAssertTrue(source.contains("telegramHeartbeatRefreshPollCount="))
        XCTAssertTrue(source.contains("telegramPollingTokenKeychainReadCount="))
        XCTAssertTrue(source.contains("telegramPollingTokenCacheHitCount="))
        XCTAssertTrue(source.contains("telegramOutboundTokenKeychainReadCount="))
        XCTAssertTrue(source.contains("telegramOutboundTokenCacheHitCount="))
        XCTAssertTrue(source.contains("appModelControlEventReceivedCount="))
        XCTAssertTrue(source.contains("appModelControlEventReceivedByName="))
        XCTAssertTrue(source.contains("appModelSnapshotApplyCountByScope="))
        XCTAssertTrue(source.contains("appModelFullSnapshotApplyCount="))
        XCTAssertTrue(source.contains("appModelFullSnapshotApplyByEvent="))
        XCTAssertTrue(source.contains("ownerSurfaceRebuildCount="))
        XCTAssertTrue(source.contains("ownerSurfaceRebuildByReason="))
        XCTAssertTrue(source.contains("commandCenterProjectionRebuildCount="))
        XCTAssertTrue(source.contains("jobScopedProjectionRefreshCount="))
        XCTAssertTrue(source.contains("ownerDecisionDeskProjectionRebuildCount="))
        XCTAssertTrue(source.contains("pmConversationPresentationRebuildCount="))
        XCTAssertTrue(source.contains("pmConversationPresentationCacheHitCount="))
        XCTAssertTrue(source.contains("pmConversationRoutineFilterScannedCount="))
        XCTAssertTrue(source.contains("strategyBriefCandidateRebuildCount="))
        XCTAssertTrue(source.contains("strategyBriefCandidateCacheHitCount="))
        XCTAssertTrue(source.contains("strategyBriefCandidateScannedMessageCount="))
        XCTAssertTrue(source.contains("strategyBriefCandidateLastScannedMessageCount="))
        XCTAssertTrue(source.contains("strategyBriefCandidateMessageScanLimit="))
        XCTAssertTrue(source.contains("volatileCacheTrimCount="))
        XCTAssertTrue(source.contains("volatileCacheMemoryPressureTrimCount="))
        XCTAssertTrue(source.contains("volatileCacheCurrentCategoryCounts="))
        XCTAssertTrue(source.contains("volatileCacheLastCategoryCounts="))
        XCTAssertTrue(source.contains("marketDataPresentationActiveTab="))
        XCTAssertTrue(source.contains("marketDataPresentationPublishedCount="))
        XCTAssertTrue(source.contains("marketDataPresentationSuppressedHiddenCount="))
        XCTAssertTrue(source.contains("portfolioWatchChartWallActiveTab="))
        XCTAssertTrue(source.contains("portfolioWatchChartWallRebuildCount="))
        XCTAssertTrue(source.contains("portfolioWatchChartWallPublishedRebuildCount="))
        XCTAssertTrue(source.contains("portfolioWatchChartWallHiddenSkipCount="))
        XCTAssertTrue(source.contains("portfolioWatchChartWallReleaseCount="))
        XCTAssertTrue(source.contains("portfolioWatchChartWallTrackerPointCount="))
        XCTAssertTrue(source.contains("topBannerPresentationRecomputeCount="))
        XCTAssertTrue(source.contains("topBannerPresentationPublishSkipCount="))
        XCTAssertTrue(source.contains("topCardPresentationRecomputeCount="))
        XCTAssertTrue(source.contains("topCardPresentationPublishSkipCount="))
        XCTAssertTrue(source.contains("systemHealthPresentationRecomputeCount="))
        XCTAssertTrue(source.contains("systemHealthPresentationPublishSkipCount="))
        XCTAssertTrue(source.contains("statusSerializationCount="))
        XCTAssertTrue(source.contains("statusSnapshotRetainedCount="))
        XCTAssertFalse(source.contains("secretKey"))
        XCTAssertFalse(source.contains("secret_key"))
        XCTAssertFalse(source.contains("chat_id"))
    }

    func testVisibleStatusAndTopBarPresentationAreCachedOutsideBody() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let appModelSource = sourceSlice(
            from: "struct CommandCenterTopBarChipPresentation: Equatable, Identifiable {",
            to: "private func rebuildOwnerSurfaceProjections(reason: String = \"direct\") {",
            in: source
        )
        let topBarSource = sourceSlice(
            from: "private var commandCenterTopBar: some View {",
            to: "    private func commandCenterChip(title: String, value: String) -> some View {",
            in: source
        )
        let systemControlSource = sourceSlice(
            from: "struct SystemControlView: View {",
            to: "    var body: some View {",
            in: source
        )
        let diagnosticsSource = sourceSlice(
            from: "private func ownerSurfaceRuntimeDiagnosticsJSON() -> JSONValue {",
            to: "private func refreshScope(for event: StoreEvent) -> StoreSnapshotRefreshScope {",
            in: source
        )

        XCTAssertTrue(source.contains("@Published private(set) var visibleStatusPresentation: VisibleStatusPresentation = .initial"))
        XCTAssertTrue(appModelSource.contains("private func rebuildVisibleStatusPresentation(reason: String = \"direct\") -> Bool"))
        XCTAssertTrue(appModelSource.contains("assignIfChanged(\\.visibleStatusPresentation, presentation)"))
        XCTAssertTrue(appModelSource.contains("makeTradeStreamReadinessPresentation("))
        XCTAssertTrue(appModelSource.contains("makeMarketDataStreamReadinessPresentation("))
        XCTAssertTrue(appModelSource.contains("makeOwnerSystemExceptionCategoryPresentations("))
        XCTAssertTrue(appModelSource.contains("ownerDecisionTopBarValue("))
        XCTAssertTrue(appModelSource.contains("let systemHealthMetrics = ["))
        XCTAssertTrue(appModelSource.contains("SystemHealthMetricPresentation(title: \"Running Jobs\""))
        XCTAssertTrue(topBarSource.contains("ForEach(appModel.commandCenterTopBarChips)"))
        XCTAssertFalse(topBarSource.contains("Trades \\(appModel.tradeStreamOwnerFacingLabel)"))
        XCTAssertFalse(topBarSource.contains("ownerDecisionChipValue("))
        XCTAssertTrue(systemControlSource.contains("appModel.ownerSystemExceptionCategories"))
        XCTAssertFalse(systemControlSource.contains("makeOwnerSystemExceptionCategoryPresentations("))
        XCTAssertTrue(source.contains("var systemHealthMetrics: [SystemHealthMetricPresentation]"))
        XCTAssertTrue(source.contains("systemStat(metrics, 0)"))
        XCTAssertTrue(diagnosticsSource.contains("\"visibleSurfaceAllocation\": .object(["))
        XCTAssertTrue(diagnosticsSource.contains("\"topBannerPresentationRecomputeCount\""))
        XCTAssertTrue(diagnosticsSource.contains("\"topCardPresentationPublishSkipCount\""))
        XCTAssertTrue(diagnosticsSource.contains("\"systemHealthPresentationPublishSkipCount\""))
        XCTAssertTrue(diagnosticsSource.contains("\"statusSerializationCount\""))
        XCTAssertTrue(diagnosticsSource.contains("\"statusSnapshotRetainedCount\": .number(0)"))
        XCTAssertTrue(source.contains("private static let diagnosticISO8601FormatterLock = NSLock()"))
        XCTAssertTrue(source.contains("private static let diagnosticISO8601Formatter"))
    }

    func testPMInboxReviewProjectionStaysVisibleBounded() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let projectionSource = sourceSlice(
            from: "private func makePMInboxReviewProjection(",
            to: "private struct AnalystSignalBadge: View {",
            in: source
        )
        let recentActivitySource = sourceSlice(
            from: "func makePMInboxRecentAnalystActivityItems(",
            to: "private func isPMRequestedAdHocDelegation(",
            in: source
        )

        XCTAssertTrue(source.contains("private enum PMInboxProjectionBudget"))
        XCTAssertTrue(source.contains("static let recentAnalystActivityVisible = 5"))
        XCTAssertTrue(source.contains("static let recentAnalystActivityScope = 25"))
        XCTAssertTrue(source.contains("static let communicationSessionsForDisplay = 25"))
        XCTAssertTrue(source.contains("static let rowSummaryCharacters = 480"))
        XCTAssertTrue(source.contains("private func boundedPMInboxPreviewText"))
        XCTAssertTrue(projectionSource.contains("limit: PMInboxProjectionBudget.recentAnalystActivityScope"))
        XCTAssertTrue(projectionSource.contains(".prefix(PMInboxProjectionBudget.communicationSessionsForDisplay)"))
        XCTAssertTrue(recentActivitySource.contains("boundedPMInboxPreviewText("))
        XCTAssertFalse(projectionSource.contains("limit: nil"))
    }

    func testPortfolioWatchChartHotPathAvoidsPerPointDomainScansAndPointAnimations() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let chartSource = sourceSlice(
            from: "private func intradayChart(",
            to: "private var connectionTitle: String",
            in: source
        )

        XCTAssertTrue(chartSource.contains("let domain = yDomain(for: points)"))
        XCTAssertTrue(chartSource.contains("yStart: .value(\"Floor\", domain.lowerBound)"))
        XCTAssertTrue(chartSource.contains(".chartYScale(domain: domain)"))
        XCTAssertTrue(chartSource.contains(".animation(.easeInOut(duration: 0.18), value: liveState)"))
        XCTAssertFalse(chartSource.contains("value: points"))
        XCTAssertFalse(chartSource.contains("yDomain(for: points).lowerBound"))
        XCTAssertTrue(source.contains("let cardIdentityKey = cards.map(\\.symbol)"))
        XCTAssertTrue(source.contains(".animation(.easeInOut(duration: 0.22), value: cardIdentityKey)"))
        XCTAssertFalse(source.contains(".animation(.easeInOut(duration: 0.22), value: cards)"))
    }

    func testMainTabsGateOffscreenHeavySurfaceConstruction() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let contentViewSource = sourceSlice(
            from: "struct ContentView: View {",
            to: "    private var commandCenterTopBar: some View {",
            in: source
        )

        XCTAssertTrue(source.contains("private struct LazyMainTabContent<Content: View>: View"))
        XCTAssertTrue(source.contains("if selectedTab == tab"))
        XCTAssertTrue(source.contains("func updateSelectedMainTab(_ tab: MainTab)"))
        XCTAssertTrue(source.contains("appModel.updateSelectedMainTab(selectedTab)"))
        XCTAssertTrue(source.contains("appModel.updateSelectedMainTab(newValue)"))
        XCTAssertTrue(source.contains("private var shouldPublishMarketDataPresentation: Bool"))
        XCTAssertTrue(contentViewSource.contains("LazyMainTabContent(tab: .marketWatch, selectedTab: $selectedTab)"))
        XCTAssertTrue(contentViewSource.contains("LazyMainTabContent(tab: .pmInbox, selectedTab: $selectedTab)"))
        XCTAssertTrue(contentViewSource.contains("LazyMainTabContent(tab: .systemControl, selectedTab: $selectedTab)"))
        XCTAssertFalse(contentViewSource.contains("\n                MarketWatchView()\n                    .tag(MainTab.marketWatch)"))
        XCTAssertFalse(contentViewSource.contains("\n                    PMInboxView(selectedTab: $selectedTab)\n                        .tag(MainTab.pmInbox)"))
    }

    func testSystemControlExposesVolatileCacheTrimWithoutDurableDeletion() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let trimSource = sourceSlice(
            from: "func trimVolatileCaches(reason: String = \"manual\") -> String {",
            to: "    var ipcStatusLine: String {",
            in: source
        )
        let systemControlSource = sourceSlice(
            from: "private var volatileCacheTrimCard: some View {",
            to: "    private var storageCleanupSummary: some View {",
            in: source
        )

        XCTAssertTrue(trimSource.contains("proposalDetailsByID = [:]"))
        XCTAssertTrue(trimSource.contains("runDetailsByID = [:]"))
        XCTAssertTrue(trimSource.contains("portfolioWatchSeriesTracker.removeAll(keepingCapacity: false)"))
        XCTAssertTrue(trimSource.contains("portfolioWatchChartCards = []"))
        XCTAssertTrue(trimSource.contains("lastVolatileCacheTrimCategoryCounts = ["))
        XCTAssertTrue(trimSource.contains("pmConversationRoutineFilterCache.entryCount"))
        XCTAssertTrue(trimSource.contains("releaseCommandCenterDerivedPresentations(reason: \"volatile_cache_trim\")"))
        XCTAssertTrue(source.contains("private func releaseCommandCenterDerivedPresentations(reason: String)"))
        XCTAssertTrue(source.contains("ownerPMConversationPresentation = nil"))
        XCTAssertTrue(trimSource.contains("Durable history and Store truth were not deleted."))
        XCTAssertFalse(trimSource.contains("fileManager.removeItem"))
        XCTAssertTrue(source.contains("DispatchSource.makeMemoryPressureSource"))
        XCTAssertTrue(source.contains("memoryPressureTrimCount"))
        XCTAssertTrue(source.contains("volatileCacheCategoryCountsJSON()"))
        XCTAssertTrue(systemControlSource.contains("Button(\"Run Memory Relief\")"))
        XCTAssertTrue(systemControlSource.contains("appModel.performMemoryRelief("))
        XCTAssertTrue(systemControlSource.contains("mode: .systemControlManual"))
        XCTAssertTrue(systemControlSource.contains("allocator to return free pages"))
    }

    func testSelfFootprintMemoryPostureMonitorUsesConservativeCadenceAndPublicAllocatorRelief() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("MemoryPostureMonitorConfiguration.conservativeDefault"))
        XCTAssertTrue(source.contains("startSelfFootprintMemoryPostureMonitoringIfNeeded()"))
        XCTAssertTrue(source.contains("MemoryPosturePolicy.shouldRunScheduledSample"))
        XCTAssertTrue(source.contains("performMemoryRelief("))
        XCTAssertTrue(source.contains("malloc_zone_pressure_relief"))
        XCTAssertTrue(source.contains("mach_task_self_"))
        XCTAssertTrue(source.contains("TASK_VM_INFO"))
        XCTAssertTrue(source.contains("memoryPostureDiagnostics"))
        XCTAssertTrue(source.contains("\"memoryPosture\": memoryPostureDiagnostics.jsonValue"))
        XCTAssertFalse(source.contains("Process()"))
    }

    func testPortfolioWatchChartWallDerivedCardsAreReleasedWhenTabIsInactive() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let rebuildSource = sourceSlice(
            from: "private func releasePortfolioWatchDerivedPresentations(reason: String) {",
            to: "    private func shortOrderID(_ orderID: String) -> String {",
            in: source
        )
        let selectedTabSource = sourceSlice(
            from: "func updateSelectedMainTab(_ tab: MainTab) {",
            to: "    func handleHostWillSleep() {",
            in: source
        )

        XCTAssertTrue(rebuildSource.contains("guard forcePublish || selectedMainTab == .marketWatch else"))
        XCTAssertTrue(rebuildSource.contains("portfolioWatchChartWallHiddenSkipCount += 1"))
        XCTAssertTrue(rebuildSource.contains("releasePortfolioWatchDerivedPresentations(reason: \"portfolio_watch_hidden\")"))
        XCTAssertTrue(rebuildSource.contains("assignIfChanged(\n            \\.portfolioWatchChartCards"))
        XCTAssertTrue(selectedTabSource.contains("releasePortfolioWatchDerivedPresentations(reason: \"tab_changed_away\")"))
        XCTAssertTrue(selectedTabSource.contains("releaseCommandCenterDerivedPresentations(reason: \"tab_changed_away\")"))
        XCTAssertTrue(selectedTabSource.contains("rebuildPortfolioWatchChartWall(forcePublish: true, reason: \"tab_visible_portfolio_watch\")"))
        XCTAssertTrue(source.contains("rebuildCommandCenterProjection(reason: reason, publishesVisibleCards: false)"))
        XCTAssertTrue(source.contains("guard selectedMainTab == .commandCenter else"))
        XCTAssertTrue(source.contains("\"portfolioWatchChartWall\": .object(["))
        XCTAssertTrue(source.contains("\"marketDataPresentation\": .object(["))
        XCTAssertTrue(source.contains("\"hiddenSkipCount\""))
        XCTAssertTrue(source.contains("\"trackerPointCount\""))
    }

    func testMarketDataOnlyTicksDoNotPublishHiddenTabPresentationState() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let marketDataSource = sourceSlice(
            from: "private func applyMarketDataSnapshot(_ snapshot: StoreSnapshot) {",
            to: "    private func applyConnectivitySnapshot(_ snapshot: StoreSnapshot) {",
            in: source
        )

        XCTAssertTrue(marketDataSource.contains("guard shouldPublishMarketDataPresentation else"))
        XCTAssertTrue(marketDataSource.contains("marketDataPresentationSuppressedCount += 1"))
        XCTAssertTrue(marketDataSource.contains("quotesBySymbolOverride: snapshot.quotesBySymbol"))
        XCTAssertTrue(marketDataSource.contains("optionQuotesBySymbolOverride: snapshot.optionQuotesBySymbol"))
        XCTAssertTrue(marketDataSource.contains("marketDataPresentationPublishedCount += 1"))
        XCTAssertTrue(marketDataSource.contains("assignIfChanged(\\.quotesBySymbol, snapshot.quotesBySymbol)"))
        XCTAssertTrue(source.contains("assignIfChanged(\\.engineStatusText, await engine.status)"))
    }

    func testAnalystCharterEventRefreshesVisibleCharterProjection() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let controlSource = sourceSlice(
            from: "private func handleControlStoreEvent(_ event: StoreEvent) async {",
            to: "private func refreshSnapshotFromStore(",
            in: source
        )

        XCTAssertTrue(controlSource.contains("event.name == \"analyst_charter_updated\""))
        XCTAssertTrue(controlSource.contains("_ = await refreshAnalystCharters()"))
        XCTAssertTrue(controlSource.contains("_ = await refreshPMContextPack()"))
    }

    func testRecentPMDecisionsNoLongerFilterOutBackgroundStandingReviewClosures() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let projectionStart = sourceIndex(of: "private func makePMInboxReviewProjection(", in: source)
        let projectionEnd = source.range(
            of: "private struct AnalystSignalBadge: View {",
            range: projectionStart..<source.endIndex
        )?.lowerBound ?? source.endIndex
        let projectionSource = String(source[projectionStart..<projectionEnd])

        XCTAssertTrue(projectionSource.contains("let visibleDecisions = Array("))
        XCTAssertFalse(projectionSource.contains("isBackgroundStandingReviewDecision("))
    }

    func testPMInboxCommunicationLogHasDirectOpenAndScrollableHistory() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let communicationGroupSource = sourceSlice(
            from: "private var pmUserCommunicationGroup: some View {",
            to: "private func pmSurfaceCoordinationView(",
            in: source
        )
        XCTAssertTrue(communicationGroupSource.contains("Button(\"Open Latest Communication Log\")"))
        XCTAssertTrue(communicationGroupSource.contains("Button(\"Jump To Latest Entry\")"))

        let communicationDetailSource = sourceSlice(
            from: "private var pmCommunicationDetail: some View {",
            to: "private func pmCommunicationChannelDisplayName(_ channel: PMCommunicationChannel) -> String {",
            in: source
        )
        XCTAssertTrue(communicationDetailSource.contains("Text(\"Conversation Log\")"))
        XCTAssertTrue(communicationDetailSource.contains("ScrollViewReader { scrollProxy in"))
        XCTAssertTrue(communicationDetailSource.contains(".frame(minHeight: 220, maxHeight: 360)"))
    }

    func testRuntimeSettingsRefreshPrefersNewerAppStateOverStaleReloads() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("func latestRuntimeSettingsValue<T>("))
        XCTAssertTrue(source.contains("recentNewsAnalystRuntimeSettings = latestRuntimeSettingsValue("))
        XCTAssertTrue(source.contains("standingBenchAnalystRuntimeSettings = latestRuntimeSettingsValue("))
    }

    func testAsyncRefreshCoordinatorRejectsStaleGenerationForSameDomain() async {
        let coordinator = AsyncRefreshCoordinator<String>()

        let stale = await coordinator.begin("pmDecisions")
        let fresh = await coordinator.begin("pmDecisions")
        let staleIsLatest = await coordinator.isLatest(stale, for: "pmDecisions")
        let freshIsLatest = await coordinator.isLatest(fresh, for: "pmDecisions")

        XCTAssertFalse(staleIsLatest)
        XCTAssertTrue(freshIsLatest)
    }

    func testPMInboxReviewRefreshUsesPerDomainFreshnessGuards() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("private let pmInboxRefreshCoordinator = AsyncRefreshCoordinator<PMInboxRefreshDomain>()"))
        XCTAssertTrue(source.contains("private func runLatestPMInboxRefresh<Value>("))
        XCTAssertTrue(source.contains("guard await pmInboxRefreshCoordinator.isLatest(generation, for: domain) else"))
        XCTAssertTrue(source.contains("let pmProfileError = await refreshPMProfiles()"))
        XCTAssertFalse(source.contains("let profiles = try await engine.listPMProfiles()"))
    }

    func testRefreshPMContextPackSchedulesStandingReviewAutoConsumeForPendingQueue() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)
        let refreshStart = sourceIndex(of: "func refreshPMContextPack() async -> String? {", in: source)
        let refreshSlice = String(source[refreshStart...])

        XCTAssertTrue(refreshSlice.contains("self?.pmContextPack = contextPack"))
        XCTAssertTrue(refreshSlice.contains("self?.scheduleAutomaticStandingReviewConsumptionIfNeeded()"))
    }

    func testRecentAnalystActivityProjectionKeepsExactLatestFiveStandingReports() {
        let base = Date(timeIntervalSince1970: 1_744_930_000)
        let reports = (0..<7).map { offset in
            AnalystStandingReport(
                reportId: "report-\(offset)",
                deliveryStatus: .reviewedByPM,
                analystId: "analyst-\(offset)",
                charterId: "charter-\(offset)",
                scheduleId: "schedule-\(offset)",
                memoId: "memo-\(offset)",
                title: "Standing report \(offset)",
                summary: "Summary \(offset)",
                cadenceIntervalSec: 604_800,
                reportingWindowSummary: "Window \(offset)",
                portfolioScopeSummary: "Scope \(offset)",
                headlineView: "Headline \(offset)",
                portfolioRelevanceSummary: "Relevance \(offset)",
                deliveredToPMInboxAt: base.addingTimeInterval(Double(offset) * 60),
                createdAt: base.addingTimeInterval(Double(offset) * 60),
                updatedAt: base.addingTimeInterval(Double(offset) * 60)
            )
        }
        let standingReportSummaries = makeStandingAnalystReportReviewSummaryPresentations(
            reports: Array(reports.reversed()),
            memos: [],
            charters: []
        )
        let recentActivity = makePMInboxRecentAnalystActivityItems(
            standingReportSummaries: standingReportSummaries,
            reports: Array(reports.reversed()),
            memos: [],
            charters: [],
            delegations: [],
            includeRecentNews: false,
            limit: 5
        )

        XCTAssertEqual(
            recentActivity.compactMap(\.linkedStandingReportID),
            ["report-6", "report-5", "report-4", "report-3", "report-2"]
        )
    }

    func testRecentPMDecisionProjectionKeepsExactLatestFiveCurrentCycleClosures() {
        let base = Date(timeIntervalSince1970: 1_744_940_000)
        let reports = (0..<5).map { offset in
            AnalystStandingReport(
                reportId: "report-\(offset)",
                deliveryStatus: .reviewedByPM,
                analystId: "analyst-\(offset)",
                charterId: "charter-\(offset)",
                scheduleId: "schedule-\(offset)",
                memoId: "memo-\(offset)",
                title: "Standing report \(offset)",
                summary: "Summary \(offset)",
                cadenceIntervalSec: 604_800,
                reportingWindowSummary: "Window \(offset)",
                portfolioScopeSummary: "Scope \(offset)",
                headlineView: "Headline \(offset)",
                portfolioRelevanceSummary: "Relevance \(offset)",
                deliveredToPMInboxAt: base.addingTimeInterval(Double(offset) * 60),
                createdAt: base.addingTimeInterval(Double(offset) * 60),
                updatedAt: base.addingTimeInterval(Double(offset) * 60)
            )
        }
        let activityItems = reports.reversed().map { report in
            PMInboxRecentAnalystActivityItem(
                id: "standing:\(report.reportId)",
                kind: .standingReport,
                analystTitle: report.title,
                timestamp: report.deliveredToPMInboxAt,
                headline: report.title,
                summary: report.headlineView,
                linkedStandingReportID: report.reportId,
                linkedMemoID: report.memoId,
                linkedDelegationID: nil
            )
        }
        let decisions = (0..<7).map { offset in
            PMDecisionRecord(
                decisionId: "decision-\(offset)",
                pmId: "pm-1",
                title: "Standing review conclusion \(offset)",
                summary: "Decision \(offset)",
                charterId: offset < 5 ? "charter-\(offset)" : "charter-stale-\(offset)",
                createdAt: base.addingTimeInterval(Double(offset) * 60 + 30),
                updatedAt: base.addingTimeInterval(Double(offset) * 60 + 30)
            )
        }

        let recentDecisions = makeRecentPMDecisionsForReview(
            decisions: Array(decisions.reversed()),
            recentAnalystActivityItems: activityItems,
            reports: reports,
            memos: [],
            delegations: []
        )

        XCTAssertEqual(
            recentDecisions.map(\.decisionId),
            ["decision-4", "decision-3", "decision-2", "decision-1", "decision-0"]
        )
    }

    func testOwnerFacingAnalystCharterEditorExposesSourcePolicyFields() throws {
        let source = try String(contentsOfFile: ownerSurfacePanelsPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Toggle(\"Reputable Web Research Allowed\""))
        XCTAssertTrue(source.contains("TextField(\"Preferred Sources (comma-separated)\""))
        XCTAssertTrue(source.contains("TextField(\"Restricted Sources (comma-separated)\""))
        XCTAssertTrue(source.contains("charter.sourcePolicy = AnalystSourcePolicy("))
    }

    func testConversationSurfaceKeepsOwnerDecisionsOutOfPMChatControls() throws {
        let source = try String(contentsOfFile: contentViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("Conversation stays separate from owner decisions."))
        XCTAssertFalse(source.contains("if let activeRequest = activeOwnerApprovalRequest(decisionItems: decisionItems)"))
    }
}
