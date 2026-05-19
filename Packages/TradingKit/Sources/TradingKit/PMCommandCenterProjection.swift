import Foundation

public struct PMCommandCenterSnapshot: Sendable, Equatable {
    public static let empty = PMCommandCenterSnapshot(
        activeDelegationsCount: 0,
        pendingApprovalRequestsCount: 0,
        ownerActionableApprovalCount: 0,
        activeDecisionCount: 0,
        activeStandingRunCount: 0,
        pendingStandingReportReviewCount: 0,
        pmReviewQueueCount: 0,
        newSignalsCount: 0,
        fyiSignalsCount: 0,
        awaitingProposalCount: 0,
        degradedDelegationsCount: 0,
        failedDelegationsCount: 0
    )

    public let activeDelegationsCount: Int
    public let pendingApprovalRequestsCount: Int
    public let ownerActionableApprovalCount: Int
    public let activeDecisionCount: Int
    public let activeStandingRunCount: Int
    public let pendingStandingReportReviewCount: Int
    public let pmReviewQueueCount: Int
    public let newSignalsCount: Int
    public let fyiSignalsCount: Int
    public let awaitingProposalCount: Int
    public let degradedDelegationsCount: Int
    public let failedDelegationsCount: Int

    public var activeAnalystBackgroundCount: Int {
        activeDelegationsCount + activeStandingRunCount
    }

    public var activePMBackgroundCount: Int {
        pmReviewQueueCount
    }

    public init(
        activeDelegationsCount: Int,
        pendingApprovalRequestsCount: Int,
        ownerActionableApprovalCount: Int? = nil,
        activeDecisionCount: Int,
        activeStandingRunCount: Int = 0,
        pendingStandingReportReviewCount: Int = 0,
        pmReviewQueueCount: Int? = nil,
        newSignalsCount: Int,
        fyiSignalsCount: Int = 0,
        awaitingProposalCount: Int,
        degradedDelegationsCount: Int,
        failedDelegationsCount: Int
    ) {
        self.activeDelegationsCount = activeDelegationsCount
        self.pendingApprovalRequestsCount = pendingApprovalRequestsCount
        self.ownerActionableApprovalCount = max(0, ownerActionableApprovalCount ?? pendingApprovalRequestsCount)
        self.activeDecisionCount = activeDecisionCount
        self.activeStandingRunCount = activeStandingRunCount
        self.pendingStandingReportReviewCount = pendingStandingReportReviewCount
        self.pmReviewQueueCount = max(0, pmReviewQueueCount ?? pendingStandingReportReviewCount)
        self.newSignalsCount = newSignalsCount
        self.fyiSignalsCount = max(0, fyiSignalsCount)
        self.awaitingProposalCount = awaitingProposalCount
        self.degradedDelegationsCount = degradedDelegationsCount
        self.failedDelegationsCount = failedDelegationsCount
    }
}

public struct RunningJobSnapshot: Sendable, Equatable, Identifiable {
    public let jobId: String
    public let type: JobType
    public let status: JobStatus
    public let updatedAt: Date
    public let summary: String?

    public var id: String { jobId }

    public init(
        jobId: String,
        type: JobType,
        status: JobStatus,
        updatedAt: Date,
        summary: String?
    ) {
        self.jobId = jobId
        self.type = type
        self.status = status
        self.updatedAt = updatedAt
        self.summary = summary
    }
}

public func makePMCommandCenterSnapshot(
    delegations: [PMDelegationRecord],
    charters: [AnalystCharter],
    tasks: [AnalystTask],
    approvalRequests: [PMApprovalRequest],
    decisions: [PMDecisionRecord],
    standingReports: [AnalystStandingReport] = [],
    jobs: [JobSummary] = [],
    signals: [Signal],
    proposals: [ProposalRow]
) -> PMCommandCenterSnapshot {
    let ownerVisibleDelegations = delegations.filter { isExercisePMDelegation($0) == false }
    let ownerVisibleApprovalRequests = approvalRequests.filter { isExercisePMApprovalRequest($0) == false }
    let ownerVisibleDecisions = decisions.filter { isExercisePMDecision($0) == false }
    let ownerVisibleStandingReports = standingReports.filter {
        isExerciseArtifactIdentifier($0.reportId) == false
    }
    let ownerActionableApprovalCount = makeOwnerActionableApprovalRequests(
        approvalRequests: ownerVisibleApprovalRequests,
        decisions: ownerVisibleDecisions
    ).count
    let pendingStandingReportReviewCount = ownerVisibleStandingReports.filter {
        $0.deliveryStatus == .pendingPMReview
    }.count
    let activeStandingRunsCount = jobs.filter {
        $0.type == .standingAnalystReport && ($0.status == .queued || $0.status == .running)
    }.count
    let chartersByID = Dictionary(uniqueKeysWithValues: charters.map { ($0.charterId, $0) })
    let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.taskId, $0) })

    var degradedDelegationsCount = 0
    var failedDelegationsCount = 0
    let activeSignals = signals.filter { $0.status == .new && isSuppressedPMTestingSignal($0) == false }

    for delegation in ownerVisibleDelegations {
        let summary = makePMDelegationObservabilitySummary(
            delegation: delegation,
            charterDefaultRuntimePolicy: chartersByID[delegation.charterId]?.defaultRuntimePolicy,
            task: delegation.taskId.flatMap { tasksByID[$0] }
        )
        guard isActivePMDelegationWorkerIssue(delegation: delegation, summary: summary) else {
            continue
        }
        switch summary.launchHealth {
        case .degradedExternalEvidence:
            degradedDelegationsCount += 1
        case .failed:
            failedDelegationsCount += 1
        case .notLaunched, .healthy:
            break
        }
    }

    return PMCommandCenterSnapshot(
        activeDelegationsCount: ownerVisibleDelegations.filter {
            $0.status == .issued
                && $0.issueResolution == nil
                && isActivePMDelegationWorkerIssue(delegation: $0) == false
        }.count,
        pendingApprovalRequestsCount: ownerVisibleApprovalRequests.filter { $0.status == .pending }.count,
        ownerActionableApprovalCount: ownerActionableApprovalCount,
        activeDecisionCount: ownerVisibleDecisions.filter { $0.status == .active }.count,
        activeStandingRunCount: activeStandingRunsCount,
        pendingStandingReportReviewCount: pendingStandingReportReviewCount,
        pmReviewQueueCount: pendingStandingReportReviewCount,
        newSignalsCount: activeSignals.filter(\.countsAsOwnerFacingSignalReview).count,
        fyiSignalsCount: activeSignals.filter(\.countsAsFYIResearchAlert).count,
        awaitingProposalCount: proposals.filter { $0.status == .draft || $0.status == .proposed }.count,
        degradedDelegationsCount: degradedDelegationsCount,
        failedDelegationsCount: failedDelegationsCount
    )
}

public func makeRunningJobSnapshots(jobs: [JobSummary]) -> [RunningJobSnapshot] {
    jobs
        .filter { $0.status == .queued || $0.status == .running }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.jobId < rhs.jobId
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        .map {
            RunningJobSnapshot(
                jobId: $0.jobId,
                type: $0.type,
                status: $0.status,
                updatedAt: $0.updatedAt,
                summary: $0.message
            )
        }
}
