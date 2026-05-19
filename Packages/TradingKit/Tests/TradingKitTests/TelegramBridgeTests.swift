import Foundation
import Testing
@testable import TradingKit

@Test("Telegram token lookup and request building stay bounded and non-sensitive")
func telegramTokenLookupAndRequestBuildingStayBounded() throws {
    let keychainProvider = KeychainCredentialsProvider(
        keyReader: StubKeyReader(
            values: [
                "\(TelegramBotKeychainStatusProvider.service)|\(TelegramBotKeychainStatusProvider.account)": "TEST_BOT_TOKEN_PLACEHOLDER"
            ]
        )
    )
    let statusProvider = TelegramBotKeychainStatusProvider(keychainProvider: keychainProvider)

    #expect(statusProvider.isConfigured())
    #expect(statusProvider.botToken() == "TEST_BOT_TOKEN_PLACEHOLDER")

    let getUpdatesRequest = try TelegramBotRequestBuilder.makeGetUpdatesRequest(
        botToken: "TEST_BOT_TOKEN_PLACEHOLDER",
        offset: 41
    )
    #expect(getUpdatesRequest.httpMethod == "GET")
    #expect(getUpdatesRequest.url?.absoluteString.contains("/botTEST_BOT_TOKEN_PLACEHOLDER/getUpdates") == true)
    #expect(getUpdatesRequest.url?.query?.contains("offset=41") == true)
    #expect(getUpdatesRequest.url?.query?.contains("allowed_updates=%5B%22message%22%5D") == true)
    #expect(getUpdatesRequest.timeoutInterval == TelegramBotRequestBuilder.requestTimeoutInterval)

    let webhookInfoRequest = try TelegramBotRequestBuilder.makeGetWebhookInfoRequest(botToken: "TEST_BOT_TOKEN_PLACEHOLDER")
    #expect(webhookInfoRequest.httpMethod == "GET")
    #expect(webhookInfoRequest.url?.absoluteString.contains("/botTEST_BOT_TOKEN_PLACEHOLDER/getWebhookInfo") == true)

    let deleteWebhookRequest = try TelegramBotRequestBuilder.makeDeleteWebhookRequest(
        botToken: "TEST_BOT_TOKEN_PLACEHOLDER",
        dropPendingUpdates: false
    )
    #expect(deleteWebhookRequest.httpMethod == "POST")
    let deleteWebhookBody = try #require(deleteWebhookRequest.httpBody)
    let deletePayload = try JSONSerialization.jsonObject(with: deleteWebhookBody) as? [String: Any]
    #expect(deletePayload?["drop_pending_updates"] as? Bool == false)

    let sendMessageRequest = try TelegramBotRequestBuilder.makeSendMessageRequest(
        botToken: "TEST_BOT_TOKEN_PLACEHOLDER",
        chatID: "testchatsend",
        text: "Hello from PM",
        replyToMessageID: 77,
        disableNotification: true
    )
    #expect(sendMessageRequest.httpMethod == "POST")
    let requestBody = try #require(sendMessageRequest.httpBody)
    let payload = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
    #expect(payload?["chat_id"] as? String == "testchatsend")
    #expect(payload?["text"] as? String == "Hello from PM")
    #expect(payload?["reply_to_message_id"] as? Int == 77)
    #expect(payload?["disable_notification"] as? Bool == true)
    #expect(sendMessageRequest.timeoutInterval == TelegramBotRequestBuilder.requestTimeoutInterval)
    #expect(String(data: requestBody, encoding: .utf8)?.contains("TEST_BOT_TOKEN_PLACEHOLDER") == false)

    let missingStatusProvider = TelegramBotKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(keyReader: StubKeyReader(values: [:]))
    )
    #expect(missingStatusProvider.isConfigured() == false)
}

@Test("Telegram poll ingests inbound updates into app-owned PM communication records")
func telegramPollIngestsInboundUpdatesIntoPMCommunicationRecords() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-poll-ingest")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 101,
            message: TelegramBotInboundMessage(
                messageId: 17,
                sentAt: Date(timeIntervalSince1970: 1_742_100_000),
                text: "hello from telegram",
                chat: TelegramBotChat(id: "testchatownera", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownera", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let sessions = try await engine.listPMCommunicationSessions()
    let messages = try await engine.listPMCommunicationMessages()
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt < rhs.sentAt
        }
    let bridgeStatus = await engine.telegramBridgeStatus()

    #expect(result.fetchedUpdateCount == 1)
    #expect(result.ingestedMessageCount == 1)
    #expect(result.duplicateUpdateCount == 0)
    #expect(result.unauthorizedIgnoredCount == 0)
    #expect(result.allowlistedOwnerChatId == "testchatownera")
    #expect(result.boundChatId == "testchatownera")
    #expect(sessions.count == 1)
    #expect(sessions.first?.channel == .telegram)
    #expect(sessions.first?.externalConversationId == "testchatownera")
    #expect(sessions.first?.participantId == "8899")
    #expect(sessions.first?.participantDisplayName == "@owneruser")
    #expect(messages.count == 2)
    #expect(messages.first?.senderRole == .owner)
    #expect(messages.first?.direction == .incoming)
    #expect(messages.first?.body == "hello from telegram")
    #expect(messages.first?.sentAt == Date(timeIntervalSince1970: 1_742_100_000))
    #expect(messages.last?.senderRole == .pm)
    #expect(messages.last?.direction == .outgoing)
    #expect(messages.last?.replyToMessageId == messages.first?.messageId)
    #expect(bridgeStatus.tokenConfigured)
    #expect(bridgeStatus.allowlistedOwnerChatId == "testchatownera")
    #expect(bridgeStatus.lastConsumedUpdateId == 101)
    #expect((try await engine.listPMApprovalRequests()).isEmpty)
    #expect((try await engine.listPMDecisions()).isEmpty)
    #expect(bridgeStatus.lastWebhookPresent == false)
    #expect(bridgeStatus.lastRequestedOffset == nil)
    #expect(bridgeStatus.lastHighestFetchedUpdateId == 101)
    let diagnostics = await engine.telegramBridgeRuntimeDiagnostics()
    #expect(diagnostics.pollCount == 1)
    #expect(diagnostics.materialChangePollCount == 1)
    #expect(diagnostics.communicationChangePollCount == 1)
    #expect(diagnostics.noChangePollCount == 0)
    #expect(diagnostics.durableStateSaveCount == 1)

    let requestedOffsets = await service.requestedOffsets()
    #expect(requestedOffsets == [nil])
}

