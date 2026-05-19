import Foundation

public enum PaperRunStatus: String, Sendable, Codable, Equatable {
    case running
    case stopped
    case error
    case aborted
}

public struct PaperRunMetrics: Sendable, Codable, Equatable {
    public var orderIntentsSubmitted: Int
    public var ordersAccepted: Int
    public var ordersRejected: Int
    public var cancelsSubmitted: Int
    public var replacesSubmitted: Int
    public var fillsCount: Int
    public var partialFillsCount: Int
    public var totalFilledQty: Decimal
    public var symbolsTraded: [String]
    public var riskBlocks: Int
    public var barsProcessed: Int
    public var lastUpdatedAt: Date
    public var realizedPnL: Decimal?
    public var unrealizedPnL: Decimal?
    public var netPnL: Decimal?
    public var startingCash: Decimal?
    public var endingCash: Decimal?
    public var startingEquity: Decimal?
    public var endingEquity: Decimal?

    public init(
        orderIntentsSubmitted: Int = 0,
        ordersAccepted: Int = 0,
        ordersRejected: Int = 0,
        cancelsSubmitted: Int = 0,
        replacesSubmitted: Int = 0,
        fillsCount: Int = 0,
        partialFillsCount: Int = 0,
        totalFilledQty: Decimal = 0,
        symbolsTraded: [String] = [],
        riskBlocks: Int = 0,
        barsProcessed: Int = 0,
        lastUpdatedAt: Date = Date(),
        realizedPnL: Decimal? = nil,
        unrealizedPnL: Decimal? = nil,
        netPnL: Decimal? = nil,
        startingCash: Decimal? = nil,
        endingCash: Decimal? = nil,
        startingEquity: Decimal? = nil,
        endingEquity: Decimal? = nil
    ) {
        self.orderIntentsSubmitted = orderIntentsSubmitted
        self.ordersAccepted = ordersAccepted
        self.ordersRejected = ordersRejected
        self.cancelsSubmitted = cancelsSubmitted
        self.replacesSubmitted = replacesSubmitted
        self.fillsCount = fillsCount
        self.partialFillsCount = partialFillsCount
        self.totalFilledQty = totalFilledQty
        self.symbolsTraded = symbolsTraded
        self.riskBlocks = riskBlocks
        self.barsProcessed = barsProcessed
        self.lastUpdatedAt = lastUpdatedAt
        self.realizedPnL = realizedPnL
        self.unrealizedPnL = unrealizedPnL
        self.netPnL = netPnL
        self.startingCash = startingCash
        self.endingCash = endingCash
        self.startingEquity = startingEquity
        self.endingEquity = endingEquity
    }

    private enum CodingKeys: String, CodingKey {
        case orderIntentsSubmitted
        case ordersAccepted
        case ordersRejected
        case cancelsSubmitted
        case replacesSubmitted
        case fillsCount
        case partialFillsCount
        case totalFilledQty
        case symbolsTraded
        case riskBlocks
        case barsProcessed
        case lastUpdatedAt
        case realizedPnL
        case unrealizedPnL
        case netPnL
        case startingCash
        case endingCash
        case startingEquity
        case endingEquity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orderIntentsSubmitted = try container.decodeIfPresent(Int.self, forKey: .orderIntentsSubmitted) ?? 0
        self.ordersAccepted = try container.decodeIfPresent(Int.self, forKey: .ordersAccepted) ?? 0
        self.ordersRejected = try container.decodeIfPresent(Int.self, forKey: .ordersRejected) ?? 0
        self.cancelsSubmitted = try container.decodeIfPresent(Int.self, forKey: .cancelsSubmitted) ?? 0
        self.replacesSubmitted = try container.decodeIfPresent(Int.self, forKey: .replacesSubmitted) ?? 0
        self.fillsCount = try container.decodeIfPresent(Int.self, forKey: .fillsCount) ?? 0
        self.partialFillsCount = try container.decodeIfPresent(Int.self, forKey: .partialFillsCount) ?? 0
        self.totalFilledQty = try container.decodeIfPresent(Decimal.self, forKey: .totalFilledQty) ?? 0
        self.symbolsTraded = try container.decodeIfPresent([String].self, forKey: .symbolsTraded) ?? []
        self.riskBlocks = try container.decodeIfPresent(Int.self, forKey: .riskBlocks) ?? 0
        self.barsProcessed = try container.decodeIfPresent(Int.self, forKey: .barsProcessed) ?? 0
        self.lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? Date()
        self.realizedPnL = try container.decodeIfPresent(Decimal.self, forKey: .realizedPnL)
        self.unrealizedPnL = try container.decodeIfPresent(Decimal.self, forKey: .unrealizedPnL)
        self.netPnL = try container.decodeIfPresent(Decimal.self, forKey: .netPnL)
        self.startingCash = try container.decodeIfPresent(Decimal.self, forKey: .startingCash)
        self.endingCash = try container.decodeIfPresent(Decimal.self, forKey: .endingCash)
        self.startingEquity = try container.decodeIfPresent(Decimal.self, forKey: .startingEquity)
        self.endingEquity = try container.decodeIfPresent(Decimal.self, forKey: .endingEquity)
    }
}

