import Foundation

public enum RetentionPolicyStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public actor RetentionPolicyStore {
    private struct PersistedPolicyV1: Codable {
        let schemaVersion: Int
        let policy: RetentionPolicy
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL

    private var loaded = false
    private var cachedPolicy: RetentionPolicy = .default
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("retention_policy.json", isDirectory: false)
        self.fileManager = fileManager
    }

    public func load() -> RetentionPolicy {
        loadIfNeeded()
        return cachedPolicy
    }

    @discardableResult
    public func save(_ policy: RetentionPolicy) throws -> RetentionPolicy {
        loadIfNeeded()
        let normalized = policy.normalized()
        cachedPolicy = normalized
        try persist(normalized)
        return normalized
    }

    @discardableResult
    public func resetToDefaults() throws -> RetentionPolicy {
        try save(.default)
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
            cachedPolicy = .default
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cachedPolicy = try Self.decodePolicy(from: data).normalized()
        } catch let error as RetentionPolicyStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "retention policy fallback defaults code=unsupported_schema_version version=\(version)"
                )
            case .invalidDocument:
                loadDiagnostics.append(
                    "retention policy fallback defaults code=invalid_document"
                )
            }
            cachedPolicy = .default
        } catch {
            loadDiagnostics.append(
                "retention policy fallback defaults code=io_failure"
            )
            cachedPolicy = .default
        }
    }

    private func persist(_ policy: RetentionPolicy) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let wrapped = PersistedPolicyV1(schemaVersion: 1, policy: policy)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        let data = try encoder.encode(wrapped)
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodePolicy(from data: Data) throws -> RetentionPolicy {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy

        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw RetentionPolicyStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedPolicyV1.self, from: data).policy
            } catch {
                throw RetentionPolicyStoreError.invalidDocument
            }
        }

        // Legacy v0 format stores raw policy JSON.
        do {
            return try decoder.decode(RetentionPolicy.self, from: data)
        } catch {
            throw RetentionPolicyStoreError.invalidDocument
        }
    }
}
