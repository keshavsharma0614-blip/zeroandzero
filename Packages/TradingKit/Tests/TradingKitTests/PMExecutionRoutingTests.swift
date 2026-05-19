import Foundation
import Testing
@testable import TradingKit

@Test("PM execution routing can submit an approved next step into proposal review")
func pmExecutionRoutingSubmitsDraftProposalIntoReview() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-submit-review")
    let proposalStore = ProposalStore(proposalsDirectory: root.appendingPathComponent("proposals", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(
        configuration: Configuration(environment: .paper),
        pmApprovalRequestStore: approvalStore,
        proposalStore: proposalStore
    )
    let now = Date(timeIntervalSince1970: 1_742_600_000)

    _ = try await proposalStore.upsertProposal(makePMExecutionRoutingProposal(id: "proposal-1", status: .draft))
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-1",
            pmId: "pm-1",
            subject: "Route proposal into review",
            rationale: "The PM has owner approval to move the proposal into the existing review path.",
            requestType: .proposalReview,
            status: .resolved,
            proposalId: "proposal-1",
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.assessPMExecutionRouting(approvalRequestId: "approval-1")
    #expect(assessment.status == PMExecutionRoutingStatus.blockedMissingProposalApproval)
    #expect(assessment.action == PMExecutionRoutingAction.submitProposalForReview)
    #expect(assessment.blockedReasons.contains(PMExecutionRoutingBlockReason.proposalApprovalRequired))

    let routed = try await engine.routePMExecutionApprovedIntent(approvalRequestId: "approval-1")
    #expect(routed.status == PMExecutionRoutingStatus.routedSuccessfully)
    #expect(routed.action == PMExecutionRoutingAction.submitProposalForReview)

    let updatedProposal = try #require(await proposalStore.getProposal(id: "proposal-1"))
    #expect(updatedProposal.approval.status == .proposed)
}

@Test("PM execution routing keeps proposed proposals waiting on separate approval")
func pmExecutionRoutingProposedProposalWaitsForApproval() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-proposed-waits")
    let proposalStore = ProposalStore(proposalsDirectory: root.appendingPathComponent("proposals", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(
        configuration: Configuration(environment: .paper),
        pmApprovalRequestStore: approvalStore,
        proposalStore: proposalStore
    )
    let now = Date(timeIntervalSince1970: 1_742_600_100)

    _ = try await proposalStore.upsertProposal(makePMExecutionRoutingProposal(id: "proposal-2", status: .proposed))
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-2",
            pmId: "pm-1",
            subject: "Wait on proposal approval",
            rationale: "The proposal is already in review.",
            requestType: .proposalReview,
            status: .resolved,
            proposalId: "proposal-2",
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.assessPMExecutionRouting(approvalRequestId: "approval-2")
    #expect(assessment.status == PMExecutionRoutingStatus.blockedMissingProposalApproval)
    #expect(assessment.action == PMExecutionRoutingAction.none)
    #expect(assessment.blockedReasons.contains(PMExecutionRoutingBlockReason.proposalApprovalRequired))
}

@Test("PM execution routing can launch approved paper proposal through existing path")
func pmExecutionRoutingLaunchesApprovedPaperProposal() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-paper-launch")
    let proposalStore = ProposalStore(proposalsDirectory: root.appendingPathComponent("proposals", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let paperRunStore = PaperRunStore(runsDirectory: root.appendingPathComponent("runs", isDirectory: true))
    let engine = Engine(
        configuration: Configuration(environment: .paper),
        pmApprovalRequestStore: approvalStore,
        proposalStore: proposalStore,
        paperRunStore: paperRunStore
    )
    let now = Date(timeIntervalSince1970: 1_742_600_200)

    _ = try await proposalStore.upsertProposal(makePMExecutionRoutingProposal(id: "proposal-3", status: .approvedPaper))
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-3",
            pmId: "pm-1",
            subject: "Launch approved paper proposal",
            rationale: "Owner approved the next paper-safe step.",
            requestType: .proposalReview,
            status: .resolved,
            proposalId: "proposal-3",
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.assessPMExecutionRouting(approvalRequestId: "approval-3")
    #expect(assessment.status == PMExecutionRoutingStatus.executableNowPaper)
    #expect(assessment.action == PMExecutionRoutingAction.startProposalExecution)

    let routed = try await engine.routePMExecutionApprovedIntent(approvalRequestId: "approval-3")
    #expect(routed.status == PMExecutionRoutingStatus.routedSuccessfully)
    #expect(routed.action == PMExecutionRoutingAction.startProposalExecution)

    let runs = try await paperRunStore.listRuns(proposalId: "proposal-3")
    #expect(runs.count == 1)
    _ = try await engine.stopStrategy(id: "heartbeat")
}

@Test("PM execution routing shows live environment mismatch and disarmed posture")
func pmExecutionRoutingLiveEnvironmentMismatchIncludesDisarmedReason() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-mismatch")
    let proposalStore = ProposalStore(proposalsDirectory: root.appendingPathComponent("proposals", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        proposalStore: proposalStore
    )
    let now = Date(timeIntervalSince1970: 1_742_600_300)

    _ = try await proposalStore.upsertProposal(makePMExecutionRoutingProposal(id: "proposal-4", status: .approvedPaper))
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-4",
            pmId: "pm-1",
            subject: "Attempt live route",
            rationale: "Live should stay blocked because the governed path is still paper-only.",
            requestType: .proposalReview,
            status: .resolved,
            proposalId: "proposal-4",
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.assessPMExecutionRouting(approvalRequestId: "approval-4")
    #expect(assessment.status == PMExecutionRoutingStatus.blockedEnvironmentMismatch)
    #expect(assessment.blockedReasons.contains(PMExecutionRoutingBlockReason.environmentMismatch))
    #expect(assessment.blockedReasons.contains(PMExecutionRoutingBlockReason.liveNotArmed))
}

@Test("PM execution routing surfaces kill switch as a live readiness blocker")
func pmExecutionRoutingSurfacesKillSwitchBlocker() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-kill-switch")
    let proposalStore = ProposalStore(proposalsDirectory: root.appendingPathComponent("proposals", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        proposalStore: proposalStore
    )
    let now = Date(timeIntervalSince1970: 1_742_600_400)

    await engine.setKillSwitchEnabled(true)
    _ = try await proposalStore.upsertProposal(makePMExecutionRoutingProposal(id: "proposal-5", status: .approvedPaper))
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-5",
            pmId: "pm-1",
            subject: "Live kill switch check",
            rationale: "The PM should see kill switch posture even when the path remains paper-governed.",
            requestType: .proposalReview,
            status: .resolved,
            proposalId: "proposal-5",
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.assessPMExecutionRouting(approvalRequestId: "approval-5")
    #expect(assessment.blockedReasons.contains(PMExecutionRoutingBlockReason.killSwitchEnabled))

    let presentation = makePMExecutionRoutingPresentation(assessment: assessment)
    #expect(presentation.blockedReasonLines.contains { $0.contains("Kill switch") })
}

@Test("PM execution routing requires owner approval before routing")
func pmExecutionRoutingRequiresOwnerApproval() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-owner-approval")
    let proposalStore = ProposalStore(proposalsDirectory: root.appendingPathComponent("proposals", isDirectory: true))
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let engine = Engine(
        configuration: Configuration(environment: .paper),
        pmApprovalRequestStore: approvalStore,
        proposalStore: proposalStore
    )
    let now = Date(timeIntervalSince1970: 1_742_600_500)

    _ = try await proposalStore.upsertProposal(makePMExecutionRoutingProposal(id: "proposal-6", status: .approvedPaper))
    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-6",
            pmId: "pm-1",
            subject: "Needs owner approval",
            rationale: "The PM cannot route this before the owner responds.",
            requestType: .proposalReview,
            status: .pending,
            proposalId: "proposal-6",
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.assessPMExecutionRouting(approvalRequestId: "approval-6")
    #expect(assessment.status == PMExecutionRoutingStatus.invalidState)
    #expect(assessment.blockedReasons == [PMExecutionRoutingBlockReason.ownerApprovalRequired])
}

@Test("Approving Live order review reaches local auth and cancel blocks before REST")
func approvingLiveOrderReviewReachesLocalAuthAndCancelBlocksBeforeREST() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-review-auth-cancel")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let authStore = LiveExecutionProtectionSettingsStore(
        fileURL: root.appendingPathComponent("live_execution_protection.json", isDirectory: false)
    )
    let now = Date(timeIntervalSince1970: 1_742_600_600)
    _ = try await authStore.upsert(
        LiveExecutionProtectionSettings.default(now: now)
            .updating(required: true, updatedBy: "test", updateSource: .ui, now: now)
    )
    let rest = PMExecutionRoutingMockRESTClient()
    let auth = PMExecutionRoutingLocalUserPresenceAuthorizer(results: [
        LocalUserPresenceAuthorizationResult(
            status: .canceled,
            summary: "Owner canceled test auth.",
            checkedAt: now
        )
    ])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        restClientFactory: { _ in rest },
        liveExecutionProtectionSettingsStore: authStore,
        localUserPresenceAuthorizer: auth
    )
    _ = await engine.armLiveTrading()

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-live-cancel",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner asked to review a Live META order.",
            requestType: .liveOrderReview,
            status: .pending,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                quantity: 1,
                instructionSummary: "Buy one META share at market for day."
            ),
            createdAt: now,
            updatedAt: now
        )
    )

    let approved = try await engine.respondToPMApprovalRequest(
        requestId: "approval-live-cancel",
        response: .approved,
        source: .ui
    )

    #expect(approved.ownerResponse == .approved)
    #expect(approved.lastExecutionRoutingAssessment?.action == .submitLiveOrderReview)
    #expect(approved.lastExecutionRoutingAssessment?.status == .blockedExecutionPrerequisites)
    #expect(approved.lastExecutionRoutingAssessment?.blockedReasons == [.localAuthenticationBlocked])
    #expect(approved.lastExecutionRoutingAssessment?.summary.contains("local authentication was canceled") == true)
    #expect(await auth.challengeCount() == 1)
    #expect(await rest.placeOrderCallCount() == 0)
}

