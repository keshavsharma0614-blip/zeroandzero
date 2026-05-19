import Foundation
import Testing
@testable import TradingKit

@Test("RSS parser + event factory are deterministic")
func rssParserDeterministic() throws {
    let xml = """
    <rss version=\"2.0\">
      <channel>
        <title>Example Feed</title>
        <item>
          <title>Fed speaks on rates</title>
          <link>https://example.com/fed-1</link>
          <guid>fed-1</guid>
          <pubDate>Tue, 02 Jan 2024 15:04:05 +0000</pubDate>
          <description>AAPL and MSFT mentioned.</description>
        </item>
      </channel>
    </rss>
    """

    let items = RSSParser.parse(data: Data(xml.utf8))
    #expect(items.count == 1)
    let item = try #require(items.first)

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let eventA = NewsEventFactory.makeFromRSS(
        source: "rss_fed",
        feedTags: ["macro"],
        item: item,
        now: now
    )
    let eventB = NewsEventFactory.makeFromRSS(
        source: "rss_fed",
        feedTags: ["macro"],
        item: item,
        now: now
    )

    #expect(eventA.eventId == eventB.eventId)
    #expect(eventA.rawSymbolHints.contains("AAPL"))
}

@Test("RSS parser skips items with invalid pubDate and emits diagnostics")
func rssParserSkipsInvalidPubDate() throws {
    let xml = """
    <rss version=\"2.0\">
      <channel>
        <item>
          <title>Invalid date item</title>
          <link>https://example.com/invalid</link>
          <guid>invalid-1</guid>
          <pubDate>not-a-real-date</pubDate>
        </item>
        <item>
          <title>Valid date item</title>
          <link>https://example.com/valid</link>
          <guid>valid-1</guid>
          <pubDate>Tue, 02 Jan 2024 15:04:05 +0000</pubDate>
        </item>
      </channel>
    </rss>
    """

    let parsed = RSSParser.parseWithDiagnostics(data: Data(xml.utf8))
    #expect(parsed.items.count == 1)
    #expect(parsed.items.first?.guid == "valid-1")
    #expect(parsed.diagnostics.contains { $0.contains("invalid_pub_date") })
}

@Test("RSS request construction includes compatibility headers")
func rssRequestConstructionIncludesCompatibilityHeaders() throws {
    let url = try #require(URL(string: "https://example.com/feed.xml"))
    let request = URLSessionRSSFetcher.makeRequest(
        url: url,
        userAgent: "AlgoTradingMac/1.0 (TradingKit RSS Poller)"
    )

    #expect(request.httpMethod == "GET")
    #expect(request.timeoutInterval == 20)
    #expect(request.value(forHTTPHeaderField: "User-Agent") == "AlgoTradingMac/1.0 (TradingKit RSS Poller)")
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/rss+xml, application/xml;q=0.9, */*;q=0.8")
}

@Test("Alpaca news client decodes current numeric-id payload shape")
func alpacaNewsClientDecodesCurrentNumericIDPayloadShape() async throws {
    let payload = """
    {
      "news": [
        {
          "id": 24918784,
          "headline": "Example market news",
          "summary": null,
          "author": "Benzinga Newsdesk",
          "created_at": "2022-01-05T22:00:37Z",
          "updated_at": "2022-01-05T22:00:38Z",
          "url": "https://www.benzinga.com/example",
          "content": "<p>redacted body</p>",
          "symbols": ["CRSR"],
          "source": "benzinga",
          "images": []
        }
      ]
    }
    """
    let client = makeAlpacaNewsClient(statusCode: 200, body: Data(payload.utf8))

    let items = try await client.fetchLatest(limit: 10)

    #expect(items.count == 1)
    #expect(items.first?.id == "24918784")
    #expect(items.first?.headline == "Example market news")
    #expect(items.first?.summary == nil)
    #expect(items.first?.symbols == ["CRSR"])
    #expect(items.first?.createdAt != nil)
}

@Test("Alpaca news client decodes empty news wrapper")
func alpacaNewsClientDecodesEmptyNewsWrapper() async throws {
    let client = makeAlpacaNewsClient(statusCode: 200, body: Data(#"{"news":[]}"#.utf8))

    let items = try await client.fetchLatest(limit: 10)

    #expect(items.isEmpty)
}

@Test("Alpaca news client classifies status-200 non-news message envelopes")
func alpacaNewsClientClassifiesStatus200NonNewsMessageEnvelope() async throws {
    let client = makeAlpacaNewsClient(
        statusCode: 200,
        body: Data(#"{"message":"news access is unavailable for this account"}"#.utf8)
    )

    do {
        _ = try await client.fetchLatest(limit: 10)
        Issue.record("Expected Alpaca news non-news envelope to throw a request failure.")
    } catch let error as AlpacaAPIError {
        #expect(error.httpStatus == 200)
        #expect(error.alpacaMessage?.contains("non-news message envelope") == true)
    } catch {
        Issue.record("Expected AlpacaAPIError, got \(error).")
    }
}

@Test("SEC request construction includes compatibility headers")
func secRequestConstructionIncludesCompatibilityHeaders() throws {
    let url = try #require(URL(string: "https://data.sec.gov/submissions/CIK0000320193.json"))
    let request = URLSessionSECFetcher.makeRequest(
        url: url,
        userAgent: SECEDGARClient.defaultUserAgent
    )

    #expect(request.httpMethod == "GET")
    #expect(request.timeoutInterval == 20)
    #expect(request.value(forHTTPHeaderField: "User-Agent") == SECEDGARClient.defaultUserAgent)
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json, text/json;q=0.9, */*;q=0.8")
}

@Test("RSS parser reports fatal malformed XML distinctly")
func rssParserFatalMalformedXML() throws {
    let xml = "<rss><channel><item><title>broken"
    let parsed = RSSParser.parseWithDiagnostics(data: Data(xml.utf8))

    #expect(parsed.items.isEmpty)
    #expect(parsed.fatalError != nil)
    #expect(parsed.diagnostics.contains { $0.contains("rss parse failed") })
}

