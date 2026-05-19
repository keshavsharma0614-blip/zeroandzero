import Foundation

public actor JobStore {
    private enum PersistedJobError: Error {
        case unsupportedSchemaVersion(Int)
    }

    private struct PersistedJobV1: Codable {
        let schemaVersion: Int
        let job: JobRecord
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private struct CleanupCandidate {
        let job: JobRecord
        let fileURL: URL
        let byteCount: Int64
    }

    private let fileManager: FileManager
    private let jobsDirectory: URL
    private var loaded = false
    private var jobsByID: [String: JobRecord] = [:]
    private var loadDiagnostics: [String] = []
    private var summaryCacheInitialized = false
    private var summaryCacheRecentCompletedLimit = 0
    private var activeSummaryCacheByID: [String: JobSummary] = [:]
    private var recentCompletedSummaryCache: [JobSummary] = []
    private var summaryProjectionDiagnosticState = JobSummaryProjectionDiagnostics()

    public init(
        jobsDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.jobsDirectory = jobsDirectory
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("jobs", isDirectory: true)
        self.fileManager = fileManager
    }

    public func loadAll() throws -> [JobRecord] {
        try loadIfNeeded()
        return jobsByID.values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.jobId < rhs.jobId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public func list(
        status: JobStatus? = nil,
        type: JobType? = nil
    ) throws -> [JobSummary] {
        try loadAll()
            .filter { record in
                if let status, record.status != status {
                    return false
                }
                if let type, record.type != type {
                    return false
                }
                return true
            }
            .map(\.summary)
    }

    public func listActiveAndRecentSummaries(
        recentCompletedLimit: Int
    ) throws -> [JobSummary] {
        try loadIfNeeded()
        let resolvedRecentCompletedLimit = max(0, recentCompletedLimit)
        summaryProjectionDiagnosticState.listRequestCount += 1
        if !summaryCacheInitialized ||
            resolvedRecentCompletedLimit > summaryCacheRecentCompletedLimit {
            rebuildSummaryCache(recentCompletedLimit: resolvedRecentCompletedLimit)
        } else {
            summaryProjectionDiagnosticState.cacheHitCount += 1
        }

        return visibleSummaryCache(recentCompletedLimit: resolvedRecentCompletedLimit)
    }

    public func count() throws -> Int {
        try loadIfNeeded()
        return jobsByID.count
    }

    public func get(id: String) throws -> JobRecord? {
        try loadIfNeeded()
        return jobsByID[id]
    }

    public func summaryProjectionDiagnostics() throws -> JobSummaryProjectionDiagnostics {
        try loadIfNeeded()
        summaryProjectionDiagnosticState.totalJobsCount = jobsByID.count
        return summaryProjectionDiagnosticState
    }

    @discardableResult
    public func upsert(_ job: JobRecord) throws -> JobRecord {
        try loadIfNeeded()
        jobsByID[job.jobId] = job
        try persist(job)
        updateSummaryCacheAfterUpsert(job)
        return job
    }

    public func delete(id: String) throws {
        try loadIfNeeded()
        guard jobsByID.removeValue(forKey: id) != nil else {
            throw JobStoreError.jobNotFound(id: id)
        }
        let fileURL = jobsDirectory
            .appendingPathComponent(id)
            .appendingPathExtension("json")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        if summaryCacheInitialized {
            rebuildSummaryCache(recentCompletedLimit: summaryCacheRecentCompletedLimit)
        }
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    public func jobsDirectoryURL() -> URL {
        jobsDirectory
    }

    private func insertRecentCompletedSummary(
        _ summary: JobSummary,
        into summaries: inout [JobSummary],
        limit: Int
    ) {
        let insertionIndex = summaries.firstIndex { existing in
            JobStore.sortJobSummaries(summary, existing)
        } ?? summaries.endIndex
        summaries.insert(summary, at: insertionIndex)
        if summaries.count > limit {
            summaries.removeLast(summaries.count - limit)
        }
    }

    private static func sortJobSummaries(_ lhs: JobSummary, _ rhs: JobSummary) -> Bool {
        if lhs.updatedAt == rhs.updatedAt {
            return lhs.jobId < rhs.jobId
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    public func purgeCompleted(
        keepDays: Int,
        keepMaxCompletedCount: Int?,
        dryRun: Bool,
        now: Date
    ) throws -> RetentionSweepResult {
        let resolvedKeepDays = max(1, keepDays)
        let cutoff = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -resolvedKeepDays,
            to: now
        ) ?? now
        let result = try pruneOldTerminalTelemetry(
            before: cutoff,
            keepMaxTerminalCount: keepMaxCompletedCount,
            protectedJobIDs: [],
            recentVisibleProtectionLimit: 0,
            dryRun: dryRun
        )
        return RetentionSweepResult(
            scannedCount: result.scannedCount,
            deletedCount: dryRun ? result.eligibleCount : result.appliedCount,
            bytesFreed: dryRun ? result.estimatedBytesReclaimable : result.appliedBytes
        )
    }

    public func pruneOldTerminalTelemetry(
        before cutoff: Date,
        keepMaxTerminalCount: Int? = nil,
        protectedJobIDs: Set<String> = [],
        recentVisibleProtectionLimit: Int = 100,
        dryRun: Bool
    ) throws -> JobTelemetryCleanupResult {
        try loadIfNeeded()

        let rootsScanned = [jobsDirectory.standardizedFileURL.path]
        let protectedVisibleIDs = try recentVisibleProtectedJobIDs(
            limit: recentVisibleProtectionLimit
        )
        let safetyExclusions = [
            "queued/running jobs",
            "schedule runningJobId jobs",
            "bounded active+recent visible job summaries",
            "proposal/run/PM/analyst linked jobs",
            "jobs updated on or after cutoff",
            "corrupt or undecodable job files"
        ]

        guard fileManager.fileExists(atPath: jobsDirectory.path) else {
            return JobTelemetryCleanupResult(
                dryRun: dryRun,
                cutoff: cutoff,
                rootsScanned: rootsScanned,
                safetyExclusions: safetyExclusions
            )
        }

        let urls = try fileManager.contentsOfDirectory(
            at: jobsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var scanned = 0
        var decodeErrors = 0
        var protected = 0
        var linkedProtected = 0
        var candidatesByID: [String: CleanupCandidate] = [:]
        var errors: [String] = []

        for url in urls where url.pathExtension.lowercased() == "json" {
            scanned += 1
            let data: Data
            let job: JobRecord
            do {
                data = try Data(contentsOf: url)
                job = try Self.decodePersistedJob(from: data)
            } catch {
                decodeErrors += 1
                protected += 1
                continue
            }

            let size = (try? fileSize(url)) ?? Int64(data.count)
            if let reason = protectionReason(
                for: job,
                cutoff: cutoff,
                protectedJobIDs: protectedJobIDs,
                protectedVisibleIDs: protectedVisibleIDs
            ) {
                protected += 1
                if reason == "linked_artifact" {
                    linkedProtected += 1
                }
                continue
            }

            candidatesByID[job.jobId] = CleanupCandidate(
                job: job,
                fileURL: url,
                byteCount: size
            )
        }

        let candidates = candidatesByID.values.sorted { lhs, rhs in
            if lhs.job.updatedAt == rhs.job.updatedAt {
                return lhs.job.jobId < rhs.job.jobId
            }
            return lhs.job.updatedAt < rhs.job.updatedAt
        }
        let estimatedBytes = candidates.reduce(Int64(0)) { $0 + max(0, $1.byteCount) }
        var appliedCount = 0
        var appliedBytes: Int64 = 0

        if !dryRun {
            for candidate in candidates {
                do {
                    if fileManager.fileExists(atPath: candidate.fileURL.path) {
                        try fileManager.removeItem(at: candidate.fileURL)
                    }
                    jobsByID.removeValue(forKey: candidate.job.jobId)
                    appliedCount += 1
                    appliedBytes += max(0, candidate.byteCount)
                } catch {
                    errors.append("job cleanup failed file=\(candidate.fileURL.lastPathComponent)")
                }
            }

            if summaryCacheInitialized {
                rebuildSummaryCache(recentCompletedLimit: summaryCacheRecentCompletedLimit)
            }
        }

        return JobTelemetryCleanupResult(
            dryRun: dryRun,
            cutoff: cutoff,
            rootsScanned: rootsScanned,
            scannedCount: scanned,
            eligibleCount: candidates.count,
            protectedCount: protected,
            skippedDecodeErrorCount: decodeErrors,
            skippedLinkedProtectedCount: linkedProtected,
            estimatedBytesReclaimable: estimatedBytes,
            appliedCount: appliedCount,
            appliedBytes: appliedBytes,
            candidateCountByStatus: countCandidatesByStatus(candidates),
            candidateCountByType: countCandidatesByType(candidates),
            oldestCandidateTimestamp: candidates.map(\.job.updatedAt).min(),
            newestCandidateTimestamp: candidates.map(\.job.updatedAt).max(),
            safetyExclusions: safetyExclusions,
            errors: errors
        )
    }

    private func rebuildSummaryCache(recentCompletedLimit: Int) {
        let resolvedRecentCompletedLimit = max(0, recentCompletedLimit)
        summaryProjectionDiagnosticState.fullScanCount += 1
        summaryProjectionDiagnosticState.lastScannedCount = jobsByID.count
        summaryCacheInitialized = true
        summaryCacheRecentCompletedLimit = resolvedRecentCompletedLimit
        activeSummaryCacheByID.removeAll(keepingCapacity: true)
        recentCompletedSummaryCache.removeAll(keepingCapacity: true)

        for record in jobsByID.values {
            updateSummaryCache(record.summary, status: record.status)
        }
        refreshSummaryProjectionDiagnosticCounts()
    }

    private func updateSummaryCacheAfterUpsert(_ job: JobRecord) {
        guard summaryCacheInitialized else {
            return
        }
        summaryProjectionDiagnosticState.incrementalUpdateCount += 1
        summaryProjectionDiagnosticState.lastScannedCount = 1
        updateSummaryCache(job.summary, status: job.status)
        refreshSummaryProjectionDiagnosticCounts()
    }

    private func updateSummaryCache(
        _ summary: JobSummary,
        status: JobStatus
    ) {
        activeSummaryCacheByID.removeValue(forKey: summary.jobId)
        recentCompletedSummaryCache.removeAll { $0.jobId == summary.jobId }

        if status == .queued || status == .running {
            activeSummaryCacheByID[summary.jobId] = summary
            return
        }

        guard summaryCacheRecentCompletedLimit > 0,
              Self.completedStatuses.contains(status)
        else {
            return
        }

        insertRecentCompletedSummary(
            summary,
            into: &recentCompletedSummaryCache,
            limit: summaryCacheRecentCompletedLimit
        )
    }

    private func visibleSummaryCache(recentCompletedLimit: Int) -> [JobSummary] {
        let resolvedRecentCompletedLimit = max(0, recentCompletedLimit)
        let activeSummaries = Array(activeSummaryCacheByID.values)
        let recentCompletedSummaries = Array(
            recentCompletedSummaryCache.prefix(resolvedRecentCompletedLimit)
        )
        let output = (activeSummaries + recentCompletedSummaries)
            .sorted(by: JobStore.sortJobSummaries)
        summaryProjectionDiagnosticState.visibleCap = resolvedRecentCompletedLimit
        summaryProjectionDiagnosticState.visibleCount = output.count
        summaryProjectionDiagnosticState.totalJobsCount = jobsByID.count
        summaryProjectionDiagnosticState.lastOutputCount = output.count
        return output
    }

    private func recentVisibleProtectedJobIDs(limit: Int) throws -> Set<String> {
        guard limit > 0 else {
            return []
        }
        return Set(
            try listActiveAndRecentSummaries(recentCompletedLimit: limit)
                .map(\.jobId)
        )
    }

    private func protectionReason(
        for job: JobRecord,
        cutoff: Date,
        protectedJobIDs: Set<String>,
        protectedVisibleIDs: Set<String>
    ) -> String? {
        if protectedJobIDs.contains(job.jobId) {
            return "schedule_running"
        }
        if job.status == .queued || job.status == .running {
            return "active_status"
        }
        guard Self.completedStatuses.contains(job.status) else {
            return "non_terminal_status"
        }
        if job.updatedAt >= cutoff {
            return "recent"
        }
        if protectedVisibleIDs.contains(job.jobId) {
            return "recent_visible"
        }
        if hasProtectedArtifactLinkage(job) {
            return "linked_artifact"
        }
        return nil
    }

    private func hasProtectedArtifactLinkage(_ job: JobRecord) -> Bool {
        if job.proposalId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }
        if job.runId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }

        let protectedKeys: Set<String> = [
            "approvalid",
            "approvalrequestid",
            "analystid",
            "analysttaskid",
            "charterid",
            "decisionid",
            "delegationid",
            "evidencebundleid",
            "findingid",
            "followupdelegationid",
            "memoid",
            "pmapprovalrequestid",
            "pmdecisionid",
            "pmdelegationid",
            "proposalid",
            "reportid",
            "runid",
            "sourcedelegationid",
            "standinganalystreportid",
            "standingreportid",
            "taskid"
        ]
        return job.parameters.keys.contains { rawKey in
            let normalized = rawKey
                .lowercased()
                .filter { $0.isLetter || $0.isNumber }
            return protectedKeys.contains(normalized)
        }
    }

    private func countCandidatesByStatus(
        _ candidates: [CleanupCandidate]
    ) -> [String: Int] {
        candidates.reduce(into: [:]) { counts, candidate in
            counts[candidate.job.status.rawValue, default: 0] += 1
        }
    }

    private func countCandidatesByType(
        _ candidates: [CleanupCandidate]
    ) -> [String: Int] {
        candidates.reduce(into: [:]) { counts, candidate in
            counts[candidate.job.type.rawValue, default: 0] += 1
        }
    }

    private func refreshSummaryProjectionDiagnosticCounts() {
        summaryProjectionDiagnosticState.visibleCap = summaryCacheRecentCompletedLimit
        summaryProjectionDiagnosticState.visibleCount =
            activeSummaryCacheByID.count + recentCompletedSummaryCache.count
        summaryProjectionDiagnosticState.totalJobsCount = jobsByID.count
        summaryProjectionDiagnosticState.lastOutputCount =
            activeSummaryCacheByID.count + recentCompletedSummaryCache.count
    }

    private func loadIfNeeded() throws {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: jobsDirectory.path) else {
            jobsByID = [:]
            return
        }

        let urls = try fileManager.contentsOfDirectory(
            at: jobsDirectory,
            includingPropertiesForKeys: nil
        )
        var loadedJobs: [String: JobRecord] = [:]
        for url in urls where url.pathExtension.lowercased() == "json" {
            do {
                let data = try Data(contentsOf: url)
                let job = try Self.decodePersistedJob(from: data)
                loadedJobs[job.jobId] = job
            } catch let error as PersistedJobError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append(
                        "job persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)"
                    )
                }
            } catch {
                loadDiagnostics.append(
                    "job persistence skipped file=\(url.lastPathComponent) code=invalid_document"
                )
            }
        }
        jobsByID = loadedJobs
    }

    private func persist(_ job: JobRecord) throws {
        try fileManager.createDirectory(
            at: jobsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let fileURL = jobsDirectory
            .appendingPathComponent(job.jobId)
            .appendingPathExtension("json")
        let wrapped = PersistedJobV1(
            schemaVersion: 1,
            job: job
        )
        let data = try Self.makeEncoder().encode(wrapped)
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return decoder
    }

    private static func decodePersistedJob(from data: Data) throws -> JobRecord {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PersistedJobError.unsupportedSchemaVersion(schemaVersion)
            }
            return try makeDecoder().decode(PersistedJobV1.self, from: data).job
        }

        // Legacy v0 format stores raw JobRecord JSON.
        return try makeDecoder().decode(JobRecord.self, from: data)
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static let completedStatuses: Set<JobStatus> = [
        .succeeded,
        .failed,
        .canceled
    ]

}
