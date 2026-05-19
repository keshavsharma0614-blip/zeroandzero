import Foundation

public struct PMContextSelectionPolicy: Sendable, Equatable {
    public var maxMandates: Int
    public var maxInstructions: Int
    public var maxNotebookEntries: Int
    public var maxRecentConversationThreads: Int
    public var maxRecentConversationMessagesPerThread: Int
    public var maxRetrievedInteractionMemories: Int
    public var maxApprovalRequests: Int
    public var maxDecisions: Int
    public var maxDelegations: Int
    public var maxMemos: Int
    public var maxPromotedCommunicationOutcomes: Int
    public var maxTopPositions: Int
    public var maxWatchlistPreview: Int

    public init(
        maxMandates: Int = 4,
        maxInstructions: Int = 6,
        maxNotebookEntries: Int = 8,
        maxRecentConversationThreads: Int = 10,
        maxRecentConversationMessagesPerThread: Int = 160,
        maxRetrievedInteractionMemories: Int = 6,
        maxApprovalRequests: Int = 5,
        maxDecisions: Int = 5,
        maxDelegations: Int = 6,
        maxMemos: Int = 4,
        maxPromotedCommunicationOutcomes: Int = 6,
        maxTopPositions: Int = 6,
        maxWatchlistPreview: Int = 8
    ) {
        self.maxMandates = maxMandates
        self.maxInstructions = maxInstructions
        self.maxNotebookEntries = maxNotebookEntries
        self.maxRecentConversationThreads = maxRecentConversationThreads
        self.maxRecentConversationMessagesPerThread = maxRecentConversationMessagesPerThread
        self.maxRetrievedInteractionMemories = maxRetrievedInteractionMemories
        self.maxApprovalRequests = maxApprovalRequests
        self.maxDecisions = maxDecisions
        self.maxDelegations = maxDelegations
        self.maxMemos = maxMemos
        self.maxPromotedCommunicationOutcomes = maxPromotedCommunicationOutcomes
        self.maxTopPositions = maxTopPositions
        self.maxWatchlistPreview = maxWatchlistPreview
    }
}

public struct PMContextBoundarySummary: Sendable, Equatable {
    public var durableMemorySources: [String]
    public var recentConversationSources: [String]
    public var communicationLogSources: [String]
    public var analystScopedSources: [String]
    public var sharedTruthSources: [String]
    public var operationalArtifactSources: [String]

    public init(
        durableMemorySources: [String],
        recentConversationSources: [String],
        communicationLogSources: [String],
        analystScopedSources: [String],
        sharedTruthSources: [String],
        operationalArtifactSources: [String]
    ) {
        self.durableMemorySources = durableMemorySources
        self.recentConversationSources = recentConversationSources
        self.communicationLogSources = communicationLogSources
        self.analystScopedSources = analystScopedSources
        self.sharedTruthSources = sharedTruthSources
        self.operationalArtifactSources = operationalArtifactSources
    }
}

public struct PMContextPositionSummary: Sendable, Equatable, Identifiable {
    public var id: String { symbol }

    public var symbol: String
    public var directionLabel: String
    public var marketValue: String

    public init(symbol: String, directionLabel: String, marketValue: String) {
        self.symbol = symbol
        self.directionLabel = directionLabel
        self.marketValue = marketValue
    }
}

public struct PMContextStrategyBriefSummary: Sendable, Equatable {
    public var title: String
    public var objectiveSummary: String
    public var currentRiskPosture: String
    public var keyThemes: [String]
    public var updatedBy: String
    public var updateSource: PortfolioStrategyBriefUpdateSource
    public var revisionSummary: String?
    public var updatedAt: Date

    public init(
        title: String,
        objectiveSummary: String,
        currentRiskPosture: String,
        keyThemes: [String],
        updatedBy: String,
        updateSource: PortfolioStrategyBriefUpdateSource,
        revisionSummary: String? = nil,
        updatedAt: Date
    ) {
        self.title = title
        self.objectiveSummary = objectiveSummary
        self.currentRiskPosture = currentRiskPosture
        self.keyThemes = keyThemes
        self.updatedBy = updatedBy
        self.updateSource = updateSource
        self.revisionSummary = revisionSummary
        self.updatedAt = updatedAt
    }
}

public struct PMSharedPortfolioTruthSummary: Sendable, Equatable {
    public var positionCount: Int
    public var openOrderCount: Int
    public var watchlistCount: Int
    public var topPositions: [PMContextPositionSummary]
    public var openOrderPreview: [String]
    public var watchlistPreview: [String]
    public var paperEstablishmentExecutionStatus: PMContextPaperEstablishmentExecutionStatusSummary?
    public var pendingPaperExecutions: [PMContextPendingPaperExecutionSummary]
    public var strategyBrief: PMContextStrategyBriefSummary?

    public init(
        positionCount: Int,
        openOrderCount: Int,
        watchlistCount: Int,
        topPositions: [PMContextPositionSummary],
        openOrderPreview: [String],
        watchlistPreview: [String],
        paperEstablishmentExecutionStatus: PMContextPaperEstablishmentExecutionStatusSummary? = nil,
        pendingPaperExecutions: [PMContextPendingPaperExecutionSummary] = [],
        strategyBrief: PMContextStrategyBriefSummary?
    ) {
        self.positionCount = positionCount
        self.openOrderCount = openOrderCount
        self.watchlistCount = watchlistCount
        self.topPositions = topPositions
        self.openOrderPreview = openOrderPreview
        self.watchlistPreview = watchlistPreview
        self.paperEstablishmentExecutionStatus = paperEstablishmentExecutionStatus
        self.pendingPaperExecutions = pendingPaperExecutions
        self.strategyBrief = strategyBrief
    }
}

public enum PMContextPaperEstablishmentExecutionLifecycleState: String, Sendable, Equatable, CaseIterable {
    case ordersOrPositionsRecorded = "orders_or_positions_recorded"
    case approvedWaitingForUsablePrices = "approved_waiting_for_usable_prices"
    case approvedBlocked = "approved_blocked"
    case approvedSubmitted = "approved_submitted"
    case approvedPartiallySubmitted = "approved_partially_submitted"
    case approvedFailed = "approved_failed"
    case approvedNoActiveExecutionState = "approved_no_active_execution_state"
    case approvalPending = "approval_pending"
    case noActiveApproval = "no_active_approval"
}

public struct PMContextPaperEstablishmentExecutionStatusSummary: Sendable, Equatable {
    public var state: PMContextPaperEstablishmentExecutionLifecycleState
    public var approvalRequestId: String?
    public var subject: String?
    public var summary: String
    public var detail: String?
    public var targetSymbols: [String]
    public var missingPriceSymbols: [String]
    public var blockedReasons: [PMExecutionRoutingBlockReason]
    public var automaticRetryEnabled: Bool
    public var orderPlanStatus: PMPaperPortfolioExecutionOrderPlanStatus?
    public var lastBlockerSummary: String?
    public var lastBlockerDetail: String?
    public var lastRouteActionAt: Date?
    public var lastRetryAttemptedAt: Date?
    public var orderAttemptCount: Int
    public var acceptedOrderAttemptCount: Int
    public var failedOrderAttemptCount: Int
    public var updatedAt: Date?

    public init(
        state: PMContextPaperEstablishmentExecutionLifecycleState,
        approvalRequestId: String? = nil,
        subject: String? = nil,
        summary: String,
        detail: String? = nil,
        targetSymbols: [String] = [],
        missingPriceSymbols: [String] = [],
        blockedReasons: [PMExecutionRoutingBlockReason] = [],
        automaticRetryEnabled: Bool = false,
        orderPlanStatus: PMPaperPortfolioExecutionOrderPlanStatus? = nil,
        lastBlockerSummary: String? = nil,
        lastBlockerDetail: String? = nil,
        lastRouteActionAt: Date? = nil,
        lastRetryAttemptedAt: Date? = nil,
        orderAttemptCount: Int = 0,
        acceptedOrderAttemptCount: Int = 0,
        failedOrderAttemptCount: Int = 0,
        updatedAt: Date? = nil
    ) {
        self.state = state
        self.approvalRequestId = approvalRequestId
        self.subject = subject
        self.summary = summary
        self.detail = detail
        self.targetSymbols = targetSymbols
        self.missingPriceSymbols = missingPriceSymbols
        self.blockedReasons = blockedReasons
        self.automaticRetryEnabled = automaticRetryEnabled
        self.orderPlanStatus = orderPlanStatus
        self.lastBlockerSummary = lastBlockerSummary
        self.lastBlockerDetail = lastBlockerDetail
        self.lastRouteActionAt = lastRouteActionAt
        self.lastRetryAttemptedAt = lastRetryAttemptedAt
        self.orderAttemptCount = orderAttemptCount
        self.acceptedOrderAttemptCount = acceptedOrderAttemptCount
        self.failedOrderAttemptCount = failedOrderAttemptCount
        self.updatedAt = updatedAt
    }
}

public struct PMContextPendingPaperExecutionSummary: Sendable, Equatable, Identifiable {
    public var id: String { approvalRequestId }

    public var approvalRequestId: String
    public var subject: String
    public var missingPriceSymbols: [String]
    public var automaticRetryEnabled: Bool
    public var lastBlockerSummary: String
    public var lastBlockerDetail: String
    public var lastRetryAttemptedAt: Date?
    public var updatedAt: Date?

    public init(
        approvalRequestId: String,
        subject: String,
        missingPriceSymbols: [String],
        automaticRetryEnabled: Bool,
        lastBlockerSummary: String,
        lastBlockerDetail: String,
        lastRetryAttemptedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.approvalRequestId = approvalRequestId
        self.subject = subject
        self.missingPriceSymbols = missingPriceSymbols
        self.automaticRetryEnabled = automaticRetryEnabled
        self.lastBlockerSummary = lastBlockerSummary
        self.lastBlockerDetail = lastBlockerDetail
        self.lastRetryAttemptedAt = lastRetryAttemptedAt
        self.updatedAt = updatedAt
    }
}

public enum PMAnalystOperatingCategory: String, Sendable, Equatable, CaseIterable {
    case sector
    case macroInternational
    case portfolioRisk
    case recentNews
    case overlay

    public var displayTitle: String {
        switch self {
        case .sector:
            return "Sector"
        case .macroInternational:
            return "Macro And International"
        case .portfolioRisk:
            return "Portfolio Risk"
        case .recentNews:
            return "Recent News"
        case .overlay:
            return "Overlay"
        }
    }
}

public struct PMAnalystStandingScheduleSummary: Sendable, Equatable {
    public var enabled: Bool
    public var cadenceSummary: String
    public var intervalSec: Int
    public var lastRunAt: Date?
    public var nextRunAt: Date?
    public var lastRunSummary: String?

    public init(
        enabled: Bool,
        cadenceSummary: String,
        intervalSec: Int,
        lastRunAt: Date?,
        nextRunAt: Date?,
        lastRunSummary: String?
    ) {
        self.enabled = enabled
        self.cadenceSummary = cadenceSummary
        self.intervalSec = intervalSec
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.lastRunSummary = lastRunSummary
    }
}

public struct PMAnalystBenchMemberSummary: Sendable, Equatable, Identifiable {
    public var id: String { charterId }

