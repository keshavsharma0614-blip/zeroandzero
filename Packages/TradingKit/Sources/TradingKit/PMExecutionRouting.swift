import Foundation

public enum PMExecutionRoutingStatus: String, Sendable, Codable, CaseIterable {
    case executableNowPaper = "executable_now_paper"
    case executableNowLive = "executable_now_live"
    case blockedMissingProposalApproval = "blocked_missing_proposal_approval"
    case blockedLiveNotArmed = "blocked_live_not_armed"
    case blockedKillSwitch = "blocked_kill_switch"
    case blockedEnvironmentMismatch = "blocked_environment_mismatch"
    case blockedExecutionPrerequisites = "blocked_execution_prerequisites"
    case routedSuccessfully = "routed_successfully"
    case partiallyRouted = "partially_routed"
    case launchFailed = "launch_failed"
    case invalidState = "invalid_state"
}

public enum PMExecutionRoutingAction: String, Sendable, Codable, CaseIterable {
    case none
    case submitProposalForReview = "submit_proposal_for_review"
    case startProposalExecution = "start_proposal_execution"
    case submitWorkingPortfolioEstablishmentOrders = "submit_working_portfolio_establishment_orders"
    case submitLiveOrderReview = "submit_live_order_review"
}

public enum PMExecutionRoutingBlockReason: String, Sendable, Codable, CaseIterable {
    case ownerApprovalRequired = "owner_approval_required"
    case proposalNotLinked = "proposal_not_linked"
    case linkedProposalMissing = "linked_proposal_missing"
    case proposalApprovalRequired = "proposal_approval_required"
    case proposalDenied = "proposal_denied"
    case liveNotArmed = "live_not_armed"
    case killSwitchEnabled = "kill_switch_enabled"
    case environmentMismatch = "environment_mismatch"
    case workingPortfolioDefinitionMissing = "working_portfolio_definition_missing"
    case workingPortfolioExecutionPlanMissing = "working_portfolio_execution_plan_missing"
    case accountEquityUnavailable = "account_equity_unavailable"
    case alpacaTradingCredentialsUnavailable = "alpaca_trading_credentials_unavailable"
    case liveOrderReviewPayloadMissing = "live_order_review_payload_missing"
    case liveOrderReviewSizingUnsupported = "live_order_review_sizing_unsupported"
    case localAppRequiredForLiveExecution = "local_app_required_for_live_execution"
    case localAuthenticationBlocked = "local_authentication_blocked"
    case marketPriceUnavailable = "market_price_unavailable"
    case currentHoldingsPresent = "current_holdings_present"
    case orderSubmissionFailed = "order_submission_failed"
}

public struct PMExecutionRoutingAssessment: Sendable, Codable, Equatable {
    public let approvalRequestId: String
    public let decisionId: String?
    public let proposalId: String?
    public let proposalTitle: String?
    public let proposalStatus: StrategyProposalStatus?
    public let environment: Environment
    public let isLiveArmed: Bool
    public let killSwitchEnabled: Bool
    public let status: PMExecutionRoutingStatus
    public let action: PMExecutionRoutingAction
    public let summary: String
    public let detail: String
    public let blockedReasons: [PMExecutionRoutingBlockReason]

    public init(
        approvalRequestId: String,
        decisionId: String?,
        proposalId: String?,
        proposalTitle: String?,
        proposalStatus: StrategyProposalStatus?,
        environment: Environment,
        isLiveArmed: Bool,
        killSwitchEnabled: Bool,
        status: PMExecutionRoutingStatus,
        action: PMExecutionRoutingAction,
        summary: String,
        detail: String,
        blockedReasons: [PMExecutionRoutingBlockReason]
    ) {
        self.approvalRequestId = approvalRequestId
        self.decisionId = decisionId
        self.proposalId = proposalId
        self.proposalTitle = proposalTitle
        self.proposalStatus = proposalStatus
        self.environment = environment
        self.isLiveArmed = isLiveArmed
        self.killSwitchEnabled = killSwitchEnabled
        self.status = status
        self.action = action
        self.summary = summary
        self.detail = detail
        self.blockedReasons = blockedReasons
    }
}

public struct PMExecutionRoutingPresentation: Sendable, Equatable {
    public let statusTitle: String
    public let summary: String
    public let detail: String
    public let actionTitle: String?
    public let blockedReasonLines: [String]
    public let boundaryNote: String

    public init(
        statusTitle: String,
        summary: String,
        detail: String,
        actionTitle: String?,
        blockedReasonLines: [String],
        boundaryNote: String
    ) {
        self.statusTitle = statusTitle
        self.summary = summary
        self.detail = detail
        self.actionTitle = actionTitle
        self.blockedReasonLines = blockedReasonLines
        self.boundaryNote = boundaryNote
    }
}