@Test("Telegram duplicate updates stay deduped and request the next offset")
func telegramDuplicateUpdatesStayDeduped() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-poll-dedupe")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 202,
            message: TelegramBotInboundMessage(
                messageId: 31,
                sentAt: Date(timeIntervalSince1970: 1_742_100_100),
                text: "still the same chat",
                chat: TelegramBotChat(id: "testchatownera", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownera", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let secondResult = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)

    #expect(secondResult.ingestedMessageCount == 0)
    #expect(secondResult.duplicateUpdateCount == 1)
    #expect((try await engine.listPMCommunicationMessages()).count == 2)
    let requestedOffsets = await service.requestedOffsets()
    #expect(requestedOffsets == [nil, 203])
}

@Test("Telegram unauthorized inbound route is ignored before PM communication truth is created")
func telegramUnauthorizedInboundRouteIsIgnoredBeforePMTruthCreation() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-unauthorized-ignore")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 211,
            message: TelegramBotInboundMessage(
                messageId: 32,
                sentAt: Date(timeIntervalSince1970: 1_742_100_101),
                text: "hello from stranger",
                chat: TelegramBotChat(id: "testchatstranger", firstName: "Stranger"),
                from: TelegramBotUser(id: "4411", username: "strangeruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownera", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let sessions = try await engine.listPMCommunicationSessions()
    let messages = try await engine.listPMCommunicationMessages()
    let status = await engine.telegramBridgeStatus()

    #expect(result.fetchedUpdateCount == 1)
    #expect(result.ingestedMessageCount == 0)
    #expect(result.unauthorizedIgnoredCount == 1)
    #expect(result.allowlistedOwnerChatId == "testchatownera")
    #expect(result.boundChatId == nil)
    #expect(sessions.isEmpty)
    #expect(messages.isEmpty)
    #expect((try await engine.listPMInstructions()).isEmpty)
    #expect((try await engine.listPMNotebookEntries()).isEmpty)
    #expect((try await engine.listPMApprovalRequests()).isEmpty)
    #expect((try await engine.listPMDecisions()).isEmpty)
    #expect((try await engine.listPMDelegations()).isEmpty)
    #expect(status.allowlistedOwnerChatId == "testchatownera")
    #expect(status.unauthorizedInboundCount == 1)
    #expect(status.lastUnauthorizedChatId == "testchatstranger")
    #expect(status.lastUnauthorizedParticipantLabel == "@strangeruser")
}

@Test("Telegram owner allowlist bootstraps from the sole persisted Telegram PM communication session")
func telegramOwnerAllowlistBootstrapsFromPersistedCommunicationSession() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-bootstrap-owner-session")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 212,
            message: TelegramBotInboundMessage(
                messageId: 33,
                sentAt: Date(timeIntervalSince1970: 1_742_100_102),
                text: "owner still here",
                chat: TelegramBotChat(id: "testchatownera", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedTelegramCommunicationSession(
        root: root,
        chatID: "testchatownera",
        participantID: "8899",
        participantLabel: "@owneruser",
        updatedAt: Date(timeIntervalSince1970: 1_742_100_090)
    )

    let engine = makeTelegramBridgeEngine(root: root, service: service)
    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let status = await engine.telegramBridgeStatus()
    let sessions = try await engine.listPMCommunicationSessions()
    let messages = try await engine.listPMCommunicationMessages()
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt < rhs.sentAt
        }

    #expect(result.ingestedMessageCount == 1)
    #expect(result.unauthorizedIgnoredCount == 0)
    #expect(result.allowlistedOwnerChatId == "testchatownera")
    #expect(status.allowlistedOwnerChatId == "testchatownera")
    #expect(status.allowlistedOwnerSessionId == "pm-user-telegram-chat-testchatownera")
    #expect(sessions.count == 1)
    #expect(messages.count == 2)
    #expect(messages.first?.body == "owner still here")
    #expect(messages.last?.senderRole == .pm)
}

@Test("Telegram polling clears webhook conflicts before binding inbound chat state")
func telegramPollingClearsWebhookConflictsBeforeBinding() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-webhook-clear")
    let service = StubTelegramBotService()
    await service.setWebhookInfo(
        TelegramBotWebhookInfo(
            url: "https://example.com/hook",
            pendingUpdateCount: 1,
            lastErrorMessage: "temporary delivery failure",
            allowedUpdates: ["message"]
        )
    )
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 250,
            message: TelegramBotInboundMessage(
                messageId: 61,
                sentAt: Date(timeIntervalSince1970: 1_742_100_150),
                text: "fresh test 1",
                chat: TelegramBotChat(id: "testchatownerb", firstName: "Owner"),
                from: TelegramBotUser(id: "9911", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerb", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let status = await engine.telegramBridgeStatus()

    #expect(result.fetchedUpdateCount == 1)
    #expect(result.boundChatId == "testchatownerb")
    #expect(result.webhookPresent == true)
    #expect(result.webhookPendingUpdateCount == 1)
    #expect(status.lastWebhookPresent == true)
    #expect(status.lastWebhookPendingUpdateCount == 1)
    #expect(await service.deleteWebhookCalls() == [false])
}

@Test("Telegram first-bind recovery poll can ingest latest inbound update when initial offset yields nothing")
func telegramFirstBindRecoveryPollCanIngestLatestInboundUpdate() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-recovery-bind")
    let service = StubTelegramBotService()
    await service.setUpdatesByOffset([
        501: [],
        -5: [
            TelegramBotUpdate(
                updateId: 480,
                message: TelegramBotInboundMessage(
                    messageId: 62,
                    sentAt: Date(timeIntervalSince1970: 1_742_100_175),
                    text: "fresh recovery bind",
                    chat: TelegramBotChat(id: "testchatownerc", firstName: "Owner"),
                    from: TelegramBotUser(id: "7712", username: "owneruser")
                )
            )
        ]
    ])

    let engine = makeTelegramBridgeEngine(root: root, service: service)
    let seeded = TelegramBridgeStateStore(
        fileURL: root.appendingPathComponent("telegram_bridge_state.json", isDirectory: false)
    )
    _ = try await seeded.save(
        TelegramBridgeState(
            allowlistedOwnerChatId: "testchatownerc",
            allowlistedOwnerSessionId: "pm-user-telegram-chat-testchatownerc",
            allowlistedOwnerParticipantLabel: "@owneruser",
            lastConsumedUpdateId: 500
        )
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let status = await engine.telegramBridgeStatus()

    #expect(result.fetchedUpdateCount == 1)
    #expect(result.ingestedMessageCount == 1)
    #expect(result.boundChatId == "testchatownerc")
    #expect(result.requestedOffset == 501)
    #expect(result.recoveryTriggered == true)
    #expect(result.recoveryOffset == -5)
    #expect(status.lastRecoveryTriggered == true)
    #expect(status.lastRecoveryOffset == -5)
    #expect(status.lastHighestFetchedUpdateId == 480)
    #expect(await service.requestedOffsets() == [501, -5])
}

@Test("Outbound PM replies use the learned Telegram chat route through the same communication substrate")
func outboundPMRepliesUseLearnedTelegramChatRoute() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-send-reply")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 303,
            message: TelegramBotInboundMessage(
                messageId: 44,
                sentAt: Date(timeIntervalSince1970: 1_742_100_200),
                text: "Can you reply remotely?",
                chat: TelegramBotChat(id: "testchatownersenda", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownersenda", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let session = try #require((try await engine.listPMCommunicationSessions()).first)
    let inboundMessage = try #require(
        (try await engine.listPMCommunicationMessages()).first(where: { $0.senderRole == .owner })
    )

    let outboundMessage = try await engine.createPMCommunicationMessage(
        sessionId: session.sessionId,
        senderRole: .pm,
        senderId: "pm-1",
        body: "Yes. This reply is still stored in the app first.",
        replyToMessageId: inboundMessage.messageId,
        source: .ui
    )

    let sentMessages = await service.sentMessages()
    let bridgeStatus = await engine.telegramBridgeStatus()

    #expect(outboundMessage.direction == .outgoing)
    #expect(sentMessages.count == 2)
    #expect(sentMessages.last?.chatID == "testchatownersenda")
    #expect(sentMessages.last?.text == "Yes. This reply is still stored in the app first.")
    #expect(sentMessages.last?.replyToMessageID == 44)
    #expect(sentMessages.last?.disableNotification == false)
    #expect(bridgeStatus.lastBoundChatId == "testchatownersenda")
    #expect(bridgeStatus.lastOutboundSummary?.contains("Sent Telegram conversation reply") == true)
    #expect(bridgeStatus.lastOutboundWakeUpClass == .conversationReply)
    #expect(bridgeStatus.lastOutboundSilent == false)
}

@Test("Telegram owner asks generate a PM reply and send it back over Telegram")
func telegramOwnerAskGeneratesPMReplyAndRoutesItBack() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-generic-ask-auto-reply")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 304,
            message: TelegramBotInboundMessage(
                messageId: 45,
                sentAt: Date(timeIntervalSince1970: 1_742_100_205),
                text: "Please read the Portfolio Strategy Brief and send me your questions and comments.",
                chat: TelegramBotChat(id: "testchatownerthread", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthread", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I reviewed the Portfolio Strategy Brief. Before I would revise it, I would tighten these points: make the escalation thresholds clearer, spell out what becomes owner-facing, and clarify the concentration discipline.",
                resolution: PMConversationResolutionState(
                    intentClass: .general,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )
    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let messages = try await engine.listPMCommunicationMessages()
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt < rhs.sentAt
        }
    let sentMessages = await service.sentMessages()
    let bridgeStatus = await engine.telegramBridgeStatus()

    #expect(result.ingestedMessageCount == 1)
    #expect(messages.count == 2)
    #expect(messages.first?.senderRole == .owner)
    #expect(messages.last?.senderRole == .pm)
    #expect(messages.last?.replyToMessageId == messages.first?.messageId)
    #expect(messages.last?.body.contains("Portfolio Strategy Brief") == true)
    #expect(messages.last?.body.contains("Before I would revise it, I would tighten these points:") == true)
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?.chatID == "testchatownerthread")
    #expect(sentMessages.first?.replyToMessageID == 45)
    #expect(sentMessages.first?.text.contains("Portfolio Strategy Brief") == true)
    #expect(bridgeStatus.lastOutboundSummary?.contains("Sent Telegram conversation reply") == true)
}

@Test("Telegram model-backed action plans do not create app-authored second PM replies")
func telegramModelBackedActionPlansDoNotCreateAppAuthoredSecondPMReplies() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-action-plan-single-visible-reply")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 304,
            message: TelegramBotInboundMessage(
                messageId: 45,
                sentAt: Date(timeIntervalSince1970: 1_742_100_205),
                text: "Tighten the consumer analyst charter around low-ticket resilience.",
                chat: TelegramBotChat(id: "testchatownerthread", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    let charterStore = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let now = Date(timeIntervalSince1970: 1_742_100_200)
    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "charter-consumer-telegram-test",
            analystId: "analyst-consumer-telegram-test",
            title: "Consumer Analyst",
            coverageScope: "Consumer coverage.",
            strategyFamily: "Long/Short Equity",
            summary: "Old summary.",
            documentBody: "Old charter body.",
            updatedBy: "owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthread", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I’ll tighten the Consumer Analyst charter around low-ticket resilience through the app-owned charter path.",
                actionPlan: PMConversationActionPlan(
                    summary: "Update the Consumer Analyst charter.",
                    actions: [
                        PMConversationActionIntent(
                            actionType: .updateAnalystCharter,
                            summary: "Consumer Analyst should focus on low-ticket resilience.",
                            body: "## Scope\nCover low-ticket resilience, demand shifts, and margin pressure.",
                            detail: "Conversation-driven charter refinement for Consumer Analyst.",
                            charterId: "charter-consumer-telegram-test",
                            sourceMessageIds: []
                        )
                    ]
                ),
                resolution: PMConversationResolutionState(
                    intentClass: .instruction,
                    disposition: .durableApplyNow
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider,
        analystCharterStore: charterStore
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let messages = try await engine.listPMCommunicationMessages()
    let pmMessages = messages.filter { $0.senderRole == .pm }
    let sentMessages = await service.sentMessages()
    let updatedCharter = try await engine.getAnalystCharter(id: "charter-consumer-telegram-test")

    #expect(result.ingestedMessageCount == 1)
    #expect(pmMessages.count == 1)
    #expect(pmMessages.first?.body.contains("low-ticket resilience") == true)
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?.text.contains("low-ticket resilience") == true)
    #expect(updatedCharter.summary.contains("low-ticket resilience"))
}

@Test("Telegram-originated ad hoc analyst task sends completion follow-through to the same chat")
func telegramOriginatedAdHocAnalystTaskSendsCompletionFollowThroughToSameChat() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-ad-hoc-analyst-follow-through")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 305,
            message: TelegramBotInboundMessage(
                messageId: 46,
                sentAt: Date(timeIntervalSince1970: 1_742_100_260),
                text: "Have the Technology Analyst research META and send me the result.",
                chat: TelegramBotChat(id: "testchatownerthread", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    let now = Date(timeIntervalSince1970: 1_742_100_500)
    let charterStore = AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true))
    let taskStore = AnalystTaskStore(tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true))
    let memoStore = AnalystMemoStore(memosDirectory: root.appendingPathComponent("memos", isDirectory: true))
    _ = try await memoStore.loadAll()
    _ = try await charterStore.upsert(
        AnalystCharter(
            charterId: "bench-sector-technology",
            analystId: "bench-sector-technology-analyst",
            title: "Technology Analyst",
            coverageScope: "Technology and technology platforms",
            strategyFamily: "Long/Short Equity",
            summary: "Technology coverage",
            updatedBy: "owner",
            updateSource: .userEdited,
            createdAt: now,
            updatedAt: now
        )
    )
    let memo = AnalystMemo(
        memoId: "memo-telegram-meta-follow-through",
        analystId: "bench-sector-technology-analyst",
        charterId: "bench-sector-technology",
        pmId: "pm-1",
        title: "META catalyst follow-up",
        executiveSummary: "META remains a credible AI-platform candidate, but the analyst would keep it in monitor/research-follow-up until official event timing and financial capacity details are refreshed.",
        currentView: "Official Meta and SEC/IR materials should lead the conclusion, with reputable secondary product reporting used for timing and rumor tiering.",
        evidenceSummary: "The memo separated official materials from secondary reporting and identified missing Connect timing, forward valuation, and cash/liquidity confirmations.",
        uncertaintySummary: "The open questions are event timing, product-roadmap confirmation, and whether 2026 technology spend is already priced.",
        recommendedNextStep: "Pull the latest official Meta IR/SEC/event materials and then rerun the catalyst check with broader public-web evidence.",
        confidence: 0.62,
        createdAt: now,
        updatedAt: now
    )
    let workerMemoStore = AnalystMemoStore(memosDirectory: root.appendingPathComponent("memos", isDirectory: true))
    _ = try await workerMemoStore.upsert(memo)

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthread", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I’m launching Technology Analyst work on META and I’ll send the result back here when it is done.",
                actionPlan: PMConversationActionPlan(
                    summary: "Launch Technology Analyst META research and close the loop.",
                    actions: [
                        PMConversationActionIntent(
                            actionType: .launchAdHocAnalystDelegation,
                            summary: "Have the Technology Analyst research META catalysts and report back.",
                            title: "Technology Analyst META catalyst research",
                            body: "Research META catalysts, official event timing, financial capacity, and 2026 technology/product positioning.",
                            detail: "Use charter-governed public-web research and send the result back to the originating owner thread.",
                            charterId: "Technology Analyst",
                            requestedOutputs: [.finding],
                            sourceMessageIds: []
                        )
                    ]
                ),
                resolution: PMConversationResolutionState(
                    intentClass: .instruction,
                    disposition: .durableApplyNow
                )
            ),
            PMConversationOpenAISynthesisOutput(
                replyBody: "The Technology Analyst work is back. My PM read is that META remains a credible AI-platform candidate, but the conclusion is still monitor/research-follow-up until official timing and liquidity details are refreshed. The full memo is in PM Inbox / Recent Analyst Activity.",
                actionPlan: PMConversationActionPlan(
                    summary: "Synthesize completed analyst task for owner follow-through.",
                    actions: [
                        PMConversationActionIntent(
                            actionType: .answerOnly,
                            summary: "Delivered PM-synthesized META analyst follow-through."
                        )
                    ]
                )
            )
        ]
    )
    let launcher = StubTelegramAnalystWorkerLauncher(
        result: AnalystWorkerLaunchResult(
            openAIKeyConfigured: true,
            usedOpenAI: false,
            charterId: "bench-sector-technology",
            taskId: nil,
            delegationId: nil,
            pmId: "pm-1",
            memoId: memo.memoId,
            memoTitle: memo.title,
            findingId: nil,
            findingTitle: nil,
            draftedSignalId: nil,
            draftedProposalId: nil,
            summary: "Technology Analyst memo completed on META.",
            outputExcerpt: memo.executiveSummary
        )
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider,
        analystCharterStore: charterStore,
        analystTaskStore: taskStore,
        analystMemoStore: memoStore,
        analystWorkerLauncher: launcher
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let messages = try await engine.listPMCommunicationMessages()
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt < rhs.sentAt
        }
    let pmMessages = messages.filter { $0.senderRole == .pm }
    let sentMessages = await service.sentMessages()
    let delegations = try await engine.listPMDelegations()
    let delegation = try #require(delegations.first)
    let deliveredMessageId = try #require(delegation.followThrough?.deliveredMessageId)
    let launchReply = try #require(pmMessages.first {
        $0.body.contains("launching Technology Analyst work on META")
    })
    let followThroughReply = try #require(pmMessages.first {
        $0.messageId == deliveredMessageId
    })

    #expect(result.ingestedMessageCount == 1)
    #expect(pmMessages.count == 2)
    #expect(launchReply.replyToMessageId != followThroughReply.replyToMessageId)
    #expect(followThroughReply.body.contains("The Technology Analyst work is back"))
    #expect(followThroughReply.body.contains("META remains a credible AI-platform candidate"))
    #expect(followThroughReply.body.contains("full memo is in PM Inbox"))
    #expect(sentMessages.count == 2)
    #expect(sentMessages.first?.text.contains("launching Technology Analyst work on META") == true)
    #expect(sentMessages.last?.text.contains("The Technology Analyst work is back") == true)
    #expect(sentMessages.last?.text == followThroughReply.body)
    #expect(sentMessages.last?.text.contains("task-") == false)
    #expect(sentMessages.last?.text.contains("delegation_id") == false)
    #expect(sentMessages.last?.text.contains("charter_id") == false)
    #expect(sentMessages.last?.text.contains("alpaca_analyst_worker") == false)
    #expect(sentMessages.last?.chatID == "testchatownerthread")
    #expect(sentMessages.last?.disableNotification == false)
    #expect(delegation.followThrough?.status == .delivered)
    #expect(delegation.followThrough?.sourceCommunicationSessionId == "pm-user-telegram-chat-testchatownerthread")
    #expect(delegation.followThrough?.deliveredMessageId == followThroughReply.messageId)
    #expect(delegation.followThrough?.canonicalBody == followThroughReply.body)
    #expect(delegation.followThrough?.telegramDeliveredMessageId == followThroughReply.messageId)
    #expect((await synthesisProvider.conversationRequests).count == 2)
}

@Test("Telegram follow-through transport sanitizes internal debug metadata")
func telegramFollowThroughTransportSanitizesInternalDebugMetadata() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-follow-through-sanitizes-debug")
    let service = StubTelegramBotService()
    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthread", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    let now = Date(timeIntervalSince1970: 1_742_100_500)
    let session = PMCommunicationSession(
        sessionId: "pm-user-telegram-chat-testchatownerthread",
        channel: .telegram,
        externalConversationId: "testchatownerthread",
        pmId: "pm-1",
        participantId: "8899",
        participantDisplayName: "@owneruser",
        status: .active,
        createdAt: now,
        updatedAt: now
    )
    _ = try await engine.upsertPMCommunicationSession(session, source: .ui)

    let rawDebugBody = """
    The Technology Analyst work is back on META 2026 technology, events, valuation, cash, and product-rumor research. I could not run PM synthesis for the follow-through, so I’m giving you a compact fallback summary here; the full analyst memo stays in PM Inbox.

    Initial takeaway: memo: Technology Analyst ongoing research — bounded PM synthesis • finding: AI infrastructure still leads tech, but quality filters matter • signal: sig-finding-bench-sector-technology-bundle-bench-sector-technology-ref-news-24d241691f0038ce-ref-news-76dce9-ecd93a97 • task: task-6b160f16-4de7-4764-8ad0-97c8cac5a768 • runtime: openai_responses

    Working note: alpaca_analyst_worker run-once succeeded charter_seeded: false openai_key_configured: true used_openai: true pm_id: pm-1 delegation_id: delegation-c4ad278d-0a56-4442-b9ec-92913cc19e5f analyst_id: bench-sector-technology-analyst charter_id: bench-sector-technology task_id: task-6b160f16-4de7-4764-8ad0-97c8cac5a768
    """

    _ = try await engine.createPMCommunicationMessage(
        sessionId: session.sessionId,
        senderRole: .pm,
        senderId: "pm-1",
        body: rawDebugBody,
        telegramDelivery: .importantWakeUp(reason: "PM-requested analyst work completed."),
        source: .ui
    )
    let sent = try #require(await service.sentMessages().last)

    #expect(sent.text.contains("Technology Analyst work is back"))
    #expect(sent.text.contains("PM Inbox"))
    #expect(sent.text.contains("task-") == false)
    #expect(sent.text.contains("delegation-") == false)
    #expect(sent.text.contains("sig-finding") == false)
    #expect(sent.text.contains("delegation_id") == false)
    #expect(sent.text.contains("charter_id") == false)
    #expect(sent.text.contains("task_id") == false)
    #expect(sent.text.contains("alpaca_analyst_worker") == false)
    #expect(sent.text.contains("openai_key_configured") == false)
}

