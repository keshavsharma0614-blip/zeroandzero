import Foundation

public struct AnalystWorkerLaunchRequest: Sendable, Equatable {
    public let charterId: String
    public let taskId: String?
    public let delegationId: String?
    public let pmId: String?
    public let intendedRuntimePolicy: AnalystRuntimePolicy?
    public let draftSignal: Bool
    public let draftProposal: Bool

    public init(
        charterId: String,
        taskId: String? = nil,
        delegationId: String? = nil,
        pmId: String? = nil,
        intendedRuntimePolicy: AnalystRuntimePolicy? = nil,
        draftSignal: Bool = false,
        draftProposal: Bool = false
    ) {
        self.charterId = charterId
        self.taskId = taskId
        self.delegationId = delegationId
        self.pmId = pmId
        self.intendedRuntimePolicy = intendedRuntimePolicy
        self.draftSignal = draftSignal
        self.draftProposal = draftProposal
    }
}

public struct AnalystWorkerLaunchResult: Codable, Sendable, Equatable {
    public let openAIKeyConfigured: Bool?
    public let usedOpenAI: Bool?
    public let charterId: String
    public let taskId: String?
    public let delegationId: String?
    public let pmId: String?
    public let memoId: String?
    public let memoTitle: String?
    public let findingId: String?
    public let findingTitle: String?
    public let draftedSignalId: String?
    public let draftedProposalId: String?
    public let runtimeProvenance: AnalystRuntimeProvenance?
    public let externalEvidenceStatus: String?
    public let externalEvidenceIssueSummary: String?
    public let synthesisStatus: String?
    public let synthesisIssueSummary: String?
    public let summary: String
    public let outputExcerpt: String

    public init(
        openAIKeyConfigured: Bool? = nil,
        usedOpenAI: Bool? = nil,
        charterId: String,
        taskId: String?,
        delegationId: String? = nil,
        pmId: String? = nil,
        memoId: String? = nil,
        memoTitle: String? = nil,
        findingId: String?,
        findingTitle: String?,
        draftedSignalId: String?,
        draftedProposalId: String? = nil,
        runtimeProvenance: AnalystRuntimeProvenance? = nil,
        externalEvidenceStatus: String? = nil,
        externalEvidenceIssueSummary: String? = nil,
        synthesisStatus: String? = nil,
        synthesisIssueSummary: String? = nil,
        summary: String,
        outputExcerpt: String
    ) {
        self.openAIKeyConfigured = openAIKeyConfigured
        self.usedOpenAI = usedOpenAI
        self.charterId = charterId
        self.taskId = taskId
        self.delegationId = delegationId
        self.pmId = pmId
        self.memoId = memoId
        self.memoTitle = memoTitle
        self.findingId = findingId
        self.findingTitle = findingTitle
        self.draftedSignalId = draftedSignalId
        self.draftedProposalId = draftedProposalId
        self.runtimeProvenance = runtimeProvenance
        self.externalEvidenceStatus = externalEvidenceStatus
        self.externalEvidenceIssueSummary = externalEvidenceIssueSummary
        self.synthesisStatus = synthesisStatus
        self.synthesisIssueSummary = synthesisIssueSummary
        self.summary = summary
        self.outputExcerpt = outputExcerpt
    }
}

public enum AnalystWorkerLaunchError: Error, Sendable, Equatable {
    case repoRootNotFound
    case workerLaunchFailed(reason: String)
    case workerExited(code: Int32, summary: String)
}

public struct AnalystWorkerProgressUpdate: Codable, Sendable, Equatable {
    public let reportedAt: Date
    public let stage: String
    public let summary: String
    public let issueSummary: String?

    public init(
        reportedAt: Date,
        stage: String,
        summary: String,
        issueSummary: String? = nil
    ) {
        self.reportedAt = reportedAt
        self.stage = stage
        self.summary = summary
        self.issueSummary = issueSummary
    }
}

