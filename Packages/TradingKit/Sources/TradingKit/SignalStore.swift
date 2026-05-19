import Foundation

public enum SignalStoreError: Error, Sendable, Equatable {
    case signalNotFound(id: String)
}

public actor SignalStore {
    private enum PersistedSignalError: Error {
        case unsupportedSchemaVersion(Int)
    }

    private struct PersistedSignalV1: Codable {
        let schemaVersion: Int
        let signal: Signal
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let signalsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var signalsByID: [String: Signal] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        signalsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.signalsDirectory = signalsDirectory
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("signals", isDirectory: true)
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [Signal] {
        try loadIfNeeded()
        return sorted(signalsByID.values)
    }

    public func list(
        status: SignalStatus? = nil,
        limit: Int? = nil
    ) throws -> [Signal] {
        let filtered = try loadAll().filter { signal in
            if let status, signal.status != status {
                return false
            }
            return true
        }
        if let limit {
            return Array(filtered.prefix(max(1, limit)))
        }
        return filtered
    }

    public func get(id: String) throws -> Signal? {
        try loadIfNeeded()
        return signalsByID[id]
    }

    @discardableResult
    public func upsert(_ signal: Signal) throws -> Signal {
        try loadIfNeeded()
        let signalID = signal.signalId.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedID = signalID.isEmpty ? UUID().uuidString : signalID

        var updated = signal
        if let existing = signalsByID[resolvedID] {
            updated.createdAt = existing.createdAt
            if signal.status == .new {
                updated.status = existing.status
            }
            updated.provenance = mergedProvenance(incoming: updated.provenance, existing: existing.provenance)
            if updated.originatingFindingId == nil {
                updated.originatingFindingId = existing.originatingFindingId
            }
            if updated.draftedProposalId == nil {
                updated.draftedProposalId = existing.draftedProposalId
            }
            if updated.linkedProposalId == nil {
                updated.linkedProposalId = existing.linkedProposalId ?? existing.draftedProposalId
            }
        }
        updated.signalId = resolvedID
        updated.updatedAt = now()

        signalsByID[resolvedID] = updated
        try persist(updated)
        return updated
    }

    @discardableResult
    public func markAcknowledged(id: String) throws -> Signal {
        try updateStatus(id: id, status: .acknowledged)
    }

    @discardableResult
    public func archive(id: String) throws -> Signal {
        try updateStatus(id: id, status: .archived)
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func updateStatus(
        id: String,
        status: SignalStatus
    ) throws -> Signal {
        try loadIfNeeded()
        guard var signal = signalsByID[id] else {
            throw SignalStoreError.signalNotFound(id: id)
        }
        signal.status = status
        signal.updatedAt = now()
        signalsByID[id] = signal
        try persist(signal)
        return signal
    }

    private func loadIfNeeded() throws {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: signalsDirectory.path) else {
            signalsByID = [:]
            return
        }

        let urls = try fileManager.contentsOfDirectory(
            at: signalsDirectory,
            includingPropertiesForKeys: nil
        )
        var loadedSignals: [String: Signal] = [:]
        for url in urls where url.pathExtension.lowercased() == "json" {
            do {
                let data = try Data(contentsOf: url)
                let signal = try Self.decodePersistedSignal(from: data)
                loadedSignals[signal.signalId] = signal
            } catch let error as PersistedSignalError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append(
                        "signal persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)"
                    )
                }
            } catch {
                loadDiagnostics.append(
                    "signal persistence skipped file=\(url.lastPathComponent) code=invalid_document"
                )
            }
        }
        signalsByID = loadedSignals
    }

    private func persist(_ signal: Signal) throws {
        try fileManager.createDirectory(
            at: signalsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let fileURL = signalsDirectory
            .appendingPathComponent(signal.signalId)
            .appendingPathExtension("json")
        let wrapped = PersistedSignalV1(schemaVersion: 1, signal: signal)
        let data = try Self.makeEncoder().encode(wrapped)
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private func sorted(_ values: Dictionary<String, Signal>.Values) -> [Signal] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.signalId < rhs.signalId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func mergedProvenance(
        incoming: SignalProvenance,
        existing: SignalProvenance
    ) -> SignalProvenance {
        SignalProvenance(
            sourceJobId: incoming.sourceJobId ?? existing.sourceJobId,
            scoringVersion: incoming.scoringVersion,
            analystId: incoming.analystId ?? existing.analystId,
            charterId: incoming.charterId ?? existing.charterId,
            taskId: incoming.taskId ?? existing.taskId,
            sourceFindingId: incoming.sourceFindingId ?? existing.sourceFindingId,
            sourceEvidenceBundleId: incoming.sourceEvidenceBundleId ?? existing.sourceEvidenceBundleId
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

    private static func decodePersistedSignal(from data: Data) throws -> Signal {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PersistedSignalError.unsupportedSchemaVersion(schemaVersion)
            }
            return try makeDecoder().decode(PersistedSignalV1.self, from: data).signal
        }

        // Legacy v0 format stored the raw Signal JSON object.
        return try makeDecoder().decode(Signal.self, from: data)
    }

}
