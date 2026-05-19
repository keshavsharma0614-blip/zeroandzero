import Foundation
import Testing
@testable import TradingKit

@Test("PM context pack assembles bounded memory, shared truth, and workflow components")
func pmContextPackAssemblesExpectedComponents() {
    let now = Date(timeIntervalSince1970: 1_720_400_000)
    let profile = PMProfile(
        pmId: "pm-primary",
        displayName: "Primary PM",
        roleSummary: "Runs the day-to-day operating loop.",
        createdAt: now,
        updatedAt: now
    )
    let mandates = [
        PMMandate(
            mandateId: "mandate-1",
            pmId: profile.pmId,
            title: "Core supervision",
            objectiveSummary: "Compound capital with bounded approvals.",
            scope: "Portfolio-level PM supervision.",
            createdAt: now,
            updatedAt: now
        )
    ]
    let instructions = [
        PMInstruction(
            instructionId: "instruction-active",
            pmId: profile.pmId,
            title: "Challenge before escalation",
            body: "Prefer disconfirming evidence before owner-facing escalation.",
            category: "operating",
            status: .active,
            createdAt: now,
            updatedAt: now
        ),
        PMInstruction(
            instructionId: "instruction-archived",
            pmId: profile.pmId,
            title: "Archived",
            body: "No longer current.",
            category: "operating",
            status: .archived,
            createdAt: now,
            updatedAt: now.addingTimeInterval(-10)
        )
    ]
    let notebookEntries = [
        PMNotebookEntry(
            entryId: "note-1",
            pmId: profile.pmId,
            title: "Owner preference",
            body: "Keep approval requests concise.",
            createdAt: now,
            updatedAt: now
        )
    ]
    let interactionMemories = [
        PMInteractionMemoryRecord(
            memoryId: "memory-owner-preference",
            pmId: profile.pmId,
            kind: .ownerPreference,
            title: "Owner wants downside work before concentrated adds",
            summary: "Before concentrated adds to AI leaders, the owner wants downside-case work and a concise approval memo.",
            symbols: ["NVDA"],
            themes: ["AI"],
            riskPostures: ["Moderate"],
            recommendationTypes: [PMApprovalRequestType.portfolioAction.rawValue],
            sourceCommunicationMessageId: "message-2",
            createdAt: now,
            updatedAt: now
        )
    ]
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Balanced growth with event-aware review.",
        keyThemes: ["AI", "quality"],
        currentRiskPosture: "Moderate",
        reviewEscalationPosture: "Escalate material changes to PM review.",
        revisionSummary: "Owner asked the PM to tighten event review wording.",
        updatedBy: profile.pmId,
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let positions = [
        PositionRow(id: "1", symbol: "NVDA", side: "long", qty: "10", marketValue: "$12,500.00"),
        PositionRow(id: "2", symbol: "MSFT", side: "long", qty: "5", marketValue: "$2,250.00")
    ]
    let watchlist = ["NVDA", "MSFT", "AAPL", "TLT"]
    let approvals = [
        PMApprovalRequest(
            approvalRequestId: "approval-1",
            pmId: profile.pmId,
            subject: "Review proposal",
            rationale: "Bounded owner review request.",
            status: .pending,
            createdAt: now,
            updatedAt: now
        )
    ]
    let decisions = [
        PMDecisionRecord(
            decisionId: "decision-1",
            pmId: profile.pmId,
            title: "Pause sizing change",
            summary: "Need stronger evidence before changing exposure.",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    ]
    let delegations = [
        PMDelegationRecord(
            delegationId: "delegation-1",
            pmId: profile.pmId,
            analystId: "tech-analyst",
            charterId: "bench-sector-technology",
            title: "Technology review",
            rationale: "Review current AI concentration.",
            status: .issued,
            createdAt: now,
            updatedAt: now
        ),
        PMDelegationRecord(
            delegationId: "delegation-2",
            pmId: profile.pmId,
            analystId: "macro-analyst",
            charterId: "bench-overlay-macro",
            title: "Macro review",
            rationale: "Review rates sensitivity.",
            status: .completed,
            createdAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60)
        )
    ]
    let memos = [
        AnalystMemo(
            memoId: "memo-1",
            analystId: "tech-analyst",
            charterId: "bench-sector-technology",
            delegationId: "delegation-1",
            pmId: profile.pmId,
            title: "Technology memo",
            executiveSummary: "Concentration remains elevated.",
            currentView: "Risk has increased.",
            evidenceSummary: "Position and price action support caution.",
            uncertaintySummary: "Awaiting next catalyst.",
            recommendedNextStep: "Keep under PM review.",
            confidence: 0.72,
            createdAt: now,
            updatedAt: now
        )
    ]
    let session = PMCommunicationSession(
        sessionId: "session-1",
        channel: .telegram,
        pmId: profile.pmId,
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let messages = [
        PMCommunicationMessage(
            messageId: "message-1",
            sessionId: session.sessionId,
            direction: .incoming,
            senderRole: .owner,
            body: "Please make this a notebook entry.",
            sentAt: now,
            promotion: PMCommunicationPromotion(
                targetType: .notebookEntry,
                targetId: "note-1",
                promotedAt: now
            ),
            createdAt: now,
            updatedAt: now
        ),
        PMCommunicationMessage(
            messageId: "message-2",
            sessionId: session.sessionId,
            direction: .incoming,
            senderRole: .owner,
            body: "Raw transcript text should not become PM memory.",
            sentAt: now,
            createdAt: now,
            updatedAt: now
        )
    ]

    let context = makePMContextPack(
        profiles: [profile],
        mandates: mandates,
        instructions: instructions,
        notebookEntries: notebookEntries,
        interactionMemories: interactionMemories,
        strategyBrief: strategyBrief,
        positions: positions,
        watchlistSymbols: watchlist,
        approvalRequests: approvals,
        decisions: decisions,
        delegations: delegations,
        analystMemos: memos,
        communicationSessions: [session],
        communicationMessages: messages,
        assembledAt: now
    )

    #expect(context.pmId == profile.pmId)
    #expect(context.profile?.displayName == "Primary PM")
    #expect(context.mandates.map(\.title) == ["Core supervision"])
    #expect(context.activeInstructions.map(\.instructionId) == ["instruction-active"])
    #expect(context.recentNotebookEntries.map(\.entryId) == ["note-1"])
    #expect(context.recentConversationContinuity.count == 1)
    #expect(context.recentConversationContinuity.first?.sourceMessageIDs == ["message-1", "message-2"])
    #expect(context.retrievedInteractionMemories.map(\.memoryId) == ["memory-owner-preference"])
    #expect(context.retrievedInteractionMemories.first?.sourceCommunicationMessageId == "message-2")
    #expect(context.retrievedInteractionMemories.first?.matchedSignals.contains(where: { $0.contains("Symbols") }) == true)
    #expect(context.sharedPortfolioTruth.positionCount == 2)
    #expect(context.sharedPortfolioTruth.watchlistCount == 4)
    #expect(context.sharedPortfolioTruth.topPositions.map(\.symbol) == ["NVDA", "MSFT"])
    #expect(context.sharedPortfolioTruth.strategyBrief?.currentRiskPosture == "Moderate")
    #expect(context.sharedPortfolioTruth.strategyBrief?.updatedBy == profile.pmId)
    #expect(context.sharedPortfolioTruth.strategyBrief?.revisionSummary?.contains("tighten event review wording") == true)
    #expect(context.openApprovalRequests.map(\.approvalRequestId) == ["approval-1"])
    #expect(context.recentDecisions.map(\.decisionId) == ["decision-1"])
    #expect(context.relevantDelegations.map(\.delegationId) == ["delegation-1", "delegation-2"])
    #expect(context.recentAnalystMemos.map(\.memoId) == ["memo-1"])
    #expect(context.promotedCommunicationOutcomes.count == 1)
    #expect(context.promotedCommunicationOutcomes.first?.targetId == "note-1")
}

@Test("PM context carries Portfolio Intelligence shorts, exposure, and Paper versus Live truth")
func pmContextPackCarriesPortfolioIntelligenceTruth() {
    let now = Date(timeIntervalSince1970: 1_765_000_200)
    let snapshot = StoreSnapshot(
        build: "test",
        isLive: false,
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "200000",
            cash: "10000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "NVDA", symbol: "NVDA", side: "long", qty: "10", marketValue: "2000"),
            PositionRow(id: "KSS", symbol: "KSS", side: "short", qty: "-50", marketValue: "-700")
        ],
        watchlistSymbols: ["NVDA", "KSS"],
        quotesBySymbol: [
            "NVDA": MarketQuote(symbol: "NVDA", lastPrice: 200, lastTradeTimestamp: "2026-04-29T16:30:00Z"),
            "KSS": MarketQuote(symbol: "KSS", lastPrice: 14, lastTradeTimestamp: "2026-04-29T16:30:00Z")
        ]
    )

    let context = makePMContextPack(
        profiles: [],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: snapshot.positions,
        openOrders: snapshot.openOrders,
        watchlistSymbols: snapshot.watchlistSymbols,
        storeSnapshot: snapshot,
        approvalRequests: [],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: now
    )

    #expect(context.portfolioIntelligence.paper.availability == .active)
    #expect(context.portfolioIntelligence.live.availability == .unavailable)
    #expect(context.portfolioIntelligence.paper.positions.contains(where: {
        $0.symbol == "KSS" && $0.side == .short
    }))
    #expect(context.portfolioIntelligence.paper.exposure.longMarketValue == 2_000)
    #expect(context.portfolioIntelligence.paper.exposure.shortMarketValue == 700)
    #expect(context.portfolioIntelligence.paper.exposure.grossExposure == 2_700)
    #expect(context.portfolioIntelligence.paper.exposure.netExposure == 1_300)
    #expect(context.portfolioIntelligence.paper.advancedMetricReadiness.items.contains(where: {
        $0.metric == .sharpeRatio && $0.status == .unavailableMissingHistory
    }))
}

