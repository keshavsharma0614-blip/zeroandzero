import Foundation

public struct TelegramBotKeychainStatusProvider: Sendable {
    public static let service = "telegram.api.key"
    public static let account = "algo-trading"

    private let keychainProvider: KeychainCredentialsProvider

    public init(keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider()) {
        self.keychainProvider = keychainProvider
    }

    public func botToken() -> String? {
        keychainProvider.readKey(service: Self.service, account: Self.account)
    }

    public func isConfigured() -> Bool {
        guard let token = botToken() else { return false }
        return token.isEmpty == false
    }
}

public enum TelegramBridgeError: Error, Sendable, Equatable {
    case missingBotToken
    case invalidBaseURL
    case invalidTelegramResponse
    case invalidChatID
    case telegramSessionNotBound(sessionId: String)
    case unsupportedInboundMessage
    case proactiveSendSuppressed(reason: String)
}

extension TelegramBridgeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingBotToken:
            return "Telegram bot token is not available in Keychain."
        case .invalidBaseURL:
            return "Telegram transport base URL is invalid."
        case .invalidTelegramResponse:
            return "Telegram returned an invalid response."
        case .invalidChatID:
            return "Telegram chat routing is not bound for this PM communication session."
        case .telegramSessionNotBound(let sessionId):
            return "Telegram PM communication session is not bound to a learned chat: \(sessionId)."
        case .unsupportedInboundMessage:
            return "Telegram transport currently supports text messages only."
        case .proactiveSendSuppressed(let reason):
            return reason
        }
    }
}

public enum TelegramPMWakeUpClass: String, Codable, Sendable, Equatable, CaseIterable {
    case approvalRequired = "approval_required"
    case importantWakeUp = "important_wake_up"
    case quietInfo = "quiet_info"
    case conversationReply = "conversation_reply"
    case doNotSendProactively = "do_not_send_proactively"
}

public struct TelegramPMDeliveryBehavior: Sendable, Equatable {
    public var wakeUpClass: TelegramPMWakeUpClass
    public var disableNotification: Bool
    public var reason: String?

    public init(
        wakeUpClass: TelegramPMWakeUpClass,
        disableNotification: Bool,
        reason: String? = nil
    ) {
        self.wakeUpClass = wakeUpClass
        self.disableNotification = disableNotification
        self.reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static let conversationReply = TelegramPMDeliveryBehavior(
        wakeUpClass: .conversationReply,
        disableNotification: false
    )

    public static func approvalRequired(reason: String? = nil) -> TelegramPMDeliveryBehavior {
        TelegramPMDeliveryBehavior(
            wakeUpClass: .approvalRequired,
            disableNotification: false,
            reason: reason
        )
    }

    public static func importantWakeUp(reason: String? = nil) -> TelegramPMDeliveryBehavior {
        TelegramPMDeliveryBehavior(
            wakeUpClass: .importantWakeUp,
            disableNotification: false,
            reason: reason
        )
    }

    public static func quietInfo(reason: String? = nil) -> TelegramPMDeliveryBehavior {
        TelegramPMDeliveryBehavior(
            wakeUpClass: .quietInfo,
            disableNotification: true,
            reason: reason
        )
    }

    public static func doNotSendProactively(reason: String? = nil) -> TelegramPMDeliveryBehavior {
        TelegramPMDeliveryBehavior(
            wakeUpClass: .doNotSendProactively,
            disableNotification: true,
            reason: reason
        )
    }
}

public struct TelegramBotUser: Codable, Sendable, Equatable {
    public let id: String
    public let username: String?
    public let firstName: String?
    public let lastName: String?

    public init(
        id: String,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) {
        self.id = id
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
    }

    public var displayName: String {
        if let username, username.isEmpty == false {
            return "@\(username)"
        }
        let parts = [firstName, lastName]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        if parts.isEmpty == false {
            return parts.joined(separator: " ")
        }
        return "Telegram User"
    }
}

public struct TelegramBotChat: Codable, Sendable, Equatable {
    public let id: String
    public let title: String?
    public let username: String?
    public let firstName: String?
    public let lastName: String?

