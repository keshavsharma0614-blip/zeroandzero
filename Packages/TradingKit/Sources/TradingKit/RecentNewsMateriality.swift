import Foundation

struct RecentNewsMaterialityMatch: Sendable, Equatable {
    let eventId: String
    let title: String
    let source: String
    let publishedAt: Date
    let impactedHeldSymbols: [String]
    let impactedWatchlistOnlySymbols: [String]
    let reasons: [String]
    let score: Int
}

enum RecentNewsClusterNovelty: String, Sendable, Equatable {
    case corroboratingPickup = "corroborating_pickup"
    case materiallyAdditiveUpdate = "materially_additive_update"
    case disconfirmingUpdate = "disconfirming_update"

    var summaryText: String {
        switch self {
        case .corroboratingPickup:
            return "Later pickup mostly corroborated the same event rather than changing the meaning."
        case .materiallyAdditiveUpdate:
            return "Later coverage added material context beyond the first headline."
        case .disconfirmingUpdate:
            return "Later coverage materially changed or qualified the original read."
        }
    }
}

enum RecentNewsEscalationDisposition: String, Sendable, Equatable, Comparable {
    case quiet = "quiet"
    case worthMonitoring = "worth_monitoring"
    case pmFollowUpWarranted = "pm_follow_up_warranted"
    case ownerRelevantStrategicConcern = "owner_relevant_strategic_concern"

    private var rank: Int {
        switch self {
        case .quiet:
            return 0
        case .worthMonitoring:
            return 1
        case .pmFollowUpWarranted:
            return 2
        case .ownerRelevantStrategicConcern:
            return 3
        }
    }

    static func < (lhs: RecentNewsEscalationDisposition, rhs: RecentNewsEscalationDisposition) -> Bool {
        lhs.rank < rhs.rank
    }

    var summaryText: String {
        switch self {
        case .quiet:
            return "quiet / non-material"
        case .worthMonitoring:
            return "worth monitoring"
        case .pmFollowUpWarranted:
            return "PM follow-up warranted"
        case .ownerRelevantStrategicConcern:
            return "owner-relevant strategic concern"
        }
    }
}

struct RecentNewsEventCluster: Sendable, Equatable {
    let clusterKey: String
    let fingerprintSeed: String
    let canonicalTitle: String
    let eventIds: [String]
    let eventCount: Int
    let sourceCount: Int
    let impactedHeldSymbols: [String]
    let impactedWatchlistOnlySymbols: [String]
    let reasons: [String]
    let score: Int
    let novelty: RecentNewsClusterNovelty
    let summary: String
    let whyNow: String
}

struct RecentNewsMaterialityEvaluation: Sendable, Equatable {
    let consideredNewsCount: Int
    let candidateMatches: [RecentNewsMaterialityMatch]
    let eventClusters: [RecentNewsEventCluster]
    let escalationDisposition: RecentNewsEscalationDisposition
    let impactedHeldSymbols: [String]
    let impactedWatchlistOnlySymbols: [String]
    let coverageSummary: String
    let whyNowSummary: String
    let bookPostureSummary: String?
    let summary: String
    let rationale: String

    var isMaterial: Bool {
        escalationDisposition >= .pmFollowUpWarranted
    }

    var candidateEventIDs: [String] {
        candidateMatches.map(\.eventId)
    }

    var primaryCluster: RecentNewsEventCluster? {
        eventClusters.first
    }
}

enum RecentNewsMaterialityEvaluator {
    private struct EventAnalysis: Sendable {
        let match: RecentNewsMaterialityMatch
        let sourceClass: String
        let primaryCategory: String
        let categoryComponents: [String]
        let clusterTerms: [String]
        let additiveSignals: Set<String>
        let disconfirmingSignals: Set<String>
    }