@Test("RSSFeedStore supports v0 decode and CRUD")
func rssFeedStoreLegacyAndCRUD() async throws {
    let tempRoot = makeTempDirectory(name: "rss-feed-store")
    let fileURL = tempRoot.appendingPathComponent("rss_feeds.json")

    let legacy: [RSSFeed] = [
        RSSFeed(
            id: "feed-legacy",
            name: "Legacy",
            url: "https://example.com/legacy.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: ["legacy"]
        )
    ]
    let legacyData = try JSONEncoder().encode(legacy)
    try legacyData.write(to: fileURL)

    let store = RSSFeedStore(fileURL: fileURL)
    let loaded = try await store.listFeeds()
    #expect(loaded.count == 1)
    #expect(loaded.first?.id == "feed-legacy")

    _ = try await store.upsert(
        RSSFeed(
            id: "feed-new",
            name: "New",
            url: "https://example.com/new.xml",
            enabled: false,
            pollIntervalSec: 120,
            tags: []
        )
    )
    var afterInsert = try await store.listFeeds()
    #expect(afterInsert.count == 2)

    try await store.remove(id: "feed-new")
    afterInsert = try await store.listFeeds()
    #expect(afterInsert.count == 1)

    let persistedText = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(persistedText.contains("\"schemaVersion\" : 1"))
}

@Test("RSSFeedStore updates existing feed instead of creating duplicates")
func rssFeedStoreUpdatesExistingFeed() async throws {
    let tempRoot = makeTempDirectory(name: "rss-feed-update")
    let fileURL = tempRoot.appendingPathComponent("rss_feeds.json")
    let store = RSSFeedStore(fileURL: fileURL)

    _ = try await store.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: ["macro"]
        )
    )
    _ = try await store.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed Updated",
            url: "https://example.com/fed-fixed.xml",
            enabled: false,
            pollIntervalSec: 600,
            tags: ["macro", "rates"]
        )
    )

    let feeds = try await store.listFeeds()
    #expect(feeds.count == 1)
    #expect(feeds.first?.name == "Fed Updated")
    #expect(feeds.first?.url == "https://example.com/fed-fixed.xml")
    #expect(feeds.first?.enabled == false)
    #expect(feeds.first?.pollIntervalSec == 600)
}

@Test("RSSFeedStore preserves persisted pollIntervalSec when loading schema v1 feeds")
func rssFeedStorePreservesPersistedLegacyCadenceField() async throws {
    let tempRoot = makeTempDirectory(name: "rss-feed-v1-compat")
    let fileURL = tempRoot.appendingPathComponent("rss_feeds.json")
    let wrapped = """
    {
      "schemaVersion": 1,
      "feeds": [
        {
          "id": "feed-compat",
          "name": "Compat Feed",
          "url": "https://example.com/compat.xml",
          "enabled": true,
          "pollIntervalSec": 900,
          "tags": ["macro"]
        }
      ]
    }
    """
    try wrapped.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = RSSFeedStore(fileURL: fileURL)
    let feeds = try await store.listFeeds()

    #expect(feeds.count == 1)
    #expect(feeds.first?.id == "feed-compat")
    #expect(feeds.first?.pollIntervalSec == 900)
}

@Test("RSSFeedStore validates required fields and http(s) URL")
func rssFeedStoreValidatesFields() async throws {
    let tempRoot = makeTempDirectory(name: "rss-feed-validation")
    let fileURL = tempRoot.appendingPathComponent("rss_feeds.json")
    let store = RSSFeedStore(fileURL: fileURL)

    do {
        _ = try await store.upsert(
            RSSFeed(
                id: "bad-feed",
                name: "Broken",
                url: "ftp://example.com/feed.xml",
                enabled: true,
                pollIntervalSec: 300,
                tags: []
            )
        )
        Issue.record("Expected invalid feed URL to throw.")
    } catch let error as RSSFeedStoreError {
        guard case .invalidFeed(let message) = error else {
            Issue.record("Unexpected RSS feed error: \(error)")
            return
        }
        #expect(message.contains("valid http(s) URL"))
    }

    do {
        _ = try await store.upsert(
            RSSFeed(
                id: "missing-name",
                name: "   ",
                url: "https://example.com/feed.xml",
                enabled: true,
                pollIntervalSec: 300,
                tags: []
            )
        )
        Issue.record("Expected blank feed name to throw.")
    } catch let error as RSSFeedStoreError {
        guard case .invalidFeed(let message) = error else {
            Issue.record("Unexpected RSS feed error: \(error)")
            return
        }
        #expect(message.contains("name is required"))
    }
}

@Test("RSSFeedStore does not reseed defaults over an existing invalid persisted feed file")
func rssFeedStoreDoesNotReseedDefaultsOverExistingInvalidFile() async throws {
    let tempRoot = makeTempDirectory(name: "rss-feed-invalid-existing")
    let fileURL = tempRoot.appendingPathComponent("rss_feeds.json")
    let original = """
    {
      "schemaVersion": 999,
      "feeds": []
    }
    """
    try original.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = RSSFeedStore(fileURL: fileURL)
    let feeds = try await store.seedDefaultsIfStoreMissing()

    #expect(feeds.isEmpty)
    #expect(try String(contentsOf: fileURL, encoding: .utf8) == original)

    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
}

