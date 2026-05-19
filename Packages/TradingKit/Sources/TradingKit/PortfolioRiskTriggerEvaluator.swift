import Foundation

struct PortfolioRiskTriggerMatch: Sendable, Equatable {
    enum Kind: String, Sendable, Equatable {
        case singlePositionConcentration = "single_position_concentration"
        case largeMoveInConcentratedHolding = "large_move_in_concentrated_holding"
        case catalystWindowInConcentratedHolding = "catalyst_window_in_concentrated_holding"
    }

    let kind: Kind
    let symbol: String
    let summary: String
    let detail: String
    let whatChanged: String
    let fingerprintComponent: String
}

enum PortfolioRiskEscalationDisposition: String, Sendable, Equatable, Comparable {
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

    static func < (lhs: PortfolioRiskEscalationDisposition, rhs: PortfolioRiskEscalationDisposition) -> Bool {
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

struct PortfolioRiskTriggerEvaluation: Sendable, Equatable {
    let observedPricesBySymbol: [String: Double]
    let observedWeightsBySymbol: [String: Double]
    let matches: [PortfolioRiskTriggerMatch]
    let impactedSymbols: [String]
    let escalationDisposition: PortfolioRiskEscalationDisposition
    let coverageSummary: String
    let concentrationSummary: String
    let clusteredRiskSummary: String
    let longShortSummary: String
    let bookPostureSummary: String
    let whyNowSummary: String
    let triggerFingerprint: String?
    let summary: String
    let rationale: String
    let whatChangedSinceReview: String

    var isMaterial: Bool {
        escalationDisposition >= .pmFollowUpWarranted
    }
}

private struct PortfolioRiskTriggerThresholds: Sendable, Equatable {
    let postureLabel: String
    let concentrationThreshold: Double
    let largeMoveThreshold: Double
    let largeMoveEligibleWeightThreshold: Double
}

private struct PortfolioRiskBookPosture: Sendable, Equatable {
    let largestSymbol: String?
    let largestWeight: Double
    let topThreeWeight: Double
    let crowdedSymbols: [String]
    let crowdedWeight: Double
    let longWeight: Double
    let shortWeight: Double
    let netWeight: Double
    let concentrationBucket: String
    let directionalBucket: String
}

enum PortfolioRiskTriggerEvaluator {
    static func evaluate(
        snapshot: StoreSnapshot,
        strategyBrief: PortfolioStrategyBrief?,
        previousObservedPricesBySymbol: [String: Double],
        previousObservedWeightsBySymbol: [String: Double],
        recentNews: [NewsEvent],
        now: Date
    ) -> PortfolioRiskTriggerEvaluation {
        let thresholds = thresholds(for: strategyBrief)
        let exposures = exposures(from: snapshot)
        let bookPosture = bookPosture(from: exposures, thresholds: thresholds)
        let observedPrices: [String: Double] = Dictionary(uniqueKeysWithValues: exposures.compactMap { exposure in
            guard let price = exposure.referencePrice else {
                return nil
            }
            return (exposure.symbol, price)
        })
        let observedWeights: [String: Double] = Dictionary(
            uniqueKeysWithValues: exposures.map { ($0.symbol, $0.weight) }
        )

        guard exposures.isEmpty == false else {
            return PortfolioRiskTriggerEvaluation(
                observedPricesBySymbol: observedPrices,
                observedWeightsBySymbol: observedWeights,
                matches: [],
                impactedSymbols: [],
                escalationDisposition: .quiet,
                coverageSummary: "No external coverage was needed because there were no in-scope positions.",
                concentrationSummary: "No concentration assessment is available because there are no in-scope positions.",
                clusteredRiskSummary: "No clustered portfolio-risk posture is available because there are no in-scope positions.",
                longShortSummary: "No long-vs-short posture is available because there are no in-scope positions.",
                bookPostureSummary: "No current in-scope book posture was available for this bounded review.",
                whyNowSummary: "No in-scope portfolio posture was available, so this run remained quiet.",
                triggerFingerprint: nil,
                summary: "portfolio_risk_analyst: no_positions_in_scope",
                rationale: "No current positions were available for bounded portfolio-risk trigger evaluation.",
                whatChangedSinceReview: "No current positions were available for comparison against the prior review anchor."
            )
        }

        var matches: [PortfolioRiskTriggerMatch] = []

        for exposure in exposures where exposure.weight >= thresholds.concentrationThreshold {
            let weightPercent = percentText(exposure.weight)
            let previousWeight = previousObservedWeightsBySymbol[exposure.symbol]
            let changeText = previousWeight.map {
                "\(exposure.symbol) is now \(weightPercent) of exposure versus \(percentText($0)) at the prior review anchor."
            } ?? "\(exposure.symbol) crossed the bounded concentration threshold at \(weightPercent) of exposure."
            let severity = concentrationSeverityBucket(
                weight: exposure.weight,
                threshold: thresholds.concentrationThreshold
            )
            matches.append(
                PortfolioRiskTriggerMatch(
                    kind: .singlePositionConcentration,
                    symbol: exposure.symbol,
                    summary: previousWeight.map {
                        "\(exposure.symbol) is now \(weightPercent) of current portfolio exposure, up from \(percentText($0)) at the prior review anchor."
                    } ?? "\(exposure.symbol) is \(weightPercent) of current portfolio exposure.",
                    detail: "Single-position concentration exceeded the \(percentText(thresholds.concentrationThreshold)) threshold under the current \(thresholds.postureLabel) risk posture.",
                    whatChanged: changeText,
                    fingerprintComponent: "concentration:\(exposure.symbol):\(severity)"
                )
            )
        }

        for exposure in exposures where exposure.weight >= thresholds.largeMoveEligibleWeightThreshold {
            guard let currentPrice = exposure.referencePrice,
                  let previousPrice = previousObservedPricesBySymbol[exposure.symbol],
                  previousPrice > 0
            else {
                continue
            }
            let move = abs((currentPrice - previousPrice) / previousPrice)
            guard move >= thresholds.largeMoveThreshold else {
                continue
            }
            let direction = currentPrice >= previousPrice ? "up" : "down"
            let severity = moveSeverityBucket(move: move, threshold: thresholds.largeMoveThreshold)
            matches.append(
                PortfolioRiskTriggerMatch(
                    kind: .largeMoveInConcentratedHolding,
                    symbol: exposure.symbol,
                    summary: "\(exposure.symbol) moved \(percentText(move)) \(direction) since the last portfolio-risk review.",
                    detail: "A concentrated holding moved more than the \(percentText(thresholds.largeMoveThreshold)) trigger threshold while representing \(percentText(exposure.weight)) of portfolio exposure.",
                    whatChanged: "\(exposure.symbol) is now \(direction) \(percentText(move)) versus the prior portfolio-risk review anchor.",
                    fingerprintComponent: "move:\(exposure.symbol):\(direction):\(severity)"
                )
            )
        }

        for exposure in exposures where exposure.weight >= thresholds.largeMoveEligibleWeightThreshold {
            guard let catalyst = recentCatalystEvent(
                for: exposure.symbol,
                recentNews: recentNews,
                now: now
            ) else {
                continue
            }
            matches.append(
                PortfolioRiskTriggerMatch(
                    kind: .catalystWindowInConcentratedHolding,
                    symbol: exposure.symbol,
                    summary: "\(exposure.symbol) is a concentrated holding with a near-term earnings catalyst now in scope.",
                    detail: "Recent normalized news indicates an approaching earnings or guidance event window while the holding represents \(percentText(exposure.weight)) of current portfolio exposure. Latest catalyst cue: \(catalyst.title)",
                    whatChanged: "A new catalyst-window headline for \(exposure.symbol) entered the normalized news stream since the prior review anchor.",
                    fingerprintComponent: "catalyst:\(exposure.symbol):earnings_window_active"
                )
            )
        }

        let coverageSummary = coverageSummary(for: matches)
        let concentrationSummary = concentrationSummary(
            bookPosture: bookPosture,
            thresholds: thresholds
        )
        let clusteredRiskSummary = clusteredRiskSummary(bookPosture: bookPosture)
        let longShortSummary = longShortSummary(bookPosture: bookPosture)
        let bookPostureSummary = "\(concentrationSummary) \(clusteredRiskSummary) \(longShortSummary)"

        let impactedSymbols = Array(Set(matches.map(\.symbol))).sorted()
        let changes = Array(Set(matches.map(\.whatChanged))).sorted().joined(separator: " | ")
        let disposition = escalationDisposition(
            matches: matches,
            bookPosture: bookPosture,
            thresholds: thresholds
        )
        let whyNow = whyNowSummary(
            disposition: disposition,
            changes: changes,
            concentrationSummary: concentrationSummary,
            longShortSummary: longShortSummary,
            strategyBrief: strategyBrief
        )

        guard matches.isEmpty == false else {
            let topHoldings = exposures.prefix(3).map { "\($0.symbol) \(percentText($0.weight))" }.joined(separator: ", ")
            let summary: String
            switch disposition {
            case .quiet:
                summary = "portfolio_risk_analyst: quiet no_material_risk_change"
            case .worthMonitoring:
                summary = "portfolio_risk_analyst: worth_monitoring posture_watch"
            case .pmFollowUpWarranted, .ownerRelevantStrategicConcern:
                summary = "portfolio_risk_analyst: pm_follow_up_warranted no_trigger_match"
            }
            return PortfolioRiskTriggerEvaluation(
                observedPricesBySymbol: observedPrices,
                observedWeightsBySymbol: observedWeights,
                matches: [],
                impactedSymbols: [],
                escalationDisposition: disposition,
                coverageSummary: coverageSummary,
                concentrationSummary: concentrationSummary,
                clusteredRiskSummary: clusteredRiskSummary,
                longShortSummary: longShortSummary,
                bookPostureSummary: bookPostureSummary,
                whyNowSummary: whyNow,
                triggerFingerprint: nil,
                summary: summary,
                rationale: "No bounded portfolio-risk trigger crossed threshold. Largest exposures remain \(topHoldings). \(bookPostureSummary)",
                whatChangedSinceReview: "No new bounded portfolio-risk change crossed threshold since the prior review anchor."
            )
        }

        let summaries = matches.map(\.summary).joined(separator: " | ")
        let fingerprintComponents = matches.map(\.fingerprintComponent).sorted() + [
            "concentration:\(bookPosture.concentrationBucket)",
            "direction:\(bookPosture.directionalBucket)",
            "disposition:\(disposition.rawValue)"
        ]
        let fingerprint = disposition >= .pmFollowUpWarranted
            ? stableHashedIdentifier(prefix: "portfolio-risk-trigger", components: fingerprintComponents)
            : nil

        return PortfolioRiskTriggerEvaluation(
            observedPricesBySymbol: observedPrices,
            observedWeightsBySymbol: observedWeights,
            matches: matches,
            impactedSymbols: impactedSymbols,
            escalationDisposition: disposition,
            coverageSummary: coverageSummary,
            concentrationSummary: concentrationSummary,
            clusteredRiskSummary: clusteredRiskSummary,
            longShortSummary: longShortSummary,
            bookPostureSummary: bookPostureSummary,
            whyNowSummary: whyNow,
            triggerFingerprint: fingerprint,
            summary: "portfolio_risk_analyst: \(disposition.rawValue) matches=\(matches.count) symbols=\(impactedSymbols.joined(separator: ", "))",
            rationale: "Portfolio Risk trigger conditions crossed bounded thresholds. \(summaries) \(bookPostureSummary)",
            whatChangedSinceReview: changes
        )
    }

    private static func exposures(from snapshot: StoreSnapshot) -> [PositionExposure] {
        let totalAbsoluteExposure = snapshot.positions.reduce(0.0) { partial, row in
            partial + abs(doubleValue(row.marketValue) ?? 0)
        }
        let accountEquity = max(0, doubleValue(snapshot.accountSummary?.equity) ?? 0)
        let denominator = accountEquity > 0 ? accountEquity : totalAbsoluteExposure
        guard denominator > 0 else {
            return []
        }

        return snapshot.positions.compactMap { row in
            let marketValue = abs(doubleValue(row.marketValue) ?? 0)
            guard marketValue > 0 else {
                return nil
            }
            let weight = marketValue / denominator
            let price = observedPrice(for: row.symbol, marketValue: marketValue, qty: row.qty, snapshot: snapshot)
            return PositionExposure(
                symbol: row.symbol.uppercased(),
                weight: weight,
                marketValue: marketValue,
                isShort: row.side.lowercased() == "short",
                referencePrice: price
            )
        }
        .sorted { lhs, rhs in
            if lhs.weight == rhs.weight {
                return lhs.symbol < rhs.symbol
            }
            return lhs.weight > rhs.weight
        }
    }

    private static func thresholds(for strategyBrief: PortfolioStrategyBrief?) -> PortfolioRiskTriggerThresholds {
        let posture = strategyBrief?.currentRiskPosture.lowercased() ?? ""
        if posture.contains("conservative") || posture.contains("defensive") || posture.contains("capital preservation") {
            return PortfolioRiskTriggerThresholds(
                postureLabel: "conservative",
                concentrationThreshold: 0.20,
                largeMoveThreshold: 0.05,
                largeMoveEligibleWeightThreshold: 0.12
            )
        }
        if posture.contains("aggressive") || posture.contains("higher risk") || posture.contains("high risk") || posture.contains("concentrated") {
            return PortfolioRiskTriggerThresholds(
                postureLabel: "aggressive",
                concentrationThreshold: 0.35,
                largeMoveThreshold: 0.10,
                largeMoveEligibleWeightThreshold: 0.20
            )
        }
        return PortfolioRiskTriggerThresholds(
            postureLabel: "moderate",
            concentrationThreshold: 0.25,
            largeMoveThreshold: 0.08,
            largeMoveEligibleWeightThreshold: 0.15
        )
    }

    private static func observedPrice(
        for symbol: String,
        marketValue: Double,
        qty: String,
        snapshot: StoreSnapshot
    ) -> Double? {
        let normalized = symbol.uppercased()
        if let quote = snapshot.quotesBySymbol[normalized] ?? snapshot.optionQuotesBySymbol[normalized] {
            if let last = quote.lastPrice {
                return last
            }
            if let bid = quote.bidPrice, let ask = quote.askPrice {
                return (bid + ask) / 2.0
            }
            return quote.bidPrice ?? quote.askPrice
        }

        guard let quantity = doubleValue(qty), quantity != 0 else {
            return nil
        }
        return marketValue / abs(quantity)
    }

    private static func recentCatalystEvent(
        for symbol: String,
        recentNews: [NewsEvent],
        now: Date
    ) -> NewsEvent? {
        let normalizedSymbol = symbol.uppercased()
        let earliest = Calendar(identifier: .gregorian).date(byAdding: .day, value: -14, to: now) ?? now
        return recentNews
            .filter { event in
                event.publishedAt >= earliest
                    && event.rawSymbolHints.map { $0.uppercased() }.contains(normalizedSymbol)
            }
            .sorted { lhs, rhs in
                if lhs.publishedAt == rhs.publishedAt {
                    return lhs.eventId > rhs.eventId
                }
                return lhs.publishedAt > rhs.publishedAt
            }
            .first(where: { event in
                let combined = "\(event.title) \(event.summary ?? "")".lowercased()
                let catalystTerms = [
                    "will report earnings",
                    "scheduled to report earnings",
                    "to report earnings",
                    "reports earnings",
                    "ahead of earnings",
                    "before earnings",
                    "earnings on",
                    "guidance ahead of earnings"
                ]
                return catalystTerms.contains(where: { combined.contains($0) })
            })
    }

    private static func concentrationSeverityBucket(weight: Double, threshold: Double) -> String {
        if weight >= threshold + 0.10 {
            return "critical"
        }
        if weight >= threshold + 0.05 {
            return "elevated"
        }
        return "breach"
    }

    private static func moveSeverityBucket(move: Double, threshold: Double) -> String {
        if move >= threshold + 0.10 {
            return "critical"
        }
        if move >= threshold + 0.05 {
            return "elevated"
        }
        return "breach"
    }

    private static func bookPosture(
        from exposures: [PositionExposure],
        thresholds: PortfolioRiskTriggerThresholds
    ) -> PortfolioRiskBookPosture {
        let largestSymbol = exposures.first?.symbol
        let largestWeight = exposures.first?.weight ?? 0
        let topThreeWeight = exposures.prefix(3).reduce(0.0) { $0 + $1.weight }
        let crowdedThreshold = max(0.12, thresholds.concentrationThreshold * 0.60)
        let crowded = exposures.filter { $0.weight >= crowdedThreshold }
        let crowdedSymbols = crowded.map(\.symbol)
        let crowdedWeight = crowded.reduce(0.0) { $0 + $1.weight }

        let gross = max(0.0, exposures.reduce(0.0) { $0 + $1.marketValue })
        let longGross = exposures.filter { $0.isShort == false }.reduce(0.0) { $0 + $1.marketValue }
        let shortGross = exposures.filter(\.isShort).reduce(0.0) { $0 + $1.marketValue }
        let longWeight = gross > 0 ? longGross / gross : 0
        let shortWeight = gross > 0 ? shortGross / gross : 0
        let netWeight = longWeight - shortWeight

        let concentrationBucket: String
        if largestWeight >= thresholds.concentrationThreshold + 0.10 {
            concentrationBucket = "single_name_critical"
        } else if largestWeight >= thresholds.concentrationThreshold {
            concentrationBucket = "single_name_breach"
        } else if topThreeWeight >= 0.70 {
            concentrationBucket = "top_cluster_heavy"
        } else if topThreeWeight >= 0.55 {
            concentrationBucket = "top_cluster_elevated"
        } else {
            concentrationBucket = "balanced"
        }

        let directionalBucket: String
        if abs(netWeight) >= 0.80 {
            directionalBucket = netWeight >= 0 ? "net_long_heavy" : "net_short_heavy"
        } else if abs(netWeight) >= 0.60 {
            directionalBucket = netWeight >= 0 ? "net_long_skew" : "net_short_skew"
        } else {
            directionalBucket = "balanced"
        }

        return PortfolioRiskBookPosture(
            largestSymbol: largestSymbol,
            largestWeight: largestWeight,
            topThreeWeight: topThreeWeight,
            crowdedSymbols: crowdedSymbols,
            crowdedWeight: crowdedWeight,
            longWeight: longWeight,
            shortWeight: shortWeight,
            netWeight: netWeight,
            concentrationBucket: concentrationBucket,
            directionalBucket: directionalBucket
        )
    }

    private static func escalationDisposition(
        matches: [PortfolioRiskTriggerMatch],
        bookPosture: PortfolioRiskBookPosture,
        thresholds: PortfolioRiskTriggerThresholds
    ) -> PortfolioRiskEscalationDisposition {
        if matches.isEmpty {
            let nearThreshold = bookPosture.largestWeight >= (thresholds.concentrationThreshold * 0.95)
            let clusteredAndSkewed = bookPosture.topThreeWeight >= 0.75
                && bookPosture.largestWeight >= (thresholds.concentrationThreshold * 0.90)
                && abs(bookPosture.netWeight) >= 0.75
            return (nearThreshold || clusteredAndSkewed) ? .worthMonitoring : .quiet
        }

        var score = 0
        for match in matches {
            switch match.kind {
            case .singlePositionConcentration:
                score += 2
            case .largeMoveInConcentratedHolding:
                score += 2
            case .catalystWindowInConcentratedHolding:
                score += 1
            }

            if match.fingerprintComponent.contains("critical") {
                score += 2
            } else if match.fingerprintComponent.contains("elevated") {
                score += 1
            }
        }

        if bookPosture.topThreeWeight >= 0.75 {
            score += 1
        }
        if abs(bookPosture.netWeight) >= 0.80 {
            score += 1
        }
        if bookPosture.crowdedSymbols.count >= 3 {
            score += 1
        }
        if bookPosture.largestWeight >= thresholds.concentrationThreshold + 0.12 {
            score += 1
        }

        let onlyCatalyst = matches.allSatisfy { $0.kind == .catalystWindowInConcentratedHolding }
        if onlyCatalyst && score <= 2 {
            return .worthMonitoring
        }
        if score >= 6 {
            return .ownerRelevantStrategicConcern
        }
        if score >= 3 {
            return .pmFollowUpWarranted
        }
        return .worthMonitoring
    }

    private static func coverageSummary(for matches: [PortfolioRiskTriggerMatch]) -> String {
        if matches.contains(where: { $0.kind == .catalystWindowInConcentratedHolding }) {
            return "App-owned portfolio posture set the baseline risk read; recent normalized news added catalyst-window context."
        }
        return "App-owned portfolio posture and trigger-state deltas drove this risk read; external/public coverage is supplemental corroboration when present."
    }

    private static func concentrationSummary(
        bookPosture: PortfolioRiskBookPosture,
        thresholds: PortfolioRiskTriggerThresholds
    ) -> String {
        guard let largestSymbol = bookPosture.largestSymbol else {
            return "No current concentration posture was available."
        }

        if bookPosture.largestWeight >= thresholds.concentrationThreshold + 0.10 {
            return "Single-name concentration is severe: \(largestSymbol) is \(percentText(bookPosture.largestWeight)) of exposure versus a \(percentText(thresholds.concentrationThreshold)) posture threshold."
        }
        if bookPosture.largestWeight >= thresholds.concentrationThreshold {
            return "Single-name concentration breached threshold: \(largestSymbol) is \(percentText(bookPosture.largestWeight)) of exposure versus a \(percentText(thresholds.concentrationThreshold)) posture threshold."
        }
        if bookPosture.topThreeWeight >= 0.70 {
            return "Top-position concentration is elevated even without a single-name breach: top-three holdings are \(percentText(bookPosture.topThreeWeight)) of exposure."
        }
        return "Largest-position concentration is currently \(largestSymbol) at \(percentText(bookPosture.largestWeight)); top-three concentration is \(percentText(bookPosture.topThreeWeight))."
    }

    private static func clusteredRiskSummary(bookPosture: PortfolioRiskBookPosture) -> String {
        if bookPosture.crowdedSymbols.count >= 3 {
            return "Risk is clustered across \(bookPosture.crowdedSymbols.prefix(4).joined(separator: ", ")); that cluster is \(percentText(bookPosture.crowdedWeight)) of exposure."
        }
        if bookPosture.crowdedSymbols.count == 2 {
            return "Risk is concentrated across a two-name cluster (\(bookPosture.crowdedSymbols.joined(separator: ", "))) at \(percentText(bookPosture.crowdedWeight)) of exposure."
        }
        if let largest = bookPosture.largestSymbol {
            return "Risk concentration is mostly isolated to \(largest) rather than spread across a broad crowded cluster."
        }
        return "No crowded multi-name concentration cluster is currently in scope."
    }

    private static func longShortSummary(bookPosture: PortfolioRiskBookPosture) -> String {
        let dominance: String
        if abs(bookPosture.netWeight) < 0.20 {
            dominance = "Directional posture is relatively balanced."
        } else if bookPosture.netWeight > 0 {
            dominance = "Current directional risk is primarily long-side."
        } else {
            dominance = "Current directional risk is primarily short-side."
        }

        return "Long-vs-short weighting is \(percentText(bookPosture.longWeight)) long / \(percentText(bookPosture.shortWeight)) short (net \(signedPercentText(bookPosture.netWeight))). \(dominance)"
    }

    private static func whyNowSummary(
        disposition: PortfolioRiskEscalationDisposition,
        changes: String,
        concentrationSummary: String,
        longShortSummary: String,
        strategyBrief: PortfolioStrategyBrief?
    ) -> String {
        let objective = strategyBrief?.objectiveSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let posture = strategyBrief?.currentRiskPosture.trimmingCharacters(in: .whitespacesAndNewlines)
        let strategyContext = [
            posture.flatMap { $0.isEmpty ? nil : "Risk posture context: \($0)." },
            objective.flatMap { $0.isEmpty ? nil : "Strategy objective context: \($0)." }
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        switch disposition {
        case .quiet:
            return "No bounded trigger crossed threshold and current book posture remained within the current review bounds."
        case .worthMonitoring:
            return "No decisive trigger-based escalation is warranted yet, but posture drift is close enough to keep on watch. \(concentrationSummary) \(longShortSummary) \(strategyContext)".trimmingCharacters(in: .whitespacesAndNewlines)
        case .pmFollowUpWarranted, .ownerRelevantStrategicConcern:
            let changeLead = changes.isEmpty
                ? "Bounded trigger conditions changed versus the prior review anchor."
                : "What changed now: \(changes)."
            return "\(changeLead) \(concentrationSummary) \(longShortSummary) \(strategyContext)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func doubleValue(_ raw: String?) -> Double? {
        guard let raw else {
            return nil
        }
        return Double(raw.replacingOccurrences(of: ",", with: ""))
    }

    private static func percentText(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private static func signedPercentText(_ value: Double) -> String {
        let absolute = percentText(abs(value))
        if value > 0 {
            return "+\(absolute)"
        }
        if value < 0 {
            return "-\(absolute)"
        }
        return absolute
    }

    private static func stableHashedIdentifier(prefix: String, components: [String]) -> String {
        let joined = components.joined(separator: "|")
        let readablePrefix = stableIdentifier(prefix: prefix, components: components)
        let hash = fnv1aHex(joined)
        return "\(readablePrefix)-\(hash)"
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

private struct PositionExposure: Sendable, Equatable {
    let symbol: String
    let weight: Double
    let marketValue: Double
    let isShort: Bool
    let referencePrice: Double?
}