    public init(
        id: String,
        title: String? = nil,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
    }

    public var displayName: String {
        if let title, title.isEmpty == false {
            return title
        }
        if let username, username.isEmpty == false {
            return "@\(username)"
        }
        let parts = [firstName, lastName]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        if parts.isEmpty == false {
            return parts.joined(separator: " ")
        }
        return "Telegram Chat"
    }
}

public struct TelegramBotInboundMessageReference: Codable, Sendable, Equatable {
    public let messageId: Int

    public init(messageId: Int) {
        self.messageId = messageId
    }
}

public struct TelegramBotInboundMessage: Codable, Sendable, Equatable {
    public let messageId: Int
    public let sentAt: Date
    public let text: String?
    public let chat: TelegramBotChat
    public let from: TelegramBotUser?
    public let replyToMessage: TelegramBotInboundMessageReference?

    public init(
        messageId: Int,
        sentAt: Date,
        text: String?,
        chat: TelegramBotChat,
        from: TelegramBotUser?,
        replyToMessage: TelegramBotInboundMessageReference? = nil
    ) {
        self.messageId = messageId
        self.sentAt = sentAt
        self.text = text
        self.chat = chat
        self.from = from
        self.replyToMessage = replyToMessage
    }
}

public struct TelegramBotUpdate: Codable, Sendable, Equatable, Identifiable {
    public var id: Int { updateId }

    public let updateId: Int
    public let message: TelegramBotInboundMessage?

    public init(updateId: Int, message: TelegramBotInboundMessage?) {
        self.updateId = updateId
        self.message = message
    }
}

public struct TelegramBotSentMessage: Codable, Sendable, Equatable {
    public let messageId: Int
    public let chatId: String
    public let sentAt: Date

    public init(messageId: Int, chatId: String, sentAt: Date) {
        self.messageId = messageId
        self.chatId = chatId
        self.sentAt = sentAt
    }
}

public struct TelegramBotWebhookInfo: Codable, Sendable, Equatable {
    public let url: String
    public let pendingUpdateCount: Int
    public let lastErrorDate: Date?
    public let lastErrorMessage: String?
    public let allowedUpdates: [String]

    public init(
        url: String,
        pendingUpdateCount: Int,
        lastErrorDate: Date? = nil,
        lastErrorMessage: String? = nil,
        allowedUpdates: [String] = []
    ) {
        self.url = url
        self.pendingUpdateCount = pendingUpdateCount
        self.lastErrorDate = lastErrorDate
        self.lastErrorMessage = lastErrorMessage
        self.allowedUpdates = allowedUpdates
    }