@Test("Approving Live order review with auth success submits through Engine order path")
func approvingLiveOrderReviewWithAuthSuccessSubmitsThroughEngineOrderPath() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-review-auth-success")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let authStore = LiveExecutionProtectionSettingsStore(
        fileURL: root.appendingPathComponent("live_execution_protection_success.json", isDirectory: false)
    )
    let now = Date(timeIntervalSince1970: 1_742_600_700)
    _ = try await authStore.upsert(
        LiveExecutionProtectionSettings.default(now: now)
            .updating(required: true, updatedBy: "test", updateSource: .ui, now: now)
    )
    let rest = PMExecutionRoutingMockRESTClient()
    let auth = PMExecutionRoutingLocalUserPresenceAuthorizer(results: [.success(checkedAt: now)])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        restClientFactory: { _ in rest },
        liveExecutionProtectionSettingsStore: authStore,
        localUserPresenceAuthorizer: auth
    )
    _ = await engine.armLiveTrading()

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-live-submit",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner asked to review a Live META order.",
            requestType: .liveOrderReview,
            status: .pending,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "meta",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                quantity: 2,
                instructionSummary: "Buy two META shares at market for day."
            ),
            createdAt: now,
            updatedAt: now
        )
    )

    let approved = try await engine.respondToPMApprovalRequest(
        requestId: "approval-live-submit",
        response: .approved,
        source: .ui
    )
    let placed = try #require(await rest.lastPlacedOrder())

    #expect(approved.lastExecutionRoutingAssessment?.status == .routedSuccessfully)
    #expect(approved.lastExecutionRoutingAssessment?.action == .submitLiveOrderReview)
    #expect(await auth.challengeCount() == 1)
    #expect(await rest.placeOrderCallCount() == 1)
    #expect(placed.symbol == "META")
    #expect(placed.qty == "2")
    #expect(placed.side == .buy)
    #expect(placed.type == .market)
    #expect(placed.timeInForce == .day)
}