    public var charterId: String
    public var analystId: String
    public var title: String
    public var benchRole: AnalystBenchRole
    public var operatingCategory: PMAnalystOperatingCategory
    public var mandateSummary: String
    public var coverageScope: String
    public var adHocTaskingAvailable: Bool
    public var standingSchedule: PMAnalystStandingScheduleSummary
    public var outstandingStandingReviewCount: Int

    public init(
        charterId: String,
        analystId: String,
        title: String,
        benchRole: AnalystBenchRole,
        operatingCategory: PMAnalystOperatingCategory,
        mandateSummary: String,
        coverageScope: String,
        adHocTaskingAvailable: Bool,
        standingSchedule: PMAnalystStandingScheduleSummary,
        outstandingStandingReviewCount: Int
    ) {
        self.charterId = charterId
        self.analystId = analystId
        self.title = title
        self.benchRole = benchRole
        self.operatingCategory = operatingCategory
        self.mandateSummary = mandateSummary
        self.coverageScope = coverageScope
        self.adHocTaskingAvailable = adHocTaskingAvailable
        self.standingSchedule = standingSchedule
        self.outstandingStandingReviewCount = outstandingStandingReviewCount
    }
}

public struct PMStandingReviewQueueItemSummary: Sendable, Equatable, Identifiable {
    public var id: String { reportId }

    public var reportId: String
    public var analystId: String
    public var charterId: String
    public var analystTitle: String
    public var reportTitle: String
    public var headlineView: String
    public var summary: String
    public var deliveredToPMInboxAt: Date

    public init(
        reportId: String,
        analystId: String,
        charterId: String,
        analystTitle: String,
        reportTitle: String,
        headlineView: String,
        summary: String,
        deliveredToPMInboxAt: Date
    ) {
        self.reportId = reportId
        self.analystId = analystId
        self.charterId = charterId
        self.analystTitle = analystTitle
        self.reportTitle = reportTitle
        self.headlineView = headlineView
        self.summary = summary
        self.deliveredToPMInboxAt = deliveredToPMInboxAt
    }
}

public struct PMStandingReviewQueueSummary: Sendable, Equatable {
    public var pendingCount: Int
    public var analystsAwaitingReview: [String]
    public var items: [PMStandingReviewQueueItemSummary]

    public init(
        pendingCount: Int,
        analystsAwaitingReview: [String],
        items: [PMStandingReviewQueueItemSummary]
    ) {
        self.pendingCount = pendingCount
        self.analystsAwaitingReview = analystsAwaitingReview
        self.items = items
    }
}

public struct PMOperatingContextSummary: Sendable, Equatable {
    public var standingBench: [PMAnalystBenchMemberSummary]
    public var standingEnabledCount: Int
    public var adHocCapableAnalystCount: Int
    public var standingReviewQueue: PMStandingReviewQueueSummary

    public init(
        standingBench: [PMAnalystBenchMemberSummary],
        standingEnabledCount: Int,
        adHocCapableAnalystCount: Int,
        standingReviewQueue: PMStandingReviewQueueSummary
    ) {
        self.standingBench = standingBench
        self.standingEnabledCount = standingEnabledCount
        self.adHocCapableAnalystCount = adHocCapableAnalystCount
        self.standingReviewQueue = standingReviewQueue
    }
}

public struct PMPromotedCommunicationOutcome: Sendable, Equatable, Identifiable {
    public var id: String { messageId }

    public var messageId: String
    public var sessionId: String
    public var channel: PMCommunicationChannel
    public var participantLabel: String?
    public var senderRole: PMCommunicationSenderRole
    public var promotedAt: Date
    public var targetType: PMCommunicationPromotionTargetType
    public var targetId: String
    public var targetTitle: String
    public var targetSummary: String
    public var targetExcerpt: String
    public var originSummary: String

    public init(
        messageId: String,
        sessionId: String,
        channel: PMCommunicationChannel,
        participantLabel: String?,
        senderRole: PMCommunicationSenderRole,
        promotedAt: Date,
        targetType: PMCommunicationPromotionTargetType,
        targetId: String,
        targetTitle: String,
        targetSummary: String,
        targetExcerpt: String,
        originSummary: String
    ) {
        self.messageId = messageId
        self.sessionId = sessionId
        self.channel = channel
        self.participantLabel = participantLabel
        self.senderRole = senderRole
        self.promotedAt = promotedAt
        self.targetType = targetType
        self.targetId = targetId
        self.targetTitle = targetTitle
        self.targetSummary = targetSummary
        self.targetExcerpt = targetExcerpt
        self.originSummary = originSummary
    }
}

public struct PMRecentConversationContinuity: Sendable, Equatable, Identifiable {
    public var id: String { sessionId }

    public var sessionId: String
    public var channel: PMCommunicationChannel
    public var participantLabel: String?
    public var continuitySummary: String
    public var topicSignals: [String]
    public var continuityReason: String
    public var sourceMessageIDs: [String]
    public var latestMessageAt: Date
    public var messageCount: Int
    public var resumedAfterPause: Bool

    public init(
        sessionId: String,
        channel: PMCommunicationChannel,
        participantLabel: String? = nil,
        continuitySummary: String,
        topicSignals: [String],
        continuityReason: String,
        sourceMessageIDs: [String],
        latestMessageAt: Date,
        messageCount: Int,
        resumedAfterPause: Bool
    ) {
        self.sessionId = sessionId
        self.channel = channel
        self.participantLabel = participantLabel
        self.continuitySummary = continuitySummary
        self.topicSignals = topicSignals
        self.continuityReason = continuityReason
        self.sourceMessageIDs = sourceMessageIDs
        self.latestMessageAt = latestMessageAt
        self.messageCount = messageCount
        self.resumedAfterPause = resumedAfterPause
    }
}

public struct PMRetrievedInteractionMemory: Sendable, Equatable, Identifiable {
    public var id: String { memoryId }

    public var memoryId: String
    public var kind: PMInteractionMemoryKind
    public var title: String
    public var summary: String
    public var matchedSignals: [String]
    public var sourceCommunicationMessageId: String?
    public var sourceDecisionId: String?
    public var sourceApprovalRequestId: String?
    public var sourceStrategyBriefId: String?
    public var sourceAnalystMemoId: String?
    public var updatedAt: Date

    public init(
        memoryId: String,
        kind: PMInteractionMemoryKind,
        title: String,
        summary: String,
        matchedSignals: [String],
        sourceCommunicationMessageId: String? = nil,
        sourceDecisionId: String? = nil,
        sourceApprovalRequestId: String? = nil,
        sourceStrategyBriefId: String? = nil,
        sourceAnalystMemoId: String? = nil,
        updatedAt: Date
    ) {
        self.memoryId = memoryId
        self.kind = kind
        self.title = title
        self.summary = summary
        self.matchedSignals = matchedSignals
        self.sourceCommunicationMessageId = sourceCommunicationMessageId
        self.sourceDecisionId = sourceDecisionId
        self.sourceApprovalRequestId = sourceApprovalRequestId
        self.sourceStrategyBriefId = sourceStrategyBriefId
        self.sourceAnalystMemoId = sourceAnalystMemoId
        self.updatedAt = updatedAt
    }
}

public struct PMSystemReadinessSummary: Sendable, Equatable {
    public var status: AlwaysOnReadinessStatus
    public var summary: String
    public var detail: String
    public var blockers: [String]
    public var lastLifecycleEvent: HostAvailabilityEvent?
    public var lastRecoveryStartedAt: Date?
    public var lastRecoveryCompletedAt: Date?

    public init(
        readiness: AlwaysOnReadinessState
    ) {
        status = readiness.status
        summary = readiness.summary
        detail = readiness.detail
        blockers = readiness.blockers
        lastLifecycleEvent = readiness.lastLifecycleEvent
        lastRecoveryStartedAt = readiness.lastRecoveryStartedAt
        lastRecoveryCompletedAt = readiness.lastRecoveryCompletedAt
    }
}

public struct PMPortfolioWatchReadinessSummary: Sendable, Equatable {
    public var selectedSymbols: [String]
    public var requestedSelectedSymbols: [String]
    public var activeSelectedSymbols: [String]
    public var pricedSelectedSymbols: [String]
    public var waitingForFirstUpdateSymbols: [String]
    public var activeButNoUsablePriceSymbols: [String]
    public var lastMarketDataReceivedAt: Date?
    public var lastMarketDataReceivedSymbol: String?
    public var marketDataConnectionState: String
    public var marketDataRawUpdateCount: Int
    public var quoteRawUpdateCount: Int
    public var tradeRawUpdateCount: Int
    public var barRawUpdateCount: Int

    public init(
        selectedSymbols: [String],
        requestedSelectedSymbols: [String],
        activeSelectedSymbols: [String],
        pricedSelectedSymbols: [String],
        waitingForFirstUpdateSymbols: [String],
        activeButNoUsablePriceSymbols: [String],
        lastMarketDataReceivedAt: Date?,
        lastMarketDataReceivedSymbol: String?,
        marketDataConnectionState: String,
        marketDataRawUpdateCount: Int,
        quoteRawUpdateCount: Int,
        tradeRawUpdateCount: Int,
        barRawUpdateCount: Int
    ) {
        self.selectedSymbols = selectedSymbols
        self.requestedSelectedSymbols = requestedSelectedSymbols
        self.activeSelectedSymbols = activeSelectedSymbols
        self.pricedSelectedSymbols = pricedSelectedSymbols
        self.waitingForFirstUpdateSymbols = waitingForFirstUpdateSymbols
        self.activeButNoUsablePriceSymbols = activeButNoUsablePriceSymbols
        self.lastMarketDataReceivedAt = lastMarketDataReceivedAt
        self.lastMarketDataReceivedSymbol = lastMarketDataReceivedSymbol
        self.marketDataConnectionState = marketDataConnectionState
        self.marketDataRawUpdateCount = marketDataRawUpdateCount
        self.quoteRawUpdateCount = quoteRawUpdateCount
        self.tradeRawUpdateCount = tradeRawUpdateCount
        self.barRawUpdateCount = barRawUpdateCount
    }

    public static let empty = PMPortfolioWatchReadinessSummary(
        selectedSymbols: [],
        requestedSelectedSymbols: [],
        activeSelectedSymbols: [],
        pricedSelectedSymbols: [],
        waitingForFirstUpdateSymbols: [],
        activeButNoUsablePriceSymbols: [],
        lastMarketDataReceivedAt: nil,
        lastMarketDataReceivedSymbol: nil,
        marketDataConnectionState: MarketDataConnectionState.disconnected.rawValue,
        marketDataRawUpdateCount: 0,
        quoteRawUpdateCount: 0,
        tradeRawUpdateCount: 0,
        barRawUpdateCount: 0
    )
}

