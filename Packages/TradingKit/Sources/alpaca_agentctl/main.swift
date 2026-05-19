import Foundation
import TradingKit

@main
struct AlpacaAgentCtl {
    static func main() async {
        let exitCode = await run(arguments: Array(CommandLine.arguments.dropFirst()))
        Foundation.exit(Int32(exitCode))
    }

    private static func run(arguments: [String]) async -> Int {
        do {
            let command = try parseCommand(arguments: arguments)
            let runtimeInfo = try AgentControlRuntimeInfoStore().load()
            let response = try await execute(command: command, runtimeInfo: runtimeInfo)
            print(response.text)

            guard response.httpStatus >= 200,
                  response.httpStatus < 300,
                  response.envelope?.ok == true
            else {
                return 1
            }
            return 0
        } catch let error as AgentControlRuntimeInfoStoreError {
            switch error {
            case .missingFile:
                print(errorEnvelope(code: "ipc_runtime_missing", message: "IPC runtime file not found. Is the app running?"))
            case .invalidFile:
                print(errorEnvelope(code: "ipc_runtime_invalid", message: "IPC runtime file is invalid."))
            case .unsupportedPath:
                print(errorEnvelope(code: "ipc_runtime_path", message: "Unsupported IPC runtime path."))
            }
            return 1
        } catch let error as CLIError {
            print(errorEnvelope(code: error.code, message: error.message))
            return 1
        } catch {
            print(errorEnvelope(code: "agentctl_failed", message: error.localizedDescription))
            return 1
        }
    }