@Test("PM context Portfolio Intelligence prompt lines preserve shorts and readiness")
func pmContextPortfolioIntelligencePromptLinesPreserveShortsAndReadiness() {
    let now = Date(timeIntervalSince1970: 1_765_000_300)
    let snapshot = StoreSnapshot(
        build: "test",
        accountSummary: AccountSummary(
            id: "paper-account",
            status: "ACTIVE",
            buyingPower: "200000",
            cash: "10000",
            equity: "100000",
            canShortSellEquities: true
        ),
        positions: [
            PositionRow(id: "NVDA", symbol: "NVDA", side: "long", qty: "10", marketValue: "2000"),
            PositionRow(id: "KSS", symbol: "KSS", side: "short", qty: "-50", marketValue: "-700")
        ]
    )
    let context = makePMContextPack(
        profiles: [],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: snapshot.positions,
        openOrders: [],
        watchlistSymbols: [],
        storeSnapshot: snapshot,
        approvalRequests: [],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: now
    )

    let lines = makePMContextPortfolioIntelligenceSummaryLines(context.portfolioIntelligence)

    #expect(lines.contains(where: { $0.contains("Paper Portfolio shorts") && $0.contains("KSS") }))
    #expect(lines.contains(where: { $0.contains("gross $2,700") && $0.contains("net $1,300") }))
    #expect(lines.contains(where: { $0.contains("Live Portfolio Intelligence: unavailable") }))
    #expect(lines.contains(where: { $0.contains("Alpha: unavailable_missing_benchmark") }))
    #expect(lines.joined(separator: "\n").contains("Sharpe ratio: 0.") == false)
}

