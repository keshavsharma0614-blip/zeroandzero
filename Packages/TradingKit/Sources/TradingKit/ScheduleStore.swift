import Foundation

public actor ScheduleStore {
    private enum PersistedScheduleError: Error {
        case unsupportedSchemaVersion(Int)
    }

    private struct PersistedSchedulesV1: Codable {
        let schemaVersion: Int
        let schedules: [ScheduledJob]
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL

    private var loaded = false
    private var storeWasMissingAtLoad = false
    private var schedulesByID: [String: ScheduledJob] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("schedules.json", isDirectory: false)
        self.fileManager = fileManager
    }

    public func listSchedules() throws -> [ScheduledJob] {
        try loadIfNeeded()
        return schedulesByID.values.sorted { lhs, rhs in
            if lhs.jobType == rhs.jobType {
                return lhs.scheduleId < rhs.scheduleId
            }
            return lhs.jobType.rawValue < rhs.jobType.rawValue
        }
    }

    public func getSchedule(id: String) throws -> ScheduledJob? {
        try loadIfNeeded()
        return schedulesByID[id]
    }

    @discardableResult
    public func upsert(_ schedule: ScheduledJob) throws -> ScheduledJob {
        try loadIfNeeded()
        var normalized = schedule
        normalized.trigger.intervalSec = max(1, normalized.trigger.intervalSec)
        normalized.policy.maxRuntimeSec = normalized.policy.maxRuntimeSec.map { max(1, $0) }
        normalized.consecutiveFailures = max(0, normalized.consecutiveFailures)
        schedulesByID[normalized.scheduleId] = normalized
        try persistAll()
        return normalized
    }

    public func remove(id: String) throws {
        try loadIfNeeded()
        guard schedulesByID.removeValue(forKey: id) != nil else {
            throw ScheduleStoreError.scheduleNotFound(id: id)
        }
        try persistAll()
    }

    @discardableResult
    public func seedDefaultsIfStoreMissing() throws -> [ScheduledJob] {
        try loadIfNeeded()
        guard storeWasMissingAtLoad, schedulesByID.isEmpty else {
            return try listSchedules()
        }

        let defaults = Self.defaultSchedules
        schedulesByID = Dictionary(uniqueKeysWithValues: defaults.map { ($0.scheduleId, $0) })
        try persistAll()
        return defaults
    }

    @discardableResult
    public func seedMissingDefaults() throws -> [ScheduledJob] {
        try loadIfNeeded()

        var didChange = false
        for schedule in Self.defaultStandingAnalystReportSchedules {
            guard schedulesByID[schedule.scheduleId] == nil else {
                continue
            }
            schedulesByID[schedule.scheduleId] = schedule
            didChange = true
        }

        if didChange {
            try persistAll()
        }
        return try listSchedules()
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else {
            return
        }
        loaded = true

        let storeExists = fileManager.fileExists(atPath: fileURL.path)
        storeWasMissingAtLoad = !storeExists

        guard storeExists else {
            schedulesByID = [:]
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decodeResult = try Self.decodeSchedules(from: data)
            let schedules = decodeResult.schedules
            schedulesByID = Dictionary(uniqueKeysWithValues: schedules.map { ($0.scheduleId, $0) })
            if decodeResult.didMigrateStartupBehavior {
                try persistAll()
            }
        } catch let error as PersistedScheduleError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "schedule persistence skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)"
                )
            }
            schedulesByID = [:]
        } catch {
            loadDiagnostics.append(
                "schedule persistence skipped file=\(fileURL.lastPathComponent) code=invalid_document"
            )
            schedulesByID = [:]
        }
    }

    private func persistAll() throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let wrapped = PersistedSchedulesV1(
            schemaVersion: 1,
            schedules: schedulesByID.values.sorted { $0.scheduleId < $1.scheduleId }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        let data = try encoder.encode(wrapped)
        try data.write(to: fileURL, options: [.atomic])
        storeWasMissingAtLoad = false
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeSchedules(from data: Data) throws -> (
        schedules: [ScheduledJob],
        didMigrateStartupBehavior: Bool
    ) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        let overrides = legacyStartupBehaviorOverrides(from: data)
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PersistedScheduleError.unsupportedSchemaVersion(schemaVersion)
            }
            let schedules = try decoder.decode(PersistedSchedulesV1.self, from: data).schedules
            return (
                schedules.map { applyStartupBehaviorOverride($0, overrides: overrides) },
                !overrides.isEmpty
            )
        }

        // Legacy v0 accepted format: raw array of ScheduledJob.
        let schedules = try decoder.decode([ScheduledJob].self, from: data)
        return (
            schedules.map { applyStartupBehaviorOverride($0, overrides: overrides) },
            !overrides.isEmpty
        )
    }

    private static func legacyStartupBehaviorOverrides(
        from data: Data
    ) -> [String: PeriodicScheduleStartupBehavior] {
        guard let rootObject = try? JSONSerialization.jsonObject(with: data),
              let scheduleObjects = scheduleDictionaries(from: rootObject)
        else {
            return [:]
        }

        var overrides: [String: PeriodicScheduleStartupBehavior] = [:]
        for scheduleObject in scheduleObjects {
            guard let scheduleID = scheduleObject["scheduleId"] as? String,
                  let jobTypeRaw = scheduleObject["jobType"] as? String,
                  let jobType = JobType(rawValue: jobTypeRaw),
                  let policyObject = scheduleObject["policy"] as? [String: Any],
                  policyObject["startupBehavior"] == nil
            else {
                continue
            }

            switch jobType {
            case .rssPoll:
                overrides[scheduleID] = .runImmediately
            default:
                overrides[scheduleID] = .waitForInterval
            }
        }
        return overrides
    }

    private static func scheduleDictionaries(from rootObject: Any) -> [[String: Any]]? {
        if let wrapped = rootObject as? [String: Any],
           let schedules = wrapped["schedules"] as? [[String: Any]] {
            return schedules
        }
        return rootObject as? [[String: Any]]
    }

    private static func applyStartupBehaviorOverride(
        _ schedule: ScheduledJob,
        overrides: [String: PeriodicScheduleStartupBehavior]
    ) -> ScheduledJob {
        guard let startupBehavior = overrides[schedule.scheduleId],
              schedule.policy.runMode == .periodic
        else {
            return schedule
        }
        var migrated = schedule
        migrated.policy.startupBehavior = startupBehavior
        return migrated
    }

    private static let defaultSchedules: [ScheduledJob] = [
        ScheduledJob(
            scheduleId: "default-rss-poll",
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
            params: [
                "maxItemsPerFeed": .number(50)
            ]
        ),
        ScheduledJob(
            scheduleId: "default-analyst-signals",
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
            params: [
                "mode": .string("notify_only"),
                "lookbackMinutes": .number(240),
                "minScoreThreshold": .number(0.55)
            ]
        ),
        ScheduledJob(
            scheduleId: "default-recent-news-analyst",
            jobType: .recentNewsAnalyst,
            enabled: false,
            trigger: ScheduledJobTrigger(intervalSec: 900),
            policy: ScheduledJobPolicy(
                runMode: .periodic,
                restartOnAppLaunch: true,
                maxRuntimeSec: nil,
                allowOverlap: false,
                startupBehavior: .waitForInterval
            ),
            params: [
                "lookbackMinutes": .number(180)
            ]
        ),
        ScheduledJob(
            scheduleId: "default-portfolio-risk-analyst",
            jobType: .portfolioRiskAnalyst,
            enabled: false,
            trigger: ScheduledJobTrigger(intervalSec: 900),
            policy: ScheduledJobPolicy(
                runMode: .periodic,
                restartOnAppLaunch: true,
                maxRuntimeSec: nil,
                allowOverlap: false,
                startupBehavior: .waitForInterval
            ),
            params: [:]
        ),
        ScheduledJob(
            scheduleId: "default-monitor",
            jobType: .monitor,
            enabled: true,
            trigger: ScheduledJobTrigger(intervalSec: 5),
            policy: ScheduledJobPolicy(
                runMode: .alwaysOn,
                restartOnAppLaunch: true,
                maxRuntimeSec: nil,
                allowOverlap: false
            ),
            params: [
                "intervalSec": .number(5)
            ]
        ),
        ScheduledJob(
            scheduleId: "default-maintenance-retention",
            jobType: .maintenanceRetention,
            enabled: true,
            trigger: ScheduledJobTrigger(intervalSec: 86_400),
            policy: ScheduledJobPolicy(
                runMode: .periodic,
                restartOnAppLaunch: true,
                maxRuntimeSec: nil,
                allowOverlap: false,
                startupBehavior: .waitForInterval
            ),
            params: [
                "dryRun": .bool(true)
            ]
        )
    ] + defaultStandingAnalystReportSchedules

    private static let defaultStandingAnalystReportSchedules = makeStandingAnalystReportDefaultSchedules()
}
