import Foundation

public enum AnalystCharterStoreError: Error, Sendable, Equatable {
    case charterNotFound(id: String)
}

public enum AnalystTaskStoreError: Error, Sendable, Equatable {
    case taskNotFound(id: String)
}

public enum AnalystSourceAccessSuggestionStoreError: Error, Sendable, Equatable {
    case suggestionNotFound(id: String)
}

public enum AnalystFindingStoreError: Error, Sendable, Equatable {
    case findingNotFound(id: String)
}

public enum AnalystEvidenceBundleStoreError: Error, Sendable, Equatable {
    case bundleNotFound(id: String)
}

public enum AnalystMemoStoreError: Error, Sendable, Equatable {
    case memoNotFound(id: String)
}

public enum AnalystStandingReportStoreError: Error, Sendable, Equatable {
    case reportNotFound(id: String)
}

public enum AnalystScopedMemoryStoreError: Error, Sendable, Equatable {
    case memoryNotFound(id: String)
}

public enum StandingBenchAnalystRuntimeSettingsStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

private enum PersistedAnalystDocumentError: Error {
    case unsupportedSchemaVersion(Int)
}

private struct PersistedSchemaProbe: Decodable {
    let schemaVersion: Int?
}

private enum AnalystPersistencePaths {
    static func analystRoot() -> URL {
        AppSupportPaths.rootDirectory()
            .appendingPathComponent("analyst", isDirectory: true)
    }

    static func chartersDirectory() -> URL {
        analystRoot().appendingPathComponent("charters", isDirectory: true)
    }

    static func tasksDirectory() -> URL {
        analystRoot().appendingPathComponent("tasks", isDirectory: true)
    }

    static func sourceAccessSuggestionsDirectory() -> URL {
        analystRoot().appendingPathComponent("source_access_suggestions", isDirectory: true)
    }

    static func findingsDirectory() -> URL {
        analystRoot().appendingPathComponent("findings", isDirectory: true)
    }

    static func evidenceDirectory() -> URL {
        analystRoot().appendingPathComponent("evidence", isDirectory: true)
    }

    static func memosDirectory() -> URL {
        analystRoot().appendingPathComponent("memos", isDirectory: true)
    }

    static func standingReportsDirectory() -> URL {
        analystRoot().appendingPathComponent("standing_reports", isDirectory: true)
    }

    static func memoryDirectory() -> URL {
        analystRoot().appendingPathComponent("memory", isDirectory: true)
    }

    static func recentNewsReviewStateFile() -> URL {
        analystRoot().appendingPathComponent("recent_news_review_state.json", isDirectory: false)
    }

    static func portfolioRiskTriggerReviewStateFile() -> URL {
        analystRoot().appendingPathComponent("portfolio_risk_trigger_review_state.json", isDirectory: false)
    }

    static func recentNewsRuntimeSettingsFile() -> URL {
        analystRoot().appendingPathComponent("recent_news_runtime_settings.json", isDirectory: false)
    }

    static func standingBenchRuntimeSettingsFile() -> URL {
        analystRoot().appendingPathComponent("standing_bench_runtime_settings.json", isDirectory: false)
    }
}

