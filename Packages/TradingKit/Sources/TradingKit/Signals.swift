import Foundation

public enum SignalStatus: String, Codable, Sendable, CaseIterable {
    case new
    case acknowledged
    case archived
}

public enum SignalDirection: String, Codable, Sendable, CaseIterable {
    case bullish
    case bearish
    case neutral
}

public enum SignalHorizon: String, Codable, Sendable, CaseIterable {
    case intraday
    case swing
    case longTerm = "long_term"
}

public enum SignalRecommendedAction: String, Codable, Sendable, CaseIterable {
    case draftProposal = "draft_proposal"
    case notifyOnly = "notify_only"
}

public enum SignalActionability: String, Codable, Sendable, CaseIterable {
    case ownerActionable = "owner_actionable"
    case pmReview = "pm_review"
    case monitorOnly = "monitor_only"
    case notifyOnly = "notify_only"
    case proposalCandidate = "proposal_candidate"
    case closed
}

public extension SignalActionability {
    var displayTitle: String {
        switch self {
        case .ownerActionable:
            return "Owner Review"
        case .pmReview:
            return "PM Review"
        case .monitorOnly:
            return "Monitor Only"
        case .notifyOnly:
            return "FYI Only"
        case .proposalCandidate:
            return "Proposal Candidate"
        case .closed:
            return "Closed"
        }
    }

    var ownerSummary: String {
        switch self {
        case .ownerActionable:
            return "This signal is meant for owner review, but it still does not approve or authorize trading."
        case .pmReview:
            return "This signal is PM review material, not a direct owner decision."
        case .monitorOnly:
            return "This signal should stay in monitoring context unless promoted later."
        case .notifyOnly:
            return "This is an FYI research alert and should not inflate owner decision work."
        case .proposalCandidate:
            return "This signal may support proposal drafting, but any proposal still requires normal review and approval gates."
        case .closed:
            return "This signal has been acknowledged or archived and remains traceable history."
        }
    }
}

public enum SignalEvidenceType: String, Codable, Sendable, CaseIterable {
    case news
    case market
    case finding
    case external
}

public struct SignalEvidenceRef: Codable, Sendable, Equatable {
    public let type: SignalEvidenceType
    public let id: String?
    public let url: String?
    public let title: String
    public let summary: String?
    public let timestamp: Date

    public init(
        type: SignalEvidenceType,
        id: String? = nil,
        url: String? = nil,
        title: String,
        summary: String? = nil,
        timestamp: Date
    ) {
        self.type = type
        self.id = id
        self.url = url
        self.title = title
        self.summary = summary
        self.timestamp = timestamp
    }
}

public struct SignalProvenance: Codable, Sendable, Equatable {
    public let sourceJobId: String?
    public let scoringVersion: String
    public let analystId: String?
    public let charterId: String?
    public let taskId: String?
    public let sourceFindingId: String?
    public let sourceEvidenceBundleId: String?

    public init(
        sourceJobId: String?,
        scoringVersion: String,
        analystId: String? = nil,
        charterId: String? = nil,
        taskId: String? = nil,
        sourceFindingId: String? = nil,
        sourceEvidenceBundleId: String? = nil
    ) {
        self.sourceJobId = sourceJobId
        self.scoringVersion = scoringVersion
        self.analystId = analystId
        self.charterId = charterId
        self.taskId = taskId
        self.sourceFindingId = sourceFindingId
        self.sourceEvidenceBundleId = sourceEvidenceBundleId
    }
}

public struct AnalystSignalLineage: Sendable, Equatable {
    public let analystId: String?
    public let charterId: String?
    public let taskId: String?
    public let findingId: String?
    public let evidenceBundleId: String?

    public init(
        analystId: String?,
        charterId: String?,
        taskId: String?,
        findingId: String?,
        evidenceBundleId: String?
    ) {
        self.analystId = analystId
        self.charterId = charterId
        self.taskId = taskId
        self.findingId = findingId
        self.evidenceBundleId = evidenceBundleId
    }
}

