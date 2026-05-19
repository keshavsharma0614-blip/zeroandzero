import Foundation

public protocol AgentControlError: Error, Sendable {
    var code: String { get }
    var message: String { get }
}

extension StrategyRunnerError: AgentControlError {}

extension ProposalStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .proposalNotFound:
            return "proposal_not_found"
        }
    }

    public var message: String {
        switch self {
        case .proposalNotFound(let id):
            return "Proposal not found: \(id)"
        }
    }
}

extension PaperRunStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .runNotFound:
            return "run_not_found"
        }
    }

    public var message: String {
        switch self {
        case .runNotFound(let id):
            return "Run not found: \(id)"
        }
    }
}

extension JobStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .jobNotFound:
            return "job_not_found"
        }
    }

    public var message: String {
        switch self {
        case .jobNotFound(let id):
            return "Job not found: \(id)"
        }
    }
}

extension JobRunnerError: AgentControlError {}

extension RSSFeedStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .feedNotFound:
            return "rss_feed_not_found"
        case .invalidFeed:
            return "rss_feed_invalid"
        }
    }

    public var message: String {
        switch self {
        case .feedNotFound(let id):
            return "RSS feed not found: \(id)"
        case .invalidFeed(let message):
            return message
        }
    }
}

extension SignalStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .signalNotFound:
            return "signal_not_found"
        }
    }

    public var message: String {
        switch self {
        case .signalNotFound(let id):
            return "Signal not found: \(id)"
        }
    }
}

extension AnalystFindingSignalDraftError: AgentControlError {
    public var code: String {
        switch self {
        case .ineligibleFinding:
            return "analyst_finding_signal_ineligible"
        }
    }

    public var message: String {
        switch self {
        case .ineligibleFinding(let id, let reason):
            return "Analyst finding \(id) cannot draft a signal: \(reason)"
        }
    }
}

extension AnalystSignalProposalDraftError: AgentControlError {
    public var code: String {
        switch self {
        case .ineligibleSignal:
            return "analyst_signal_proposal_ineligible"
        }
    }

    public var message: String {
        switch self {
        case .ineligibleSignal(let id, let reason):
            return "Analyst signal \(id) cannot draft a proposal: \(reason)"
        }
    }
}

extension AnalystCharterStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .charterNotFound:
            return "analyst_charter_not_found"
        }
    }

    public var message: String {
        switch self {
        case .charterNotFound(let id):
            return "Analyst charter not found: \(id)"
        }
    }
}

extension AnalystTaskStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .taskNotFound:
            return "analyst_task_not_found"
        }
    }

    public var message: String {
        switch self {
        case .taskNotFound(let id):
            return "Analyst task not found: \(id)"
        }
    }
}

extension AnalystFindingStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .findingNotFound:
            return "analyst_finding_not_found"
        }
    }

    public var message: String {
        switch self {
        case .findingNotFound(let id):
            return "Analyst finding not found: \(id)"
        }
    }
}

extension AnalystEvidenceBundleStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .bundleNotFound:
            return "analyst_evidence_bundle_not_found"
        }
    }

    public var message: String {
        switch self {
        case .bundleNotFound(let id):
            return "Analyst evidence bundle not found: \(id)"
        }
    }
}

extension AnalystMemoStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .memoNotFound:
            return "analyst_memo_not_found"
        }
    }

    public var message: String {
        switch self {
        case .memoNotFound(let id):
            return "Analyst memo not found: \(id)"
        }
    }
}

extension PMProfileStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .profileNotFound:
            return "pm_profile_not_found"
        }
    }

    public var message: String {
        switch self {
        case .profileNotFound(let id):
            return "PM profile not found: \(id)"
        }
    }
}

extension PMMandateStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .mandateNotFound:
            return "pm_mandate_not_found"
        }
    }

    public var message: String {
        switch self {
        case .mandateNotFound(let id):
            return "PM mandate not found: \(id)"
        }
    }
}

extension PMInstructionStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .instructionNotFound:
            return "pm_instruction_not_found"
        }
    }

    public var message: String {
        switch self {
        case .instructionNotFound(let id):
            return "PM instruction not found: \(id)"
        }
    }
}

extension PMNotebookStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .entryNotFound:
            return "pm_notebook_entry_not_found"
        }
    }

    public var message: String {
        switch self {
        case .entryNotFound(let id):
            return "PM notebook entry not found: \(id)"
        }
    }
}

extension PortfolioStrategyBriefStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .briefNotFound:
            return "portfolio_strategy_brief_not_found"
        }
    }

    public var message: String {
        switch self {
        case .briefNotFound(let id):
            return "Portfolio strategy brief not found: \(id)"
        }
    }
}

extension PMDecisionStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .decisionNotFound:
            return "pm_decision_not_found"
        }
    }

    public var message: String {
        switch self {
        case .decisionNotFound(let id):
            return "PM decision not found: \(id)"
        }
    }
}

extension PMApprovalRequestStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .approvalRequestNotFound:
            return "pm_approval_request_not_found"
        }
    }

    public var message: String {
        switch self {
        case .approvalRequestNotFound(let id):
            return "PM approval request not found: \(id)"
        }
    }
}

extension PMCommunicationSessionStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .sessionNotFound:
            return "pm_communication_session_not_found"
        }
    }

    public var message: String {
        switch self {
        case .sessionNotFound(let id):
            return "PM communication session not found: \(id)"
        }
    }
}