    static func evaluate(
        recentNews: [NewsEvent],
        positions: [PositionRow],
        watchlistSymbols: [String],
        strategyBrief: PortfolioStrategyBrief?
    ) -> RecentNewsMaterialityEvaluation {
        let heldSymbols = Set(
            positions
                .map(\.symbol)
                .map(normalizedSymbol(_:))
                .filter { $0.isEmpty == false }
        )
        let watchSymbols = Set(
            watchlistSymbols
                .map(normalizedSymbol(_:))
                .filter { $0.isEmpty == false }
        )

        let scopeSymbols = heldSymbols.isEmpty ? watchSymbols : heldSymbols.union(watchSymbols)
        let considered = recentNews
            .filter { event in
                Set(event.rawSymbolHints.map(normalizedSymbol(_:))).intersection(scopeSymbols).isEmpty == false
            }
            .sorted { lhs, rhs in
                if lhs.publishedAt == rhs.publishedAt {
                    return lhs.eventId < rhs.eventId
                }
                return lhs.publishedAt > rhs.publishedAt
            }

        let analyses = considered.compactMap { event -> EventAnalysis? in
            let eventSymbols = Set(event.rawSymbolHints.map(normalizedSymbol(_:)))
            let impactedHeld = Array(eventSymbols.intersection(heldSymbols)).sorted()
            let impactedWatchOnly = Array(eventSymbols.intersection(watchSymbols).subtracting(heldSymbols)).sorted()
            if impactedHeld.isEmpty && impactedWatchOnly.isEmpty {
                return nil
            }

            let text = [
                event.title,
                event.summary ?? "",
                event.tags.joined(separator: " ")
            ]
            .joined(separator: " ")
            .lowercased()

            var score = 0
            var reasons: [String] = []

            if impactedHeld.isEmpty == false {
                score += 2
                reasons.append("direct_holding_exposure")
            } else if heldSymbols.isEmpty == false {
                score += 1
                reasons.append("watchlist_context")
            }

            let sourceClass = sourceClass(for: event.source)
            if sourceClass != "newswire" {
                reasons.append("source_class=\(sourceClass)")
            }

            let filingReason = filingReasonIfMaterial(text: text)
            if let filingReason {
                score += filingReason.score
                reasons.append(filingReason.reason)
            }

            let keywordMatches = materialKeywordMatches(in: text)
            if keywordMatches.isEmpty == false {
                score += 2
                reasons.append("material_keywords=\(keywordMatches.joined(separator: ","))")
            }

            let disconfirmingSignals = Set(disconfirmingKeywordMatches(in: text))
            if disconfirmingSignals.isEmpty == false {
                score += 2
                reasons.append("disconfirming_update=\(disconfirmingSignals.sorted().joined(separator: ","))")
            }

            let additiveSignals = Set(additiveContextKeywordMatches(in: text))
            if additiveSignals.isEmpty == false {
                reasons.append("additive_context=\(additiveSignals.sorted().joined(separator: ","))")
            }

            let strategyMaterialMatches = strategyBriefMatches(
                entries: strategyBrief?.materialDevelopments ?? [],
                in: text
            )
            if strategyMaterialMatches.isEmpty == false {
                score += 1
                reasons.append("strategy_brief_material=\(strategyMaterialMatches.joined(separator: ","))")
            }

            let strategyNonMaterialMatches = strategyBriefMatches(
                entries: strategyBrief?.nonMaterialDevelopments ?? [],
                in: text
            )
            if strategyNonMaterialMatches.isEmpty == false,
               filingReason == nil,
               keywordMatches.isEmpty,
               disconfirmingSignals.isEmpty {
                score -= 1
                reasons.append("strategy_brief_non_material=\(strategyNonMaterialMatches.joined(separator: ","))")
            }

            if score < 3 {
                return nil
            }

            let categoryComponents = Array(
                Set(
                    [filingReason?.reason]
                        .compactMap { $0 }
                        + keywordMatches
                        + disconfirmingSignals.map { "disconfirming:\($0)" }
                )
            )
            .sorted()

            let primaryCategory = categoryComponents.first ?? "material_event"
            let clusterTerms = clusterTerms(
                title: event.title,
                summary: event.summary,
                symbols: eventSymbols
            )

            return EventAnalysis(
                match: RecentNewsMaterialityMatch(
                    eventId: event.eventId,
                    title: event.title,
                    source: event.source,
                    publishedAt: event.publishedAt,
                    impactedHeldSymbols: impactedHeld,
                    impactedWatchlistOnlySymbols: impactedWatchOnly,
                    reasons: reasons,
                    score: score
                ),
                sourceClass: sourceClass,
                primaryCategory: primaryCategory,
                categoryComponents: categoryComponents,
                clusterTerms: clusterTerms,
                additiveSignals: additiveSignals,
                disconfirmingSignals: disconfirmingSignals
            )
        }

        let matches = analyses.map(\.match)

        if analyses.isEmpty {
            return RecentNewsMaterialityEvaluation(
                consideredNewsCount: considered.count,
                candidateMatches: [],
                eventClusters: [],
                escalationDisposition: .quiet,
                impactedHeldSymbols: [],
                impactedWatchlistOnlySymbols: [],
                coverageSummary: "No coherent material event cluster emerged from the current recent-news window.",
                whyNowSummary: "No recent normalized news item crossed the bounded PM follow-up threshold for the current portfolio/watch context.",
                bookPostureSummary: nil,
                summary: "recent_news_analyst: considered=\(considered.count) no_material_impact",
                rationale: "No recent normalized news item crossed the bounded material-impact threshold for the current portfolio/watch context."
            )
        }

        let positionWeights = positionWeightsBySymbol(from: positions)
        let clusters = clusterAnalyses(
            analyses,
            positionWeights: positionWeights,
            strategyBrief: strategyBrief
        )
        let primaryCluster = clusters.first
        let held = Array(Set(clusters.flatMap { $0.impactedHeldSymbols })).sorted()
        let watchOnly = Array(Set(clusters.flatMap { $0.impactedWatchlistOnlySymbols })).sorted()
        let disposition = primaryCluster.map {
            classifyDisposition(
                for: $0,
                positionWeights: positionWeights,
                heldSymbolsPresent: heldSymbols.isEmpty == false,
                strategyBrief: strategyBrief
            )
        } ?? .quiet
        let bookPosture = bookPostureSummary(
            positions: positions,
            impactedSymbols: held.isEmpty == false ? held : watchOnly
        )

        if disposition < .pmFollowUpWarranted {
            let reason = primaryCluster.map { cluster in
                "The current cluster around \(cluster.canonicalTitle) is \(disposition.summaryText) rather than a PM wake-up. \(cluster.summary)"
            } ?? "The current recent-news window stayed below the PM follow-up threshold."
            return RecentNewsMaterialityEvaluation(
                consideredNewsCount: considered.count,
                candidateMatches: matches,
                eventClusters: clusters,
                escalationDisposition: disposition,
                impactedHeldSymbols: held,
                impactedWatchlistOnlySymbols: watchOnly,
                coverageSummary: coverageSummary(for: clusters),
                whyNowSummary: primaryCluster?.whyNow ?? reason,
                bookPostureSummary: bookPosture,
                summary: "recent_news_analyst: considered=\(considered.count) disposition=\(disposition.rawValue) no_pm_escalation",
                rationale: reason
            )
        }

        let symbolLead = held.isEmpty == false ? held.joined(separator: ", ") : watchOnly.joined(separator: ", ")
        let headlineLead = clusters.prefix(2).map(\.canonicalTitle).joined(separator: " | ")
        let whyNow = primaryCluster?.whyNow
            ?? "Recent normalized news may have a material impact on \(symbolLead)."

        return RecentNewsMaterialityEvaluation(
            consideredNewsCount: considered.count,
            candidateMatches: matches,
            eventClusters: clusters,
            escalationDisposition: disposition,
            impactedHeldSymbols: held,
            impactedWatchlistOnlySymbols: watchOnly,
            coverageSummary: coverageSummary(for: clusters),
            whyNowSummary: whyNow,
            bookPostureSummary: bookPosture,
            summary: "recent_news_analyst: considered=\(considered.count) clusters=\(clusters.count) disposition=\(disposition.rawValue) symbols=\(symbolLead)",
            rationale: "\(whyNow) Primary cluster(s): \(headlineLead)."
        )
    }

