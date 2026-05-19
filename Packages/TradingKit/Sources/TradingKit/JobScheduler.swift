import Foundation

public protocol ScheduledJobExecuting: Actor {
    func submit(type: JobType, parameters: [String: JSONValue]) async throws -> JobRecord
    func get(jobId: String) async throws -> JobRecord
    func cancel(jobId: String) async throws -> JobRecord
}

extension JobRunner: ScheduledJobExecuting {}

public actor JobScheduler {
    public typealias SchedulesChangedHook = @Sendable ([ScheduledJobSummary]) async -> Void
    public typealias DiagnosticHook = @Sendable (String, AuditEventLevel, String?) async -> Void

    private let scheduleStore: ScheduleStore
    private let jobExecutor: any ScheduledJobExecuting
    private let onSchedulesChanged: SchedulesChangedHook?
    private let onDiagnostic: DiagnosticHook?
    private let nowDate: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let tickIntervalSec: TimeInterval

    private var loaded = false
    private var started = false
    private var schedulesByID: [String: ScheduledJob] = [:]
    private var loopTask: Task<Void, Never>?

    public init(
        scheduleStore: ScheduleStore,
        jobExecutor: any ScheduledJobExecuting,
        onSchedulesChanged: SchedulesChangedHook? = nil,
        onDiagnostic: DiagnosticHook? = nil,
        nowDate: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        },
        tickIntervalSec: TimeInterval = 2
    ) {
        self.scheduleStore = scheduleStore
        self.jobExecutor = jobExecutor
        self.onSchedulesChanged = onSchedulesChanged
        self.onDiagnostic = onDiagnostic
        self.nowDate = nowDate
        self.sleep = sleep
        self.tickIntervalSec = max(0.5, tickIntervalSec)
    }

    deinit {
        loopTask?.cancel()
    }

    public func start() async {
        guard !started else {
            return
        }
        started = true

        do {
            _ = try await scheduleStore.seedDefaultsIfStoreMissing()
            _ = try await scheduleStore.seedMissingDefaults()
            loaded = false
            try await loadIfNeeded()
            let now = nowDate()
            let changed = try await bootstrapOnStart(now: now)
            if changed {
                await publishSummaries()
            } else {
                await publishSummaries()
            }
        } catch {
            await emitDiagnostic(
                "scheduler start failed reason=\(error.localizedDescription)",
                level: .warning,
                action: "schedule_start"
            )
        }

        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    public func stop() async {
        started = false
        let task = loopTask
        loopTask = nil
        task?.cancel()
        if let task {
            await task.value
        }
    }

    public func listSummaries() async throws -> [ScheduledJobSummary] {
        try await loadIfNeeded()
        return summaryList()
    }

    public func listSchedules() async throws -> [ScheduledJob] {
        try await loadIfNeeded()
        return schedulesByID.values.sorted { lhs, rhs in
            lhs.scheduleId < rhs.scheduleId
        }
    }

    public func getSchedule(id: String) async throws -> ScheduledJob? {
        try await loadIfNeeded()
        return schedulesByID[id]
    }

    @discardableResult
    public func upsertSchedule(_ schedule: ScheduledJob) async throws -> ScheduledJobSummary {
        try await loadIfNeeded()
        var normalized = normalize(schedule)
        if let existing = schedulesByID[normalized.scheduleId] {
            normalized.lastRunAt = existing.lastRunAt
            normalized.lastRunJobId = existing.lastRunJobId
            normalized.lastRunStatus = existing.lastRunStatus
            normalized.lastRunSummary = existing.lastRunSummary
            normalized.lastSuccessAt = existing.lastSuccessAt
            normalized.lastError = existing.lastError
            normalized.lastErrorCode = existing.lastErrorCode
            normalized.lastErrorMessage = existing.lastErrorMessage
            normalized.runningJobId = existing.runningJobId
            normalized.consecutiveFailures = existing.consecutiveFailures
            normalized.nextRunAt = existing.nextRunAt
        }
        normalized = prepareScheduleForStateTransition(normalized, enabled: normalized.enabled, now: nowDate())
        try await persistSchedule(normalized)
        await publishSummaries()
        await emitDiagnostic(
            "schedule upserted id=\(shortID(normalized.scheduleId)) type=\(normalized.jobType.rawValue) enabled=\(normalized.enabled)",
            level: .info,
            action: "schedule_upsert"
        )
        return ScheduledJobSummary(schedule: normalized)
    }

    public func removeSchedule(id: String) async throws {
        try await loadIfNeeded()
        guard let existing = schedulesByID[id] else {
            throw ScheduleStoreError.scheduleNotFound(id: id)
        }
        if let runningJobID = existing.runningJobId {
            _ = try? await jobExecutor.cancel(jobId: runningJobID)
        }
        try await scheduleStore.remove(id: id)
        schedulesByID.removeValue(forKey: id)
        await publishSummaries()
        await emitDiagnostic(
            "schedule removed id=\(shortID(id))",
            level: .warning,
            action: "schedule_remove"
        )
    }

    @discardableResult
    public func setScheduleEnabled(
        id: String,
        enabled: Bool
    ) async throws -> ScheduledJobSummary {
        try await loadIfNeeded()
        guard var schedule = schedulesByID[id] else {
            throw ScheduleStoreError.scheduleNotFound(id: id)
        }

        let now = nowDate()
        if !enabled, let runningJobID = schedule.runningJobId {
            _ = try? await jobExecutor.cancel(jobId: runningJobID)
        }
        schedule = prepareScheduleForStateTransition(schedule, enabled: enabled, now: now)
        try await persistSchedule(schedule)
        await publishSummaries()
        await emitDiagnostic(
            "schedule \(enabled ? "enabled" : "disabled") id=\(shortID(id))",
            level: .info,
            action: "schedule_enable"
        )
        return ScheduledJobSummary(schedule: schedule)
    }

    @discardableResult
    public func runScheduleNow(id: String) async throws -> ScheduledJobSummary {
        try await loadIfNeeded()
        guard var schedule = schedulesByID[id] else {
            throw ScheduleStoreError.scheduleNotFound(id: id)
        }
        guard schedule.runningJobId == nil else {
            throw SchedulerError.invalidSchedule(message: "Schedule is already running.")
        }
        let now = nowDate()
        do {
            schedule = try await startScheduleRun(schedule, now: now, reason: "run_now")
        } catch {
            let errorCode = (error as? any AgentControlError)?.code ?? "schedule_run_now_failed"
            let errorMessage = error.localizedDescription
            schedule.lastRunStatus = .failed
            schedule.lastRunSummary = nil
            schedule.lastErrorCode = errorCode
            schedule.lastErrorMessage = errorMessage
            schedule.lastError = errorCode
            schedule.consecutiveFailures += 1
            schedule.nextRunAt = restartDate(for: schedule, now: now, failed: true)
            try await persistSchedule(schedule)
            await publishSummaries()
            await emitDiagnostic(
                "schedule run-now failed id=\(shortID(id)) reason=\(errorCode)",
                level: .warning,
                action: "schedule_run_now"
            )
            throw error
        }
        try await persistSchedule(schedule)
        await publishSummaries()
        await emitDiagnostic(
            "schedule run-now dispatched id=\(shortID(id)) job_id=\(shortID(schedule.runningJobId ?? ""))",
            level: .info,
            action: "schedule_run_now"
        )
        return ScheduledJobSummary(schedule: schedule)
    }

    public func tickNow() async throws {
        try await loadIfNeeded()
        let changed = try await evaluateSchedules(now: nowDate())
        if changed {
            await publishSummaries()
        }
    }

    public func recoverAfterWake() async throws {
        try await loadIfNeeded()
        let changed = try await evaluateSchedules(now: nowDate())
        if changed {
            await publishSummaries()
        } else {
            await publishSummaries()
        }
        await emitDiagnostic(
            "scheduler wake recovery evaluated schedules=\(schedulesByID.count)",
            level: .info,
            action: "schedule_wake_recovery"
        )
    }

    private func runLoop() async {
        while !Task.isCancelled {
            await sleep(tickIntervalSec)
            if Task.isCancelled {
                return
            }
            do {
                try await loadIfNeeded()
                let changed = try await evaluateSchedules(now: nowDate())
                if changed {
                    await publishSummaries()
                }
            } catch {
                await emitDiagnostic(
                    "scheduler loop failed reason=\(error.localizedDescription)",
                    level: .warning,
                    action: "schedule_loop"
                )
            }
        }
    }

    private func loadIfNeeded() async throws {
        guard !loaded else {
            return
        }
        loaded = true
        let loadedSchedules = try await scheduleStore.listSchedules()
        schedulesByID = Dictionary(
            uniqueKeysWithValues: loadedSchedules.map { ($0.scheduleId, normalize($0)) }
        )
        await publishStoreDiagnostics()
    }

    private func bootstrapOnStart(now: Date) async throws -> Bool {
        var changed = false
        let ids = schedulesByID.keys.sorted()
        for id in ids {
            guard var schedule = schedulesByID[id] else {
                continue
            }
            if let runningJobID = schedule.runningJobId {
                if let state = try? await jobExecutor.get(jobId: runningJobID).status,
                   state == .running || state == .queued {
                    continue
                }
                schedule.runningJobId = nil
            }
            if schedule.enabled, schedule.policy.restartOnAppLaunch {
                if schedule.policy.runMode == .alwaysOn {
                    schedule.nextRunAt = now
                } else {
                    schedule.nextRunAt = startupNextRunDate(for: schedule, now: now)
                }
            } else if !schedule.enabled {
                schedule.nextRunAt = nil
            }

            if schedule != schedulesByID[id] {
                try await persistSchedule(schedule)
                changed = true
            }
        }

        let cycleChanged = try await evaluateSchedules(now: now)
        return changed || cycleChanged
    }

    private func evaluateSchedules(now: Date) async throws -> Bool {
        var changed = false
        let ids = schedulesByID.keys.sorted()
        for id in ids {
            guard var schedule = schedulesByID[id] else {
                continue
            }
            let (updated, didChange) = try await evaluateSingleSchedule(schedule, now: now)
            if didChange {
                schedule = updated
                try await persistSchedule(schedule)
                changed = true
            }
        }
        return changed
    }

    private func evaluateSingleSchedule(
        _ schedule: ScheduledJob,
        now: Date
    ) async throws -> (ScheduledJob, Bool) {
        var updated = schedule
        var changed = false

        if let runningJobID = updated.runningJobId {
            do {
                let job = try await jobExecutor.get(jobId: runningJobID)
                switch job.status {
                case .queued, .running:
                    if let maxRuntimeSec = updated.policy.maxRuntimeSec,
                       now.timeIntervalSince(job.createdAt) > Double(maxRuntimeSec) {
                        _ = try? await jobExecutor.cancel(jobId: runningJobID)
                        updated.runningJobId = nil
                        updated.lastRunStatus = .failed
                        updated.lastRunSummary = nil
                        updated.lastErrorCode = "max_runtime_exceeded"
                        updated.lastErrorMessage = "Scheduled job exceeded max runtime."
                        updated.lastError = "max_runtime_exceeded"
                        updated.consecutiveFailures += 1
                        updated.nextRunAt = restartDate(for: updated, now: now, failed: true)
                        changed = true
                        await emitDiagnostic(
                            "schedule job canceled by max runtime id=\(shortID(updated.scheduleId)) job_id=\(shortID(runningJobID))",
                            level: .warning,
                            action: "schedule_runtime"
                        )
                    }
                    return (updated, changed)
                case .succeeded:
                    updated = applyFinishedJob(
                        schedule: updated,
                        job: job,
                        now: now,
                        status: .succeeded,
                        failed: false
                    )
                    changed = true
                case .failed:
                    updated = applyFinishedJob(
                        schedule: updated,
                        job: job,
                        now: now,
                        status: .failed,
                        failed: true
                    )
                    changed = true
                case .canceled:
                    updated = applyFinishedJob(
                        schedule: updated,
                        job: job,
                        now: now,
                        status: .canceled,
                        failed: updated.enabled
                    )
                    if !updated.enabled {
                        updated.nextRunAt = nil
                    }
                    changed = true
                }
            } catch {
                updated.runningJobId = nil
                if missingRunningJobIsFailure(for: updated) {
                    updated.lastRunStatus = .failed
                    updated.lastRunSummary = nil
                    updated.lastErrorCode = "job_not_found"
                    updated.lastErrorMessage = "Scheduled job record was not found."
                    updated.lastError = "job_not_found"
                    updated.nextRunAt = restartDate(for: updated, now: now, failed: true)
                    updated.consecutiveFailures += 1
                } else {
                    updated.nextRunAt = restartDate(for: updated, now: now, failed: false)
                }
                changed = true
            }
        }

        guard updated.enabled else {
            if updated.nextRunAt != nil {
                updated.nextRunAt = nil
                changed = true
            }
            return (updated, changed)
        }

        if updated.runningJobId != nil {
            return (updated, changed)
        }

        let due: Bool
        if updated.policy.runMode == .alwaysOn {
            due = (updated.nextRunAt ?? now) <= now
        } else {
            if updated.nextRunAt == nil {
                updated.nextRunAt = now.addingTimeInterval(Double(updated.trigger.intervalSec))
                changed = true
            }
            due = (updated.nextRunAt ?? now) <= now
        }

        guard due else {
            return (updated, changed)
        }

        do {
            updated = try await startScheduleRun(updated, now: now, reason: "due")
            changed = true
        } catch {
            updated.lastRunStatus = .failed
            updated.lastRunSummary = nil
            updated.lastErrorCode = "schedule_start_failed"
            updated.lastErrorMessage = error.localizedDescription
            updated.lastError = error.localizedDescription
            updated.consecutiveFailures += 1
            updated.nextRunAt = restartDate(for: updated, now: now, failed: true)
            changed = true
            await emitDiagnostic(
                "schedule start failed id=\(shortID(updated.scheduleId)) reason=\(error.localizedDescription)",
                level: .warning,
                action: "schedule_start"
            )
        }

        return (updated, changed)
    }

    private func startScheduleRun(
        _ schedule: ScheduledJob,
        now: Date,
        reason: String
    ) async throws -> ScheduledJob {
        var parameters = schedule.params
        parameters["_scheduleId"] = .string(schedule.scheduleId)
        parameters["_scheduleRunMode"] = .string(schedule.policy.runMode.rawValue)

        let job = try await jobExecutor.submit(type: schedule.jobType, parameters: parameters)

        var updated = schedule
        updated.runningJobId = job.jobId
        updated.lastRunAt = now
        updated.lastRunJobId = job.jobId
        updated.nextRunAt = (schedule.policy.runMode == .periodic)
            ? now.addingTimeInterval(Double(schedule.trigger.intervalSec))
            : nil
        updated.lastError = nil
        updated.lastErrorCode = nil
        updated.lastErrorMessage = nil

        await emitDiagnostic(
            "schedule started id=\(shortID(schedule.scheduleId)) job_id=\(shortID(job.jobId)) reason=\(reason)",
            level: .info,
            action: "schedule_started"
        )
        return updated
    }

    private func restartDate(
        for schedule: ScheduledJob,
        now: Date,
        failed: Bool
    ) -> Date? {
        guard schedule.enabled else {
            return nil
        }
        switch schedule.policy.runMode {
        case .alwaysOn:
            if failed {
                return now.addingTimeInterval(restartBackoffSec(for: schedule))
            }
            return now
        case .periodic:
            return now.addingTimeInterval(Double(schedule.trigger.intervalSec))
        }
    }

    private func restartBackoffSec(for schedule: ScheduledJob) -> TimeInterval {
        let base = max(1, schedule.trigger.intervalSec)
        let exponent = max(0, min(schedule.consecutiveFailures - 1, 5))
        let multiplier = pow(2.0, Double(exponent))
        return min(300, Double(base) * multiplier)
    }

    private func normalize(_ schedule: ScheduledJob) -> ScheduledJob {
        var normalized = schedule
        normalized.trigger.intervalSec = max(1, normalized.trigger.intervalSec)
        normalized.policy.maxRuntimeSec = normalized.policy.maxRuntimeSec.map { max(1, $0) }
        normalized.consecutiveFailures = max(0, normalized.consecutiveFailures)
        return normalized
    }

    private func prepareScheduleForStateTransition(
        _ schedule: ScheduledJob,
        enabled: Bool,
        now: Date
    ) -> ScheduledJob {
        var updated = normalize(schedule)
        updated.enabled = enabled
        if !enabled {
            updated.runningJobId = nil
            updated.nextRunAt = nil
            return updated
        }

        if updated.policy.runMode == .alwaysOn {
            if updated.runningJobId == nil {
                updated.nextRunAt = now
            }
        } else if updated.nextRunAt == nil {
            updated.nextRunAt = now.addingTimeInterval(Double(updated.trigger.intervalSec))
        }
        return updated
    }

    private func startupNextRunDate(
        for schedule: ScheduledJob,
        now: Date
    ) -> Date {
        guard schedule.policy.runMode == .periodic else {
            return now
        }
        switch schedule.policy.startupBehavior {
        case .waitForInterval:
            return now.addingTimeInterval(Double(schedule.trigger.intervalSec))
        case .runImmediately:
            return now
        }
    }

    private func missingRunningJobIsFailure(for schedule: ScheduledJob) -> Bool {
        schedule.policy.runMode == .alwaysOn
    }

    private func applyFinishedJob(
        schedule: ScheduledJob,
        job: JobRecord,
        now: Date,
        status: ScheduleLastRunStatus,
        failed: Bool
    ) -> ScheduledJob {
        var updated = schedule
        updated.runningJobId = nil
        updated.lastRunJobId = job.jobId
        updated.lastRunStatus = status
        updated.lastRunSummary = summaryText(for: job)
        updated.lastErrorCode = failed ? job.error?.code : nil
        updated.lastErrorMessage = failed ? (job.error?.message ?? job.message ?? "job_failed") : nil
        updated.lastError = failed ? (job.error?.message ?? job.message ?? "job_failed") : nil
        updated.nextRunAt = restartDate(for: updated, now: now, failed: failed)
        if failed {
            updated.consecutiveFailures += 1
        } else {
            updated.lastSuccessAt = now
            updated.consecutiveFailures = 0
        }
        return updated
    }

    private func summaryText(for job: JobRecord) -> String? {
        guard let result = job.result?.objectValue else {
            return job.message
        }

        if job.type == .rssPoll {
            let feeds = result["feedsPolled"]?.intValue ?? 0
            let parsed = result["itemsParsed"]?.intValue ?? 0
            let secFilings = result["secFilingsParsed"]?.intValue ?? 0
            let newEvents = result["newEvents"]?.intValue
                ?? result["inserted"]?.intValue
                ?? 0
            let duplicates = result["duplicates"]?.intValue ?? 0
            let failures = result["failedFeeds"]?.intValue
                ?? result["errors"]?.intValue
                ?? 0
            if secFilings > 0 {
                return "rss_poll: feeds=\(feeds) parsed=\(parsed) sec=\(secFilings) new=\(newEvents) dup=\(duplicates) failed=\(failures)"
            }
            return "rss_poll: feeds=\(feeds) parsed=\(parsed) new=\(newEvents) dup=\(duplicates) failed=\(failures)"
        }

        if let summary = result["summary"]?.stringValue, !summary.isEmpty {
            return summary
        }
        return job.message
    }

    private func persistSchedule(_ schedule: ScheduledJob) async throws {
        schedulesByID[schedule.scheduleId] = schedule
        _ = try await scheduleStore.upsert(schedule)
        await publishStoreDiagnostics()
    }

    private func publishSummaries() async {
        guard let onSchedulesChanged else {
            return
        }
        await onSchedulesChanged(summaryList())
    }

    private func summaryList() -> [ScheduledJobSummary] {
        schedulesByID.values
            .map(ScheduledJobSummary.init(schedule:))
            .sorted { lhs, rhs in
                if lhs.jobType == rhs.jobType {
                    return lhs.scheduleId < rhs.scheduleId
                }
                return lhs.jobType.rawValue < rhs.jobType.rawValue
            }
    }

    private func publishStoreDiagnostics() async {
        let diagnostics = await scheduleStore.drainLoadDiagnostics()
        for message in diagnostics {
            await emitDiagnostic(
                message,
                level: .warning,
                action: "schedule_persistence"
            )
        }
    }

    private func emitDiagnostic(
        _ message: String,
        level: AuditEventLevel,
        action: String?
    ) async {
        if let onDiagnostic {
            await onDiagnostic(message, level, action)
        }
    }

    private func shortID(_ value: String) -> String {
        String(value.prefix(8))
    }
}