extension PMCommunicationMessageStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .messageNotFound:
            return "pm_communication_message_not_found"
        }
    }

    public var message: String {
        switch self {
        case .messageNotFound(let id):
            return "PM communication message not found: \(id)"
        }
    }
}

extension PMDelegationStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .delegationNotFound:
            return "pm_delegation_not_found"
        }
    }

    public var message: String {
        switch self {
        case .delegationNotFound(let id):
            return "PM delegation not found: \(id)"
        }
    }
}

extension PMDecisionValidationError: AgentControlError {
    public var code: String { "bad_request" }

    public var message: String {
        switch self {
        case .pmIdRequired:
            return "PM decision pmId is required"
        case .titleRequired:
            return "PM decision title is required"
        case .summaryRequired:
            return "PM decision summary is required"
        }
    }
}

extension PMApprovalRequestValidationError: AgentControlError {
    public var code: String { "bad_request" }

    public var message: String {
        switch self {
        case .pmIdRequired:
            return "PM approval request pmId is required"
        case .subjectRequired:
            return "PM approval request subject is required"
        case .rationaleRequired:
            return "PM approval request rationale is required"
        }
    }
}

extension PMCommunicationSessionValidationError: AgentControlError {
    public var code: String { "bad_request" }

    public var message: String {
        switch self {
        case .sessionIdRequired:
            return "PM communication session id is required"
        }
    }
}

extension PMCommunicationMessageValidationError: AgentControlError {
    public var code: String {
        switch self {
        case .sessionNotFound:
            return "pm_communication_session_not_found"
        case .sessionIdRequired, .bodyRequired, .promotionTargetIdRequired:
            return "bad_request"
        }
    }

    public var message: String {
        switch self {
        case .sessionIdRequired:
            return "PM communication message session id is required"
        case .bodyRequired:
            return "PM communication message body is required"
        case .sessionNotFound(let id):
            return "PM communication session not found: \(id)"
        case .promotionTargetIdRequired:
            return "PM communication promotion target id is required"
        }
    }
}

extension AnalystRuntimePolicyValidationError: AgentControlError {
    public var code: String { "analyst_runtime_policy_invalid" }

    public var message: String {
        switch self {
        case .runtimeIdentifierRequired:
            return "Analyst runtime policy requires a non-empty runtimeIdentifier."
        }
    }
}

extension PMDelegationValidationError: AgentControlError {
    public var code: String {
        switch self {
        case .pmIdRequired,
             .charterIdRequired,
             .titleRequired,
             .rationaleRequired,
             .requestedOutputsRequired:
            return "bad_request"
        case .analystCharterMismatch, .analystTaskMismatch:
            return "pm_delegation_invalid_target"
        }
    }

    public var message: String {
        switch self {
        case .pmIdRequired:
            return "PM delegation requires a non-empty pmId."
        case .charterIdRequired:
            return "PM delegation requires a non-empty charterId."
        case .titleRequired:
            return "PM delegation requires a non-empty title."
        case .rationaleRequired:
            return "PM delegation requires a non-empty rationale."
        case .requestedOutputsRequired:
            return "PM delegation requires at least one requested output."
        case .analystCharterMismatch(let expected, let actual):
            return "PM delegation task/charter mismatch: expected charter \(expected), got \(actual)."
        case .analystTaskMismatch(let taskId):
            return "PM delegation task does not match the delegated analyst context: \(taskId)."
        }
    }
}

extension ScheduleStoreError: AgentControlError {
    public var code: String {
        switch self {
        case .scheduleNotFound:
            return "schedule_not_found"
        }
    }

    public var message: String {
        switch self {
        case .scheduleNotFound(let id):
            return "Schedule not found: \(id)"
        }
    }
}

extension SchedulerError: AgentControlError {
    public var code: String {
        switch self {
        case .scheduleNotFound:
            return "schedule_not_found"
        case .invalidSchedule:
            return "schedule_invalid"
        }
    }

    public var message: String {
        switch self {
        case .scheduleNotFound(let id):
            return "Schedule not found: \(id)"
        case .invalidSchedule(let message):
            return message
        }
    }
}

public enum StrategyProposalExecutionError: AgentControlError, Equatable {
    case strategyNotApprovedForPaper(proposalId: String)
    case proposalRequiresPaperEnvironment(proposalId: String)
    case proposalNotPaperOnly(proposalId: String)
    case reviewNotesRequired

    public var code: String {
        switch self {
        case .strategyNotApprovedForPaper:
            return "strategy_not_approved_for_paper"
        case .proposalRequiresPaperEnvironment:
            return "proposal_requires_paper_environment"
        case .proposalNotPaperOnly:
            return "proposal_not_paper_only"
        case .reviewNotesRequired:
            return "review_notes_required"
        }
    }

    public var message: String {
        switch self {
        case .strategyNotApprovedForPaper(let proposalId):
            return "Proposal \(proposalId) is not approved for paper runs."
        case .proposalRequiresPaperEnvironment(let proposalId):
            return "Proposal \(proposalId) can only run in paper environment."
        case .proposalNotPaperOnly(let proposalId):
            return "Proposal \(proposalId) is not marked as paper-only for this slice."
        case .reviewNotesRequired:
            return "Review notes are required."
        }
    }
}