@Test("BuiltInNewsSourcesSettingsStore defaults to enabled and persists schema v1")
func builtInNewsSourcesSettingsStorePersistsAndDefaults() async throws {
    let tempRoot = makeTempDirectory(name: "news-source-settings")
    let fileURL = tempRoot.appendingPathComponent("news_source_settings.json")
    let store = BuiltInNewsSourcesSettingsStore(fileURL: fileURL)

    let defaultSettings = await store.load()
    #expect(defaultSettings.alpacaNewsEnabled == true)

    _ = try await store.save(BuiltInNewsSourcesSettings(alpacaNewsEnabled: false))
    let reloadedStore = BuiltInNewsSourcesSettingsStore(fileURL: fileURL)
    let reloaded = await reloadedStore.load()
    #expect(reloaded.alpacaNewsEnabled == false)

    let persistedText = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(persistedText.contains("\"schemaVersion\" : 1"))
}

@Test("BuiltInNewsSourcesSettingsStore loads legacy v0 and falls back on unknown schema")
func builtInNewsSourcesSettingsStoreLegacyAndFallback() async throws {
    let tempRoot = makeTempDirectory(name: "news-source-settings-legacy")
    let fileURL = tempRoot.appendingPathComponent("news_source_settings.json")

    let legacyData = try JSONEncoder().encode(
        BuiltInNewsSourcesSettings(alpacaNewsEnabled: false)
    )
    try legacyData.write(to: fileURL)

    let legacyStore = BuiltInNewsSourcesSettingsStore(fileURL: fileURL)
    let legacyLoaded = await legacyStore.load()
    #expect(legacyLoaded.alpacaNewsEnabled == false)

    let unknownText = """
    {
      "schemaVersion": 99,
      "settings": {
        "alpacaNewsEnabled": false
      }
    }
    """
    try Data(unknownText.utf8).write(to: fileURL, options: [.atomic])

    let fallbackStore = BuiltInNewsSourcesSettingsStore(fileURL: fileURL)
    let fallback = await fallbackStore.load()
    #expect(fallback.alpacaNewsEnabled == true)
    let diagnostics = await fallbackStore.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
}

@Test("SEC EDGAR client resolves watchlist issuers and normalizes supported filings")
func secEDGARClientResolvesWatchlistAndNormalizesFilings() async throws {
    let client = SECEDGARClient(
        fetcher: ConfigurableMockSECFetcher { url, _ in
            switch url.lastPathComponent {
            case "company_tickers.json":
                let payload = """
                {
                  "0": { "cik_str": 320193, "ticker": "AAPL", "title": "Apple Inc." },
                  "1": { "cik_str": 789019, "ticker": "MSFT", "title": "Microsoft Corp" }
                }
                """
                return SECFetchResponse(statusCode: 200, data: Data(payload.utf8))
            case "CIK0000320193.json":
                let payload = """
                {
                  "cik": "0000320193",
                  "name": "Apple Inc.",
                  "filings": {
                    "recent": {
                      "form": ["8-K", "S-8", "10-Q"],
                      "filingDate": ["2026-03-10", "2026-03-09", "2026-03-08"],
                      "acceptanceDateTime": ["2026-03-10T12:30:00.000Z", "2026-03-09T12:30:00.000Z", "2026-03-08T12:30:00.000Z"],
                      "accessionNumber": ["0000320193-26-000001", "0000320193-26-000002", "0000320193-26-000003"],
                      "primaryDocument": ["a8k.htm", "as8.htm", "a10q.htm"],
                      "primaryDocDescription": ["Current report", "Registration statement", "Quarterly report"]
                    }
                  }
                }
                """
                return SECFetchResponse(statusCode: 200, data: Data(payload.utf8))
            default:
                Issue.record("Unexpected SEC URL: \(url.absoluteString)")
                return SECFetchResponse(statusCode: 404, data: Data())
            }
        }
    )

    let result = await client.fetchRecentFilings(
        for: ["AAPL", "AAPL240119C00190000", "unknown"]
    )

    #expect(result.requestedSymbols == ["AAPL", "UNKNOWN"])
    #expect(result.resolvedSymbols == ["AAPL"])
    #expect(result.failedSymbols == ["UNKNOWN"])
    #expect(result.filings.count == 2)
    #expect(result.filings.allSatisfy { $0.formType != "S-8" })
    #expect(result.diagnostics.contains { $0.contains("mapping unavailable symbol=UNKNOWN") })

    let event = NewsEventFactory.makeFromSECFiling(
        filing: try #require(result.filings.first),
        now: Date(timeIntervalSince1970: 1_700_000_000)
    )
    #expect(event.source == "sec_edgar")
    #expect(event.title.contains("filed"))
    #expect(event.summary?.contains("SEC") == true)
    #expect(event.rawSymbolHints == ["AAPL"])
}

@Test("SEC EDGAR client surfaces malformed submissions payload as bounded diagnostics")
func secEDGARClientMalformedPayloadIsBounded() async throws {
    let client = SECEDGARClient(
        fetcher: ConfigurableMockSECFetcher { url, _ in
            switch url.lastPathComponent {
            case "company_tickers.json":
                let payload = """
                {
                  "0": { "cik_str": 320193, "ticker": "AAPL", "title": "Apple Inc." }
                }
                """
                return SECFetchResponse(statusCode: 200, data: Data(payload.utf8))
            case "CIK0000320193.json":
                return SECFetchResponse(statusCode: 200, data: Data("{\"broken\":".utf8))
            default:
                return SECFetchResponse(statusCode: 404, data: Data())
            }
        }
    )

    let result = await client.fetchRecentFilings(for: ["AAPL"])
    #expect(result.filings.isEmpty)
    #expect(result.failedSymbols == ["AAPL"])
    #expect(result.diagnostics.count == 1)
    #expect(result.diagnostics.first?.contains("sec submissions failed symbol=AAPL") == true)
    #expect(result.diagnostics.first?.contains("decode failure") == true)
}

