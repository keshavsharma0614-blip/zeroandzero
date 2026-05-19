import Foundation
import Testing
@testable import TradingKit

@Test("ScheduleStore persists schema v1 and loads legacy v0 schedules")
func scheduleStorePersistsV1AndLoadsLegacyV0() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("schedule-store-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "schedule-v1",
        jobType: .monitor,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 5),
        policy: ScheduledJobPolicy(
            runMode: .alwaysOn,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let persistedData = try Data(contentsOf: fileURL)
    let persisted = try JSONDecoder().decode(JSONValue.self, from: persistedData)
    let persistedObject = try #require(persisted.objectValue)
    #expect(persistedObject["schemaVersion"] == .number(1))

    let legacyData = Data(
        """
        [
          {
            "scheduleId": "schedule-v0",
            "jobType": "rss_poll",
            "enabled": true,
            "trigger": {
              "intervalSec": 60
            },
            "policy": {
              "runMode": "periodic",
              "restartOnAppLaunch": true,
              "maxRuntimeSec": null,
              "allowOverlap": false
            },
            "params": {
              "maxItemsPerFeed": 10
            },
            "consecutiveFailures": 0
          }
        ]
        """.utf8
    )
    try legacyData.write(to: fileURL, options: [.atomic])

    let reloaded = ScheduleStore(fileURL: fileURL)
    let loaded = try await reloaded.listSchedules()
    #expect(loaded.count == 1)
    #expect(loaded.first?.scheduleId == "schedule-v0")
    #expect(loaded.first?.policy.startupBehavior == .runImmediately)

    let upgradedText = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(upgradedText.contains("\"startupBehavior\" : \"run_immediately\""))
}

