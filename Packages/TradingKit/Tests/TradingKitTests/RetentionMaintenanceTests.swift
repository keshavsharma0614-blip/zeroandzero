import Foundation
import Testing
@testable import TradingKit

@Test("RetentionPolicyStore persists v1 and reads legacy v0")
func retentionPolicyStorePersistsAndLoadsLegacy() async throws {
    let root = makeTempDirectory(name: "retention-policy-store")
    let fileURL = root.appendingPathComponent("retention_policy.json")

    let store = RetentionPolicyStore(fileURL: fileURL)
    let saved = try await store.save(
        RetentionPolicy(
            audit: .init(rotateWhenMB: 20, keepDays: 40),
            news: .init(keepDays: 15),
            jobs: .init(keepDaysCompleted: 10, keepMaxCompletedCount: 250),
            runs: .init(enabled: true, keepDays: 120),
            barsCache: .init(enabled: true, maxDBMB: 512)
        )
    )
    #expect(saved.audit.rotateWhenMB == 20)

    let persisted = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(persisted.contains("\"schemaVersion\" : 1"))

    let legacy = RetentionPolicy(
        audit: .init(rotateWhenMB: 17, keepDays: 99),
        news: .init(keepDays: 9),
        jobs: .init(keepDaysCompleted: 8, keepMaxCompletedCount: 42),
        runs: .init(enabled: false, keepDays: 3650),
        barsCache: .init(enabled: false, maxDBMB: nil)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    try encoder.encode(legacy).write(to: fileURL, options: [.atomic])

    let reloaded = RetentionPolicyStore(fileURL: fileURL)
    let loaded = await reloaded.load()
    #expect(loaded.audit.rotateWhenMB == 17)
    #expect(loaded.jobs.keepMaxCompletedCount == 42)
}

@Test("RetentionPolicyStore unknown schema falls back to defaults with diagnostics")
func retentionPolicyStoreUnknownSchemaFallback() async throws {
    let root = makeTempDirectory(name: "retention-policy-schema")
    let fileURL = root.appendingPathComponent("retention_policy.json")

    let payload = """
    {
      "schemaVersion": 999,
      "policy": {
        "audit": { "rotateWhenMB": 10, "keepDays": 10 },
        "news": { "keepDays": 10 },
        "jobs": { "keepDaysCompleted": 10, "keepMaxCompletedCount": 10 },
        "runs": { "enabled": false, "keepDays": 3650 },
        "barsCache": { "enabled": false, "maxDBMB": null }
      }
    }
    """
    try payload.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = RetentionPolicyStore(fileURL: fileURL)
    let loaded = await store.load()
    #expect(loaded == .default)

    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
}

@Test("Maintenance retention supports dry-run and apply with isolated root")
func maintenanceRetentionDryRunAndApply() async throws {
    let root = makeTempDirectory(name: "maintenance")

    let retentionStore = RetentionPolicyStore(fileURL: root.appendingPathComponent("retention_policy.json"))
    let newsStore = NewsStore(newsDirectory: root.appendingPathComponent("news", isDirectory: true))
    let jobStore = JobStore(jobsDirectory: root.appendingPathComponent("jobs", isDirectory: true))
    let runStore = PaperRunStore(runsDirectory: root.appendingPathComponent("runs", isDirectory: true))
    let barsCache = BarsCache(databaseURL: root.appendingPathComponent("bars_cache.sqlite"))

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let old = now.addingTimeInterval(-60 * 60 * 24 * 90)
    let service = MaintenanceRetentionService(
        policyStore: retentionStore,
        newsStore: newsStore,
        jobStore: jobStore,
        paperRunStore: runStore,
        barsCache: barsCache,
        nowDate: { now },
        rootDirectory: { root },
        recentVisibleJobProtectionLimit: 0
    )

    let currentAuditURL = root.appendingPathComponent("audit_events.jsonl")
    try "{\"ok\":true}\n".write(to: currentAuditURL, atomically: true, encoding: .utf8)

    let oldAuditURL = root.appendingPathComponent("audit_events_2000-01-01_00-00-00.jsonl")
    try "old\n".write(to: oldAuditURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: oldAuditURL.path)

    let recentAuditURL = root.appendingPathComponent("audit_events_2099-01-01_00-00-00.jsonl")
    try "recent\n".write(to: recentAuditURL, atomically: true, encoding: .utf8)

    let oldNewsURL = root
        .appendingPathComponent("news", isDirectory: true)
        .appendingPathComponent("news_events_2020-01-01.jsonl")
    try FileManager.default.createDirectory(at: oldNewsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let oldNewsEvent = makeNewsEvent(id: "news-old", publishedAt: old)
    try writeNewsEventLine(oldNewsEvent, to: oldNewsURL)

    let recentNewsURL = root
        .appendingPathComponent("news", isDirectory: true)
        .appendingPathComponent("news_events_2099-01-01.jsonl")
    let recentNewsEvent = makeNewsEvent(id: "news-new", publishedAt: now)
    try writeNewsEventLine(recentNewsEvent, to: recentNewsURL)

    _ = try await jobStore.upsert(
        JobRecord(
            jobId: "job-old",
            type: .monitor,
            createdAt: old,
            updatedAt: old,
            status: .succeeded,
            progress: 1,
            message: "done",
            parameters: [:]
        )
    )
    _ = try await jobStore.upsert(
        JobRecord(
            jobId: "job-new",
            type: .monitor,
            createdAt: now,
            updatedAt: now,
            status: .succeeded,
            progress: 1,
            message: "done",
            parameters: [:]
        )
    )

    let constraints = StrategyProposalConstraints(maxOrdersPerMinute: 1, maxNotionalPerOrder: 100)
    _ = try await runStore.createRun(
        PaperRunRecord(
            runId: "run-old",
            proposalId: "proposal-1",
            strategyId: "heartbeat",
            startedAt: old,
            endedAt: old,
            status: .stopped,
            stopReason: "done",
            runType: .paper,
            environment: .paper,
            parametersSnapshot: [:],
            constraintsSnapshot: constraints,
            metrics: PaperRunMetrics(lastUpdatedAt: old)
        )
    )
    _ = try await runStore.createRun(
        PaperRunRecord(
            runId: "run-new",
            proposalId: "proposal-1",
            strategyId: "heartbeat",
            startedAt: now,
            endedAt: now,
            status: .stopped,
            stopReason: "done",
            runType: .paper,
            environment: .paper,
            parametersSnapshot: [:],
            constraintsSnapshot: constraints,
            metrics: PaperRunMetrics(lastUpdatedAt: now)
        )
    )

    let policy = RetentionPolicy(
        audit: .init(rotateWhenMB: 25, keepDays: 30),
        news: .init(keepDays: 30),
        jobs: .init(keepDaysCompleted: 30, keepMaxCompletedCount: 10),
        runs: .init(enabled: true, keepDays: 30),
        barsCache: .init(enabled: false, maxDBMB: nil)
    )

    let dryRun = await service.run(policy: policy, dryRun: true)
    #expect(dryRun.areas.contains { $0.area == "news" && $0.deletedCount >= 1 })
    #expect(dryRun.areas.contains { $0.area == "jobs" && $0.deletedCount >= 1 })
    #expect(dryRun.areas.contains { $0.area == "runs" && $0.deletedCount >= 1 })

    #expect(FileManager.default.fileExists(atPath: oldAuditURL.path))
    #expect(FileManager.default.fileExists(atPath: oldNewsURL.path))
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("jobs/job-old.json").path))
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("runs/run-old.json").path))

    let apply = await service.run(policy: policy, dryRun: false)
    #expect(apply.totalBytesFreed >= 0)

    #expect(FileManager.default.fileExists(atPath: oldAuditURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: oldNewsURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("jobs/job-old.json").path) == false)
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("runs/run-old.json").path) == false)

    let outsideRoot = makeTempDirectory(name: "outside-root")
    let outsideFile = outsideRoot.appendingPathComponent("audit_events_1900-01-01_00-00-00.jsonl")
    try "outside".write(to: outsideFile, atomically: true, encoding: .utf8)

    _ = await service.run(policy: policy, dryRun: false)
    #expect(FileManager.default.fileExists(atPath: outsideFile.path))
    await barsCache.close()
}