extension AnalystWorkerLaunchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .repoRootNotFound:
            return "Analyst worker launch failed: repo root not found."
        case .workerLaunchFailed(let reason):
            return "Analyst worker launch failed: \(reason)"
        case .workerExited(_, let summary):
            return "Analyst worker exited unsuccessfully: \(summary)"
        }
    }
}

public protocol AnalystWorkerLaunching: Sendable {
    var requiresAppIPCServer: Bool { get }
    func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult
    func runOnce(
        request: AnalystWorkerLaunchRequest,
        onProgress: (@Sendable (AnalystWorkerProgressUpdate) -> Void)?
    ) async throws -> AnalystWorkerLaunchResult
    func preflightOpenAIKeyAccess() async throws -> Bool
}

public extension AnalystWorkerLaunching {
    var requiresAppIPCServer: Bool { false }

    func runOnce(
        request: AnalystWorkerLaunchRequest,
        onProgress: (@Sendable (AnalystWorkerProgressUpdate) -> Void)?
    ) async throws -> AnalystWorkerLaunchResult {
        _ = onProgress
        return try await runOnce(request: request)
    }

    func preflightOpenAIKeyAccess() async throws -> Bool {
        false
    }
}

struct AnalystWorkerCLIInvocation: Sendable, Equatable {
    let executableURL: URL
    let arguments: [String]
    let workingDirectoryURL: URL
    let environment: [String: String]
}

struct AnalystWorkerSessionCredential: Sendable, Equatable {
    let providerKind: LLMProviderKind
    let apiKey: String
}

public struct CLIAnalystWorkerLauncher: AnalystWorkerLaunching {
    private let invocationFactory: @Sendable (AnalystWorkerLaunchRequest) throws -> AnalystWorkerCLIInvocation
    private let runner: @Sendable (AnalystWorkerCLIInvocation, AnalystWorkerSessionCredential?) async throws -> AnalystWorkerLaunchResult
    private let preflightRunner: @Sendable (AnalystWorkerSessionCredential?) async throws -> Bool
    private let sessionCredentialProvider: @Sendable (AnalystWorkerLaunchRequest) -> AnalystWorkerSessionCredential?

    public var requiresAppIPCServer: Bool { true }

    public init() {
        self.invocationFactory = Self.makeInvocation
        self.runner = { invocation, sessionCredential in
            try await Self.runInvocation(invocation, sessionCredential: sessionCredential)
        }
        self.preflightRunner = { sessionCredential in
            try await Self.runOpenAIKeyPreflight(sessionOpenAIKey: sessionCredential?.providerKind == .openAI ? sessionCredential?.apiKey : nil)
        }
        self.sessionCredentialProvider = Self.sessionCredential(for:)
    }

    init(
        invocationFactory: @escaping @Sendable (AnalystWorkerLaunchRequest) throws -> AnalystWorkerCLIInvocation,
        runner: @escaping @Sendable (AnalystWorkerCLIInvocation, AnalystWorkerSessionCredential?) async throws -> AnalystWorkerLaunchResult,
        preflightRunner: @escaping @Sendable (AnalystWorkerSessionCredential?) async throws -> Bool,
        sessionCredentialProvider: @escaping @Sendable (AnalystWorkerLaunchRequest) -> AnalystWorkerSessionCredential?
    ) {
        self.invocationFactory = invocationFactory
        self.runner = runner
        self.preflightRunner = preflightRunner
        self.sessionCredentialProvider = sessionCredentialProvider
    }