@Test("NewsStore dedupes and skips corrupt lines")
func newsStoreDedupeAndCorruptLine() async throws {
    let tempRoot = makeTempDirectory(name: "news-store")
    let newsDir = tempRoot.appendingPathComponent("news", isDirectory: true)
    let store = NewsStore(newsDirectory: newsDir)

    let published = Date(timeIntervalSince1970: 1_700_000_000)
    let event = NewsEvent(
        eventId: "evt-1",
        source: "rss_fed",
        title: "Fed headline",
        url: "https://example.com/fed",
        publishedAt: published,
        receivedAt: published,
        summary: "summary",
        rawSymbolHints: ["AAPL"],
        tags: ["macro"],
        payloadVersion: 1
    )

    let firstAppend = try await store.append([event])
    #expect(firstAppend.inserted == 1)
    #expect(firstAppend.duplicates == 0)

    let secondAppend = try await store.append([event])
    #expect(secondAppend.inserted == 0)
    #expect(secondAppend.duplicates == 1)

    let fileURL = newsDir.appendingPathComponent("news_events_2023-11-14.jsonl")
    let handle = try FileHandle(forWritingTo: fileURL)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("{this-is-corrupt}\n".utf8))
    try handle.close()

    let recent = try await store.listRecent(limit: 10)
    #expect(recent.count == 1)
    let diagnostics = await store.drainLoadDiagnostics()
    #expect(diagnostics.contains { $0.contains("invalid_document") })
}

@Test("NewsStore clamps future-dated publishedAt to receivedAt for active news persistence")
func newsStoreClampsFutureDatedItemsToPullTime() async throws {
    let tempRoot = makeTempDirectory(name: "news-store-future-date-clamp")
    let newsDir = tempRoot.appendingPathComponent("news", isDirectory: true)
    let store = NewsStore(newsDirectory: newsDir)

    let receivedAt = Date(timeIntervalSince1970: 1_743_374_400) // 2025-03-29T12:00:00Z
    let futurePublishedAt = Date(timeIntervalSince1970: 1_746_828_800) // 2025-05-08T12:00:00Z
    let event = NewsEvent(
        eventId: "evt-future",
        source: "rss_cepr_events",
        title: "Future conference item",
        url: "https://example.com/cepr",
        publishedAt: futurePublishedAt,
        receivedAt: receivedAt,
        summary: "Future-dated feed item",
        rawSymbolHints: [],
        tags: [],
        payloadVersion: 1
    )

    let appended = try await store.append([event])
    #expect(appended.inserted == 1)

    let recent = try await store.listRecent(limit: 10)
    let stored = try #require(recent.first)
    #expect(stored.publishedAt == receivedAt)
    #expect(stored.receivedAt == receivedAt)

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    let receivedDayFile = newsDir.appendingPathComponent("news_events_\(formatter.string(from: receivedAt)).jsonl")
    #expect(FileManager.default.fileExists(atPath: receivedDayFile.path))
    let futureDayFile = newsDir.appendingPathComponent("news_events_\(formatter.string(from: futurePublishedAt)).jsonl")
    #expect(FileManager.default.fileExists(atPath: futureDayFile.path) == false)
}

@Test("NewsStore bounded recent listing avoids decoding all historical news files")
func newsStoreBoundedRecentListingAvoidsFullHistoryDecode() async throws {
    let tempRoot = makeTempDirectory(name: "news-store-bounded-recent")
    let newsDir = tempRoot.appendingPathComponent("news", isDirectory: true)
    let store = NewsStore(newsDirectory: newsDir)
    let base = Date(timeIntervalSince1970: 1_762_000_000)

    var events: [NewsEvent] = []
    for dayOffset in 0..<90 {
        for itemOffset in 0..<12 {
            let publishedAt = base.addingTimeInterval(-Double(dayOffset) * 86_400 + Double(itemOffset))
            events.append(
                NewsEvent(
                    eventId: "event-\(dayOffset)-\(itemOffset)",
                    source: "rss_memory_test",
                    title: "Headline \(dayOffset)-\(itemOffset)",
                    publishedAt: publishedAt,
                    receivedAt: publishedAt
                )
            )
        }
    }

    _ = try await store.append(events)

    let reloaded = NewsStore(newsDirectory: newsDir)
    let recent = try await reloaded.listRecent(limit: 10)
    let diagnostics = await reloaded.runtimeDiagnosticsSnapshot()

    #expect(recent.count == 10)
    #expect(diagnostics.knownEventIDLoadCount == 0)
    #expect(diagnostics.listRecentRequestCount == 1)
    #expect(diagnostics.listRecentFileReadCount == 1)
    #expect(diagnostics.listRecentDecodedLineCount == 12)
    #expect(diagnostics.listRecentDecodedLineCount < events.count)
}

@Test("Engine listNews purges orphaned removed-feed RSS news from active news and analyst baseline")
func engineListNewsPurgesOrphanedRemovedFeedNews() async throws {
    let tempRoot = makeTempDirectory(name: "rss-orphaned-news-cleanup")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-engadget",
            name: "Engadget",
            url: "https://example.com/engadget.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: []
        )
    )

    let receivedAt = Date(timeIntervalSince1970: 1_743_374_400)
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "cepr-1",
            source: "rss_cepr_events",
            title: "CEPR Future Event",
            url: "https://cepr.org/events/item",
            publishedAt: Date(timeIntervalSince1970: 1_746_828_800),
            receivedAt: receivedAt
        ),
        NewsEvent(
            eventId: "engadget-1",
            source: "rss_engadget",
            title: "Engadget headline",
            url: "https://www.engadget.com/item",
            publishedAt: receivedAt.addingTimeInterval(-300),
            receivedAt: receivedAt
        ),
        NewsEvent(
            eventId: "alpaca-1",
            source: "alpaca_news",
            title: "Alpaca baseline item",
            url: "https://example.com/alpaca",
            publishedAt: receivedAt.addingTimeInterval(-600),
            receivedAt: receivedAt
        )
    ])

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )

    let recent = try await engine.listNews(limit: 10)
    #expect(recent.contains(where: { $0.source == "rss_cepr_events" }) == false)
    #expect(recent.contains(where: { $0.source == "rss_engadget" }))
    #expect(recent.contains(where: { $0.source == "alpaca_news" }))

    let reloadedNewsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let reloaded = try await reloadedNewsStore.listRecent(limit: 10)
    #expect(reloaded.contains(where: { $0.source == "rss_cepr_events" }) == false)
    #expect(reloaded.contains(where: { $0.source == "rss_engadget" }))
}

