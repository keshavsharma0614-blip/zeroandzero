import Foundation

public struct NewsStoreAppendResult: Sendable, Equatable {
    public let inserted: Int
    public let duplicates: Int

    public init(inserted: Int, duplicates: Int) {
        self.inserted = inserted
        self.duplicates = duplicates
    }
}

public struct NewsRetentionResult: Sendable, Equatable {
    public let filesRemoved: Int
    public let bytesRemoved: Int64

    public init(filesRemoved: Int, bytesRemoved: Int64) {
        self.filesRemoved = filesRemoved
        self.bytesRemoved = bytesRemoved
    }
}

public struct NewsSourceCleanupResult: Sendable, Equatable {
    public let removedEvents: Int
    public let affectedFiles: Int

    public init(removedEvents: Int, affectedFiles: Int) {
        self.removedEvents = removedEvents
        self.affectedFiles = affectedFiles
    }
}

public struct NewsStoreRuntimeDiagnostics: Sendable, Equatable {
    public var knownEventIDLoadCount: Int
    public var knownEventIDLoadDecodedLineCount: Int
    public var listRecentRequestCount: Int
    public var listRecentFileReadCount: Int
    public var listRecentDecodedLineCount: Int
    public var listRecentReturnedCount: Int
    public var listRecentByReceivedAtRequestCount: Int
    public var listRecentByReceivedAtFileReadCount: Int
    public var listRecentByReceivedAtDecodedLineCount: Int
    public var listRecentByReceivedAtReturnedCount: Int
    public var purgeRSSSourcesCount: Int
    public var purgeRSSSourcesFileScanCount: Int
    public var purgeRSSSourcesDecodedLineCount: Int
    public var purgeRSSSourcesRemovedEventCount: Int
    public var purgeRSSSourcesAffectedFileCount: Int

    public init(
        knownEventIDLoadCount: Int = 0,
        knownEventIDLoadDecodedLineCount: Int = 0,
        listRecentRequestCount: Int = 0,
        listRecentFileReadCount: Int = 0,
        listRecentDecodedLineCount: Int = 0,
        listRecentReturnedCount: Int = 0,
        listRecentByReceivedAtRequestCount: Int = 0,
        listRecentByReceivedAtFileReadCount: Int = 0,
        listRecentByReceivedAtDecodedLineCount: Int = 0,
        listRecentByReceivedAtReturnedCount: Int = 0,
        purgeRSSSourcesCount: Int = 0,
        purgeRSSSourcesFileScanCount: Int = 0,
        purgeRSSSourcesDecodedLineCount: Int = 0,
        purgeRSSSourcesRemovedEventCount: Int = 0,
        purgeRSSSourcesAffectedFileCount: Int = 0
    ) {
        self.knownEventIDLoadCount = knownEventIDLoadCount
        self.knownEventIDLoadDecodedLineCount = knownEventIDLoadDecodedLineCount
        self.listRecentRequestCount = listRecentRequestCount
        self.listRecentFileReadCount = listRecentFileReadCount
        self.listRecentDecodedLineCount = listRecentDecodedLineCount
        self.listRecentReturnedCount = listRecentReturnedCount
        self.listRecentByReceivedAtRequestCount = listRecentByReceivedAtRequestCount
        self.listRecentByReceivedAtFileReadCount = listRecentByReceivedAtFileReadCount
        self.listRecentByReceivedAtDecodedLineCount = listRecentByReceivedAtDecodedLineCount
        self.listRecentByReceivedAtReturnedCount = listRecentByReceivedAtReturnedCount
        self.purgeRSSSourcesCount = purgeRSSSourcesCount
        self.purgeRSSSourcesFileScanCount = purgeRSSSourcesFileScanCount
        self.purgeRSSSourcesDecodedLineCount = purgeRSSSourcesDecodedLineCount
        self.purgeRSSSourcesRemovedEventCount = purgeRSSSourcesRemovedEventCount
        self.purgeRSSSourcesAffectedFileCount = purgeRSSSourcesAffectedFileCount
    }
}