@Test("Telegram complete Live order instruction creates in-app review item without submitting order")
func telegramCompleteLiveOrderInstructionCreatesInAppReviewItemWithoutSubmittingOrder() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-live-order-review-item")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 305,
            message: TelegramBotInboundMessage(
                messageId: 46,
                sentAt: Date(timeIntervalSince1970: 1_742_100_260),
                text: "Review a live market day order to buy 1 AAPL share.",
                chat: TelegramBotChat(id: "testchatownerthread", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthread", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I created an in-app Live order review item in Command Center > Your Decisions. No order has been submitted.",
                actionPlan: PMConversationActionPlan(
                    summary: "Create a PM decision and owner-visible Live order review item.",
                    actions: [
                        PMConversationActionIntent(
                            actionType: .createPMDecision,
                            summary: "Review a Live market day order to buy 1 AAPL share.",
                            title: "Live order review: buy 1 AAPL",
                            body: "The owner asked to review a Live market day order to buy 1 AAPL share. This is a review artifact only.",
                            detail: "Review whether this Live order instruction should advance to the governed in-app order path. Do not submit an order from Telegram.",
                            decisionType: .recommendation,
                            sourceMessageIds: []
                        ),
                        PMConversationActionIntent(
                            actionType: .createPMApprovalRequest,
                            summary: "Surface the Live order instruction for in-app review.",
                            title: "Review Live order instruction: buy 1 AAPL",
                            body: "Review a Live market day order instruction to buy 1 AAPL share. This approval request does not submit an order.",
                            detail: "Approve only if this instruction should advance to the governed in-app order path; Live NEW/REPLACE still requires final local authentication when enabled.",
                            liveOrderSymbol: "AAPL",
                            liveOrderSide: .buy,
                            liveOrderQuantity: 1,
                            liveOrderType: .market,
                            liveOrderTimeInForce: .day,
                            requestType: .liveOrderReview,
                            sourceMessageIds: []
                        )
                    ]
                ),
                resolution: PMConversationResolutionState(
                    intentClass: .instruction,
                    disposition: .durableApplyNow
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let messages = try await engine.listPMCommunicationMessages()
    let decisions = try await engine.listPMDecisions()
    let approvalRequests = try await engine.listPMApprovalRequests()
    let approval = try #require(approvalRequests.first)
    let sentMessages = await service.sentMessages()
    let ownerDecisionItems = makeOwnerDecisionDeskPresentations(
        approvalRequests: approvalRequests,
        decisions: decisions,
        delegations: [],
        tasks: [],
        findings: [],
        communicationMessages: messages,
        charters: [],
        memos: [],
        strategyBrief: nil
    )

    #expect(result.ingestedMessageCount == 1)
    #expect(messages.contains { $0.senderRole == .owner && $0.body.contains("AAPL") })
    #expect(messages.contains { $0.senderRole == .pm && $0.body.contains("Your Decisions") })
    #expect(approval.requestType == .liveOrderReview)
    #expect(approval.status == .pending)
    #expect(approval.liveOrderReview?.symbol == "AAPL")
    #expect(approval.liveOrderReview?.quantity == 1)
    #expect(approval.liveOrderReview?.orderType == .market)
    #expect(approval.liveOrderReview?.timeInForce == .day)
    #expect(approval.ownerResponse == nil)
    #expect(approval.lastExecutionRoutingAssessment == nil)
    #expect(ownerDecisionItems.count == 1)
    #expect(ownerDecisionItems.first?.approvalRequestId == approval.approvalRequestId)
    #expect(ownerDecisionItems.first?.requestTypeTitle == "Live Order Review")
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?.text.contains("No order has been submitted") == true)
}

@Test("Telegram Live order instruction with approval wording creates pending review only")
func telegramLiveOrderInstructionWithApprovalWordingCreatesPendingReviewOnly() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-live-order-review-approve-wording")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 306,
            message: TelegramBotInboundMessage(
                messageId: 47,
                sentAt: Date(timeIntervalSince1970: 1_742_100_265),
                text: "Buy $10k META live and approve it.",
                chat: TelegramBotChat(id: "testchatownerthreadapprove", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreadapprove", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I created an in-app Live order review item in Command Center > Your Decisions. Final approval must happen on the Mac; no order has been submitted.",
                actionPlan: PMConversationActionPlan(
                    summary: "Create a PM decision and owner-visible Live order review item, but do not approve it from Telegram.",
                    actions: [
                        PMConversationActionIntent(
                            actionType: .createPMDecision,
                            summary: "Review a Live market day order to buy about $10,000 of META.",
                            title: "Live order review: buy about $10,000 META",
                            body: "The owner asked to buy about $10,000 of META Live and included approval wording. This remains a review artifact only.",
                            detail: "Review whether this Live order instruction should advance to the governed in-app order path. Do not submit an order from Telegram.",
                            decisionType: .recommendation,
                            sourceMessageIds: []
                        ),
                        PMConversationActionIntent(
                            actionType: .createPMApprovalRequest,
                            summary: "Surface the Live order instruction for in-app review.",
                            title: "Review Live order instruction: buy about $10,000 META",
                            body: "Review a Live market day order instruction to buy about $10,000 of META. This approval request does not submit an order.",
                            detail: "Approval must happen in Command Center > Your Decisions on the Mac before any governed Live order route.",
                            liveOrderSymbol: "META",
                            liveOrderSide: .buy,
                            liveOrderNotionalAmount: Decimal(10_000),
                            liveOrderType: .market,
                            liveOrderTimeInForce: .day,
                            requestType: .liveOrderReview,
                            sourceMessageIds: []
                        ),
                        PMConversationActionIntent(
                            actionType: .approvePMApprovalRequest,
                            summary: "The owner included approval wording in the Telegram instruction.",
                            title: "Attempted Telegram approval for Live order review",
                            body: "The model should not be allowed to finalize Live approval from Telegram.",
                            detail: "Approval wording was present in the Telegram instruction.",
                            sourceMessageIds: []
                        )
                    ]
                ),
                resolution: PMConversationResolutionState(
                    intentClass: .instruction,
                    disposition: .durableApplyNow
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let messages = try await engine.listPMCommunicationMessages()
    let approval = try #require((try await engine.listPMApprovalRequests()).first)
    let reply = try #require(messages.first { $0.senderRole == .pm && $0.replyToMessageId != nil })
    let approveAction = try #require(reply.conversationActionPlan?.actions.first { $0.actionType == .approvePMApprovalRequest })
    let sentMessages = await service.sentMessages()

    #expect(result.ingestedMessageCount == 1)
    #expect(result.approvalResponseCount == 0)
    #expect(approval.requestType == .liveOrderReview)
    #expect(approval.status == .pending)
    #expect(approval.ownerResponse == nil)
    #expect(approval.ownerRespondedAt == nil)
    #expect(approval.lastExecutionRoutingAssessment == nil)
    #expect(approval.liveOrderExecutionLifecycleState == nil)
    #expect(approval.liveOrderReview?.symbol == "META")
    #expect(approval.liveOrderReview?.notionalAmount == Decimal(10_000))
    #expect(approveAction.detail?.contains("Live order approval must be completed in Command Center > Your Decisions on the Mac.") == true)
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?.text.contains("Final approval must happen on the Mac") == true)
    #expect(sentMessages.first?.text.contains("no order has been submitted") == true)
}

@Test("Telegram incomplete Live order instruction asks follow-up and creates no approval")
func telegramIncompleteLiveOrderInstructionAsksFollowUpAndCreatesNoApproval() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-live-order-incomplete")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 306,
            message: TelegramBotInboundMessage(
                messageId: 47,
                sentAt: Date(timeIntervalSince1970: 1_742_100_270),
                text: "Buy AAPL live.",
                chat: TelegramBotChat(id: "testchatownerthread", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthread", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I need the missing Live order details before I can create an in-app review item: quantity or notional, order type, and time-in-force.",
                actionPlan: PMConversationActionPlan(
                    summary: "Ask for missing Live order details before creating any approval item.",
                    actions: [
                        PMConversationActionIntent(
                            actionType: .askFollowUp,
                            summary: "Ask for quantity or notional, order type, and time-in-force before Live order review.",
                            sourceMessageIds: []
                        )
                    ]
                ),
                resolution: PMConversationResolutionState(
                    intentClass: .ambiguous,
                    disposition: .clarificationRequired
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let approvalRequests = try await engine.listPMApprovalRequests()
    let sentMessages = await service.sentMessages()

    #expect(result.ingestedMessageCount == 1)
    #expect(approvalRequests.isEmpty)
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?.text.contains("quantity or notional") == true)
    #expect(sentMessages.first?.text.contains("Touch ID") == false)
}

@Test("Telegram PM reply cannot promise in-app approval or Touch ID without durable artifact")
func telegramPMReplyCannotPromiseInAppApprovalOrTouchIDWithoutDurableArtifact() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-live-order-ghost-approval-guard")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 307,
            message: TelegramBotInboundMessage(
                messageId: 48,
                sentAt: Date(timeIntervalSince1970: 1_742_100_280),
                text: "Place that live order now.",
                chat: TelegramBotChat(id: "testchatownerthread", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthread", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I created the in-app approval. Approve via Touch ID or your Mac password in the app.",
                actionPlan: PMConversationActionPlan(
                    summary: "Model failed to emit the consequential approval action.",
                    actions: [
                        PMConversationActionIntent(
                            actionType: .answerOnly,
                            summary: "No durable approval action was emitted.",
                            sourceMessageIds: []
                        )
                    ]
                ),
                resolution: PMConversationResolutionState(
                    intentClass: .instruction,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let approvalRequests = try await engine.listPMApprovalRequests()
    let pmReply = try #require(try await engine.listPMCommunicationMessages().last { $0.senderRole == .pm })
    let sentMessages = await service.sentMessages()

    #expect(result.ingestedMessageCount == 1)
    #expect(approvalRequests.isEmpty)
    #expect(pmReply.body.contains("I have not created an in-app approval item"))
    #expect(pmReply.body.contains("No PM approval request"))
    #expect(pmReply.body.contains("Touch ID route"))
    #expect(pmReply.runtimeProvenance?.conversationTrace?.visibleReplyModifiedAfterSynthesis == true)
    #expect(pmReply.conversationActionPlan?.actions.first?.detail?.contains("Work commitment consistency guard") == true)
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?.text == pmReply.body)
}

@Test("Telegram report detail questions route through model-backed PM continuity instead of no-active-item fallback")
func telegramReportDetailQuestionsRouteThroughModelBackedPMContinuity() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-report-detail-question")
    let service = StubTelegramBotService()
    let ownerQuestion = """
    I see short positions when I open the detailed supporting section. For example the latest Technology Analyst report lists Best Short Candidates as SNOW, Unity and INTC. Can you see that?
    """
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 305,
            message: TelegramBotInboundMessage(
                messageId: 46,
                sentAt: Date(timeIntervalSince1970: 1_742_100_206),
                text: ownerQuestion,
                chat: TelegramBotChat(id: "testchatownerthreadb", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    let reportStore = AnalystStandingReportStore(
        reportsDirectory: root.appendingPathComponent("standing_reports", isDirectory: true)
    )
    let now = Date(timeIntervalSince1970: 1_742_100_206)
    _ = try await reportStore.upsert(
        AnalystStandingReport(
            reportId: "telegram-technology-report-detail",
            deliveryStatus: .reviewedByPM,
            analystId: "bench-sector-technology-analyst",
            charterId: "bench-sector-technology",
            scheduleId: "standing-report-bench-sector-technology",
            memoId: "memo-telegram-technology-report-detail",
            title: "Technology Analyst Standing Report",
            summary: "The compact Technology summary does not enumerate detailed short candidates.",
            cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
            reportingWindowSummary: "Latest Technology Analyst review.",
            portfolioScopeSummary: "Technology sector coverage.",
            headlineView: "Long-oriented technology refresh with detailed supporting short section.",
            portfolioRelevanceSummary: "Detailed supporting sections carry short-side pressure tests.",
            sections: [
                AnalystStandingReportSection(
                    sectionId: "telegram-technology-shorts",
                    kind: .shortIdeas,
                    summary: "Best current short-side pressure-test candidates in technology.",
                    items: [
                        AnalystStandingReportItem(
                            itemId: "telegram-snow-short",
                            headline: "SNOW is a premium-valuation short candidate.",
                            detail: "SNOW belongs on the short side when premium valuation and execution sensitivity look mismatched to current construction.",
                            symbol: "SNOW",
                            stance: .short,
                            conviction: 7
                        ),
                        AnalystStandingReportItem(
                            itemId: "telegram-unity-short",
                            headline: "Unity is a short-side pressure test.",
                            detail: "Unity is a useful short-side pressure test because the report details operational uncertainty and weak execution visibility.",
                            symbol: "U",
                            stance: .short,
                            conviction: 6
                        ),
                        AnalystStandingReportItem(
                            itemId: "telegram-intc-short",
                            headline: "INTC remains a bounded short candidate.",
                            detail: "INTC is a bounded short-side pressure test while turnaround timing and capital intensity remain contested.",
                            symbol: "INTC",
                            stance: .short,
                            conviction: 5
                        )
                    ]
                )
            ],
            deliveredToPMInboxAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreadb", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "Yes. I’m checking the analyst report details rather than treating Telegram as a detached PM ask.",
                resolution: PMConversationResolutionState(
                    intentClass: .followUpQuestion,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider,
        analystStandingReportStore: reportStore
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let messages = try await engine.listPMCommunicationMessages()
    let sentMessages = await service.sentMessages()
    let request = try #require(await synthesisProvider.lastConversationRequest)

    #expect(result.ingestedMessageCount == 1)
    #expect(messages.contains(where: { $0.senderRole == .owner && $0.body == ownerQuestion }))
    #expect(messages.contains(where: { $0.senderRole == .pm && $0.body.contains("checking the analyst report details") }))
    #expect(sentMessages.first?.text.contains("checking the analyst report details") == true)
    #expect(sentMessages.first?.text.contains("current PM ask or recommendation linked to this chat") == false)
    #expect(request.ownerMessageBody.contains("Best Short Candidates"))
    #expect(request.sessionChannel == PMCommunicationChannel.telegram.rawValue)
    let artifactGrounding = request.analystArtifactSummary.joined(separator: "\n")
    #expect(artifactGrounding.contains("Best Short Candidates"))
    #expect(artifactGrounding.contains("SNOW"))
    #expect(artifactGrounding.contains("Unity"))
    #expect(artifactGrounding.contains("INTC"))
    #expect(makePMConversationPromptText(from: request).contains("Best Short Candidates"))
}

@Test("Telegram analyst report question receives open analyst lane index")
func telegramAnalystReportQuestionReceivesOpenAnalystLaneIndex() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-recent-news-report-specific")
    let service = StubTelegramBotService()
    let ownerQuestion = "What was the last Recent News Analyst report you reviewed?"
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 306,
            message: TelegramBotInboundMessage(
                messageId: 47,
                sentAt: Date(timeIntervalSince1970: 1_742_100_208),
                text: ownerQuestion,
                chat: TelegramBotChat(id: "testchatownerthreadd", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    let reportStore = AnalystStandingReportStore(
        reportsDirectory: root.appendingPathComponent("standing_reports", isDirectory: true)
    )
    let now = Date(timeIntervalSince1970: 1_742_100_200)
    _ = try await reportStore.upsert(
        AnalystStandingReport(
            reportId: "telegram-recent-news-reviewed",
            deliveryStatus: .reviewedByPM,
            analystId: "recent-news-material-impact-analyst",
            charterId: recentNewsStandingAnalystCharterID,
            scheduleId: "standing-report-recent-news-material-impact-analyst",
            memoId: "memo-telegram-recent-news-reviewed",
            title: "Recent News Analyst Standing Report",
            summary: "PM reviewed the latest Recent News Analyst report.",
            cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
            reportingWindowSummary: "Recent news review.",
            portfolioScopeSummary: "Current portfolio and watchlist.",
            headlineView: "Latest reviewed Recent News Analyst artifact.",
            portfolioRelevanceSummary: "Monitor-only recent-news context.",
            sections: [
                AnalystStandingReportSection(
                    sectionId: "recent-news-items",
                    kind: .materialDevelopments,
                    summary: "No material item required an owner-facing action."
                )
            ],
            deliveredToPMInboxAt: now.addingTimeInterval(-120),
            createdAt: now.addingTimeInterval(-120),
            updatedAt: now.addingTimeInterval(-60)
        )
    )
    _ = try await reportStore.upsert(
        AnalystStandingReport(
            reportId: "telegram-consumer-newer",
            deliveryStatus: .reviewedByPM,
            analystId: "bench-sector-consumer-analyst",
            charterId: "bench-sector-consumer",
            scheduleId: "standing-report-bench-sector-consumer",
            memoId: "memo-telegram-consumer-newer",
            title: "Consumer Analyst Standing Report",
            summary: "A newer Consumer Analyst report that must not answer a Recent News query.",
            cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
            reportingWindowSummary: "Consumer review.",
            portfolioScopeSummary: "Consumer sector.",
            headlineView: "Consumer report is newer but unrelated.",
            portfolioRelevanceSummary: "Consumer context only.",
            deliveredToPMInboxAt: now.addingTimeInterval(-30),
            createdAt: now.addingTimeInterval(-30),
            updatedAt: now.addingTimeInterval(-20)
        )
    )

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreadd", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "The latest reviewed Recent News Analyst report is the monitor-only recent-news review.",
                resolution: PMConversationResolutionState(
                    intentClass: .followUpQuestion,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider,
        analystStandingReportStore: reportStore
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let request = try #require(await synthesisProvider.lastConversationRequest)
    let sentMessages = await service.sentMessages()

    #expect(result.ingestedMessageCount == 1)
    #expect(request.sessionChannel == PMCommunicationChannel.telegram.rawValue)
    let laneIndex = request.analystArtifactSummary.joined(separator: "\n")
    #expect(laneIndex.contains("PM model must choose the relevant analyst lane"))
    #expect(laneIndex.contains("deterministic app code is not choosing"))
    #expect(laneIndex.contains("Recent News Analyst: latest reviewed"))
    #expect(laneIndex.contains("telegram-recent-news-reviewed"))
    #expect(laneIndex.contains("Consumer Analyst: latest reviewed"))
    #expect(laneIndex.contains("telegram-consumer-newer"))
    #expect(sentMessages.first?.text.contains("Recent News Analyst") == true)
}

@Test("Telegram latest Recent News detail prompt sends one PM reply with full report detail grounding")
func telegramLatestRecentNewsDetailPromptSendsOnePMReplyWithFullReportDetailGrounding() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-recent-news-full-detail-live-prompt")
    let service = StubTelegramBotService()
    let ownerQuestion = "What was the latest Recent News Analyst report you reviewed, and what material articles or signals did it contain?"
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 307,
            message: TelegramBotInboundMessage(
                messageId: 48,
                sentAt: Date(timeIntervalSince1970: 1_742_100_212),
                text: ownerQuestion,
                chat: TelegramBotChat(id: "testchatownerthreade", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    let reportStore = AnalystStandingReportStore(
        reportsDirectory: root.appendingPathComponent("standing_reports", isDirectory: true)
    )
    let now = Date(timeIntervalSince1970: 1_742_100_210)
    _ = try await reportStore.upsert(
        AnalystStandingReport(
            reportId: "telegram-recent-news-latest-full-detail",
            deliveryStatus: .reviewedByPM,
            analystId: recentNewsStandingAnalystID,
            charterId: recentNewsStandingAnalystCharterID,
            scheduleId: "standing-report-\(recentNewsStandingAnalystID)",
            memoId: "memo-telegram-recent-news-latest-full-detail",
            title: "Recent News Analyst Standing Report",
            summary: "Latest Recent News report with owner-visible material/support detail.",
            cadenceIntervalSec: standingAnalystReportDefaultIntervalSec,
            reportingWindowSummary: "Latest Recent News review.",
            portfolioScopeSummary: "Current portfolio and watchlist recent-news coverage.",
            headlineView: "Shipping-risk headline confirmed as material; GameStop-eBay remains low-confidence.",
            portfolioRelevanceSummary: "Monitor shipping risk and wait for official or issuer-level confirmation before escalation.",
            sections: [
                AnalystStandingReportSection(
                    sectionId: "telegram-recent-news-material-list",
                    kind: .materialDevelopments,
                    summary: "Material news list from full analyst report.",
                    items: [
                        AnalystStandingReportItem(
                            itemId: "telegram-hormuz-shipping",
                            headline: "Oil prices rise as U.S. launches operation to restore freedom of navigation in Strait of Hormuz.",
                            detail: "The latest Recent News Analyst report treats the shipping-risk headline as the material monitoring signal and waits for official maritime-security or insurer follow-up.",
                            stance: .risk
                        ),
                        AnalystStandingReportItem(
                            itemId: "telegram-gamestop-ebay",
                            headline: "eBay pops as Ryan Cohen says GameStop could issue stock to pay for takeover of much bigger retailer.",
                            detail: "The same report keeps the GameStop/eBay bid as low-confidence headline risk rather than a confirmed portfolio-changing signal.",
                            stance: .neutral
                        )
                    ]
                ),
                AnalystStandingReportSection(
                    sectionId: "telegram-recent-news-support",
                    kind: .evidence,
                    summary: "Support list and supplemental source checks.",
                    items: [
                        AnalystStandingReportItem(
                            itemId: "telegram-support-list",
                            headline: "Supplemental sources checked: Axios, TechCrunch, Digital Trends, and CNBC.",
                            detail: "Support remained monitor-only; the PM treatment closed the recommendation episode with no further owner action pending.",
                            stance: .neutral
                        )
                    ]
                )
            ],
            deliveredToPMInboxAt: now.addingTimeInterval(-60),
            createdAt: now.addingTimeInterval(-60),
            updatedAt: now
        )
    )

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreade", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "The latest Recent News Analyst report was the shipping-risk monitor-only review.",
                resolution: PMConversationResolutionState(
                    intentClass: .followUpQuestion,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider,
        analystStandingReportStore: reportStore
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let request = try #require(await synthesisProvider.lastConversationRequest)
    let sentMessages = await service.sentMessages()
    let messages = try await engine.listPMCommunicationMessages()
    let artifactGrounding = request.analystArtifactSummary.joined(separator: "\n")
    let renderedPrompt = makePMConversationPromptText(from: request)

    #expect(result.ingestedMessageCount == 1)
    #expect(messages.filter { $0.senderRole == .owner }.count == 1)
    #expect(messages.filter { $0.senderRole == .pm }.count == 1)
    #expect(sentMessages.count == 1)
    #expect(request.sessionChannel == PMCommunicationChannel.telegram.rawValue)
    #expect(artifactGrounding.contains("Named analyst full-report retrieval")
        || artifactGrounding.contains("Open analyst-lane full-report retrieval"))
    #expect(artifactGrounding.contains("FULL_ANALYST_REPORT_DOCUMENT"))
    #expect(artifactGrounding.contains("FULL_REPORT_LINKED_MEMO_AND_EVIDENCE"))
    #expect(artifactGrounding.contains("FULL_REPORT_SECTION"))
    #expect(artifactGrounding.contains("Recent News Analyst"))
    #expect(artifactGrounding.contains("Oil prices rise as U.S. launches operation"))
    #expect(artifactGrounding.contains("GameStop/eBay bid as low-confidence"))
    #expect(renderedPrompt.contains("Material news list from full analyst report"))
    #expect(renderedPrompt.contains("Supplemental sources checked"))
    #expect(sentMessages.first?.text.contains("shipping-risk") == true)
    #expect(sentMessages.first?.text.contains("current PM ask or recommendation linked to this chat") == false)
}

@Test("Telegram PM synthesis receives same-owner in-app conversation continuity")
func telegramPMSynthesisReceivesSameOwnerInAppConversationContinuity() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-same-owner-continuity")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 306,
            message: TelegramBotInboundMessage(
                messageId: 47,
                sentAt: Date(timeIntervalSince1970: 1_742_100_208),
                text: "Can you still see that short-side context from the app conversation?",
                chat: TelegramBotChat(id: "testchatownerthreadd", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreadd", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "Yes. I can carry the in-app PM context into this Telegram continuation.",
                resolution: PMConversationResolutionState(
                    intentClass: .followUpQuestion,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )
    let inAppSession = try await engine.ensureInAppPMUserCommunicationSession(pmId: "pm-1")
    _ = try await engine.createPMCommunicationMessage(
        sessionId: inAppSession.sessionId,
        senderRole: .owner,
        senderId: "owner",
        body: "In app, please remember that the current analyst question is about short candidates in the detailed report sections.",
        source: .ui
    )
    _ = try await engine.createPMCommunicationMessage(
        sessionId: inAppSession.sessionId,
        senderRole: .pm,
        senderId: "pm-1",
        body: "Understood. I’ll keep the detailed analyst sections separate from summary-only recaps.",
        source: .ui
    )

    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let request = try #require(await synthesisProvider.lastConversationRequest)

    #expect(request.recentConversationSummary.contains(where: {
        $0.contains("short candidates in the detailed report sections")
    }))
    #expect(request.recentConversationSummary.contains(where: {
        $0.contains("summary-only recaps")
    }))
    #expect(request.sessionChannel == PMCommunicationChannel.telegram.rawValue)
}

@Test("Second Telegram owner turns generate a fresh outbound PM reply grounded on the newest ask")
func secondTelegramOwnerTurnGeneratesFreshOutboundReply() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-second-turn-fresh-reply")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 306,
            message: TelegramBotInboundMessage(
                messageId: 51,
                sentAt: Date(timeIntervalSince1970: 1_742_100_210),
                text: "Please read the Portfolio Strategy Brief and send me your questions and comments.",
                chat: TelegramBotChat(id: "testchatownerthreadc", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreadc", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I reviewed the Portfolio Strategy Brief. Before I would revise it, I would tighten these points: make the escalation thresholds clearer, spell out what becomes owner-facing, and clarify the concentration discipline.",
                resolution: PMConversationResolutionState(
                    intentClass: .general,
                    disposition: .conversationOnly
                )
            ),
            PMConversationOpenAISynthesisOutput(
                replyBody: "Suggested Portfolio Strategy Brief revision note: clarify the catalyst-aware sizing rules, define what counts as thesis drift, and note that the saved Strategy Brief stays unchanged until you approve edits.",
                resolution: PMConversationResolutionState(
                    intentClass: .instruction,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)

    await service.setUpdatesByOffset([
        307: [
            TelegramBotUpdate(
                updateId: 307,
                message: TelegramBotInboundMessage(
                    messageId: 52,
                    sentAt: Date(timeIntervalSince1970: 1_742_100_220),
                    text: "Prepare a revision note.",
                    chat: TelegramBotChat(id: "testchatownerthreadc", firstName: "Owner"),
                    from: TelegramBotUser(id: "8899", username: "owneruser")
                )
            )
        ]
    ])
    await service.setUpdates([])

    let secondResult = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let messages = try await engine.listPMCommunicationMessages()
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt < rhs.sentAt
        }
    let sentMessages = await service.sentMessages()

    #expect(secondResult.ingestedMessageCount == 1)
    #expect(messages.count == 4)
    let secondOwnerMessage = try #require(messages.first(where: { message in
        message.senderRole == .owner && message.body == "Prepare a revision note."
    }))
    let secondPMReply = try #require(messages.first(where: { message in
        message.senderRole == .pm
            && message.replyToMessageId == secondOwnerMessage.messageId
    }))
    let firstPMReply = try #require(messages.first(where: { message in
        message.senderRole == .pm
            && message.replyToMessageId != secondOwnerMessage.messageId
    }))

    #expect(secondPMReply.body.contains("Suggested Portfolio Strategy Brief revision note:"))
    #expect(secondPMReply.body.contains("saved Strategy Brief stays unchanged"))
    #expect(secondPMReply.body != firstPMReply.body)

    #expect(sentMessages.count == 2)
    #expect(sentMessages[0].replyToMessageID == 51)
    #expect(sentMessages[1].replyToMessageID == 52)
    #expect(sentMessages[1].text.contains("Suggested Portfolio Strategy Brief revision note:"))
}