    private static func clusterAnalyses(
        _ analyses: [EventAnalysis],
        positionWeights: [String: Double],
        strategyBrief: PortfolioStrategyBrief?
    ) -> [RecentNewsEventCluster] {
        let grouped = Dictionary(grouping: analyses, by: clusterSeed(for:))

        return grouped.values.map { items in
            let sorted = items.sorted { lhs, rhs in
                if lhs.match.publishedAt == rhs.match.publishedAt {
                    return lhs.match.eventId < rhs.match.eventId
                }
                return lhs.match.publishedAt > rhs.match.publishedAt
            }
            let lead = sorted[0]

            let held = Array(Set(sorted.flatMap { $0.match.impactedHeldSymbols })).sorted()
            let watchOnly = Array(Set(sorted.flatMap { $0.match.impactedWatchlistOnlySymbols })).sorted()
            let sourceClasses = Set(sorted.map(\.sourceClass))
            let mergedReasons = Array(Set(sorted.flatMap { $0.match.reasons })).sorted()
            let score = sorted.map(\.match.score).max() ?? lead.match.score
            let novelty = clusterNovelty(for: sorted)
            let canonicalTitle = lead.match.title
            let fingerprintSeed = clusterFingerprintSeed(
                lead: lead,
                heldSymbols: held,
                watchSymbols: watchOnly,
                novelty: novelty
            )
            let summary = clusterSummary(
                canonicalTitle: canonicalTitle,
                eventCount: sorted.count,
                sourceCount: sourceClasses.count,
                novelty: novelty
            )
            let whyNow = whyNowSummary(
                clusterTitle: canonicalTitle,
                novelty: novelty,
                impactedHeldSymbols: held,
                impactedWatchlistOnlySymbols: watchOnly,
                positionWeights: positionWeights,
                strategyBrief: strategyBrief
            )

            return RecentNewsEventCluster(
                clusterKey: localStableIdentifier(
                    prefix: "recent-news-cluster",
                    components: [canonicalTitle] + held + watchOnly
                ),
                fingerprintSeed: fingerprintSeed,
                canonicalTitle: canonicalTitle,
                eventIds: sorted.map(\.match.eventId),
                eventCount: sorted.count,
                sourceCount: sourceClasses.count,
                impactedHeldSymbols: held,
                impactedWatchlistOnlySymbols: watchOnly,
                reasons: mergedReasons,
                score: score,
                novelty: novelty,
                summary: summary,
                whyNow: whyNow
            )
        }
        .sorted { lhs, rhs in
            let leftDisposition = classifyDisposition(
                for: lhs,
                positionWeights: positionWeights,
                heldSymbolsPresent: heldSymbolsPresent(in: analyses),
                strategyBrief: strategyBrief
            )
            let rightDisposition = classifyDisposition(
                for: rhs,
                positionWeights: positionWeights,
                heldSymbolsPresent: heldSymbolsPresent(in: analyses),
                strategyBrief: strategyBrief
            )
            if leftDisposition != rightDisposition {
                return leftDisposition > rightDisposition
            }
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.canonicalTitle < rhs.canonicalTitle
        }
    }