@Test("IPC cannot route approved Live order review into Live order submission")
func ipcCannotRouteApprovedLiveOrderReviewIntoLiveSubmission() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-review-ipc-block")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let authStore = LiveExecutionProtectionSettingsStore(
        fileURL: root.appendingPathComponent("live_execution_protection_ipc_block.json", isDirectory: false)
    )
    let now = Date(timeIntervalSince1970: 1_742_600_720)
    _ = try await authStore.upsert(
        LiveExecutionProtectionSettings.default(now: now)
            .updating(required: true, updatedBy: "test", updateSource: .ui, now: now)
    )
    let rest = PMExecutionRoutingMockRESTClient()
    let auth = PMExecutionRoutingLocalUserPresenceAuthorizer(results: [.success(checkedAt: now)])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        restClientFactory: { _ in rest },
        liveExecutionProtectionSettingsStore: authStore,
        localUserPresenceAuthorizer: auth
    )
    _ = await engine.armLiveTrading()

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-live-ipc",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner approved a Live META order review in the Mac app.",
            requestType: .liveOrderReview,
            status: .resolved,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                quantity: 2,
                instructionSummary: "Buy two META shares at market for day."
            ),
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.routePMExecutionApprovedIntent(
        approvalRequestId: "approval-live-ipc",
        source: .ipc
    )
    let stored = try await engine.getPMApprovalRequest(id: "approval-live-ipc")

    #expect(assessment.status == .blockedExecutionPrerequisites)
    #expect(assessment.action == .none)
    #expect(assessment.blockedReasons == [.localAppRequiredForLiveExecution])
    #expect(assessment.summary.contains("Mac app") == true)
    #expect(assessment.detail.contains("Ordinary IPC") == true)
    #expect(stored.status == .resolved)
    #expect(stored.ownerResponse == .approved)
    #expect(stored.liveOrderExecutionLifecycleState == nil)
    #expect(stored.lastExecutionRoutingAssessment?.blockedReasons == [.localAppRequiredForLiveExecution])
    #expect(await auth.challengeCount() == 0)
    #expect(await rest.placeOrderCallCount() == 0)
}