public struct PMContextPack: Sendable, Equatable {
    public var pmId: String?
    public var profile: PMProfile?
    public var mandates: [PMMandate]
    public var activeInstructions: [PMInstruction]
    public var recentNotebookEntries: [PMNotebookEntry]
    public var recentConversationContinuity: [PMRecentConversationContinuity]
    public var retrievedInteractionMemories: [PMRetrievedInteractionMemory]
    public var sharedPortfolioTruth: PMSharedPortfolioTruthSummary
    public var portfolioIntelligence: PortfolioIntelligenceSnapshot
    public var portfolioWatchReadiness: PMPortfolioWatchReadinessSummary
    public var openApprovalRequests: [PMApprovalRequest]
    public var recentDecisions: [PMDecisionRecord]
    public var relevantDelegations: [PMDelegationRecord]
    public var recentAnalystMemos: [AnalystMemo]
    public var promotedCommunicationOutcomes: [PMPromotedCommunicationOutcome]
    public var operatingContext: PMOperatingContextSummary
    public var systemReadiness: PMSystemReadinessSummary
    public var boundarySummary: PMContextBoundarySummary
    public var assembledAt: Date

    public init(
        pmId: String?,
        profile: PMProfile?,
        mandates: [PMMandate],
        activeInstructions: [PMInstruction],
        recentNotebookEntries: [PMNotebookEntry],
        recentConversationContinuity: [PMRecentConversationContinuity],
        retrievedInteractionMemories: [PMRetrievedInteractionMemory],
        sharedPortfolioTruth: PMSharedPortfolioTruthSummary,
        portfolioIntelligence: PortfolioIntelligenceSnapshot = .empty(generatedAt: Date(timeIntervalSince1970: 0)),
        portfolioWatchReadiness: PMPortfolioWatchReadinessSummary = .empty,
        openApprovalRequests: [PMApprovalRequest],
        recentDecisions: [PMDecisionRecord],
        relevantDelegations: [PMDelegationRecord],
        recentAnalystMemos: [AnalystMemo],
        promotedCommunicationOutcomes: [PMPromotedCommunicationOutcome],
        operatingContext: PMOperatingContextSummary,
        systemReadiness: PMSystemReadinessSummary,
        boundarySummary: PMContextBoundarySummary,
        assembledAt: Date
    ) {
        self.pmId = pmId
        self.profile = profile
        self.mandates = mandates
        self.activeInstructions = activeInstructions
        self.recentNotebookEntries = recentNotebookEntries
        self.recentConversationContinuity = recentConversationContinuity
        self.retrievedInteractionMemories = retrievedInteractionMemories
        self.sharedPortfolioTruth = sharedPortfolioTruth
        self.portfolioIntelligence = portfolioIntelligence
        self.portfolioWatchReadiness = portfolioWatchReadiness
        self.openApprovalRequests = openApprovalRequests
        self.recentDecisions = recentDecisions
        self.relevantDelegations = relevantDelegations
        self.recentAnalystMemos = recentAnalystMemos
        self.promotedCommunicationOutcomes = promotedCommunicationOutcomes
        self.operatingContext = operatingContext
        self.systemReadiness = systemReadiness
        self.boundarySummary = boundarySummary
        self.assembledAt = assembledAt
    }
}

public func defaultPMContextBoundarySummary() -> PMContextBoundarySummary {
    PMContextBoundarySummary(
        durableMemorySources: [
            "PM profile",
            "PM mandates",
            "Active PM instructions",
            "Recent PM notebook entries",
            "Retrieved interaction memories"
        ],
        recentConversationSources: [
            "Bounded recent-conversation continuity summaries derived from recent PM/User dialogue",
            "Gap-aware resumed-topic continuity may carry forward a recent discussion arc without replaying full transcript history",
            "Short-horizon continuity remains distinct from durable promoted memory"
        ],
        communicationLogSources: [
            "PM communication sessions (log-only by default)",
            "PM communication messages (log-only by default)"
        ],
        analystScopedSources: [
            "Analyst scoped memory",
            "Analyst task checkpoint memory",
            "Standing analyst bench charters"
        ],
        sharedTruthSources: [
            "Current positions",
            "Current open orders",
            "Current watchlist",
            "Portfolio Intelligence Paper/Live exposure, positions, data quality, and advanced-metric readiness",
            "Paper-establishment execution lifecycle status",
            "Portfolio strategy brief"
        ],
        operationalArtifactSources: [
            "PM decisions",
            "PM approval requests",
            "PM delegations",
            "Analyst memos",
            "Standing analyst schedules",
            "Standing reports awaiting PM review"
        ]
    )
}

public func makePMContextPack(
    requestedPMId: String? = nil,
    profiles: [PMProfile],
    mandates: [PMMandate],
    instructions: [PMInstruction],
    notebookEntries: [PMNotebookEntry],
    interactionMemories: [PMInteractionMemoryRecord],
    strategyBrief: PortfolioStrategyBrief?,
    positions: [PositionRow],
    openOrders: [OrderRow] = [],
    watchlistSymbols: [String],
    storeSnapshot: StoreSnapshot? = nil,
    portfolioWatchSelectedSymbols: [String] = [],
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord],
    delegations: [PMDelegationRecord],
    analystMemos: [AnalystMemo],
    analystCharters: [AnalystCharter] = [],
    schedules: [ScheduledJobSummary] = [],
    standingReports: [AnalystStandingReport] = [],
    systemReadiness: AlwaysOnReadinessState = .initial(),
    communicationSessions: [PMCommunicationSession],
    communicationMessages: [PMCommunicationMessage],
    selectionPolicy: PMContextSelectionPolicy = PMContextSelectionPolicy(),
    assembledAt: Date
) -> PMContextPack {
    let resolvedPMID = resolvePMContextPMID(requestedPMId: requestedPMId, profiles: profiles)
    let profile = profiles
        .filter { isExercisePMProfile($0) == false }
        .filter { resolvedPMID == nil || $0.pmId == resolvedPMID }
        .sorted(by: pmProfilesNewestFirst)
        .first

    let filteredMandates = mandates
        .filter { isExercisePMMandate($0) == false }
        .filter { resolvedPMID == nil || $0.pmId == resolvedPMID }
        .sorted(by: pmMandatesNewestFirst)
        .prefix(selectionPolicy.maxMandates)
    let filteredInstructions = instructions
        .filter { isExercisePMInstruction($0) == false }
        .filter { ($0.status == .active) && (resolvedPMID == nil || $0.pmId == resolvedPMID) }
        .sorted(by: pmInstructionsNewestFirst)
        .prefix(selectionPolicy.maxInstructions)
    let filteredNotebookEntries = notebookEntries
        .filter { isExercisePMNotebookEntry($0) == false }
        .filter { resolvedPMID == nil || $0.pmId == resolvedPMID }
        .sorted(by: pmNotebookNewestFirst)
        .prefix(selectionPolicy.maxNotebookEntries)
    let filteredApprovalRequests = approvalRequests
        .filter { isExercisePMApprovalRequest($0) == false }
        .filter { ($0.status == .pending) && (resolvedPMID == nil || $0.pmId == resolvedPMID) }
        .sorted(by: pmApprovalRequestsNewestFirst)
        .prefix(selectionPolicy.maxApprovalRequests)
    let filteredDecisions = decisions
        .filter { isExercisePMDecision($0) == false }
        .filter { ($0.status == .active) && (resolvedPMID == nil || $0.pmId == resolvedPMID) }
        .sorted(by: pmDecisionsNewestFirst)
        .prefix(selectionPolicy.maxDecisions)
    let relevantDelegations = selectRelevantPMDelegations(
        delegations: delegations,
        pmId: resolvedPMID,
        limit: selectionPolicy.maxDelegations
    )
    let delegationIDs = Set(relevantDelegations.map(\.delegationId))
    let decisionDelegationIDs = Set(filteredDecisions.compactMap(\.delegationId))
    let approvalDelegationIDs = Set(filteredApprovalRequests.compactMap(\.delegationId))
    let memoDelegationIDs = delegationIDs.union(decisionDelegationIDs).union(approvalDelegationIDs)

    let filteredMemos = analystMemos
        .filter { memo in
            guard isExerciseAnalystMemo(memo) == false else { return false }
            if let pmId = resolvedPMID, let memoPMID = memo.pmId, memoPMID != pmId {
                return false
            }
            if let delegationId = memo.delegationId, memoDelegationIDs.contains(delegationId) {
                return true
            }
            return resolvedPMID != nil && memo.pmId == resolvedPMID
        }
        .sorted(by: analystMemosNewestFirst)
        .prefix(selectionPolicy.maxMemos)

    let filteredInteractionMemories = retrieveRelevantPMInteractionMemories(
        interactionMemories: interactionMemories,
        pmId: resolvedPMID,
        strategyBrief: strategyBrief,
        positions: positions,
        watchlistSymbols: watchlistSymbols,
        approvalRequests: Array(filteredApprovalRequests),
        decisions: Array(filteredDecisions),
        delegations: relevantDelegations,
        selectionPolicy: selectionPolicy
    )

    let filteredPromotions = makePMPromotedCommunicationOutcomes(
        sessions: communicationSessions,
        messages: communicationMessages,
        notebookEntries: notebookEntries,
        instructions: instructions,
        decisions: decisions,
        approvalRequests: approvalRequests,
        delegations: delegations,
        strategyBrief: strategyBrief,
        pmId: resolvedPMID,
        limit: selectionPolicy.maxPromotedCommunicationOutcomes
    )

    let recentConversationContinuity = makePMRecentConversationContinuity(
        sessions: communicationSessions,
        messages: communicationMessages,
        pmId: resolvedPMID,
        strategyBrief: strategyBrief,
        positions: positions,
        watchlistSymbols: watchlistSymbols,
        approvalRequests: Array(filteredApprovalRequests),
        decisions: Array(filteredDecisions),
        delegations: relevantDelegations,
        selectionPolicy: selectionPolicy,
        assembledAt: assembledAt
    )

    let sharedPortfolioTruth = makePMSharedPortfolioTruthSummary(
        positions: positions,
        openOrders: openOrders,
        watchlistSymbols: watchlistSymbols,
        approvalRequests: approvalRequests.filter { resolvedPMID == nil || $0.pmId == resolvedPMID },
        strategyBrief: strategyBrief,
        selectionPolicy: selectionPolicy
    )
    let portfolioIntelligenceSnapshot = makePortfolioIntelligenceSnapshot(
        snapshot: storeSnapshot ?? StoreSnapshot(
            build: "pm-context",
            positions: positions,
            openOrders: openOrders,
            watchlistSymbols: watchlistSymbols
        ),
        paperEstablishmentExecution: pmContextLatestPaperEstablishmentLifecycleState(
            approvalRequests: approvalRequests.filter { resolvedPMID == nil || $0.pmId == resolvedPMID }
        ),
        generatedAt: assembledAt
    )
    let resolvedStoreSnapshot = storeSnapshot ?? StoreSnapshot(
        build: "pm-context",
        positions: positions,
        openOrders: openOrders,
        watchlistSymbols: watchlistSymbols
    )
    let portfolioWatchReadiness = makePMPortfolioWatchReadinessSummary(
        snapshot: resolvedStoreSnapshot,
        selectedSymbols: portfolioWatchSelectedSymbols
    )

    return PMContextPack(
        pmId: resolvedPMID,
        profile: profile,
        mandates: Array(filteredMandates),
        activeInstructions: Array(filteredInstructions),
        recentNotebookEntries: Array(filteredNotebookEntries),
        recentConversationContinuity: recentConversationContinuity,
        retrievedInteractionMemories: filteredInteractionMemories,
        sharedPortfolioTruth: sharedPortfolioTruth,
        portfolioIntelligence: portfolioIntelligenceSnapshot,
        portfolioWatchReadiness: portfolioWatchReadiness,
        openApprovalRequests: Array(filteredApprovalRequests),
        recentDecisions: Array(filteredDecisions),
        relevantDelegations: relevantDelegations,
        recentAnalystMemos: Array(filteredMemos),
        promotedCommunicationOutcomes: filteredPromotions,
        operatingContext: makePMOperatingContextSummary(
            charters: analystCharters,
            schedules: schedules,
            standingReports: standingReports
        ),
        systemReadiness: PMSystemReadinessSummary(readiness: systemReadiness),
        boundarySummary: defaultPMContextBoundarySummary(),
        assembledAt: assembledAt
    )
}