    private static func heldSymbolsPresent(in analyses: [EventAnalysis]) -> Bool {
        analyses.contains { !$0.match.impactedHeldSymbols.isEmpty }
    }

    private static func clusterSeed(for analysis: EventAnalysis) -> String {
        localStableIdentifier(
            prefix: "cluster",
            components: analysis.match.impactedHeldSymbols
                + analysis.match.impactedWatchlistOnlySymbols
                + Array(analysis.clusterTerms.prefix(4))
        )
    }

    private static func clusterNovelty(for analyses: [EventAnalysis]) -> RecentNewsClusterNovelty {
        if analyses.contains(where: { $0.disconfirmingSignals.isEmpty == false }) {
            return .disconfirmingUpdate
        }
        guard analyses.count > 1 else {
            return .materiallyAdditiveUpdate
        }

        let leadCategories = Set(analyses.first?.categoryComponents ?? [])
        let combinedCategories = Set(analyses.flatMap(\.categoryComponents))
        let combinedAdditiveSignals = Set(analyses.flatMap { $0.additiveSignals })
        let sourceClasses = Set(analyses.map(\.sourceClass))

        if combinedCategories.subtracting(leadCategories).isEmpty == false
            || combinedAdditiveSignals.isEmpty == false
            || sourceClasses.contains("sec_or_regulator") {
            return .materiallyAdditiveUpdate
        }
        return .corroboratingPickup
    }