public actor NewsStore {
    private enum NewsStoreDecodeError: Error {
        case unsupportedSchemaVersion(Int)
    }

    private enum LoadPurpose {
        case knownIDs
        case listRecent
        case listRecentByReceivedAt
        case purgeRSSSources
        case getByID
    }

    private struct PersistedNewsEventV1: Codable {
        let schemaVersion: Int
        let event: NewsEvent
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let newsDirectory: URL
    private let now: @Sendable () -> Date

    private var loaded = false
    private var knownEventIDs: Set<String> = []
    private var loadDiagnostics: [String] = []
    private var runtimeDiagnostics = NewsStoreRuntimeDiagnostics()

    public init(
        newsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.newsDirectory = newsDirectory
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("news", isDirectory: true)
        self.fileManager = fileManager
        self.now = now
    }

    @discardableResult
    public func append(_ events: [NewsEvent]) throws -> NewsStoreAppendResult {
        try loadIfNeeded()
        guard !events.isEmpty else {
            return NewsStoreAppendResult(inserted: 0, duplicates: 0)
        }

        try ensureDirectoryExists()
        var inserted = 0
        var duplicates = 0

        for rawEvent in events {
            let event = Self.sanitizedForPersistence(rawEvent)
            if knownEventIDs.contains(event.eventId) {
                duplicates += 1
                continue
            }

            let fileURL = newsFileURL(for: event.publishedAt)
            try appendLine(event: event, to: fileURL)
            knownEventIDs.insert(event.eventId)
            inserted += 1
        }

        return NewsStoreAppendResult(inserted: inserted, duplicates: duplicates)
    }

    @discardableResult
    public func purgeRSSSources(notIn activeSources: Set<String>) throws -> NewsSourceCleanupResult {
        runtimeDiagnostics.purgeRSSSourcesCount += 1
        let shouldReloadKnownIDsAfterMutation = loaded
        guard fileManager.fileExists(atPath: newsDirectory.path) else {
            return NewsSourceCleanupResult(removedEvents: 0, affectedFiles: 0)
        }

        let urls = try datedNewsFiles()
        var removedEvents = 0
        var affectedFiles = 0

        for url in urls {
            let events = try loadEvents(from: url, purpose: .purgeRSSSources)
            let kept = events.filter { event in
                guard event.source.hasPrefix("rss_") else {
                    return true
                }
                return activeSources.contains(event.source)
            }

            guard kept.count != events.count else {
                continue
            }

            removedEvents += events.count - kept.count
            affectedFiles += 1

            if kept.isEmpty {
                try fileManager.removeItem(at: url)
            } else {
                try rewrite(events: kept, to: url)
            }
        }

        runtimeDiagnostics.purgeRSSSourcesRemovedEventCount += removedEvents
        runtimeDiagnostics.purgeRSSSourcesAffectedFileCount += affectedFiles

        if removedEvents > 0, shouldReloadKnownIDsAfterMutation {
            knownEventIDs.removeAll()
            loaded = false
            try loadIfNeeded()
        }

        return NewsSourceCleanupResult(
            removedEvents: removedEvents,
            affectedFiles: affectedFiles
        )
    }

    public func listRecent(
        limit: Int,
        since: Date? = nil
    ) throws -> [NewsEvent] {
        runtimeDiagnostics.listRecentRequestCount += 1
        let resolvedLimit = max(1, limit)
        let urls = try datedNewsFiles()
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? utcCalendar.timeZone
        let sinceDay = since.map {
            utcCalendar.startOfDay(for: $0)
        }

        var events: [NewsEvent] = []
        for url in urls {
            if let sinceDay,
               let fileDate = dateFromNewsFileName(url.lastPathComponent),
               fileDate < sinceDay {
                break
            }
            let fileEvents = try loadEvents(from: url, purpose: .listRecent)
            for rawEvent in fileEvents {
                let event = Self.sanitizedForActiveUse(rawEvent)
                if let since, event.publishedAt < since {
                    continue
                }
                events.append(event)
            }

            events.sort { lhs, rhs in
                if lhs.publishedAt == rhs.publishedAt {
                    return lhs.eventId > rhs.eventId
                }
                return lhs.publishedAt > rhs.publishedAt
            }
            if events.count > resolvedLimit {
                events = Array(events.prefix(resolvedLimit))
            }
            if events.count >= resolvedLimit {
                break
            }
        }

        let sorted = events.sorted { lhs, rhs in
            if lhs.publishedAt == rhs.publishedAt {
                return lhs.eventId > rhs.eventId
            }
            return lhs.publishedAt > rhs.publishedAt
        }

        let result = sorted.count <= resolvedLimit
            ? sorted
            : Array(sorted.prefix(resolvedLimit))
        runtimeDiagnostics.listRecentReturnedCount += result.count
        return result
    }

    public func listRecentByReceivedAt(
        limit: Int,
        receivedSince: Date? = nil
    ) throws -> [NewsEvent] {
        runtimeDiagnostics.listRecentByReceivedAtRequestCount += 1
        let resolvedLimit = max(1, limit)
        let urls = try datedNewsFiles()

        var events: [NewsEvent] = []
        for url in urls {
            let fileEvents = try loadEvents(from: url, purpose: .listRecentByReceivedAt)
            for rawEvent in fileEvents {
                let event = Self.sanitizedForActiveUse(rawEvent)
                if let receivedSince, event.receivedAt < receivedSince {
                    continue
                }
                events.append(event)
            }
        }

        let sorted = events.sorted { lhs, rhs in
            if lhs.receivedAt == rhs.receivedAt {
                return lhs.eventId < rhs.eventId
            }
            return lhs.receivedAt < rhs.receivedAt
        }

        let result = sorted.count <= resolvedLimit
            ? sorted
            : Array(sorted.prefix(resolvedLimit))
        runtimeDiagnostics.listRecentByReceivedAtReturnedCount += result.count
        return result
    }

    public func getById(_ id: String) throws -> NewsEvent? {
        let urls = try datedNewsFiles()
        for url in urls {
            let events = try loadEvents(from: url, purpose: .getByID)
            if let event = events.first(where: { $0.eventId == id }) {
                return Self.sanitizedForActiveUse(event)
            }
        }
        return nil
    }

    public func newsDirectoryURL() -> URL {
        newsDirectory
    }

    @discardableResult
    public func purge(
        keepDays: Int,
        maxTotalMB: Int? = nil,
        dryRun: Bool = false
    ) throws -> NewsRetentionResult {
        try loadIfNeeded()
        try ensureDirectoryExists()

        let resolvedKeepDays = max(1, keepDays)
        let threshold = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -resolvedKeepDays,
            to: now()
        ) ?? now()

        var removedFiles = 0
        var removedBytes: Int64 = 0

        let urls = try datedNewsFiles()
        var retained: [(url: URL, size: Int64)] = []

        for url in urls {
            if let date = dateFromNewsFileName(url.lastPathComponent), date < threshold {
                let size = try fileSize(url)
                if !dryRun {
                    try fileManager.removeItem(at: url)
                }
                removedFiles += 1
                removedBytes += size
                continue
            }
            retained.append((url: url, size: try fileSize(url)))
        }

        if let maxTotalMB {
            let maxBytes = Int64(maxTotalMB) * 1_048_576
            var totalBytes = retained.reduce(Int64(0)) { $0 + $1.size }
            if totalBytes > maxBytes {
                let oldestFirst = retained.sorted { lhs, rhs in
                    lhs.url.lastPathComponent < rhs.url.lastPathComponent
                }
                for candidate in oldestFirst where totalBytes > maxBytes {
                    if !dryRun {
                        try fileManager.removeItem(at: candidate.url)
                    }
                    totalBytes -= candidate.size
                    removedFiles += 1
                    removedBytes += candidate.size
                }
            }
        }

        if !dryRun {
            knownEventIDs.removeAll()
            loaded = false
            try loadIfNeeded()
        }

        return NewsRetentionResult(filesRemoved: removedFiles, bytesRemoved: removedBytes)
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    public func runtimeDiagnosticsSnapshot() -> NewsStoreRuntimeDiagnostics {
        runtimeDiagnostics
    }

    public func resetRuntimeDiagnostics() {
        runtimeDiagnostics = NewsStoreRuntimeDiagnostics()
    }

    private func loadIfNeeded() throws {
        guard !loaded else {
            return
        }
        loaded = true
        knownEventIDs = []
        runtimeDiagnostics.knownEventIDLoadCount += 1

        guard fileManager.fileExists(atPath: newsDirectory.path) else {
            return
        }

        let urls = try datedNewsFiles()
        for url in urls {
            let events = try loadEvents(from: url, purpose: .knownIDs)
            for event in events {
                knownEventIDs.insert(event.eventId)
            }
        }
    }

    private func loadEvents(from fileURL: URL, purpose: LoadPurpose) throws -> [NewsEvent] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        var events: [NewsEvent] = []
        var decodedLineCount = 0
        for (index, rawLine) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            decodedLineCount += 1
            do {
                let data = Data(line.utf8)
                let event = try Self.decodeLine(data: data)
                events.append(event)
            } catch let error as NewsStoreDecodeError {
                switch error {
                case .unsupportedSchemaVersion(let version):
                    loadDiagnostics.append(
                        "news persistence skipped line file=\(fileURL.lastPathComponent) line=\(index + 1) code=unsupported_schema_version version=\(version)"
                    )
                }
            } catch {
                loadDiagnostics.append(
                    "news persistence skipped line file=\(fileURL.lastPathComponent) line=\(index + 1) code=invalid_document"
                )
            }
        }

        recordLoad(purpose: purpose, decodedLineCount: decodedLineCount)
        return events
    }

    private func recordLoad(purpose: LoadPurpose, decodedLineCount: Int) {
        switch purpose {
        case .knownIDs:
            runtimeDiagnostics.knownEventIDLoadDecodedLineCount += decodedLineCount
        case .listRecent:
            runtimeDiagnostics.listRecentFileReadCount += 1
            runtimeDiagnostics.listRecentDecodedLineCount += decodedLineCount
        case .listRecentByReceivedAt:
            runtimeDiagnostics.listRecentByReceivedAtFileReadCount += 1
            runtimeDiagnostics.listRecentByReceivedAtDecodedLineCount += decodedLineCount
        case .purgeRSSSources:
            runtimeDiagnostics.purgeRSSSourcesFileScanCount += 1
            runtimeDiagnostics.purgeRSSSourcesDecodedLineCount += decodedLineCount
        case .getByID:
            break
        }
    }

    private func appendLine(event: NewsEvent, to fileURL: URL) throws {
        let lineData = try makeLine(event: event)
        if !fileManager.fileExists(atPath: fileURL.path) {
            let created = fileManager.createFile(
                atPath: fileURL.path,
                contents: Data(),
                attributes: [.posixPermissions: 0o600]
            )
            if !created {
                throw NSError(domain: "TradingKit.NewsStore", code: 1)
            }
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer {
            try? handle.close()
        }

        try handle.seekToEnd()
        try handle.write(contentsOf: lineData)
    }

    private func rewrite(events: [NewsEvent], to fileURL: URL) throws {
        guard !events.isEmpty else {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }

        var data = Data()
        for event in events {
            try data.append(contentsOf: makeLine(event: Self.sanitizedForPersistence(event)))
        }
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private func makeLine(event: NewsEvent) throws -> Data {
        let wrapped = PersistedNewsEventV1(schemaVersion: 1, event: event)
        let encoder = Self.makeEncoder()
        let json = try encoder.encode(wrapped)
        guard var line = String(data: json, encoding: .utf8) else {
            return Data()
        }
        line.append("\n")
        return Data(line.utf8)
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(
            at: newsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func datedNewsFiles() throws -> [URL] {
        guard fileManager.fileExists(atPath: newsDirectory.path) else {
            return []
        }
        let urls = try fileManager.contentsOfDirectory(
            at: newsDirectory,
            includingPropertiesForKeys: nil
        )
        return urls
            .filter { $0.lastPathComponent.hasPrefix("news_events_") && $0.pathExtension.lowercased() == "jsonl" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func newsFileURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: date)
        return newsDirectory
            .appendingPathComponent("news_events_\(day)", isDirectory: false)
            .appendingPathExtension("jsonl")
    }

    private func dateFromNewsFileName(_ fileName: String) -> Date? {
        let prefix = "news_events_"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(".jsonl") else {
            return nil
        }
        let day = String(fileName.dropFirst(prefix.count).dropLast(".jsonl".count))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: day)
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return decoder
    }

    private static func decodeLine(data: Data) throws -> NewsEvent {
        let decoder = makeDecoder()
        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw NewsStoreDecodeError.unsupportedSchemaVersion(schemaVersion)
            }
            return try makeDecoder().decode(PersistedNewsEventV1.self, from: data).event
        }

        // Legacy v0 accepts raw NewsEvent lines.
        return try makeDecoder().decode(NewsEvent.self, from: data)
    }

    private static func sanitizedForPersistence(_ event: NewsEvent) -> NewsEvent {
        let clampedPublishedAt = min(event.publishedAt, event.receivedAt)
        guard clampedPublishedAt != event.publishedAt else {
            return event
        }

        return NewsEvent(
            eventId: event.eventId,
            source: event.source,
            title: event.title,
            url: event.url,
            publishedAt: clampedPublishedAt,
            receivedAt: event.receivedAt,
            summary: event.summary,
            rawSymbolHints: event.rawSymbolHints,
            tags: event.tags,
            payloadVersion: event.payloadVersion
        )
    }

    private static func sanitizedForActiveUse(_ event: NewsEvent) -> NewsEvent {
        sanitizedForPersistence(event)
    }

}
