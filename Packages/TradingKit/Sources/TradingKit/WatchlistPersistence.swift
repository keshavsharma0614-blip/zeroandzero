import Foundation

public protocol WatchlistPersisting: Sendable {
    func loadWatchlistSymbols() -> [String]
    func saveWatchlistSymbols(_ symbols: [String])
}

public enum WatchlistPersistenceError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public struct FileWatchlistPersistence: WatchlistPersisting {
    private struct PersistedWatchlistV1: Codable {
        let schemaVersion: Int
        let symbols: [String]
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileURL: URL

    public init(fileURL: URL = FileWatchlistPersistence.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public func loadWatchlistSymbols() -> [String] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        do {
            let decoded = try Self.decodeSymbols(from: data)
            return Array(MarketDataSubscriptionSet.normalized(decoded)).sorted()
        } catch {
            return []
        }
    }

    public func saveWatchlistSymbols(_ symbols: [String]) {
        let normalized = Array(MarketDataSubscriptionSet.normalized(symbols)).sorted()
        let directory = fileURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let wrapped = PersistedWatchlistV1(
                schemaVersion: 1,
                symbols: normalized
            )
            let data = try JSONEncoder().encode(wrapped)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // v1 persistence is best-effort; failure is surfaced via diagnostics in Engine.
        }
    }

    static func decodeSymbols(from data: Data) throws -> [String] {
        if let probe = try? JSONDecoder().decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw WatchlistPersistenceError.unsupportedSchemaVersion(schemaVersion)
            }
            return try JSONDecoder().decode(PersistedWatchlistV1.self, from: data).symbols
        }

        // Legacy v0 format stored symbols directly.
        guard let symbols = try? JSONDecoder().decode([String].self, from: data) else {
            throw WatchlistPersistenceError.invalidDocument
        }
        return symbols
    }

    public static func defaultFileURL() -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return root
            .appendingPathComponent("AlgoTradingMac", isDirectory: true)
            .appendingPathComponent("watchlist.json", isDirectory: false)
    }
}
