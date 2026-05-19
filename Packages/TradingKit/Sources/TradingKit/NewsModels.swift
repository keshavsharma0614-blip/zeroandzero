import Foundation

public struct NewsEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        eventId
    }

    public let eventId: String
    public let source: String
    public let title: String
    public let url: String?
    public let publishedAt: Date
    public let receivedAt: Date
    public let summary: String?
    public let rawSymbolHints: [String]
    public let tags: [String]
    public let payloadVersion: Int

    public init(
        eventId: String,
        source: String,
        title: String,
        url: String? = nil,
        publishedAt: Date,
        receivedAt: Date,
        summary: String? = nil,
        rawSymbolHints: [String] = [],
        tags: [String] = [],
        payloadVersion: Int = 1
    ) {
        self.eventId = eventId
        self.source = source
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.receivedAt = receivedAt
        self.summary = summary
        self.rawSymbolHints = rawSymbolHints
        self.tags = tags
        self.payloadVersion = payloadVersion
    }
}

public struct RSSFeed: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var url: String
    public var enabled: Bool
    public var pollIntervalSec: Int
    public var tags: [String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        url: String,
        enabled: Bool = true,
        pollIntervalSec: Int = 300,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.enabled = enabled
        self.pollIntervalSec = max(15, pollIntervalSec)
        self.tags = tags
    }
}

public struct RSSFeedSummary: Sendable, Equatable {
    public var enabledCount: Int
    public var disabledCount: Int
    public var lastPollStatus: String?

    public init(
        enabledCount: Int = 0,
        disabledCount: Int = 0,
        lastPollStatus: String? = nil
    ) {
        self.enabledCount = enabledCount
        self.disabledCount = disabledCount
        self.lastPollStatus = lastPollStatus
    }
}

public struct NewsIngestStatus: Sendable, Equatable {
    public var rssStatus: String
    public var alpacaStatus: String
    public var secStatus: String
    public var lastUpdatedAt: Date?

    public init(
        rssStatus: String = "idle",
        alpacaStatus: String = "idle",
        secStatus: String = "idle",
        lastUpdatedAt: Date? = nil
    ) {
        self.rssStatus = rssStatus
        self.alpacaStatus = alpacaStatus
        self.secStatus = secStatus
        self.lastUpdatedAt = lastUpdatedAt
    }
}