public func pmExecutionRoutingStatusDisplayTitle(_ status: PMExecutionRoutingStatus) -> String {
    switch status {
    case .executableNowPaper:
        return "Executable Now in Paper"
    case .executableNowLive:
        return "Executable Now in Live"
    case .blockedMissingProposalApproval:
        return "Waiting on Proposal Approval"
    case .blockedLiveNotArmed:
        return "Blocked: Live Not Armed"
    case .blockedKillSwitch:
        return "Blocked: Kill Switch"
    case .blockedEnvironmentMismatch:
        return "Blocked: Environment Mismatch"
    case .blockedExecutionPrerequisites:
        return "Blocked: Execution Prerequisites Missing"
    case .routedSuccessfully:
        return "Routed Successfully"
    case .partiallyRouted:
        return "Partially Submitted"
    case .launchFailed:
        return "Route Failed"
    case .invalidState:
        return "Invalid State"
    }
}

public func pmExecutionRoutingActionDisplayTitle(_ action: PMExecutionRoutingAction) -> String? {
    switch action {
    case .none:
        return nil
    case .submitProposalForReview:
        return "Route Into Proposal Review"
    case .startProposalExecution:
        return "Route Through Existing Execution Path"
    case .submitWorkingPortfolioEstablishmentOrders:
        return "Submit Paper-Portfolio Orders"
    case .submitLiveOrderReview:
        return "Route Approved Live Order Review"
    }
}

public func pmExecutionRoutingBlockReasonDescription(_ reason: PMExecutionRoutingBlockReason) -> String {
    switch reason {
    case .ownerApprovalRequired:
        return "Owner approval on the PM request is still required before routing the next step."
    case .proposalNotLinked:
        return "This PM request is not linked to a proposal-backed next step."
    case .linkedProposalMissing:
        return "The linked proposal record is missing from the current app state."
    case .proposalApprovalRequired:
        return "The separate proposal review and approval path is not complete yet."
    case .proposalDenied:
        return "The linked proposal has already been denied for paper and cannot be routed into execution."
    case .liveNotArmed:
        return "Live is currently disarmed."
    case .killSwitchEnabled:
        return "Kill switch is enabled."
    case .environmentMismatch:
        return "The current app environment does not match the governed execution path for this proposal."
    case .workingPortfolioDefinitionMissing:
        return "The app does not have a machine-readable working paper-portfolio definition to execute."
    case .workingPortfolioExecutionPlanMissing:
        return "The current working paper-portfolio target could not be converted into an executable order plan."
    case .accountEquityUnavailable:
        return "Account equity is unavailable, so the app cannot size the paper-portfolio orders yet."
    case .alpacaTradingCredentialsUnavailable:
        return "Alpaca trading credentials are unavailable for the current environment, so the app cannot submit orders."
    case .liveOrderReviewPayloadMissing:
        return "The Live order review is missing a machine-readable order payload."
    case .liveOrderReviewSizingUnsupported:
        return "The Live order review cannot be converted into a positive concrete share quantity by the app-owned route."
    case .localAppRequiredForLiveExecution:
        return "Live order routing must be completed in the Mac app. Ordinary IPC cannot submit Live order reviews."
    case .localAuthenticationBlocked:
        return "Local macOS authentication did not authorize the Live order submission."
    case .marketPriceUnavailable:
        return "One or more symbols do not currently have usable market pricing for order sizing."
    case .currentHoldingsPresent:
        return "This narrow initial paper-establishment route only runs when confirmed holdings are still empty."
    case .orderSubmissionFailed:
        return "One or more paper-portfolio orders were rejected or failed during submission."
    }
}

public func makePMExecutionRoutingPresentation(
    assessment: PMExecutionRoutingAssessment
) -> PMExecutionRoutingPresentation {
    PMExecutionRoutingPresentation(
        statusTitle: pmExecutionRoutingStatusDisplayTitle(assessment.status),
        summary: assessment.summary,
        detail: assessment.detail,
        actionTitle: pmExecutionRoutingActionDisplayTitle(assessment.action),
        blockedReasonLines: assessment.blockedReasons.map(pmExecutionRoutingBlockReasonDescription),
        boundaryNote: "PM routing only moves approved intent into the existing governed proposal/order path. It does not approve proposals, change environment, arm Live, bypass the kill switch, or bypass the final LocalAuthentication gate for Live NEW/REPLACE orders."
    )
}