private func makePMOperatingContextSummary(
    charters: [AnalystCharter],
    schedules: [ScheduledJobSummary],
    standingReports: [AnalystStandingReport]
) -> PMOperatingContextSummary {
    let standingBench = makeStandingAnalystReportSchedulePresentations(
        charters: charters,
        schedules: schedules
    )
    let outstandingReports = standingReports
        .filter {
            isExerciseArtifactIdentifier($0.reportId) == false
                && $0.deliveryStatus == .pendingPMReview
        }
        .sorted { lhs, rhs in
            if lhs.deliveredToPMInboxAt == rhs.deliveredToPMInboxAt {
                return lhs.reportId < rhs.reportId
            }
            return lhs.deliveredToPMInboxAt > rhs.deliveredToPMInboxAt
        }
    let pendingCountsByCharter = Dictionary(
        grouping: outstandingReports,
        by: \.charterId
    ).mapValues(\.count)
    let chartersByID = Dictionary(
        uniqueKeysWithValues: charters.map { ($0.charterId, $0) }
    )

    let standingBenchSummaries = standingBench.map { presentation in
        let charter = chartersByID[presentation.charterId]
        let mandateSummary = pmAnalystMandateSummary(for: charter)
        return PMAnalystBenchMemberSummary(
            charterId: presentation.charterId,
            analystId: presentation.analystId,
            title: presentation.analystTitle,
            benchRole: presentation.benchRole,
            operatingCategory: pmAnalystOperatingCategory(for: charter),
            mandateSummary: mandateSummary,
            coverageScope: presentation.coverageScope,
            adHocTaskingAvailable: true,
            standingSchedule: PMAnalystStandingScheduleSummary(
                enabled: presentation.enabled,
                cadenceSummary: pmStandingCadenceSummary(intervalSec: presentation.intervalSec),
                intervalSec: presentation.intervalSec,
                lastRunAt: presentation.lastRunAt,
                nextRunAt: presentation.nextRunAt,
                lastRunSummary: presentation.lastRunSummary
            ),
            outstandingStandingReviewCount: pendingCountsByCharter[presentation.charterId] ?? 0
        )
    }

    let queueItems = outstandingReports.map { report in
        PMStandingReviewQueueItemSummary(
            reportId: report.reportId,
            analystId: report.analystId,
            charterId: report.charterId,
            analystTitle: chartersByID[report.charterId]?.title ?? report.title,
            reportTitle: report.title,
            headlineView: report.headlineView,
            summary: report.summary,
            deliveredToPMInboxAt: report.deliveredToPMInboxAt
        )
    }
    let analystsAwaitingReview = Array(
        Set(queueItems.map(\.analystTitle))
    ).sorted()

    return PMOperatingContextSummary(
        standingBench: standingBenchSummaries,
        standingEnabledCount: standingBenchSummaries.filter(\.standingSchedule.enabled).count,
        adHocCapableAnalystCount: standingBenchSummaries.filter(\.adHocTaskingAvailable).count,
        standingReviewQueue: PMStandingReviewQueueSummary(
            pendingCount: queueItems.count,
            analystsAwaitingReview: analystsAwaitingReview,
            items: queueItems
        )
    )
}

private func pmAnalystOperatingCategory(for charter: AnalystCharter?) -> PMAnalystOperatingCategory {
    guard let charter else { return .overlay }
    switch charter.charterId {
    case "bench-overlay-macro-international":
        return .macroInternational
    case "bench-overlay-portfolio-risk":
        return .portfolioRisk
    case recentNewsStandingAnalystCharterID:
        return .recentNews
    default:
        return charter.benchRole == .sector ? .sector : .overlay
    }
}

private func pmAnalystMandateSummary(for charter: AnalystCharter?) -> String {
    guard let charter else {
        return "Standing bench analyst available for PM-directed work and recurring review."
    }
    let summary = charter.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    if summary.isEmpty == false {
        return summary
    }
    let coverageScope = charter.coverageScope.trimmingCharacters(in: .whitespacesAndNewlines)
    if coverageScope.isEmpty == false {
        return coverageScope
    }
    let strategyFamily = charter.strategyFamily.trimmingCharacters(in: .whitespacesAndNewlines)
    if strategyFamily.isEmpty == false {
        return strategyFamily
    }
    return "Standing bench analyst available for PM-directed work and recurring review."
}

private func pmStandingCadenceSummary(intervalSec: Int) -> String {
    let hours = max(1, intervalSec / 3_600)
    if intervalSec % (24 * 3_600) == 0 {
        let days = max(1, intervalSec / (24 * 3_600))
        return days == 1 ? "Daily" : "Every \(days) days"
    }
    return hours == 1 ? "Hourly" : "Every \(hours) hours"
}