@Test("PM context Portfolio Watch readiness lines preserve no-first-data caveats")
func pmContextPortfolioWatchReadinessLinesPreserveNoFirstDataCaveats() {
    let snapshot = StoreSnapshot(
        build: "test",
        watchlistSymbols: ["NVDA", "AAPL", "KSS"],
        marketDataDesiredSubscriptions: MarketDataSubscriptionSet(
            quotes: ["NVDA", "AAPL", "KSS"],
            trades: ["NVDA", "AAPL", "KSS"]
        ),
        marketDataSubscriptions: MarketDataSubscriptionSet(
            quotes: ["NVDA", "AAPL", "KSS"],
            trades: ["NVDA", "AAPL", "KSS"]
        ),
        quotesBySymbol: [:],
        lastMarketDataReceivedAt: nil,
        lastMarketDataReceivedSymbol: nil,
        marketDataConnectionState: MarketDataConnectionState.subscribed.rawValue,
        eventStreamDiagnostics: StoreEventStreamDiagnostics(
            marketDataRawUpdateCount: 0,
            marketDataRawUpdateCountsByName: [:]
        )
    )

    let readiness = makePMPortfolioWatchReadinessSummary(
        snapshot: snapshot,
        selectedSymbols: ["NVDA", "AAPL", "KSS"]
    )
    let lines = makePMContextPortfolioWatchReadinessSummaryLines(readiness)
    let rendered = lines.joined(separator: "\n")

    #expect(rendered.contains("requested 3/3"))
    #expect(rendered.contains("active subscriptions 3/3"))
    #expect(rendered.contains("usable Store prices 0/3"))
    #expect(rendered.contains("none in this app session"))
    #expect(rendered.contains("waiting for usable quote/trade/bar truth"))
    #expect(rendered.contains("active subscription acknowledgement is not the same as a usable Store price"))
}

@Test("PM synthesis prompt instructs use of Portfolio Intelligence and forbids fabricated advanced metrics")
func pmSynthesisPromptUsesPortfolioIntelligenceAndForbidsFabricatedMetrics() {
    let request = PMConversationOpenAISynthesisRequest(
        runtimeIdentifier: "gpt-5.4",
        reasoningMode: .standard,
        plannerMode: "owner_conversation_action_planning",
        sessionChannel: "in_app",
        ownerMessageBody: "Summarize my current paper portfolio risk from Portfolio Watch.",
        confirmedAppTruthSummary: [
            "Paper Portfolio Intelligence: active; equity $100,000; cash $10,000; buying power $200,000; positions 2; open orders 0.",
            "Paper Portfolio exposure: long $2,000 (2%); short $700 (0.7%); gross $2,700; net $1,300; cash weight 10%; largest NVDA 2%; top 3 concentration 2.7%.",
            "Paper Portfolio shorts from Portfolio Intelligence: KSS qty -50; signed MV -$700; absolute weight 0.7%.",
            "Portfolio Watch live-data truth: selected 3 (NVDA, AAPL, KSS); requested 3/3; active subscriptions 3/3; usable Store prices 0/3; market-data connection subscribed.",
            "Portfolio Watch first-update caveat: selected symbols still waiting for usable quote/trade/bar truth: NVDA, AAPL, KSS.",
            "Paper Portfolio advanced metrics readiness: Advanced risk/performance metrics need portfolio return history. Examples: Sharpe ratio: unavailable_missing_history (Needs a portfolio return series); Alpha: unavailable_missing_benchmark (Needs benchmark returns)."
        ]
    )

    let prompt = makePMConversationPromptText(from: request)

    #expect(prompt.contains("Treat Portfolio Intelligence inside confirmed app truth as the current app-owned portfolio risk snapshot"))
    #expect(prompt.contains("Treat Portfolio Watch live-data truth inside confirmed app truth"))
    #expect(prompt.contains("Do not treat subscribed or active market-data subscriptions as proof of usable prices"))
    #expect(prompt.contains("Do not drop short positions"))
    #expect(prompt.contains("Do not invent alpha, beta, Sharpe"))
    #expect(prompt.contains("KSS qty -50"))
    #expect(prompt.contains("waiting for usable quote/trade/bar truth"))
    #expect(prompt.contains("Sharpe ratio: unavailable_missing_history"))
}