@Test("Job telemetry cleanup dry-run reports conservative eligibility without deleting files")
func jobTelemetryCleanupDryRunReportsEligibility() async throws {
    let root = makeTempDirectory(name: "job-telemetry-cleanup-dry-run")
    let jobsDirectory = root.appendingPathComponent("jobs", isDirectory: true)
    let store = JobStore(jobsDirectory: jobsDirectory)
    let cutoff = try #require(DateCodec.parseISO8601("2026-04-29T00:00:00Z"))
    let old = try #require(DateCodec.parseISO8601("2026-01-05T00:00:00Z"))
    let recent = try #require(DateCodec.parseISO8601("2026-04-30T00:00:00Z"))

    _ = try await store.upsert(cleanupTestJob(id: "eligible-succeeded", type: .monitor, status: .succeeded, at: old))
    _ = try await store.upsert(cleanupTestJob(id: "eligible-failed", type: .replayBatch, status: .failed, at: old))
    _ = try await store.upsert(cleanupTestJob(id: "eligible-canceled", type: .rssPoll, status: .canceled, at: old))
    _ = try await store.upsert(
        cleanupTestJob(
            id: "eligible-interrupted",
            type: .maintenanceRetention,
            status: .failed,
            at: old,
            error: JobErrorInfo(code: "job_interrupted", message: "interrupted")
        )
    )
    _ = try await store.upsert(cleanupTestJob(id: "recent-completed", type: .monitor, status: .succeeded, at: recent))
    _ = try await store.upsert(cleanupTestJob(id: "running-job", type: .monitor, status: .running, at: old))
    _ = try await store.upsert(cleanupTestJob(id: "queued-job", type: .monitor, status: .queued, at: old))
    _ = try await store.upsert(cleanupTestJob(id: "schedule-running", type: .rssPoll, status: .succeeded, at: old))
    _ = try await store.upsert(
        cleanupTestJob(
            id: "linked-job",
            type: .standingAnalystReport,
            status: .succeeded,
            at: old,
            proposalId: "proposal-current"
        )
    )
    try "not-json".write(
        to: jobsDirectory.appendingPathComponent("corrupt-job.json"),
        atomically: true,
        encoding: .utf8
    )

    let result = try await store.pruneOldTerminalTelemetry(
        before: cutoff,
        protectedJobIDs: ["schedule-running"],
        recentVisibleProtectionLimit: 0,
        dryRun: true
    )

    #expect(result.dryRun == true)
    #expect(result.scannedCount == 10)
    #expect(result.eligibleCount == 4)
    #expect(result.protectedCount == 6)
    #expect(result.skippedDecodeErrorCount == 1)
    #expect(result.skippedLinkedProtectedCount == 1)
    #expect(result.estimatedBytesReclaimable > 0)
    #expect(result.appliedCount == 0)
    #expect(result.candidateCountByStatus["succeeded"] == 1)
    #expect(result.candidateCountByStatus["failed"] == 2)
    #expect(result.candidateCountByStatus["canceled"] == 1)
    #expect(result.candidateCountByType["maintenance_retention"] == 1)
    #expect(result.oldestCandidateTimestamp != nil)
    #expect(result.newestCandidateTimestamp != nil)
    #expect(result.safetyExclusions.contains("queued/running jobs"))
    #expect(FileManager.default.fileExists(atPath: jobsDirectory.appendingPathComponent("eligible-succeeded.json").path))
    #expect(FileManager.default.fileExists(atPath: jobsDirectory.appendingPathComponent("eligible-failed.json").path))
    #expect(try await store.count() == 9)
}