public struct SignalTechnicalLineageRef: Sendable, Equatable, Identifiable {
    public var id: String { label }

    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct SignalLineageReadablePresentation: Sendable, Equatable {
    public let analystLabel: String
    public let charterLabel: String
    public let taskLabel: String
    public let findingLabel: String
    public let evidenceLabel: String
    public let technicalRefs: [SignalTechnicalLineageRef]

    public init(
        analystLabel: String,
        charterLabel: String,
        taskLabel: String,
        findingLabel: String,
        evidenceLabel: String,
        technicalRefs: [SignalTechnicalLineageRef]
    ) {
        self.analystLabel = analystLabel
        self.charterLabel = charterLabel
        self.taskLabel = taskLabel
        self.findingLabel = findingLabel
        self.evidenceLabel = evidenceLabel
        self.technicalRefs = technicalRefs
    }
}

public struct Signal: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        signalId
    }

    public var signalId: String
    public var createdAt: Date
    public var updatedAt: Date
    public var status: SignalStatus
    public var symbols: [String]
    public var direction: SignalDirection
    public var horizon: SignalHorizon
    public var confidence: Double
    public var score: Double
    public var positionStatement: String
    public var recommendedAction: SignalRecommendedAction
    public var evidence: [SignalEvidenceRef]
    public var provenance: SignalProvenance
    public var originatingFindingId: String?
    public var draftedProposalId: String?
    public var linkedProposalId: String?

    public init(
        signalId: String,
        createdAt: Date,
        updatedAt: Date,
        status: SignalStatus = .new,
        symbols: [String],
        direction: SignalDirection,
        horizon: SignalHorizon,
        confidence: Double,
        score: Double,
        positionStatement: String,
        recommendedAction: SignalRecommendedAction,
        evidence: [SignalEvidenceRef],
        provenance: SignalProvenance,
        originatingFindingId: String? = nil,
        draftedProposalId: String? = nil,
        linkedProposalId: String? = nil
    ) {
        self.signalId = signalId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.symbols = symbols
        self.direction = direction
        self.horizon = horizon
        self.confidence = min(max(confidence, 0), 1)
        self.score = score
        self.positionStatement = positionStatement
        self.recommendedAction = recommendedAction
        self.evidence = evidence
        self.provenance = provenance
        self.originatingFindingId = originatingFindingId
        self.draftedProposalId = draftedProposalId
        self.linkedProposalId = linkedProposalId
    }
}

public extension Signal {
    var proposalLinkId: String? {
        linkedProposalId ?? draftedProposalId
    }

    var analystLineage: AnalystSignalLineage? {
        let analystId = provenance.analystId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let charterId = provenance.charterId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let taskId = provenance.taskId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let findingId = originatingFindingId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? provenance.sourceFindingId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let evidenceBundleId = provenance.sourceEvidenceBundleId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        guard analystId != nil
            || charterId != nil
            || taskId != nil
            || findingId != nil
            || evidenceBundleId != nil else {
            return nil
        }

        return AnalystSignalLineage(
            analystId: analystId,
            charterId: charterId,
            taskId: taskId,
            findingId: findingId,
            evidenceBundleId: evidenceBundleId
        )
    }

    var isAnalystOriginated: Bool {
        analystLineage != nil
    }

    var actionability: SignalActionability {
        switch status {
        case .acknowledged, .archived:
            return .closed
        case .new:
            break
        }

        if proposalLinkId != nil {
            return .proposalCandidate
        }

        if recommendedAction == .draftProposal {
            return direction == .neutral ? .pmReview : .proposalCandidate
        }

        if direction == .neutral || confidence < 0.5 || score < 0.5 {
            return .notifyOnly
        }

        return isAnalystOriginated ? .pmReview : .monitorOnly
    }

    var countsAsOwnerFacingSignalReview: Bool {
        guard status == .new,
              isSuppressedPMTestingSignal(self) == false else {
            return false
        }

        switch actionability {
        case .ownerActionable, .proposalCandidate:
            return true
        case .pmReview, .monitorOnly, .notifyOnly, .closed:
            return false
        }
    }

    var countsAsFYIResearchAlert: Bool {
        guard status == .new,
              isSuppressedPMTestingSignal(self) == false else {
            return false
        }
        return countsAsOwnerFacingSignalReview == false
    }
}

