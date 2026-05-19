import Foundation

private let genericBenchThemeTags: Set<String> = [
    "checkpointed",
    "recent-news-analyst",
    "recent_news_material_impact",
    "portfolio-material-impact",
    "task-recommendation",
    "analyst_long_horizon"
]

public struct PMBenchRoutingSectionPresentation: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let helperText: String
    public let candidates: [PMBenchRoutingCandidatePresentation]

    public init(
        id: String,
        title: String,
        helperText: String,
        candidates: [PMBenchRoutingCandidatePresentation]
    ) {
        self.id = id
        self.title = title
        self.helperText = helperText
        self.candidates = candidates
    }
}

public struct PMBenchRoutingCandidatePresentation: Sendable, Equatable, Identifiable {
    public let charterId: String
    public let title: String
    public let analystId: String
    public let roleTitle: String
    public let coverageSummary: String
    public let routingHint: String
    public let followUpHint: String?
    public let sharedContextSummary: String
    public let continuitySummary: String
    public let trackedSymbols: [String]
    public let trackedThemes: [String]
    public let recentMemoCount: Int
    public let recentFindingCount: Int
    public let recentTaskCount: Int
    public let hasContinuity: Bool

    public var id: String { charterId }

    public init(
        charterId: String,
        title: String,
        analystId: String,
        roleTitle: String,
        coverageSummary: String,
        routingHint: String,
        followUpHint: String?,
        sharedContextSummary: String,
        continuitySummary: String,
        trackedSymbols: [String],
        trackedThemes: [String],
        recentMemoCount: Int,
        recentFindingCount: Int,
        recentTaskCount: Int,
        hasContinuity: Bool
    ) {
        self.charterId = charterId
        self.title = title
        self.analystId = analystId
        self.roleTitle = roleTitle
        self.coverageSummary = coverageSummary
        self.routingHint = routingHint
        self.followUpHint = followUpHint
        self.sharedContextSummary = sharedContextSummary
        self.continuitySummary = continuitySummary
        self.trackedSymbols = trackedSymbols
        self.trackedThemes = trackedThemes
        self.recentMemoCount = recentMemoCount
        self.recentFindingCount = recentFindingCount
        self.recentTaskCount = recentTaskCount
        self.hasContinuity = hasContinuity
    }
}

public func makePMBenchRoutingSections(
    charters: [AnalystCharter],
    tasks: [AnalystTask],
    findings: [AnalystFinding],
    memos: [AnalystMemo]
) -> [PMBenchRoutingSectionPresentation] {
    makeAnalystBenchSections(charters: charters).map { section in
        PMBenchRoutingSectionPresentation(
            id: section.id,
            title: section.title,
            helperText: benchSectionHelperText(sectionID: section.id),
            candidates: section.charters.map { charter in
                makePMBenchRoutingCandidatePresentation(
                    charter: charter,
                    tasks: tasks,
                    findings: findings,
                    memos: memos
                )
            }
        )
    }
}