    static func parseCommand(arguments: [String]) throws -> CLICommand {
        guard let first = arguments.first else {
            throw CLIError(code: "usage", message: usage())
        }

        switch first {
        case "status":
            return .status
        case "arm-live":
            return .armLive
        case "disarm-live":
            return .disarmLive
        case "kill-switch":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "kill-switch requires on|off")
            }
            switch arguments[1].lowercased() {
            case "on": return .killSwitch(true)
            case "off": return .killSwitch(false)
            default:
                throw CLIError(code: "usage", message: "kill-switch requires on|off")
            }
        case "strategy":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "strategy requires list|start|stop")
            }
            switch arguments[1] {
            case "list":
                return .strategyList
            case "start":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "strategy start <id> [--params '<json>'] | strategy start --proposal <id>")
                }
                if arguments[2] == "--proposal" {
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "strategy start --proposal <id>")
                    }
                    return .strategyStartFromProposal(proposalID: arguments[3])
                }
                let id = arguments[2]
                let params = try parseParamsFlag(Array(arguments.dropFirst(3)))
                return .strategyStart(id: id, params: params)
            case "stop":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "strategy stop <id>")
                }
                return .strategyStop(id: arguments[2])
            default:
                throw CLIError(code: "usage", message: "strategy requires list|start|stop")
            }
        case "analyst":
            guard arguments.count >= 3 else {
                throw CLIError(code: "usage", message: "analyst requires charter|task|memo|finding|signal|evidence-bundle|news")
            }
            switch arguments[1] {
            case "charter":
                switch arguments[2] {
                case "list":
                    return .analystCharterList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "analyst charter get <id>")
                    }
                    return .analystCharterGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5,
                          arguments[3] == "--file"
                    else {
                        throw CLIError(code: "usage", message: "analyst charter upsert --file <path-to-json>")
                    }
                    return .analystCharterUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "analyst charter requires list|get|upsert")
                }
            case "task":
                switch arguments[2] {
                case "list":
                    return .analystTaskList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "analyst task get <id>")
                    }
                    return .analystTaskGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5,
                          arguments[3] == "--file"
                    else {
                        throw CLIError(code: "usage", message: "analyst task upsert --file <path-to-json>")
                    }
                    return .analystTaskUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "analyst task requires list|get|upsert")
                }
            case "memo":
                switch arguments[2] {
                case "list":
                    return .analystMemoList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "analyst memo get <id>")
                    }
                    return .analystMemoGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5,
                          arguments[3] == "--file"
                    else {
                        throw CLIError(code: "usage", message: "analyst memo upsert --file <path-to-json>")
                    }
                    return .analystMemoUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "analyst memo requires list|get|upsert")
                }
            case "finding":
                switch arguments[2] {
                case "list":
                    return .analystFindingList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "analyst finding get <id>")
                    }
                    return .analystFindingGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5,
                          arguments[3] == "--file"
                    else {
                        throw CLIError(code: "usage", message: "analyst finding upsert --file <path-to-json>")
                    }
                    return .analystFindingUpsert(filePath: arguments[4])
                case "draft-signal":
                    guard arguments.count >= 5,
                          arguments[3] == "--id"
                    else {
                        throw CLIError(code: "usage", message: "analyst finding draft-signal --id <finding-id>")
                    }
                    return .analystFindingDraftSignal(id: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "analyst finding requires list|get|upsert|draft-signal")
                }
            case "signal":
                switch arguments[2] {
                case "draft-proposal":
                    guard arguments.count >= 5,
                          arguments[3] == "--id"
                    else {
                        throw CLIError(code: "usage", message: "analyst signal draft-proposal --id <signal-id> [--strategy <strategy-id>]")
                    }
                    let signalID = arguments[4]
                    let values = try parseFlagMap(Array(arguments.dropFirst(5)))
                    return .analystSignalDraftProposal(
                        id: signalID,
                        strategyID: values["--strategy"]
                    )
                default:
                    throw CLIError(code: "usage", message: "analyst signal requires draft-proposal")
                }
            case "evidence-bundle":
                switch arguments[2] {
                case "upsert":
                    guard arguments.count >= 5,
                          arguments[3] == "--file"
                    else {
                        throw CLIError(code: "usage", message: "analyst evidence-bundle upsert --file <path-to-json>")
                    }
                    return .analystEvidenceBundleUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "analyst evidence-bundle requires upsert")
                }
            case "news":
                switch arguments[2] {
                case "list":
                    let values = try parseFlagMap(Array(arguments.dropFirst(3)))
                    let limit = try parseNonNegativeIntFlag(values["--limit"], label: "--limit", defaultValue: 50)
                    let since = try parseOptionalDateFlag(values["--since"], label: "--since")
                    return .analystNewsList(limit: max(1, limit), since: since)
                default:
                    throw CLIError(code: "usage", message: "analyst news requires list")
                }
            default:
                throw CLIError(code: "usage", message: "analyst requires charter|task|memo|finding|signal|evidence-bundle|news")
            }
        case "pm":
            guard arguments.count >= 3 else {
                throw CLIError(code: "usage", message: "pm requires profile|mandate|instruction|notebook-entry|portfolio-strategy-brief|recent-news-analyst-runtime|standing-bench-analyst-runtime|decision|approval-request|communication-session|communication-message|delegation|exercise")
            }
            switch arguments[1] {
            case "profile":
                switch arguments[2] {
                case "list":
                    return .pmProfileList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm profile get <id>")
                    }
                    return .pmProfileGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm profile upsert --file <path-to-json>")
                    }
                    return .pmProfileUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm profile requires list|get|upsert")
                }
            case "mandate":
                switch arguments[2] {
                case "list":
                    return .pmMandateList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm mandate get <id>")
                    }
                    return .pmMandateGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm mandate upsert --file <path-to-json>")
                    }
                    return .pmMandateUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm mandate requires list|get|upsert")
                }
            case "instruction":
                switch arguments[2] {
                case "list":
                    return .pmInstructionList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm instruction get <id>")
                    }
                    return .pmInstructionGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm instruction upsert --file <path-to-json>")
                    }
                    return .pmInstructionUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm instruction requires list|get|upsert")
                }
            case "notebook-entry":
                switch arguments[2] {
                case "list":
                    return .pmNotebookEntryList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm notebook-entry get <id>")
                    }
                    return .pmNotebookEntryGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm notebook-entry upsert --file <path-to-json>")
                    }
                    return .pmNotebookEntryUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm notebook-entry requires list|get|upsert")
                }
            case "portfolio-strategy-brief":
                switch arguments[2] {
                case "get":
                    return .portfolioStrategyBriefGet
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm portfolio-strategy-brief upsert --file <path-to-json>")
                    }
                    return .portfolioStrategyBriefUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm portfolio-strategy-brief requires get|upsert")
                }
            case "recent-news-analyst-runtime":
                switch arguments[2] {
                case "get":
                    return .recentNewsAnalystRuntimeSettingsGet
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm recent-news-analyst-runtime upsert --file <path-to-json>")
                    }
                    return .recentNewsAnalystRuntimeSettingsUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm recent-news-analyst-runtime requires get|upsert")
                }
            case "standing-bench-analyst-runtime":
                switch arguments[2] {
                case "get":
                    return .standingBenchAnalystRuntimeSettingsGet
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm standing-bench-analyst-runtime upsert --file <path-to-json>")
                    }
                    return .standingBenchAnalystRuntimeSettingsUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm standing-bench-analyst-runtime requires get|upsert")
                }
            case "decision":
                switch arguments[2] {
                case "list":
                    return .pmDecisionList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm decision get <id>")
                    }
                    return .pmDecisionGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm decision upsert --file <path-to-json>")
                    }
                    return .pmDecisionUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm decision requires list|get|upsert")
                }
            case "approval-request":
                switch arguments[2] {
                case "list":
                    return .pmApprovalRequestList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm approval-request get <id>")
                    }
                    return .pmApprovalRequestGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm approval-request upsert --file <path-to-json>")
                    }
                    return .pmApprovalRequestUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm approval-request requires list|get|upsert")
                }
            case "communication-session":
                switch arguments[2] {
                case "list":
                    return .pmCommunicationSessionList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm communication-session get <id>")
                    }
                    return .pmCommunicationSessionGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm communication-session upsert --file <path-to-json>")
                    }
                    return .pmCommunicationSessionUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm communication-session requires list|get|upsert")
                }
            case "communication-message":
                switch arguments[2] {
                case "list":
                    return .pmCommunicationMessageList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm communication-message get <id>")
                    }
                    return .pmCommunicationMessageGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm communication-message upsert --file <path-to-json>")
                    }
                    return .pmCommunicationMessageUpsert(filePath: arguments[4])
                default:
                    throw CLIError(code: "usage", message: "pm communication-message requires list|get|upsert")
                }
            case "delegation":
                switch arguments[2] {
                case "list":
                    return .pmDelegationList
                case "get":
                    guard arguments.count >= 4 else {
                        throw CLIError(code: "usage", message: "pm delegation get <id>")
                    }
                    return .pmDelegationGet(id: arguments[3])
                case "upsert":
                    guard arguments.count >= 5, arguments[3] == "--file" else {
                        throw CLIError(code: "usage", message: "pm delegation upsert --file <path-to-json>")
                    }
                    return .pmDelegationUpsert(filePath: arguments[4])
                case "launch":
                    guard arguments.count >= 5, arguments[3] == "--id" else {
                        throw CLIError(code: "usage", message: "pm delegation launch --id <delegation-id> [--draft-signal] [--draft-proposal]")
                    }
                    let delegationID = arguments[4]
                    let draftSignal = arguments.contains("--draft-signal")
                    let draftProposal = arguments.contains("--draft-proposal")
                    return .pmDelegationLaunch(
                        id: delegationID,
                        draftSignal: draftSignal,
                        draftProposal: draftProposal
                    )
                default:
                    throw CLIError(code: "usage", message: "pm delegation requires list|get|upsert|launch")
                }
            case "exercise":
                switch arguments[2] {
                case "run":
                    let values = try parseFlagMap(Array(arguments.dropFirst(3)))
                    let pmID = values["--pm-id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let charterID = values["--charter-id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let taskID = values["--task-id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let scenarioLabel = values["--scenario-label"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let runtimeID = values["--runtime-id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let reasoningMode: AnalystRuntimeReasoningMode?
                    if let rawReasoning = values["--reasoning-mode"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !rawReasoning.isEmpty {
                        guard let parsed = AnalystRuntimeReasoningMode(rawValue: rawReasoning) else {
                            throw CLIError(code: "usage", message: "pm exercise run --reasoning-mode must be standard|deliberate")
                        }
                        reasoningMode = parsed
                    } else {
                        reasoningMode = nil
                    }
                    let draftSignal = values["--draft-signal"] != nil
                    let draftProposal = values["--draft-proposal"] != nil
                    if draftProposal && draftSignal == false {
                        throw CLIError(code: "usage", message: "pm exercise run --draft-proposal requires --draft-signal")
                    }
                    return .pmExerciseRun(
                        options: PMOperationalExerciseOptions(
                            pmId: pmID?.nilIfEmpty,
                            charterId: charterID?.nilIfEmpty,
                            taskId: taskID?.nilIfEmpty,
                            scenarioLabel: scenarioLabel?.nilIfEmpty,
                            taskTitleOverride: nil,
                            taskDescriptionOverride: nil,
                            taskTagsOverride: [],
                            runtimeIdentifier: runtimeID?.nilIfEmpty,
                            reasoningMode: reasoningMode,
                            draftSignal: draftSignal,
                            draftProposal: draftProposal
                        )
                    )
                case "quality-suite":
                    let values = try parseFlagMap(Array(arguments.dropFirst(3)))
                    return .pmExerciseQualitySuite(
                        options: PMOperationalExerciseQualitySuiteOptions(
                            pmId: values["--pm-id"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                            charterId: values["--charter-id"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        )
                    )
                case "workflow-suite":
                    let values = try parseFlagMap(Array(arguments.dropFirst(3)))
                    return .pmExerciseWorkflowSuite(
                        options: PMOperationalWorkflowSuiteOptions(
                            pmId: values["--pm-id"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                            charterId: values["--charter-id"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        )
                    )
                case "canonical-suite":
                    let values = try parseFlagMap(Array(arguments.dropFirst(3)))
                    return .pmExerciseCanonicalSuite(
                        options: PMCanonicalOperatingSuiteOptions(
                            pmId: values["--pm-id"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                            charterId: values["--charter-id"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        )
                    )
                default:
                    throw CLIError(code: "usage", message: "pm exercise requires run|quality-suite|workflow-suite|canonical-suite")
                }
            default:
                throw CLIError(code: "usage", message: "pm requires profile|mandate|instruction|notebook-entry|portfolio-strategy-brief|recent-news-analyst-runtime|standing-bench-analyst-runtime|decision|approval-request|communication-session|communication-message|delegation|exercise")
            }
        case "proposal":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "proposal requires list|get|upsert|submit|approve-paper|deny-paper")
            }
            switch arguments[1] {
            case "list":
                return .proposalList
            case "get":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "proposal get <id>")
                }
                return .proposalGet(id: arguments[2])
            case "upsert":
                guard arguments.count >= 4,
                      arguments[2] == "--file"
                else {
                    throw CLIError(code: "usage", message: "proposal upsert --file <path-to-json>")
                }
                return .proposalUpsert(filePath: arguments[3])
            case "submit":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "proposal submit <id>")
                }
                return .proposalSubmit(id: arguments[2])
            case "approve-paper":
                guard arguments.count >= 5,
                      arguments[3] == "--notes"
                else {
                    throw CLIError(code: "usage", message: "proposal approve-paper <id> --notes \"...\"")
                }
                return .proposalApprovePaper(id: arguments[2], notes: arguments[4])
            case "deny-paper":
                guard arguments.count >= 5,
                      arguments[3] == "--notes"
                else {
                    throw CLIError(code: "usage", message: "proposal deny-paper <id> --notes \"...\"")
                }
                return .proposalDenyPaper(id: arguments[2], notes: arguments[4])
            default:
                throw CLIError(code: "usage", message: "proposal requires list|get|upsert|submit|approve-paper|deny-paper")
            }
        case "run":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "run requires list|get|export")
            }
            switch arguments[1] {
            case "list":
                guard arguments.count >= 4,
                      arguments[2] == "--proposal"
                else {
                    throw CLIError(code: "usage", message: "run list --proposal <proposalId>")
                }
                return .runList(proposalID: arguments[3])
            case "get":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "run get <runId>")
                }
                return .runGet(runID: arguments[2])
            case "export":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "run export <runId> [--out <path>]")
                }
                let runID = arguments[2]
                if arguments.count == 3 {
                    return .runExport(runID: runID, outPath: nil)
                }
                guard arguments.count == 5,
                      arguments[3] == "--out"
                else {
                    throw CLIError(code: "usage", message: "run export <runId> [--out <path>]")
                }
                return .runExport(runID: runID, outPath: arguments[4])
            default:
                throw CLIError(code: "usage", message: "run requires list|get|export")
            }
        case "job":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "job requires submit|list|get|cancel")
            }
            switch arguments[1] {
            case "list":
                return .jobList
            case "get":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "job get <id>")
                }
                return .jobGet(id: arguments[2])
            case "cancel":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "job cancel <id>")
                }
                return .jobCancel(id: arguments[2])
            case "submit":
                guard arguments.count >= 6,
                      arguments[2] == "--type",
                      arguments[4] == "--params"
                else {
                    throw CLIError(code: "usage", message: "job submit --type <monitor|replay_batch|rss_poll|news_retention|analyst_signals|recent_news_analyst|maintenance_retention> --params '<json>'")
                }
                guard let type = JobType(rawValue: arguments[3]) else {
                    throw CLIError(code: "usage", message: "job submit --type <monitor|replay_batch|rss_poll|news_retention|analyst_signals|recent_news_analyst|maintenance_retention> --params '<json>'")
                }
                let params: [String: JSONValue]
                do {
                    params = try JSONValue.parseObject(json: arguments[5])
                } catch {
                    throw CLIError(code: "invalid_params_json", message: "Unable to parse --params JSON object")
                }
                return .jobSubmit(type: type, params: params)
            default:
                throw CLIError(code: "usage", message: "job requires submit|list|get|cancel")
            }
        case "retention":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "retention requires get|set")
            }
            switch arguments[1] {
            case "get":
                return .retentionGet
            case "set":
                guard arguments.count >= 4,
                      arguments[2] == "--json"
                else {
                    throw CLIError(code: "usage", message: "retention set --json '<object>'")
                }
                let payload: [String: JSONValue]
                do {
                    payload = try JSONValue.parseObject(json: arguments[3])
                } catch {
                    throw CLIError(code: "invalid_params_json", message: "Unable to parse retention policy JSON object")
                }
                return .retentionSet(payload: payload)
            default:
                throw CLIError(code: "usage", message: "retention requires get|set")
            }
        case "maintenance":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "maintenance requires run|jobs-prune|memory-relief")
            }
            switch arguments[1] {
            case "run":
                let values = try parseFlagMap(Array(arguments.dropFirst(2)))
                let dryRun: Bool
                if values["--dry-run"] != nil {
                    dryRun = true
                } else if values["--apply"] != nil {
                    dryRun = false
                } else {
                    throw CLIError(code: "usage", message: "maintenance run --dry-run|--apply")
                }
                return .maintenanceRun(dryRun: dryRun)
            case "jobs-prune":
                let values = try parseFlagMap(Array(arguments.dropFirst(2)))
                let cutoff = try parseDateFlag(values["--before"], label: "--before")
                if values["--dry-run"] != nil && values["--apply"] != nil {
                    throw CLIError(code: "usage", message: "maintenance jobs-prune --before <ISO8601> [--dry-run|--apply]")
                }
                let dryRun = values["--apply"] == nil
                return .maintenanceJobsPrune(cutoff: cutoff, dryRun: dryRun)
            case "memory-relief":
                let values = try parseFlagMap(Array(arguments.dropFirst(2)))
                if values["--dry-run"] != nil && values["--force"] != nil {
                    throw CLIError(code: "usage", message: "maintenance memory-relief [--dry-run|--force]")
                }
                return .maintenanceMemoryRelief(
                    dryRun: values["--dry-run"] != nil,
                    force: values["--force"] != nil
                )
            default:
                throw CLIError(code: "usage", message: "maintenance requires run|jobs-prune|memory-relief")
            }
        case "schedule":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "schedule requires list|get|upsert|enable|run-now|remove")
            }
            switch arguments[1] {
            case "list":
                return .scheduleList
            case "get":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "schedule get <id>")
                }
                return .scheduleGet(id: arguments[2])
            case "upsert":
                guard arguments.count >= 4,
                      arguments[2] == "--json"
                else {
                    throw CLIError(code: "usage", message: "schedule upsert --json '<object>'")
                }
                let payload: [String: JSONValue]
                do {
                    payload = try JSONValue.parseObject(json: arguments[3])
                } catch {
                    throw CLIError(code: "invalid_params_json", message: "Unable to parse schedule JSON object")
                }
                return .scheduleUpsert(payload: payload)
            case "enable":
                guard arguments.count >= 4 else {
                    throw CLIError(code: "usage", message: "schedule enable <id> true|false")
                }
                guard let enabled = parseStrictBool(arguments[3]) else {
                    throw CLIError(code: "usage", message: "schedule enable <id> true|false")
                }
                return .scheduleEnable(id: arguments[2], enabled: enabled)
            case "run-now":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "schedule run-now <id>")
                }
                return .scheduleRunNow(id: arguments[2])
            case "remove":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "schedule remove <id>")
                }
                return .scheduleRemove(id: arguments[2])
            default:
                throw CLIError(code: "usage", message: "schedule requires list|get|upsert|enable|run-now|remove")
            }
        case "rss":
            guard arguments.count >= 3,
                  arguments[1] == "feed"
            else {
                throw CLIError(code: "usage", message: "rss feed requires list|add|update|remove")
            }
            switch arguments[2] {
            case "list":
                return .rssFeedList
            case "add":
                let values = try parseFlagMap(Array(arguments.dropFirst(3)))
                guard let name = values["--name"], !name.isEmpty else {
                    throw CLIError(code: "usage", message: "rss feed add requires --name")
                }
                guard let url = values["--url"], !url.isEmpty else {
                    throw CLIError(code: "usage", message: "rss feed add requires --url")
                }
                let interval = try parseNonNegativeIntFlag(values["--interval"], label: "--interval", defaultValue: 300)
                let enabled = parseBoolFlag(values["--enabled"], defaultValue: true, label: "--enabled")
                let tags = parseCSV(values["--tags"])
                return .rssFeedAdd(
                    name: name,
                    url: url,
                    enabled: enabled,
                    pollIntervalSec: max(15, interval),
                    tags: tags
                )
            case "update":
                let values = try parseFlagMap(Array(arguments.dropFirst(3)))
                guard let id = values["--id"], !id.isEmpty else {
                    throw CLIError(code: "usage", message: "rss feed update requires --id")
                }
                guard let name = values["--name"], !name.isEmpty else {
                    throw CLIError(code: "usage", message: "rss feed update requires --name")
                }
                guard let url = values["--url"], !url.isEmpty else {
                    throw CLIError(code: "usage", message: "rss feed update requires --url")
                }
                let interval = try parseNonNegativeIntFlag(values["--interval"], label: "--interval", defaultValue: 300)
                let enabled = parseBoolFlag(values["--enabled"], defaultValue: true, label: "--enabled")
                let tags = parseCSV(values["--tags"])
                return .rssFeedUpdate(
                    id: id,
                    name: name,
                    url: url,
                    enabled: enabled,
                    pollIntervalSec: max(15, interval),
                    tags: tags
                )
            case "remove":
                guard arguments.count >= 4 else {
                    throw CLIError(code: "usage", message: "rss feed remove <id>")
                }
                return .rssFeedRemove(id: arguments[3])
            default:
                throw CLIError(code: "usage", message: "rss feed requires list|add|update|remove")
            }
        case "news":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "news requires list")
            }
            switch arguments[1] {
            case "list":
                let values = try parseFlagMap(Array(arguments.dropFirst(2)))
                let limit = try parseNonNegativeIntFlag(values["--limit"], label: "--limit", defaultValue: 50)
                let since = try parseOptionalDateFlag(values["--since"], label: "--since")
                return .newsList(limit: max(1, limit), since: since)
            default:
                throw CLIError(code: "usage", message: "news requires list")
            }
        case "signal":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "signal requires list|get|ack|archive")
            }
            switch arguments[1] {
            case "list":
                let values = try parseFlagMap(Array(arguments.dropFirst(2)))
                let limit = try parseNonNegativeIntFlag(values["--limit"], label: "--limit", defaultValue: 100)
                let status = values["--status"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                return .signalList(status: status?.isEmpty == true ? nil : status, limit: max(1, limit))
            case "get":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "signal get <id>")
                }
                return .signalGet(id: arguments[2])
            case "ack":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "signal ack <id>")
                }
                return .signalAck(id: arguments[2])
            case "archive":
                guard arguments.count >= 3 else {
                    throw CLIError(code: "usage", message: "signal archive <id>")
                }
                return .signalArchive(id: arguments[2])
            default:
                throw CLIError(code: "usage", message: "signal requires list|get|ack|archive")
            }
        case "replay":
            guard arguments.count >= 2 else {
                throw CLIError(code: "usage", message: "replay requires ingest|run|quick")
            }
            switch arguments[1] {
            case "ingest":
                return try parseReplayIngest(arguments: Array(arguments.dropFirst(2)))
            case "run":
                return try parseReplayRun(arguments: Array(arguments.dropFirst(2)))
            case "quick":
                return try parseReplayQuick(arguments: Array(arguments.dropFirst(2)))
            default:
                throw CLIError(code: "usage", message: "replay requires ingest|run|quick")
            }
        default:
            throw CLIError(code: "usage", message: usage())
        }
    }

    private static func parseParamsFlag(_ arguments: [String]) throws -> [String: JSONValue] {
        guard !arguments.isEmpty else {
            return [:]
        }
        guard arguments.count == 2,
              arguments[0] == "--params"
        else {
            throw CLIError(code: "usage", message: "Expected: --params '<json>'")
        }

        do {
            return try JSONValue.parseObject(json: arguments[1])
        } catch {
            throw CLIError(code: "invalid_params_json", message: "Unable to parse --params JSON object")
        }
    }

    private static func parseReplayIngest(arguments: [String]) throws -> CLICommand {
        let values = try parseFlagMap(arguments)
        let symbols = try parseSymbolsFlag(values["--symbols"])
        let timeframe = try parseTimeframe(values["--timeframe"])
        let start = try parseDateFlag(values["--from"], label: "--from")
        let end = try parseDateFlag(values["--to"], label: "--to")
        let feed = try parseFeed(values["--feed"])

        return .replayIngest(
            symbols: symbols,
            timeframe: timeframe,
            start: start,
            end: end,
            feed: feed
        )
    }

    private static func parseReplayRun(arguments: [String]) throws -> CLICommand {
        let values = try parseFlagMap(arguments)
        guard let proposalID = values["--proposal"], !proposalID.isEmpty else {
            throw CLIError(code: "usage", message: "replay run requires --proposal <id>")
        }
        let symbols = try parseSymbolsFlag(values["--symbols"])
        let timeframe = try parseTimeframe(values["--timeframe"])
        let start = try parseDateFlag(values["--from"], label: "--from")
        let end = try parseDateFlag(values["--to"], label: "--to")
        let speed = try parseReplaySpeed(values["--speed"])
        let autoIngest = values["--auto-ingest"] != nil
        let simulateTrades = values["--simulate-trades"] != nil
        let marketSlippage = try parseNonNegativeIntFlag(
            values["--slippage-bps-market"],
            label: "--slippage-bps-market",
            defaultValue: 0
        )
        let limitSlippage = try parseNonNegativeIntFlag(
            values["--slippage-bps-limit"],
            label: "--slippage-bps-limit",
            defaultValue: 0
        )
        let feed = try parseFeed(values["--feed"])

        return .replayRun(
            proposalID: proposalID,
            symbols: symbols,
            timeframe: timeframe,
            start: start,
            end: end,
            speed: speed,
            autoIngest: autoIngest,
            feed: feed,
            simulateTrades: simulateTrades,
            slippageBps: ReplaySlippageBps(
                market: marketSlippage,
                limit: limitSlippage
            )
        )
    }

    private static func parseReplayQuick(arguments: [String]) throws -> CLICommand {
        let values = try parseFlagMap(arguments)
        guard let proposalID = values["--proposal"], !proposalID.isEmpty else {
            throw CLIError(code: "usage", message: "replay quick requires --proposal <id>")
        }
        let symbols = try parseSymbolsFlag(values["--symbols"])
        let daysString = values["--days"] ?? ""
        guard let days = Int(daysString), days > 0 else {
            throw CLIError(code: "usage", message: "replay quick requires --days <positive-int>")
        }
        let timeframe = try parseTimeframe(values["--timeframe"])
        let speed = try parseReplaySpeed(values["--speed"])
        let autoIngest = values["--auto-ingest"] != nil
        let simulateTrades = values["--simulate-trades"] != nil
        let marketSlippage = try parseNonNegativeIntFlag(
            values["--slippage-bps-market"],
            label: "--slippage-bps-market",
            defaultValue: 0
        )
        let limitSlippage = try parseNonNegativeIntFlag(
            values["--slippage-bps-limit"],
            label: "--slippage-bps-limit",
            defaultValue: 0
        )
        let feed = try parseFeed(values["--feed"])
        let end = try parseOptionalDateFlag(values["--end"], label: "--end")

        return .replayQuick(
            proposalID: proposalID,
            symbols: symbols,
            timeframe: timeframe,
            days: days,
            end: end,
            speed: speed,
            autoIngest: autoIngest,
            feed: feed,
            simulateTrades: simulateTrades,
            slippageBps: ReplaySlippageBps(
                market: marketSlippage,
                limit: limitSlippage
            )
        )
    }

    private static func parseFlagMap(_ arguments: [String]) throws -> [String: String] {
        var index = 0
        var values: [String: String] = [:]
        while index < arguments.count {
            let token = arguments[index]
            guard token.hasPrefix("--") else {
                throw CLIError(code: "usage", message: "Unexpected argument: \(token)")
            }
            if token == "--auto-ingest" ||
                token == "--simulate-trades" ||
                token == "--dry-run" ||
                token == "--apply" ||
                token == "--force" ||
                token == "--draft-signal" ||
                token == "--draft-proposal" {
                values[token] = "true"
                index += 1
                continue
            }
            guard index + 1 < arguments.count else {
                throw CLIError(code: "usage", message: "Missing value for \(token)")
            }
            values[token] = arguments[index + 1]
            index += 2
        }
        return values
    }

    private static func parseSymbolsFlag(_ raw: String?) throws -> [String] {
        guard let raw, !raw.isEmpty else {
            throw CLIError(code: "usage", message: "Missing --symbols <comma-separated>")
        }
        let symbols = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
        guard !symbols.isEmpty else {
            throw CLIError(code: "usage", message: "Missing --symbols <comma-separated>")
        }
        return symbols
    }

    private static func parseTimeframe(_ raw: String?) throws -> BarTimeframe {
        guard let raw, !raw.isEmpty else {
            throw CLIError(code: "usage", message: "Missing --timeframe <1Min|5Min|1Day>")
        }
        guard let timeframe = BarTimeframe(rawValue: raw) else {
            throw CLIError(code: "usage", message: "Invalid timeframe: \(raw)")
        }
        return timeframe
    }

    private static func parseReplaySpeed(_ raw: String?) throws -> ReplaySpeed {
        guard let raw, !raw.isEmpty else {
            throw CLIError(code: "usage", message: "Missing --speed <fast|realtime>")
        }
        guard let speed = ReplaySpeed(rawValue: raw) else {
            throw CLIError(code: "usage", message: "Invalid speed: \(raw)")
        }
        return speed
    }

    private static func parseFeed(_ raw: String?) throws -> ReplayFeed {
        guard let raw, !raw.isEmpty else {
            return .iex
        }
        guard let feed = ReplayFeed(rawValue: raw) else {
            throw CLIError(code: "usage", message: "Invalid feed: \(raw)")
        }
        return feed
    }

    private static func parseDateFlag(_ raw: String?, label: String) throws -> Date {
        guard let raw, !raw.isEmpty else {
            throw CLIError(code: "usage", message: "Missing \(label) <ISO-date>")
        }
        guard let parsed = parseDate(raw) else {
            throw CLIError(code: "usage", message: "Invalid date for \(label): \(raw)")
        }
        return parsed
    }

    private static func parseOptionalDateFlag(_ raw: String?, label: String) throws -> Date? {
        guard let raw, !raw.isEmpty else {
            return nil
        }
        guard let parsed = parseDate(raw) else {
            throw CLIError(code: "usage", message: "Invalid date for \(label): \(raw)")
        }
        return parsed
    }

    private static func parseDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: raw) {
            return parsed
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let parsed = standard.date(from: raw) {
            return parsed
        }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyy-MM-dd"
        if let day = dayFormatter.date(from: raw) {
            return day
        }
        return nil
    }

    private static func parseNonNegativeIntFlag(
        _ raw: String?,
        label: String,
        defaultValue: Int
    ) throws -> Int {
        guard let raw, !raw.isEmpty else {
            return defaultValue
        }
        guard let value = Int(raw), value >= 0 else {
            throw CLIError(code: "usage", message: "\(label) must be a non-negative integer.")
        }
        return value
    }

    private static func parseBoolFlag(
        _ raw: String?,
        defaultValue: Bool,
        label: String
    ) -> Bool {
        guard let raw else {
            return defaultValue
        }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "true" || normalized == "1" || normalized == "yes" || normalized == "on" {
            return true
        }
        if normalized == "false" || normalized == "0" || normalized == "no" || normalized == "off" {
            return false
        }
        return defaultValue
    }

    private static func parseStrictBool(_ raw: String) -> Bool? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "true" || normalized == "1" || normalized == "yes" || normalized == "on" {
            return true
        }
        if normalized == "false" || normalized == "0" || normalized == "no" || normalized == "off" {
            return false
        }
        return nil
    }

    private static func parseCSV(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else {
            return []
        }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func execute(
        command: CLICommand,
        runtimeInfo: AgentControlRuntimeInfo
    ) async throws -> CLIResponse {
        if case .runExport(let runID, let outPath) = command {
            let response = try await executeRunExport(
                runID: runID,
                outPath: outPath,
                runtimeInfo: runtimeInfo
            )
            return response
        }
        if case .pmExerciseRun(let options) = command {
            return try await executePMOperationalExercise(options: options, runtimeInfo: runtimeInfo)
        }
        if case .pmExerciseQualitySuite(let options) = command {
            return try await executePMOperationalExerciseQualitySuite(options: options, runtimeInfo: runtimeInfo)
        }
        if case .pmExerciseWorkflowSuite(let options) = command {
            return try await executePMOperationalWorkflowSuite(options: options, runtimeInfo: runtimeInfo)
        }
        if case .pmExerciseCanonicalSuite(let options) = command {
            return try await executePMCanonicalOperatingSuite(options: options, runtimeInfo: runtimeInfo)
        }
        let endpoint = try endpoint(for: command)

        guard let url = URL(string: "http://\(runtimeInfo.host):\(runtimeInfo.port)\(endpoint.path)") else {
            throw CLIError(code: "invalid_ipc_url", message: "Invalid IPC endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.timeoutInterval = 10
        request.setValue(runtimeInfo.token, forHTTPHeaderField: "X-Agent-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = body
            if let contentType = endpoint.contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CLIError(code: "ipc_unreachable", message: "Unable to reach IPC server")
        }

        guard let http = response as? HTTPURLResponse else {
            throw CLIError(code: "ipc_invalid_response", message: "IPC server returned non-HTTP response")
        }

        let text = String(data: data, encoding: .utf8)
            ?? errorEnvelope(code: "invalid_response", message: "Non-UTF8 response body")
        let envelope = try? JSONDecoder().decode(AgentControlEnvelope.self, from: data)
        return CLIResponse(httpStatus: http.statusCode, text: text, envelope: envelope)
    }

    private static func executePMOperationalExercise(
        options: PMOperationalExerciseOptions,
        runtimeInfo: AgentControlRuntimeInfo
    ) async throws -> CLIResponse {
        let result = try await runPMOperationalExercise(options: options) { spec in
            let response = try await sendRequest(spec: spec, runtimeInfo: runtimeInfo)
            guard let envelope = response.envelope else {
                throw CLIError(code: "ipc_invalid_response", message: "IPC response was missing a JSON envelope")
            }
            guard response.httpStatus >= 200,
                  response.httpStatus < 300,
                  envelope.ok == true else {
                if let error = envelope.error {
                    throw CLIError(code: error.code, message: error.message)
                }
                throw CLIError(code: "ipc_request_failed", message: "IPC request failed for \(spec.method) \(spec.path)")
            }
            return envelope
        }

        let envelope = AgentControlEnvelope(
            ok: true,
            result: try jsonValue(from: result)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        let text = String(data: data, encoding: .utf8)
            ?? errorEnvelope(code: "encode_failed", message: "Unable to encode PM exercise result")
        return CLIResponse(httpStatus: 200, text: text, envelope: envelope)
    }

    private static func executePMOperationalExerciseQualitySuite(
        options: PMOperationalExerciseQualitySuiteOptions,
        runtimeInfo: AgentControlRuntimeInfo
    ) async throws -> CLIResponse {
        let result = try await runPMOperationalExerciseQualitySuite(options: options) { spec in
            let response = try await sendRequest(spec: spec, runtimeInfo: runtimeInfo)
            guard let envelope = response.envelope else {
                throw CLIError(code: "ipc_invalid_response", message: "IPC response was missing a JSON envelope")
            }
            guard response.httpStatus >= 200,
                  response.httpStatus < 300,
                  envelope.ok == true else {
                if let error = envelope.error {
                    throw CLIError(code: error.code, message: error.message)
                }
                throw CLIError(code: "ipc_request_failed", message: "IPC request failed for \(spec.method) \(spec.path)")
            }
            return envelope
        }

        let envelope = AgentControlEnvelope(
            ok: true,
            result: try jsonValue(from: result)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        let text = String(data: data, encoding: .utf8)
            ?? errorEnvelope(code: "encode_failed", message: "Unable to encode PM quality suite result")
        return CLIResponse(httpStatus: 200, text: text, envelope: envelope)
    }

    private static func executePMOperationalWorkflowSuite(
        options: PMOperationalWorkflowSuiteOptions,
        runtimeInfo: AgentControlRuntimeInfo
    ) async throws -> CLIResponse {
        let result = try await runPMOperationalWorkflowSuite(options: options) { spec in
            let response = try await sendRequest(spec: spec, runtimeInfo: runtimeInfo)
            guard let envelope = response.envelope else {
                throw CLIError(code: "ipc_invalid_response", message: "IPC response was missing a JSON envelope")
            }
            guard response.httpStatus >= 200,
                  response.httpStatus < 300,
                  envelope.ok == true else {
                if let error = envelope.error {
                    throw CLIError(code: error.code, message: error.message)
                }
                throw CLIError(code: "ipc_request_failed", message: "IPC request failed for \(spec.method) \(spec.path)")
            }
            return envelope
        }

        let envelope = AgentControlEnvelope(
            ok: true,
            result: try jsonValue(from: result)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        let text = String(data: data, encoding: .utf8)
            ?? errorEnvelope(code: "encode_failed", message: "Unable to encode PM workflow suite result")
        return CLIResponse(httpStatus: 200, text: text, envelope: envelope)
    }

    private static func executePMCanonicalOperatingSuite(
        options: PMCanonicalOperatingSuiteOptions,
        runtimeInfo: AgentControlRuntimeInfo
    ) async throws -> CLIResponse {
        let result = try await runPMCanonicalOperatingSuite(options: options) { spec in
            let response = try await sendRequest(spec: spec, runtimeInfo: runtimeInfo)
            guard let envelope = response.envelope else {
                throw CLIError(code: "ipc_invalid_response", message: "IPC response was missing a JSON envelope")
            }
            guard response.httpStatus >= 200,
                  response.httpStatus < 300,
                  envelope.ok == true else {
                if let error = envelope.error {
                    throw CLIError(code: error.code, message: error.message)
                }
                throw CLIError(code: "ipc_request_failed", message: "IPC request failed for \(spec.method) \(spec.path)")
            }
            return envelope
        }

        let envelope = AgentControlEnvelope(
            ok: true,
            result: try jsonValue(from: result)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        let text = String(data: data, encoding: .utf8)
            ?? errorEnvelope(code: "encode_failed", message: "Unable to encode PM canonical suite result")
        return CLIResponse(httpStatus: 200, text: text, envelope: envelope)
    }

    static func runPMOperationalExercise(
        options: PMOperationalExerciseOptions,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope,
        now: @escaping @Sendable () -> Date = Date.init
    ) async throws -> PMOperationalExerciseResult {
        _ = try await send(AgentCtlRequestSpec(method: "GET", path: "/status", jsonBody: nil))

        let timestamp = now()
        let suffix = compactTimestamp(timestamp)

        let pmProfile = try await resolveExercisePMProfile(
            requestedPMID: options.pmId,
            timestamp: timestamp,
            send: send
        )
        let charter = try await resolveExerciseAnalystCharter(
            requestedCharterID: options.charterId,
            timestamp: timestamp,
            send: send
        )

        let taskResolution = try await resolveExerciseTask(
            requestedTaskID: options.taskId,
            charter: charter,
            scenarioLabel: options.scenarioLabel,
            titleOverride: options.taskTitleOverride,
            descriptionOverride: options.taskDescriptionOverride,
            tagsOverride: options.taskTagsOverride,
            suffix: suffix,
            timestamp: timestamp,
            send: send
        )

        let runtimePolicyOverride = makeExerciseRuntimePolicy(
            runtimeIdentifier: options.runtimeIdentifier,
            reasoningMode: options.reasoningMode,
            timestamp: timestamp
        )

        let delegationID = "exercise-delegation-\(suffix)"
        let requestedOutputs = exerciseRequestedOutputs(
            draftSignal: options.draftSignal,
            draftProposal: options.draftProposal
        )
        let delegation = PMDelegationRecord(
            delegationId: delegationID,
            pmId: pmProfile.pmId,
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: taskResolution.task.taskId,
            title: exerciseDisplayTitle(charter: charter, scenarioLabel: options.scenarioLabel),
            rationale: exerciseDelegationRationale(
                charter: charter,
                scenarioLabel: options.scenarioLabel,
                runtimePolicy: runtimePolicyOverride
            ),
            requestedOutputs: requestedOutputs,
            status: .issued,
            runtimePolicyOverride: runtimePolicyOverride,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let persistedDelegation: PMDelegationRecord = try await sendJSON(
            method: "POST",
            path: "/pm/delegation/upsert",
            body: delegation,
            responseType: PMDelegationRecord.self,
            send: send
        )

        let launchBody = JSONValue.object([
            "delegationId": .string(persistedDelegation.delegationId),
            "draftSignal": .bool(options.draftSignal),
            "draftProposal": .bool(options.draftProposal)
        ])
        let launchResult: AnalystWorkerLaunchResult = try await sendJSONValue(
            method: "POST",
            path: "/pm/delegation/launch",
            body: launchBody,
            responseType: AnalystWorkerLaunchResult.self,
            send: send
        )
        let memo = try await fetchExerciseMemoIfAvailable(
            memoID: launchResult.memoId,
            send: send
        )

        let decisionID = "exercise-decision-\(suffix)"
        let decision = PMDecisionRecord(
            decisionId: decisionID,
            pmId: pmProfile.pmId,
            title: exerciseDecisionTitle(
                charter: charter,
                launchResult: launchResult,
                memo: memo,
                scenarioLabel: options.scenarioLabel
            ),
            summary: exerciseDecisionSummary(
                charter: charter,
                launchResult: launchResult,
                memo: memo,
                scenarioLabel: options.scenarioLabel
            ),
            decisionType: launchResult.draftedProposalId != nil ? .recommendation : .readinessAssessment,
            status: .active,
            delegationId: persistedDelegation.delegationId,
            charterId: charter.charterId,
            taskId: taskResolution.task.taskId,
            findingId: launchResult.findingId,
            signalId: launchResult.draftedSignalId,
            proposalId: launchResult.draftedProposalId,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let persistedDecision: PMDecisionRecord = try await sendJSON(
            method: "POST",
            path: "/pm/decision/upsert",
            body: decision,
            responseType: PMDecisionRecord.self,
            send: send
        )

        let approvalRequestID = "exercise-approval-request-\(suffix)"
        let approvalRequest = PMApprovalRequest(
            approvalRequestId: approvalRequestID,
            pmId: pmProfile.pmId,
            subject: exerciseApprovalSubject(
                charter: charter,
                launchResult: launchResult,
                memo: memo,
                scenarioLabel: options.scenarioLabel
            ),
            rationale: exerciseApprovalRationale(
                launchResult: launchResult,
                memo: memo,
                scenarioLabel: options.scenarioLabel
            ),
            requestType: launchResult.draftedProposalId != nil ? .proposalReview : .other,
            status: .pending,
            decisionId: persistedDecision.decisionId,
            delegationId: persistedDelegation.delegationId,
            findingId: launchResult.findingId,
            signalId: launchResult.draftedSignalId,
            proposalId: launchResult.draftedProposalId,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let persistedApprovalRequest: PMApprovalRequest = try await sendJSON(
            method: "POST",
            path: "/pm/approval-request/upsert",
            body: approvalRequest,
            responseType: PMApprovalRequest.self,
            send: send
        )

        return PMOperationalExerciseResult(
            pmId: pmProfile.pmId,
            charterId: charter.charterId,
            taskId: taskResolution.task.taskId,
            taskCreated: taskResolution.taskCreated,
            delegationId: persistedDelegation.delegationId,
            decisionId: persistedDecision.decisionId,
            approvalRequestId: persistedApprovalRequest.approvalRequestId,
            scenarioLabel: options.scenarioLabel,
            findingId: launchResult.findingId,
            memoId: launchResult.memoId,
            memoTitle: launchResult.memoTitle,
            draftedSignalId: launchResult.draftedSignalId,
            draftedProposalId: launchResult.draftedProposalId,
            intendedRuntimeIdentifier: launchResult.runtimeProvenance?.intendedPolicy?.runtimeIdentifier
                ?? persistedDelegation.runtimePolicyOverride?.runtimeIdentifier
                ?? charter.defaultRuntimePolicy?.runtimeIdentifier,
            intendedReasoningMode: launchResult.runtimeProvenance?.intendedPolicy?.reasoningMode?.rawValue
                ?? persistedDelegation.runtimePolicyOverride?.reasoningMode?.rawValue
                ?? charter.defaultRuntimePolicy?.reasoningMode?.rawValue,
            actualRuntimeIdentifier: launchResult.runtimeProvenance?.actualRuntimeIdentifier,
            actualReasoningMode: launchResult.runtimeProvenance?.actualReasoningMode?.rawValue,
            externalEvidenceStatus: launchResult.externalEvidenceStatus,
            externalEvidenceIssueSummary: launchResult.externalEvidenceIssueSummary,
            summary: launchResult.summary
        )
    }

    static func runPMOperationalExerciseQualitySuite(
        options: PMOperationalExerciseQualitySuiteOptions,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope,
        now: @escaping @Sendable () -> Date = Date.init
    ) async throws -> PMOperationalExerciseQualitySuiteResult {
        let suiteTimestamp = now()
        let templates = qualitySuiteScenarioTemplates()
        var scenarioResults: [PMOperationalExerciseResult] = []

        for (index, template) in templates.enumerated() {
            let scenarioTime = suiteTimestamp.addingTimeInterval(TimeInterval(index))
            let result = try await runPMOperationalExercise(
                options: PMOperationalExerciseOptions(
                    pmId: options.pmId,
                    charterId: options.charterId,
                    taskId: nil,
                    scenarioLabel: template.label,
                    taskTitleOverride: template.taskTitle,
                    taskDescriptionOverride: template.taskDescription,
                    taskTagsOverride: template.tags,
                    runtimeIdentifier: template.runtimeIdentifier,
                    reasoningMode: template.reasoningMode,
                    draftSignal: template.draftSignal,
                    draftProposal: template.draftProposal
                ),
                send: send,
                now: { scenarioTime }
            )
            scenarioResults.append(result)
        }

        let observations = [
            "Compared synthesis memo quality across gpt-5 deliberate and gpt-4.1-mini standard runtime selections.",
            "Recommendation and action-adjacent review tasks preserve readable memo output while keeping PM review separate from proposal approval and trading authority.",
            "Requested Model and Execution Used remain attributable per scenario through the normal delegation/runtime provenance path."
        ]

        return PMOperationalExerciseQualitySuiteResult(
            suiteLabel: "pm_analyst_quality_suite",
            comparedTaskType: "synthesis",
            scenarioResults: scenarioResults,
            observations: observations
        )
    }

    static func runPMOperationalWorkflowSuite(
        options: PMOperationalWorkflowSuiteOptions,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope,
        now: @escaping @Sendable () -> Date = Date.init
    ) async throws -> PMOperationalWorkflowSuiteResult {
        let suiteTimestamp = now()
        let context = try await resolvePMOperationalWorkflowContext(send: send)
        let pmProfile = try await resolveExercisePMProfile(
            requestedPMID: options.pmId,
            timestamp: suiteTimestamp,
            send: send
        )
        let charter = try await resolveExerciseAnalystCharter(
            requestedCharterID: options.charterId,
            timestamp: suiteTimestamp,
            send: send
        )
        let inAppSession = try await upsertPMWorkflowExerciseSession(
            pmId: pmProfile.pmId,
            channel: .inApp,
            participantId: "owner-exercise",
            participantDisplayName: "Owner (Exercise)",
            timestamp: suiteTimestamp,
            send: send
        )
        let telegramSession = try await upsertPMWorkflowExerciseSession(
            pmId: pmProfile.pmId,
            channel: .mockTelegram,
            externalConversationId: "mock-owner-chat-\(compactTimestamp(suiteTimestamp))",
            participantId: "owner-telegram-exercise",
            participantDisplayName: "Owner (Telegram Exercise)",
            timestamp: suiteTimestamp.addingTimeInterval(0.01),
            send: send
        )

        let scenarioA = try await runPMWorkflowRemoteContinuityScenario(
            pmProfile: pmProfile,
            session: telegramSession,
            symbol: context.selectedSymbols[0],
            contextMode: context.mode,
            timestamp: suiteTimestamp,
            send: send
        )

        let scenarioB = try await runPMWorkflowStrategyRevisionScenario(
            pmProfile: pmProfile,
            session: telegramSession,
            symbol: context.selectedSymbols[0],
            contextMode: context.mode,
            timestamp: suiteTimestamp.addingTimeInterval(1),
            send: send
        )

        let scenarioC = try await runPMWorkflowResearchScenario(
            pmProfile: pmProfile,
            charter: charter,
            session: inAppSession,
            symbol: context.selectedSymbols[1],
            contextMode: context.mode,
            timestamp: suiteTimestamp.addingTimeInterval(2),
            send: send
        )
        let scenarioD = try await runPMWorkflowExecutionScenario(
            pmProfile: pmProfile,
            session: telegramSession,
            symbol: context.selectedSymbols[2],
            contextMode: context.mode,
            timestamp: suiteTimestamp.addingTimeInterval(3),
            send: send
        )
        let scenarioE = try await runPMWorkflowFollowUpScenario(
            pmProfile: pmProfile,
            charter: charter,
            session: inAppSession,
            sourceDelegationId: scenarioC.delegationId,
            symbol: context.selectedSymbols[1],
            contextMode: context.mode,
            timestamp: suiteTimestamp.addingTimeInterval(4),
            send: send
        )

        var observations = [
            "The PM loop now exercises in-app and Telegram-linked PM/User communication, conversation-led strategy refinement, analyst delegation, PM recommendationing, explicit owner response, and governed execution routing through the existing control-plane paths.",
            "Raw PM/User messages remain communication logs. Durable PM decisions, approval requests, and delegation lineage still carry the working truth.",
            "The Telegram scenario coverage uses a bounded mock Telegram session so remote-channel behavior is exercised without turning transport into durable PM truth.",
            context.mode == .portfolioBacked
                ? "Workflow exercise used the current watchlist-backed operating universe first."
                : "Workflow exercise fell back to bounded seeded watch symbols because the current watchlist was empty or unavailable."
        ]
        if scenarioD.proposalSeeded == true {
            observations.append("Execution routing used a bounded exercise-only paper-safe proposal because no suitable proposal-backed context was already available for the selected watched symbol.")
        }

        return PMOperationalWorkflowSuiteResult(
            suiteLabel: "pm_operational_workflow_suite",
            contextMode: context.mode,
            watchlistSymbolsUsed: context.watchlistSymbols,
            seededSymbols: context.mode == .seeded ? context.selectedSymbols : [],
            scenarioResults: [scenarioA, scenarioB, scenarioC, scenarioD, scenarioE],
            observations: observations
        )
    }

    static func runPMCanonicalOperatingSuite(
        options: PMCanonicalOperatingSuiteOptions,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope,
        now: @escaping @Sendable () -> Date = Date.init
    ) async throws -> PMCanonicalOperatingSuiteResult {
        let suiteTimestamp = now()
        let context = try await resolvePMOperationalWorkflowContext(send: send)
        let pmProfile = try await resolveExercisePMProfile(
            requestedPMID: options.pmId,
            timestamp: suiteTimestamp,
            send: send
        )
        let charter = try await resolveExerciseAnalystCharter(
            requestedCharterID: options.charterId,
            timestamp: suiteTimestamp,
            send: send
        )
        let inAppSession = try await upsertPMWorkflowExerciseSession(
            pmId: pmProfile.pmId,
            channel: .inApp,
            participantId: "owner-canonical-exercise",
            participantDisplayName: "Owner (Canonical Exercise)",
            timestamp: suiteTimestamp,
            send: send
        )
        let telegramSession = try await upsertPMWorkflowExerciseSession(
            pmId: pmProfile.pmId,
            channel: .mockTelegram,
            externalConversationId: "mock-owner-canonical-chat-\(compactTimestamp(suiteTimestamp))",
            participantId: "owner-canonical-telegram-exercise",
            participantDisplayName: "Owner (Canonical Telegram Exercise)",
            timestamp: suiteTimestamp.addingTimeInterval(0.01),
            send: send
        )

        let backgroundScenario = try await runPMWorkflowResearchScenario(
            pmProfile: pmProfile,
            charter: charter,
            session: inAppSession,
            symbol: context.selectedSymbols[0],
            contextMode: context.mode,
            timestamp: suiteTimestamp,
            send: send
        )
        let decisionScenario = try await runPMWorkflowExecutionScenario(
            pmProfile: pmProfile,
            session: telegramSession,
            symbol: context.selectedSymbols[1],
            contextMode: context.mode,
            timestamp: suiteTimestamp.addingTimeInterval(1),
            send: send
        )
        let moreWorkScenario = try await runPMCanonicalMoreWorkScenario(
            pmProfile: pmProfile,
            charter: charter,
            session: inAppSession,
            sourceDelegationId: backgroundScenario.delegationId,
            symbol: context.selectedSymbols[0],
            contextMode: context.mode,
            timestamp: suiteTimestamp.addingTimeInterval(2),
            send: send
        )
        let telegramScenario = try await runPMWorkflowStrategyRevisionScenario(
            pmProfile: pmProfile,
            session: telegramSession,
            symbol: context.selectedSymbols[2],
            contextMode: context.mode,
            timestamp: suiteTimestamp.addingTimeInterval(3),
            send: send
        )
        let runtimeScenario = makePMCanonicalRuntimeDegradedScenario(
            timestamp: suiteTimestamp.addingTimeInterval(4),
            contextMode: context.mode
        )

        let scenarioResults = [
            makeCanonicalBackgroundHandlingResult(from: backgroundScenario),
            makeCanonicalDecisionRequiredResult(from: decisionScenario),
            makeCanonicalMoreWorkResult(from: moreWorkScenario),
            makeCanonicalTelegramContinuationResult(from: telegramScenario),
            runtimeScenario
        ]

        let observations = [
            "The canonical suite proves five compact MVP desk stories: background handling, decision-required closure, more-work reroute, Telegram continuation, and honest degraded-runtime operation.",
            "Scenario end states assert initiative posture, owner actionability, closure discipline, desk-readiness, cross-surface coherence, and bounded runtime-operability truth rather than only producing artifacts.",
            "Telegram remains transport only throughout the canonical suite. PM decisions, approvals, delegations, strategy brief updates, and runtime status remain app-owned control-plane truth.",
            context.mode == .portfolioBacked
                ? "Canonical scenarios used the current watchlist-backed operating universe first."
                : "Canonical scenarios fell back to bounded seeded watch symbols because the current watchlist was empty or unavailable."
        ]

        return PMCanonicalOperatingSuiteResult(
            suiteLabel: "pm_canonical_operating_suite",
            contextMode: context.mode,
            watchlistSymbolsUsed: context.watchlistSymbols,
            seededSymbols: context.mode == .seeded ? context.selectedSymbols : [],
            scenarioResults: scenarioResults,
            observations: observations
        )
    }

    private struct PMOperationalWorkflowContext {
        let mode: PMOperationalExerciseContextMode
        let watchlistSymbols: [String]
        let selectedSymbols: [String]
    }

    private static func makeCanonicalDeskReadinessState(
        snapshot: PMCommandCenterSnapshot,
        initiativePosture: PMInitiativePosture?,
        initiativeReason: String?,
        closureStatus: PMRecommendationClosureStatus?,
        title: String,
        ownerAsk: String?,
        runtimeOperability: RuntimeOperabilityPresentation? = nil
    ) -> CommandCenterDeskReadinessState {
        let decisionItems: [OwnerDecisionDeskItemPresentation]
        if let initiativePosture,
           let initiativeReason,
           let closureStatus,
           let ownerAsk,
           makePMRecommendationClosurePresentation(status: closureStatus).ownerPending {
            let coherence = makePMEventCoherencePresentation(
                posture: initiativePosture,
                initiativeSummary: initiativeReason
            )
            let closure = makePMRecommendationClosurePresentation(status: closureStatus)
            decisionItems = [
                OwnerDecisionDeskItemPresentation(
                    approvalRequestId: "canonical-\(closureStatus.rawValue)",
                    title: title,
                    requestTypeTitle: "PM Ask",
                    initiativePosture: initiativePosture,
                    initiativeSummary: initiativeReason,
                    coherence: coherence,
                    closure: closure,
                    ownerAsk: ownerAsk,
                    whyNow: initiativeReason,
                    recommendation: nil,
                    strategicAlignment: nil,
                    portfolioContextSummary: nil,
                    researchTrustLabel: nil,
                    researchTrustSummary: nil,
                    researchTrustSourceConstraintSummary: nil,
                    supportingEvidence: nil,
                    uncertaintySummary: nil,
                    approvedNextStep: nil,
                    declinedNextStep: nil,
                    moreWorkNextStep: nil,
                    linkedProposalId: nil,
                    linkedCommunicationSummary: nil,
                    boundaryNote: "Canonical operating scenario projection."
                )
            ]
        } else {
            decisionItems = []
        }

        return makeCommandCenterDeskReadinessPresentation(
            snapshot: snapshot,
            decisionItems: decisionItems,
            runtimeOperability: runtimeOperability
        ).state
    }

    private static func canonicalCrossSurfaceMeaningAligned(
        posture: PMInitiativePosture,
        actionabilityCategory: PMEventActionabilityCategory
    ) -> Bool {
        let coherence = makePMEventCoherencePresentation(
            posture: posture,
            initiativeSummary: "Canonical scenario: preserve one PM event meaning across surfaces."
        )
        guard coherence.actionabilityCategory == actionabilityCategory else {
            return false
        }

        switch actionabilityCategory {
        case .clarification, .ownerInformational, .ownerDecisionRequired:
            return coherence.ownerVisible && coherence.traceabilityOnly == false
        case .benchInternal, .traceabilityOnly:
            return coherence.ownerVisible == false && coherence.traceabilityOnly
        }
    }

    private static func makeCanonicalBackgroundHandlingResult(
        from scenario: PMOperationalWorkflowScenarioResult
    ) -> PMCanonicalOperatingScenarioResult {
        let snapshot = PMCommandCenterSnapshot(
            activeDelegationsCount: scenario.delegationId == nil ? 0 : 1,
            pendingApprovalRequestsCount: 0,
            activeDecisionCount: scenario.decisionId == nil ? 0 : 1,
            pmReviewQueueCount: scenario.decisionId == nil ? 0 : 1,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        )

        return PMCanonicalOperatingScenarioResult(
            scenarioID: "canonical_background_handling",
            scenarioLabel: "Background Handling",
            scenarioKind: .backgroundHandling,
            contextMode: scenario.contextMode,
            symbol: scenario.symbol,
            initiativePosture: scenario.initiativePosture,
            actionabilityCategory: scenario.actionabilityCategory,
            closureStatus: scenario.closureStatus,
            initialDeskReadinessState: nil,
            finalDeskReadinessState: makeCanonicalDeskReadinessState(
                snapshot: snapshot,
                initiativePosture: nil,
                initiativeReason: nil,
                closureStatus: nil,
                title: scenario.scenarioLabel,
                ownerAsk: nil
            ),
            ownerActionWasRequested: false,
            ownerActionStillPending: false,
            crossSurfaceMeaningAligned: canonicalCrossSurfaceMeaningAligned(
                posture: scenario.initiativePosture,
                actionabilityCategory: scenario.actionabilityCategory
            ),
            telegramContinuationUsed: false,
            pmRuntimeOperabilityState: nil,
            recentNewsRuntimeOperabilityState: nil,
            degradedModeActive: false,
            fallbackActive: false,
            communicationSessionId: scenario.communicationSessionId,
            decisionId: scenario.decisionId,
            approvalRequestId: scenario.approvalRequestId,
            delegationId: scenario.delegationId,
            followUpDelegationId: scenario.followUpDelegationId,
            ownerResponse: scenario.ownerResponse,
            summary: "PM handled \(scenario.symbol) in the background through analyst work and a bounded PM read without surfacing a fresh owner ask."
        )
    }

    private static func makeCanonicalDecisionRequiredResult(
        from scenario: PMOperationalWorkflowScenarioResult
    ) -> PMCanonicalOperatingScenarioResult {
        let initialSnapshot = PMCommandCenterSnapshot(
            activeDelegationsCount: 0,
            pendingApprovalRequestsCount: 1,
            activeDecisionCount: 1,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        )
        let finalSnapshot = PMCommandCenterSnapshot(
            activeDelegationsCount: 0,
            pendingApprovalRequestsCount: 0,
            activeDecisionCount: 1,
            pmReviewQueueCount: scenario.executionPathReached ? 1 : 0,
            newSignalsCount: 0,
            awaitingProposalCount: scenario.executionPathReached ? 0 : 1,
            degradedDelegationsCount: 0,
            failedDelegationsCount: scenario.closureStatus == .blockedOrFailed ? 1 : 0
        )

        return PMCanonicalOperatingScenarioResult(
            scenarioID: "canonical_decision_required",
            scenarioLabel: "Decision Required",
            scenarioKind: .decisionRequired,
            contextMode: scenario.contextMode,
            symbol: scenario.symbol,
            initiativePosture: scenario.initiativePosture,
            actionabilityCategory: scenario.actionabilityCategory,
            closureStatus: scenario.closureStatus,
            initialDeskReadinessState: makeCanonicalDeskReadinessState(
                snapshot: initialSnapshot,
                initiativePosture: scenario.initiativePosture,
                initiativeReason: scenario.initiativeReason,
                closureStatus: .awaitingOwner,
                title: "Approve PM next step for \(scenario.symbol)",
                ownerAsk: "Approve, decline, or request more work."
            ),
            finalDeskReadinessState: makeCanonicalDeskReadinessState(
                snapshot: finalSnapshot,
                initiativePosture: nil,
                initiativeReason: nil,
                closureStatus: nil,
                title: scenario.scenarioLabel,
                ownerAsk: nil
            ),
            ownerActionWasRequested: true,
            ownerActionStillPending: false,
            crossSurfaceMeaningAligned: canonicalCrossSurfaceMeaningAligned(
                posture: scenario.initiativePosture,
                actionabilityCategory: scenario.actionabilityCategory
            ),
            telegramContinuationUsed: scenario.usedTelegramRemotePath,
            pmRuntimeOperabilityState: nil,
            recentNewsRuntimeOperabilityState: nil,
            degradedModeActive: scenario.closureStatus == .blockedOrFailed,
            fallbackActive: false,
            communicationSessionId: scenario.communicationSessionId,
            decisionId: scenario.decisionId,
            approvalRequestId: scenario.approvalRequestId,
            delegationId: scenario.delegationId,
            followUpDelegationId: scenario.followUpDelegationId,
            ownerResponse: scenario.ownerResponse,
            summary: "The PM produced a decision-ready ask, closed the owner-pending state after the response, and left the desk in handled or routed form rather than an ambiguous partial ask."
        )
    }

    private static func makeCanonicalMoreWorkResult(
        from scenario: PMOperationalWorkflowScenarioResult
    ) -> PMCanonicalOperatingScenarioResult {
        let initialSnapshot = PMCommandCenterSnapshot(
            activeDelegationsCount: scenario.delegationId == nil ? 0 : 1,
            pendingApprovalRequestsCount: 1,
            activeDecisionCount: 1,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        )
        let finalSnapshot = PMCommandCenterSnapshot(
            activeDelegationsCount: scenario.followUpDelegationId == nil ? 0 : 1,
            pendingApprovalRequestsCount: 0,
            activeDecisionCount: 1,
            pmReviewQueueCount: scenario.followUpDelegationId == nil ? 0 : 1,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        )

        return PMCanonicalOperatingScenarioResult(
            scenarioID: "canonical_more_work_reroute",
            scenarioLabel: "More Work / Reroute",
            scenarioKind: .moreWorkReroute,
            contextMode: scenario.contextMode,
            symbol: scenario.symbol,
            initiativePosture: scenario.initiativePosture,
            actionabilityCategory: scenario.actionabilityCategory,
            closureStatus: scenario.closureStatus,
            initialDeskReadinessState: makeCanonicalDeskReadinessState(
                snapshot: initialSnapshot,
                initiativePosture: .ownerDecisionRequired,
                initiativeReason: "Decision required: the PM had a mature enough read to ask whether to proceed or request more work.",
                closureStatus: .awaitingOwner,
                title: "Review PM follow-up posture for \(scenario.symbol)",
                ownerAsk: "Approve, decline, or request more work."
            ),
            finalDeskReadinessState: makeCanonicalDeskReadinessState(
                snapshot: finalSnapshot,
                initiativePosture: nil,
                initiativeReason: nil,
                closureStatus: nil,
                title: scenario.scenarioLabel,
                ownerAsk: nil
            ),
            ownerActionWasRequested: true,
            ownerActionStillPending: false,
            crossSurfaceMeaningAligned: canonicalCrossSurfaceMeaningAligned(
                posture: scenario.initiativePosture,
                actionabilityCategory: scenario.actionabilityCategory
            ),
            telegramContinuationUsed: false,
            pmRuntimeOperabilityState: nil,
            recentNewsRuntimeOperabilityState: nil,
            degradedModeActive: false,
            fallbackActive: false,
            communicationSessionId: scenario.communicationSessionId,
            decisionId: scenario.decisionId,
            approvalRequestId: scenario.approvalRequestId,
            delegationId: scenario.delegationId,
            followUpDelegationId: scenario.followUpDelegationId,
            ownerResponse: scenario.ownerResponse,
            summary: "The owner requested more work, the prior ask stopped reading as decision-pending, and the PM rerouted the issue back through the analyst bench with traceable follow-up lineage."
        )
    }

    private static func makeCanonicalTelegramContinuationResult(
        from scenario: PMOperationalWorkflowScenarioResult
    ) -> PMCanonicalOperatingScenarioResult {
        let finalSnapshot = PMCommandCenterSnapshot(
            activeDelegationsCount: 0,
            pendingApprovalRequestsCount: 0,
            activeDecisionCount: 0,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        )

        return PMCanonicalOperatingScenarioResult(
            scenarioID: "canonical_telegram_continuation",
            scenarioLabel: "Telegram Continuation",
            scenarioKind: .telegramContinuation,
            contextMode: scenario.contextMode,
            symbol: scenario.symbol,
            initiativePosture: scenario.initiativePosture,
            actionabilityCategory: scenario.actionabilityCategory,
            closureStatus: scenario.closureStatus,
            initialDeskReadinessState: nil,
            finalDeskReadinessState: makeCanonicalDeskReadinessState(
                snapshot: finalSnapshot,
                initiativePosture: nil,
                initiativeReason: nil,
                closureStatus: nil,
                title: scenario.scenarioLabel,
                ownerAsk: nil
            ),
            ownerActionWasRequested: false,
            ownerActionStillPending: false,
            crossSurfaceMeaningAligned: canonicalCrossSurfaceMeaningAligned(
                posture: scenario.initiativePosture,
                actionabilityCategory: scenario.actionabilityCategory
            ),
            telegramContinuationUsed: scenario.usedTelegramRemotePath,
            pmRuntimeOperabilityState: nil,
            recentNewsRuntimeOperabilityState: nil,
            degradedModeActive: false,
            fallbackActive: false,
            communicationSessionId: scenario.communicationSessionId,
            decisionId: scenario.decisionId,
            approvalRequestId: scenario.approvalRequestId,
            delegationId: scenario.delegationId,
            followUpDelegationId: scenario.followUpDelegationId,
            ownerResponse: scenario.ownerResponse,
            summary: "Telegram continued the same PM relationship and stayed semantically aligned with Command Center without creating a second truth layer."
        )
    }

    private static func makePMCanonicalRuntimeDegradedScenario(
        timestamp: Date,
        contextMode: PMOperationalExerciseContextMode
    ) -> PMCanonicalOperatingScenarioResult {
        let pmSettings = PMRuntimeSettings(
            runtimeIdentifier: "gpt-5-future-typo",
            reasoningMode: .deliberate,
            validationStatus: RuntimeValidationRecord(
                status: .invalid,
                category: .unavailable,
                summary: "Configured PM runtime is currently unavailable.",
                checkedAt: timestamp,
                checkedBy: "canonical-suite"
            ),
            lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                verifiedAt: timestamp.addingTimeInterval(-3_600),
                summary: "Last known good PM runtime remains available for bounded fallback."
            ),
            lastFallback: RuntimeFallbackRecord(
                configuredRuntimeIdentifier: "gpt-5-future-typo",
                configuredReasoningMode: .deliberate,
                fallbackRuntimeIdentifier: "gpt-5",
                fallbackReasoningMode: .deliberate,
                reasonCategory: .unavailable,
                reasonSummary: "Provider reported the configured PM runtime unavailable.",
                occurredAt: timestamp
            ),
            updatedBy: "owner",
            updateSource: .userEdited,
            createdAt: timestamp.addingTimeInterval(-7_200),
            updatedAt: timestamp.addingTimeInterval(-300)
        )
        let recentNewsSettings = RecentNewsAnalystRuntimeSettings(
            runtimeIdentifier: "gpt-5-news-next",
            reasoningMode: .standard,
            validationStatus: RuntimeValidationRecord(
                status: .invalid,
                category: .networkFailure,
                summary: "Recent News runtime check hit a network failure.",
                checkedAt: timestamp,
                checkedBy: "canonical-suite"
            ),
            lastKnownGoodRuntime: LastKnownGoodRuntimeRecord(
                runtimeIdentifier: "gpt-4.1-mini",
                reasoningMode: .standard,
                verifiedAt: timestamp.addingTimeInterval(-7_200),
                summary: "Last known good Recent News runtime remains recorded."
            ),
            lastFallback: RuntimeFallbackRecord(
                configuredRuntimeIdentifier: "gpt-5-news-next",
                configuredReasoningMode: .standard,
                fallbackRuntimeIdentifier: "gpt-4.1-mini",
                fallbackReasoningMode: .standard,
                reasonCategory: .networkFailure,
                reasonSummary: "Recent News runtime check failed due to network transport.",
                occurredAt: timestamp
            ),
            updatedBy: "owner",
            updateSource: .userEdited,
            createdAt: timestamp.addingTimeInterval(-7_200),
            updatedAt: timestamp.addingTimeInterval(-300)
        )
        let pmRuntimeOperability = makeRuntimeOperabilityPresentation(pmRuntimeSettings: pmSettings)
        let recentNewsRuntimeOperability = makeRuntimeOperabilityPresentation(
            recentNewsAnalystRuntimeSettings: recentNewsSettings
        )
        let snapshot = PMCommandCenterSnapshot(
            activeDelegationsCount: 0,
            pendingApprovalRequestsCount: 0,
            activeDecisionCount: 0,
            newSignalsCount: 0,
            awaitingProposalCount: 0,
            degradedDelegationsCount: 0,
            failedDelegationsCount: 0
        )

        return PMCanonicalOperatingScenarioResult(
            scenarioID: "canonical_runtime_degraded_fallback",
            scenarioLabel: "Runtime Degraded / Fallback",
            scenarioKind: .runtimeDegradedFallback,
            contextMode: contextMode,
            symbol: nil,
            initiativePosture: nil,
            actionabilityCategory: nil,
            closureStatus: nil,
            initialDeskReadinessState: nil,
            finalDeskReadinessState: makeCanonicalDeskReadinessState(
                snapshot: snapshot,
                initiativePosture: nil,
                initiativeReason: nil,
                closureStatus: nil,
                title: "Runtime degraded fallback",
                ownerAsk: nil,
                runtimeOperability: pmRuntimeOperability
            ),
            ownerActionWasRequested: false,
            ownerActionStillPending: false,
            crossSurfaceMeaningAligned: true,
            telegramContinuationUsed: false,
            pmRuntimeOperabilityState: pmRuntimeOperability?.state,
            recentNewsRuntimeOperabilityState: recentNewsRuntimeOperability?.state,
            degradedModeActive: pmRuntimeOperability?.degradedModeActive == true
                || recentNewsRuntimeOperability?.degradedModeActive == true,
            fallbackActive: pmRuntimeOperability?.fallbackActive == true
                || recentNewsRuntimeOperability?.fallbackActive == true,
            communicationSessionId: nil,
            decisionId: nil,
            approvalRequestId: nil,
            delegationId: nil,
            followUpDelegationId: nil,
            ownerResponse: nil,
            summary: "Runtime operability remains honest under degradation: PM and Recent News both surface the configured runtime, the fallback actually in use, and the bounded reason degraded mode is active."
        )
    }

    private struct PMWorkflowDelegationArtifacts {
        let task: AnalystTask
        let taskCreated: Bool
        let delegation: PMDelegationRecord
        let launchResult: AnalystWorkerLaunchResult
        let memo: AnalystMemo?
    }

    private static func resolvePMOperationalWorkflowContext(
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMOperationalWorkflowContext {
        let statusEnvelope = try await send(AgentCtlRequestSpec(method: "GET", path: "/status", jsonBody: nil))
        let watchlistSymbols = normalizedWatchlistSymbols(from: statusEnvelope)
        let selectedSymbols: [String]
        let mode: PMOperationalExerciseContextMode
        if watchlistSymbols.isEmpty {
            mode = .seeded
            selectedSymbols = ["AAPL", "MSFT", "NVDA"]
        } else {
            mode = .portfolioBacked
            selectedSymbols = cycleSymbols(watchlistSymbols, count: 3)
        }
        return PMOperationalWorkflowContext(
            mode: mode,
            watchlistSymbols: watchlistSymbols,
            selectedSymbols: selectedSymbols
        )
    }

    private static func normalizedWatchlistSymbols(
        from envelope: AgentControlEnvelope
    ) -> [String] {
        let values = envelope.result?.objectValue?["watchlist"]?.arrayValue ?? []
        var seen: Set<String> = []
        var symbols: [String] = []
        for value in values {
            guard let symbol = value.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
                  symbol.isEmpty == false,
                  seen.insert(symbol).inserted else {
                continue
            }
            symbols.append(symbol)
        }
        return symbols
    }

    private static func cycleSymbols(_ symbols: [String], count: Int) -> [String] {
        guard symbols.isEmpty == false else {
            return []
        }
        var values: [String] = []
        values.reserveCapacity(count)
        for index in 0..<count {
            values.append(symbols[index % symbols.count])
        }
        return values
    }

    private static func upsertPMWorkflowExerciseSession(
        pmId: String,
        channel: PMCommunicationChannel,
        externalConversationId: String? = nil,
        participantId: String,
        participantDisplayName: String,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMCommunicationSession {
        let suffix = compactTimestamp(timestamp)
        let session = PMCommunicationSession(
            sessionId: channel == .inApp
                ? "exercise-session-\(suffix)"
                : "exercise-telegram-session-\(suffix)",
            channel: channel,
            externalConversationId: externalConversationId,
            pmId: pmId,
            participantId: participantId,
            participantDisplayName: participantDisplayName,
            status: .active,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return try await sendJSON(
            method: "POST",
            path: "/pm/communication-session/upsert",
            body: session,
            responseType: PMCommunicationSession.self,
            send: send
        )
    }

    private static func upsertPMWorkflowMessage(
        sessionId: String,
        senderRole: PMCommunicationSenderRole,
        body: String,
        replyToMessageId: String?,
        timestamp: Date,
        idPrefix: String,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMCommunicationMessage {
        let direction: PMCommunicationMessageDirection = senderRole == .owner ? .incoming : .outgoing
        let suffix = compactTimestamp(timestamp)
        let message = PMCommunicationMessage(
            messageId: "\(idPrefix)-\(suffix)",
            sessionId: sessionId,
            direction: direction,
            senderRole: senderRole,
            senderId: senderRole == .owner ? "owner-exercise" : "pm-operational-exercise",
            body: body,
            sentAt: timestamp,
            replyToMessageId: replyToMessageId,
            promotion: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return try await sendJSON(
            method: "POST",
            path: "/pm/communication-message/upsert",
            body: message,
            responseType: PMCommunicationMessage.self,
            send: send
        )
    }

    private static func launchPMWorkflowDelegation(
        pmId: String,
        charter: AnalystCharter,
        scenarioLabel: String,
        symbol: String,
        taskDescription: String,
        tags: [String],
        taskingBrief: PMTaskingBrief?,
        runtimePolicyOverride: AnalystRuntimePolicy?,
        draftSignal: Bool,
        draftProposal: Bool,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMWorkflowDelegationArtifacts {
        let suffix = compactTimestamp(timestamp)
        let taskResolution = try await resolveExerciseTask(
            requestedTaskID: nil,
            charter: charter,
            scenarioLabel: scenarioLabel,
            titleOverride: "\(scenarioLabel): \(symbol) review",
            descriptionOverride: taskDescription,
            tagsOverride: tags,
            suffix: suffix,
            timestamp: timestamp,
            send: send
        )
        let delegation = PMDelegationRecord(
            delegationId: "exercise-delegation-\(suffix)",
            pmId: pmId,
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: taskResolution.task.taskId,
            title: "\(scenarioLabel): \(symbol)",
            rationale: "Exercise the bounded PM workflow on watched symbol \(symbol) through the existing control plane.",
            taskingBrief: taskingBrief,
            requestedOutputs: exerciseRequestedOutputs(draftSignal: draftSignal, draftProposal: draftProposal),
            status: .issued,
            runtimePolicyOverride: runtimePolicyOverride,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let persistedDelegation: PMDelegationRecord = try await sendJSON(
            method: "POST",
            path: "/pm/delegation/upsert",
            body: delegation,
            responseType: PMDelegationRecord.self,
            send: send
        )
        let launchResult: AnalystWorkerLaunchResult = try await sendJSONValue(
            method: "POST",
            path: "/pm/delegation/launch",
            body: .object([
                "delegationId": .string(persistedDelegation.delegationId),
                "draftSignal": .bool(draftSignal),
                "draftProposal": .bool(draftProposal)
            ]),
            responseType: AnalystWorkerLaunchResult.self,
            send: send
        )
        let memo = try await fetchExerciseMemoIfAvailable(memoID: launchResult.memoId, send: send)
        return PMWorkflowDelegationArtifacts(
            task: taskResolution.task,
            taskCreated: taskResolution.taskCreated,
            delegation: persistedDelegation,
            launchResult: launchResult,
            memo: memo
        )
    }

    private static func fetchPMWorkflowPortfolioStrategyBrief(
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PortfolioStrategyBrief {
        try await sendJSONValue(
            method: "GET",
            path: "/pm/portfolio-strategy-brief",
            body: nil,
            responseType: PortfolioStrategyBrief.self,
            send: send
        )
    }

    private static func makePMWorkflowStrategyBriefDocument(
        from existing: PortfolioStrategyBrief,
        symbol: String
    ) -> String {
        let keyThemes = Array(Set(existing.keyThemes + ["Downside-aware adds", "Macro-aware concentration review"]))
            .sorted()
        let materialDevelopments = Array(Set(existing.materialDevelopments + [
            "Owner asked for more downside analysis before concentrated adds in \(symbol).",
            "Current strategy should emphasize explicit macro framing before larger allocation changes."
        ])).sorted()
        let usuallyNotMaterial = Array(Set(existing.nonMaterialDevelopments + [
            "Routine analyst iteration that does not change the risk posture."
        ])).sorted()

        return [
            "## Objective",
            existing.objectiveSummary.isEmpty
                ? "Preserve disciplined compounding while keeping strategy changes inside explicit owner-reviewed PM workflows."
                : existing.objectiveSummary,
            "",
            "## Key Themes",
            keyThemes.map { "- \($0)" }.joined(separator: "\n"),
            "",
            "## Current Risk Posture",
            "Moderate risk posture with clearer downside scrutiny before concentrated adds or macro-sensitive allocation changes.",
            "",
            "## Material Developments",
            materialDevelopments.map { "- \($0)" }.joined(separator: "\n"),
            "",
            "## Usually Not Material",
            usuallyNotMaterial.map { "- \($0)" }.joined(separator: "\n"),
            "",
            "## Review Posture",
            "Escalate concentration changes only after downside framing, macro context, and PM recommendation quality are explicit enough for owner review."
        ].joined(separator: "\n")
    }

    private static func runPMWorkflowRemoteContinuityScenario(
        pmProfile: PMProfile,
        session: PMCommunicationSession,
        symbol: String,
        contextMode: PMOperationalExerciseContextMode,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMOperationalWorkflowScenarioResult {
        let priorOwnerMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .owner,
            body: "Last week we were discussing whether \(symbol) still belongs in the active watch set.",
            replyToMessageId: nil,
            timestamp: timestamp.addingTimeInterval(-86_400),
            idPrefix: "exercise-telegram-prior-owner",
            send: send
        )
        let priorPMMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "I kept \(symbol) on active watch, but I wanted more downside framing before recommending any bigger move.",
            replyToMessageId: priorOwnerMessage.messageId,
            timestamp: timestamp.addingTimeInterval(-86_399.8),
            idPrefix: "exercise-telegram-prior-pm",
            send: send
        )
        let resumedOwnerMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .owner,
            body: "Picking this back up remotely: what is your current short read on \(symbol), and does anything feel newly urgent?",
            replyToMessageId: priorPMMessage.messageId,
            timestamp: timestamp,
            idPrefix: "exercise-telegram-owner",
            send: send
        )
        let conciseReply = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "\(symbol) still looks worth active PM attention. Why now: the owner is resuming a recent thread and the watch thesis still needs a downside-aware read before any bigger move.",
            replyToMessageId: resumedOwnerMessage.messageId,
            timestamp: timestamp.addingTimeInterval(0.1),
            idPrefix: "exercise-telegram-pm",
            send: send
        )
        let clarificationRequest = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .owner,
            body: "What supports this, and summarize the memo-level concern in one pass.",
            replyToMessageId: conciseReply.messageId,
            timestamp: timestamp.addingTimeInterval(0.2),
            idPrefix: "exercise-telegram-owner-clarify",
            send: send
        )
        let clarificationReply = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "Support: the prior watch thesis is still intact, but I still want cleaner downside framing before a larger recommendation. Summary: stay engaged, do not treat this as execution-ready yet.",
            replyToMessageId: clarificationRequest.messageId,
            timestamp: timestamp.addingTimeInterval(0.3),
            idPrefix: "exercise-telegram-pm-clarify",
            send: send
        )

        return PMOperationalWorkflowScenarioResult(
            scenarioID: "scenario_a",
            scenarioLabel: "Scenario A — Remote conversation continuity and clarification",
            contextMode: contextMode,
            symbol: symbol,
            initiativePosture: .clarifyFirst,
            actionabilityCategory: .clarification,
            closureStatus: .awaitingOwner,
            initiativeReason: "The owner asked for narrower detail, so the PM clarified directly instead of escalating or launching new bench work.",
            communicationChannel: session.channel,
            usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
            communicationSessionId: session.sessionId,
            inboundMessageId: resumedOwnerMessage.messageId,
            outboundMessageId: conciseReply.messageId,
            clarificationMessageId: clarificationReply.messageId,
            delegationId: nil,
            followUpDelegationId: nil,
            followUpActionId: nil,
            memoId: nil,
            decisionId: nil,
            approvalRequestId: nil,
            proposalId: nil,
            proposalSeeded: nil,
            strategyBriefId: nil,
            strategyBriefChanged: false,
            ownerResponse: nil,
            readinessStatus: nil,
            routeStatus: nil,
            executionPathReached: false,
            summary: "Used the \(session.channel.rawValue) PM/User path to resume a prior \(symbol) thread, answer concisely, and handle a bounded clarification follow-up without creating a parallel transport truth layer."
        )
    }

    private static func runPMWorkflowStrategyRevisionScenario(
        pmProfile: PMProfile,
        session: PMCommunicationSession,
        symbol: String,
        contextMode: PMOperationalExerciseContextMode,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMOperationalWorkflowScenarioResult {
        let ownerMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .owner,
            body: "Update the strategy framing: before concentrated adds around \(symbol), I want clearer downside analysis and more macro context in the PM read.",
            replyToMessageId: nil,
            timestamp: timestamp,
            idPrefix: "exercise-strategy-owner",
            send: send
        )
        let currentBrief = try await fetchPMWorkflowPortfolioStrategyBrief(send: send)
        let revisedBrief = PortfolioStrategyBrief(
            briefId: currentBrief.briefId,
            title: currentBrief.title,
            documentBody: makePMWorkflowStrategyBriefDocument(from: currentBrief, symbol: symbol),
            objectiveSummary: currentBrief.objectiveSummary,
            keyThemes: currentBrief.keyThemes,
            currentRiskPosture: currentBrief.currentRiskPosture,
            materialDevelopments: currentBrief.materialDevelopments,
            nonMaterialDevelopments: currentBrief.nonMaterialDevelopments,
            reviewEscalationPosture: currentBrief.reviewEscalationPosture,
            revisionSummary: "Conversation-derived update: require clearer downside analysis and macro framing before concentrated adds around \(symbol).",
            sourceCommunicationMessageId: ownerMessage.messageId,
            updatedBy: pmProfile.pmId,
            updateSource: .conversationDerived,
            createdAt: currentBrief.createdAt,
            updatedAt: timestamp.addingTimeInterval(0.1)
        )
        let storedBrief: PortfolioStrategyBrief = try await sendJSON(
            method: "POST",
            path: "/pm/portfolio-strategy-brief/upsert",
            body: revisedBrief,
            responseType: PortfolioStrategyBrief.self,
            send: send
        )
        let pmReply = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "I revised the strategy brief accordingly. Why now: this changes how I frame concentrated adds and macro-sensitive review before I escalate anything further.",
            replyToMessageId: ownerMessage.messageId,
            timestamp: timestamp.addingTimeInterval(0.2),
            idPrefix: "exercise-strategy-pm",
            send: send
        )

        return PMOperationalWorkflowScenarioResult(
            scenarioID: "scenario_b",
            scenarioLabel: "Scenario B — Conversation-driven strategy refinement",
            contextMode: contextMode,
            symbol: symbol,
            initiativePosture: .summarizeAndInform,
            actionabilityCategory: .ownerInformational,
            closureStatus: .closedNoFurtherAction,
            initiativeReason: "The conversation changed strategy posture, so the PM updated the brief and informed the owner without turning it into a decision ask.",
            communicationChannel: session.channel,
            usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
            communicationSessionId: session.sessionId,
            inboundMessageId: ownerMessage.messageId,
            outboundMessageId: pmReply.messageId,
            clarificationMessageId: nil,
            delegationId: nil,
            followUpDelegationId: nil,
            followUpActionId: nil,
            memoId: nil,
            decisionId: nil,
            approvalRequestId: nil,
            proposalId: nil,
            proposalSeeded: nil,
            strategyBriefId: storedBrief.briefId,
            strategyBriefChanged: true,
            ownerResponse: nil,
            readinessStatus: nil,
            routeStatus: nil,
            executionPathReached: false,
            summary: "Revised the app-owned strategy brief from a PM/User conversation on \(symbol) and kept the durable strategy truth inside the existing brief record rather than in transport logs."
        )
    }

    private static func runPMWorkflowResearchScenario(
        pmProfile: PMProfile,
        charter: AnalystCharter,
        session: PMCommunicationSession,
        symbol: String,
        contextMode: PMOperationalExerciseContextMode,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMOperationalWorkflowScenarioResult {
        let strategyBrief = try await fetchPMWorkflowPortfolioStrategyBrief(send: send)
        let ownerMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .owner,
            body: "Please review \(symbol) under the latest strategy posture and tell me whether this still deserves active PM attention.",
            replyToMessageId: nil,
            timestamp: timestamp,
            idPrefix: "exercise-owner-message",
            send: send
        )
        let delegationArtifacts = try await launchPMWorkflowDelegation(
            pmId: pmProfile.pmId,
            charter: charter,
            scenarioLabel: "Scenario C — Conversation to analyst delegation and PM recommendation",
            symbol: symbol,
            taskDescription: "User-originated PM exercise request for watched symbol \(symbol). Use the current strategy brief posture (risk posture: \(strategyBrief.currentRiskPosture)) and produce a bounded readable memo that explains what changed, what matters now, and whether PM follow-up is warranted.",
            tags: ["pm-exercise", "exercise-scenario-c", "user-originated", "symbol-\(symbol.lowercased())"],
            taskingBrief: PMTaskingBrief(
                taskObjective: "Review the current operating relevance of \(symbol).",
                whyNow: strategyBrief.revisionSummary ?? "The owner just sharpened strategy posture and wants the PM read refreshed accordingly.",
                reviewLens: "Owner-facing watchlist review.",
                expectedAnswerShape: .recommendationReadySynthesis,
                challengeInstruction: "Surface disconfirming evidence before recommending escalation.",
                evidenceExpectation: "Use app-owned watch, PM communication, and current strategy-brief context first.",
                disconfirmingEvidenceExpectation: "Show what would weaken the current watch case under the updated posture.",
                expectedOutputs: ["Readable memo", "Bounded PM recommendation"]
            ),
            runtimePolicyOverride: nil,
            draftSignal: false,
            draftProposal: false,
            timestamp: timestamp.addingTimeInterval(0.1),
            send: send
        )
        let decision = PMDecisionRecord(
            decisionId: "exercise-decision-\(compactTimestamp(timestamp.addingTimeInterval(0.2)))",
            pmId: pmProfile.pmId,
            title: "PM review for \(symbol)",
            summary: delegationArtifacts.memo?.executiveSummary
                ?? delegationArtifacts.launchResult.summary,
            recommendedAction: delegationArtifacts.memo?.recommendedNextStep,
            evidenceSummary: delegationArtifacts.memo?.evidenceSummary,
            ownerAsk: "Tell me whether you want this to remain in PM review or whether you want a more action-oriented follow-up.",
            approvedNextStepSummary: "Keep this as bounded PM review unless the owner requests a proposal-linked next step.",
            sourceCommunicationMessageId: ownerMessage.messageId,
            decisionType: .recommendation,
            status: .active,
            delegationId: delegationArtifacts.delegation.delegationId,
            charterId: charter.charterId,
            taskId: delegationArtifacts.task.taskId,
            findingId: delegationArtifacts.launchResult.findingId,
            signalId: delegationArtifacts.launchResult.draftedSignalId,
            proposalId: delegationArtifacts.launchResult.draftedProposalId,
            createdAt: timestamp.addingTimeInterval(0.2),
            updatedAt: timestamp.addingTimeInterval(0.2)
        )
        let persistedDecision: PMDecisionRecord = try await sendJSON(
            method: "POST",
            path: "/pm/decision/upsert",
            body: decision,
            responseType: PMDecisionRecord.self,
            send: send
        )
        let pmReply = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "PM recommendation for \(symbol): \(delegationArtifacts.memo?.executiveSummary ?? delegationArtifacts.launchResult.summary) Strategy fit: \(strategyBrief.revisionSummary ?? strategyBrief.currentRiskPosture)",
            replyToMessageId: ownerMessage.messageId,
            timestamp: timestamp.addingTimeInterval(0.3),
            idPrefix: "exercise-pm-message",
            send: send
        )

        return PMOperationalWorkflowScenarioResult(
            scenarioID: "scenario_c",
            scenarioLabel: "Scenario C — Conversation to analyst delegation and PM recommendation",
            contextMode: contextMode,
            symbol: symbol,
            initiativePosture: .analystBenchFirst,
            actionabilityCategory: .benchInternal,
            closureStatus: .routedOrInProgress,
            initiativeReason: "Analyst work sharpened the answer before the PM re-engaged the owner with a recommendation.",
            communicationChannel: session.channel,
            usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
            communicationSessionId: session.sessionId,
            inboundMessageId: ownerMessage.messageId,
            outboundMessageId: pmReply.messageId,
            clarificationMessageId: nil,
            delegationId: delegationArtifacts.delegation.delegationId,
            followUpDelegationId: nil,
            followUpActionId: nil,
            memoId: delegationArtifacts.memo?.memoId ?? delegationArtifacts.launchResult.memoId,
            decisionId: persistedDecision.decisionId,
            approvalRequestId: nil,
            proposalId: delegationArtifacts.launchResult.draftedProposalId,
            proposalSeeded: nil,
            strategyBriefId: strategyBrief.briefId,
            strategyBriefChanged: false,
            ownerResponse: nil,
            readinessStatus: nil,
            routeStatus: nil,
            executionPathReached: false,
            summary: "Used \(contextMode.rawValue) context on \(symbol) to carry a user-originated discussion through strategy-aware analyst delegation, memo return, and PM recommendation capture."
        )
    }

    private static func runPMWorkflowExecutionScenario(
        pmProfile: PMProfile,
        session: PMCommunicationSession,
        symbol: String,
        contextMode: PMOperationalExerciseContextMode,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMOperationalWorkflowScenarioResult {
        let pmMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "Recommendation for \(symbol): I want to route one bounded paper-safe next step through the existing governed proposal path. Reply `Approve`, `Decline`, or `More Work` so I know how to proceed.",
            replyToMessageId: nil,
            timestamp: timestamp,
            idPrefix: "exercise-pm-action-message",
            send: send
        )

        let proposalResolution = try await resolvePMWorkflowProposal(
            symbol: symbol,
            timestamp: timestamp.addingTimeInterval(0.1),
            send: send
        )
        let decision = PMDecisionRecord(
            decisionId: "exercise-decision-\(compactTimestamp(timestamp.addingTimeInterval(0.2)))",
            pmId: pmProfile.pmId,
            title: "PM recommendation for \(symbol)",
            summary: "Route a bounded paper-safe next step for \(symbol) only through the existing governed proposal and execution path.",
            recommendedAction: "Ask the owner to approve PM routing into the existing paper-safe proposal path.",
            evidenceSummary: "This exercise recommendation uses watched-equity context and existing PM approval/execution boundaries.",
            approvedNextStepSummary: "If approved, the PM may route the linked proposal through the existing paper-safe review or execution path, subject to current environment and safety posture.",
            sourceCommunicationMessageId: pmMessage.messageId,
            decisionType: .recommendation,
            status: .active,
            delegationId: nil,
            charterId: nil,
            taskId: nil,
            findingId: nil,
            signalId: nil,
            proposalId: proposalResolution.proposal.proposalId,
            createdAt: timestamp.addingTimeInterval(0.2),
            updatedAt: timestamp.addingTimeInterval(0.2)
        )
        let persistedDecision: PMDecisionRecord = try await sendJSON(
            method: "POST",
            path: "/pm/decision/upsert",
            body: decision,
            responseType: PMDecisionRecord.self,
            send: send
        )
        var approvalRequest = PMApprovalRequest(
            approvalRequestId: "exercise-approval-request-\(compactTimestamp(timestamp.addingTimeInterval(0.3)))",
            pmId: pmProfile.pmId,
            subject: "Approve PM next step for \(symbol)",
            rationale: "This request records owner approval at the PM layer only. Any proposal review or execution step remains behind the app's existing governed path.",
            requestedActionSummary: "Confirm whether the PM may route the linked \(symbol) proposal into the current paper-safe path.",
            approvedNextStepSummary: "The PM may route the linked proposal into the existing proposal review or paper execution path, depending on current proposal state and environment.",
            rejectedNextStepSummary: "Keep the recommendation in PM review and request more analyst work instead of routing.",
            reviewedNextStepSummary: "Keep the PM recommendation recorded without routing.",
            sourceCommunicationMessageId: pmMessage.messageId,
            requestType: .portfolioAction,
            status: .pending,
            decisionId: persistedDecision.decisionId,
            delegationId: nil,
            findingId: nil,
            signalId: nil,
            proposalId: proposalResolution.proposal.proposalId,
            ownerResponse: nil,
            ownerRespondedAt: nil,
            createdAt: timestamp.addingTimeInterval(0.3),
            updatedAt: timestamp.addingTimeInterval(0.3)
        )
        approvalRequest = try await sendJSON(
            method: "POST",
            path: "/pm/approval-request/upsert",
            body: approvalRequest,
            responseType: PMApprovalRequest.self,
            send: send
        )

        let ownerReply = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .owner,
            body: "Approve. Route the bounded paper-safe next step for \(symbol) only if the app still enforces the normal proposal and execution gates.",
            replyToMessageId: pmMessage.messageId,
            timestamp: timestamp.addingTimeInterval(0.4),
            idPrefix: "exercise-owner-approval",
            send: send
        )

        approvalRequest.ownerResponse = .approved
        approvalRequest.ownerRespondedAt = timestamp.addingTimeInterval(0.4)
        approvalRequest.status = .resolved
        approvalRequest.updatedAt = timestamp.addingTimeInterval(0.4)
        approvalRequest = try await sendJSON(
            method: "POST",
            path: "/pm/approval-request/upsert",
            body: approvalRequest,
            responseType: PMApprovalRequest.self,
            send: send
        )

        let initialReadiness = try await fetchPMExecutionReadiness(
            approvalRequestId: approvalRequest.approvalRequestId,
            send: send
        )
        var finalRouteStatus: PMExecutionRoutingStatus? = nil
        var finalReadiness = initialReadiness

        if initialReadiness.action == .submitProposalForReview {
            let routeResult = try await routePMExecution(
                approvalRequestId: approvalRequest.approvalRequestId,
                send: send
            )
            finalRouteStatus = routeResult.status
            let _: StrategyProposal = try await sendJSONValue(
                method: "POST",
                path: "/proposal/approve-paper",
                body: .object([
                    "id": .string(proposalResolution.proposal.proposalId),
                    "reviewedBy": .string("pm-exercise"),
                    "notes": .string("Exercise-only paper-safe approval for \(symbol).")
                ]),
                responseType: StrategyProposal.self,
                send: send
            )
            finalReadiness = try await fetchPMExecutionReadiness(
                approvalRequestId: approvalRequest.approvalRequestId,
                send: send
            )
        } else if proposalResolution.proposal.approval.status == .proposed {
            let _: StrategyProposal = try await sendJSONValue(
                method: "POST",
                path: "/proposal/approve-paper",
                body: .object([
                    "id": .string(proposalResolution.proposal.proposalId),
                    "reviewedBy": .string("pm-exercise"),
                    "notes": .string("Exercise-only paper-safe approval for \(symbol).")
                ]),
                responseType: StrategyProposal.self,
                send: send
            )
            finalReadiness = try await fetchPMExecutionReadiness(
                approvalRequestId: approvalRequest.approvalRequestId,
                send: send
            )
        }

        if finalReadiness.action == .startProposalExecution {
            let executionRoute = try await routePMExecution(
                approvalRequestId: approvalRequest.approvalRequestId,
                send: send
            )
            finalRouteStatus = executionRoute.status
        }

        return PMOperationalWorkflowScenarioResult(
            scenarioID: "scenario_d",
            scenarioLabel: "Scenario D — Remote approval-response loop",
            contextMode: contextMode,
            symbol: symbol,
            initiativePosture: .ownerDecisionRequired,
            actionabilityCategory: .ownerDecisionRequired,
            closureStatus: (finalRouteStatus == .routedSuccessfully || finalReadiness.action == .startProposalExecution) ? .routedOrInProgress : .blockedOrFailed,
            initiativeReason: "The next step was decision-ready and required explicit owner direction before routing through the existing governed path.",
            communicationChannel: session.channel,
            usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
            communicationSessionId: session.sessionId,
            inboundMessageId: ownerReply.messageId,
            outboundMessageId: pmMessage.messageId,
            clarificationMessageId: nil,
            delegationId: nil,
            followUpDelegationId: nil,
            followUpActionId: nil,
            memoId: nil,
            decisionId: persistedDecision.decisionId,
            approvalRequestId: approvalRequest.approvalRequestId,
            proposalId: proposalResolution.proposal.proposalId,
            proposalSeeded: proposalResolution.seeded,
            strategyBriefId: nil,
            strategyBriefChanged: false,
            ownerResponse: approvalRequest.ownerResponse,
            readinessStatus: finalReadiness.status,
            routeStatus: finalRouteStatus,
            executionPathReached: finalRouteStatus != nil || finalReadiness.action == .startProposalExecution,
            summary: "Captured an explicit remote approval ask, recorded the owner's `Approve` response, and exercised proposal-linked execution readiness for \(symbol). Final readiness: \(finalReadiness.status.rawValue)."
        )
    }

    private static func runPMWorkflowFollowUpScenario(
        pmProfile: PMProfile,
        charter: AnalystCharter,
        session: PMCommunicationSession,
        sourceDelegationId: String?,
        symbol: String,
        contextMode: PMOperationalExerciseContextMode,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMOperationalWorkflowScenarioResult {
        guard let sourceDelegationId else {
            return PMOperationalWorkflowScenarioResult(
                scenarioID: "scenario_e",
                scenarioLabel: "Scenario E — Follow-up challenge and reroute",
                contextMode: contextMode,
                symbol: symbol,
                initiativePosture: .stayQuiet,
                actionabilityCategory: .traceabilityOnly,
                closureStatus: .closedNoFurtherAction,
                initiativeReason: "No source delegation existed, so there was no useful owner-facing follow-up to surface yet.",
                communicationChannel: session.channel,
                usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
                communicationSessionId: session.sessionId,
                inboundMessageId: nil,
                outboundMessageId: nil,
                clarificationMessageId: nil,
                delegationId: nil,
                followUpDelegationId: nil,
                followUpActionId: nil,
                memoId: nil,
                decisionId: nil,
                approvalRequestId: nil,
                proposalId: nil,
                proposalSeeded: nil,
                strategyBriefId: nil,
                strategyBriefChanged: false,
                ownerResponse: nil,
                readinessStatus: nil,
                routeStatus: nil,
                executionPathReached: false,
                summary: "Skipped follow-up scenario because no source delegation was available from the earlier exercise steps."
            )
        }

        let followUpResult: PMDelegationFollowUpResult = try await sendJSON(
            method: "POST",
            path: "/pm/delegation/follow-up",
            body: PMDelegationFollowUpRequest(
                sourceDelegationId: sourceDelegationId,
                actionType: .rerunWithRuntime,
                summary: "Challenge the first pass on \(symbol), strengthen disconfirming evidence, and rerun with deliberate reasoning.",
                requestedCharterId: charter.charterId,
                requestedRuntimePolicy: AnalystRuntimePolicy(
                    runtimeIdentifier: "gpt-5",
                    reasoningMode: .deliberate,
                    policySource: .pmDelegationOverride,
                    createdAt: timestamp,
                    updatedAt: timestamp
                ),
                taskingBrief: PMTaskingBrief(
                    taskObjective: "Challenge the prior conclusion for \(symbol).",
                    reviewLens: "Disconfirming evidence and alternate framing.",
                    challengeInstruction: "Assume the prior memo may be directionally wrong and look for what would change the PM read.",
                    evidenceExpectation: "Broaden evidence support without changing authority boundaries.",
                    expectedOutputs: ["Follow-up memo", "Updated PM recommendation"],
                    revisionReason: "Exercise follow-up challenge workflow continuity."
                )
            ),
            responseType: PMDelegationFollowUpResult.self,
            send: send
        )
        let memo = try await fetchExerciseMemoIfAvailable(
            memoID: followUpResult.launchResult?.memoId,
            send: send
        )
        let decision = PMDecisionRecord(
            decisionId: "exercise-decision-\(compactTimestamp(timestamp.addingTimeInterval(0.1)))",
            pmId: pmProfile.pmId,
            title: "PM follow-up read for \(symbol)",
            summary: memo?.executiveSummary ?? followUpResult.launchResult?.summary ?? "Recorded PM follow-up request.",
            recommendedAction: memo?.recommendedNextStep,
            evidenceSummary: memo?.evidenceSummary,
            approvedNextStepSummary: "Keep any downstream action behind the existing PM approval and proposal-routing path after the follow-up pass.",
            sourceCommunicationMessageId: nil,
            decisionType: .readinessAssessment,
            status: .active,
            delegationId: followUpResult.createdDelegationId,
            charterId: charter.charterId,
            taskId: followUpResult.createdTaskId,
            findingId: followUpResult.launchResult?.findingId,
            signalId: followUpResult.launchResult?.draftedSignalId,
            proposalId: followUpResult.launchResult?.draftedProposalId,
            createdAt: timestamp.addingTimeInterval(0.1),
            updatedAt: timestamp.addingTimeInterval(0.1)
        )
        let persistedDecision: PMDecisionRecord = try await sendJSON(
            method: "POST",
            path: "/pm/decision/upsert",
            body: decision,
            responseType: PMDecisionRecord.self,
            send: send
        )
        let pmMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "Follow-up on \(symbol): \(memo?.executiveSummary ?? "The PM requested a bounded challenge pass and recorded the revised read.")",
            replyToMessageId: nil,
            timestamp: timestamp.addingTimeInterval(0.2),
            idPrefix: "exercise-pm-followup",
            send: send
        )

        return PMOperationalWorkflowScenarioResult(
            scenarioID: "scenario_e",
            scenarioLabel: "Scenario E — Follow-up challenge and reroute",
            contextMode: contextMode,
            symbol: symbol,
            initiativePosture: .analystBenchFirst,
            actionabilityCategory: .benchInternal,
            closureStatus: .routedOrInProgress,
            initiativeReason: "The PM challenged the first pass and sent it back through the bench instead of escalating an undercooked conclusion to the owner.",
            communicationChannel: session.channel,
            usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
            communicationSessionId: session.sessionId,
            inboundMessageId: nil,
            outboundMessageId: pmMessage.messageId,
            clarificationMessageId: nil,
            delegationId: sourceDelegationId,
            followUpDelegationId: followUpResult.createdDelegationId,
            followUpActionId: followUpResult.sourceFollowUpActionId,
            memoId: memo?.memoId ?? followUpResult.launchResult?.memoId,
            decisionId: persistedDecision.decisionId,
            approvalRequestId: nil,
            proposalId: followUpResult.launchResult?.draftedProposalId,
            proposalSeeded: nil,
            strategyBriefId: nil,
            strategyBriefChanged: false,
            ownerResponse: nil,
            readinessStatus: nil,
            routeStatus: nil,
            executionPathReached: false,
            summary: "Exercised the PM follow-up challenge loop on \(symbol) using the existing analyst delegation lineage and deliberate-runtime rerun path."
        )
    }

    private static func runPMCanonicalMoreWorkScenario(
        pmProfile: PMProfile,
        charter: AnalystCharter,
        session: PMCommunicationSession,
        sourceDelegationId: String?,
        symbol: String,
        contextMode: PMOperationalExerciseContextMode,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMOperationalWorkflowScenarioResult {
        guard let sourceDelegationId else {
            return PMOperationalWorkflowScenarioResult(
                scenarioID: "canonical_more_work",
                scenarioLabel: "Canonical Scenario — More Work / Reroute",
                contextMode: contextMode,
                symbol: symbol,
                initiativePosture: .stayQuiet,
                actionabilityCategory: .traceabilityOnly,
                closureStatus: .closedNoFurtherAction,
                initiativeReason: "No source delegation was available, so there was no honest way to ask for more work and reroute it through the bench.",
                communicationChannel: session.channel,
                usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
                communicationSessionId: session.sessionId,
                inboundMessageId: nil,
                outboundMessageId: nil,
                clarificationMessageId: nil,
                delegationId: nil,
                followUpDelegationId: nil,
                followUpActionId: nil,
                memoId: nil,
                decisionId: nil,
                approvalRequestId: nil,
                proposalId: nil,
                proposalSeeded: nil,
                strategyBriefId: nil,
                strategyBriefChanged: false,
                ownerResponse: nil,
                readinessStatus: nil,
                routeStatus: nil,
                executionPathReached: false,
                summary: "Skipped more-work reroute because no source delegation existed to challenge or reroute."
            )
        }

        let pmMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "I have a bounded read on \(symbol), but you can still tell me `Approve`, `Decline`, or `More Work` before I take the next PM step.",
            replyToMessageId: nil,
            timestamp: timestamp,
            idPrefix: "canonical-more-work-pm",
            send: send
        )
        let decision = PMDecisionRecord(
            decisionId: "canonical-decision-\(compactTimestamp(timestamp.addingTimeInterval(0.1)))",
            pmId: pmProfile.pmId,
            title: "Canonical PM follow-up for \(symbol)",
            summary: "The PM has a bounded follow-up read on \(symbol), but the owner may still request more work before anything else happens.",
            recommendedAction: "Keep the symbol in PM review unless the owner approves a tighter next step.",
            evidenceSummary: "The prior analyst pass surfaced enough signal to frame a decision, but not enough to skip owner review.",
            ownerAsk: "Approve, decline, or request more work on the \(symbol) follow-up.",
            approvedNextStepSummary: "If approved, keep the next step inside the normal PM and execution safety shell.",
            sourceCommunicationMessageId: pmMessage.messageId,
            decisionType: .recommendation,
            status: .active,
            delegationId: sourceDelegationId,
            charterId: charter.charterId,
            taskId: nil,
            findingId: nil,
            signalId: nil,
            proposalId: nil,
            createdAt: timestamp.addingTimeInterval(0.1),
            updatedAt: timestamp.addingTimeInterval(0.1)
        )
        let persistedDecision: PMDecisionRecord = try await sendJSON(
            method: "POST",
            path: "/pm/decision/upsert",
            body: decision,
            responseType: PMDecisionRecord.self,
            send: send
        )
        var approvalRequest = PMApprovalRequest(
            approvalRequestId: "canonical-approval-\(compactTimestamp(timestamp.addingTimeInterval(0.2)))",
            pmId: pmProfile.pmId,
            subject: "Review PM follow-up for \(symbol)",
            rationale: "This keeps the owner loop explicit while preserving the PM's ability to reroute for more bench work instead of forcing a premature decision.",
            requestedActionSummary: "Tell the PM whether to proceed, decline, or do more work on \(symbol).",
            approvedNextStepSummary: "Proceed only through the existing PM and proposal-routing boundaries.",
            rejectedNextStepSummary: "Leave the recommendation closed and do not route anything further.",
            reviewedNextStepSummary: "Close this ask in its current form and send the issue back for more analyst work.",
            sourceCommunicationMessageId: pmMessage.messageId,
            requestType: .portfolioAction,
            status: .pending,
            decisionId: persistedDecision.decisionId,
            delegationId: sourceDelegationId,
            findingId: nil,
            signalId: nil,
            proposalId: nil,
            ownerResponse: nil,
            ownerRespondedAt: nil,
            createdAt: timestamp.addingTimeInterval(0.2),
            updatedAt: timestamp.addingTimeInterval(0.2)
        )
        approvalRequest = try await sendJSON(
            method: "POST",
            path: "/pm/approval-request/upsert",
            body: approvalRequest,
            responseType: PMApprovalRequest.self,
            send: send
        )
        let ownerReply = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .owner,
            body: "More Work. Challenge the current \(symbol) read first and come back with a sharper disconfirming-evidence pass.",
            replyToMessageId: pmMessage.messageId,
            timestamp: timestamp.addingTimeInterval(0.3),
            idPrefix: "canonical-more-work-owner",
            send: send
        )

        approvalRequest.ownerResponse = .reviewed
        approvalRequest.ownerRespondedAt = timestamp.addingTimeInterval(0.3)
        approvalRequest.status = .resolved
        approvalRequest.updatedAt = timestamp.addingTimeInterval(0.3)
        approvalRequest = try await sendJSON(
            method: "POST",
            path: "/pm/approval-request/upsert",
            body: approvalRequest,
            responseType: PMApprovalRequest.self,
            send: send
        )

        let followUpResult: PMDelegationFollowUpResult = try await sendJSON(
            method: "POST",
            path: "/pm/delegation/follow-up",
            body: PMDelegationFollowUpRequest(
                sourceDelegationId: sourceDelegationId,
                actionType: .rerunWithRuntime,
                summary: "Owner requested more work on \(symbol). Challenge the current read and return with stronger disconfirming evidence before the PM asks again.",
                requestedCharterId: charter.charterId,
                requestedRuntimePolicy: AnalystRuntimePolicy(
                    runtimeIdentifier: "gpt-5",
                    reasoningMode: .deliberate,
                    policySource: .pmDelegationOverride,
                    createdAt: timestamp.addingTimeInterval(0.31),
                    updatedAt: timestamp.addingTimeInterval(0.31)
                ),
                taskingBrief: PMTaskingBrief(
                    taskObjective: "Challenge the current PM recommendation for \(symbol).",
                    whyNow: "The owner explicitly requested more work instead of approving the prior read.",
                    reviewLens: "Disconfirming evidence before the next PM recommendation.",
                    expectedAnswerShape: .recommendationReadySynthesis,
                    challengeInstruction: "Assume the previous read may be incomplete and show what would reverse it.",
                    evidenceExpectation: "Use existing app-owned strategy, communication, and watch context first.",
                    disconfirmingEvidenceExpectation: "Make the downside case explicit before returning a revised PM recommendation.",
                    expectedOutputs: ["Follow-up memo", "Revised PM recommendation"]
                )
            ),
            responseType: PMDelegationFollowUpResult.self,
            send: send
        )
        let pmFollowUpMessage = try await upsertPMWorkflowMessage(
            sessionId: session.sessionId,
            senderRole: .pm,
            body: "Understood. I closed the prior \(symbol) ask in its old form and routed it back through the analyst bench for a stronger challenge pass.",
            replyToMessageId: ownerReply.messageId,
            timestamp: timestamp.addingTimeInterval(0.4),
            idPrefix: "canonical-more-work-pm-follow-up",
            send: send
        )

        return PMOperationalWorkflowScenarioResult(
            scenarioID: "canonical_more_work",
            scenarioLabel: "Canonical Scenario — More Work / Reroute",
            contextMode: contextMode,
            symbol: symbol,
            initiativePosture: .analystBenchFirst,
            actionabilityCategory: .benchInternal,
            closureStatus: .moreWorkRequested,
            initiativeReason: "The owner asked for more work, so the PM closed the prior ask posture and rerouted the issue through the analyst bench instead of leaving a stale pending decision.",
            communicationChannel: session.channel,
            usedTelegramRemotePath: session.channel == .telegram || session.channel == .mockTelegram,
            communicationSessionId: session.sessionId,
            inboundMessageId: ownerReply.messageId,
            outboundMessageId: pmFollowUpMessage.messageId,
            clarificationMessageId: nil,
            delegationId: sourceDelegationId,
            followUpDelegationId: followUpResult.createdDelegationId,
            followUpActionId: followUpResult.sourceFollowUpActionId,
            memoId: followUpResult.launchResult?.memoId,
            decisionId: persistedDecision.decisionId,
            approvalRequestId: approvalRequest.approvalRequestId,
            proposalId: nil,
            proposalSeeded: nil,
            strategyBriefId: nil,
            strategyBriefChanged: false,
            ownerResponse: approvalRequest.ownerResponse,
            readinessStatus: nil,
            routeStatus: nil,
            executionPathReached: false,
            summary: "Recorded an explicit `More Work` owner response on \(symbol), cleared the prior decision-ready ask posture, and rerouted the issue through bounded analyst follow-up."
        )
    }

    private static func resolvePMWorkflowProposal(
        symbol: String,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> (proposal: StrategyProposal, seeded: Bool) {
        let rows: [ProposalRow] = try await sendJSONValue(
            method: "GET",
            path: "/proposals",
            body: nil,
            responseType: [ProposalRow].self,
            send: send
        )

        for row in rows {
            let proposal: StrategyProposal = try await sendJSONValue(
                method: "GET",
                path: "/proposal?id=\(percentEncode(row.id))",
                body: nil,
                responseType: StrategyProposal.self,
                send: send
            )
            let scopeSymbols = proposal.scope.symbols?.map { $0.uppercased() } ?? []
            if scopeSymbols.contains(symbol.uppercased()),
               proposal.approval.status != .deniedPaper {
                return (proposal, false)
            }
        }

        let proposal = StrategyProposal(
            proposalId: "exercise-proposal-\(compactTimestamp(timestamp))",
            createdAt: timestamp,
            updatedAt: timestamp,
            createdBy: "pm-exercise",
            title: "Exercise proposal for \(symbol)",
            summary: "Bounded exercise-only proposal linked to watched symbol \(symbol).",
            strategyId: "heartbeat",
            parameters: ["intervalSec": .number(1)],
            scope: StrategyProposalScope(symbols: [symbol], watchlistReference: "portfolio_watch"),
            intendedEnvironmentPaperOnly: true,
            constraints: StrategyProposalConstraints(
                maxOrdersPerMinute: 1,
                maxNotionalPerOrder: Decimal(1000),
                maxDailyNotional: Decimal(1000),
                allowShort: false,
                allowOptions: false
            ),
            testPlan: StrategyProposalTestPlan(
                durationMinutes: 10,
                successMetrics: ["Workflow continuity", "No safety bypass"],
                stopConditions: ["Manual stop", "Unexpected execution error"]
            ),
            rationale: "Exercise-only PM routing artifact for watched symbol \(symbol).",
            metadata: [
                "exerciseOnly": .bool(true),
                "exerciseScenario": .string("scenario-c"),
                "exerciseSymbol": .string(symbol)
            ],
            approval: StrategyProposalApproval(status: .draft)
        )
        let persisted: StrategyProposal = try await sendJSON(
            method: "POST",
            path: "/proposal/upsert",
            body: proposal,
            responseType: StrategyProposal.self,
            send: send
        )
        return (persisted, true)
    }

    private static func fetchPMExecutionReadiness(
        approvalRequestId: String,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMExecutionRoutingAssessment {
        try await sendJSONValue(
            method: "GET",
            path: "/pm/execution-readiness?approvalRequestId=\(percentEncode(approvalRequestId))",
            body: nil,
            responseType: PMExecutionRoutingAssessment.self,
            send: send
        )
    }

    private static func routePMExecution(
        approvalRequestId: String,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMExecutionRoutingAssessment {
        try await sendJSONValue(
            method: "POST",
            path: "/pm/execution/route",
            body: .object(["approvalRequestId": .string(approvalRequestId)]),
            responseType: PMExecutionRoutingAssessment.self,
            send: send
        )
    }

    private static func sendRequest(
        spec: AgentCtlRequestSpec,
        runtimeInfo: AgentControlRuntimeInfo
    ) async throws -> CLIResponse {
        let endpoint = Endpoint(method: spec.method, path: spec.path, jsonBody: spec.jsonBody)
        guard let url = URL(string: "http://\(runtimeInfo.host):\(runtimeInfo.port)\(endpoint.path)") else {
            throw CLIError(code: "invalid_ipc_url", message: "Invalid IPC endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.timeoutInterval = 10
        request.setValue(runtimeInfo.token, forHTTPHeaderField: "X-Agent-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = body
            if let contentType = endpoint.contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CLIError(code: "ipc_unreachable", message: "Unable to reach IPC server")
        }

        guard let http = response as? HTTPURLResponse else {
            throw CLIError(code: "ipc_invalid_response", message: "IPC server returned non-HTTP response")
        }

        let text = String(data: data, encoding: .utf8)
            ?? errorEnvelope(code: "invalid_response", message: "Non-UTF8 response body")
        let envelope = try? JSONDecoder().decode(AgentControlEnvelope.self, from: data)
        return CLIResponse(httpStatus: http.statusCode, text: text, envelope: envelope)
    }

    private static func sendJSON<T: Decodable, Body: Encodable>(
        method: String,
        path: String,
        body: Body,
        responseType: T.Type,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> T {
        try await sendJSONValue(
            method: method,
            path: path,
            body: try jsonValue(from: body),
            responseType: responseType,
            send: send
        )
    }

    private static func sendJSONValue<T: Decodable>(
        method: String,
        path: String,
        body: JSONValue?,
        responseType: T.Type,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> T {
        let envelope = try await send(AgentCtlRequestSpec(method: method, path: path, jsonBody: body))
        guard let result = envelope.result else {
            throw CLIError(code: "ipc_missing_result", message: "IPC response for \(method) \(path) was missing a result payload")
        }
        return try decodeJSONValue(result, as: responseType)
    }

    static func requestSpec(for command: CLICommand) throws -> AgentCtlRequestSpec {
        let endpoint = try endpoint(for: command)
        var jsonBody: JSONValue?
        if let body = endpoint.body, endpoint.contentType == "application/json" {
            jsonBody = try? JSONDecoder().decode(JSONValue.self, from: body)
        }
        return AgentCtlRequestSpec(method: endpoint.method, path: endpoint.path, jsonBody: jsonBody)
    }

    static func endpoint(
        for command: CLICommand,
        fileLoader: (String) throws -> Data = { filePath in
            try Data(contentsOf: URL(fileURLWithPath: filePath))
        }
    ) throws -> Endpoint {
        switch command {
        case .pmExerciseRun, .pmExerciseQualitySuite, .pmExerciseWorkflowSuite, .pmExerciseCanonicalSuite:
            throw CLIError(code: "unsupported", message: "pm exercise commands are multi-step commands and do not map to a single IPC route")
        case .status:
            return Endpoint(method: "GET", path: "/status")
        case .strategyList:
            return Endpoint(method: "GET", path: "/strategies")
        case .strategyStart(let id, let params):
            return Endpoint(
                method: "POST",
                path: "/strategy/start",
                jsonBody: .object([
                    "id": .string(id),
                    "params": .object(params)
                ])
            )
        case .strategyStartFromProposal(let proposalID):
            return Endpoint(
                method: "POST",
                path: "/strategy/start-from-proposal",
                jsonBody: .object([
                    "proposalId": .string(proposalID)
                ])
            )
        case .strategyStop(let id):
            return Endpoint(
                method: "POST",
                path: "/strategy/stop",
                jsonBody: .object([
                    "id": .string(id)
                ])
            )
        case .analystCharterList:
            return Endpoint(method: "GET", path: "/analyst/charters")
        case .analystCharterGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/analyst/charter?id=\(encoded)")
        case .analystCharterUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "analyst_charter_file_read_failed", message: "Unable to read analyst charter file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/analyst/charter/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .analystTaskList:
            return Endpoint(method: "GET", path: "/analyst/tasks")
        case .analystTaskGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/analyst/task?id=\(encoded)")
        case .analystTaskUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "analyst_task_file_read_failed", message: "Unable to read analyst task file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/analyst/task/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .analystMemoList:
            return Endpoint(method: "GET", path: "/analyst/memos")
        case .analystMemoGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/analyst/memo?id=\(encoded)")
        case .analystMemoUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "analyst_memo_file_read_failed", message: "Unable to read analyst memo file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/analyst/memo/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .analystFindingList:
            return Endpoint(method: "GET", path: "/analyst/findings")
        case .analystFindingGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/analyst/finding?id=\(encoded)")
        case .analystFindingUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "analyst_finding_file_read_failed", message: "Unable to read analyst finding file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/analyst/finding/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .analystFindingDraftSignal(let id):
            return Endpoint(
                method: "POST",
                path: "/analyst/finding/draft-signal",
                jsonBody: .object([
                    "findingId": .string(id)
                ])
            )
        case .analystSignalDraftProposal(let id, let strategyID):
            var body: [String: JSONValue] = [
                "signalId": .string(id)
            ]
            if let strategyID, !strategyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                body["strategyId"] = .string(strategyID)
            }
            return Endpoint(
                method: "POST",
                path: "/analyst/signal/draft-proposal",
                jsonBody: .object(body)
            )
        case .analystEvidenceBundleUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "analyst_evidence_bundle_file_read_failed", message: "Unable to read analyst evidence bundle file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/analyst/evidence-bundle/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .analystNewsList(let limit, let since):
            var path = "/analyst/news?limit=\(max(1, limit))"
            if let since {
                let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~:")
                let encoded = iso8601(since).addingPercentEncoding(withAllowedCharacters: allowed) ?? iso8601(since)
                path.append("&since=\(encoded)")
            }
            return Endpoint(method: "GET", path: path)
        case .pmProfileList:
            return Endpoint(method: "GET", path: "/pm/profiles")
        case .pmProfileGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/profile?id=\(encoded)")
        case .pmProfileUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_profile_file_read_failed", message: "Unable to read PM profile file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/profile/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmMandateList:
            return Endpoint(method: "GET", path: "/pm/mandates")
        case .pmMandateGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/mandate?id=\(encoded)")
        case .pmMandateUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_mandate_file_read_failed", message: "Unable to read PM mandate file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/mandate/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmInstructionList:
            return Endpoint(method: "GET", path: "/pm/instructions")
        case .pmInstructionGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/instruction?id=\(encoded)")
        case .pmInstructionUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_instruction_file_read_failed", message: "Unable to read PM instruction file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/instruction/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmNotebookEntryList:
            return Endpoint(method: "GET", path: "/pm/notebook")
        case .pmNotebookEntryGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/notebook-entry?id=\(encoded)")
        case .pmNotebookEntryUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_notebook_entry_file_read_failed", message: "Unable to read PM notebook entry file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/notebook-entry/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .portfolioStrategyBriefGet:
            return Endpoint(method: "GET", path: "/pm/portfolio-strategy-brief")
        case .portfolioStrategyBriefUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "portfolio_strategy_brief_file_read_failed", message: "Unable to read portfolio strategy brief file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/portfolio-strategy-brief/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .recentNewsAnalystRuntimeSettingsGet:
            return Endpoint(method: "GET", path: "/pm/recent-news-analyst-runtime")
        case .recentNewsAnalystRuntimeSettingsUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "recent_news_analyst_runtime_settings_file_read_failed", message: "Unable to read Recent News Analyst runtime settings file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/recent-news-analyst-runtime/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .standingBenchAnalystRuntimeSettingsGet:
            return Endpoint(method: "GET", path: "/pm/standing-bench-analyst-runtime")
        case .standingBenchAnalystRuntimeSettingsUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "standing_bench_analyst_runtime_settings_file_read_failed", message: "Unable to read Standing Bench Analyst runtime settings file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/standing-bench-analyst-runtime/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmDecisionList:
            return Endpoint(method: "GET", path: "/pm/decisions")
        case .pmDecisionGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/decision?id=\(encoded)")
        case .pmDecisionUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_decision_file_read_failed", message: "Unable to read PM decision file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/decision/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmApprovalRequestList:
            return Endpoint(method: "GET", path: "/pm/approval-requests")
        case .pmApprovalRequestGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/approval-request?id=\(encoded)")
        case .pmApprovalRequestUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_approval_request_file_read_failed", message: "Unable to read PM approval request file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/approval-request/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmCommunicationSessionList:
            return Endpoint(method: "GET", path: "/pm/communication-sessions")
        case .pmCommunicationSessionGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/communication-session?id=\(encoded)")
        case .pmCommunicationSessionUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_communication_session_file_read_failed", message: "Unable to read PM communication session file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/communication-session/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmCommunicationMessageList:
            return Endpoint(method: "GET", path: "/pm/communication-messages")
        case .pmCommunicationMessageGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/communication-message?id=\(encoded)")
        case .pmCommunicationMessageUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_communication_message_file_read_failed", message: "Unable to read PM communication message file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/communication-message/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmDelegationList:
            return Endpoint(method: "GET", path: "/pm/delegations")
        case .pmDelegationGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/pm/delegation?id=\(encoded)")
        case .pmDelegationUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "pm_delegation_file_read_failed", message: "Unable to read PM delegation file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/pm/delegation/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .pmDelegationLaunch(let id, let draftSignal, let draftProposal):
            return Endpoint(
                method: "POST",
                path: "/pm/delegation/launch",
                jsonBody: .object([
                    "delegationId": .string(id),
                    "draftSignal": .bool(draftSignal),
                    "draftProposal": .bool(draftProposal)
                ])
            )
        case .proposalList:
            return Endpoint(method: "GET", path: "/proposals")
        case .proposalGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/proposal?id=\(encoded)")
        case .proposalUpsert(let filePath):
            let data: Data
            do {
                data = try fileLoader(filePath)
            } catch {
                throw CLIError(code: "proposal_file_read_failed", message: "Unable to read proposal file: \(filePath)")
            }
            return Endpoint(
                method: "POST",
                path: "/proposal/upsert",
                rawBody: data,
                contentType: "application/json"
            )
        case .proposalSubmit(let id):
            return Endpoint(
                method: "POST",
                path: "/proposal/submit",
                jsonBody: .object([
                    "id": .string(id)
                ])
            )
        case .proposalApprovePaper(let id, let notes):
            return Endpoint(
                method: "POST",
                path: "/proposal/approve-paper",
                jsonBody: .object([
                    "id": .string(id),
                    "reviewedBy": .string("agentctl"),
                    "notes": .string(notes)
                ])
            )
        case .proposalDenyPaper(let id, let notes):
            return Endpoint(
                method: "POST",
                path: "/proposal/deny-paper",
                jsonBody: .object([
                    "id": .string(id),
                    "reviewedBy": .string("agentctl"),
                    "notes": .string(notes)
                ])
            )
        case .runList(let proposalID):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = proposalID.addingPercentEncoding(withAllowedCharacters: allowed) ?? proposalID
            return Endpoint(method: "GET", path: "/runs?proposalId=\(encoded)")
        case .runGet(let runID):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = runID.addingPercentEncoding(withAllowedCharacters: allowed) ?? runID
            return Endpoint(method: "GET", path: "/run?id=\(encoded)")
        case .runExport(let runID, _):
            return Endpoint(
                method: "POST",
                path: "/run/export",
                jsonBody: .object([
                    "runId": .string(runID)
                ])
            )
        case .jobList:
            return Endpoint(method: "GET", path: "/jobs")
        case .jobGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/job?id=\(encoded)")
        case .jobSubmit(let type, let params):
            return Endpoint(
                method: "POST",
                path: "/jobs/submit",
                jsonBody: .object([
                    "type": .string(type.rawValue),
                    "params": .object(params)
                ])
            )
        case .jobCancel(let id):
            return Endpoint(
                method: "POST",
                path: "/job/cancel",
                jsonBody: .object([
                    "jobId": .string(id)
                ])
            )
        case .scheduleList:
            return Endpoint(method: "GET", path: "/schedules")
        case .scheduleGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/schedule?id=\(encoded)")
        case .scheduleUpsert(let payload):
            return Endpoint(
                method: "POST",
                path: "/schedule/upsert",
                jsonBody: .object(payload)
            )
        case .scheduleEnable(let id, let enabled):
            return Endpoint(
                method: "POST",
                path: "/schedule/enable",
                jsonBody: .object([
                    "id": .string(id),
                    "enabled": .bool(enabled)
                ])
            )
        case .scheduleRunNow(let id):
            return Endpoint(
                method: "POST",
                path: "/schedule/run-now",
                jsonBody: .object([
                    "id": .string(id)
                ])
            )
        case .scheduleRemove(let id):
            return Endpoint(
                method: "POST",
                path: "/schedule/remove",
                jsonBody: .object([
                    "id": .string(id)
                ])
            )
        case .retentionGet:
            return Endpoint(method: "GET", path: "/retention-policy")
        case .retentionSet(let payload):
            return Endpoint(
                method: "POST",
                path: "/retention-policy/update",
                jsonBody: .object(payload)
            )
        case .maintenanceRun(let dryRun):
            return Endpoint(
                method: "POST",
                path: "/maintenance/run",
                jsonBody: .object([
                    "dryRun": .bool(dryRun)
                ])
            )
        case .maintenanceJobsPrune(let cutoff, let dryRun):
            return Endpoint(
                method: "POST",
                path: "/maintenance/run",
                jsonBody: .object([
                    "dryRun": .bool(dryRun),
                    "jobTelemetryCleanupBefore": .string(iso8601(cutoff))
                ])
            )
        case .maintenanceMemoryRelief(let dryRun, let force):
            return Endpoint(
                method: "POST",
                path: "/maintenance/memory-relief",
                jsonBody: .object([
                    "dryRun": .bool(dryRun),
                    "force": .bool(force),
                    "reason": .string(dryRun ? "agentctl_memory_relief_dry_run" : "agentctl_memory_relief")
                ])
            )
        case .rssFeedList:
            return Endpoint(method: "GET", path: "/rss/feeds")
        case .rssFeedAdd(let name, let url, let enabled, let pollIntervalSec, let tags):
            return Endpoint(
                method: "POST",
                path: "/rss/feed/add",
                jsonBody: .object([
                    "name": .string(name),
                    "url": .string(url),
                    "enabled": .bool(enabled),
                    "pollIntervalSec": .number(Double(pollIntervalSec)),
                    "tags": .array(tags.map(JSONValue.string))
                ])
            )
        case .rssFeedUpdate(let id, let name, let url, let enabled, let pollIntervalSec, let tags):
            return Endpoint(
                method: "POST",
                path: "/rss/feed/update",
                jsonBody: .object([
                    "id": .string(id),
                    "name": .string(name),
                    "url": .string(url),
                    "enabled": .bool(enabled),
                    "pollIntervalSec": .number(Double(pollIntervalSec)),
                    "tags": .array(tags.map(JSONValue.string))
                ])
            )
        case .rssFeedRemove(let id):
            return Endpoint(
                method: "POST",
                path: "/rss/feed/remove",
                jsonBody: .object([
                    "id": .string(id)
                ])
            )
        case .newsList(let limit, let since):
            var path = "/news?limit=\(max(1, limit))"
            if let since {
                let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~:")
                let encoded = iso8601(since).addingPercentEncoding(withAllowedCharacters: allowed) ?? iso8601(since)
                path.append("&since=\(encoded)")
            }
            return Endpoint(method: "GET", path: path)
        case .signalList(let status, let limit):
            var path = "/signals?limit=\(max(1, limit))"
            if let status, !status.isEmpty {
                let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
                let encoded = status.addingPercentEncoding(withAllowedCharacters: allowed) ?? status
                path.append("&status=\(encoded)")
            }
            return Endpoint(method: "GET", path: path)
        case .signalGet(let id):
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
            let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
            return Endpoint(method: "GET", path: "/signal?id=\(encoded)")
        case .signalAck(let id):
            return Endpoint(
                method: "POST",
                path: "/signal/ack",
                jsonBody: .object(["id": .string(id)])
            )
        case .signalArchive(let id):
            return Endpoint(
                method: "POST",
                path: "/signal/archive",
                jsonBody: .object(["id": .string(id)])
            )
        case .replayIngest(let symbols, let timeframe, let start, let end, let feed):
            return Endpoint(
                method: "POST",
                path: "/replay/ingest",
                jsonBody: .object([
                    "symbols": .array(symbols.map(JSONValue.string)),
                    "timeframe": .string(timeframe.rawValue),
                    "start": .string(iso8601(start)),
                    "end": .string(iso8601(end)),
                    "feed": .string(feed.rawValue)
                ])
            )
        case .replayRun(let proposalID, let symbols, let timeframe, let start, let end, let speed, let autoIngest, let feed, let simulateTrades, let slippageBps):
            return Endpoint(
                method: "POST",
                path: "/replay/run",
                jsonBody: .object([
                    "proposalId": .string(proposalID),
                    "symbols": .array(symbols.map(JSONValue.string)),
                    "timeframe": .string(timeframe.rawValue),
                    "start": .string(iso8601(start)),
                    "end": .string(iso8601(end)),
                    "speed": .string(speed.rawValue),
                    "autoIngest": .bool(autoIngest),
                    "feed": .string(feed.rawValue),
                    "simulateTrades": .bool(simulateTrades),
                    "allowTradingInReplay": .bool(simulateTrades),
                    "fillPolicy": .string(ReplayFillPolicy.nextOpenMarket.rawValue),
                    "slippageBps": .object([
                        "market": .number(Double(slippageBps.market)),
                        "limit": .number(Double(slippageBps.limit))
                    ])
                ])
            )
        case .replayQuick(let proposalID, let symbols, let timeframe, let days, let end, let speed, let autoIngest, let feed, let simulateTrades, let slippageBps):
            var object: [String: JSONValue] = [
                "proposalId": .string(proposalID),
                "symbols": .array(symbols.map(JSONValue.string)),
                "timeframe": .string(timeframe.rawValue),
                "days": .number(Double(days)),
                "speed": .string(speed.rawValue),
                "autoIngest": .bool(autoIngest),
                "feed": .string(feed.rawValue),
                "simulateTrades": .bool(simulateTrades),
                "allowTradingInReplay": .bool(simulateTrades),
                "fillPolicy": .string(ReplayFillPolicy.nextOpenMarket.rawValue),
                "slippageBps": .object([
                    "market": .number(Double(slippageBps.market)),
                    "limit": .number(Double(slippageBps.limit))
                ])
            ]
            object["end"] = end.map { .string(iso8601($0)) } ?? .null
            return Endpoint(
                method: "POST",
                path: "/replay/quick",
                jsonBody: .object(object)
            )
        case .killSwitch(let enabled):
            return Endpoint(
                method: "POST",
                path: "/safety/kill-switch",
                jsonBody: .object([
                    "enabled": .bool(enabled)
                ])
            )
        case .armLive:
            return Endpoint(method: "POST", path: "/safety/arm-live", jsonBody: .object([:]))
        case .disarmLive:
            return Endpoint(method: "POST", path: "/safety/disarm-live", jsonBody: .object([:]))
        }
    }

    private static func executeRunExport(
        runID: String,
        outPath: String?,
        runtimeInfo: AgentControlRuntimeInfo
    ) async throws -> CLIResponse {
        let endpoint = try endpoint(for: .runExport(runID: runID, outPath: outPath))
        guard let url = URL(string: "http://\(runtimeInfo.host):\(runtimeInfo.port)\(endpoint.path)") else {
            throw CLIError(code: "invalid_ipc_url", message: "Invalid IPC endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.timeoutInterval = 10
        request.setValue(runtimeInfo.token, forHTTPHeaderField: "X-Agent-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = endpoint.body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CLIError(code: "ipc_unreachable", message: "Unable to reach IPC server")
        }

        guard let http = response as? HTTPURLResponse else {
            throw CLIError(code: "ipc_invalid_response", message: "IPC server returned non-HTTP response")
        }

        let envelope = try? JSONDecoder().decode(AgentControlEnvelope.self, from: data)
        let fallbackText = String(data: data, encoding: .utf8)
            ?? errorEnvelope(code: "invalid_response", message: "Non-UTF8 response body")
        guard http.statusCode >= 200,
              http.statusCode < 300,
              envelope?.ok == true
        else {
            return CLIResponse(httpStatus: http.statusCode, text: fallbackText, envelope: envelope)
        }

        guard let outPath else {
            return CLIResponse(httpStatus: http.statusCode, text: fallbackText, envelope: envelope)
        }

        guard let resultObject = envelope?.result?.objectValue,
              let json = resultObject["json"]?.stringValue
        else {
            throw CLIError(code: "run_export_invalid_payload", message: "IPC run export payload missing json field")
        }

        let outURL = URL(fileURLWithPath: outPath)
        do {
            try json.write(to: outURL, atomically: true, encoding: .utf8)
        } catch {
            throw CLIError(code: "run_export_write_failed", message: "Unable to write run JSON to \(outPath)")
        }

        let success = AgentControlEnvelope(
            ok: true,
            result: .object([
                "runId": .string(runID),
                "outPath": .string(outPath)
            ])
        )
        let successData = try JSONEncoder().encode(success)
        let successText = String(data: successData, encoding: .utf8) ?? fallbackText
        return CLIResponse(httpStatus: http.statusCode, text: successText, envelope: success)
    }

    private static func errorEnvelope(code: String, message: String) -> String {
        let envelope = AgentControlEnvelope(
            ok: false,
            error: AgentControlErrorBody(code: code, message: message)
        )
        guard let data = try? JSONEncoder().encode(envelope),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":{\"code\":\"encode_failed\",\"message\":\"\(message)\"}}"
        }
        return text
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func compactTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: date)
    }

    private static func resolveExercisePMProfile(
        requestedPMID: String?,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> PMProfile {
        let profiles: [PMProfile] = try await sendJSONValue(
            method: "GET",
            path: "/pm/profiles",
            body: nil,
            responseType: [PMProfile].self,
            send: send
        )

        if let requestedPMID {
            if let existing = profiles.first(where: { $0.pmId == requestedPMID }) {
                return existing
            }
            let created = PMProfile(
                pmId: requestedPMID,
                displayName: "Operational Exercise PM",
                roleSummary: "Bounded PM actor used to exercise the real app control plane and leave durable supervisory artifacts.",
                createdAt: timestamp,
                updatedAt: timestamp
            )
            return try await sendJSON(
                method: "POST",
                path: "/pm/profile/upsert",
                body: created,
                responseType: PMProfile.self,
                send: send
            )
        }

        if profiles.count == 1, let only = profiles.first {
            return only
        }

        if profiles.isEmpty {
            let created = PMProfile(
                pmId: "pm-operational-exercise",
                displayName: "Operational Exercise PM",
                roleSummary: "Bounded PM actor used to exercise the real app control plane and leave durable supervisory artifacts.",
                createdAt: timestamp,
                updatedAt: timestamp
            )
            return try await sendJSON(
                method: "POST",
                path: "/pm/profile/upsert",
                body: created,
                responseType: PMProfile.self,
                send: send
            )
        }

        throw CLIError(code: "usage", message: "pm exercise run requires --pm-id when multiple PM profiles exist")
    }

    private static func resolveExerciseAnalystCharter(
        requestedCharterID: String?,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> AnalystCharter {
        let charters: [AnalystCharter] = try await sendJSONValue(
            method: "GET",
            path: "/analyst/charters",
            body: nil,
            responseType: [AnalystCharter].self,
            send: send
        )

        let seed = AnalystCharterSeed()
        if let requestedCharterID {
            if let existing = charters.first(where: { $0.charterId == requestedCharterID }) {
                return existing
            }
            if charters.isEmpty, requestedCharterID == AnalystCharterSeed.charterId {
                return try await sendJSON(
                    method: "POST",
                    path: "/analyst/charter/upsert",
                    body: seed.makeInitialCharter(now: timestamp),
                    responseType: AnalystCharter.self,
                    send: send
                )
            }
            throw CLIError(code: "analyst_charter_not_found", message: "PM exercise charter not found: \(requestedCharterID)")
        }

        if charters.count == 1, let only = charters.first {
            return only
        }

        if charters.isEmpty {
            return try await sendJSON(
                method: "POST",
                path: "/analyst/charter/upsert",
                body: seed.makeInitialCharter(now: timestamp),
                responseType: AnalystCharter.self,
                send: send
            )
        }

        throw CLIError(code: "usage", message: "pm exercise run requires --charter-id when multiple analyst charters exist")
    }

    private struct ExerciseTaskResolution: Equatable {
        let task: AnalystTask
        let taskCreated: Bool
    }

    private struct PMExerciseQualityScenarioTemplate: Equatable {
        let label: String
        let taskTitle: String
        let taskDescription: String
        let tags: [String]
        let runtimeIdentifier: String
        let reasoningMode: AnalystRuntimeReasoningMode
        let draftSignal: Bool
        let draftProposal: Bool
    }

    private static func resolveExerciseTask(
        requestedTaskID: String?,
        charter: AnalystCharter,
        scenarioLabel: String?,
        titleOverride: String?,
        descriptionOverride: String?,
        tagsOverride: [String],
        suffix: String,
        timestamp: Date,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> ExerciseTaskResolution {
        if let requestedTaskID {
            let task: AnalystTask = try await sendJSONValue(
                method: "GET",
                path: "/analyst/task?id=\(percentEncode(requestedTaskID))",
                body: nil,
                responseType: AnalystTask.self,
                send: send
            )
            return ExerciseTaskResolution(task: task, taskCreated: false)
        }

        let task = AnalystTask(
            taskId: "exercise-task-\(suffix)",
            analystId: charter.analystId,
            charterId: charter.charterId,
            title: titleOverride ?? exerciseDisplayTitle(charter: charter, scenarioLabel: scenarioLabel),
            description: descriptionOverride ?? exerciseTaskDescription(
                charter: charter,
                scenarioLabel: scenarioLabel
            ),
            status: .queued,
            createdAt: timestamp,
            updatedAt: timestamp,
            tags: tagsOverride.isEmpty ? exerciseTaskTags(scenarioLabel: scenarioLabel) : tagsOverride
        )
        let persisted: AnalystTask = try await sendJSON(
            method: "POST",
            path: "/analyst/task/upsert",
            body: task,
            responseType: AnalystTask.self,
            send: send
        )
        return ExerciseTaskResolution(task: persisted, taskCreated: true)
    }

    private static func fetchExerciseMemoIfAvailable(
        memoID: String?,
        send: @escaping @Sendable (AgentCtlRequestSpec) async throws -> AgentControlEnvelope
    ) async throws -> AnalystMemo? {
        guard let memoID, !memoID.isEmpty else {
            return nil
        }
        return try await sendJSONValue(
            method: "GET",
            path: "/analyst/memo?id=\(percentEncode(memoID))",
            body: nil,
            responseType: AnalystMemo.self,
            send: send
        )
    }

    private static func makeExerciseRuntimePolicy(
        runtimeIdentifier: String?,
        reasoningMode: AnalystRuntimeReasoningMode?,
        timestamp: Date
    ) -> AnalystRuntimePolicy? {
        guard let runtimeIdentifier,
              !runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return AnalystRuntimePolicy(
            runtimeIdentifier: runtimeIdentifier,
            reasoningMode: reasoningMode,
            policySource: .pmDelegationOverride,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static func exerciseRequestedOutputs(
        draftSignal: Bool,
        draftProposal: Bool
    ) -> [PMDelegationRequestedOutput] {
        var outputs: [PMDelegationRequestedOutput] = [.finding, .checkpointUpdate]
        if draftSignal {
            outputs.append(.signal)
        }
        if draftProposal {
            outputs.append(.proposalDraft)
        }
        return outputs
    }

    private static func exerciseDisplayTitle(
        charter: AnalystCharter,
        scenarioLabel: String?
    ) -> String {
        if let scenarioLabel, !scenarioLabel.isEmpty {
            return "PM Exercise [\(scenarioLabel)]: \(charter.title)"
        }
        return "PM Exercise: \(charter.title)"
    }

    private static func exerciseTaskDescription(
        charter: AnalystCharter,
        scenarioLabel: String?
    ) -> String {
        if let scenarioLabel, !scenarioLabel.isEmpty {
            return "Bounded PM-authored analyst scenario \"\(scenarioLabel)\" created through the authenticated control plane for \(charter.title)."
        }
        return "Bounded PM/Analyst operational exercise task created through the authenticated control plane."
    }

    private static func exerciseTaskTags(scenarioLabel: String?) -> [String] {
        var tags = ["pm-exercise", "operator-exercise"]
        if let scenarioLabel, !scenarioLabel.isEmpty {
            let normalized = scenarioLabel
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            tags.append("scenario-\(normalized)")
        }
        return tags
    }

    private static func qualitySuiteScenarioTemplates() -> [PMExerciseQualityScenarioTemplate] {
        [
            PMExerciseQualityScenarioTemplate(
                label: "Synthesis A — Deep",
                taskTitle: "Synthesis Task: technology adoption watch memo",
                taskDescription: "Synthesize the current app-owned and policy-governed external evidence into a readable watch memo for the PM. Focus on what changed, what still matters, and what remains unresolved.",
                tags: ["pm-exercise", "quality-suite", "task-synthesis", "comparison-pair"],
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                draftSignal: false,
                draftProposal: false
            ),
            PMExerciseQualityScenarioTemplate(
                label: "Synthesis B — Concise",
                taskTitle: "Synthesis Task: technology adoption watch memo",
                taskDescription: "Synthesize the current app-owned and policy-governed external evidence into a readable watch memo for the PM. Focus on what changed, what still matters, and what remains unresolved.",
                tags: ["pm-exercise", "quality-suite", "task-synthesis", "comparison-pair"],
                runtimeIdentifier: "gpt-4.1-mini",
                reasoningMode: .standard,
                draftSignal: false,
                draftProposal: false
            ),
            PMExerciseQualityScenarioTemplate(
                label: "Recommendation — PM escalation check",
                taskTitle: "Recommendation Task: should the PM escalate this thesis now?",
                taskDescription: "Use the current evidence to make a bounded PM-oriented recommendation: keep monitoring, wait for more evidence, or prepare a PM-layer review request. Explain why that recommendation is warranted.",
                tags: ["pm-exercise", "quality-suite", "task-recommendation"],
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                draftSignal: false,
                draftProposal: false
            ),
            PMExerciseQualityScenarioTemplate(
                label: "Action Review — Owner readiness",
                taskTitle: "Action-adjacent review task: owner review readiness",
                taskDescription: "Assess whether the current evidence is strong enough for a PM-layer owner review request. Make clear what is ready for owner review and what is still too weak or too uncertain for escalation.",
                tags: ["pm-exercise", "quality-suite", "task-action-adjacent"],
                runtimeIdentifier: "gpt-4.1-mini",
                reasoningMode: .standard,
                draftSignal: false,
                draftProposal: false
            )
        ]
    }

    private static func exerciseDelegationRationale(
        charter: AnalystCharter,
        scenarioLabel: String?,
        runtimePolicy: AnalystRuntimePolicy?
    ) -> String {
        var parts: [String] = []
        if let scenarioLabel, !scenarioLabel.isEmpty {
            parts.append("Bounded PM-authored analyst scenario \"\(scenarioLabel)\" for \(charter.title).")
        } else {
            parts.append("Bounded PM/Analyst operational exercise through the authenticated control plane for command-center observability validation.")
        }
        if let runtimePolicy {
            let reasoning = runtimePolicy.reasoningMode?.rawValue ?? "standard"
            parts.append("Requested runtime profile: \(runtimePolicy.runtimeIdentifier) with \(reasoning) reasoning.")
        }
        return parts.joined(separator: " ")
    }

    private static func exerciseDecisionTitle(
        charter: AnalystCharter,
        launchResult: AnalystWorkerLaunchResult,
        memo: AnalystMemo?,
        scenarioLabel: String?
    ) -> String {
        let prefix: String
        if let scenarioLabel, !scenarioLabel.isEmpty {
            prefix = "PM Scenario [\(scenarioLabel)]"
        } else {
            prefix = "PM Exercise"
        }
        if let memo, !memo.title.isEmpty {
            return "\(prefix): \(memo.title)"
        }
        if launchResult.draftedProposalId != nil {
            return "\(prefix): Review proposal draft from \(charter.title)"
        }
        if launchResult.draftedSignalId != nil {
            return "\(prefix): Review signal from \(charter.title)"
        }
        return "\(prefix): Review finding from \(charter.title)"
    }

    private static func exerciseDecisionSummary(
        charter: AnalystCharter,
        launchResult: AnalystWorkerLaunchResult,
        memo: AnalystMemo?,
        scenarioLabel: String?
    ) -> String {
        if let memo {
            var parts: [String] = []
            if let scenarioLabel, !scenarioLabel.isEmpty {
                parts.append("Scenario: \(scenarioLabel).")
            }
            parts.append("PM takeaway: \(leadingSentence(in: memo.currentView))")
            parts.append("Recommended next step: \(leadingSentence(in: memo.recommendedNextStep))")
            if let supportingRead = compactSupportingRead(from: memo) {
                parts.append("Analyst support: \(supportingRead)")
            }
            if let evidenceCaveat = compactEvidenceCaveat(from: launchResult) {
                parts.append(evidenceCaveat)
            }
            if launchResult.draftedProposalId != nil {
                parts.append("A separate proposal draft exists for bounded human review; proposal approval semantics remain separate.")
            } else if launchResult.draftedSignalId != nil {
                parts.append("A separate signal draft exists; downstream proposal and trading review still require separate gates.")
            }
            return parts.joined(separator: " ")
        }

        var parts: [String] = []
        if let scenarioLabel, !scenarioLabel.isEmpty {
            parts.append("Delegated \(charter.title) through the authenticated control plane for the PM-authored scenario \"\(scenarioLabel)\".")
        } else {
            parts.append("Delegated \(charter.title) through the authenticated control plane.")
        }
        if let findingTitle = launchResult.findingTitle, !findingTitle.isEmpty {
            parts.append("Finding: \(findingTitle).")
        }
        if let memoTitle = launchResult.memoTitle, !memoTitle.isEmpty {
            parts.append("Readable memo: \(memoTitle).")
        }
        if let externalEvidenceStatus = launchResult.externalEvidenceStatus,
           externalEvidenceStatus != "ok" {
            let issueSummary = launchResult.externalEvidenceIssueSummary ?? externalEvidenceStatus
            parts.append("External evidence was degraded: \(issueSummary).")
        }
        if launchResult.draftedProposalId != nil {
            parts.append("A proposal draft now exists for bounded human review.")
        } else if launchResult.draftedSignalId != nil {
            parts.append("A signal draft now exists; proposal approval semantics remain unchanged.")
        } else {
            parts.append("No downstream signal or proposal draft was requested or produced.")
        }
        return parts.joined(separator: " ")
    }

    private static func exerciseApprovalSubject(
        charter: AnalystCharter,
        launchResult: AnalystWorkerLaunchResult,
        memo: AnalystMemo?,
        scenarioLabel: String?
    ) -> String {
        if let memo, !memo.title.isEmpty {
            return "Review PM recommendation based on analyst memo: \(memo.title)"
        }
        let prefix: String
        if let scenarioLabel, !scenarioLabel.isEmpty {
            prefix = "Review PM analyst scenario \"\(scenarioLabel)\""
        } else {
            prefix = "Review PM exercise"
        }
        if launchResult.draftedProposalId != nil {
            return "\(prefix) proposal draft from \(charter.title)"
        }
        if launchResult.draftedSignalId != nil {
            return "\(prefix) signal outcome from \(charter.title)"
        }
        return "\(prefix) analyst output from \(charter.title)"
    }

    private static func exerciseApprovalRationale(
        launchResult: AnalystWorkerLaunchResult,
        memo: AnalystMemo?,
        scenarioLabel: String?
    ) -> String {
        var parts: [String] = []
        if let scenarioLabel, !scenarioLabel.isEmpty {
            parts.append("This PM-layer review request comes from the analyst scenario \"\(scenarioLabel)\".")
        }
        if let memo {
            parts.append("Current view: \(leadingSentence(in: memo.currentView))")
            parts.append("Requested review: \(leadingSentence(in: memo.recommendedNextStep))")
            if let supportingRead = compactSupportingRead(from: memo) {
                parts.append("Analyst support: \(supportingRead)")
            }
        }
        parts.append("This is a bounded PM-layer request for human review and does not approve trading, proposals, or safety-state changes.")
        if let evidenceCaveat = compactEvidenceCaveat(from: launchResult) {
            parts.append(evidenceCaveat.replacingOccurrences(of: "Evidence caveat:", with: "Evidence caveat for this review:"))
        }
        return parts.joined(separator: " ")
    }

    private static func leadingSentence(in text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let range = trimmed.range(of: ". ") {
            return String(trimmed[..<range.lowerBound]) + "."
        }
        if trimmed.hasSuffix(".") {
            return trimmed
        }
        return trimmed + "."
    }

    private static func compactSupportingRead(from memo: AnalystMemo) -> String? {
        let executive = leadingSentence(in: memo.executiveSummary)
        let currentView = leadingSentence(in: memo.currentView)
        guard !executive.isEmpty, executive != currentView else {
            return nil
        }
        return executive
    }

    private static func compactEvidenceCaveat(from launchResult: AnalystWorkerLaunchResult) -> String? {
        guard let externalEvidenceStatus = launchResult.externalEvidenceStatus,
              externalEvidenceStatus != "ok" else {
            return nil
        }
        let issueSummary = launchResult.externalEvidenceIssueSummary ?? externalEvidenceStatus
        return "Evidence caveat: \(issueSummary)."
    }

    private static func jsonValue<T: Encodable>(from value: T) throws -> JSONValue {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601(date))
        }
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private static func decodeJSONValue<T: Decodable>(_ value: JSONValue, as type: T.Type) throws -> T {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let parsed = parseDate(string) {
                return parsed
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(string)")
        }
        return try decoder.decode(type, from: data)
    }

    private static func percentEncode(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
    }

    private static func usage() -> String {
        "Usage: alpaca_agentctl status | strategy list | strategy start <id> --params '<json>' | strategy start --proposal <id> | strategy stop <id> | analyst charter list | analyst charter get <id> | analyst charter upsert --file <path> | analyst task list | analyst task get <id> | analyst task upsert --file <path> | analyst memo list | analyst memo get <id> | analyst memo upsert --file <path> | analyst finding list | analyst finding get <id> | analyst finding upsert --file <path> | analyst finding draft-signal --id <finding-id> | analyst signal draft-proposal --id <signal-id> [--strategy <strategy-id>] | analyst evidence-bundle upsert --file <path> | analyst news list [--limit 50] [--since <ISO8601>] | pm profile list | pm profile get <id> | pm profile upsert --file <path> | pm mandate list | pm mandate get <id> | pm mandate upsert --file <path> | pm instruction list | pm instruction get <id> | pm instruction upsert --file <path> | pm notebook-entry list | pm notebook-entry get <id> | pm notebook-entry upsert --file <path> | pm portfolio-strategy-brief get | pm portfolio-strategy-brief upsert --file <path> | pm recent-news-analyst-runtime get | pm recent-news-analyst-runtime upsert --file <path> | pm standing-bench-analyst-runtime get | pm standing-bench-analyst-runtime upsert --file <path> | pm decision list | pm decision get <id> | pm decision upsert --file <path> | pm approval-request list | pm approval-request get <id> | pm approval-request upsert --file <path> | pm communication-session list | pm communication-session get <id> | pm communication-session upsert --file <path> | pm communication-message list | pm communication-message get <id> | pm communication-message upsert --file <path> | pm delegation list | pm delegation get <id> | pm delegation upsert --file <path> | pm delegation launch --id <id> [--draft-signal] [--draft-proposal] | pm exercise run [--pm-id <id>] [--charter-id <id>] [--task-id <id>] [--scenario-label <label>] [--runtime-id <id>] [--reasoning-mode standard|deliberate] [--draft-signal] [--draft-proposal] | pm exercise quality-suite [--pm-id <id>] [--charter-id <id>] | pm exercise workflow-suite [--pm-id <id>] [--charter-id <id>] | pm exercise canonical-suite [--pm-id <id>] [--charter-id <id>] | proposal list | proposal get <id> | proposal upsert --file <path> | proposal submit <id> | proposal approve-paper <id> --notes \"...\" | proposal deny-paper <id> --notes \"...\" | run list --proposal <proposalId> | run get <runId> | run export <runId> [--out <path>] | job list | job get <id> | job submit --type <monitor|replay_batch|rss_poll|news_retention|analyst_signals|recent_news_analyst|maintenance_retention> --params '<json>' | job cancel <id> | schedule list | schedule get <id> | schedule upsert --json '<object>' | schedule enable <id> true|false | schedule run-now <id> | schedule remove <id> | retention get | retention set --json '<object>' | maintenance run --dry-run|--apply | maintenance jobs-prune --before <ISO8601> [--dry-run|--apply] | maintenance memory-relief [--dry-run|--force] | rss feed list | rss feed add --name <name> --url <url> [--interval 300] [--enabled true|false] [--tags a,b] | rss feed update --id <id> --name <name> --url <url> [--interval 300] [--enabled true|false] [--tags a,b] | rss feed remove <id> | news list [--limit 50] [--since <ISO8601>] | signal list [--status new|acknowledged|archived] [--limit 100] | signal get <id> | signal ack <id> | signal archive <id> | replay ingest --symbols AAPL,MSFT --timeframe 1Min --from 2026-02-01 --to 2026-02-05 [--feed iex|sip|test] | replay run --proposal <id> --symbols AAPL --timeframe 1Min --from 2026-02-01 --to 2026-02-05 --speed fast [--auto-ingest] [--simulate-trades] [--slippage-bps-market 0] [--slippage-bps-limit 0] [--feed iex|sip|test] | replay quick --proposal <id> --symbols AAPL,MSFT --days 5 --timeframe 1Min --speed fast [--auto-ingest] [--simulate-trades] [--slippage-bps-market 0] [--slippage-bps-limit 0] [--feed iex|sip|test] [--end 2026-02-28] | kill-switch on|off | arm-live | disarm-live"
    }
}

private struct CLIResponse {
    let httpStatus: Int
    let text: String
    let envelope: AgentControlEnvelope?
}

struct PMOperationalExerciseOptions: Equatable {
    let pmId: String?
    let charterId: String?
    let taskId: String?
    let scenarioLabel: String?
    let taskTitleOverride: String?
    let taskDescriptionOverride: String?
    let taskTagsOverride: [String]
    let runtimeIdentifier: String?
    let reasoningMode: AnalystRuntimeReasoningMode?
    let draftSignal: Bool
    let draftProposal: Bool
}

struct PMOperationalExerciseQualitySuiteOptions: Equatable {
    let pmId: String?
    let charterId: String?
}

struct PMOperationalWorkflowSuiteOptions: Equatable {
    let pmId: String?
    let charterId: String?
}

struct PMCanonicalOperatingSuiteOptions: Equatable {
    let pmId: String?
    let charterId: String?
}

struct PMOperationalExerciseResult: Codable, Equatable {
    let pmId: String
    let charterId: String
    let taskId: String
    let taskCreated: Bool
    let delegationId: String
    let decisionId: String
    let approvalRequestId: String
    let scenarioLabel: String?
    let findingId: String?
    let memoId: String?
    let memoTitle: String?
    let draftedSignalId: String?
    let draftedProposalId: String?
    let intendedRuntimeIdentifier: String?
    let intendedReasoningMode: String?
    let actualRuntimeIdentifier: String?
    let actualReasoningMode: String?
    let externalEvidenceStatus: String?
    let externalEvidenceIssueSummary: String?
    let summary: String
}

struct PMOperationalExerciseQualitySuiteResult: Codable, Equatable {
    let suiteLabel: String
    let comparedTaskType: String
    let scenarioResults: [PMOperationalExerciseResult]
    let observations: [String]
}

enum PMOperationalExerciseContextMode: String, Codable, Equatable {
    case portfolioBacked = "portfolio_backed"
    case seeded = "seeded"
}

struct PMOperationalWorkflowScenarioResult: Codable, Equatable {
    let scenarioID: String
    let scenarioLabel: String
    let contextMode: PMOperationalExerciseContextMode
    let symbol: String
    let initiativePosture: PMInitiativePosture
    let actionabilityCategory: PMEventActionabilityCategory
    let closureStatus: PMRecommendationClosureStatus
    let initiativeReason: String
    let communicationChannel: PMCommunicationChannel?
    let usedTelegramRemotePath: Bool
    let communicationSessionId: String?
    let inboundMessageId: String?
    let outboundMessageId: String?
    let clarificationMessageId: String?
    let delegationId: String?
    let followUpDelegationId: String?
    let followUpActionId: String?
    let memoId: String?
    let decisionId: String?
    let approvalRequestId: String?
    let proposalId: String?
    let proposalSeeded: Bool?
    let strategyBriefId: String?
    let strategyBriefChanged: Bool
    let ownerResponse: PMApprovalRequestOwnerResponse?
    let readinessStatus: PMExecutionRoutingStatus?
    let routeStatus: PMExecutionRoutingStatus?
    let executionPathReached: Bool
    let summary: String
}

struct PMOperationalWorkflowSuiteResult: Codable, Equatable {
    let suiteLabel: String
    let contextMode: PMOperationalExerciseContextMode
    let watchlistSymbolsUsed: [String]
    let seededSymbols: [String]
    let scenarioResults: [PMOperationalWorkflowScenarioResult]
    let observations: [String]
}

enum PMCanonicalOperatingScenarioKind: String, Codable, Equatable {
    case backgroundHandling = "background_handling"
    case decisionRequired = "decision_required"
    case moreWorkReroute = "more_work_reroute"
    case telegramContinuation = "telegram_continuation"
    case runtimeDegradedFallback = "runtime_degraded_fallback"
}

struct PMCanonicalOperatingScenarioResult: Codable, Equatable {
    let scenarioID: String
    let scenarioLabel: String
    let scenarioKind: PMCanonicalOperatingScenarioKind
    let contextMode: PMOperationalExerciseContextMode
    let symbol: String?
    let initiativePosture: PMInitiativePosture?
    let actionabilityCategory: PMEventActionabilityCategory?
    let closureStatus: PMRecommendationClosureStatus?
    let initialDeskReadinessState: CommandCenterDeskReadinessState?
    let finalDeskReadinessState: CommandCenterDeskReadinessState
    let ownerActionWasRequested: Bool
    let ownerActionStillPending: Bool
    let crossSurfaceMeaningAligned: Bool
    let telegramContinuationUsed: Bool
    let pmRuntimeOperabilityState: RuntimeOperabilityState?
    let recentNewsRuntimeOperabilityState: RuntimeOperabilityState?
    let degradedModeActive: Bool
    let fallbackActive: Bool
    let communicationSessionId: String?
    let decisionId: String?
    let approvalRequestId: String?
    let delegationId: String?
    let followUpDelegationId: String?
    let ownerResponse: PMApprovalRequestOwnerResponse?
    let summary: String
}

struct PMCanonicalOperatingSuiteResult: Codable, Equatable {
    let suiteLabel: String
    let contextMode: PMOperationalExerciseContextMode
    let watchlistSymbolsUsed: [String]
    let seededSymbols: [String]
    let scenarioResults: [PMCanonicalOperatingScenarioResult]
    let observations: [String]
}

struct AgentCtlRequestSpec: Equatable {
    let method: String
    let path: String
    let jsonBody: JSONValue?
}

struct Endpoint {
    let method: String
    let path: String
    let body: Data?
    let contentType: String?

    init(
        method: String,
        path: String,
        jsonBody: JSONValue? = nil
    ) {
        self.method = method
        self.path = path
        if let jsonBody {
            self.body = try? JSONEncoder().encode(jsonBody)
            self.contentType = "application/json"
        } else {
            self.body = nil
            self.contentType = nil
        }
    }

    init(
        method: String,
        path: String,
        rawBody: Data,
        contentType: String
    ) {
        self.method = method
        self.path = path
        self.body = rawBody
        self.contentType = contentType
    }
}

enum CLICommand {
    case status
    case strategyList
    case strategyStart(id: String, params: [String: JSONValue])
    case strategyStartFromProposal(proposalID: String)
    case strategyStop(id: String)
    case analystCharterList
    case analystCharterGet(id: String)
    case analystCharterUpsert(filePath: String)
    case analystTaskList
    case analystTaskGet(id: String)
    case analystTaskUpsert(filePath: String)
    case analystMemoList
    case analystMemoGet(id: String)
    case analystMemoUpsert(filePath: String)
    case analystFindingList
    case analystFindingGet(id: String)
    case analystFindingUpsert(filePath: String)
    case analystFindingDraftSignal(id: String)
    case analystSignalDraftProposal(id: String, strategyID: String?)
    case analystEvidenceBundleUpsert(filePath: String)
    case analystNewsList(limit: Int, since: Date?)
    case pmProfileList
    case pmProfileGet(id: String)
    case pmProfileUpsert(filePath: String)
    case pmMandateList
    case pmMandateGet(id: String)
    case pmMandateUpsert(filePath: String)
    case pmInstructionList
    case pmInstructionGet(id: String)
    case pmInstructionUpsert(filePath: String)
    case pmNotebookEntryList
    case pmNotebookEntryGet(id: String)
    case pmNotebookEntryUpsert(filePath: String)
    case portfolioStrategyBriefGet
    case portfolioStrategyBriefUpsert(filePath: String)
    case recentNewsAnalystRuntimeSettingsGet
    case recentNewsAnalystRuntimeSettingsUpsert(filePath: String)
    case standingBenchAnalystRuntimeSettingsGet
    case standingBenchAnalystRuntimeSettingsUpsert(filePath: String)
    case pmDecisionList
    case pmDecisionGet(id: String)
    case pmDecisionUpsert(filePath: String)
    case pmApprovalRequestList
    case pmApprovalRequestGet(id: String)
    case pmApprovalRequestUpsert(filePath: String)
    case pmCommunicationSessionList
    case pmCommunicationSessionGet(id: String)
    case pmCommunicationSessionUpsert(filePath: String)
    case pmCommunicationMessageList
    case pmCommunicationMessageGet(id: String)
    case pmCommunicationMessageUpsert(filePath: String)
    case pmDelegationList
    case pmDelegationGet(id: String)
    case pmDelegationUpsert(filePath: String)
    case pmDelegationLaunch(id: String, draftSignal: Bool, draftProposal: Bool)
    case pmExerciseRun(options: PMOperationalExerciseOptions)
    case pmExerciseQualitySuite(options: PMOperationalExerciseQualitySuiteOptions)
    case pmExerciseWorkflowSuite(options: PMOperationalWorkflowSuiteOptions)
    case pmExerciseCanonicalSuite(options: PMCanonicalOperatingSuiteOptions)
    case proposalList
    case proposalGet(id: String)
    case proposalUpsert(filePath: String)
    case proposalSubmit(id: String)
    case proposalApprovePaper(id: String, notes: String)
    case proposalDenyPaper(id: String, notes: String)
    case runList(proposalID: String)
    case runGet(runID: String)
    case runExport(runID: String, outPath: String?)
    case jobList
    case jobGet(id: String)
    case jobSubmit(type: JobType, params: [String: JSONValue])
    case jobCancel(id: String)
    case scheduleList
    case scheduleGet(id: String)
    case scheduleUpsert(payload: [String: JSONValue])
    case scheduleEnable(id: String, enabled: Bool)
    case scheduleRunNow(id: String)
    case scheduleRemove(id: String)
    case retentionGet
    case retentionSet(payload: [String: JSONValue])
    case maintenanceRun(dryRun: Bool)
    case maintenanceJobsPrune(cutoff: Date, dryRun: Bool)
    case maintenanceMemoryRelief(dryRun: Bool, force: Bool)
    case rssFeedList
    case rssFeedAdd(name: String, url: String, enabled: Bool, pollIntervalSec: Int, tags: [String])
    case rssFeedUpdate(id: String, name: String, url: String, enabled: Bool, pollIntervalSec: Int, tags: [String])
    case rssFeedRemove(id: String)
    case newsList(limit: Int, since: Date?)
    case signalList(status: String?, limit: Int)
    case signalGet(id: String)
    case signalAck(id: String)
    case signalArchive(id: String)
    case replayIngest(symbols: [String], timeframe: BarTimeframe, start: Date, end: Date, feed: ReplayFeed)
    case replayRun(proposalID: String, symbols: [String], timeframe: BarTimeframe, start: Date, end: Date, speed: ReplaySpeed, autoIngest: Bool, feed: ReplayFeed, simulateTrades: Bool, slippageBps: ReplaySlippageBps)
    case replayQuick(proposalID: String, symbols: [String], timeframe: BarTimeframe, days: Int, end: Date?, speed: ReplaySpeed, autoIngest: Bool, feed: ReplayFeed, simulateTrades: Bool, slippageBps: ReplaySlippageBps)
    case killSwitch(Bool)
    case armLive
    case disarmLive
}

struct CLIError: Error {
    let code: String
    let message: String
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
