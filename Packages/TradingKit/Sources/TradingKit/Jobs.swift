import Foundation

public enum JobType: String, Sendable, Codable, CaseIterable {
    case monitor
    case replayBatch = "replay_batch"
    case rssPoll = "rss_poll"
    case newsRetention = "news_retention"
    case analystSignals = "analyst_signals"
    case standingAnalystReport = "standing_analyst_report"
    case recentNewsAnalyst = "recent_news_analyst"
    case portfolioRiskAnalyst = "portfolio_risk_analyst"
    case maintenanceRetention = "maintenance_retention"

    public static let operationalScheduleControllableCases: [JobType] = [
        .monitor,
        .replayBatch,
        .rssPoll,
        .newsRetention,
        .analystSignals,
        .standingAnalystReport,
        .recentNewsAnalyst,
        .portfolioRiskAnalyst
    ]
}

public enum JobStatus: String, Sendable, Codable, CaseIterable {
    case queued
    case running
    case succeeded
    case failed
    case canceled
}

public struct JobErrorInfo: Sendable, Codable, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct JobRecord: Sendable, Codable, Equatable, Identifiable {
    public var id: String {
        jobId
    }

    public var jobId: String
    public var type: JobType
    public var createdAt: Date
    public var updatedAt: Date
    public var status: JobStatus
    public var progress: Double?
    public var message: String?
    public var parameters: [String: JSONValue]
    public var result: JSONValue?
    public var error: JobErrorInfo?
    public var proposalId: String?
    public var runId: String?

    public init(
        jobId: String = UUID().uuidString,
        type: JobType,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: JobStatus = .queued,
        progress: Double? = nil,
        message: String? = nil,
        parameters: [String: JSONValue] = [:],
        result: JSONValue? = nil,
        error: JobErrorInfo? = nil,
        proposalId: String? = nil,
        runId: String? = nil
    ) {
        self.jobId = jobId
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.progress = progress
        self.message = message
        self.parameters = parameters
        self.result = result
        self.error = error
        self.proposalId = proposalId
        self.runId = runId
    }
}

public struct JobSummary: Sendable, Codable, Equatable, Identifiable {
    public var id: String {
        jobId
    }

    public let jobId: String
    public let type: JobType
    public let status: JobStatus
    public let createdAt: Date
    public let updatedAt: Date
    public let progress: Double?
    public let message: String?
    public let proposalId: String?
    public let runId: String?

    public init(
        jobId: String,
        type: JobType,
        status: JobStatus,
        createdAt: Date,
        updatedAt: Date,
        progress: Double?,
        message: String?,
        proposalId: String?,
        runId: String?
    ) {
        self.jobId = jobId
        self.type = type
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.progress = progress
        self.message = message
        self.proposalId = proposalId
        self.runId = runId
    }
}

public struct JobSummaryProjectionDiagnostics: Sendable, Codable, Equatable {
    public var visibleCap: Int
    public var visibleCount: Int
    public var totalJobsCount: Int
    public var listRequestCount: Int
    public var cacheHitCount: Int
    public var fullScanCount: Int
    public var incrementalUpdateCount: Int
    public var lastScannedCount: Int
    public var lastOutputCount: Int
    public var jobProgressPersistCount: Int

    public init(
        visibleCap: Int = 0,
        visibleCount: Int = 0,
        totalJobsCount: Int = 0,
        listRequestCount: Int = 0,
        cacheHitCount: Int = 0,
        fullScanCount: Int = 0,
        incrementalUpdateCount: Int = 0,
        lastScannedCount: Int = 0,
        lastOutputCount: Int = 0,
        jobProgressPersistCount: Int = 0
    ) {
        self.visibleCap = visibleCap
        self.visibleCount = visibleCount
        self.totalJobsCount = totalJobsCount
        self.listRequestCount = listRequestCount
        self.cacheHitCount = cacheHitCount
        self.fullScanCount = fullScanCount
        self.incrementalUpdateCount = incrementalUpdateCount
        self.lastScannedCount = lastScannedCount
        self.lastOutputCount = lastOutputCount
        self.jobProgressPersistCount = jobProgressPersistCount
    }
}