@Test("Filled Live order review records lifecycle and PM completion follow-through")
func filledLiveOrderReviewRecordsLifecycleAndPMCompletionFollowThrough() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-review-fill-follow-through")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let sessionStore = PMCommunicationSessionStore(sessionsDirectory: root.appendingPathComponent("communication_sessions", isDirectory: true))
    let messageStore = PMCommunicationMessageStore(messagesDirectory: root.appendingPathComponent("communication_messages", isDirectory: true))
    let rest = PMExecutionRoutingMockRESTClient()
    let auth = PMExecutionRoutingLocalUserPresenceAuthorizer(results: [.success()])
    let now = Date(timeIntervalSince1970: 1_742_600_760)
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        pmCommunicationSessionStore: sessionStore,
        pmCommunicationMessageStore: messageStore,
        restClientFactory: { _ in rest },
        localUserPresenceAuthorizer: auth,
        nowDate: { now }
    )
    _ = await engine.armLiveTrading()
    _ = try await engine.upsertPMCommunicationSession(
        PMCommunicationSession(
            sessionId: "pm-user-in-app-default",
            channel: .inApp,
            pmId: "pm-1",
            participantId: "owner",
            participantDisplayName: "Owner",
            status: .active,
            createdAt: now,
            updatedAt: now
        )
    )
    _ = try await engine.upsertPMCommunicationMessage(
        PMCommunicationMessage(
            messageId: "owner-live-order-message",
            sessionId: "pm-user-in-app-default",
            direction: .incoming,
            senderRole: .owner,
            senderId: "owner",
            body: "Purchase two META shares live.",
            sentAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-live-fill",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner asked to review a Live META order.",
            sourceCommunicationMessageId: "owner-live-order-message",
            requestType: .liveOrderReview,
            status: .resolved,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                quantity: 2
            ),
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.routePMExecutionApprovedIntent(approvalRequestId: "approval-live-fill")
    let submitted = try await engine.getPMApprovalRequest(id: "approval-live-fill")
    #expect(assessment.status == .routedSuccessfully)
    #expect(submitted.liveOrderExecutionLifecycleState?.status == .submitted)
    #expect(submitted.liveOrderExecutionLifecycleState?.orderId == "ord-live-review-1")

    await engine.processTradeUpdate(
        TradeUpdateEvent(
            event: "fill",
            orderID: "ord-live-review-1",
            symbol: "META",
            side: "buy",
            qty: "2",
            filledQty: "2",
            filledAvgPrice: "600.12",
            timestamp: DateCodec.formatISO8601(now.addingTimeInterval(5)),
            orderStatus: "filled"
        ),
        allowRESTRepairs: false
    )

    let completed = try await engine.getPMApprovalRequest(id: "approval-live-fill")
    let lifecycle = try #require(completed.liveOrderExecutionLifecycleState)
    #expect(lifecycle.status == .filled)
    #expect(lifecycle.filledQuantity == "2")
    #expect(lifecycle.averageFillPrice == "600.12")
    #expect(lifecycle.positionQuantity == "2")
    #expect(lifecycle.completionFollowThroughMessageId != nil)

    let messages = try await engine.listPMCommunicationMessages()
    let followThrough = try #require(messages.first(where: { $0.messageId == lifecycle.completionFollowThroughMessageId }))
    #expect(followThrough.body.contains("The Live META buy completed."))
    #expect(followThrough.body.contains("Filled quantity: 2."))
    #expect(followThrough.body.contains("Live portfolio now records 2 META shares."))
    #expect(followThrough.body.contains("ord-live-review") == false)

    await engine.processTradeUpdate(
        TradeUpdateEvent(
            event: "fill",
            orderID: "ord-live-review-1",
            symbol: "META",
            side: "buy",
            qty: "2",
            filledQty: "2",
            filledAvgPrice: "600.12",
            timestamp: DateCodec.formatISO8601(now.addingTimeInterval(6)),
            orderStatus: "filled"
        ),
        allowRESTRepairs: false
    )
    let afterDuplicate = try await engine.listPMCommunicationMessages()
        .filter { $0.body.contains("The Live META buy completed.") }
    #expect(afterDuplicate.count == 1)
}