public actor AnalystCharterStore {
    private struct PersistedCharterV1: Codable {
        let schemaVersion: Int
        let charter: AnalystCharter
    }

    private let fileManager: FileManager
    private let chartersDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var chartersByID: [String: AnalystCharter] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        chartersDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.chartersDirectory = chartersDirectory ?? AnalystPersistencePaths.chartersDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystCharter] {
        try loadIfNeeded()
        return sorted(chartersByID.values)
    }

    public func get(id: String) throws -> AnalystCharter? {
        try loadIfNeeded()
        return chartersByID[id]
    }

    @discardableResult
    public func upsert(_ charter: AnalystCharter) throws -> AnalystCharter {
        try loadIfNeeded()
        let charterID = normalizedID(charter.charterId)
        let existing = chartersByID[charterID]
        if let existing, shouldIgnoreIncomingSystemSeed(charter, existing: existing) {
            loadDiagnostics.append("analyst charter persistence kept_existing_charter code=ignored_system_seed_overwrite")
            return existing
        }
        var updated = protectedIncomingCharter(charter, existing: existing)
        updated.charterId = charterID
        updated.createdAt = existing?.createdAt ?? charter.createdAt
        updated.updatedAt = now()
        chartersByID[charterID] = updated
        try persist(updated)
        return updated
    }

    @discardableResult
    public func remove(id: String) throws -> Bool {
        try loadIfNeeded()
        let charterID = normalizedID(id)
        guard chartersByID.removeValue(forKey: charterID) != nil else {
            return false
        }

        let fileURL = chartersDirectory.appendingPathComponent(charterID).appendingPathExtension("json")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        return true
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: chartersDirectory.path) else {
            chartersByID = [:]
            return
        }

        var loadedCharters: [String: AnalystCharter] = [:]
        for url in try jsonFiles(in: chartersDirectory, fileManager: fileManager) {
            do {
                let charter = try Self.decodePersistedCharter(from: Data(contentsOf: url))
                loadedCharters[charter.charterId] = charter
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst charter persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst charter persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        chartersByID = loadedCharters
    }

    private func persist(_ charter: AnalystCharter) throws {
        try createProtectedDirectory(at: chartersDirectory, fileManager: fileManager)
        let fileURL = chartersDirectory.appendingPathComponent(charter.charterId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedCharterV1(schemaVersion: 1, charter: charter))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func protectedIncomingCharter(
        _ incoming: AnalystCharter,
        existing: AnalystCharter?
    ) -> AnalystCharter {
        guard let existing else { return incoming }

        var protected = incoming
        let incomingDocumentBody = incoming.documentBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let existingDocumentBody = existing.documentBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Preserve the current saved long-form charter when a later sparse update omits the body.
        if incomingDocumentBody.isEmpty, existingDocumentBody.isEmpty == false {
            protected.documentBody = existing.documentBody
        }

        // Older/sparse charter update paths know nothing about Agent Skills. Preserve
        // existing references unless the owner UI explicitly saves an empty set.
        if incoming.skillReferences.isEmpty,
           existing.skillReferences.isEmpty == false,
           incoming.updateSource != .userEdited {
            protected.skillReferences = existing.skillReferences
        }

        return protected
    }

    private func shouldIgnoreIncomingSystemSeed(
        _ incoming: AnalystCharter,
        existing: AnalystCharter
    ) -> Bool {
        incoming.updateSource == .systemSeed && canSystemSeedReplace(existing) == false
    }

    private func canSystemSeedReplace(_ charter: AnalystCharter) -> Bool {
        if charter.updateSource == .systemSeed {
            return true
        }

        if charter.updateSource == .userEdited {
            return false
        }

        let hasDocumentBody = charter.documentBody?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false

        let isStandingBenchCharter = StandingAnalystBenchSeed.definitions.contains { definition in
            definition.charterId == charter.charterId
        }

        if hasDocumentBody == false, isStandingBenchCharter {
            return true
        }

        return hasDocumentBody == false && charter.benchRole != nil
    }

    private func sorted(_ values: Dictionary<String, AnalystCharter>.Values) -> [AnalystCharter] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.charterId < rhs.charterId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedCharter(from data: Data) throws -> AnalystCharter {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedCharterV1.self, from: data).charter
        }
        return try makeDecoder().decode(AnalystCharter.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public actor AnalystSourceAccessSuggestionStore {
    private struct PersistedSuggestionV1: Codable {
        let schemaVersion: Int
        let suggestion: AnalystSourceAccessSuggestionRecord
    }

    private let fileManager: FileManager
    private let suggestionsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var suggestionsByID: [String: AnalystSourceAccessSuggestionRecord] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        suggestionsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.suggestionsDirectory = suggestionsDirectory ?? AnalystPersistencePaths.sourceAccessSuggestionsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystSourceAccessSuggestionRecord] {
        try loadIfNeeded()
        return sorted(suggestionsByID.values)
    }

    public func get(id: String) throws -> AnalystSourceAccessSuggestionRecord? {
        try loadIfNeeded()
        return suggestionsByID[id]
    }

    @discardableResult
    public func upsert(_ suggestion: AnalystSourceAccessSuggestionRecord) throws -> AnalystSourceAccessSuggestionRecord {
        try loadIfNeeded()
        let suggestionID = normalizedID(suggestion.suggestionId)
        let existing = suggestionsByID[suggestionID]
        var updated = suggestion
        updated.suggestionId = suggestionID
        updated.createdAt = existing?.createdAt ?? suggestion.createdAt
        updated.updatedAt = now()
        suggestionsByID[suggestionID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: suggestionsDirectory.path) else {
            suggestionsByID = [:]
            return
        }

        var loadedSuggestions: [String: AnalystSourceAccessSuggestionRecord] = [:]
        for url in try jsonFiles(in: suggestionsDirectory, fileManager: fileManager) {
            do {
                let suggestion = try Self.decodePersistedSuggestion(from: Data(contentsOf: url))
                loadedSuggestions[suggestion.suggestionId] = suggestion
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst source suggestion persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst source suggestion persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        suggestionsByID = loadedSuggestions
    }

    private func persist(_ suggestion: AnalystSourceAccessSuggestionRecord) throws {
        try createProtectedDirectory(at: suggestionsDirectory, fileManager: fileManager)
        let fileURL = suggestionsDirectory.appendingPathComponent(suggestion.suggestionId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedSuggestionV1(schemaVersion: 1, suggestion: suggestion))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystSourceAccessSuggestionRecord>.Values) -> [AnalystSourceAccessSuggestionRecord] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.suggestionId < rhs.suggestionId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedSuggestion(from data: Data) throws -> AnalystSourceAccessSuggestionRecord {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedSuggestionV1.self, from: data).suggestion
        }
        return try makeDecoder().decode(AnalystSourceAccessSuggestionRecord.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public actor AnalystTaskStore {
    private struct PersistedTaskV1: Codable {
        let schemaVersion: Int
        let task: AnalystTask
    }

    private let fileManager: FileManager
    private let tasksDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var tasksByID: [String: AnalystTask] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        tasksDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.tasksDirectory = tasksDirectory ?? AnalystPersistencePaths.tasksDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystTask] {
        try loadIfNeeded()
        return sorted(tasksByID.values)
    }

    public func get(id: String) throws -> AnalystTask? {
        try loadIfNeeded()
        return tasksByID[id]
    }

    @discardableResult
    public func upsert(_ task: AnalystTask) throws -> AnalystTask {
        try loadIfNeeded()
        let taskID = normalizedID(task.taskId)
        let existing = tasksByID[taskID]
        var updated = task
        updated.taskId = taskID
        updated.createdAt = existing?.createdAt ?? task.createdAt
        updated.updatedAt = now()
        if var checkpoint = updated.checkpoint {
            checkpoint.taskId = taskID
            checkpoint.analystId = updated.analystId
            checkpoint.charterId = updated.charterId
            updated.checkpoint = checkpoint
            updated.lastCheckpointSummary = checkpoint.summary
        }
        tasksByID[taskID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: tasksDirectory.path) else {
            tasksByID = [:]
            return
        }

        var loadedTasks: [String: AnalystTask] = [:]
        for url in try jsonFiles(in: tasksDirectory, fileManager: fileManager) {
            do {
                let task = try Self.decodePersistedTask(from: Data(contentsOf: url))
                loadedTasks[task.taskId] = task
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst task persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst task persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        tasksByID = loadedTasks
    }

    private func persist(_ task: AnalystTask) throws {
        try createProtectedDirectory(at: tasksDirectory, fileManager: fileManager)
        let fileURL = tasksDirectory.appendingPathComponent(task.taskId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedTaskV1(schemaVersion: 1, task: task))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystTask>.Values) -> [AnalystTask] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.taskId < rhs.taskId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedTask(from data: Data) throws -> AnalystTask {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedTaskV1.self, from: data).task
        }
        return try makeDecoder().decode(AnalystTask.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public actor AnalystFindingStore {
    private struct PersistedFindingV1: Codable {
        let schemaVersion: Int
        let finding: AnalystFinding
    }

    private let fileManager: FileManager
    private let findingsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var findingsByID: [String: AnalystFinding] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        findingsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.findingsDirectory = findingsDirectory ?? AnalystPersistencePaths.findingsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystFinding] {
        try loadIfNeeded()
        return sorted(findingsByID.values)
    }

    public func get(id: String) throws -> AnalystFinding? {
        try loadIfNeeded()
        return findingsByID[id]
    }

    @discardableResult
    public func upsert(_ finding: AnalystFinding) throws -> AnalystFinding {
        try loadIfNeeded()
        let findingID = normalizedID(finding.findingId)
        let existing = findingsByID[findingID]
        var updated = finding
        updated.findingId = findingID
        updated.createdAt = existing?.createdAt ?? finding.createdAt
        updated.updatedAt = now()
        findingsByID[findingID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: findingsDirectory.path) else {
            findingsByID = [:]
            return
        }

        var loadedFindings: [String: AnalystFinding] = [:]
        for url in try jsonFiles(in: findingsDirectory, fileManager: fileManager) {
            do {
                let finding = try Self.decodePersistedFinding(from: Data(contentsOf: url))
                loadedFindings[finding.findingId] = finding
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst finding persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst finding persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        findingsByID = loadedFindings
    }

    private func persist(_ finding: AnalystFinding) throws {
        try createProtectedDirectory(at: findingsDirectory, fileManager: fileManager)
        let fileURL = findingsDirectory.appendingPathComponent(finding.findingId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedFindingV1(schemaVersion: 1, finding: finding))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystFinding>.Values) -> [AnalystFinding] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.findingId < rhs.findingId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedFinding(from data: Data) throws -> AnalystFinding {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedFindingV1.self, from: data).finding
        }
        return try makeDecoder().decode(AnalystFinding.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public actor AnalystEvidenceBundleStore {
    private struct PersistedEvidenceBundleV1: Codable {
        let schemaVersion: Int
        let bundle: AnalystEvidenceBundle
    }

    private let fileManager: FileManager
    private let evidenceDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var bundlesByID: [String: AnalystEvidenceBundle] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        evidenceDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.evidenceDirectory = evidenceDirectory ?? AnalystPersistencePaths.evidenceDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystEvidenceBundle] {
        try loadIfNeeded()
        return sorted(bundlesByID.values)
    }

    public func get(id: String) throws -> AnalystEvidenceBundle? {
        try loadIfNeeded()
        return bundlesByID[id]
    }

    @discardableResult
    public func upsert(_ bundle: AnalystEvidenceBundle) throws -> AnalystEvidenceBundle {
        try loadIfNeeded()
        let bundleID = normalizedID(bundle.bundleId)
        let existing = bundlesByID[bundleID]
        var updated = bundle
        updated.bundleId = bundleID
        updated.createdAt = existing?.createdAt ?? bundle.createdAt
        updated.updatedAt = now()
        bundlesByID[bundleID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: evidenceDirectory.path) else {
            bundlesByID = [:]
            return
        }

        var loadedBundles: [String: AnalystEvidenceBundle] = [:]
        for url in try jsonFiles(in: evidenceDirectory, fileManager: fileManager) {
            do {
                let bundle = try Self.decodePersistedBundle(from: Data(contentsOf: url))
                loadedBundles[bundle.bundleId] = bundle
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst evidence persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst evidence persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        bundlesByID = loadedBundles
    }

    private func persist(_ bundle: AnalystEvidenceBundle) throws {
        try createProtectedDirectory(at: evidenceDirectory, fileManager: fileManager)
        let fileURL = evidenceDirectory.appendingPathComponent(bundle.bundleId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedEvidenceBundleV1(schemaVersion: 1, bundle: bundle))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystEvidenceBundle>.Values) -> [AnalystEvidenceBundle] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.bundleId < rhs.bundleId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedBundle(from data: Data) throws -> AnalystEvidenceBundle {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedEvidenceBundleV1.self, from: data).bundle
        }
        return try makeDecoder().decode(AnalystEvidenceBundle.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public actor AnalystMemoStore {
    private struct PersistedMemoV1: Codable {
        let schemaVersion: Int
        let memo: AnalystMemo
    }

    private let fileManager: FileManager
    private let memosDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var memosByID: [String: AnalystMemo] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        memosDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.memosDirectory = memosDirectory ?? AnalystPersistencePaths.memosDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystMemo] {
        try loadIfNeeded()
        return sorted(memosByID.values)
    }

    public func get(id: String) throws -> AnalystMemo? {
        try loadIfNeeded()
        return memosByID[id]
    }

    public func reloadFromDisk() throws -> [AnalystMemo] {
        loaded = true
        memosByID = try loadMemosFromDisk()
        return sorted(memosByID.values)
    }

    @discardableResult
    public func upsert(_ memo: AnalystMemo) throws -> AnalystMemo {
        try loadIfNeeded()
        let memoID = normalizedID(memo.memoId)
        let existing = memosByID[memoID]
        var updated = memo
        updated.memoId = memoID
        updated.createdAt = existing?.createdAt ?? memo.createdAt
        updated.updatedAt = now()
        memosByID[memoID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true
        memosByID = try loadMemosFromDisk()
    }

    private func loadMemosFromDisk() throws -> [String: AnalystMemo] {
        guard fileManager.fileExists(atPath: memosDirectory.path) else {
            return [:]
        }

        var loadedMemos: [String: AnalystMemo] = [:]
        for url in try jsonFiles(in: memosDirectory, fileManager: fileManager) {
            do {
                let memo = try Self.decodePersistedMemo(from: Data(contentsOf: url))
                loadedMemos[memo.memoId] = memo
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst memo persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst memo persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        return loadedMemos
    }

    private func persist(_ memo: AnalystMemo) throws {
        try createProtectedDirectory(at: memosDirectory, fileManager: fileManager)
        let fileURL = memosDirectory.appendingPathComponent(memo.memoId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedMemoV1(schemaVersion: 1, memo: memo))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystMemo>.Values) -> [AnalystMemo] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.memoId < rhs.memoId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedMemo(from data: Data) throws -> AnalystMemo {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedMemoV1.self, from: data).memo
        }
        return try makeDecoder().decode(AnalystMemo.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public actor AnalystStandingReportStore {
    private struct PersistedStandingReportV1: Codable {
        let schemaVersion: Int
        let report: AnalystStandingReport
    }

    private let fileManager: FileManager
    private let reportsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var reportsByID: [String: AnalystStandingReport] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        reportsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.reportsDirectory = reportsDirectory ?? AnalystPersistencePaths.standingReportsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystStandingReport] {
        try loadIfNeeded()
        return sorted(reportsByID.values)
    }

    public func get(id: String) throws -> AnalystStandingReport? {
        try loadIfNeeded()
        return reportsByID[id]
    }

    @discardableResult
    public func upsert(_ report: AnalystStandingReport) throws -> AnalystStandingReport {
        try loadIfNeeded()
        let reportID = normalizedID(report.reportId)
        let existing = reportsByID[reportID]
        var updated = report
        updated.reportId = reportID
        updated.createdAt = existing?.createdAt ?? report.createdAt
        updated.updatedAt = now()
        reportsByID[reportID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: reportsDirectory.path) else {
            reportsByID = [:]
            return
        }

        var loadedReports: [String: AnalystStandingReport] = [:]
        for url in try jsonFiles(in: reportsDirectory, fileManager: fileManager) {
            do {
                let report = try Self.decodePersistedStandingReport(from: Data(contentsOf: url))
                loadedReports[report.reportId] = report
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst standing report persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst standing report persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        reportsByID = loadedReports
    }

    private func persist(_ report: AnalystStandingReport) throws {
        try createProtectedDirectory(at: reportsDirectory, fileManager: fileManager)
        let fileURL = reportsDirectory.appendingPathComponent(report.reportId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedStandingReportV1(schemaVersion: 1, report: report))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystStandingReport>.Values) -> [AnalystStandingReport] {
        values.sorted { lhs, rhs in
            if lhs.deliveredToPMInboxAt == rhs.deliveredToPMInboxAt {
                return lhs.reportId < rhs.reportId
            }
            return lhs.deliveredToPMInboxAt > rhs.deliveredToPMInboxAt
        }
    }

    private static func decodePersistedStandingReport(from data: Data) throws -> AnalystStandingReport {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedStandingReportV1.self, from: data).report
        }
        return try makeDecoder().decode(AnalystStandingReport.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public actor AnalystScopedMemoryStore {
    private struct PersistedScopedMemoryV1: Codable {
        let schemaVersion: Int
        let memory: AnalystScopedMemoryRecord
    }

    private let fileManager: FileManager
    private let memoryDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var memoriesByID: [String: AnalystScopedMemoryRecord] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        memoryDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.memoryDirectory = memoryDirectory ?? AnalystPersistencePaths.memoryDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystScopedMemoryRecord] {
        try loadIfNeeded()
        return sorted(memoriesByID.values)
    }

    public func get(id: String) throws -> AnalystScopedMemoryRecord? {
        try loadIfNeeded()
        return memoriesByID[id]
    }

    public func getByAnalystID(_ analystID: String) throws -> AnalystScopedMemoryRecord? {
        try loadIfNeeded()
        return memoriesByID[normalizedID(analystID)]
    }

    @discardableResult
    public func upsert(_ memory: AnalystScopedMemoryRecord) throws -> AnalystScopedMemoryRecord {
        try loadIfNeeded()
        let memoryID = normalizedID(memory.memoryId)
        let existing = memoriesByID[memoryID]
        var updated = memory
        updated.memoryId = memoryID
        updated.analystId = normalizedID(memory.analystId)
        updated.createdAt = existing?.createdAt ?? memory.createdAt
        updated.updatedAt = now()
        memoriesByID[memoryID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: memoryDirectory.path) else {
            memoriesByID = [:]
            return
        }

        var loadedMemories: [String: AnalystScopedMemoryRecord] = [:]
        for url in try jsonFiles(in: memoryDirectory, fileManager: fileManager) {
            do {
                let memory = try Self.decodePersistedMemory(from: Data(contentsOf: url))
                loadedMemories[memory.memoryId] = memory
            } catch let error as PersistedAnalystDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("analyst memory persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("analyst memory persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        memoriesByID = loadedMemories
    }

    private func persist(_ memory: AnalystScopedMemoryRecord) throws {
        try createProtectedDirectory(at: memoryDirectory, fileManager: fileManager)
        let fileURL = memoryDirectory.appendingPathComponent(memory.memoryId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedScopedMemoryV1(schemaVersion: 1, memory: memory))
        try writeProtectedFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystScopedMemoryRecord>.Values) -> [AnalystScopedMemoryRecord] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.memoryId < rhs.memoryId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedMemory(from data: Data) throws -> AnalystScopedMemoryRecord {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedAnalystDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makeDecoder().decode(PersistedScopedMemoryV1.self, from: data).memory
        }
        return try makeDecoder().decode(AnalystScopedMemoryRecord.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makeAnalystEncoder() }
    private static func makeDecoder() -> JSONDecoder { makeAnalystDecoder() }
}

public enum RecentNewsAnalystReviewStateStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public enum PortfolioRiskTriggerReviewStateStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public enum RecentNewsAnalystRuntimeSettingsStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public actor PortfolioRiskTriggerReviewStateStore {
    private struct PersistedReviewStateV1: Codable {
        let schemaVersion: Int
        let state: PortfolioRiskTriggerReviewState
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL

    private var loaded = false
    private var cachedState: PortfolioRiskTriggerReviewState?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL ?? AnalystPersistencePaths.portfolioRiskTriggerReviewStateFile()
        self.fileManager = fileManager
    }

    public func load() -> PortfolioRiskTriggerReviewState? {
        loadIfNeeded()
        return cachedState
    }

    @discardableResult
    public func save(_ state: PortfolioRiskTriggerReviewState) throws -> PortfolioRiskTriggerReviewState {
        loadIfNeeded()
        cachedState = state
        try persist(state)
        return state
    }

    public func fileLocation() -> URL {
        fileURL
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: fileURL.path) else {
            cachedState = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cachedState = try Self.decodeState(from: data)
        } catch let error as PortfolioRiskTriggerReviewStateStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "portfolio risk trigger review state skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)"
                )
            case .invalidDocument:
                loadDiagnostics.append(
                    "portfolio risk trigger review state skipped file=\(fileURL.lastPathComponent) code=invalid_document"
                )
            }
            cachedState = nil
        } catch {
            loadDiagnostics.append(
                "portfolio risk trigger review state skipped file=\(fileURL.lastPathComponent) code=io_failure"
            )
            cachedState = nil
        }
    }

    private func persist(_ state: PortfolioRiskTriggerReviewState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let data = try makeAnalystEncoder().encode(
            PersistedReviewStateV1(schemaVersion: 1, state: state)
        )
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeState(from data: Data) throws -> PortfolioRiskTriggerReviewState {
        let decoder = makeAnalystDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PortfolioRiskTriggerReviewStateStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedReviewStateV1.self, from: data).state
            } catch {
                throw PortfolioRiskTriggerReviewStateStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(PortfolioRiskTriggerReviewState.self, from: data)
        } catch {
            throw PortfolioRiskTriggerReviewStateStoreError.invalidDocument
        }
    }
}

public actor RecentNewsAnalystReviewStateStore {
    private struct PersistedReviewStateV1: Codable {
        let schemaVersion: Int
        let state: RecentNewsAnalystReviewState
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL

    private var loaded = false
    private var cachedState: RecentNewsAnalystReviewState?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL ?? AnalystPersistencePaths.recentNewsReviewStateFile()
        self.fileManager = fileManager
    }

    public func load() -> RecentNewsAnalystReviewState? {
        loadIfNeeded()
        return cachedState
    }

    @discardableResult
    public func save(_ state: RecentNewsAnalystReviewState) throws -> RecentNewsAnalystReviewState {
        loadIfNeeded()
        cachedState = state
        try persist(state)
        return state
    }

    public func fileLocation() -> URL {
        fileURL
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: fileURL.path) else {
            cachedState = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cachedState = try Self.decodeState(from: data)
        } catch let error as RecentNewsAnalystReviewStateStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "recent news review state skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)"
                )
            case .invalidDocument:
                loadDiagnostics.append(
                    "recent news review state skipped file=\(fileURL.lastPathComponent) code=invalid_document"
                )
            }
            cachedState = nil
        } catch {
            loadDiagnostics.append(
                "recent news review state skipped file=\(fileURL.lastPathComponent) code=io_failure"
            )
            cachedState = nil
        }
    }

    private func persist(_ state: RecentNewsAnalystReviewState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let data = try makeAnalystEncoder().encode(
            PersistedReviewStateV1(schemaVersion: 1, state: state)
        )
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeState(from data: Data) throws -> RecentNewsAnalystReviewState {
        let decoder = makeAnalystDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw RecentNewsAnalystReviewStateStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedReviewStateV1.self, from: data).state
            } catch {
                throw RecentNewsAnalystReviewStateStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(RecentNewsAnalystReviewState.self, from: data)
        } catch {
            throw RecentNewsAnalystReviewStateStoreError.invalidDocument
        }
    }
}

public actor RecentNewsAnalystRuntimeSettingsStore {
    private struct PersistedRuntimeSettingsV1: Codable {
        let schemaVersion: Int
        let settings: RecentNewsAnalystRuntimeSettings
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var cachedSettings: RecentNewsAnalystRuntimeSettings?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileURL = fileURL ?? AnalystPersistencePaths.recentNewsRuntimeSettingsFile()
        self.fileManager = fileManager
        self.now = now
    }

    public func load() -> RecentNewsAnalystRuntimeSettings? {
        loadIfNeeded()
        return cachedSettings
    }

    public func loadOrDefault() -> RecentNewsAnalystRuntimeSettings {
        loadIfNeeded()
        return cachedSettings ?? .default(now: now())
    }

    @discardableResult
    public func upsert(_ settings: RecentNewsAnalystRuntimeSettings) throws -> RecentNewsAnalystRuntimeSettings {
        loadIfNeeded()
        let existing = cachedSettings
        var updated = settings
        updated.settingsId = RecentNewsAnalystRuntimeSettings.singletonID
        updated.createdAt = existing?.createdAt ?? settings.createdAt
        updated.updatedAt = now()
        cachedSettings = updated
        try persist(updated)
        return updated
    }

    public func fileLocation() -> URL {
        fileURL
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: fileURL.path) else {
            cachedSettings = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cachedSettings = try Self.decodeSettings(from: data)
        } catch let error as RecentNewsAnalystRuntimeSettingsStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "recent news runtime settings skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)"
                )
            case .invalidDocument:
                loadDiagnostics.append(
                    "recent news runtime settings skipped file=\(fileURL.lastPathComponent) code=invalid_document"
                )
            }
            cachedSettings = nil
        } catch {
            loadDiagnostics.append(
                "recent news runtime settings skipped file=\(fileURL.lastPathComponent) code=io_failure"
            )
            cachedSettings = nil
        }
    }

    private func persist(_ settings: RecentNewsAnalystRuntimeSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let data = try makeAnalystEncoder().encode(
            PersistedRuntimeSettingsV1(schemaVersion: 1, settings: settings)
        )
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeSettings(from data: Data) throws -> RecentNewsAnalystRuntimeSettings {
        let decoder = makeAnalystDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw RecentNewsAnalystRuntimeSettingsStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedRuntimeSettingsV1.self, from: data).settings
            } catch {
                throw RecentNewsAnalystRuntimeSettingsStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(RecentNewsAnalystRuntimeSettings.self, from: data)
        } catch {
            throw RecentNewsAnalystRuntimeSettingsStoreError.invalidDocument
        }
    }
}

public actor StandingBenchAnalystRuntimeSettingsStore {
    private struct PersistedRuntimeSettingsV1: Codable {
        let schemaVersion: Int
        let settings: StandingBenchAnalystRuntimeSettings
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var cachedSettings: StandingBenchAnalystRuntimeSettings?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileURL = fileURL ?? AnalystPersistencePaths.standingBenchRuntimeSettingsFile()
        self.fileManager = fileManager
        self.now = now
    }

    public func load() -> StandingBenchAnalystRuntimeSettings? {
        loadIfNeeded()
        return cachedSettings
    }

    public func loadOrDefault() -> StandingBenchAnalystRuntimeSettings {
        loadIfNeeded()
        return cachedSettings ?? .default(now: now())
    }

    @discardableResult
    public func upsert(_ settings: StandingBenchAnalystRuntimeSettings) throws -> StandingBenchAnalystRuntimeSettings {
        loadIfNeeded()
        let existing = cachedSettings
        var updated = settings
        updated.settingsId = StandingBenchAnalystRuntimeSettings.singletonID
        updated.createdAt = existing?.createdAt ?? settings.createdAt
        updated.updatedAt = now()
        cachedSettings = updated
        try persist(updated)
        return updated
    }

    public func fileLocation() -> URL {
        fileURL
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: fileURL.path) else {
            cachedSettings = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cachedSettings = try Self.decodeSettings(from: data)
        } catch let error as StandingBenchAnalystRuntimeSettingsStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "standing bench runtime settings skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)"
                )
            case .invalidDocument:
                loadDiagnostics.append(
                    "standing bench runtime settings skipped file=\(fileURL.lastPathComponent) code=invalid_document"
                )
            }
            cachedSettings = nil
        } catch {
            loadDiagnostics.append(
                "standing bench runtime settings skipped file=\(fileURL.lastPathComponent) code=io_failure"
            )
            cachedSettings = nil
        }
    }

    private func persist(_ settings: StandingBenchAnalystRuntimeSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let data = try makeAnalystEncoder().encode(
            PersistedRuntimeSettingsV1(schemaVersion: 1, settings: settings)
        )
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeSettings(from data: Data) throws -> StandingBenchAnalystRuntimeSettings {
        let decoder = makeAnalystDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw StandingBenchAnalystRuntimeSettingsStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedRuntimeSettingsV1.self, from: data).settings
            } catch {
                throw StandingBenchAnalystRuntimeSettingsStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(StandingBenchAnalystRuntimeSettings.self, from: data)
        } catch {
            throw StandingBenchAnalystRuntimeSettingsStoreError.invalidDocument
        }
    }
}

private func normalizedID(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? UUID().uuidString : trimmed
}

private func createProtectedDirectory(at url: URL, fileManager: FileManager) throws {
    try fileManager.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
}

private func writeProtectedFile(data: Data, to fileURL: URL, fileManager: FileManager) throws {
    try data.write(to: fileURL, options: [.atomic])
    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
}

private func jsonFiles(in directory: URL, fileManager: FileManager) throws -> [URL] {
    try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "json" }
}

private func makeAnalystEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    return encoder
}

private func makeAnalystDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
    return decoder
}
