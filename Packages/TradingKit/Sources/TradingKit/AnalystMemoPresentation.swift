import Foundation

public struct AnalystMemoPresentationSection: Sendable, Equatable, Identifiable {
    public let title: String
    public let body: String

    public var id: String { title }

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public struct AnalystMemoReadablePresentation: Sendable, Equatable {
    public let requestedModelSummary: String?
    public let executionUsedSummary: String?
    public let executiveSummary: String
    public let currentView: String
    public let recommendedNextStep: String
    public let confidenceSummary: String
    public let detailSections: [AnalystMemoPresentationSection]

    public init(
        requestedModelSummary: String?,
        executionUsedSummary: String?,
        executiveSummary: String,
        currentView: String,
        recommendedNextStep: String,
        confidenceSummary: String,
        detailSections: [AnalystMemoPresentationSection]
    ) {
        self.requestedModelSummary = requestedModelSummary
        self.executionUsedSummary = executionUsedSummary
        self.executiveSummary = executiveSummary
        self.currentView = currentView
        self.recommendedNextStep = recommendedNextStep
        self.confidenceSummary = confidenceSummary
        self.detailSections = detailSections
    }
}

public struct PMDelegationReadablePresentation: Sendable, Equatable {
    public let subheadline: String
    public let outcomeSummary: String
    public let requestedModelSummary: String
    public let executionUsedSummary: String
    public let latestOutputSummary: String
    public let detailSections: [AnalystMemoPresentationSection]