    public var hasWebhook: Bool {
        url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

public enum TelegramBotRequestBuilder {
    public static let baseURL = URL(string: "https://api.telegram.org")!
    public static let requestTimeoutInterval: TimeInterval = 15
    public static let pollAllowedUpdates = ["message"]

    public static func makeGetUpdatesRequest(
        botToken: String,
        offset: Int?,
        timeoutSec: Int = 0,
        baseURL: URL = baseURL
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("bot\(botToken)/getUpdates"),
            resolvingAgainstBaseURL: false
        ) else {
            throw TelegramBridgeError.invalidBaseURL
        }

        var queryItems: [URLQueryItem] = []
        if let offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        if timeoutSec > 0 {
            queryItems.append(URLQueryItem(name: "timeout", value: String(timeoutSec)))
        }
        let allowedUpdatesJSON = try allowedUpdatesJSONString(pollAllowedUpdates)
        queryItems.append(URLQueryItem(name: "allowed_updates", value: allowedUpdatesJSON))
        if queryItems.isEmpty == false {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw TelegramBridgeError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeoutInterval
        return request
    }

    public static func makeGetWebhookInfoRequest(
        botToken: String,
        baseURL: URL = baseURL
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("bot\(botToken)/getWebhookInfo")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeoutInterval
        return request
    }

    public static func makeDeleteWebhookRequest(
        botToken: String,
        dropPendingUpdates: Bool,
        baseURL: URL = baseURL
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("bot\(botToken)/deleteWebhook")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeoutInterval
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(DeleteWebhookBody(dropPendingUpdates: dropPendingUpdates))
        return request
    }

    public static func makeSendMessageRequest(
        botToken: String,
        chatID: String,
        text: String,
        replyToMessageID: Int? = nil,
        disableNotification: Bool = false,
        baseURL: URL = baseURL
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("bot\(botToken)/sendMessage")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeoutInterval

        let body = SendMessageBody(
            chatId: chatID,
            text: text,
            replyToMessageId: replyToMessageID,
            disableNotification: disableNotification ? true : nil
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        return request
    }

    private struct SendMessageBody: Encodable {
        let chatId: String
        let text: String
        let replyToMessageId: Int?
        let disableNotification: Bool?
    }

    private struct DeleteWebhookBody: Encodable {
        let dropPendingUpdates: Bool
    }

    private static func allowedUpdatesJSONString(_ values: [String]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: values)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TelegramBridgeError.invalidTelegramResponse
        }
        return json
    }
}

public protocol TelegramBotServing: Sendable {
    func getUpdates(botToken: String, offset: Int?) async throws -> [TelegramBotUpdate]
    func getWebhookInfo(botToken: String) async throws -> TelegramBotWebhookInfo
    func deleteWebhook(botToken: String, dropPendingUpdates: Bool) async throws -> Bool
    func sendMessage(
        botToken: String,
        chatID: String,
        text: String,
        replyToMessageID: Int?,
        disableNotification: Bool
    ) async throws -> TelegramBotSentMessage
}

public struct URLSessionTelegramBotClient: TelegramBotServing, Sendable {
    private let session: any HTTPDataSessioning
    private let baseURL: URL

    public init(
        session: any HTTPDataSessioning = URLSession.shared,
        baseURL: URL = TelegramBotRequestBuilder.baseURL
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func getUpdates(botToken: String, offset: Int?) async throws -> [TelegramBotUpdate] {
        let request = try TelegramBotRequestBuilder.makeGetUpdatesRequest(
            botToken: botToken,
            offset: offset,
            baseURL: baseURL
        )
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
        let envelope = try decodeEnvelope([TelegramBotUpdateDTO].self, from: data)
        return envelope.result?.map { $0.mapTelegramUpdate() } ?? []
    }

    public func getWebhookInfo(botToken: String) async throws -> TelegramBotWebhookInfo {
        let request = try TelegramBotRequestBuilder.makeGetWebhookInfoRequest(
            botToken: botToken,
            baseURL: baseURL
        )
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
        let envelope = try decodeEnvelope(TelegramBotWebhookInfoDTO.self, from: data)
        guard let result = envelope.result else {
            throw TelegramBridgeError.invalidTelegramResponse
        }
        return result.mapWebhookInfo()
    }

    public func deleteWebhook(botToken: String, dropPendingUpdates: Bool) async throws -> Bool {
        let request = try TelegramBotRequestBuilder.makeDeleteWebhookRequest(
            botToken: botToken,
            dropPendingUpdates: dropPendingUpdates,
            baseURL: baseURL
        )
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
        let envelope = try decodeEnvelope(Bool.self, from: data)
        guard let result = envelope.result else {
            throw TelegramBridgeError.invalidTelegramResponse
        }
        return result
    }

    public func sendMessage(
        botToken: String,
        chatID: String,
        text: String,
        replyToMessageID: Int?,
        disableNotification: Bool
    ) async throws -> TelegramBotSentMessage {
        let request = try TelegramBotRequestBuilder.makeSendMessageRequest(
            botToken: botToken,
            chatID: chatID,
            text: text,
            replyToMessageID: replyToMessageID,
            disableNotification: disableNotification,
            baseURL: baseURL
        )
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
        let envelope = try decodeEnvelope(TelegramBotSentMessageDTO.self, from: data)
        guard let result = envelope.result else {
            throw TelegramBridgeError.invalidTelegramResponse
        }
        return result.mapSentMessage()
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw TelegramBridgeError.invalidTelegramResponse
        }
    }

