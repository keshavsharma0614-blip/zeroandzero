import Foundation

public enum OwnerPrimarySurface: String, CaseIterable, Sendable {
    case commandCenter = "Command Center"
    case portfolioWatch = "Portfolio Watch"
    case news = "News"
    case systemControl = "System Control"
}

public enum OwnerAdvancedSurface: String, CaseIterable, Sendable {
    case pmInbox = "PM Inbox"
    case manualOrders = "Manual Orders"
    case ordersBlotter = "Orders Blotter"
    case signals = "Signals"
    case proposals = "Proposals"
    case jobs = "Jobs"
    case logsAudit = "Logs / Audit"
}

public func makeVisibleOwnerAdvancedSurfaces(
    persistentPreferenceEnabled: Bool,
    temporarilyOpenedSurface: OwnerAdvancedSurface?
) -> [OwnerAdvancedSurface] {
    if persistentPreferenceEnabled {
        return OwnerAdvancedSurface.allCases
    }
    if let temporarilyOpenedSurface {
        return [temporarilyOpenedSurface]
    }
    return []
}

public enum OwnerAttentionKind: String, Sendable, Equatable {
    case userActionNeeded = "user_action_needed"
    case pmReviewing = "pm_reviewing"
    case analystActivity = "analyst_activity"
    case systemExceptions = "system_exceptions"
}

public struct OwnerAttentionCardPresentation: Sendable, Equatable, Identifiable {
    public let kind: OwnerAttentionKind
    public let title: String
    public let count: Int
    public let summary: String
    public let detail: String
    public let drillDownLabel: String

    public var id: OwnerAttentionKind { kind }

    public init(
        kind: OwnerAttentionKind,
        title: String,
        count: Int,
        summary: String,
        detail: String,
        drillDownLabel: String
    ) {
        self.kind = kind
        self.title = title
        self.count = count
        self.summary = summary
        self.detail = detail
        self.drillDownLabel = drillDownLabel
    }
}

public struct OwnerRecentChangePresentation: Sendable, Equatable, Identifiable {
    public let title: String
    public let summary: String
    public let drillDownLabel: String

    public var id: String { title }

    public init(title: String, summary: String, drillDownLabel: String) {
        self.title = title
        self.summary = summary
        self.drillDownLabel = drillDownLabel
    }
}

public struct OwnerSystemExceptionCategoryPresentation: Sendable, Equatable, Identifiable {
    public let title: String
    public let count: Int
    public let summary: String
    public let detailLabel: String

    public var id: String { title }

    public init(title: String, count: Int, summary: String, detailLabel: String) {
        self.title = title
        self.count = max(0, count)
        self.summary = summary
        self.detailLabel = detailLabel
    }
}

public struct PlainEnglishStorageCategoryPresentation: Sendable, Equatable, Identifiable {
    public let title: String
    public let detail: String
    public let bytes: Int64

    public var id: String { title }

    public init(title: String, detail: String, bytes: Int64) {
        self.title = title
        self.detail = detail
        self.bytes = max(0, bytes)
    }
}

public struct OldJobTelemetryCleanupBreakdownItem: Sendable, Equatable, Identifiable {
    public let label: String
    public let count: Int

    public var id: String { label }

    public init(label: String, count: Int) {
        self.label = label
        self.count = max(0, count)
    }
}

public struct OldJobTelemetryCleanupPresentation: Sendable, Equatable {
    public let dryRun: Bool
    public let cutoff: Date?
    public let cutoffText: String
    public let cutoffSource: String
    public let scannedCount: Int
    public let eligibleCount: Int
    public let protectedCount: Int
    public let skippedDecodeErrorCount: Int
    public let skippedLinkedProtectedCount: Int
    public let estimatedBytesReclaimable: Int64
    public let appliedCount: Int
    public let appliedBytes: Int64
    public let candidateCountByStatus: [OldJobTelemetryCleanupBreakdownItem]
    public let candidateCountByType: [OldJobTelemetryCleanupBreakdownItem]
    public let oldestCandidateTimestamp: String?
    public let newestCandidateTimestamp: String?
    public let safetyExclusions: [String]

    public var canApplyAfterPreview: Bool {
        dryRun && eligibleCount > 0 && cutoff != nil
    }

    public var modeLabel: String {
        dryRun ? "Preview" : "Applied"
    }

    public var deletionStateNote: String {
        dryRun
            ? "No files deleted yet."
            : "Cleanup was applied through app-owned maintenance."
    }