public func makeSignalLineageReadablePresentation(
    signal: Signal,
    charters: [AnalystCharter] = [],
    tasks: [AnalystTask] = [],
    findings: [AnalystFinding] = [],
    evidenceBundles: [AnalystEvidenceBundle] = []
) -> SignalLineageReadablePresentation? {
    guard let lineage = signal.analystLineage else {
        return nil
    }

    let task = lineage.taskId.flatMap { taskID in
        tasks.first(where: { $0.taskId == taskID })
    }
    let finding = lineage.findingId.flatMap { findingID in
        findings.first(where: { $0.findingId == findingID })
    }
    let bundle = lineage.evidenceBundleId.flatMap { bundleID in
        evidenceBundles.first(where: { $0.bundleId == bundleID })
    }
    let charter = lineage.charterId.flatMap { charterID in
        charters.first(where: { $0.charterId == charterID })
    } ?? task?.charterId.flatMap { charterID in
        charters.first(where: { $0.charterId == charterID })
    } ?? finding?.charterId.flatMap { charterID in
        charters.first(where: { $0.charterId == charterID })
    }

    let analystLabel = task?.analystId
        ?? finding?.analystId
        ?? bundle?.analystId
        ?? lineage.analystId
        ?? "Analyst unavailable (reference retained)"

    let charterLabel: String
    if let charter {
        charterLabel = charter.title
    } else if lineage.charterId != nil {
        charterLabel = "Charter unavailable (reference retained)"
    } else {
        charterLabel = "No charter reference recorded"
    }

    let taskLabel: String
    if let task {
        let symbolText = task.symbols.isEmpty ? "" : " • \(task.symbols.joined(separator: ", "))"
        taskLabel = "\(task.title)\(symbolText)"
    } else if lineage.taskId != nil {
        taskLabel = "Task unavailable (reference retained)"
    } else {
        taskLabel = "No task reference recorded"
    }

    let findingLabel: String
    if let finding {
        findingLabel = "\(finding.title): \(boundedSignalLineageText(finding.summary, limit: 180))"
    } else if lineage.findingId != nil {
        findingLabel = "Finding unavailable (reference retained)"
    } else {
        findingLabel = "No finding reference recorded"
    }

    let evidenceLabel: String
    if let bundle {
        let titles = bundle.refs.prefix(3).map(\.title).filter { $0.isEmpty == false }
        if titles.isEmpty {
            evidenceLabel = boundedSignalLineageText(bundle.summary, limit: 220)
        } else {
            evidenceLabel = "\(boundedSignalLineageText(bundle.summary, limit: 160)) Sources: \(titles.joined(separator: "; "))"
        }
    } else if lineage.evidenceBundleId != nil {
        evidenceLabel = "Evidence bundle unavailable (reference retained)"
    } else {
        evidenceLabel = "No evidence bundle reference recorded"
    }

    let technicalRefs = [
        ("Analyst ID", lineage.analystId),
        ("Charter ID", lineage.charterId),
        ("Task ID", lineage.taskId),
        ("Finding ID", lineage.findingId),
        ("Evidence Bundle ID", lineage.evidenceBundleId)
    ].compactMap { label, value in
        value.map { SignalTechnicalLineageRef(label: label, value: $0) }
    }

    return SignalLineageReadablePresentation(
        analystLabel: analystLabel,
        charterLabel: charterLabel,
        taskLabel: taskLabel,
        findingLabel: findingLabel,
        evidenceLabel: evidenceLabel,
        technicalRefs: technicalRefs
    )
}

public func pmConversationAskNeedsSignalTruth(_ ask: String) -> Bool {
    let normalized = ask
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let tokens = Set(normalized.split(separator: " ").map(String.init))
    if tokens.contains("signal") || tokens.contains("signals") {
        return true
    }
    return normalized.contains("research alert")
        || normalized.contains("research alerts")
        || normalized.contains("fyi alert")
        || normalized.contains("actionable")
        || normalized.contains("notify only")
}

public func makePMConversationSignalTruthSummary(
    ask: String,
    signals: [Signal],
    now: Date = Date(),
    limit: Int = 8
) -> [String] {
    guard pmConversationAskNeedsSignalTruth(ask) else {
        return []
    }

    let visible = signals
        .filter { isSuppressedPMTestingSignal($0, now: now) == false }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.signalId < rhs.signalId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    let active = visible.filter { $0.status == .new }
    let ownerReviewCount = active.filter(\.countsAsOwnerFacingSignalReview).count
    let fyiCount = active.filter(\.countsAsFYIResearchAlert).count
    let closedCount = visible.filter { $0.status == .acknowledged || $0.status == .archived }.count

    var lines: [String] = [
        "Confirmed signal truth: \(active.count) new research alert(s): \(ownerReviewCount) owner-review/proposal-candidate, \(fyiCount) FYI/monitor-only/PM-review. \(closedCount) acknowledged or archived signal(s) remain traceable history.",
        "Signal semantics: signals are operationalized research alerts. Notify-only, neutral, or low-confidence signals are not owner decisions, trade recommendations, approvals, or execution authority."
    ]

    for signal in active.prefix(max(0, limit)) {
        let symbols = signal.symbols.isEmpty ? "no symbols" : signal.symbols.joined(separator: ",")
        lines.append(
            "Signal \(shortSignalTruthID(signal.signalId)) \(symbols): status=\(signal.status.rawValue), actionability=\(signal.actionability.rawValue), action=\(signal.recommendedAction.rawValue), direction=\(signal.direction.rawValue), confidence=\(signalPercent(signal.confidence)), score=\(signalPercent(signal.score)); \(boundedSignalLineageText(signal.positionStatement, limit: 180))"
        )
    }

    if active.isEmpty {
        lines.append("No new signals are currently active in app-owned signal truth.")
    }

    return lines
}