@Test("PM context exposes approved paper establishment without active execution state")
func pmContextPackExposesApprovedPaperEstablishmentWithoutActiveExecutionState() {
    let now = Date(timeIntervalSince1970: 1_746_500_000)
    let profile = PMProfile(
        pmId: "pm-1",
        displayName: "Primary PM",
        roleSummary: "Runs the paper-establishment workflow.",
        createdAt: now,
        updatedAt: now
    )
    let approval = PMApprovalRequest(
        approvalRequestId: "approval-paper-establishment-approved",
        pmId: profile.pmId,
        subject: "Review PM recommendation: establish the initial paper portfolio",
        rationale: "The current working paper portfolio is defined and ready for governed paper-establishment.",
        requestedActionSummary: "Approve moving the current working paper portfolio into the governed paper-establishment workflow now.",
        requestType: .portfolioAction,
        status: .resolved,
        ownerResponse: .approved,
        ownerRespondedAt: now.addingTimeInterval(-60),
        createdAt: now.addingTimeInterval(-120),
        updatedAt: now.addingTimeInterval(-60)
    )

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: [],
        openOrders: [],
        watchlistSymbols: ["NVDA"],
        approvalRequests: [approval],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: now
    )

    let status = try! #require(context.sharedPortfolioTruth.paperEstablishmentExecutionStatus)
    #expect(status.state == .approvedNoActiveExecutionState)
    #expect(status.approvalRequestId == approval.approvalRequestId)
    #expect(status.summary.contains("no active pending execution/retry state"))
    #expect(status.summary.contains("Alpaca order submission has not been attempted"))
}

@Test("PM context exposes approved pending paper establishment blocked on prices")
func pmContextPackExposesApprovedPendingPaperEstablishmentBlockedOnPrices() {
    let now = Date(timeIntervalSince1970: 1_746_500_060)
    let profile = PMProfile(
        pmId: "pm-1",
        displayName: "Primary PM",
        roleSummary: "Runs the paper-establishment workflow.",
        createdAt: now,
        updatedAt: now
    )
    let approval = PMApprovalRequest(
        approvalRequestId: "approval-paper-establishment-waiting-prices",
        pmId: profile.pmId,
        subject: "Review PM recommendation: execute the current working paper portfolio",
        rationale: "The current working paper portfolio is approved, but order sizing needs usable prices.",
        requestedActionSummary: "Approve the governed paper-establishment workflow.",
        requestType: .portfolioAction,
        status: .resolved,
        ownerResponse: .approved,
        ownerRespondedAt: now.addingTimeInterval(-120),
        paperPortfolioExecutionPendingState: PMPaperPortfolioExecutionPendingState(
            status: .waitingForUsablePrices,
            missingPriceSymbols: ["AAPL", "NVDA"],
            marketDataSubscriptionSymbols: ["AAPL", "NVDA"],
            automaticRetryEnabled: true,
            lastBlockerSummary: "Missing usable prices for AAPL and NVDA.",
            lastBlockerDetail: "The app requested market-data recovery and will retry when prices arrive.",
            lastMarketDataSubscriptionRequestedAt: now.addingTimeInterval(-90),
            lastRetryAttemptedAt: now.addingTimeInterval(-30),
            updatedAt: now.addingTimeInterval(-30)
        ),
        createdAt: now.addingTimeInterval(-180),
        updatedAt: now.addingTimeInterval(-30)
    )

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: [],
        openOrders: [],
        watchlistSymbols: ["NVDA"],
        approvalRequests: [approval],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: now
    )

    let status = try! #require(context.sharedPortfolioTruth.paperEstablishmentExecutionStatus)
    #expect(status.state == .approvedWaitingForUsablePrices)
    #expect(status.approvalRequestId == approval.approvalRequestId)
    #expect(status.missingPriceSymbols == ["AAPL", "NVDA"])
    #expect(status.automaticRetryEnabled)
    #expect(status.lastBlockerSummary == "Missing usable prices for AAPL and NVDA.")
    #expect(status.lastRetryAttemptedAt == now.addingTimeInterval(-30))
    #expect(context.sharedPortfolioTruth.pendingPaperExecutions.count == 1)
}

@Test("PM context exposes paper establishment lifecycle order-attempt truth")
func pmContextPackExposesPaperEstablishmentLifecycleOrderAttemptTruth() {
    let now = Date(timeIntervalSince1970: 1_746_500_090)
    let profile = PMProfile(
        pmId: "pm-1",
        displayName: "Primary PM",
        roleSummary: "Runs the paper-establishment workflow.",
        createdAt: now,
        updatedAt: now
    )
    let approval = PMApprovalRequest(
        approvalRequestId: "approval-paper-establishment-submitted",
        pmId: profile.pmId,
        subject: "Review PM recommendation: execute the current working paper portfolio",
        rationale: "The current working paper portfolio has been routed.",
        requestedActionSummary: "Approve the governed paper-establishment workflow.",
        requestType: .portfolioAction,
        status: .resolved,
        ownerResponse: .approved,
        ownerRespondedAt: now.addingTimeInterval(-120),
        lastExecutionRoutingAssessment: PMExecutionRoutingAssessment(
            approvalRequestId: "approval-paper-establishment-submitted",
            decisionId: nil,
            proposalId: nil,
            proposalTitle: nil,
            proposalStatus: nil,
            environment: .paper,
            isLiveArmed: false,
            killSwitchEnabled: false,
            status: .routedSuccessfully,
            action: .submitWorkingPortfolioEstablishmentOrders,
            summary: "I submitted the current paper-portfolio establishment orders through the app.",
            detail: "Accepted order attempts: NVDA buy 160.",
            blockedReasons: []
        ),
        paperPortfolioExecutionLifecycleState: PMPaperPortfolioExecutionLifecycleState(
            status: .submitted,
            orderPlanStatus: .submitted,
            summary: "I submitted the current paper-portfolio establishment orders through the app.",
            detail: "Accepted order attempts: NVDA buy 160.",
            targetSymbols: ["NVDA"],
            lastRouteActionAt: now.addingTimeInterval(-30),
            orderAttemptCount: 1,
            acceptedOrderAttemptCount: 1,
            updatedAt: now.addingTimeInterval(-30)
        ),
        createdAt: now.addingTimeInterval(-180),
        updatedAt: now.addingTimeInterval(-30)
    )

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: [],
        openOrders: [],
        watchlistSymbols: ["NVDA"],
        approvalRequests: [approval],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: now
    )

    let status = try! #require(context.sharedPortfolioTruth.paperEstablishmentExecutionStatus)
    #expect(status.state == .approvedSubmitted)
    #expect(status.orderPlanStatus == .submitted)
    #expect(status.targetSymbols == ["NVDA"])
    #expect(status.orderAttemptCount == 1)
    #expect(status.acceptedOrderAttemptCount == 1)
    #expect(status.lastRouteActionAt == now.addingTimeInterval(-30))
}

