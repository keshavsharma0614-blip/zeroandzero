import Darwin
import Foundation

public protocol AnalystControlPlaneClient: Sendable {
    func listCharters() async throws -> [AnalystCharter]
    func upsertCharter(_ charter: AnalystCharter) async throws -> AnalystCharter
    func listSourceAccessSuggestions() async throws -> [AnalystSourceAccessSuggestionRecord]
    func upsertSourceAccessSuggestion(_ suggestion: AnalystSourceAccessSuggestionRecord) async throws -> AnalystSourceAccessSuggestionRecord
    func listTasks() async throws -> [AnalystTask]
    func getTask(id: String) async throws -> AnalystTask
    func upsertTask(_ task: AnalystTask) async throws -> AnalystTask
    func listMemos() async throws -> [AnalystMemo]
    func getMemo(id: String) async throws -> AnalystMemo
    func listNews(limit: Int, since: Date?) async throws -> [NewsEvent]
    func upsertEvidenceBundle(_ bundle: AnalystEvidenceBundle) async throws -> AnalystEvidenceBundle
    func upsertMemo(_ memo: AnalystMemo) async throws -> AnalystMemo
    func upsertFinding(_ finding: AnalystFinding) async throws -> AnalystFinding
    func draftSignalFromFinding(id: String) async throws -> Signal
    func draftProposalFromSignal(id: String, strategyID: String) async throws -> StrategyProposal
}

public protocol OpenAIKeyStatusProviding: Sendable {
    func apiKey() -> String?
    func isConfigured() -> Bool
    func credentialResolution() -> OpenAICredentialResolution
}

public extension OpenAIKeyStatusProviding {
    func credentialResolution() -> OpenAICredentialResolution {
        guard let apiKey = apiKey() else {
            return OpenAICredentialResolution(
                status: .missingKey,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "No OpenAI API key is available through the configured credential provider."
            )
        }
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return OpenAICredentialResolution(
                status: .emptyKey,
                account: OpenAIKeychainCredentialResolver.account,
                summary: "The configured OpenAI API key provider returned an empty key value."
            )
        }
        return OpenAICredentialResolution(
            status: .ready,
            apiKey: trimmed,
            source: .inferred,
            account: OpenAIKeychainCredentialResolver.account,
            summary: "OpenAI API key resolved through the configured credential provider."
        )
    }
}

public struct ExternalAnalystEvidenceDocument: Sendable, Equatable {
    public let sourceID: String
    public let url: String
    public let title: String
    public let observedAt: Date?
    public let summary: String
    public let snippet: String
    public let provenanceNote: String
    public let sourceTier: AnalystResearchSourceTier

    public init(
        sourceID: String,
        url: String,
        title: String,
        observedAt: Date?,
        summary: String,
        snippet: String,
        provenanceNote: String,
        sourceTier: AnalystResearchSourceTier = .reputableSecondary
    ) {
        self.sourceID = sourceID
        self.url = url
        self.title = title
        self.observedAt = observedAt
        self.summary = summary
        self.snippet = snippet
        self.provenanceNote = provenanceNote
        self.sourceTier = sourceTier
    }
}

public enum AnalystResearchSourceTier: String, Sendable, Equatable, CaseIterable {
    case appOwnedTruth = "app_owned_truth"
    case officialPrimary = "official_primary"
    case reputableSecondary = "reputable_secondary"
    case missingOrRestricted = "missing_or_restricted"

    public var displayTitle: String {
        switch self {
        case .appOwnedTruth:
            return "App-Owned Truth"
        case .officialPrimary:
            return "Official / Primary"
        case .reputableSecondary:
            return "Reputable Secondary"
        case .missingOrRestricted:
            return "Missing / Restricted"
        }
    }
}

enum AnalystResearchCandidateAccessMode: String, Sendable, Equatable {
    case publicOpen = "public_open"
    case signUpGated = "sign_up_gated"
    case subscriptionGated = "subscription_gated"
    case restrictedByPolicy = "restricted_by_policy"
    case unsupportedByTooling = "unsupported_by_tooling"
}

enum AnalystResearchCandidateKind: String, Sendable, Equatable {
    case appNewsLinked = "app_news_linked"
    case preferredPublic = "preferred_public"
    case preferredGap = "preferred_gap"
    case sectorSpecificPublic = "sector_specific_public"
    case sectorSpecificGap = "sector_specific_gap"
}

struct AnalystResearchSourceCandidate: Sendable, Equatable {
    let candidateID: String
    let kind: AnalystResearchCandidateKind
    let label: String
    let category: String
    let requestedSource: String
    let requestedDomain: String?
    let accessMode: AnalystResearchCandidateAccessMode
    let sourceTier: AnalystResearchSourceTier
    let whyItMatters: String
    let missingInformationHint: String
    let approvedSource: ApprovedAnalystSourceDefinition?
}

struct AnalystResearchPlan: Sendable, Equatable {
    struct PublicTarget: Sendable, Equatable {
        let candidateID: String
        let label: String
        let category: String
        let whyItMatters: String
        let approvedSource: ApprovedAnalystSourceDefinition
    }

    struct SourceGap: Sendable, Equatable {
        let candidateID: String
        let requestedSource: String
        let requestedDomain: String?
        let whyItMatters: String
        let missingInformationNeed: String
        let limitation: AnalystSourceAccessSuggestionLimitation
        let recommendedNextStep: AnalystSourceAccessSuggestionNextStep
    }

    let planSummary: String
    let missingInformation: [String]
    let researchQuestions: [String]
    let publicTargets: [PublicTarget]
    let sourceGaps: [SourceGap]

    var selectedSourceDefinitions: [ApprovedAnalystSourceDefinition] {
        publicTargets.map(\.approvedSource)
    }
}

public protocol AnalystResearchPlanningProviding: Sendable {
    func planResearch(
        request: AnalystResearchPlanningRequest,
        apiKey: String
    ) async throws -> AnalystResearchPlanningOutput
}

public protocol ExternalAnalystEvidenceProviding: Sendable {
    func fetchEvidence(
        for charter: AnalystCharter,
        task: AnalystTask,
        baselineNews: [NewsEvent],
        plannedSources: [ApprovedAnalystSourceDefinition]
    ) async -> AnalystExternalEvidenceFetchResult
}

public protocol ExternalAnalystHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct OpenAIKeychainStatusProvider: OpenAIKeyStatusProviding, Sendable {
    public static let service = "open_api_key"
    public static let account = "algo-trading"

    private let credentialResolver: OpenAIKeychainCredentialResolver

    public init(
        keychainProvider: KeychainCredentialsProvider = KeychainCredentialsProvider(),
        labelReader: @escaping @Sendable (String, String) -> String? = SystemKeyReader.readKey(label:account:),
        providerSettingsStore: LLMProviderSettingsStore? = LLMProviderSettingsStore(),
        cache: OpenAIKeychainCredentialResolutionCache? = .shared
    ) {
        self.credentialResolver = OpenAIKeychainCredentialResolver(
            keychainProvider: keychainProvider,
            labelReader: labelReader,
            providerSettingsStore: providerSettingsStore,
            cache: cache
        )
    }

    public func apiKey() -> String? {
        credentialResolution().apiKey
    }

    public func isConfigured() -> Bool {
        credentialResolution().isReady
    }

    public func credentialResolution() -> OpenAICredentialResolution {
        credentialResolver.resolve()
    }
}

public struct StaticOpenAIKeyStatusProvider: OpenAIKeyStatusProviding, Sendable {
    private let resolvedKey: String?

    public init(apiKey: String?) {
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.resolvedKey = trimmed?.isEmpty == false ? trimmed : nil
    }

    public func apiKey() -> String? {
        resolvedKey
    }

    public func isConfigured() -> Bool {
        resolvedKey != nil
    }
}

public enum AnalystIPCClientError: Error, Sendable, Equatable {
    case missingResult
    case invalidURL
    case invalidResponse
    case transport(
        category: String,
        host: String,
        port: Int,
        tokenPresent: Bool,
        metadataSource: String,
        attempts: Int
    )
    case unauthorized(
        host: String,
        port: Int,
        tokenPresent: Bool,
        metadataSource: String
    )
    case server(code: String, message: String)
}

public enum AnalystWorkerSelectionError: Error, Sendable, Equatable {
    case charterNotFound(id: String)
    case ambiguousCharterSelection(availableCharterIDs: [String])
    case cannotSeedRequestedCharter(id: String, seedCharterID: String)
    case invalidDraftSelection(reason: String)
    case providerSynthesisFailed(reason: String)
}

extension AnalystWorkerSelectionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .charterNotFound(let id):
            return "Analyst charter not found: \(id)."
        case .ambiguousCharterSelection(let availableCharterIDs):
            return "Analyst charter selection is ambiguous. Available charters: \(availableCharterIDs.joined(separator: ", "))."
        case .cannotSeedRequestedCharter(let id, let seedCharterID):
            return "Requested charter \(id) could not be seeded from \(seedCharterID)."
        case .invalidDraftSelection(let reason):
            return reason
        case .providerSynthesisFailed(let reason):
            return reason
        }
    }
}

public enum AnalystExternalEvidenceError: Error, Sendable, Equatable {
    case noApprovedSources(charterID: String)
    case transport(host: String, description: String)
    case httpStatus(host: String, statusCode: Int)
    case invalidResponse(host: String)
    case invalidContent(host: String)
}

extension AnalystExternalEvidenceError: LocalizedError {
    public var errorDescription: String? {
        asIssue().boundedSummary
    }

    fileprivate func asIssue() -> AnalystExternalEvidenceIssue {
        switch self {
        case .noApprovedSources(let charterID):
            return AnalystExternalEvidenceIssue(
                category: .noApprovedSources,
                detail: "charter=\(charterID)"
            )
        case .transport(let host, let description):
            return AnalystExternalEvidenceIssue(
                category: .transport,
                host: host,
                detail: description
            )
        case .httpStatus(let host, let statusCode):
            return AnalystExternalEvidenceIssue(
                category: .httpStatus,
                host: host,
                statusCode: statusCode,
                detail: "non_success_status"
            )
        case .invalidResponse(let host):
            return AnalystExternalEvidenceIssue(
                category: .invalidResponse,
                host: host,
                detail: "non_http_or_missing_response"
            )
        case .invalidContent(let host):
            return AnalystExternalEvidenceIssue(
                category: .invalidContent,
                host: host,
                detail: "empty_or_unsupported_html_content"
            )
        }
    }
}

public enum AnalystExternalEvidenceIssueCategory: String, Sendable, Equatable {
    case noApprovedSources = "no_approved_sources"
    case transport = "transport"
    case httpStatus = "http_status"
    case invalidResponse = "invalid_response"
    case invalidContent = "invalid_content"
    case unexpected = "unexpected"
}

public struct AnalystExternalEvidenceIssue: Sendable, Equatable {
    public let category: AnalystExternalEvidenceIssueCategory
    public let host: String?
    public let statusCode: Int?
    public let detail: String

    public init(
        category: AnalystExternalEvidenceIssueCategory,
        host: String? = nil,
        statusCode: Int? = nil,
        detail: String
    ) {
        self.category = category
        self.host = host
        self.statusCode = statusCode
        self.detail = detail
    }

    public var boundedSummary: String {
        var parts = ["category=\(category.rawValue)"]
        if let host, !host.isEmpty {
            parts.append("host=\(host)")
        }
        if let statusCode {
            parts.append("status=\(statusCode)")
        }
        if !detail.isEmpty {
            parts.append("detail=\(detail)")
        }
        return parts.joined(separator: " ")
    }
}

public struct AnalystExternalEvidenceFetchResult: Sendable, Equatable {
    public let documents: [ExternalAnalystEvidenceDocument]
    public let issues: [AnalystExternalEvidenceIssue]

    public init(
        documents: [ExternalAnalystEvidenceDocument],
        issues: [AnalystExternalEvidenceIssue] = []
    ) {
        self.documents = documents
        self.issues = issues
    }
}

public struct ApprovedAnalystSourceDefinition: Sendable, Equatable {
    public let sourceID: String
    public let url: URL
    public let titleHint: String
    public let provenanceNote: String
    public let allowsDiscovery: Bool
    public let sourceTier: AnalystResearchSourceTier

    public init(
        sourceID: String,
        url: URL,
        titleHint: String,
        provenanceNote: String,
        allowsDiscovery: Bool = false,
        sourceTier: AnalystResearchSourceTier = .reputableSecondary
    ) {
        self.sourceID = sourceID
        self.url = url
        self.titleHint = titleHint
        self.provenanceNote = provenanceNote
        self.allowsDiscovery = allowsDiscovery
        self.sourceTier = sourceTier
    }
}

private enum CrucialSiteSourceClass: String, Sendable {
    case investorRelations = "investor_relations"
    case issuerRegulatorExchange = "issuer_regulator_exchange"
    case companyPressBlog = "company_press_blog"
    case industryPublication = "industry_publication"
    case genericPublicWeb = "generic_public_web"
}

public actor AnalystIPCClient: AnalystControlPlaneClient {
    private let runtimeInfoStore: AgentControlRuntimeInfoStore
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        runtimeInfoStore: AgentControlRuntimeInfoStore = AgentControlRuntimeInfoStore(),
        session: URLSession = .shared
    ) {
        self.runtimeInfoStore = runtimeInfoStore
        self.session = session
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        self.decoder = decoder
    }

    public func listCharters() async throws -> [AnalystCharter] {
        try await request(method: "GET", path: "/analyst/charters", responseType: [AnalystCharter].self)
    }

    public func upsertCharter(_ charter: AnalystCharter) async throws -> AnalystCharter {
        try await request(
            method: "POST",
            path: "/analyst/charter/upsert",
            body: try encoder.encode(charter),
            responseType: AnalystCharter.self
        )
    }

    public func listSourceAccessSuggestions() async throws -> [AnalystSourceAccessSuggestionRecord] {
        try await request(
            method: "GET",
            path: "/analyst/source-access-suggestions",
            responseType: [AnalystSourceAccessSuggestionRecord].self
        )
    }

    public func upsertSourceAccessSuggestion(_ suggestion: AnalystSourceAccessSuggestionRecord) async throws -> AnalystSourceAccessSuggestionRecord {
        try await request(
            method: "POST",
            path: "/analyst/source-access-suggestion/upsert",
            body: try encoder.encode(suggestion),
            responseType: AnalystSourceAccessSuggestionRecord.self
        )
    }

    public func listTasks() async throws -> [AnalystTask] {
        try await request(method: "GET", path: "/analyst/tasks", responseType: [AnalystTask].self)
    }

    public func getTask(id: String) async throws -> AnalystTask {
        try await request(method: "GET", path: "/analyst/task?id=\(id)", responseType: AnalystTask.self)
    }

    public func upsertTask(_ task: AnalystTask) async throws -> AnalystTask {
        try await request(
            method: "POST",
            path: "/analyst/task/upsert",
            body: try encoder.encode(task),
            responseType: AnalystTask.self
        )
    }

    public func listMemos() async throws -> [AnalystMemo] {
        try await request(method: "GET", path: "/analyst/memos", responseType: [AnalystMemo].self)
    }

    public func getMemo(id: String) async throws -> AnalystMemo {
        try await request(method: "GET", path: "/analyst/memo?id=\(id)", responseType: AnalystMemo.self)
    }

    public func listNews(limit: Int, since: Date?) async throws -> [NewsEvent] {
        var path = "/analyst/news?limit=\(max(1, limit))"
        if let since {
            path += "&since=\(DateCodec.formatISO8601(since))"
        }
        return try await request(method: "GET", path: path, responseType: [NewsEvent].self)
    }

    public func upsertEvidenceBundle(_ bundle: AnalystEvidenceBundle) async throws -> AnalystEvidenceBundle {
        try await request(
            method: "POST",
            path: "/analyst/evidence-bundle/upsert",
            body: try encoder.encode(bundle),
            responseType: AnalystEvidenceBundle.self
        )
    }

    public func upsertMemo(_ memo: AnalystMemo) async throws -> AnalystMemo {
        try await request(
            method: "POST",
            path: "/analyst/memo/upsert",
            body: try encoder.encode(memo),
            responseType: AnalystMemo.self
        )
    }

    public func upsertFinding(_ finding: AnalystFinding) async throws -> AnalystFinding {
        try await request(
            method: "POST",
            path: "/analyst/finding/upsert",
            body: try encoder.encode(finding),
            responseType: AnalystFinding.self
        )
    }

    public func draftSignalFromFinding(id: String) async throws -> Signal {
        try await request(
            method: "POST",
            path: "/analyst/finding/draft-signal",
            body: try encoder.encode(JSONValue.object(["findingId": .string(id)])),
            responseType: Signal.self
        )
    }

    public func draftProposalFromSignal(id: String, strategyID: String) async throws -> StrategyProposal {
        try await request(
            method: "POST",
            path: "/analyst/signal/draft-proposal",
            body: try encoder.encode(JSONValue.object([
                "signalId": .string(id),
                "strategyId": .string(strategyID)
            ])),
            responseType: StrategyProposal.self
        )
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        let runtimeInfo = try runtimeInfoStore.load()
        let metadataSource = Self.runtimeMetadataSourceLabel(try? runtimeInfoStore.fileURL())
        guard let url = URL(string: "http://\(runtimeInfo.host):\(runtimeInfo.port)\(path)") else {
            throw AnalystIPCClientError.invalidURL
        }

        var lastTransportError: AnalystIPCClientError?
        for attempt in 1...Self.maxRequestAttempts {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = Self.requestTimeoutInterval
            request.setValue(runtimeInfo.token, forHTTPHeaderField: "X-Agent-Token")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                let category = Self.transportCategory(for: error)
                let transportError = AnalystIPCClientError.transport(
                    category: category,
                    host: runtimeInfo.host,
                    port: runtimeInfo.port,
                    tokenPresent: runtimeInfo.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                    metadataSource: metadataSource,
                    attempts: attempt
                )
                lastTransportError = transportError
                if attempt < Self.maxRequestAttempts,
                   Self.isRetryableTransportCategory(category) {
                    try? await Task.sleep(nanoseconds: Self.retryDelayNanoseconds(forAttempt: attempt))
                    continue
                }
                throw transportError
            }

            guard let http = response as? HTTPURLResponse else {
                throw AnalystIPCClientError.invalidResponse
            }

            let envelope = try decoder.decode(AgentControlEnvelope.self, from: data)
            if http.statusCode == 401 || envelope.error?.code == "unauthorized" {
                throw AnalystIPCClientError.unauthorized(
                    host: runtimeInfo.host,
                    port: runtimeInfo.port,
                    tokenPresent: runtimeInfo.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                    metadataSource: metadataSource
                )
            }
            if envelope.ok == false {
                let code = envelope.error?.code ?? "ipc_failed"
                let message = envelope.error?.message ?? "IPC request failed"
                throw AnalystIPCClientError.server(code: code, message: message)
            }
            guard let result = envelope.result else {
                throw AnalystIPCClientError.missingResult
            }
            return try decoder.decode(T.self, from: encoder.encode(result))
        }

        if let lastTransportError {
            throw lastTransportError
        }
        throw AnalystIPCClientError.invalidResponse
    }

    private static let maxRequestAttempts = 4
    private static let requestTimeoutInterval: TimeInterval = 3

    private static func retryDelayNanoseconds(forAttempt attempt: Int) -> UInt64 {
        let delays: [UInt64] = [100_000_000, 250_000_000, 500_000_000]
        return delays[min(max(0, attempt - 1), delays.count - 1)]
    }

    private static func isRetryableTransportCategory(_ category: String) -> Bool {
        switch category {
        case "connection_refused",
             "timed_out",
             "network_connection_lost",
             "not_connected",
             "transport_error":
            return true
        default:
            return false
        }
    }

    private static func transportCategory(for error: Error) -> String {
        let nsError = error as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           underlying.code == ECONNREFUSED {
            return "connection_refused"
        }
        guard nsError.domain == NSURLErrorDomain else {
            return "transport_error"
        }
        switch nsError.code {
        case NSURLErrorCannotConnectToHost:
            return "connection_refused"
        case NSURLErrorTimedOut:
            return "timed_out"
        case NSURLErrorNetworkConnectionLost:
            return "network_connection_lost"
        case NSURLErrorCannotFindHost:
            return "cannot_find_host"
        case NSURLErrorNotConnectedToInternet:
            return "not_connected"
        default:
            return "transport_error"
        }
    }

    private static func runtimeMetadataSourceLabel(_ url: URL?) -> String {
        guard let url else {
            return "unknown"
        }
        let root = AppSupportPaths.rootDirectory().standardizedFileURL
        let standardized = url.standardizedFileURL
        if standardized.path.hasPrefix(root.path) {
            return "app_support/\(standardized.lastPathComponent)"
        }
        return standardized.lastPathComponent
    }
}

public struct ApprovedAnalystSourceCatalog: Sendable {
    private let resolve: @Sendable (AnalystCharter, [NewsEvent]) -> [ApprovedAnalystSourceDefinition]

    public init(resolve: @escaping @Sendable (AnalystCharter, [NewsEvent]) -> [ApprovedAnalystSourceDefinition]) {
        self.resolve = resolve
    }

    public init() {
        self.resolve = { charter, baselineNews in
            let sourcePolicy = charter.sourcePolicy
            let preferredSources = Set(sourcePolicy.preferredSources.map { $0.lowercased() })
            guard sourcePolicy.reputableWebResearchAllowed else {
                return []
            }
            var sources: [ApprovedAnalystSourceDefinition] = []

            for newsItem in baselineNews.prefix(6) {
                guard let source = appNewsLinkedSourceDefinition(
                    from: newsItem,
                    charter: charter
                ) else {
                    continue
                }
                sources.append(source)
            }

            for preferredSource in sourcePolicy.preferredSources {
                guard let explicitSource = explicitPreferredSourceDefinition(
                    from: preferredSource,
                    charter: charter
                ) else {
                    continue
                }
                sources.append(explicitSource)
            }

            if charter.charterId == AnalystCharterSeed.charterId
                || preferredSources.contains("stanford ai index report")
                || preferredSources.contains("stanford ai index")
                || preferredSources.contains("reference_research")
                || preferredSources.contains("reputable research/reference sources")
                || charter.allowedSources.contains("approved_allowlist_source:stanford_ai_index") {
                sources.append(
                    ApprovedAnalystSourceDefinition(
                        sourceID: "stanford-ai-index-report",
                        url: URL(string: "https://aiindex.stanford.edu/report/")!,
                        titleHint: "Stanford AI Index Report",
                        provenanceNote: "charter_preferred_source:stanford_ai_index_report",
                        sourceTier: .reputableSecondary
                    )
                )
            }

            var uniqueSources: [ApprovedAnalystSourceDefinition] = []
            var seenURLs = Set<String>()
            for source in sources {
                let normalizedURL = source.url.absoluteString.lowercased()
                guard seenURLs.insert(normalizedURL).inserted else {
                    continue
                }
                uniqueSources.append(source)
            }
            return uniqueSources
        }
    }

    public func sources(
        for charter: AnalystCharter,
        baselineNews: [NewsEvent] = []
    ) -> [ApprovedAnalystSourceDefinition] {
        resolve(charter, baselineNews)
    }
}

private func explicitPreferredSourceDefinition(
    from preferredSource: String,
    charter: AnalystCharter
) -> ApprovedAnalystSourceDefinition? {
    let trimmed = preferredSource.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = normalizedPublicSourceURL(from: trimmed),
          isAllowedPublicSourceURL(url, charter: charter) else {
        return nil
    }

    let titleHint = url.host?.replacingOccurrences(of: "www.", with: "") ?? trimmed
    let sourceID = "charter-source-\(stableIdentifier(prefix: "source", components: [url.absoluteString.lowercased()]))"
    let sourceClass = inferCrucialSiteSourceClass(for: url, titleHint: titleHint)
    let allowsDiscovery = supportsBoundedDiscovery(for: url, sourceClass: sourceClass)
    return ApprovedAnalystSourceDefinition(
        sourceID: sourceID,
        url: url,
        titleHint: titleHint,
        provenanceNote: "charter_preferred_public_source:\(url.host?.lowercased() ?? url.absoluteString.lowercased())",
        allowsDiscovery: allowsDiscovery,
        sourceTier: sourceTierForResearchSource(url: url, titleHint: titleHint)
    )
}

private func appNewsLinkedSourceDefinition(
    from newsItem: NewsEvent,
    charter: AnalystCharter
) -> ApprovedAnalystSourceDefinition? {
    guard let rawURL = newsItem.url,
          let url = URL(string: rawURL),
          isAllowedPublicSourceURL(url, charter: charter) else {
        return nil
    }
    return ApprovedAnalystSourceDefinition(
        sourceID: "app-news-linked-\(newsItem.eventId)",
        url: url,
        titleHint: newsItem.title,
        provenanceNote: "supplemental_public_web_from_app_news:\(url.host?.lowercased() ?? "unknown_host")",
        allowsDiscovery: false,
        sourceTier: sourceTierForResearchSource(url: url, titleHint: newsItem.title)
    )
}

private enum AnalystResearchEvidenceMode: Sendable, Equatable {
    case secondaryAssisted
    case primaryOnly
}

private func researchPlanPublicTargetLimit(for mode: AnalystResearchEvidenceMode) -> Int {
    switch mode {
    case .secondaryAssisted:
        return 10
    case .primaryOnly:
        return 6
    }
}

private func fallbackNonAppPublicTargetLimit(for mode: AnalystResearchEvidenceMode) -> Int {
    switch mode {
    case .secondaryAssisted:
        return 8
    case .primaryOnly:
        return 4
    }
}

private func externalEvidenceDocumentLimit(
    for mode: AnalystResearchEvidenceMode,
    configuredLimit: Int
) -> Int {
    switch mode {
    case .secondaryAssisted:
        return max(configuredLimit, 10)
    case .primaryOnly:
        return configuredLimit
    }
}

private func externalEvidenceDiscoveryLimit(
    for mode: AnalystResearchEvidenceMode,
    configuredLimit: Int
) -> Int {
    switch mode {
    case .secondaryAssisted:
        return max(configuredLimit, 4)
    case .primaryOnly:
        return configuredLimit
    }
}

private func researchEvidenceMode(for task: AnalystTask) -> AnalystResearchEvidenceMode {
    let text = taskResearchText(task).lowercased()
    let secondaryAssistedSignals = [
        "use reputable secondary",
        "secondary sources for discovery",
        "secondary-source evidence",
        "secondary assisted",
        "secondary-assisted",
        "discovery and corroboration if needed",
        "corroboration if needed"
    ]
    if secondaryAssistedSignals.contains(where: { text.contains($0) }) {
        return .secondaryAssisted
    }

    let primaryOnlySignals = [
        "official-only",
        "official source only",
        "official sources only",
        "only official",
        "primary-only",
        "primary source only",
        "primary sources only",
        "only primary",
        "do not use secondary",
        "do not use third-party",
        "block rather than infer",
        "extract holdings only from official"
    ]
    if primaryOnlySignals.contains(where: { text.contains($0) }) {
        return .primaryOnly
    }

    return .secondaryAssisted
}

private func taskResearchText(_ task: AnalystTask) -> String {
    let brief = task.pmTaskingBrief
    let briefParts = [
        brief?.taskObjective,
        brief?.whyNow,
        brief?.reviewLens,
        brief?.challengeInstruction,
        brief?.evidenceExpectation,
        brief?.disconfirmingEvidenceExpectation,
        brief?.revisionReason
    ].compactMap { $0 }
    return ([task.title, task.description] + briefParts + (brief?.expectedOutputs ?? []))
        .joined(separator: "\n")
}

