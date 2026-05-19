import Foundation

public enum ScheduleRunMode: String, Sendable, Codable, CaseIterable {
    case alwaysOn = "always_on"
    case periodic
}

public enum PeriodicScheduleStartupBehavior: String, Sendable, Codable, CaseIterable {
    case waitForInterval = "wait_for_interval"
    case runImmediately = "run_immediately"
}

public enum ScheduleLastRunStatus: String, Sendable, Codable, CaseIterable {
    case succeeded
    case failed
    case canceled
}

public struct ScheduledJobTrigger: Sendable, Codable, Equatable {
    public var intervalSec: Int

    public init(intervalSec: Int) {
        self.intervalSec = max(1, intervalSec)
    }
}

public struct ScheduledJobPolicy: Sendable, Codable, Equatable {
    public var runMode: ScheduleRunMode
    public var restartOnAppLaunch: Bool
    public var maxRuntimeSec: Int?
    public var allowOverlap: Bool
    public var startupBehavior: PeriodicScheduleStartupBehavior

    private enum CodingKeys: String, CodingKey {
        case runMode
        case restartOnAppLaunch
        case maxRuntimeSec
        case allowOverlap
        case startupBehavior
    }

    public init(
        runMode: ScheduleRunMode = .periodic,
        restartOnAppLaunch: Bool = true,
        maxRuntimeSec: Int? = nil,
        allowOverlap: Bool = false,
        startupBehavior: PeriodicScheduleStartupBehavior = .waitForInterval
    ) {
        self.runMode = runMode
        self.restartOnAppLaunch = restartOnAppLaunch
        self.maxRuntimeSec = maxRuntimeSec.map { max(1, $0) }
        self.allowOverlap = allowOverlap
        self.startupBehavior = startupBehavior
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runMode = try container.decodeIfPresent(ScheduleRunMode.self, forKey: .runMode) ?? .periodic
        restartOnAppLaunch = try container.decodeIfPresent(Bool.self, forKey: .restartOnAppLaunch) ?? true
        maxRuntimeSec = try container.decodeIfPresent(Int.self, forKey: .maxRuntimeSec).map { max(1, $0) }
        allowOverlap = try container.decodeIfPresent(Bool.self, forKey: .allowOverlap) ?? false
        startupBehavior = try container.decodeIfPresent(
            PeriodicScheduleStartupBehavior.self,
            forKey: .startupBehavior
        ) ?? .waitForInterval
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runMode, forKey: .runMode)
        try container.encode(restartOnAppLaunch, forKey: .restartOnAppLaunch)
        try container.encodeIfPresent(maxRuntimeSec, forKey: .maxRuntimeSec)
        try container.encode(allowOverlap, forKey: .allowOverlap)
        try container.encode(startupBehavior, forKey: .startupBehavior)
    }
}

public struct ScheduledJob: Sendable, Codable, Equatable, Identifiable {
    public var id: String { scheduleId }

    public var scheduleId: String
    public var jobType: JobType
    public var enabled: Bool
    public var trigger: ScheduledJobTrigger
    public var policy: ScheduledJobPolicy
    public var params: [String: JSONValue]
    public var lastRunAt: Date?
    public var lastRunJobId: String?
    public var lastRunStatus: ScheduleLastRunStatus?
    public var lastRunSummary: String?
    public var lastSuccessAt: Date?
    public var lastError: String?
    public var lastErrorCode: String?
    public var lastErrorMessage: String?
    public var nextRunAt: Date?
    public var runningJobId: String?
    public var consecutiveFailures: Int

    public init(
        scheduleId: String = UUID().uuidString,
        jobType: JobType,
        enabled: Bool = true,
        trigger: ScheduledJobTrigger,
        policy: ScheduledJobPolicy = ScheduledJobPolicy(),
        params: [String: JSONValue] = [:],
        lastRunAt: Date? = nil,
        lastRunJobId: String? = nil,
        lastRunStatus: ScheduleLastRunStatus? = nil,
        lastRunSummary: String? = nil,
        lastSuccessAt: Date? = nil,
        lastError: String? = nil,
        lastErrorCode: String? = nil,
        lastErrorMessage: String? = nil,
        nextRunAt: Date? = nil,
        runningJobId: String? = nil,
        consecutiveFailures: Int = 0
    ) {
        self.scheduleId = scheduleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? UUID().uuidString
            : scheduleId
        self.jobType = jobType
        self.enabled = enabled
        self.trigger = ScheduledJobTrigger(intervalSec: trigger.intervalSec)
        self.policy = policy
        self.params = params
        self.lastRunAt = lastRunAt
        self.lastRunJobId = lastRunJobId
        self.lastRunStatus = lastRunStatus
        self.lastRunSummary = lastRunSummary
        self.lastSuccessAt = lastSuccessAt
        self.lastError = lastError
        self.lastErrorCode = lastErrorCode
        self.lastErrorMessage = lastErrorMessage
        self.nextRunAt = nextRunAt
        self.runningJobId = runningJobId
        self.consecutiveFailures = max(0, consecutiveFailures)
    }
}

public struct ScheduledJobSummary: Sendable, Codable, Equatable, Identifiable {
    public var id: String { scheduleId }

    public let scheduleId: String
    public let jobType: JobType
    public let enabled: Bool
    public let runMode: ScheduleRunMode
    public let intervalSec: Int
    public let allowOverlap: Bool
    public let restartOnAppLaunch: Bool
    public let maxRuntimeSec: Int?
    public let startupBehavior: PeriodicScheduleStartupBehavior
    public let runningJobId: String?
    public let nextRunAt: Date?
    public let lastRunAt: Date?
    public let lastRunJobId: String?
    public let lastRunStatus: ScheduleLastRunStatus?
    public let lastRunSummary: String?
    public let lastSuccessAt: Date?
    public let lastError: String?
    public let lastErrorCode: String?
    public let lastErrorMessage: String?
    public let params: [String: JSONValue]

    public init(schedule: ScheduledJob) {
        scheduleId = schedule.scheduleId
        jobType = schedule.jobType
        enabled = schedule.enabled
        runMode = schedule.policy.runMode
        intervalSec = schedule.trigger.intervalSec
        allowOverlap = schedule.policy.allowOverlap
        restartOnAppLaunch = schedule.policy.restartOnAppLaunch
        maxRuntimeSec = schedule.policy.maxRuntimeSec
        startupBehavior = schedule.policy.startupBehavior
        runningJobId = schedule.runningJobId
        nextRunAt = schedule.nextRunAt
        lastRunAt = schedule.lastRunAt
        lastRunJobId = schedule.lastRunJobId
        lastRunStatus = schedule.lastRunStatus
        lastRunSummary = schedule.lastRunSummary
        lastSuccessAt = schedule.lastSuccessAt
        lastError = schedule.lastError
        lastErrorCode = schedule.lastErrorCode
        lastErrorMessage = schedule.lastErrorMessage
        params = schedule.params
    }
}

public enum ScheduleStoreError: Error, Sendable, Equatable {
    case scheduleNotFound(id: String)
}

public enum SchedulerError: Error, Sendable, Equatable {
    case scheduleNotFound(id: String)
    case invalidSchedule(message: String)
}