    public init(
        dryRun: Bool,
        cutoff: Date?,
        cutoffText: String,
        cutoffSource: String,
        scannedCount: Int,
        eligibleCount: Int,
        protectedCount: Int,
        skippedDecodeErrorCount: Int,
        skippedLinkedProtectedCount: Int,
        estimatedBytesReclaimable: Int64,
        appliedCount: Int,
        appliedBytes: Int64,
        candidateCountByStatus: [OldJobTelemetryCleanupBreakdownItem],
        candidateCountByType: [OldJobTelemetryCleanupBreakdownItem],
        oldestCandidateTimestamp: String?,
        newestCandidateTimestamp: String?,
        safetyExclusions: [String]
    ) {
        self.dryRun = dryRun
        self.cutoff = cutoff
        self.cutoffText = cutoffText
        self.cutoffSource = cutoffSource
        self.scannedCount = max(0, scannedCount)
        self.eligibleCount = max(0, eligibleCount)
        self.protectedCount = max(0, protectedCount)
        self.skippedDecodeErrorCount = max(0, skippedDecodeErrorCount)
        self.skippedLinkedProtectedCount = max(0, skippedLinkedProtectedCount)
        self.estimatedBytesReclaimable = max(0, estimatedBytesReclaimable)
        self.appliedCount = max(0, appliedCount)
        self.appliedBytes = max(0, appliedBytes)
        self.candidateCountByStatus = candidateCountByStatus
        self.candidateCountByType = candidateCountByType
        self.oldestCandidateTimestamp = oldestCandidateTimestamp
        self.newestCandidateTimestamp = newestCandidateTimestamp
        self.safetyExclusions = safetyExclusions
    }
}

public func makeOwnerAttentionCardPresentations(
    snapshot: PMCommandCenterSnapshot
) -> [OwnerAttentionCardPresentation] {
    let exceptions = snapshot.failedDelegationsCount + snapshot.degradedDelegationsCount
    let pmReviewCount = snapshot.pmReviewQueueCount
    let analystActivityCount = snapshot.activeDelegationsCount + snapshot.activeStandingRunCount
    return [
        OwnerAttentionCardPresentation(
            kind: .userActionNeeded,
            title: "Your Review",
            count: snapshot.ownerActionableApprovalCount,
            summary: countSentence(
                snapshot.ownerActionableApprovalCount,
                zero: "Nothing is waiting for your decision.",
                singular: "1 item is waiting for your decision.",
                plural: "\(snapshot.ownerActionableApprovalCount) items are waiting for your decision."
            ),
            detail: snapshot.ownerActionableApprovalCount == 0
                ? "No owner action is needed right now."
                : "Resolve these from Command Center > Your Decisions.",
            drillDownLabel: "Open Command Center"
        ),
        OwnerAttentionCardPresentation(
            kind: .pmReviewing,
            title: "PM Reviewing",
            count: pmReviewCount,
            summary: countSentence(
                pmReviewCount,
                zero: "No items are under PM review.",
                singular: "1 item is under PM review.",
                plural: "\(pmReviewCount) items are under PM review."
            ),
            detail: pmReviewCount == 0
                ? "The PM review queue is quiet."
                : "This reflects standing analyst reports currently awaiting PM review in PM Inbox.",
            drillDownLabel: "Open PM Inbox"
        ),
        OwnerAttentionCardPresentation(
            kind: .analystActivity,
            title: "Analyst Activity",
            count: analystActivityCount,
            summary: countSentence(
                analystActivityCount,
                zero: "No analyst tasks are active.",
                singular: "1 analyst item is active.",
                plural: "\(analystActivityCount) analyst items are active."
            ),
            detail: analystActivityCount == 0
                ? "No analyst work is in flight right now."
                : "This includes issued delegations and in-flight standing analyst runs.",
            drillDownLabel: "Open PM Inbox"
        ),
        OwnerAttentionCardPresentation(
            kind: .systemExceptions,
            title: "System Exceptions",
            count: exceptions,
            summary: countSentence(
                exceptions,
                zero: "No system issues need review.",
                singular: "1 system issue needs review.",
                plural: "\(exceptions) system issues need review."
            ),
            detail: exceptions == 0
                ? "No degraded or failed analyst launches are active."
                : "\(snapshot.failedDelegationsCount) failed and \(snapshot.degradedDelegationsCount) degraded worker issue(s) are active.",
            drillDownLabel: "Open System Control"
        )
    ]
}

