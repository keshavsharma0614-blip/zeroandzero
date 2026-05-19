import Foundation

public enum ProposalStoreError: Error, Sendable, Equatable {
    case proposalNotFound(id: String)
}

public actor ProposalStore {
    private enum PersistedProposalError: Error {
        case unsupportedSchemaVersion(Int)
    }

    private struct PersistedProposalV1: Codable {
        let schemaVersion: Int
        let proposal: StrategyProposal
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let proposalsDirectory: URL
    private let now: @Sendable () -> Date

    private var proposalsByID: [String: StrategyProposal] = [:]
    private var loadDiagnostics: [String] = []
    private var loaded = false

    public init(
        proposalsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.proposalsDirectory = proposalsDirectory
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("proposals", isDirectory: true)
        self.fileManager = fileManager
        self.now = now
    }

    public func listProposals() async throws -> [StrategyProposal] {
        try loadIfNeeded()
        return proposalsByID.values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.proposalId < rhs.proposalId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public func listProposalRows() async throws -> [ProposalRow] {
        let proposals = try await listProposals()
        return proposals.map(\.proposalRow)
    }

    public func getProposal(id: String) async throws -> StrategyProposal? {
        try loadIfNeeded()
        return proposalsByID[id]
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    @discardableResult
    public func upsertProposal(_ proposal: StrategyProposal) async throws -> StrategyProposal {
        try loadIfNeeded()

        let timestamp = now()
        let normalizedID = proposal.proposalId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let proposalID = normalizedID.isEmpty ? UUID().uuidString : normalizedID

        let existing = proposalsByID[proposalID]
        var updated = proposal
        updated.proposalId = proposalID
        updated.createdAt = existing?.createdAt ?? proposal.createdAt
        updated.updatedAt = timestamp

        proposalsByID[proposalID] = updated
        try persist(updated)
        return updated
    }

    @discardableResult
    public func setStatus(
        id: String,
        status: StrategyProposalStatus,
        reviewedBy: String?,
        notes: String?
    ) async throws -> StrategyProposal {
        try loadIfNeeded()
        guard var proposal = proposalsByID[id] else {
            throw ProposalStoreError.proposalNotFound(id: id)
        }

        proposal.approval.status = status
        proposal.approval.reviewedBy = reviewedBy
        proposal.approval.reviewNotes = notes
        proposal.approval.reviewedAt = now()
        proposal.updatedAt = now()

        proposalsByID[id] = proposal
        try persist(proposal)
        return proposal
    }

    @discardableResult
    public func recordPaperRunResult(
        proposalID: String,
        status: String
    ) async throws -> StrategyProposal {
        try loadIfNeeded()
        guard var proposal = proposalsByID[proposalID] else {
            throw ProposalStoreError.proposalNotFound(id: proposalID)
        }

        var runResult = proposal.runResult ?? StrategyProposalRunResult()
        runResult.lastRunAt = now()
        runResult.lastRunStatus = status
        proposal.runResult = runResult
        proposal.updatedAt = now()

        proposalsByID[proposalID] = proposal
        try persist(proposal)
        return proposal
    }

    private func loadIfNeeded() throws {
        guard !loaded else {
            return
        }
        loaded = true

        guard fileManager.fileExists(atPath: proposalsDirectory.path) else {
            proposalsByID = [:]
            return
        }

        let urls = try fileManager.contentsOfDirectory(
            at: proposalsDirectory,
            includingPropertiesForKeys: nil
        )
        var loadedProposals: [String: StrategyProposal] = [:]
        for url in urls where url.pathExtension.lowercased() == "json" {
            do {
                let data = try Data(contentsOf: url)
                let proposal = try Self.decodePersistedProposal(from: data)
                loadedProposals[proposal.proposalId] = proposal
            } catch let error as PersistedProposalError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append(
                        "proposal persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)"
                    )
                }
            } catch {
                loadDiagnostics.append(
                    "proposal persistence skipped file=\(url.lastPathComponent) code=invalid_document"
                )
                continue
            }
        }
        proposalsByID = loadedProposals
    }

    private func persist(_ proposal: StrategyProposal) throws {
        try fileManager.createDirectory(
            at: proposalsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let fileURL = proposalsDirectory
            .appendingPathComponent(proposal.proposalId)
            .appendingPathExtension("json")
        let wrapped = PersistedProposalV1(
            schemaVersion: 1,
            proposal: proposal
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
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return decoder
    }

    private static func decodePersistedProposal(from data: Data) throws -> StrategyProposal {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PersistedProposalError.unsupportedSchemaVersion(schemaVersion)
            }
            return try makeDecoder().decode(PersistedProposalV1.self, from: data).proposal
        }

        // Legacy v0 format stored the proposal JSON directly.
        return try makeDecoder().decode(StrategyProposal.self, from: data)
    }

}