@Test("Job telemetry cleanup apply deletes only eligible files and refreshes active recent cache")
func jobTelemetryCleanupApplyDeletesOnlyEligibleAndRefreshesCache() async throws {
    let root = makeTempDirectory(name: "job-telemetry-cleanup-apply")
    let jobsDirectory = root.appendingPathComponent("jobs", isDirectory: true)
    let scheduleFile = root.appendingPathComponent("schedules.json")
    try "{\"schedules\":[]}".write(to: scheduleFile, atomically: true, encoding: .utf8)
    let store = JobStore(jobsDirectory: jobsDirectory)
    let cutoff = try #require(DateCodec.parseISO8601("2026-04-29T00:00:00Z"))
    let older = try #require(DateCodec.parseISO8601("2026-01-05T00:00:00Z"))
    let visibleOld = try #require(DateCodec.parseISO8601("2026-04-28T00:00:00Z"))

    _ = try await store.upsert(cleanupTestJob(id: "visible-old", type: .monitor, status: .succeeded, at: visibleOld))
    _ = try await store.upsert(cleanupTestJob(id: "eligible-old", type: .monitor, status: .succeeded, at: older))
    _ = try await store.upsert(cleanupTestJob(id: "eligible-failed", type: .rssPoll, status: .failed, at: older))
    _ = try await store.upsert(cleanupTestJob(id: "running-job", type: .monitor, status: .running, at: older))
    _ = try await store.upsert(cleanupTestJob(id: "schedule-running", type: .rssPoll, status: .succeeded, at: older))
    _ = try await store.upsert(
        cleanupTestJob(
            id: "linked-job",
            type: .standingAnalystReport,
            status: .succeeded,
            at: older,
            parameters: ["delegationId": .string("delegation-current")]
        )
    )

    let initialVisible = try await store.listActiveAndRecentSummaries(recentCompletedLimit: 1)
    #expect(initialVisible.contains { $0.jobId == "visible-old" })

    let applied = try await store.pruneOldTerminalTelemetry(
        before: cutoff,
        protectedJobIDs: ["schedule-running"],
        recentVisibleProtectionLimit: 1,
        dryRun: false
    )

    #expect(applied.eligibleCount == 2)
    #expect(applied.appliedCount == 2)
    #expect(try await store.get(id: "eligible-old") == nil)
    #expect(try await store.get(id: "eligible-failed") == nil)
    #expect(try await store.get(id: "visible-old") != nil)
    #expect(try await store.get(id: "running-job") != nil)
    #expect(try await store.get(id: "schedule-running") != nil)
    #expect(try await store.get(id: "linked-job") != nil)
    #expect(FileManager.default.fileExists(atPath: scheduleFile.path))

    let afterVisible = try await store.listActiveAndRecentSummaries(recentCompletedLimit: 1)
    #expect(afterVisible.contains { $0.jobId == "running-job" })
    #expect(afterVisible.contains { $0.jobId == "visible-old" })
    let diagnostics = try await store.summaryProjectionDiagnostics()
    #expect(diagnostics.totalJobsCount == 4)

    let secondApply = try await store.pruneOldTerminalTelemetry(
        before: cutoff,
        protectedJobIDs: ["schedule-running"],
        recentVisibleProtectionLimit: 1,
        dryRun: false
    )
    #expect(secondApply.eligibleCount == 0)
    #expect(secondApply.appliedCount == 0)
    #expect(try await store.count() == 4)
}