public struct PaperRunRecord: Sendable, Codable, Equatable, Identifiable {
    public var id: String { runId }

    public var runId: String
    public var proposalId: String
    public var strategyId: String
    public var startedAt: Date
    public var endedAt: Date?
    public var status: PaperRunStatus
    public var stopReason: String?
    public var runType: ReplayRunType
    public var environment: Environment
    public var dataSource: ReplayDataSource?
    public var replaySimulation: ReplaySimulationMetadata?
    public var parametersSnapshot: [String: JSONValue]
    public var constraintsSnapshot: StrategyProposalConstraints
    public var metrics: PaperRunMetrics

    public init(
        runId: String = UUID().uuidString,
        proposalId: String,
        strategyId: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: PaperRunStatus = .running,
        stopReason: String? = nil,
        runType: ReplayRunType = .paper,
        environment: Environment = .paper,
        dataSource: ReplayDataSource? = nil,
        replaySimulation: ReplaySimulationMetadata? = nil,
        parametersSnapshot: [String: JSONValue],
        constraintsSnapshot: StrategyProposalConstraints,
        metrics: PaperRunMetrics = PaperRunMetrics()
    ) {
        self.runId = runId
        self.proposalId = proposalId
        self.strategyId = strategyId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.stopReason = stopReason
        self.runType = runType
        self.environment = environment
        self.dataSource = dataSource
        self.replaySimulation = replaySimulation
        self.parametersSnapshot = parametersSnapshot
        self.constraintsSnapshot = constraintsSnapshot
        self.metrics = metrics
    }

    private enum CodingKeys: String, CodingKey {
        case runId
        case proposalId
        case strategyId
        case startedAt
        case endedAt
        case status
        case stopReason
        case runType
        case environment
        case dataSource
        case replaySimulation
        case parametersSnapshot
        case constraintsSnapshot
        case metrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.runId = try container.decode(String.self, forKey: .runId)
        self.proposalId = try container.decode(String.self, forKey: .proposalId)
        self.strategyId = try container.decode(String.self, forKey: .strategyId)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.status = try container.decode(PaperRunStatus.self, forKey: .status)
        self.stopReason = try container.decodeIfPresent(String.self, forKey: .stopReason)
        self.runType = try container.decodeIfPresent(ReplayRunType.self, forKey: .runType) ?? .paper
        self.environment = try container.decode(Environment.self, forKey: .environment)
        self.dataSource = try container.decodeIfPresent(ReplayDataSource.self, forKey: .dataSource)
        self.replaySimulation = try container.decodeIfPresent(ReplaySimulationMetadata.self, forKey: .replaySimulation)
        self.parametersSnapshot = try container.decode([String: JSONValue].self, forKey: .parametersSnapshot)
        self.constraintsSnapshot = try container.decode(StrategyProposalConstraints.self, forKey: .constraintsSnapshot)
        self.metrics = try container.decode(PaperRunMetrics.self, forKey: .metrics)
    }
}

public struct PaperRunRecordSummary: Sendable, Codable, Equatable, Identifiable {
    public var id: String { runId }

    public var runId: String
    public var proposalId: String
    public var strategyId: String
    public var startedAt: Date
    public var endedAt: Date?
    public var status: PaperRunStatus
    public var runType: ReplayRunType
    public var fillsCount: Int
    public var barsProcessed: Int
    public var ordersAccepted: Int
    public var riskBlocks: Int
    public var netPnL: Decimal?

    public init(
        runId: String,
        proposalId: String,
        strategyId: String,
        startedAt: Date,
        endedAt: Date?,
        status: PaperRunStatus,
        runType: ReplayRunType,
        fillsCount: Int,
        barsProcessed: Int,
        ordersAccepted: Int,
        riskBlocks: Int,
        netPnL: Decimal?
    ) {
        self.runId = runId
        self.proposalId = proposalId
        self.strategyId = strategyId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.runType = runType
        self.fillsCount = fillsCount
        self.barsProcessed = barsProcessed
        self.ordersAccepted = ordersAccepted
        self.riskBlocks = riskBlocks
        self.netPnL = netPnL
    }
}

public extension PaperRunRecord {
    var summary: PaperRunRecordSummary {
        PaperRunRecordSummary(
            runId: runId,
            proposalId: proposalId,
            strategyId: strategyId,
            startedAt: startedAt,
            endedAt: endedAt,
            status: status,
            runType: runType,
            fillsCount: metrics.fillsCount,
            barsProcessed: metrics.barsProcessed,
            ordersAccepted: metrics.ordersAccepted,
            riskBlocks: metrics.riskBlocks,
            netPnL: metrics.netPnL
        )
    }
}
