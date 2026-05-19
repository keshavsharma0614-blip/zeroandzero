import Foundation

public enum RSSFeedFetchError: Error, Sendable, Equatable {
    case invalidURL(feedName: String)
    case transport(host: String?, message: String)
    case invalidResponse(host: String?)
    case httpStatus(host: String?, statusCode: Int)
    case parsing(host: String?, message: String)
}

extension RSSFeedFetchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let feedName):
            return "RSS feed URL is invalid for \(feedName)."
        case .transport(let host, let message):
            return "RSS transport failure\(hostDescription(host)): \(message)"
        case .invalidResponse(let host):
            return "RSS response validation failed\(hostDescription(host))."
        case .httpStatus(let host, let statusCode):
            return "RSS HTTP status \(statusCode)\(hostDescription(host))."
        case .parsing(let host, let message):
            return "RSS parse failure\(hostDescription(host)): \(message)"
        }
    }

    private func hostDescription(_ host: String?) -> String {
        guard let host, !host.isEmpty else {
            return ""
        }
        return " host=\(host)"
    }
}

extension RSSFeedFetchError {
    var compactSummary: String {
        switch self {
        case .invalidURL:
            return "invalid_url"
        case .transport(let host, _):
            return "transport\(host.map { "@\($0)" } ?? "")"
        case .invalidResponse(let host):
            return "invalid_response\(host.map { "@\($0)" } ?? "")"
        case .httpStatus(let host, let statusCode):
            return "http_\(statusCode)\(host.map { "@\($0)" } ?? "")"
        case .parsing(let host, _):
            return "parse\(host.map { "@\($0)" } ?? "")"
        }
    }
}

public struct RSSFetchResponse: Sendable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol RSSFetching: Sendable {
    func fetch(url: URL, userAgent: String) async throws -> RSSFetchResponse
}

public struct URLSessionRSSFetcher: RSSFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    static func makeRequest(url: URL, userAgent: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        return request
    }

    public func fetch(url: URL, userAgent: String) async throws -> RSSFetchResponse {
        let request = Self.makeRequest(url: url, userAgent: userAgent)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RSSFeedFetchError.transport(host: url.host, message: error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RSSFeedFetchError.invalidResponse(host: url.host)
        }
        return RSSFetchResponse(statusCode: httpResponse.statusCode, data: data)
    }
}

public enum SECEDGARFetchError: Error, Sendable, Equatable {
    case transport(host: String?, message: String)
    case invalidResponse(host: String?)
    case httpStatus(host: String?, statusCode: Int)
    case decoding(host: String?, message: String)
}

extension SECEDGARFetchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .transport(let host, let message):
            return "SEC EDGAR transport failure\(hostDescription(host)): \(message)"
        case .invalidResponse(let host):
            return "SEC EDGAR response validation failed\(hostDescription(host))."
        case .httpStatus(let host, let statusCode):
            return "SEC EDGAR HTTP status \(statusCode)\(hostDescription(host))."
        case .decoding(let host, let message):
            return "SEC EDGAR decode failure\(hostDescription(host)): \(message)"
        }
    }

    private func hostDescription(_ host: String?) -> String {
        guard let host, !host.isEmpty else {
            return ""
        }
        return " host=\(host)"
    }
}

public struct SECFetchResponse: Sendable, Equatable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol SECFetching: Sendable {
    func fetch(url: URL, userAgent: String) async throws -> SECFetchResponse
}

public struct URLSessionSECFetcher: SECFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    static func makeRequest(url: URL, userAgent: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/json;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        return request
    }

    public func fetch(url: URL, userAgent: String) async throws -> SECFetchResponse {
        let request = Self.makeRequest(url: url, userAgent: userAgent)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SECEDGARFetchError.transport(host: url.host, message: error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SECEDGARFetchError.invalidResponse(host: url.host)
        }
        return SECFetchResponse(statusCode: httpResponse.statusCode, data: data)
    }
}

public struct SECRecentFiling: Sendable, Equatable {
    public let symbol: String
    public let cik: String
    public let companyName: String
    public let formType: String
    public let filedAt: Date
    public let acceptedAt: Date?
    public let filingURL: String?
    public let accessionNumber: String
    public let primaryDocumentDescription: String?