@Test("Engine skips RSS news source cleanup when configured feed sources are unchanged")
func engineSkipsRSSNewsCleanupWhenFeedSourcesUnchanged() async throws {
    let tempRoot = makeTempDirectory(name: "rss-news-cleanup-skip")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-fed",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: []
        )
    )

    let publishedAt = Date(timeIntervalSince1970: 1_743_374_400)
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "fed-1",
            source: "rss_fed",
            title: "Fed headline",
            publishedAt: publishedAt,
            receivedAt: publishedAt
        )
    ])

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )

    _ = try await engine.listNews(limit: 10)
    _ = try await engine.listNews(limit: 10)

    let status = await engine.agentControlStatusJSON()
    guard case .object(let payload) = status,
          case .object(let newsRuntime)? = payload["newsRuntime"] else {
        Issue.record("Expected agent-control status to include news runtime diagnostics.")
        return
    }

    #expect(newsRuntime["cleanupRequestCount"] == .number(2))
    #expect(newsRuntime["cleanupFullScanCount"] == .number(1))
    #expect(newsRuntime["cleanupSkippedNoSourceChangeCount"] == .number(1))
    #expect(newsRuntime["purgeRSSSourcesCount"] == .number(1))
}

@Test("Renaming an RSS feed purges the old source-scoped news without deleting new-source or non-RSS events")
func renamingRSSFeedPurgesOldSourceScopedNewsOnly() async throws {
    let tempRoot = makeTempDirectory(name: "rss-feed-rename-purges-old-news")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    let feed = try await rssStore.upsert(
        RSSFeed(
            id: "feed-fed",
            name: "Fed Old",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: []
        )
    )

    let publishedAt = Date(timeIntervalSince1970: 1_743_374_400)
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "old-source",
            source: "rss_fed_old",
            title: "Old source headline",
            publishedAt: publishedAt,
            receivedAt: publishedAt
        ),
        NewsEvent(
            eventId: "new-source",
            source: "rss_fed_new",
            title: "New source headline",
            publishedAt: publishedAt.addingTimeInterval(1),
            receivedAt: publishedAt.addingTimeInterval(1)
        ),
        NewsEvent(
            eventId: "sec-source",
            source: "sec_edgar",
            title: "SEC headline",
            publishedAt: publishedAt.addingTimeInterval(2),
            receivedAt: publishedAt.addingTimeInterval(2)
        )
    ])

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )

    _ = try await engine.updateRSSFeed(
        RSSFeed(
            id: feed.id,
            name: "Fed New",
            url: feed.url,
            enabled: true,
            pollIntervalSec: feed.pollIntervalSec,
            tags: feed.tags
        )
    )

    let recent = try await engine.listNews(limit: 10)
    #expect(recent.contains(where: { $0.source == "rss_fed_old" }) == false)
    #expect(recent.contains(where: { $0.source == "rss_fed_new" }))
    #expect(recent.contains(where: { $0.source == "sec_edgar" }))
}

@Test("Removing an RSS feed purges its persisted source-scoped news while leaving other sources intact")
func removingRSSFeedPurgesItsPersistedNewsOnly() async throws {
    let tempRoot = makeTempDirectory(name: "rss-feed-remove-purges-news")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    let ceprFeed = try await rssStore.upsert(
        RSSFeed(
            id: "feed-cepr",
            name: "CEPR Events",
            url: "https://cepr.org/rss/events",
            enabled: true,
            pollIntervalSec: 300,
            tags: []
        )
    )
    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-engadget",
            name: "Engadget",
            url: "https://example.com/engadget.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: []
        )
    )

    let receivedAt = Date(timeIntervalSince1970: 1_743_374_400)
    _ = try await newsStore.append([
        NewsEvent(
            eventId: "cepr-1",
            source: "rss_cepr_events",
            title: "CEPR Future Event",
            url: "https://cepr.org/events/item",
            publishedAt: Date(timeIntervalSince1970: 1_746_828_800),
            receivedAt: receivedAt
        ),
        NewsEvent(
            eventId: "engadget-1",
            source: "rss_engadget",
            title: "Engadget headline",
            url: "https://www.engadget.com/item",
            publishedAt: receivedAt,
            receivedAt: receivedAt
        )
    ])

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )

    try await engine.removeRSSFeed(id: ceprFeed.id)
    let recent = try await engine.listNews(limit: 10)
    #expect(recent.contains(where: { $0.source == "rss_cepr_events" }) == false)
    #expect(recent.contains(where: { $0.source == "rss_engadget" }))
}

@Test("rss_poll job runs one tick with mocked fetcher")
func rssPollJobOneTick() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["macro"]
        )
    )

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "maxTicks": .number(1),
            "includeAlpaca": .bool(false),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)

    let recentNews = try await engine.listNews(limit: 10)
    #expect(recentNews.count == 1)
    #expect(recentNews.first?.title == "Fed update")
    await engine.stop()
}

