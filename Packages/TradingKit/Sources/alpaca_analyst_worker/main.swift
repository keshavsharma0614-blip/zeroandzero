import Darwin
import Foundation
import TradingKit

private struct WorkerOptions {
    var command: Command = .runOnce
    var newsLimit: Int = 10
    var charterID: String?
    var taskID: String?
    var delegationID: String?
    var pmID: String?
    var runtimeID: String?
    var providerKind: LLMProviderKind?
    var credentialProfileID: String?
    var reasoningMode: AnalystRuntimeReasoningMode?
    var runtimePolicySource: AnalystRuntimePolicySource?
    var draftSignal: Bool = false
    var draftProposal: Bool = false
    var useOpenAICredentialStdin: Bool = false
    var useAnthropicCredentialStdin: Bool = false

    enum Command {
        case runOnce
        case preflightOpenAIKeyAccess
    }
}

@main
struct AlpacaAnalystWorker {
    static func main() async {
        let exitCode = await run(arguments: Array(CommandLine.arguments.dropFirst()))
        Darwin.exit(Int32(exitCode))
    }

    private static func run(arguments: [String]) async -> Int {
        do {
            let options = try parseOptions(arguments: arguments)
            printProgress(
                AnalystWorkerProgressUpdate(
                    reportedAt: Date(),
                    stage: "process_started",
                    summary: "Analyst worker process started and parsed launch arguments."
                )
            )
            let stdinCredential = options.usesCredentialStdin
                ? readCredentialFromStandardInput()
                : nil
            if options.usesCredentialStdin {
                printProgress(
                    AnalystWorkerProgressUpdate(
                        reportedAt: Date(),
                        stage: stdinCredential == nil ? "credential_handoff_missing" : "credential_handoff_received",
                        summary: stdinCredential == nil
                            ? "Analyst worker did not receive an app session credential."
                            : "Analyst worker received an app session credential through the local worker channel."
                    )
                )
            }
            let openAIKeyStatusProvider = makeOpenAIKeyStatusProvider(
                sessionOpenAIKey: options.useOpenAICredentialStdin ? stdinCredential : nil,
                requiresSessionCredential: options.useOpenAICredentialStdin
            )
            let llmCredentialResolver = makeLLMCredentialResolver(
                sessionAnthropicKey: options.useAnthropicCredentialStdin ? stdinCredential : nil,
                requiresSessionCredential: options.useAnthropicCredentialStdin
            )
            switch options.command {
            case .runOnce:
                let session = URLSession(configuration: .ephemeral)
                defer {
                    session.finishTasksAndInvalidate()
                }
                let client = AnalystIPCClient(session: session)
                let service = AnalystWorkerService(
                    client: client,
                    openAIKeyStatusProvider: openAIKeyStatusProvider,
                    llmCredentialResolver: llmCredentialResolver
                )
                printProgress(
                    AnalystWorkerProgressUpdate(
                        reportedAt: Date(),
                        stage: "service_starting",
                        summary: "Analyst worker is starting the app-owned analyst service run."
                    )
                )
                let summary = try await service.runOnce(
                    charterID: options.charterID,
                    taskID: options.taskID,
                    delegationID: options.delegationID,
                    pmID: options.pmID,
                    intendedRuntimePolicy: options.intendedRuntimePolicy,
                    newsLimit: options.newsLimit,
                    draftSignal: options.draftSignal,
                    draftProposal: options.draftProposal,
                    reportProgress: printProgress
                )
                printSummary(summary)
                return 0
            case .preflightOpenAIKeyAccess:
                return runOpenAIKeyPreflight(openAIKeyStatusProvider: openAIKeyStatusProvider)
            }
        } catch let error as AgentControlRuntimeInfoStoreError {
            switch error {
            case .missingFile:
                fputs("alpaca_analyst_worker failed: IPC runtime file not found. Is the app running?\n", stderr)
            case .invalidFile:
                fputs("alpaca_analyst_worker failed: IPC runtime file is invalid.\n", stderr)
            case .unsupportedPath:
                fputs("alpaca_analyst_worker failed: Unsupported IPC runtime path.\n", stderr)
            }
            return 1
        } catch let error as AnalystIPCClientError {
            fputs("alpaca_analyst_worker failed: \(render(error: error))\n", stderr)
            return 1
        } catch let error as AnalystWorkerSelectionError {
            fputs("alpaca_analyst_worker failed: \(render(error: error))\n", stderr)
            return 1
        } catch let error as AnalystExternalEvidenceError {
            fputs("alpaca_analyst_worker failed: \(error.localizedDescription)\n", stderr)
            return 1
        } catch let error as WorkerExit {
            switch error {
            case .normal:
                return 0
            case .invalidArguments(let message):
                fputs("alpaca_analyst_worker failed: \(message)\n", stderr)
                return 1
            }
        } catch {
            fputs("alpaca_analyst_worker failed: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func parseOptions(arguments: [String]) throws -> WorkerOptions {
        var options = WorkerOptions()
        if arguments.isEmpty {
            return options
        }

        var index = 0
        if arguments[index] == "run-once" {
            options.command = .runOnce
            index += 1
        } else if arguments[index] == "preflight-openai-key-access" {
            options.command = .preflightOpenAIKeyAccess
            index += 1
        }

        while index < arguments.count {
            switch arguments[index] {
            case "--help", "-h":
                printUsage()
                throw WorkerExit.normal
            case "--news-limit":
                let value = try parseValue(arguments: arguments, index: &index)
                guard let parsed = Int(value), parsed > 0 else {
                    throw WorkerExit.invalidArguments("--news-limit must be a positive integer")
                }
                options.newsLimit = parsed
            case "--charter-id":
                let value = try parseValue(arguments: arguments, index: &index)
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw WorkerExit.invalidArguments("--charter-id must not be empty")
                }
                options.charterID = value
            case "--task-id":
                let value = try parseValue(arguments: arguments, index: &index)
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw WorkerExit.invalidArguments("--task-id must not be empty")
                }
                options.taskID = value
            case "--delegation-id":
                let value = try parseValue(arguments: arguments, index: &index)
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw WorkerExit.invalidArguments("--delegation-id must not be empty")
                }
                options.delegationID = value
            case "--pm-id":
                let value = try parseValue(arguments: arguments, index: &index)
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw WorkerExit.invalidArguments("--pm-id must not be empty")
                }
                options.pmID = value
            case "--runtime-id":
                let value = try parseValue(arguments: arguments, index: &index)
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw WorkerExit.invalidArguments("--runtime-id must not be empty")
                }
                options.runtimeID = value
            case "--provider-kind":
                let value = try parseValue(arguments: arguments, index: &index)
                guard let provider = LLMProviderKind(rawValue: value) else {
                    throw WorkerExit.invalidArguments("--provider-kind must be one of: openai, anthropic")
                }
                options.providerKind = provider
            case "--credential-profile-id":
                let value = try parseValue(arguments: arguments, index: &index)
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw WorkerExit.invalidArguments("--credential-profile-id must not be empty")
                }
                options.credentialProfileID = value
            case "--reasoning-mode":
                let value = try parseValue(arguments: arguments, index: &index)
                guard let mode = AnalystRuntimeReasoningMode(rawValue: value) else {
                    throw WorkerExit.invalidArguments("--reasoning-mode must be one of: standard, deliberate")
                }
                options.reasoningMode = mode
            case "--runtime-policy-source":
                let value = try parseValue(arguments: arguments, index: &index)
                guard let source = AnalystRuntimePolicySource(rawValue: value) else {
                    throw WorkerExit.invalidArguments("--runtime-policy-source must be one of: charter_default, specialization_default, pm_delegation_override, task_override")
                }
                options.runtimePolicySource = source
            case "--draft-signal":
                options.draftSignal = true
                index += 1
            case "--draft-proposal":
                options.draftProposal = true
                index += 1
            case "--openai-credential-stdin":
                options.useOpenAICredentialStdin = true
                index += 1
            case "--anthropic-credential-stdin":
                options.useAnthropicCredentialStdin = true
                index += 1
            default:
                throw WorkerExit.invalidArguments("Unknown argument: \(arguments[index])")
            }
        }

        return options
    }

    private static func parseValue(arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw WorkerExit.invalidArguments("Missing value for \(arguments[index])")
        }
        let value = arguments[valueIndex]
        index = valueIndex + 1
        return value
    }

    private static func printSummary(_ summary: AnalystWorkerRunSummary) {
        print("alpaca_analyst_worker run-once succeeded")
        print("charter_seeded: \(summary.charterSeeded)")
        print("openai_key_configured: \(summary.openAIKeyConfigured)")
        print("used_openai: \(summary.usedOpenAI)")
        print("pm_id: \(summary.pmId ?? "-")")
        print("delegation_id: \(summary.delegationId ?? "-")")
        print("analyst_id: \(summary.analystId)")
        print("charter_id: \(summary.charterId)")
        print("task_id: \(summary.taskId)")
        print("resolved_runtime_identifier: \(summary.runtimeProvenance?.intendedPolicy?.runtimeIdentifier ?? "-")")
        print("resolved_provider_kind: \(summary.runtimeProvenance?.intendedPolicy?.providerKind.rawValue ?? "-")")
        print("resolved_credential_profile_id: \(summary.runtimeProvenance?.intendedPolicy?.credentialProfileId ?? "-")")
        print("resolved_reasoning_mode: \(summary.runtimeProvenance?.intendedPolicy?.reasoningMode?.rawValue ?? "-")")
        print("resolved_runtime_policy_source: \(summary.runtimeProvenance?.intendedPolicy?.policySource.rawValue ?? "-")")
        print("actual_runtime_identifier: \(summary.runtimeProvenance?.actualRuntimeIdentifier ?? "-")")
        print("actual_reasoning_mode: \(summary.runtimeProvenance?.actualReasoningMode?.rawValue ?? "-")")
        print("runtime_launched_at: \(summary.runtimeProvenance.map { formatISO8601($0.launchedAt) } ?? "-")")
        print("news_items: \(summary.newsCount)")
        print("external_evidence_items: \(summary.externalEvidenceCount)")
        print("external_evidence_issue_count: \(summary.externalEvidenceIssueCount)")
        print("external_evidence_status: \(summary.externalEvidenceStatus)")
        print("external_evidence_issue_summary: \(summary.externalEvidenceIssueSummary ?? "-")")
        print("synthesis_status: \(summary.synthesisStatus)")
        print("synthesis_issue_summary: \(summary.synthesisIssueSummary ?? "-")")
        print("evidence_bundle_id: \(summary.evidenceBundleId)")
        print("memo_id: \(summary.memoId)")
        print("memo_title: \(summary.memoTitle)")
        print("finding_id: \(summary.findingId)")
        print("finding_title: \(summary.findingTitle)")
        print("drafted_signal_id: \(summary.draftedSignalId ?? "-")")
        print("drafted_proposal_id: \(summary.draftedProposalId ?? "-")")
    }

    private static func printProgress(_ update: AnalystWorkerProgressUpdate) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(update),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        print("progress_event: \(json)")
        fflush(stdout)
    }

    private static func render(error: AnalystIPCClientError) -> String {
        switch error {
        case .missingResult:
            return "IPC response was missing a result payload"
        case .invalidURL:
            return "Invalid IPC URL"
        case .invalidResponse:
            return "IPC server returned an invalid response"
        case .transport(let category, let host, let port, let tokenPresent, let metadataSource, let attempts):
            return "IPC transport unavailable category=\(category) host=\(host) port=\(port) token_present=\(tokenPresent) metadata=\(metadataSource) attempts=\(attempts)"
        case .unauthorized(let host, let port, let tokenPresent, let metadataSource):
            return "IPC authorization failed host=\(host) port=\(port) token_present=\(tokenPresent) metadata=\(metadataSource)"
        case .server(let code, let message):
            return "\(code): \(message)"
        }
    }

    private static func render(error: AnalystWorkerSelectionError) -> String {
        switch error {
        case .charterNotFound(let id):
            return "requested charter not found: \(id)"
        case .ambiguousCharterSelection(let availableCharterIDs):
            let available = availableCharterIDs.joined(separator: ", ")
            return "multiple charters are available; rerun with --charter-id. Available: \(available)"
        case .cannotSeedRequestedCharter(let id, let seedCharterID):
            return "no charters exist and requested charter \(id) cannot be seeded. Seeded startup charter id is \(seedCharterID)"
        case .invalidDraftSelection(let reason):
            return reason
        case .providerSynthesisFailed(let reason):
            return reason
        }
    }

    private static func printUsage() {
        print("Usage: swift run alpaca_analyst_worker [run-once|preflight-openai-key-access] [--charter-id ID] [--task-id ID] [--delegation-id ID] [--pm-id ID] [--provider-kind openai|anthropic] [--credential-profile-id ID] [--runtime-id ID] [--reasoning-mode standard|deliberate] [--runtime-policy-source charter_default|specialization_default|pm_delegation_override|task_override] [--news-limit 10] [--draft-signal] [--draft-proposal] [--openai-credential-stdin|--anthropic-credential-stdin]")
    }

    private static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func runOpenAIKeyPreflight(
        openAIKeyStatusProvider: any OpenAIKeyStatusProviding
    ) -> Int {
        let resolution = openAIKeyStatusProvider.credentialResolution()
        print("openai_key_ready: \(resolution.isReady ? "true" : "false")")
        print("openai_key_status: \(resolution.status.rawValue)")
        print("openai_key_summary: \(resolution.summary)")
        return 0
    }

    private static func makeOpenAIKeyStatusProvider(
        sessionOpenAIKey: String?,
        requiresSessionCredential: Bool = false
    ) -> any OpenAIKeyStatusProviding {
        if let sessionOpenAIKey,
           sessionOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return StaticOpenAIKeyStatusProvider(apiKey: sessionOpenAIKey)
        }
        if requiresSessionCredential {
            return StaticOpenAIKeyStatusProvider(apiKey: nil)
        }
        return OpenAIKeychainStatusProvider()
    }

    private static func makeLLMCredentialResolver(
        sessionAnthropicKey: String?,
        requiresSessionCredential: Bool = false
    ) -> any LLMCredentialResolving {
        guard let sessionAnthropicKey,
              sessionAnthropicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            if requiresSessionCredential {
                return MissingSessionLLMCredentialResolver(providerKind: .anthropic)
            }
            return LLMKeychainCredentialResolver()
        }
        return StaticLLMCredentialResolver(
            providerKind: .anthropic,
            apiKey: sessionAnthropicKey
        )
    }

    private static func readCredentialFromStandardInput() -> String? {
        guard let value = readLine(strippingNewline: true) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct MissingSessionLLMCredentialResolver: LLMCredentialResolving {
    let providerKind: LLMProviderKind

    func resolve(profile: LLMCredentialProfile) -> LLMCredentialResolution {
        LLMCredentialResolution(
            status: .missingKey,
            profileId: profile.profileId,
            providerKind: profile.providerKind,
            matchedServiceOrLabel: profile.keychainService,
            account: profile.keychainAccount,
            summary: "No app session credential was handed to the analyst worker for \(providerKind.displayName)."
        )
    }
}

private extension WorkerOptions {
    var usesCredentialStdin: Bool {
        useOpenAICredentialStdin || useAnthropicCredentialStdin
    }

    var intendedRuntimePolicy: AnalystRuntimePolicy? {
        guard let runtimeID else { return nil }
        let provider = providerKind ?? .openAI
        return AnalystRuntimePolicy(
            providerKind: provider,
            credentialProfileId: credentialProfileID ?? provider.defaultCredentialProfileId,
            runtimeIdentifier: runtimeID,
            reasoningMode: reasoningMode,
            policySource: runtimePolicySource ?? .pmDelegationOverride,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private struct StaticLLMCredentialResolver: LLMCredentialResolving {
    let providerKind: LLMProviderKind
    let apiKey: String

    func resolve(profile: LLMCredentialProfile) -> LLMCredentialResolution {
        guard profile.providerKind == providerKind else {
            return LLMCredentialResolution(
                status: .missingKey,
                profileId: profile.profileId,
                providerKind: profile.providerKind,
                account: profile.keychainAccount,
                summary: "No static session credential was provided for \(profile.providerKind.displayName)."
            )
        }
        return LLMCredentialResolution(
            status: .ready,
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            profileId: profile.profileId,
            providerKind: profile.providerKind,
            matchedServiceOrLabel: profile.keychainService,
            account: profile.keychainAccount,
            summary: "\(profile.providerKind.displayName) API key resolved from the app session credential channel."
        )
    }
}

private enum WorkerExit: Error {
    case normal
    case invalidArguments(String)
}