    private static func classifyDisposition(
        for cluster: RecentNewsEventCluster,
        positionWeights: [String: Double],
        heldSymbolsPresent: Bool,
        strategyBrief: PortfolioStrategyBrief?
    ) -> RecentNewsEscalationDisposition {
        let maxHeldWeight = cluster.impactedHeldSymbols.compactMap { positionWeights[$0] }.max() ?? 0
        let riskPosture = strategyBrief?.currentRiskPosture.lowercased() ?? ""
        let riskSensitive = ["tight", "defensive", "cautious", "elevated", "review"].contains {
            riskPosture.contains($0)
        }
        let touchesHeld = cluster.impactedHeldSymbols.isEmpty == false

        if touchesHeld
            && (cluster.novelty == .disconfirmingUpdate || maxHeldWeight >= 0.25 || (riskSensitive && cluster.score >= 5)) {
            return .ownerRelevantStrategicConcern
        }
        if touchesHeld
            || (cluster.eventCount > 1 && cluster.novelty != .corroboratingPickup)
            || cluster.score >= 5
            || (heldSymbolsPresent == false && cluster.impactedWatchlistOnlySymbols.isEmpty == false && cluster.score >= 5) {
            return .pmFollowUpWarranted
        }
        if cluster.impactedWatchlistOnlySymbols.isEmpty == false {
            return .worthMonitoring
        }
        return .quiet
    }

    private static func coverageSummary(for clusters: [RecentNewsEventCluster]) -> String {
        guard let primary = clusters.first else {
            return "No coherent material event cluster emerged."
        }
        if primary.eventCount == 1 {
            return "One coherent event cluster drove the current read."
        }
        return "\(primary.eventCount) related items were compacted into one coherent event cluster. \(primary.novelty.summaryText)"
    }

    private static func whyNowSummary(
        clusterTitle: String,
        novelty: RecentNewsClusterNovelty,
        impactedHeldSymbols: [String],
        impactedWatchlistOnlySymbols: [String],
        positionWeights: [String: Double],
        strategyBrief: PortfolioStrategyBrief?
    ) -> String {
        let symbols = impactedHeldSymbols.isEmpty == false ? impactedHeldSymbols : impactedWatchlistOnlySymbols
        let symbolLead = symbols.joined(separator: ", ")
        let focus = impactedHeldSymbols.isEmpty == false
            ? "The cluster directly touches current holdings"
            : "The cluster affects current watchlist names"
        let concentrationText: String
        if let largest = impactedHeldSymbols
            .compactMap({ symbol -> (String, Double)? in
                guard let weight = positionWeights[symbol] else {
                    return nil
                }
                return (symbol, weight)
            })
            .max(by: { $0.1 < $1.1 }) {
            concentrationText = "\(largest.0) is \(percentText(largest.1)) of gross exposure."
        } else {
            concentrationText = ""
        }
        let strategyText = strategyBrief?.currentRiskPosture.isEmpty == false
            ? " Current risk posture: \(strategyBrief?.currentRiskPosture ?? "")."
            : ""
        return "\(focus) (\(symbolLead)) around \(clusterTitle). \(novelty.summaryText) \(concentrationText)\(strategyText)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clusterSummary(
        canonicalTitle: String,
        eventCount: Int,
        sourceCount: Int,
        novelty: RecentNewsClusterNovelty
    ) -> String {
        if eventCount == 1 {
            return "One event cluster centered on \"\(canonicalTitle)\" drove the current read."
        }
        return "\(eventCount) items across \(sourceCount) source class(es) collapsed into one event view around \"\(canonicalTitle)\". \(novelty.summaryText)"
    }