public struct JobTelemetryCleanupResult: Sendable, Codable, Equatable {
    public var dryRun: Bool
    public var cutoff: Date
    public var rootsScanned: [String]
    public var scannedCount: Int
    public var eligibleCount: Int
    public var protectedCount: Int
    public var skippedDecodeErrorCount: Int
    public var skippedLinkedProtectedCount: Int
    public var estimatedBytesReclaimable: Int64
    public var appliedCount: Int
    public var appliedBytes: Int64
    public var candidateCountByStatus: [String: Int]
    public var candidateCountByType: [String: Int]
    public var oldestCandidateTimestamp: Date?
    public var newestCandidateTimestamp: Date?
    public var safetyExclusions: [String]
    public var errors: [String]

    public init(
        dryRun: Bool,
        cutoff: Date,
        rootsScanned: [String],
        scannedCount: Int = 0,
        eligibleCount: Int = 0,
        protectedCount: Int = 0,
        skippedDecodeErrorCount: Int = 0,
        skippedLinkedProtectedCount: Int = 0,
        estimatedBytesReclaimable: Int64 = 0,
        appliedCount: Int = 0,
        appliedBytes: Int64 = 0,
        candidateCountByStatus: [String: Int] = [:],
        candidateCountByType: [String: Int] = [:],
        oldestCandidateTimestamp: Date? = nil,
        newestCandidateTimestamp: Date? = nil,
        safetyExclusions: [String] = [],
        errors: [String] = []
    ) {
        self.dryRun = dryRun
        self.cutoff = cutoff
        self.rootsScanned = rootsScanned
        self.scannedCount = max(0, scannedCount)
        self.eligibleCount = max(0, eligibleCount)
        self.protectedCount = max(0, protectedCount)
        self.skippedDecodeErrorCount = max(0, skippedDecodeErrorCount)
        self.skippedLinkedProtectedCount = max(0, skippedLinkedProtectedCount)
        self.estimatedBytesReclaimable = max(0, estimatedBytesReclaimable)
        self.appliedCount = max(0, appliedCount)
        self.appliedBytes = max(0, appliedBytes)
        self.candidateCountByStatus = candidateCountByStatus
        self.candidateCountByType = candidateCountByType
        self.oldestCandidateTimestamp = oldestCandidateTimestamp
        self.newestCandidateTimestamp = newestCandidateTimestamp
        self.safetyExclusions = safetyExclusions
        self.errors = errors
    }
}

public extension JobRecord {
    var summary: JobSummary {
        JobSummary(
            jobId: jobId,
            type: type,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            progress: progress,
            message: message,
            proposalId: proposalId,
            runId: runId
        )
    }
}

public enum JobStoreError: Error, Sendable, Equatable {
    case jobNotFound(id: String)
}

public enum JobRunnerError: Error, Sendable, Equatable {
    case unsupportedJobType(String)
    case invalidParameters(message: String)

    public var code: String {
        switch self {
        case .unsupportedJobType:
            return "job_unsupported_type"
        case .invalidParameters:
            return "job_invalid_parameters"
        }
    }

    public var message: String {
        switch self {
        case .unsupportedJobType(let raw):
            return "Unsupported job type: \(raw)"
        case .invalidParameters(let message):
            return message
        }
    }
}

public struct JobNotification: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public let timestamp: String
    public let source: String
    public let message: String
    public let jobId: String?
    public let symbol: String?
    public let score: Double?

    public init(
        id: String = UUID().uuidString,
        timestamp: String,
        source: String,
        message: String,
        jobId: String? = nil,
        symbol: String? = nil,
        score: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.message = message
        self.jobId = jobId
        self.symbol = symbol
        self.score = score
    }
}