private func resolvePMContextPMID(requestedPMId: String?, profiles: [PMProfile]) -> String? {
    if let requestedPMId {
        let trimmed = requestedPMId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    return profiles.sorted(by: pmProfilesNewestFirst).first?.pmId
}

private func selectRelevantPMDelegations(
    delegations: [PMDelegationRecord],
    pmId: String?,
    limit: Int
) -> [PMDelegationRecord] {
    let relevant = delegations
        .filter { isExercisePMDelegation($0) == false }
        .filter { pmId == nil || $0.pmId == pmId }
        .sorted(by: pmDelegationsNewestFirst)
    let active = relevant.filter { $0.status == .issued }
    let activeIDs = Set(active.map(\.delegationId))
    let recentCompleted = relevant.filter { !activeIDs.contains($0.delegationId) }
    return Array((active + recentCompleted).prefix(limit))
}

private func makePMSharedPortfolioTruthSummary(
    positions: [PositionRow],
    openOrders: [OrderRow],
    watchlistSymbols: [String],
    approvalRequests: [PMApprovalRequest],
    strategyBrief: PortfolioStrategyBrief?,
    selectionPolicy: PMContextSelectionPolicy
) -> PMSharedPortfolioTruthSummary {
    let topPositions = positions
        .sorted(by: pmPositionsMarketValueDescending)
        .prefix(selectionPolicy.maxTopPositions)
        .map {
            PMContextPositionSummary(
                symbol: $0.symbol,
                directionLabel: $0.directionLabel,
                marketValue: $0.marketValue
            )
        }

    let openOrderPreview = openOrders
        .sorted { lhs, rhs in
            if lhs.symbol == rhs.symbol {
                return lhs.id < rhs.id
            }
            return lhs.symbol < rhs.symbol
        }
        .prefix(selectionPolicy.maxTopPositions)
        .map { row in
            let qty = row.qty.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(row.symbol) \(row.side.uppercased()) \(qty) (\(row.status))"
        }

    let strategySummary = strategyBrief.map {
        PMContextStrategyBriefSummary(
            title: $0.title,
            objectiveSummary: $0.objectiveSummary,
            currentRiskPosture: $0.currentRiskPosture,
            keyThemes: Array($0.keyThemes.prefix(6)),
            updatedBy: $0.updatedBy,
            updateSource: $0.updateSource,
            revisionSummary: $0.revisionSummary,
            updatedAt: $0.updatedAt
        )
    }

    let pendingPaperExecutions = approvalRequests
        .filter { request in
            guard request.status == .resolved,
                  request.ownerResponse == .approved,
                  let pendingState = request.paperPortfolioExecutionPendingState,
                  pendingState.status == .waitingForUsablePrices else {
                return false
            }
            return request.requestType == .portfolioAction
        }
        .sorted(by: pmApprovalRequestsNewestFirst)
        .prefix(selectionPolicy.maxApprovalRequests)
        .map { request in
            let pendingState = request.paperPortfolioExecutionPendingState!
            return PMContextPendingPaperExecutionSummary(
                approvalRequestId: request.approvalRequestId,
                subject: request.subject,
                missingPriceSymbols: pendingState.missingPriceSymbols,
                automaticRetryEnabled: pendingState.automaticRetryEnabled,
                lastBlockerSummary: pendingState.lastBlockerSummary,
                lastBlockerDetail: pendingState.lastBlockerDetail,
                lastRetryAttemptedAt: pendingState.lastRetryAttemptedAt,
                updatedAt: pendingState.updatedAt
            )
        }

    let paperEstablishmentExecutionStatus = makePMPaperEstablishmentExecutionStatusSummary(
        positions: positions,
        openOrders: openOrders,
        approvalRequests: approvalRequests,
        pendingPaperExecutions: Array(pendingPaperExecutions)
    )

    return PMSharedPortfolioTruthSummary(
        positionCount: positions.count,
        openOrderCount: openOrders.count,
        watchlistCount: watchlistSymbols.count,
        topPositions: topPositions,
        openOrderPreview: openOrderPreview,
        watchlistPreview: Array(watchlistSymbols.prefix(selectionPolicy.maxWatchlistPreview)),
        paperEstablishmentExecutionStatus: paperEstablishmentExecutionStatus,
        pendingPaperExecutions: pendingPaperExecutions,
        strategyBrief: strategySummary
    )
}

private func makePMPaperEstablishmentExecutionStatusSummary(
    positions: [PositionRow],
    openOrders: [OrderRow],
    approvalRequests: [PMApprovalRequest],
    pendingPaperExecutions: [PMContextPendingPaperExecutionSummary]
) -> PMContextPaperEstablishmentExecutionStatusSummary? {
    let establishmentRequests = approvalRequests
        .filter { request in
            isExercisePMApprovalRequest(request) == false
                && request.requestType == .portfolioAction
                && pmApprovalRequestAppearsToBePaperPortfolioEstablishment(request)
        }
        .sorted(by: pmApprovalRequestsNewestFirst)

    if let lifecycleRequest = establishmentRequests.first(where: {
        $0.status == .resolved
            && $0.ownerResponse == .approved
            && $0.paperPortfolioExecutionLifecycleState != nil
    }),
       let lifecycleState = lifecycleRequest.paperPortfolioExecutionLifecycleState {
        let state: PMContextPaperEstablishmentExecutionLifecycleState
        switch lifecycleState.status {
        case .waitingForUsablePrices:
            state = .approvedWaitingForUsablePrices
        case .blocked:
            state = .approvedBlocked
        case .ordersAlreadyRecorded:
            state = .ordersOrPositionsRecorded
        case .submitted:
            state = .approvedSubmitted
        case .partiallySubmitted:
            state = .approvedPartiallySubmitted
        case .failed:
            state = .approvedFailed
        }
        let pending = lifecycleRequest.paperPortfolioExecutionPendingState
        return PMContextPaperEstablishmentExecutionStatusSummary(
            state: state,
            approvalRequestId: lifecycleRequest.approvalRequestId,
            subject: lifecycleRequest.subject,
            summary: lifecycleState.summary,
            detail: lifecycleState.detail,
            targetSymbols: lifecycleState.targetSymbols,
            missingPriceSymbols: lifecycleState.missingPriceSymbols,
            blockedReasons: lifecycleState.blockedReasons,
            automaticRetryEnabled: pending?.automaticRetryEnabled ?? false,
            orderPlanStatus: lifecycleState.orderPlanStatus,
            lastBlockerSummary: lifecycleState.summary,
            lastBlockerDetail: lifecycleState.detail,
            lastRouteActionAt: lifecycleState.lastRouteActionAt,
            lastRetryAttemptedAt: lifecycleState.lastRetryAttemptedAt ?? pending?.lastRetryAttemptedAt,
            orderAttemptCount: lifecycleState.orderAttemptCount,
            acceptedOrderAttemptCount: lifecycleState.acceptedOrderAttemptCount,
            failedOrderAttemptCount: lifecycleState.failedOrderAttemptCount,
            updatedAt: lifecycleState.updatedAt
        )
    }

    if positions.isEmpty == false || openOrders.isEmpty == false {
        return PMContextPaperEstablishmentExecutionStatusSummary(
            state: .ordersOrPositionsRecorded,
            summary: "App truth has current holdings or open orders recorded, so paper-establishment status must be read from the Orders Blotter and current holdings instead of assuming no activity."
        )
    }

    if let pending = pendingPaperExecutions.first {
        return PMContextPaperEstablishmentExecutionStatusSummary(
            state: .approvedWaitingForUsablePrices,
            approvalRequestId: pending.approvalRequestId,
            subject: pending.subject,
            summary: "Owner approval is recorded and paper-establishment execution is pending on usable prices before order sizing/submission can retry.",
            missingPriceSymbols: pending.missingPriceSymbols,
            automaticRetryEnabled: pending.automaticRetryEnabled,
            lastBlockerSummary: pending.lastBlockerSummary,
            lastBlockerDetail: pending.lastBlockerDetail,
            lastRetryAttemptedAt: pending.lastRetryAttemptedAt,
            updatedAt: pending.updatedAt
        )
    }

    if let approved = establishmentRequests.first(where: {
        $0.status == .resolved && $0.ownerResponse == .approved
    }) {
        return PMContextPaperEstablishmentExecutionStatusSummary(
            state: .approvedNoActiveExecutionState,
            approvalRequestId: approved.approvalRequestId,
            subject: approved.subject,
            summary: "Owner approval is recorded for paper-establishment, but app truth has no active pending execution/retry state, no open paper-establishment orders, and no current holdings recorded. Alpaca order submission has not been attempted from this visible lifecycle state.",
            updatedAt: approved.updatedAt
        )
    }

    if let pendingApproval = establishmentRequests.first(where: { $0.status == .pending }) {
        return PMContextPaperEstablishmentExecutionStatusSummary(
            state: .approvalPending,
            approvalRequestId: pendingApproval.approvalRequestId,
            subject: pendingApproval.subject,
            summary: "Paper-establishment is still waiting on the surfaced owner approval request before governed execution can run.",
            updatedAt: pendingApproval.updatedAt
        )
    }

    return PMContextPaperEstablishmentExecutionStatusSummary(
        state: .noActiveApproval,
        summary: "No active paper-establishment approval, pending execution state, open order, or holding is recorded in app truth."
    )
}

private func pmApprovalRequestAppearsToBePaperPortfolioEstablishment(_ request: PMApprovalRequest) -> Bool {
    [
        request.subject,
        request.rationale,
        request.requestedActionSummary,
        request.approvedNextStepSummary
    ]
        .compactMap { $0?.lowercased() }
        .contains { value in
            (value.contains("paper") && (
                value.contains("portfolio")
                    || value.contains("establish")
                    || value.contains("establishment")
            ))
                || value.contains("working paper portfolio")
                || value.contains("paper-establishment")
        }
}

private func pmContextLatestPaperEstablishmentLifecycleState(
    approvalRequests: [PMApprovalRequest]
) -> PMPaperPortfolioExecutionLifecycleState? {
    approvalRequests
        .filter { request in
            isExercisePMApprovalRequest(request) == false
                && request.status == .resolved
                && request.ownerResponse == .approved
                && request.requestType == .portfolioAction
                && request.paperPortfolioExecutionLifecycleState != nil
                && pmApprovalRequestAppearsToBePaperPortfolioEstablishment(request)
        }
        .sorted(by: pmApprovalRequestsNewestFirst)
        .first?
        .paperPortfolioExecutionLifecycleState
}

public func makePMContextPortfolioIntelligenceSummaryLines(
    _ intelligence: PortfolioIntelligenceSnapshot
) -> [String] {
    [
        pmContextPortfolioEnvironmentLine(intelligence.paper),
        pmContextPortfolioExposureLine(intelligence.paper),
        pmContextPortfolioPositionsLine(intelligence.paper),
        pmContextPortfolioShortsLine(intelligence.paper),
        pmContextPortfolioDataQualityLine(intelligence.paper),
        pmContextPortfolioAdvancedMetricsLine(intelligence.paper),
        pmContextPortfolioEnvironmentLine(intelligence.live)
    ].filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
}

public func makePMPortfolioWatchReadinessSummary(
    snapshot: StoreSnapshot,
    selectedSymbols: [String] = []
) -> PMPortfolioWatchReadinessSummary {
    let effectiveSelectedSymbols = PortfolioWatchChartWallConfiguration.effectiveSelectedSymbols(
        selectedSymbols: selectedSymbols,
        watchlistSymbols: snapshot.watchlistSymbols
    )
    func isRequested(_ symbol: String) -> Bool {
        snapshot.marketDataDesiredSubscriptions.quotes.contains(symbol)
            || snapshot.marketDataDesiredSubscriptions.trades.contains(symbol)
            || snapshot.marketDataDesiredSubscriptions.bars.contains(symbol)
            || snapshot.marketDataDesiredSubscriptions.optionQuotes.contains(symbol)
            || snapshot.marketDataDesiredSubscriptions.optionTrades.contains(symbol)
            || snapshot.marketDataDesiredSubscriptions.optionBars.contains(symbol)
    }
    func isActive(_ symbol: String) -> Bool {
        snapshot.marketDataSubscriptions.quotes.contains(symbol)
            || snapshot.marketDataSubscriptions.trades.contains(symbol)
            || snapshot.marketDataSubscriptions.bars.contains(symbol)
            || snapshot.marketDataSubscriptions.optionQuotes.contains(symbol)
            || snapshot.marketDataSubscriptions.optionTrades.contains(symbol)
            || snapshot.marketDataSubscriptions.optionBars.contains(symbol)
    }
    func hasUsablePrice(_ symbol: String) -> Bool {
        resolvePortfolioWatchLiveValue(
            from: snapshot.quotesBySymbol[symbol] ?? snapshot.optionQuotesBySymbol[symbol]
        ) != nil
    }

    let requestedSymbols = effectiveSelectedSymbols.filter(isRequested)
    let activeSymbols = effectiveSelectedSymbols.filter(isActive)
    let pricedSymbols = effectiveSelectedSymbols.filter(hasUsablePrice)
    let waitingSymbols = effectiveSelectedSymbols.filter { hasUsablePrice($0) == false }
    let activeButNoPriceSymbols = effectiveSelectedSymbols.filter { isActive($0) && hasUsablePrice($0) == false }
    let counts = snapshot.eventStreamDiagnostics.marketDataRawUpdateCountsByName
    return PMPortfolioWatchReadinessSummary(
        selectedSymbols: effectiveSelectedSymbols,
        requestedSelectedSymbols: requestedSymbols,
        activeSelectedSymbols: activeSymbols,
        pricedSelectedSymbols: pricedSymbols,
        waitingForFirstUpdateSymbols: waitingSymbols,
        activeButNoUsablePriceSymbols: activeButNoPriceSymbols,
        lastMarketDataReceivedAt: snapshot.lastMarketDataReceivedAt,
        lastMarketDataReceivedSymbol: snapshot.lastMarketDataReceivedSymbol,
        marketDataConnectionState: snapshot.marketDataConnectionState,
        marketDataRawUpdateCount: snapshot.eventStreamDiagnostics.marketDataRawUpdateCount,
        quoteRawUpdateCount: counts["market_quote"] ?? 0,
        tradeRawUpdateCount: counts["market_trade"] ?? 0,
        barRawUpdateCount: counts["market_bar"] ?? 0
    )
}

public func makePMContextPortfolioWatchReadinessSummaryLines(
    _ readiness: PMPortfolioWatchReadinessSummary
) -> [String] {
    guard readiness.selectedSymbols.isEmpty == false else {
        return []
    }

    let selected = readiness.selectedSymbols.prefix(16).joined(separator: ", ")
    var lines: [String] = [
        "Portfolio Watch live-data truth: selected \(readiness.selectedSymbols.count) (\(selected)); requested \(readiness.requestedSelectedSymbols.count)/\(readiness.selectedSymbols.count); active subscriptions \(readiness.activeSelectedSymbols.count)/\(readiness.selectedSymbols.count); usable Store prices \(readiness.pricedSelectedSymbols.count)/\(readiness.selectedSymbols.count); market-data connection \(readiness.marketDataConnectionState)."
    ]

    if let receivedAt = readiness.lastMarketDataReceivedAt {
        let symbol = readiness.lastMarketDataReceivedSymbol ?? "unknown"
        lines.append(
            "Portfolio Watch last usable Store market-data receipt: \(DateCodec.formatISO8601(receivedAt)) for \(symbol); raw updates \(readiness.marketDataRawUpdateCount) (quotes \(readiness.quoteRawUpdateCount), trades \(readiness.tradeRawUpdateCount), bars \(readiness.barRawUpdateCount))."
        )
    } else {
        lines.append(
            "Portfolio Watch last usable Store market-data receipt: none in this app session; raw updates \(readiness.marketDataRawUpdateCount)."
        )
    }

    if readiness.waitingForFirstUpdateSymbols.isEmpty == false {
        lines.append(
            "Portfolio Watch first-update caveat: selected symbols still waiting for usable quote/trade/bar truth: \(readiness.waitingForFirstUpdateSymbols.prefix(16).joined(separator: ", "))."
        )
    }

    if readiness.activeButNoUsablePriceSymbols.isEmpty == false {
        lines.append(
            "Portfolio Watch data-quality caveat: active subscription acknowledgement is not the same as a usable Store price; active-but-no-usable-price symbols: \(readiness.activeButNoUsablePriceSymbols.prefix(16).joined(separator: ", "))."
        )
    }

    return lines
}

private func pmContextPortfolioEnvironmentLine(
    _ summary: PortfolioEnvironmentSummary
) -> String {
    guard summary.availability == .active else {
        return "\(summary.environment.displayTitle) Intelligence: unavailable. \(summary.statusSummary)"
    }

    let equity = pmContextPortfolioCurrency(summary.account?.equity) ?? "unavailable"
    let cash = pmContextPortfolioCurrency(summary.account?.cash) ?? "unavailable"
    let buyingPower = pmContextPortfolioCurrency(summary.account?.buyingPower) ?? "unavailable"
    return "\(summary.environment.displayTitle) Intelligence: active; equity \(equity); cash \(cash); buying power \(buyingPower); positions \(summary.positions.count); open orders \(summary.orderActivity.openOrderCount)."
}

private func pmContextPortfolioExposureLine(
    _ summary: PortfolioEnvironmentSummary
) -> String {
    guard summary.availability == .active else { return "" }
    let exposure = summary.exposure
    let largest = exposure.largestPositionSymbol.map { symbol in
        "largest \(symbol) \(pmContextPortfolioPercent(exposure.largestPositionWeight) ?? "weight unavailable")"
    } ?? "largest unavailable"
    let topThree = pmContextPortfolioPercent(exposure.topThreeConcentration) ?? "unavailable"
    return "\(summary.environment.displayTitle) exposure: long \(pmContextPortfolioCurrency(exposure.longMarketValue) ?? "unavailable") (\(pmContextPortfolioPercent(exposure.longWeight) ?? "weight unavailable")); short \(pmContextPortfolioCurrency(exposure.shortMarketValue) ?? "unavailable") (\(pmContextPortfolioPercent(exposure.shortWeight) ?? "weight unavailable")); gross \(pmContextPortfolioCurrency(exposure.grossExposure) ?? "unavailable"); net \(pmContextPortfolioCurrency(exposure.netExposure) ?? "unavailable"); cash weight \(pmContextPortfolioPercent(exposure.cashWeight) ?? "unavailable"); \(largest); top 3 concentration \(topThree)."
}

private func pmContextPortfolioPositionsLine(
    _ summary: PortfolioEnvironmentSummary
) -> String {
    guard summary.availability == .active else { return "" }
    guard summary.positions.isEmpty == false else {
        return "\(summary.environment.displayTitle) holdings: none recorded."
    }
    let positions = summary.positions.prefix(20).map { position in
        "\(position.symbol) \(position.side.rawValue.uppercased()) qty \(pmContextPortfolioQuantity(position.quantity)); signed MV \(pmContextPortfolioCurrency(position.marketValueSigned) ?? "unavailable"); weight \(pmContextPortfolioPercent(position.absoluteWeight) ?? "unavailable"); price \(pmContextPortfolioPrice(position.latestPrice) ?? "unavailable"); \(position.dataQualitySummary)"
    }
    return "\(summary.environment.displayTitle) holdings from Portfolio Intelligence: \(positions.joined(separator: "; "))."
}

private func pmContextPortfolioShortsLine(
    _ summary: PortfolioEnvironmentSummary
) -> String {
    guard summary.availability == .active else { return "" }
    let shorts = summary.positions.filter { $0.side == .short }
    guard shorts.isEmpty == false else {
        return "\(summary.environment.displayTitle) shorts from Portfolio Intelligence: none recorded."
    }
    let items = shorts.map { position in
        "\(position.symbol) qty \(pmContextPortfolioQuantity(position.quantity)); signed MV \(pmContextPortfolioCurrency(position.marketValueSigned) ?? "unavailable"); absolute weight \(pmContextPortfolioPercent(position.absoluteWeight) ?? "unavailable")"
    }
    return "\(summary.environment.displayTitle) shorts from Portfolio Intelligence: \(items.joined(separator: "; "))."
}

private func pmContextPortfolioDataQualityLine(
    _ summary: PortfolioEnvironmentSummary
) -> String {
    guard summary.availability == .active else { return "" }
    var components = [
        "\(summary.environment.displayTitle) data quality: \(summary.dataQuality.summary)",
        "priced \(summary.dataQuality.pricedPositionCount)/\(summary.dataQuality.positionCount)"
    ]
    if summary.dataQuality.missingPriceSymbols.isEmpty == false {
        components.append("missing prices \(summary.dataQuality.missingPriceSymbols.joined(separator: ", "))")
    }
    if summary.dataQuality.stalePriceSymbols.isEmpty == false {
        components.append("stale prices \(summary.dataQuality.stalePriceSymbols.joined(separator: ", "))")
    }
    return components.joined(separator: "; ") + "."
}

private func pmContextPortfolioAdvancedMetricsLine(
    _ summary: PortfolioEnvironmentSummary
) -> String {
    let examples = summary.advancedMetricReadiness.items.prefix(4).map { item in
        "\(item.metric.displayTitle): \(item.status.rawValue) (\(item.reason))"
    }
    return "\(summary.environment.displayTitle) advanced metrics readiness: \(summary.advancedMetricReadiness.summary) Examples: \(examples.joined(separator: "; "))."
}

private func pmContextPortfolioCurrency(_ value: Double?) -> String? {
    guard let value, value.isFinite else { return nil }
    let absoluteValue = abs(value)
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = absoluteValue >= 1_000 ? 0 : 2
    formatter.minimumFractionDigits = 0
    formatter.locale = Locale(identifier: "en_US_POSIX")
    guard let formatted = formatter.string(from: NSNumber(value: absoluteValue)) else {
        return nil
    }
    return "\(value < 0 ? "-" : "")$\(formatted)"
}

private func pmContextPortfolioPercent(_ value: Double?) -> String? {
    guard let value, value.isFinite else { return nil }
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: NSNumber(value: value))
}

