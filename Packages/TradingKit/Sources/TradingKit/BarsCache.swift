import Foundation
import SQLite3

public enum BarsCacheError: AgentControlError, Sendable, Equatable {
    case openFailed(message: String)
    case executeFailed(message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)

    public var code: String {
        switch self {
        case .openFailed:
            return "bars_cache_open_failed"
        case .executeFailed:
            return "bars_cache_execute_failed"
        case .prepareFailed:
            return "bars_cache_prepare_failed"
        case .stepFailed:
            return "bars_cache_step_failed"
        }
    }

    public var message: String {
        switch self {
        case .openFailed(let message),
             .executeFailed(let message),
             .prepareFailed(let message),
             .stepFailed(let message):
            return message
        }
    }
}

public actor BarsCache {
    private final class SQLiteConnectionBox: @unchecked Sendable {
        let handle: OpaquePointer

        init(handle: OpaquePointer) {
            self.handle = handle
        }

        deinit {
            sqlite3_close_v2(handle)
        }
    }

    private let fileManager: FileManager
    private let databaseURL: URL
    private var db: SQLiteConnectionBox?

    public init(
        databaseURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.databaseURL = databaseURL
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("bars_cache.sqlite", isDirectory: false)
        self.fileManager = fileManager
    }

    public func databaseFileURL() -> URL {
        databaseURL
    }

    public func close() {
        guard let db else {
            return
        }
        sqlite3_close_v2(db.handle)
        self.db = nil
    }

    @discardableResult
    public func upsertBars(_ bars: [Bar]) throws -> Int {
        guard !bars.isEmpty else {
            return 0
        }
        try openIfNeeded()
        guard let db else {
            throw BarsCacheError.openFailed(message: "Bars cache is unavailable.")
        }

        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let sql = """
            INSERT INTO bars(symbol,timeframe,ts,open,high,low,close,volume)
            VALUES(?,?,?,?,?,?,?,?)
            ON CONFLICT(symbol,timeframe,ts)
            DO UPDATE SET
              open=excluded.open,
              high=excluded.high,
              low=excluded.low,
              close=excluded.close,
              volume=excluded.volume
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db.handle, sql, -1, &statement, nil) == SQLITE_OK else {
                throw BarsCacheError.prepareFailed(message: errorMessage(db.handle))
            }
            defer {
                sqlite3_finalize(statement)
            }

            for bar in bars {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                sqlite3_bind_text(statement, 1, bar.symbol, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, bar.timeframe.rawValue, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(statement, 3, Int64(bar.timestamp.timeIntervalSince1970))
                sqlite3_bind_double(statement, 4, bar.open)
                sqlite3_bind_double(statement, 5, bar.high)
                sqlite3_bind_double(statement, 6, bar.low)
                sqlite3_bind_double(statement, 7, bar.close)
                sqlite3_bind_double(statement, 8, bar.volume)

                let step = sqlite3_step(statement)
                guard step == SQLITE_DONE else {
                    throw BarsCacheError.stepFailed(message: errorMessage(db.handle))
                }
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            if let cacheError = error as? BarsCacheError {
                throw cacheError
            }
            throw BarsCacheError.executeFailed(message: error.localizedDescription)
        }

        return bars.count
    }

    public func queryBars(
        symbols: [String],
        timeframe: BarTimeframe,
        start: Date,
        end: Date
    ) throws -> [Bar] {
        let normalizedSymbols = Array(MarketDataSubscriptionSet.normalized(symbols)).sorted()
        guard !normalizedSymbols.isEmpty else {
            return []
        }
        try openIfNeeded()
        guard let db else {
            throw BarsCacheError.openFailed(message: "Bars cache is unavailable.")
        }

        let placeholders = normalizedSymbols.map { _ in "?" }.joined(separator: ",")
        let sql = """
        SELECT symbol, timeframe, ts, open, high, low, close, volume
        FROM bars
        WHERE timeframe = ?
          AND ts >= ?
          AND ts <= ?
          AND symbol IN (\(placeholders))
        ORDER BY ts ASC, symbol ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db.handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw BarsCacheError.prepareFailed(message: errorMessage(db.handle))
        }
        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_text(statement, 1, timeframe.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 2, Int64(start.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 3, Int64(end.timeIntervalSince1970))
        for (index, symbol) in normalizedSymbols.enumerated() {
            sqlite3_bind_text(statement, Int32(4 + index), symbol, -1, SQLITE_TRANSIENT)
        }

        var bars: [Bar] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let symbolCString = sqlite3_column_text(statement, 0),
                  let timeframeCString = sqlite3_column_text(statement, 1)
            else {
                continue
            }

            let symbol = String(cString: symbolCString)
            let timeframeRaw = String(cString: timeframeCString)
            guard let timeframe = BarTimeframe(rawValue: timeframeRaw) else {
                continue
            }

            let ts = sqlite3_column_int64(statement, 2)
            bars.append(
                Bar(
                    symbol: symbol,
                    timeframe: timeframe,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(ts)),
                    open: sqlite3_column_double(statement, 3),
                    high: sqlite3_column_double(statement, 4),
                    low: sqlite3_column_double(statement, 5),
                    close: sqlite3_column_double(statement, 6),
                    volume: sqlite3_column_double(statement, 7)
                )
            )
        }

        return bars
    }

    public func currentDatabaseFootprintBytes() throws -> Int64 {
        try sqliteFootprintBytes()
    }

    public func enforceMaxDatabaseSize(
        maxDBMB: Int,
        dryRun: Bool
    ) throws -> RetentionSweepResult {
        let resolvedMaxMB = max(1, maxDBMB)
        let maxBytes = Int64(resolvedMaxMB) * 1_048_576
        let originalBytes = try sqliteFootprintBytes()
        guard originalBytes > maxBytes else {
            return RetentionSweepResult(scannedCount: 0, deletedCount: 0, bytesFreed: 0)
        }

        if dryRun {
            let rowCount = (try? countBarsRows()) ?? 0
            return RetentionSweepResult(
                scannedCount: rowCount,
                deletedCount: 0,
                bytesFreed: 0
            )
        }

        let rowCount = try countBarsRows()
        var deletedRows = 0
        var iteration = 0
        var currentBytes = originalBytes

        while currentBytes > maxBytes, iteration < 200 {
            let removed = try deleteOldestRows(limit: 5_000)
            guard removed > 0 else {
                break
            }
            deletedRows += removed
            iteration += 1
            try execute("PRAGMA wal_checkpoint(TRUNCATE);")
            try execute("VACUUM;")
            currentBytes = try sqliteFootprintBytes()
        }

        return RetentionSweepResult(
            scannedCount: rowCount,
            deletedCount: deletedRows,
            bytesFreed: max(0, originalBytes - currentBytes)
        )
    }

    private func openIfNeeded() throws {
        if db != nil {
            return
        }
        let directory = databaseURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK,
              let opened = handle
        else {
            throw BarsCacheError.openFailed(message: "Unable to open bars cache database.")
        }
        db = SQLiteConnectionBox(handle: opened)

        try execute("PRAGMA journal_mode=WAL;")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS bars(
              symbol TEXT NOT NULL,
              timeframe TEXT NOT NULL,
              ts INTEGER NOT NULL,
              open REAL NOT NULL,
              high REAL NOT NULL,
              low REAL NOT NULL,
              close REAL NOT NULL,
              volume REAL NOT NULL,
              PRIMARY KEY(symbol,timeframe,ts)
            );
            """
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_bars_timeframe_ts_symbol
            ON bars(timeframe, ts, symbol);
            """
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: databaseURL.path
        )
    }

    private func countBarsRows() throws -> Int {
        try openIfNeeded()
        guard let db else {
            throw BarsCacheError.openFailed(message: "Bars cache is unavailable.")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db.handle, "SELECT COUNT(*) FROM bars", -1, &statement, nil) == SQLITE_OK else {
            throw BarsCacheError.prepareFailed(message: errorMessage(db.handle))
        }
        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw BarsCacheError.stepFailed(message: errorMessage(db.handle))
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func deleteOldestRows(limit: Int) throws -> Int {
        try openIfNeeded()
        guard let db else {
            throw BarsCacheError.openFailed(message: "Bars cache is unavailable.")
        }

        let resolvedLimit = max(1, limit)
        let sql = """
        DELETE FROM bars
        WHERE (symbol, timeframe, ts) IN (
            SELECT symbol, timeframe, ts
            FROM bars
            ORDER BY ts ASC, symbol ASC
            LIMIT \(resolvedLimit)
        )
        """
        try execute(sql)
        return Int(sqlite3_changes(db.handle))
    }

    private func sqliteFootprintBytes() throws -> Int64 {
        let files = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm")
        ]
        var bytes: Int64 = 0
        for file in files where fileManager.fileExists(atPath: file.path) {
            let attrs = try fileManager.attributesOfItem(atPath: file.path)
            bytes += (attrs[.size] as? NSNumber)?.int64Value ?? 0
        }
        return bytes
    }

    private func execute(_ sql: String) throws {
        guard let db else {
            throw BarsCacheError.openFailed(message: "Bars cache is unavailable.")
        }
        guard sqlite3_exec(db.handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw BarsCacheError.executeFailed(message: errorMessage(db.handle))
        }
    }

    private func errorMessage(_ db: OpaquePointer) -> String {
        if let pointer = sqlite3_errmsg(db) {
            return String(cString: pointer)
        }
        return "Unknown SQLite error."
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