@Test("Telegram receipt-confirmation asks return a concise one-sentence reply")
func telegramReceiptConfirmationAskReturnsConciseReply() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-receipt-confirmation")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 308,
            message: TelegramBotInboundMessage(
                messageId: 53,
                sentAt: Date(timeIntervalSince1970: 1_742_100_230),
                text: "Please reply with one sentence confirming you received my latest Telegram turn.",
                chat: TelegramBotChat(id: "testchatownerthreadd", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreadd", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "Yes, I received your latest Telegram turn.",
                resolution: PMConversationResolutionState(
                    intentClass: .general,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)

    let messages = try await engine.listPMCommunicationMessages()
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt < rhs.sentAt
        }
    let reply = try #require(messages.last)
    let sentMessage = try #require(await service.sentMessages().last)

    #expect(reply.senderRole == .pm)
    #expect(reply.body == "Yes, I received your latest Telegram turn.")
    #expect(sentMessage.replyToMessageID == 53)
    #expect(sentMessage.text == "Yes, I received your latest Telegram turn.")
}

@Test("App-originated PM conversation replies stay in-app and do not send to Telegram by default")
func inAppPMConversationRepliesStayInApp() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-in-app-no-route")
    let service = StubTelegramBotService()
    let engine = makeTelegramBridgeEngine(root: root, service: service)

    let session = try await engine.ensureInAppPMUserCommunicationSession(pmId: "pm-1")
    let outboundMessage = try await engine.createPMCommunicationMessage(
        sessionId: session.sessionId,
        senderRole: .pm,
        senderId: "pm-1",
        body: "This reply stays in the app conversation because the owner started it there.",
        source: .ui
    )

    let sentMessages = await service.sentMessages()
    let storedMessages = try await engine.listPMCommunicationMessages()

    #expect(session.channel == .inApp)
    #expect(outboundMessage.direction == .outgoing)
    #expect(sentMessages.isEmpty)
    #expect(storedMessages.contains(where: { $0.messageId == outboundMessage.messageId }))
}

