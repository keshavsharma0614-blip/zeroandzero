import Foundation
import TradingKit

@main
struct PMReasoningSmoke {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("pm_reasoning_smoke failed: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func run() async throws {
        let credentialResolution = OpenAIKeychainStatusProvider().credentialResolution()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pm-reasoning-smoke-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let newsStore = NewsStore(newsDirectory: root.appendingPathComponent("news", isDirectory: true))
        let engine = Engine(
            newsStore: newsStore,
            pmProfileStore: PMProfileStore(profilesDirectory: root.appendingPathComponent("profiles", isDirectory: true)),
            pmNotebookStore: PMNotebookStore(notebookDirectory: root.appendingPathComponent("notebook", isDirectory: true)),
            pmRuntimeSettingsStore: PMRuntimeSettingsStore(fileURL: root.appendingPathComponent("pm_runtime_settings.json", isDirectory: false)),
            portfolioStrategyBriefStore: PortfolioStrategyBriefStore(fileURL: root.appendingPathComponent("strategy_brief.json", isDirectory: false)),
            pmDecisionStore: PMDecisionStore(decisionsDirectory: root.appendingPathComponent("decisions", isDirectory: true)),
            pmApprovalRequestStore: PMApprovalRequestStore(approvalRequestsDirectory: root.appendingPathComponent("approval_requests", isDirectory: true)),
            pmCommunicationSessionStore: PMCommunicationSessionStore(sessionsDirectory: root.appendingPathComponent("sessions", isDirectory: true)),
            pmCommunicationMessageStore: PMCommunicationMessageStore(messagesDirectory: root.appendingPathComponent("messages", isDirectory: true)),
            pmDelegationStore: PMDelegationStore(delegationsDirectory: root.appendingPathComponent("delegations", isDirectory: true)),
            analystCharterStore: AnalystCharterStore(chartersDirectory: root.appendingPathComponent("charters", isDirectory: true)),
            analystMemoStore: AnalystMemoStore(memosDirectory: root.appendingPathComponent("memos", isDirectory: true)),
            analystStandingReportStore: AnalystStandingReportStore(reportsDirectory: root.appendingPathComponent("standing_reports", isDirectory: true)),
            analystExternalEvidenceProvider: SmokeExternalEvidenceProvider(),
            jobStore: JobStore(jobsDirectory: root.appendingPathComponent("jobs", isDirectory: true)),
            scheduleStore: ScheduleStore(fileURL: root.appendingPathComponent("schedules.json", isDirectory: false)),
            replaySleep: { _ in }
        )

        let now = Date()
        _ = try await engine.upsertPMProfile(
            PMProfile(
                pmId: "pm-1",
                displayName: "Primary PM",
                roleSummary: "Smoke-test PM profile.",
                createdAt: now,
                updatedAt: now
            ),
            source: AuditEventSource.ui
        )
        _ = try await engine.upsertPortfolioStrategyBrief(
            PortfolioStrategyBrief(
                title: "Current Portfolio Strategy Brief",
                documentBody: "Smoke-test strategy brief.",
                objectiveSummary: "Keep technology exposure deliberate while monitoring earnings risk.",
                keyThemes: ["AI infrastructure", "earnings discipline"],
                currentRiskPosture: "Constructive with tighter review around earnings clusters.",
                reviewEscalationPosture: "Escalate only material posture changes to the owner.",
                updatedBy: "smoke",
                updateSource: .userEdited,
                createdAt: now,
                updatedAt: now
            ),
            source: AuditEventSource.ui
        )
        await engine.store.applyPositionsRefreshSnapshot(
            positions: [
                try makePosition(symbol: "NVDA", qty: "10", side: "long", marketValue: "15000"),
                try makePosition(symbol: "MSFT", qty: "5", side: "long", marketValue: "8000")
            ]
        )
        await engine.store.setWatchlistSymbols(["AVGO", "INTC"])

        _ = try await newsStore.append([
            NewsEvent(
                eventId: "smoke-news-1",
                source: "smoke",
                title: "NVDA demand remains firm",
                url: "https://example.com/smoke-news-1",
                publishedAt: now,
                receivedAt: now,
                summary: "AI infrastructure demand remains firm into the next earnings window.",
                rawSymbolHints: ["NVDA", "AVGO"],
                tags: ["ai", "earnings"],
                payloadVersion: 1
            )
        ])

        _ = try await engine.listAnalystCharters()
        guard let schedule = makeStandingAnalystReportDefaultSchedules()
            .first(where: { $0.scheduleId == "standing-report-bench-sector-technology" })
        else {
            throw SmokeError("standing schedule missing")
        }
        _ = try await engine.upsertSchedule(schedule, source: AuditEventSource.ui)

        let scheduleSummary = try await engine.runScheduleNow(id: schedule.scheduleId, source: AuditEventSource.ui)
        guard let jobID = scheduleSummary.runningJobId else {
            throw SmokeError("standing job id missing")
        }
        let standingJob = try await waitForJob(engine: engine, jobID: jobID)
        guard standingJob.status == .succeeded else {
            let errorCode = standingJob.error?.code ?? "unknown"
            let errorMessage = standingJob.error?.message ?? standingJob.message ?? "no error message"
            throw SmokeError(
                "standing job failed status=\(standingJob.status.rawValue) code=\(errorCode) message=\(errorMessage)"
            )
        }

        let reports = try await engine.listAnalystStandingReports()
        guard let report = reports
            .filter({ $0.scheduleId == schedule.scheduleId })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first
        else {
            throw SmokeError("standing report missing after successful job")
        }
        let memos = try await engine.listAnalystMemos()
        guard let memo = memos.first(where: { $0.memoId == report.memoId }) else {
            throw SmokeError("standing memo missing")
        }

        _ = try await engine.completePendingStandingReviewCycle(source: AuditEventSource.ui)
        let decisions = try await engine.listPMDecisions()
        let decision = decisions.sorted { $0.updatedAt > $1.updatedAt }.first

        let session = try await engine.ensureInAppPMUserCommunicationSession(pmId: "pm-1")
        let ownerAsk = try await engine.createPMCommunicationMessage(
            sessionId: session.sessionId,
            senderRole: PMCommunicationSenderRole.owner,
            senderId: "owner",
            body: "How should I think about the current strategy and earnings risk?",
            source: AuditEventSource.ui
        )
        let reply = try await engine.generatePMConversationReply(to: ownerAsk.messageId, source: AuditEventSource.ui)

        print("openai_credential_status=\(credentialResolution.status.rawValue)")
        print("openai_credential_summary=\(credentialResolution.summary)")
        print("standing_requested_runtime=\(analystRequestedRuntimeText(memo.runtimeProvenance?.intendedPolicy))")
        print("standing_execution_used=\(analystExecutionUsedRuntimeText(memo.runtimeProvenance))")
        print("standing_used_openai=\(memo.runtimeProvenance?.actualRuntimeIdentifier.hasPrefix("openai_responses[") == true)")
        print("standing_fallback_state=\(memo.runtimeProvenance.map(standingFallbackState) ?? "none")")
        if let decisionRuntime = decision?.runtimeProvenance {
            print("pm_review_requested_runtime=\(pmRequestedRuntimeText(decisionRuntime))")
            print("pm_review_execution_used=\(pmExecutionUsedRuntimeText(decisionRuntime))")
            print("pm_review_used_openai=\(decisionRuntime.usedOpenAI)")
            print("pm_review_fallback_state=\(pmFallbackState(decisionRuntime))")
        } else {
            print("pm_review_requested_runtime=none")
            print("pm_review_execution_used=none")
            print("pm_review_used_openai=false")
            print("pm_review_fallback_state=no_runtime_recorded")
        }
        if let replyRuntime = reply.runtimeProvenance {
            print("pm_reply_requested_runtime=\(pmRequestedRuntimeText(replyRuntime))")
            print("pm_reply_execution_used=\(pmExecutionUsedRuntimeText(replyRuntime))")
            print("pm_reply_used_openai=\(replyRuntime.usedOpenAI)")
            print("pm_reply_fallback_state=\(pmFallbackState(replyRuntime))")
        } else {
            print("pm_reply_requested_runtime=none")
            print("pm_reply_execution_used=deterministic_local")
            print("pm_reply_used_openai=false")
            print("pm_reply_fallback_state=no_runtime_recorded")
        }
    }

    private static func waitForJob(engine: Engine, jobID: String) async throws -> JobRecord {
        for _ in 0..<600 {
            let job = try await engine.getJob(jobID: jobID)
            if job.status == .succeeded || job.status == .failed || job.status == .canceled {
                return job
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        throw SmokeError("job wait timed out for \(jobID)")
    }

    private static func makePosition(
        symbol: String,
        qty: String,
        side: String,
        marketValue: String
    ) throws -> Position {
        let payload = """
        {
          "symbol": "\(symbol)",
          "qty": "\(qty)",
          "side": "\(side)",
          "marketValue": "\(marketValue)"
        }
        """
        return try JSONDecoder().decode(Position.self, from: Data(payload.utf8))
    }

    private static func standingFallbackState(_ runtime: AnalystRuntimeProvenance) -> String {
        return runtime.actualRuntimeIdentifier
    }

    private static func pmFallbackState(_ runtime: PMRuntimeProvenance) -> String {
        if let issue = runtime.synthesisIssueSummary, issue.isEmpty == false {
            return "\(runtime.synthesisStatus):\(issue)"
        }
        return runtime.synthesisStatus
    }

    private struct SmokeError: LocalizedError {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? { message }
    }

    private struct SmokeExternalEvidenceProvider: ExternalAnalystEvidenceProviding {
        func fetchEvidence(
            for charter: AnalystCharter,
            task: AnalystTask,
            baselineNews: [NewsEvent],
            plannedSources: [ApprovedAnalystSourceDefinition]
        ) async -> AnalystExternalEvidenceFetchResult {
            _ = task
            _ = baselineNews
            _ = plannedSources
            return AnalystExternalEvidenceFetchResult(
                documents: [
                    ExternalAnalystEvidenceDocument(
                        sourceID: "smoke-anchor-\(charter.analystId)",
                        url: "https://example.com/\(charter.analystId)",
                        title: "\(charter.title) bounded smoke anchor",
                        observedAt: Date(),
                        summary: "Bounded smoke evidence for charter-governed standing synthesis.",
                        snippet: "Bounded smoke evidence for charter-governed standing synthesis.",
                        provenanceNote: "smoke_stubbed_external_evidence"
                    )
                ],
                issues: []
            )
        }
    }
}