public func isSuppressedPMTestingSignal(
    _ signal: Signal,
    now: Date = Date()
) -> Bool {
    if isExerciseArtifactIdentifier(signal.signalId) {
        return true
    }

    guard signal.status == .new,
          signal.proposalLinkId == nil,
          signal.provenance.sourceJobId == "analyst.finding_draft",
          signal.signalId.matches("^sig-finding-[0-9]+$"),
          signal.createdAt < now.addingTimeInterval(-30 * 24 * 60 * 60)
    else {
        return false
    }

    let placeholderLineage = [
        (signal.provenance.charterId, "^charter-[0-9]+$"),
        (signal.provenance.taskId, "^task-[0-9]+$"),
        (signal.provenance.sourceFindingId, "^finding-[0-9]+$"),
        (signal.provenance.sourceEvidenceBundleId, "^bundle-[0-9]+$")
    ]

    return placeholderLineage.allSatisfy { value, pattern in
        value?.matches(pattern) == true
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}

private func boundedSignalLineageText(_ text: String, limit: Int) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > limit else {
        return trimmed
    }
    let index = trimmed.index(trimmed.startIndex, offsetBy: max(0, limit - 1))
    return String(trimmed[..<index]) + "..."
}

private func shortSignalTruthID(_ id: String) -> String {
    String(id.prefix(8))
}

private func signalPercent(_ value: Double) -> String {
    String(format: "%.0f%%", value * 100)
}

public enum AnalystFindingSignalDraftError: Error, Sendable, Equatable {
    case ineligibleFinding(id: String, reason: String)
}

public enum AnalystSignalProposalDraftError: Error, Sendable, Equatable {
    case ineligibleSignal(id: String, reason: String)
}

public struct SignalScoringInput: Sendable {
    public let recentNews: [NewsEvent]
    public let snapshot: StoreSnapshot
    public let now: Date
    public let sourceJobId: String?
    public let scoringVersion: String
    public let draftThreshold: Double

    public init(
        recentNews: [NewsEvent],
        snapshot: StoreSnapshot,
        now: Date,
        sourceJobId: String?,
        scoringVersion: String,
        draftThreshold: Double
    ) {
        self.recentNews = recentNews
        self.snapshot = snapshot
        self.now = now
        self.sourceJobId = sourceJobId
        self.scoringVersion = scoringVersion
        self.draftThreshold = draftThreshold
    }
}

public protocol ScoringEngine: Sendable {
    func generateSignals(input: SignalScoringInput) -> [Signal]
}

public struct DefaultScoringEngine: ScoringEngine {
    public init() {}

