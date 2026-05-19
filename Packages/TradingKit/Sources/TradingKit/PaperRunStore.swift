import Foundation

public enum PaperRunStoreError: Error, Sendable, Equatable {
    case runNotFound(id: String)
}

public actor PaperRunStore {
    private enum PersistedRunError: Error {
        case unsupportedSchemaVersion(Int)
    }

    private struct PersistedRunV1: Codable {
        let schemaVersion: Int
        let run: PaperRunRecord
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let runsDirectory: URL
    private var loadDiagnostics: [String] = []
    private var loaded = false
    private var runsByID: [String: PaperRunRecord] = [:]

    public init(
        runsDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.runsDirectory = runsDirectory
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("runs", isDirectory: true)
        self.fileManager = fileManager
    }

    @discardableResult
    public func createRun(_ record: PaperRunRecord) async throws -> String {
        try loadIfNeeded()
        runsByID[record.runId] = record
        try persist(record)
        return record.runId
    }

    public func updateRun(runId: String, record: PaperRunRecord) async throws {
        try loadIfNeeded()
        guard runsByID[runId] != nil else {
            throw PaperRunStoreError.runNotFound(id: runId)
        }
        runsByID[runId] = record
        try persist(record)
    }

    public func listRuns(proposalId: String) async throws -> [PaperRunRecordSummary] {
        try loadIfNeeded()
        return runsByID.values
            .filter { $0.proposalId == proposalId }
            .map(\.summary)
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt {
                    return lhs.runId < rhs.runId
                }
                return lhs.startedAt > rhs.startedAt
            }
    }

    public func getRun(runId: String) async throws -> PaperRunRecord {
        try loadIfNeeded()
        guard let run = runsByID[runId] else {
            throw PaperRunStoreError.runNotFound(id: runId)
        }
        return run
    }

    public func exportRunJSON(runId: String) async throws -> String {
        let run = try await getRun(runId: runId)
        let data = try Self.makeEncoder().encode(run)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    public func runsDirectoryURL() -> URL {
        runsDirectory
    }

    public func purge(
        keepDays: Int,
        dryRun: Bool,
        now: Date
    ) throws -> RetentionSweepResult {
        try loadIfNeeded()
        let resolvedKeepDays = max(1, keepDays)
        let scannedCount = runsByID.count
        let cutoff = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -resolvedKeepDays,
            to: now
        ) ?? now

        let candidates = runsByID.values.filter { run in
            let ended = run.endedAt ?? run.startedAt
            return run.status != .running && ended < cutoff
        }
        let idsToDelete = Set(candidates.map(\.runId))

        var bytesFreed: Int64 = 0
        for runID in idsToDelete {
            let fileURL = runsDirectory
                .appendingPathComponent(runID)
                .appendingPathExtension("json")
            if fileManager.fileExists(atPath: fileURL.path) {
                bytesFreed += (try? fileSize(fileURL)) ?? 0
                if !dryRun {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
            if !dryRun {
                runsByID.removeValue(forKey: runID)
            }
        }

        return RetentionSweepResult(
            scannedCount: scannedCount,
            deletedCount: idsToDelete.count,
            bytesFreed: bytesFreed
        )
    }

    private func loadIfNeeded() throws {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: runsDirectory.path) else {
            runsByID = [:]
            return
        }

        let urls = try fileManager.contentsOfDirectory(
            at: runsDirectory,
            includingPropertiesForKeys: nil
        )
        var loadedRuns: [String: PaperRunRecord] = [:]
        for url in urls where url.pathExtension.lowercased() == "json" {
            do {
                let data = try Data(contentsOf: url)
                let run = try Self.decodePersistedRun(from: data)
                loadedRuns[run.runId] = run
            } catch let error as PersistedRunError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append(
                        "run persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)"
                    )
                }
            } catch {
                loadDiagnostics.append(
                    "run persistence skipped file=\(url.lastPathComponent) code=invalid_document"
                )
                continue
            }
        }
        runsByID = loadedRuns
    }

    private func persist(_ run: PaperRunRecord) throws {
        try fileManager.createDirectory(
            at: runsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let fileURL = runsDirectory
            .appendingPathComponent(run.runId)
            .appendingPathExtension("json")
        let wrapped = PersistedRunV1(
            schemaVersion: 1,
            run: run
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

    private static func decodePersistedRun(from data: Data) throws -> PaperRunRecord {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PersistedRunError.unsupportedSchemaVersion(schemaVersion)
            }
            return try makeDecoder().decode(PersistedRunV1.self, from: data).run
        }

        // Legacy v0 format stored the run JSON directly.
        return try makeDecoder().decode(PaperRunRecord.self, from: data)
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }
}