public func makeOwnerRecentChangePresentations(
    snapshot: PMCommandCenterSnapshot
) -> [OwnerRecentChangePresentation] {
    [
        OwnerRecentChangePresentation(
            title: "Signals",
            summary: signalRecentChangeSummary(snapshot),
            drillDownLabel: "Open Signals"
        ),
        OwnerRecentChangePresentation(
            title: "Proposals",
            summary: snapshot.awaitingProposalCount == 0
                ? "No proposal review queue is building."
                : countSentence(
                    snapshot.awaitingProposalCount,
                    zero: "No proposal review queue is building.",
                    singular: "1 proposal is awaiting PM handling.",
                    plural: "\(snapshot.awaitingProposalCount) proposals are awaiting PM handling."
                ),
            drillDownLabel: "Open Proposals"
        )
    ]
}

private func signalRecentChangeSummary(_ snapshot: PMCommandCenterSnapshot) -> String {
    if snapshot.newSignalsCount == 0 && snapshot.fyiSignalsCount == 0 {
        return "No new research signals are waiting."
    }

    var parts: [String] = []
    if snapshot.newSignalsCount > 0 {
        parts.append(
            countSentence(
                snapshot.newSignalsCount,
                zero: "",
                singular: "1 signal needs owner review",
                plural: "\(snapshot.newSignalsCount) signals need owner review"
            )
        )
    }
    if snapshot.fyiSignalsCount > 0 {
        parts.append(
            countSentence(
                snapshot.fyiSignalsCount,
                zero: "",
                singular: "1 FYI research alert",
                plural: "\(snapshot.fyiSignalsCount) FYI research alerts"
            )
        )
    }

    return parts.joined(separator: "; ") + "."
}

public func makeOwnerSystemExceptionCategoryPresentations(
    snapshot: PMCommandCenterSnapshot,
    tradeConnectionState: String,
    marketDataConnectionState: String,
    workerLinkConnected: Bool
) -> [OwnerSystemExceptionCategoryPresentation] {
    let feedIssues = connectionIssueCount(state: tradeConnectionState) + connectionIssueCount(state: marketDataConnectionState)
    let workerIssues = snapshot.failedDelegationsCount + snapshot.degradedDelegationsCount + (workerLinkConnected ? 0 : 1)
    let otherIssues = 0

    return [
        OwnerSystemExceptionCategoryPresentation(
            title: "Feed Issues",
            count: feedIssues,
            summary: feedIssues == 0
                ? "Trade and market-data feeds look healthy."
                : connectionIssueSummary(
                    tradeConnectionState: tradeConnectionState,
                    marketDataConnectionState: marketDataConnectionState
                ),
            detailLabel: "Feed detail"
        ),
        OwnerSystemExceptionCategoryPresentation(
            title: "Worker / Launch Issues",
            count: workerIssues,
            summary: workerIssues == 0
                ? "No worker-link or analyst-launch issues are active."
                : workerIssueSummary(
                    snapshot: snapshot,
                    workerLinkConnected: workerLinkConnected
                ),
            detailLabel: "Worker detail"
        ),
        OwnerSystemExceptionCategoryPresentation(
            title: "Other System Issues",
            count: otherIssues,
            summary: "No other system issues are currently summarized here.",
            detailLabel: "Other detail"
        )
    ]
}

public func makePlainEnglishStorageCategoryPresentations(
    _ summary: StorageFootprintSummary
) -> [PlainEnglishStorageCategoryPresentation] {
    [
        PlainEnglishStorageCategoryPresentation(
            title: "Activity History",
            detail: "Structured system and operator history.",
            bytes: summary.auditBytes
        ),
        PlainEnglishStorageCategoryPresentation(
            title: "News Archive",
            detail: "Normalized RSS, Alpaca News, and SEC filing history.",
            bytes: summary.newsBytes
        ),
        PlainEnglishStorageCategoryPresentation(
            title: "Job History",
            detail: "Background job records and automation results.",
            bytes: summary.jobsBytes
        ),
        PlainEnglishStorageCategoryPresentation(
            title: "Run History",
            detail: "Replay and paper-run records.",
            bytes: summary.runsBytes
        ),
        PlainEnglishStorageCategoryPresentation(
            title: "Market Data Cache",
            detail: "Historical bars and cached market data.",
            bytes: summary.barsCacheBytes
        )
    ]
}

