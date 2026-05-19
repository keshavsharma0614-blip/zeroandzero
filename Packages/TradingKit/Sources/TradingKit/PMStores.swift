import Foundation

public enum PMProfileStoreError: Error, Sendable, Equatable {
    case profileNotFound(id: String)
}

public enum PMMandateStoreError: Error, Sendable, Equatable {
    case mandateNotFound(id: String)
}

public enum PMInstructionStoreError: Error, Sendable, Equatable {
    case instructionNotFound(id: String)
}

public enum PMNotebookStoreError: Error, Sendable, Equatable {
    case entryNotFound(id: String)
}

public enum PMInteractionMemoryStoreError: Error, Sendable, Equatable {
    case memoryNotFound(id: String)
}

public enum PMRuntimeSettingsStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public enum PortfolioStrategyBriefStoreError: Error, Sendable, Equatable {
    case briefNotFound(id: String)
}

public enum AnalystStrategyImplicationStoreError: Error, Sendable, Equatable {
    case implicationNotFound(id: String)
}

public enum AnalystStrategyFollowUpCandidateStoreError: Error, Sendable, Equatable {
    case candidateNotFound(id: String)
}

public enum PMDecisionStoreError: Error, Sendable, Equatable {
    case decisionNotFound(id: String)
}

public enum PMApprovalRequestStoreError: Error, Sendable, Equatable {
    case approvalRequestNotFound(id: String)
}

public enum PMCommunicationSessionStoreError: Error, Sendable, Equatable {
    case sessionNotFound(id: String)
}

public enum PMCommunicationMessageStoreError: Error, Sendable, Equatable {
    case messageNotFound(id: String)
}

public enum PMDelegationStoreError: Error, Sendable, Equatable {
    case delegationNotFound(id: String)
}

private enum PersistedPMDocumentError: Error {
    case unsupportedSchemaVersion(Int)
}

private struct PersistedPMSchemaProbe: Decodable {
    let schemaVersion: Int?
}

private enum PMPersistencePaths {
    static func pmRoot() -> URL {
        AppSupportPaths.rootDirectory()
            .appendingPathComponent("pm", isDirectory: true)
    }

    static func profilesDirectory() -> URL {
        pmRoot().appendingPathComponent("profiles", isDirectory: true)
    }

    static func mandatesDirectory() -> URL {
        pmRoot().appendingPathComponent("mandates", isDirectory: true)
    }

    static func instructionsDirectory() -> URL {
        pmRoot().appendingPathComponent("instructions", isDirectory: true)
    }

    static func notebookDirectory() -> URL {
        pmRoot().appendingPathComponent("notebook", isDirectory: true)
    }

    static func interactionMemoryDirectory() -> URL {
        pmRoot().appendingPathComponent("interaction_memory", isDirectory: true)
    }

    static func runtimeSettingsFile() -> URL {
        pmRoot().appendingPathComponent("runtime_settings.json", isDirectory: false)
    }

    static func portfolioStrategyBriefFile() -> URL {
        pmRoot().appendingPathComponent("portfolio_strategy_brief.json", isDirectory: false)
    }

    static func analystStrategyImplicationsDirectory() -> URL {
        pmRoot().appendingPathComponent("analyst_strategy_implications", isDirectory: true)
    }

    static func analystStrategyFollowUpCandidatesDirectory() -> URL {
        pmRoot().appendingPathComponent("analyst_strategy_follow_up_candidates", isDirectory: true)
    }

    static func decisionsDirectory() -> URL {
        pmRoot().appendingPathComponent("decisions", isDirectory: true)
    }

    static func approvalRequestsDirectory() -> URL {
        pmRoot().appendingPathComponent("approval_requests", isDirectory: true)
    }

    static func communicationSessionsDirectory() -> URL {
        pmRoot().appendingPathComponent("communication_sessions", isDirectory: true)
    }

    static func communicationMessagesDirectory() -> URL {
        pmRoot().appendingPathComponent("communication_messages", isDirectory: true)
    }

    static func delegationsDirectory() -> URL {
        pmRoot().appendingPathComponent("delegations", isDirectory: true)
    }
}

