import Foundation

private let genericAnalystThemeTags: Set<String> = [
    "checkpointed",
    "recent-news-analyst",
    "recent_news_material_impact",
    "portfolio-material-impact",
    "task-recommendation",
    "analyst_long_horizon"
]

func makeAnalystPositionContext(_ position: PositionRow) -> AnalystPositionContext {
    AnalystPositionContext(
        symbol: position.symbol.uppercased(),
        directionLabel: position.directionLabel,
        quantity: position.qty,
        marketValue: position.marketValue
    )
}

func makeAnalystStrategyBriefContext(_ brief: PortfolioStrategyBrief) -> AnalystStrategyBriefContext {
    let priorities = analystStrategyBriefPriorities(from: brief)
    return AnalystStrategyBriefContext(
        title: brief.title,
        objectiveSummary: brief.objectiveSummary,
        keyThemes: brief.keyThemes,
        currentRiskPosture: brief.currentRiskPosture,
        materialDevelopments: brief.materialDevelopments,
        nonMaterialDevelopments: brief.nonMaterialDevelopments,
        reviewEscalationPosture: brief.reviewEscalationPosture,
        strategicPriorities: priorities,
        groundingSummary: analystStrategyBriefGroundingSummary(from: brief, priorities: priorities),
        updatedBy: brief.updatedBy,
        updateSource: brief.updateSource,
        revisionSummary: brief.revisionSummary,
        updatedAt: brief.updatedAt
    )
}

func analystStrategyBriefPriorities(from brief: PortfolioStrategyBrief) -> [String] {
    let candidates = [
        brief.objectiveSummary.isEmpty ? nil : "Objective: \(brief.objectiveSummary)",
        brief.keyThemes.isEmpty ? nil : "Key themes: \(brief.keyThemes.prefix(3).joined(separator: "; "))",
        brief.currentRiskPosture.isEmpty ? nil : "Risk posture: \(brief.currentRiskPosture)",
        brief.materialDevelopments.isEmpty ? nil : "Material developments: \(brief.materialDevelopments.prefix(3).joined(separator: "; "))",
        brief.reviewEscalationPosture.isEmpty ? nil : "Review posture: \(brief.reviewEscalationPosture)"
    ]

    return candidates.compactMap { $0 }
}