private func pmContextPortfolioQuantity(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "unavailable" }
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(format: "%.4f", value)
}

private func pmContextPortfolioPrice(_ value: Double?) -> String? {
    guard let value, value.isFinite else { return nil }
    return String(format: "$%.2f", value)
}

private func makePMPromotedCommunicationOutcomes(
    sessions: [PMCommunicationSession],
    messages: [PMCommunicationMessage],
    notebookEntries: [PMNotebookEntry],
    instructions: [PMInstruction],
    decisions: [PMDecisionRecord],
    approvalRequests: [PMApprovalRequest],
    delegations: [PMDelegationRecord],
    strategyBrief: PortfolioStrategyBrief?,
    pmId: String?,
    limit: Int
) -> [PMPromotedCommunicationOutcome] {
    let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.sessionId, $0) })
    let notebookByID = Dictionary(uniqueKeysWithValues: notebookEntries.map { ($0.entryId, $0) })
    let instructionsByID = Dictionary(uniqueKeysWithValues: instructions.map { ($0.instructionId, $0) })
    let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.decisionId, $0) })
    let approvalsByID = Dictionary(uniqueKeysWithValues: approvalRequests.map { ($0.approvalRequestId, $0) })
    let delegationsByID = Dictionary(uniqueKeysWithValues: delegations.map { ($0.delegationId, $0) })

    return messages
        .filter { message in
            guard isExercisePMCommunicationMessage(message) == false else { return false }
            guard message.promotion != nil else { return false }
            guard let session = sessionsByID[message.sessionId] else { return false }
            guard isExercisePMCommunicationSession(session) == false else { return false }
            if let pmId {
                let sessionMatches = session.pmId == nil || session.pmId == pmId
                let promotedTargetMatches: Bool
                switch message.promotion?.targetType {
                case .notebookEntry:
                    promotedTargetMatches = notebookByID[message.promotion?.targetId ?? ""]?.pmId == pmId
                case .instruction:
                    promotedTargetMatches = instructionsByID[message.promotion?.targetId ?? ""]?.pmId == pmId
                case .decision:
                    promotedTargetMatches = decisionsByID[message.promotion?.targetId ?? ""]?.pmId == pmId
                case .approvalRequest:
                    promotedTargetMatches = approvalsByID[message.promotion?.targetId ?? ""]?.pmId == pmId
                case .delegation:
                    promotedTargetMatches = delegationsByID[message.promotion?.targetId ?? ""]?.pmId == pmId
                case .strategyBrief:
                    promotedTargetMatches = strategyBrief?.briefId == message.promotion?.targetId
                case .none:
                    promotedTargetMatches = false
                }
                return sessionMatches || promotedTargetMatches
            }
            return true
        }
        .compactMap { message -> PMPromotedCommunicationOutcome? in
            guard
                let promotion = message.promotion,
                let session = sessionsByID[message.sessionId]
            else {
                return nil
            }

            let resolved = resolvePromotionTargetSummary(
                promotion: promotion,
                notebookByID: notebookByID,
                instructionsByID: instructionsByID,
                decisionsByID: decisionsByID,
                approvalsByID: approvalsByID,
                delegationsByID: delegationsByID,
                strategyBrief: strategyBrief
            )

            return PMPromotedCommunicationOutcome(
                messageId: message.messageId,
                sessionId: message.sessionId,
                channel: session.channel,
                participantLabel: session.participantDisplayName ?? session.participantId,
                senderRole: message.senderRole,
                promotedAt: promotion.promotedAt,
                targetType: promotion.targetType,
                targetId: promotion.targetId,
                targetTitle: resolved.title,
                targetSummary: resolved.summary,
                targetExcerpt: resolved.excerpt,
                originSummary: makePMPromotionOriginSummary(session: session, senderRole: message.senderRole)
            )
        }
        .sorted { lhs, rhs in
            if lhs.promotedAt == rhs.promotedAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.promotedAt > rhs.promotedAt
        }
        .prefix(limit)
        .map { $0 }
}

private func resolvePromotionTargetSummary(
    promotion: PMCommunicationPromotion,
    notebookByID: [String: PMNotebookEntry],
    instructionsByID: [String: PMInstruction],
    decisionsByID: [String: PMDecisionRecord],
    approvalsByID: [String: PMApprovalRequest],
    delegationsByID: [String: PMDelegationRecord],
    strategyBrief: PortfolioStrategyBrief?
) -> (title: String, summary: String, excerpt: String) {
    switch promotion.targetType {
    case .notebookEntry:
        if let note = notebookByID[promotion.targetId] {
            let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let source = note.sourceSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let excerptSource = body.isEmpty ? source : body
            return (
                note.title,
                boundedPMContextText(source.isEmpty ? excerptSource : source),
                boundedPMContextText(excerptSource, maxLength: 360)
            )
        }
    case .instruction:
        if let instruction = instructionsByID[promotion.targetId] {
            return (
                instruction.title,
                boundedPMContextText(instruction.body),
                boundedPMContextText(instruction.body, maxLength: 320)
            )
        }
    case .decision:
        if let decision = decisionsByID[promotion.targetId] {
            return (
                decision.title,
                boundedPMContextText(decision.summary),
                boundedPMContextText(decision.summary, maxLength: 320)
            )
        }
    case .approvalRequest:
        if let request = approvalsByID[promotion.targetId] {
            return (
                request.subject,
                boundedPMContextText(request.rationale),
                boundedPMContextText(request.rationale, maxLength: 320)
            )
        }
    case .delegation:
        if let delegation = delegationsByID[promotion.targetId] {
            return (
                delegation.title,
                boundedPMContextText(delegation.rationale),
                boundedPMContextText(delegation.rationale, maxLength: 320)
            )
        }
    case .strategyBrief:
        if let strategyBrief, strategyBrief.briefId == promotion.targetId {
            return (
                strategyBrief.title,
                boundedPMContextText(
                    strategyBrief.revisionSummary
                        ?? strategyBrief.objectiveSummary
                ),
                boundedPMContextText(strategyBrief.primaryDocumentBody, maxLength: 360)
            )
        }
    }

    return (
        "Promoted \(promotion.targetType.rawValue)",
        "Promoted target remains linked as an app-owned record.",
        "Promoted target remains linked as an app-owned record."
    )
}