@Test("rss_poll is one-shot without internal repeat sleep")
func rssPollJobCompletesWithoutInternalLooping() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-one-shot")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let rssAttemptCounter = AttemptCounter()
    let sleepCounter = AttemptCounter()

    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 300,
            tags: ["macro"]
        )
    )

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: ConfigurableMockRSSFetcher { url, userAgent in
            _ = url
            _ = userAgent
            await rssAttemptCounter.increment()
            let xml = """
            <rss version=\"2.0\"><channel><item><title>Fed update</title><link>https://example.com/a</link><guid>a</guid><pubDate>Tue, 02 Jan 2024 15:04:05 +0000</pubDate><description>Policy headline</description></item></channel></rss>
            """
            return RSSFetchResponse(statusCode: 200, data: Data(xml.utf8))
        },
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in
            await sleepCounter.increment()
        }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "includeAlpaca": .bool(false),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    #expect(await rssAttemptCounter.count == 1)
    #expect(await sleepCounter.count == 0)
    #expect(completed.result?.objectValue?["ticks"]?.intValue == 1)

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.newsIngestStatus.rssStatus.contains("Fed:parsed1/+1/dup0"))
    await engine.stop()
}

@Test("rss_poll job surfaces RSS-specific transport diagnostics")
func rssPollJobTransportFailureUsesRSSDomain() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-transport")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-transport",
            name: "Transport Feed",
            url: "https://transport.example/feed.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: []
        )
    )

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: ConfigurableMockRSSFetcher { _, _ in
            throw RSSFeedFetchError.transport(host: "transport.example", message: "The request timed out.")
        },
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "maxTicks": .number(1),
            "includeAlpaca": .bool(false)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    #expect(completed.result?.objectValue?["failedFeeds"]?.intValue == 1)

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.auditLines.contains { $0.contains("RSS transport failure host=transport.example") })
    #expect(snapshot.auditLines.allSatisfy { !$0.contains("AlpacaAPIError") })
    #expect(snapshot.newsIngestStatus.rssStatus.contains("transport@transport.example"))
    await engine.stop()
}

@Test("rss_poll isolates per-feed failures and keeps categories actionable")
func rssPollJobIsolatesFailuresAndSummarizesCategories() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-categories")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    let feeds = [
        RSSFeed(
            id: "feed-ok",
            name: "Fed",
            url: "https://ok.example/fed.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["macro"]
        ),
        RSSFeed(
            id: "feed-http",
            name: "SEC",
            url: "https://http.example/sec.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["filings"]
        ),
        RSSFeed(
            id: "feed-parse",
            name: "MarketWatch",
            url: "https://parse.example/mw.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["market"]
        )
    ]
    for feed in feeds {
        _ = try await rssStore.upsert(feed)
    }

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: ConfigurableMockRSSFetcher { url, _ in
            switch url.host {
            case "ok.example":
                let xml = """
                <rss version=\"2.0\"><channel><item><title>Fed update</title><link>https://example.com/a</link><guid>a</guid><pubDate>Tue, 02 Jan 2024 15:04:05 +0000</pubDate><description>Policy headline</description></item></channel></rss>
                """
                return RSSFetchResponse(statusCode: 200, data: Data(xml.utf8))
            case "http.example":
                return RSSFetchResponse(statusCode: 503, data: Data())
            case "parse.example":
                return RSSFetchResponse(statusCode: 200, data: Data("<rss><channel><item><title>broken".utf8))
            default:
                throw RSSFeedFetchError.transport(host: url.host, message: "Unexpected host")
            }
        },
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "maxTicks": .number(1),
            "includeAlpaca": .bool(false),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    let result = try #require(completed.result?.objectValue)
    #expect(result["feedsPolled"]?.intValue == 1)
    #expect(result["failedFeeds"]?.intValue == 2)
    #expect(result["newEvents"]?.intValue == 1)

    let recentNews = try await engine.listNews(limit: 10)
    #expect(recentNews.count == 1)
    #expect(recentNews.first?.title == "Fed update")

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.newsIngestStatus.rssStatus.contains("Fed:parsed1/+1/dup0"))
    #expect(snapshot.newsIngestStatus.rssStatus.contains("SEC:http_503@http.example"))
    #expect(snapshot.newsIngestStatus.rssStatus.contains("MarketWatch:parse@parse.example"))
    #expect(snapshot.auditLines.contains { $0.contains("RSS HTTP status 503 host=http.example") })
    #expect(snapshot.auditLines.contains { $0.contains("RSS parse failure host=parse.example") })
    #expect(snapshot.auditLines.allSatisfy { !$0.contains("AlpacaAPIError") })
    await engine.stop()
}

@Test("rss_poll includes Alpaca News when built-in source is enabled")
func rssPollJobIncludesAlpacaWhenEnabled() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-alpaca-enabled")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsSettingsStore = BuiltInNewsSourcesSettingsStore(
        fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
    )
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let counter = AttemptCounter()

    _ = try await newsSettingsStore.save(BuiltInNewsSourcesSettings(alpacaNewsEnabled: true))

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: newsSettingsStore,
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in
            CountingMockAlpacaNewsClient(counter: counter, items: [
                AlpacaNewsItem(
                    id: "alpaca-1",
                    headline: "Alpaca market headline",
                    summary: "Summary",
                    url: "https://example.com/alpaca",
                    symbols: ["AAPL"],
                    createdAt: Date(timeIntervalSince1970: 1_700_000_100),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
                )
            ])
        },
        replaySleep: { _ in }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "maxTicks": .number(1),
            "includeAlpaca": .bool(true),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    #expect(await counter.count == 1)

    let recentNews = try await engine.listNews(limit: 10)
    #expect(recentNews.count == 1)
    #expect(recentNews.first?.source == "alpaca_news")

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.newsIngestStatus.alpacaStatus.contains("ok new=1"))
    await engine.stop()
}

@Test("rss_poll skips Alpaca News and diagnostics when built-in source is disabled")
func rssPollJobSkipsAlpacaWhenDisabled() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-alpaca-disabled")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsSettingsStore = BuiltInNewsSourcesSettingsStore(
        fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
    )
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let counter = AttemptCounter()

    _ = try await newsSettingsStore.save(BuiltInNewsSourcesSettings(alpacaNewsEnabled: false))

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: newsSettingsStore,
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in
            CountingMockAlpacaNewsClient(counter: counter, items: [])
        },
        replaySleep: { _ in }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "maxTicks": .number(1),
            "includeAlpaca": .bool(true),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    #expect(await counter.count == 0)

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.newsIngestStatus.alpacaStatus == "disabled")
    #expect(snapshot.auditLines.allSatisfy { !$0.contains("alpaca news ingest unavailable") })
    await engine.stop()
}