    private static func clusterFingerprintSeed(
        lead: EventAnalysis,
        heldSymbols: [String],
        watchSymbols: [String],
        novelty: RecentNewsClusterNovelty
    ) -> String {
        localStableIdentifier(
            prefix: "recent-news",
            components: heldSymbols
                + watchSymbols
                + [lead.primaryCategory, novelty.rawValue]
                + Array(lead.clusterTerms.prefix(4))
        )
    }

    private static func positionWeightsBySymbol(from positions: [PositionRow]) -> [String: Double] {
        let exposures = positions.compactMap { row -> (String, Double)? in
            guard let marketValue = decimalValue(row.marketValue) else {
                return nil
            }
            return (normalizedSymbol(row.symbol), abs((marketValue as NSDecimalNumber).doubleValue))
        }
        let gross = exposures.reduce(0) { $0 + $1.1 }
        guard gross > 0 else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: exposures.map { ($0.0, $0.1 / gross) })
    }

    private static func bookPostureSummary(
        positions: [PositionRow],
        impactedSymbols: [String]
    ) -> String? {
        let exposures = positions.compactMap { row -> (symbol: String, marketValue: Double, isShort: Bool)? in
            guard let marketValue = decimalValue(row.marketValue) else {
                return nil
            }
            return (
                symbol: normalizedSymbol(row.symbol),
                marketValue: abs((marketValue as NSDecimalNumber).doubleValue),
                isShort: row.isShort
            )
        }
        let gross = exposures.reduce(0) { $0 + $1.marketValue }
        guard gross > 0 else {
            return nil
        }
        let longExposure = exposures.reduce(0) { $0 + ($1.isShort ? 0 : $1.marketValue) }
        let shortExposure = exposures.reduce(0) { $0 + ($1.isShort ? $1.marketValue : 0) }
        let largest = exposures.max { lhs, rhs in
            lhs.marketValue < rhs.marketValue
        }
        let impactedLargest = largest.map { largest in
            impactedSymbols.contains(largest.symbol)
                ? " The cluster touches the largest current concentration, \(largest.symbol), at \(percentText(largest.marketValue / gross)) of gross exposure."
                : ""
        } ?? ""
        return "Book posture is \(percentText(longExposure / gross)) long / \(percentText(shortExposure / gross)) short.\(impactedLargest)"
    }

    private static func sourceClass(for source: String) -> String {
        switch source {
        case "sec_edgar", "regulator", "exchange_notice":
            return "sec_or_regulator"
        case let value where value.contains("press") || value.contains("blog") || value.contains("company"):
            return "company_publication"
        case let value where value.contains("news") || value.contains("rss") || value.contains("alpaca"):
            return "newswire"
        default:
            return "other_public_source"
        }
    }

    private static func filingReasonIfMaterial(text: String) -> (score: Int, reason: String)? {
        if text.contains("8-k") || text.contains("6-k") || text.contains("form 4") || text.contains(" filed 4") {
            return (2, "high_signal_sec_filing")
        }
        if text.contains("13d") || text.contains("13g") {
            return (2, "ownership_change_filing")
        }
        if text.contains("10-q") || text.contains("10-k") {
            return (1, "periodic_sec_filing")
        }
        return nil
    }

    private static func materialKeywordMatches(in text: String) -> [String] {
        let keywords = [
            "earnings",
            "guidance",
            "merger",
            "acquisition",
            "bankruptcy",
            "investigation",
            "offering",
            "dividend",
            "buyback",
            "layoff",
            "restructuring",
            "data breach",
            "fraud",
            "ceo",
            "cfo"
        ]
        return keywords.filter { text.contains($0) }
    }

    private static func disconfirmingKeywordMatches(in text: String) -> [String] {
        let keywords = [
            "withdraw",
            "terminate",
            "deny",
            "denied",
            "dispute",
            "reversed",
            "walk back",
            "no longer",
            "suspended"
        ]
        return keywords.filter { text.contains($0) }
    }

    private static func additiveContextKeywordMatches(in text: String) -> [String] {
        let keywords = [
            "presentation",
            "call transcript",
            "investor presentation",
            "slides",
            "outlook",
            "timing",
            "backlog",
            "customer",
            "segment",
            "margin"
        ]
        return keywords.filter { text.contains($0) }
    }

    private static func strategyBriefMatches(entries: [String], in text: String) -> [String] {
        entries.compactMap { entry in
            let tokens = strategyBriefTokens(from: entry)
            guard tokens.isEmpty == false else {
                return nil
            }
            let matched = tokens.contains { text.contains($0) }
            return matched ? entry : nil
        }
    }

    private static func strategyBriefTokens(from entry: String) -> [String] {
        let stopWords: Set<String> = [
            "about", "after", "ahead", "also", "amid", "and", "case", "current", "does",
            "from", "have", "into", "more", "news", "only", "portfolio", "should",
            "that", "than", "their", "them", "then", "they", "this", "what", "when",
            "with", "would"
        ]
        return Array(
            Set(
                entry
                    .lowercased()
                    .split { $0.isWhitespace || $0.isPunctuation }
                    .map(String.init)
                    .filter { $0.count >= 4 && stopWords.contains($0) == false }
            )
        )
        .sorted()
        .prefix(6)
        .map { $0 }
    }

    private static func clusterTerms(title: String, summary: String?, symbols: Set<String>) -> [String] {
        let stopWords: Set<String> = [
            "after", "amid", "from", "into", "that", "this", "with", "says", "said",
            "news", "company", "shares", "stock", "report", "reports", "update", "updates",
            "files", "filed", "inc", "corp", "ltd", "another", "pickup", "repeat", "repeated"
        ]
        let symbolTokens = Set(symbols.map { $0.lowercased() })
        let combined = title.lowercased()
        let tokens = combined
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .map(stemmedToken(_:))
            .filter { token in
                token.count >= 4
                    && stopWords.contains(token) == false
                    && symbolTokens.contains(token) == false
            }
        return Array(Set(tokens)).sorted()
    }

    private static func stemmedToken(_ raw: String) -> String {
        var token = raw
        for suffix in ["ing", "ers", "er", "ed", "es", "s"] {
            if token.count > suffix.count + 2, token.hasSuffix(suffix) {
                token.removeLast(suffix.count)
                break
            }
        }
        return token
    }

    private static func normalizedSymbol(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func decimalValue(_ raw: String) -> Decimal? {
        Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func percentText(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private static func localStableIdentifier(prefix: String, components: [String]) -> String {
        let trimmed = components
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let joined = trimmed.joined(separator: "-")
        let sanitized = joined
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if sanitized.isEmpty {
            return prefix
        }
        return "\(prefix)-\(String(sanitized.prefix(96)))"
    }
}

struct RecentNewsEscalationPlan: Sendable, Equatable {
    let clusterKey: String
    let clusterFingerprint: String
    let taskId: String
    let delegationId: String
    let decisionId: String
    let taskTitle: String
    let taskDescription: String
    let impactedSymbols: [String]
}

enum RecentNewsEscalationPlanner {
    static func makePlan(
        evaluation: RecentNewsMaterialityEvaluation,
        positions: [PositionRow],
        watchlistSymbols: [String],
        strategyBrief: PortfolioStrategyBrief?
    ) -> RecentNewsEscalationPlan {
        let primaryCluster = evaluation.primaryCluster
        let impactedSymbols = primaryCluster.map { cluster in
            cluster.impactedHeldSymbols.isEmpty == false
                ? cluster.impactedHeldSymbols
                : cluster.impactedWatchlistOnlySymbols
        } ?? (
            evaluation.impactedHeldSymbols.isEmpty == false
                ? evaluation.impactedHeldSymbols
                : evaluation.impactedWatchlistOnlySymbols
        )
        let fingerprintComponents = [
            primaryCluster?.fingerprintSeed ?? "recent-news-cluster",
            evaluation.escalationDisposition.rawValue
        ]
        let fingerprint = stableHashedIdentifier(
            prefix: "cluster",
            components: fingerprintComponents
        )

        let heldLines = positions
            .filter { impactedSymbols.contains($0.symbol.uppercased()) }
            .map { "\($0.symbol) \($0.directionLabel) qty \($0.qty) market value \($0.marketValue)" }
        let heldSymbols = Set(
            positions
                .filter { impactedSymbols.contains($0.symbol.uppercased()) }
                .map { $0.symbol.uppercased() }
        )

        let watchOnly = watchlistSymbols
            .map { $0.uppercased() }
            .filter { impactedSymbols.contains($0) && heldSymbols.contains($0) == false }

        let triggeringLines = evaluation.eventClusters.prefix(3).map { cluster in
            "\(cluster.summary) Reasons: \(cluster.reasons.joined(separator: ", "))"
        }
        let strategyPriorities = strategyBrief.map(analystStrategyBriefPriorities(from:))

        let description = [
            "Review recent normalized news for potentially material portfolio impact.",
            heldLines.isEmpty ? nil : "Held positions in scope: \(heldLines.joined(separator: "; ")).",
            watchOnly.isEmpty ? nil : "Watchlist context: \(watchOnly.joined(separator: ", ")).",
            strategyBrief.map { "Portfolio strategy brief objective: \($0.objectiveSummary)" },
            strategyBrief.flatMap { $0.keyThemes.isEmpty ? nil : "Strategy themes: \($0.keyThemes.joined(separator: "; "))." },
            strategyBrief.flatMap {
                $0.currentRiskPosture.isEmpty ? nil : "Current risk posture: \($0.currentRiskPosture)"
            },
            strategyPriorities.flatMap { $0.isEmpty ? nil : "Strategy priorities: \($0.joined(separator: " | "))." },
            strategyBrief.flatMap {
                $0.materialDevelopments.isEmpty ? nil : "Material developments: \($0.materialDevelopments.joined(separator: "; "))."
            },
            strategyBrief.flatMap {
                $0.nonMaterialDevelopments.isEmpty ? nil : "Usually not material: \($0.nonMaterialDevelopments.joined(separator: "; "))."
            },
            strategyBrief.flatMap {
                $0.reviewEscalationPosture.isEmpty ? nil : "Review posture: \($0.reviewEscalationPosture)"
            },
            strategyBrief.flatMap { brief in
                guard let revisionSummary = brief.revisionSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
                      revisionSummary.isEmpty == false else {
                    return nil
                }
                return "Latest strategy revision: \(revisionSummary)."
            },
            "Coverage posture: \(evaluation.coverageSummary)",
            primaryCluster.map { "Clustered event view: \($0.summary)" },
            "Escalation posture: \(evaluation.escalationDisposition.summaryText).",
            "Why now: \(evaluation.whyNowSummary)",
            evaluation.bookPostureSummary.map { "Current book posture: \($0)" },
            "Materiality trigger: \(evaluation.rationale)",
            triggeringLines.isEmpty ? nil : "Triggering news: \(triggeringLines.joined(separator: " | "))",
            "If the impact is not strong enough for escalation, keep the conclusion bounded and explicit. This task does not authorize trading or proposal approval."
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        let titleSymbols = impactedSymbols.joined(separator: ", ")
        return RecentNewsEscalationPlan(
            clusterKey: fingerprint,
            clusterFingerprint: fingerprint,
            taskId: "recent-news-task-\(fingerprint)",
            delegationId: "recent-news-delegation-\(fingerprint)",
            decisionId: "recent-news-decision-\(fingerprint)",
            taskTitle: "Recent news materiality review: \(titleSymbols)",
            taskDescription: description,
            impactedSymbols: impactedSymbols
        )
    }

    private static func stableIdentifier(prefix: String, components: [String]) -> String {
        let trimmed = components
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let joined = trimmed.joined(separator: "-")
        let sanitized = joined
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if sanitized.isEmpty {
            return prefix
        }
        let readable = String(sanitized.prefix(96))
        return "\(prefix)-\(readable)"
    }

    private static func stableHashedIdentifier(prefix: String, components: [String]) -> String {
        let joined = components.joined(separator: "|")
        let readablePrefix = stableIdentifier(prefix: prefix, components: components)
        let hash = fnv1aHex(joined)
        return "\(readablePrefix)-\(hash)"
    }

    private static func fnv1aHex(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        let full = String(hash, radix: 16, uppercase: false)
        return String(full.suffix(8))
    }
}