    public init(
        symbol: String,
        cik: String,
        companyName: String,
        formType: String,
        filedAt: Date,
        acceptedAt: Date?,
        filingURL: String?,
        accessionNumber: String,
        primaryDocumentDescription: String?
    ) {
        self.symbol = symbol
        self.cik = cik
        self.companyName = companyName
        self.formType = formType
        self.filedAt = filedAt
        self.acceptedAt = acceptedAt
        self.filingURL = filingURL
        self.accessionNumber = accessionNumber
        self.primaryDocumentDescription = primaryDocumentDescription
    }
}

public struct SECRecentFilingsResult: Sendable, Equatable {
    public let requestedSymbols: [String]
    public let resolvedSymbols: [String]
    public let filings: [SECRecentFiling]
    public let diagnostics: [String]
    public let failedSymbols: [String]

    public init(
        requestedSymbols: [String] = [],
        resolvedSymbols: [String] = [],
        filings: [SECRecentFiling] = [],
        diagnostics: [String] = [],
        failedSymbols: [String] = []
    ) {
        self.requestedSymbols = requestedSymbols
        self.resolvedSymbols = resolvedSymbols
        self.filings = filings
        self.diagnostics = diagnostics
        self.failedSymbols = failedSymbols
    }
}

public protocol SECFilingsProviding: Sendable {
    func fetchRecentFilings(for watchlistSymbols: [String]) async -> SECRecentFilingsResult
}

