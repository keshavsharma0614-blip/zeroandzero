import Foundation
import Darwin

public enum AuditEventSource: String, Sendable, Codable {
    case ui
    case strategy
    case ipc
    case cli
    case engine
    case system
}

public enum AuditEventLevel: String, Sendable, Codable {
    case info
    case warning
    case error
}

public struct AuditEvent: Sendable, Codable, Equatable, Identifiable {
    public var id: String {
        "\(timestamp)|\(source.rawValue)|\(message)"
    }

    public let timestamp: String
    public let source: AuditEventSource
    public let level: AuditEventLevel
    public let message: String
    public let env: Environment
    public let strategyId: String?
    public let orderId: String?
    public let symbol: String?
    public let action: String?
    public let errorCode: String?

    public init(
        timestamp: String,
        source: AuditEventSource,
        level: AuditEventLevel,
        message: String,
        env: Environment,
        strategyId: String? = nil,
        orderId: String? = nil,
        symbol: String? = nil,
        action: String? = nil,
        errorCode: String? = nil
    ) {
        self.timestamp = timestamp
        self.source = source
        self.level = level
        self.message = message
        self.env = env
        self.strategyId = strategyId
        self.orderId = orderId
        self.symbol = symbol
        self.action = action
        self.errorCode = errorCode
    }
}

public protocol AuditEventPersisting: Sendable {
    func append(_ event: AuditEvent) async
}

public actor JSONLAuditEventSink: AuditEventPersisting {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder

    public init(
        fileURL: URL = JSONLAuditEventSink.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        if #available(macOS 13.0, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        self.encoder = encoder
    }

    public func append(_ event: AuditEvent) async {
        do {
            try ensureParentDirectoryExists()
            try ensureFileExists()

            let json = try encoder.encode(event)
            guard var line = String(data: json, encoding: .utf8) else {
                return
            }
            line.append("\n")

            let handle = try FileHandle(forWritingTo: fileURL)
            defer {
                try? handle.close()
            }
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } catch {
            // Persistence is best-effort; in-memory audit lines remain authoritative for UI.
        }
    }

    public static func defaultFileURL() -> URL {
        AppSupportPaths.rootDirectory()
            .appendingPathComponent("audit_events.jsonl", isDirectory: false)
    }

    private func ensureParentDirectoryExists() throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func ensureFileExists() throws {
        guard !fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        let created = fileManager.createFile(
            atPath: fileURL.path,
            contents: Data(),
            attributes: [.posixPermissions: 0o600]
        )
        if !created {
            throw NSError(domain: "TradingKit.JSONLAuditEventSink", code: 1)
        }
    }
}

enum AppSupportPaths {
    private final class TestRootState: @unchecked Sendable {
        let lock = NSLock()
        var cachedRoot: URL?
        var instanceIdentifier: String?
    }

    private static let testRootState = TestRootState()

    static func rootDirectory(fileManager: FileManager = .default) -> URL {
        if let overridden = ProcessInfo.processInfo.environment["TRADINGKIT_APP_SUPPORT_ROOT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !overridden.isEmpty {
            return URL(fileURLWithPath: overridden, isDirectory: true)
        }

        // Tests run in parallel by default. Use isolated temp roots for default
        // persistence paths to prevent cross-test file and SQLite contention.
        if isRunningTests() {
            return sharedTestRoot(fileManager: fileManager)
        }

        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return root.appendingPathComponent("AlgoTradingMac", isDirectory: true)
    }

    private static func isRunningTests() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil ||
            env["XCTestBundlePath"] != nil ||
            env["XCTestSessionIdentifier"] != nil {
            return true
        }

        let processName = ProcessInfo.processInfo.processName.lowercased()
        return processName.contains("xctest")
            || processName.contains("swiftpm-testing-helper")
    }

    static func resetCachedTestRootForTesting() {
        testRootState.lock.lock()
        defer { testRootState.lock.unlock() }
        testRootState.cachedRoot = nil
        testRootState.instanceIdentifier = nil
    }

    static func makeTestRoot(
        baseDirectory: URL,
        processIdentifier: Int32,
        instanceIdentifier: String,
        fileManager: FileManager = .default,
        processExists: (Int32) -> Bool = isProcessAlive
    ) -> URL {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        cleanupStaleTestRoots(
            baseDirectory: baseDirectory,
            fileManager: fileManager,
            processExists: processExists
        )

        let root = baseDirectory.appendingPathComponent(
            "\(processIdentifier)-\(instanceIdentifier)",
            isDirectory: true
        )
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func cleanupStaleTestRoots(
        baseDirectory: URL,
        fileManager: FileManager = .default,
        processExists: (Int32) -> Bool = isProcessAlive
    ) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for entry in contents {
            let name = entry.lastPathComponent
            let pidPrefix = name.split(separator: "-", maxSplits: 1).first.map(String.init) ?? name
            guard let pid = Int32(pidPrefix), processExists(pid) == false else {
                continue
            }
            try? fileManager.removeItem(at: entry)
        }
    }

    private static func sharedTestRoot(fileManager: FileManager) -> URL {
        testRootState.lock.lock()
        defer { testRootState.lock.unlock() }

        if let cachedRoot = testRootState.cachedRoot {
            return cachedRoot
        }

        let instanceIdentifier = testRootState.instanceIdentifier ?? UUID().uuidString
        testRootState.instanceIdentifier = instanceIdentifier
        let baseDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("AlgoTradingMacTests", isDirectory: true)
        let root = makeTestRoot(
            baseDirectory: baseDirectory,
            processIdentifier: Int32(ProcessInfo.processInfo.processIdentifier),
            instanceIdentifier: instanceIdentifier,
            fileManager: fileManager
        )
        testRootState.cachedRoot = root
        return root
    }

    private static func isProcessAlive(_ processIdentifier: Int32) -> Bool {
        if processIdentifier <= 0 {
            return false
        }
        let result = kill(processIdentifier, 0)
        if result == 0 {
            return true
        }
        return errno == EPERM
    }
}