@Test("Telegram reply delivery failures record an honest system note instead of silently succeeding")
func telegramReplyDeliveryFailuresRecordHonestSystemNote() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-delivery-failure")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 305,
            message: TelegramBotInboundMessage(
                messageId: 46,
                sentAt: Date(timeIntervalSince1970: 1_742_100_206),
                text: "Please give me the PM view on the current setup.",
                chat: TelegramBotChat(id: "testchatownerthreadb", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])
    await service.setSendMessageError(.invalidTelegramResponse)

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreadb", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)

    await #expect(throws: TelegramBridgeError.invalidTelegramResponse) {
        _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    }

    let messages = try await engine.listPMCommunicationMessages()
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.messageId < rhs.messageId
            }
            return lhs.sentAt < rhs.sentAt
        }
    let bridgeStatus = await engine.telegramBridgeStatus()
    let ownerMessage = try #require(messages.first(where: { $0.senderRole == .owner }))
    let pmMessage = try #require(messages.first(where: { $0.senderRole == .pm }))
    let systemMessage = try #require(messages.first(where: { $0.senderRole == .system }))

    #expect(messages.count == 3)
    #expect(ownerMessage.body == "Please give me the PM view on the current setup.")
    #expect(pmMessage.replyToMessageId == ownerMessage.messageId)
    #expect(systemMessage.body.contains("Telegram delivery failed") == true)
    #expect(systemMessage.replyToMessageId == ownerMessage.messageId)
    #expect(bridgeStatus.lastConsumedUpdateId == 305)
    #expect(bridgeStatus.lastOutboundSummary == nil)
}

@Test("Telegram bridge state persists compact routing and poll diagnostics")
func telegramBridgeStatePersistsCompactRoutingAndPollDiagnostics() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-state-store")
    let fileURL = root.appendingPathComponent("telegram_bridge_state.json", isDirectory: false)
    let store = TelegramBridgeStateStore(fileURL: fileURL)

    _ = try await store.save(
        TelegramBridgeState(
            allowlistedOwnerChatId: "testchatstate",
            allowlistedOwnerSessionId: "pm-user-telegram-chat-testchatstate",
            allowlistedOwnerParticipantLabel: "@owneruser",
            lastConsumedUpdateId: 55,
            lastPollAt: Date(timeIntervalSince1970: 1_742_100_300),
            lastPollSummary: "Fetched 1 Telegram update; ingested 1 new message",
            lastBoundChatId: "testchatstate",
            lastBoundSessionId: "pm-user-telegram-chat-testchatstate",
            lastBoundParticipantLabel: "@owneruser",
            lastOutboundAt: Date(timeIntervalSince1970: 1_742_100_320),
            lastOutboundSummary: "Sent Telegram conversation reply to @owneruser · normal alert",
            lastOutboundWakeUpClass: .conversationReply,
            lastOutboundSilent: false,
            lastOutboundReason: "Direct owner-requested reply."
        )
    )

    let reloaded = TelegramBridgeStateStore(fileURL: fileURL)
    let state = await reloaded.load()

    #expect(state.lastConsumedUpdateId == 55)
    #expect(state.allowlistedOwnerChatId == "testchatstate")
    #expect(state.allowlistedOwnerSessionId == "pm-user-telegram-chat-testchatstate")
    #expect(state.lastBoundChatId == "testchatstate")
    #expect(state.lastBoundSessionId == "pm-user-telegram-chat-testchatstate")
    #expect(state.lastOutboundSummary?.contains("Sent Telegram conversation reply") == true)
    #expect(state.lastOutboundWakeUpClass == .conversationReply)
    #expect(state.lastOutboundSilent == false)
    #expect(state.lastOutboundReason == "Direct owner-requested reply.")
}

@Test("Telegram no-change polls skip durable status refresh until heartbeat is due")
func telegramNoChangePollsSkipDurableStatusRefreshUntilHeartbeatIsDue() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-no-change-poll-heartbeat")
    let service = StubTelegramBotService()
    await service.setUpdates([])
    let keyReader = CountingKeyReader(
        values: [
            "\(TelegramBotKeychainStatusProvider.service)|\(TelegramBotKeychainStatusProvider.account)": "TEST_BOT_TOKEN_PLACEHOLDER"
        ]
    )

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatnochange", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service, keyReader: keyReader)

    let first = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let statusAfterFirstPoll = await engine.telegramBridgeStatus()
    let second = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let statusAfterSecondPoll = await engine.telegramBridgeStatus()
    let third = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let diagnostics = await engine.telegramBridgeRuntimeDiagnostics()

    #expect(first.fetchedUpdateCount == 0)
    #expect(first.statusRefreshRecommended == true)
    #expect(second.fetchedUpdateCount == 0)
    #expect(second.statusRefreshRecommended == false)
    #expect(third.fetchedUpdateCount == 0)
    #expect(third.statusRefreshRecommended == false)
    #expect(statusAfterFirstPoll.lastPollAt == Date(timeIntervalSince1970: 1_742_100_500))
    #expect(statusAfterSecondPoll.lastPollAt == statusAfterFirstPoll.lastPollAt)
    #expect(diagnostics.pollCount == 3)
    #expect(diagnostics.noChangePollCount == 3)
    #expect(diagnostics.materialChangePollCount == 0)
    #expect(diagnostics.heartbeatRefreshPollCount == 1)
    #expect(diagnostics.statusRefreshRecommendedPollCount == 1)
    #expect(diagnostics.durableStateSaveCount == 1)
    #expect(diagnostics.pollingTokenKeychainReadCount == 1)
    #expect(diagnostics.pollingTokenCacheHitCount == 2)
    #expect(diagnostics.statusTokenKeychainReadCount == 0)
    #expect(diagnostics.statusTokenCacheHitCount == 2)
    #expect(keyReader.readCount(
        service: TelegramBotKeychainStatusProvider.service,
        account: TelegramBotKeychainStatusProvider.account
    ) == 1)
    #expect(await service.requestedOffsets() == [nil, -5, nil, -5, nil, -5])
}

@Test("Telegram diagnostics expose safe aggregate poll counters through status JSON")
func telegramDiagnosticsExposeSafeAggregatePollCountersThroughStatusJSON() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-status-counters")
    let service = StubTelegramBotService()
    await service.setUpdates([])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatnochange", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)

    let status = await engine.agentControlStatusJSON()
    let object = try #require(status.objectValue)
    let telegramRuntime = try #require(object["telegramBridgeRuntime"]?.objectValue)

    #expect(telegramRuntime["pollCount"] == .number(2))
    #expect(telegramRuntime["noChangePollCount"] == .number(2))
    #expect(telegramRuntime["materialChangePollCount"] == .number(0))
    #expect(telegramRuntime["heartbeatRefreshPollCount"] == .number(1))
    #expect(telegramRuntime["durableStateSaveCount"] == .number(1))
    #expect(telegramRuntime["pollingTokenKeychainReadCount"] == .number(1))
    #expect(telegramRuntime["pollingTokenCacheHitCount"] == .number(1))

    let encoded = try JSONEncoder().encode(status)
    let body = try #require(String(data: encoded, encoding: .utf8))
    #expect(body.contains("TEST_BOT_TOKEN_PLACEHOLDER") == false)
    #expect(body.contains("chat_id") == false)
}

@Test("Telegram explicit approval terms stay low-ambiguity")
func telegramExplicitApprovalTermsStayLowAmbiguity() {
    #expect(parseTelegramPMInboundIntent("Approve") == .ownerApprovalResponse(.approved))
    #expect(parseTelegramPMInboundIntent("Decline") == .ownerApprovalResponse(.rejected))
    #expect(parseTelegramPMInboundIntent("More Work") == .ownerApprovalResponse(.reviewed))
    #expect(parseTelegramPMInboundIntent("yes") == nil)
    #expect(parseTelegramPMInboundIntent("ok") == nil)
    #expect(parseTelegramPMInboundIntent("sounds good") == nil)
}

@Test("Telegram free-form PM questions are not deterministically interpreted")
func telegramFreeFormPMQuestionsAreNotDeterministicallyInterpreted() {
    let reportDetailQuestion = """
    I see short positions when I open the detailed supporting section. For example the latest Technology Analyst report lists Best Short Candidates as SNOW, Unity and INTC. Can you see that?
    """

    #expect(parseTelegramPMInboundIntent(reportDetailQuestion) == nil)
    #expect(parseTelegramPMInboundIntent("What supports this?") == nil)
    #expect(parseTelegramPMInboundIntent("Show me the supporting evidence") == nil)
    #expect(parseTelegramPMInboundIntent("How does this fit the strategy?") == nil)
    #expect(parseTelegramPMInboundIntent("Can you summarize the memo?") == nil)
}