@Test("Live order review with notional and usable Store price computes nearest share and submits through Engine")
func liveOrderReviewWithNotionalAndStorePriceComputesNearestShareAndSubmits() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-review-notional-price")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let authStore = LiveExecutionProtectionSettingsStore(
        fileURL: root.appendingPathComponent("live_execution_protection_notional.json", isDirectory: false)
    )
    let rest = PMExecutionRoutingMockRESTClient()
    let auth = PMExecutionRoutingLocalUserPresenceAuthorizer(results: [.success()])
    let now = Date(timeIntervalSince1970: 1_742_600_800)
    _ = try await authStore.upsert(
        LiveExecutionProtectionSettings.default(now: now)
            .updating(required: true, updatedBy: "test", updateSource: .ui, now: now)
    )
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        restClientFactory: { _ in rest },
        liveExecutionProtectionSettingsStore: authStore,
        localUserPresenceAuthorizer: auth,
        nowDate: { now }
    )
    _ = await engine.armLiveTrading()
    await engine.store.publishMarketTrade(
        MarketDataTradeEvent(
            symbol: "META",
            price: 598.86,
            size: 100,
            timestamp: DateCodec.formatISO8601(now)
        )
    )

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-live-notional",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner asked to review a notional Live META order.",
            requestType: .liveOrderReview,
            status: .resolved,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                notionalAmount: Decimal(10_000),
                instructionSummary: "Buy roughly ten thousand dollars of META."
            ),
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.routePMExecutionApprovedIntent(approvalRequestId: "approval-live-notional")
    let placed = try #require(await rest.lastPlacedOrder())

    #expect(assessment.status == .routedSuccessfully)
    #expect(assessment.action == .submitLiveOrderReview)
    #expect(assessment.detail.contains("nearest whole-share quantity 17"))
    #expect(await auth.challengeCount() == 1)
    #expect(await rest.placeOrderCallCount() == 1)
    #expect(placed.symbol == "META")
    #expect(placed.qty == "17")
    #expect(placed.side == .buy)
    #expect(placed.type == .market)
    #expect(placed.timeInForce == .day)
}

