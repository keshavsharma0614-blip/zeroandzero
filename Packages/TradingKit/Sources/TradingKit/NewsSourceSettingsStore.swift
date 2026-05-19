import Foundation

public struct BuiltInNewsSourcesSettings: Codable, Sendable, Equatable {
    public var alpacaNewsEnabled: Bool

    public init(alpacaNewsEnabled: Bool = true) {
        self.alpacaNewsEnabled = alpacaNewsEnabled
    }
}

public enum BuiltInNewsSourcesSettingsStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public actor BuiltInNewsSourcesSettingsStore {
    private struct PersistedSettingsV1: Codable {
        let schemaVersion: Int
        let settings: BuiltInNewsSourcesSettings
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL

    private var loaded = false
    private var cachedSettings = BuiltInNewsSourcesSettings()
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("news_source_settings.json", isDirectory: false)
        self.fileManager = fileManager
    }

    public func load() -> BuiltInNewsSourcesSettings {
        loadIfNeeded()
        return cachedSettings
    }

    @discardableResult
    public func save(_ settings: BuiltInNewsSourcesSettings) throws -> BuiltInNewsSourcesSettings {
        loadIfNeeded()
        cachedSettings = settings
        try persist(settings)
        return settings
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
            cachedSettings = BuiltInNewsSourcesSettings()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cachedSettings = try Self.decodeSettings(from: data)
        } catch let error as BuiltInNewsSourcesSettingsStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "news source settings fallback defaults code=unsupported_schema_version version=\(version)"
                )
            case .invalidDocument:
                loadDiagnostics.append(
                    "news source settings fallback defaults code=invalid_document"
                )
            }
            cachedSettings = BuiltInNewsSourcesSettings()
        } catch {
            loadDiagnostics.append(
                "news source settings fallback defaults code=io_failure"
            )
            cachedSettings = BuiltInNewsSourcesSettings()
        }
    }

    private func persist(_ settings: BuiltInNewsSourcesSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let wrapped = PersistedSettingsV1(schemaVersion: 1, settings: settings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(wrapped)
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeSettings(from data: Data) throws -> BuiltInNewsSourcesSettings {
        let decoder = JSONDecoder()

        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw BuiltInNewsSourcesSettingsStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedSettingsV1.self, from: data).settings
            } catch {
                throw BuiltInNewsSourcesSettingsStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(BuiltInNewsSourcesSettings.self, from: data)
        } catch {
            throw BuiltInNewsSourcesSettingsStoreError.invalidDocument
        }
    }
}