    public init(
        subheadline: String,
        outcomeSummary: String,
        requestedModelSummary: String,
        executionUsedSummary: String,
        latestOutputSummary: String,
        detailSections: [AnalystMemoPresentationSection]
    ) {
        self.subheadline = subheadline
        self.outcomeSummary = outcomeSummary
        self.requestedModelSummary = requestedModelSummary
        self.executionUsedSummary = executionUsedSummary
        self.latestOutputSummary = latestOutputSummary
        self.detailSections = detailSections
    }
}

public func makeAnalystMemoReadablePresentation(_ memo: AnalystMemo) -> AnalystMemoReadablePresentation {
    var detailSections: [AnalystMemoPresentationSection] = [
        AnalystMemoPresentationSection(title: "Supporting Evidence", body: memo.evidenceSummary),
        AnalystMemoPresentationSection(title: "Risks And Uncertainty", body: memo.uncertaintySummary)
    ]
    if memo.questionCoverage.isEmpty == false {
        detailSections.insert(
            AnalystMemoPresentationSection(
                title: "Question Coverage",
                body: makeAnalystMemoQuestionCoverageBody(memo.questionCoverage)
            ),
            at: 0
        )
    }

    let provenanceBody = makeAnalystMemoProvenanceBody(memo)
    if !provenanceBody.isEmpty {
        if memo.skillUsageSummaries.isEmpty == false {
            detailSections.append(
                AnalystMemoPresentationSection(
                    title: "Agent Skills Used / Considered",
                    body: makeAnalystMemoSkillUsageBody(memo.skillUsageSummaries)
                )
            )
        }
        detailSections.append(
            AnalystMemoPresentationSection(title: "Technical Provenance", body: provenanceBody)
        )
    }

    return AnalystMemoReadablePresentation(
        requestedModelSummary: memo.runtimeProvenance?.intendedPolicy.map(analystRequestedRuntimeText),
        executionUsedSummary: memo.runtimeProvenance.map(analystExecutionUsedRuntimeText),
        executiveSummary: memo.executiveSummary,
        currentView: memo.currentView,
        recommendedNextStep: memo.recommendedNextStep,
        confidenceSummary: analystConfidenceSummary(memo.confidence),
        detailSections: detailSections
    )
}

public func makeAnalystMemoQuestionCoverageBody(_ coverage: [AnalystQuestionCoverage]) -> String {
    coverage
        .prefix(12)
        .enumerated()
        .map { index, item in
            var parts = [
                "\(index + 1). \(item.status.displayTitle): \(item.question)",
                item.answerSummary
            ]
            if let sourceTier = item.sourceTierSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               sourceTier.isEmpty == false {
                parts.append("Sources: \(sourceTier)")
            }
            if let gap = item.remainingGap?.trimmingCharacters(in: .whitespacesAndNewlines),
               gap.isEmpty == false {
                parts.append("Gap: \(gap)")
            }
            return parts.joined(separator: " - ")
        }
        .joined(separator: "\n")
}

private func makeAnalystMemoSkillUsageBody(_ values: [AgentSkillUsageSummary]) -> String {
    values
        .prefix(8)
        .map { value in
            let sources = value.referenceSources.isEmpty
                ? ""
                : " • Sources: \(value.referenceSources.map(\.displayTitle).joined(separator: ", "))"
            return "\(value.skillTitle) (\(value.requirement.displayTitle), \(value.usage.displayTitle)\(sources)): \(value.usageSummary)"
        }
        .joined(separator: "\n")
}

public func makePMDelegationReadablePresentation(
    delegation: PMDelegationRecord,
    charterTitle: String?,
    taskTitle: String?,
    observability: PMDelegationObservabilitySummary,
    latestOutputSummary: String
) -> PMDelegationReadablePresentation {
    let titleParts = [charterTitle ?? delegation.charterId, taskTitle]
        .compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

    var detailSections: [AnalystMemoPresentationSection] = []
    if let rationale = nonEmpty(delegation.rationale) {
        detailSections.append(AnalystMemoPresentationSection(title: "Delegation Rationale", body: rationale))
    }
    let taskingBody = makePMTaskingBriefBody(delegation.taskingBrief)
    if !taskingBody.isEmpty {
        detailSections.append(AnalystMemoPresentationSection(title: "PM Tasking Brief", body: taskingBody))
    }
    if let launchSummary = delegation.lastLaunch?.summary, !launchSummary.isEmpty {
        detailSections.append(AnalystMemoPresentationSection(title: "Latest Launch Summary", body: launchSummary))
    }
    let executionBody = makePMDelegationExecutionBody(delegation: delegation, summary: observability)
    if !executionBody.isEmpty {
        detailSections.append(AnalystMemoPresentationSection(title: "Execution Progress", body: executionBody))
    }
    if let latestFollowUp = delegation.followUpActions.last {
        detailSections.append(
            AnalystMemoPresentationSection(
                title: "Latest PM Follow-Up",
                body: makePMAnalystFollowUpBody(latestFollowUp)
            )
        )
    }

    let linkageBody = makePMDelegationLinkageBody(delegation: delegation)
    if !linkageBody.isEmpty {
        detailSections.append(AnalystMemoPresentationSection(title: "Linked Artifacts", body: linkageBody))
    }

    return PMDelegationReadablePresentation(
        subheadline: titleParts.isEmpty ? delegation.analystId : titleParts.joined(separator: " • "),
        outcomeSummary: readableDelegationOutcomeSummary(
            delegation: delegation,
            summary: observability
        ),
        requestedModelSummary: analystRequestedRuntimeText(observability.intendedRuntimePolicy),
        executionUsedSummary: analystExecutionUsedRuntimeText(delegation.lastRuntimeProvenance),
        latestOutputSummary: latestOutputSummary,
        detailSections: detailSections
    )
}

private func makeAnalystMemoProvenanceBody(_ memo: AnalystMemo) -> String {
    var lines: [String] = []
    lines.append("Confidence: \(analystConfidenceSummary(memo.confidence))")
    if let requested = memo.runtimeProvenance?.intendedPolicy {
        lines.append("Requested model: \(analystRequestedRuntimeText(requested))")
    }
    if let runtime = memo.runtimeProvenance {
        lines.append("Execution used: \(analystExecutionUsedRuntimeText(runtime))")
        lines.append("Launched: \(DateCodec.formatISO8601(runtime.launchedAt))")
    }
    if let delegationId = nonEmpty(memo.delegationId) {
        lines.append("Delegation: \(delegationId)")
    }
    if let findingId = nonEmpty(memo.findingId) {
        lines.append("Finding: \(findingId)")
    }
    if let evidenceBundleId = nonEmpty(memo.evidenceBundleId) {
        lines.append("Evidence Bundle: \(evidenceBundleId)")
    }
    lines.append("Updated: \(DateCodec.formatISO8601(memo.updatedAt))")
    return lines.joined(separator: "\n")
}

private func makePMDelegationLinkageBody(delegation: PMDelegationRecord) -> String {
    var lines: [String] = []
    if !delegation.linkedFindingIDs.isEmpty {
        lines.append("Findings: \(delegation.linkedFindingIDs.joined(separator: ", "))")
    }
    if !delegation.linkedSignalIDs.isEmpty {
        lines.append("Signals: \(delegation.linkedSignalIDs.joined(separator: ", "))")
    }
    if !delegation.linkedProposalIDs.isEmpty {
        lines.append("Proposals: \(delegation.linkedProposalIDs.joined(separator: ", "))")
    }
    if let parentDelegationId = nonEmpty(delegation.parentDelegationId) {
        lines.append("Parent Delegation: \(parentDelegationId)")
    }
    if let sourceFollowUpActionId = nonEmpty(delegation.sourceFollowUpActionId) {
        lines.append("Source Follow-Up Action: \(sourceFollowUpActionId)")
    }
    return lines.joined(separator: "\n")
}

private func readableDelegationOutcomeSummary(
    delegation: PMDelegationRecord,
    summary: PMDelegationObservabilitySummary
) -> String {
    var parts: [String] = []

    switch summary.launchHealth {
    case .notLaunched:
        parts.append("No analyst launch has been recorded yet.")
    case .healthy:
        parts.append("The latest analyst launch is healthy.")
    case .degradedExternalEvidence:
        parts.append("The latest analyst launch is degraded by external evidence limits.")
    case .failed:
        parts.append("The latest analyst launch failed.")
    }

    switch summary.executionState {
    case .pendingLaunch:
        parts.append("The delegation is waiting for an explicit worker launch.")
    case .running:
        parts.append("The worker is running.")
    case .progressing:
        parts.append("The worker is making bounded progress.")
    case .completed:
        parts.append("The latest launch completed.")
    case .failed:
        parts.append("The latest launch ended in failure.")
    case .stale:
        parts.append("The latest launch appears stale because no recent progress heartbeat was recorded.")
    case .canceled:
        parts.append("The delegation is canceled.")
    }

    switch summary.workflowState {
    case .noOutputsYet:
        parts.append("No downstream output has been recorded yet.")
    case .awaitingDownstreamReview:
        parts.append("Useful downstream output is available for review.")
    case .resolved:
        parts.append("The worker issue has been resolved or dismissed from active owner surfaces; the history remains traceable.")
    case .canceled:
        parts.append("The delegation is canceled.")
    }

    if let resolution = delegation.issueResolution {
        parts.append("Resolution: \(resolution.summary)")
    }

    if delegation.status == .completed {
        parts.append("The delegation itself is marked completed.")
    }

    if let latestFollowUp = delegation.followUpActions.last {
        parts.append("Latest PM direction: \(makePMAnalystFollowUpGuidance(latestFollowUp.actionType).managerialIntent)")
    }

    return parts.joined(separator: " ")
}

private func makePMDelegationExecutionBody(
    delegation: PMDelegationRecord,
    summary: PMDelegationObservabilitySummary
) -> String {
    guard let launch = delegation.lastLaunch else {
        return ""
    }

    var lines = [
        "Execution state: \(summary.executionState.rawValue)",
        "Launched: \(DateCodec.formatISO8601(launch.launchedAt))"
    ]
    if let stage = summary.progressStage, !stage.isEmpty {
        lines.append("Stage: \(stage)")
    }
    if let lastProgressAt = summary.lastProgressAt {
        lines.append("Last progress: \(DateCodec.formatISO8601(lastProgressAt))")
    }
    if let completedAt = launch.completedAt {
        lines.append("Completed: \(DateCodec.formatISO8601(completedAt))")
    }
    if let issue = launch.lastIssueSummary, !issue.isEmpty {
        lines.append("Last issue: \(issue)")
    }
    if let resolution = delegation.issueResolution {
        lines.append("Issue resolution: \(resolution.reason.rawValue) at \(DateCodec.formatISO8601(resolution.resolvedAt)) by \(resolution.resolvedBy).")
        lines.append("Resolution summary: \(resolution.summary)")
        if let supersededBy = resolution.supersededByDelegationId, !supersededBy.isEmpty {
            lines.append("Superseded by delegation: \(supersededBy)")
        }
    }
    return lines.joined(separator: "\n")
}

private func analystConfidenceSummary(_ confidence: Double) -> String {
    "\(Int((min(max(confidence, 0), 1) * 100).rounded()))%"
}

private func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