public func makePMBenchRoutingCandidatePresentation(
    charter: AnalystCharter,
    tasks: [AnalystTask],
    findings: [AnalystFinding],
    memos: [AnalystMemo]
) -> PMBenchRoutingCandidatePresentation {
    let scopedTasks = tasks
        .filter { $0.analystId == charter.analystId }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.taskId < rhs.taskId }
            return lhs.updatedAt > rhs.updatedAt
        }
    let scopedFindings = findings
        .filter { $0.analystId == charter.analystId }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.findingId < rhs.findingId }
            return lhs.updatedAt > rhs.updatedAt
        }
    let scopedMemos = memos
        .filter { $0.analystId == charter.analystId }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.memoId < rhs.memoId }
            return lhs.updatedAt > rhs.updatedAt
        }

    let persistedMemory = scopedTasks
        .compactMap(\.contextPack?.scopedMemory)
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.memoryId < rhs.memoryId }
            return lhs.updatedAt > rhs.updatedAt
        }
        .first

    let trackedSymbols = persistedMemory?.trackedSymbols
        ?? Array(
            Set(
                scopedTasks.flatMap(\.symbols).map { $0.uppercased() } +
                scopedFindings.flatMap(\.symbols).map { $0.uppercased() }
            )
        )
        .sorted()
        .prefix(6)
        .map { $0 }

    let trackedThemes = persistedMemory?.trackedThemes
        ?? Array(
            Set(
                scopedFindings
                    .flatMap(\.tags)
                    .map { $0.lowercased() }
                    .filter { genericBenchThemeTags.contains($0) == false }
            )
        )
        .sorted()
        .prefix(4)
        .map { $0 }

    let roleTitle = charter.benchRole?.displayTitle ?? "Additional Analyst"
    let sharedContextSummary = "Shared context includes positions, watchlist, portfolio strategy, recent news, and PM mandates/instructions when relevant."
    let continuitySummary = makeBenchContinuitySummary(
        trackedSymbols: trackedSymbols,
        trackedThemes: trackedThemes,
        recentMemoCount: scopedMemos.count,
        recentFindingCount: scopedFindings.count,
        recentTaskCount: scopedTasks.count
    )

    return PMBenchRoutingCandidatePresentation(
        charterId: charter.charterId,
        title: charter.title,
        analystId: charter.analystId,
        roleTitle: roleTitle,
        coverageSummary: charter.coverageScope,
        routingHint: benchRoutingHint(for: charter),
        followUpHint: benchFollowUpHint(for: charter),
        sharedContextSummary: sharedContextSummary,
        continuitySummary: continuitySummary,
        trackedSymbols: trackedSymbols,
        trackedThemes: trackedThemes,
        recentMemoCount: scopedMemos.count,
        recentFindingCount: scopedFindings.count,
        recentTaskCount: scopedTasks.count,
        hasContinuity: !trackedSymbols.isEmpty || !trackedThemes.isEmpty || !scopedMemos.isEmpty || !scopedFindings.isEmpty || !scopedTasks.isEmpty
    )
}

private func benchSectionHelperText(sectionID: String) -> String {
    switch sectionID {
    case "sector":
        return "Use a sector analyst when the primary question is company, industry, or sector interpretation inside a domain specialist's coverage."
    case "overlay":
        return "Use an overlay analyst when the question cuts across sectors, exposures, or portfolio-level posture."
    default:
        return "Additional bounded charters remain available, but the standing bench is the default PM routing path."
    }
}

private func benchRoutingHint(for charter: AnalystCharter) -> String {
    switch charter.charterId {
    case "bench-overlay-macro-international":
        return "Route work here when rates, policy, currency, geopolitical, or international developments change the interpretation of sector-level evidence."
    case "bench-overlay-portfolio-risk":
        return "Route work here when concentration, correlation, event clustering, or strategy-fragility across holdings is the main question."
    default:
        if charter.benchRole == .overlay {
            return "Route work here when the question is cross-sector or portfolio-level rather than owned by one sector specialist."
        }
        return "Route work here when the first question is company, industry, or sector interpretation within this analyst's coverage."
    }
}

private func benchFollowUpHint(for charter: AnalystCharter) -> String? {
    switch charter.charterId {
    case "bench-overlay-macro-international":
        return "Use as cross-sector follow-up when macro or international context changes the meaning of sector research."
    case "bench-overlay-portfolio-risk":
        return "Use as cross-position follow-up when sector research reveals clustering, concentration, or fragility concerns."
    default:
        if charter.benchRole == .sector {
            return "If the task broadens beyond one sector, consider Macro and International for cross-sector context or Portfolio Risk for portfolio-level exposure review."
        }
        return nil
    }
}

private func makeBenchContinuitySummary(
    trackedSymbols: [String],
    trackedThemes: [String],
    recentMemoCount: Int,
    recentFindingCount: Int,
    recentTaskCount: Int
) -> String {
    var parts: [String] = []

    if recentMemoCount > 0 || recentFindingCount > 0 || recentTaskCount > 0 {
        parts.append(
            "Prior work: \(recentMemoCount) memo\(recentMemoCount == 1 ? "" : "s"), \(recentFindingCount) finding\(recentFindingCount == 1 ? "" : "s"), \(recentTaskCount) task\(recentTaskCount == 1 ? "" : "s")."
        )
    }
    if trackedSymbols.isEmpty == false {
        parts.append("Tracked symbols: \(trackedSymbols.joined(separator: ", ")).")
    }
    if trackedThemes.isEmpty == false {
        parts.append("Standing themes: \(trackedThemes.joined(separator: ", ")).")
    }

    if parts.isEmpty {
        return "No analyst-specific continuity is recorded yet. The analyst will still receive the shared current context pack on first assignment."
    }
    return parts.joined(separator: " ")
}