@Test("Live order review with notional and no usable price blocks precisely before auth and REST")
func liveOrderReviewWithNotionalAndNoUsablePriceBlocksBeforeAuthAndREST() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-review-notional-missing-price")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let rest = PMExecutionRoutingMockRESTClient()
    let auth = PMExecutionRoutingLocalUserPresenceAuthorizer(results: [.success()])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        restClientFactory: { _ in rest },
        localUserPresenceAuthorizer: auth
    )
    _ = await engine.armLiveTrading()
    let now = Date(timeIntervalSince1970: 1_742_600_850)

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-live-notional-no-price",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner asked to review a notional Live META order.",
            requestType: .liveOrderReview,
            status: .resolved,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                notionalAmount: Decimal(10_000),
                instructionSummary: "Buy roughly ten thousand dollars of META to the nearest share."
            ),
            ownerResponse: .approved,
            ownerRespondedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let assessment = try await engine.routePMExecutionApprovedIntent(approvalRequestId: "approval-live-notional-no-price")

    #expect(assessment.status == .blockedExecutionPrerequisites)
    #expect(assessment.action == .submitLiveOrderReview)
    #expect(assessment.blockedReasons == [.marketPriceUnavailable])
    #expect(assessment.summary.contains("waiting for a usable META price"))
    #expect(assessment.detail.contains("No order has been sent"))
    #expect(await auth.challengeCount() == 0)
    #expect(await rest.placeOrderCallCount() == 0)
}

@Test("Rejected Live order review does not route")
func rejectedLiveOrderReviewDoesNotRoute() async throws {
    let root = makePMExecutionRoutingTempDirectory(name: "pm-execution-live-review-reject")
    let approvalStore = PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true))
    let rest = PMExecutionRoutingMockRESTClient()
    let auth = PMExecutionRoutingLocalUserPresenceAuthorizer(results: [.success()])
    let engine = Engine(
        configuration: Configuration(environment: .live),
        pmApprovalRequestStore: approvalStore,
        restClientFactory: { _ in rest },
        localUserPresenceAuthorizer: auth
    )
    _ = await engine.armLiveTrading()
    let now = Date(timeIntervalSince1970: 1_742_600_900)

    _ = try await engine.upsertPMApprovalRequest(
        PMApprovalRequest(
            approvalRequestId: "approval-live-reject",
            pmId: "pm-1",
            subject: "Approve Live META buy review",
            rationale: "Owner asked to review a Live META order.",
            requestType: .liveOrderReview,
            status: .pending,
            liveOrderReview: PMLiveOrderReviewPayload(
                symbol: "META",
                side: .buy,
                orderType: .market,
                timeInForce: .day,
                quantity: 1
            ),
            createdAt: now,
            updatedAt: now
        )
    )

    let rejected = try await engine.respondToPMApprovalRequest(
        requestId: "approval-live-reject",
        response: .rejected,
        source: .ui
    )

    #expect(rejected.ownerResponse == .rejected)
    #expect(rejected.lastExecutionRoutingAssessment == nil)
    #expect(await auth.challengeCount() == 0)
    #expect(await rest.placeOrderCallCount() == 0)
}