@Test("Telegram exact approval word without pending approval falls back to model conversation")
func telegramExactApprovalWordWithoutPendingApprovalFallsBackToModelConversation() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-approve-no-pending-model")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 307,
            message: TelegramBotInboundMessage(
                messageId: 48,
                sentAt: Date(timeIntervalSince1970: 1_742_100_209),
                text: "Approve",
                chat: TelegramBotChat(id: "testchatownerthreade", firstName: "Owner"),
                from: TelegramBotUser(id: "8899", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatownerthreade", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "I do not see a pending approval to apply, so I’m treating this as a normal PM conversation turn.",
                resolution: PMConversationResolutionState(
                    intentClass: .followUpQuestion,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let synthesisRequest = try #require(await synthesisProvider.lastConversationRequest)
    let sentMessages = await service.sentMessages()

    #expect(result.approvalResponseCount == 0)
    #expect(result.clarificationReplyCount == 0)
    #expect(synthesisRequest.ownerMessageBody == "Approve")
    #expect(sentMessages.first?.text.contains("normal PM conversation turn") == true)
    #expect(sentMessages.first?.text.contains("current PM ask or recommendation linked to this chat") == false)
}

@Test("Telegram approval prompt stays concise and explicit")
func telegramApprovalPromptStaysConciseAndExplicit() {
    let request = PMApprovalRequest(
        approvalRequestId: "approval-1",
        pmId: "pm-1",
        subject: "Review concentration trim",
        rationale: "The position is above target size after the post-earnings gap and now conflicts with the current concentration discipline in the strategy brief.",
        requestedActionSummary: "Decide whether I should advance the trim recommendation.",
        approvedNextStepSummary: "I will route the next bounded proposal review step while keeping proposal and trading authority behind the existing gates.",
        requestType: .portfolioAction,
        status: .pending,
        createdAt: Date(timeIntervalSince1970: 1_742_100_100),
        updatedAt: Date(timeIntervalSince1970: 1_742_100_100)
    )
    let memo = PMApprovalRequestMemoPresentation(
        initiativePosture: .ownerDecisionRequired,
        initiativeSummary: "Owner decision: The next step is ready for direction now.",
        coherence: makePMEventCoherencePresentation(
            posture: .ownerDecisionRequired,
            initiativeSummary: "Owner decision: The next step is ready for direction now."
        ),
        closure: makePMRecommendationClosurePresentation(status: .awaitingOwner),
        requestedAction: "Decide whether I should advance the trim recommendation.",
        whyNow: "Recent price strength pushed the holding beyond the current risk posture.",
        recommendation: "Trim the oversized position rather than adding risk into strength.",
        strategicAlignment: "This keeps concentration aligned with the current strategy brief.",
        portfolioContextSummary: nil,
        evidenceSummary: "The latest analyst memo and current exposure both point the same way.",
        uncertaintySummary: "I still want to confirm that the catalyst window is not widening near-term upside asymmetrically.",
        approvedNextStep: request.approvedNextStepSummary,
        rejectedNextStep: "I will leave the recommendation unapproved and keep it monitor-only.",
        reviewedNextStep: "I will revisit the case with more downside and catalyst work before returning with a narrower recommendation.",
        ownerActionMeaning: "Your response tells the PM whether to advance, stop, or rework the recommendation.",
        boundaryNote: "PM-layer only.",
        supportingSections: []
    )

    let prompt = makeTelegramApprovalRequestPrompt(request: request, memo: memo)
    let lines = prompt.components(separatedBy: CharacterSet.newlines)

    #expect(lines.count <= 5)
    #expect(lines.first?.hasPrefix("Decision required:") == true)
    #expect(prompt.contains("Reply with exactly: Approve, Decline, or More Work."))
    #expect(prompt.count < 520)
}

@Test("Telegram Live order review prompt does not invite Telegram approval")
func telegramLiveOrderReviewPromptDoesNotInviteTelegramApproval() {
    let request = PMApprovalRequest(
        approvalRequestId: "approval-live-telegram-prompt",
        pmId: "pm-1",
        subject: "Review Live order instruction",
        rationale: "The owner asked the PM to prepare a Live order review.",
        requestedActionSummary: "Review whether this Live order instruction should advance.",
        approvedNextStepSummary: "The Live order can route only after in-app owner approval.",
        rejectedNextStepSummary: "I will leave the Live order unapproved.",
        reviewedNextStepSummary: "I will do more work before returning with a Live order review.",
        requestType: .liveOrderReview,
        status: .pending,
        liveOrderReview: PMLiveOrderReviewPayload(
            symbol: "META",
            side: .buy,
            orderType: .market,
            timeInForce: .day,
            notionalAmount: Decimal(10_000),
            instructionSummary: "Buy about $10,000 of META Live at market for today."
        ),
        createdAt: Date(timeIntervalSince1970: 1_742_100_100),
        updatedAt: Date(timeIntervalSince1970: 1_742_100_100)
    )
    let memo = PMApprovalRequestMemoPresentation(
        initiativePosture: .ownerDecisionRequired,
        initiativeSummary: "Owner decision: Live order review is ready for in-app approval.",
        coherence: makePMEventCoherencePresentation(
            posture: .ownerDecisionRequired,
            initiativeSummary: "Owner decision: Live order review is ready for in-app approval."
        ),
        closure: makePMRecommendationClosurePresentation(status: .awaitingOwner),
        requestedAction: "Review whether this Live order instruction should advance.",
        whyNow: "The owner requested a Live order review.",
        recommendation: "Complete the final Live approval in the Mac app.",
        strategicAlignment: "Live execution remains behind owner review.",
        portfolioContextSummary: nil,
        evidenceSummary: nil,
        uncertaintySummary: nil,
        approvedNextStep: request.approvedNextStepSummary,
        rejectedNextStep: request.rejectedNextStepSummary,
        reviewedNextStep: request.reviewedNextStepSummary,
        ownerActionMeaning: "Final Live order approval happens locally in the app.",
        boundaryNote: "Live execution boundary.",
        supportingSections: []
    )

    let prompt = makeTelegramApprovalRequestPrompt(request: request, memo: memo)

    #expect(prompt.contains("Reply with exactly: Approve") == false)
    #expect(prompt.contains("If approved:") == false)
    #expect(prompt.contains("Live order approval happens in Command Center > Your Decisions on the Mac.") == true)
    #expect(prompt.contains("From Telegram, you can reply Decline or More Work.") == true)
    #expect(prompt.contains("No Live order is sent from Telegram approval.") == true)
}

@Test("Telegram prompt framing keeps clarification, FYI, and passive events semantically aligned")
func telegramPromptFramingStaysSemanticallyAligned() {
    let clarifyMemo = PMDecisionMemoPresentation(
        initiativePosture: .clarifyFirst,
        initiativeSummary: "Clarify first: I need one narrower point before I escalate this.",
        coherence: makePMEventCoherencePresentation(
            posture: .clarifyFirst,
            initiativeSummary: "Clarify first: I need one narrower point before I escalate this."
        ),
        closure: makePMRecommendationClosurePresentation(status: .awaitingOwner),
        recommendation: "I need one narrower point on your downside concern.",
        whyNow: "The request is still directionally useful, but it is not specific enough for a bench handoff or recommendation.",
        strategicAlignment: nil,
        recommendedAction: "Tell me which downside path you care about most.",
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: "Which downside path matters most to you here?",
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )
    let informationalMemo = PMDecisionMemoPresentation(
        initiativePosture: .summarizeAndInform,
        initiativeSummary: "Summary only: This is useful context, but not a decision ask.",
        coherence: makePMEventCoherencePresentation(
            posture: .summarizeAndInform,
            initiativeSummary: "Summary only: This is useful context, but not a decision ask."
        ),
        closure: makePMRecommendationClosurePresentation(status: .closedNoFurtherAction),
        recommendation: "The recent change matters enough to keep on your radar.",
        whyNow: "The setup moved, but not enough to justify a fresh owner decision.",
        strategicAlignment: nil,
        recommendedAction: "Keep it on watch.",
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: nil,
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )
    let passiveMemo = PMDecisionMemoPresentation(
        initiativePosture: .analystBenchFirst,
        initiativeSummary: "Bench first: The bench should sharpen this before I interrupt the owner.",
        coherence: makePMEventCoherencePresentation(
            posture: .analystBenchFirst,
            initiativeSummary: "Bench first: The bench should sharpen this before I interrupt the owner."
        ),
        closure: makePMRecommendationClosurePresentation(status: .routedOrInProgress),
        recommendation: "Send this through the bench first.",
        whyNow: "A specialist pass would materially sharpen the answer.",
        strategicAlignment: nil,
        recommendedAction: nil,
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: nil,
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )
    let decision = PMDecisionRecord(
        decisionId: "decision-1",
        pmId: "pm-1",
        title: "Cross-surface coherence",
        summary: "Keep the same meaning across surfaces.",
        decisionType: .recommendation,
        status: .active,
        createdAt: .distantPast,
        updatedAt: .distantPast
    )

    let clarifyPrompt = makeTelegramDecisionPrompt(decision: decision, memo: clarifyMemo)
    let informationalPrompt = makeTelegramDecisionPrompt(decision: decision, memo: informationalMemo)
    let passivePrompt = makeTelegramDecisionPrompt(decision: decision, memo: passiveMemo)

    #expect(clarifyPrompt.contains("Clarification:") == true)
    #expect(clarifyPrompt.contains("Reply with the narrower point") == true)
    #expect(informationalPrompt.contains("FYI:") == true)
    #expect(informationalPrompt.contains("No immediate action is needed.") == true)
    #expect(passivePrompt.contains("Bench first: this PM item stays passive in Telegram by default.") == true)
}

@Test("Telegram wake-up classification keeps approval asks, important updates, quiet info, and passive items distinct")
func telegramWakeUpClassificationKeepsImportantCasesDistinct() {
    let ownerAskMemo = PMDecisionMemoPresentation(
        initiativePosture: .ownerDecisionRequired,
        initiativeSummary: "Owner decision: The next step is decision-ready.",
        coherence: makePMEventCoherencePresentation(
            posture: .ownerDecisionRequired,
            initiativeSummary: "Owner decision: The next step is decision-ready."
        ),
        closure: makePMRecommendationClosurePresentation(status: .awaitingOwner),
        recommendation: "Trim the oversized position.",
        whyNow: "Risk is above the current concentration posture.",
        strategicAlignment: "This stays aligned with the strategy brief.",
        recommendedAction: "Advance a trim recommendation.",
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: "Tell me whether to advance the recommendation now.",
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )
    let noAskMemo = PMDecisionMemoPresentation(
        initiativePosture: .summarizeAndInform,
        initiativeSummary: "Summary only: This is material enough to surface, but not yet a decision ask.",
        coherence: makePMEventCoherencePresentation(
            posture: .summarizeAndInform,
            initiativeSummary: "Summary only: This is material enough to surface, but not yet a decision ask."
        ),
        closure: makePMRecommendationClosurePresentation(status: .closedNoFurtherAction),
        recommendation: "Recent-news review now matters for held names.",
        whyNow: "A materially important news cluster touched current holdings.",
        strategicAlignment: nil,
        recommendedAction: "Review the memo and decide whether to escalate.",
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: nil,
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )
    let routineMemo = PMDecisionMemoPresentation(
        initiativePosture: .stayQuiet,
        initiativeSummary: "Stay quiet: No stronger owner-facing step is justified.",
        coherence: makePMEventCoherencePresentation(
            posture: .stayQuiet,
            initiativeSummary: "Stay quiet: No stronger owner-facing step is justified."
        ),
        closure: makePMRecommendationClosurePresentation(status: .closedNoFurtherAction),
        recommendation: "Keep this monitor-only for now.",
        whyNow: "No stronger PM action is justified.",
        strategicAlignment: nil,
        recommendedAction: nil,
        evidenceSummary: nil,
        uncertaintySummary: nil,
        ownerAsk: nil,
        approvedNextStep: nil,
        boundaryNote: "PM-layer only.",
        relationshipNote: nil,
        supportingSections: []
    )

    let ownerAskDecision = PMDecisionRecord(
        decisionId: "decision-owner-ask",
        pmId: "pm-1",
        title: "Owner-facing trim review",
        summary: "Ask the owner whether to advance the trim recommendation.",
        recommendedAction: "Advance a trim recommendation.",
        ownerAsk: "Tell me whether to advance the recommendation now.",
        decisionType: .recommendation,
        status: .active,
        createdAt: .distantPast,
        updatedAt: .distantPast
    )
    let recentNewsDecision = PMDecisionRecord(
        decisionId: "decision-recent-news",
        pmId: "pm-1",
        title: "Recent news analyst escalation",
        summary: "Recent news may require PM attention.",
        decisionType: .escalation,
        taskId: "recent-news-task-1",
        createdAt: .distantPast,
        updatedAt: .distantPast
    )
    let routineDecision = PMDecisionRecord(
        decisionId: "decision-routine",
        pmId: "pm-1",
        title: "Routine PM note",
        summary: "Background PM reviewing only.",
        decisionType: .recommendation,
        status: .active,
        createdAt: .distantPast,
        updatedAt: .distantPast
    )
    let readinessDecision = PMDecisionRecord(
        decisionId: "decision-readiness",
        pmId: "pm-1",
        title: "Execution readiness blocked",
        summary: "Execution readiness is blocked until market data normalizes.",
        decisionType: .readinessAssessment,
        status: .active,
        createdAt: .distantPast,
        updatedAt: .distantPast
    )

    let recentNewsWakeUp = RecentNewsWakeUpPresentation(
        isRecentNewsWakeUp: true,
        originLabel: "Recent News Analyst",
        rowSummary: "Material recent-news cluster.",
        rowAffectedNames: "Holdings: NVDA",
        rowNextStep: "Review for PM escalation.",
        whatHappened: "Material recent-news cluster.",
        whyItMatters: "It may change the PM posture for a held name.",
        strategyRelevance: nil,
        recommendedNextStep: "Review for PM escalation.",
        pmActionGuidance: "PM review only.",
        affectedHoldings: ["NVDA"],
        affectedWatchlistOnly: []
    )

    #expect(
        classifyTelegramDecisionWakeUpClass(
            decision: ownerAskDecision,
            memo: ownerAskMemo,
            recentNewsWakeUp: nil,
            portfolioRiskWakeUp: nil
        ) == .importantWakeUp
    )
    #expect(
        classifyTelegramDecisionWakeUpClass(
            decision: recentNewsDecision,
            memo: noAskMemo,
            recentNewsWakeUp: recentNewsWakeUp,
            portfolioRiskWakeUp: nil
        ) == .importantWakeUp
    )
    #expect(
        classifyTelegramDecisionWakeUpClass(
            decision: readinessDecision,
            memo: routineMemo,
            recentNewsWakeUp: nil,
            portfolioRiskWakeUp: nil
        ) == .quietInfo
    )
    #expect(
        classifyTelegramDecisionWakeUpClass(
            decision: routineDecision,
            memo: routineMemo,
            recentNewsWakeUp: nil,
            portfolioRiskWakeUp: nil
        ) == .doNotSendProactively
    )
}