@Test("PM context pack includes standing bench roster, schedule state, ad hoc availability, and pending standing review queue")
func pmContextPackIncludesStandingBenchOperatingContext() {
    let now = Date(timeIntervalSince1970: 1_742_200_000)
    let profile = PMProfile(
        pmId: "pm-primary",
        displayName: "Primary PM",
        roleSummary: "Runs the PM operating loop.",
        createdAt: now,
        updatedAt: now
    )
    let charters = StandingAnalystBenchSeed()
        .seededCharters(now: now)
        .filter {
            [
                "bench-sector-technology",
                recentNewsStandingAnalystCharterID,
                "bench-overlay-macro-international",
                "bench-overlay-portfolio-risk"
            ].contains($0.charterId)
        }
    let schedules = [
        ScheduledJobSummary(
            schedule: ScheduledJob(
                scheduleId: "standing-report-bench-sector-technology",
                jobType: .standingAnalystReport,
                enabled: true,
                trigger: ScheduledJobTrigger(intervalSec: 24 * 3_600),
                params: [
                    "analystId": .string("bench-sector-technology-analyst"),
                    "charterId": .string("bench-sector-technology"),
                    "analystTitle": .string("Technology Analyst")
                ],
                lastRunAt: now.addingTimeInterval(-3_600),
                lastRunSummary: "Technology standing report delivered.",
                nextRunAt: now.addingTimeInterval(23 * 3_600)
            )
        ),
        ScheduledJobSummary(
            schedule: ScheduledJob(
                scheduleId: "standing-report-bench-overlay-macro-international",
                jobType: .standingAnalystReport,
                enabled: false,
                trigger: ScheduledJobTrigger(intervalSec: 12 * 3_600),
                params: [
                    "analystId": .string("bench-overlay-macro-international-analyst"),
                    "charterId": .string("bench-overlay-macro-international"),
                    "analystTitle": .string("Macro and International Analyst")
                ],
                lastRunAt: now.addingTimeInterval(-7_200),
                lastRunSummary: "Macro overlay paused pending PM review.",
                nextRunAt: now.addingTimeInterval(12 * 3_600)
            )
        ),
        ScheduledJobSummary(
            schedule: ScheduledJob(
                scheduleId: "standing-report-\(recentNewsStandingAnalystCharterID)",
                jobType: .standingAnalystReport,
                enabled: true,
                trigger: ScheduledJobTrigger(intervalSec: 6 * 3_600),
                params: [
                    "analystId": .string(recentNewsStandingAnalystID),
                    "charterId": .string(recentNewsStandingAnalystCharterID),
                    "analystTitle": .string(recentNewsStandingAnalystTitle)
                ],
                lastRunAt: now.addingTimeInterval(-1_800),
                lastRunSummary: "No material escalation.",
                nextRunAt: now.addingTimeInterval(6 * 3_600)
            )
        ),
        ScheduledJobSummary(
            schedule: ScheduledJob(
                scheduleId: "standing-report-bench-overlay-portfolio-risk",
                jobType: .standingAnalystReport,
                enabled: true,
                trigger: ScheduledJobTrigger(intervalSec: 24 * 3_600),
                params: [
                    "analystId": .string("bench-overlay-portfolio-risk-analyst"),
                    "charterId": .string("bench-overlay-portfolio-risk"),
                    "analystTitle": .string("Portfolio Risk Analyst")
                ],
                lastRunAt: now.addingTimeInterval(-4_000),
                lastRunSummary: "Risk review delivered.",
                nextRunAt: now.addingTimeInterval(22 * 3_600)
            )
        )
    ]
    let standingReports = [
        AnalystStandingReport(
            reportId: "standing-report-macro-1",
            analystId: "bench-overlay-macro-international-analyst",
            charterId: "bench-overlay-macro-international",
            scheduleId: "standing-report-bench-overlay-macro-international",
            memoId: "memo-macro-1",
            title: "Macro and International Analyst Standing Report",
            summary: "Rates and dollar strength still need PM review.",
            cadenceIntervalSec: 12 * 3_600,
            reportingWindowSummary: "Past 12 hours",
            portfolioScopeSummary: "Cross-sector macro overlay",
            headlineView: "Dollar strength is changing the interpretation of international exposure.",
            portfolioRelevanceSummary: "Cross-sector macro review remains warranted.",
            deliveredToPMInboxAt: now.addingTimeInterval(-1_200),
            createdAt: now.addingTimeInterval(-1_200),
            updatedAt: now.addingTimeInterval(-1_200)
        ),
        AnalystStandingReport(
            reportId: "standing-report-risk-1",
            analystId: "bench-overlay-portfolio-risk-analyst",
            charterId: "bench-overlay-portfolio-risk",
            scheduleId: "standing-report-bench-overlay-portfolio-risk",
            memoId: "memo-risk-1",
            title: "Portfolio Risk Analyst Standing Report",
            summary: "Concentration review is awaiting PM attention.",
            cadenceIntervalSec: 24 * 3_600,
            reportingWindowSummary: "Past day",
            portfolioScopeSummary: "Portfolio-wide risk overlay",
            headlineView: "AI concentration remains the top PM review item.",
            portfolioRelevanceSummary: "Portfolio-level review remains warranted.",
            deliveredToPMInboxAt: now.addingTimeInterval(-600),
            createdAt: now.addingTimeInterval(-600),
            updatedAt: now.addingTimeInterval(-600)
        )
    ]

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: PortfolioStrategyBrief(
            objectiveSummary: "Compound capital with bounded PM review.",
            keyThemes: ["AI", "downside discipline"],
            currentRiskPosture: "Moderate",
            reviewEscalationPosture: "Escalate material changes to PM review.",
            updatedBy: profile.pmId,
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        ),
        positions: [],
        watchlistSymbols: ["NVDA", "TLT"],
        approvalRequests: [],
        decisions: [],
        delegations: [],
        analystMemos: [],
        analystCharters: charters,
        schedules: schedules,
        standingReports: standingReports,
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: now
    )

    #expect(context.operatingContext.standingBench.count == 4)
    #expect(context.operatingContext.standingEnabledCount == 3)
    #expect(context.operatingContext.adHocCapableAnalystCount == 4)
    #expect(context.operatingContext.standingBench.map(\.title).contains("Technology Analyst"))
    #expect(context.operatingContext.standingBench.map(\.title).contains("Recent News Analyst"))
    #expect(context.operatingContext.standingBench.first(where: { $0.charterId == "bench-overlay-macro-international" })?.operatingCategory == .macroInternational)
    #expect(context.operatingContext.standingBench.first(where: { $0.charterId == "bench-overlay-portfolio-risk" })?.operatingCategory == .portfolioRisk)
    #expect(context.operatingContext.standingBench.first(where: { $0.charterId == recentNewsStandingAnalystCharterID })?.operatingCategory == .recentNews)
    #expect(context.operatingContext.standingBench.first(where: { $0.charterId == "bench-overlay-macro-international" })?.standingSchedule.enabled == false)
    #expect(context.operatingContext.standingBench.first(where: { $0.charterId == "bench-sector-technology" })?.standingSchedule.cadenceSummary == "Daily")
    #expect(context.operatingContext.standingBench.first(where: { $0.charterId == "bench-overlay-portfolio-risk" })?.outstandingStandingReviewCount == 1)
    #expect(context.operatingContext.standingReviewQueue.pendingCount == 2)
    #expect(context.operatingContext.standingReviewQueue.analystsAwaitingReview == ["Macro and International Analyst", "Portfolio Risk Analyst"])
    #expect(context.operatingContext.standingReviewQueue.items.map(\.analystTitle) == ["Portfolio Risk Analyst", "Macro and International Analyst"])
}

