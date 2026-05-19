import Foundation

public struct RetentionPolicy: Sendable, Codable, Equatable {
    public struct Audit: Sendable, Codable, Equatable {
        public var rotateWhenMB: Int
        public var keepDays: Int

        public init(rotateWhenMB: Int = 25, keepDays: Int = 30) {
            self.rotateWhenMB = max(1, rotateWhenMB)
            self.keepDays = max(1, keepDays)
        }
    }

    public struct News: Sendable, Codable, Equatable {
        public var keepDays: Int

        public init(keepDays: Int = 30) {
            self.keepDays = max(1, keepDays)
        }
    }

    public struct Jobs: Sendable, Codable, Equatable {
        public var keepDaysCompleted: Int
        public var keepMaxCompletedCount: Int?

        public init(keepDaysCompleted: Int = 14, keepMaxCompletedCount: Int? = 500) {
            self.keepDaysCompleted = max(1, keepDaysCompleted)
            self.keepMaxCompletedCount = keepMaxCompletedCount.map { max(1, $0) }
        }
    }

    public struct Runs: Sendable, Codable, Equatable {
        public var enabled: Bool
        public var keepDays: Int

        public init(enabled: Bool = false, keepDays: Int = 3650) {
            self.enabled = enabled
            self.keepDays = max(1, keepDays)
        }
    }

    public struct BarsCache: Sendable, Codable, Equatable {
        public var enabled: Bool
        public var maxDBMB: Int?

        public init(enabled: Bool = false, maxDBMB: Int? = nil) {
            self.enabled = enabled
            self.maxDBMB = maxDBMB.map { max(1, $0) }
        }
    }

    public var audit: Audit
    public var news: News
    public var jobs: Jobs
    public var runs: Runs
    public var barsCache: BarsCache

    public init(
        audit: Audit = Audit(),
        news: News = News(),
        jobs: Jobs = Jobs(),
        runs: Runs = Runs(),
        barsCache: BarsCache = BarsCache()
    ) {
        self.audit = audit
        self.news = news
        self.jobs = jobs
        self.runs = runs
        self.barsCache = barsCache
    }

    public static var `default`: RetentionPolicy {
        RetentionPolicy()
    }

    public func normalized() -> RetentionPolicy {
        RetentionPolicy(
            audit: Audit(
                rotateWhenMB: max(1, audit.rotateWhenMB),
                keepDays: max(1, audit.keepDays)
            ),
            news: News(keepDays: max(1, news.keepDays)),
            jobs: Jobs(
                keepDaysCompleted: max(1, jobs.keepDaysCompleted),
                keepMaxCompletedCount: jobs.keepMaxCompletedCount.map { max(1, $0) }
            ),
            runs: Runs(
                enabled: runs.enabled,
                keepDays: max(1, runs.keepDays)
            ),
            barsCache: BarsCache(
                enabled: barsCache.enabled,
                maxDBMB: barsCache.maxDBMB.map { max(1, $0) }
            )
        )
    }
}

public struct StorageFootprintSummary: Sendable, Codable, Equatable {
    public var rootPath: String
    public var auditBytes: Int64
    public var newsBytes: Int64
    public var jobsBytes: Int64
    public var runsBytes: Int64
    public var barsCacheBytes: Int64
    public var capturedAt: Date

    public init(
        rootPath: String,
        auditBytes: Int64,
        newsBytes: Int64,
        jobsBytes: Int64,
        runsBytes: Int64,
        barsCacheBytes: Int64,
        capturedAt: Date
    ) {
        self.rootPath = rootPath
        self.auditBytes = max(0, auditBytes)
        self.newsBytes = max(0, newsBytes)
        self.jobsBytes = max(0, jobsBytes)
        self.runsBytes = max(0, runsBytes)
        self.barsCacheBytes = max(0, barsCacheBytes)
        self.capturedAt = capturedAt
    }

    public var totalBytes: Int64 {
        auditBytes + newsBytes + jobsBytes + runsBytes + barsCacheBytes
    }
}

public struct MaintenanceAreaResult: Sendable, Codable, Equatable {
    public var area: String
    public var scannedCount: Int
    public var deletedCount: Int
    public var bytesFreed: Int64
    public var dryRun: Bool
    public var errors: [String]
    public var details: JSONValue?

    public init(
        area: String,
        scannedCount: Int,
        deletedCount: Int,
        bytesFreed: Int64,
        dryRun: Bool,
        errors: [String] = [],
        details: JSONValue? = nil
    ) {
        self.area = area
        self.scannedCount = max(0, scannedCount)
        self.deletedCount = max(0, deletedCount)
        self.bytesFreed = max(0, bytesFreed)
        self.dryRun = dryRun
        self.errors = errors
        self.details = details
    }
}

public struct RetentionSweepResult: Sendable, Codable, Equatable {
    public var scannedCount: Int
    public var deletedCount: Int
    public var bytesFreed: Int64

    public init(
        scannedCount: Int = 0,
        deletedCount: Int = 0,
        bytesFreed: Int64 = 0
    ) {
        self.scannedCount = max(0, scannedCount)
        self.deletedCount = max(0, deletedCount)
        self.bytesFreed = max(0, bytesFreed)
    }
}

public struct MaintenanceRunSummary: Sendable, Codable, Equatable {
    public var dryRun: Bool
    public var startedAt: Date
    public var finishedAt: Date
    public var policy: RetentionPolicy
    public var areas: [MaintenanceAreaResult]

    public init(
        dryRun: Bool,
        startedAt: Date,
        finishedAt: Date,
        policy: RetentionPolicy,
        areas: [MaintenanceAreaResult]
    ) {
        self.dryRun = dryRun
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.policy = policy
        self.areas = areas
    }

    public var totalBytesFreed: Int64 {
        areas.reduce(Int64(0)) { $0 + max(0, $1.bytesFreed) }
    }

    public var hasErrors: Bool {
        areas.contains { !$0.errors.isEmpty }
    }

    public var compactSummaryLine: String {
        let deleted = areas.reduce(0) { $0 + $1.deletedCount }
        let steps = areas.map { "\($0.area):\($0.deletedCount)" }.joined(separator: ",")
        let mode = dryRun ? "dry_run" : "apply"
        return "maintenance \(mode) deleted=\(deleted) bytes_freed=\(totalBytesFreed) steps=[\(steps)]"
    }
}

public extension StorageFootprintSummary {
    static func empty(rootPath: String, now: Date) -> StorageFootprintSummary {
        StorageFootprintSummary(
            rootPath: rootPath,
            auditBytes: 0,
            newsBytes: 0,
            jobsBytes: 0,
            runsBytes: 0,
            barsCacheBytes: 0,
            capturedAt: now
        )
    }
}