func analystStrategyBriefGroundingSummary(
    from brief: PortfolioStrategyBrief,
    priorities: [String]? = nil
) -> String {
    let resolvedPriorities = priorities ?? analystStrategyBriefPriorities(from: brief)
    return resolvedPriorities
        .joined(separator: " | ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func makeAnalystNewsContextItem(_ event: NewsEvent) -> AnalystNewsContextItem {
    AnalystNewsContextItem(
        eventId: event.eventId,
        title: event.title,
        source: event.source,
        url: event.url,
        publishedAt: event.publishedAt,
        symbolHints: event.rawSymbolHints.map { $0.uppercased() },
        summary: event.summary,
        tags: event.tags
    )
}

func makeAnalystMandateContextItem(_ mandate: PMMandate) -> AnalystMandateContextItem {
    AnalystMandateContextItem(
        mandateId: mandate.mandateId,
        title: mandate.title,
        objectiveSummary: mandate.objectiveSummary,
        scope: mandate.scope
    )
}

func makeAnalystInstructionContextItem(_ instruction: PMInstruction) -> AnalystInstructionContextItem {
    AnalystInstructionContextItem(
        instructionId: instruction.instructionId,
        title: instruction.title,
        category: instruction.category,
        body: instruction.body
    )
}

func bootstrapAnalystScopedMemoryRecord(
    analystId: String,
    charterId: String?,
    tasks: [AnalystTask],
    findings: [AnalystFinding],
    memos: [AnalystMemo],
    now: Date
) -> AnalystScopedMemoryRecord {
    let scopedTasks = tasks
        .filter { $0.analystId == analystId }
        .sorted { $0.updatedAt > $1.updatedAt }
    let scopedFindings = findings
        .filter { $0.analystId == analystId }
        .sorted { $0.updatedAt > $1.updatedAt }
    let scopedMemos = memos
        .filter { $0.analystId == analystId }
        .sorted { $0.updatedAt > $1.updatedAt }

    let trackedSymbols = Array(
        Set(
            scopedTasks.flatMap(\.symbols).map { $0.uppercased() } +
            scopedFindings.flatMap(\.symbols).map { $0.uppercased() }
        )
    )
    .sorted()
    .prefix(12)
    .map { $0 }

    let trackedThemes = Array(
        Set(
            scopedFindings
                .flatMap(\.tags)
                .map { $0.lowercased() }
                .filter { genericAnalystThemeTags.contains($0) == false }
        )
    )
    .sorted()
    .prefix(8)
    .map { $0 }

    let openQuestions = Array(
        Set(
            scopedTasks
                .compactMap(\.checkpoint)
                .flatMap(\.openQuestions)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
        )
    )
    .sorted()
    .prefix(8)
    .map { $0 }

    return AnalystScopedMemoryRecord(
        memoryId: analystId,
        analystId: analystId,
        charterId: charterId,
        trackedSymbols: trackedSymbols,
        trackedThemes: trackedThemes,
        openQuestions: openQuestions,
        recentMemoIDs: scopedMemos.map(\.memoId).prefix(6).map { $0 },
        recentFindingIDs: scopedFindings.map(\.findingId).prefix(6).map { $0 },
        createdAt: now,
        updatedAt: now
    )
}

func mergeAnalystScopedMemoryRecord(
    existing: AnalystScopedMemoryRecord,
    task: AnalystTask? = nil,
    finding: AnalystFinding? = nil,
    memo: AnalystMemo? = nil,
    now: Date
) -> AnalystScopedMemoryRecord {
    var updated = existing

    updated.trackedSymbols = mergedSortedValues(
        existing: updated.trackedSymbols,
        newValues: (task?.symbols ?? []) + (finding?.symbols ?? []),
        maxCount: 12
    )
    updated.trackedThemes = mergedSortedValues(
        existing: updated.trackedThemes,
        newValues: finding?.tags.filter { genericAnalystThemeTags.contains($0.lowercased()) == false } ?? [],
        maxCount: 8,
        transform: { $0.lowercased() }
    )
    updated.openQuestions = mergedSortedValues(
        existing: updated.openQuestions,
        newValues: task?.checkpoint?.openQuestions ?? [],
        maxCount: 8,
        transform: { $0 }
    )

    if let memo {
        updated.recentMemoIDs = prependedUniqueValue(memo.memoId, existing: updated.recentMemoIDs, maxCount: 6)
    }
    if let finding {
        updated.recentFindingIDs = prependedUniqueValue(finding.findingId, existing: updated.recentFindingIDs, maxCount: 6)
    }
    if let charterId = finding?.charterId ?? memo?.charterId ?? task?.charterId {
        updated.charterId = charterId
    }
    updated.updatedAt = now
    return updated
}

func makeAnalystScopedMemorySnapshot(
    memory: AnalystScopedMemoryRecord,
    memosByID: [String: AnalystMemo],
    findingsByID: [String: AnalystFinding]
) -> AnalystScopedMemorySnapshot {
    let recentMemos = memory.recentMemoIDs.compactMap { memoID -> AnalystArtifactContextItem? in
        guard let memo = memosByID[memoID] else { return nil }
        return AnalystArtifactContextItem(
            artifactId: memo.memoId,
            kind: .memo,
            title: memo.title,
            summary: memo.executiveSummary,
            symbols: [],
            observedAt: memo.updatedAt
        )
    }

    let recentFindings = memory.recentFindingIDs.compactMap { findingID -> AnalystArtifactContextItem? in
        guard let finding = findingsByID[findingID] else { return nil }
        return AnalystArtifactContextItem(
            artifactId: finding.findingId,
            kind: .finding,
            title: finding.title,
            summary: finding.summary,
            symbols: finding.symbols.map { $0.uppercased() },
            observedAt: finding.updatedAt
        )
    }

    return AnalystScopedMemorySnapshot(
        memoryId: memory.memoryId,
        analystId: memory.analystId,
        charterId: memory.charterId,
        trackedSymbols: memory.trackedSymbols,
        trackedThemes: memory.trackedThemes,
        openQuestions: memory.openQuestions,
        recentMemos: recentMemos,
        recentFindings: recentFindings,
        updatedAt: memory.updatedAt
    )
}

private func mergedSortedValues(
    existing: [String],
    newValues: [String],
    maxCount: Int,
    transform: (String) -> String = { $0.uppercased() }
) -> [String] {
    let merged = Set(
        (existing + newValues)
            .map { transform($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    )
    return Array(merged).sorted().prefix(max(1, maxCount)).map { $0 }
}

private func prependedUniqueValue(_ value: String, existing: [String], maxCount: Int) -> [String] {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return existing }
    return Array(([trimmed] + existing.filter { $0 != trimmed }).prefix(max(1, maxCount)))
}
