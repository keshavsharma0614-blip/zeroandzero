import Foundation

public struct JobExecutionReport: Sendable, Equatable {
    public let result: JSONValue?
    public let proposalId: String?
    public let runId: String?

    public init(
        result: JSONValue? = nil,
        proposalId: String? = nil,
        runId: String? = nil
    ) {
        self.result = result
        self.proposalId = proposalId
        self.runId = runId
    }
}

public actor JobRunner {
    public typealias JobProgressUpdater = @Sendable (Double?, String?) async -> Void
    public typealias JobExecutor = @Sendable (JobRecord, JobProgressUpdater) async throws -> JobExecutionReport
    public typealias JobUpdateHook = @Sendable (JobRecord) async -> Void
    public typealias JobDiagnosticHook = @Sendable (String, AuditEventLevel, String?) async -> Void

    private let jobStore: JobStore
    private let nowDate: @Sendable () -> Date
    private var monitorExecutor: JobExecutor?
    private var replayBatchExecutor: JobExecutor?
    private var rssPollExecutor: JobExecutor?
    private var newsRetentionExecutor: JobExecutor?
    private var analystSignalsExecutor: JobExecutor?
    private var standingAnalystReportExecutor: JobExecutor?
    private var recentNewsAnalystExecutor: JobExecutor?
    private var portfolioRiskAnalystExecutor: JobExecutor?
    private var maintenanceRetentionExecutor: JobExecutor?
    private var onJobUpdated: JobUpdateHook?
    private var onDiagnostic: JobDiagnosticHook?
    private var tasksByID: [String: Task<Void, Never>] = [:]
    private var jobProgressPersistCount = 0

    public init(
        jobStore: JobStore,
        nowDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.jobStore = jobStore
        self.nowDate = nowDate
    }

    deinit {
        let tasks = Array(tasksByID.values)
        tasksByID.removeAll()
        for task in tasks {
            task.cancel()
        }
    }

    public func configure(
        monitorExecutor: JobExecutor?,
        replayBatchExecutor: JobExecutor?,
        rssPollExecutor: JobExecutor?,
        newsRetentionExecutor: JobExecutor?,
        analystSignalsExecutor: JobExecutor?,
        standingAnalystReportExecutor: JobExecutor? = nil,
        recentNewsAnalystExecutor: JobExecutor?,
        portfolioRiskAnalystExecutor: JobExecutor?,
        maintenanceRetentionExecutor: JobExecutor?,
        onJobUpdated: JobUpdateHook? = nil,
        onDiagnostic: JobDiagnosticHook? = nil
    ) {
        self.monitorExecutor = monitorExecutor
        self.replayBatchExecutor = replayBatchExecutor
        self.rssPollExecutor = rssPollExecutor
        self.newsRetentionExecutor = newsRetentionExecutor
        self.analystSignalsExecutor = analystSignalsExecutor
        self.standingAnalystReportExecutor = standingAnalystReportExecutor
        self.recentNewsAnalystExecutor = recentNewsAnalystExecutor
        self.portfolioRiskAnalystExecutor = portfolioRiskAnalystExecutor
        self.maintenanceRetentionExecutor = maintenanceRetentionExecutor
        self.onJobUpdated = onJobUpdated
        self.onDiagnostic = onDiagnostic
    }

    @discardableResult
    public func submit(
        type: JobType,
        parameters: [String: JSONValue]
    ) async throws -> JobRecord {
        let timestamp = nowDate()
        var job = JobRecord(
            type: type,
            createdAt: timestamp,
            updatedAt: timestamp,
            status: .queued,
            progress: 0,
            message: "Queued",
            parameters: parameters,
            proposalId: parameters["proposalId"]?.stringValue,
            runId: parameters["runId"]?.stringValue
        )
        job = try await persist(job)
        await emitDiagnostic(
            "job queued id=\(shortJobID(job.jobId)) type=\(job.type.rawValue)",
            level: .info,
            action: "job_queued"
        )
        await startIfNeeded(jobId: job.jobId)
        return job
    }

    public func list() async throws -> [JobSummary] {
        try await jobStore.list()
    }

    public func listActiveAndRecentSummaries(
        recentCompletedLimit: Int
    ) async throws -> [JobSummary] {
        try await jobStore.listActiveAndRecentSummaries(
            recentCompletedLimit: recentCompletedLimit
        )
    }

    public func count() async throws -> Int {
        try await jobStore.count()
    }

    public func summaryProjectionDiagnostics() async throws -> JobSummaryProjectionDiagnostics {
        var diagnostics = try await jobStore.summaryProjectionDiagnostics()
        diagnostics.jobProgressPersistCount = jobProgressPersistCount
        return diagnostics
    }

    public func get(jobId: String) async throws -> JobRecord {
        guard let job = try await jobStore.get(id: jobId) else {
            throw JobStoreError.jobNotFound(id: jobId)
        }
        return job
    }

    @discardableResult
    public func cancel(jobId: String) async throws -> JobRecord {
        var job = try await get(jobId: jobId)
        if job.status == .succeeded || job.status == .failed || job.status == .canceled {
            return job
        }

        let task = tasksByID.removeValue(forKey: jobId)
        task?.cancel()
        if let task {
            await task.value
        }
        job.status = .canceled
        job.progress = job.progress ?? 0
        job.updatedAt = nowDate()
        job.message = "Canceled"
        job.error = JobErrorInfo(code: "job_canceled", message: "Job canceled by user.")
        let updated = try await persist(job)
        await emitDiagnostic(
            "job canceled id=\(shortJobID(jobId)) type=\(job.type.rawValue)",
            level: .warning,
            action: "job_canceled"
        )
        return updated
    }

    public func resumePendingJobsOnStartup() async {
        do {
            let jobs = try await jobStore.loadAll()
            for job in jobs {
                switch job.status {
                case .queued:
                    if await interruptScheduledPeriodicJobOnStartupIfNeeded(job) {
                        continue
                    }
                    await startIfNeeded(jobId: job.jobId)
                case .running:
                    if await interruptScheduledPeriodicJobOnStartupIfNeeded(job) {
                        continue
                    }
                    if job.type == .monitor || job.type == .rssPoll || job.type == .analystSignals {
                        var resumed = job
                        resumed.status = .queued
                        resumed.updatedAt = nowDate()
                        resumed.message = "Resuming after restart"
                        resumed.error = nil
                        _ = try? await persist(resumed)
                        await emitDiagnostic(
                            "job resumed id=\(shortJobID(job.jobId)) type=\(job.type.rawValue)",
                            level: .info,
                            action: "job_resumed"
                        )
                        await startIfNeeded(jobId: job.jobId)
                    } else {
                        var interrupted = job
                        interrupted.status = .failed
                        interrupted.updatedAt = nowDate()
                        interrupted.message = "Interrupted by restart"
                        interrupted.error = JobErrorInfo(
                            code: "job_interrupted",
                            message: "Job was running during restart and must be re-submitted."
                        )
                        _ = try? await persist(interrupted)
                        await emitDiagnostic(
                            "job interrupted id=\(shortJobID(job.jobId)) type=\(job.type.rawValue)",
                            level: .warning,
                            action: "job_interrupted"
                        )
                    }
                case .succeeded, .failed, .canceled:
                    continue
                }
            }
        } catch {
            await emitDiagnostic(
                "job resume failed reason=\(error.localizedDescription)",
                level: .error,
                action: "job_resume"
            )
        }
    }

    private func interruptScheduledPeriodicJobOnStartupIfNeeded(_ job: JobRecord) async -> Bool {
        guard let scheduledRunMode = scheduledRunMode(for: job),
              scheduledRunMode == .periodic,
              let scheduleID = scheduledScheduleID(for: job)
        else {
            return false
        }

        var interrupted = job
        interrupted.status = .failed
        interrupted.updatedAt = nowDate()
        interrupted.message = "Interrupted by restart"
        interrupted.error = JobErrorInfo(
            code: "job_interrupted",
            message: "Periodic scheduled jobs do not resume after restart; scheduler will dispatch a fresh run when due."
        )
        _ = try? await persist(interrupted)
        await emitDiagnostic(
            "job interrupted id=\(shortJobID(job.jobId)) type=\(job.type.rawValue) schedule=\(shortJobID(scheduleID)) reason=periodic_restart_reconciliation",
            level: .warning,
            action: "job_interrupted"
        )
        return true
    }

    public func handleEngineStop() async {
        let taskIDs = Array(tasksByID.keys)
        let tasks = Array(tasksByID.values)
        for task in tasks {
            task.cancel()
        }
        tasksByID.removeAll()
        for task in tasks {
            await task.value
        }

        for jobID in taskIDs {
            guard var job = try? await get(jobId: jobID) else {
                continue
            }
            if job.status == .running || job.status == .queued {
                job.status = .failed
                job.updatedAt = nowDate()
                job.message = "Interrupted by engine stop"
                job.error = JobErrorInfo(
                    code: "job_interrupted",
                    message: "Engine stopped while job was active."
                )
                _ = try? await persist(job)
            }
        }
    }

    private func startIfNeeded(jobId: String) async {
        guard tasksByID[jobId] == nil else {
            return
        }

        let task = Task<Void, Never> { [self] in
            await runJob(jobId: jobId)
        }
        tasksByID[jobId] = task
    }

    private func runJob(jobId: String) async {
        defer {
            tasksByID[jobId] = nil
        }

        guard var job = try? await get(jobId: jobId) else {
            return
        }
        guard job.status == .queued || job.status == .running else {
            return
        }

        job.status = .running
        job.updatedAt = nowDate()
        job.message = "Running"
        job.error = nil
        _ = try? await persist(job)
        await emitDiagnostic(
            "job running id=\(shortJobID(job.jobId)) type=\(job.type.rawValue)",
            level: .info,
            action: "job_running"
        )

        do {
            let executor = try executor(for: job.type)
            let report = try await executor(job) { [self] progress, message in
                await updateProgress(jobId: jobId, progress: progress, message: message)
            }

            var finished = try await get(jobId: jobId)
            if finished.status == .canceled {
                return
            }
            finished.status = .succeeded
            finished.updatedAt = nowDate()
            finished.progress = 1
            finished.message = finished.message ?? "Completed"
            finished.result = report.result
            if let proposalId = report.proposalId {
                finished.proposalId = proposalId
            }
            if let runId = report.runId {
                finished.runId = runId
            }
            finished.error = nil
            _ = try? await persist(finished)
            await emitDiagnostic(
                "job succeeded id=\(shortJobID(finished.jobId)) type=\(finished.type.rawValue)",
                level: .info,
                action: "job_succeeded"
            )
        } catch is CancellationError {
            if var canceled = try? await get(jobId: jobId) {
                canceled.status = .canceled
                canceled.updatedAt = nowDate()
                canceled.message = "Canceled"
                canceled.error = JobErrorInfo(
                    code: "job_canceled",
                    message: "Job canceled."
                )
                _ = try? await persist(canceled)
            }
        } catch let controlError as AgentControlError {
            if var failed = try? await get(jobId: jobId) {
                failed.status = .failed
                failed.updatedAt = nowDate()
                failed.message = controlError.message
                failed.error = JobErrorInfo(code: controlError.code, message: controlError.message)
                _ = try? await persist(failed)
            }
            await emitDiagnostic(
                "job failed id=\(shortJobID(jobId)) reason=\(controlError.code)",
                level: .error,
                action: "job_failed"
            )
        } catch {
            if var failed = try? await get(jobId: jobId) {
                failed.status = .failed
                failed.updatedAt = nowDate()
                failed.message = error.localizedDescription
                failed.error = JobErrorInfo(code: "job_execution_failed", message: error.localizedDescription)
                _ = try? await persist(failed)
            }
            await emitDiagnostic(
                "job failed id=\(shortJobID(jobId)) reason=job_execution_failed",
                level: .error,
                action: "job_failed"
            )
        }
    }

    private func executor(for type: JobType) throws -> JobExecutor {
        switch type {
        case .monitor:
            if let monitorExecutor {
                return monitorExecutor
            }
            throw JobRunnerError.invalidParameters(message: "Monitor executor unavailable.")
        case .replayBatch:
            if let replayBatchExecutor {
                return replayBatchExecutor
            }
            throw JobRunnerError.invalidParameters(message: "Replay batch executor unavailable.")
        case .rssPoll:
            if let rssPollExecutor {
                return rssPollExecutor
            }
            throw JobRunnerError.invalidParameters(message: "RSS poll executor unavailable.")
        case .newsRetention:
            if let newsRetentionExecutor {
                return newsRetentionExecutor
            }
            throw JobRunnerError.invalidParameters(message: "News retention executor unavailable.")
        case .analystSignals:
            if let analystSignalsExecutor {
                return analystSignalsExecutor
            }
            throw JobRunnerError.invalidParameters(message: "Analyst signals executor unavailable.")
        case .standingAnalystReport:
            if let standingAnalystReportExecutor {
                return standingAnalystReportExecutor
            }
            throw JobRunnerError.invalidParameters(message: "Standing analyst report executor unavailable.")
        case .recentNewsAnalyst:
            if let recentNewsAnalystExecutor {
                return recentNewsAnalystExecutor
            }
            throw JobRunnerError.invalidParameters(message: "Recent news analyst executor unavailable.")
        case .portfolioRiskAnalyst:
            if let portfolioRiskAnalystExecutor {
                return portfolioRiskAnalystExecutor
            }
            throw JobRunnerError.invalidParameters(message: "Portfolio risk analyst executor unavailable.")
        case .maintenanceRetention:
            if let maintenanceRetentionExecutor {
                return maintenanceRetentionExecutor
            }
            throw JobRunnerError.invalidParameters(message: "Maintenance retention executor unavailable.")
        }
    }

    private func updateProgress(
        jobId: String,
        progress: Double?,
        message: String?
    ) async {
        guard var job = try? await get(jobId: jobId) else {
            return
        }
        if job.status == .canceled {
            return
        }
        if let progress {
            job.progress = min(1, max(0, progress))
        }
        if let message {
            job.message = message
        }
        job.updatedAt = nowDate()
        jobProgressPersistCount += 1
        _ = try? await persist(job)
    }

    @discardableResult
    private func persist(_ job: JobRecord) async throws -> JobRecord {
        let saved = try await jobStore.upsert(job)
        if let onJobUpdated {
            await onJobUpdated(saved)
        }
        return saved
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

    private func shortJobID(_ id: String) -> String {
        String(id.prefix(8))
    }

    private func scheduledScheduleID(for job: JobRecord) -> String? {
        guard let value = job.parameters["_scheduleId"]?.stringValue else {
            return nil
        }
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty
        else {
            return nil
        }
        return raw
    }

    private func scheduledRunMode(for job: JobRecord) -> ScheduleRunMode? {
        guard let value = job.parameters["_scheduleRunMode"]?.stringValue else {
            return nil
        }
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty
        else {
            return nil
        }
        return ScheduleRunMode(rawValue: raw)
    }
}