@Test("PM context pack includes promoted communication outcomes without raw transcript spillover")
func pmContextPackUsesPromotionMetadataInsteadOfRawTranscriptHistory() {
    let now = Date(timeIntervalSince1970: 1_720_400_100)
    let profile = PMProfile(
        pmId: "pm-primary",
        displayName: "Primary PM",
        roleSummary: "Runs the day-to-day operating loop.",
        createdAt: now,
        updatedAt: now
    )
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: profile.pmId,
        title: "Hold current sizing",
        summary: "Need another analyst pass before increasing risk.",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let session = PMCommunicationSession(
        sessionId: "session-1",
        channel: .telegram,
        pmId: profile.pmId,
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let promotedMessage = PMCommunicationMessage(
        messageId: "message-1",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        body: "This long raw owner message should not be the PM working-context summary. It is only source communication.",
        sentAt: now,
        promotion: PMCommunicationPromotion(
            targetType: .decision,
            targetId: decision.decisionId,
            promotedAt: now
        ),
        createdAt: now,
        updatedAt: now
    )

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: [],
        watchlistSymbols: [],
        approvalRequests: [],
        decisions: [decision],
        delegations: [],
        analystMemos: [],
        communicationSessions: [session],
        communicationMessages: [promotedMessage],
        assembledAt: now
    )

    let promoted = try! #require(context.promotedCommunicationOutcomes.first)
    #expect(promoted.targetTitle == "Hold current sizing")
    #expect(promoted.targetSummary == "Need another analyst pass before increasing risk.")
    #expect(promoted.originSummary.contains("telegram"))
    #expect(promoted.targetSummary.contains("raw owner message") == false)
    #expect(context.recentConversationContinuity.count == 1)
    #expect(context.recentConversationContinuity.first?.continuitySummary.contains("raw owner message") == true)
    #expect(context.recentConversationContinuity.first?.sourceMessageIDs == ["message-1"])
}