public actor AnalystStrategyImplicationStore {
    private struct PersistedImplicationV1: Codable {
        let schemaVersion: Int
        let implication: AnalystStrategyImplicationRecord
    }

    private let fileManager: FileManager
    private let implicationsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var implicationsByID: [String: AnalystStrategyImplicationRecord] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        implicationsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.implicationsDirectory = implicationsDirectory ?? PMPersistencePaths.analystStrategyImplicationsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystStrategyImplicationRecord] {
        try loadIfNeeded()
        return sorted(implicationsByID.values)
    }

    public func get(id: String) throws -> AnalystStrategyImplicationRecord? {
        try loadIfNeeded()
        return implicationsByID[id]
    }

    @discardableResult
    public func upsert(_ implication: AnalystStrategyImplicationRecord) throws -> AnalystStrategyImplicationRecord {
        try loadIfNeeded()
        let implicationID = normalizedImplicationID(implication.implicationId)
        let existing = implicationsByID[implicationID]
        var updated = implication
        updated.implicationId = implicationID
        updated.createdAt = existing?.createdAt ?? implication.createdAt
        updated.updatedAt = now()
        implicationsByID[implicationID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard loaded == false else { return }
        loaded = true

        guard fileManager.fileExists(atPath: implicationsDirectory.path) else {
            implicationsByID = [:]
            return
        }

        var loadedImplications: [String: AnalystStrategyImplicationRecord] = [:]
        for url in try jsonFilesInPMDirectory(implicationsDirectory, fileManager: fileManager) {
            do {
                let implication = try Self.decodePersistedImplication(from: Data(contentsOf: url))
                loadedImplications[implication.implicationId] = implication
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm analyst strategy implication persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm analyst strategy implication persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        implicationsByID = loadedImplications
    }

    private func persist(_ implication: AnalystStrategyImplicationRecord) throws {
        try createProtectedPMDirectory(at: implicationsDirectory, fileManager: fileManager)
        let fileURL = implicationsDirectory.appendingPathComponent(implication.implicationId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(
            PersistedImplicationV1(schemaVersion: 1, implication: implication)
        )
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystStrategyImplicationRecord>.Values) -> [AnalystStrategyImplicationRecord] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.implicationId < rhs.implicationId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedImplication(from data: Data) throws -> AnalystStrategyImplicationRecord {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedImplicationV1.self, from: data).implication
        }
        return try makePMDecoder().decode(AnalystStrategyImplicationRecord.self, from: data)
    }

    private func normalizedImplicationID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor AnalystStrategyFollowUpCandidateStore {
    private struct PersistedCandidateV1: Codable {
        let schemaVersion: Int
        let candidate: AnalystStrategyFollowUpCandidateRecord
    }

    private let fileManager: FileManager
    private let candidatesDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var candidatesByID: [String: AnalystStrategyFollowUpCandidateRecord] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        candidatesDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.candidatesDirectory = candidatesDirectory ?? PMPersistencePaths.analystStrategyFollowUpCandidatesDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [AnalystStrategyFollowUpCandidateRecord] {
        try loadIfNeeded()
        return sorted(candidatesByID.values)
    }

    public func get(id: String) throws -> AnalystStrategyFollowUpCandidateRecord? {
        try loadIfNeeded()
        return candidatesByID[id]
    }

    @discardableResult
    public func upsert(_ candidate: AnalystStrategyFollowUpCandidateRecord) throws -> AnalystStrategyFollowUpCandidateRecord {
        try loadIfNeeded()
        let candidateID = normalizedCandidateID(candidate.candidateId)
        let existing = candidatesByID[candidateID]
        var updated = candidate
        updated.candidateId = candidateID
        updated.createdAt = existing?.createdAt ?? candidate.createdAt
        updated.updatedAt = now()
        candidatesByID[candidateID] = updated
        try persist(updated)
        return updated
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() throws {
        guard loaded == false else { return }
        loaded = true

        guard fileManager.fileExists(atPath: candidatesDirectory.path) else {
            candidatesByID = [:]
            return
        }

        var loadedCandidates: [String: AnalystStrategyFollowUpCandidateRecord] = [:]
        for url in try jsonFilesInPMDirectory(candidatesDirectory, fileManager: fileManager) {
            do {
                let candidate = try Self.decodePersistedCandidate(from: Data(contentsOf: url))
                loadedCandidates[candidate.candidateId] = candidate
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm analyst strategy follow-up candidate persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm analyst strategy follow-up candidate persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        candidatesByID = loadedCandidates
    }

    private func persist(_ candidate: AnalystStrategyFollowUpCandidateRecord) throws {
        try createProtectedPMDirectory(at: candidatesDirectory, fileManager: fileManager)
        let fileURL = candidatesDirectory.appendingPathComponent(candidate.candidateId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(
            PersistedCandidateV1(schemaVersion: 1, candidate: candidate)
        )
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, AnalystStrategyFollowUpCandidateRecord>.Values) -> [AnalystStrategyFollowUpCandidateRecord] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.candidateId < rhs.candidateId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedCandidate(from data: Data) throws -> AnalystStrategyFollowUpCandidateRecord {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedCandidateV1.self, from: data).candidate
        }
        return try makePMDecoder().decode(AnalystStrategyFollowUpCandidateRecord.self, from: data)
    }

    private func normalizedCandidateID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMProfileStore {
    private struct PersistedProfileV1: Codable {
        let schemaVersion: Int
        let profile: PMProfile
    }

    private let fileManager: FileManager
    private let profilesDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var profilesByID: [String: PMProfile] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        profilesDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.profilesDirectory = profilesDirectory ?? PMPersistencePaths.profilesDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMProfile] {
        try loadIfNeeded()
        return sorted(profilesByID.values)
    }

    public func get(id: String) throws -> PMProfile? {
        try loadIfNeeded()
        return profilesByID[id]
    }

    @discardableResult
    public func upsert(_ profile: PMProfile) throws -> PMProfile {
        try loadIfNeeded()
        let profileID = normalizedPMID(profile.pmId)
        let existing = profilesByID[profileID]
        var updated = profile
        updated.pmId = profileID
        updated.createdAt = existing?.createdAt ?? profile.createdAt
        updated.updatedAt = now()
        profilesByID[profileID] = updated
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

        guard fileManager.fileExists(atPath: profilesDirectory.path) else {
            profilesByID = [:]
            return
        }

        var loadedProfiles: [String: PMProfile] = [:]
        for url in try jsonFilesInPMDirectory(profilesDirectory, fileManager: fileManager) {
            do {
                let profile = try Self.decodePersistedProfile(from: Data(contentsOf: url))
                loadedProfiles[profile.pmId] = profile
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm profile persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm profile persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        profilesByID = loadedProfiles
    }

    private func persist(_ profile: PMProfile) throws {
        try createProtectedPMDirectory(at: profilesDirectory, fileManager: fileManager)
        let fileURL = profilesDirectory.appendingPathComponent(profile.pmId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedProfileV1(schemaVersion: 1, profile: profile))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMProfile>.Values) -> [PMProfile] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.pmId < rhs.pmId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedProfile(from data: Data) throws -> PMProfile {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedProfileV1.self, from: data).profile
        }
        return try makePMDecoder().decode(PMProfile.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMMandateStore {
    private struct PersistedMandateV1: Codable {
        let schemaVersion: Int
        let mandate: PMMandate
    }

    private let fileManager: FileManager
    private let mandatesDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var mandatesByID: [String: PMMandate] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        mandatesDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.mandatesDirectory = mandatesDirectory ?? PMPersistencePaths.mandatesDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMMandate] {
        try loadIfNeeded()
        return sorted(mandatesByID.values)
    }

    public func get(id: String) throws -> PMMandate? {
        try loadIfNeeded()
        return mandatesByID[id]
    }

    @discardableResult
    public func upsert(_ mandate: PMMandate) throws -> PMMandate {
        try loadIfNeeded()
        let mandateID = normalizedPMID(mandate.mandateId)
        let existing = mandatesByID[mandateID]
        var updated = mandate
        updated.mandateId = mandateID
        updated.createdAt = existing?.createdAt ?? mandate.createdAt
        updated.updatedAt = now()
        mandatesByID[mandateID] = updated
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

        guard fileManager.fileExists(atPath: mandatesDirectory.path) else {
            mandatesByID = [:]
            return
        }

        var loadedMandates: [String: PMMandate] = [:]
        for url in try jsonFilesInPMDirectory(mandatesDirectory, fileManager: fileManager) {
            do {
                let mandate = try Self.decodePersistedMandate(from: Data(contentsOf: url))
                loadedMandates[mandate.mandateId] = mandate
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm mandate persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm mandate persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        mandatesByID = loadedMandates
    }

    private func persist(_ mandate: PMMandate) throws {
        try createProtectedPMDirectory(at: mandatesDirectory, fileManager: fileManager)
        let fileURL = mandatesDirectory.appendingPathComponent(mandate.mandateId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedMandateV1(schemaVersion: 1, mandate: mandate))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMMandate>.Values) -> [PMMandate] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.mandateId < rhs.mandateId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedMandate(from data: Data) throws -> PMMandate {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedMandateV1.self, from: data).mandate
        }
        return try makePMDecoder().decode(PMMandate.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMInstructionStore {
    private struct PersistedInstructionV1: Codable {
        let schemaVersion: Int
        let instruction: PMInstruction
    }

    private let fileManager: FileManager
    private let instructionsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var instructionsByID: [String: PMInstruction] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        instructionsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.instructionsDirectory = instructionsDirectory ?? PMPersistencePaths.instructionsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMInstruction] {
        try loadIfNeeded()
        return sorted(instructionsByID.values)
    }

    public func get(id: String) throws -> PMInstruction? {
        try loadIfNeeded()
        return instructionsByID[id]
    }

    @discardableResult
    public func upsert(_ instruction: PMInstruction) throws -> PMInstruction {
        try loadIfNeeded()
        let instructionID = normalizedPMID(instruction.instructionId)
        let existing = instructionsByID[instructionID]
        var updated = instruction
        updated.instructionId = instructionID
        updated.createdAt = existing?.createdAt ?? instruction.createdAt
        updated.updatedAt = now()
        instructionsByID[instructionID] = updated
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

        guard fileManager.fileExists(atPath: instructionsDirectory.path) else {
            instructionsByID = [:]
            return
        }

        var loadedInstructions: [String: PMInstruction] = [:]
        for url in try jsonFilesInPMDirectory(instructionsDirectory, fileManager: fileManager) {
            do {
                let instruction = try Self.decodePersistedInstruction(from: Data(contentsOf: url))
                loadedInstructions[instruction.instructionId] = instruction
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm instruction persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm instruction persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        instructionsByID = loadedInstructions
    }

    private func persist(_ instruction: PMInstruction) throws {
        try createProtectedPMDirectory(at: instructionsDirectory, fileManager: fileManager)
        let fileURL = instructionsDirectory.appendingPathComponent(instruction.instructionId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedInstructionV1(schemaVersion: 1, instruction: instruction))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMInstruction>.Values) -> [PMInstruction] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.instructionId < rhs.instructionId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedInstruction(from data: Data) throws -> PMInstruction {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedInstructionV1.self, from: data).instruction
        }
        return try makePMDecoder().decode(PMInstruction.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMNotebookStore {
    private struct PersistedNotebookEntryV1: Codable {
        let schemaVersion: Int
        let entry: PMNotebookEntry
    }

    private let fileManager: FileManager
    private let notebookDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var entriesByID: [String: PMNotebookEntry] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        notebookDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.notebookDirectory = notebookDirectory ?? PMPersistencePaths.notebookDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMNotebookEntry] {
        try loadIfNeeded()
        return sorted(entriesByID.values)
    }

    public func get(id: String) throws -> PMNotebookEntry? {
        try loadIfNeeded()
        return entriesByID[id]
    }

    @discardableResult
    public func upsert(_ entry: PMNotebookEntry) throws -> PMNotebookEntry {
        try loadIfNeeded()
        let entryID = normalizedPMID(entry.entryId)
        let existing = entriesByID[entryID]
        var updated = entry
        updated.entryId = entryID
        updated.createdAt = existing?.createdAt ?? entry.createdAt
        updated.updatedAt = now()
        entriesByID[entryID] = updated
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

        guard fileManager.fileExists(atPath: notebookDirectory.path) else {
            entriesByID = [:]
            return
        }

        var loadedEntries: [String: PMNotebookEntry] = [:]
        for url in try jsonFilesInPMDirectory(notebookDirectory, fileManager: fileManager) {
            do {
                let entry = try Self.decodePersistedEntry(from: Data(contentsOf: url))
                loadedEntries[entry.entryId] = entry
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm notebook persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm notebook persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        entriesByID = loadedEntries
    }

    private func persist(_ entry: PMNotebookEntry) throws {
        try createProtectedPMDirectory(at: notebookDirectory, fileManager: fileManager)
        let fileURL = notebookDirectory.appendingPathComponent(entry.entryId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedNotebookEntryV1(schemaVersion: 1, entry: entry))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMNotebookEntry>.Values) -> [PMNotebookEntry] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.entryId < rhs.entryId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedEntry(from data: Data) throws -> PMNotebookEntry {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedNotebookEntryV1.self, from: data).entry
        }
        return try makePMDecoder().decode(PMNotebookEntry.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMInteractionMemoryStore {
    private struct PersistedInteractionMemoryV1: Codable {
        let schemaVersion: Int
        let memory: PMInteractionMemoryRecord
    }

    private let fileManager: FileManager
    private let interactionMemoryDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var memoriesByID: [String: PMInteractionMemoryRecord] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        interactionMemoryDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.interactionMemoryDirectory = interactionMemoryDirectory ?? PMPersistencePaths.interactionMemoryDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMInteractionMemoryRecord] {
        try loadIfNeeded()
        return sorted(memoriesByID.values)
    }

    public func get(id: String) throws -> PMInteractionMemoryRecord? {
        try loadIfNeeded()
        return memoriesByID[id]
    }

    @discardableResult
    public func upsert(_ memory: PMInteractionMemoryRecord) throws -> PMInteractionMemoryRecord {
        try loadIfNeeded()
        let memoryID = normalizedPMID(memory.memoryId)
        let existing = memoriesByID[memoryID]
        var updated = memory
        updated.memoryId = memoryID
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

        guard fileManager.fileExists(atPath: interactionMemoryDirectory.path) else {
            memoriesByID = [:]
            return
        }

        var loadedMemories: [String: PMInteractionMemoryRecord] = [:]
        for url in try jsonFilesInPMDirectory(interactionMemoryDirectory, fileManager: fileManager) {
            do {
                let memory = try Self.decodePersistedMemory(from: Data(contentsOf: url))
                loadedMemories[memory.memoryId] = memory
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm interaction memory persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm interaction memory persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        memoriesByID = loadedMemories
    }

    private func persist(_ memory: PMInteractionMemoryRecord) throws {
        try createProtectedPMDirectory(at: interactionMemoryDirectory, fileManager: fileManager)
        let fileURL = interactionMemoryDirectory.appendingPathComponent(memory.memoryId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedInteractionMemoryV1(schemaVersion: 1, memory: memory))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMInteractionMemoryRecord>.Values) -> [PMInteractionMemoryRecord] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.memoryId < rhs.memoryId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedMemory(from data: Data) throws -> PMInteractionMemoryRecord {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedInteractionMemoryV1.self, from: data).memory
        }
        return try makePMDecoder().decode(PMInteractionMemoryRecord.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMRuntimeSettingsStore {
    private struct PersistedRuntimeSettingsV1: Codable {
        let schemaVersion: Int
        let settings: PMRuntimeSettings
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var settings: PMRuntimeSettings?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileURL = fileURL ?? PMPersistencePaths.runtimeSettingsFile()
        self.fileManager = fileManager
        self.now = now
    }

    public func load() throws -> PMRuntimeSettings? {
        try loadIfNeeded()
        return settings
    }

    public func loadOrDefault() throws -> PMRuntimeSettings {
        try loadIfNeeded()
        return settings ?? .default(now: now())
    }

    @discardableResult
    public func upsert(_ settings: PMRuntimeSettings) throws -> PMRuntimeSettings {
        try loadIfNeeded()
        let existing = self.settings
        var updated = settings
        updated.settingsId = PMRuntimeSettings.singletonID
        updated.createdAt = existing?.createdAt ?? settings.createdAt
        updated.updatedAt = now()
        self.settings = updated
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

        guard fileManager.fileExists(atPath: fileURL.path) else {
            settings = nil
            return
        }

        do {
            settings = try Self.decodePersistedSettings(from: Data(contentsOf: fileURL))
        } catch let error as PMRuntimeSettingsStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append("pm runtime settings persistence skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)")
            case .invalidDocument:
                loadDiagnostics.append("pm runtime settings persistence skipped file=\(fileURL.lastPathComponent) code=invalid_document")
            }
            settings = nil
        } catch {
            loadDiagnostics.append("pm runtime settings persistence skipped file=\(fileURL.lastPathComponent) code=io_failure")
            settings = nil
        }
    }

    private func persist(_ settings: PMRuntimeSettings) throws {
        try createProtectedPMDirectory(at: fileURL.deletingLastPathComponent(), fileManager: fileManager)
        let data = try Self.makeEncoder().encode(PersistedRuntimeSettingsV1(schemaVersion: 1, settings: settings))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private static func decodePersistedSettings(from data: Data) throws -> PMRuntimeSettings {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PMRuntimeSettingsStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedRuntimeSettingsV1.self, from: data).settings
            } catch {
                throw PMRuntimeSettingsStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(PMRuntimeSettings.self, from: data)
        } catch {
            throw PMRuntimeSettingsStoreError.invalidDocument
        }
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PortfolioStrategyBriefStore {
    private struct PersistedBriefV1: Codable {
        let schemaVersion: Int
        let brief: PortfolioStrategyBrief
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var brief: PortfolioStrategyBrief?
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileURL = fileURL ?? PMPersistencePaths.portfolioStrategyBriefFile()
        self.fileManager = fileManager
        self.now = now
    }

    public func load() throws -> PortfolioStrategyBrief? {
        try loadIfNeeded()
        return brief
    }

    public func loadOrDefault() throws -> PortfolioStrategyBrief {
        try loadIfNeeded()
        return brief ?? .default(now: now())
    }

    @discardableResult
    public func upsert(_ brief: PortfolioStrategyBrief) throws -> PortfolioStrategyBrief {
        try loadIfNeeded()
        let existing = self.brief
        let protected = protectedIncomingBrief(brief, existing: existing)
        var updated = protected.applyingDocumentExtraction()
        updated.briefId = PortfolioStrategyBrief.singletonID
        updated.createdAt = existing?.createdAt ?? protected.createdAt
        updated.updatedAt = now()
        self.brief = updated
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

        guard fileManager.fileExists(atPath: fileURL.path) else {
            brief = nil
            return
        }

        do {
            let decoded = try Self.decodePersistedBrief(from: Data(contentsOf: fileURL)).applyingDocumentExtraction()
            let upgraded = upgradedLoadedBriefIfNeeded(decoded)
            brief = upgraded
            if upgraded != decoded {
                try persist(upgraded)
            }
        } catch let error as PersistedPMDocumentError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append("portfolio strategy brief persistence skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)")
            }
            brief = nil
        } catch {
            loadDiagnostics.append("portfolio strategy brief persistence skipped file=\(fileURL.lastPathComponent) code=invalid_document")
            brief = nil
        }
    }

    private func persist(_ brief: PortfolioStrategyBrief) throws {
        try createProtectedPMDirectory(at: fileURL.deletingLastPathComponent(), fileManager: fileManager)
        let data = try Self.makeEncoder().encode(PersistedBriefV1(schemaVersion: 1, brief: brief))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func protectedIncomingBrief(
        _ incoming: PortfolioStrategyBrief,
        existing: PortfolioStrategyBrief?
    ) -> PortfolioStrategyBrief {
        guard let existing else { return incoming }

        if incoming.updateSource == .systemSeed,
           existing.updateSource != .systemSeed {
            loadDiagnostics.append("portfolio strategy brief persistence kept_existing_brief code=ignored_system_seed_overwrite")
            return existing
        }

        var protected = incoming
        let incomingDocumentBody = incoming.documentBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let existingDocumentBody = existing.documentBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if incomingDocumentBody.isEmpty == false,
           existingDocumentBody.isEmpty == false,
           incomingDocumentBody != existingDocumentBody,
           incoming.updateSource != .userEdited,
           looksLikeLegacyPlaceholderBrief(incoming),
           looksLikeLegacyPlaceholderBrief(existing) == false {
            loadDiagnostics.append("portfolio strategy brief persistence kept_existing_brief code=ignored_legacy_placeholder_regression")
            return existing
        }

        // Preserve the current saved long-form document when a later sparse update omits the body,
        // except when the existing body came from an apply-generated follow-up artifact. In that
        // case, the next explicit PM brief edit should re-render from the incoming structured fields.
        if incomingDocumentBody.isEmpty,
           existingDocumentBody.isEmpty == false,
           existing.updateSource != .strategyFollowUpCandidateApplied {
            protected.documentBody = existing.documentBody
        }

        return protected
    }

    private func upgradedLoadedBriefIfNeeded(
        _ loadedBrief: PortfolioStrategyBrief
    ) -> PortfolioStrategyBrief {
        let persistedDocumentBody = loadedBrief.documentBody?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard persistedDocumentBody.isEmpty else {
            return loadedBrief
        }

        var upgraded = loadedBrief
        upgraded.documentBody = loadedBrief.primaryDocumentBody
        return upgraded
    }

    private static func decodePersistedBrief(from data: Data) throws -> PortfolioStrategyBrief {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedBriefV1.self, from: data).brief
        }
        return try makePMDecoder().decode(PortfolioStrategyBrief.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

private func looksLikeLegacyPlaceholderBrief(_ brief: PortfolioStrategyBrief) -> Bool {
    let normalizedBody = brief.primaryDocumentBody
        .lowercased()
        .replacingOccurrences(of: "\r\n", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard normalizedBody.isEmpty == false else {
        return false
    }

    let requiredMarkers = [
        "## example technology research portfolio",
        "this charter defines the strategic foundation, investment principles, portfolio construction philosophy, and operating framework for the example technology research portfolio.",
        "this is not a passive thematic portfolio. it is an actively managed, research-intensive example strategy",
        "the central research question is how technology adoption and infrastructure constraints may affect the opportunity set over the next 24 months."
    ]

    return requiredMarkers.allSatisfy { normalizedBody.contains($0) }
}

public actor PMDecisionStore {
    private struct PersistedDecisionV1: Codable {
        let schemaVersion: Int
        let decision: PMDecisionRecord
    }

    private let fileManager: FileManager
    private let decisionsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var decisionsByID: [String: PMDecisionRecord] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        decisionsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.decisionsDirectory = decisionsDirectory ?? PMPersistencePaths.decisionsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMDecisionRecord] {
        try loadIfNeeded()
        return sorted(decisionsByID.values)
    }

    public func get(id: String) throws -> PMDecisionRecord? {
        try loadIfNeeded()
        return decisionsByID[id]
    }

    @discardableResult
    public func upsert(_ decision: PMDecisionRecord) throws -> PMDecisionRecord {
        try loadIfNeeded()
        let decisionID = normalizedPMID(decision.decisionId)
        let existing = decisionsByID[decisionID]
        var updated = decision
        updated.decisionId = decisionID
        updated.createdAt = existing?.createdAt ?? decision.createdAt
        updated.updatedAt = now()
        decisionsByID[decisionID] = updated
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

        guard fileManager.fileExists(atPath: decisionsDirectory.path) else {
            decisionsByID = [:]
            return
        }

        var loadedDecisions: [String: PMDecisionRecord] = [:]
        for url in try jsonFilesInPMDirectory(decisionsDirectory, fileManager: fileManager) {
            do {
                let decision = try Self.decodePersistedDecision(from: Data(contentsOf: url))
                loadedDecisions[decision.decisionId] = decision
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm decision persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm decision persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        decisionsByID = loadedDecisions
    }

    private func persist(_ decision: PMDecisionRecord) throws {
        try createProtectedPMDirectory(at: decisionsDirectory, fileManager: fileManager)
        let fileURL = decisionsDirectory.appendingPathComponent(decision.decisionId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedDecisionV1(schemaVersion: 1, decision: decision))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMDecisionRecord>.Values) -> [PMDecisionRecord] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.decisionId < rhs.decisionId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedDecision(from data: Data) throws -> PMDecisionRecord {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedDecisionV1.self, from: data).decision
        }
        return try makePMDecoder().decode(PMDecisionRecord.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMApprovalRequestStore {
    private struct PersistedApprovalRequestV1: Codable {
        let schemaVersion: Int
        let approvalRequest: PMApprovalRequest
    }

    private let fileManager: FileManager
    private let approvalRequestsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var approvalRequestsByID: [String: PMApprovalRequest] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        approvalRequestsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.approvalRequestsDirectory = approvalRequestsDirectory ?? PMPersistencePaths.approvalRequestsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMApprovalRequest] {
        try loadIfNeeded()
        return sorted(approvalRequestsByID.values)
    }

    public func get(id: String) throws -> PMApprovalRequest? {
        try loadIfNeeded()
        return approvalRequestsByID[id]
    }

    @discardableResult
    public func upsert(_ approvalRequest: PMApprovalRequest) throws -> PMApprovalRequest {
        try loadIfNeeded()
        let requestID = normalizedPMID(approvalRequest.approvalRequestId)
        let existing = approvalRequestsByID[requestID]
        var updated = approvalRequest
        updated.approvalRequestId = requestID
        updated.createdAt = existing?.createdAt ?? approvalRequest.createdAt
        updated.updatedAt = now()
        approvalRequestsByID[requestID] = updated
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

        guard fileManager.fileExists(atPath: approvalRequestsDirectory.path) else {
            approvalRequestsByID = [:]
            return
        }

        var loadedRequests: [String: PMApprovalRequest] = [:]
        for url in try jsonFilesInPMDirectory(approvalRequestsDirectory, fileManager: fileManager) {
            do {
                let approvalRequest = try Self.decodePersistedApprovalRequest(from: Data(contentsOf: url))
                loadedRequests[approvalRequest.approvalRequestId] = approvalRequest
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm approval request persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm approval request persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        approvalRequestsByID = loadedRequests
    }

    private func persist(_ approvalRequest: PMApprovalRequest) throws {
        try createProtectedPMDirectory(at: approvalRequestsDirectory, fileManager: fileManager)
        let fileURL = approvalRequestsDirectory.appendingPathComponent(approvalRequest.approvalRequestId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedApprovalRequestV1(schemaVersion: 1, approvalRequest: approvalRequest))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMApprovalRequest>.Values) -> [PMApprovalRequest] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.approvalRequestId < rhs.approvalRequestId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedApprovalRequest(from data: Data) throws -> PMApprovalRequest {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedApprovalRequestV1.self, from: data).approvalRequest
        }
        return try makePMDecoder().decode(PMApprovalRequest.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMCommunicationSessionStore {
    private struct PersistedCommunicationSessionV1: Codable {
        let schemaVersion: Int
        let session: PMCommunicationSession
    }

    private let fileManager: FileManager
    private let sessionsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var sessionsByID: [String: PMCommunicationSession] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        sessionsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionsDirectory = sessionsDirectory ?? PMPersistencePaths.communicationSessionsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMCommunicationSession] {
        try loadIfNeeded()
        return sorted(sessionsByID.values)
    }

    public func get(id: String) throws -> PMCommunicationSession? {
        try loadIfNeeded()
        return sessionsByID[id]
    }

    @discardableResult
    public func upsert(_ session: PMCommunicationSession) throws -> PMCommunicationSession {
        try loadIfNeeded()
        let sessionID = normalizedPMID(session.sessionId)
        let existing = sessionsByID[sessionID]
        var updated = session
        updated.sessionId = sessionID
        updated.createdAt = existing?.createdAt ?? session.createdAt
        updated.updatedAt = now()
        sessionsByID[sessionID] = updated
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

        guard fileManager.fileExists(atPath: sessionsDirectory.path) else {
            sessionsByID = [:]
            return
        }

        var loadedSessions: [String: PMCommunicationSession] = [:]
        for url in try jsonFilesInPMDirectory(sessionsDirectory, fileManager: fileManager) {
            do {
                let session = try Self.decodePersistedSession(from: Data(contentsOf: url))
                loadedSessions[session.sessionId] = session
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm communication session persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm communication session persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        sessionsByID = loadedSessions
    }

    private func persist(_ session: PMCommunicationSession) throws {
        try createProtectedPMDirectory(at: sessionsDirectory, fileManager: fileManager)
        let fileURL = sessionsDirectory.appendingPathComponent(session.sessionId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedCommunicationSessionV1(schemaVersion: 1, session: session))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMCommunicationSession>.Values) -> [PMCommunicationSession] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.sessionId < rhs.sessionId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedSession(from data: Data) throws -> PMCommunicationSession {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedCommunicationSessionV1.self, from: data).session
        }
        return try makePMDecoder().decode(PMCommunicationSession.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMCommunicationMessageStore {
    private struct PersistedCommunicationMessageV1: Codable {
        let schemaVersion: Int
        let message: PMCommunicationMessage
    }

    private let fileManager: FileManager
    private let messagesDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var messagesByID: [String: PMCommunicationMessage] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        messagesDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.messagesDirectory = messagesDirectory ?? PMPersistencePaths.communicationMessagesDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMCommunicationMessage] {
        try loadIfNeeded()
        return sorted(messagesByID.values)
    }

    public func get(id: String) throws -> PMCommunicationMessage? {
        try loadIfNeeded()
        return messagesByID[id]
    }

    @discardableResult
    public func upsert(_ message: PMCommunicationMessage) throws -> PMCommunicationMessage {
        try loadIfNeeded()
        let messageID = normalizedPMID(message.messageId)
        let existing = messagesByID[messageID]
        var updated = message
        updated.messageId = messageID
        updated.createdAt = existing?.createdAt ?? message.createdAt
        updated.updatedAt = now()
        messagesByID[messageID] = updated
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

        guard fileManager.fileExists(atPath: messagesDirectory.path) else {
            messagesByID = [:]
            return
        }

        var loadedMessages: [String: PMCommunicationMessage] = [:]
        for url in try jsonFilesInPMDirectory(messagesDirectory, fileManager: fileManager) {
            do {
                let message = try Self.decodePersistedMessage(from: Data(contentsOf: url))
                loadedMessages[message.messageId] = message
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm communication message persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm communication message persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        messagesByID = loadedMessages
    }

    private func persist(_ message: PMCommunicationMessage) throws {
        try createProtectedPMDirectory(at: messagesDirectory, fileManager: fileManager)
        let fileURL = messagesDirectory.appendingPathComponent(message.messageId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedCommunicationMessageV1(schemaVersion: 1, message: message))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMCommunicationMessage>.Values) -> [PMCommunicationMessage] {
        values.sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt > rhs.sentAt
        }
    }

    private static func decodePersistedMessage(from data: Data) throws -> PMCommunicationMessage {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedCommunicationMessageV1.self, from: data).message
        }
        return try makePMDecoder().decode(PMCommunicationMessage.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

public actor PMDelegationStore {
    private struct PersistedDelegationV1: Codable {
        let schemaVersion: Int
        let delegation: PMDelegationRecord
    }

    private let fileManager: FileManager
    private let delegationsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var delegationsByID: [String: PMDelegationRecord] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        delegationsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.delegationsDirectory = delegationsDirectory ?? PMPersistencePaths.delegationsDirectory()
        self.fileManager = fileManager
        self.now = now
    }

    public func loadAll() throws -> [PMDelegationRecord] {
        try loadIfNeeded()
        return sorted(delegationsByID.values)
    }

    public func get(id: String) throws -> PMDelegationRecord? {
        try loadIfNeeded()
        return delegationsByID[id]
    }

    @discardableResult
    public func upsert(_ delegation: PMDelegationRecord) throws -> PMDelegationRecord {
        try loadIfNeeded()
        let delegationID = normalizedPMID(delegation.delegationId)
        let existing = delegationsByID[delegationID]
        var updated = delegation
        updated.delegationId = delegationID
        updated.createdAt = existing?.createdAt ?? delegation.createdAt
        updated.updatedAt = now()
        delegationsByID[delegationID] = updated
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

        guard fileManager.fileExists(atPath: delegationsDirectory.path) else {
            delegationsByID = [:]
            return
        }

        var loadedDelegations: [String: PMDelegationRecord] = [:]
        for url in try jsonFilesInPMDirectory(delegationsDirectory, fileManager: fileManager) {
            do {
                let delegation = try Self.decodePersistedDelegation(from: Data(contentsOf: url))
                loadedDelegations[delegation.delegationId] = delegation
            } catch let error as PersistedPMDocumentError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append("pm delegation persistence skipped file=\(url.lastPathComponent) code=unsupported_schema_version version=\(version)")
                }
            } catch {
                loadDiagnostics.append("pm delegation persistence skipped file=\(url.lastPathComponent) code=invalid_document")
            }
        }
        delegationsByID = loadedDelegations
    }

    private func persist(_ delegation: PMDelegationRecord) throws {
        try createProtectedPMDirectory(at: delegationsDirectory, fileManager: fileManager)
        let fileURL = delegationsDirectory.appendingPathComponent(delegation.delegationId).appendingPathExtension("json")
        let data = try Self.makeEncoder().encode(PersistedDelegationV1(schemaVersion: 1, delegation: delegation))
        try writeProtectedPMFile(data: data, to: fileURL, fileManager: fileManager)
    }

    private func sorted(_ values: Dictionary<String, PMDelegationRecord>.Values) -> [PMDelegationRecord] {
        values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.delegationId < rhs.delegationId }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func decodePersistedDelegation(from data: Data) throws -> PMDelegationRecord {
        let decoder = makePMDecoder()
        if let probe = try? decoder.decode(PersistedPMSchemaProbe.self, from: data), let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else { throw PersistedPMDocumentError.unsupportedSchemaVersion(schemaVersion) }
            return try makePMDecoder().decode(PersistedDelegationV1.self, from: data).delegation
        }
        return try makePMDecoder().decode(PMDelegationRecord.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder { makePMEncoder() }
}

private func normalizedPMID(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? UUID().uuidString : trimmed
}

private func createProtectedPMDirectory(at url: URL, fileManager: FileManager) throws {
    try fileManager.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
}

private func writeProtectedPMFile(data: Data, to fileURL: URL, fileManager: FileManager) throws {
    try data.write(to: fileURL, options: [.atomic])
    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
}

private func jsonFilesInPMDirectory(_ directory: URL, fileManager: FileManager) throws -> [URL] {
    try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "json" }
}

private func makePMEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    return encoder
}

private func makePMDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
    return decoder
}