    private func decodeEnvelope<Result: Decodable>(_ type: Result.Type, from data: Data) throws -> TelegramResponseEnvelope<Result> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let envelope = try? decoder.decode(TelegramResponseEnvelope<Result>.self, from: data),
              envelope.ok,
              let result = envelope.result else {
            throw TelegramBridgeError.invalidTelegramResponse
        }
        return TelegramResponseEnvelope(ok: true, result: result)
    }
}

public struct TelegramBridgeState: Codable, Sendable, Equatable {
    public var allowlistedOwnerChatId: String?
    public var allowlistedOwnerSessionId: String?
    public var allowlistedOwnerParticipantLabel: String?
    public var lastConsumedUpdateId: Int?
    public var lastPollAt: Date?
    public var lastPollSummary: String?
    public var lastRequestedOffset: Int?
    public var lastHighestFetchedUpdateId: Int?
    public var lastRecoveryTriggered: Bool
    public var lastRecoveryOffset: Int?
    public var lastWebhookPresent: Bool
    public var lastWebhookPendingUpdateCount: Int?
    public var lastWebhookLastErrorMessage: String?
    public var lastBoundChatId: String?
    public var lastBoundSessionId: String?
    public var lastBoundParticipantLabel: String?
    public var lastOutboundAt: Date?
    public var lastOutboundSummary: String?
    public var lastOutboundWakeUpClass: TelegramPMWakeUpClass?
    public var lastOutboundSilent: Bool?
    public var lastOutboundReason: String?
    public var unauthorizedInboundCount: Int
    public var lastUnauthorizedInboundAt: Date?
    public var lastUnauthorizedChatId: String?
    public var lastUnauthorizedParticipantLabel: String?

    public init(
        allowlistedOwnerChatId: String? = nil,
        allowlistedOwnerSessionId: String? = nil,
        allowlistedOwnerParticipantLabel: String? = nil,
        lastConsumedUpdateId: Int? = nil,
        lastPollAt: Date? = nil,
        lastPollSummary: String? = nil,
        lastRequestedOffset: Int? = nil,
        lastHighestFetchedUpdateId: Int? = nil,
        lastRecoveryTriggered: Bool = false,
        lastRecoveryOffset: Int? = nil,
        lastWebhookPresent: Bool = false,
        lastWebhookPendingUpdateCount: Int? = nil,
        lastWebhookLastErrorMessage: String? = nil,
        lastBoundChatId: String? = nil,
        lastBoundSessionId: String? = nil,
        lastBoundParticipantLabel: String? = nil,
        lastOutboundAt: Date? = nil,
        lastOutboundSummary: String? = nil,
        lastOutboundWakeUpClass: TelegramPMWakeUpClass? = nil,
        lastOutboundSilent: Bool? = nil,
        lastOutboundReason: String? = nil,
        unauthorizedInboundCount: Int = 0,
        lastUnauthorizedInboundAt: Date? = nil,
        lastUnauthorizedChatId: String? = nil,
        lastUnauthorizedParticipantLabel: String? = nil
    ) {
        self.allowlistedOwnerChatId = allowlistedOwnerChatId
        self.allowlistedOwnerSessionId = allowlistedOwnerSessionId
        self.allowlistedOwnerParticipantLabel = allowlistedOwnerParticipantLabel
        self.lastConsumedUpdateId = lastConsumedUpdateId
        self.lastPollAt = lastPollAt
        self.lastPollSummary = lastPollSummary
        self.lastRequestedOffset = lastRequestedOffset
        self.lastHighestFetchedUpdateId = lastHighestFetchedUpdateId
        self.lastRecoveryTriggered = lastRecoveryTriggered
        self.lastRecoveryOffset = lastRecoveryOffset
        self.lastWebhookPresent = lastWebhookPresent
        self.lastWebhookPendingUpdateCount = lastWebhookPendingUpdateCount
        self.lastWebhookLastErrorMessage = lastWebhookLastErrorMessage
        self.lastBoundChatId = lastBoundChatId
        self.lastBoundSessionId = lastBoundSessionId
        self.lastBoundParticipantLabel = lastBoundParticipantLabel
        self.lastOutboundAt = lastOutboundAt
        self.lastOutboundSummary = lastOutboundSummary
        self.lastOutboundWakeUpClass = lastOutboundWakeUpClass
        self.lastOutboundSilent = lastOutboundSilent
        self.lastOutboundReason = lastOutboundReason
        self.unauthorizedInboundCount = unauthorizedInboundCount
        self.lastUnauthorizedInboundAt = lastUnauthorizedInboundAt
        self.lastUnauthorizedChatId = lastUnauthorizedChatId
        self.lastUnauthorizedParticipantLabel = lastUnauthorizedParticipantLabel
    }
}

public struct TelegramBridgeStatus: Sendable, Equatable {
    public var tokenConfigured: Bool
    public var allowlistedOwnerChatId: String?
    public var allowlistedOwnerSessionId: String?
    public var allowlistedOwnerParticipantLabel: String?
    public var lastConsumedUpdateId: Int?
    public var lastPollAt: Date?
    public var lastPollSummary: String?
    public var lastRequestedOffset: Int?
    public var lastHighestFetchedUpdateId: Int?
    public var lastRecoveryTriggered: Bool
    public var lastRecoveryOffset: Int?
    public var lastWebhookPresent: Bool
    public var lastWebhookPendingUpdateCount: Int?
    public var lastWebhookLastErrorMessage: String?
    public var lastBoundChatId: String?
    public var lastBoundSessionId: String?
    public var lastBoundParticipantLabel: String?
    public var lastOutboundAt: Date?
    public var lastOutboundSummary: String?
    public var lastOutboundWakeUpClass: TelegramPMWakeUpClass?
    public var lastOutboundSilent: Bool?
    public var lastOutboundReason: String?
    public var unauthorizedInboundCount: Int
    public var lastUnauthorizedInboundAt: Date?
    public var lastUnauthorizedChatId: String?
    public var lastUnauthorizedParticipantLabel: String?

