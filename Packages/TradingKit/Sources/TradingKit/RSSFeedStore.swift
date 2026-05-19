import Foundation

public enum RSSFeedStoreError: Error, Sendable, Equatable {
    case feedNotFound(id: String)
    case invalidFeed(message: String)
}

extension RSSFeedStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .feedNotFound(let id):
            return "RSS feed not found: \(id)"
        case .invalidFeed(let message):
            return message
        }
    }
}

public actor RSSFeedStore {
    private enum PersistedFeedError: Error {
        case unsupportedSchemaVersion(Int)
    }

    private struct PersistedFeedsV1: Codable {
        let schemaVersion: Int
        let feeds: [RSSFeed]
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL

    private var loaded = false
    private var storeWasMissingAtLoad = false
    private var feedsByID: [String: RSSFeed] = [:]
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("rss_feeds.json", isDirectory: false)
        self.fileManager = fileManager
    }

    public func listFeeds() throws -> [RSSFeed] {
        try loadIfNeeded()
        return feedsByID.values.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.id < rhs.id
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func get(id: String) throws -> RSSFeed? {
        try loadIfNeeded()
        return feedsByID[id]
    }

    @discardableResult
    public func upsert(_ feed: RSSFeed) throws -> RSSFeed {
        try loadIfNeeded()
        let normalized = try validate(feed)
        feedsByID[normalized.id] = normalized
        try persistAll()
        return normalized
    }

    public func remove(id: String) throws {
        try loadIfNeeded()
        guard feedsByID.removeValue(forKey: id) != nil else {
            throw RSSFeedStoreError.feedNotFound(id: id)
        }
        try persistAll()
    }

    @discardableResult
    public func seedDefaultsIfStoreMissing() throws -> [RSSFeed] {
        try loadIfNeeded()
        guard storeWasMissingAtLoad, feedsByID.isEmpty else {
            return try listFeeds()
        }

        let defaults = Self.defaultFeeds
        feedsByID = Dictionary(uniqueKeysWithValues: defaults.map { ($0.id, $0) })
        try persistAll()
        return defaults
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
            feedsByID = [:]
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let feeds = try Self.decodeFeeds(from: data)
            feedsByID = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
        } catch let error as PersistedFeedError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "rss feed persistence skipped file=\(fileURL.lastPathComponent) code=unsupported_schema_version version=\(version)"
                )
            }
            feedsByID = [:]
        } catch {
            loadDiagnostics.append(
                "rss feed persistence skipped file=\(fileURL.lastPathComponent) code=invalid_document"
            )
            feedsByID = [:]
        }
    }

    private func persistAll() throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let wrapped = PersistedFeedsV1(
            schemaVersion: 1,
            feeds: feedsByID.values.sorted { $0.id < $1.id }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(wrapped)
        try data.write(to: fileURL, options: [.atomic])
        storeWasMissingAtLoad = false
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeFeeds(from data: Data) throws -> [RSSFeed] {
        let decoder = JSONDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw PersistedFeedError.unsupportedSchemaVersion(schemaVersion)
            }
            return try decoder.decode(PersistedFeedsV1.self, from: data).feeds
        }

        // Legacy v0 accepted format: raw array of RSSFeed.
        return try decoder.decode([RSSFeed].self, from: data)
    }

    private func validate(_ feed: RSSFeed) throws -> RSSFeed {
        var normalized = feed
        normalized.name = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.url = normalized.url.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.pollIntervalSec = max(15, normalized.pollIntervalSec)
        normalized.tags = normalized.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalized.name.isEmpty else {
            throw RSSFeedStoreError.invalidFeed(message: "RSS feed name is required.")
        }
        guard !normalized.url.isEmpty else {
            throw RSSFeedStoreError.invalidFeed(message: "RSS feed URL is required.")
        }
        guard let components = URLComponents(string: normalized.url),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false
        else {
            throw RSSFeedStoreError.invalidFeed(
                message: "RSS feed URL must be a valid http(s) URL."
            )
        }

        return normalized
    }

    // Placeholder URLs are intentional until concrete feed URLs are documented in-repo.
    private static let defaultFeeds: [RSSFeed] = [
        RSSFeed(
            name: "Federal Reserve RSS",
            url: "https://example.com/fed-rss.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: ["macro", "rates"]
        ),
        RSSFeed(
            name: "SEC RSS",
            url: "https://example.com/sec-rss.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: ["filings", "regulatory"]
        ),
        RSSFeed(
            name: "MarketWatch RSS",
            url: "https://example.com/marketwatch-rss.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: ["headlines", "markets"]
        )
    ]
}
