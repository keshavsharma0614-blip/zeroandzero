import Foundation

public struct CredentialsStatus: Equatable, Sendable {
    public let paperPublicFound: Bool
    public let paperSecretFound: Bool
    public let paperKeysFound: Bool
    public let livePublicFound: Bool
    public let liveSecretFound: Bool
    public let liveKeysFound: Bool
    public let telegramConfigured: Bool
    public let openAIConfigured: Bool
    public let openAIStatusSummary: String?
    public let lastChecked: Date?

    public init(
        paperPublicFound: Bool,
        paperSecretFound: Bool,
        livePublicFound: Bool,
        liveSecretFound: Bool,
        telegramConfigured: Bool = false,
        openAIConfigured: Bool = false,
        openAIStatusSummary: String? = nil,
        lastChecked: Date? = nil
    ) {
        self.paperPublicFound = paperPublicFound
        self.paperSecretFound = paperSecretFound
        self.paperKeysFound = paperPublicFound && paperSecretFound
        self.livePublicFound = livePublicFound
        self.liveSecretFound = liveSecretFound
        self.liveKeysFound = livePublicFound && liveSecretFound
        self.telegramConfigured = telegramConfigured
        self.openAIConfigured = openAIConfigured
        self.openAIStatusSummary = openAIStatusSummary
        self.lastChecked = lastChecked
    }
}
