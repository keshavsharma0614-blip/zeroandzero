import Foundation
import TradingKit

private struct Options {
    var pmId = "pm-default"
    var reply: String?
    var approvalRequestId: String?
    var createSmokeApprovalAsk = false
    var decisionId: String?
    var delivery = TelegramPMWakeUpClass.conversationReply
    var sessionId: String?
    var waitForBindSec: Int = 20
}

@main
struct TelegramBridgeSmokeMain {
    static func main() async {
        let code = await run()
        Foundation.exit(code)
    }

    private static func run() async -> Int32 {
        do {
            let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))

            let tokenProvider = TelegramBotKeychainStatusProvider()
            guard tokenProvider.isConfigured() else {
                fputs("Missing Telegram bot token in Keychain for service=telegram.api.key account=algo-trading.\n", stderr)
                return 2
            }

            let engine = Engine()
            let result = try await pollUntilBound(engine: engine, options: options)
            print("telegram_poll fetched=\(result.fetchedUpdateCount) ingested=\(result.ingestedMessageCount) duplicates=\(result.duplicateUpdateCount) skipped=\(result.skippedUnsupportedCount) approvals=\(result.approvalResponseCount) replies=\(result.clarificationReplyCount)")
            if let chatId = result.boundChatId, let sessionId = result.boundSessionId {
                print("bound_chat chat_id=\(chatId) session_id=\(sessionId)")
            }

            let status = await engine.telegramBridgeStatus()
            if let chatId = status.allowlistedOwnerChatId {
                if let participant = status.allowlistedOwnerParticipantLabel,
                   participant.isEmpty == false {
                    print("allowlisted_owner_route participant=\(participant) chat_id=\(chatId)")
                } else {
                    print("allowlisted_owner_route chat_id=\(chatId)")
                }
            } else {
                print("allowlisted_owner_route none")
            }
            if let chatId = status.lastBoundChatId, let sessionId = status.lastBoundSessionId {
                print("status_bound_chat chat_id=\(chatId) session_id=\(sessionId)")
            } else {
                print("status_bound_chat none")
            }
            if let summary = status.lastPollSummary, summary.isEmpty == false {
                print("last_poll_summary \(summary)")
            }
            print("status_webhook present=\(status.lastWebhookPresent) pending=\(status.lastWebhookPendingUpdateCount.map(String.init) ?? "nil")")
            print("status_offset requested=\(status.lastRequestedOffset.map(String.init) ?? "nil") highest=\(status.lastHighestFetchedUpdateId.map(String.init) ?? "nil") recovery=\(status.lastRecoveryTriggered) recovery_offset=\(status.lastRecoveryOffset.map(String.init) ?? "nil")")
            print("status_unauthorized ignored=\(status.unauthorizedInboundCount) last_chat=\(status.lastUnauthorizedChatId ?? "nil")")
            let sessions = try await engine.listPMCommunicationSessions()
            let targetSessionId = options.sessionId
                ?? result.boundSessionId
                ?? status.lastBoundSessionId
                ?? sessions.first(where: { $0.channel == .telegram })?.sessionId

            let approvalRequestId = try await resolvedApprovalRequestId(engine: engine, options: options)
            if let approvalRequestId {
                guard let targetSessionId else {
                    fputs("No Telegram session is currently bound. Poll inbound updates first.\n", stderr)
                    return 3
                }
                fputs("telegram_bridge_smoke: sending explicit approval ask...\n", stderr)
                _ = try await engine.sendTelegramApprovalRequestPrompt(
                    approvalRequestId: approvalRequestId,
                    sessionId: targetSessionId,
                    source: .system
                )
                print("telegram_send mode=approval_request session_id=\(targetSessionId) approval_request_id=\(approvalRequestId)")
            } else if let decisionId = options.decisionId {
                guard let targetSessionId else {
                    fputs("No Telegram session is currently bound. Poll inbound updates first.\n", stderr)
                    return 3
                }
                fputs("telegram_bridge_smoke: sending decision wake-up...\n", stderr)
                _ = try await engine.sendTelegramDecisionPrompt(
                    decisionId: decisionId,
                    sessionId: targetSessionId,
                    wakeUpClass: options.delivery,
                    source: .system
                )
                print("telegram_send mode=decision session_id=\(targetSessionId) delivery=\(options.delivery.rawValue)")
            } else if let reply = options.reply?.trimmingCharacters(in: .whitespacesAndNewlines), reply.isEmpty == false {
                guard let targetSessionId else {
                    fputs("No Telegram session is currently bound. Poll inbound updates first.\n", stderr)
                    return 3
                }
                fputs("telegram_bridge_smoke: sending bounded reply...\n", stderr)
                let delivery: TelegramPMDeliveryBehavior
                switch options.delivery {
                case .approvalRequired:
                    delivery = .approvalRequired(reason: "Smoke validation explicit approval wake-up.")
                case .importantWakeUp:
                    delivery = .importantWakeUp(reason: "Smoke validation important wake-up.")
                case .quietInfo:
                    delivery = .quietInfo(reason: "Smoke validation quiet informational send.")
                case .conversationReply:
                    delivery = .conversationReply
                case .doNotSendProactively:
                    delivery = .doNotSendProactively(reason: "Smoke validation passive send suppression.")
                }
                _ = try await engine.createPMCommunicationMessage(
                    sessionId: targetSessionId,
                    senderRole: .pm,
                    senderId: options.pmId,
                    body: reply,
                    telegramDelivery: delivery,
                    source: .system
                )
                print("telegram_send mode=reply session_id=\(targetSessionId) delivery=\(options.delivery.rawValue)")
            }