private struct PMRecentConversationSelection {
    var continuity: PMRecentConversationContinuity
    var score: Int
}

private struct PMContextRelevanceSignals {
    var symbols: Set<String>
    var themes: Set<String>
    var riskPostures: Set<String>
    var recommendationTypes: Set<String>
    var ownerResponsePatterns: Set<PMApprovalRequestOwnerResponse>
    var activeDecisionIDs: Set<String>
    var activeApprovalRequestIDs: Set<String>
    var currentStrategyBriefID: String?
}

private struct PMInteractionMemoryMatch {
    var score: Int
    var signals: [String]
}

private func makePMRecentConversationContinuity(
    sessions: [PMCommunicationSession],
    messages: [PMCommunicationMessage],
    pmId: String?,
    strategyBrief: PortfolioStrategyBrief?,
    positions: [PositionRow],
    watchlistSymbols: [String],
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord],
    delegations: [PMDelegationRecord],
    selectionPolicy: PMContextSelectionPolicy,
    assembledAt: Date
) -> [PMRecentConversationContinuity] {
    let signals = makePMContextRelevanceSignals(
        strategyBrief: strategyBrief,
        positions: positions,
        watchlistSymbols: watchlistSymbols,
        approvalRequests: approvalRequests,
        decisions: decisions,
        delegations: delegations
    )
    let messagesBySession = Dictionary(grouping: messages) { $0.sessionId }

    return sessions
        .filter { isExercisePMCommunicationSession($0) == false }
        .filter { pmId == nil || $0.pmId == nil || $0.pmId == pmId }
        .compactMap { session -> PMRecentConversationSelection? in
            let sessionMessages = (messagesBySession[session.sessionId] ?? [])
                .filter { isExercisePMCommunicationMessage($0) == false }
            return summarizePMRecentConversationSession(
                session: session,
                messages: sessionMessages,
                signals: signals,
                selectionPolicy: selectionPolicy,
                assembledAt: assembledAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                if lhs.continuity.latestMessageAt == rhs.continuity.latestMessageAt {
                    return lhs.continuity.sessionId < rhs.continuity.sessionId
                }
                return lhs.continuity.latestMessageAt > rhs.continuity.latestMessageAt
            }
            return lhs.score > rhs.score
        }
        .prefix(selectionPolicy.maxRecentConversationThreads)
        .map(\.continuity)
}

private func summarizePMRecentConversationSession(
    session: PMCommunicationSession,
    messages: [PMCommunicationMessage],
    signals: PMContextRelevanceSignals,
    selectionPolicy: PMContextSelectionPolicy,
    assembledAt: Date
) -> PMRecentConversationSelection? {
    guard messages.isEmpty == false else { return nil }

    let sortedMessages = messages.sorted { lhs, rhs in
        if lhs.sentAt == rhs.sentAt {
            return lhs.messageId < rhs.messageId
        }
        return lhs.sentAt < rhs.sentAt
    }

    guard let latestMessage = sortedMessages.last else { return nil }
    let latestAge = assembledAt.timeIntervalSince(latestMessage.sentAt)
    guard latestAge <= pmConversationExtendedWindow else { return nil }

    let selectedMessages = selectPMRecentConversationMessages(
        from: sortedMessages,
        maxMessages: selectionPolicy.maxRecentConversationMessagesPerThread
    )
    guard selectedMessages.isEmpty == false else { return nil }

    let resumedAfterPause = pmRecentConversationHasPause(selectedMessages)
    let topicSignals = makePMConversationTopicSignals(messages: selectedMessages, signals: signals)
    let continuitySummary = makePMConversationContinuitySummary(messages: selectedMessages)
    guard continuitySummary.isEmpty == false else { return nil }

    let continuityReason: String
    if resumedAfterPause {
        continuityReason = "Resumed recent topic after a pause because the latest discussion reused the same topic cues."
    } else if selectedMessages.count >= 4 {
        continuityReason = "Active recent PM/User back-and-forth."
    } else {
        continuityReason = "Latest recent PM/User thread."
    }

    let score = scorePMRecentConversationSelection(
        latestAge: latestAge,
        messageCount: selectedMessages.count,
        resumedAfterPause: resumedAfterPause,
        topicSignals: topicSignals
    )
    guard score > 0 else { return nil }

    return PMRecentConversationSelection(
        continuity: PMRecentConversationContinuity(
            sessionId: session.sessionId,
            channel: session.channel,
            participantLabel: session.participantDisplayName ?? session.participantId,
            continuitySummary: continuitySummary,
            topicSignals: topicSignals,
            continuityReason: continuityReason,
            sourceMessageIDs: selectedMessages.map(\.messageId),
            latestMessageAt: latestMessage.sentAt,
            messageCount: selectedMessages.count,
            resumedAfterPause: resumedAfterPause
        ),
        score: score
    )
}

private func selectPMRecentConversationMessages(
    from messages: [PMCommunicationMessage],
    maxMessages: Int
) -> [PMCommunicationMessage] {
    guard let latestMessage = messages.last else { return [] }

    var selected: [PMCommunicationMessage] = [latestMessage]
    var topicTokens = pmConversationTopicTokens(in: latestMessage.body)
    var selectedIDs = Set([latestMessage.messageId])
    var earliestSelected = latestMessage

    for candidate in messages.dropLast().reversed() {
        guard selected.count < maxMessages else { break }

        let ageFromLatest = latestMessage.sentAt.timeIntervalSince(candidate.sentAt)
        if ageFromLatest > pmConversationExtendedWindow {
            break
        }

        let candidateTokens = pmConversationTopicTokens(in: candidate.body)
        let topicOverlap = topicTokens.intersection(candidateTokens)
        let replyLinked = candidate.replyToMessageId.map(selectedIDs.contains(_:)) == true
            || earliestSelected.replyToMessageId == candidate.messageId
        let closeGap = earliestSelected.sentAt.timeIntervalSince(candidate.sentAt) <= pmConversationDenseGapWindow
        let recentWindow = ageFromLatest <= pmConversationBaseWindow
        let include = replyLinked || (topicOverlap.isEmpty == false && ageFromLatest <= pmConversationExtendedWindow) || (closeGap && recentWindow)

        guard include else {
            if ageFromLatest > pmConversationBaseWindow {
                break
            }
            continue
        }

        selected.insert(candidate, at: 0)
        selectedIDs.insert(candidate.messageId)
        earliestSelected = candidate
        topicTokens.formUnion(candidateTokens)
    }

    return selected
}

private func scorePMRecentConversationSelection(
    latestAge: TimeInterval,
    messageCount: Int,
    resumedAfterPause: Bool,
    topicSignals: [String]
) -> Int {
    var score = 0

    switch latestAge {
    case ..<pmConversationDenseGapWindow:
        score += 5
    case ..<pmConversationBaseWindow:
        score += 4
    case ..<pmConversationResumeWindow:
        score += 3
    case ..<pmConversationExtendedWindow:
        score += 2
    default:
        break
    }

    score += min(messageCount, 4)
    if resumedAfterPause {
        score += 2
    }
    score += min(topicSignals.count, 3)
    return score
}

private func makePMConversationContinuitySummary(messages: [PMCommunicationMessage]) -> String {
    let latestOwnerMessage = messages.last(where: { $0.senderRole == .owner })
    let latestPMMessage = messages.last(where: { $0.senderRole == .pm })

    if let owner = latestOwnerMessage, let pm = latestPMMessage, pm.sentAt >= owner.sentAt {
        return "Owner last focused on \(boundedPMContextText(owner.body, maxLength: 110)). PM last replied: \(boundedPMContextText(pm.body, maxLength: 110))"
    }
    if let owner = latestOwnerMessage {
        return "Owner recently focused on \(boundedPMContextText(owner.body, maxLength: 140))"
    }
    if let pm = latestPMMessage {
        return "PM recently carried forward \(boundedPMContextText(pm.body, maxLength: 140))"
    }
    if let latest = messages.last {
        return boundedPMContextText(latest.body, maxLength: 140)
    }
    return ""
}

private func makePMConversationTopicSignals(
    messages: [PMCommunicationMessage],
    signals: PMContextRelevanceSignals
) -> [String] {
    var labels: [String] = []
    let combinedText = messages.map(\.body).joined(separator: " ")
    let uppercaseSymbols = pmConversationSymbolCandidates(in: combinedText)
        .intersection(signals.symbols)
        .sorted()
    if uppercaseSymbols.isEmpty == false {
        labels.append("Symbols: \(uppercaseSymbols.prefix(3).joined(separator: ", "))")
    }

    let messageTokens = Set(pmConversationTopicTokens(in: combinedText))
    let themeMatches = messageTokens.intersection(signals.themes).sorted()
    if themeMatches.isEmpty == false {
        labels.append("Themes: \(themeMatches.prefix(3).joined(separator: ", "))")
    }

    let recommendationMatches = messages
        .map(\.body)
        .flatMap(pmTokenizeRelevanceText(_:))
        .filter { token in
            signals.recommendationTypes.contains(token) || signals.recommendationTypes.contains(token.replacingOccurrences(of: " ", with: "_"))
        }
    if recommendationMatches.isEmpty == false {
        labels.append("Workflow type still active")
    }

    if labels.isEmpty {
        let fallback = Array(messageTokens.subtracting(pmConversationStopwords).sorted().prefix(3))
        if fallback.isEmpty == false {
            labels.append("Topics: \(fallback.joined(separator: ", "))")
        }
    }

    return labels
}

private func retrieveRelevantPMInteractionMemories(
    interactionMemories: [PMInteractionMemoryRecord],
    pmId: String?,
    strategyBrief: PortfolioStrategyBrief?,
    positions: [PositionRow],
    watchlistSymbols: [String],
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord],
    delegations: [PMDelegationRecord],
    selectionPolicy: PMContextSelectionPolicy
) -> [PMRetrievedInteractionMemory] {
    let signals = makePMContextRelevanceSignals(
        strategyBrief: strategyBrief,
        positions: positions,
        watchlistSymbols: watchlistSymbols,
        approvalRequests: approvalRequests,
        decisions: decisions,
        delegations: delegations
    )

    return interactionMemories
        .filter { isExercisePMInteractionMemory($0) == false }
        .filter { $0.status == .active }
        .filter { pmId == nil || $0.pmId == pmId }
        .compactMap { memory -> (PMInteractionMemoryRecord, PMInteractionMemoryMatch)? in
            let match = matchPMInteractionMemory(memory, signals: signals)
            guard match.score > 0 else { return nil }
            return (memory, match)
        }
        .sorted { lhs, rhs in
            if lhs.1.score == rhs.1.score {
                if lhs.0.updatedAt == rhs.0.updatedAt {
                    return lhs.0.memoryId < rhs.0.memoryId
                }
                return lhs.0.updatedAt > rhs.0.updatedAt
            }
            return lhs.1.score > rhs.1.score
        }
        .prefix(selectionPolicy.maxRetrievedInteractionMemories)
        .map { memory, match in
            PMRetrievedInteractionMemory(
                memoryId: memory.memoryId,
                kind: memory.kind,
                title: memory.title,
                summary: boundedPMContextText(memory.summary, maxLength: 260),
                matchedSignals: match.signals,
                sourceCommunicationMessageId: memory.sourceCommunicationMessageId,
                sourceDecisionId: memory.sourceDecisionId,
                sourceApprovalRequestId: memory.sourceApprovalRequestId,
                sourceStrategyBriefId: memory.sourceStrategyBriefId,
                sourceAnalystMemoId: memory.sourceAnalystMemoId,
                updatedAt: memory.updatedAt
            )
        }
}