@Test("ScheduleStore does not reseed defaults over an existing invalid persisted schedule file")
func scheduleStoreDoesNotReseedDefaultsOverExistingInvalidFile() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("schedule-store-invalid-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let original = """
    {
      "schemaVersion": 999,
      "schedules": []
    }
    """
    try original.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = ScheduleStore(fileURL: fileURL)
    let schedules = try await store.seedDefaultsIfStoreMissing()

    #expect(schedules.isEmpty)
    #expect(try String(contentsOf: fileURL, encoding: .utf8) == original)

    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
}

@Test("Scheduler always_on starts and restarts after failure with backoff")
func schedulerAlwaysOnStartsAndRestartsAfterFailure() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-always-on-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "always-on-1",
        jobType: .monitor,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 2),
        policy: ScheduledJobPolicy(
            runMode: .alwaysOn,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_000_000))
    let jobs = MockScheduledJobExecutor()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    var summaries = try await scheduler.listSummaries()
    #expect(await jobs.submitCount() == 1)
    let runningJobID = try #require(summaries.first?.runningJobId)

    await jobs.setStatus(
        jobId: runningJobID,
        status: .failed,
        message: "failed",
        error: JobErrorInfo(code: "job_failed", message: "failed")
    )
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 1)

    clock.advance(by: 2)
    try await scheduler.tickNow()

    #expect(await jobs.submitCount() == 2)
    summaries = try await scheduler.listSummaries()
    #expect(summaries.first?.runningJobId != nil)
    await scheduler.stop()
}

@Test("Scheduler rss_poll can run immediately on startup then respect interval cadence")
func schedulerPeriodicStartupImmediateThenCadence() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-startup-immediate-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "rss-startup-1",
        jobType: .rssPoll,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 300),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false,
            startupBehavior: .runImmediately
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_080_000))
    let jobs = MockScheduledJobExecutor()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    #expect(await jobs.submitCount() == 1)

    var summary = try #require(try await scheduler.listSummaries().first)
    let firstJobID = try #require(summary.runningJobId)

    clock.advance(by: 60)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 1)

    await jobs.setStatus(
        jobId: firstJobID,
        status: .succeeded,
        message: "done",
        result: .object(["summary": .string("rss poll ok")]),
        error: nil
    )
    try await scheduler.tickNow()

    summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId == nil)
    #expect(summary.lastRunStatus == .succeeded)
    #expect(summary.nextRunAt == clock.now().addingTimeInterval(300))

    clock.advance(by: 299)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 1)

    clock.advance(by: 1)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 2)
    await scheduler.stop()
}

@Test("Scheduler wake recovery evaluates due work without duplicating running jobs")
func schedulerWakeRecoveryDoesNotDuplicateRunningJobs() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-wake-recovery-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "rss-wake-recovery",
        jobType: .rssPoll,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 300),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false,
            startupBehavior: .runImmediately
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_080_000))
    let jobs = MockScheduledJobExecutor()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    #expect(await jobs.submitCount() == 1)

    try await scheduler.recoverAfterWake()
    #expect(await jobs.submitCount() == 1)

    await scheduler.stop()
}

@Test("Scheduler analyst_signals waits for interval on startup")
func schedulerPeriodicStartupWaitsForInterval() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-startup-wait-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "signals-startup-1",
        jobType: .analystSignals,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 60),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false,
            startupBehavior: .waitForInterval
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_081_000))
    let jobs = MockScheduledJobExecutor()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    #expect(await jobs.submitCount() == 0)

    var summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.nextRunAt == clock.now().addingTimeInterval(60))
    #expect(summary.runningJobId == nil)

    clock.advance(by: 59)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 0)

    clock.advance(by: 1)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 1)
    summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId == "job-1")
    await scheduler.stop()
}

@Test("Scheduler periodic run-now plus interval trigger are deterministic")
func schedulerPeriodicRunNowAndInterval() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-periodic-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "periodic-1",
        jobType: .rssPoll,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 10),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_100_000))
    let jobs = MockScheduledJobExecutor()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    #expect(await jobs.submitCount() == 0)

    _ = try await scheduler.runScheduleNow(id: "periodic-1")
    #expect(await jobs.submitCount() == 1)

    var summary = try #require(try await scheduler.listSummaries().first)
    let firstJobID = try #require(summary.runningJobId)
    await jobs.setStatus(
        jobId: firstJobID,
        status: .succeeded,
        message: "done",
        result: .object([
            "jobType": .string(JobType.rssPoll.rawValue),
            "feedsPolled": .number(3),
            "itemsParsed": .number(52),
            "newEvents": .number(12),
            "duplicates": .number(40),
            "failedFeeds": .number(0),
            "summary": .string("rss_poll: feeds=3 parsed=52 new=12 dup=40 failed=0")
        ]),
        error: nil
    )
    try await scheduler.tickNow()
    summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId == nil)
    #expect(summary.lastRunJobId == firstJobID)
    #expect(summary.lastRunStatus == .succeeded)
    #expect(summary.lastRunSummary == "rss_poll: feeds=3 parsed=52 new=12 dup=40 failed=0")
    #expect(summary.lastError == nil)

    clock.advance(by: 10)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 2)
    summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId != nil)
    await scheduler.stop()
}

@Test("Scheduler periodic missing job record clears running state without job_not_found error")
func schedulerPeriodicMissingJobRecordIsNotFailure() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-periodic-missing-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "periodic-missing-1",
        jobType: .rssPoll,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 10),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false
        ),
        params: [:],
        lastRunStatus: .succeeded,
        lastRunSummary: "rss_poll: feeds=1 parsed=5 new=2 dup=3 failed=0"
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_150_000))
    let jobs = MockScheduledJobExecutor()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    let dispatched = try await scheduler.runScheduleNow(id: "periodic-missing-1")
    let runningJobID = try #require(dispatched.runningJobId)
    await jobs.remove(jobId: runningJobID)

    try await scheduler.tickNow()

    let summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId == nil)
    #expect(summary.lastRunStatus == .succeeded)
    #expect(summary.lastRunSummary == "rss_poll: feeds=1 parsed=5 new=2 dup=3 failed=0")
    #expect(summary.lastErrorCode == nil)
    #expect(summary.lastErrorMessage == nil)
    #expect(summary.lastError == nil)
    await scheduler.stop()
}

@Test("Scheduler overlap prevention avoids duplicate runs")
func schedulerOverlapPrevention() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-overlap-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "overlap-1",
        jobType: .monitor,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 1),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_200_000))
    let jobs = MockScheduledJobExecutor()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    _ = try await scheduler.runScheduleNow(id: "overlap-1")
    #expect(await jobs.submitCount() == 1)

    clock.advance(by: 5)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 1)
    await scheduler.stop()
}

@Test("Scheduler startup does not overlap resumed periodic jobs when overlap is disabled")
func schedulerStartupDoesNotOverlapResumedPeriodicJob() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-resume-periodic-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let start = Date(timeIntervalSince1970: 1_700_250_000)
    let store = ScheduleStore(fileURL: fileURL)
    let resumedJob = JobRecord(
        jobId: "job-resumed",
        type: .analystSignals,
        createdAt: start.addingTimeInterval(-60),
        updatedAt: start.addingTimeInterval(-5),
        status: .queued,
        progress: 0.2,
        message: "Resuming after restart",
        parameters: ["_scheduleId": .string("resume-1")]
    )
    let schedule = ScheduledJob(
        scheduleId: "resume-1",
        jobType: .analystSignals,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 30),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false
        ),
        params: [:],
        lastRunAt: start.addingTimeInterval(-60),
        lastRunJobId: resumedJob.jobId,
        nextRunAt: start.addingTimeInterval(-1),
        runningJobId: resumedJob.jobId
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: start)
    let jobs = MockScheduledJobExecutor()
    await jobs.seed(job: resumedJob)
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    #expect(await jobs.submitCount() == 0)

    var summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId == resumedJob.jobId)

    clock.advance(by: 90)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 0)

    await jobs.setStatus(
        jobId: resumedJob.jobId,
        status: .succeeded,
        message: "done",
        result: .object(["summary": .string("analyst_signals completed")]),
        error: nil
    )
    try await scheduler.tickNow()

    summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.lastRunJobId == resumedJob.jobId)
    #expect(summary.lastRunStatus == .succeeded)
    #expect(summary.runningJobId == nil)

    clock.advance(by: 30)
    try await scheduler.tickNow()
    #expect(await jobs.submitCount() == 1)
    summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId == "job-1")
    await scheduler.stop()
}

@Test("Scheduler run-now returns job id and emits dispatch diagnostic")
func schedulerRunNowReturnsJobIDAndDiagnostic() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-run-now-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let store = ScheduleStore(fileURL: fileURL)
    let schedule = ScheduledJob(
        scheduleId: "run-now-1",
        jobType: .analystSignals,
        enabled: true,
        trigger: ScheduledJobTrigger(intervalSec: 60),
        policy: ScheduledJobPolicy(
            runMode: .periodic,
            restartOnAppLaunch: true,
            maxRuntimeSec: nil,
            allowOverlap: false
        ),
        params: [:]
    )
    _ = try await store.upsert(schedule)

    let clock = ManualDateSource(start: Date(timeIntervalSince1970: 1_700_300_000))
    let jobs = MockScheduledJobExecutor()
    let diagnostics = DiagnosticSink()
    let scheduler = JobScheduler(
        scheduleStore: store,
        jobExecutor: jobs,
        onDiagnostic: { message, _, action in
            await diagnostics.append(action: action, message: message)
        },
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    let summary = try await scheduler.runScheduleNow(id: "run-now-1")
    let runningJobID = try #require(summary.runningJobId)
    #expect(runningJobID == "job-1")
    #expect(await jobs.submitCount() == 1)

    let records = await diagnostics.records()
    #expect(records.contains(where: { record in
        record.action == "schedule_run_now" && record.message.contains("dispatched")
    }))
    await scheduler.stop()
}

@Test("JobRunner interrupts scheduled periodic jobs on startup instead of resuming them")
func jobRunnerInterruptsScheduledPeriodicJobsOnStartup() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("job-runner-periodic-interrupt-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: jobsDirectory) }

    let now = Date(timeIntervalSince1970: 1_700_350_000)
    let jobStore = JobStore(jobsDirectory: jobsDirectory)
    let probe = BlockingJobProbe()
    let runner = JobRunner(jobStore: jobStore, nowDate: { now })
    await runner.configure(
        monitorExecutor: nil,
        replayBatchExecutor: nil,
        rssPollExecutor: { job, _ in
            await probe.started(job.jobId)
            return JobExecutionReport()
        },
        newsRetentionExecutor: nil,
        analystSignalsExecutor: { job, _ in
            await probe.started(job.jobId)
            return JobExecutionReport()
        },
        recentNewsAnalystExecutor: nil,
        portfolioRiskAnalystExecutor: nil,
        maintenanceRetentionExecutor: nil
    )

    let queued = JobRecord(
        jobId: "queued-periodic",
        type: .rssPoll,
        createdAt: now.addingTimeInterval(-120),
        updatedAt: now.addingTimeInterval(-60),
        status: .queued,
        progress: 0,
        message: "Queued",
        parameters: [
            "_scheduleId": .string("schedule-a"),
            "_scheduleRunMode": .string(ScheduleRunMode.periodic.rawValue)
        ]
    )
    let running = JobRecord(
        jobId: "running-periodic",
        type: .analystSignals,
        createdAt: now.addingTimeInterval(-90),
        updatedAt: now.addingTimeInterval(-30),
        status: .running,
        progress: 0.5,
        message: "Running",
        parameters: [
            "_scheduleId": .string("schedule-b"),
            "_scheduleRunMode": .string(ScheduleRunMode.periodic.rawValue)
        ]
    )
    try await jobStore.upsert(queued)
    try await jobStore.upsert(running)

    await runner.resumePendingJobsOnStartup()

    let queuedAfter = try await runner.get(jobId: queued.jobId)
    let runningAfter = try await runner.get(jobId: running.jobId)
    #expect(queuedAfter.status == .failed)
    #expect(queuedAfter.error?.code == "job_interrupted")
    #expect(runningAfter.status == .failed)
    #expect(runningAfter.error?.code == "job_interrupted")
    #expect(await probe.startCount() == 0)
}

@Test("Periodic startup reconciliation prevents analyst_signals spawn storm")
func periodicStartupReconciliationPreventsSpawnStorm() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-spawn-storm-jobs-\(UUID().uuidString)", isDirectory: true)
    let scheduleFileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-spawn-storm-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer {
        try? FileManager.default.removeItem(at: jobsDirectory)
        try? FileManager.default.removeItem(at: scheduleFileURL)
    }

    let start = Date(timeIntervalSince1970: 1_700_360_000)
    let clock = ManualDateSource(start: start)
    let jobStore = JobStore(jobsDirectory: jobsDirectory)
    let scheduleStore = ScheduleStore(fileURL: scheduleFileURL)
    let probe = BlockingJobProbe()
    let runner = JobRunner(jobStore: jobStore, nowDate: { clock.now() })
    await runner.configure(
        monitorExecutor: nil,
        replayBatchExecutor: nil,
        rssPollExecutor: nil,
        newsRetentionExecutor: nil,
        analystSignalsExecutor: { job, _ in
            await probe.started(job.jobId)
            do {
                try await Task.sleep(nanoseconds: .max)
                await probe.finished(job.jobId)
                return JobExecutionReport(result: .object(["summary": .string("analyst_signals completed")]))
            } catch is CancellationError {
                await probe.finished(job.jobId)
                throw CancellationError()
            } catch {
                await probe.finished(job.jobId)
                throw error
            }
        },
        recentNewsAnalystExecutor: nil,
        portfolioRiskAnalystExecutor: nil,
        maintenanceRetentionExecutor: nil
    )

    let staleIDs = (1...3).map { "stale-\($0)" }
    for staleID in staleIDs {
        let staleJob = JobRecord(
            jobId: staleID,
            type: .analystSignals,
            createdAt: start.addingTimeInterval(-120),
            updatedAt: start.addingTimeInterval(-30),
            status: .running,
            progress: 0.5,
            message: "Running",
            parameters: [
                "_scheduleId": .string("default-analyst-signals"),
                "_scheduleRunMode": .string(ScheduleRunMode.periodic.rawValue)
            ]
        )
        try await jobStore.upsert(staleJob)
    }

    _ = try await scheduleStore.upsert(
        ScheduledJob(
            scheduleId: "default-analyst-signals",
            jobType: .analystSignals,
            enabled: true,
            trigger: ScheduledJobTrigger(intervalSec: 1),
            policy: ScheduledJobPolicy(
                runMode: .periodic,
                restartOnAppLaunch: true,
                maxRuntimeSec: nil,
                allowOverlap: false,
                startupBehavior: .runImmediately
            ),
            params: [
                "mode": .string("notify_only"),
                "lookbackMinutes": .number(240),
                "minScoreThreshold": .number(0.55)
            ],
            nextRunAt: start.addingTimeInterval(-1),
            runningJobId: staleIDs.first
        )
    )

    await runner.resumePendingJobsOnStartup()
    for staleID in staleIDs {
        let job = try await runner.get(jobId: staleID)
        #expect(job.status == .failed)
        #expect(job.error?.code == "job_interrupted")
    }

    let scheduler = JobScheduler(
        scheduleStore: scheduleStore,
        jobExecutor: runner,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    try await waitUntil(timeout: 120) {
        await probe.startCount() == 1
    }

    for _ in 0..<5 {
        clock.advance(by: 1)
        try await scheduler.tickNow()
    }

    #expect(await probe.startCount() == 1)
    #expect(await probe.maxActiveCount() == 1)

    let jobs = try await runner.list()
    let activeJobs = jobs.filter { $0.status == .queued || $0.status == .running }
    #expect(activeJobs.count == 1)
    #expect(jobs.count == 4)

    let summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.runningJobId != nil)
    #expect(summary.lastRunJobId == summary.runningJobId)

    await scheduler.stop()
    await runner.handleEngineStop()
}

@Test("Disabled periodic schedule does not dispatch after startup reconciliation")
func disabledPeriodicScheduleDoesNotDispatchAfterStartupReconciliation() async throws {
    let jobsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-disabled-periodic-jobs-\(UUID().uuidString)", isDirectory: true)
    let scheduleFileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scheduler-disabled-periodic-\(UUID().uuidString)")
        .appendingPathExtension("json")
    defer {
        try? FileManager.default.removeItem(at: jobsDirectory)
        try? FileManager.default.removeItem(at: scheduleFileURL)
    }

    let start = Date(timeIntervalSince1970: 1_700_370_000)
    let clock = ManualDateSource(start: start)
    let jobStore = JobStore(jobsDirectory: jobsDirectory)
    let scheduleStore = ScheduleStore(fileURL: scheduleFileURL)
    let probe = BlockingJobProbe()
    let runner = JobRunner(jobStore: jobStore, nowDate: { clock.now() })
    await runner.configure(
        monitorExecutor: nil,
        replayBatchExecutor: nil,
        rssPollExecutor: nil,
        newsRetentionExecutor: nil,
        analystSignalsExecutor: { job, _ in
            await probe.started(job.jobId)
            return JobExecutionReport()
        },
        recentNewsAnalystExecutor: nil,
        portfolioRiskAnalystExecutor: nil,
        maintenanceRetentionExecutor: nil
    )

    try await jobStore.upsert(
        JobRecord(
            jobId: "stale-disabled",
            type: .analystSignals,
            createdAt: start.addingTimeInterval(-90),
            updatedAt: start.addingTimeInterval(-30),
            status: .running,
            progress: 0.4,
            message: "Running",
            parameters: [
                "_scheduleId": .string("disabled-analyst-signals"),
                "_scheduleRunMode": .string(ScheduleRunMode.periodic.rawValue)
            ]
        )
    )

    _ = try await scheduleStore.upsert(
        ScheduledJob(
            scheduleId: "disabled-analyst-signals",
            jobType: .analystSignals,
            enabled: false,
            trigger: ScheduledJobTrigger(intervalSec: 1),
            policy: ScheduledJobPolicy(
                runMode: .periodic,
                restartOnAppLaunch: true,
                maxRuntimeSec: nil,
                allowOverlap: false
            ),
            params: [:],
            nextRunAt: start.addingTimeInterval(-1),
            runningJobId: "stale-disabled"
        )
    )

    await runner.resumePendingJobsOnStartup()

    let scheduler = JobScheduler(
        scheduleStore: scheduleStore,
        jobExecutor: runner,
        nowDate: { clock.now() },
        sleep: { _ in
            try? await Task.sleep(nanoseconds: .max)
        },
        tickIntervalSec: 60
    )

    await scheduler.start()
    for _ in 0..<3 {
        clock.advance(by: 1)
        try await scheduler.tickNow()
    }

    #expect(await probe.startCount() == 0)
    let summary = try #require(try await scheduler.listSummaries().first)
    #expect(summary.enabled == false)
    #expect(summary.runningJobId == nil)
    #expect(summary.nextRunAt == nil)

    await scheduler.stop()
}

private final class ManualDateSource: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(start: Date) {
        value = start
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(interval)
        lock.unlock()
    }
}

private actor MockScheduledJobExecutor: ScheduledJobExecuting {
    private var jobsByID: [String: JobRecord] = [:]
    private var nextID = 0
    private var submitCalls = 0

    func submit(type: JobType, parameters: [String: JSONValue]) async throws -> JobRecord {
        nextID += 1
        submitCalls += 1
        let now = Date(timeIntervalSince1970: 1_700_000_000 + Double(nextID))
        let id = "job-\(nextID)"
        let job = JobRecord(
            jobId: id,
            type: type,
            createdAt: now,
            updatedAt: now,
            status: .running,
            progress: 0,
            message: "Running",
            parameters: parameters
        )
        jobsByID[id] = job
        return job
    }

    func get(jobId: String) async throws -> JobRecord {
        guard let job = jobsByID[jobId] else {
            throw JobStoreError.jobNotFound(id: jobId)
        }
        return job
    }

    func cancel(jobId: String) async throws -> JobRecord {
        guard var job = jobsByID[jobId] else {
            throw JobStoreError.jobNotFound(id: jobId)
        }
        job.status = .canceled
        job.updatedAt = job.updatedAt.addingTimeInterval(1)
        jobsByID[jobId] = job
        return job
    }

    func setStatus(
        jobId: String,
        status: JobStatus,
        message: String?,
        result: JSONValue? = nil,
        error: JobErrorInfo?
    ) {
        guard var job = jobsByID[jobId] else {
            return
        }
        job.status = status
        job.message = message
        job.result = result
        job.error = error
        job.updatedAt = job.updatedAt.addingTimeInterval(1)
        jobsByID[jobId] = job
    }

    func seed(job: JobRecord) {
        jobsByID[job.jobId] = job
    }

    func remove(jobId: String) {
        jobsByID.removeValue(forKey: jobId)
    }

    func submitCount() -> Int {
        submitCalls
    }
}

private actor DiagnosticSink {
    struct Record: Sendable {
        let action: String?
        let message: String
    }

    private var values: [Record] = []

    func append(action: String?, message: String) {
        values.append(Record(action: action, message: message))
    }

    func records() -> [Record] {
        values
    }
}

private actor BlockingJobProbe {
    private var startedJobIDs: [String] = []
    private var activeJobIDs: Set<String> = []
    private var maxActive = 0

    func started(_ jobID: String) {
        startedJobIDs.append(jobID)
        activeJobIDs.insert(jobID)
        maxActive = max(maxActive, activeJobIDs.count)
    }

    func finished(_ jobID: String) {
        activeJobIDs.remove(jobID)
    }

    func startCount() -> Int {
        startedJobIDs.count
    }

    func maxActiveCount() -> Int {
        maxActive
    }
}

private func waitUntil(
    timeout: TimeInterval = 1,
    interval: UInt64 = 10_000_000,
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: interval)
    }
    Issue.record("Timed out waiting for condition")
}