public actor SECEDGARClient: SECFilingsProviding {
    private struct TickerDirectoryEntry: Decodable {
        let cikStr: Int
        let ticker: String
        let title: String
    }

    private struct CompanySubmissionsDocument: Decodable {
        struct Filings: Decodable {
            struct Recent: Decodable {
                let form: [String]
                let filingDate: [String]
                let acceptanceDateTime: [String]?
                let accessionNumber: [String]
                let primaryDocument: [String]?
                let primaryDocDescription: [String]?
            }

            let recent: Recent
        }

        let cik: String
        let name: String
        let filings: Filings
    }

    private struct TickerReference: Sendable, Equatable {
        let ticker: String
        let cikPadded: String
        let cikArchiveComponent: String
        let companyName: String
    }

    private let fetcher: any SECFetching
    private let supportedForms: Set<String>
    private let maxFilingsPerIssuer: Int
    private let userAgent: String
    private let now: @Sendable () -> TimeInterval
    private var rateLimiter: TokenBucketRateLimiter
    private var cachedTickerDirectory: [String: TickerReference]?

    public init(
        fetcher: any SECFetching = URLSessionSECFetcher(),
        supportedForms: Set<String> = SECEDGARClient.defaultSupportedForms,
        maxFilingsPerIssuer: Int = 5,
        userAgent: String = SECEDGARClient.defaultUserAgent,
        rateLimiter: TokenBucketRateLimiter? = nil,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.fetcher = fetcher
        self.supportedForms = supportedForms
        self.maxFilingsPerIssuer = max(1, maxFilingsPerIssuer)
        self.userAgent = userAgent
        self.now = now
        self.rateLimiter = rateLimiter ?? TokenBucketRateLimiter(
            capacity: 5,
            refillRatePerSecond: 2,
            initialTime: now()
        )
    }

    public func fetchRecentFilings(for watchlistSymbols: [String]) async -> SECRecentFilingsResult {
        let requestedSymbols = Self.normalizedIssuerSymbols(from: watchlistSymbols)
        guard !requestedSymbols.isEmpty else {
            return SECRecentFilingsResult()
        }

        let directory: [String: TickerReference]
        do {
            directory = try await loadTickerDirectory()
        } catch {
            return SECRecentFilingsResult(
                requestedSymbols: requestedSymbols,
                resolvedSymbols: [],
                filings: [],
                diagnostics: ["sec ticker directory unavailable reason=\(error.localizedDescription)"],
                failedSymbols: requestedSymbols
            )
        }

        var resolvedSymbols: [String] = []
        var filings: [SECRecentFiling] = []
        var diagnostics: [String] = []
        var failedSymbols: [String] = []

        for symbol in requestedSymbols {
            guard let reference = directory[Self.secLookupKey(symbol)] else {
                diagnostics.append("sec ticker mapping unavailable symbol=\(symbol)")
                failedSymbols.append(symbol)
                continue
            }

            do {
                let issuerFilings = try await fetchRecentFilings(
                    for: reference,
                    symbol: symbol
                )
                resolvedSymbols.append(symbol)
                filings.append(contentsOf: issuerFilings)
            } catch {
                diagnostics.append("sec submissions failed symbol=\(symbol) reason=\(error.localizedDescription)")
                failedSymbols.append(symbol)
            }
        }

        filings.sort { lhs, rhs in
            if lhs.filedAt == rhs.filedAt {
                if lhs.symbol == rhs.symbol {
                    return lhs.accessionNumber < rhs.accessionNumber
                }
                return lhs.symbol < rhs.symbol
            }
            return lhs.filedAt > rhs.filedAt
        }

        return SECRecentFilingsResult(
            requestedSymbols: requestedSymbols,
            resolvedSymbols: resolvedSymbols,
            filings: filings,
            diagnostics: diagnostics,
            failedSymbols: failedSymbols
        )
    }

    private func loadTickerDirectory() async throws -> [String: TickerReference] {
        if let cachedTickerDirectory {
            return cachedTickerDirectory
        }

        let url = URL(string: "https://www.sec.gov/files/company_tickers.json")!
        let response = try await fetchSEC(url: url)
        guard (200...299).contains(response.statusCode) else {
            throw SECEDGARFetchError.httpStatus(host: url.host, statusCode: response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = try decodeTickerDirectory(data: response.data, decoder: decoder)
        let mapped = Dictionary(uniqueKeysWithValues: raw.values.map { entry in
            let ticker = Self.secLookupKey(entry.ticker)
            let padded = String(format: "%010d", entry.cikStr)
            let archiveComponent = String(entry.cikStr)
            return (
                ticker,
                TickerReference(
                    ticker: ticker,
                    cikPadded: padded,
                    cikArchiveComponent: archiveComponent,
                    companyName: entry.title
                )
            )
        })
        cachedTickerDirectory = mapped
        return mapped
    }

    private func fetchRecentFilings(
        for reference: TickerReference,
        symbol: String
    ) async throws -> [SECRecentFiling] {
        let url = URL(string: "https://data.sec.gov/submissions/CIK\(reference.cikPadded).json")!
        let response = try await fetchSEC(url: url)
        guard (200...299).contains(response.statusCode) else {
            throw SECEDGARFetchError.httpStatus(host: url.host, statusCode: response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let document: CompanySubmissionsDocument
        do {
            document = try decoder.decode(CompanySubmissionsDocument.self, from: response.data)
        } catch {
            throw SECEDGARFetchError.decoding(host: url.host, message: error.localizedDescription)
        }

        return Self.makeRecentFilings(
            document: document,
            symbol: symbol,
            companyName: reference.companyName,
            cikArchiveComponent: reference.cikArchiveComponent,
            supportedForms: supportedForms,
            limit: maxFilingsPerIssuer
        )
    }

    private func fetchSEC(url: URL) async throws -> SECFetchResponse {
        do {
            try rateLimiter.acquire(at: now())
        } catch RateLimiterError.rateLimited(let retryAfter) {
            throw SECEDGARFetchError.transport(
                host: url.host,
                message: "local rate limited retry_after=\(String(format: "%.2f", retryAfter))"
            )
        } catch {
            throw SECEDGARFetchError.transport(host: url.host, message: "Rate limiter failed")
        }

        return try await fetcher.fetch(url: url, userAgent: userAgent)
    }

    private func decodeTickerDirectory(
        data: Data,
        decoder: JSONDecoder
    ) throws -> [String: TickerDirectoryEntry] {
        do {
            return try decoder.decode([String: TickerDirectoryEntry].self, from: data)
        } catch {
            throw SECEDGARFetchError.decoding(host: "www.sec.gov", message: error.localizedDescription)
        }
    }

    static func normalizedIssuerSymbols(from watchlistSymbols: [String]) -> [String] {
        let normalized = MarketDataSubscriptionSet.normalized(watchlistSymbols)
        let issuers = normalized.compactMap { symbol -> String? in
            if let parsed = OptionContractSymbol.parse(symbol) {
                return secLookupKey(parsed.underlyingSymbol)
            }
            guard MarketSymbolClassifier.instrumentType(for: symbol) == .equity else {
                return nil
            }
            return secLookupKey(symbol)
        }
        return Array(Set(issuers)).sorted()
    }

    private static func makeRecentFilings(
        document: CompanySubmissionsDocument,
        symbol: String,
        companyName: String,
        cikArchiveComponent: String,
        supportedForms: Set<String>,
        limit: Int
    ) -> [SECRecentFiling] {
        let recent = document.filings.recent
        let total = min(
            recent.form.count,
            recent.filingDate.count,
            recent.accessionNumber.count
        )
        guard total > 0 else {
            return []
        }

        var filings: [SECRecentFiling] = []
        filings.reserveCapacity(min(total, limit))

        for index in 0..<total {
            let form = recent.form[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard supportedForms.contains(form) else {
                continue
            }
            guard let filedAt = parseSECDate(recent.filingDate[index]) else {
                continue
            }
            let accessionNumber = recent.accessionNumber[index]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !accessionNumber.isEmpty else {
                continue
            }

            let acceptedAt: Date?
            if let values = recent.acceptanceDateTime, index < values.count {
                acceptedAt = parseSECAcceptance(values[index])
            } else {
                acceptedAt = nil
            }

            let primaryDocument: String?
            if let values = recent.primaryDocument, index < values.count {
                let raw = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
                primaryDocument = raw.isEmpty ? nil : raw
            } else {
                primaryDocument = nil
            }

            let primaryDocumentDescription: String?
            if let values = recent.primaryDocDescription, index < values.count {
                let raw = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
                primaryDocumentDescription = raw.isEmpty ? nil : raw
            } else {
                primaryDocumentDescription = nil
            }
            let archiveAccession = accessionNumber.replacingOccurrences(of: "-", with: "")
            let filingURL = primaryDocument.map {
                "https://www.sec.gov/Archives/edgar/data/\(cikArchiveComponent)/\(archiveAccession)/\($0)"
            }

            filings.append(
                SECRecentFiling(
                    symbol: symbol,
                    cik: document.cik,
                    companyName: companyName,
                    formType: form,
                    filedAt: filedAt,
                    acceptedAt: acceptedAt,
                    filingURL: filingURL,
                    accessionNumber: accessionNumber,
                    primaryDocumentDescription: primaryDocumentDescription
                )
            )

            if filings.count >= limit {
                break
            }
        }

        return filings
    }

    static func secLookupKey(_ symbol: String) -> String {
        symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ".", with: "-")
    }

    private static func parseSECDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }

    private static func parseSECAcceptance(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let normalized = trimmed.contains("T") ? trimmed : trimmed.replacingOccurrences(of: " ", with: "T") + "Z"
        return DateCodec.parseISO8601(normalized)
    }

    public static let defaultSupportedForms: Set<String> = [
        "8-K",
        "10-K",
        "10-Q",
        "6-K",
        "4",
        "13F-HR",
        "13F-HR/A",
        "13F-NT",
        "SC 13D",
        "SC 13D/A",
        "SC 13G",
        "SC 13G/A"
    ]

    public static let defaultUserAgent = "AlgoTradingMac/1.0 (SEC EDGAR ingest; source=https://github.com/zeroandzero-ai/zeroandzero)"
}

public struct RSSItem: Sendable, Equatable {
    public let title: String
    public let link: String?
    public let guid: String?
    public let publishedAt: Date?
    public let summary: String?

    public init(
        title: String,
        link: String?,
        guid: String?,
        publishedAt: Date?,
        summary: String?
    ) {
        self.title = title
        self.link = link
        self.guid = guid
        self.publishedAt = publishedAt
        self.summary = summary
    }
}

public enum RSSParser {
    public static func parse(data: Data) -> [RSSItem] {
        parseWithDiagnostics(data: data).items
    }

    public static func parseWithDiagnostics(data: Data) -> RSSParseResult {
        let delegate = RSSXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            let message = parser.parserError?.localizedDescription ?? "malformed xml"
            return RSSParseResult(
                items: [],
                diagnostics: ["rss parse failed: \(message)"],
                fatalError: message
            )
        }
        return RSSParseResult(items: delegate.items, diagnostics: delegate.diagnostics)
    }
}

public struct RSSParseResult: Sendable, Equatable {
    public let items: [RSSItem]
    public let diagnostics: [String]
    public let fatalError: String?

    public init(items: [RSSItem], diagnostics: [String], fatalError: String? = nil) {
        self.items = items
        self.diagnostics = diagnostics
        self.fatalError = fatalError
    }
}

private final class RSSXMLDelegate: NSObject, XMLParserDelegate {
    fileprivate private(set) var items: [RSSItem] = []
    fileprivate private(set) var diagnostics: [String] = []

    private var inItem = false
    private var currentElement = ""
    private var titleBuffer = ""
    private var linkBuffer = ""
    private var guidBuffer = ""
    private var pubDateBuffer = ""
    private var descriptionBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let lower = elementName.lowercased()
        if lower == "item" || lower == "entry" {
            inItem = true
            titleBuffer = ""
            linkBuffer = ""
            guidBuffer = ""
            pubDateBuffer = ""
            descriptionBuffer = ""
        }

        guard inItem else {
            return
        }

        currentElement = lower
        if lower == "link", linkBuffer.isEmpty {
            if let href = attributeDict["href"], !href.isEmpty {
                linkBuffer = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else {
            return
        }

        switch currentElement {
        case "title":
            titleBuffer.append(string)
        case "link":
            if linkBuffer.isEmpty {
                linkBuffer.append(string)
            }
        case "guid", "id":
            guidBuffer.append(string)
        case "pubdate", "published", "updated":
            pubDateBuffer.append(string)
        case "description", "summary", "content":
            descriptionBuffer.append(string)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let lower = elementName.lowercased()
        if lower == "item" || lower == "entry" {
            inItem = false
            let title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                let link = normalizedOptional(linkBuffer)
                let guid = normalizedOptional(guidBuffer)
                let rawPubDate = normalizedOptional(pubDateBuffer)
                let pubDate = rawPubDate.flatMap(DateCodec.parseRSSDate)
                if rawPubDate != nil, pubDate == nil {
                    diagnostics.append("rss parse skipped item reason=invalid_pub_date")
                    currentElement = ""
                    return
                }
                let summary = normalizedOptional(descriptionBuffer)
                items.append(
                    RSSItem(
                        title: title,
                        link: link,
                        guid: guid,
                        publishedAt: pubDate,
                        summary: summary
                    )
                )
            }
        }

        currentElement = ""
    }

    private func normalizedOptional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public protocol AlpacaNewsProviding: Sendable {
    func fetchLatest(limit: Int) async throws -> [AlpacaNewsItem]
}

public struct AlpacaNewsItem: Codable, Sendable, Equatable {
    public let id: String?
    public let headline: String
    public let summary: String?
    public let url: String?
    public let symbols: [String]?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: String? = nil,
        headline: String,
        summary: String? = nil,
        url: String? = nil,
        symbols: [String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.headline = headline
        self.summary = summary
        self.url = url
        self.symbols = symbols
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case headline
        case title
        case summary
        case url
        case symbols
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.decodeLossyString(from: container, forKey: .id)

        let decodedHeadline = try container.decodeIfPresent(String.self, forKey: .headline)
            ?? container.decodeIfPresent(String.self, forKey: .title)
        guard let headline = decodedHeadline?.trimmingCharacters(in: .whitespacesAndNewlines),
              headline.isEmpty == false else {
            throw DecodingError.keyNotFound(
                CodingKeys.headline,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Alpaca news item missing headline"
                )
            )
        }
        self.headline = headline

        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        symbols = try container.decodeIfPresent([String].self, forKey: .symbols)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(headline, forKey: .headline)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(symbols, forKey: .symbols)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    private static func decodeLossyString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decodeIfPresent(Int64.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}

public actor AlpacaNewsClient: AlpacaNewsProviding {
    private struct NewsEnvelope: Decodable {
        let news: [AlpacaNewsItem]

        private enum CodingKeys: String, CodingKey {
            case news
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard container.contains(.news) else {
                throw DecodingError.keyNotFound(
                    CodingKeys.news,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Alpaca news envelope missing news key"
                    )
                )
            }
            news = try container.decodeIfPresent([AlpacaNewsItem].self, forKey: .news) ?? []
        }
    }

    private let environment: Environment
    private let keychainProvider: KeychainCredentialsProvider
    private let session: URLSession
    private let now: @Sendable () -> TimeInterval
    private var rateLimiter: TokenBucketRateLimiter

    public init(
        environment: Environment = .paper,
        keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider(),
        session: URLSession = .shared,
        rateLimiter: TokenBucketRateLimiter? = nil,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.environment = environment
        self.keychainProvider = keychainProvider
        self.session = session
        self.now = now
        self.rateLimiter = rateLimiter ?? TokenBucketRateLimiter(
            capacity: 60,
            refillRatePerSecond: 1,
            initialTime: now()
        )
    }

    public func fetchLatest(limit: Int) async throws -> [AlpacaNewsItem] {
        let resolvedLimit = min(max(limit, 1), 50)
        do {
            try rateLimiter.acquire(at: now())
        } catch RateLimiterError.rateLimited(let retryAfter) {
            throw AlpacaAPIError.localRateLimited(retryAfter: retryAfter)
        } catch {
            throw AlpacaAPIError.transportFailure(message: "Rate limiter failed")
        }

        guard let credentials = keychainProvider.credentials(for: environment) else {
            throw AlpacaAPIError.missingCredentials(environment: environment)
        }

        var components = URLComponents(
            url: environment.marketDataRESTBaseURL,
            resolvingAgainstBaseURL: false
        )
        components?.path = "/v1beta1/news"
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(resolvedLimit))
        ]

        guard let url = components?.url else {
            throw AlpacaAPIError.transportFailure(message: "Unable to construct Alpaca news URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(credentials.publicKey, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credentials.secretKey, forHTTPHeaderField: "APCA-API-SECRET-KEY")

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw AlpacaAPIError.transportFailure(message: error.localizedDescription)
        }

        guard let response = result.1 as? HTTPURLResponse else {
            throw AlpacaAPIError.transportFailure(message: "Unexpected response type")
        }

        guard (200...299).contains(response.statusCode) else {
            throw mapHTTPError(data: result.0, response: response)
        }

        let decoder = Self.makeDecoder()
        if let envelope = try? decoder.decode(NewsEnvelope.self, from: result.0) {
            return envelope.news
        }
        if let news = try? decoder.decode([AlpacaNewsItem].self, from: result.0) {
            return news
        }
        if let payload = try? JSONDecoder().decode(AlpacaNewsErrorPayload.self, from: result.0),
           let message = payload.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           message.isEmpty == false {
            throw AlpacaAPIError.requestFailed(
                httpStatus: response.statusCode,
                alpacaMessage: "Alpaca news returned a non-news message envelope: \(String(message.prefix(180)))",
                requestID: response.value(forHTTPHeaderField: "apca-request-id")
            )
        }

        throw AlpacaAPIError.decodingFailed(
            httpStatus: response.statusCode,
            alpacaMessage: "Unable to decode Alpaca news payload",
            requestID: response.value(forHTTPHeaderField: "apca-request-id")
        )
    }

    private func mapHTTPError(data: Data, response: HTTPURLResponse) -> AlpacaAPIError {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let message = (try? decoder.decode(AlpacaNewsErrorPayload.self, from: data))?.message
        let requestID = response.value(forHTTPHeaderField: "apca-request-id")
            ?? response.value(forHTTPHeaderField: "x-request-id")

        if response.statusCode == 429 {
            let retryAfter = TimeInterval(response.value(forHTTPHeaderField: "Retry-After") ?? "")
            return .rateLimited(
                httpStatus: response.statusCode,
                alpacaMessage: message,
                requestID: requestID,
                retryAfter: retryAfter
            )
        }

        return .requestFailed(
            httpStatus: response.statusCode,
            alpacaMessage: message,
            requestID: requestID
        )
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return decoder
    }
}

private struct AlpacaNewsErrorPayload: Decodable {
    let message: String?
}

public enum NewsEventFactory {
    public static func makeFromRSS(
        source: String,
        feedTags: [String],
        item: RSSItem,
        now: Date
    ) -> NewsEvent {
        let published = item.publishedAt ?? now
        let identitySeed = [
            source,
            item.guid ?? "",
            item.link ?? "",
            item.title,
            iso8601(published)
        ].joined(separator: "|")

        return NewsEvent(
            eventId: "news_\(stableHash(identitySeed))",
            source: source,
            title: item.title,
            url: item.link,
            publishedAt: published,
            receivedAt: now,
            summary: item.summary,
            rawSymbolHints: extractSymbolHints(from: item.title + " " + (item.summary ?? "")),
            tags: feedTags,
            payloadVersion: 1
        )
    }

    public static func makeFromAlpaca(
        item: AlpacaNewsItem,
        now: Date
    ) -> NewsEvent {
        let published = item.updatedAt ?? item.createdAt ?? now
        let identitySeed = [
            "alpaca_news",
            item.id ?? "",
            item.url ?? "",
            item.headline,
            iso8601(published)
        ].joined(separator: "|")

        return NewsEvent(
            eventId: "news_\(stableHash(identitySeed))",
            source: "alpaca_news",
            title: item.headline,
            url: item.url,
            publishedAt: published,
            receivedAt: now,
            summary: item.summary,
            rawSymbolHints: item.symbols ?? extractSymbolHints(from: item.headline),
            tags: ["alpaca"],
            payloadVersion: 1
        )
    }

    public static func makeFromSECFiling(
        filing: SECRecentFiling,
        now: Date
    ) -> NewsEvent {
        let published = filing.acceptedAt ?? filing.filedAt
        let identitySeed = [
            "sec_edgar",
            filing.symbol,
            filing.formType,
            filing.accessionNumber,
            iso8601(published)
        ].joined(separator: "|")

        let subject = filing.companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? filing.symbol
            : filing.companyName
        let filingDateText = filing.acceptedAt.map { DateCodec.formatISO8601($0) }
            ?? DateCodec.formatISO8601(filing.filedAt)
        let description = filing.primaryDocumentDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionSuffix: String
        if let description, !description.isEmpty, description.caseInsensitiveCompare(filing.formType) != .orderedSame {
            descriptionSuffix = " \(description)."
        } else {
            descriptionSuffix = ""
        }

        return NewsEvent(
            eventId: "news_\(stableHash(identitySeed))",
            source: "sec_edgar",
            title: "\(subject) filed \(filing.formType)",
            url: filing.filingURL,
            publishedAt: published,
            receivedAt: now,
            summary: "\(subject) filed SEC \(filing.formType) on \(filingDateText).\(descriptionSuffix)",
            rawSymbolHints: [filing.symbol],
            tags: ["sec", "edgar", filing.formType.lowercased()],
            payloadVersion: 1
        )
    }

    private static func extractSymbolHints(from text: String) -> [String] {
        let pattern = #"\b[A-Z]{1,5}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(location: 0, length: (text as NSString).length)
        let matches = regex.matches(in: text, options: [], range: range)
        let values = matches.compactMap { match -> String? in
            guard let swiftRange = Range(match.range, in: text) else {
                return nil
            }
            let value = String(text[swiftRange]).uppercased()
            if value.count <= 1 {
                return nil
            }
            return value
        }
        return Array(Set(values)).sorted()
    }

    private static func iso8601(_ date: Date) -> String {
        DateCodec.formatISO8601(date)
    }

    private static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return String(hash, radix: 16)
    }
}