@Test("disabling Alpaca News does not affect normal RSS feed processing")
func rssPollJobProcessesRSSNormallyWhenAlpacaDisabled() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-rss-only")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsSettingsStore = BuiltInNewsSourcesSettingsStore(
        fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
    )
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))
    let counter = AttemptCounter()

    _ = try await newsSettingsStore.save(BuiltInNewsSourcesSettings(alpacaNewsEnabled: false))
    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["macro"]
        )
    )

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: newsSettingsStore,
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in
            CountingMockAlpacaNewsClient(counter: counter, items: [])
        },
        replaySleep: { _ in }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "maxTicks": .number(1),
            "includeAlpaca": .bool(true),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    #expect(await counter.count == 0)

    let recentNews = try await engine.listNews(limit: 10)
    #expect(recentNews.count == 1)
    #expect(recentNews.first?.source == "rss_fed")

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.newsIngestStatus.rssStatus.contains("Fed:parsed1/+1/dup0"))
    #expect(snapshot.newsIngestStatus.alpacaStatus == "disabled")
    await engine.stop()
}

@Test("Alpaca News credential failure degrades without poisoning RSS ingestion")
func rssPollJobDegradesAlpacaCredentialFailureWithoutPoisoningRSS() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-alpaca-credentials-degraded")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsSettingsStore = BuiltInNewsSourcesSettingsStore(
        fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
    )
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    _ = try await newsSettingsStore.save(BuiltInNewsSourcesSettings(alpacaNewsEnabled: true))
    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["macro"]
        )
    )

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: newsSettingsStore,
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(),
        alpacaNewsClientFactory: { _ in ThrowingMockAlpacaNewsClient(error: AlpacaAPIError.missingCredentials(environment: .paper)) },
        replaySleep: { _ in }
    )

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "maxTicks": .number(1),
            "includeAlpaca": .bool(true),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    #expect(completed.result?.objectValue?["errors"]?.intValue == 1)

    let recentNews = try await engine.listNews(limit: 10)
    #expect(recentNews.count == 1)
    #expect(recentNews.first?.source == "rss_fed")

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.newsIngestStatus.rssStatus.contains("Fed:parsed1/+1/dup0"))
    #expect(snapshot.newsIngestStatus.alpacaStatus.contains("unavailable"))
    #expect(snapshot.auditLines.contains { $0.contains("Missing Alpaca credentials for paper environment") })
    await engine.stop()
}

@Test("rss_poll integrates SEC EDGAR filings for watchlist symbols in one bounded pass")
func rssPollJobIncludesSECEDGARForWatchlistSymbols() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-sec")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["macro"]
        )
    )

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(result: SECRecentFilingsResult(
            requestedSymbols: ["AAPL"],
            resolvedSymbols: ["AAPL"],
            filings: [
                SECRecentFiling(
                    symbol: "AAPL",
                    cik: "0000320193",
                    companyName: "Apple Inc.",
                    formType: "8-K",
                    filedAt: Date(timeIntervalSince1970: 1_710_000_000),
                    acceptedAt: Date(timeIntervalSince1970: 1_710_000_300),
                    filingURL: "https://www.sec.gov/Archives/edgar/data/320193/000032019326000001/a8k.htm",
                    accessionNumber: "0000320193-26-000001",
                    primaryDocumentDescription: "Current report"
                )
            ],
            diagnostics: [],
            failedSymbols: []
        )),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )
    await engine.store.setWatchlistSymbols(["AAPL"])

    let job = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "includeAlpaca": .bool(false),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )

    let completed = try await waitForJobCompletion(engine: engine, jobID: job.jobId)
    #expect(completed.status == .succeeded)
    #expect(completed.result?.objectValue?["secFilingsParsed"]?.intValue == 1)

    let recentNews = try await engine.listNews(limit: 10)
    #expect(recentNews.count == 2)
    #expect(recentNews.contains { $0.source == "sec_edgar" && $0.title == "Apple Inc. filed 8-K" })

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.newsIngestStatus.secStatus.contains("watch=1 filings=1 new=1 dup=0 failed=0"))
    #expect(snapshot.newsIngestStatus.rssStatus.contains("SEC:watch1/filings1/+1/dup0/fail0"))
    await engine.stop()
}