private func makePMContextRelevanceSignals(
    strategyBrief: PortfolioStrategyBrief?,
    positions: [PositionRow],
    watchlistSymbols: [String],
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord],
    delegations: [PMDelegationRecord]
) -> PMContextRelevanceSignals {
    let positionSymbols = positions.map { $0.symbol.uppercased() }
    let watchSymbols = watchlistSymbols.map { $0.uppercased() }
    let delegationText = delegations.flatMap { [$0.title, $0.rationale] }

    return PMContextRelevanceSignals(
        symbols: Set(positionSymbols + watchSymbols),
        themes: Set(
            strategyBrief?.keyThemes.map(pmNormalizedRelevanceToken(_:)) ?? []
        ).union(
            delegationText
                .flatMap(pmTokenizeRelevanceText(_:))
        ),
        riskPostures: Set(
            [strategyBrief?.currentRiskPosture]
                .compactMap { $0 }
                .map(pmNormalizedRelevanceToken(_:))
                .filter { $0.isEmpty == false }
        ),
        recommendationTypes: Set(
            approvalRequests.map { $0.requestType.rawValue } + decisions.map { $0.decisionType.rawValue }
        ),
        ownerResponsePatterns: Set(approvalRequests.compactMap(\.ownerResponse)),
        activeDecisionIDs: Set(decisions.map(\.decisionId)),
        activeApprovalRequestIDs: Set(approvalRequests.map(\.approvalRequestId)),
        currentStrategyBriefID: strategyBrief?.briefId
    )
}

private func matchPMInteractionMemory(
    _ memory: PMInteractionMemoryRecord,
    signals: PMContextRelevanceSignals
) -> PMInteractionMemoryMatch {
    var score = 0
    var matchedSignals: [String] = []

    switch memory.kind {
    case .ownerPreference, .reviewPreference, .operatingPreference:
        score += 1
        matchedSignals.append("Standing \(memory.kind.displayTitle.lowercased())")
    case .decisionPattern, .recurringConcern:
        break
    }

    let symbolOverlap = Set(memory.symbols.map { $0.uppercased() }).intersection(signals.symbols)
    if symbolOverlap.isEmpty == false {
        score += 4
        matchedSignals.append("Symbols: \(symbolOverlap.sorted().prefix(3).joined(separator: ", "))")
    }

    let themeOverlap = Set(memory.themes.map(pmNormalizedRelevanceToken(_:))).intersection(signals.themes)
    if themeOverlap.isEmpty == false {
        score += 3
        matchedSignals.append("Themes: \(themeOverlap.sorted().prefix(3).joined(separator: ", "))")
    }

    let riskOverlap = Set(memory.riskPostures.map(pmNormalizedRelevanceToken(_:))).intersection(signals.riskPostures)
    if riskOverlap.isEmpty == false {
        score += 2
        matchedSignals.append("Risk posture aligned")
    }

    let recommendationOverlap = Set(memory.recommendationTypes).intersection(signals.recommendationTypes)
    if recommendationOverlap.isEmpty == false {
        score += 2
        matchedSignals.append("Recommendation type aligned")
    }

    let responseOverlap = Set(memory.ownerResponsePatterns).intersection(signals.ownerResponsePatterns)
    if responseOverlap.isEmpty == false {
        score += 1
        matchedSignals.append("Owner response pattern aligned")
    }

    if let sourceDecisionId = memory.sourceDecisionId, signals.activeDecisionIDs.contains(sourceDecisionId) {
        score += 2
        matchedSignals.append("Linked active decision")
    }

    if let sourceApprovalRequestId = memory.sourceApprovalRequestId, signals.activeApprovalRequestIDs.contains(sourceApprovalRequestId) {
        score += 2
        matchedSignals.append("Linked open approval")
    }

    if let sourceStrategyBriefId = memory.sourceStrategyBriefId,
       sourceStrategyBriefId == signals.currentStrategyBriefID {
        score += 1
        matchedSignals.append("Linked current strategy brief")
    }

    return PMInteractionMemoryMatch(
        score: score,
        signals: Array(matchedSignals.prefix(4))
    )
}

private let pmConversationDenseGapWindow: TimeInterval = 2 * 24 * 60 * 60
private let pmConversationPauseThreshold: TimeInterval = 5 * 24 * 60 * 60
private let pmConversationBaseWindow: TimeInterval = 30 * 24 * 60 * 60
private let pmConversationResumeWindow: TimeInterval = 60 * 24 * 60 * 60
private let pmConversationExtendedWindow: TimeInterval = 120 * 24 * 60 * 60
private let pmConversationStopwords: Set<String> = [
    "about", "after", "again", "also", "and", "around", "are", "before", "bring", "carry", "could",
    "does", "for", "from", "have", "into", "keep", "last", "let", "lets", "more", "need", "next",
    "not", "our", "owner", "please", "pm", "recent", "review", "should", "still", "than", "that",
    "the", "their", "them", "then", "they", "this", "what", "will", "with", "would", "your"
]

private func pmRecentConversationHasPause(_ messages: [PMCommunicationMessage]) -> Bool {
    guard messages.count >= 2 else { return false }
    for index in 1..<messages.count {
        let older = messages[index - 1]
        let newer = messages[index]
        if newer.sentAt.timeIntervalSince(older.sentAt) > pmConversationPauseThreshold {
            return true
        }
    }
    return false
}

private func pmNormalizedRelevanceToken(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func pmTokenizeRelevanceText(_ value: String) -> [String] {
    pmNormalizedRelevanceToken(value)
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { $0.count >= 3 }
}

private func pmConversationTopicTokens(in value: String) -> Set<String> {
    Set(
        pmTokenizeRelevanceText(value)
            .filter { pmConversationStopwords.contains($0) == false }
            .prefix(12)
    )
}

private func pmConversationSymbolCandidates(in value: String) -> Set<String> {
    let tokens = value
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { token in
            let upper = token.uppercased()
            return upper == token && token.count >= 2 && token.count <= 5 && token.allSatisfy(\.isLetter)
        }
        .map { $0.uppercased() }
    return Set(tokens)
}

private func isExercisePMProfile(_ profile: PMProfile) -> Bool {
    isExerciseArtifactIdentifier(profile.pmId) || profile.pmId == "pm-operational-exercise"
}

private func isExercisePMMandate(_ mandate: PMMandate) -> Bool {
    isExerciseArtifactIdentifier(mandate.mandateId)
        || isExerciseArtifactIdentifier(mandate.pmId)
        || mandate.pmId == "pm-operational-exercise"
}

private func isExercisePMInstruction(_ instruction: PMInstruction) -> Bool {
    isExerciseArtifactIdentifier(instruction.instructionId)
        || isExerciseArtifactIdentifier(instruction.pmId)
        || instruction.pmId == "pm-operational-exercise"
}

private func isExercisePMNotebookEntry(_ entry: PMNotebookEntry) -> Bool {
    isExerciseArtifactIdentifier(entry.entryId)
        || isExerciseArtifactIdentifier(entry.pmId)
        || entry.pmId == "pm-operational-exercise"
}

private func isExercisePMInteractionMemory(_ memory: PMInteractionMemoryRecord) -> Bool {
    isExerciseArtifactIdentifier(memory.memoryId)
        || isExerciseArtifactIdentifier(memory.pmId)
        || memory.pmId == "pm-operational-exercise"
        || memory.sourceCommunicationMessageId.map(isExerciseArtifactIdentifier(_:)) == true
        || memory.sourceDecisionId.map(isExerciseArtifactIdentifier(_:)) == true
        || memory.sourceApprovalRequestId.map(isExerciseArtifactIdentifier(_:)) == true
        || memory.sourceAnalystMemoId.map(isExerciseArtifactIdentifier(_:)) == true
}

private func isExerciseAnalystMemo(_ memo: AnalystMemo) -> Bool {
    isExerciseArtifactIdentifier(memo.memoId)
        || memo.delegationId.map(isExerciseArtifactIdentifier(_:)) == true
        || memo.pmId.map(isExerciseArtifactIdentifier(_:)) == true
        || memo.pmId == "pm-operational-exercise"
        || memo.taskId.map(isExerciseArtifactIdentifier(_:)) == true
}

private func makePMPromotionOriginSummary(
    session: PMCommunicationSession,
    senderRole: PMCommunicationSenderRole
) -> String {
    let participant = session.participantDisplayName ?? session.participantId ?? "participant"
    return "Promoted from \(senderRole.rawValue) communication on \(session.channel.rawValue) with \(participant)."
}

private func boundedPMContextText(_ text: String, maxLength: Int = 140) -> String {
    let collapsed = text
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard collapsed.count > maxLength else { return collapsed }
    let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
    return String(collapsed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
}

private func pmProfilesNewestFirst(lhs: PMProfile, rhs: PMProfile) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.pmId < rhs.pmId }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmMandatesNewestFirst(lhs: PMMandate, rhs: PMMandate) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.mandateId < rhs.mandateId }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmInstructionsNewestFirst(lhs: PMInstruction, rhs: PMInstruction) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.instructionId < rhs.instructionId }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmNotebookNewestFirst(lhs: PMNotebookEntry, rhs: PMNotebookEntry) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.entryId < rhs.entryId }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmApprovalRequestsNewestFirst(lhs: PMApprovalRequest, rhs: PMApprovalRequest) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.approvalRequestId < rhs.approvalRequestId }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmDecisionsNewestFirst(lhs: PMDecisionRecord, rhs: PMDecisionRecord) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.decisionId < rhs.decisionId }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmDelegationsNewestFirst(lhs: PMDelegationRecord, rhs: PMDelegationRecord) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.delegationId < rhs.delegationId }
    return lhs.updatedAt > rhs.updatedAt
}

private func analystMemosNewestFirst(lhs: AnalystMemo, rhs: AnalystMemo) -> Bool {
    if lhs.updatedAt == rhs.updatedAt { return lhs.memoId < rhs.memoId }
    return lhs.updatedAt > rhs.updatedAt
}

private func pmPositionsMarketValueDescending(lhs: PositionRow, rhs: PositionRow) -> Bool {
    let lhsValue = absolutePMMarketValue(lhs.marketValue)
    let rhsValue = absolutePMMarketValue(rhs.marketValue)
    if lhsValue == rhsValue { return lhs.symbol < rhs.symbol }
    return lhsValue > rhsValue
}

private func absolutePMMarketValue(_ raw: String) -> Decimal {
    let allowed = raw.filter { $0.isNumber || $0 == "." || $0 == "-" }
    let decimal = Decimal(string: allowed, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    return decimal < 0 ? -decimal : decimal
}