public func makeOldJobTelemetryCleanupPresentation(
    from job: JobRecord?
) -> OldJobTelemetryCleanupPresentation? {
    guard let job,
          let result = job.result?.objectValue,
          let jobsArea = result["areas"]?.arrayValue?.compactMap(\.objectValue).first(where: { area in
              area["area"]?.stringValue == "jobs"
          }),
          let details = jobsArea["details"]?.objectValue,
          details["cleanupKind"]?.stringValue == "job_telemetry"
    else {
        return nil
    }

    let cutoffText = details["cutoff"]?.stringValue ?? "-"
    let cutoff = DateCodec.parseISO8601(cutoffText)
    let dryRun = details["dryRun"]?.boolValue
        ?? jobsArea["dryRun"]?.boolValue
        ?? result["dryRun"]?.boolValue
        ?? true

    return OldJobTelemetryCleanupPresentation(
        dryRun: dryRun,
        cutoff: cutoff,
        cutoffText: cutoffText,
        cutoffSource: details["cutoffSource"]?.stringValue ?? "-",
        scannedCount: jsonInt(details["scannedCount"]),
        eligibleCount: jsonInt(details["eligibleCount"]),
        protectedCount: jsonInt(details["protectedCount"]),
        skippedDecodeErrorCount: jsonInt(details["skippedDecodeErrorCount"]),
        skippedLinkedProtectedCount: jsonInt(details["skippedLinkedProtectedCount"]),
        estimatedBytesReclaimable: Int64(jsonInt(details["estimatedBytesReclaimable"])),
        appliedCount: jsonInt(details["appliedCount"]),
        appliedBytes: Int64(jsonInt(details["appliedBytes"])),
        candidateCountByStatus: sortedBreakdownItems(details["candidateCountByStatus"]?.objectValue),
        candidateCountByType: sortedBreakdownItems(details["candidateCountByType"]?.objectValue),
        oldestCandidateTimestamp: nonEmptyString(details["oldestCandidateTimestamp"]?.stringValue),
        newestCandidateTimestamp: nonEmptyString(details["newestCandidateTimestamp"]?.stringValue),
        safetyExclusions: details["safetyExclusions"]?.arrayValue?.compactMap(\.stringValue) ?? []
    )
}

private func countSentence(
    _ count: Int,
    zero: String,
    singular: String,
    plural: String
) -> String {
    switch count {
    case 0:
        return zero
    case 1:
        return singular
    default:
        return plural
    }
}

private func sortedBreakdownItems(
    _ object: [String: JSONValue]?
) -> [OldJobTelemetryCleanupBreakdownItem] {
    (object ?? [:])
        .map { key, value in
            OldJobTelemetryCleanupBreakdownItem(label: key, count: jsonInt(value))
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.label < rhs.label
            }
            return lhs.count > rhs.count
        }
}

private func jsonInt(_ value: JSONValue?) -> Int {
    if let intValue = value?.intValue {
        return max(0, intValue)
    }
    if let doubleValue = value?.doubleValue {
        return max(0, Int(doubleValue.rounded()))
    }
    return 0
}

private func nonEmptyString(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false
    else {
        return nil
    }
    return trimmed
}

private func connectionIssueCount(state: String) -> Int {
    let normalized = state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "subscribed", "authenticated", "listening", "healthy":
        return 0
    default:
        return 1
    }
}

private func connectionIssueSummary(
    tradeConnectionState: String,
    marketDataConnectionState: String
) -> String {
    let tradeHealthy = connectionIssueCount(state: tradeConnectionState) == 0
    let marketHealthy = connectionIssueCount(state: marketDataConnectionState) == 0

    switch (tradeHealthy, marketHealthy) {
    case (true, true):
        return "Trade and market-data feeds look healthy."
    case (false, true):
        return "Trade updates are not fully connected yet."
    case (true, false):
        return "Market-data feed is not fully connected yet."
    case (false, false):
        return "Trade and market-data feeds both need attention."
    }
}

private func workerIssueSummary(
    snapshot: PMCommandCenterSnapshot,
    workerLinkConnected: Bool
) -> String {
    var parts: [String] = []
    if workerLinkConnected == false {
        parts.append("worker link unavailable")
    }
    if snapshot.failedDelegationsCount > 0 {
        parts.append(
            countSentence(
                snapshot.failedDelegationsCount,
                zero: "",
                singular: "1 failed launch",
                plural: "\(snapshot.failedDelegationsCount) failed launches"
            )
        )
    }
    if snapshot.degradedDelegationsCount > 0 {
        parts.append(
            countSentence(
                snapshot.degradedDelegationsCount,
                zero: "",
                singular: "1 degraded launch",
                plural: "\(snapshot.degradedDelegationsCount) degraded launches"
            )
        )
    }
    return parts.isEmpty ? "No worker-link or analyst-launch issues are active." : parts.joined(separator: ", ") + "."
}
