import Foundation

public actor MaintenanceRetentionService {
    private let policyStore: RetentionPolicyStore
    private let newsStore: NewsStore
    private let jobStore: JobStore
    private let paperRunStore: PaperRunStore
    private let barsCache: BarsCache
    private let fileManager: FileManager
    private let nowDate: @Sendable () -> Date
    private let rootDirectory: @Sendable () -> URL
    private let scheduledRunningJobIDs: @Sendable () async -> Set<String>
    private let recentVisibleJobProtectionLimit: Int

    public init(
        policyStore: RetentionPolicyStore,
        newsStore: NewsStore,
        jobStore: JobStore,
        paperRunStore: PaperRunStore,
        barsCache: BarsCache,
        fileManager: FileManager = .default,
        nowDate: @escaping @Sendable () -> Date = { Date() },
        rootDirectory: (@Sendable () -> URL)? = nil,
        scheduledRunningJobIDs: (@Sendable () async -> Set<String>)? = nil,
        recentVisibleJobProtectionLimit: Int = 100
    ) {
        self.policyStore = policyStore
        self.newsStore = newsStore
        self.jobStore = jobStore
        self.paperRunStore = paperRunStore
        self.barsCache = barsCache
        self.fileManager = fileManager
        self.nowDate = nowDate
        self.rootDirectory = rootDirectory ?? { AppSupportPaths.rootDirectory() }
        self.scheduledRunningJobIDs = scheduledRunningJobIDs ?? { [] }
        self.recentVisibleJobProtectionLimit = max(0, recentVisibleJobProtectionLimit)
    }

    public func loadPolicy() async -> RetentionPolicy {
        await policyStore.load()
    }

    @discardableResult
    public func savePolicy(_ policy: RetentionPolicy) async throws -> RetentionPolicy {
        try await policyStore.save(policy)
    }

    @discardableResult
    public func resetPolicyToDefaults() async throws -> RetentionPolicy {
        try await policyStore.resetToDefaults()
    }

    public func storageFootprint() async -> StorageFootprintSummary {
        let root = rootDirectory().standardizedFileURL
        let now = nowDate()

        do {
            let audit = try auditBytes(root: root)
            let news = try directoryBytesIfExists(await newsStore.newsDirectoryURL())
            let jobs = try directoryBytesIfExists(await jobStore.jobsDirectoryURL())
            let runs = try directoryBytesIfExists(await paperRunStore.runsDirectoryURL())
            let bars = (try? await barsCache.currentDatabaseFootprintBytes()) ?? 0

            return StorageFootprintSummary(
                rootPath: root.path,
                auditBytes: audit,
                newsBytes: news,
                jobsBytes: jobs,
                runsBytes: runs,
                barsCacheBytes: bars,
                capturedAt: now
            )
        } catch {
            return StorageFootprintSummary.empty(rootPath: root.path, now: now)
        }
    }

    public func run(
        policy: RetentionPolicy,
        dryRun: Bool,
        jobTelemetryCleanupBefore: Date? = nil
    ) async -> MaintenanceRunSummary {
        let startedAt = nowDate()
        let normalizedPolicy = policy.normalized()

        var areas: [MaintenanceAreaResult] = []

        areas.append(runAuditRetention(policy: normalizedPolicy.audit, dryRun: dryRun))

        areas.append(await runNewsRetention(policy: normalizedPolicy.news, dryRun: dryRun))

        areas.append(
            await runJobsRetention(
                policy: normalizedPolicy.jobs,
                dryRun: dryRun,
                explicitCutoff: jobTelemetryCleanupBefore
            )
        )

        areas.append(await runRunsRetention(policy: normalizedPolicy.runs, dryRun: dryRun))

        areas.append(await runBarsCacheRetention(policy: normalizedPolicy.barsCache, dryRun: dryRun))

        return MaintenanceRunSummary(
            dryRun: dryRun,
            startedAt: startedAt,
            finishedAt: nowDate(),
            policy: normalizedPolicy,
            areas: areas
        )
    }

    private func runAuditRetention(
        policy: RetentionPolicy.Audit,
        dryRun: Bool
    ) -> MaintenanceAreaResult {
        let root = rootDirectory().standardizedFileURL
        let currentURL = root
            .appendingPathComponent("audit_events.jsonl", isDirectory: false)
            .standardizedFileURL
        let thresholdBytes = Int64(max(1, policy.rotateWhenMB)) * 1_048_576
        let cutoff = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -max(1, policy.keepDays),
            to: nowDate()
        ) ?? nowDate()

        var scanned = 0
        var deleted = 0
        var bytesFreed: Int64 = 0
        var errors: [String] = []

        guard isPathInsideRoot(currentURL, root: root) else {
            return MaintenanceAreaResult(
                area: "audit",
                scannedCount: 0,
                deletedCount: 0,
                bytesFreed: 0,
                dryRun: dryRun,
                errors: ["audit path is outside app support root"]
            )
        }

        let rotatedPrefix = "audit_events_"
        let rotatedSuffix = ".jsonl"

        do {
            try ensureDirectoryExists(root)
            if fileManager.fileExists(atPath: currentURL.path) {
                scanned += 1
                let currentSize = try fileSize(currentURL)
                if currentSize > thresholdBytes {
                    let rotatedURL = root
                        .appendingPathComponent("\(rotatedPrefix)\(timestampForFileName(nowDate()))\(rotatedSuffix)", isDirectory: false)
                    if isPathInsideRoot(rotatedURL, root: root) {
                        if !dryRun {
                            try? fileManager.removeItem(at: rotatedURL)
                            try fileManager.moveItem(at: currentURL, to: rotatedURL)
                            let created = fileManager.createFile(
                                atPath: currentURL.path,
                                contents: Data(),
                                attributes: [.posixPermissions: 0o600]
                            )
                            if !created {
                                errors.append("failed to recreate audit_events.jsonl after rotation")
                            }
                        }
                    } else {
                        errors.append("rotation destination escaped app support root")
                    }
                }
            }

            let urls = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            for url in urls where url.lastPathComponent.hasPrefix(rotatedPrefix) && url.lastPathComponent.hasSuffix(rotatedSuffix) {
                guard isPathInsideRoot(url, root: root) else {
                    errors.append("skipped external audit file \(url.lastPathComponent)")
                    continue
                }
                scanned += 1
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    ?? auditDateFromFileName(url.lastPathComponent)
                    ?? .distantFuture
                guard modified < cutoff else {
                    continue
                }

                let size = (try? fileSize(url)) ?? 0
                bytesFreed += size
                deleted += 1
                if !dryRun {
                    try? fileManager.removeItem(at: url)
                }
            }
        } catch {
            errors.append("audit retention failure")
        }

        return MaintenanceAreaResult(
            area: "audit",
            scannedCount: scanned,
            deletedCount: deleted,
            bytesFreed: bytesFreed,
            dryRun: dryRun,
            errors: errors
        )
    }

    private func runNewsRetention(
        policy: RetentionPolicy.News,
        dryRun: Bool
    ) async -> MaintenanceAreaResult {
        do {
            let directory = await newsStore.newsDirectoryURL().standardizedFileURL
            let root = rootDirectory().standardizedFileURL
            guard isPathInsideRoot(directory, root: root) else {
                return MaintenanceAreaResult(
                    area: "news",
                    scannedCount: 0,
                    deletedCount: 0,
                    bytesFreed: 0,
                    dryRun: dryRun,
                    errors: ["news path is outside app support root"]
                )
            }

            let scanned = try countDirectoryItems(directory)
            let result = try await newsStore.purge(
                keepDays: max(1, policy.keepDays),
                maxTotalMB: nil,
                dryRun: dryRun
            )
            return MaintenanceAreaResult(
                area: "news",
                scannedCount: scanned,
                deletedCount: result.filesRemoved,
                bytesFreed: result.bytesRemoved,
                dryRun: dryRun
            )
        } catch {
            return MaintenanceAreaResult(
                area: "news",
                scannedCount: 0,
                deletedCount: 0,
                bytesFreed: 0,
                dryRun: dryRun,
                errors: ["news retention failure"]
            )
        }
    }

    private func runJobsRetention(
        policy: RetentionPolicy.Jobs,
        dryRun: Bool,
        explicitCutoff: Date?
    ) async -> MaintenanceAreaResult {
        do {
            let directory = await jobStore.jobsDirectoryURL().standardizedFileURL
            let root = rootDirectory().standardizedFileURL
            guard isPathInsideRoot(directory, root: root) else {
                return MaintenanceAreaResult(
                    area: "jobs",
                    scannedCount: 0,
                    deletedCount: 0,
                    bytesFreed: 0,
                    dryRun: dryRun,
                    errors: ["jobs path is outside app support root"]
                )
            }

            let cutoff = explicitCutoff ?? Calendar(identifier: .gregorian).date(
                byAdding: .day,
                value: -max(1, policy.keepDaysCompleted),
                to: nowDate()
            ) ?? nowDate()
            let result = try await jobStore.pruneOldTerminalTelemetry(
                before: cutoff,
                keepMaxTerminalCount: explicitCutoff == nil ? policy.keepMaxCompletedCount : nil,
                protectedJobIDs: await scheduledRunningJobIDs(),
                recentVisibleProtectionLimit: recentVisibleJobProtectionLimit,
                dryRun: dryRun
            )
            return MaintenanceAreaResult(
                area: "jobs",
                scannedCount: result.scannedCount,
                deletedCount: dryRun ? result.eligibleCount : result.appliedCount,
                bytesFreed: dryRun ? result.estimatedBytesReclaimable : result.appliedBytes,
                dryRun: dryRun,
                errors: result.errors,
                details: jobTelemetryCleanupDetails(
                    result,
                    cutoffSource: explicitCutoff == nil ? "retention_policy" : "explicit"
                )
            )
        } catch {
            return MaintenanceAreaResult(
                area: "jobs",
                scannedCount: 0,
                deletedCount: 0,
                bytesFreed: 0,
                dryRun: dryRun,
                errors: ["jobs retention failure"]
            )
        }
    }

    private func runRunsRetention(
        policy: RetentionPolicy.Runs,
        dryRun: Bool
    ) async -> MaintenanceAreaResult {
        guard policy.enabled else {
            return MaintenanceAreaResult(
                area: "runs",
                scannedCount: 0,
                deletedCount: 0,
                bytesFreed: 0,
                dryRun: dryRun
            )
        }

        do {
            let directory = await paperRunStore.runsDirectoryURL().standardizedFileURL
            let root = rootDirectory().standardizedFileURL
            guard isPathInsideRoot(directory, root: root) else {
                return MaintenanceAreaResult(
                    area: "runs",
                    scannedCount: 0,
                    deletedCount: 0,
                    bytesFreed: 0,
                    dryRun: dryRun,
                    errors: ["runs path is outside app support root"]
                )
            }

            let result = try await paperRunStore.purge(
                keepDays: policy.keepDays,
                dryRun: dryRun,
                now: nowDate()
            )
            return MaintenanceAreaResult(
                area: "runs",
                scannedCount: result.scannedCount,
                deletedCount: result.deletedCount,
                bytesFreed: result.bytesFreed,
                dryRun: dryRun
            )
        } catch {
            return MaintenanceAreaResult(
                area: "runs",
                scannedCount: 0,
                deletedCount: 0,
                bytesFreed: 0,
                dryRun: dryRun,
                errors: ["runs retention failure"]
            )
        }
    }

    private func runBarsCacheRetention(
        policy: RetentionPolicy.BarsCache,
        dryRun: Bool
    ) async -> MaintenanceAreaResult {
        guard policy.enabled, let maxDBMB = policy.maxDBMB else {
            return MaintenanceAreaResult(
                area: "bars_cache",
                scannedCount: 0,
                deletedCount: 0,
                bytesFreed: 0,
                dryRun: dryRun
            )
        }

        do {
            let dbURL = await barsCache.databaseFileURL().standardizedFileURL
            let root = rootDirectory().standardizedFileURL
            guard isPathInsideRoot(dbURL, root: root) else {
                return MaintenanceAreaResult(
                    area: "bars_cache",
                    scannedCount: 0,
                    deletedCount: 0,
                    bytesFreed: 0,
                    dryRun: dryRun,
                    errors: ["bars cache path is outside app support root"]
                )
            }

            let result = try await barsCache.enforceMaxDatabaseSize(
                maxDBMB: maxDBMB,
                dryRun: dryRun
            )
            return MaintenanceAreaResult(
                area: "bars_cache",
                scannedCount: result.scannedCount,
                deletedCount: result.deletedCount,
                bytesFreed: result.bytesFreed,
                dryRun: dryRun
            )
        } catch {
            return MaintenanceAreaResult(
                area: "bars_cache",
                scannedCount: 0,
                deletedCount: 0,
                bytesFreed: 0,
                dryRun: dryRun,
                errors: ["bars cache retention failure"]
            )
        }
    }

    private func jobTelemetryCleanupDetails(
        _ result: JobTelemetryCleanupResult,
        cutoffSource: String
    ) -> JSONValue {
        .object([
            "cleanupKind": .string("job_telemetry"),
            "cutoff": .string(DateCodec.formatISO8601(result.cutoff)),
            "cutoffSource": .string(cutoffSource),
            "rootsScanned": .array(result.rootsScanned.map(JSONValue.string)),
            "scannedCount": .number(Double(result.scannedCount)),
            "eligibleCount": .number(Double(result.eligibleCount)),
            "protectedCount": .number(Double(result.protectedCount)),
            "skippedDecodeErrorCount": .number(Double(result.skippedDecodeErrorCount)),
            "skippedLinkedProtectedCount": .number(Double(result.skippedLinkedProtectedCount)),
            "estimatedBytesReclaimable": .number(Double(result.estimatedBytesReclaimable)),
            "appliedCount": .number(Double(result.appliedCount)),
            "appliedBytes": .number(Double(result.appliedBytes)),
            "candidateCountByStatus": .object(
                result.candidateCountByStatus.mapValues { .number(Double($0)) }
            ),
            "candidateCountByType": .object(
                result.candidateCountByType.mapValues { .number(Double($0)) }
            ),
            "oldestCandidateTimestamp": result.oldestCandidateTimestamp
                .map { .string(DateCodec.formatISO8601($0)) } ?? .null,
            "newestCandidateTimestamp": result.newestCandidateTimestamp
                .map { .string(DateCodec.formatISO8601($0)) } ?? .null,
            "safetyExclusions": .array(result.safetyExclusions.map(JSONValue.string))
        ])
    }

    private func ensureDirectoryExists(_ directory: URL) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func isPathInsideRoot(_ url: URL, root: URL) -> Bool {
        let normalizedRoot = root.standardizedFileURL.path
        let normalizedURL = url.standardizedFileURL.path
        return normalizedURL == normalizedRoot || normalizedURL.hasPrefix(normalizedRoot + "/")
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func auditBytes(root: URL) throws -> Int64 {
        let urls = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        var total: Int64 = 0
        for url in urls where url.lastPathComponent.hasPrefix("audit_events") && url.pathExtension.lowercased() == "jsonl" {
            total += (try? fileSize(url)) ?? 0
        }
        return total
    }

    private func directoryBytesIfExists(_ directory: URL) throws -> Int64 {
        let normalized = directory.standardizedFileURL
        guard fileManager.fileExists(atPath: normalized.path) else {
            return 0
        }
        return try directoryBytes(normalized)
    }

    private func directoryBytes(_ directory: URL) throws -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    private func countDirectoryItems(_ directory: URL) throws -> Int {
        guard fileManager.fileExists(atPath: directory.path) else {
            return 0
        }
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls.count
    }

    private func timestampForFileName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }

    private func auditDateFromFileName(_ value: String) -> Date? {
        guard value.hasPrefix("audit_events_"), value.hasSuffix(".jsonl") else {
            return nil
        }
        let raw = String(
            value
                .dropFirst("audit_events_".count)
                .dropLast(".jsonl".count)
        )
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.date(from: raw)
    }
}