    public init(
        tokenConfigured: Bool,
        allowlistedOwnerChatId: String? = nil,
        allowlistedOwnerSessionId: String? = nil,
        allowlistedOwnerParticipantLabel: String? = nil,
        lastConsumedUpdateId: Int? = nil,
        lastPollAt: Date? = nil,
        lastPollSummary: String? = nil,
        lastRequestedOffset: Int? = nil,
        lastHighestFetchedUpdateId: Int? = nil,
        lastRecoveryTriggered: Bool = false,
        lastRecoveryOffset: Int? = nil,
        lastWebhookPresent: Bool = false,
        lastWebhookPendingUpdateCount: Int? = nil,
        lastWebhookLastErrorMessage: String? = nil,
        lastBoundChatId: String? = nil,
        lastBoundSessionId: String? = nil,
        lastBoundParticipantLabel: String? = nil,
        lastOutboundAt: Date? = nil,
        lastOutboundSummary: String? = nil,
        lastOutboundWakeUpClass: TelegramPMWakeUpClass? = nil,
        lastOutboundSilent: Bool? = nil,
        lastOutboundReason: String? = nil,
        unauthorizedInboundCount: Int = 0,
        lastUnauthorizedInboundAt: Date? = nil,
        lastUnauthorizedChatId: String? = nil,
        lastUnauthorizedParticipantLabel: String? = nil
    ) {
        self.tokenConfigured = tokenConfigured
        self.allowlistedOwnerChatId = allowlistedOwnerChatId
        self.allowlistedOwnerSessionId = allowlistedOwnerSessionId
        self.allowlistedOwnerParticipantLabel = allowlistedOwnerParticipantLabel
        self.lastConsumedUpdateId = lastConsumedUpdateId
        self.lastPollAt = lastPollAt
        self.lastPollSummary = lastPollSummary
        self.lastRequestedOffset = lastRequestedOffset
        self.lastHighestFetchedUpdateId = lastHighestFetchedUpdateId
        self.lastRecoveryTriggered = lastRecoveryTriggered
        self.lastRecoveryOffset = lastRecoveryOffset
        self.lastWebhookPresent = lastWebhookPresent
        self.lastWebhookPendingUpdateCount = lastWebhookPendingUpdateCount
        self.lastWebhookLastErrorMessage = lastWebhookLastErrorMessage
        self.lastBoundChatId = lastBoundChatId
        self.lastBoundSessionId = lastBoundSessionId
        self.lastBoundParticipantLabel = lastBoundParticipantLabel
        self.lastOutboundAt = lastOutboundAt
        self.lastOutboundSummary = lastOutboundSummary
        self.lastOutboundWakeUpClass = lastOutboundWakeUpClass
        self.lastOutboundSilent = lastOutboundSilent
        self.lastOutboundReason = lastOutboundReason
        self.unauthorizedInboundCount = unauthorizedInboundCount
        self.lastUnauthorizedInboundAt = lastUnauthorizedInboundAt
        self.lastUnauthorizedChatId = lastUnauthorizedChatId
        self.lastUnauthorizedParticipantLabel = lastUnauthorizedParticipantLabel
    }
}

public struct TelegramBridgePollResult: Sendable, Equatable {
    public var fetchedUpdateCount: Int
    public var ingestedMessageCount: Int
    public var duplicateUpdateCount: Int
    public var skippedUnsupportedCount: Int
    public var unauthorizedIgnoredCount: Int
    public var approvalResponseCount: Int
    public var clarificationReplyCount: Int
    public var requestedOffset: Int?
    public var highestFetchedUpdateId: Int?
    public var recoveryTriggered: Bool
    public var recoveryOffset: Int?
    public var webhookPresent: Bool
    public var webhookPendingUpdateCount: Int?
    public var lastConsumedUpdateId: Int?
    public var allowlistedOwnerChatId: String?
    public var allowlistedOwnerSessionId: String?
    public var boundChatId: String?
    public var boundSessionId: String?
    public var statusRefreshRecommended: Bool