    public func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
        let invocation = try invocationFactory(request)
        return try await runner(invocation, sessionCredentialProvider(request))
    }

    public func runOnce(
        request: AnalystWorkerLaunchRequest,
        onProgress: (@Sendable (AnalystWorkerProgressUpdate) -> Void)?
    ) async throws -> AnalystWorkerLaunchResult {
        let invocation = try invocationFactory(request)
        return try await Self.runInvocation(
            invocation,
            sessionCredential: sessionCredentialProvider(request),
            onProgress: onProgress
        )
    }

    public func preflightOpenAIKeyAccess() async throws -> Bool {
        let request = AnalystWorkerLaunchRequest(
            charterId: "preflight-openai-key-access",
            intendedRuntimePolicy: AnalystRuntimePolicy(
                providerKind: .openAI,
                credentialProfileId: LLMCredentialProfile.openAIDefaultProfileID,
                runtimeIdentifier: "gpt-5.4",
                policySource: .taskOverride,
                createdAt: Date(timeIntervalSince1970: 0),
                updatedAt: Date(timeIntervalSince1970: 0)
            )
        )
        return try await preflightRunner(sessionCredentialProvider(request))
    }

    static func makeInvocation(request: AnalystWorkerLaunchRequest) throws -> AnalystWorkerCLIInvocation {
        guard let repoRootURL = resolveRepoRootURL() else {
            throw AnalystWorkerLaunchError.repoRootNotFound
        }
        let packageRootURL = repoRootURL
            .appendingPathComponent("Packages", isDirectory: true)
            .appendingPathComponent("TradingKit", isDirectory: true)
        let packageManifestURL = packageRootURL.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageManifestURL.path) else {
            throw AnalystWorkerLaunchError.repoRootNotFound
        }

        let directWorkerExecutable = findBuiltWorkerExecutable(packageRootURL: packageRootURL)
        var arguments: [String]
        let executableURL: URL
        if let directWorkerExecutable {
            executableURL = directWorkerExecutable
            arguments = [
                "run-once",
                "--charter-id",
                request.charterId
            ]
        } else {
            executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            arguments = [
                "swift",
                "run",
                "--package-path",
                packageRootURL.path,
                "alpaca_analyst_worker",
                "run-once",
                "--charter-id",
                request.charterId
            ]
        }
        if let taskId = request.taskId,
           !taskId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--task-id", taskId])
        }
        if let delegationId = request.delegationId,
           !delegationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--delegation-id", delegationId])
        }
        if let pmId = request.pmId,
           !pmId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--pm-id", pmId])
        }
        if let intendedRuntimePolicy = request.intendedRuntimePolicy {
            arguments.append(contentsOf: ["--provider-kind", intendedRuntimePolicy.providerKind.rawValue])
            arguments.append(contentsOf: ["--credential-profile-id", intendedRuntimePolicy.credentialProfileId])
            arguments.append(contentsOf: ["--runtime-id", intendedRuntimePolicy.runtimeIdentifier])
            if let reasoningMode = intendedRuntimePolicy.reasoningMode {
                arguments.append(contentsOf: ["--reasoning-mode", reasoningMode.rawValue])
            }
            arguments.append(contentsOf: ["--runtime-policy-source", intendedRuntimePolicy.policySource.rawValue])
        }
        if request.draftSignal {
            arguments.append("--draft-signal")
        }
        if request.draftProposal {
            arguments.append("--draft-proposal")
        }

        return AnalystWorkerCLIInvocation(
            executableURL: executableURL,
            arguments: arguments,
            workingDirectoryURL: repoRootURL,
            environment: workerEnvironment()
        )
    }

    private static func findBuiltWorkerExecutable(packageRootURL: URL) -> URL? {
        let candidates = [
            packageRootURL
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent("alpaca_analyst_worker"),
            packageRootURL
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("arm64-apple-macosx", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent("alpaca_analyst_worker")
        ]
        return candidates.first { url in
            FileManager.default.isExecutableFile(atPath: url.path)
        }
    }

    private static func sessionCredential(
        for request: AnalystWorkerLaunchRequest
    ) -> AnalystWorkerSessionCredential? {
        guard let policy = request.intendedRuntimePolicy else {
            return nil
        }
        switch policy.providerKind {
        case .openAI:
            guard let apiKey = OpenAIKeychainStatusProvider().apiKey() else {
                return nil
            }
            return AnalystWorkerSessionCredential(providerKind: .openAI, apiKey: apiKey)
        case .anthropic:
            let settings = (try? LLMProviderSettingsStore().loadOrDefault()) ?? .default(now: Date())
            let profileID = policy.credentialProfileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? LLMProviderKind.anthropic.defaultCredentialProfileId
                : policy.credentialProfileId
            let profile = settings.profile(id: profileID)
                ?? settings.profiles(for: .anthropic).first
                ?? LLMCredentialProfile.defaultAnthropic(now: Date())
            let resolution = LLMKeychainCredentialResolver().resolve(profile: profile)
            guard let apiKey = resolution.apiKey else {
                return nil
            }
            return AnalystWorkerSessionCredential(providerKind: .anthropic, apiKey: apiKey)
        }
    }

    private static func resolveRepoRootURL() -> URL? {
        let compileTimeURL = URL(fileURLWithPath: #filePath)
        var candidate = compileTimeURL
        for _ in 0..<5 {
            candidate.deleteLastPathComponent()
        }
        if hasRepoMarkers(at: candidate) {
            return candidate
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return hasRepoMarkers(at: cwd) ? cwd : nil
    }

    private static func hasRepoMarkers(at url: URL) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: url.appendingPathComponent("AlgoTradingMac.xcworkspace").path)
            && fileManager.fileExists(atPath: url.appendingPathComponent("Packages/TradingKit/Package.swift").path)
    }

    private static func makePreflightInvocation() throws -> AnalystWorkerCLIInvocation {
        guard let repoRootURL = resolveRepoRootURL() else {
            throw AnalystWorkerLaunchError.repoRootNotFound
        }

        let packageRootURL = repoRootURL
            .appendingPathComponent("Packages", isDirectory: true)
            .appendingPathComponent("TradingKit", isDirectory: true)
        let packageManifestURL = packageRootURL.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageManifestURL.path) else {
            throw AnalystWorkerLaunchError.repoRootNotFound
        }

        return AnalystWorkerCLIInvocation(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: [
                "swift",
                "run",
                "--package-path",
                packageRootURL.path,
                "alpaca_analyst_worker",
                "preflight-openai-key-access"
            ],
            workingDirectoryURL: repoRootURL,
            environment: workerEnvironment()
        )
    }

    private static func workerEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["TRADINGKIT_APP_SUPPORT_ROOT"] = AppSupportPaths.rootDirectory().path
        return environment
    }

    private static let progressEventPrefix = "progress_event: "
    private static let openAICredentialStdinFlag = "--openai-credential-stdin"
    private static let anthropicCredentialStdinFlag = "--anthropic-credential-stdin"

    private static func runOpenAIKeyPreflight(sessionOpenAIKey: String?) async throws -> Bool {
        let invocation = try makePreflightInvocation()
        let sessionCredential = sessionOpenAIKey.map {
            AnalystWorkerSessionCredential(providerKind: .openAI, apiKey: $0)
        }
        let process = Process()
        process.executableURL = invocation.executableURL
        process.arguments = processArguments(
            from: invocation.arguments,
            sessionCredential: sessionCredential
        )
        process.currentDirectoryURL = invocation.workingDirectoryURL
        process.environment = invocation.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let credentialInput = configureCredentialInput(
            for: process,
            sessionCredential: sessionCredential
        )

        try process.run()
        do {
            try credentialInput?.send()
        } catch {
            process.terminate()
            throw error
        }
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()
        process.waitUntilExit()

        let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            let summary = boundedOutputSummary(stdout: stdout, stderr: stderr)
            throw AnalystWorkerLaunchError.workerExited(code: process.terminationStatus, summary: summary)
        }

        for line in stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            if line == "openai_key_ready: true" {
                return true
            }
            if line == "openai_key_ready: false" {
                return false
            }
        }

        throw AnalystWorkerLaunchError.workerLaunchFailed(
            reason: "worker preflight output did not include openai_key_ready"
        )
    }

    private static func runInvocation(
        _ invocation: AnalystWorkerCLIInvocation,
        sessionCredential: AnalystWorkerSessionCredential?,
        onProgress: (@Sendable (AnalystWorkerProgressUpdate) -> Void)? = nil
    ) async throws -> AnalystWorkerLaunchResult {
        try await withCheckedThrowingContinuation { continuation in
            final class ProcessCapture: @unchecked Sendable {
                private let lock = NSLock()
                private var stdout = ""
                private var stderr = ""
                private var stdoutRemainder = ""
                private var stderrRemainder = ""
                private var resumed = false

                func appendStdout(
                    _ data: Data,
                    onProgress: (@Sendable (AnalystWorkerProgressUpdate) -> Void)?
                ) {
                    append(data, isStdout: true, onProgress: onProgress)
                }

                func appendStderr(_ data: Data) {
                    append(data, isStdout: false, onProgress: nil)
                }

                func finalize() -> (stdout: String, stderr: String) {
                    lock.lock()
                    defer { lock.unlock() }
                    if !stdoutRemainder.isEmpty {
                        stdout += stdoutRemainder
                        stdoutRemainder = ""
                    }
                    if !stderrRemainder.isEmpty {
                        stderr += stderrRemainder
                        stderrRemainder = ""
                    }
                    return (stdout, stderr)
                }

                func resumeOnce(
                    _ body: () -> Void
                ) {
                    lock.lock()
                    guard resumed == false else {
                        lock.unlock()
                        return
                    }
                    resumed = true
                    lock.unlock()
                    body()
                }

                private func append(
                    _ data: Data,
                    isStdout: Bool,
                    onProgress: (@Sendable (AnalystWorkerProgressUpdate) -> Void)?
                ) {
                    guard data.isEmpty == false,
                          let chunk = String(data: data, encoding: .utf8),
                          chunk.isEmpty == false else {
                        return
                    }

                    var progressEvents: [AnalystWorkerProgressUpdate] = []

                    lock.lock()
                    let buffer = isStdout ? stdoutRemainder + chunk : stderrRemainder + chunk
                    let endsWithNewline = buffer.hasSuffix("\n")
                    let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)

                    let completeCount = endsWithNewline ? lines.count : max(0, lines.count - 1)
                    for index in 0..<completeCount {
                        let line = String(lines[index])
                        if isStdout,
                           let update = CLIAnalystWorkerLauncher.parseProgressUpdate(from: line) {
                            progressEvents.append(update)
                        } else if isStdout {
                            stdout += line + "\n"
                        } else {
                            stderr += line + "\n"
                        }
                    }

                    let remainder = endsWithNewline ? "" : String(lines.last ?? "")
                    if isStdout {
                        stdoutRemainder = remainder
                    } else {
                        stderrRemainder = remainder
                    }
                    lock.unlock()

                    progressEvents.forEach { update in
                        onProgress?(update)
                    }
                }
            }

            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let capture = ProcessCapture()

            process.executableURL = invocation.executableURL
            process.arguments = processArguments(
                from: invocation.arguments,
                sessionCredential: sessionCredential
            )
            process.currentDirectoryURL = invocation.workingDirectoryURL
            process.environment = invocation.environment
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                capture.appendStdout(data, onProgress: onProgress)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                capture.appendStderr(data)
            }

            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                capture.appendStdout(remainingStdout, onProgress: onProgress)
                capture.appendStderr(remainingStderr)

                let finalOutput = capture.finalize()
                capture.resumeOnce {
                    do {
                        if process.terminationStatus == 0 {
                            let parsed = try parseSummary(from: finalOutput.stdout)
                            continuation.resume(returning: parsed)
                        } else {
                            let summary = boundedOutputSummary(stdout: finalOutput.stdout, stderr: finalOutput.stderr)
                            continuation.resume(throwing: AnalystWorkerLaunchError.workerExited(
                                code: process.terminationStatus,
                                summary: summary
                            ))
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            do {
                let credentialInput = configureCredentialInput(
                    for: process,
                    sessionCredential: sessionCredential
                )
                try process.run()
                do {
                    try credentialInput?.send()
                } catch {
                    process.terminate()
                    throw error
                }
                try? stdoutPipe.fileHandleForWriting.close()
                try? stderrPipe.fileHandleForWriting.close()
            } catch {
                capture.resumeOnce {
                    continuation.resume(throwing: AnalystWorkerLaunchError.workerLaunchFailed(reason: error.localizedDescription))
                }
            }
        }
    }

    private static func processArguments(
        from arguments: [String],
        sessionCredential: AnalystWorkerSessionCredential?
    ) -> [String] {
        guard let sessionCredential,
              sessionCredential.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return arguments
        }
        switch sessionCredential.providerKind {
        case .openAI:
            return arguments + [openAICredentialStdinFlag]
        case .anthropic:
            return arguments + [anthropicCredentialStdinFlag]
        }
    }

    private final class CredentialPipeInput: @unchecked Sendable {
        let pipe = Pipe()
        private let data: Data
        private var didSend = false

        init(apiKey: String) {
            data = Data((apiKey + "\n").utf8)
        }

        func send() throws {
            guard didSend == false else {
                return
            }
            didSend = true
            pipe.fileHandleForWriting.write(data)
            try pipe.fileHandleForWriting.close()
        }
    }

    private static func configureCredentialInput(
        for process: Process,
        sessionCredential: AnalystWorkerSessionCredential?
    ) -> CredentialPipeInput? {
        guard let sessionCredential,
              sessionCredential.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        let credentialInput = CredentialPipeInput(apiKey: sessionCredential.apiKey)
        process.standardInput = credentialInput.pipe
        return credentialInput
    }

    static func parseProgressUpdate(from line: String) -> AnalystWorkerProgressUpdate? {
        guard line.hasPrefix(progressEventPrefix) else {
            return nil
        }
        let payload = String(line.dropFirst(progressEventPrefix.count))
        guard let data = payload.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return try? decoder.decode(AnalystWorkerProgressUpdate.self, from: data)
    }

    static func parseSummary(from stdout: String) throws -> AnalystWorkerLaunchResult {
        var values: [String: String] = [:]
        for line in stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "progress_event" {
                continue
            }
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }

        guard let charterId = values["charter_id"], !charterId.isEmpty else {
            throw AnalystWorkerLaunchError.workerLaunchFailed(reason: "worker output did not include charter_id")
        }
        let taskId = values["task_id"].flatMap(nilIfDash)
        let delegationId = values["delegation_id"].flatMap(nilIfDash)
        let pmId = values["pm_id"].flatMap(nilIfDash)
        let openAIKeyConfigured = values["openai_key_configured"].flatMap(parseBool)
        let usedOpenAI = values["used_openai"].flatMap(parseBool)
        let memoId = values["memo_id"].flatMap(nilIfDash)
        let memoTitle = values["memo_title"].flatMap(nilIfDash)
        let findingId = values["finding_id"].flatMap(nilIfDash)
        let findingTitle = values["finding_title"].flatMap(nilIfDash)
        let draftedSignalId = values["drafted_signal_id"].flatMap(nilIfDash)
        let draftedProposalId = values["drafted_proposal_id"].flatMap(nilIfDash)
        let synthesisStatus = values["synthesis_status"].flatMap(nilIfDash)
        let synthesisIssueSummary = values["synthesis_issue_summary"].flatMap(nilIfDash)
        let runtimeProvenance = makeRuntimeProvenance(
            values: values,
            usedOpenAI: usedOpenAI,
            synthesisStatus: synthesisStatus
        )
        let externalEvidenceStatus = values["external_evidence_status"].flatMap(nilIfDash)
        let externalEvidenceIssueSummary = values["external_evidence_issue_summary"].flatMap(nilIfDash)
        let summary = [
            memoTitle.map { "memo: \($0)" },
            findingTitle.map { "finding: \($0)" },
            draftedSignalId.map { "signal: \($0)" },
            draftedProposalId.map { "proposal: \($0)" },
            taskId.map { "task: \($0)" },
            runtimeSummary(runtimeProvenance),
            providerSummary(
                openAIKeyConfigured: openAIKeyConfigured,
                usedOpenAI: usedOpenAI,
                synthesisStatus: synthesisStatus,
                synthesisIssueSummary: synthesisIssueSummary
            ),
            externalEvidenceSummary(status: externalEvidenceStatus, issueSummary: externalEvidenceIssueSummary)
        ]
        .compactMap { $0 }
        .joined(separator: " • ")

        return AnalystWorkerLaunchResult(
            openAIKeyConfigured: openAIKeyConfigured,
            usedOpenAI: usedOpenAI,
            charterId: charterId,
            taskId: taskId,
            delegationId: delegationId,
            pmId: pmId,
            memoId: memoId,
            memoTitle: memoTitle,
            findingId: findingId,
            findingTitle: findingTitle,
            draftedSignalId: draftedSignalId,
            draftedProposalId: draftedProposalId,
            runtimeProvenance: runtimeProvenance,
            externalEvidenceStatus: externalEvidenceStatus,
            externalEvidenceIssueSummary: externalEvidenceIssueSummary,
            synthesisStatus: synthesisStatus,
            synthesisIssueSummary: synthesisIssueSummary,
            summary: summary.isEmpty ? "Worker completed." : summary,
            outputExcerpt: boundedExcerpt(stdout)
        )
    }

    private static func boundedOutputSummary(stdout: String, stderr: String) -> String {
        let stderrExcerpt = boundedExcerpt(stderr)
        if !stderrExcerpt.isEmpty {
            return stderrExcerpt
        }
        let stdoutExcerpt = boundedExcerpt(stdout)
        return stdoutExcerpt.isEmpty ? "worker exited without output" : stdoutExcerpt
    }

    private static func externalEvidenceSummary(status: String?, issueSummary: String?) -> String? {
        guard let status, status != "ok" else { return nil }
        if let issueSummary, !issueSummary.isEmpty {
            return "external: \(status) (\(issueSummary))"
        }
        return "external: \(status)"
    }

    private static func runtimeSummary(_ runtimeProvenance: AnalystRuntimeProvenance?) -> String? {
        guard let runtimeProvenance else { return nil }
        if let intended = runtimeProvenance.intendedPolicy {
            return "runtime: \(runtimeProvenance.actualRuntimeIdentifier) (intended: \(intended.runtimeIdentifier))"
        }
        return "runtime: \(runtimeProvenance.actualRuntimeIdentifier)"
    }

    private static func providerSummary(
        openAIKeyConfigured: Bool?,
        usedOpenAI: Bool?,
        synthesisStatus: String?,
        synthesisIssueSummary: String?
    ) -> String? {
        if usedOpenAI == true {
            return "provider: OpenAI Responses API"
        }

        switch synthesisStatus {
        case "anthropic_messages":
            return "provider: Anthropic Messages API"
        case "deterministic_local":
            return "provider: local deterministic synthesis"
        case "fallback_missing_openai_key":
            return "provider: local deterministic fallback (OpenAI API key missing)"
        case "fallback_missing_anthropic_key", "fallback_anthropic_key_unavailable":
            return "provider: local deterministic fallback (Anthropic API key missing)"
        case "fallback_openai_error":
            if let synthesisIssueSummary, !synthesisIssueSummary.isEmpty {
                return "provider: local deterministic fallback (\(synthesisIssueSummary))"
            }
            return "provider: local deterministic fallback (OpenAI provider error)"
        case "fallback_anthropic_error":
            if let synthesisIssueSummary, !synthesisIssueSummary.isEmpty {
                return "provider: local deterministic fallback (\(synthesisIssueSummary))"
            }
            return "provider: local deterministic fallback (Anthropic provider error)"
        case "openai_responses":
            return "provider: OpenAI Responses API"
        default:
            if openAIKeyConfigured == false {
                return "provider: local deterministic synthesis (OpenAI API key missing)"
            }
            return nil
        }
    }

    private static func boundedExcerpt(_ text: String, limit: Int = 280) -> String {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard trimmed.count > limit else {
            return trimmed
        }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[..<end]) + "..."
    }

    private static func nilIfDash(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "-" ? nil : trimmed
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }

    private static func makeRuntimeProvenance(
        values: [String: String],
        usedOpenAI: Bool?,
        synthesisStatus: String?
    ) -> AnalystRuntimeProvenance? {
        let launchedAt = values["runtime_launched_at"].flatMap(nilIfDash).flatMap(DateCodec.parseISO8601)
        let intendedRuntimeIdentifier = values["resolved_runtime_identifier"].flatMap(nilIfDash)
        let intendedProviderKind = values["resolved_provider_kind"]
            .flatMap(nilIfDash)
            .flatMap(LLMProviderKind.init(rawValue:))
            ?? .openAI
        let intendedCredentialProfileId = values["resolved_credential_profile_id"]
            .flatMap(nilIfDash)
            ?? intendedProviderKind.defaultCredentialProfileId
        let intendedReasoningMode = values["resolved_reasoning_mode"]
            .flatMap(nilIfDash)
            .flatMap(AnalystRuntimeReasoningMode.init(rawValue:))
        let intendedPolicySource = values["resolved_runtime_policy_source"]
            .flatMap(nilIfDash)
            .flatMap(AnalystRuntimePolicySource.init(rawValue:))
        let actualRuntimeIdentifier = values["actual_runtime_identifier"].flatMap(nilIfDash)
        let actualReasoningMode = values["actual_reasoning_mode"]
            .flatMap(nilIfDash)
            .flatMap(AnalystRuntimeReasoningMode.init(rawValue:))

        guard launchedAt != nil
            || intendedRuntimeIdentifier != nil
            || actualRuntimeIdentifier != nil else {
            return nil
        }

        let intendedPolicy: AnalystRuntimePolicy?
        if let intendedRuntimeIdentifier,
           let intendedPolicySource {
            let timestamp = launchedAt ?? Date(timeIntervalSince1970: 0)
            intendedPolicy = AnalystRuntimePolicy(
                providerKind: intendedProviderKind,
                credentialProfileId: intendedCredentialProfileId,
                runtimeIdentifier: intendedRuntimeIdentifier,
                reasoningMode: intendedReasoningMode,
                policySource: intendedPolicySource,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        } else {
            intendedPolicy = nil
        }

        let inferredActualRuntimeIdentifier: String
        if let actualRuntimeIdentifier {
            inferredActualRuntimeIdentifier = actualRuntimeIdentifier
        } else if usedOpenAI == true || synthesisStatus == "openai_responses" {
            if let intendedRuntimeIdentifier {
                inferredActualRuntimeIdentifier = "openai_responses[\(intendedRuntimeIdentifier)]"
            } else {
                inferredActualRuntimeIdentifier = "openai_responses"
            }
        } else if synthesisStatus == "anthropic_messages" {
            if let intendedRuntimeIdentifier {
                inferredActualRuntimeIdentifier = "anthropic_messages[\(intendedRuntimeIdentifier)]"
            } else {
                inferredActualRuntimeIdentifier = "anthropic_messages"
            }
        } else if synthesisStatus == "fallback_missing_openai_key" || synthesisStatus == "fallback_openai_error" {
            if let intendedRuntimeIdentifier {
                inferredActualRuntimeIdentifier = "deterministic_local_fallback[\(intendedRuntimeIdentifier)]"
            } else {
                inferredActualRuntimeIdentifier = "deterministic_local_fallback"
            }
        } else if synthesisStatus == "fallback_missing_anthropic_key"
            || synthesisStatus == "fallback_anthropic_key_unavailable"
            || synthesisStatus == "fallback_anthropic_error" {
            if let intendedRuntimeIdentifier {
                inferredActualRuntimeIdentifier = "deterministic_local_fallback[\(intendedRuntimeIdentifier)]"
            } else {
                inferredActualRuntimeIdentifier = "deterministic_local_fallback"
            }
        } else {
            inferredActualRuntimeIdentifier = "deterministic_local"
        }

        return AnalystRuntimeProvenance(
            intendedPolicy: intendedPolicy,
            actualRuntimeIdentifier: inferredActualRuntimeIdentifier,
            actualReasoningMode: actualReasoningMode,
            launchedAt: launchedAt ?? Date(timeIntervalSince1970: 0)
        )
    }
}