@Test("Telegram quiet informational sends use disable_notification and persist wake-up diagnostics")
func telegramQuietInformationalSendsUseDisableNotification() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-quiet-info")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 601,
            message: TelegramBotInboundMessage(
                messageId: 121,
                sentAt: Date(timeIntervalSince1970: 1_742_101_000),
                text: "bind chat",
                chat: TelegramBotChat(id: "testchatfollowupa", firstName: "Owner"),
                from: TelegramBotUser(id: "7711", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatfollowupa", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let session = try #require((try await engine.listPMCommunicationSessions()).first)

    _ = try await engine.createPMCommunicationMessage(
        sessionId: session.sessionId,
        senderRole: .pm,
        senderId: "pm-1",
        body: "Quiet PM update: no immediate action is needed.",
        telegramDelivery: .quietInfo(reason: "Low-urgency PM informational update."),
        source: .ui
    )

    let sentMessages = await service.sentMessages()
    let status = await engine.telegramBridgeStatus()

    #expect(sentMessages.count == 2)
    #expect(sentMessages.last?.disableNotification == true)
    #expect(status.lastOutboundWakeUpClass == .quietInfo)
    #expect(status.lastOutboundSilent == true)
    #expect(status.lastOutboundReason == "Low-urgency PM informational update.")
    #expect(status.lastOutboundSummary?.contains("quiet Telegram informational update") == true)
}

@Test("Telegram approval asks stay high-signal and do not suppress notification")
func telegramApprovalAsksStayHighSignal() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-approval-wakeup")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 701,
            message: TelegramBotInboundMessage(
                messageId: 131,
                sentAt: Date(timeIntervalSince1970: 1_742_101_100),
                text: "bind approval chat",
                chat: TelegramBotChat(id: "testchatfollowupb", firstName: "Owner"),
                from: TelegramBotUser(id: "8822", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatfollowupb", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let session = try #require((try await engine.listPMCommunicationSessions()).first)

    let request = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-telegram-high-signal",
            pmId: "pm-1",
            subject: "Advance trim review",
            rationale: "The holding is above target concentration.",
            requestedActionSummary: "Decide whether I should advance the trim recommendation.",
            approvedNextStepSummary: "I will move to the next bounded review step.",
            requestType: .portfolioAction,
            status: .pending,
            createdAt: Date(timeIntervalSince1970: 1_742_101_110),
            updatedAt: Date(timeIntervalSince1970: 1_742_101_110)
        ),
        source: .ui
    )

    _ = try await engine.sendTelegramApprovalRequestPrompt(
        approvalRequestId: request.approvalRequestId,
        sessionId: session.sessionId,
        source: .ui
    )

    let sentMessages = await service.sentMessages()
    let status = await engine.telegramBridgeStatus()

    #expect(sentMessages.count == 2)
    #expect(sentMessages.last?.disableNotification == false)
    #expect(sentMessages.last?.text.contains("Reply with exactly: Approve, Decline, or More Work.") == true)
    #expect(status.lastOutboundWakeUpClass == .approvalRequired)
    #expect(status.lastOutboundSilent == false)
    #expect(status.lastOutboundSummary?.contains("approval-required Telegram wake-up") == true)
}

@Test("Telegram poll records explicit approval responses through app-owned PM approval records")
func telegramPollRecordsExplicitApprovalResponses() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-explicit-approval")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 401,
            message: TelegramBotInboundMessage(
                messageId: 71,
                sentAt: Date(timeIntervalSince1970: 1_742_100_700),
                text: "hello",
                chat: TelegramBotChat(id: "testchatfollowupc", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatfollowupc", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let session = try #require((try await engine.listPMCommunicationSessions()).first)

    let request = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-telegram-1",
            pmId: "pm-1",
            subject: "Review concentration trim",
            rationale: "The holding is above target concentration after the latest move.",
            requestedActionSummary: "Decide whether I should advance the trim recommendation.",
            approvedNextStepSummary: "I will route the next bounded proposal review step while keeping proposal and trading gates separate.",
            rejectedNextStepSummary: "I will leave the recommendation unapproved and keep it monitor-only.",
            reviewedNextStepSummary: "I will do more downside and catalyst work before coming back.",
            requestType: .portfolioAction,
            status: .pending,
            createdAt: Date(timeIntervalSince1970: 1_742_100_710),
            updatedAt: Date(timeIntervalSince1970: 1_742_100_710)
        ),
        source: .ui
    )
    _ = try await engine.sendTelegramApprovalRequestPrompt(
        approvalRequestId: request.approvalRequestId,
        sessionId: session.sessionId,
        source: .ui
    )

    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 401,
            message: TelegramBotInboundMessage(
                messageId: 71,
                sentAt: Date(timeIntervalSince1970: 1_742_100_700),
                text: "hello",
                chat: TelegramBotChat(id: "testchatfollowupc", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        ),
        TelegramBotUpdate(
            updateId: 402,
            message: TelegramBotInboundMessage(
                messageId: 72,
                sentAt: Date(timeIntervalSince1970: 1_742_100_720),
                text: "Approve",
                chat: TelegramBotChat(id: "testchatfollowupc", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        )
    ])

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let updatedRequest = try await engine.getPMApprovalRequest(id: request.approvalRequestId)
    let sentMessages = await service.sentMessages()

    #expect(result.approvalResponseCount == 1)
    #expect(result.clarificationReplyCount == 1)
    #expect(updatedRequest.ownerResponse == .approved)
    #expect(updatedRequest.status == .resolved)
    #expect(sentMessages.last?.text.contains("Approve recorded.") == true)
}

@Test("Telegram Approve leaves pending Live order review unapproved and unrouted")
func telegramApproveLeavesPendingLiveOrderReviewUnapprovedAndUnrouted() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-live-approve-blocked")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 411,
            message: TelegramBotInboundMessage(
                messageId: 81,
                sentAt: Date(timeIntervalSince1970: 1_742_100_730),
                text: "hello",
                chat: TelegramBotChat(id: "testchatliveapprovea", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatliveapprovea", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let session = try #require((try await engine.listPMCommunicationSessions()).first)

    let request = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-telegram-live-blocked",
            pmId: "pm-1",
            subject: "Review Live order instruction",
            rationale: "The owner asked for a Live order review.",
            requestedActionSummary: "Review whether this Live order instruction should advance.",
            approvedNextStepSummary: "Approval must happen in the Mac app before any Live order can route.",
            rejectedNextStepSummary: "I will leave the Live order unapproved.",
            reviewedNextStepSummary: "I will do more work before returning with a Live review.",
            requestType: .liveOrderReview,
            status: .pending,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                notionalAmount: Decimal(10_000),
                instructionSummary: "Buy about $10,000 of META Live at market for today."
            ),
            createdAt: Date(timeIntervalSince1970: 1_742_100_735),
            updatedAt: Date(timeIntervalSince1970: 1_742_100_735)
        ),
        source: .ui
    )
    _ = try await engine.sendTelegramApprovalRequestPrompt(
        approvalRequestId: request.approvalRequestId,
        sessionId: session.sessionId,
        source: .ui
    )

    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 411,
            message: TelegramBotInboundMessage(
                messageId: 81,
                sentAt: Date(timeIntervalSince1970: 1_742_100_730),
                text: "hello",
                chat: TelegramBotChat(id: "testchatliveapprovea", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        ),
        TelegramBotUpdate(
            updateId: 412,
            message: TelegramBotInboundMessage(
                messageId: 82,
                sentAt: Date(timeIntervalSince1970: 1_742_100_740),
                text: "Approve",
                chat: TelegramBotChat(id: "testchatliveapprovea", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        )
    ])

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let updatedRequest = try await engine.getPMApprovalRequest(id: request.approvalRequestId)
    let sentMessages = await service.sentMessages()

    #expect(result.approvalResponseCount == 0)
    #expect(result.clarificationReplyCount == 1)
    #expect(updatedRequest.status == .pending)
    #expect(updatedRequest.ownerResponse == nil)
    #expect(updatedRequest.ownerRespondedAt == nil)
    #expect(updatedRequest.lastExecutionRoutingAssessment == nil)
    #expect(updatedRequest.liveOrderExecutionLifecycleState == nil)
    #expect(sentMessages.last?.text.contains("Live order approval must be completed in Command Center > Your Decisions on the Mac.") == true)
    #expect(sentMessages.last?.text.contains("I left the Live order review pending.") == true)
    #expect(sentMessages.last?.text.contains("No order was sent.") == true)
}

@Test("Telegram sole pending fallback cannot approve Live order review")
func telegramSolePendingFallbackCannotApproveLiveOrderReview() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-live-approve-single-fallback")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 421,
            message: TelegramBotInboundMessage(
                messageId: 83,
                sentAt: Date(timeIntervalSince1970: 1_742_100_750),
                text: "bind chat",
                chat: TelegramBotChat(id: "testchatliveapproveb", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatliveapproveb", participantLabel: "@owneruser")
    let engine = makeTelegramBridgeEngine(root: root, service: service)
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)

    let request = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-telegram-live-single-fallback",
            pmId: "pm-1",
            subject: "Review Live order instruction",
            rationale: "The owner asked for a Live order review.",
            requestedActionSummary: "Review whether this Live order instruction should advance.",
            requestType: .liveOrderReview,
            status: .pending,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "MSFT",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                quantity: 1,
                instructionSummary: "Buy 1 MSFT Live at market for today."
            ),
            createdAt: Date(timeIntervalSince1970: 1_742_100_755),
            updatedAt: Date(timeIntervalSince1970: 1_742_100_755)
        ),
        source: .ui
    )

    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 421,
            message: TelegramBotInboundMessage(
                messageId: 83,
                sentAt: Date(timeIntervalSince1970: 1_742_100_750),
                text: "bind chat",
                chat: TelegramBotChat(id: "testchatliveapproveb", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        ),
        TelegramBotUpdate(
            updateId: 422,
            message: TelegramBotInboundMessage(
                messageId: 84,
                sentAt: Date(timeIntervalSince1970: 1_742_100_760),
                text: "Approve",
                chat: TelegramBotChat(id: "testchatliveapproveb", firstName: "Owner"),
                from: TelegramBotUser(id: "5511", username: "owneruser")
            )
        )
    ])

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let updatedRequest = try await engine.getPMApprovalRequest(id: request.approvalRequestId)

    #expect(result.approvalResponseCount == 0)
    #expect(result.clarificationReplyCount == 1)
    #expect(updatedRequest.status == .pending)
    #expect(updatedRequest.ownerResponse == nil)
    #expect(updatedRequest.lastExecutionRoutingAssessment == nil)
    #expect(updatedRequest.liveOrderExecutionLifecycleState == nil)
}

@Test("Telegram Decline and More Work for Live review stay non-executing")
func telegramDeclineAndMoreWorkForLiveReviewStayNonExecuting() async throws {
    let cases: [(String, PMApprovalRequestOwnerResponse, PMApprovalRequestStatus)] = [
        ("Decline", .rejected, .resolved),
        ("More Work", .reviewed, .resolved)
    ]

    for (index, testCase) in cases.enumerated() {
        let root = makeTelegramBridgeTempDirectory(name: "telegram-live-\(testCase.0.lowercased().replacingOccurrences(of: " ", with: "-"))")
        let service = StubTelegramBotService()
        let chatID = "testchatlive\(index)"
        await service.setUpdates([
            TelegramBotUpdate(
                updateId: 431 + index * 10,
                message: TelegramBotInboundMessage(
                    messageId: 91 + index * 10,
                    sentAt: Date(timeIntervalSince1970: 1_742_100_770 + Double(index)),
                    text: "bind chat",
                    chat: TelegramBotChat(id: chatID, firstName: "Owner"),
                    from: TelegramBotUser(id: "5511", username: "owneruser")
                )
            )
        ])

        try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: chatID, participantLabel: "@owneruser")
        let engine = makeTelegramBridgeEngine(root: root, service: service)
        _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)

        let request = try await engine.upsertPMApprovalRequest(
            PMApprovalRequest(
                approvalRequestId: "approval-telegram-live-\(index)",
                pmId: "pm-1",
                subject: "Review Live order instruction",
                rationale: "The owner asked for a Live order review.",
                requestedActionSummary: "Review whether this Live order instruction should advance.",
                requestType: .liveOrderReview,
                status: .pending,
                liveOrderReview: PMLiveOrderReviewPayload(
                    symbol: "META",
                    side: .buy,
                    orderType: .market,
                    timeInForce: .day,
                    quantity: 1,
                    instructionSummary: "Buy 1 META Live at market for today."
                ),
                createdAt: Date(timeIntervalSince1970: 1_742_100_780 + Double(index)),
                updatedAt: Date(timeIntervalSince1970: 1_742_100_780 + Double(index))
            ),
            source: .ui
        )

        await service.setUpdates([
            TelegramBotUpdate(
                updateId: 431 + index * 10,
                message: TelegramBotInboundMessage(
                    messageId: 91 + index * 10,
                    sentAt: Date(timeIntervalSince1970: 1_742_100_770 + Double(index)),
                    text: "bind chat",
                    chat: TelegramBotChat(id: chatID, firstName: "Owner"),
                    from: TelegramBotUser(id: "5511", username: "owneruser")
                )
            ),
            TelegramBotUpdate(
                updateId: 432 + index * 10,
                message: TelegramBotInboundMessage(
                    messageId: 92 + index * 10,
                    sentAt: Date(timeIntervalSince1970: 1_742_100_790 + Double(index)),
                    text: testCase.0,
                    chat: TelegramBotChat(id: chatID, firstName: "Owner"),
                    from: TelegramBotUser(id: "5511", username: "owneruser")
                )
            )
        ])

        let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
        let updatedRequest = try await engine.getPMApprovalRequest(id: request.approvalRequestId)

        #expect(result.approvalResponseCount == 1)
        #expect(updatedRequest.status == testCase.2)
        #expect(updatedRequest.ownerResponse == testCase.1)
        #expect(updatedRequest.lastExecutionRoutingAssessment == nil)
        #expect(updatedRequest.liveOrderExecutionLifecycleState == nil)
    }
}