@Test("PM context pack retrieves relevant interaction memories while excluding stale exercise artifacts")
func pmContextPackRetrievesRelevantInteractionMemoriesAndExcludesExerciseArtifacts() {
    let now = Date(timeIntervalSince1970: 1_720_400_200)
    let profile = PMProfile(
        pmId: "pm-primary",
        displayName: "Primary PM",
        roleSummary: "Runs the day-to-day operating loop.",
        createdAt: now,
        updatedAt: now
    )
    let strategyBrief = PortfolioStrategyBrief(
        objectiveSummary: "Balanced growth with event-aware review.",
        keyThemes: ["international", "macro"],
        currentRiskPosture: "Moderate",
        reviewEscalationPosture: "Escalate material changes to PM review.",
        updatedBy: profile.pmId,
        updateSource: .pmControlPlane,
        createdAt: now,
        updatedAt: now
    )
    let approval = PMApprovalRequest(
        approvalRequestId: "approval-international",
        pmId: profile.pmId,
        subject: "Review international allocation change",
        rationale: "Need owner review before changing the international sleeve.",
        requestType: .portfolioAction,
        status: .pending,
        createdAt: now,
        updatedAt: now
    )
    let memories = [
        PMInteractionMemoryRecord(
            memoryId: "memory-international-review",
            pmId: profile.pmId,
            kind: .reviewPreference,
            title: "Macro review before international allocation changes",
            summary: "The owner prefers macro review before international allocation changes.",
            themes: ["international", "macro"],
            recommendationTypes: [PMApprovalRequestType.portfolioAction.rawValue],
            createdAt: now,
            updatedAt: now
        ),
        PMInteractionMemoryRecord(
            memoryId: "memory-global-preference",
            pmId: profile.pmId,
            kind: .ownerPreference,
            title: "Keep approval memos concise",
            summary: "The owner wants concise approval memos.",
            createdAt: now,
            updatedAt: now.addingTimeInterval(-10)
        ),
        PMInteractionMemoryRecord(
            memoryId: "exercise-memory-noise",
            pmId: "pm-operational-exercise",
            kind: .recurringConcern,
            title: "Exercise noise",
            summary: "Should never land in PM working context.",
            themes: ["macro"],
            createdAt: now,
            updatedAt: now.addingTimeInterval(5)
        )
    ]

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: memories,
        strategyBrief: strategyBrief,
        positions: [],
        watchlistSymbols: ["EFA"],
        approvalRequests: [approval],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [],
        communicationMessages: [],
        assembledAt: now
    )

    #expect(context.retrievedInteractionMemories.map(\.memoryId) == ["memory-international-review", "memory-global-preference"])
    #expect(context.retrievedInteractionMemories.contains(where: { $0.memoryId == "exercise-memory-noise" }) == false)
    #expect(context.retrievedInteractionMemories.first?.matchedSignals.contains(where: { $0.contains("Themes") }) == true)
    #expect(context.retrievedInteractionMemories.first?.matchedSignals.contains("Recommendation type aligned") == true)
}

@Test("PM recent conversation continuity survives a pause when the resumed topic is clearly related")
func pmRecentConversationContinuityCarriesResumedTopicAcrossPause() {
    let now = Date(timeIntervalSince1970: 1_720_500_000)
    let profile = PMProfile(
        pmId: "pm-primary",
        displayName: "Primary PM",
        roleSummary: "Runs the day-to-day operating loop.",
        createdAt: now,
        updatedAt: now
    )
    let session = PMCommunicationSession(
        sessionId: "session-1",
        channel: .inApp,
        pmId: profile.pmId,
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now.addingTimeInterval(-(15 * 24 * 60 * 60)),
        updatedAt: now
    )
    let messages = [
        PMCommunicationMessage(
            messageId: "message-older-owner",
            sessionId: session.sessionId,
            direction: .incoming,
            senderRole: .owner,
            body: "Before we change the international sleeve, I want macro review first.",
            sentAt: now.addingTimeInterval(-(14 * 24 * 60 * 60)),
            createdAt: now,
            updatedAt: now
        ),
        PMCommunicationMessage(
            messageId: "message-older-pm",
            sessionId: session.sessionId,
            direction: .outgoing,
            senderRole: .pm,
            body: "Understood. I will keep international allocation changes tied to macro review.",
            sentAt: now.addingTimeInterval(-(13 * 24 * 60 * 60)),
            createdAt: now,
            updatedAt: now
        ),
        PMCommunicationMessage(
            messageId: "message-latest-owner",
            sessionId: session.sessionId,
            direction: .incoming,
            senderRole: .owner,
            body: "After travel, I want to resume that international allocation discussion and the macro review question.",
            sentAt: now.addingTimeInterval(-(1 * 24 * 60 * 60)),
            createdAt: now,
            updatedAt: now
        ),
        PMCommunicationMessage(
            messageId: "message-latest-pm",
            sessionId: session.sessionId,
            direction: .outgoing,
            senderRole: .pm,
            body: "Resuming the same topic: macro review still comes first before an international sleeve change.",
            sentAt: now,
            createdAt: now,
            updatedAt: now
        )
    ]

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: PortfolioStrategyBrief(
            objectiveSummary: "Keep international changes macro-aware.",
            keyThemes: ["international", "macro"],
            currentRiskPosture: "Moderate",
            reviewEscalationPosture: "Escalate material changes to PM review.",
            updatedBy: profile.pmId,
            updateSource: .pmControlPlane,
            createdAt: now,
            updatedAt: now
        ),
        positions: [],
        watchlistSymbols: ["EFA"],
        approvalRequests: [],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [session],
        communicationMessages: messages,
        assembledAt: now
    )

    let continuity = try! #require(context.recentConversationContinuity.first)
    #expect(continuity.resumedAfterPause == true)
    #expect(continuity.sourceMessageIDs.contains("message-older-owner"))
    #expect(continuity.sourceMessageIDs.contains("message-latest-pm"))
    #expect(continuity.topicSignals.contains(where: { $0.contains("Themes") || $0.contains("Topics") }))
}

