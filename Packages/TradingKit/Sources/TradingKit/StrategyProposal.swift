import Foundation

public enum StrategyProposalStatus: String, Sendable, Codable, CaseIterable {
    case draft
    case proposed
    case approvedPaper
    case deniedPaper
}

public struct StrategyProposalScope: Sendable, Codable, Equatable {
    public var symbols: [String]?
    public var watchlistReference: String?

    public init(
        symbols: [String]? = nil,
        watchlistReference: String? = nil
    ) {
        self.symbols = symbols
        self.watchlistReference = watchlistReference
    }
}

public struct StrategyProposalConstraints: Sendable, Codable, Equatable {
    public var maxOrdersPerMinute: Int
    public var maxNotionalPerOrder: Decimal
    public var maxDailyNotional: Decimal?
    public var allowShort: Bool?
    public var allowOptions: Bool?

    public init(
        maxOrdersPerMinute: Int,
        maxNotionalPerOrder: Decimal,
        maxDailyNotional: Decimal? = nil,
        allowShort: Bool? = nil,
        allowOptions: Bool? = nil
    ) {
        self.maxOrdersPerMinute = maxOrdersPerMinute
        self.maxNotionalPerOrder = maxNotionalPerOrder
        self.maxDailyNotional = maxDailyNotional
        self.allowShort = allowShort
        self.allowOptions = allowOptions
    }
}

public struct StrategyProposalTestPlan: Sendable, Codable, Equatable {
    public var durationMinutes: Int
    public var successMetrics: [String]
    public var stopConditions: [String]

    public init(
        durationMinutes: Int,
        successMetrics: [String],
        stopConditions: [String]
    ) {
        self.durationMinutes = durationMinutes
        self.successMetrics = successMetrics
        self.stopConditions = stopConditions
    }
}

public struct StrategyProposalApproval: Sendable, Codable, Equatable {
    public var status: StrategyProposalStatus
    public var reviewedBy: String?
    public var reviewedAt: Date?
    public var reviewNotes: String?

    public init(
        status: StrategyProposalStatus = .draft,
        reviewedBy: String? = nil,
        reviewedAt: Date? = nil,
        reviewNotes: String? = nil
    ) {
        self.status = status
        self.reviewedBy = reviewedBy
        self.reviewedAt = reviewedAt
        self.reviewNotes = reviewNotes
    }
}

public struct StrategyProposalRunResult: Sendable, Codable, Equatable {
    public var lastRunAt: Date?
    public var lastRunStatus: String?

    public init(
        lastRunAt: Date? = nil,
        lastRunStatus: String? = nil
    ) {
        self.lastRunAt = lastRunAt
        self.lastRunStatus = lastRunStatus
    }
}

public struct AnalystProposalLineage: Sendable, Codable, Equatable {
    public var analystId: String?
    public var charterId: String?
    public var taskId: String?
    public var originatingFindingId: String?
    public var sourceEvidenceBundleId: String?

    public init(
        analystId: String? = nil,
        charterId: String? = nil,
        taskId: String? = nil,
        originatingFindingId: String? = nil,
        sourceEvidenceBundleId: String? = nil
    ) {
        self.analystId = analystId
        self.charterId = charterId
        self.taskId = taskId
        self.originatingFindingId = originatingFindingId
        self.sourceEvidenceBundleId = sourceEvidenceBundleId
    }
}

public struct StrategyProposal: Sendable, Codable, Equatable, Identifiable {
    public var id: String {
        proposalId
    }

    public var proposalId: String
    public var createdAt: Date
    public var updatedAt: Date
    public var createdBy: String
    public var title: String
    public var summary: String
    public var strategyId: String
    public var parameters: [String: JSONValue]
    public var scope: StrategyProposalScope
    public var intendedEnvironmentPaperOnly: Bool
    public var constraints: StrategyProposalConstraints
    public var testPlan: StrategyProposalTestPlan
    public var rationale: String
    public var metadata: [String: JSONValue]
    public var originatingSignalId: String?
    public var analystLineage: AnalystProposalLineage?
    public var approval: StrategyProposalApproval
    public var runResult: StrategyProposalRunResult?

    public init(
        proposalId: String = UUID().uuidString,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String,
        title: String,
        summary: String,
        strategyId: String,
        parameters: [String: JSONValue],
        scope: StrategyProposalScope = StrategyProposalScope(),
        intendedEnvironmentPaperOnly: Bool = true,
        constraints: StrategyProposalConstraints,
        testPlan: StrategyProposalTestPlan,
        rationale: String,
        metadata: [String: JSONValue] = [:],
        originatingSignalId: String? = nil,
        analystLineage: AnalystProposalLineage? = nil,
        approval: StrategyProposalApproval = StrategyProposalApproval(),
        runResult: StrategyProposalRunResult? = nil
    ) {
        self.proposalId = proposalId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.title = title
        self.summary = summary
        self.strategyId = strategyId
        self.parameters = parameters
        self.scope = scope
        self.intendedEnvironmentPaperOnly = intendedEnvironmentPaperOnly
        self.constraints = constraints
        self.testPlan = testPlan
        self.rationale = rationale
        self.metadata = metadata
        self.originatingSignalId = originatingSignalId
        self.analystLineage = analystLineage
        self.approval = approval
        self.runResult = runResult
    }
}

public struct ProposalRow: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let status: StrategyProposalStatus
    public let updatedAt: Date
    public let strategyId: String
    public let createdBy: String

    public init(
        id: String,
        title: String,
        status: StrategyProposalStatus,
        updatedAt: Date,
        strategyId: String,
        createdBy: String
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.updatedAt = updatedAt
        self.strategyId = strategyId
        self.createdBy = createdBy
    }
}

public extension StrategyProposal {
    var proposalRow: ProposalRow {
        ProposalRow(
            id: proposalId,
            title: title,
            status: approval.status,
            updatedAt: updatedAt,
            strategyId: strategyId,
            createdBy: createdBy
        )
    }

    var isAnalystOriginated: Bool {
        analystLineage != nil
    }
}