    public init(
        fetchedUpdateCount: Int,
        ingestedMessageCount: Int,
        duplicateUpdateCount: Int,
        skippedUnsupportedCount: Int,
        unauthorizedIgnoredCount: Int = 0,
        approvalResponseCount: Int = 0,
        clarificationReplyCount: Int = 0,
        requestedOffset: Int? = nil,
        highestFetchedUpdateId: Int? = nil,
        recoveryTriggered: Bool = false,
        recoveryOffset: Int? = nil,
        webhookPresent: Bool = false,
        webhookPendingUpdateCount: Int? = nil,
        lastConsumedUpdateId: Int?,
        allowlistedOwnerChatId: String?,
        allowlistedOwnerSessionId: String?,
        boundChatId: String?,
        boundSessionId: String?,
        statusRefreshRecommended: Bool = true
    ) {
        self.fetchedUpdateCount = fetchedUpdateCount
        self.ingestedMessageCount = ingestedMessageCount
        self.duplicateUpdateCount = duplicateUpdateCount
        self.skippedUnsupportedCount = skippedUnsupportedCount
        self.unauthorizedIgnoredCount = unauthorizedIgnoredCount
        self.approvalResponseCount = approvalResponseCount
        self.clarificationReplyCount = clarificationReplyCount
        self.requestedOffset = requestedOffset
        self.highestFetchedUpdateId = highestFetchedUpdateId
        self.recoveryTriggered = recoveryTriggered
        self.recoveryOffset = recoveryOffset
        self.webhookPresent = webhookPresent
        self.webhookPendingUpdateCount = webhookPendingUpdateCount
        self.lastConsumedUpdateId = lastConsumedUpdateId
        self.allowlistedOwnerChatId = allowlistedOwnerChatId
        self.allowlistedOwnerSessionId = allowlistedOwnerSessionId
        self.boundChatId = boundChatId
        self.boundSessionId = boundSessionId
        self.statusRefreshRecommended = statusRefreshRecommended
    }
}

public struct TelegramBridgeRuntimeDiagnostics: Sendable, Equatable {
    public var pollCount: Int
    public var noChangePollCount: Int
    public var materialChangePollCount: Int
    public var communicationChangePollCount: Int
    public var heartbeatRefreshPollCount: Int
    public var statusRefreshRecommendedPollCount: Int
    public var durableStateSaveCount: Int
    public var pollingTokenKeychainReadCount: Int
    public var pollingTokenCacheHitCount: Int
    public var pollingTokenMissingThrottleCount: Int
    public var statusTokenKeychainReadCount: Int
    public var statusTokenCacheHitCount: Int
    public var outboundTokenKeychainReadCount: Int
    public var outboundTokenCacheHitCount: Int
    public var missingBotTokenCount: Int