    public func generateSignals(input: SignalScoringInput) -> [Signal] {
        let watchlist = Set(input.snapshot.watchlistSymbols)
        let events = input.recentNews.sorted { lhs, rhs in
            if lhs.publishedAt == rhs.publishedAt {
                return lhs.eventId < rhs.eventId
            }
            return lhs.publishedAt > rhs.publishedAt
        }

        var signals: [Signal] = []
        for event in events {
            let symbols = resolvedSymbols(for: event, watchlist: watchlist)
            guard !symbols.isEmpty else {
                continue
            }
            for symbol in symbols {
                if let signal = buildSignal(
                    event: event,
                    symbol: symbol,
                    input: input
                ) {
                    signals.append(signal)
                }
            }
        }

        return signals.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.signalId < rhs.signalId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func buildSignal(
        event: NewsEvent,
        symbol: String,
        input: SignalScoringInput
    ) -> Signal? {
        let recencyHours = max(0, input.now.timeIntervalSince(event.publishedAt) / 3_600)
        let recencyWeight = max(0, 1 - min(recencyHours / 24, 1))

        let quote = input.snapshot.quotesBySymbol[symbol]
            ?? input.snapshot.optionQuotesBySymbol[symbol]
        let move = marketMove(quote: quote)
        let moveScore = min(1, abs(move) * 20)
        let score = min(1, (0.65 * recencyWeight) + (0.35 * moveScore))
        let confidence = min(max(score, 0), 1)
        let direction = resolvedDirection(move: move, text: event.title + " " + (event.summary ?? ""))
        let action: SignalRecommendedAction = score >= input.draftThreshold ? .draftProposal : .notifyOnly

        let scoreText = String(format: "%.2f", score)
        let moveText = String(format: "%.2f%%", move * 100)
        let statement = "News signal for \(symbol): \(event.title). Recent move \(moveText). Score \(scoreText)."

        var evidence: [SignalEvidenceRef] = [
            SignalEvidenceRef(
                type: .news,
                id: event.eventId,
                url: event.url,
                title: event.title,
                summary: event.summary,
                timestamp: event.publishedAt
            )
        ]
        if let quote {
            evidence.append(
                SignalEvidenceRef(
                    type: .market,
                    id: symbol,
                    url: nil,
                    title: "Market snapshot \(symbol)",
                    summary: marketSummary(quote: quote),
                    timestamp: parseTimestamp(quote.timestamp) ?? input.now
                )
            )
        }

        let signalID = "sig_" + stableHash(
            "\(input.scoringVersion)|\(symbol)|\(event.eventId)"
        )
        return Signal(
            signalId: signalID,
            createdAt: input.now,
            updatedAt: input.now,
            status: .new,
            symbols: [symbol],
            direction: direction,
            horizon: .intraday,
            confidence: confidence,
            score: score,
            positionStatement: statement,
            recommendedAction: action,
            evidence: evidence,
            provenance: SignalProvenance(
                sourceJobId: input.sourceJobId,
                scoringVersion: input.scoringVersion
            )
        )
    }

    private func resolvedSymbols(
        for event: NewsEvent,
        watchlist: Set<String>
    ) -> [String] {
        let hints = Set(event.rawSymbolHints.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }.filter { !$0.isEmpty })
        let extracted = extractTickers(from: event.title + " " + (event.summary ?? ""))
        let combined = hints.union(extracted)
        if combined.isEmpty {
            return []
        }
        if watchlist.isEmpty {
            return combined.sorted()
        }
        let filtered = combined.intersection(watchlist)
        return filtered.sorted()
    }

    private func extractTickers(from text: String) -> Set<String> {
        let pattern = #"\b[A-Z]{1,5}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(location: 0, length: (text as NSString).length)
        let matches = regex.matches(in: text, options: [], range: range)
        return Set(matches.compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else {
                return nil
            }
            let value = String(text[swiftRange]).uppercased()
            return value.count <= 1 ? nil : value
        })
    }

    private func marketMove(quote: MarketQuote?) -> Double {
        guard let quote else {
            return 0
        }
        guard let last = quote.lastPrice else {
            return 0
        }
        if let bid = quote.bidPrice, let ask = quote.askPrice {
            let mid = (bid + ask) / 2
            guard mid > 0 else {
                return 0
            }
            return (last - mid) / mid
        }
        guard let bid = quote.bidPrice ?? quote.askPrice, bid > 0 else {
            return 0
        }
        return (last - bid) / bid
    }

    private func resolvedDirection(
        move: Double,
        text: String
    ) -> SignalDirection {
        if move > 0.002 {
            return .bullish
        }
        if move < -0.002 {
            return .bearish
        }

        let lower = text.lowercased()
        let bullishTerms = ["beats", "upgrade", "approval", "surge", "record high"]
        if bullishTerms.contains(where: { lower.contains($0) }) {
            return .bullish
        }
        let bearishTerms = ["downgrade", "probe", "lawsuit", "misses", "cuts guidance"]
        if bearishTerms.contains(where: { lower.contains($0) }) {
            return .bearish
        }
        return .neutral
    }

    private func marketSummary(quote: MarketQuote) -> String {
        let bid = quote.bidPrice.map { String(format: "%.4f", $0) } ?? "-"
        let ask = quote.askPrice.map { String(format: "%.4f", $0) } ?? "-"
        let last = quote.lastPrice.map { String(format: "%.4f", $0) } ?? "-"
        return "bid=\(bid) ask=\(ask) last=\(last)"
    }

    private func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return DateCodec.parseISO8601(raw)
    }

    private func stableHash(_ text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return String(hash, radix: 16)
    }
}