@Test("Maintenance job cleanup result includes explicit cutoff details and protects schedule running jobs")
func maintenanceJobCleanupDetailsProtectScheduleRunningJobs() async throws {
    let root = makeTempDirectory(name: "maintenance-job-cleanup-details")
    let retentionStore = RetentionPolicyStore(fileURL: root.appendingPathComponent("retention_policy.json"))
    let newsStore = NewsStore(newsDirectory: root.appendingPathComponent("news", isDirectory: true))
    let jobStore = JobStore(jobsDirectory: root.appendingPathComponent("jobs", isDirectory: true))
    let runStore = PaperRunStore(runsDirectory: root.appendingPathComponent("runs", isDirectory: true))
    let barsCache = BarsCache(databaseURL: root.appendingPathComponent("bars_cache.sqlite"))
    let cutoff = try #require(DateCodec.parseISO8601("2026-04-29T00:00:00Z"))
    let old = try #require(DateCodec.parseISO8601("2026-01-05T00:00:00Z"))
    let scheduleFile = root.appendingPathComponent("schedules.json")
    try "{\"schedules\":[]}".write(to: scheduleFile, atomically: true, encoding: .utf8)

    _ = try await jobStore.upsert(cleanupTestJob(id: "eligible-old", type: .monitor, status: .succeeded, at: old))
    _ = try await jobStore.upsert(cleanupTestJob(id: "schedule-running", type: .rssPoll, status: .succeeded, at: old))

    let service = MaintenanceRetentionService(
        policyStore: retentionStore,
        newsStore: newsStore,
        jobStore: jobStore,
        paperRunStore: runStore,
        barsCache: barsCache,
        nowDate: { cutoff },
        rootDirectory: { root },
        scheduledRunningJobIDs: { ["schedule-running"] },
        recentVisibleJobProtectionLimit: 0
    )

    let dryRun = await service.run(
        policy: .default,
        dryRun: true,
        jobTelemetryCleanupBefore: cutoff
    )
    let jobsArea = try #require(dryRun.areas.first { $0.area == "jobs" })
    #expect(jobsArea.deletedCount == 1)
    let details = try #require(jobsArea.details?.objectValue)
    #expect(details["cleanupKind"] == .string("job_telemetry"))
    #expect(details["cutoffSource"] == .string("explicit"))
    #expect(details["eligibleCount"] == .number(1))
    #expect(details["protectedCount"] == .number(1))
    #expect(details["rootsScanned"]?.arrayValue?.isEmpty == false)

    let apply = await service.run(
        policy: .default,
        dryRun: false,
        jobTelemetryCleanupBefore: cutoff
    )
    let applyJobsArea = try #require(apply.areas.first { $0.area == "jobs" })
    #expect(applyJobsArea.deletedCount == 1)
    #expect(try await jobStore.get(id: "eligible-old") == nil)
    #expect(try await jobStore.get(id: "schedule-running") != nil)
    #expect(FileManager.default.fileExists(atPath: scheduleFile.path))
    await barsCache.close()
}