private func makePMExecutionRoutingTempDirectory(name: String) -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests", isDirectory: true)
        .appendingPathComponent(name + "-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private actor PMExecutionRoutingLocalUserPresenceAuthorizer: LocalUserPresenceAuthorizing {
    private var queuedResults: [LocalUserPresenceAuthorizationResult]
    private var recordedChallenges: [LocalUserPresenceChallenge] = []

    init(results: [LocalUserPresenceAuthorizationResult]) {
        self.queuedResults = results
    }

    func authorize(challenge: LocalUserPresenceChallenge) async -> LocalUserPresenceAuthorizationResult {
        recordedChallenges.append(challenge)
        if queuedResults.isEmpty {
            return LocalUserPresenceAuthorizationResult(
                status: .systemError,
                summary: "No queued test authorization result.",
                checkedAt: Date(timeIntervalSince1970: 0)
            )
        }
        return queuedResults.removeFirst()
    }

    func challengeCount() -> Int {
        recordedChallenges.count
    }
}

private actor PMExecutionRoutingMockRESTClient: AlpacaRESTServing {
    private var placeOrderInvocations = 0
    private var placedOrders: [NewOrderRequest] = []

    func fetchAccount() async throws -> Account {
        Account(
            id: "acct-test",
            status: "ACTIVE",
            cash: "100000",
            buyingPower: "200000",
            equity: "100000",
            multiplier: "2"
        )
    }

    func fetchPositions() async throws -> [Position] {
        []
    }

    func fetchOpenOrders() async throws -> [Order] {
        []
    }

    func fetchAsset(symbol: String) async throws -> Asset {
        Asset(symbol: symbol.uppercased(), tradable: true, marginable: true, shortable: true)
    }

    func fetchOptionContract(symbolOrID: String) async throws -> OptionContract {
        OptionContract(id: "opt-\(symbolOrID)", symbol: symbolOrID, underlyingSymbol: nil)
    }

    func placeOrder(request: NewOrderRequest) async throws -> Order {
        placeOrderInvocations += 1
        placedOrders.append(request)
        return Order(
            id: "ord-live-review-\(placeOrderInvocations)",
            symbol: request.symbol,
            qty: request.qty,
            side: request.side.rawValue,
            type: request.type.rawValue,
            timeInForce: request.timeInForce.rawValue,
            status: "new"
        )
    }

    func replaceOrder(orderId: String, request: ReplaceOrderRequest) async throws -> Order {
        Order(
            id: "ord-replace-\(orderId)",
            symbol: "META",
            qty: request.qty ?? "1",
            side: "buy",
            type: "limit",
            timeInForce: "day",
            status: "new"
        )
    }

    func cancelOrder(orderId: String) async throws {}

    func placeOrderCallCount() -> Int {
        placeOrderInvocations
    }

    func lastPlacedOrder() -> NewOrderRequest? {
        placedOrders.last
    }
}

private func makePMExecutionRoutingProposal(
    id: String,
    status: StrategyProposalStatus
) -> StrategyProposal {
    StrategyProposal(
        proposalId: id,
        createdAt: Date(timeIntervalSince1970: 1_742_600_000),
        updatedAt: Date(timeIntervalSince1970: 1_742_600_000),
        createdBy: "pm",
        title: "PM execution routing test",
        summary: "Route approved PM intent through the governed proposal path.",
        strategyId: "heartbeat",
        parameters: ["intervalSec": .number(0.2)],
        scope: StrategyProposalScope(symbols: ["AAPL"]),
        intendedEnvironmentPaperOnly: true,
        constraints: StrategyProposalConstraints(
            maxOrdersPerMinute: 5,
            maxNotionalPerOrder: Decimal(string: "1000")!,
            maxDailyNotional: Decimal(string: "5000"),
            allowShort: false,
            allowOptions: false
        ),
        testPlan: StrategyProposalTestPlan(
            durationMinutes: 15,
            successMetrics: ["No crashes"],
            stopConditions: ["Excess errors"]
        ),
        rationale: "Exercise PM execution routing.",
        approval: StrategyProposalApproval(status: status)
    )
}