@Test("Telegram support questions use model-backed PM conversation instead of deterministic clarification")
func telegramSupportQuestionsUseModelBackedPMConversation() async throws {
    let root = makeTelegramBridgeTempDirectory(name: "telegram-support-model-backed")
    let service = StubTelegramBotService()
    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 501,
            message: TelegramBotInboundMessage(
                messageId: 91,
                sentAt: Date(timeIntervalSince1970: 1_742_100_800),
                text: "hello",
                chat: TelegramBotChat(id: "testchatfollowupd", firstName: "Owner"),
                from: TelegramBotUser(id: "7711", username: "owneruser")
            )
        )
    ])

    try await seedAuthorizedTelegramOwnerRoute(root: root, chatID: "testchatfollowupd", participantLabel: "@owneruser")
    let synthesisProvider = StubTelegramPMOpenAISynthesisProvider(
        conversationOutputs: [
            PMConversationOpenAISynthesisOutput(
                replyBody: "The support comes from the current concentration, analyst work, and strategy brief, and I’m answering through the normal PM conversation path.",
                resolution: PMConversationResolutionState(
                    intentClass: .followUpQuestion,
                    disposition: .conversationOnly
                )
            )
        ]
    )
    let engine = makeTelegramBridgeEngine(
        root: root,
        service: service,
        openAIKeyStatusProvider: StubTelegramOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        pmOpenAISynthesisProvider: synthesisProvider
    )
    _ = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let session = try #require((try await engine.listPMCommunicationSessions()).first)

    let decision = try await engine.upsertPMDecision(
        PMDecisionRecord(
            decisionId: "decision-telegram-1",
            pmId: "pm-1",
            title: "Trim concentration",
            summary: "Reduce the oversized position rather than adding into the current move.",
            recommendedAction: "Advance a trim recommendation.",
            evidenceSummary: "Current concentration, analyst work, and the strategy brief all point the same way.",
            ownerAsk: "Decide whether I should advance the trim recommendation.",
            approvedNextStepSummary: "I will route the next bounded proposal review step while keeping all trading gates separate.",
            decisionType: .recommendation,
            status: .active,
            createdAt: Date(timeIntervalSince1970: 1_742_100_810),
            updatedAt: Date(timeIntervalSince1970: 1_742_100_810)
        ),
        source: .ui
    )
    let request = try await engine.createPMApprovalRequestFromDecision(
        decisionId: decision.decisionId,
        source: .ui
    )
    _ = try await engine.sendTelegramApprovalRequestPrompt(
        approvalRequestId: request.approvalRequestId,
        sessionId: session.sessionId,
        source: .ui
    )

    await service.setUpdates([
        TelegramBotUpdate(
            updateId: 501,
            message: TelegramBotInboundMessage(
                messageId: 91,
                sentAt: Date(timeIntervalSince1970: 1_742_100_800),
                text: "hello",
                chat: TelegramBotChat(id: "testchatfollowupd", firstName: "Owner"),
                from: TelegramBotUser(id: "7711", username: "owneruser")
            )
        ),
        TelegramBotUpdate(
            updateId: 502,
            message: TelegramBotInboundMessage(
                messageId: 92,
                sentAt: Date(timeIntervalSince1970: 1_742_100_820),
                text: "what supports this",
                chat: TelegramBotChat(id: "testchatfollowupd", firstName: "Owner"),
                from: TelegramBotUser(id: "7711", username: "owneruser")
            )
        )
    ])

    let result = try await engine.pollTelegramUpdates(pmId: "pm-1", source: .ui)
    let sentMessages = await service.sentMessages()
    let synthesisRequest = try #require(await synthesisProvider.lastConversationRequest)
    let reply = try #require(sentMessages.last?.text)

    #expect(result.approvalResponseCount == 0)
    #expect(result.clarificationReplyCount == 0)
    #expect(synthesisRequest.ownerMessageBody == "what supports this")
    #expect(reply.contains("normal PM conversation path"))
    #expect(reply.contains("What supports this:") == false)
    #expect(reply.contains("current PM ask or recommendation linked to this chat") == false)
}

private func makeTelegramBridgeEngine(
    root: URL,
    service: any TelegramBotServing,
    openAIKeyStatusProvider: any OpenAIKeyStatusProviding = StubTelegramOpenAIKeyProvider(),
    pmOpenAISynthesisProvider: any PMOpenAISynthesisProviding = OpenAIResponsesPMSynthesisProvider(),
    keyReader: (any KeyReading)? = nil,
    analystStandingReportStore: AnalystStandingReportStore? = nil,
    analystCharterStore: AnalystCharterStore? = nil,
    analystTaskStore: AnalystTaskStore? = nil,
    analystMemoStore: AnalystMemoStore? = nil,
    analystWorkerLauncher: (any AnalystWorkerLaunching)? = nil
) -> Engine {
    let keychainProvider = KeychainCredentialsProvider(
        keyReader: keyReader ?? StubKeyReader(
            values: [
                "\(TelegramBotKeychainStatusProvider.service)|\(TelegramBotKeychainStatusProvider.account)": "TEST_BOT_TOKEN_PLACEHOLDER"
            ]
        )
    )

    return Engine(
        pmInstructionStore: PMInstructionStore(
            instructionsDirectory: root.appendingPathComponent("instructions", isDirectory: true)
        ),
        pmNotebookStore: PMNotebookStore(
            notebookDirectory: root.appendingPathComponent("notebook", isDirectory: true)
        ),
        pmInteractionMemoryStore: PMInteractionMemoryStore(
            interactionMemoryDirectory: root.appendingPathComponent("interaction_memory", isDirectory: true)
        ),
        pmDecisionStore: PMDecisionStore(
            decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true)
        ),
        pmApprovalRequestStore: PMApprovalRequestStore(
            approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true)
        ),
        pmCommunicationSessionStore: PMCommunicationSessionStore(
            sessionsDirectory: root.appendingPathComponent("sessions", isDirectory: true)
        ),
        pmCommunicationMessageStore: PMCommunicationMessageStore(
            messagesDirectory: root.appendingPathComponent("messages", isDirectory: true)
        ),
        telegramBridgeStateStore: TelegramBridgeStateStore(
            fileURL: root.appendingPathComponent("telegram_bridge_state.json", isDirectory: false)
        ),
        telegramBotService: service,
        pmDelegationStore: PMDelegationStore(
            delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true)
        ),
        analystCharterStore: analystCharterStore ?? AnalystCharterStore(
            chartersDirectory: root.appendingPathComponent("charters", isDirectory: true)
        ),
        analystTaskStore: analystTaskStore ?? AnalystTaskStore(
            tasksDirectory: root.appendingPathComponent("tasks", isDirectory: true)
        ),
        analystMemoStore: analystMemoStore ?? AnalystMemoStore(
            memosDirectory: root.appendingPathComponent("memos", isDirectory: true)
        ),
        analystStandingReportStore: analystStandingReportStore ?? AnalystStandingReportStore(
            reportsDirectory: root.appendingPathComponent("standing_reports", isDirectory: true)
        ),
        openAIKeyStatusProvider: openAIKeyStatusProvider,
        pmOpenAISynthesisProvider: pmOpenAISynthesisProvider,
        analystWorkerLauncher: analystWorkerLauncher ?? CLIAnalystWorkerLauncher(),
        keychainProvider: keychainProvider,
        nowDate: { Date(timeIntervalSince1970: 1_742_100_500) }
    )
}

private struct StubTelegramOpenAIKeyProvider: OpenAIKeyStatusProviding {
    var configured: Bool = false
    var value: String? = nil

    func apiKey() -> String? { value }
    func isConfigured() -> Bool { configured }
}

private actor StubTelegramPMOpenAISynthesisProvider: PMOpenAISynthesisProviding {
    let conversationOutputs: [PMConversationOpenAISynthesisOutput]
    let standingReviewOutput = PMStandingReviewOpenAISynthesisOutput(
        disposition: "worth_monitoring",
        summary: "Unused standing review summary.",
        recommendedAction: "Unused standing review action."
    )
    private(set) var lastConversationRequest: PMConversationOpenAISynthesisRequest?
    private(set) var conversationRequests: [PMConversationOpenAISynthesisRequest] = []
    private var nextConversationOutputIndex = 0

    init(conversationOutputs: [PMConversationOpenAISynthesisOutput]) {
        self.conversationOutputs = conversationOutputs
    }

    func synthesizeConversationReply(
        request: PMConversationOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMConversationOpenAISynthesisOutput {
        _ = apiKey
        lastConversationRequest = request
        conversationRequests.append(request)
        let index = min(nextConversationOutputIndex, max(conversationOutputs.count - 1, 0))
        let output = conversationOutputs[index]
        nextConversationOutputIndex += 1
        return output
    }

    func synthesizeStandingReview(
        request: PMStandingReviewOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> PMStandingReviewOpenAISynthesisOutput {
        _ = request
        _ = apiKey
        return standingReviewOutput
    }
}

private struct StubTelegramAnalystWorkerLauncher: AnalystWorkerLaunching {
    let result: AnalystWorkerLaunchResult

    func runOnce(request: AnalystWorkerLaunchRequest) async throws -> AnalystWorkerLaunchResult {
        _ = request
        return result
    }
}

private func seedAuthorizedTelegramOwnerRoute(
    root: URL,
    chatID: String,
    participantLabel: String
) async throws {
    let store = TelegramBridgeStateStore(
        fileURL: root.appendingPathComponent("telegram_bridge_state.json", isDirectory: false)
    )
    _ = try await store.save(
        TelegramBridgeState(
            allowlistedOwnerChatId: chatID,
            allowlistedOwnerSessionId: "pm-user-telegram-chat-\(chatID)",
            allowlistedOwnerParticipantLabel: participantLabel
        )
    )
}

private func seedTelegramCommunicationSession(
    root: URL,
    chatID: String,
    participantID: String?,
    participantLabel: String,
    updatedAt: Date
) async throws {
    let store = PMCommunicationSessionStore(
        sessionsDirectory: root.appendingPathComponent("sessions", isDirectory: true)
    )
    _ = try await store.upsert(
        PMCommunicationSession(
            sessionId: "pm-user-telegram-chat-\(chatID)",
            channel: .telegram,
            externalConversationId: chatID,
            pmId: "pm-1",
            participantId: participantID,
            participantDisplayName: participantLabel,
            status: .active,
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    )
}

private func makeTelegramBridgeTempDirectory(name: String) -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private struct StubKeyReader: KeyReading {
    let values: [String: String]

    func readKey(service: String, account: String) -> String? {
        values["\(service)|\(account)"]
    }
}

private final class CountingKeyReader: KeyReading, @unchecked Sendable {
    private let values: [String: String]
    private let lock = NSLock()
    private var countsByKey: [String: Int] = [:]

    init(values: [String: String]) {
        self.values = values
    }

    func readKey(service: String, account: String) -> String? {
        let key = "\(service)|\(account)"
        lock.lock()
        countsByKey[key, default: 0] += 1
        lock.unlock()
        return values[key]
    }

    func readCount(service: String, account: String) -> Int {
        let key = "\(service)|\(account)"
        lock.lock()
        let count = countsByKey[key, default: 0]
        lock.unlock()
        return count
    }
}

private actor StubTelegramBotService: TelegramBotServing {
    struct SentMessageCall: Sendable, Equatable {
        let botToken: String
        let chatID: String
        let text: String
        let replyToMessageID: Int?
        let disableNotification: Bool
    }

    private var updates: [TelegramBotUpdate] = []
    private var updatesByOffset: [Int: [TelegramBotUpdate]] = [:]
    private var webhookInfo = TelegramBotWebhookInfo(url: "", pendingUpdateCount: 0)
    private var requestedOffsetsStorage: [Int?] = []
    private var sentMessagesStorage: [SentMessageCall] = []
    private var deleteWebhookCallsStorage: [Bool] = []
    private var sendMessageError: TelegramBridgeError?

    func setUpdates(_ updates: [TelegramBotUpdate]) {
        self.updates = updates
    }

    func setUpdatesByOffset(_ updatesByOffset: [Int: [TelegramBotUpdate]]) {
        self.updatesByOffset = updatesByOffset
    }

    func setWebhookInfo(_ webhookInfo: TelegramBotWebhookInfo) {
        self.webhookInfo = webhookInfo
    }

    func requestedOffsets() -> [Int?] {
        requestedOffsetsStorage
    }

    func sentMessages() -> [SentMessageCall] {
        sentMessagesStorage
    }

    func deleteWebhookCalls() -> [Bool] {
        deleteWebhookCallsStorage
    }

    func setSendMessageError(_ error: TelegramBridgeError?) {
        sendMessageError = error
    }

    func getUpdates(botToken: String, offset: Int?) async throws -> [TelegramBotUpdate] {
        requestedOffsetsStorage.append(offset)
        if let offset, let updates = updatesByOffset[offset] {
            return updates
        }
        return updates
    }

    func getWebhookInfo(botToken: String) async throws -> TelegramBotWebhookInfo {
        webhookInfo
    }

    func deleteWebhook(botToken: String, dropPendingUpdates: Bool) async throws -> Bool {
        deleteWebhookCallsStorage.append(dropPendingUpdates)
        webhookInfo = TelegramBotWebhookInfo(
            url: "",
            pendingUpdateCount: 0,
            allowedUpdates: webhookInfo.allowedUpdates
        )
        return true
    }

    func sendMessage(
        botToken: String,
        chatID: String,
        text: String,
        replyToMessageID: Int?,
        disableNotification: Bool
    ) async throws -> TelegramBotSentMessage {
        if let sendMessageError {
            throw sendMessageError
        }
        sentMessagesStorage.append(
            SentMessageCall(
                botToken: botToken,
                chatID: chatID,
                text: text,
                replyToMessageID: replyToMessageID,
                disableNotification: disableNotification
            )
        )
        return TelegramBotSentMessage(
            messageId: 901,
            chatId: chatID,
            sentAt: Date(timeIntervalSince1970: 1_742_100_600)
        )
    }
}
