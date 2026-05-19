import Foundation

public enum PMDelegationLaunchHealth: String, Codable, Sendable, CaseIterable {
    case notLaunched = "Not launched"
    case healthy = "Healthy"
    case degradedExternalEvidence = "Degraded external evidence"
    case failed = "Launch failed"
}

public enum PMDelegationExecutionState: String, Codable, Sendable, CaseIterable {
    case pendingLaunch = "Pending launch"
    case running = "Running"
    case progressing = "Making progress"
    case completed = "Completed"
    case failed = "Failed"
    case stale = "Stale"
    case canceled = "Canceled"
}

public enum PMDelegationWorkflowState: String, Codable, Sendable, CaseIterable {
    case noOutputsYet = "No outputs yet"
    case awaitingDownstreamReview = "Awaiting downstream review"
    case resolved = "Resolved"
    case canceled = "Canceled"
}

public struct PMDelegationObservabilitySummary: Sendable, Equatable {
    public static let staleProgressThreshold: TimeInterval = 120

    public let intendedRuntimePolicy: AnalystRuntimePolicy?
    public let producedOutputs: [PMDelegationRequestedOutput]
    public let launchHealth: PMDelegationLaunchHealth
    public let executionState: PMDelegationExecutionState
    public let progressStage: String?
    public let progressSummary: String?
    public let lastProgressAt: Date?
    public let workflowState: PMDelegationWorkflowState

    public init(
        intendedRuntimePolicy: AnalystRuntimePolicy?,
        producedOutputs: [PMDelegationRequestedOutput],
        launchHealth: PMDelegationLaunchHealth,
        executionState: PMDelegationExecutionState = .pendingLaunch,
        progressStage: String? = nil,
        progressSummary: String? = nil,
        lastProgressAt: Date? = nil,
        workflowState: PMDelegationWorkflowState
    ) {
        self.intendedRuntimePolicy = intendedRuntimePolicy
        self.producedOutputs = producedOutputs
        self.launchHealth = launchHealth
        self.executionState = executionState
        self.progressStage = progressStage
        self.progressSummary = progressSummary
        self.lastProgressAt = lastProgressAt
        self.workflowState = workflowState
    }
}

public func makePMDelegationObservabilitySummary(
    delegation: PMDelegationRecord,
    charterDefaultRuntimePolicy: AnalystRuntimePolicy? = nil,
    task: AnalystTask? = nil,
    now: Date = Date()
) -> PMDelegationObservabilitySummary {
    let producedOutputs = pmDelegationProducedOutputs(delegation: delegation, task: task)
    let intendedRuntimePolicy = delegation.runtimePolicyOverride ?? charterDefaultRuntimePolicy

    let launchHealth: PMDelegationLaunchHealth
    switch delegation.lastLaunch?.status {
    case .healthy:
        launchHealth = .healthy
    case .degradedExternalEvidence:
        launchHealth = .degradedExternalEvidence
    case .failed:
        launchHealth = .failed
    case .running, .progressing:
        launchHealth = .healthy
    case .none:
        launchHealth = .notLaunched
    }

    let executionState: PMDelegationExecutionState
    if delegation.status == .canceled {
        executionState = .canceled
    } else if let lastLaunch = delegation.lastLaunch {
        switch lastLaunch.status {
        case .running:
            if pmDelegationLaunchIsStale(lastLaunch, now: now) {
                executionState = .stale
            } else {
                executionState = .running
            }
        case .progressing:
            if pmDelegationLaunchIsStale(lastLaunch, now: now) {
                executionState = .stale
            } else {
                executionState = .progressing
            }
        case .healthy, .degradedExternalEvidence:
            executionState = .completed
        case .failed:
            executionState = .failed
        }
    } else {
        executionState = .pendingLaunch
    }

    let workflowState: PMDelegationWorkflowState
    if delegation.status == .canceled {
        workflowState = .canceled
    } else if delegation.issueResolution != nil {
        workflowState = .resolved
    } else if producedOutputs.isEmpty {
        workflowState = .noOutputsYet
    } else {
        workflowState = .awaitingDownstreamReview
    }

    return PMDelegationObservabilitySummary(
        intendedRuntimePolicy: intendedRuntimePolicy,
        producedOutputs: producedOutputs,
        launchHealth: launchHealth,
        executionState: executionState,
        progressStage: delegation.lastLaunch?.progressStage,
        progressSummary: delegation.lastLaunch?.summary,
        lastProgressAt: delegation.lastLaunch?.lastProgressAt,
        workflowState: workflowState
    )
}

public func pmDelegationLaunchIsStale(
    _ launch: PMDelegationLastLaunch,
    now: Date,
    threshold: TimeInterval = PMDelegationObservabilitySummary.staleProgressThreshold
) -> Bool {
    switch launch.status {
    case .running, .progressing:
        let reference = launch.lastProgressAt ?? launch.launchedAt
        return now.timeIntervalSince(reference) > threshold
    case .healthy, .degradedExternalEvidence, .failed:
        return false
    }
}

public func isActivePMDelegationWorkerIssue(
    delegation: PMDelegationRecord,
    summary: PMDelegationObservabilitySummary? = nil
) -> Bool {
    guard delegation.issueResolution == nil else { return false }
    let resolvedSummary = summary ?? makePMDelegationObservabilitySummary(delegation: delegation)
    switch resolvedSummary.launchHealth {
    case .failed, .degradedExternalEvidence:
        return true
    case .notLaunched, .healthy:
        return false
    }
}

public func pmDelegationProducedOutputs(
    delegation: PMDelegationRecord,
    task: AnalystTask? = nil
) -> [PMDelegationRequestedOutput] {
    var outputs: [PMDelegationRequestedOutput] = []

    if !delegation.linkedFindingIDs.isEmpty {
        outputs.append(.finding)
    }
    if !delegation.linkedSignalIDs.isEmpty {
        outputs.append(.signal)
    }
    if !delegation.linkedProposalIDs.isEmpty {
        outputs.append(.proposalDraft)
    }
    if let task,
       task.taskId == delegation.taskId,
       let checkpoint = task.checkpoint,
       checkpoint.updatedAt >= delegation.createdAt {
        outputs.append(.checkpointUpdate)
    }

    return outputs
}