@Test("PM recent conversation continuity stays bounded and excludes stale exercise chatter")
func pmRecentConversationContinuityStaysBoundedAndHygienic() {
    let now = Date(timeIntervalSince1970: 1_720_600_000)
    let profile = PMProfile(
        pmId: "pm-primary",
        displayName: "Primary PM",
        roleSummary: "Runs the day-to-day operating loop.",
        createdAt: now,
        updatedAt: now
    )
    let session = PMCommunicationSession(
        sessionId: "session-1",
        channel: .inApp,
        pmId: profile.pmId,
        participantDisplayName: "Owner",
        status: .active,
        createdAt: now.addingTimeInterval(-(3 * 24 * 60 * 60)),
        updatedAt: now
    )
    let unrelatedOld = PMCommunicationMessage(
        messageId: "message-old-unrelated",
        sessionId: session.sessionId,
        direction: .incoming,
        senderRole: .owner,
        body: "Let us revisit the vacation calendar and office logistics.",
        sentAt: now.addingTimeInterval(-(20 * 24 * 60 * 60)),
        createdAt: now,
        updatedAt: now
    )
    let recentMessages: [PMCommunicationMessage] = (0..<14).map { index in
        PMCommunicationMessage(
            messageId: "message-recent-\(index)",
            sessionId: session.sessionId,
            direction: index.isMultiple(of: 2) ? .incoming : .outgoing,
            senderRole: index.isMultiple(of: 2) ? .owner : .pm,
            body: index.isMultiple(of: 2)
                ? "Please keep the NVDA concentration review concise and focused on downside evidence \(index)."
                : "Understood. I am keeping the NVDA concentration review concise and focused on downside evidence \(index).",
            sentAt: now.addingTimeInterval(TimeInterval(-index * 4 * 60 * 60)),
            createdAt: now,
            updatedAt: now
        )
    }
    let exerciseSession = PMCommunicationSession(
        sessionId: "exercise-session-1",
        channel: .inApp,
        pmId: "pm-operational-exercise",
        participantId: "owner-exercise",
        participantDisplayName: "Exercise Owner",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    let exerciseMessage = PMCommunicationMessage(
        messageId: "exercise-message-1",
        sessionId: exerciseSession.sessionId,
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner-exercise",
        body: "Exercise chatter should not appear in PM working context.",
        sentAt: now,
        createdAt: now,
        updatedAt: now
    )

    let context = makePMContextPack(
        profiles: [profile],
        mandates: [],
        instructions: [],
        notebookEntries: [],
        interactionMemories: [],
        strategyBrief: nil,
        positions: [PositionRow(id: "1", symbol: "NVDA", side: "long", qty: "10", marketValue: "$10,000.00")],
        watchlistSymbols: ["NVDA"],
        approvalRequests: [],
        decisions: [],
        delegations: [],
        analystMemos: [],
        communicationSessions: [session, exerciseSession],
        communicationMessages: [unrelatedOld] + recentMessages + [exerciseMessage],
        assembledAt: now
    )

    let continuity = try! #require(context.recentConversationContinuity.first)
    #expect(context.recentConversationContinuity.count == 1)
    #expect(continuity.messageCount <= PMContextSelectionPolicy().maxRecentConversationMessagesPerThread)
    #expect(continuity.sourceMessageIDs.contains("message-old-unrelated") == false)
    #expect(continuity.sourceMessageIDs.contains("exercise-message-1") == false)
    #expect(continuity.topicSignals.contains(where: { $0.contains("Symbols: NVDA") }))
}

@Test("PM context boundary summary keeps PM memory separate from logs, analyst memory, and shared truth")
func pmContextBoundarySummaryStaysExplicit() {
    let boundary = defaultPMContextBoundarySummary()

    #expect(boundary.durableMemorySources.contains("PM profile"))
    #expect(boundary.durableMemorySources.contains("Retrieved interaction memories"))
    #expect(boundary.recentConversationSources.contains("Short-horizon continuity remains distinct from durable promoted memory"))
    #expect(boundary.communicationLogSources == ["PM communication sessions (log-only by default)", "PM communication messages (log-only by default)"])
    #expect(boundary.analystScopedSources.contains("Analyst scoped memory"))
    #expect(boundary.analystScopedSources.contains("Standing analyst bench charters"))
    #expect(boundary.sharedTruthSources.contains("Portfolio strategy brief"))
    #expect(boundary.operationalArtifactSources.contains("PM delegations"))
    #expect(boundary.operationalArtifactSources.contains("Standing analyst schedules"))
    #expect(boundary.operationalArtifactSources.contains("Standing reports awaiting PM review"))
}