private func writeNewsEventLine(_ event: NewsEvent, to fileURL: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let json = try encoder.encode(event)
    let line = String(data: json, encoding: .utf8)! + "\n"
    try line.write(to: fileURL, atomically: true, encoding: .utf8)
}

private func cleanupTestJob(
    id: String,
    type: JobType,
    status: JobStatus,
    at timestamp: Date,
    parameters: [String: JSONValue] = [:],
    error: JobErrorInfo? = nil,
    proposalId: String? = nil,
    runId: String? = nil
) -> JobRecord {
    JobRecord(
        jobId: id,
        type: type,
        createdAt: timestamp,
        updatedAt: timestamp,
        status: status,
        progress: status == .succeeded ? 1 : nil,
        message: status.rawValue,
        parameters: parameters,
        result: nil,
        error: error,
        proposalId: proposalId,
        runId: runId
    )
}

private func makeNewsEvent(id: String, publishedAt: Date) -> NewsEvent {
    NewsEvent(
        eventId: id,
        source: "rss_fed",
        title: id,
        url: "https://example.com/\(id)",
        publishedAt: publishedAt,
        receivedAt: publishedAt,
        summary: nil,
        rawSymbolHints: [],
        tags: [],
        payloadVersion: 1
    )
}

private func makeTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