    public init(
        pollCount: Int = 0,
        noChangePollCount: Int = 0,
        materialChangePollCount: Int = 0,
        communicationChangePollCount: Int = 0,
        heartbeatRefreshPollCount: Int = 0,
        statusRefreshRecommendedPollCount: Int = 0,
        durableStateSaveCount: Int = 0,
        pollingTokenKeychainReadCount: Int = 0,
        pollingTokenCacheHitCount: Int = 0,
        pollingTokenMissingThrottleCount: Int = 0,
        statusTokenKeychainReadCount: Int = 0,
        statusTokenCacheHitCount: Int = 0,
        outboundTokenKeychainReadCount: Int = 0,
        outboundTokenCacheHitCount: Int = 0,
        missingBotTokenCount: Int = 0
    ) {
        self.pollCount = pollCount
        self.noChangePollCount = noChangePollCount
        self.materialChangePollCount = materialChangePollCount
        self.communicationChangePollCount = communicationChangePollCount
        self.heartbeatRefreshPollCount = heartbeatRefreshPollCount
        self.statusRefreshRecommendedPollCount = statusRefreshRecommendedPollCount
        self.durableStateSaveCount = durableStateSaveCount
        self.pollingTokenKeychainReadCount = pollingTokenKeychainReadCount
        self.pollingTokenCacheHitCount = pollingTokenCacheHitCount
        self.pollingTokenMissingThrottleCount = pollingTokenMissingThrottleCount
        self.statusTokenKeychainReadCount = statusTokenKeychainReadCount
        self.statusTokenCacheHitCount = statusTokenCacheHitCount
        self.outboundTokenKeychainReadCount = outboundTokenKeychainReadCount
        self.outboundTokenCacheHitCount = outboundTokenCacheHitCount
        self.missingBotTokenCount = missingBotTokenCount
    }
}

public enum TelegramBridgeStateStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidDocument
}