private func normalizedCIKs(in text: String) -> [String] {
    let explicitMatches = text.matches(for: #"(?i)\bcik\s*[:#-]?\s*0*([0-9]{1,10})\b"#)
    let barePaddedMatches = text.matches(for: #"\b(0{3,}[0-9]{4,10})\b"#)
    var results: [String] = []
    var seen = Set<String>()

    for raw in explicitMatches + barePaddedMatches {
        let digits = String(raw.filter { $0.isNumber })
        guard digits.isEmpty == false, digits.count <= 10 else {
            continue
        }
        let padded = String(repeating: "0", count: max(0, 10 - digits.count)) + digits
        guard seen.insert(padded).inserted else {
            continue
        }
        results.append(padded)
    }
    return results
}

private func sourceTierForResearchSource(
    category: String,
    urlString: String?,
    titleHint: String
) -> AnalystResearchSourceTier {
    if let urlString,
       let url = normalizedPublicSourceURL(from: urlString) {
        return sourceTierForResearchSource(url: url, titleHint: titleHint, category: category)
    }
    let lowered = [category, titleHint].joined(separator: " ").lowercased()
    if lowered.contains("official")
        || lowered.contains("regulator")
        || lowered.contains("filing")
        || lowered.contains("clinical_primary")
        || lowered.contains("macro_policy")
        || lowered.contains("official_data") {
        return .officialPrimary
    }
    if lowered.contains("restricted") || lowered.contains("unsupported") {
        return .missingOrRestricted
    }
    return .reputableSecondary
}

private func sourceTierForResearchSource(
    url: URL,
    titleHint: String,
    category: String = ""
) -> AnalystResearchSourceTier {
    let host = url.host?.lowercased() ?? ""
    let descriptor = [host, url.path.lowercased(), titleHint.lowercased(), category.lowercased()]
        .joined(separator: " ")
    if host.hasSuffix(".gov")
        || host == "sec.gov"
        || host == "www.sec.gov"
        || host == "data.sec.gov"
        || host.contains("fda.gov")
        || host.contains("clinicaltrials.gov")
        || host.contains("federalreserve.gov")
        || host.contains("fdic.gov")
        || host.contains("eia.gov")
        || host.contains("ecb.europa.eu")
        || host.contains("imf.org")
        || descriptor.contains("official")
        || descriptor.contains("regulator")
        || descriptor.contains("filing")
        || descriptor.contains("investor relations") {
        return .officialPrimary
    }

    switch inferCrucialSiteSourceClass(for: url, titleHint: titleHint) {
    case .investorRelations, .issuerRegulatorExchange, .companyPressBlog:
        return .officialPrimary
    case .industryPublication, .genericPublicWeb:
        return .reputableSecondary
    }
}

private func normalizedPublicSourceURL(from value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed),
       url.scheme?.lowercased() == "https",
       url.host != nil {
        return url
    }
    let lowered = trimmed.lowercased()
    guard lowered.contains(" ") == false,
          lowered.contains("."),
          lowered.contains("/") == false else {
        return nil
    }
    return URL(string: "https://\(lowered)")
}

private func isAllowedPublicSourceURL(_ url: URL, charter: AnalystCharter) -> Bool {
    guard url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(),
          host.isEmpty == false,
          url.user == nil,
          url.password == nil,
          pathLooksInteractive(url) == false else {
        return false
    }
    return isRestrictedHost(host, charter: charter) == false
}

private func isRestrictedSourceDescriptor(_ descriptor: String, charter: AnalystCharter) -> Bool {
    if let url = normalizedPublicSourceURL(from: descriptor),
       let host = url.host?.lowercased() {
        return isRestrictedHost(host, charter: charter)
    }
    let lowered = descriptor.lowercased()
    return charter.sourcePolicy.restrictedSources.contains { restricted in
        lowered == restricted.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private func isRestrictedHost(_ host: String, charter: AnalystCharter) -> Bool {
    let normalizedHost = host.lowercased()
    return charter.sourcePolicy.restrictedSources.contains { restricted in
        guard let restrictedURL = normalizedPublicSourceURL(from: restricted),
              let restrictedHost = restrictedURL.host?.lowercased() else {
            let value = restricted.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return value == normalizedHost
        }
        return normalizedHost == restrictedHost || normalizedHost.hasSuffix(".\(restrictedHost)")
    }
}

private func normalizeDiscoveredURL(_ rawHref: String, relativeTo baseURL: URL) -> URL? {
    let trimmed = rawHref.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return nil }

    let lowered = trimmed.lowercased()
    guard lowered.hasPrefix("#") == false,
          lowered.hasPrefix("javascript:") == false,
          lowered.hasPrefix("mailto:") == false,
          lowered.hasPrefix("tel:") == false,
          lowered.hasPrefix("data:") == false else {
        return nil
    }

    guard let resolved = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else {
        return nil
    }

    guard var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
        return nil
    }
    components.fragment = nil
    guard let normalized = components.url else {
        return nil
    }
    return normalized
}

private func discoveryKeywords(task: AnalystTask, baselineNews: [NewsEvent]) -> [String] {
    let stopWords: Set<String> = [
        "about", "after", "again", "analyst", "analysis", "because", "before", "being", "between",
        "beyond", "charter", "could", "current", "description", "detail", "during", "evidence",
        "external", "first", "from", "have", "into", "keep", "make", "memo", "more", "news",
        "only", "outside", "over", "review", "source", "supplemental", "task", "that", "their",
        "there", "these", "this", "through", "topic", "under", "update", "using", "when", "with"
    ]

    let rawValues = [task.title, task.description]
        + baselineNews.prefix(3).flatMap { newsItem in
            [newsItem.title]
                + [newsItem.summary].compactMap { $0 }
                + newsItem.rawSymbolHints
                + newsItem.tags
        }

    var keywords: [String] = []
    var seen = Set<String>()

    for value in rawValues {
        for token in value.lowercased().split(whereSeparator: { $0.isLetter == false && $0.isNumber == false }) {
            let keyword = String(token)
            guard keyword.count >= 3,
                  stopWords.contains(keyword) == false,
                  seen.insert(keyword).inserted else {
                continue
            }
            keywords.append(keyword)
            if keywords.count >= 12 {
                return keywords
            }
        }
    }

    return keywords
}

private func pathLooksInteractive(_ url: URL) -> Bool {
    let path = url.path.lowercased()
    let query = url.query?.lowercased() ?? ""
    let interactiveMarkers = [
        "/login", "/log-in", "/signin", "/sign-in", "/signup", "/sign-up",
        "/subscribe", "/account", "/auth", "login=", "signin=", "auth="
    ]
    return interactiveMarkers.contains { marker in
        path.contains(marker) || query.contains(marker)
    }
}

private extension String {
    func matches(for pattern: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        return expression.matches(in: self, options: [], range: range).compactMap { match in
            let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            guard let range = Range(captureRange, in: self) else {
                return nil
            }
            return String(self[range])
        }
    }
}

public struct URLSessionExternalAnalystHTTPClient: ExternalAnalystHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

private struct SECSubmissionsEvidenceEnvelope: Decodable {
    struct Filings: Decodable {
        let recent: Recent?
    }

    struct Recent: Decodable {
        let form: [String]?
        let filingDate: [String]?
        let accessionNumber: [String]?
        let primaryDocument: [String]?
        let reportDate: [String]?
    }

    let cik: String?
    let name: String?
    let filings: Filings?
}

private func adaptSECSubmissionsEvidenceDocument(
    html: String,
    source: ApprovedAnalystSourceDefinition,
    observedAt: Date
) -> ExternalAnalystEvidenceDocument? {
    guard source.url.host?.lowercased() == "data.sec.gov",
          source.url.path.lowercased().contains("/submissions/cik") else {
        return nil
    }
    guard let data = html.data(using: .utf8),
          let envelope = try? JSONDecoder().decode(SECSubmissionsEvidenceEnvelope.self, from: data) else {
        return nil
    }

    let cik = (envelope.cik ?? source.url.lastPathComponent)
        .replacingOccurrences(of: ".json", with: "")
    let trimmedName = envelope.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let name = trimmedName.isEmpty ? "SEC filer" : trimmedName
    let recent = envelope.filings?.recent
    let forms = recent?.form ?? []
    let filingDates = recent?.filingDate ?? []
    let accessions = recent?.accessionNumber ?? []
    let documents = recent?.primaryDocument ?? []
    let reportDates = recent?.reportDate ?? []
    let rows = forms.indices.map { index in
        (
            form: forms[index],
            filingDate: filingDates.indices.contains(index) ? filingDates[index] : "",
            accession: accessions.indices.contains(index) ? accessions[index] : "",
            document: documents.indices.contains(index) ? documents[index] : "",
            reportDate: reportDates.indices.contains(index) ? reportDates[index] : ""
        )
    }
    let thirteenFForms = rows.filter { row in
        ["13F-HR", "13F-HR/A", "13F-NT"].contains(row.form.uppercased())
    }
    var recentForms: [String] = []
    for row in rows.prefix(6) {
        let parts = [row.form, row.filingDate, row.accession].filter { $0.isEmpty == false }
        let value = parts.joined(separator: " ")
        if value.isEmpty == false {
            recentForms.append(value)
        }
    }

    let summary: String
    if thirteenFForms.isEmpty {
        let recentText = recentForms.isEmpty ? "no recent form list was recoverable" : recentForms.joined(separator: "; ")
        summary = "Official SEC submissions metadata for \(name) (CIK \(cik)) was fetched. The recent metadata did not list a 13F-HR, 13F-HR/A, or 13F-NT entry in the bounded recent array; recent forms observed: \(recentText). Treat holdings extraction as unresolved until an official archive/information-table file or reputable secondary evidence is checked."
    } else {
        let thirteenFText = thirteenFForms.prefix(4).map { row in
            var parts = ["form=\(row.form)"]
            if row.filingDate.isEmpty == false { parts.append("filed=\(row.filingDate)") }
            if row.reportDate.isEmpty == false { parts.append("report=\(row.reportDate)") }
            if row.accession.isEmpty == false { parts.append("accession=\(row.accession)") }
            if row.document.isEmpty == false { parts.append("primary_document=\(row.document)") }
            return parts.joined(separator: " ")
        }.joined(separator: "; ")
        summary = "Official SEC submissions metadata for \(name) (CIK \(cik)) lists bounded recent 13F-related filing metadata: \(thirteenFText). This source confirms official filing metadata, but holdings still require the corresponding official information-table file or clearly labeled secondary evidence."
    }

    return ExternalAnalystEvidenceDocument(
        sourceID: source.sourceID,
        url: source.url.absoluteString,
        title: "\(name) SEC submissions metadata",
        observedAt: observedAt,
        summary: summary,
        snippet: boundedEvidenceExcerpt(from: summary, limit: 420),
        provenanceNote: source.provenanceNote,
        sourceTier: .officialPrimary
    )
}

public final class ApprovedAnalystExternalEvidenceFetcher: ExternalAnalystEvidenceProviding, @unchecked Sendable {
    private struct FetchedExternalPage: Sendable {
        let source: ApprovedAnalystSourceDefinition
        let html: String
        let observedAt: Date
    }

    private let httpClient: any ExternalAnalystHTTPClient
    private let catalog: ApprovedAnalystSourceCatalog
    private let maxFetchedDocumentsPerRun: Int
    private let maxDiscoveredLinksPerSeed: Int

    public init(
        httpClient: any ExternalAnalystHTTPClient = URLSessionExternalAnalystHTTPClient(),
        catalog: ApprovedAnalystSourceCatalog = ApprovedAnalystSourceCatalog(),
        maxFetchedDocumentsPerRun: Int = 10,
        maxDiscoveredLinksPerSeed: Int = 4
    ) {
        self.httpClient = httpClient
        self.catalog = catalog
        self.maxFetchedDocumentsPerRun = max(1, maxFetchedDocumentsPerRun)
        self.maxDiscoveredLinksPerSeed = max(0, maxDiscoveredLinksPerSeed)
    }

    public func fetchEvidence(
        for charter: AnalystCharter,
        task: AnalystTask,
        baselineNews: [NewsEvent],
        plannedSources: [ApprovedAnalystSourceDefinition] = []
    ) async -> AnalystExternalEvidenceFetchResult {
        if charter.sourcePolicy.reputableWebResearchAllowed == false
            || charter.allowedSources.contains("no_external_evidence_required") {
            return AnalystExternalEvidenceFetchResult(documents: [], issues: [])
        }

        let sources = plannedSources.isEmpty
            ? catalog.sources(for: charter, baselineNews: baselineNews)
            : plannedSources
        guard !sources.isEmpty else {
            return AnalystExternalEvidenceFetchResult(
                documents: [],
                issues: [AnalystExternalEvidenceError.noApprovedSources(charterID: charter.charterId).asIssue()]
            )
        }

        var documents: [ExternalAnalystEvidenceDocument] = []
        var issues: [AnalystExternalEvidenceIssue] = []
        let evidenceMode = researchEvidenceMode(for: task)
        let documentLimit = externalEvidenceDocumentLimit(for: evidenceMode, configuredLimit: maxFetchedDocumentsPerRun)
        let discoveryLimit = externalEvidenceDiscoveryLimit(for: evidenceMode, configuredLimit: maxDiscoveredLinksPerSeed)
        var pendingSources = Array(sources.prefix(documentLimit + discoveryLimit))
        var seenURLs: Set<String> = []

        while !pendingSources.isEmpty && documents.count < documentLimit {
            let source = pendingSources.removeFirst()
            let normalizedURL = source.url.absoluteString.lowercased()
            guard seenURLs.insert(normalizedURL).inserted else {
                continue
            }
            do {
                let page = try await fetchPage(source)
                documents.append(normalizeDocument(from: page))
                if source.allowsDiscovery, documents.count < documentLimit {
                    let discovered = discoverRelevantLinkedSources(
                        from: page.html,
                        seed: source,
                        charter: charter,
                        task: task,
                        baselineNews: baselineNews,
                        excluding: seenURLs
                    )
                    pendingSources.append(contentsOf: Array(discovered.prefix(discoveryLimit)))
                }
            } catch let error as AnalystExternalEvidenceError {
                issues.append(error.asIssue())
            } catch {
                issues.append(
                    AnalystExternalEvidenceIssue(
                        category: .unexpected,
                        host: source.url.host ?? source.url.absoluteString,
                        detail: error.localizedDescription
                    )
                )
            }
        }
        return AnalystExternalEvidenceFetchResult(documents: documents, issues: issues)
    }

    private func fetchPage(_ source: ApprovedAnalystSourceDefinition) async throws -> FetchedExternalPage {
        var request = URLRequest(url: source.url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("AlgoTradingMacAnalystWorker/1.0 (+charter-governed external evidence fetch)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch {
            throw AnalystExternalEvidenceError.transport(
                host: source.url.host ?? source.url.absoluteString,
                description: error.localizedDescription
            )
        }

        guard let http = response as? HTTPURLResponse else {
            throw AnalystExternalEvidenceError.invalidResponse(host: source.url.host ?? source.url.absoluteString)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AnalystExternalEvidenceError.httpStatus(host: source.url.host ?? source.url.absoluteString, statusCode: http.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw AnalystExternalEvidenceError.invalidContent(host: source.url.host ?? source.url.absoluteString)
        }

        let cleanedBody = cleanHTMLText(html)
        let normalizedHTML = html.lowercased()
        let looksLikeHTML = normalizedHTML.contains("<html")
            || normalizedHTML.contains("<title")
            || normalizedHTML.contains("<meta")
            || normalizedHTML.contains("<body")
        let looksLikeText = isMeaningfulExternalEvidenceText(cleanedBody)
        guard looksLikeHTML || looksLikeText else {
            throw AnalystExternalEvidenceError.invalidContent(host: source.url.host ?? source.url.absoluteString)
        }

        let observedAt = parseHTTPDate(http.value(forHTTPHeaderField: "Last-Modified"))
            ?? parseHTTPDate(http.value(forHTTPHeaderField: "Date"))
            ?? Date()

        return FetchedExternalPage(
            source: source,
            html: html,
            observedAt: observedAt
        )
    }

    private func normalizeDocument(from page: FetchedExternalPage) -> ExternalAnalystEvidenceDocument {
        let html = page.html
        let source = page.source
        if let adaptedSEC = adaptSECSubmissionsEvidenceDocument(
            html: html,
            source: source,
            observedAt: page.observedAt
        ) {
            return adaptedSEC
        }
        let sourceClass = inferCrucialSiteSourceClass(for: source.url, titleHint: source.titleHint)
        let title = extractAdaptedExternalTitle(
            in: html,
            sourceClass: sourceClass,
            fallback: source.titleHint
        )
        let primaryText = extractAdaptedPrimaryText(in: html, sourceClass: sourceClass) ?? ""
        let summary = buildAdaptedExternalSummary(
            sourceClass: sourceClass,
            html: html,
            fallbackText: primaryText
        )
        let snippetSource = primaryText.isEmpty ? summary : primaryText
        let snippet = boundedEvidenceExcerpt(from: snippetSource, limit: 420)
        let observedAt = extractAdaptedObservedAt(in: html) ?? page.observedAt

        return ExternalAnalystEvidenceDocument(
            sourceID: source.sourceID,
            url: source.url.absoluteString,
            title: title,
            observedAt: observedAt,
            summary: summary,
            snippet: snippet,
            provenanceNote: source.provenanceNote,
            sourceTier: source.sourceTier
        )
    }

    private func discoverRelevantLinkedSources(
        from html: String,
        seed: ApprovedAnalystSourceDefinition,
        charter: AnalystCharter,
        task: AnalystTask,
        baselineNews: [NewsEvent],
        excluding seenURLs: Set<String>
    ) -> [ApprovedAnalystSourceDefinition] {
        guard maxDiscoveredLinksPerSeed > 0 else { return [] }
        guard let host = seed.url.host?.lowercased() else { return [] }

        let keywords = discoveryKeywords(task: task, baselineNews: baselineNews)
        let sourceClass = inferCrucialSiteSourceClass(for: seed.url, titleHint: seed.titleHint)
        let pathHints = discoveryPathHints(for: sourceClass)
        guard !keywords.isEmpty || !pathHints.isEmpty else { return [] }

        let anchorMatches = extractAnchorCandidates(in: html)
        var discovered: [ApprovedAnalystSourceDefinition] = []

        for match in anchorMatches {
            let rawHref = match.href
            guard let candidateURL = normalizeDiscoveredURL(rawHref, relativeTo: seed.url),
                  isAllowedPublicSourceURL(candidateURL, charter: charter),
                  candidateURL.host?.lowercased() == host else {
                continue
            }
            let loweredURL = candidateURL.absoluteString.lowercased()
            guard seenURLs.contains(loweredURL) == false else {
                continue
            }

            let keywordDescriptor = [
                candidateURL.path.lowercased(),
                rawHref.lowercased(),
                match.anchorText.lowercased()
            ].joined(separator: " ")
            let classHintDescriptor = [
                candidateURL.path.lowercased(),
                match.anchorText.lowercased()
            ].joined(separator: " ")
            let matchesKeyword = keywords.contains(where: { keywordDescriptor.contains($0) })
            let matchesClassHint = pathHints.contains(where: { classHintDescriptor.contains($0) })
            guard matchesKeyword || matchesClassHint else {
                continue
            }

            discovered.append(
                ApprovedAnalystSourceDefinition(
                    sourceID: "\(seed.sourceID)-discovered-\(stableIdentifier(prefix: "link", components: [loweredURL]))",
                    url: candidateURL,
                    titleHint: "\(seed.titleHint) related page",
                    provenanceNote: "\(seed.provenanceNote)+discovered_page",
                    allowsDiscovery: false,
                    sourceTier: seed.sourceTier
                )
            )
            if discovered.count >= maxDiscoveredLinksPerSeed {
                break
            }
        }

        return discovered
    }
}

public struct AnalystWorkerRunSummary: Sendable, Equatable {
    public let charterSeeded: Bool
    public let openAIKeyConfigured: Bool
    public let pmId: String?
    public let delegationId: String?
    public let analystId: String
    public let charterId: String
    public let taskId: String
    public let evidenceBundleId: String
    public let findingId: String
    public let memoId: String
    public let runtimeProvenance: AnalystRuntimeProvenance?
    public let newsCount: Int
    public let externalEvidenceCount: Int
    public let externalEvidenceIssueCount: Int
    public let externalEvidenceStatus: String
    public let externalEvidenceIssueSummary: String?
    public let synthesisStatus: String
    public let synthesisIssueSummary: String?
    public let findingTitle: String
    public let memoTitle: String
    public let draftedSignalId: String?
    public let draftedProposalId: String?
    public let usedOpenAI: Bool

    public init(
        charterSeeded: Bool,
        openAIKeyConfigured: Bool,
        pmId: String? = nil,
        delegationId: String? = nil,
        analystId: String,
        charterId: String,
        taskId: String,
        evidenceBundleId: String,
        findingId: String,
        memoId: String,
        runtimeProvenance: AnalystRuntimeProvenance? = nil,
        newsCount: Int,
        externalEvidenceCount: Int,
        externalEvidenceIssueCount: Int = 0,
        externalEvidenceStatus: String = "ok",
        externalEvidenceIssueSummary: String? = nil,
        synthesisStatus: String = "deterministic_local",
        synthesisIssueSummary: String? = nil,
        findingTitle: String,
        memoTitle: String,
        draftedSignalId: String? = nil,
        draftedProposalId: String? = nil,
        usedOpenAI: Bool
    ) {
        self.charterSeeded = charterSeeded
        self.openAIKeyConfigured = openAIKeyConfigured
        self.pmId = pmId
        self.delegationId = delegationId
        self.analystId = analystId
        self.charterId = charterId
        self.taskId = taskId
        self.evidenceBundleId = evidenceBundleId
        self.findingId = findingId
        self.memoId = memoId
        self.runtimeProvenance = runtimeProvenance
        self.newsCount = newsCount
        self.externalEvidenceCount = externalEvidenceCount
        self.externalEvidenceIssueCount = externalEvidenceIssueCount
        self.externalEvidenceStatus = externalEvidenceStatus
        self.externalEvidenceIssueSummary = externalEvidenceIssueSummary
        self.synthesisStatus = synthesisStatus
        self.synthesisIssueSummary = synthesisIssueSummary
        self.findingTitle = findingTitle
        self.memoTitle = memoTitle
        self.draftedSignalId = draftedSignalId
        self.draftedProposalId = draftedProposalId
        self.usedOpenAI = usedOpenAI
    }
}

public struct AnalystWorkerService: Sendable {
    private enum LocalMemoStyle: Sendable {
        case concise
        case balanced
        case deep
    }

    private enum LocalTaskIntent: Sendable {
        case synthesis
        case recommendation
        case actionAdjacentReview
        case recentNewsMaterialImpact
        case portfolioRiskTrigger
        case general
    }

    private struct RecentNewsTaskContext: Sendable, Equatable {
        let heldPositionsSummary: String?
        let watchlistSummary: String?
        let strategyObjective: String?
        let strategyThemes: String?
        let riskPosture: String?
        let materialDevelopments: String?
        let nonMaterialDevelopments: String?
        let reviewPosture: String?
        let coveragePosture: String?
        let clusteredEventView: String?
        let escalationPosture: String?
        let whyNowSummary: String?
        let bookPostureSummary: String?
        let materialityTrigger: String?
        let triggeringNewsSummary: String?
        let scopedMemorySymbols: String?
        let scopedMemoryThemes: String?
        let scopedMemoryOpenQuestions: String?
    }

    private struct PortfolioRiskTaskContext: Sendable, Equatable {
        let heldPositionsSummary: String?
        let watchlistSummary: String?
        let strategyObjective: String?
        let strategyThemes: String?
        let riskPosture: String?
        let reviewPosture: String?
        let riskFrameworkGuidance: String?
        let coveragePosture: String?
        let concentrationPosture: String?
        let clusteredRiskView: String?
        let longShortPosture: String?
        let escalationPosture: String?
        let whyNowSummary: String?
        let bookPostureSummary: String?
        let riskTrigger: String?
        let whatChangedSinceReview: String?
        let triggeringConditions: String?
        let priorReviewAnchor: String?
        let priorReviewSource: String?
        let scopedMemorySymbols: String?
        let scopedMemoryThemes: String?
        let scopedMemoryOpenQuestions: String?
    }

    private struct LocalRuntimeExecutionProfile: Sendable {
        let actualRuntimeIdentifier: String
        let actualReasoningMode: AnalystRuntimeReasoningMode?
        let memoStyle: LocalMemoStyle
    }

    private struct SynthesisAttemptOutcome: Sendable {
        let output: AnalystOpenAISynthesisOutput?
        let actualRuntimeIdentifier: String
        let actualReasoningMode: AnalystRuntimeReasoningMode?
        let memoStyle: LocalMemoStyle
        let usedOpenAI: Bool
        let synthesisStatus: String
        let synthesisIssueSummary: String?
    }

    private struct ResearchSourceSeed: Sendable {
        let label: String
        let urlString: String?
        let category: String
        let accessMode: AnalystResearchCandidateAccessMode
        let sourceTier: AnalystResearchSourceTier
        let whyItMatters: String
        let missingInformationHint: String

        init(
            label: String,
            urlString: String?,
            category: String,
            accessMode: AnalystResearchCandidateAccessMode,
            sourceTier: AnalystResearchSourceTier? = nil,
            whyItMatters: String,
            missingInformationHint: String
        ) {
            self.label = label
            self.urlString = urlString
            self.category = category
            self.accessMode = accessMode
            self.sourceTier = sourceTier ?? sourceTierForResearchSource(
                category: category,
                urlString: urlString,
                titleHint: label
            )
            self.whyItMatters = whyItMatters
            self.missingInformationHint = missingInformationHint
        }
    }

    private let client: any AnalystControlPlaneClient
    private let standingBenchSeed: StandingAnalystBenchSeed
    private let openAIKeyStatusProvider: any OpenAIKeyStatusProviding
    private let llmProviderSettingsStore: LLMProviderSettingsStore
    private let llmCredentialResolver: any LLMCredentialResolving
    private let researchPlanningProvider: any AnalystResearchPlanningProviding
    private let openAISynthesisProvider: any AnalystOpenAISynthesisProviding
    private let anthropicSynthesisProvider: any AnalystOpenAISynthesisProviding
    private let externalEvidenceProvider: any ExternalAnalystEvidenceProviding
    private let now: @Sendable () -> Date

    public init(
        client: any AnalystControlPlaneClient,
        standingBenchSeed: StandingAnalystBenchSeed = StandingAnalystBenchSeed(),
        openAIKeyStatusProvider: any OpenAIKeyStatusProviding = OpenAIKeychainStatusProvider(),
        llmProviderSettingsStore: LLMProviderSettingsStore = LLMProviderSettingsStore(),
        llmCredentialResolver: any LLMCredentialResolving = LLMKeychainCredentialResolver(),
        researchPlanningProvider: any AnalystResearchPlanningProviding = OpenAIResponsesAnalystResearchPlanningProvider(),
        openAISynthesisProvider: any AnalystOpenAISynthesisProviding = OpenAIResponsesAnalystSynthesisProvider(),
        anthropicSynthesisProvider: any AnalystOpenAISynthesisProviding = AnthropicMessagesAnalystSynthesisProvider(),
        externalEvidenceProvider: any ExternalAnalystEvidenceProviding = ApprovedAnalystExternalEvidenceFetcher(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.client = client
        self.standingBenchSeed = standingBenchSeed
        self.openAIKeyStatusProvider = openAIKeyStatusProvider
        self.llmProviderSettingsStore = llmProviderSettingsStore
        self.llmCredentialResolver = llmCredentialResolver
        self.researchPlanningProvider = researchPlanningProvider
        self.openAISynthesisProvider = openAISynthesisProvider
        self.anthropicSynthesisProvider = anthropicSynthesisProvider
        self.externalEvidenceProvider = externalEvidenceProvider
        self.now = now
    }

    public func runOnce(
        charterID: String? = nil,
        taskID: String? = nil,
        delegationID: String? = nil,
        pmID: String? = nil,
        intendedRuntimePolicy: AnalystRuntimePolicy? = nil,
        newsLimit: Int = 10,
        draftSignal: Bool = false,
        draftProposal: Bool = false,
        reportProgress: @escaping @Sendable (AnalystWorkerProgressUpdate) -> Void = { _ in }
    ) async throws -> AnalystWorkerRunSummary {
        if draftProposal && draftSignal == false {
            throw AnalystWorkerSelectionError.invalidDraftSelection(
                reason: "proposal drafting requires --draft-signal"
            )
        }
        let timestamp = now()
        let openAIConfigured = if intendedRuntimePolicy?.providerKind == .anthropic {
            false
        } else {
            openAIKeyStatusProvider.credentialResolution().isReady
        }
        reportProgress(
            AnalystWorkerProgressUpdate(
                reportedAt: timestamp,
                stage: "launch_started",
                summary: "Analyst worker launched and is resolving charter, task, and app-owned context."
            )
        )

        let existingCharters = try await client.listCharters()
        let (charter, charterSeeded) = try await resolveCharter(
            from: existingCharters,
            requestedCharterID: charterID,
            now: timestamp
        )
        let task = try await resolveTask(
            requestedTaskID: taskID,
            charter: charter,
            now: timestamp
        )
        let taskIntent = inferTaskIntent(from: task)
        reportProgress(
            AnalystWorkerProgressUpdate(
                reportedAt: now(),
                stage: "context_resolved",
                summary: "Current charter, task, and app-owned context were resolved."
            )
        )

        let fetchedNews = try await client.listNews(limit: max(1, newsLimit), since: nil)
        let news = scopedBaselineNews(for: task, fallback: fetchedNews, limit: max(1, newsLimit))
        let llmRuntimeOwnsPublicResearch = llmRuntimeCanOwnPublicResearch(
            charter: charter,
            intendedRuntimePolicy: intendedRuntimePolicy
        )
        let researchPlan: AnalystResearchPlan?
        let externalEvidenceResult: AnalystExternalEvidenceFetchResult
        if llmRuntimeOwnsPublicResearch {
            researchPlan = nil
            externalEvidenceResult = AnalystExternalEvidenceFetchResult(documents: [], issues: [])
        } else {
            researchPlan = await resolveResearchPlan(
                charter: charter,
                task: task,
                news: news,
                taskIntent: taskIntent,
                intendedRuntimePolicy: intendedRuntimePolicy
            )
            externalEvidenceResult = await externalEvidenceProvider.fetchEvidence(
                for: charter,
                task: task,
                baselineNews: news,
                plannedSources: researchPlan?.selectedSourceDefinitions ?? []
            )
        }
        let externalEvidence = externalEvidenceResult.documents
        let externalIssues = externalEvidenceResult.issues
        reportProgress(
            AnalystWorkerProgressUpdate(
                reportedAt: now(),
                stage: "evidence_ready",
                summary: llmRuntimeOwnsPublicResearch
                    ? "App-owned context is ready; direct analyst LLM public-web research will run inside synthesis."
                    : "News and policy-governed supplemental evidence inputs were assembled for fallback/local synthesis.",
                issueSummary: externalIssues.isEmpty ? nil : externalIssues.map(\.boundedSummary).joined(separator: " | ")
            )
        )
        let synthesisOutcome = await performSynthesis(
            charter: charter,
            task: task,
            news: news,
            researchPlan: researchPlan,
            externalEvidence: externalEvidence,
            externalIssues: externalIssues,
            taskIntent: taskIntent,
            intendedRuntimePolicy: intendedRuntimePolicy
        )
        if providerSynthesisIsRequired(for: task, intendedRuntimePolicy: intendedRuntimePolicy),
           synthesisOutcome.output == nil {
            let issue = synthesisOutcome.synthesisIssueSummary?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = issue?.isEmpty == false
                ? issue!
                : "configured analyst LLM runtime did not return a usable synthesis"
            let summary = "Analyst LLM runtime failed before producing a research memo: \(reason). No deterministic local fallback was accepted as completed analyst research."
            var failedTask = task
            failedTask.status = .failed
            failedTask.updatedAt = now()
            failedTask.lastCheckpointSummary = summary
            failedTask.checkpoint = AnalystTaskCheckpoint(
                checkpointID: "checkpoint-\(task.taskId)",
                taskId: task.taskId,
                analystId: task.analystId,
                charterId: task.charterId,
                summary: summary,
                nextPlannedAction: "Resolve the analyst LLM runtime blocker and rerun the task; do not treat deterministic fallback as the analyst answer.",
                openQuestions: requiredResearchQuestions(for: task, researchPlan: researchPlan),
                updatedAt: failedTask.updatedAt
            )
            _ = try? await client.upsertTask(failedTask)
            reportProgress(
                AnalystWorkerProgressUpdate(
                    reportedAt: now(),
                    stage: "synthesis_failed",
                    summary: summary,
                    issueSummary: reason
                )
            )
            throw AnalystWorkerSelectionError.providerSynthesisFailed(reason: summary)
        }
        reportProgress(
            AnalystWorkerProgressUpdate(
                reportedAt: now(),
                stage: "synthesis_complete",
                summary: "Analyst synthesis completed and durable artifacts are being persisted.",
                issueSummary: synthesisOutcome.synthesisIssueSummary
            )
        )
        let runtimeProvenance = AnalystRuntimeProvenance(
            intendedPolicy: intendedRuntimePolicy,
            actualRuntimeIdentifier: synthesisOutcome.actualRuntimeIdentifier,
            actualReasoningMode: synthesisOutcome.actualReasoningMode,
            launchedAt: timestamp
        )
        let bundle = try await client.upsertEvidenceBundle(
            makeEvidenceBundle(
                charter: charter,
                task: task,
                news: news,
                researchPlan: researchPlan,
                externalEvidence: externalEvidence,
                externalIssues: externalIssues,
                llmRuntimeOwnsPublicResearch: llmRuntimeOwnsPublicResearch,
                taskIntent: taskIntent,
                now: timestamp
            )
        )
        let finding = try await client.upsertFinding(
            makeFinding(
                charter: charter,
                task: task,
                news: news,
                externalEvidence: externalEvidence,
                externalIssues: externalIssues,
                taskIntent: taskIntent,
                bundleId: bundle.bundleId,
                synthesized: synthesisOutcome.output,
                now: timestamp
            )
        )
        let updatedTask = try await client.upsertTask(
            makeUpdatedTask(
                existingTask: task,
                charter: charter,
                news: news,
                researchPlan: researchPlan,
                externalEvidence: externalEvidence,
                externalIssues: externalIssues,
                llmRuntimeOwnsPublicResearch: llmRuntimeOwnsPublicResearch,
                taskIntent: taskIntent,
                bundleId: bundle.bundleId,
                findingId: finding.findingId,
                now: timestamp
            )
        )
        let memo = try await client.upsertMemo(
            makeMemo(
                charter: charter,
                task: updatedTask,
                news: news,
                researchPlan: researchPlan,
                externalEvidence: externalEvidence,
                externalIssues: externalIssues,
                bundle: bundle,
                finding: finding,
                taskIntent: taskIntent,
                memoStyle: synthesisOutcome.memoStyle,
                runtimeProvenance: runtimeProvenance,
                delegationID: delegationID,
                pmID: pmID,
                synthesized: synthesisOutcome.output,
                now: timestamp
            )
        )
        let sourceSuggestions = makeSourceAccessSuggestions(
            charter: charter,
            task: updatedTask,
            memo: memo,
            finding: finding,
            bundle: bundle,
            delegationID: delegationID,
            researchPlan: researchPlan,
            externalIssues: externalIssues
        )
        for suggestion in sourceSuggestions {
            _ = try await client.upsertSourceAccessSuggestion(suggestion)
        }
        reportProgress(
            AnalystWorkerProgressUpdate(
                reportedAt: now(),
                stage: "artifacts_persisted",
                summary: sourceSuggestions.isEmpty
                    ? "Evidence, finding, checkpoint, and memo artifacts were persisted through the app-owned control plane."
                    : "Evidence, finding, checkpoint, memo, and source-access suggestion artifacts were persisted through the app-owned control plane."
            )
        )
        let draftedSignal: Signal?
        if draftSignal {
            do {
                draftedSignal = try await client.draftSignalFromFinding(id: finding.findingId)
            } catch let error as AnalystIPCClientError where Self.isSignalDraftIneligible(error) && draftProposal == false {
                draftedSignal = nil
                reportProgress(
                    AnalystWorkerProgressUpdate(
                        reportedAt: now(),
                        stage: "signal_draft_skipped",
                        summary: "Finding was persisted, but signal drafting was skipped because the finding did not satisfy signal eligibility."
                    )
                )
            }
        } else {
            draftedSignal = nil
        }
        let draftedProposal: StrategyProposal?
        if draftProposal {
            guard let draftedSignal else {
                throw AnalystWorkerSelectionError.invalidDraftSelection(
                    reason: "proposal drafting requires a drafted signal"
                )
            }
            draftedProposal = try await client.draftProposalFromSignal(
                id: draftedSignal.signalId,
                strategyID: "heartbeat"
            )
        } else {
            draftedProposal = nil
        }

        return AnalystWorkerRunSummary(
            charterSeeded: charterSeeded,
            openAIKeyConfigured: openAIConfigured,
            pmId: pmID,
            delegationId: delegationID,
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: updatedTask.taskId,
            evidenceBundleId: bundle.bundleId,
            findingId: finding.findingId,
            memoId: memo.memoId,
            runtimeProvenance: runtimeProvenance,
            newsCount: news.count,
            externalEvidenceCount: externalEvidence.count,
            externalEvidenceIssueCount: externalIssues.count,
            externalEvidenceStatus: externalEvidenceStatus(documents: externalEvidence, issues: externalIssues),
            externalEvidenceIssueSummary: externalEvidenceIssueSummary(externalIssues),
            synthesisStatus: synthesisOutcome.synthesisStatus,
            synthesisIssueSummary: synthesisOutcome.synthesisIssueSummary,
            findingTitle: finding.title,
            memoTitle: memo.title,
            draftedSignalId: draftedSignal?.signalId,
            draftedProposalId: draftedProposal?.proposalId,
            usedOpenAI: synthesisOutcome.usedOpenAI
        )
    }

    private func resolveResearchPlan(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        taskIntent: LocalTaskIntent,
        intendedRuntimePolicy: AnalystRuntimePolicy?
    ) async -> AnalystResearchPlan? {
        guard charter.sourcePolicy.reputableWebResearchAllowed,
              charter.allowedSources.contains("no_external_evidence_required") == false else {
            return nil
        }

        let candidates = buildResearchSourceCandidates(
            charter: charter,
            task: task,
            news: news,
            taskIntent: taskIntent
        )

        let fallback = fallbackResearchPlan(
            charter: charter,
            task: task,
            news: news,
            candidates: candidates
        )

        let trimmedRuntimeIdentifier = intendedRuntimePolicy?.runtimeIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedRuntimeIdentifier, trimmedRuntimeIdentifier.isEmpty == false else {
            return fallback
        }
        guard intendedRuntimePolicy?.providerKind != .anthropic else {
            return fallback
        }

        let credentialResolution = openAIKeyStatusProvider.credentialResolution()
        guard let apiKey = credentialResolution.apiKey else {
            return candidates.isEmpty ? nil : fallback
        }

        do {
            let planned = try await researchPlanningProvider.planResearch(
                request: makeResearchPlanningRequest(
                    charter: charter,
                    task: task,
                    news: news,
                    taskIntent: taskIntent,
                    intendedRuntimePolicy: intendedRuntimePolicy,
                    candidates: candidates
                ),
                apiKey: apiKey
            )
            return normalizeResearchPlan(
                planned,
                charter: charter,
                task: task,
                news: news,
                candidates: candidates,
                fallback: fallback
            )
        } catch {
            return fallback
        }
    }

    private static func isSignalDraftIneligible(_ error: AnalystIPCClientError) -> Bool {
        guard case .server(let code, _) = error else {
            return false
        }
        return code == "analyst_finding_signal_ineligible"
    }

    private func makeResearchPlanningRequest(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        taskIntent: LocalTaskIntent,
        intendedRuntimePolicy: AnalystRuntimePolicy?,
        candidates: [AnalystResearchSourceCandidate]
    ) -> AnalystResearchPlanningRequest {
        AnalystResearchPlanningRequest(
            runtimeIdentifier: intendedRuntimePolicy?.runtimeIdentifier ?? "gpt-4.1",
            reasoningMode: intendedRuntimePolicy?.reasoningMode,
            charterTitle: charter.title,
            charterSummary: charter.summary,
            charterDocumentBodyExcerpt: trimmedDocumentBody(charter.primaryDocumentBody, limit: 2_400),
            taskTitle: task.title,
            taskDescription: task.description,
            taskIntent: synthesisIntentLabel(taskIntent),
            pmTaskingBriefBody: makePMTaskingBriefBody(task.pmTaskingBrief),
            requiredResearchQuestions: requiredResearchQuestions(for: task, researchPlan: nil),
            newsItems: news.prefix(8).map { item in
                AnalystResearchPlanningRequest.NewsItem(
                    source: item.source,
                    title: item.title,
                    summary: item.summary,
                    symbols: item.rawSymbolHints,
                    tags: item.tags,
                    publishedAt: item.publishedAt
                )
            },
            sourcePolicySummary: makeSourcePolicySummary(charter.sourcePolicy),
            scopedOpenQuestions: Array(
                Set(
                    (task.contextPack?.scopedMemory?.openQuestions ?? [])
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { $0.isEmpty == false }
                )
            )
            .sorted()
            .prefix(4)
            .map { $0 },
            researchHints: Array(
                Set(
                    candidates
                        .filter { $0.kind != .appNewsLinked }
                        .map(\.missingInformationHint)
                )
            )
            .sorted()
            .prefix(6)
            .map { $0 },
            suggestedPublicSites: candidates.compactMap { candidate in
                guard candidate.accessMode == .publicOpen else { return nil }
                let source = candidate.approvedSource?.url.absoluteString ?? candidate.requestedSource
                return AnalystResearchPlanningRequest.SuggestedSite(
                    label: candidate.label,
                    source: source,
                    category: candidate.category,
                    whyItMatters: candidate.whyItMatters
                )
            }
        )
    }

    private func makeSourcePolicySummary(_ policy: AnalystSourcePolicy) -> String {
        var lines: [String] = []
        lines.append(
            policy.reputableWebResearchAllowed
                ? "Public/domain web research: enabled by default unless an explicit restriction applies."
                : "Public/domain web research: disabled by explicit source restriction for this run."
        )
        if policy.preferredSources.isEmpty == false {
            lines.append("Preferred sources: \(policy.preferredSources.joined(separator: ", "))")
        }
        if policy.restrictedSources.isEmpty == false {
            lines.append("Restricted sources: \(policy.restrictedSources.joined(separator: ", "))")
        }
        if policy.sourceCategories.isEmpty == false {
            lines.append("Preferred source categories: \(policy.sourceCategories.joined(separator: ", "))")
        }
        if policy.guidanceNotes.isEmpty == false {
            lines.append(contentsOf: policy.guidanceNotes)
        }
        return lines.joined(separator: "\n")
    }

    private func buildResearchSourceCandidates(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        taskIntent: LocalTaskIntent
    ) -> [AnalystResearchSourceCandidate] {
        var candidates: [AnalystResearchSourceCandidate] = []

        for newsItem in news.prefix(4) {
            guard let source = appNewsLinkedSourceDefinition(from: newsItem, charter: charter) else {
                continue
            }
            candidates.append(
                AnalystResearchSourceCandidate(
                    candidateID: stableHashedIdentifier(
                        prefix: "research-candidate",
                        components: [charter.charterId, source.url.absoluteString.lowercased()]
                    ),
                    kind: .appNewsLinked,
                    label: newsItem.title,
                    category: "app_news_linked",
                    requestedSource: source.url.absoluteString,
                    requestedDomain: source.url.host?.lowercased(),
                    accessMode: .publicOpen,
                    sourceTier: source.sourceTier,
                    whyItMatters: "This is the primary app-news-linked source already in scope and can confirm or qualify the baseline event directly.",
                    missingInformationHint: "Whether the baseline app-news event is confirmed, qualified, or challenged by more primary reporting on the same topic.",
                    approvedSource: source
                )
            )
        }

        let genericPreferredSources: Set<String> = [
            "primary sources",
            "official company / regulator / exchange / issuer materials",
            "reputable financial press",
            "reputable industry publications",
            "reputable research/reference sources"
        ]
        for preferredSource in charter.sourcePolicy.preferredSources {
            let normalized = preferredSource.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = normalized.lowercased()
            guard normalized.isEmpty == false,
                  genericPreferredSources.contains(lowered) == false else {
                continue
            }
            if isRestrictedSourceDescriptor(normalized, charter: charter) {
                candidates.append(
                    AnalystResearchSourceCandidate(
                        candidateID: stableHashedIdentifier(
                            prefix: "research-candidate",
                            components: [charter.charterId, normalized.lowercased(), "restricted"]
                        ),
                        kind: .preferredGap,
                        label: normalized,
                        category: "charter_preferred_source",
                        requestedSource: normalized,
                        requestedDomain: extractSuggestedDomain(from: normalized),
                        accessMode: .restrictedByPolicy,
                        sourceTier: .missingOrRestricted,
                        whyItMatters: "The charter already identifies this source as useful, but current policy marks it restricted.",
                        missingInformationHint: "Whether a preferred but currently restricted source would materially sharpen the analyst read.",
                        approvedSource: nil
                    )
                )
                continue
            }
            if let explicitSource = explicitPreferredSourceDefinition(from: normalized, charter: charter) {
                candidates.append(
                    AnalystResearchSourceCandidate(
                        candidateID: stableHashedIdentifier(
                            prefix: "research-candidate",
                            components: [charter.charterId, explicitSource.url.absoluteString.lowercased()]
                        ),
                        kind: .preferredPublic,
                        label: explicitSource.titleHint,
                        category: "charter_preferred_source",
                        requestedSource: explicitSource.url.absoluteString,
                        requestedDomain: explicitSource.url.host?.lowercased(),
                        accessMode: .publicOpen,
                        sourceTier: explicitSource.sourceTier,
                        whyItMatters: "This charter-preferred source is a good candidate when the analyst needs stronger primary or specialist confirmation beyond the app-news baseline.",
                        missingInformationHint: "Whether a charter-preferred external source materially changes the read beyond the app-news baseline.",
                        approvedSource: explicitSource
                    )
                )
            } else {
                candidates.append(
                    AnalystResearchSourceCandidate(
                        candidateID: stableHashedIdentifier(
                            prefix: "research-candidate",
                            components: [charter.charterId, normalized.lowercased(), "unsupported"]
                        ),
                        kind: .preferredGap,
                        label: normalized,
                        category: "charter_preferred_source",
                        requestedSource: normalized,
                        requestedDomain: extractSuggestedDomain(from: normalized),
                        accessMode: .unsupportedByTooling,
                        sourceTier: .missingOrRestricted,
                        whyItMatters: "The charter prefers this source, but the bounded fetcher cannot resolve it automatically from the current run context.",
                        missingInformationHint: "Whether a charter-preferred but unresolved source would materially improve the analysis.",
                        approvedSource: nil
                    )
                )
            }
        }

        for source in officialSECSourcesFromTask(task, charter: charter)
            + officialSECDiscoverySourcesFromTask(task, charter: charter) {
            candidates.append(
                AnalystResearchSourceCandidate(
                    candidateID: stableHashedIdentifier(
                        prefix: "research-candidate",
                        components: [charter.charterId, source.url.absoluteString.lowercased()]
                    ),
                    kind: .sectorSpecificPublic,
                    label: source.titleHint,
                    category: "official_filings",
                    requestedSource: source.url.absoluteString,
                    requestedDomain: source.url.host?.lowercased(),
                    accessMode: .publicOpen,
                    sourceTier: source.sourceTier,
                    whyItMatters: "The task supplied or implied a SEC filer/CIK/filings research need, so this official SEC source should be checked before treating the work as blocked.",
                    missingInformationHint: "Whether official SEC submissions, archive directory, or information-table material resolves the filing or holdings question.",
                    approvedSource: source
                )
            )
        }

        for seed in sectorResearchSourceSeeds(for: charter, taskIntent: taskIntent) {
            let normalizedURL = seed.urlString.flatMap { normalizedPublicSourceURL(from: $0) }
            let requestedSource = normalizedURL?.absoluteString ?? seed.label
            let requestedDomain = normalizedURL?.host?.lowercased() ?? extractSuggestedDomain(from: requestedSource)
            let accessMode: AnalystResearchCandidateAccessMode
            let approvedSource: ApprovedAnalystSourceDefinition?

            if seed.accessMode == .publicOpen,
               let normalizedURL,
               isAllowedPublicSourceURL(normalizedURL, charter: charter) {
                let sourceClass = inferCrucialSiteSourceClass(for: normalizedURL, titleHint: seed.label)
                approvedSource = ApprovedAnalystSourceDefinition(
                    sourceID: "planned-source-\(stableIdentifier(prefix: "source", components: [normalizedURL.absoluteString.lowercased()]))",
                    url: normalizedURL,
                    titleHint: seed.label,
                    provenanceNote: "sector_or_overlay_research_plan:\(normalizedURL.host?.lowercased() ?? normalizedURL.absoluteString.lowercased())",
                    allowsDiscovery: supportsBoundedDiscovery(for: normalizedURL, sourceClass: sourceClass),
                    sourceTier: seed.sourceTier
                )
                accessMode = .publicOpen
            } else if seed.accessMode == .publicOpen,
                      let normalizedURL,
                      let host = normalizedURL.host?.lowercased(),
                      isRestrictedHost(host, charter: charter) {
                approvedSource = nil
                accessMode = .restrictedByPolicy
            } else {
                approvedSource = nil
                accessMode = seed.accessMode
            }

            candidates.append(
                AnalystResearchSourceCandidate(
                    candidateID: stableHashedIdentifier(
                        prefix: "research-candidate",
                        components: [charter.charterId, requestedSource.lowercased(), seed.category]
                    ),
                    kind: accessMode == .publicOpen ? .sectorSpecificPublic : .sectorSpecificGap,
                    label: seed.label,
                    category: seed.category,
                    requestedSource: requestedSource,
                    requestedDomain: requestedDomain,
                    accessMode: accessMode,
                    sourceTier: accessMode == .publicOpen ? seed.sourceTier : .missingOrRestricted,
                    whyItMatters: seed.whyItMatters,
                    missingInformationHint: seed.missingInformationHint,
                    approvedSource: approvedSource
                )
            )
        }

        var deduplicated: [AnalystResearchSourceCandidate] = []
        var seen = Set<String>()
        for candidate in candidates {
            let fingerprint = [
                candidate.requestedDomain?.lowercased(),
                candidate.requestedSource.lowercased(),
                candidate.label.lowercased()
            ]
            .compactMap { $0 }
            .joined(separator: "|")
            guard seen.insert(fingerprint).inserted else {
                continue
            }
            deduplicated.append(candidate)
        }
        if researchEvidenceMode(for: task) == .primaryOnly {
            return deduplicated.filter { candidate in
                candidate.sourceTier == .officialPrimary || candidate.sourceTier == .appOwnedTruth
            }
        }
        return deduplicated
    }

    private func officialSECSourcesFromTask(
        _ task: AnalystTask,
        charter: AnalystCharter
    ) -> [ApprovedAnalystSourceDefinition] {
        let ciks = normalizedCIKs(in: taskResearchText(task))
        guard ciks.isEmpty == false else {
            return []
        }

        var sources: [ApprovedAnalystSourceDefinition] = []
        for cik in ciks.prefix(2) {
            let unpadded = String(cik.drop { $0 == "0" })
            let archiveCIK = unpadded.isEmpty ? "0" : unpadded
            let sourceSpecs: [(String, String, Bool)] = [
                (
                    "SEC submissions metadata for CIK \(cik)",
                    "https://data.sec.gov/submissions/CIK\(cik).json",
                    false
                ),
                (
                    "SEC EDGAR archive directory for CIK \(cik)",
                    "https://www.sec.gov/Archives/edgar/data/\(archiveCIK)/",
                    true
                )
            ]
            for (title, rawURL, allowsDiscovery) in sourceSpecs {
                guard let url = URL(string: rawURL),
                      isAllowedPublicSourceURL(url, charter: charter) else {
                    continue
                }
                sources.append(
                    ApprovedAnalystSourceDefinition(
                        sourceID: "sec-cik-\(stableIdentifier(prefix: "source", components: [url.absoluteString.lowercased()]))",
                        url: url,
                        titleHint: title,
                        provenanceNote: "official_sec_cik_source:\(cik)",
                        allowsDiscovery: allowsDiscovery,
                        sourceTier: .officialPrimary
                    )
                )
            }
        }
        return sources
    }

    private func officialSECDiscoverySourcesFromTask(
        _ task: AnalystTask,
        charter: AnalystCharter
    ) -> [ApprovedAnalystSourceDefinition] {
        let text = taskResearchText(task).lowercased()
        let filingSignals = [
            "13f", "sec", "edgar", "filing", "filer", "cik", "form 10-k", "form 10-q", "form 8-k"
        ]
        guard filingSignals.contains(where: { text.contains($0) }) else {
            return []
        }
        guard let url = URL(string: "https://www.sec.gov/edgar/search/"),
              isAllowedPublicSourceURL(url, charter: charter) else {
            return []
        }
        return [
            ApprovedAnalystSourceDefinition(
                sourceID: "sec-edgar-search",
                url: url,
                titleHint: "SEC EDGAR search",
                provenanceNote: "official_sec_discovery_source:edgar_search",
                allowsDiscovery: true,
                sourceTier: .officialPrimary
            )
        ]
    }

    private func fallbackResearchPlan(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        candidates: [AnalystResearchSourceCandidate]
    ) -> AnalystResearchPlan {
        let taskQuestions = isPMRequestedAdHocTask(task)
            ? requiredResearchQuestions(for: task, researchPlan: nil)
            : []
        let memoryQuestions = task.contextPack?.scopedMemory?.openQuestions ?? []
        let inferredMissing = Array(
            Set(
                (taskQuestions + memoryQuestions + candidates.map(\.missingInformationHint))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            )
        )
        .sorted()
        .prefix(AnalystTaskQuestionChecklist.maxQuestionCount)
        .map { $0 }

        let publicCandidates = candidates.filter {
            $0.accessMode == .publicOpen && $0.approvedSource != nil
        }
        let nonAppNewsPublic = publicCandidates.filter { $0.kind != .appNewsLinked }
        let appNewsLinked = publicCandidates.filter { $0.kind == .appNewsLinked }
        let mode = researchEvidenceMode(for: task)
        let selectedNonAppNewsPublic: [AnalystResearchSourceCandidate]
        if mode == .secondaryAssisted {
            var balanced: [AnalystResearchSourceCandidate] = []
            if let official = nonAppNewsPublic.first(where: { $0.sourceTier == .officialPrimary || $0.sourceTier == .appOwnedTruth }) {
                balanced.append(official)
            }
            if let secondary = nonAppNewsPublic.first(where: { candidate in
                candidate.sourceTier == .reputableSecondary
                    && balanced.contains(where: { $0.candidateID == candidate.candidateID }) == false
            }) {
                balanced.append(secondary)
            }
            let targetLimit = fallbackNonAppPublicTargetLimit(for: mode)
            for candidate in nonAppNewsPublic where balanced.count < targetLimit {
                guard balanced.contains(where: { $0.candidateID == candidate.candidateID }) == false else {
                    continue
                }
                balanced.append(candidate)
            }
            selectedNonAppNewsPublic = balanced
        } else {
            selectedNonAppNewsPublic = Array(nonAppNewsPublic.prefix(fallbackNonAppPublicTargetLimit(for: mode)))
        }
        let selectedPublic = selectedNonAppNewsPublic + Array(appNewsLinked.prefix(mode == .secondaryAssisted ? 2 : 1))
        let selectedGaps = Array(
            candidates
                .filter { $0.accessMode != .publicOpen }
                .prefix(2)
        )

        let publicTargets: [AnalystResearchPlan.PublicTarget] = selectedPublic.compactMap { candidate in
            guard let approvedSource = candidate.approvedSource else { return nil }
            return AnalystResearchPlan.PublicTarget(
                candidateID: candidate.candidateID,
                label: candidate.label,
                category: candidate.category,
                whyItMatters: candidate.whyItMatters,
                approvedSource: approvedSource
            )
        }

        let sourceGaps = selectedGaps.map { candidate in
            AnalystResearchPlan.SourceGap(
                candidateID: candidate.candidateID,
                requestedSource: candidate.requestedSource,
                requestedDomain: candidate.requestedDomain,
                whyItMatters: candidate.whyItMatters,
                missingInformationNeed: candidate.missingInformationHint,
                limitation: candidate.accessMode == .restrictedByPolicy ? .restrictedByPolicy : .unsupportedByTooling,
                recommendedNextStep: candidate.accessMode == .restrictedByPolicy ? .allowByCharterUpdate : .improveToolingSupport
            )
        }

        let questions = AnalystTaskQuestionChecklist.normalizedQuestions(
            taskQuestions + inferredMissing.map { need in
                "Which source is most likely to answer: \(need)"
            }
        )

        let summary: String
        if inferredMissing.isEmpty {
            summary = "After reviewing the app-news baseline, the worker prepared a task-specific public-research plan to help the analyst runtime test whether broader sector evidence or primary sources materially change the read."
        } else {
            summary = "After reviewing \(news.count) app-news baseline item(s), the worker identified missing information around \(inferredMissing.prefix(3).joined(separator: "; ")) and prepared a task-specific public-research plan for the required task questions."
        }

        return AnalystResearchPlan(
            planSummary: summary,
            missingInformation: inferredMissing,
            researchQuestions: questions,
            publicTargets: publicTargets,
            sourceGaps: sourceGaps
        )
    }

    private func normalizeResearchPlan(
        _ planned: AnalystResearchPlanningOutput,
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        candidates: [AnalystResearchSourceCandidate],
        fallback: AnalystResearchPlan
    ) -> AnalystResearchPlan {
        let taskQuestions = isPMRequestedAdHocTask(task)
            ? requiredResearchQuestions(for: task, researchPlan: nil)
            : []
        let missingInformation = Array(
            Set(
                (taskQuestions + planned.missingInformation)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            )
        )
        .sorted()
        .prefix(AnalystTaskQuestionChecklist.maxQuestionCount)
        .map { $0 }
        let researchQuestions = AnalystTaskQuestionChecklist.normalizedQuestions(
            taskQuestions + planned.researchQuestions + fallback.researchQuestions
        )

        var publicTargets: [AnalystResearchPlan.PublicTarget] = []
        for target in planned.publicTargets {
            let rawSource = target.urlOrDomain?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceText = target.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let requestedSource = rawSource.flatMap { $0.isEmpty ? nil : $0 } ?? sourceText
            guard requestedSource.isEmpty == false,
                  let url = normalizedPublicSourceURL(from: requestedSource) else {
                continue
            }
            guard isAllowedPublicSourceURL(url, charter: charter) else {
                continue
            }
            let titleHint = sourceText.isEmpty == false ? sourceText : (url.host?.replacingOccurrences(of: "www.", with: "") ?? requestedSource)
            let sourceClass = inferCrucialSiteSourceClass(for: url, titleHint: titleHint)
            let approvedSource = ApprovedAnalystSourceDefinition(
                sourceID: "planned-source-\(stableIdentifier(prefix: "source", components: [url.absoluteString.lowercased()]))",
                url: url,
                titleHint: titleHint,
                provenanceNote: "missing_information_research_plan:\(url.host?.lowercased() ?? url.absoluteString.lowercased())",
                allowsDiscovery: supportsBoundedDiscovery(for: url, sourceClass: sourceClass),
                sourceTier: sourceTierForResearchSource(url: url, titleHint: titleHint, category: target.category)
            )
            publicTargets.append(
                AnalystResearchPlan.PublicTarget(
                    candidateID: stableHashedIdentifier(
                        prefix: "research-candidate",
                        components: [charter.charterId, requestedSource.lowercased(), target.category.lowercased()]
                    ),
                    label: titleHint,
                    category: target.category,
                    whyItMatters: target.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "This source was selected to answer a material missing-information question beyond the initial app-news baseline."
                        : target.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines),
                    approvedSource: approvedSource
                )
            )
        }

        var seenPublicURLs = Set<String>()
        publicTargets = publicTargets.filter { target in
            seenPublicURLs.insert(target.approvedSource.url.absoluteString.lowercased()).inserted
        }

        if publicTargets.isEmpty {
            publicTargets = fallback.publicTargets
        }

        let hasNonAppNewsTarget = publicTargets.contains { target in
            let provenance = target.approvedSource.provenanceNote.lowercased()
            return provenance.contains("supplemental_public_web_from_app_news") == false
        }
        if hasNonAppNewsTarget == false,
           let differentiatedFallback = fallback.publicTargets.first(where: { target in
               target.approvedSource.provenanceNote.lowercased().contains("supplemental_public_web_from_app_news") == false
           }),
           publicTargets.contains(where: { $0.approvedSource.url == differentiatedFallback.approvedSource.url }) == false {
            publicTargets.insert(differentiatedFallback, at: 0)
        }

        if charter.analystId == recentNewsStandingAnalystID,
           let requiredAxiosTarget = fallback.publicTargets.first(where: { target in
               target.approvedSource.url.host?.lowercased().contains("axios.com") == true
           }),
           publicTargets.contains(where: { $0.approvedSource.url.host?.lowercased().contains("axios.com") == true }) == false {
            publicTargets.insert(requiredAxiosTarget, at: 0)
        }

        let mode = researchEvidenceMode(for: task)
        if mode == .secondaryAssisted {
            publicTargets = ensureSecondaryAssistedSourceBalance(
                publicTargets,
                fallbackTargets: fallback.publicTargets
            )
        }

        var sourceGaps: [AnalystResearchPlan.SourceGap] = []
        for gap in planned.sourceGapRecommendations {
            let requestedSource = gap.source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard requestedSource.isEmpty == false else { continue }
            let requestedDomain = gap.domain?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? gap.domain?.trimmingCharacters(in: .whitespacesAndNewlines)
                : extractSuggestedDomain(from: requestedSource)
            let loweredHint = gap.limitationHint?.lowercased() ?? ""
            let limitation: AnalystSourceAccessSuggestionLimitation = if loweredHint.contains("restricted")
                || isRestrictedSourceDescriptor(requestedSource, charter: charter) {
                .restrictedByPolicy
            } else {
                .unsupportedByTooling
            }
            let recommendedNextStep: AnalystSourceAccessSuggestionNextStep = limitation == .restrictedByPolicy
                ? .allowByCharterUpdate
                : .improveToolingSupport
            sourceGaps.append(
                AnalystResearchPlan.SourceGap(
                    candidateID: stableHashedIdentifier(
                        prefix: "research-candidate",
                        components: [charter.charterId, requestedSource.lowercased(), "gap"]
                    ),
                    requestedSource: requestedSource,
                    requestedDomain: requestedDomain,
                    whyItMatters: gap.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "This source was identified as useful for a missing-information question but could not be used directly in the current bounded run."
                        : gap.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines),
                    missingInformationNeed: gap.missingInformationNeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "A material sector-specific information gap remained after the app-news baseline review."
                        : gap.missingInformationNeed.trimmingCharacters(in: .whitespacesAndNewlines),
                    limitation: limitation,
                    recommendedNextStep: recommendedNextStep
                )
            )
        }

        if sourceGaps.isEmpty, publicTargets == fallback.publicTargets {
            sourceGaps = fallback.sourceGaps
        }

        return AnalystResearchPlan(
            planSummary: planned.planSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? fallback.planSummary
                : planned.planSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            missingInformation: missingInformation.isEmpty ? fallback.missingInformation : missingInformation,
            researchQuestions: researchQuestions.isEmpty ? fallback.researchQuestions : researchQuestions,
            publicTargets: Array(publicTargets.prefix(researchPlanPublicTargetLimit(for: mode))),
            sourceGaps: Array(sourceGaps.prefix(4))
        )
    }

    private func ensureSecondaryAssistedSourceBalance(
        _ publicTargets: [AnalystResearchPlan.PublicTarget],
        fallbackTargets: [AnalystResearchPlan.PublicTarget]
    ) -> [AnalystResearchPlan.PublicTarget] {
        var balanced = publicTargets

        func isOfficialOrAppOwned(_ target: AnalystResearchPlan.PublicTarget) -> Bool {
            target.approvedSource.sourceTier == .officialPrimary
                || target.approvedSource.sourceTier == .appOwnedTruth
        }

        func isSecondary(_ target: AnalystResearchPlan.PublicTarget) -> Bool {
            target.approvedSource.sourceTier == .reputableSecondary
        }

        func containsURL(_ target: AnalystResearchPlan.PublicTarget) -> Bool {
            balanced.contains { $0.approvedSource.url.absoluteString.lowercased() == target.approvedSource.url.absoluteString.lowercased() }
        }

        if balanced.contains(where: isOfficialOrAppOwned) == false,
           let officialFallback = fallbackTargets.first(where: isOfficialOrAppOwned),
           containsURL(officialFallback) == false {
            balanced.insert(officialFallback, at: 0)
        }

        if balanced.contains(where: isSecondary) == false,
           let secondaryFallback = fallbackTargets.first(where: isSecondary),
           containsURL(secondaryFallback) == false {
            balanced.append(secondaryFallback)
        }

        var deduplicated: [AnalystResearchPlan.PublicTarget] = []
        var seenURLs = Set<String>()
        for target in balanced {
            let key = target.approvedSource.url.absoluteString.lowercased()
            guard seenURLs.insert(key).inserted else { continue }
            deduplicated.append(target)
        }

        let targetLimit = researchPlanPublicTargetLimit(for: .secondaryAssisted)
        guard deduplicated.count > targetLimit else {
            return deduplicated
        }

        var prioritized: [AnalystResearchPlan.PublicTarget] = []
        func appendIfNeeded(_ target: AnalystResearchPlan.PublicTarget) {
            guard prioritized.count < targetLimit,
                  prioritized.contains(where: {
                      $0.approvedSource.url.absoluteString.lowercased() == target.approvedSource.url.absoluteString.lowercased()
                  }) == false else {
                return
            }
            prioritized.append(target)
        }

        if let official = deduplicated.first(where: isOfficialOrAppOwned) {
            appendIfNeeded(official)
        }
        if let secondary = deduplicated.first(where: isSecondary) {
            appendIfNeeded(secondary)
        }
        for target in deduplicated {
            appendIfNeeded(target)
        }
        return prioritized
    }

    private func sectorResearchSourceSeeds(
        for charter: AnalystCharter,
        taskIntent: LocalTaskIntent
    ) -> [ResearchSourceSeed] {
        if taskIntent == .portfolioRiskTrigger {
            return [
                ResearchSourceSeed(
                    label: "Federal Reserve press releases",
                    urlString: "https://www.federalreserve.gov/newsevents/pressreleases.htm",
                    category: "macro_policy",
                    accessMode: .publicOpen,
                    whyItMatters: "Official policy updates can help explain whether a portfolio-risk concern is part of a broader rates, liquidity, or financial-conditions move.",
                    missingInformationHint: "Whether the current portfolio-risk posture is being reinforced by official policy or funding signals."
                )
            ]
        }

        switch charter.analystId {
        case recentNewsStandingAnalystID:
            return [
                ResearchSourceSeed(
                    label: "Axios",
                    urlString: "https://www.axios.com/",
                    category: "recent_news_baseline",
                    accessMode: .publicOpen,
                    whyItMatters: "Axios AI and technology coverage is part of the required practical recent-news baseline for this analyst and should be checked even when it is not in RSS ingestion.",
                    missingInformationHint: "Whether Axios coverage adds or omits a materially relevant same-window development beyond the app-owned recent-news baseline."
                ),
                ResearchSourceSeed(
                    label: "TechCrunch",
                    urlString: "https://techcrunch.com/",
                    category: "supplemental_recent_news",
                    accessMode: .publicOpen,
                    whyItMatters: "Broader technology and startup reporting can confirm timing, breadth, or competitive context when the app-news baseline leaves a recent-news development ambiguous.",
                    missingInformationHint: "Whether broader public reporting confirms, qualifies, or challenges the app-owned recent-news read."
                ),
                ResearchSourceSeed(
                    label: "The Information",
                    urlString: "https://www.theinformation.com/",
                    category: "premium_recent_news",
                    accessMode: .subscriptionGated,
                    whyItMatters: "Specialist premium reporting may materially improve the read when public recent-news evidence remains thin or incomplete.",
                    missingInformationHint: "Which gated premium source would materially sharpen the recent-news interpretation if access were available."
                )
            ]
        case "bench-sector-technology-analyst":
            return [
                ResearchSourceSeed(label: "SEC company filings", urlString: "https://www.sec.gov/edgar/search/", category: "official_filings", accessMode: .publicOpen, whyItMatters: "Company filings and official disclosures help distinguish product or demand headlines from management-confirmed commentary.", missingInformationHint: "What management, filings, or official company materials say about demand, capex, pricing, or timing."),
                ResearchSourceSeed(label: "Semiconductor Engineering", urlString: "https://semiengineering.com/", category: "industry_publication", accessMode: .publicOpen, whyItMatters: "Sector trade coverage can add supply-chain, tooling, and manufacturing context beyond a single headline.", missingInformationHint: "Whether sector breadth, supply constraints, or implementation bottlenecks are showing up across the broader technology stack."),
                ResearchSourceSeed(label: "Data Center Dynamics", urlString: "https://www.datacenterdynamics.com/en/news/", category: "industry_publication", accessMode: .publicOpen, whyItMatters: "Data-center infrastructure reporting can sharpen the read on deployment timing, power, and buildout bottlenecks.", missingInformationHint: "Whether infrastructure, power, and deployment conditions support or challenge the baseline technology headline."),
                ResearchSourceSeed(label: "SemiAnalysis", urlString: "https://www.semianalysis.com/", category: "premium_industry_research", accessMode: .subscriptionGated, whyItMatters: "Premium semiconductor research can materially improve understanding of supply-chain and capex developments when public evidence is thin.", missingInformationHint: "Which premium industry work would best answer unresolved semicap, supply-chain, or infrastructure questions.")
            ]
        case "bench-sector-healthcare-biotech-analyst":
            return [
                ResearchSourceSeed(label: "FDA press announcements", urlString: "https://www.fda.gov/news-events/press-announcements", category: "regulator", accessMode: .publicOpen, whyItMatters: "Official regulator updates help confirm approvals, warnings, and trial-related developments.", missingInformationHint: "Whether regulator or company-primary sources confirm the healthcare headline and clarify timing."),
                ResearchSourceSeed(label: "ClinicalTrials.gov", urlString: "https://clinicaltrials.gov/", category: "clinical_primary_source", accessMode: .publicOpen, whyItMatters: "Trial records can sharpen the analyst view when media coverage gestures at pipeline or data developments.", missingInformationHint: "What formal trial status or pipeline evidence exists beyond the initial healthcare headline."),
                ResearchSourceSeed(label: "Fierce Biotech", urlString: "https://www.fiercebiotech.com/", category: "industry_publication", accessMode: .publicOpen, whyItMatters: "Healthcare trade press can add competitor, pipeline, and therapy-area context beyond one issuer headline.", missingInformationHint: "Whether sector competitors, pipeline context, or therapy-area breadth confirm or challenge the initial read."),
                ResearchSourceSeed(label: "Endpoints News", urlString: "https://www.endpts.com/", category: "premium_industry_research", accessMode: .signUpGated, whyItMatters: "Specialist biotech reporting can materially improve understanding of fast-moving clinical or regulatory developments.", missingInformationHint: "Which gated biotech reporting would materially sharpen the view on trial, regulatory, or competitive context.")
            ]
        case "bench-sector-consumer-analyst":
            return [
                ResearchSourceSeed(label: "Retail Dive", urlString: "https://www.retaildive.com/", category: "industry_publication", accessMode: .publicOpen, whyItMatters: "Consumer trade coverage can add pricing, traffic, inventory, and category breadth context.", missingInformationHint: "Whether the consumer headline is isolated or part of a broader demand, pricing, or inventory pattern."),
                ResearchSourceSeed(label: "National Retail Federation", urlString: "https://nrf.com/media-center", category: "industry_association", accessMode: .publicOpen, whyItMatters: "Industry association materials can help confirm whether the setup is broad, seasonal, or category-specific.", missingInformationHint: "What broader category or seasonal context exists beyond the initial consumer headline."),
                ResearchSourceSeed(label: "Company investor relations materials", urlString: nil, category: "official_company_materials", accessMode: .unsupportedByTooling, whyItMatters: "Direct IR materials would sharpen the read when the analyst needs management commentary, guidance, or category updates from a specific consumer issuer.", missingInformationHint: "What official company commentary would materially sharpen the view on consumer demand or margin quality.")
            ]
        case "bench-sector-industrials-analyst":
            return [
                ResearchSourceSeed(label: "FAA newsroom", urlString: "https://www.faa.gov/newsroom", category: "regulator", accessMode: .publicOpen, whyItMatters: "Official aviation and transport notices can help confirm safety, certification, or traffic-related developments.", missingInformationHint: "Whether official regulator or operating data confirms the industrial or aerospace headline."),
                ResearchSourceSeed(label: "Supply Chain Dive", urlString: "https://www.supplychaindive.com/", category: "industry_publication", accessMode: .publicOpen, whyItMatters: "Supply-chain trade coverage can add delivery, backlog, logistics, and input-cost context.", missingInformationHint: "Whether backlog, logistics, or supply-chain conditions across the sector reinforce or challenge the baseline view."),
                ResearchSourceSeed(label: "Defense News", urlString: "https://www.defensenews.com/", category: "industry_publication", accessMode: .publicOpen, whyItMatters: "Defense and aerospace sector coverage can add peer, backlog, and execution context.", missingInformationHint: "What competitor, backlog, or end-market context matters beyond the first industrial headline.")
            ]
        case "bench-sector-financials-analyst":
            return [
                ResearchSourceSeed(label: "Federal Reserve press releases", urlString: "https://www.federalreserve.gov/newsevents/pressreleases.htm", category: "regulator", accessMode: .publicOpen, whyItMatters: "Official policy and supervision releases can materially change the read on funding, credit, or liquidity-sensitive financial names.", missingInformationHint: "Whether official policy, supervision, or funding signals reinforce the financials headline."),
                ResearchSourceSeed(label: "FDIC newsroom", urlString: "https://www.fdic.gov/news/", category: "regulator", accessMode: .publicOpen, whyItMatters: "Banking regulator commentary can add deposit, resolution, and credit-system context.", missingInformationHint: "What system-level funding or deposit context exists beyond the initial bank headline."),
                ResearchSourceSeed(label: "WhaleWisdom 13F research", urlString: "https://whalewisdom.com/", category: "reputable_secondary_13f_discovery", accessMode: .publicOpen, sourceTier: .reputableSecondary, whyItMatters: "Reputable secondary 13F aggregation can help discover or corroborate asset-manager filing identity and holdings context when official SEC retrieval is incomplete.", missingInformationHint: "Whether reputable secondary 13F coverage helps identify the filer, latest filing, or holdings context that official sources should then confirm."),
                ResearchSourceSeed(label: "American Banker", urlString: "https://www.americanbanker.com/", category: "premium_industry_research", accessMode: .subscriptionGated, whyItMatters: "Specialist financial trade coverage can materially sharpen the read when regional-bank or credit-system nuance matters.", missingInformationHint: "Which premium financial-industry reporting would most help answer open credit, funding, or supervision questions.")
            ]
        case "bench-sector-energy-materials-analyst":
            return [
                ResearchSourceSeed(label: "EIA Today in Energy", urlString: "https://www.eia.gov/todayinenergy/", category: "official_data", accessMode: .publicOpen, whyItMatters: "Official energy data and commentary can confirm whether a commodity headline is broad and durable.", missingInformationHint: "Whether commodity, demand, or inventory data confirms the energy/materials headline."),
                ResearchSourceSeed(label: "OPEC press room", urlString: "https://www.opec.org/opec_web/en/press_room/19.htm", category: "official_industry_body", accessMode: .publicOpen, whyItMatters: "Producer guidance can sharpen the read on oil supply posture and macro transmission.", missingInformationHint: "What official supply or production guidance says beyond the initial commodity headline."),
                ResearchSourceSeed(label: "Mining.com", urlString: "https://www.mining.com/", category: "industry_publication", accessMode: .publicOpen, whyItMatters: "Industry coverage can add miner, metal, and supply-chain context.", missingInformationHint: "Whether broader materials and mining conditions reinforce the initial sector read."),
                ResearchSourceSeed(label: "S&P Global Commodity Insights", urlString: "https://www.spglobal.com/commodityinsights/en", category: "premium_industry_research", accessMode: .subscriptionGated, whyItMatters: "Premium commodity reporting can materially sharpen the view when public market commentary is too generic.", missingInformationHint: "Which premium commodity or shipping source would best answer unresolved supply, inventory, or pricing questions.")
            ]
        case "bench-overlay-macro-international-analyst":
            return [
                ResearchSourceSeed(label: "Federal Reserve press releases", urlString: "https://www.federalreserve.gov/newsevents/pressreleases.htm", category: "macro_policy", accessMode: .publicOpen, whyItMatters: "Official policy releases help confirm transmission from macro headlines into rates and risk assets.", missingInformationHint: "Which official policy or rates sources best explain macro transmission into current holdings or ETF expressions."),
                ResearchSourceSeed(label: "European Central Bank press releases", urlString: "https://www.ecb.europa.eu/press/html/index.en.html", category: "macro_policy", accessMode: .publicOpen, whyItMatters: "International policy signals can materially change the macro or FX overlay read.", missingInformationHint: "Whether international central-bank or policy moves materially change the macro and FX view."),
                ResearchSourceSeed(label: "IMF News", urlString: "https://www.imf.org/en/News", category: "macro_international", accessMode: .publicOpen, whyItMatters: "Macro and international coverage can add global breadth and transmission context.", missingInformationHint: "What cross-border, FX, or growth-transmission evidence exists beyond the initial macro headline."),
                ResearchSourceSeed(label: "Reuters Markets", urlString: "https://www.reuters.com/markets/", category: "reputable_macro_markets_news", accessMode: .publicOpen, sourceTier: .reputableSecondary, whyItMatters: "Reputable markets reporting can add cross-asset context, investor interpretation, and corroboration around official macro or international data.", missingInformationHint: "Whether reputable markets coverage corroborates or complicates the official macro-policy or international signal."),
                ResearchSourceSeed(label: "Haver Analytics", urlString: "https://www.haver.com/", category: "premium_macro_research", accessMode: .subscriptionGated, whyItMatters: "Premium macro data services may be useful when public evidence is too thin for a higher-confidence overlay view.", missingInformationHint: "Which premium macro data source would materially sharpen unresolved cross-asset or international questions.")
            ]
        case "bench-overlay-portfolio-risk":
            return [
                ResearchSourceSeed(label: "Federal Reserve press releases", urlString: "https://www.federalreserve.gov/newsevents/pressreleases.htm", category: "macro_policy", accessMode: .publicOpen, whyItMatters: "Policy and funding signals can help determine whether portfolio-risk posture changes are local or system-wide.", missingInformationHint: "Whether macro policy or funding conditions materially change the current portfolio-risk posture."),
                ResearchSourceSeed(label: "SEC company filings", urlString: "https://www.sec.gov/edgar/search/", category: "official_filings", accessMode: .publicOpen, whyItMatters: "Issuer filings can help confirm whether a concentration or event-cluster concern has fundamental support.", missingInformationHint: "Which issuer-primary materials would clarify whether the risk trigger is durable or only headline noise.")
            ]
        default:
            return []
        }
    }

    private func makeSourceAccessSuggestions(
        charter: AnalystCharter,
        task: AnalystTask,
        memo: AnalystMemo,
        finding: AnalystFinding,
        bundle: AnalystEvidenceBundle,
        delegationID: String?,
        researchPlan: AnalystResearchPlan?,
        externalIssues: [AnalystExternalEvidenceIssue]
    ) -> [AnalystSourceAccessSuggestionRecord] {
        var suggestions: [AnalystSourceAccessSuggestionRecord] = []
        let supportedSources = ApprovedAnalystSourceCatalog().sources(for: charter)
        let supportedFingerprints = Set(
            supportedSources.flatMap { source in
                [
                    source.sourceID.lowercased(),
                    source.titleHint.lowercased(),
                    source.url.host?.lowercased(),
                    source.url.absoluteString.lowercased()
                ].compactMap { $0 }
            }
        )
        let genericPreferredSources: Set<String> = [
            "primary sources",
            "official company / regulator / exchange / issuer materials",
            "reputable financial press",
            "reputable industry publications",
            "reputable research/reference sources"
        ]

        if charter.sourcePolicy.reputableWebResearchAllowed {
            for preferredSource in charter.sourcePolicy.preferredSources {
                let normalized = preferredSource.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowered = normalized.lowercased()
                guard normalized.isEmpty == false,
                      genericPreferredSources.contains(lowered) == false else {
                    continue
                }
                if isRestrictedSourceDescriptor(normalized, charter: charter) {
                    suggestions.append(
                        makeSourceAccessSuggestion(
                            charter: charter,
                            task: task,
                            memo: memo,
                            finding: finding,
                            bundle: bundle,
                            delegationID: delegationID,
                            requestedSource: normalized,
                            requestedDomain: extractSuggestedDomain(from: normalized),
                            whyItMatters: "This source would otherwise be relevant for recurring research, but the current charter policy marks it restricted in the covered fetch path.",
                            limitation: .restrictedByPolicy,
                            recommendedNextStep: .allowByCharterUpdate
                        )
                    )
                    continue
                }
                guard supportedFingerprints.contains(lowered) == false else {
                    continue
                }
                suggestions.append(
                    makeSourceAccessSuggestion(
                        charter: charter,
                        task: task,
                        memo: memo,
                        finding: finding,
                        bundle: bundle,
                        delegationID: delegationID,
                        requestedSource: normalized,
                        requestedDomain: extractSuggestedDomain(from: normalized),
                        whyItMatters: "This charter prefers \(normalized) for recurring research, but the current bounded worker tooling cannot fetch or normalize it yet.",
                        limitation: .unsupportedByTooling,
                        recommendedNextStep: .improveToolingSupport
                    )
                )
            }
        }

        for issue in externalIssues {
            guard issue.category == .transport
                || issue.category == .httpStatus
                || issue.category == .invalidResponse
                || issue.category == .invalidContent else {
                continue
            }
            let requestedSource = issue.host ?? "external source"
            suggestions.append(
                makeSourceAccessSuggestion(
                    charter: charter,
                    task: task,
                    memo: memo,
                    finding: finding,
                    bundle: bundle,
                    delegationID: delegationID,
                    requestedSource: requestedSource,
                    requestedDomain: issue.host,
                    whyItMatters: "This source was allowed by the charter-driven policy for the current run, but it was inaccessible or failed normalization during evidence assembly.",
                    limitation: .inaccessible,
                    recommendedNextStep: .improveToolingSupport
                )
            )
        }

        if let researchPlan {
            for gap in researchPlan.sourceGaps {
                suggestions.append(
                    makeSourceAccessSuggestion(
                        charter: charter,
                        task: task,
                        memo: memo,
                        finding: finding,
                        bundle: bundle,
                        delegationID: delegationID,
                        requestedSource: gap.requestedSource,
                        requestedDomain: gap.requestedDomain,
                        whyItMatters: "\(gap.whyItMatters) Missing information it would help answer: \(gap.missingInformationNeed)",
                        limitation: gap.limitation,
                        recommendedNextStep: gap.recommendedNextStep
                    )
                )
            }
        }

        var unique: [String: AnalystSourceAccessSuggestionRecord] = [:]
        for suggestion in suggestions {
            unique[suggestion.suggestionId] = suggestion
        }
        return unique.values.sorted { lhs, rhs in lhs.suggestionId < rhs.suggestionId }
    }

    private func makeSourceAccessSuggestion(
        charter: AnalystCharter,
        task: AnalystTask,
        memo: AnalystMemo,
        finding: AnalystFinding,
        bundle: AnalystEvidenceBundle,
        delegationID: String?,
        requestedSource: String,
        requestedDomain: String?,
        whyItMatters: String,
        limitation: AnalystSourceAccessSuggestionLimitation,
        recommendedNextStep: AnalystSourceAccessSuggestionNextStep
    ) -> AnalystSourceAccessSuggestionRecord {
        let createdAt = now()
        return AnalystSourceAccessSuggestionRecord(
            suggestionId: stableHashedIdentifier(
                prefix: "source-gap",
                components: [charter.charterId, task.taskId, requestedSource, limitation.rawValue]
            ),
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: task.taskId,
            memoId: memo.memoId,
            findingId: finding.findingId,
            evidenceBundleId: bundle.bundleId,
            delegationId: delegationID,
            requestedSource: requestedSource,
            requestedDomain: requestedDomain,
            siteName: requestedSource,
            whyItMatters: whyItMatters,
            affectedTaskSummary: task.title,
            limitation: limitation,
            recommendedNextStep: recommendedNextStep,
            status: .open,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func extractSuggestedDomain(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains(".") else {
            return nil
        }
        return trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/")
            .first
            .map(String.init)
    }

    private func localRuntimeExecutionProfile(
        for intendedRuntimePolicy: AnalystRuntimePolicy?
    ) -> LocalRuntimeExecutionProfile {
        let trimmedRuntimeIdentifier = intendedRuntimePolicy?.runtimeIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let memoStyle: LocalMemoStyle
        if let trimmedRuntimeIdentifier, trimmedRuntimeIdentifier.isEmpty == false {
            let lowered = trimmedRuntimeIdentifier.lowercased()
            if lowered.contains("mini") {
                memoStyle = .concise
            } else if lowered.contains("gpt-5") || intendedRuntimePolicy?.reasoningMode == .deliberate {
                memoStyle = .deep
            } else {
                memoStyle = .balanced
            }
        } else if intendedRuntimePolicy?.reasoningMode == .deliberate {
            memoStyle = .deep
        } else {
            memoStyle = .balanced
        }

        let actualRuntimeIdentifier: String
        if let trimmedRuntimeIdentifier, trimmedRuntimeIdentifier.isEmpty == false {
            actualRuntimeIdentifier = "deterministic_local[\(trimmedRuntimeIdentifier)]"
        } else {
            actualRuntimeIdentifier = "deterministic_local"
        }

        return LocalRuntimeExecutionProfile(
            actualRuntimeIdentifier: actualRuntimeIdentifier,
            actualReasoningMode: intendedRuntimePolicy?.reasoningMode,
            memoStyle: memoStyle
        )
    }

    private func fallbackLocalRuntimeExecutionProfile(
        for intendedRuntimePolicy: AnalystRuntimePolicy?
    ) -> LocalRuntimeExecutionProfile {
        let base = localRuntimeExecutionProfile(for: intendedRuntimePolicy)
        guard let runtimeIdentifier = intendedRuntimePolicy?.runtimeIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !runtimeIdentifier.isEmpty else {
            return LocalRuntimeExecutionProfile(
                actualRuntimeIdentifier: "deterministic_local_fallback",
                actualReasoningMode: base.actualReasoningMode,
                memoStyle: base.memoStyle
            )
        }

        return LocalRuntimeExecutionProfile(
            actualRuntimeIdentifier: "deterministic_local_fallback[\(runtimeIdentifier)]",
            actualReasoningMode: base.actualReasoningMode,
            memoStyle: base.memoStyle
        )
    }

    private func performSynthesis(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        taskIntent: LocalTaskIntent,
        intendedRuntimePolicy: AnalystRuntimePolicy?
    ) async -> SynthesisAttemptOutcome {
        let trimmedRuntimeIdentifier = intendedRuntimePolicy?.runtimeIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedRuntimeIdentifier, !trimmedRuntimeIdentifier.isEmpty else {
            let local = localRuntimeExecutionProfile(for: intendedRuntimePolicy)
            return SynthesisAttemptOutcome(
                output: nil,
                actualRuntimeIdentifier: local.actualRuntimeIdentifier,
                actualReasoningMode: local.actualReasoningMode,
                memoStyle: local.memoStyle,
                usedOpenAI: false,
                synthesisStatus: "deterministic_local",
                synthesisIssueSummary: nil
            )
        }

        switch intendedRuntimePolicy?.providerKind ?? .openAI {
        case .openAI:
            return await performOpenAISynthesis(
                trimmedRuntimeIdentifier: trimmedRuntimeIdentifier,
                charter: charter,
                task: task,
                news: news,
                researchPlan: researchPlan,
                externalEvidence: externalEvidence,
                externalIssues: externalIssues,
                taskIntent: taskIntent,
                intendedRuntimePolicy: intendedRuntimePolicy
            )
        case .anthropic:
            return await performAnthropicSynthesis(
                trimmedRuntimeIdentifier: trimmedRuntimeIdentifier,
                charter: charter,
                task: task,
                news: news,
                researchPlan: researchPlan,
                externalEvidence: externalEvidence,
                externalIssues: externalIssues,
                taskIntent: taskIntent,
                intendedRuntimePolicy: intendedRuntimePolicy
            )
        }
    }

    private func performOpenAISynthesis(
        trimmedRuntimeIdentifier: String,
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        taskIntent: LocalTaskIntent,
        intendedRuntimePolicy: AnalystRuntimePolicy?
    ) async -> SynthesisAttemptOutcome {
        let credentialResolution = openAIKeyStatusProvider.credentialResolution()
        guard let apiKey = credentialResolution.apiKey else {
            let fallback = fallbackLocalRuntimeExecutionProfile(for: intendedRuntimePolicy)
            return SynthesisAttemptOutcome(
                output: nil,
                actualRuntimeIdentifier: fallback.actualRuntimeIdentifier,
                actualReasoningMode: fallback.actualReasoningMode,
                memoStyle: fallback.memoStyle,
                usedOpenAI: false,
                synthesisStatus: credentialResolution.fallbackStatus,
                synthesisIssueSummary: credentialResolution.synthesisIssueSummary
            )
        }

        do {
            let output = try await openAISynthesisProvider.synthesize(
                request: makeOpenAISynthesisRequest(
                    charter: charter,
                    task: task,
                    news: news,
                    researchPlan: researchPlan,
                    externalEvidence: externalEvidence,
                    externalIssues: externalIssues,
                    taskIntent: taskIntent,
                    intendedRuntimePolicy: intendedRuntimePolicy
                ),
                apiKey: apiKey
            )
            return SynthesisAttemptOutcome(
                output: output,
                actualRuntimeIdentifier: "openai_responses[\(trimmedRuntimeIdentifier)]",
                actualReasoningMode: intendedRuntimePolicy?.reasoningMode,
                memoStyle: localRuntimeExecutionProfile(for: intendedRuntimePolicy).memoStyle,
                usedOpenAI: true,
                synthesisStatus: "openai_responses",
                synthesisIssueSummary: nil
            )
        } catch let error as AnalystOpenAISynthesisError {
            let fallback = fallbackLocalRuntimeExecutionProfile(for: intendedRuntimePolicy)
            return SynthesisAttemptOutcome(
                output: nil,
                actualRuntimeIdentifier: fallback.actualRuntimeIdentifier,
                actualReasoningMode: fallback.actualReasoningMode,
                memoStyle: fallback.memoStyle,
                usedOpenAI: false,
                synthesisStatus: "fallback_openai_error",
                synthesisIssueSummary: error.boundedSummary
            )
        } catch {
            let fallback = fallbackLocalRuntimeExecutionProfile(for: intendedRuntimePolicy)
            return SynthesisAttemptOutcome(
                output: nil,
                actualRuntimeIdentifier: fallback.actualRuntimeIdentifier,
                actualReasoningMode: fallback.actualReasoningMode,
                memoStyle: fallback.memoStyle,
                usedOpenAI: false,
                synthesisStatus: "fallback_openai_error",
                synthesisIssueSummary: "openai_unexpected_error"
            )
        }
    }

    private func performAnthropicSynthesis(
        trimmedRuntimeIdentifier: String,
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        taskIntent: LocalTaskIntent,
        intendedRuntimePolicy: AnalystRuntimePolicy?
    ) async -> SynthesisAttemptOutcome {
        guard let intendedRuntimePolicy else {
            return await performOpenAISynthesis(
                trimmedRuntimeIdentifier: trimmedRuntimeIdentifier,
                charter: charter,
                task: task,
                news: news,
                researchPlan: researchPlan,
                externalEvidence: externalEvidence,
                externalIssues: externalIssues,
                taskIntent: taskIntent,
                intendedRuntimePolicy: nil
            )
        }

        let credentialResolution = llmCredentialResolution(for: intendedRuntimePolicy)
        guard let apiKey = credentialResolution.apiKey else {
            let fallback = fallbackLocalRuntimeExecutionProfile(for: intendedRuntimePolicy)
            return SynthesisAttemptOutcome(
                output: nil,
                actualRuntimeIdentifier: fallback.actualRuntimeIdentifier,
                actualReasoningMode: fallback.actualReasoningMode,
                memoStyle: fallback.memoStyle,
                usedOpenAI: false,
                synthesisStatus: credentialResolution.fallbackStatus,
                synthesisIssueSummary: credentialResolution.synthesisIssueSummary
            )
        }

        do {
            let output = try await anthropicSynthesisProvider.synthesize(
                request: makeOpenAISynthesisRequest(
                    charter: charter,
                    task: task,
                    news: news,
                    researchPlan: researchPlan,
                    externalEvidence: externalEvidence,
                    externalIssues: externalIssues,
                    taskIntent: taskIntent,
                    intendedRuntimePolicy: intendedRuntimePolicy
                ),
                apiKey: apiKey
            )
            return SynthesisAttemptOutcome(
                output: output,
                actualRuntimeIdentifier: "anthropic_messages[\(trimmedRuntimeIdentifier)]",
                actualReasoningMode: intendedRuntimePolicy.reasoningMode,
                memoStyle: localRuntimeExecutionProfile(for: intendedRuntimePolicy).memoStyle,
                usedOpenAI: false,
                synthesisStatus: "anthropic_messages",
                synthesisIssueSummary: nil
            )
        } catch let error as AnalystAnthropicSynthesisError {
            let fallback = fallbackLocalRuntimeExecutionProfile(for: intendedRuntimePolicy)
            return SynthesisAttemptOutcome(
                output: nil,
                actualRuntimeIdentifier: fallback.actualRuntimeIdentifier,
                actualReasoningMode: fallback.actualReasoningMode,
                memoStyle: fallback.memoStyle,
                usedOpenAI: false,
                synthesisStatus: "fallback_anthropic_error",
                synthesisIssueSummary: error.boundedSummary
            )
        } catch {
            let fallback = fallbackLocalRuntimeExecutionProfile(for: intendedRuntimePolicy)
            return SynthesisAttemptOutcome(
                output: nil,
                actualRuntimeIdentifier: fallback.actualRuntimeIdentifier,
                actualReasoningMode: fallback.actualReasoningMode,
                memoStyle: fallback.memoStyle,
                usedOpenAI: false,
                synthesisStatus: "fallback_anthropic_error",
                synthesisIssueSummary: "anthropic_unexpected_error"
            )
        }
    }

    private func llmCredentialResolution(
        for policy: AnalystRuntimePolicy
    ) -> LLMCredentialResolution {
        let settings = (try? llmProviderSettingsStore.loadOrDefault()) ?? .default(now: now())
        let profileId = policy.credentialProfileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? policy.providerKind.defaultCredentialProfileId
            : policy.credentialProfileId
        let profile = settings.profile(id: profileId)
            ?? settings.profiles(for: policy.providerKind).first
            ?? (policy.providerKind == .openAI
                ? LLMCredentialProfile.defaultOpenAI(now: now())
                : LLMCredentialProfile.defaultAnthropic(now: now()))
        return llmCredentialResolver.resolve(profile: profile)
    }

    private func llmRuntimeCanOwnPublicResearch(
        charter: AnalystCharter,
        intendedRuntimePolicy: AnalystRuntimePolicy?
    ) -> Bool {
        guard directPublicWebSearchEnabled(for: charter),
              let intendedRuntimePolicy,
              intendedRuntimePolicy.runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return false
        }
        switch intendedRuntimePolicy.providerKind {
        case .openAI:
            return openAIKeyStatusProvider.credentialResolution().apiKey != nil
        case .anthropic:
            return llmCredentialResolution(for: intendedRuntimePolicy).apiKey != nil
        }
    }

    private func providerSynthesisIsRequired(
        for task: AnalystTask,
        intendedRuntimePolicy: AnalystRuntimePolicy?
    ) -> Bool {
        guard intendedRuntimePolicy != nil else {
            return false
        }
        return isPMRequestedAdHocTask(task)
            || task.tags.contains("standing_report")
            || task.tags.contains("recent_news_material_impact")
            || task.tags.contains("portfolio_risk_trigger")
    }

    private func makeOpenAISynthesisRequest(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        taskIntent: LocalTaskIntent,
        intendedRuntimePolicy: AnalystRuntimePolicy?
    ) -> AnalystOpenAISynthesisRequest {
        let supplementalAssessments = assessSupplementalExternalEvidence(
            news: news,
            externalEvidence: externalEvidence
        )
        return AnalystOpenAISynthesisRequest(
            runtimeIdentifier: intendedRuntimePolicy?.runtimeIdentifier ?? "gpt-4.1",
            reasoningMode: intendedRuntimePolicy?.reasoningMode,
            charterTitle: charter.title,
            charterSummary: charter.summary,
            charterDocumentBodyExcerpt: trimmedDocumentBody(charter.primaryDocumentBody, limit: 2_400),
            taskTitle: task.title,
            taskDescription: task.description,
            taskIntent: synthesisIntentLabel(taskIntent),
            pmTaskingBriefBody: makePMTaskingBriefBody(task.pmTaskingBrief),
            researchPlanSummary: researchPlan?.planSummary,
            missingInformationItems: researchPlan?.missingInformation ?? [],
            researchQuestionItems: requiredResearchQuestions(for: task, researchPlan: researchPlan),
            plannedSourceTargets: researchPlan?.publicTargets.map { target in
                AnalystOpenAISynthesisRequest.PlannedSourceTarget(
                    label: target.label,
                    category: target.category,
                    source: target.approvedSource.url.absoluteString,
                    whyItMatters: target.whyItMatters
                )
            } ?? [],
            sourceGapItems: researchPlan?.sourceGaps.map { gap in
                AnalystOpenAISynthesisRequest.SourceGapItem(
                    requestedSource: gap.requestedSource,
                    requestedDomain: gap.requestedDomain,
                    whyItMatters: gap.whyItMatters,
                    missingInformationNeed: gap.missingInformationNeed,
                    limitation: gap.limitation.rawValue
                )
            } ?? [],
            newsItems: news.prefix(8).map { item in
                AnalystOpenAISynthesisRequest.NewsItem(
                    source: item.source,
                    title: item.title,
                    summary: item.summary,
                    symbols: item.rawSymbolHints,
                    tags: item.tags,
                    publishedAt: item.publishedAt
                )
            },
            externalEvidenceItems: Array(supplementalAssessments.prefix(10)).map { assessment in
                let item = assessment.document
                return AnalystOpenAISynthesisRequest.EvidenceItem(
                    sourceID: item.sourceID,
                    title: item.title,
                    summary: item.summary,
                    snippet: item.snippet,
                    url: item.url,
                    observedAt: item.observedAt,
                    provenanceNote: item.provenanceNote,
                    sourceTier: item.sourceTier,
                    baselineRelation: assessment.relation.rawValue,
                    incrementalValueSummary: assessment.incrementalValueSummary
                )
            },
            externalEvidenceIssues: externalIssues.map(\.boundedSummary),
            selectedSkills: task.contextPack?.referencedSkills ?? [],
            publicWebSearchEnabled: directPublicWebSearchEnabled(for: charter)
        )
    }

    private func directPublicWebSearchEnabled(for charter: AnalystCharter) -> Bool {
        charter.sourcePolicy.reputableWebResearchAllowed
            && charter.allowedSources.contains("no_external_evidence_required") == false
    }

    private func scopedBaselineNews(
        for task: AnalystTask,
        fallback: [NewsEvent],
        limit: Int
    ) -> [NewsEvent] {
        let sourceNews: [NewsEvent]
        if let contextPack = task.contextPack,
           contextPack.sharedCurrentTruth.recentNews.isEmpty == false {
            sourceNews = contextPack.sharedCurrentTruth.recentNews.map { item in
                NewsEvent(
                    eventId: item.eventId,
                    source: item.source,
                    title: item.title,
                    url: item.url,
                    publishedAt: item.publishedAt,
                    receivedAt: item.publishedAt,
                    summary: item.summary,
                    rawSymbolHints: item.symbolHints,
                    tags: item.tags ?? []
                )
            }
        } else {
            sourceNews = fallback
        }

        let limited = Array(sourceNews.prefix(limit))
        guard isPMRequestedAdHocTask(task) else {
            return limited
        }

        let relevant = limited.filter { newsItem in
            appNewsItem(newsItem, isRelevantTo: task)
        }
        return relevant
    }

    private func isPMRequestedAdHocTask(_ task: AnalystTask) -> Bool {
        task.tags.contains("pm-conversation-delegation")
            || task.pmTaskingBrief?.coverageRequired == true
            || (task.pmTaskingBrief?.researchQuestions.isEmpty == false)
    }

    private func appNewsItem(_ newsItem: NewsEvent, isRelevantTo task: AnalystTask) -> Bool {
        let taskSymbols = Set(
            task.symbols
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                .filter { $0.isEmpty == false }
        )
        let newsSymbols = Set(newsItem.rawSymbolHints.map { $0.uppercased() })
        if taskSymbols.isEmpty == false,
           taskSymbols.intersection(newsSymbols).isEmpty == false {
            return true
        }

        let text = [
            newsItem.title,
            newsItem.summary ?? "",
            newsItem.tags.joined(separator: " "),
            newsItem.rawSymbolHints.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()

        for symbol in taskSymbols where symbol.count >= 3 {
            if text.contains(symbol.lowercased()) {
                return true
            }
        }

        let terms = taskRelevanceTerms(for: task)
        guard terms.isEmpty == false else {
            return true
        }
        var hitCount = 0
        for term in terms where text.contains(term) {
            hitCount += 1
            if hitCount >= 2 {
                return true
            }
        }
        return false
    }

    private func taskRelevanceTerms(for task: AnalystTask) -> [String] {
        let stopWords: Set<String> = [
            "about", "analyst", "answer", "available", "baseline", "cash", "charter", "context",
            "current", "evidence", "expected", "full", "latest", "liquidity", "market", "next",
            "official", "owner", "public", "question", "questions", "report", "research",
            "source", "sources", "task", "timing", "valuation", "whether", "with"
        ]
        let values = [
            task.title,
            task.description,
            task.pmTaskingBrief?.taskObjective ?? "",
            task.pmTaskingBrief?.whyNow ?? "",
            task.pmTaskingBrief?.researchQuestions.joined(separator: " ") ?? ""
        ]
        .joined(separator: " ")

        var terms: [String] = []
        var seen = Set<String>()
        for token in values.lowercased().split(whereSeparator: { $0.isLetter == false && $0.isNumber == false }) {
            let value = String(token)
            guard value.count >= 4,
                  stopWords.contains(value) == false,
                  seen.insert(value).inserted else {
                continue
            }
            terms.append(value)
            if terms.count >= 16 {
                break
            }
        }
        return terms
    }

    private func requiredResearchQuestions(
        for task: AnalystTask,
        researchPlan: AnalystResearchPlan?
    ) -> [String] {
        let taskQuestions = AnalystTaskQuestionChecklist.questions(
            taskTitle: task.title,
            taskDescription: task.description,
            taskingBrief: task.pmTaskingBrief
        )
        if taskQuestions.isEmpty == false {
            return taskQuestions
        }

        return AnalystTaskQuestionChecklist.normalizedQuestions(researchPlan?.researchQuestions ?? [])
    }

    private func makeQuestionCoverage(
        for task: AnalystTask,
        researchPlan: AnalystResearchPlan?,
        synthesized: AnalystOpenAISynthesisOutput?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue]
    ) -> [AnalystQuestionCoverage] {
        let required = requiredResearchQuestions(for: task, researchPlan: researchPlan)
        guard required.isEmpty == false else {
            return synthesized?.questionCoverage ?? []
        }

        var coverageByQuestion: [String: AnalystQuestionCoverage] = [:]
        for item in synthesized?.questionCoverage ?? [] {
            let key = item.question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard key.isEmpty == false else { continue }
            coverageByQuestion[key] = item
        }

        let sourceTierSummary = sourceTierSummary(
            for: externalEvidence,
            synthesized: synthesized
        )
        let unresolvedReason = externalIssues.isEmpty
            ? "The analyst output did not explicitly cover this required question; follow-up/revision is required before treating it as answered."
            : "External evidence was degraded while this required question remained unresolved: \(externalEvidenceIssueSummary(externalIssues) ?? "external evidence unavailable")."

        return required.map { question in
            let key = question.lowercased()
            if let exact = coverageByQuestion[key] {
                return exact
            }
            if let fuzzy = coverageByQuestion.values.first(where: {
                $0.question.lowercased().contains(key) || key.contains($0.question.lowercased())
            }) {
                return fuzzy
            }
            if let inferred = inferredQuestionCoverage(
                question: question,
                synthesized: synthesized,
                sourceTierSummary: sourceTierSummary
            ) {
                return inferred
            }
            return AnalystQuestionCoverage(
                question: question,
                status: .notAddressed,
                answerSummary: "Not explicitly answered in the analyst output.",
                sourceTierSummary: sourceTierSummary,
                remainingGap: unresolvedReason
            )
        }
    }

    private func sourceTierSummary(
        for externalEvidence: [ExternalAnalystEvidenceDocument],
        synthesized: AnalystOpenAISynthesisOutput?
    ) -> String {
        let tiers = Array(Set(externalEvidence.map(\.sourceTier.rawValue))).sorted()
        if tiers.isEmpty == false {
            return tiers.joined(separator: ", ")
        }
        if let evidenceSummary = synthesized?.memoEvidenceSummary.trimmingCharacters(in: .whitespacesAndNewlines),
           evidenceSummary.isEmpty == false {
            return boundedEvidenceExcerpt(from: evidenceSummary, limit: 420)
        }
        return "app-owned truth and missing/restricted external source gaps"
    }

    private func inferredQuestionCoverage(
        question: String,
        synthesized: AnalystOpenAISynthesisOutput?,
        sourceTierSummary: String
    ) -> AnalystQuestionCoverage? {
        guard let synthesized else {
            return nil
        }
        let sections = [
            synthesized.memoExecutiveSummary,
            synthesized.memoCurrentView,
            synthesized.memoEvidenceSummary,
            synthesized.memoUncertaintySummary,
            synthesized.memoRecommendedNextStep
        ]
        guard let bestSection = sections.first(where: {
            synthesizedMemoSection($0, appearsToAddress: question)
        }) else {
            return nil
        }
        return AnalystQuestionCoverage(
            question: question,
            status: .partial,
            answerSummary: "Addressed in memo body, but omitted from the structured coverage array: \(boundedEvidenceExcerpt(from: bestSection, limit: 420))",
            sourceTierSummary: sourceTierSummary,
            remainingGap: "The analyst should include this answer directly in structured questionCoverage on the next pass."
        )
    }

    private func synthesizedMemoSection(_ section: String, appearsToAddress question: String) -> Bool {
        let lowerQuestion = question.lowercased()
        let lowerSection = section.lowercased()
        guard lowerSection.isEmpty == false else {
            return false
        }

        if lowerQuestion.contains("p/e")
            || lowerQuestion.contains("forward pe")
            || lowerQuestion.contains("valuation") {
            return lowerSection.contains("p/e")
                || lowerSection.contains("price-to-earnings")
                || lowerSection.contains("forward pe")
                || lowerSection.contains("forward p/e")
        }

        if lowerQuestion.contains("liquidity")
            || lowerQuestion.contains("cash")
            || lowerQuestion.contains("marketable securities")
            || lowerQuestion.contains("current assets") {
            return lowerSection.contains("cash")
                && (
                    lowerSection.contains("marketable")
                    || lowerSection.contains("current assets")
                    || lowerSection.contains("free cash flow")
                    || lowerSection.contains("long-term debt")
                    || lowerSection.contains("capex")
                    || lowerSection.contains("commitments")
                )
        }

        if lowerQuestion.contains("ai splash")
            || lowerQuestion.contains("product releases")
            || lowerQuestion.contains("release timing")
            || lowerQuestion.contains("rumors") {
            return lowerSection.contains("ai")
                && (
                    lowerSection.contains("product")
                    || lowerSection.contains("release")
                    || lowerSection.contains("catalyst")
                    || lowerSection.contains("splash")
                    || lowerSection.contains("rumor")
                    || lowerSection.contains("expectation")
                )
        }

        if lowerQuestion.contains("earnings") {
            return lowerSection.contains("earnings")
                || lowerSection.contains("results")
                || lowerSection.contains("reported")
        }

        if lowerQuestion.contains("conference")
            || lowerQuestion.contains("connect")
            || lowerQuestion.contains("conversations") {
            return lowerSection.contains("conference")
                || lowerSection.contains("connect")
                || lowerSection.contains("conversations")
                || lowerSection.contains("event")
        }

        let questionTokens = Set(
            lowerQuestion
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { token in
                    token.count >= 4
                        && Self.coverageStopWords.contains(token) == false
                }
        )
        guard questionTokens.isEmpty == false else {
            return false
        }
        let matched = questionTokens.filter { lowerSection.contains($0) }
        return matched.count >= min(4, max(2, questionTokens.count / 2))
    }

    private static let coverageStopWords: Set<String> = [
        "about", "after", "also", "analyst", "answer", "available", "current",
        "explicit", "explicitly", "including", "latest", "question", "research",
        "source", "status", "their", "there", "these", "timing", "whether",
        "with", "from", "what", "when", "where", "which"
    ]

    private func synthesisIntentLabel(_ taskIntent: LocalTaskIntent) -> String {
        switch taskIntent {
        case .synthesis:
            return "recommendation_ready_synthesis"
        case .recommendation:
            return "pm_recommendation"
        case .actionAdjacentReview:
            return "action_adjacent_review"
        case .recentNewsMaterialImpact:
            return "recent_news_material_impact"
        case .portfolioRiskTrigger:
            return "portfolio_risk_trigger"
        case .general:
            return "general_research"
        }
    }

    private func trimmedDocumentBody(_ body: String?, limit: Int) -> String? {
        guard let body else { return nil }
        let collapsed = body
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        if collapsed.count <= limit {
            return collapsed
        }
        return String(collapsed.prefix(limit)) + "..."
    }

    private func resolveCharter(
        from existingCharters: [AnalystCharter],
        requestedCharterID: String?,
        now: Date
    ) async throws -> (AnalystCharter, Bool) {
        if existingCharters.isEmpty {
            let seeded = try await seedStandingBench(now: now)
            if let requestedCharterID {
                guard let charter = seeded.first(where: { $0.charterId == requestedCharterID }) else {
                    throw AnalystWorkerSelectionError.cannotSeedRequestedCharter(
                        id: requestedCharterID,
                        seedCharterID: seeded.map(\.charterId).sorted().joined(separator: ", ")
                    )
                }
                return (charter, true)
            }
            throw AnalystWorkerSelectionError.ambiguousCharterSelection(
                availableCharterIDs: seeded.map(\.charterId).sorted()
            )
        }

        if let requestedCharterID {
            guard let charter = existingCharters.first(where: { $0.charterId == requestedCharterID }) else {
                throw AnalystWorkerSelectionError.charterNotFound(id: requestedCharterID)
            }
            return (charter, false)
        }

        if existingCharters.count == 1, let only = existingCharters.first {
            return (only, false)
        }

        throw AnalystWorkerSelectionError.ambiguousCharterSelection(
            availableCharterIDs: existingCharters
                .map(\.charterId)
                .sorted()
        )
    }

    private func seedStandingBench(now: Date) async throws -> [AnalystCharter] {
        var seeded: [AnalystCharter] = []
        for charter in standingBenchSeed.seededCharters(now: now) {
            seeded.append(try await client.upsertCharter(charter))
        }
        return seeded
    }

    private func resolveTask(
        requestedTaskID: String?,
        charter: AnalystCharter,
        now: Date
    ) async throws -> AnalystTask {
        let tasks = try await client.listTasks()
        if let requestedTaskID {
            if let existing = tasks.first(where: { $0.taskId == requestedTaskID }) {
                return existing
            }
            return makeDefaultTask(charter: charter, taskID: requestedTaskID, now: now)
        }

        let defaultTaskID = defaultTaskID(for: charter)
        if let existing = tasks.first(where: { $0.taskId == defaultTaskID }) {
            return existing
        }
        return makeDefaultTask(charter: charter, taskID: defaultTaskID, now: now)
    }

    private func makeEvidenceBundle(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        llmRuntimeOwnsPublicResearch: Bool,
        taskIntent: LocalTaskIntent,
        now: Date
    ) -> AnalystEvidenceBundle {
        let supplementalAssessments = assessSupplementalExternalEvidence(
            news: news,
            externalEvidence: externalEvidence
        )
        let supplementalRollup = summarizeSupplementalExternalEvidence(supplementalAssessments)
        var refs: [AnalystEvidenceRef] = []
        if news.isEmpty {
            let emptyScopeTitle: String
            let emptyScopeSummary: String
            if task.tags.contains("app_news_scope_empty") || isPMRequestedAdHocTask(task) {
                emptyScopeTitle = "No materially relevant app-news baseline items"
                emptyScopeSummary = "The reporting-window app-owned news feed returned no materially relevant items for this PM-requested ad hoc task; the analyst must continue with charter-governed public web research unless expressly restricted."
            } else {
                emptyScopeTitle = "No recent app news available"
                emptyScopeSummary = "The app-owned news store returned no recent items for the worker run."
            }
            refs.append(
                AnalystEvidenceRef(
                    refId: stableIdentifier(prefix: "ref", components: [charter.charterId, "no-news", DateCodec.formatISO8601(now)]),
                    sourceKind: .manualNote,
                    sourceIdentifier: "no_recent_app_news",
                    title: emptyScopeTitle,
                    observedAt: now,
                    summary: emptyScopeSummary
                )
            )
        } else {
            refs.append(contentsOf: news.prefix(5).map { event in
                AnalystEvidenceRef(
                    refId: stableIdentifier(prefix: "ref", components: [event.eventId]),
                    sourceKind: .appNews,
                    sourceIdentifier: event.source,
                    url: event.url,
                    appEntityID: event.eventId,
                    title: event.title,
                    observedAt: event.publishedAt,
                    summary: event.summary,
                    freshnessNote: "recent_app_news"
                )
            })
        }

        if let researchPlan,
           researchPlan.planSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let missingInfo = researchPlan.missingInformation.isEmpty
                ? "none recorded"
                : researchPlan.missingInformation.prefix(3).joined(separator: " | ")
            let targetedSources = researchPlan.publicTargets.isEmpty
                ? "no public web targets selected"
                : researchPlan.publicTargets.map(\.label).joined(separator: " | ")
            let sourceGaps = researchPlan.sourceGaps.isEmpty
                ? "no source gaps recorded"
                : researchPlan.sourceGaps.map(\.requestedSource).joined(separator: " | ")
            refs.append(
                AnalystEvidenceRef(
                    refId: stableIdentifier(prefix: "ref", components: [charter.charterId, task.taskId, "research-plan"]),
                    sourceKind: .manualNote,
                    sourceIdentifier: "missing_information_research_plan",
                    title: "Missing-information research plan",
                    observedAt: now,
                    summary: "\(researchPlan.planSummary) Missing information: \(missingInfo). Targeted public sources: \(targetedSources). Source gaps: \(sourceGaps)."
                )
            )
        }

        refs.append(contentsOf: supplementalAssessments.map { assessment in
            let document = assessment.document
            return AnalystEvidenceRef(
                refId: stableIdentifier(prefix: "ref", components: [document.sourceID, document.url]),
                sourceKind: .web,
                sourceIdentifier: document.sourceID,
                url: document.url,
                title: document.title,
                observedAt: document.observedAt,
                summary: compactExternalEvidenceRefSummary(
                    document: document,
                    assessment: assessment
                ),
                sourceQuality: 0.75,
                freshnessNote: "\(document.provenanceNote);source_tier=\(document.sourceTier.rawValue)"
            )
        })

        if !externalIssues.isEmpty {
            refs.append(
                AnalystEvidenceRef(
                    refId: stableIdentifier(
                        prefix: "ref",
                        components: [charter.charterId, task.taskId, "external-evidence-issue"]
                    ),
                    sourceKind: .manualNote,
                    sourceIdentifier: "external_evidence_diagnostic",
                    title: "External evidence degraded",
                    observedAt: now,
                    summary: externalEvidenceIssueSummary(externalIssues)
                        ?? "External evidence was unavailable for this worker run."
                )
            )
        }

        let bundleNotes: String
        if taskIntent == .recentNewsMaterialImpact {
            bundleNotes = "Worker-generated evidence bundle for recent normalized news and portfolio materiality review. App-owned news is the primary source for this specialization."
        } else if taskIntent == .portfolioRiskTrigger {
            bundleNotes = "Worker-generated evidence bundle for bounded portfolio-risk trigger review. App-owned portfolio state is the primary source for this specialization."
        } else if llmRuntimeOwnsPublicResearch {
            bundleNotes = "Worker-generated evidence bundle for analyst run-once flow with app-owned context first. The analyst LLM runtime owned public-web research directly during synthesis; no deterministic external-evidence fetcher capped or preselected the web source set. \(directLLMWebResearchRollup(newsCount: news.count))"
        } else if externalIssues.isEmpty {
            bundleNotes = "Worker-generated evidence bundle for analyst MVP run-once flow with app-owned news first and supplemental policy-governed external evidence. \(supplementalRollup)"
        } else {
            bundleNotes = "Worker-generated evidence bundle for analyst MVP run-once flow with app-owned news first and degraded supplemental external evidence: \(externalEvidenceIssueSummary(externalIssues) ?? "external_evidence_unavailable"). \(supplementalRollup)"
        }

        let bundleSummary: String
        if llmRuntimeOwnsPublicResearch {
            bundleSummary = "Worker provided \(news.count) relevant app-news baseline item(s) for \(charter.title); the analyst LLM runtime owned task-specific public-web research directly during synthesis. No deterministic external-evidence fetcher capped or preselected the web source set."
        } else {
            bundleSummary = "Worker reviewed \(news.count) app-news baseline item(s), identified \(researchPlan?.missingInformation.count ?? 0) missing-information line(s), and reviewed \(externalEvidence.count) supplemental policy-governed external source(s) for \(charter.title). \(supplementalRollup)"
        }

        return AnalystEvidenceBundle(
            bundleId: stableHashedIdentifier(
                prefix: "bundle",
                components: [charter.charterId] + refs.map(\.refId)
            ),
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: task.taskId,
            refs: refs,
            summary: bundleSummary,
            notes: bundleNotes,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeFinding(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        taskIntent: LocalTaskIntent,
        bundleId: String,
        synthesized: AnalystOpenAISynthesisOutput?,
        now: Date
    ) -> AnalystFinding {
        var finding = makeLocalFinding(
            charter: charter,
            task: task,
            news: news,
            externalEvidence: externalEvidence,
            externalIssues: externalIssues,
            taskIntent: taskIntent,
            bundleId: bundleId,
            now: now
        )
        guard let synthesized else {
            return finding
        }

        finding.title = synthesized.findingTitle
        finding.summary = synthesized.findingSummary
        finding.thesis = synthesized.findingThesis
        if let timeHorizon = synthesized.findingTimeHorizon,
           !timeHorizon.isEmpty {
            finding.timeHorizon = timeHorizon
        }
        finding.confidence = synthesized.findingConfidence
        let mergedSymbols = Array(Set((finding.symbols + synthesized.suggestedSymbols).map { $0.uppercased() })).sorted()
        if !mergedSymbols.isEmpty {
            finding.symbols = Array(mergedSymbols.prefix(8))
        }
        let mergedTags = Array(Set(finding.tags + synthesized.suggestedTags)).sorted()
        if !mergedTags.isEmpty {
            finding.tags = Array(mergedTags.prefix(10))
        }
        return finding
    }

    private func makeLocalFinding(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        taskIntent: LocalTaskIntent,
        bundleId: String,
        now: Date
    ) -> AnalystFinding {
        if taskIntent == .recentNewsMaterialImpact {
            return makeRecentNewsMaterialImpactFinding(
                charter: charter,
                task: task,
                news: news,
                externalIssues: externalIssues,
                bundleId: bundleId,
                now: now
            )
        }
        if taskIntent == .portfolioRiskTrigger {
            return makePortfolioRiskTriggerFinding(
                charter: charter,
                task: task,
                externalIssues: externalIssues,
                bundleId: bundleId,
                now: now
            )
        }

        let symbols = Array(Set(task.symbols + news.flatMap(\.rawSymbolHints))).sorted().prefix(6)
        let tags = Array(Set(["analyst_mvp", "tech", "technology_adoption", "external_evidence"] + news.flatMap(\.tags))).sorted()
        let count = news.count
        let confidence = min(0.82, 0.3 + (Double(min(count, 4)) * 0.08) + (Double(min(externalEvidence.count, 2)) * 0.12))
        let latestHeadline = news.first?.title
            ?? "No recent app news available"
        let supplementalAssessments = assessSupplementalExternalEvidence(
            news: news,
            externalEvidence: externalEvidence
        )
        let supplementalRollup = summarizeSupplementalExternalEvidence(supplementalAssessments)
        let externalText = externalEvidence
            .map { "\($0.title) \($0.summary) \($0.snippet)" }
            .joined(separator: " ")
            .lowercased()
        let internalText = news
            .map { "\($0.title) \($0.summary ?? "")" }
            .joined(separator: " ")
            .lowercased()
        let combined = "\(internalText) \(externalText)"
        let frictionKeywords = ["constraint", "constraints", "delay", "lag", "bottleneck", "power", "integration", "regulation", "shortage", "monetization"]
        let supportKeywords = ["adoption", "deployment", "growth", "demand", "revenue", "investment", "productivity", "buildout", "accelerat"]
        let frictionHits = frictionKeywords.filter { combined.contains($0) }
        let supportHits = supportKeywords.filter { combined.contains($0) }
        let scenarioVerdict: String
        if frictionHits.count > supportHits.count {
            scenarioVerdict = "delay_or_reshape"
        } else if supportHits.count > frictionHits.count {
            scenarioVerdict = "support_with_timing_risk"
        } else {
            scenarioVerdict = "mixed_or_uncertain"
        }
        let summary: String
        let thesis: String

        if news.isEmpty && externalEvidence.isEmpty {
            summary = "No app-owned news or policy-governed external evidence was available for \(charter.title). This finding records the absence of fresh evidence and keeps the thesis in monitor mode."
            thesis = "Without internal or policy-governed external evidence, the current charter thesis remains unconfirmed and should stay in watch mode."
        } else {
            summary = "\(count) recent app news item(s) formed the baseline evidence set for \(charter.title). \(supplementalRollup) Latest app headline: \(latestHeadline)."
            switch scenarioVerdict {
            case "delay_or_reshape":
                thesis = "Combined app-owned and external evidence suggests the thesis is being delayed or reshaped by adoption friction. Supporting evidence exists, but disconfirming pressure from timing mismatches, infrastructure, policy, or monetization constraints remains material."
            case "support_with_timing_risk":
                thesis = "Combined app-owned and external evidence currently supports the charter thesis, but timing uncertainty remains high. The thesis should be treated as provisional and explicitly tested against disconfirming evidence on adoption, integration, power, and monetization."
            default:
                thesis = "Combined app-owned and external evidence is mixed. The thesis should be treated as a scenario under test, with both support and disconfirming timing friction tracked explicitly rather than assumed resolved."
            }
        }

        let uncertaintyTag = scenarioVerdict == "delay_or_reshape" ? "timing_friction" : "timing_uncertainty"
        let issueSummary = externalEvidenceIssueSummary(externalIssues)
        let degradedSuffix = issueSummary.map { " External evidence degraded: \($0)." } ?? ""

        return AnalystFinding(
            findingId: stableHashedIdentifier(
                prefix: "finding",
                components: [charter.charterId, bundleId, DateCodec.formatISO8601(now)]
            ),
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: task.taskId,
            title: news.isEmpty
                ? "Technology adoption monitor: external evidence review"
                : "Technology adoption monitor: \(latestHeadline)",
            summary: "\(summary)\(degradedSuffix)",
            thesis: "\(thesis) App-owned news remained the baseline evidence set. Supplemental external evidence reviewed: \(externalEvidence.count) source(s). \(supplementalRollup) Scenario verdict: \(scenarioVerdict).\((issueSummary.map { " External evidence degraded: \($0)." }) ?? "")",
            symbols: Array(symbols),
            tags: tags + [uncertaintyTag],
            status: .open,
            confidence: confidence,
            timeHorizon: "swing",
            evidenceBundleId: bundleId,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeUpdatedTask(
        existingTask: AnalystTask,
        charter: AnalystCharter,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        llmRuntimeOwnsPublicResearch: Bool,
        taskIntent: LocalTaskIntent,
        bundleId: String,
        findingId: String,
        now: Date
    ) -> AnalystTask {
        if taskIntent == .recentNewsMaterialImpact {
            return makeRecentNewsMaterialImpactTaskUpdate(
                existingTask: existingTask,
                charter: charter,
                news: news,
                externalIssues: externalIssues,
                bundleId: bundleId,
                findingId: findingId,
                now: now
            )
        }
        if taskIntent == .portfolioRiskTrigger {
            return makePortfolioRiskTriggerTaskUpdate(
                existingTask: existingTask,
                charter: charter,
                externalIssues: externalIssues,
                bundleId: bundleId,
                findingId: findingId,
                now: now
            )
        }

        let symbols = Array(Set(existingTask.symbols + news.flatMap(\.rawSymbolHints))).sorted().prefix(8)
        let latestHeadline = news.first?.title ?? "no recent app news"
        let supplementalAssessments = assessSupplementalExternalEvidence(
            news: news,
            externalEvidence: externalEvidence
        )
        let supplementalRollup = summarizeSupplementalExternalEvidence(supplementalAssessments)
        let issueSuffix = externalEvidenceIssueSummary(externalIssues).map { " External evidence degraded: \($0)." } ?? ""
        let summary: String
        if llmRuntimeOwnsPublicResearch {
            summary = "Provided \(news.count) relevant app-news baseline item(s) to the analyst LLM; direct task-specific public-web research ran inside synthesis rather than through a deterministic external-evidence fetcher. Latest app evidence: \(latestHeadline).\(issueSuffix)"
        } else {
            summary = "Reviewed \(news.count) app-news baseline item(s) and \(externalEvidence.count) supplemental policy-governed external source(s). Latest app evidence: \(latestHeadline). \(supplementalRollup)\(issueSuffix)"
        }

        var task = existingTask
        task.analystId = charter.analystId
        task.charterId = charter.charterId
        if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.title = "\(charter.title) ongoing research"
        }
        if task.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.description = "Durable long-horizon analyst task for repeated evidence review under \(charter.title)."
        }
        let pmRequestedAdHoc = isPMRequestedAdHocTask(existingTask)
        task.status = pmRequestedAdHoc ? .completed : .inProgress
        task.symbols = Array(symbols)
        let lifecycleTags = pmRequestedAdHoc
            ? ["ad_hoc", "pm_requested", "checkpointed"]
            : ["analyst_long_horizon", "checkpointed"]
        task.tags = Array(Set(task.tags + lifecycleTags)).sorted()
        task.linkedFindingIDs = Array(Set(task.linkedFindingIDs + [findingId])).sorted()
        task.checkpoint = AnalystTaskCheckpoint(
            checkpointID: task.checkpoint?.checkpointID ?? stableIdentifier(prefix: "checkpoint", components: [task.taskId]),
            taskId: task.taskId,
            analystId: charter.analystId,
            charterId: charter.charterId,
            summary: summary,
            nextPlannedAction: pmRequestedAdHoc
                ? "Deliver the completed ad hoc analyst memo back to the originating PM/User conversation; rerun only if the owner explicitly asks for follow-up coverage."
                : (externalEvidence.isEmpty
                    ? "Refresh internal news and add another policy-governed external source before escalating the thesis."
                    : "Re-run against the next news cycle and test for disconfirming evidence that changes the timing view."),
            openQuestions: researchPlan?.researchQuestions.isEmpty == false
                ? Array((researchPlan?.researchQuestions ?? []).prefix(AnalystTaskQuestionChecklist.maxQuestionCount))
                : [
                    "Are current adoption frictions delaying monetization or only changing sequencing?",
                    "What new evidence would materially refute the current scenario verdict?"
                ],
            linkedFindingIDs: task.linkedFindingIDs,
            linkedEvidenceBundleIDs: Array(Set((task.checkpoint?.linkedEvidenceBundleIDs ?? []) + [bundleId])).sorted(),
            updatedAt: now
        )
        task.lastCheckpointSummary = task.checkpoint?.summary
        return task
    }

    private func makeMemo(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        bundle: AnalystEvidenceBundle,
        finding: AnalystFinding,
        taskIntent: LocalTaskIntent,
        memoStyle: LocalMemoStyle,
        runtimeProvenance: AnalystRuntimeProvenance?,
        delegationID: String?,
        pmID: String?,
        synthesized: AnalystOpenAISynthesisOutput?,
        now: Date
    ) -> AnalystMemo {
        var memo = makeLocalMemo(
            charter: charter,
            task: task,
            news: news,
            researchPlan: researchPlan,
            externalEvidence: externalEvidence,
            externalIssues: externalIssues,
            bundle: bundle,
            finding: finding,
            taskIntent: taskIntent,
            memoStyle: memoStyle,
            runtimeProvenance: runtimeProvenance,
            delegationID: delegationID,
            pmID: pmID,
            now: now
        )
        memo.questionCoverage = makeQuestionCoverage(
            for: task,
            researchPlan: researchPlan,
            synthesized: synthesized,
            externalEvidence: externalEvidence,
            externalIssues: externalIssues
        )
        guard let synthesized else {
            return memo
        }

        memo.title = synthesized.memoTitle
        memo.executiveSummary = synthesized.memoExecutiveSummary
        memo.currentView = synthesized.memoCurrentView
        memo.evidenceSummary = synthesized.memoEvidenceSummary
        memo.uncertaintySummary = synthesized.memoUncertaintySummary
        memo.recommendedNextStep = synthesized.memoRecommendedNextStep
        memo.questionCoverage = makeQuestionCoverage(
            for: task,
            researchPlan: researchPlan,
            synthesized: synthesized,
            externalEvidence: externalEvidence,
            externalIssues: externalIssues
        )
        memo.confidence = finding.confidence
        let selectedSkills = task.contextPack?.referencedSkills ?? []
        memo.skillUsageSummaries = synthesized.skillUsageSummaries.isEmpty
            ? makeFallbackAgentSkillUsageSummaries(from: task.contextPack?.referencedSkills ?? [])
            : enrichedAgentSkillUsageSummaries(synthesized.skillUsageSummaries, selectedSkills: selectedSkills)
        return memo
    }

    private func makeLocalMemo(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalIssues: [AnalystExternalEvidenceIssue],
        bundle: AnalystEvidenceBundle,
        finding: AnalystFinding,
        taskIntent: LocalTaskIntent,
        memoStyle: LocalMemoStyle,
        runtimeProvenance: AnalystRuntimeProvenance?,
        delegationID: String?,
        pmID: String?,
        now: Date
    ) -> AnalystMemo {
        let externalIssueText = externalEvidenceIssueSummary(externalIssues)
        let topHeadline = news.first?.title ?? "No fresh app news was available"
        let externalAnchor = externalEvidence.first?.title
        let confidencePercent = Int((finding.confidence * 100).rounded())
        let recentNewsContext = recentNewsTaskContext(from: task)
        let portfolioRiskContext = portfolioRiskTaskContext(from: task)

        let executiveSummary = makeMemoExecutiveSummary(
            finding: finding,
            taskIntent: taskIntent,
            memoStyle: memoStyle,
            externalIssueText: externalIssueText,
            recentNewsContext: recentNewsContext,
            portfolioRiskContext: portfolioRiskContext
        )

        return AnalystMemo(
            memoId: stableHashedIdentifier(prefix: "memo", components: [finding.findingId]),
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: task.taskId,
            delegationId: delegationID,
            pmId: pmID,
            findingId: finding.findingId,
            evidenceBundleId: bundle.bundleId,
            title: finding.title,
            executiveSummary: executiveSummary,
            currentView: makeMemoCurrentView(
                finding: finding,
                taskIntent: taskIntent,
                confidencePercent: confidencePercent,
                memoStyle: memoStyle,
                recentNewsContext: recentNewsContext,
                portfolioRiskContext: portfolioRiskContext
            ),
            evidenceSummary: makeMemoEvidenceSummary(
                news: news,
                researchPlan: researchPlan,
                externalEvidence: externalEvidence,
                externalAnchor: externalAnchor,
                latestHeadline: topHeadline,
                taskIntent: taskIntent,
                memoStyle: memoStyle,
                recentNewsContext: recentNewsContext,
                portfolioRiskContext: portfolioRiskContext
            ),
            uncertaintySummary: makeMemoUncertaintySummary(
                finding: finding,
                externalIssueText: externalIssueText,
                externalEvidenceCount: externalEvidence.count,
                taskIntent: taskIntent,
                memoStyle: memoStyle,
                recentNewsContext: recentNewsContext,
                portfolioRiskContext: portfolioRiskContext
            ),
            recommendedNextStep: makeMemoRecommendedNextStep(
                finding: finding,
                externalIssueText: externalIssueText,
                externalEvidenceCount: externalEvidence.count,
                taskIntent: taskIntent,
                memoStyle: memoStyle,
                recentNewsContext: recentNewsContext,
                portfolioRiskContext: portfolioRiskContext
            ),
            confidence: finding.confidence,
            runtimeProvenance: runtimeProvenance,
            skillUsageSummaries: makeFallbackAgentSkillUsageSummaries(
                from: task.contextPack?.referencedSkills ?? []
            ),
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeFallbackAgentSkillUsageSummaries(
        from skills: [AgentSkillContextItem]
    ) -> [AgentSkillUsageSummary] {
        skills.prefix(8).map { skill in
            let usage: AgentSkillUsage
            let summary: String
            switch skill.availability {
            case .active:
                usage = skill.requirement == .required ? .considered : .considered
                summary = "\(skill.title) was supplied as \(skill.requirement.displayTitle.lowercased()) methodology guidance; the local fallback path did not receive provider-specific skill-use detail."
            case .archived:
                usage = .blockedByHigherPriorityPolicy
                summary = "\(skill.title) is archived, so the analyst did not apply its body as live methodology guidance."
            case .missing:
                usage = .blockedByHigherPriorityPolicy
                summary = "Referenced skill \(skill.skillId) is missing, so the analyst could not apply it."
            }
            return AgentSkillUsageSummary(
                skillId: skill.skillId,
                skillTitle: skill.title,
                requirement: skill.requirement,
                usage: usage,
                usageSummary: summary,
                skillUpdatedAt: skill.skillUpdatedAt,
                referenceSources: skill.referenceSources
            )
        }
    }

    private func enrichedAgentSkillUsageSummaries(
        _ summaries: [AgentSkillUsageSummary],
        selectedSkills: [AgentSkillContextItem]
    ) -> [AgentSkillUsageSummary] {
        let selectedByID = Dictionary(uniqueKeysWithValues: selectedSkills.map { ($0.skillId, $0) })
        return summaries.prefix(8).map { summary in
            guard let selected = selectedByID[summary.skillId] else { return summary }
            return AgentSkillUsageSummary(
                skillId: summary.skillId,
                skillTitle: summary.skillTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? selected.title
                    : summary.skillTitle,
                requirement: selected.requirement,
                usage: summary.usage,
                usageSummary: summary.usageSummary,
                skillUpdatedAt: summary.skillUpdatedAt ?? selected.skillUpdatedAt,
                referenceSources: summary.referenceSources.isEmpty ? selected.referenceSources : summary.referenceSources
            )
        }
    }

    private func memoProfileLead(for memoStyle: LocalMemoStyle) -> String {
        switch memoStyle {
        case .concise:
            return "Bottom line:"
        case .balanced:
            return "Current read:"
        case .deep:
            return "Working conclusion:"
        }
    }

    private func inferTaskIntent(from task: AnalystTask) -> LocalTaskIntent {
        let combined = [
            task.title,
            task.description,
            task.tags.joined(separator: " "),
            makePMTaskingBriefBody(task.pmTaskingBrief)
        ]
        .joined(separator: " ")
        .lowercased()

        if combined.contains("recent-news-analyst") || combined.contains("portfolio-material-impact") || combined.contains("recent news materiality") {
            return .recentNewsMaterialImpact
        }
        if combined.contains("portfolio-risk-trigger") || combined.contains("portfolio risk trigger") || combined.contains("portfolio risk review") {
            return .portfolioRiskTrigger
        }
        if combined.contains("recommendation-ready synthesis") {
            return .recommendation
        }
        if combined.contains("task-recommendation") || combined.contains("recommendation") || combined.contains("should the pm") || combined.contains("what should the pm do") {
            return .recommendation
        }
        if combined.contains("risk view") || combined.contains("escalation-only conclusion") {
            return .actionAdjacentReview
        }
        if combined.contains("task-action-adjacent") || combined.contains("action-adjacent") || combined.contains("review readiness") {
            return .actionAdjacentReview
        }
        if combined.contains("competing-case comparison") || combined.contains("evidence-backed answer") || combined.contains("revised take") {
            return .synthesis
        }
        if combined.contains("task-synthesis") || combined.contains("synthesis") || combined.contains("synthesize") || combined.contains("watch memo") {
            return .synthesis
        }
        return .general
    }

    private func makeMemoExecutiveSummary(
        finding: AnalystFinding,
        taskIntent: LocalTaskIntent,
        memoStyle: LocalMemoStyle,
        externalIssueText: String?,
        recentNewsContext: RecentNewsTaskContext?,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        if taskIntent == .recentNewsMaterialImpact {
            return makeRecentNewsMemoExecutiveSummary(
                finding: finding,
                memoStyle: memoStyle,
                recentNewsContext: recentNewsContext
            )
        }
        if taskIntent == .portfolioRiskTrigger {
            return makePortfolioRiskMemoExecutiveSummary(
                finding: finding,
                memoStyle: memoStyle,
                portfolioRiskContext: portfolioRiskContext
            )
        }

        let lead = memoProfileLead(for: memoStyle)
        let thesisLead = leadingSentence(in: finding.thesis)
        let summaryContext = droppingExternalDegradedSuffix(from: finding.summary)
        let boundedEvidenceText: String
        if let externalIssueText, !externalIssueText.isEmpty {
            boundedEvidenceText = " External evidence was only partially available, so this memo leans more heavily on app-owned evidence and keeps confidence bounded."
        } else {
            boundedEvidenceText = ""
        }

        let intentPrefix: String
        switch taskIntent {
        case .synthesis:
            intentPrefix = "This synthesis memo distills the current analyst read."
        case .recommendation:
            intentPrefix = "This recommendation memo translates the analyst read into a PM-usable next step."
        case .actionAdjacentReview:
            intentPrefix = "This review-readiness memo explains whether the current evidence is strong enough for PM-layer owner review."
        case .recentNewsMaterialImpact:
            intentPrefix = "This recent-news memo translates the current news cluster into a bounded PM materiality review."
        case .portfolioRiskTrigger:
            intentPrefix = "This portfolio-risk memo translates bounded trigger conditions into a PM-usable overlay review."
        case .general:
            intentPrefix = "This analyst memo captures the current working read."
        }

        return "\(lead) \(thesisLead) \(intentPrefix) \(summaryContext)\(boundedEvidenceText)"
    }

    private func makeMemoCurrentView(
        finding: AnalystFinding,
        taskIntent: LocalTaskIntent,
        confidencePercent: Int,
        memoStyle: LocalMemoStyle,
        recentNewsContext: RecentNewsTaskContext?,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        if taskIntent == .recentNewsMaterialImpact {
            return makeRecentNewsMemoCurrentView(
                finding: finding,
                confidencePercent: confidencePercent,
                recentNewsContext: recentNewsContext
            )
        }
        if taskIntent == .portfolioRiskTrigger {
            return makePortfolioRiskMemoCurrentView(
                finding: finding,
                confidencePercent: confidencePercent,
                portfolioRiskContext: portfolioRiskContext
            )
        }

        let thesisLead = leadingSentence(in: finding.thesis)
        let confidenceLine: String
        switch memoStyle {
        case .concise:
            confidenceLine = "Confidence is \(confidencePercent) percent and remains provisional."
        case .balanced:
            confidenceLine = "Confidence is currently \(confidencePercent) percent."
        case .deep:
            confidenceLine = "Confidence is currently \(confidencePercent) percent, and the memo keeps disconfirming timing evidence in scope before escalation."
        }

        switch taskIntent {
        case .synthesis:
            return "\(thesisLead) \(confidenceLine) The current goal is to summarize the state of evidence rather than force an immediate action."
        case .recommendation:
            return "\(thesisLead) \(confidenceLine) The current goal is to help the PM decide whether to keep monitoring, escalate, or wait for another evidence cycle."
        case .actionAdjacentReview:
            return "\(thesisLead) \(confidenceLine) The current goal is to judge whether the evidence is strong enough for owner-facing PM review without implying execution authority."
        case .recentNewsMaterialImpact:
            return "\(thesisLead) \(confidenceLine) The current goal is to show whether the recent-news cluster warrants bounded PM attention for current holdings or watch context."
        case .portfolioRiskTrigger:
            return "\(thesisLead) \(confidenceLine) The current goal is to show whether bounded portfolio-risk trigger conditions warrant PM attention without implying execution authority."
        case .general:
            return "\(thesisLead) \(confidenceLine)"
        }
    }

    private func makeMemoEvidenceSummary(
        news: [NewsEvent],
        researchPlan: AnalystResearchPlan?,
        externalEvidence: [ExternalAnalystEvidenceDocument],
        externalAnchor: String?,
        latestHeadline: String,
        taskIntent: LocalTaskIntent,
        memoStyle: LocalMemoStyle,
        recentNewsContext: RecentNewsTaskContext?,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        if taskIntent == .recentNewsMaterialImpact {
            return makeRecentNewsMemoEvidenceSummary(
                news: news,
                latestHeadline: latestHeadline,
                recentNewsContext: recentNewsContext
            )
        }
        if taskIntent == .portfolioRiskTrigger {
            return makePortfolioRiskMemoEvidenceSummary(
                news: news,
                portfolioRiskContext: portfolioRiskContext,
                latestHeadline: latestHeadline
            )
        }

        let base = makeEvidenceSummary(
            news: news,
            researchPlan: researchPlan,
            externalEvidence: externalEvidence,
            externalAnchor: externalAnchor,
            latestHeadline: latestHeadline
        )
        switch memoStyle {
        case .concise:
            break
        case .balanced:
            return "\(base) \(evidenceIntentSuffix(taskIntent)) The memo keeps app-owned news as the primary anchor unless policy-governed external evidence adds a stronger timing signal."
        case .deep:
            return "\(base) \(evidenceIntentSuffix(taskIntent)) The memo weighs internal news flow against policy-governed external anchors to separate adoption support from timing-friction evidence."
        }
        return "\(base) \(evidenceIntentSuffix(taskIntent))"
    }

    private func makeMemoUncertaintySummary(
        finding: AnalystFinding,
        externalIssueText: String?,
        externalEvidenceCount: Int,
        taskIntent: LocalTaskIntent,
        memoStyle: LocalMemoStyle,
        recentNewsContext: RecentNewsTaskContext?,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        if taskIntent == .recentNewsMaterialImpact {
            return makeRecentNewsMemoUncertaintySummary(
                finding: finding,
                recentNewsContext: recentNewsContext
            )
        }
        if taskIntent == .portfolioRiskTrigger {
            return makePortfolioRiskMemoUncertaintySummary(
                finding: finding,
                portfolioRiskContext: portfolioRiskContext
            )
        }

        let base = makeUncertaintySummary(
            finding: finding,
            externalIssueText: externalIssueText,
            externalEvidenceCount: externalEvidenceCount
        )
        switch memoStyle {
        case .concise:
            break
        case .balanced:
            return "\(base) \(uncertaintyIntentSuffix(taskIntent))"
        case .deep:
            return "\(base) \(uncertaintyIntentSuffix(taskIntent)) The memo treats disconfirming evidence and timing friction as live factors that can still overturn the working view."
        }
        return "\(base) \(uncertaintyIntentSuffix(taskIntent))"
    }

    private func makeMemoRecommendedNextStep(
        finding: AnalystFinding,
        externalIssueText: String?,
        externalEvidenceCount: Int,
        taskIntent: LocalTaskIntent,
        memoStyle: LocalMemoStyle,
        recentNewsContext: RecentNewsTaskContext?,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        if taskIntent == .recentNewsMaterialImpact {
            return makeRecentNewsMemoRecommendedNextStep(
                finding: finding,
                recentNewsContext: recentNewsContext
            )
        }
        if taskIntent == .portfolioRiskTrigger {
            return makePortfolioRiskMemoRecommendedNextStep(
                finding: finding,
                portfolioRiskContext: portfolioRiskContext
            )
        }

        let base = makeRecommendedNextStep(
            finding: finding,
            externalIssueText: externalIssueText,
            externalEvidenceCount: externalEvidenceCount
        )
        switch memoStyle {
        case .concise:
            break
        case .balanced:
            return "\(base) \(recommendedNextStepSuffix(taskIntent))"
        case .deep:
            return "\(base) \(recommendedNextStepSuffix(taskIntent)) If the PM wants escalation, compare this memo against a follow-up run with a different runtime profile before moving to a decision or request."
        }
        return "\(base) \(recommendedNextStepSuffix(taskIntent))"
    }

    private func evidenceIntentSuffix(_ taskIntent: LocalTaskIntent) -> String {
        switch taskIntent {
        case .synthesis:
            return "It is organized to help the PM absorb the current state of evidence quickly."
        case .recommendation:
            return "It is organized to support a recommendation rather than a raw evidence dump."
        case .actionAdjacentReview:
            return "It is organized to show whether there is enough support for a PM-layer owner review step."
        case .recentNewsMaterialImpact:
            return "It is organized to show why the recent-news cluster may matter for the current portfolio."
        case .portfolioRiskTrigger:
            return "It is organized to show why bounded portfolio-risk trigger conditions may matter for the current portfolio."
        case .general:
            return "It is organized to keep the analyst read readable for PM review."
        }
    }

    private func uncertaintyIntentSuffix(_ taskIntent: LocalTaskIntent) -> String {
        switch taskIntent {
        case .synthesis:
            return "This remains a synthesis memo rather than an instruction to act."
        case .recommendation:
            return "Any recommendation here is still bounded by unresolved uncertainty and separate PM/trading gates."
        case .actionAdjacentReview:
            return "Review readiness is still bounded by uncertainty and does not imply proposal or trade approval."
        case .recentNewsMaterialImpact:
            return "This remains a PM-layer materiality review and does not imply trading, proposal approval, or owner action by itself."
        case .portfolioRiskTrigger:
            return "This remains a PM-layer portfolio-risk review and does not imply trading, proposal approval, or owner action by itself."
        case .general:
            return "This remains a PM-reviewable research artifact rather than an execution-ready instruction."
        }
    }

    private func recommendedNextStepSuffix(_ taskIntent: LocalTaskIntent) -> String {
        switch taskIntent {
        case .synthesis:
            return "Use the memo to keep the PM informed about the state of the thesis rather than to force a binary call."
        case .recommendation:
            return "If the PM agrees, convert the memo into a bounded PM decision or approval request rather than treating it as execution authority."
        case .actionAdjacentReview:
            return "If this is escalated, the next step should be PM-layer owner review rather than any execution change."
        case .recentNewsMaterialImpact:
            return "If the PM agrees this looks material, the next step is bounded PM review and follow-up, not direct execution."
        case .portfolioRiskTrigger:
            return "If the PM agrees this looks material, the next step is bounded PM review and follow-up, not direct execution."
        case .general:
            return "Keep the memo in PM review before taking any downstream drafting step."
        }
    }

    private func recentNewsTaskContext(from task: AnalystTask) -> RecentNewsTaskContext? {
        let legacy = recentNewsTaskContextFromDescription(task.description)
        guard let contextPack = task.contextPack else {
            return legacy
        }

        let impactedSymbols = Set(task.symbols.map { $0.uppercased() })
        let heldPositions = contextPack.sharedCurrentTruth.positions.filter { position in
            impactedSymbols.isEmpty || impactedSymbols.contains(position.symbol.uppercased())
        }
        let heldSummary = heldPositions.isEmpty ? legacy?.heldPositionsSummary : heldPositions
            .map { "\($0.symbol) \($0.directionLabel) qty \($0.quantity) market value \($0.marketValue)" }
            .joined(separator: "; ")

        let heldSymbolSet = Set(heldPositions.map { $0.symbol.uppercased() })
        let watchlistOnly = contextPack.sharedCurrentTruth.watchlistSymbols
            .map { $0.uppercased() }
            .filter { symbol in
                (impactedSymbols.isEmpty || impactedSymbols.contains(symbol)) && heldSymbolSet.contains(symbol) == false
            }
        let watchlistSummary = watchlistOnly.isEmpty ? legacy?.watchlistSummary : watchlistOnly.joined(separator: ", ")

        let strategyBrief = contextPack.sharedCurrentTruth.portfolioStrategyBrief
        let triggeringNews = contextPack.sharedCurrentTruth.recentNews.filter { item in
            impactedSymbols.isEmpty || Set(item.symbolHints.map { $0.uppercased() }).isDisjoint(with: impactedSymbols) == false
        }
        let triggeringNewsSummary = triggeringNews.isEmpty ? legacy?.triggeringNewsSummary : triggeringNews
            .prefix(4)
            .map { "[\($0.source.replacingOccurrences(of: "_", with: " ").capitalized)] \($0.title)" }
            .joined(separator: " | ")

        let scopedMemory = contextPack.scopedMemory
        let merged = RecentNewsTaskContext(
            heldPositionsSummary: heldSummary,
            watchlistSummary: watchlistSummary,
            strategyObjective: strategyBrief?.objectiveSummary ?? legacy?.strategyObjective,
            strategyThemes: strategyBrief?.keyThemes.isEmpty == false
                ? strategyBrief?.keyThemes.joined(separator: "; ")
                : legacy?.strategyThemes,
            riskPosture: strategyBrief?.currentRiskPosture ?? legacy?.riskPosture,
            materialDevelopments: strategyBrief?.materialDevelopments.isEmpty == false
                ? strategyBrief?.materialDevelopments.joined(separator: "; ")
                : legacy?.materialDevelopments,
            nonMaterialDevelopments: strategyBrief?.nonMaterialDevelopments.isEmpty == false
                ? strategyBrief?.nonMaterialDevelopments.joined(separator: "; ")
                : legacy?.nonMaterialDevelopments,
            reviewPosture: strategyBrief?.reviewEscalationPosture ?? legacy?.reviewPosture,
            coveragePosture: legacy?.coveragePosture,
            clusteredEventView: legacy?.clusteredEventView,
            escalationPosture: legacy?.escalationPosture,
            whyNowSummary: legacy?.whyNowSummary,
            bookPostureSummary: legacy?.bookPostureSummary,
            materialityTrigger: legacy?.materialityTrigger ?? leadingSentence(in: task.description),
            triggeringNewsSummary: triggeringNewsSummary,
            scopedMemorySymbols: scopedMemory?.trackedSymbols.isEmpty == false
                ? scopedMemory?.trackedSymbols.joined(separator: ", ")
                : nil,
            scopedMemoryThemes: scopedMemory?.trackedThemes.isEmpty == false
                ? scopedMemory?.trackedThemes.joined(separator: "; ")
                : nil,
            scopedMemoryOpenQuestions: scopedMemory?.openQuestions.isEmpty == false
                ? scopedMemory?.openQuestions.joined(separator: " | ")
                : nil
        )

        if merged.heldPositionsSummary == nil,
           merged.watchlistSummary == nil,
           merged.strategyObjective == nil,
           merged.strategyThemes == nil,
           merged.riskPosture == nil,
           merged.materialDevelopments == nil,
           merged.nonMaterialDevelopments == nil,
           merged.reviewPosture == nil,
           merged.coveragePosture == nil,
           merged.clusteredEventView == nil,
           merged.escalationPosture == nil,
           merged.whyNowSummary == nil,
           merged.bookPostureSummary == nil,
           merged.materialityTrigger == nil,
           merged.triggeringNewsSummary == nil,
           merged.scopedMemorySymbols == nil,
           merged.scopedMemoryThemes == nil,
           merged.scopedMemoryOpenQuestions == nil {
            return nil
        }
        return merged
    }

    private func recentNewsTaskContextFromDescription(_ description: String) -> RecentNewsTaskContext? {
        let held = taskContextValue(prefix: "Held positions in scope:", from: description)
        let watchlist = taskContextValue(prefix: "Watchlist context:", from: description)
        let strategyObjective = taskContextValue(prefix: "Portfolio strategy brief objective:", from: description)
        let strategyThemes = taskContextValue(prefix: "Strategy themes:", from: description)
        let riskPosture = taskContextValue(prefix: "Current risk posture:", from: description)
        let materialDevelopments = taskContextValue(prefix: "Material developments:", from: description)
        let nonMaterialDevelopments = taskContextValue(prefix: "Usually not material:", from: description)
        let reviewPosture = taskContextValue(prefix: "Review posture:", from: description)
        let coveragePosture = taskContextValue(prefix: "Coverage posture:", from: description)
        let clusteredEventView = taskContextValue(prefix: "Clustered event view:", from: description)
        let escalationPosture = taskContextValue(prefix: "Escalation posture:", from: description)
        let whyNowSummary = taskContextValue(prefix: "Why now:", from: description)
        let bookPostureSummary = taskContextValue(prefix: "Current book posture:", from: description)
        let trigger = taskContextValue(prefix: "Materiality trigger:", from: description)
        let news = taskContextValue(prefix: "Triggering news:", from: description)

        if held == nil,
           watchlist == nil,
           strategyObjective == nil,
           strategyThemes == nil,
           riskPosture == nil,
           materialDevelopments == nil,
           nonMaterialDevelopments == nil,
           reviewPosture == nil,
           coveragePosture == nil,
           clusteredEventView == nil,
           escalationPosture == nil,
           whyNowSummary == nil,
           bookPostureSummary == nil,
           trigger == nil,
           news == nil {
            return nil
        }

        return RecentNewsTaskContext(
            heldPositionsSummary: held,
            watchlistSummary: watchlist,
            strategyObjective: strategyObjective,
            strategyThemes: strategyThemes,
            riskPosture: riskPosture,
            materialDevelopments: materialDevelopments,
            nonMaterialDevelopments: nonMaterialDevelopments,
            reviewPosture: reviewPosture,
            coveragePosture: coveragePosture,
            clusteredEventView: clusteredEventView,
            escalationPosture: escalationPosture,
            whyNowSummary: whyNowSummary,
            bookPostureSummary: bookPostureSummary,
            materialityTrigger: trigger,
            triggeringNewsSummary: news,
            scopedMemorySymbols: nil,
            scopedMemoryThemes: nil,
            scopedMemoryOpenQuestions: nil
        )
    }

    private func portfolioRiskTaskContext(from task: AnalystTask) -> PortfolioRiskTaskContext? {
        let legacy = portfolioRiskTaskContextFromDescription(task.description)
        guard let contextPack = task.contextPack else {
            return legacy
        }

        let impactedSymbols = Set(task.symbols.map { $0.uppercased() })
        let heldPositions = contextPack.sharedCurrentTruth.positions.filter { position in
            impactedSymbols.isEmpty || impactedSymbols.contains(position.symbol.uppercased())
        }
        let heldSummary = heldPositions.isEmpty ? legacy?.heldPositionsSummary : heldPositions
            .map { "\($0.symbol) \($0.directionLabel) qty \($0.quantity) market value \($0.marketValue)" }
            .joined(separator: "; ")

        let heldSymbolSet = Set(heldPositions.map { $0.symbol.uppercased() })
        let watchlistOnly = contextPack.sharedCurrentTruth.watchlistSymbols
            .map { $0.uppercased() }
            .filter { symbol in
                (impactedSymbols.isEmpty || impactedSymbols.contains(symbol)) && heldSymbolSet.contains(symbol) == false
            }
        let watchlistSummary = watchlistOnly.isEmpty ? legacy?.watchlistSummary : watchlistOnly.joined(separator: ", ")

        let strategyBrief = contextPack.sharedCurrentTruth.portfolioStrategyBrief
        let scopedMemory = contextPack.scopedMemory
        let merged = PortfolioRiskTaskContext(
            heldPositionsSummary: heldSummary,
            watchlistSummary: watchlistSummary,
            strategyObjective: strategyBrief?.objectiveSummary ?? legacy?.strategyObjective,
            strategyThemes: strategyBrief?.keyThemes.isEmpty == false
                ? strategyBrief?.keyThemes.joined(separator: "; ")
                : legacy?.strategyThemes,
            riskPosture: strategyBrief?.currentRiskPosture ?? legacy?.riskPosture,
            reviewPosture: strategyBrief?.reviewEscalationPosture ?? legacy?.reviewPosture,
            riskFrameworkGuidance: legacy?.riskFrameworkGuidance,
            coveragePosture: legacy?.coveragePosture,
            concentrationPosture: legacy?.concentrationPosture,
            clusteredRiskView: legacy?.clusteredRiskView,
            longShortPosture: legacy?.longShortPosture,
            escalationPosture: legacy?.escalationPosture,
            whyNowSummary: legacy?.whyNowSummary,
            bookPostureSummary: legacy?.bookPostureSummary,
            riskTrigger: legacy?.riskTrigger ?? leadingSentence(in: task.description),
            whatChangedSinceReview: legacy?.whatChangedSinceReview,
            triggeringConditions: legacy?.triggeringConditions,
            priorReviewAnchor: legacy?.priorReviewAnchor,
            priorReviewSource: legacy?.priorReviewSource,
            scopedMemorySymbols: scopedMemory?.trackedSymbols.isEmpty == false
                ? scopedMemory?.trackedSymbols.joined(separator: ", ")
                : nil,
            scopedMemoryThemes: scopedMemory?.trackedThemes.isEmpty == false
                ? scopedMemory?.trackedThemes.joined(separator: "; ")
                : nil,
            scopedMemoryOpenQuestions: scopedMemory?.openQuestions.isEmpty == false
                ? scopedMemory?.openQuestions.joined(separator: " | ")
                : nil
        )

        if merged.heldPositionsSummary == nil,
           merged.watchlistSummary == nil,
           merged.strategyObjective == nil,
           merged.strategyThemes == nil,
           merged.riskPosture == nil,
           merged.reviewPosture == nil,
           merged.riskFrameworkGuidance == nil,
           merged.coveragePosture == nil,
           merged.concentrationPosture == nil,
           merged.clusteredRiskView == nil,
           merged.longShortPosture == nil,
           merged.escalationPosture == nil,
           merged.whyNowSummary == nil,
           merged.bookPostureSummary == nil,
           merged.riskTrigger == nil,
           merged.whatChangedSinceReview == nil,
           merged.triggeringConditions == nil,
           merged.priorReviewAnchor == nil,
           merged.priorReviewSource == nil,
           merged.scopedMemorySymbols == nil,
           merged.scopedMemoryThemes == nil,
           merged.scopedMemoryOpenQuestions == nil {
            return nil
        }
        return merged
    }

    private func portfolioRiskTaskContextFromDescription(_ description: String) -> PortfolioRiskTaskContext? {
        let held = taskContextValue(prefix: "Held positions in scope:", from: description)
        let watchlist = taskContextValue(prefix: "Watchlist context:", from: description)
        let strategyObjective = taskContextValue(prefix: "Portfolio strategy brief objective:", from: description)
        let strategyThemes = taskContextValue(prefix: "Strategy themes:", from: description)
        let riskPosture = taskContextValue(prefix: "Current risk posture:", from: description)
        let reviewPosture = taskContextValue(prefix: "Review posture:", from: description)
        let riskFrameworkGuidance = taskContextValue(prefix: "Risk framework guidance:", from: description)
        let coveragePosture = taskContextValue(prefix: "Coverage posture:", from: description)
        let concentrationPosture = taskContextValue(prefix: "Concentration posture:", from: description)
        let clusteredRiskView = taskContextValue(prefix: "Clustered risk view:", from: description)
        let longShortPosture = taskContextValue(prefix: "Long-vs-short posture:", from: description)
        let escalationPosture = taskContextValue(prefix: "Escalation posture:", from: description)
        let whyNowSummary = taskContextValue(prefix: "Why now:", from: description)
        let bookPostureSummary = taskContextValue(prefix: "Current book posture:", from: description)
        let riskTrigger = taskContextValue(prefix: "Risk trigger:", from: description)
        let whatChangedSinceReview = taskContextValue(prefix: "What changed since prior review:", from: description)
        let triggeringConditions = taskContextValue(prefix: "Triggering conditions:", from: description)
        let priorReviewAnchor = taskContextValue(prefix: "Prior portfolio-risk review anchor:", from: description)
        let priorReviewSource = taskContextValue(prefix: "The last review anchor came from", from: description)

        if held == nil,
           watchlist == nil,
           strategyObjective == nil,
           strategyThemes == nil,
           riskPosture == nil,
           reviewPosture == nil,
           riskFrameworkGuidance == nil,
           coveragePosture == nil,
           concentrationPosture == nil,
           clusteredRiskView == nil,
           longShortPosture == nil,
           escalationPosture == nil,
           whyNowSummary == nil,
           bookPostureSummary == nil,
           riskTrigger == nil,
           whatChangedSinceReview == nil,
           triggeringConditions == nil,
           priorReviewAnchor == nil,
           priorReviewSource == nil {
            return nil
        }

        return PortfolioRiskTaskContext(
            heldPositionsSummary: held,
            watchlistSummary: watchlist,
            strategyObjective: strategyObjective,
            strategyThemes: strategyThemes,
            riskPosture: riskPosture,
            reviewPosture: reviewPosture,
            riskFrameworkGuidance: riskFrameworkGuidance,
            coveragePosture: coveragePosture,
            concentrationPosture: concentrationPosture,
            clusteredRiskView: clusteredRiskView,
            longShortPosture: longShortPosture,
            escalationPosture: escalationPosture,
            whyNowSummary: whyNowSummary,
            bookPostureSummary: bookPostureSummary,
            riskTrigger: riskTrigger,
            whatChangedSinceReview: whatChangedSinceReview,
            triggeringConditions: triggeringConditions,
            priorReviewAnchor: priorReviewAnchor,
            priorReviewSource: priorReviewSource,
            scopedMemorySymbols: nil,
            scopedMemoryThemes: nil,
            scopedMemoryOpenQuestions: nil
        )
    }

    private func taskContextValue(prefix: String, from description: String) -> String? {
        guard let range = description.range(of: prefix) else {
            return nil
        }
        let remainder = description[range.upperBound...]
        let terminators = [
            " Held positions in scope:",
            " Watchlist context:",
            " Portfolio strategy brief objective:",
            " Strategy themes:",
            " Current risk posture:",
            " Material developments:",
            " Usually not material:",
            " Review posture:",
            " Coverage posture:",
            " Clustered event view:",
            " Escalation posture:",
            " Why now:",
            " Current book posture:",
            " Concentration posture:",
            " Clustered risk view:",
            " Long-vs-short posture:",
            " Materiality trigger:",
            " Triggering news:",
            " Risk trigger:",
            " What changed since prior review:",
            " Triggering conditions:",
            " Prior portfolio-risk review anchor:",
            " The last review anchor came from",
            " If the impact is not strong enough"
        ]
        let suffixRange = terminators
            .compactMap { terminator in
                remainder.range(of: terminator)
            }
            .min(by: { $0.lowerBound < $1.lowerBound })
        let value = suffixRange.map { String(remainder[..<$0.lowerBound]) } ?? String(remainder)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func makeRecentNewsMaterialImpactFinding(
        charter: AnalystCharter,
        task: AnalystTask,
        news: [NewsEvent],
        externalIssues: [AnalystExternalEvidenceIssue],
        bundleId: String,
        now: Date
    ) -> AnalystFinding {
        let context = recentNewsTaskContext(from: task)
        let symbols = Array(Set(task.symbols + news.flatMap(\.rawSymbolHints))).sorted().prefix(8)
        let latestHeadline = news.first?.title ?? "No recent app news available"
        let confidence = min(0.78, 0.42 + (Double(min(news.count, 3)) * 0.08) + (Double(min(task.symbols.count, 3)) * 0.06))
        let issueText = externalEvidenceIssueSummary(externalIssues).map { " External evidence degraded: \($0)." } ?? ""
        let triggerText = context?.materialityTrigger ?? "Recent normalized news may have a portfolio-relevant impact."
        let holdingsText = context?.heldPositionsSummary.map { " Holdings in scope: \($0)" } ?? ""
        let watchlistText = context?.watchlistSummary.map { " Watchlist context: \($0)" } ?? ""
        let strategyText = context?.strategyObjective.map { " Strategy objective: \($0)" } ?? ""

        return AnalystFinding(
            findingId: stableHashedIdentifier(
                prefix: "finding",
                components: [charter.charterId, bundleId, DateCodec.formatISO8601(now)]
            ),
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: task.taskId,
            title: "Recent news materiality review: \(symbols.joined(separator: ", "))",
            summary: "\(triggerText) Latest normalized headline: \(latestHeadline).\(holdingsText)\(watchlistText)\(strategyText)\(issueText)",
            thesis: "The recent normalized news cluster may be materially relevant to the current portfolio context. \(triggerText)\(strategyText) This remains a PM-reviewable analyst conclusion rather than a trade instruction or proposal approval.\(issueText)",
            symbols: Array(symbols),
            tags: Array(Set(task.tags + ["recent_news_material_impact"])).sorted(),
            status: .open,
            confidence: confidence,
            timeHorizon: "event-driven",
            evidenceBundleId: bundleId,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeRecentNewsMaterialImpactTaskUpdate(
        existingTask: AnalystTask,
        charter: AnalystCharter,
        news: [NewsEvent],
        externalIssues: [AnalystExternalEvidenceIssue],
        bundleId: String,
        findingId: String,
        now: Date
    ) -> AnalystTask {
        var task = existingTask
        task.analystId = charter.analystId
        task.charterId = charter.charterId
        task.status = .inProgress
        task.symbols = Array(Set(existingTask.symbols + news.flatMap(\.rawSymbolHints))).sorted()
        task.tags = Array(Set(task.tags + ["checkpointed", "recent-news-analyst"])).sorted()
        task.linkedFindingIDs = Array(Set(task.linkedFindingIDs + [findingId])).sorted()

        let context = recentNewsTaskContext(from: task)
        let trigger = context?.materialityTrigger ?? "Recent normalized news may have a material impact on the current portfolio."
        let issueSuffix = externalEvidenceIssueSummary(externalIssues).map { " External evidence degraded: \($0)." } ?? ""
        task.checkpoint = AnalystTaskCheckpoint(
            checkpointID: task.checkpoint?.checkpointID ?? stableIdentifier(prefix: "checkpoint", components: [task.taskId]),
            taskId: task.taskId,
            analystId: charter.analystId,
            charterId: charter.charterId,
            summary: "\(trigger)\(issueSuffix)",
            nextPlannedAction: "PM should review the memo and decide whether the recent-news impact warrants follow-up or owner-facing escalation.",
            openQuestions: [
                "Does this news change the PM's current risk posture for the impacted symbol set?",
                "Is more portfolio-specific follow-up needed before any owner-facing PM review?"
            ],
            linkedFindingIDs: task.linkedFindingIDs,
            linkedEvidenceBundleIDs: Array(Set((task.checkpoint?.linkedEvidenceBundleIDs ?? []) + [bundleId])).sorted(),
            updatedAt: now
        )
        task.lastCheckpointSummary = task.checkpoint?.summary
        return task
    }

    private func makeRecentNewsMemoExecutiveSummary(
        finding: AnalystFinding,
        memoStyle: LocalMemoStyle,
        recentNewsContext: RecentNewsTaskContext?
    ) -> String {
        let lead = memoProfileLead(for: memoStyle)
        let trigger = recentNewsContext?.whyNowSummary ?? recentNewsContext?.materialityTrigger ?? leadingSentence(in: finding.summary)
        let escalation = recentNewsContext?.escalationPosture.map { " Current escalation posture: \($0)." } ?? ""
        return "\(lead) \(trigger) This memo records one coherent recent-news event view for PM review and stays separate from trading, proposal approval, and safety-state changes.\(escalation)"
    }

    private func makeRecentNewsMemoCurrentView(
        finding: AnalystFinding,
        confidencePercent: Int,
        recentNewsContext: RecentNewsTaskContext?
    ) -> String {
        let holdings = recentNewsContext?.heldPositionsSummary ?? "No current holdings summary was attached to the task."
        let riskPosture = recentNewsContext?.riskPosture.map { " Risk posture: \($0)" } ?? ""
        let bookPosture = recentNewsContext?.bookPostureSummary.map { " Book posture: \($0)" } ?? ""
        let clusteredView = recentNewsContext?.clusteredEventView.map { " Clustered event view: \($0)" } ?? ""
        let memoryThemes = recentNewsContext?.scopedMemoryThemes.map { " Standing analyst memory keeps these themes in scope: \($0)." } ?? ""
        return "\(leadingSentence(in: finding.thesis)) Confidence is currently \(confidencePercent) percent and remains bounded by event-driven uncertainty. Portfolio context: \(holdings)\(riskPosture)\(bookPosture)\(clusteredView)\(memoryThemes)"
    }

    private func makeRecentNewsMemoEvidenceSummary(
        news: [NewsEvent],
        latestHeadline: String,
        recentNewsContext: RecentNewsTaskContext?
    ) -> String {
        let trigger = recentNewsContext?.triggeringNewsSummary ?? latestHeadline
        let coverage = recentNewsContext?.coveragePosture.map { " Coverage posture: \($0)" } ?? ""
        let cluster = recentNewsContext?.clusteredEventView.map { " Clustered event view: \($0)" } ?? ""
        let holdings = recentNewsContext?.heldPositionsSummary.map { "Held positions in scope: \($0)" } ?? ""
        let watchlist = recentNewsContext?.watchlistSummary.map { " Watchlist context: \($0)" } ?? ""
        let strategyThemes = recentNewsContext?.strategyThemes.map { " Strategy themes: \($0)" } ?? ""
        let memorySymbols = recentNewsContext?.scopedMemorySymbols.map { " Standing analyst memory is already tracking: \($0)." } ?? ""
        return "Primary support comes from recent normalized app-owned news. Triggering cluster: \(trigger). Latest headline: \(latestHeadline).\(coverage)\(cluster) \(holdings)\(watchlist)\(strategyThemes)\(memorySymbols)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeRecentNewsMemoUncertaintySummary(
        finding: AnalystFinding,
        recentNewsContext: RecentNewsTaskContext?
    ) -> String {
        let watchlist = recentNewsContext?.watchlistSummary ?? "watchlist context unavailable"
        let nonMaterial = recentNewsContext?.nonMaterialDevelopments.map { " The standing brief currently treats these as usually not material: \($0)." } ?? ""
        let openQuestions = recentNewsContext?.scopedMemoryOpenQuestions.map { " Open analyst memory questions still in scope: \($0)." } ?? ""
        return "This memo reflects a potentially material news cluster, not a confirmed portfolio instruction. The effect on current holdings may still depend on follow-up facts, additional filings, and whether the PM believes the watch context (\(watchlist)) changes current portfolio assumptions.\(nonMaterial)\(openQuestions)"
    }

    private func makeRecentNewsMemoRecommendedNextStep(
        finding: AnalystFinding,
        recentNewsContext: RecentNewsTaskContext?
    ) -> String {
        let trigger = recentNewsContext?.whyNowSummary ?? recentNewsContext?.materialityTrigger ?? leadingSentence(in: finding.summary)
        let reviewPosture = recentNewsContext?.reviewPosture.map { " The current review posture is: \($0)." } ?? ""
        let escalationPosture = recentNewsContext?.escalationPosture.map { " Current escalation posture: \($0)." } ?? ""
        let continuity = recentNewsContext?.scopedMemoryOpenQuestions.map { " Use the standing analyst memory questions as follow-up prompts: \($0)." } ?? ""
        return "PM should review this recent-news memo, decide whether \(trigger.lowercased()) justifies deeper follow-up, and keep any downstream proposal or trading decision behind the existing separate approval gates.\(reviewPosture)\(escalationPosture)\(continuity)"
    }

    private func makePortfolioRiskTriggerFinding(
        charter: AnalystCharter,
        task: AnalystTask,
        externalIssues: [AnalystExternalEvidenceIssue],
        bundleId: String,
        now: Date
    ) -> AnalystFinding {
        let context = portfolioRiskTaskContext(from: task)
        let symbols = task.symbols.sorted().prefix(8)
        let trigger = context?.riskTrigger ?? "Bounded portfolio-risk trigger conditions crossed threshold."
        let whyNow = context?.whyNowSummary ?? trigger
        let holdingsText = context?.heldPositionsSummary.map { " Holdings in scope: \($0)" } ?? ""
        let postureText = context?.riskPosture.map { " Current risk posture: \($0)." } ?? ""
        let concentrationText = context?.concentrationPosture.map { " Concentration posture: \($0)." } ?? ""
        let longShortText = context?.longShortPosture.map { " Long-vs-short posture: \($0)." } ?? ""
        let conditionsText = context?.triggeringConditions.map { " Triggering conditions: \($0)" } ?? ""
        let issueText = externalEvidenceIssueSummary(externalIssues).map { " External evidence degraded: \($0)." } ?? ""

        return AnalystFinding(
            findingId: stableHashedIdentifier(
                prefix: "finding",
                components: [charter.charterId, bundleId, DateCodec.formatISO8601(now)]
            ),
            analystId: charter.analystId,
            charterId: charter.charterId,
            taskId: task.taskId,
            title: "Portfolio risk review: \(symbols.joined(separator: ", "))",
            summary: "\(whyNow)\(holdingsText)\(postureText)\(concentrationText)\(longShortText)\(conditionsText)\(issueText)",
            thesis: "Portfolio Risk believes the current portfolio setup may warrant PM attention because bounded concentration, clustering, or directional-posture meaning changed enough to matter now. This remains a PM-reviewable risk memo rather than a trade instruction, proposal approval, or safety-state change.\(postureText)\(concentrationText)\(longShortText)\(issueText)",
            symbols: Array(symbols),
            tags: Array(Set(task.tags + ["portfolio_risk_trigger"])).sorted(),
            status: .open,
            confidence: 0.68,
            timeHorizon: "event-driven",
            evidenceBundleId: bundleId,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makePortfolioRiskTriggerTaskUpdate(
        existingTask: AnalystTask,
        charter: AnalystCharter,
        externalIssues: [AnalystExternalEvidenceIssue],
        bundleId: String,
        findingId: String,
        now: Date
    ) -> AnalystTask {
        var task = existingTask
        task.analystId = charter.analystId
        task.charterId = charter.charterId
        task.status = .inProgress
        task.tags = Array(Set(task.tags + ["checkpointed", "portfolio-risk-analyst", "portfolio-risk-trigger"])).sorted()
        task.linkedFindingIDs = Array(Set(task.linkedFindingIDs + [findingId])).sorted()

        let context = portfolioRiskTaskContext(from: task)
        let trigger = context?.whyNowSummary ?? context?.riskTrigger ?? "Bounded portfolio-risk trigger conditions crossed threshold."
        let issueSuffix = externalEvidenceIssueSummary(externalIssues).map { " External evidence degraded: \($0)." } ?? ""
        task.checkpoint = AnalystTaskCheckpoint(
            checkpointID: task.checkpoint?.checkpointID ?? stableIdentifier(prefix: "checkpoint", components: [task.taskId]),
            taskId: task.taskId,
            analystId: charter.analystId,
            charterId: charter.charterId,
            summary: "\(trigger)\(issueSuffix)",
            nextPlannedAction: "PM should review the portfolio-risk memo and decide whether the trigger stays monitor-only or needs deeper follow-up.",
            openQuestions: [
                "Does the current concentration still fit the stated portfolio risk posture?",
                "Is additional sector, macro, or owner-facing PM follow-up warranted before any downstream action?"
            ],
            linkedFindingIDs: task.linkedFindingIDs,
            linkedEvidenceBundleIDs: Array(Set((task.checkpoint?.linkedEvidenceBundleIDs ?? []) + [bundleId])).sorted(),
            updatedAt: now
        )
        task.lastCheckpointSummary = task.checkpoint?.summary
        return task
    }

    private func makePortfolioRiskMemoExecutiveSummary(
        finding: AnalystFinding,
        memoStyle: LocalMemoStyle,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        let lead = memoProfileLead(for: memoStyle)
        let whyNow = portfolioRiskContext?.whyNowSummary ?? portfolioRiskContext?.riskTrigger ?? leadingSentence(in: finding.summary)
        let escalation = portfolioRiskContext?.escalationPosture.map { " Current escalation posture: \($0)." } ?? ""
        return "\(lead) \(whyNow) This memo records a bounded Portfolio Risk trigger case for PM review and stays separate from trading, proposal approval, and safety-state changes.\(escalation)"
    }

    private func makePortfolioRiskMemoCurrentView(
        finding: AnalystFinding,
        confidencePercent: Int,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        let holdings = portfolioRiskContext?.heldPositionsSummary ?? "No current holdings summary was attached to the task."
        let posture = portfolioRiskContext?.riskPosture.map { " Risk posture: \($0)" } ?? ""
        let framework = portfolioRiskContext?.riskFrameworkGuidance.map { " Framework guidance: \($0)" } ?? ""
        let concentration = portfolioRiskContext?.concentrationPosture.map { " Concentration posture: \($0)" } ?? ""
        let clusteredView = portfolioRiskContext?.clusteredRiskView.map { " Clustered risk view: \($0)" } ?? ""
        let longShort = portfolioRiskContext?.longShortPosture.map { " Long-vs-short posture: \($0)" } ?? ""
        let bookPosture = portfolioRiskContext?.bookPostureSummary.map { " Current book posture: \($0)" } ?? ""
        let changed = portfolioRiskContext?.whatChangedSinceReview.map { " What changed since the prior review: \($0)" } ?? ""
        let memoryThemes = portfolioRiskContext?.scopedMemoryThemes.map { " Standing analyst memory keeps these themes in scope: \($0)." } ?? ""
        return "\(leadingSentence(in: finding.thesis)) Confidence is currently \(confidencePercent) percent and remains bounded by event-driven portfolio-risk uncertainty. Portfolio context: \(holdings)\(posture)\(framework)\(concentration)\(clusteredView)\(longShort)\(bookPosture)\(changed)\(memoryThemes)"
    }

    private func makePortfolioRiskMemoEvidenceSummary(
        news: [NewsEvent],
        portfolioRiskContext: PortfolioRiskTaskContext?,
        latestHeadline: String
    ) -> String {
        let conditions = portfolioRiskContext?.triggeringConditions ?? "No explicit trigger-condition summary was attached."
        let coverage = portfolioRiskContext?.coveragePosture.map { " Coverage posture: \($0)" } ?? ""
        let framework = portfolioRiskContext?.riskFrameworkGuidance.map { " Risk framework guidance: \($0)" } ?? ""
        let concentration = portfolioRiskContext?.concentrationPosture.map { " Concentration posture: \($0)" } ?? ""
        let longShort = portfolioRiskContext?.longShortPosture.map { " Long-vs-short posture: \($0)" } ?? ""
        let holdings = portfolioRiskContext?.heldPositionsSummary.map { "Held positions in scope: \($0)" } ?? ""
        let watchlist = portfolioRiskContext?.watchlistSummary.map { " Watchlist context: \($0)" } ?? ""
        let strategyThemes = portfolioRiskContext?.strategyThemes.map { " Strategy themes: \($0)" } ?? ""
        let reviewAnchor = portfolioRiskContext?.priorReviewAnchor.map { " Prior review anchor: \($0)." } ?? ""
        let memorySymbols = portfolioRiskContext?.scopedMemorySymbols.map { " Standing analyst memory is already tracking: \($0)." } ?? ""
        let newsLead = news.isEmpty ? "" : " Recent normalized news in context still includes: \(latestHeadline)."
        return "Primary support comes from app-owned portfolio state, bounded trigger evaluation, and the Portfolio Risk charter framework. Triggering conditions: \(conditions).\(coverage)\(framework)\(concentration)\(longShort) \(holdings)\(watchlist)\(strategyThemes)\(reviewAnchor)\(memorySymbols)\(newsLead)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makePortfolioRiskMemoUncertaintySummary(
        finding: AnalystFinding,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        let reviewPosture = portfolioRiskContext?.reviewPosture.map { " The current review posture is: \($0)." } ?? ""
        let escalation = portfolioRiskContext?.escalationPosture.map { " Current escalation posture: \($0)." } ?? ""
        let openQuestions = portfolioRiskContext?.scopedMemoryOpenQuestions.map { " Open analyst memory questions still in scope: \($0)." } ?? ""
        return "This memo reflects a bounded Portfolio Risk trigger, not a confirmed portfolio instruction. The current exposure may still require PM judgment on whether the trigger changes monitoring posture, requires deeper overlay review, or should simply stay on watch.\(reviewPosture)\(escalation)\(openQuestions)"
    }

    private func makePortfolioRiskMemoRecommendedNextStep(
        finding: AnalystFinding,
        portfolioRiskContext: PortfolioRiskTaskContext?
    ) -> String {
        let trigger = portfolioRiskContext?.whyNowSummary ?? portfolioRiskContext?.riskTrigger ?? leadingSentence(in: finding.summary)
        let reviewPosture = portfolioRiskContext?.reviewPosture.map { " The current review posture is: \($0)." } ?? ""
        let escalation = portfolioRiskContext?.escalationPosture.map { " Current escalation posture: \($0)." } ?? ""
        let changed = portfolioRiskContext?.whatChangedSinceReview.map { " Focus the next review on this change: \($0)." } ?? ""
        let continuity = portfolioRiskContext?.scopedMemoryOpenQuestions.map { " Use the standing analyst memory questions as follow-up prompts: \($0)." } ?? ""
        return "PM should review this portfolio-risk memo, decide whether \(trigger.lowercased()) warrants monitor-only treatment, deeper overlay follow-up, or a separate owner-facing PM review, and keep any downstream proposal or trading decision behind the existing separate approval gates.\(reviewPosture)\(escalation)\(changed)\(continuity)"
    }

    private func leadingSentence(in text: String) -> String {
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

    private func droppingExternalDegradedSuffix(from text: String) -> String {
        let marker = " External evidence degraded:"
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: marker) else {
            return trimmed
        }
        return String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeDefaultTask(charter: AnalystCharter, taskID: String, now: Date) -> AnalystTask {
        AnalystTask(
            taskId: taskID,
            analystId: charter.analystId,
            charterId: charter.charterId,
            title: "\(charter.title) ongoing research",
            description: "Durable long-horizon analyst task for repeated evidence review under \(charter.title).",
            status: .queued,
            createdAt: now,
            updatedAt: now,
            tags: ["analyst_long_horizon", "checkpointed"]
        )
    }

    private func defaultTaskID(for charter: AnalystCharter) -> String {
        stableIdentifier(prefix: "task", components: [charter.charterId, "ongoing-research"])
    }
}

private func extractMetaDescription(in html: String) -> String? {
    let patterns = [
        "<meta[^>]+name=[\"']description[\"'][^>]+content=[\"'](.*?)[\"'][^>]*>",
        "<meta[^>]+content=[\"'](.*?)[\"'][^>]+name=[\"']description[\"'][^>]*>",
        "<meta[^>]+property=[\"']og:description[\"'][^>]+content=[\"'](.*?)[\"'][^>]*>"
    ]
    for pattern in patterns {
        if let match = extractFirstMatch(in: html, pattern: pattern),
           let cleaned = cleanHTMLText(match),
           !cleaned.isEmpty {
            return cleaned
        }
    }
    return nil
}

private func inferCrucialSiteSourceClass(for url: URL, titleHint: String? = nil) -> CrucialSiteSourceClass {
    let host = url.host?.lowercased() ?? ""
    let path = url.path.lowercased()
    let title = titleHint?.lowercased() ?? ""
    let descriptor = [host, path, title].joined(separator: " ")

    let investorRelationsMarkers = [
        "investor", "investors", "investor-relations", "investorrelations",
        "news-releases", "earnings", "results", "presentation", "shareholder", "transcript"
    ]
    if host.hasPrefix("ir.") || host.contains(".ir.")
        || host.hasPrefix("investor.") || host.contains(".investor.")
        || investorRelationsMarkers.contains(where: { descriptor.contains($0) }) {
        return .investorRelations
    }

    let regulatorHosts = [
        "sec.gov", "www.sec.gov",
        "nasdaq.com", "www.nasdaq.com",
        "nyse.com", "www.nyse.com",
        "cmegroup.com", "www.cmegroup.com",
        "ice.com", "www.ice.com"
    ]
    let regulatorMarkers = [
        "/filing", "/filings", "/notice", "/notices", "/regulation", "/rule", "/bulletin"
    ]
    if regulatorHosts.contains(host)
        || regulatorMarkers.contains(where: { descriptor.contains($0) }) {
        return .issuerRegulatorExchange
    }

    let companyPressMarkers = [
        "newsroom", "press", "press-release", "pressrelease", "blog", "updates",
        "stories", "product", "launch", "release-notes"
    ]
    if companyPressMarkers.contains(where: { descriptor.contains($0) }) {
        return .companyPressBlog
    }

    let industryMarkers = [
        "analysis", "article", "research", "report", "insight", "industry", "trade", "reference"
    ]
    if industryMarkers.contains(where: { descriptor.contains($0) }) {
        return .industryPublication
    }

    return .genericPublicWeb
}

private func supportsBoundedDiscovery(
    for url: URL,
    sourceClass: CrucialSiteSourceClass
) -> Bool {
    let path = url.path.lowercased()
    if path.isEmpty || path == "/" {
        return true
    }
    let hubHints = discoveryPathHints(for: sourceClass)
    return hubHints.contains { path.contains($0) }
}

private func discoveryPathHints(for sourceClass: CrucialSiteSourceClass) -> [String] {
    switch sourceClass {
    case .investorRelations:
        return [
            "/investor", "/investors", "/investor-relations", "/news-releases",
            "/earnings", "/results", "/presentation", "/presentations", "/transcript"
        ]
    case .issuerRegulatorExchange:
        return [
            "/announcement", "/announcements", "/notice", "/notices",
            "/filing", "/filings", "/release", "/releases", "/bulletin",
            "13f", "infotable", "informationtable", ".xml", ".txt"
        ]
    case .companyPressBlog:
        return [
            "/newsroom", "/press", "/press-release", "/blog", "/updates", "/stories", "/product"
        ]
    case .industryPublication:
        return [
            "/article", "/articles", "/analysis", "/research", "/report", "/insight", "/news"
        ]
    case .genericPublicWeb:
        return []
    }
}

private struct HTMLAnchorCandidate: Sendable {
    let href: String
    let anchorText: String
}

private func extractAnchorCandidates(in html: String) -> [HTMLAnchorCandidate] {
    let patterns = [
        #"<a[^>]*href\s*=\s*"([^"]+)"[^>]*>(.*?)</a>"#,
        #"<a[^>]*href\s*=\s*'([^']+)'[^>]*>(.*?)</a>"#
    ]

    var candidates: [HTMLAnchorCandidate] = []
    var seen = Set<String>()
    let range = NSRange(html.startIndex..<html.endIndex, in: html)

    for pattern in patterns {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            continue
        }

        for match in regex.matches(in: html, options: [], range: range) {
            guard match.numberOfRanges >= 3,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else {
                continue
            }
            let href = String(html[hrefRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard href.isEmpty == false else {
                continue
            }
            let anchorText = cleanHTMLText(String(html[textRange])) ?? ""
            let key = "\(href.lowercased())|\(anchorText.lowercased())"
            guard seen.insert(key).inserted else {
                continue
            }
            candidates.append(HTMLAnchorCandidate(href: href, anchorText: anchorText))
        }
    }

    return candidates
}

private func extractAdaptedExternalTitle(
    in html: String,
    sourceClass: CrucialSiteSourceClass,
    fallback: String
) -> String {
    let patterns = [
        #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
        #"<meta[^>]+name=["']twitter:title["'][^>]+content=["']([^"']+)["']"#,
        #""headline"\s*:\s*"([^"]+)""#,
        #"<h1[^>]*>(.*?)</h1>"#,
        #"<title[^>]*>(.*?)</title>"#
    ]

    for pattern in patterns {
        if let match = extractFirstMatch(in: html, pattern: pattern),
           let cleaned = cleanHTMLText(match),
           cleaned.isEmpty == false {
            return cleaned
        }
    }

    let cleanedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleanedFallback.isEmpty == false {
        return cleanedFallback
    }

    switch sourceClass {
    case .investorRelations:
        return "Investor relations material"
    case .issuerRegulatorExchange:
        return "Issuer / regulator / exchange material"
    case .companyPressBlog:
        return "Official company update"
    case .industryPublication:
        return "Industry publication"
    case .genericPublicWeb:
        return "Policy-governed external source"
    }
}

private func extractAdaptedPrimaryText(
    in html: String,
    sourceClass: CrucialSiteSourceClass
) -> String? {
    var blockPatterns = [
        #"<article[^>]*>(.*?)</article>"#,
        #"<main[^>]*>(.*?)</main>"#
    ]

    let sourceClassMarkers: [String]
    switch sourceClass {
    case .investorRelations:
        sourceClassMarkers = ["news-release", "earnings", "presentation", "transcript", "investor", "release"]
    case .issuerRegulatorExchange:
        sourceClassMarkers = ["announcement", "notice", "filing", "release", "bulletin"]
    case .companyPressBlog:
        sourceClassMarkers = ["newsroom", "press", "blog", "story", "product", "update"]
    case .industryPublication:
        sourceClassMarkers = ["article", "analysis", "story", "content", "report", "insight"]
    case .genericPublicWeb:
        sourceClassMarkers = ["content", "article", "story"]
    }

    blockPatterns.append(contentsOf: sourceClassMarkers.map { marker in
        #"<(?:section|div)[^>]*(?:class|id)=["'][^"']*"# + marker + #"[^"']*["'][^>]*>(.*?)</(?:section|div)>"#
    })

    for pattern in blockPatterns {
        if let match = extractFirstMatch(in: html, pattern: pattern),
           let cleaned = cleanHTMLText(match),
           isMeaningfulExternalEvidenceText(cleaned) {
            return boundedEvidenceExcerpt(from: cleaned, limit: 700)
        }
    }

    let paragraphs = html.matches(for: #"<p[^>]*>(.*?)</p>"#)
        .compactMap(cleanHTMLText)
        .filter(isMeaningfulExternalEvidenceText)
    if paragraphs.isEmpty == false {
        return boundedEvidenceExcerpt(from: paragraphs.prefix(3).joined(separator: " "), limit: 700)
    }

    return cleanHTMLText(html).flatMap { cleaned in
        isMeaningfulExternalEvidenceText(cleaned) ? boundedEvidenceExcerpt(from: cleaned, limit: 700) : nil
    }
}

private func buildAdaptedExternalSummary(
    sourceClass: CrucialSiteSourceClass,
    html: String,
    fallbackText: String
) -> String {
    var parts: [String] = []

    if let description = extractMetaDescription(in: html) {
        let cleaned = boundedEvidenceExcerpt(from: description, limit: 260)
        if cleaned.isEmpty == false {
            parts.append(cleaned)
        }
    }

    let cleanedFallback = boundedEvidenceExcerpt(from: fallbackText, limit: 320)
    if cleanedFallback.isEmpty == false,
       parts.contains(where: { $0.caseInsensitiveCompare(cleanedFallback) == .orderedSame }) == false {
        parts.append(cleanedFallback)
    }

    let combined = parts.prefix(2).joined(separator: " ")
    if combined.isEmpty == false {
        return combined
    }

    switch sourceClass {
    case .investorRelations:
        return "Investor relations material fetched as bounded supplemental evidence."
    case .issuerRegulatorExchange:
        return "Issuer, regulator, or exchange material fetched as bounded supplemental evidence."
    case .companyPressBlog:
        return "Official company press, product, or blog material fetched as bounded supplemental evidence."
    case .industryPublication:
        return "Industry publication fetched as bounded supplemental evidence."
    case .genericPublicWeb:
        return "Policy-governed external source fetched for analyst context."
    }
}

private func boundedEvidenceExcerpt(from text: String, limit: Int) -> String {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.isEmpty == false else {
        return ""
    }
    guard cleaned.count > limit else {
        return cleaned
    }

    let prefix = String(cleaned.prefix(limit))
    if let sentenceBoundary = prefix.lastIndex(where: { ".!?".contains($0) }) {
        let sentence = prefix[...sentenceBoundary].trimmingCharacters(in: .whitespacesAndNewlines)
        if sentence.count >= 80 {
            return sentence
        }
    }

    if let wordBoundary = prefix.lastIndex(of: " ") {
        return String(prefix[..<wordBoundary]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    return prefix + "..."
}

private func extractAdaptedObservedAt(in html: String) -> Date? {
    let patterns = [
        #"<meta[^>]+property=["']article:published_time["'][^>]+content=["']([^"']+)["']"#,
        #"<meta[^>]+name=["']article:published_time["'][^>]+content=["']([^"']+)["']"#,
        #"<meta[^>]+property=["']og:published_time["'][^>]+content=["']([^"']+)["']"#,
        #"<meta[^>]+name=["']pubdate["'][^>]+content=["']([^"']+)["']"#,
        #"<meta[^>]+itemprop=["']datePublished["'][^>]+content=["']([^"']+)["']"#,
        #"<time[^>]+datetime=["']([^"']+)["']"#,
        #""datePublished"\s*:\s*"([^"]+)""#
    ]

    for pattern in patterns {
        guard let match = extractFirstMatch(in: html, pattern: pattern) else {
            continue
        }
        if let parsed = parsePublishedDate(match) {
            return parsed
        }
    }

    return nil
}

private func parsePublishedDate(_ value: String) -> Date? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else {
        return nil
    }

    let preciseISOFormatter = ISO8601DateFormatter()
    preciseISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = preciseISOFormatter.date(from: trimmed) {
        return date
    }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: trimmed) {
        return date
    }

    let formatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mmXXXXX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    for formatter in formatters {
        if let date = formatter.date(from: trimmed) {
            return date
        }
    }

    return nil
}

private func makeEvidenceSummary(
    news: [NewsEvent],
    researchPlan: AnalystResearchPlan?,
    externalEvidence: [ExternalAnalystEvidenceDocument],
    externalAnchor: String?,
    latestHeadline: String
) -> String {
    let supplementalAssessments = assessSupplementalExternalEvidence(
        news: news,
        externalEvidence: externalEvidence
    )
    let supplementalRollup = summarizeSupplementalExternalEvidence(supplementalAssessments)
    let planningSummary: String
    if let researchPlan {
        let missingInfo = researchPlan.missingInformation.isEmpty
            ? "the worker did not record a specific missing-information list"
            : "the worker identified missing information around \(researchPlan.missingInformation.prefix(2).joined(separator: "; "))"
        let targetSummary = researchPlan.publicTargets.isEmpty
            ? "no additional public-web target was selected"
            : "targeted \(researchPlan.publicTargets.map(\.label).joined(separator: ", "))"
        planningSummary = " After reviewing the app-owned baseline, \(missingInfo) and \(targetSummary)."
    } else {
        planningSummary = ""
    }

    if news.isEmpty && externalEvidence.isEmpty {
        return "No app-owned news or policy-governed external sources were available during this run, so the memo remains a bounded watch-state update."
    }

    if news.isEmpty {
        return "No recent app-owned news items were available, so this memo used \(externalEvidence.count) policy-governed external source(s), led by \(externalAnchor ?? "the first available source"), as a bounded fallback evidence anchor. \(sourceTierSummary(for: externalEvidence))\(planningSummary)"
    }

    if externalEvidence.isEmpty {
        return "This memo is based on \(news.count) recent app-owned news item(s). The latest headline was \(latestHeadline). No additional policy-governed external source was available for corroboration in this run.\(planningSummary)"
    }

    return "This memo starts from \(news.count) recent app-owned news item(s) as the baseline evidence set. The latest app-owned headline was \(latestHeadline). Supplemental external research reviewed \(externalEvidence.count) policy-governed source(s), led by \(externalAnchor ?? "the first available source"). \(sourceTierSummary(for: externalEvidence)) \(supplementalRollup)\(planningSummary)"
}

private func sourceTierSummary(for externalEvidence: [ExternalAnalystEvidenceDocument]) -> String {
    guard externalEvidence.isEmpty == false else {
        return "Source tiers: none."
    }
    let official = externalEvidence.filter { $0.sourceTier == .officialPrimary }.count
    let secondary = externalEvidence.filter { $0.sourceTier == .reputableSecondary }.count
    let missing = externalEvidence.filter { $0.sourceTier == .missingOrRestricted }.count
    var parts: [String] = []
    if official > 0 { parts.append("\(official) official/primary") }
    if secondary > 0 { parts.append("\(secondary) reputable secondary/domain") }
    if missing > 0 { parts.append("\(missing) missing/restricted") }
    return "Source tiers: \(parts.joined(separator: ", "))."
}

private enum SupplementalExternalEvidenceRelation: String, Sendable {
    case fallbackWithoutAppNews = "fallback_without_app_news"
    case duplicateSupport = "duplicate_support"
    case strongerConfirmation = "stronger_confirmation"
    case incrementalContext = "incremental_context"
    case contradictionOrDisconfirmation = "contradiction_or_disconfirmation"
}

private struct SupplementalExternalEvidenceAssessment: Sendable, Equatable {
    let document: ExternalAnalystEvidenceDocument
    let relation: SupplementalExternalEvidenceRelation
    let incrementalValueSummary: String
}

private func assessSupplementalExternalEvidence(
    news: [NewsEvent],
    externalEvidence: [ExternalAnalystEvidenceDocument]
) -> [SupplementalExternalEvidenceAssessment] {
    externalEvidence.map { document in
        assessSupplementalExternalEvidence(document: document, news: news)
    }
}

private func assessSupplementalExternalEvidence(
    document: ExternalAnalystEvidenceDocument,
    news: [NewsEvent]
) -> SupplementalExternalEvidenceAssessment {
    guard !news.isEmpty else {
        return SupplementalExternalEvidenceAssessment(
            document: document,
            relation: .fallbackWithoutAppNews,
            incrementalValueSummary: "No recent app-owned news was available, so this source served as a bounded fallback evidence anchor."
        )
    }

    let documentText = normalizedEvidenceText(
        title: document.title,
        summary: document.summary,
        snippet: document.snippet
    )
    let documentTokens = significantFactTokens(in: documentText)

    let bestBaselineMatch = news.max { lhs, rhs in
        overlapScore(
            lhs: significantFactTokens(in: normalizedEvidenceText(
                title: lhs.title,
                summary: lhs.summary ?? "",
                snippet: ""
            )),
            rhs: documentTokens
        ) < overlapScore(
            lhs: significantFactTokens(in: normalizedEvidenceText(
                title: rhs.title,
                summary: rhs.summary ?? "",
                snippet: ""
            )),
            rhs: documentTokens
        )
    }

    let baselineTokens = significantFactTokens(
        in: normalizedEvidenceText(
            title: bestBaselineMatch?.title ?? "",
            summary: bestBaselineMatch?.summary ?? "",
            snippet: ""
        )
    )
    let overlap = overlapScore(lhs: baselineTokens, rhs: documentTokens)
    let uniqueDocumentTokens = documentTokens.subtracting(baselineTokens)
    let contradiction = containsDisconfirmingLanguage(documentText)
    let primarySourceHint = hasPrimarySourceHint(document: document)

    let relation: SupplementalExternalEvidenceRelation
    let incrementalValueSummary: String

    if contradiction && overlap >= 0.25 {
        relation = .contradictionOrDisconfirmation
        incrementalValueSummary = "This source qualifies or challenges the app-news baseline and should be surfaced as disconfirming evidence rather than repetition."
    } else if overlap >= 0.58 && uniqueDocumentTokens.count <= 4 {
        relation = .duplicateSupport
        incrementalValueSummary = "This source mostly repeats the app-news fact pattern, so it should be compacted into corroboration rather than treated as a separate insight."
    } else if overlap >= 0.42 && (primarySourceHint || uniqueDocumentTokens.count <= 8) {
        relation = .strongerConfirmation
        incrementalValueSummary = "This source confirms the app-news baseline with stronger or more primary sourcing and adds only limited extra detail."
    } else {
        relation = .incrementalContext
        incrementalValueSummary = "This source adds incremental timing, background, or strategic/risk context beyond the app-news baseline."
    }

    return SupplementalExternalEvidenceAssessment(
        document: document,
        relation: relation,
        incrementalValueSummary: incrementalValueSummary
    )
}

private func summarizeSupplementalExternalEvidence(
    _ assessments: [SupplementalExternalEvidenceAssessment]
) -> String {
    guard !assessments.isEmpty else {
        return "No supplemental external evidence was available in this run."
    }

    let duplicateCount = assessments.filter { $0.relation == .duplicateSupport }.count
    let strongerCount = assessments.filter { $0.relation == .strongerConfirmation }.count
    let incrementalCount = assessments.filter { $0.relation == .incrementalContext }.count
    let contradictionCount = assessments.filter { $0.relation == .contradictionOrDisconfirmation }.count
    let fallbackCount = assessments.filter { $0.relation == .fallbackWithoutAppNews }.count

    if duplicateCount == assessments.count {
        return "Supplemental external research mostly repeated the same fact pattern as the app-news baseline, so it was compacted into corroborating support rather than treated as separate analysis."
    }

    var parts: [String] = []
    if strongerCount > 0 {
        parts.append("\(strongerCount) source\(strongerCount == 1 ? "" : "s") provided stronger confirmation")
    }
    if incrementalCount > 0 {
        parts.append("\(incrementalCount) added incremental context")
    }
    if contradictionCount > 0 {
        parts.append("\(contradictionCount) introduced disconfirming or qualifying context")
    }
    if duplicateCount > 0 {
        parts.append("\(duplicateCount) overlapping source\(duplicateCount == 1 ? "" : "s") were compacted as corroboration")
    }
    if fallbackCount > 0 {
        parts.append("\(fallbackCount) acted as bounded fallback evidence because no app-owned news baseline was available")
    }

    guard !parts.isEmpty else {
        return "Supplemental external evidence was reviewed, but it added limited incremental value beyond the app-news baseline."
    }
    return "Supplemental external research was kept secondary to the app-news baseline: \(parts.joined(separator: "; "))."
}

private func directLLMWebResearchRollup(newsCount: Int) -> String {
    if newsCount == 0 {
        return "No relevant app-owned news baseline item was available; that absence is context, not a cap on analyst public-web research."
    }
    return "Relevant app-owned news was baseline context only; direct analyst runtime web search remained responsible for task-specific outside research."
}

private func compactExternalEvidenceRefSummary(
    document: ExternalAnalystEvidenceDocument,
    assessment: SupplementalExternalEvidenceAssessment
) -> String {
    let base = document.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    let tierPrefix = "Source tier: \(document.sourceTier.displayTitle)."
    if base.isEmpty {
        return "\(tierPrefix) \(assessment.incrementalValueSummary)"
    }
    return "\(tierPrefix) \(base) Supplemental role: \(assessment.incrementalValueSummary)"
}

private func normalizedEvidenceText(title: String, summary: String, snippet: String) -> String {
    "\(title) \(summary) \(snippet)"
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func significantFactTokens(in text: String) -> Set<String> {
    let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "into", "after", "before", "about",
        "company", "companies", "market", "markets", "stock", "stocks", "share", "shares", "says",
        "said", "report", "reports", "reporting", "news", "update", "latest", "more", "than", "over",
        "under", "through", "their", "there", "while", "where", "when", "have", "has", "had", "were",
        "was", "are", "will", "would", "could", "should", "also", "amid"
    ]

    return Set(
        text
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                token.count >= 4 && stopWords.contains(token) == false
            }
    )
}

private func overlapScore(lhs: Set<String>, rhs: Set<String>) -> Double {
    guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
    let intersection = lhs.intersection(rhs).count
    let denominator = max(1, min(lhs.count, rhs.count))
    return Double(intersection) / Double(denominator)
}

private func containsDisconfirmingLanguage(_ text: String) -> Bool {
    let keywords = [
        "contradict", "disconfirm", "deny", "denies", "walk back", "walks back", "cuts guidance",
        "delayed", "delay", "reversed", "reverses", "slower than expected", "missed", "shortfall"
    ]
    return keywords.contains { text.contains($0) }
}

private func hasPrimarySourceHint(document: ExternalAnalystEvidenceDocument) -> Bool {
    let note = document.provenanceNote.lowercased()
    let host = URL(string: document.url)?.host?.lowercased() ?? ""
    return note.contains("official")
        || note.contains("regulator")
        || note.contains("issuer")
        || host.contains("sec.gov")
        || host.contains("investor")
        || host.contains("ir.")
        || host.contains("earnings")
}

private func makeUncertaintySummary(
    finding: AnalystFinding,
    externalIssueText: String?,
    externalEvidenceCount: Int
) -> String {
    var parts: [String] = []

    if let timeHorizon = finding.timeHorizon, !timeHorizon.isEmpty {
        parts.append("This is currently framed as a \(timeHorizon) view rather than a settled long-term conclusion.")
    }

    if let externalIssueText, !externalIssueText.isEmpty {
        parts.append("External evidence was degraded during this run (\(externalIssueText)), which limits corroboration and should keep confidence bounded.")
    } else if externalEvidenceCount == 0 {
        parts.append("No policy-governed external evidence was available, so corroboration is thinner than ideal.")
    }

    parts.append("Disconfirming evidence on adoption timing, integration friction, power availability, regulation, and monetization should continue to be monitored before escalation.")
    return parts.joined(separator: " ")
}

private func makeRecommendedNextStep(
    finding: AnalystFinding,
    externalIssueText: String?,
    externalEvidenceCount: Int
) -> String {
    if let externalIssueText, !externalIssueText.isEmpty {
        return "Treat this as a research memo, refresh policy-governed external evidence, and re-run before escalating to a stronger PM recommendation. Current degradation: \(externalIssueText)."
    }

    if externalEvidenceCount == 0 {
        return "Keep the thesis in monitored review and gather another policy-governed external source before escalating beyond PM review."
    }

    if finding.confidence >= 0.7 {
        return "Use this memo as readable analyst support for PM review, then decide whether a downstream signal or proposal step is warranted."
    }

    return "Keep the task active, gather another evidence cycle, and look for disconfirming evidence before making a stronger recommendation."
}

private func extractFirstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
        return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range),
          match.numberOfRanges > 1,
          let valueRange = Range(match.range(at: 1), in: text) else {
        return nil
    }
    return String(text[valueRange])
}

private func cleanHTMLText(_ text: String) -> String? {
    let noTags = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    let decoded = noTags
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
    let collapsed = decoded
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return collapsed.isEmpty ? nil : collapsed
}

private func isMeaningfulExternalEvidenceText(_ text: String?) -> Bool {
    guard let text, !text.isEmpty else { return false }
    let scalars = Array(text.unicodeScalars)
    guard !scalars.isEmpty else { return false }

    let printableCount = scalars.filter { !CharacterSet.controlCharacters.contains($0) }.count
    let printableRatio = Double(printableCount) / Double(scalars.count)
    guard printableRatio >= 0.85 else { return false }

    let letterCount = scalars.filter { CharacterSet.letters.contains($0) }.count
    let whitespaceCount = scalars.filter { CharacterSet.whitespacesAndNewlines.contains($0) }.count
    return text.count >= 24 && letterCount >= 12 && whitespaceCount >= 2
}

private func parseHTTPDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
    return formatter.date(from: value)
}

private func externalEvidenceStatus(
    documents: [ExternalAnalystEvidenceDocument],
    issues: [AnalystExternalEvidenceIssue]
) -> String {
    if issues.isEmpty {
        return "ok"
    }
    return documents.isEmpty ? "degraded" : "partial"
}

private func externalEvidenceIssueSummary(_ issues: [AnalystExternalEvidenceIssue]) -> String? {
    guard !issues.isEmpty else { return nil }
    return issues
        .prefix(2)
        .map(\.boundedSummary)
        .joined(separator: " | ")
}

private func stableIdentifier(prefix: String, components: [String]) -> String {
    let sanitized = components
        .joined(separator: "-")
        .lowercased()
        .unicodeScalars
        .map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }

    let collapsed = String(sanitized)
        .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    let suffix = collapsed.isEmpty ? "item" : String(collapsed.prefix(96))
    return "\(prefix)-\(suffix)"
}

private func stableHashedIdentifier(prefix: String, components: [String]) -> String {
    let joined = components.joined(separator: "-")
    let readablePrefix = stableIdentifier(prefix: prefix, components: components)
    let hash = fnv1aHex(joined)
    return "\(readablePrefix)-\(hash)"
}

private func fnv1aHex(_ value: String) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    let full = String(hash, radix: 16, uppercase: false)
    return String(full.suffix(8))
}