            if let outbound = status.lastOutboundSummary, outbound.isEmpty == false {
                print("last_outbound \(outbound)")
            }
            return 0
        } catch SmokeError.help {
            return 0
        } catch {
            fputs("telegram_bridge_smoke failed: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func parseOptions(arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--help", "-h":
                printUsage()
                throw SmokeError.help
            case "--pm-id":
                options.pmId = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--reply":
                options.reply = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--approval-request":
                options.approvalRequestId = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--smoke-approval-ask":
                options.createSmokeApprovalAsk = true
            case "--decision":
                options.decisionId = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--delivery":
                let rawValue = try nextValue(for: arg, arguments: arguments, index: &index)
                guard let delivery = TelegramPMWakeUpClass(rawValue: rawValue) else {
                    throw SmokeError.invalidArguments("Invalid delivery for --delivery: \(rawValue)")
                }
                options.delivery = delivery
            case "--session-id":
                options.sessionId = try nextValue(for: arg, arguments: arguments, index: &index)
            case "--wait-for-bind-sec":
                let rawValue = try nextValue(for: arg, arguments: arguments, index: &index)
                guard let value = Int(rawValue), value >= 0 else {
                    throw SmokeError.invalidArguments("Invalid integer for --wait-for-bind-sec: \(rawValue)")
                }
                options.waitForBindSec = value
            default:
                throw SmokeError.invalidArguments("Unknown argument: \(arg)")
            }
        }

        let activeModes = [options.reply != nil, options.approvalRequestId != nil || options.createSmokeApprovalAsk, options.decisionId != nil]
            .filter { $0 }
            .count
        if activeModes > 1 {
            throw SmokeError.invalidArguments("Use only one of --reply, --approval-request/--smoke-approval-ask, or --decision.")
        }

        return options
    }

    private static func nextValue(
        for flag: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw SmokeError.invalidArguments("Missing value for \(flag)")
        }
        let value = arguments[valueIndex]
        index = valueIndex + 1
        return value
    }

    private static func printUsage() {
        print("""
        Usage: swift run telegram_bridge_smoke [--pm-id <id>] [--session-id <session-id>] [--wait-for-bind-sec <seconds>] [--reply \"...\"] [--approval-request <approval-request-id> | --smoke-approval-ask] [--decision <decision-id>] [--delivery <conversation_reply|important_wake_up|quiet_info>]
        - Always polls Telegram updates first and will retry for a bounded interval while no Telegram route is bound.
        - Optionally sends one concise outbound PM reply, one decision wake-up, or one explicit approval ask over the bound Telegram chat.
        """)
    }

    private static func pollUntilBound(
        engine: Engine,
        options: Options
    ) async throws -> TelegramBridgePollResult {
        let startedAt = Date()
        var attempt = 0

        while true {
            attempt += 1
            fputs("telegram_bridge_smoke: polling Telegram updates (attempt \(attempt))...\n", stderr)
            let result = try await engine.pollTelegramUpdates(pmId: options.pmId, source: .system)
            if result.boundChatId != nil && result.boundSessionId != nil {
                return result
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            guard Int(elapsed.rounded(.down)) < options.waitForBindSec else {
                return result
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    private static func resolvedApprovalRequestId(
        engine: Engine,
        options: Options
    ) async throws -> String? {
        if let existing = options.approvalRequestId {
            return existing
        }
        return try await createSmokeApprovalRequestIfNeeded(engine: engine, options: options)
    }

    private static func createSmokeApprovalRequestIfNeeded(
        engine: Engine,
        options: Options
    ) async throws -> String? {
        guard options.createSmokeApprovalAsk else {
            return nil
        }

        let now = Date()
        let identifier = "telegram-smoke-approval-\(Int(now.timeIntervalSince1970))"
        let request = PMApprovalRequest(
            approvalRequestId: identifier,
            pmId: options.pmId,
            subject: "Telegram smoke approval ask",
            rationale: "Bounded remote wake-up validation only. This records PM communication flow and does not change proposal, trading, or safety authority.",
            requestedActionSummary: "Decide whether I should advance this smoke validation review.",
            approvedNextStepSummary: "I will treat this as a bounded remote-validation approval and keep proposal, trading, and safety gates separate.",
            rejectedNextStepSummary: "I will leave the smoke validation ask declined and take no further action.",
            reviewedNextStepSummary: "I will treat More Work as a request for additional validation without changing authority.",
            requestType: .other,
            status: .pending,
            createdAt: now,
            updatedAt: now
        )
        _ = try await engine.upsertPMApprovalRequest(request, source: .system)
        print("telegram_smoke_created_approval_request id=\(identifier)")
        return identifier
    }
}

private enum SmokeError: Error {
    case help
    case invalidArguments(String)
}

extension SmokeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .help:
            return nil
        case .invalidArguments(let message):
            return message
        }
    }
}