public actor TelegramBridgeStateStore {
    private struct PersistedBridgeStateV1: Codable {
        let schemaVersion: Int
        let state: TelegramBridgeState
    }

    private struct PersistedSchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private let fileManager: FileManager
    private let fileURL: URL

    private var loaded = false
    private var cachedState = TelegramBridgeState()
    private var loadDiagnostics: [String] = []

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
            ?? AppSupportPaths.rootDirectory()
            .appendingPathComponent("pm", isDirectory: true)
            .appendingPathComponent("telegram_bridge_state.json", isDirectory: false)
        self.fileManager = fileManager
    }

    public func load() -> TelegramBridgeState {
        loadIfNeeded()
        return cachedState
    }

    @discardableResult
    public func save(_ state: TelegramBridgeState) throws -> TelegramBridgeState {
        loadIfNeeded()
        cachedState = state
        try persist(state)
        return state
    }

    public func drainLoadDiagnostics() -> [String] {
        let diagnostics = loadDiagnostics
        loadDiagnostics.removeAll()
        return diagnostics
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard fileManager.fileExists(atPath: fileURL.path) else {
            cachedState = TelegramBridgeState()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cachedState = try Self.decodeState(from: data)
        } catch let error as TelegramBridgeStateStoreError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                loadDiagnostics.append(
                    "telegram bridge state fallback defaults code=unsupported_schema_version version=\(version)"
                )
            case .invalidDocument:
                loadDiagnostics.append(
                    "telegram bridge state fallback defaults code=invalid_document"
                )
            }
            cachedState = TelegramBridgeState()
        } catch {
            loadDiagnostics.append(
                "telegram bridge state fallback defaults code=io_failure"
            )
            cachedState = TelegramBridgeState()
        }
    }

    private func persist(_ state: TelegramBridgeState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let wrapped = PersistedBridgeStateV1(schemaVersion: 1, state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        let data = try encoder.encode(wrapped)
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func decodeState(from data: Data) throws -> TelegramBridgeState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy

        if let probe = try? decoder.decode(PersistedSchemaProbe.self, from: data),
           let schemaVersion = probe.schemaVersion {
            guard schemaVersion == 1 else {
                throw TelegramBridgeStateStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            do {
                return try decoder.decode(PersistedBridgeStateV1.self, from: data).state
            } catch {
                throw TelegramBridgeStateStoreError.invalidDocument
            }
        }

        do {
            return try decoder.decode(TelegramBridgeState.self, from: data)
        } catch {
            throw TelegramBridgeStateStoreError.invalidDocument
        }
    }
}

private struct TelegramResponseEnvelope<Result: Decodable>: Decodable {
    let ok: Bool
    let result: Result?
}

private struct TelegramBotUpdateDTO: Decodable {
    let updateId: Int
    let message: TelegramBotInboundMessageDTO?

    func mapTelegramUpdate() -> TelegramBotUpdate {
        TelegramBotUpdate(
            updateId: updateId,
            message: message?.mapInboundMessage()
        )
    }
}

private struct TelegramBotInboundMessageDTO: Decodable {
    let messageId: Int
    let date: Int
    let text: String?
    let chat: TelegramBotChatDTO
    let from: TelegramBotUserDTO?
    let replyToMessage: TelegramBotInboundMessageReferenceDTO?

    func mapInboundMessage() -> TelegramBotInboundMessage {
        TelegramBotInboundMessage(
            messageId: messageId,
            sentAt: Date(timeIntervalSince1970: TimeInterval(date)),
            text: text,
            chat: chat.mapChat(),
            from: from?.mapUser(),
            replyToMessage: replyToMessage?.mapReference()
        )
    }
}

private struct TelegramBotInboundMessageReferenceDTO: Decodable {
    let messageId: Int

    func mapReference() -> TelegramBotInboundMessageReference {
        TelegramBotInboundMessageReference(messageId: messageId)
    }
}

private struct TelegramBotChatDTO: Decodable {
    let id: Int64
    let title: String?
    let username: String?
    let firstName: String?
    let lastName: String?

    func mapChat() -> TelegramBotChat {
        TelegramBotChat(
            id: String(id),
            title: title,
            username: username,
            firstName: firstName,
            lastName: lastName
        )
    }
}

private struct TelegramBotUserDTO: Decodable {
    let id: Int64
    let username: String?
    let firstName: String?
    let lastName: String?

    func mapUser() -> TelegramBotUser {
        TelegramBotUser(
            id: String(id),
            username: username,
            firstName: firstName,
            lastName: lastName
        )
    }
}

private struct TelegramBotSentMessageDTO: Decodable {
    let messageId: Int
    let date: Int
    let chat: TelegramBotChatDTO

    func mapSentMessage() -> TelegramBotSentMessage {
        TelegramBotSentMessage(
            messageId: messageId,
            chatId: String(chat.id),
            sentAt: Date(timeIntervalSince1970: TimeInterval(date))
        )
    }
}

private struct TelegramBotWebhookInfoDTO: Decodable {
    let url: String
    let pendingUpdateCount: Int
    let lastErrorDate: Int?
    let lastErrorMessage: String?
    let allowedUpdates: [String]?

    func mapWebhookInfo() -> TelegramBotWebhookInfo {
        TelegramBotWebhookInfo(
            url: url,
            pendingUpdateCount: pendingUpdateCount,
            lastErrorDate: lastErrorDate.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            lastErrorMessage: lastErrorMessage,
            allowedUpdates: allowedUpdates ?? []
        )
    }
}