@Test("rss_poll isolates SEC diagnostics and dedupes SEC filings across reruns")
func rssPollJobIsolatesSECDiagnosticsAndDedupesAcrossReruns() async throws {
    let tempRoot = makeTempDirectory(name: "rss-job-sec-dedupe")
    let rssStore = RSSFeedStore(fileURL: tempRoot.appendingPathComponent("rss_feeds.json"))
    let newsStore = NewsStore(newsDirectory: tempRoot.appendingPathComponent("news", isDirectory: true))

    _ = try await rssStore.upsert(
        RSSFeed(
            id: "feed-1",
            name: "Fed",
            url: "https://example.com/fed.xml",
            enabled: true,
            pollIntervalSec: 15,
            tags: ["macro"]
        )
    )

    let secResult = SECRecentFilingsResult(
        requestedSymbols: ["MSFT"],
        resolvedSymbols: [],
        filings: [],
        diagnostics: ["sec ticker mapping unavailable symbol=MSFT"],
        failedSymbols: ["MSFT"]
    )

    let engine = Engine(
        rssFeedStore: rssStore,
        newsSourceSettingsStore: BuiltInNewsSourcesSettingsStore(
            fileURL: tempRoot.appendingPathComponent("news_source_settings.json")
        ),
        newsStore: newsStore,
        rssFetcher: MockRSSFetcher(),
        secFilingsProvider: MockSECFilingsProvider(result: secResult),
        alpacaNewsClientFactory: { _ in MockAlpacaNewsClient() },
        replaySleep: { _ in }
    )
    await engine.store.setWatchlistSymbols(["MSFT"])

    let firstJob = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "includeAlpaca": .bool(false),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )
    _ = try await waitForJobCompletion(engine: engine, jobID: firstJob.jobId)

    let secondJob = try await engine.submitJob(
        type: .rssPoll,
        parameters: [
            "includeAlpaca": .bool(false),
            "maxItemsPerFeed": .number(10)
        ],
        source: .engine
    )
    let completed = try await waitForJobCompletion(engine: engine, jobID: secondJob.jobId)

    let recentNews = try await engine.listNews(limit: 10)
    #expect(recentNews.count == 1)
    #expect(recentNews.first?.source == "rss_fed")
    #expect(completed.result?.objectValue?["duplicates"]?.intValue == 1)

    let snapshot = await engine.store.snapshot()
    #expect(snapshot.auditLines.contains { $0.contains("sec ticker mapping unavailable symbol=MSFT") })
    #expect(snapshot.newsIngestStatus.secStatus.contains("failed=1"))
    #expect(snapshot.newsIngestStatus.rssStatus.contains("Fed:parsed1/+0/dup1"))
    await engine.stop()
}

private func waitForJobCompletion(
    engine: Engine,
    jobID: String,
    retries: Int = 40
) async throws -> JobRecord {
    for _ in 0..<retries {
        let job = try await engine.getJob(jobID: jobID)
        if job.status == .succeeded || job.status == .failed || job.status == .canceled {
            return job
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    return try await engine.getJob(jobID: jobID)
}

private func makeTempDirectory(name: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private struct MockRSSFetcher: RSSFetching {
    func fetch(url: URL, userAgent: String) async throws -> RSSFetchResponse {
        _ = userAgent
        let xml = """
        <rss version=\"2.0\"><channel><item><title>Fed update</title><link>https://example.com/a</link><guid>a</guid><pubDate>Tue, 02 Jan 2024 15:04:05 +0000</pubDate><description>Policy headline</description></item></channel></rss>
        """
        return RSSFetchResponse(statusCode: 200, data: Data(xml.utf8))
    }
}

private func makeAlpacaNewsClient(statusCode: Int, body: Data) -> AlpacaNewsClient {
    let responseID = UUID().uuidString
    AlpacaNewsURLProtocol.setResponse((statusCode, body), for: responseID)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpAdditionalHeaders = [
        AlpacaNewsURLProtocol.responseIDHeader: responseID
    ]
    configuration.protocolClasses = [AlpacaNewsURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return AlpacaNewsClient(
        environment: .paper,
        keychainProvider: KeychainCredentialsProvider(
            keyReader: StaticNewsKeyReader()
        ),
        session: session
    )
}

private final class AlpacaNewsURLProtocol: URLProtocol {
    static let responseIDHeader = "X-Alpaca-News-Test-Response-ID"
    nonisolated(unsafe) private static var responses: [String: (statusCode: Int, body: Data)] = [:]
    private static let responsesLock = NSLock()

    static func setResponse(_ response: (statusCode: Int, body: Data), for responseID: String) {
        responsesLock.lock()
        responses[responseID] = response
        responsesLock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responseID = request.value(forHTTPHeaderField: Self.responseIDHeader),
              let response = Self.response(for: responseID),
              let url = request.url,
              let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: ["apca-request-id": "test-request"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func response(for responseID: String) -> (statusCode: Int, body: Data)? {
        responsesLock.lock()
        let response = responses[responseID]
        responsesLock.unlock()
        return response
    }
}

private struct StaticNewsKeyReader: KeyReading {
    func readKey(service: String, account: String) -> String? {
        _ = service
        _ = account
        return "test-key"
    }
}

private struct ConfigurableMockRSSFetcher: RSSFetching {
    let handler: @Sendable (URL, String) async throws -> RSSFetchResponse

    func fetch(url: URL, userAgent: String) async throws -> RSSFetchResponse {
        try await handler(url, userAgent)
    }
}

private struct ConfigurableMockSECFetcher: SECFetching {
    let handler: @Sendable (URL, String) async throws -> SECFetchResponse

    func fetch(url: URL, userAgent: String) async throws -> SECFetchResponse {
        try await handler(url, userAgent)
    }
}

private struct MockAlpacaNewsClient: AlpacaNewsProviding {
    func fetchLatest(limit: Int) async throws -> [AlpacaNewsItem] {
        _ = limit
        return []
    }
}

private struct ThrowingMockAlpacaNewsClient: AlpacaNewsProviding {
    let error: Error

    func fetchLatest(limit: Int) async throws -> [AlpacaNewsItem] {
        _ = limit
        throw error
    }
}

private actor AttemptCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

private struct MockSECFilingsProvider: SECFilingsProviding {
    var result = SECRecentFilingsResult()

    func fetchRecentFilings(for watchlistSymbols: [String]) async -> SECRecentFilingsResult {
        if result.requestedSymbols.isEmpty && result.resolvedSymbols.isEmpty && result.filings.isEmpty && result.diagnostics.isEmpty && result.failedSymbols.isEmpty {
            return SECRecentFilingsResult(
                requestedSymbols: SECEDGARClient.normalizedIssuerSymbols(from: watchlistSymbols),
                resolvedSymbols: [],
                filings: [],
                diagnostics: [],
                failedSymbols: []
            )
        }
        return result
    }
}

private struct CountingMockAlpacaNewsClient: AlpacaNewsProviding {
    let counter: AttemptCounter
    let items: [AlpacaNewsItem]

    func fetchLatest(limit: Int) async throws -> [AlpacaNewsItem] {
        _ = limit
        await counter.increment()
        return items
    }
}
