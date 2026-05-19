import Foundation
import Testing
@testable import TradingKit

@Test("Legacy example analyst charter remains deterministic for bounded worker compatibility")
func seededAnalystCharterDeterministic() throws {
    let now = Date(timeIntervalSince1970: 1_700_500_000)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)

    #expect(charter.charterId == "technology-innovation-research")
    #expect(charter.analystId == "technology-innovation-research-analyst")
    #expect(charter.title == "Technology Innovation Research Analyst")
    #expect(charter.coverageScope.contains("Technology companies"))
    #expect(charter.strategyFamily.contains("Public example"))
    #expect(charter.summary.contains("Public example charter"))
    #expect(charter.duties.contains(where: { $0.contains("supply constraints") }))
    #expect(charter.constraints.contains(where: { $0.contains("No auto-trade") }))
    #expect(charter.expectedOutputs.contains(where: { $0.contains("support, refute, delay, or reshape") }))
    #expect(charter.allowedSources.contains("app_news"))
    #expect(charter.allowedSources.contains("approved_external_sources"))
    #expect(charter.allowedSources.contains("approved_allowlist_source:stanford_ai_index"))
    #expect(charter.sourcePolicy.reputableWebResearchAllowed == true)
    #expect(charter.sourcePolicy.preferredSources.contains("Stanford AI Index Report"))
    #expect(charter.createdAt == now)
    #expect(charter.updatedAt == now)
}

@Test("Standing analyst bench seed is deterministic and role-aware")
func standingAnalystBenchSeedDeterministic() throws {
    let now = Date(timeIntervalSince1970: 1_700_500_000)
    let charters = StandingAnalystBenchSeed().seededCharters(now: now)

    #expect(charters.count == 9)
    #expect(Set(charters.map(\.charterId)).count == 9)
    #expect(charters.filter { $0.benchRole == .sector }.count == 6)
    #expect(charters.filter { $0.benchRole == .overlay }.count == 3)
    #expect(charters.contains { $0.title == "Technology Analyst" && $0.benchRole == .sector })
    #expect(charters.contains { $0.title == recentNewsStandingAnalystTitle && $0.benchRole == .overlay })
    #expect(charters.contains { $0.title == "Macro and International Analyst" && $0.benchRole == .overlay })
    #expect(charters.contains { $0.title == "Portfolio Risk Analyst" && $0.summary.contains("future bounded trigger-based invocation") })
    #expect(charters.allSatisfy { $0.defaultRuntimePolicy == nil })
    #expect(charters.allSatisfy { $0.primaryDocumentBody.contains("# Analyst Charter") })
    #expect(charters.contains { $0.charterId == recentNewsStandingAnalystCharterID && $0.primaryDocumentBody.contains("Recent News Analyst") })
    #expect(charters.contains { $0.charterId == "bench-overlay-macro-international" && $0.primaryDocumentBody.contains("Macro & International Analyst") })
    #expect(charters.contains { $0.charterId == "bench-overlay-portfolio-risk" && $0.primaryDocumentBody.contains("focused on actual portfolio risk") })
    #expect(charters.contains { $0.charterId == "bench-overlay-portfolio-risk" && $0.primaryDocumentBody.contains("### Risk Metrics And Calculation Guidance") })
}

@Test("Engine removes the duplicate legacy analyst charter while keeping the standing Technology Analyst")
func engineRemovesLegacyDuplicateCharterDuringBenchSeeding() async throws {
    let root = makeAnalystTempDirectory(name: "legacy-charter-cleanup")
    let charterStore = AnalystCharterStore(chartersDirectory: root)
    let now = Date(timeIntervalSince1970: 1_700_500_500)

    _ = try await charterStore.upsert(AnalystCharterSeed().makeInitialCharter(now: now))

    let engine = Engine(
        analystCharterStore: charterStore
    )

    let charters = try await engine.listAnalystCharters()

    #expect(charters.contains { $0.title == "Technology Analyst" && $0.charterId == "bench-sector-technology" })
    #expect(charters.contains { $0.charterId == AnalystCharterSeed.charterId } == false)
    #expect(try await charterStore.get(id: AnalystCharterSeed.charterId) == nil)
}

@Test("Analyst worker CLI invocation includes explicit charter and optional task args")
func analystWorkerCLIInvocationBuildsExplicitArgs() throws {
    let invocation = try CLIAnalystWorkerLauncher.makeInvocation(
        request: AnalystWorkerLaunchRequest(
            charterId: "charter-1",
            taskId: "task-9",
            delegationId: "delegation-1",
            pmId: "pm-1",
            intendedRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5",
                reasoningMode: .deliberate,
                policySource: .pmDelegationOverride,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            draftSignal: true
        )
    )

    #expect(invocation.executableURL.lastPathComponent == "xcrun" || invocation.executableURL.lastPathComponent == "alpaca_analyst_worker")
    if invocation.executableURL.lastPathComponent == "xcrun" {
        #expect(invocation.arguments.starts(with: [
            "swift",
            "run",
            "--package-path"
        ]))
        #expect(invocation.arguments.contains("alpaca_analyst_worker"))
    } else {
        #expect(invocation.arguments.first == "run-once")
    }
    #expect(invocation.arguments.contains("run-once"))
    #expect(invocation.arguments.contains("--charter-id"))
    #expect(invocation.arguments.contains("charter-1"))
    #expect(invocation.arguments.contains("--task-id"))
    #expect(invocation.arguments.contains("task-9"))
    #expect(invocation.arguments.contains("--delegation-id"))
    #expect(invocation.arguments.contains("delegation-1"))
    #expect(invocation.arguments.contains("--pm-id"))
    #expect(invocation.arguments.contains("pm-1"))
    #expect(invocation.arguments.contains("--provider-kind"))
    #expect(invocation.arguments.contains("openai"))
    #expect(invocation.arguments.contains("--credential-profile-id"))
    #expect(invocation.arguments.contains(LLMCredentialProfile.openAIDefaultProfileID))
    #expect(invocation.arguments.contains("--runtime-id"))
    #expect(invocation.arguments.contains("gpt-5"))
    #expect(invocation.arguments.contains("--reasoning-mode"))
    #expect(invocation.arguments.contains("deliberate"))
    #expect(invocation.arguments.contains("--runtime-policy-source"))
    #expect(invocation.arguments.contains("pm_delegation_override"))
    #expect(invocation.arguments.contains("--draft-signal"))
    #expect(invocation.environment["TRADINGKIT_APP_SUPPORT_ROOT"]?.isEmpty == false)
    #expect(FileManager.default.fileExists(atPath: invocation.workingDirectoryURL.appendingPathComponent("AlgoTradingMac.xcworkspace").path))
}

@Test("Analyst worker CLI invocation carries app-support root for standing and PM delegation launches")
func analystWorkerCLIInvocationCarriesAppSupportRootForAllLaunchTypes() throws {
    let standingInvocation = try CLIAnalystWorkerLauncher.makeInvocation(
        request: AnalystWorkerLaunchRequest(
            charterId: "bench-sector-technology",
            taskId: "standing-task-1"
        )
    )
    let pmDelegationInvocation = try CLIAnalystWorkerLauncher.makeInvocation(
        request: AnalystWorkerLaunchRequest(
            charterId: "bench-sector-technology",
            taskId: "pm-task-1",
            delegationId: "delegation-1",
            pmId: "pm-1"
        )
    )

    let expectedRoot = AppSupportPaths.rootDirectory().path
    #expect(standingInvocation.environment["TRADINGKIT_APP_SUPPORT_ROOT"] == expectedRoot)
    #expect(pmDelegationInvocation.environment["TRADINGKIT_APP_SUPPORT_ROOT"] == expectedRoot)
    #expect(pmDelegationInvocation.arguments.contains("--delegation-id"))
    #expect(pmDelegationInvocation.arguments.contains("delegation-1"))
}

@Test("Analyst worker CLI invocation preserves Anthropic provider and credential profile across worker boundary")
func analystWorkerCLIInvocationPreservesAnthropicRuntimePolicy() throws {
    let invocation = try CLIAnalystWorkerLauncher.makeInvocation(
        request: AnalystWorkerLaunchRequest(
            charterId: "bench-overlay-portfolio-risk",
            intendedRuntimePolicy: AnalystRuntimePolicy(
                providerKind: .anthropic,
                credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
                runtimeIdentifier: "claude-sonnet-4-6",
                reasoningMode: .standard,
                policySource: .standingBenchDefault,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
    )

    #expect(invocation.arguments.contains("--provider-kind"))
    #expect(invocation.arguments.contains("anthropic"))
    #expect(invocation.arguments.contains("--credential-profile-id"))
    #expect(invocation.arguments.contains(LLMCredentialProfile.anthropicDefaultProfileID))
    #expect(invocation.arguments.contains("--runtime-id"))
    #expect(invocation.arguments.contains("claude-sonnet-4-6"))
    #expect(invocation.arguments.contains("--runtime-policy-source"))
    #expect(invocation.arguments.contains("standing_bench_default"))
}

@Test("CLI analyst worker launcher reuses the app session OpenAI key for preflight and run-once launches")
func cliAnalystWorkerLauncherUsesSessionOpenAIKey() async throws {
    actor SessionKeyRecorder {
        private(set) var runKeys: [String?] = []
        private(set) var preflightKeys: [String?] = []
        private(set) var runProviders: [LLMProviderKind?] = []
        private(set) var preflightProviders: [LLMProviderKind?] = []

        func recordRun(_ credential: AnalystWorkerSessionCredential?) {
            runKeys.append(credential?.apiKey)
            runProviders.append(credential?.providerKind)
        }

        func recordPreflight(_ credential: AnalystWorkerSessionCredential?) {
            preflightKeys.append(credential?.apiKey)
            preflightProviders.append(credential?.providerKind)
        }
    }

    let recorder = SessionKeyRecorder()
    let launcher = CLIAnalystWorkerLauncher(
        invocationFactory: { _ in
            AnalystWorkerCLIInvocation(
                executableURL: URL(fileURLWithPath: "/usr/bin/true"),
                arguments: ["alpaca_analyst_worker", "run-once"],
                workingDirectoryURL: URL(fileURLWithPath: "/tmp", isDirectory: true),
                environment: ProcessInfo.processInfo.environment
            )
        },
        runner: { invocation, sessionCredential in
            await recorder.recordRun(sessionCredential)
            return AnalystWorkerLaunchResult(
                charterId: invocation.arguments.first ?? "charter-1",
                taskId: nil,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                summary: "ok",
                outputExcerpt: "ok"
            )
        },
        preflightRunner: { sessionCredential in
            await recorder.recordPreflight(sessionCredential)
            return true
        },
        sessionCredentialProvider: { _ in
            AnalystWorkerSessionCredential(providerKind: .openAI, apiKey: "session-openai-key")
        }
    )

    _ = try await launcher.preflightOpenAIKeyAccess()
    _ = try await launcher.runOnce(
        request: AnalystWorkerLaunchRequest(charterId: "charter-1")
    )

    #expect(await recorder.preflightKeys == ["session-openai-key"])
    #expect(await recorder.runKeys == ["session-openai-key"])
    #expect(await recorder.preflightProviders == [.openAI])
    #expect(await recorder.runProviders == [.openAI])
}

@Test("CLI analyst worker launcher can hand Anthropic session key to run-once without OpenAI fallback")
func cliAnalystWorkerLauncherUsesAnthropicSessionCredentialForAnthropicRun() async throws {
    actor SessionCredentialRecorder {
        private(set) var runCredentials: [AnalystWorkerSessionCredential?] = []

        func recordRun(_ credential: AnalystWorkerSessionCredential?) {
            runCredentials.append(credential)
        }
    }

    let recorder = SessionCredentialRecorder()
    let launcher = CLIAnalystWorkerLauncher(
        invocationFactory: { request in
            let invocation = try CLIAnalystWorkerLauncher.makeInvocation(request: request)
            return AnalystWorkerCLIInvocation(
                executableURL: URL(fileURLWithPath: "/usr/bin/true"),
                arguments: invocation.arguments,
                workingDirectoryURL: URL(fileURLWithPath: "/tmp", isDirectory: true),
                environment: invocation.environment
            )
        },
        runner: { invocation, sessionCredential in
            await recorder.recordRun(sessionCredential)
            return AnalystWorkerLaunchResult(
                charterId: invocation.arguments.first ?? "charter-1",
                taskId: nil,
                findingId: nil,
                findingTitle: nil,
                draftedSignalId: nil,
                runtimeProvenance: AnalystRuntimeProvenance(
                    intendedPolicy: AnalystRuntimePolicy(
                        providerKind: .anthropic,
                        credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
                        runtimeIdentifier: "claude-sonnet-4-6",
                        reasoningMode: .standard,
                        policySource: .standingBenchDefault,
                        createdAt: Date(timeIntervalSince1970: 0),
                        updatedAt: Date(timeIntervalSince1970: 0)
                    ),
                    actualRuntimeIdentifier: "anthropic_messages[claude-sonnet-4-6]",
                    actualReasoningMode: .standard,
                    launchedAt: Date(timeIntervalSince1970: 1)
                ),
                synthesisStatus: "anthropic_messages",
                summary: "ok",
                outputExcerpt: "ok"
            )
        },
        preflightRunner: { _ in true },
        sessionCredentialProvider: { request in
            guard request.intendedRuntimePolicy?.providerKind == .anthropic else { return nil }
            return AnalystWorkerSessionCredential(providerKind: .anthropic, apiKey: "session-anthropic-key")
        }
    )

    _ = try await launcher.runOnce(
        request: AnalystWorkerLaunchRequest(
            charterId: "bench-overlay-portfolio-risk",
            intendedRuntimePolicy: AnalystRuntimePolicy(
                providerKind: .anthropic,
                credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
                runtimeIdentifier: "claude-sonnet-4-6",
                reasoningMode: .standard,
                policySource: .standingBenchDefault,
                createdAt: Date(timeIntervalSince1970: 0),
                updatedAt: Date(timeIntervalSince1970: 0)
            )
        )
    )

    let credential = try #require(await recorder.runCredentials.first ?? nil)
    #expect(credential.providerKind == .anthropic)
    #expect(credential.apiKey == "session-anthropic-key")
}

@Test("Analyst worker CLI summary parsing returns bounded operator result")
func analystWorkerCLISummaryParsing() throws {
    let stdout = """
    alpaca_analyst_worker run-once succeeded
    progress_event: {"reportedAt":"2023-11-14T12:45:20Z","stage":"context_resolved","summary":"Current charter, task, and app-owned context were resolved."}
    charter_seeded: false
    openai_key_configured: true
    used_openai: false
    pm_id: pm-1
    delegation_id: delegation-1
    analyst_id: technology-research-analyst
    charter_id: charter-1
    task_id: task-9
    resolved_runtime_identifier: gpt-5
    resolved_reasoning_mode: deliberate
    resolved_runtime_policy_source: pm_delegation_override
    actual_runtime_identifier: deterministic_local[gpt-5]
    actual_reasoning_mode: deliberate
    runtime_launched_at: 2023-11-14T12:45:26Z
    news_items: 2
    external_evidence_items: 1
    external_evidence_issue_count: 1
    external_evidence_status: partial
    external_evidence_issue_summary: category=http_status host=aiindex.stanford.edu status=503 detail=non_success_status
    synthesis_status: fallback_openai_error
    synthesis_issue_summary: openai_provider_timeout
    evidence_bundle_id: bundle-1
    finding_id: finding-1
    finding_title: Adoption friction persists
    memo_id: memo-1
    memo_title: Adoption Friction Memo
    drafted_signal_id: sig-1
    drafted_proposal_id: proposal-1
    """

    let result = try CLIAnalystWorkerLauncher.parseSummary(from: stdout)

    #expect(result.charterId == "charter-1")
    #expect(result.taskId == "task-9")
    #expect(result.delegationId == "delegation-1")
    #expect(result.pmId == "pm-1")
    #expect(result.openAIKeyConfigured == true)
    #expect(result.usedOpenAI == false)
    #expect(result.findingId == "finding-1")
    #expect(result.findingTitle == "Adoption friction persists")
    #expect(result.memoId == "memo-1")
    #expect(result.memoTitle == "Adoption Friction Memo")
    #expect(result.draftedSignalId == "sig-1")
    #expect(result.draftedProposalId == "proposal-1")
    #expect(result.runtimeProvenance?.intendedPolicy?.runtimeIdentifier == "gpt-5")
    #expect(result.runtimeProvenance?.intendedPolicy?.policySource == .pmDelegationOverride)
    #expect(result.runtimeProvenance?.actualRuntimeIdentifier == "deterministic_local[gpt-5]")
    #expect(result.runtimeProvenance?.actualReasoningMode == .deliberate)
    #expect(result.externalEvidenceStatus == "partial")
    #expect(result.externalEvidenceIssueSummary?.contains("category=http_status") == true)
    #expect(result.synthesisStatus == "fallback_openai_error")
    #expect(result.synthesisIssueSummary == "openai_provider_timeout")
    #expect(result.summary.contains("finding: Adoption friction persists"))
    #expect(result.summary.contains("memo: Adoption Friction Memo"))
    #expect(result.summary.contains("signal: sig-1"))
    #expect(result.summary.contains("proposal: proposal-1"))
    #expect(result.summary.contains("runtime: deterministic_local[gpt-5]"))
    #expect(result.summary.contains("provider: local deterministic fallback (openai_provider_timeout)"))
    #expect(result.summary.contains("external: partial") == true)
}

@Test("Analyst worker CLI summary infers OpenAI runtime truth when provider flags are present")
func analystWorkerCLISummaryInfersOpenAIRuntimeTruthWhenProviderFlagsArePresent() throws {
    let stdout = """
    alpaca_analyst_worker run-once succeeded
    charter_seeded: false
    openai_key_configured: true
    used_openai: true
    pm_id: pm-1
    delegation_id: delegation-1
    analyst_id: recent-news-material-impact-analyst
    charter_id: charter-1
    task_id: task-9
    resolved_runtime_identifier: gpt-5.4-mini
    resolved_reasoning_mode: standard
    resolved_runtime_policy_source: specialization_default
    actual_runtime_identifier: -
    actual_reasoning_mode: standard
    runtime_launched_at: 2023-11-14T12:45:26Z
    news_items: 3
    external_evidence_items: 2
    external_evidence_issue_count: 0
    external_evidence_status: ok
    external_evidence_issue_summary: -
    synthesis_status: openai_responses
    synthesis_issue_summary: -
    evidence_bundle_id: bundle-1
    finding_id: finding-1
    finding_title: Recent news materiality review
    memo_id: memo-1
    memo_title: Recent News Analyst memo
    drafted_signal_id: -
    drafted_proposal_id: -
    """

    let result = try CLIAnalystWorkerLauncher.parseSummary(from: stdout)

    #expect(result.usedOpenAI == true)
    #expect(result.synthesisStatus == "openai_responses")
    #expect(result.runtimeProvenance?.intendedPolicy?.runtimeIdentifier == "gpt-5.4-mini")
    #expect(result.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-5.4-mini]")
    #expect(result.summary.contains("provider: OpenAI Responses API"))
}

@Test("Analyst worker CLI summary preserves Anthropic runtime provenance")
func analystWorkerCLISummaryInfersAnthropicRuntimeTruthWhenProviderFlagsArePresent() throws {
    let stdout = """
    alpaca_analyst_worker run-once succeeded
    charter_seeded: false
    openai_key_configured: true
    used_openai: false
    pm_id: pm-1
    delegation_id: -
    analyst_id: bench-overlay-portfolio-risk-analyst
    charter_id: bench-overlay-portfolio-risk
    task_id: task-risk
    resolved_runtime_identifier: claude-sonnet-4-6
    resolved_provider_kind: anthropic
    resolved_credential_profile_id: anthropic-default
    resolved_reasoning_mode: standard
    resolved_runtime_policy_source: standing_bench_default
    actual_runtime_identifier: -
    actual_reasoning_mode: standard
    runtime_launched_at: 2023-11-14T12:45:26Z
    news_items: 3
    external_evidence_items: 2
    external_evidence_issue_count: 0
    external_evidence_status: ok
    external_evidence_issue_summary: -
    synthesis_status: anthropic_messages
    synthesis_issue_summary: -
    evidence_bundle_id: bundle-1
    finding_id: finding-1
    finding_title: Portfolio risk posture
    memo_id: memo-1
    memo_title: Portfolio Risk memo
    drafted_signal_id: -
    drafted_proposal_id: -
    """

    let result = try CLIAnalystWorkerLauncher.parseSummary(from: stdout)

    #expect(result.usedOpenAI == false)
    #expect(result.synthesisStatus == "anthropic_messages")
    #expect(result.runtimeProvenance?.intendedPolicy?.providerKind == .anthropic)
    #expect(result.runtimeProvenance?.intendedPolicy?.credentialProfileId == LLMCredentialProfile.anthropicDefaultProfileID)
    #expect(result.runtimeProvenance?.intendedPolicy?.runtimeIdentifier == "claude-sonnet-4-6")
    #expect(result.runtimeProvenance?.intendedPolicy?.policySource == .standingBenchDefault)
    #expect(result.runtimeProvenance?.actualRuntimeIdentifier == "anthropic_messages[claude-sonnet-4-6]")
    #expect(result.runtimeProvenance?.actualReasoningMode == .standard)
    #expect(result.summary.contains("provider: Anthropic Messages API"))
    #expect(analystActualRuntimeText(result.runtimeProvenance).contains("Anthropic Messages model claude-sonnet-4-6"))
}

@Test("Analyst worker CLI progress parsing returns bounded update")
func analystWorkerCLIProgressParsing() throws {
    let line = #"progress_event: {"reportedAt":"2023-11-14T12:45:26Z","stage":"evidence_ready","summary":"App-owned context is ready; direct analyst LLM public-web research will run inside synthesis.","issueSummary":"category=http_status host=example.com status=503 detail=non_success_status"}"#

    let update = try #require(CLIAnalystWorkerLauncher.parseProgressUpdate(from: line))

    #expect(update.reportedAt == parseISO("2023-11-14T12:45:26Z"))
    #expect(update.stage == "evidence_ready")
    #expect(update.summary == "App-owned context is ready; direct analyst LLM public-web research will run inside synthesis.")
    #expect(update.issueSummary?.contains("category=http_status") == true)
}

@Test("Analyst worker emits bounded lifecycle progress updates during run")
func analystWorkerEmitsBoundedProgressUpdates() async throws {
    final class ProgressRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var updates: [AnalystWorkerProgressUpdate] = []

        func append(_ update: AnalystWorkerProgressUpdate) {
            lock.lock()
            updates.append(update)
            lock.unlock()
        }

        func all() -> [AnalystWorkerProgressUpdate] {
            lock.lock()
            defer { lock.unlock() }
            return updates
        }
    }

    let now = Date(timeIntervalSince1970: 1_744_000_000)
    let charter = AnalystCharter(
        charterId: "charter-progress",
        analystId: "analyst-progress",
        title: "Progress Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Exercise bounded progress reporting.",
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-progress",
        analystId: "analyst-progress",
        charterId: "charter-progress",
        title: "Progress Task",
        description: "Track lifecycle progress updates.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-progress",
                source: "rss_marketwatch",
                title: "Progress event input",
                url: "https://example.com/progress",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Use one bounded input for progress testing.",
                rawSymbolHints: ["NVDA"],
                tags: ["ai"],
                payloadVersion: 1
            )
        ]
    )
    let recorder = ProgressRecorder()
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { now.addingTimeInterval(20) }
    )

    _ = try await service.runOnce(
        charterID: "charter-progress",
        taskID: "task-progress",
        newsLimit: 5,
        reportProgress: { update in
            recorder.append(update)
        }
    )

    let updates = recorder.all()
    #expect(updates.map(\.stage) == [
        "launch_started",
        "context_resolved",
        "evidence_ready",
        "synthesis_complete",
        "artifacts_persisted"
    ])
    #expect(updates.last?.summary.contains("persisted") == true)
}

@Test("Approved external fetcher normalizes policy-governed evidence and preserves provenance")
func approvedExternalFetcherNormalizesEvidence() async throws {
    let observedAt = Date(timeIntervalSince1970: 1_700_700_000)
    let source = ApprovedAnalystSourceDefinition(
        sourceID: "stanford-ai-index-report",
        url: try #require(URL(string: "https://aiindex.stanford.edu/report/")),
        titleHint: "Stanford AI Index Report",
        provenanceNote: "approved_allowlist_source:stanford_ai_index"
    )
    let httpClient = StubExternalHTTPClient(
        response: .success(
            Data("""
            <html>
              <head>
                <title>AI Index 2025</title>
                <meta name="description" content="Compute, power, and enterprise integration remain adoption constraints.">
              </head>
              <body><p>AI adoption is rising, but power bottlenecks remain.</p></body>
            </html>
            """.utf8),
            HTTPURLResponse(
                url: source.url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Last-Modified": "Tue, 14 Nov 2023 12:45:26 GMT"]
            )!
        )
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [source] })
    )
    let charter = AnalystCharterSeed().makeInitialCharter(now: observedAt)

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(),
        baselineNews: []
    )

    #expect(result.documents.count == 1)
    #expect(result.issues.isEmpty)
    #expect(result.documents[0].sourceID == "stanford-ai-index-report")
    #expect(result.documents[0].url == "https://aiindex.stanford.edu/report/")
    #expect(result.documents[0].title == "AI Index 2025")
    #expect(result.documents[0].provenanceNote == "approved_allowlist_source:stanford_ai_index")
    #expect(result.documents[0].summary.contains("Compute, power, and enterprise integration remain adoption constraints."))
    #expect(result.documents[0].observedAt == parseISO("2023-11-14T12:45:26Z"))

    let requests = await httpClient.requests()
    #expect(requests.count == 1)
    #expect(requests[0].value(forHTTPHeaderField: "User-Agent")?.contains("AlgoTradingMacAnalystWorker") == true)
    #expect(requests[0].value(forHTTPHeaderField: "Accept")?.contains("text/html") == true)
}

@Test("Approved external fetcher no longer caps secondary research at four outside sources")
func approvedExternalFetcherBroadSecondaryResearchFetchesMoreThanFourSources() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_005)
    let charter = AnalystCharter(
        charterId: "charter-broad-secondary-fetch",
        analystId: "analyst-broad-secondary-fetch",
        title: "Broad Secondary Fetch Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Use app news as a seed and search reputable public web sources unless the charter restricts them.",
        sourcePolicy: AnalystSourcePolicy(reputableWebResearchAllowed: true),
        createdAt: now,
        updatedAt: now
    )
    let sources = try (0..<7).map { index -> ApprovedAnalystSourceDefinition in
        ApprovedAnalystSourceDefinition(
            sourceID: "broad-source-\(index)",
            url: try #require(URL(string: "https://source\(index).example.com/research/meta-ai-\(index)")),
            titleHint: "Broad public source \(index)",
            provenanceNote: "missing_information_research_plan:source\(index).example.com",
            allowsDiscovery: false,
            sourceTier: index == 0 ? .officialPrimary : .reputableSecondary
        )
    }
    var responsesByURL: [String: StubExternalHTTPClient.Response] = [:]
    for source in sources {
        responsesByURL[source.url.absoluteString] = .success(
            Data("""
            <html>
              <head>
                <title>\(source.titleHint)</title>
                <meta name="description" content="This public source adds distinct current evidence for META technology product timing, financial capacity, or event cadence.">
              </head>
              <body>
                <article>
                  <p>\(source.titleHint) provides distinct evidence for the analyst question and should be available to synthesis.</p>
                  <p>The worker should not stop after four outside pages when the the charter does not expressly restrict broad public-web research.</p>
                </article>
              </body>
            </html>
            """.utf8),
            HTTPURLResponse(url: source.url, statusCode: 200, httpVersion: nil, headerFields: [:])!
        )
    }
    let httpClient = StubExternalHTTPClient(responsesByURL: responsesByURL)
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in sources }),
        maxFetchedDocumentsPerRun: 4,
        maxDiscoveredLinksPerSeed: 1
    )

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(
            id: "task-broad-secondary-fetch",
            title: "META catalyst research",
            description: "Use full charter-governed public internet research and reputable secondary sources for discovery and corroboration."
        ),
        baselineNews: []
    )

    #expect(result.issues.isEmpty)
    #expect(result.documents.count == sources.count)
    let requests = await httpClient.requests()
    #expect(requests.count == sources.count)
}

@Test("Approved external fetcher adapts investor relations earnings materials into bounded evidence")
func approvedExternalFetcherAdaptsInvestorRelationsMaterial() async throws {
    let source = ApprovedAnalystSourceDefinition(
        sourceID: "investor-relations-q1-results",
        url: try #require(URL(string: "https://investors.example.com/news-releases/q1-2026-results")),
        titleHint: "Example Investor Relations",
        provenanceNote: "charter_preferred_public_source:investors.example.com"
    )
    let httpClient = StubExternalHTTPClient(
        response: .success(
            Data("""
            <html>
              <head>
                <meta property="og:title" content="Example Corp Q1 2026 Earnings Release">
                <meta name="description" content="Revenue rose 18% year over year while AI rack deployments remained power constrained.">
                <meta property="article:published_time" content="2026-02-01T13:00:00Z">
              </head>
              <body>
                <main>
                  <article>
                    <h1>Example Corp Q1 2026 Earnings Release</h1>
                    <p>Revenue rose 18% year over year.</p>
                    <p>Management said AI rack deployments remain gated by grid and transformer availability.</p>
                  </article>
                </main>
              </body>
            </html>
            """.utf8),
            HTTPURLResponse(url: source.url, statusCode: 200, httpVersion: nil, headerFields: [:])!
        )
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [source] })
    )
    let charter = AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_700_010))

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(id: "task-ir-adapter"),
        baselineNews: []
    )

    #expect(result.issues.isEmpty)
    #expect(result.documents.count == 1)
    #expect(result.documents[0].title == "Example Corp Q1 2026 Earnings Release")
    #expect(result.documents[0].summary.contains("Revenue rose 18% year over year") == true)
    #expect(result.documents[0].snippet.contains("AI rack deployments remain gated by grid and transformer availability") == true)
    #expect(result.documents[0].observedAt == parseISO("2026-02-01T13:00:00Z"))
}

@Test("Approved external fetcher adapts regulator notices into bounded evidence")
func approvedExternalFetcherAdaptsRegulatorNoticeMaterial() async throws {
    let source = ApprovedAnalystSourceDefinition(
        sourceID: "sec-notice",
        url: try #require(URL(string: "https://www.sec.gov/announcements/example-notice")),
        titleHint: "SEC Notice",
        provenanceNote: "supplemental_public_web_from_app_news:sec.gov"
    )
    let httpClient = StubExternalHTTPClient(
        response: .success(
            Data("""
            <html>
              <head>
                <title>SEC Announces New Large Trader Reporting Guidance</title>
              </head>
              <body>
                <section class="announcement-body">
                  <time datetime="2026-01-15T14:30:00Z">January 15, 2026</time>
                  <p>The guidance narrows the filing window for certain large trader updates.</p>
                  <p>The notice clarifies when amended reporting is required after control changes.</p>
                </section>
              </body>
            </html>
            """.utf8),
            HTTPURLResponse(url: source.url, statusCode: 200, httpVersion: nil, headerFields: [:])!
        )
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [source] })
    )
    let charter = AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_700_020))

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(id: "task-regulator-adapter"),
        baselineNews: []
    )

    #expect(result.issues.isEmpty)
    #expect(result.documents.count == 1)
    #expect(result.documents[0].title == "SEC Announces New Large Trader Reporting Guidance")
    #expect(result.documents[0].summary.contains("narrows the filing window") == true)
    #expect(result.documents[0].snippet.contains("amended reporting is required after control changes") == true)
    #expect(result.documents[0].observedAt == parseISO("2026-01-15T14:30:00Z"))
}

@Test("Approved external fetcher adapts SEC submissions metadata and labels official source tier")
func approvedExternalFetcherAdaptsSECSubmissionsMetadata() async throws {
    let source = ApprovedAnalystSourceDefinition(
        sourceID: "sec-cik-0002045724-submissions",
        url: try #require(URL(string: "https://data.sec.gov/submissions/CIK0002045724.json")),
        titleHint: "SEC submissions metadata for CIK 0002045724",
        provenanceNote: "official_sec_cik_source:0002045724",
        sourceTier: .officialPrimary
    )
    let httpClient = StubExternalHTTPClient(
        response: .success(
            Data("""
            {
              "cik": "2045724",
              "name": "SITUATIONAL AWARENESS LP",
              "filings": {
                "recent": {
                  "form": ["13F-HR", "D"],
                  "filingDate": ["2026-02-14", "2025-12-01"],
                  "accessionNumber": ["0002045724-26-000001", "0002045724-25-000002"],
                  "primaryDocument": ["primary_doc.xml", "xslFormDX01/primary_doc.xml"],
                  "reportDate": ["2025-12-31", ""]
                }
              }
            }
            """.utf8),
            HTTPURLResponse(
                url: source.url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Date": "Thu, 07 May 2026 12:00:00 GMT"]
            )!
        )
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [source] })
    )
    let charter = try #require(
        StandingAnalystBenchSeed()
            .seededCharters(now: Date(timeIntervalSince1970: 1_700_700_030))
            .first(where: { $0.charterId == "bench-sector-financials" })
    )

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(
            id: "task-sec-submissions-adapter",
            title: "SEC 13F metadata adapter",
            description: "Research latest 13F for CIK 0002045724."
        ),
        baselineNews: [],
        plannedSources: [source]
    )

    let document = try #require(result.documents.first)

    #expect(result.issues.isEmpty)
    #expect(result.documents.count == 1)
    #expect(document.sourceTier == .officialPrimary)
    #expect(document.title == "SITUATIONAL AWARENESS LP SEC submissions metadata")
    #expect(document.summary.contains("Official SEC submissions metadata") == true)
    #expect(document.summary.contains("13F-related filing metadata") == true)
    #expect(document.summary.contains("accession=0002045724-26-000001") == true)
    #expect(document.summary.contains("holdings still require") == true)
    #expect(document.observedAt == parseISO("2026-05-07T12:00:00Z"))
}

@Test("Approved external fetcher degrades with bounded HTTP status issue")
func approvedExternalFetcherSurfacesHTTPStatusIssue() async throws {
    let source = ApprovedAnalystSourceDefinition(
        sourceID: "stanford-ai-index-report",
        url: try #require(URL(string: "https://aiindex.stanford.edu/report/")),
        titleHint: "Stanford AI Index Report",
        provenanceNote: "approved_allowlist_source:stanford_ai_index"
    )
    let httpClient = StubExternalHTTPClient(
        response: .success(
            Data(),
            HTTPURLResponse(url: source.url, statusCode: 503, httpVersion: nil, headerFields: [:])!
        )
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [source] })
    )
    let charter = AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_700_100))

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(),
        baselineNews: []
    )

    #expect(result.documents.isEmpty)
    #expect(result.issues == [
        AnalystExternalEvidenceIssue(
            category: .httpStatus,
            host: "aiindex.stanford.edu",
            statusCode: 503,
            detail: "non_success_status"
        )
    ])
}

@Test("Approved external fetcher degrades with bounded transport issue")
func approvedExternalFetcherSurfacesTransportIssue() async throws {
    struct StubTransportError: Error, LocalizedError {
        var errorDescription: String? { "offline" }
    }

    let source = ApprovedAnalystSourceDefinition(
        sourceID: "stanford-ai-index-report",
        url: try #require(URL(string: "https://aiindex.stanford.edu/report/")),
        titleHint: "Stanford AI Index Report",
        provenanceNote: "approved_allowlist_source:stanford_ai_index"
    )
    let httpClient = StubExternalHTTPClient(response: .failure(StubTransportError()))
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [source] })
    )
    let charter = AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_700_200))

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(),
        baselineNews: []
    )

    #expect(result.documents.isEmpty)
    #expect(result.issues == [
        AnalystExternalEvidenceIssue(
            category: .transport,
            host: "aiindex.stanford.edu",
            statusCode: nil,
            detail: "offline"
        )
    ])
}

@Test("Approved external fetcher degrades with bounded invalid-content issue")
func approvedExternalFetcherSurfacesInvalidContentIssue() async throws {
    let source = ApprovedAnalystSourceDefinition(
        sourceID: "stanford-ai-index-report",
        url: try #require(URL(string: "https://aiindex.stanford.edu/report/")),
        titleHint: "Stanford AI Index Report",
        provenanceNote: "approved_allowlist_source:stanford_ai_index"
    )
    let invalidBytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
    let httpClient = StubExternalHTTPClient(
        response: .success(
            invalidBytes,
            HTTPURLResponse(url: source.url, statusCode: 200, httpVersion: nil, headerFields: [:])!
        )
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [source] })
    )
    let charter = AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_700_300))

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(),
        baselineNews: []
    )

    #expect(result.documents.isEmpty)
    #expect(result.issues == [
        AnalystExternalEvidenceIssue(
            category: .invalidContent,
            host: "aiindex.stanford.edu",
            statusCode: nil,
            detail: "empty_or_unsupported_html_content"
        )
    ])
}

@Test("Approved external fetcher reports no-approved-sources without aborting")
func approvedExternalFetcherReportsNoApprovedSources() async throws {
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: StubExternalHTTPClient(
            response: .failure(URLError(.badServerResponse))
        ),
        catalog: ApprovedAnalystSourceCatalog(resolve: { _, _ in [] })
    )
    let charter = AnalystCharter(
        charterId: "charter-custom",
        analystId: "analyst-custom",
        title: "Custom Charter",
        coverageScope: "Tech",
        strategyFamily: "swing",
        summary: "Custom charter without explicit external sources yet.",
        sourcePolicy: AnalystSourcePolicy(reputableWebResearchAllowed: true),
        createdAt: Date(timeIntervalSince1970: 1_700_700_400),
        updatedAt: Date(timeIntervalSince1970: 1_700_700_400)
    )

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(),
        baselineNews: []
    )

    #expect(result.documents.isEmpty)
    #expect(result.issues == [
        AnalystExternalEvidenceIssue(
            category: .noApprovedSources,
            host: nil,
            statusCode: nil,
            detail: "charter=charter-custom"
        )
    ])
}

@Test("Approved external fetcher can use app-news-linked public pages as bounded supplemental sources")
func approvedExternalFetcherUsesAppNewsLinkedPublicPage() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_450)
    let charter = AnalystCharter(
        charterId: "charter-app-news-fetch",
        analystId: "analyst-app-news-fetch",
        title: "App News Fetch Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Use app-owned news first and fetch bounded supplemental public evidence.",
        sourcePolicy: AnalystSourcePolicy(reputableWebResearchAllowed: true),
        createdAt: now,
        updatedAt: now
    )
    let newsItem = NewsEvent(
        eventId: "news-linked-page",
        source: "rss_marketwatch",
        title: "Example company updates AI buildout",
        url: "https://example.com/articles/ai-buildout",
        publishedAt: now.addingTimeInterval(10),
        receivedAt: now.addingTimeInterval(11),
        summary: "App-owned news already captured the event; outside fetch should stay supplemental.",
        rawSymbolHints: ["NVDA"],
        tags: ["ai"],
        payloadVersion: 1
    )
    let httpClient = StubExternalHTTPClient(
        responsesByURL: [
            "https://example.com/articles/ai-buildout": .success(
                Data("""
                <html>
                  <head>
                    <title>Example company updates AI buildout</title>
                    <meta name="description" content="Management says data-center power timing still matters.">
                  </head>
                  <body><p>Outside evidence adds management color, not a replacement event stream.</p></body>
                </html>
                """.utf8),
                HTTPURLResponse(
                    url: try #require(URL(string: "https://example.com/articles/ai-buildout")),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [:]
                )!
            )
        ]
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(httpClient: httpClient)

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(id: "task-app-news-linked"),
        baselineNews: [newsItem]
    )

    #expect(result.issues.isEmpty)
    #expect(result.documents.count == 1)
    #expect(result.documents[0].url == "https://example.com/articles/ai-buildout")
    #expect(result.documents[0].provenanceNote == "supplemental_public_web_from_app_news:example.com")
    let requests = await httpClient.requests()
    #expect(requests.count == 1)
}

@Test("Approved external fetcher keeps app-news-linked supplemental fetches bounded to the linked page itself")
func approvedExternalFetcherKeepsAppNewsLinkedFetchesBounded() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_500)
    let charter = AnalystCharter(
        charterId: "charter-discovery",
        analystId: "analyst-discovery",
        title: "Discovery Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Allow bounded same-host discovery from preferred reputable sources.",
        sourcePolicy: AnalystSourcePolicy(
            reputableWebResearchAllowed: true,
            preferredSources: ["example.com"]
        ),
        createdAt: now,
        updatedAt: now
    )
    let rootURL = try #require(URL(string: "https://example.com/"))
    let discoveredURL = try #require(URL(string: "https://example.com/research/ai-earnings-context"))
    let httpClient = StubExternalHTTPClient(
        responsesByURL: [
            "https://example.com": .success(
                Data("""
                <html>
                  <head><title>Example Research</title></head>
                  <body>
                    <a href="/research/ai-earnings-context">Technology earnings context</a>
                    <a href="https://other.example.net/research/ai-earnings-context">Other host</a>
                  </body>
                </html>
                """.utf8),
                HTTPURLResponse(url: rootURL, statusCode: 200, httpVersion: nil, headerFields: [:])!
            ),
            rootURL.absoluteString: .success(
                Data("""
                <html>
                  <head><title>Example Research</title></head>
                  <body>
                    <a href="/research/ai-earnings-context">Technology earnings context</a>
                    <a href="https://other.example.net/research/ai-earnings-context">Other host</a>
                  </body>
                </html>
                """.utf8),
                HTTPURLResponse(url: rootURL, statusCode: 200, httpVersion: nil, headerFields: [:])!
            ),
            discoveredURL.absoluteString: .success(
                Data("""
                <html>
                  <head>
                    <title>Technology earnings context</title>
                    <meta name="description" content="Utility and grid delays still matter for technology demand timing.">
                  </head>
                  <body><p>Incremental context for the existing app-news baseline.</p></body>
                </html>
                """.utf8),
                HTTPURLResponse(url: discoveredURL, statusCode: 200, httpVersion: nil, headerFields: [:])!
            )
        ]
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        maxFetchedDocumentsPerRun: 4,
        maxDiscoveredLinksPerSeed: 2
    )
    let baselineNews = [
        NewsEvent(
            eventId: "news-discovery",
            source: "rss_marketwatch",
            title: "AI earnings timing still depends on data-center power delivery",
            url: "https://example.com",
            publishedAt: now.addingTimeInterval(10),
            receivedAt: now.addingTimeInterval(11),
            summary: "Baseline app news identifies the event; discovery should deepen context.",
            rawSymbolHints: ["NVDA"],
            tags: ["ai", "earnings", "power"],
            payloadVersion: 1
        )
    ]

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(
            id: "task-discovery",
            title: "Technology earnings context review",
            description: "Use preferred reputable sources for AI earnings and power context."
        ),
        baselineNews: baselineNews
    )

    #expect(result.issues.isEmpty)
    #expect(result.documents.count == 1)
    #expect(result.documents.contains(where: { $0.url == "https://example.com" || $0.url == rootURL.absoluteString }))
    #expect(result.documents.contains(where: { $0.url == discoveredURL.absoluteString }) == false)
    let requests = await httpClient.requests()
    #expect(requests.count == 1)
    #expect(requests.contains(where: { $0.url?.absoluteString == "https://example.com" || $0.url?.absoluteString == rootURL.absoluteString }))
}

@Test("Approved external fetcher discovers investor relations earnings pages from a bounded hub")
func approvedExternalFetcherDiscoversInvestorRelationsHubPages() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_540)
    let charter = AnalystCharter(
        charterId: "charter-ir-hub",
        analystId: "analyst-ir-hub",
        title: "IR Hub Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Allow bounded discovery from investor relations hubs.",
        sourcePolicy: AnalystSourcePolicy(
            reputableWebResearchAllowed: true,
            preferredSources: ["https://investors.example.com/news-releases/"]
        ),
        createdAt: now,
        updatedAt: now
    )
    let hubURL = try #require(URL(string: "https://investors.example.com/news-releases/"))
    let earningsURL = try #require(URL(string: "https://investors.example.com/news-releases/q1-2026-results"))
    let httpClient = StubExternalHTTPClient(
        responsesByURL: [
            "https://investors.example.com/news-releases": .success(
                Data("""
                <html>
                  <head><title>Example Investor Relations News Releases</title></head>
                  <body>
                    <a href="/news-releases/q1-2026-results">First Quarter 2026 Earnings Release</a>
                    <a href="/careers">Careers</a>
                  </body>
                </html>
                """.utf8),
                HTTPURLResponse(url: hubURL, statusCode: 200, httpVersion: nil, headerFields: [:])!
            ),
            hubURL.absoluteString: .success(
                Data("""
                <html>
                  <head><title>Example Investor Relations News Releases</title></head>
                  <body>
                    <a href="/news-releases/q1-2026-results">First Quarter 2026 Earnings Release</a>
                    <a href="/careers">Careers</a>
                  </body>
                </html>
                """.utf8),
                HTTPURLResponse(url: hubURL, statusCode: 200, httpVersion: nil, headerFields: [:])!
            ),
            earningsURL.absoluteString: .success(
                Data("""
                <html>
                  <head>
                    <title>Example Corp Q1 2026 Earnings Release</title>
                    <meta name="description" content="Management reiterated demand but highlighted power-delivery timing pressure.">
                  </head>
                  <body>
                    <main>
                      <article>
                        <p>Management reiterated demand but highlighted power-delivery timing pressure.</p>
                        <p>Customer deployments remain paced by utility interconnect schedules.</p>
                      </article>
                    </main>
                  </body>
                </html>
                """.utf8),
                HTTPURLResponse(url: earningsURL, statusCode: 200, httpVersion: nil, headerFields: [:])!
            )
        ]
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(
        httpClient: httpClient,
        maxFetchedDocumentsPerRun: 4,
        maxDiscoveredLinksPerSeed: 2
    )

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(
            id: "task-ir-hub",
            title: "IR earnings release review",
            description: "Use investor relations releases to sharpen earnings context."
        ),
        baselineNews: []
    )

    #expect(result.issues.isEmpty)
    #expect(result.documents.count == 2)
    #expect(result.documents.contains(where: { $0.url == hubURL.absoluteString }))
    #expect(result.documents.contains(where: { $0.url == earningsURL.absoluteString }))
    let requests = await httpClient.requests()
    #expect(requests.count >= 2)
    #expect(requests.count <= 3)
}

@Test("Approved external fetcher does not fetch restricted preferred sources")
func approvedExternalFetcherSkipsRestrictedPreferredSources() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_550)
    let charter = AnalystCharter(
        charterId: "charter-restricted-fetch",
        analystId: "analyst-restricted-fetch",
        title: "Restricted Fetch Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Restricted sources must not be fetched even if they are preferred.",
        sourcePolicy: AnalystSourcePolicy(
            reputableWebResearchAllowed: true,
            preferredSources: ["example.com"],
            restrictedSources: ["example.com"]
        ),
        createdAt: now,
        updatedAt: now
    )
    let httpClient = StubExternalHTTPClient(
        response: .failure(URLError(.badURL))
    )
    let fetcher = ApprovedAnalystExternalEvidenceFetcher(httpClient: httpClient)

    let result = await fetcher.fetchEvidence(
        for: charter,
        task: makeExternalFetchTask(id: "task-restricted-fetch"),
        baselineNews: []
    )

    #expect(result.documents.isEmpty)
    #expect(result.issues == [
        AnalystExternalEvidenceIssue(
            category: .noApprovedSources,
            host: nil,
            statusCode: nil,
            detail: "charter=charter-restricted-fetch"
        )
    ])
    let requests = await httpClient.requests()
    #expect(requests.isEmpty)
}

@Test("Analyst worker records a durable restricted-source access suggestion when policy blocks a relevant source")
func analystWorkerRecordsRestrictedSourceAccessSuggestion() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_600)
    let charter = AnalystCharter(
        charterId: "charter-restricted-suggestion",
        analystId: "analyst-restricted-suggestion",
        title: "Restricted Suggestion Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Restricted preferred sources should surface as PM-reviewable access gaps.",
        sourcePolicy: AnalystSourcePolicy(
            reputableWebResearchAllowed: true,
            preferredSources: ["example.com"],
            restrictedSources: ["example.com"]
        ),
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-restricted-suggestion",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Restricted source gap review",
        description: "If a useful source is policy-restricted, surface a bounded suggestion.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-restricted-suggestion",
                source: "rss_marketwatch",
                title: "App news baseline remains primary",
                url: "https://example.net/baseline-news",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "External research would help but is restricted by charter policy.",
                rawSymbolHints: ["MSFT"],
                tags: ["ai"],
                payloadVersion: 1
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: ApprovedAnalystExternalEvidenceFetcher(
            httpClient: StubExternalHTTPClient(response: .failure(URLError(.badURL)))
        ),
        now: { now.addingTimeInterval(20) }
    )

    let summary = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        newsLimit: 5
    )

    #expect(summary.externalEvidenceStatus == "degraded")
    let suggestions = await fixture.sourceAccessSuggestions()
    let restrictedSuggestion = try #require(suggestions.first(where: { $0.limitation == .restrictedByPolicy }))
    #expect(restrictedSuggestion.requestedSource == "example.com")
    #expect(restrictedSuggestion.recommendedNextStep == .allowByCharterUpdate)
    #expect(restrictedSuggestion.taskId == task.taskId)
    #expect(restrictedSuggestion.charterId == charter.charterId)
}

@Test("OpenAI keychain status provider reports configured key without exposing value")
func openAIKeychainStatusProviderReadsConfiguredKey() {
    struct FakeKeyReader: KeyReading {
        let values: [String: String]

        func readKey(service: String, account: String) -> String? {
            values["\(service)|\(account)"]
        }
    }

    let provider = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [
                "open_api_key|algo-trading": "secret-value"
            ])
        ),
        labelReader: { _, _ in nil },
        cache: nil
    )
    #expect(provider.isConfigured() == true)

    let missing = OpenAIKeychainStatusProvider(
        keychainProvider: KeychainCredentialsProvider(
            keyReader: FakeKeyReader(values: [:])
        ),
        labelReader: { _, _ in nil },
        cache: nil
    )
    #expect(missing.isConfigured() == false)
}

@Test("Analyst worker seeds standing bench and requires explicit charter selection when empty")
func analystWorkerSeedsStandingBenchIfEmpty() async throws {
    let fixture = AnalystWorkerFixture()
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true),
        now: { Date(timeIntervalSince1970: 1_700_500_100) }
    )
    await #expect(throws: AnalystWorkerSelectionError.self) {
        try await service.runOnce(newsLimit: 5)
    }

    let charters = await fixture.charters()
    #expect(charters.count == 9)
    #expect(charters.contains { $0.title == "Technology Analyst" && $0.benchRole == .sector })
    #expect(charters.contains { $0.title == recentNewsStandingAnalystTitle && $0.benchRole == .overlay })
    #expect(charters.contains { $0.title == "Portfolio Risk Analyst" && $0.benchRole == .overlay })
    #expect(await fixture.bundles().isEmpty)
    #expect(await fixture.findings().isEmpty)
    #expect(await fixture.memos().isEmpty)
    #expect(await fixture.tasks().isEmpty)
}

@Test("Analyst worker does not overwrite existing charter when one already exists")
func analystWorkerKeepsExistingCharter() async throws {
    let existing = AnalystCharter(
        charterId: "existing-charter",
        analystId: "existing-analyst",
        title: "Existing Charter",
        coverageScope: "Existing scope",
        strategyFamily: "Existing style",
        summary: "Existing summary",
        createdAt: Date(timeIntervalSince1970: 1_700_400_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_400_000)
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [existing],
        initialNews: []
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "custom-source",
                url: "https://example.com/source",
                title: "Custom Source",
                observedAt: Date(timeIntervalSince1970: 1_700_500_190),
                summary: "Custom supporting source.",
                snippet: "Custom supporting source.",
                provenanceNote: "approved_allowlist_source:custom"
            )
        ]),
        now: { Date(timeIntervalSince1970: 1_700_500_200) }
    )

    let summary = try await service.runOnce(newsLimit: 5)

    #expect(summary.charterSeeded == false)
    #expect(summary.analystId == "existing-analyst")
    #expect(summary.taskId == "task-existing-charter-ongoing-research")
    let charters = await fixture.charters()
    #expect(charters.count == 1)
    #expect(charters[0].charterId == "existing-charter")
    let findings = await fixture.findings()
    #expect(findings.first?.charterId == "existing-charter")
}

@Test("Analyst worker drafts a signal only when explicitly requested")
func analystWorkerDraftsSignalOnlyWhenFlagPresent() async throws {
    let fixture = AnalystWorkerFixture(
        initialCharters: [
            AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_500_000))
        ]
    )
    await fixture.setNews([
        NewsEvent(
            eventId: "news-1",
            source: "rss_marketwatch",
            title: "technology platform demand stays strong",
            url: "https://example.com/news-1",
            publishedAt: Date(timeIntervalSince1970: 1_700_500_010),
            receivedAt: Date(timeIntervalSince1970: 1_700_500_020),
            summary: "Large-cap software and semis may benefit from continued technology demand.",
            rawSymbolHints: ["NVDA"],
            tags: ["bullish", "ai"],
            payloadVersion: 1
        )
    ])

    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: Date(timeIntervalSince1970: 1_700_500_050),
                summary: "Adoption remains real but timing uncertainty persists.",
                snippet: "Adoption remains real but timing uncertainty persists.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { Date(timeIntervalSince1970: 1_700_500_100) }
    )

    let noDraftSummary = try await service.runOnce(newsLimit: 5, draftSignal: false)
    #expect(noDraftSummary.draftedSignalId == nil)
    #expect(await fixture.signals().isEmpty)
    #expect(await fixture.findings().first?.linkedSignalId == nil)

    let draftSummary = try await service.runOnce(newsLimit: 5, draftSignal: true)
    #expect(draftSummary.draftedSignalId == "sig-\(draftSummary.findingId)")
    let signals = await fixture.signals()
    #expect(signals.count == 1)
    #expect(signals.first?.originatingFindingId == draftSummary.findingId)
    #expect(signals.first?.provenance.analystId == AnalystCharterSeed.analystId)
    #expect(await fixture.findings().first?.linkedSignalId == draftSummary.draftedSignalId)
}

@Test("Analyst worker treats optional signal draft validation issue as completed analysis")
func analystWorkerCompletesWhenOptionalSignalDraftHasValidationIssue() async throws {
    let fixture = AnalystWorkerFixture(
        initialCharters: [
            AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_500_000))
        ],
        signalDraftError: AnalystIPCClientError.server(
            code: "analyst_finding_signal_ineligible",
            message: "Analyst finding finding-1 cannot draft a signal: linked evidence bundle was not found"
        )
    )
    await fixture.setNews([
        NewsEvent(
            eventId: "news-1",
            source: "rss_marketwatch",
            title: "technology platform demand stays strong but confirmation remains bounded",
            url: "https://example.com/news-1",
            publishedAt: Date(timeIntervalSince1970: 1_700_500_010),
            receivedAt: Date(timeIntervalSince1970: 1_700_500_020),
            summary: "Large-cap software and semis may benefit from continued technology demand, but evidence remains monitor-only.",
            rawSymbolHints: ["NVDA"],
            tags: ["ai"],
            payloadVersion: 1
        )
    ])

    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: Date(timeIntervalSince1970: 1_700_500_050),
                summary: "Adoption remains real but timing uncertainty persists.",
                snippet: "Adoption remains real but timing uncertainty persists.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { Date(timeIntervalSince1970: 1_700_500_100) }
    )

    let summary = try await service.runOnce(newsLimit: 5, draftSignal: true)

    #expect(summary.findingId.isEmpty == false)
    #expect(summary.memoId.isEmpty == false)
    #expect(summary.draftedSignalId == nil)
    #expect(await fixture.signals().isEmpty)
}

@Test("Analyst worker can explicitly draft a proposal after drafting a signal")
func analystWorkerDraftsProposalOnlyWhenExplicitlyRequested() async throws {
    let fixture = AnalystWorkerFixture(
        initialCharters: [
            AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_500_000))
        ]
    )
    await fixture.setNews([
        NewsEvent(
            eventId: "news-1",
            source: "rss_marketwatch",
            title: "technology platform demand stays strong",
            url: "https://example.com/news-1",
            publishedAt: Date(timeIntervalSince1970: 1_700_500_010),
            receivedAt: Date(timeIntervalSince1970: 1_700_500_020),
            summary: "Large-cap software and semis may benefit from continued technology demand.",
            rawSymbolHints: ["NVDA"],
            tags: ["bullish", "ai"],
            payloadVersion: 1
        )
    ])

    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: Date(timeIntervalSince1970: 1_700_500_050),
                summary: "Adoption remains real but timing uncertainty persists.",
                snippet: "Adoption remains real but timing uncertainty persists.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { Date(timeIntervalSince1970: 1_700_500_100) }
    )

    let summary = try await service.runOnce(newsLimit: 5, draftSignal: true, draftProposal: true)
    #expect(summary.draftedSignalId == "sig-\(summary.findingId)")
    #expect(summary.draftedProposalId == "proposal-sig-\(summary.findingId)")
}

@Test("Analyst worker rejects proposal drafting without explicit signal drafting")
func analystWorkerRejectsProposalDraftWithoutSignalDraft() async throws {
    let fixture = AnalystWorkerFixture()
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: Date(timeIntervalSince1970: 1_700_500_050),
                summary: "Power constraints remain relevant.",
                snippet: "Power constraints remain relevant.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { Date(timeIntervalSince1970: 1_700_500_100) }
    )

    await #expect(throws: AnalystWorkerSelectionError.invalidDraftSelection(reason: "proposal drafting requires --draft-signal")) {
        try await service.runOnce(newsLimit: 5, draftProposal: true)
    }
}

@Test("Analyst worker updates existing task checkpoint state without losing provenance")
func analystWorkerUpdatesExistingTaskCheckpoint() async throws {
    let now = Date(timeIntervalSince1970: 1_700_500_350)
    let charter = AnalystCharter(
        charterId: "charter-task",
        analystId: "analyst-task",
        title: "Task Charter",
        coverageScope: "Tech",
        strategyFamily: "swing",
        summary: "Task charter summary",
        createdAt: now,
        updatedAt: now
    )
    let existingTask = AnalystTask(
        taskId: "task-charter-task-ongoing-research",
        analystId: "analyst-task",
        charterId: "charter-task",
        title: "Existing task",
        description: "Existing description",
        status: .inProgress,
        createdAt: now,
        updatedAt: now,
        lastCheckpointSummary: "Previous checkpoint",
        checkpoint: AnalystTaskCheckpoint(
            checkpointID: "checkpoint-1",
            taskId: "task-charter-task-ongoing-research",
            analystId: "analyst-task",
            charterId: "charter-task",
            summary: "Previous checkpoint",
            nextPlannedAction: "Continue review",
            openQuestions: ["Old question"],
            linkedFindingIDs: [],
            linkedEvidenceBundleIDs: [],
            updatedAt: now
        )
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [existingTask],
        initialNews: [
            NewsEvent(
                eventId: "news-task",
                source: "rss_marketwatch",
                title: "Enterprise AI rollout slips",
                url: "https://example.com/news-task",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Integration and power bottlenecks slow deployment.",
                rawSymbolHints: ["MSFT"],
                tags: ["enterprise", "ai"],
                payloadVersion: 1
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: now.addingTimeInterval(20),
                summary: "Power and integration remain important constraints.",
                snippet: "Power and integration remain important constraints.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { now.addingTimeInterval(30) }
    )

    let summary = try await service.runOnce(charterID: "charter-task", newsLimit: 5)

    #expect(summary.taskId == existingTask.taskId)
    let tasks = await fixture.tasks()
    #expect(tasks.count == 1)
    #expect(tasks[0].taskId == existingTask.taskId)
    #expect(tasks[0].checkpoint?.checkpointID == "checkpoint-1")
    #expect(tasks[0].checkpoint?.linkedFindingIDs.count == 1)
    #expect(tasks[0].checkpoint?.linkedEvidenceBundleIDs.count == 1)
    #expect(tasks[0].checkpoint?.analystId == "analyst-task")
    #expect(tasks[0].checkpoint?.charterId == "charter-task")
}

@Test("Analyst worker degrades gracefully when external evidence is unavailable")
func analystWorkerDegradesGracefullyOnExternalEvidenceFailure() async throws {
    let now = Date(timeIntervalSince1970: 1_700_500_600)
    let charter = AnalystCharter(
        charterId: "charter-custom",
        analystId: "analyst-custom",
        title: "Custom Charter",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Test a thesis with app news first and external evidence when available.",
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-custom",
        analystId: "analyst-custom",
        charterId: "charter-custom",
        title: "Custom Task",
        description: "Run with degraded external evidence.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-custom",
                source: "rss_marketwatch",
                title: "Power constraints still matter for AI buildouts",
                url: "https://example.com/news-custom",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Power and deployment bottlenecks continue to shape monetization timing.",
                rawSymbolHints: ["NVDA"],
                tags: ["ai", "power"],
                payloadVersion: 1
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(
            result: AnalystExternalEvidenceFetchResult(
                documents: [],
                issues: [
                    AnalystExternalEvidenceIssue(
                        category: .noApprovedSources,
                        detail: "charter=charter-custom"
                    )
                ]
            )
        ),
        now: { now.addingTimeInterval(20) }
    )

    let summary = try await service.runOnce(charterID: "charter-custom", taskID: "task-custom", newsLimit: 5)

    #expect(summary.charterId == "charter-custom")
    #expect(summary.taskId == "task-custom")
    #expect(summary.externalEvidenceCount == 0)
    #expect(summary.externalEvidenceIssueCount == 1)
    #expect(summary.externalEvidenceStatus == "degraded")
    #expect(summary.externalEvidenceIssueSummary?.contains("category=no_approved_sources") == true)

    let bundles = await fixture.bundles()
    #expect(bundles.count == 1)
    let hasDiagnosticRef = bundles[0].refs.contains(where: {
        $0.sourceKind == .manualNote && $0.sourceIdentifier == "external_evidence_diagnostic"
    })
    #expect(hasDiagnosticRef)

    let findings = await fixture.findings()
    #expect(findings.count == 1)
    #expect(findings[0].analystId == "analyst-custom")
    #expect(findings[0].charterId == "charter-custom")
    #expect(findings[0].taskId == "task-custom")
    #expect(findings[0].summary.contains("External evidence degraded"))

    let memos = await fixture.memos()
    #expect(memos.count == 1)
    #expect(memos[0].findingId == findings[0].findingId)
    #expect(memos[0].uncertaintySummary.contains("External evidence was degraded") == true)
    #expect(memos[0].recommendedNextStep.contains("refresh policy-governed external evidence") == true)
}

@Test("Analyst worker fails clearly when multiple charters exist and none is selected")
func analystWorkerRejectsAmbiguousSelection() async throws {
    let fixture = AnalystWorkerFixture(
        initialCharters: [
            AnalystCharter(
                charterId: "charter-a",
                analystId: "analyst-a",
                title: "Charter A",
                coverageScope: "Coverage A",
                strategyFamily: "Strategy A",
                summary: "Summary A",
                createdAt: Date(timeIntervalSince1970: 1_700_400_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_400_000)
            ),
            AnalystCharter(
                charterId: "charter-b",
                analystId: "analyst-b",
                title: "Charter B",
                coverageScope: "Coverage B",
                strategyFamily: "Strategy B",
                summary: "Summary B",
                createdAt: Date(timeIntervalSince1970: 1_700_400_100),
                updatedAt: Date(timeIntervalSince1970: 1_700_400_100)
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { Date(timeIntervalSince1970: 1_700_500_250) }
    )

    await #expect(throws: AnalystWorkerSelectionError.ambiguousCharterSelection(availableCharterIDs: ["charter-a", "charter-b"])) {
        try await service.runOnce(newsLimit: 5)
    }
}

@Test("Analyst worker selects an explicit charter when multiple charters exist")
func analystWorkerSelectsExplicitCharter() async throws {
    let fixture = AnalystWorkerFixture(
        initialCharters: [
            AnalystCharter(
                charterId: "charter-a",
                analystId: "analyst-a",
                title: "Charter A",
                coverageScope: "Coverage A",
                strategyFamily: "Strategy A",
                summary: "Summary A",
                createdAt: Date(timeIntervalSince1970: 1_700_400_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_400_000)
            ),
            AnalystCharter(
                charterId: "charter-b",
                analystId: "analyst-b",
                title: "Charter B",
                coverageScope: "Coverage B",
                strategyFamily: "Strategy B",
                summary: "Summary B",
                createdAt: Date(timeIntervalSince1970: 1_700_400_100),
                updatedAt: Date(timeIntervalSince1970: 1_700_400_100)
            )
        ],
        initialNews: [
            NewsEvent(
                eventId: "news-b",
                source: "rss_marketwatch",
                title: "Tech margins compress",
                url: "https://example.com/news-b",
                publishedAt: Date(timeIntervalSince1970: 1_700_500_010),
                receivedAt: Date(timeIntervalSince1970: 1_700_500_020),
                summary: "Pressure test for tech long/short positioning.",
                rawSymbolHints: ["MSFT"],
                tags: ["tech"],
                payloadVersion: 1
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "strategy-note",
                url: "https://example.com/strategy-note",
                title: "Strategy Note",
                observedAt: Date(timeIntervalSince1970: 1_700_500_250),
                summary: "Adoption is rising but power remains constrained.",
                snippet: "Adoption is rising but power remains constrained.",
                provenanceNote: "approved_allowlist_source:strategy_note"
            )
        ]),
        now: { Date(timeIntervalSince1970: 1_700_500_300) }
    )

    let summary = try await service.runOnce(charterID: "charter-b", newsLimit: 5)

    #expect(summary.analystId == "analyst-b")
    #expect(summary.charterId == "charter-b")
    let bundles = await fixture.bundles()
    let findings = await fixture.findings()
    #expect(bundles.first?.charterId == "charter-b")
    #expect(findings.first?.charterId == "charter-b")
    #expect(findings.first?.analystId == "analyst-b")
}

@Test("Analyst worker rejects a requested seed mismatch when no charters exist")
func analystWorkerRejectsUnknownRequestedSeed() async throws {
    let fixture = AnalystWorkerFixture()
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { Date(timeIntervalSince1970: 1_700_500_325) }
    )

    await #expect(throws: AnalystWorkerSelectionError.cannotSeedRequestedCharter(
        id: "other-charter",
        seedCharterID: StandingAnalystBenchSeed.definitions.map(\.charterId).sorted().joined(separator: ", ")
    )) {
        try await service.runOnce(charterID: "other-charter", newsLimit: 5)
    }
}

@Test("Analyst worker uses distinct local execution profiles for distinct runtime selections")
func analystWorkerUsesDistinctLocalExecutionProfiles() async throws {
    let baseNews = [
        NewsEvent(
            eventId: "news-1",
            source: "rss_marketwatch",
            title: "technology infrastructure demand stays uneven",
            url: "https://example.com/news-1",
            publishedAt: Date(timeIntervalSince1970: 1_700_500_010),
            receivedAt: Date(timeIntervalSince1970: 1_700_500_020),
            summary: "Enterprise rollouts remain real, but timing frictions persist.",
            rawSymbolHints: ["NVDA", "MSFT"],
            tags: ["ai", "timing"],
            payloadVersion: 1
        )
    ]
    let initialCharter = AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_500_000))
    let deepFixture = AnalystWorkerFixture(initialCharters: [initialCharter], initialNews: baseNews)
    let deepService = AnalystWorkerService(
        client: deepFixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { Date(timeIntervalSince1970: 1_700_500_100) }
    )

    let deepSummary = try await deepService.runOnce(
        taskID: "task-deep",
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: Date(timeIntervalSince1970: 1_700_500_090),
            updatedAt: Date(timeIntervalSince1970: 1_700_500_090)
        ),
        newsLimit: 5
    )
    let conciseFixture = AnalystWorkerFixture(initialCharters: [initialCharter], initialNews: baseNews)
    let conciseService = AnalystWorkerService(
        client: conciseFixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { Date(timeIntervalSince1970: 1_700_500_200) }
    )
    let conciseSummary = try await conciseService.runOnce(
        taskID: "task-concise",
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1-mini",
            reasoningMode: .standard,
            policySource: .pmDelegationOverride,
            createdAt: Date(timeIntervalSince1970: 1_700_500_091),
            updatedAt: Date(timeIntervalSince1970: 1_700_500_091)
        ),
        newsLimit: 5
    )

    #expect(deepSummary.runtimeProvenance?.actualRuntimeIdentifier == "deterministic_local_fallback[gpt-5]")
    #expect(conciseSummary.runtimeProvenance?.actualRuntimeIdentifier == "deterministic_local_fallback[gpt-4.1-mini]")
    #expect(deepSummary.synthesisStatus == "fallback_missing_openai_key")
    #expect(deepSummary.synthesisIssueSummary == "openai_api_key_missing")
    #expect(conciseSummary.synthesisStatus == "fallback_missing_openai_key")
    #expect(conciseSummary.synthesisIssueSummary == "openai_api_key_missing")
    #expect(deepSummary.memoId != conciseSummary.memoId)
    #expect(deepSummary.findingId != conciseSummary.findingId)

    let deepMemo = try #require(await deepFixture.memos().first)
    let conciseMemo = try #require(await conciseFixture.memos().first)

    #expect(deepMemo.executiveSummary.contains("Working conclusion:") == true)
    #expect(conciseMemo.executiveSummary.contains("Bottom line:") == true)
    #expect(deepMemo.recommendedNextStep.contains("different runtime profile") == true)
    #expect(conciseMemo.recommendedNextStep.contains("different runtime profile") == false)
}

@Test("Analyst worker shapes memo language by task intent while staying evidence-bounded")
func analystWorkerShapesMemoByTaskIntent() async throws {
    let news = [
        NewsEvent(
            eventId: "news-1",
            source: "rss_marketwatch",
            title: "AI deployment remains uneven across enterprise workloads",
            url: "https://example.com/news-1",
            publishedAt: Date(timeIntervalSince1970: 1_700_500_010),
            receivedAt: Date(timeIntervalSince1970: 1_700_500_020),
            summary: "Rollout progress exists, but integration friction still affects timing.",
            rawSymbolHints: ["MSFT", "AMZN"],
            tags: ["ai", "enterprise"],
            payloadVersion: 1
        )
    ]
    let charter = AnalystCharterSeed().makeInitialCharter(now: Date(timeIntervalSince1970: 1_700_500_000))
    let synthesisTask = AnalystTask(
        taskId: "task-synthesis",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Synthesis Task: technology adoption watch memo",
        description: "Synthesize the current evidence into a readable watch memo.",
        status: .queued,
        createdAt: Date(timeIntervalSince1970: 1_700_500_001),
        updatedAt: Date(timeIntervalSince1970: 1_700_500_001),
        tags: ["task-synthesis"]
    )
    let recommendationTask = AnalystTask(
        taskId: "task-recommendation",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Recommendation Task: should the PM escalate now?",
        description: "Recommend whether the PM should keep monitoring or escalate for owner review.",
        status: .queued,
        createdAt: Date(timeIntervalSince1970: 1_700_500_002),
        updatedAt: Date(timeIntervalSince1970: 1_700_500_002),
        tags: ["task-recommendation"]
    )

    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [synthesisTask, recommendationTask],
        initialNews: news
    )
    let synthesisService = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { Date(timeIntervalSince1970: 1_700_500_100) }
    )
    let recommendationService = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { Date(timeIntervalSince1970: 1_700_500_200) }
    )

    _ = try await synthesisService.runOnce(taskID: "task-synthesis", newsLimit: 5)
    _ = try await recommendationService.runOnce(taskID: "task-recommendation", newsLimit: 5)

    let memos = await fixture.memos().sorted { ($0.taskId ?? "") < ($1.taskId ?? "") }
    let synthesisMemo = try #require(memos.first(where: { $0.taskId == "task-synthesis" }))
    let recommendationMemo = try #require(memos.first(where: { $0.taskId == "task-recommendation" }))

    #expect(synthesisMemo.currentView.contains("summarize the state of evidence") == true)
    #expect(synthesisMemo.recommendedNextStep.contains("keep the PM informed") == true)
    #expect(recommendationMemo.currentView.contains("help the PM decide") == true)
    #expect(recommendationMemo.recommendedNextStep.contains("PM decision or approval request") == true)
    #expect(recommendationMemo.uncertaintySummary.contains("separate PM/trading gates") == true)
}

@Test("Analyst runtime presentation text is human-readable")
func analystRuntimePresentationTextReadable() {
    let provenance = AnalystRuntimeProvenance(
        intendedPolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: Date(timeIntervalSince1970: 1_700_500_090),
            updatedAt: Date(timeIntervalSince1970: 1_700_500_090)
        ),
        actualRuntimeIdentifier: "deterministic_local[gpt-5]",
        actualReasoningMode: .deliberate,
        launchedAt: Date(timeIntervalSince1970: 1_700_500_100)
    )

    #expect(analystRequestedRuntimeText(provenance.intendedPolicy) == "gpt-5 (deliberate reasoning)")
    #expect(analystActualRuntimeText(provenance) == "Local synthesis profile gpt-5 with deliberate reasoning")
    #expect(analystExecutionUsedRuntimeText(provenance) == "Local synthesis profile gpt-5 with deliberate reasoning")
    #expect(analystRuntimeComparisonText(provenance) == "Requested gpt-5 (deliberate reasoning). Executed with Local synthesis profile gpt-5 with deliberate reasoning.")
}

@Test("Analyst runtime presentation makes fallback execution explicit when requested and actual differ")
func analystRuntimePresentationMakesFallbackExplicit() {
    let now = Date(timeIntervalSince1970: 1_743_300_400)
    let provenance = AnalystRuntimeProvenance(
        intendedPolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        actualRuntimeIdentifier: "deterministic_local_fallback[gpt-4.1-mini]",
        actualReasoningMode: .standard,
        launchedAt: now
    )

    #expect(
        analystExecutionUsedRuntimeText(provenance)
            == "Local synthesis fallback profile gpt-4.1-mini with standard reasoning (fallback from gpt-5 (deliberate reasoning))"
    )
    #expect(
        analystRuntimeComparisonText(provenance)
            == "Requested gpt-5 (deliberate reasoning). Executed with Local synthesis fallback profile gpt-4.1-mini with standard reasoning (fallback from gpt-5 (deliberate reasoning))."
    )
}

@Test("Analyst worker uses OpenAI-backed synthesis when provider succeeds")
func analystWorkerUsesOpenAISynthesisWhenProviderSucceeds() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_100)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)
    let task = AnalystTask(
        taskId: "task-openai",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "OpenAI-backed synthesis task",
        description: "Use the selected runtime to synthesize a memo from bounded evidence.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-openai",
                source: "rss_marketwatch",
                title: "technology infrastructure remains capital intensive",
                url: "https://example.com/news-openai",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Power and capex frictions still shape monetization timing.",
                rawSymbolHints: ["NVDA", "MSFT"],
                tags: ["ai", "power"],
                payloadVersion: 1
            )
        ]
    )
    let synthesisProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "OpenAI finding title",
            findingSummary: "OpenAI finding summary",
            findingThesis: "OpenAI thesis",
            findingConfidence: 0.74,
            findingTimeHorizon: "quarterly",
            memoTitle: "OpenAI memo title",
            memoExecutiveSummary: "OpenAI executive summary",
            memoCurrentView: "OpenAI current view",
            memoEvidenceSummary: "OpenAI evidence summary",
            memoUncertaintySummary: "OpenAI uncertainty summary",
            memoRecommendedNextStep: "OpenAI recommended next step",
            suggestedSymbols: ["nvda", "msft"],
            suggestedTags: ["AI", "Power"]
        )
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: now.addingTimeInterval(20),
                summary: "Scaling frictions remain relevant.",
                snippet: "Scaling frictions remain relevant.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { now.addingTimeInterval(30) }
    )

    let summary = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    #expect(summary.usedOpenAI == true)
    #expect(summary.synthesisStatus == "openai_responses")
    #expect(summary.synthesisIssueSummary == nil)
    #expect(summary.runtimeProvenance?.actualRuntimeIdentifier == "openai_responses[gpt-4.1]")
    #expect(summary.runtimeProvenance?.actualReasoningMode == .standard)
    #expect(summary.findingTitle == "OpenAI finding title")
    #expect(summary.memoTitle == "OpenAI memo title")

    let findings = await fixture.findings()
    let memos = await fixture.memos()
    #expect(findings.first?.title == "OpenAI finding title")
    #expect(findings.first?.summary == "OpenAI finding summary")
    #expect(findings.first?.thesis == "OpenAI thesis")
    #expect(findings.first?.symbols == ["MSFT", "NVDA"])
    #expect(findings.first?.tags.contains("ai") == true)
    #expect(memos.first?.title == "OpenAI memo title")
    #expect(memos.first?.executiveSummary == "OpenAI executive summary")
    #expect(memos.first?.currentView == "OpenAI current view")
    #expect(memos.first?.evidenceSummary == "OpenAI evidence summary")
    #expect(memos.first?.uncertaintySummary == "OpenAI uncertainty summary")
    #expect(memos.first?.recommendedNextStep == "OpenAI recommended next step")

    let capturedRequest = try #require(await synthesisProvider.lastRequest)
    #expect(capturedRequest.runtimeIdentifier == "gpt-4.1")
    #expect(capturedRequest.taskTitle == "OpenAI-backed synthesis task")
    #expect(capturedRequest.newsItems.count == 1)
    #expect(capturedRequest.publicWebSearchEnabled == true)
    #expect(capturedRequest.externalEvidenceItems.isEmpty)
}

@Test("Analyst worker uses Anthropic-backed synthesis when analyst runtime selects Anthropic")
func analystWorkerUsesAnthropicSynthesisWhenProviderSucceeds() async throws {
    let root = makeAnalystTempDirectory(name: "worker-anthropic-synthesis")
    let now = Date(timeIntervalSince1970: 1_700_700_140)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)
    let task = AnalystTask(
        taskId: "task-anthropic",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Anthropic-backed synthesis task",
        description: "Use the selected Anthropic runtime to synthesize a memo from bounded evidence.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-anthropic",
                source: "rss_marketwatch",
                title: "technology infrastructure remains power constrained",
                url: "https://example.com/news-anthropic",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Power and capex frictions still shape monetization timing.",
                rawSymbolHints: ["NVDA", "MSFT"],
                tags: ["ai", "power"],
                payloadVersion: 1
            )
        ]
    )
    let anthropicProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "Anthropic finding title",
            findingSummary: "Anthropic finding summary",
            findingThesis: "Anthropic thesis",
            findingConfidence: 0.72,
            findingTimeHorizon: "quarterly",
            memoTitle: "Anthropic memo title",
            memoExecutiveSummary: "Anthropic executive summary",
            memoCurrentView: "Anthropic current view",
            memoEvidenceSummary: "Anthropic evidence summary",
            memoUncertaintySummary: "Anthropic uncertainty summary",
            memoRecommendedNextStep: "Anthropic recommended next step",
            suggestedSymbols: ["nvda", "msft"],
            suggestedTags: ["Anthropic", "Power"]
        )
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        llmProviderSettingsStore: LLMProviderSettingsStore(
            fileURL: root.appendingPathComponent("llm-provider-settings.json"),
            now: { now }
        ),
        llmCredentialResolver: StubAnalystLLMCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .ready,
                apiKey: "test-anthropic-key",
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: "anthropic_api_key",
                account: "algo-trading",
                summary: "Anthropic API key resolved from app session handoff."
            )
        ),
        openAISynthesisProvider: StubOpenAISynthesisProvider(
            error: AnalystOpenAISynthesisError.transport
        ),
        anthropicSynthesisProvider: anthropicProvider,
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: now.addingTimeInterval(20),
                summary: "Scaling frictions remain relevant.",
                snippet: "Scaling frictions remain relevant.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { now.addingTimeInterval(30) }
    )

    let summary = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            providerKind: .anthropic,
            credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
            runtimeIdentifier: "claude-sonnet-4-6",
            reasoningMode: .standard,
            policySource: .standingBenchDefault,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    #expect(summary.usedOpenAI == false)
    #expect(summary.synthesisStatus == "anthropic_messages")
    #expect(summary.synthesisIssueSummary == nil)
    #expect(summary.runtimeProvenance?.intendedPolicy?.providerKind == .anthropic)
    #expect(summary.runtimeProvenance?.intendedPolicy?.credentialProfileId == LLMCredentialProfile.anthropicDefaultProfileID)
    #expect(summary.runtimeProvenance?.actualRuntimeIdentifier == "anthropic_messages[claude-sonnet-4-6]")
    #expect(summary.runtimeProvenance?.actualReasoningMode == .standard)
    #expect(summary.findingTitle == "Anthropic finding title")
    #expect(summary.memoTitle == "Anthropic memo title")

    let findings = await fixture.findings()
    let memos = await fixture.memos()
    #expect(findings.first?.title == "Anthropic finding title")
    #expect(findings.first?.summary == "Anthropic finding summary")
    #expect(memos.first?.title == "Anthropic memo title")
    #expect(memos.first?.executiveSummary == "Anthropic executive summary")
    #expect(memos.first?.runtimeProvenance?.actualRuntimeIdentifier == "anthropic_messages[claude-sonnet-4-6]")

    let capturedRequest = try #require(await anthropicProvider.lastRequest)
    #expect(capturedRequest.runtimeIdentifier == "claude-sonnet-4-6")
    #expect(capturedRequest.taskTitle == "Anthropic-backed synthesis task")
    #expect(capturedRequest.newsItems.count == 1)
    #expect(capturedRequest.publicWebSearchEnabled == true)
    #expect(capturedRequest.externalEvidenceItems.isEmpty)
}

@Test("Analyst worker can launch every canonical standing analyst lane under Anthropic fake provider")
func analystWorkerCanLaunchEveryCanonicalStandingLaneUnderAnthropic() async throws {
    let root = makeAnalystTempDirectory(name: "worker-anthropic-all-lanes")
    let now = Date(timeIntervalSince1970: 1_700_700_180)
    let charters = StandingAnalystBenchSeed().seededCharters(now: now)
    let tasks = charters.map { charter in
        AnalystTask(
            taskId: "task-\(charter.charterId)",
            analystId: charter.analystId,
            charterId: charter.charterId,
            title: "\(charter.title) Anthropic test report",
            description: "Run the canonical standing analyst lane under Anthropic for provenance validation.",
            status: .queued,
            createdAt: now,
            updatedAt: now
        )
    }
    let fixture = AnalystWorkerFixture(
        initialCharters: charters,
        initialTasks: tasks,
        initialNews: [
            NewsEvent(
                eventId: "news-all-lanes",
                source: "rss_marketwatch",
                title: "Cross-sector market signal remains monitor-only",
                url: "https://example.com/news-all-lanes",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "A bounded app-owned headline is available for lane-specific analysis.",
                rawSymbolHints: ["NVDA", "XOM", "JPM"],
                tags: ["market", "portfolio"],
                payloadVersion: 1
            )
        ]
    )
    let anthropicProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "Anthropic lane finding",
            findingSummary: "Anthropic lane finding summary",
            findingThesis: "Anthropic lane thesis",
            findingConfidence: 0.70,
            findingTimeHorizon: "weekly",
            memoTitle: "Anthropic lane memo",
            memoExecutiveSummary: "Anthropic lane executive summary",
            memoCurrentView: "Anthropic lane current view",
            memoEvidenceSummary: "Anthropic lane evidence summary",
            memoUncertaintySummary: "Anthropic lane uncertainty summary",
            memoRecommendedNextStep: "Anthropic lane recommended next step",
            suggestedSymbols: [],
            suggestedTags: ["Anthropic"]
        )
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        llmProviderSettingsStore: LLMProviderSettingsStore(
            fileURL: root.appendingPathComponent("llm-provider-settings.json"),
            now: { now }
        ),
        llmCredentialResolver: StubAnalystLLMCredentialResolver(
            resolution: LLMCredentialResolution(
                status: .ready,
                apiKey: "test-anthropic-key",
                profileId: LLMCredentialProfile.anthropicDefaultProfileID,
                providerKind: .anthropic,
                matchedServiceOrLabel: "anthropic_api_key",
                account: "algo-trading",
                summary: "Anthropic API key resolved from app session handoff."
            )
        ),
        openAISynthesisProvider: StubOpenAISynthesisProvider(
            error: AnalystOpenAISynthesisError.transport
        ),
        anthropicSynthesisProvider: anthropicProvider,
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { now.addingTimeInterval(30) }
    )

    for (charter, task) in zip(charters, tasks) {
        let summary = try await service.runOnce(
            charterID: charter.charterId,
            taskID: task.taskId,
            intendedRuntimePolicy: AnalystRuntimePolicy(
                providerKind: .anthropic,
                credentialProfileId: LLMCredentialProfile.anthropicDefaultProfileID,
                runtimeIdentifier: "claude-sonnet-4-6",
                reasoningMode: .standard,
                policySource: charter.charterId == recentNewsStandingAnalystCharterID
                    ? .specializationDefault
                    : .standingBenchDefault,
                createdAt: now,
                updatedAt: now
            ),
            newsLimit: 5
        )
        #expect(summary.synthesisStatus == "anthropic_messages")
        #expect(summary.runtimeProvenance?.intendedPolicy?.providerKind == .anthropic)
        #expect(summary.runtimeProvenance?.actualRuntimeIdentifier == "anthropic_messages[claude-sonnet-4-6]")
    }

    #expect(await anthropicProvider.callCount == charters.count)
    let memos = await fixture.memos()
    #expect(memos.count == charters.count)
    #expect(Set(memos.compactMap { $0.runtimeProvenance?.intendedPolicy?.providerKind }) == [.anthropic])
    #expect(Set(memos.map(\.charterId)) == Set(charters.map(\.charterId)))
}

@Test("Analyst worker keeps app-owned news as baseline and compacts duplicate external support")
func analystWorkerCompactsDuplicateExternalSupport() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_100)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)
    let task = AnalystTask(
        taskId: "task-dedup",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Deduplicate overlapping evidence",
        description: "Review app news first and keep duplicate outside research compact.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-dedup",
                source: "rss_marketwatch",
                title: "Nvidia AI buildout faces power bottlenecks",
                url: "https://example.com/news-dedup",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Power constraints still shape the rollout pace for new infrastructure capacity.",
                rawSymbolHints: ["NVDA"],
                tags: ["ai", "power"],
                payloadVersion: 1
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "dup-source",
                url: "https://example.com/dup-source",
                title: "Nvidia AI buildout faces power bottlenecks",
                observedAt: now.addingTimeInterval(20),
                summary: "Power constraints still shape the rollout pace for new infrastructure capacity.",
                snippet: "Power constraints still shape the rollout pace for new infrastructure capacity.",
                provenanceNote: "charter_preferred_source:industry_publication"
            )
        ]),
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1-mini",
            reasoningMode: .standard,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let memo = try #require(await fixture.memos().first)
    let bundle = try #require(await fixture.bundles().first)

    #expect(memo.evidenceSummary.contains("starts from 1 recent app-owned news item(s) as the baseline evidence set") == true)
    #expect(memo.evidenceSummary.contains("compacted into corroborating support rather than treated as separate analysis") == true)
    #expect(bundle.summary.contains("supplemental policy-governed external source") == true)
    #expect(bundle.summary.contains("compacted into corroborating support") == true)
}

@Test("Analyst worker surfaces incremental external value beyond app news")
func analystWorkerSurfacesIncrementalExternalValue() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_200)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)
    let task = AnalystTask(
        taskId: "task-incremental-context",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Incremental external context review",
        description: "Use app news first and surface only what external research adds.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-incremental",
                source: "rss_marketwatch",
                title: "Microsoft expands technology infrastructure spending",
                url: "https://example.com/news-incremental",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "Management signaled another round of technology infrastructure spending.",
                rawSymbolHints: ["MSFT"],
                tags: ["ai", "capex"],
                payloadVersion: 1
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "incremental-source",
                url: "https://example.com/incremental-source",
                title: "Utility filings show power-delivery delays for new data centers",
                observedAt: now.addingTimeInterval(20),
                summary: "Regional utility filings point to transformer and grid-connection delays for new data-center capacity.",
                snippet: "The filings suggest power-delivery timing, not demand, is the main constraint.",
                provenanceNote: "charter_preferred_source:industry_publication"
            )
        ]),
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1-mini",
            reasoningMode: .standard,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let memo = try #require(await fixture.memos().first)
    let bundle = try #require(await fixture.bundles().first)
    let webRef = try #require(bundle.refs.first(where: { $0.sourceKind == AnalystEvidenceSourceKind.web }))

    #expect(memo.evidenceSummary.contains("Supplemental external research was kept secondary to the app-news baseline") == true)
    #expect(memo.evidenceSummary.contains("added incremental context") == true)
    #expect(webRef.summary?.contains("Supplemental role: This source adds incremental timing, background, or strategic/risk context") == true)
}

@Test("Analyst worker lets LLM runtime own broad web research without deterministic prefetch")
func analystWorkerLetsLLMRuntimeOwnBroadWebResearchWithoutDeterministicPrefetch() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_230)
    let charter = AnalystCharter(
        charterId: "charter-web-search-no-candidates",
        analystId: "analyst-web-search-no-candidates",
        title: "Ad Hoc Public Research Analyst",
        coverageScope: "Technology",
        strategyFamily: "long short",
        summary: "Use broad public web research unless a source is restricted.",
        sourcePolicy: AnalystSourcePolicy(reputableWebResearchAllowed: true),
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-web-search-no-candidates",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "META 2026 technology catalyst research",
        description: "Research META earnings timing, developer conference timing, expected technology product releases, forward P/E, liquidity, and whether META may make meaningful technology-platform progress in 2026.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: []
    )
    let planningProvider = StubResearchPlanningProvider(
        output: AnalystResearchPlanningOutput(
            planSummary: "Use current public web search to identify official Meta IR/event materials and reputable financial/product reporting.",
            missingInformation: [
                "Meta earnings timing and official event schedule.",
                "Reputable current product and valuation context."
            ],
            researchQuestions: [
                "Which official Meta sources answer the timing questions?",
                "Which reputable market-data or financial sources corroborate valuation and liquidity context?"
            ],
            publicTargets: [
                .init(
                    source: "Meta Investor Relations",
                    urlOrDomain: "https://investor.fb.com/",
                    category: "issuer_primary",
                    whyItMatters: "Official IR materials are needed for earnings timing, filings, liquidity, and management commentary.",
                    missingInformationNeed: "Whether official Meta materials answer the owner-requested earnings and financial-capacity questions."
                ),
                .init(
                    source: "Meta Newsroom",
                    urlOrDomain: "https://about.fb.com/news/",
                    category: "company_press_blog",
                    whyItMatters: "Official product/event communications are needed before treating product-roadmap claims as grounded.",
                    missingInformationNeed: "Whether official Meta product channels confirm developer conference timing or technology product roadmap details."
                )
            ],
            sourceGapRecommendations: []
        )
    )
    let externalProvider = RecordingExternalEvidenceProvider(documents: [])
    let synthesisProvider = StubOpenAISynthesisProvider(output: makeStubSynthesisOutput(title: "META research completed"))
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        researchPlanningProvider: planningProvider,
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    #expect(await planningProvider.callCount == 0)
    #expect(await externalProvider.callCount() == 0)
    let synthesisRequest = try #require(await synthesisProvider.lastRequest)

    #expect(synthesisRequest.publicWebSearchEnabled == true)
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("earnings timing") }))
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("forward P/E") || $0.contains("liquidity") }))
    #expect(synthesisRequest.externalEvidenceItems.isEmpty)
}

@Test("Ad hoc analyst worker preserves multi-question checklist and filters irrelevant app news")
func adHocAnalystWorkerPreservesMultiQuestionChecklistAndFiltersIrrelevantAppNews() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_235)
    let charter = AnalystCharter(
        charterId: "charter-meta-ad-hoc",
        analystId: "analyst-meta-ad-hoc",
        title: "Technology Analyst",
        coverageScope: "Technology and technology platforms",
        strategyFamily: "long short",
        summary: "Use broad public web research unless a source is restricted.",
        sourcePolicy: AnalystSourcePolicy(reputableWebResearchAllowed: true),
        createdAt: now,
        updatedAt: now
    )
    let description = """
    Research META for an example technology research portfolio. Answer: next earnings report timing; next developer conference / Meta Connect timing; credible public roadmap signals and expected timing for 2026 product releases; forward P/E and valuation context; available cash/liquidity and 2026 cash outlook; whether META is positioned for meaningful technology-platform progress in 2026; portfolio relevance and conclusion.
    """
    let task = AnalystTask(
        taskId: "task-meta-ad-hoc-checklist",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "META multi-question ad hoc research",
        description: description,
        pmTaskingBrief: PMTaskingBrief(
            taskObjective: "Launch META research with Technology Analyst",
            whyNow: description,
            evidenceExpectation: "Use full charter-governed public internet research outside the app-news baseline.",
            coverageRequired: true,
            expectedOutputs: ["finding"]
        ),
        status: .queued,
        createdAt: now,
        updatedAt: now,
        symbols: ["META"],
        tags: ["pm-conversation-delegation"]
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-oil-unrelated",
                source: "rss_marketwatch",
                title: "Oil prices rise on geopolitical comments",
                url: "https://example.com/oil",
                publishedAt: now,
                receivedAt: now,
                summary: "Energy-market story with no platform relevance.",
                rawSymbolHints: ["USO"],
                tags: ["energy"],
                payloadVersion: 1
            ),
            NewsEvent(
                eventId: "news-tv-unrelated",
                source: "rss_nyt",
                title: "NBC turns a word game into a TV show",
                url: "https://example.com/tv",
                publishedAt: now.addingTimeInterval(1),
                receivedAt: now.addingTimeInterval(1),
                summary: "Media programming item unrelated to the requested company research.",
                rawSymbolHints: ["TV"],
                tags: ["media"],
                payloadVersion: 1
            )
        ]
    )
    let planningProvider = StubResearchPlanningProvider(
        output: AnalystResearchPlanningOutput(
            planSummary: "Use separate public search paths for every META timing, product, valuation, liquidity, and portfolio question.",
            missingInformation: [
                "META earnings timing.",
                "META Connect timing.",
                "META product roadmap and rumor timing.",
                "META valuation and liquidity."
            ],
            researchQuestions: [
                "Which official Meta IR source confirms the next earnings timing?",
                "Which official event source confirms Meta Connect timing?",
                "Which reputable product reporting supports release timing?",
                "Which reputable financial source supports forward P/E and cash/liquidity?"
            ],
            publicTargets: [
                .init(
                    source: "Meta Investor Relations",
                    urlOrDomain: "https://investor.fb.com/",
                    category: "issuer_primary",
                    whyItMatters: "Official IR materials answer earnings, filings, cash, and liquidity questions.",
                    missingInformationNeed: "META earnings timing and financial capacity."
                ),
                .init(
                    source: "Meta Newsroom",
                    urlOrDomain: "https://about.fb.com/news/",
                    category: "company_press_blog",
                    whyItMatters: "Official product and event communications answer Meta Connect and technology roadmap questions.",
                    missingInformationNeed: "META event and product timing."
                )
            ],
            sourceGapRecommendations: []
        )
    )
    let synthesisProvider = StubOpenAISynthesisProvider(output: makeStubSynthesisOutput(title: "META checklist memo"))
    let externalProvider = RecordingExternalEvidenceProvider(documents: [])
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        researchPlanningProvider: planningProvider,
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let synthesisRequest = try #require(await synthesisProvider.lastRequest)
    let memo = try #require(await fixture.memos().first)
    let completedTask = try #require(await fixture.tasks().first(where: { $0.taskId == task.taskId }))

    #expect(await planningProvider.callCount == 0)
    #expect(await externalProvider.callCount() == 0)
    #expect(synthesisRequest.newsItems.isEmpty)
    #expect(synthesisRequest.publicWebSearchEnabled == true)
    #expect(synthesisRequest.researchQuestionItems.count >= 7)
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("next earnings report") }))
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("2026 product releases") }))
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("forward P/E") }))
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("Meta Connect") }))
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("PM tasking brief") }) == false)
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("Evidence expectation") }) == false)
    #expect(synthesisRequest.researchQuestionItems.contains(where: { $0.contains("Baseline status") }) == false)
    #expect(synthesisRequest.externalEvidenceItems.isEmpty)
    #expect(memo.questionCoverage.count >= 7)
    #expect(memo.questionCoverage.allSatisfy { $0.status != .answered })
    #expect(completedTask.status == .completed)
    #expect(completedTask.tags.contains("pm_requested"))
}

@Test("Ad hoc analyst coverage does not mark answered memo-body facts as not addressed")
func adHocAnalystCoverageDoesNotMarkMemoBodyFactsAsNotAddressed() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_238)
    let charter = AnalystCharter(
        charterId: "charter-meta-coverage-inference",
        analystId: "analyst-meta-coverage-inference",
        title: "Technology Analyst",
        coverageScope: "Technology and technology platforms",
        strategyFamily: "long short",
        summary: "Use broad public web research unless a source is restricted.",
        sourcePolicy: AnalystSourcePolicy(reputableWebResearchAllowed: true),
        createdAt: now,
        updatedAt: now
    )
    let task = AnalystTask(
        taskId: "task-meta-coverage-inference",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "META ad hoc coverage inference",
        description: "Answer explicitly: (1) trailing/current P/E and forward P/E if available with timestamp/source; (2) latest filing liquidity, including cash, marketable securities, current assets/current liabilities, long-term debt, operating cash flow/free cash flow, 2026 capex guide, and commitments; (3) whether META is likely to make meaningful technology-platform progress in 2026.",
        pmTaskingBrief: PMTaskingBrief(
            researchQuestions: [
                "trailing/current P/E and forward P/E if available with timestamp/source",
                "latest filing liquidity, including cash, marketable securities, current assets/current liabilities, long-term debt, operating cash flow/free cash flow, 2026 capex guide, and commitments",
                "whether META is likely to make meaningful technology-platform progress in 2026"
            ],
            coverageRequired: true,
            expectedOutputs: ["finding"]
        ),
        status: .queued,
        createdAt: now,
        updatedAt: now,
        symbols: ["META"],
        tags: ["pm-conversation-delegation"]
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: []
    )
    var output = makeStubSynthesisOutput(title: "META body-answer memo")
    output.memoExecutiveSummary = "META is positioned for a credible 2026 technology-platform progress if product proof points arrive fast enough to justify capex."
    output.memoCurrentView = "The balance-sheet read is strong but capital intensive: cash plus marketable securities were $81.18B, current assets/current liabilities were $109.77B/$46.75B, operating cash flow/free cash flow were $32.23B/$12.39B, and 2026 capex guidance was $125B-$145B."
    output.memoEvidenceSummary = "Market data showed META at $598.86, P/E 21.78, and provider variation in forward P/E around the low-20s. Filing evidence showed cash, marketable securities, long-term debt, free cash flow, capex, and commitments."
    output.questionCoverage = []
    let synthesisProvider = StubOpenAISynthesisProvider(output: output)
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: RecordingExternalEvidenceProvider(documents: []),
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let memo = try #require(await fixture.memos().first)
    let statuses = Dictionary(uniqueKeysWithValues: memo.questionCoverage.map { ($0.question, $0.status) })

    #expect(statuses.values.allSatisfy { $0 != .notAddressed })
    #expect(memo.questionCoverage.contains(where: { $0.question.localizedCaseInsensitiveContains("P/E") && $0.answerSummary.localizedCaseInsensitiveContains("21.78") }))
    #expect(memo.questionCoverage.contains(where: { $0.question.localizedCaseInsensitiveContains("liquidity") && $0.answerSummary.localizedCaseInsensitiveContains("$81.18B") }))
    #expect(memo.questionCoverage.contains(where: { $0.question.localizedCaseInsensitiveContains("technology-platform progress") && $0.answerSummary.localizedCaseInsensitiveContains("credible 2026 technology-platform progress") }))
}

@Test("Analyst synthesis does not depend on deterministic external evidence when LLM owns web research")
func analystSynthesisDoesNotDependOnDeterministicExternalEvidenceWhenLLMOwnsWebResearch() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_240)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)
    let task = AnalystTask(
        taskId: "task-synthesis-broad-evidence",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Broad evidence synthesis",
        description: "Use full charter-governed public internet research outside the app-news baseline.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let documents = (0..<10).map { index in
        ExternalAnalystEvidenceDocument(
            sourceID: "external-source-\(index)",
            url: "https://source\(index).example.com/research",
            title: "External evidence source \(index)",
            observedAt: now.addingTimeInterval(Double(index)),
            summary: "Distinct public evidence item \(index) for the analyst's broad internet research.",
            snippet: "Distinct evidence item \(index).",
            provenanceNote: "missing_information_research_plan:source\(index).example.com",
            sourceTier: index == 0 ? .officialPrimary : .reputableSecondary
        )
    }
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: []
    )
    let synthesisProvider = StubOpenAISynthesisProvider(output: makeStubSynthesisOutput(title: "Broad evidence memo"))
    let externalProvider = RecordingExternalEvidenceProvider(documents: documents)
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        researchPlanningProvider: StubResearchPlanningProvider(
            output: AnalystResearchPlanningOutput(
                planSummary: "Use broad external evidence.",
                missingInformation: [],
                researchQuestions: [],
                publicTargets: [],
                sourceGapRecommendations: []
            )
        ),
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let capturedSynthesisRequest = try #require(await synthesisProvider.lastRequest)
    let bundle = try #require(await fixture.bundles().first)
    let updatedTask = try #require(await fixture.tasks().first)
    #expect(await externalProvider.callCount() == 0)
    #expect(capturedSynthesisRequest.publicWebSearchEnabled == true)
    #expect(capturedSynthesisRequest.externalEvidenceItems.isEmpty)
    #expect(bundle.summary.contains("analyst LLM runtime owned task-specific public-web research directly"))
    #expect(bundle.summary.contains("reviewed 0 supplemental") == false)
    #expect(updatedTask.checkpoint?.summary.contains("direct task-specific public-web research ran inside synthesis") == true)
    #expect(updatedTask.checkpoint?.summary.contains("0 supplemental") == false)
}

@Test("Analyst worker uses supplemental fetch only as degraded fallback when LLM web research is unavailable")
func analystWorkerUsesSupplementalFetchOnlyAsDegradedFallbackWhenLLMWebUnavailable() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_260)
    let charter = try #require(
        StandingAnalystBenchSeed()
            .seededCharters(now: now)
            .first(where: { $0.charterId == "bench-sector-technology" })
    )
    let task = AnalystTask(
        taskId: "task-research-plan",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Technology standing refresh",
        description: "Read app-owned news first, identify what is still missing, and then do bounded sector-specific follow-up.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-research-plan",
                source: "rss_marketwatch",
                title: "Nvidia suppliers flag fresh AI rack deployment delays",
                url: "https://example.com/news-research-plan",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "The app-news baseline points to rack-level bottlenecks but does not clarify management commentary or broader sector breadth.",
                rawSymbolHints: ["NVDA"],
                tags: ["ai", "infrastructure"],
                payloadVersion: 1
            )
        ]
    )
    let planningProvider = StubResearchPlanningProvider(
        output: AnalystResearchPlanningOutput(
            planSummary: "After reviewing the app-news baseline, test whether management commentary and sector-breadth evidence confirm that deployment delays are spreading beyond one supplier headline.",
            missingInformation: [
                "What management or investor-relations materials say about deployment timing and bottlenecks.",
                "Whether broader semiconductor and data-center trade coverage confirms sector breadth beyond the initial app-news item."
            ],
            researchQuestions: [
                "Do issuer-primary materials confirm timing pressure or capex slippage?",
                "Is the bottleneck isolated or showing up across the broader technology stack?"
            ],
            publicTargets: [
                .init(
                    source: "NVIDIA Investor Relations",
                    urlOrDomain: "https://investor.nvidia.com/",
                    category: "issuer_primary",
                    whyItMatters: "Issuer-primary materials can confirm whether the timing issue is management-confirmed rather than media speculation.",
                    missingInformationNeed: "What management has said about deployment timing, supply bottlenecks, or capex cadence."
                ),
                .init(
                    source: "Semiconductor Engineering",
                    urlOrDomain: "https://semiengineering.com/",
                    category: "industry_publication",
                    whyItMatters: "Sector trade coverage can test whether the app-news item reflects broader supply-chain breadth.",
                    missingInformationNeed: "Whether broader semiconductor and infrastructure commentary confirms a sector-wide bottleneck."
                )
            ],
            sourceGapRecommendations: []
        )
    )
    let synthesisProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "Technology breadth remains the key missing variable",
            findingSummary: "The app-news item matters, but management commentary and broader sector checks are needed to decide whether the bottleneck is isolated or systemic.",
            findingThesis: "Bounded sector-specific follow-up materially improved the report beyond the initial headline.",
            findingConfidence: 0.68,
            findingTimeHorizon: "quarterly",
            memoTitle: "Technology breadth follow-up memo",
            memoExecutiveSummary: "After reviewing app news first, the analyst targeted issuer-primary and trade-publication follow-up to answer the missing questions that mattered most.",
            memoCurrentView: "The initial news item matters, but the sharper read comes from testing management commentary and broader sector breadth.",
            memoEvidenceSummary: "App news stayed first; supplemental public-web research was shaped by the identified missing-information needs.",
            memoUncertaintySummary: "Management confirmation and broader sector breadth still need to be monitored for follow-through.",
            memoRecommendedNextStep: "Keep the issue in the standing review lane and re-check management commentary on the next cycle.",
            suggestedSymbols: ["nvda"],
            suggestedTags: ["AI", "Supply Chain"]
        )
    )
    let externalProvider = RecordingExternalEvidenceProvider(
        documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "semiengineering-follow-up",
                url: "https://semiengineering.com/chip-supply-follow-up",
                title: "Sector trade follow-up confirms broader rack-level bottlenecks",
                observedAt: now.addingTimeInterval(20),
                summary: "Trade coverage shows the same rack-level bottleneck is appearing across multiple suppliers, not just one linked headline.",
                snippet: "Broader supplier commentary points to a multi-quarter infrastructure bottleneck.",
                provenanceNote: "supplemental_public_web_research:industry_publication"
            )
        ]
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false, value: nil),
        researchPlanningProvider: planningProvider,
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            policySource: .standingBenchDefault,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    #expect(await planningProvider.callCount == 0)
    #expect(await synthesisProvider.callCount == 0)
    let capturedPlannedSources = await externalProvider.plannedSources()
    let bundle = try #require(await fixture.bundles().first)

    #expect(capturedPlannedSources.isEmpty == false)
    #expect(capturedPlannedSources.contains(where: { $0.titleHint == "Semiconductor Engineering" }))
    #expect(capturedPlannedSources.contains(where: { $0.titleHint == "Data Center Dynamics" }))
    #expect(bundle.summary.contains("identified") == true)
    #expect(bundle.summary.contains("reviewed 1 supplemental policy-governed external source(s)") == true)
}

@Test("Financials 13F research defaults to secondary-assisted source selection unless charter restricts")
func financials13FResearchDefaultsToSecondaryAssistedSourceSelection() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_270)
    let charter = try #require(
        StandingAnalystBenchSeed()
            .seededCharters(now: now)
            .first(where: { $0.charterId == "bench-sector-financials" })
    )
    let task = AnalystTask(
        taskId: "task-financials-13f-secondary-assisted",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Situational Awareness LP 13F research",
        description: "Research Situational Awareness LP latest 13F holdings for CIK 0002045724. Use official SEC evidence when available, but use reputable secondary sources for discovery and corroboration if needed.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: []
    )
    let externalProvider = RecordingExternalEvidenceProvider(documents: [])
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let plannedSources = await externalProvider.plannedSources()
    let includesSECSubmissions = plannedSources.contains { source in
        source.titleHint == "SEC submissions metadata for CIK 0002045724"
            && source.url.absoluteString == "https://data.sec.gov/submissions/CIK0002045724.json"
            && source.sourceTier == .officialPrimary
    }
    let includesSecondary13FSource = plannedSources.contains { source in
        source.titleHint == "WhaleWisdom 13F research"
            && source.sourceTier == .reputableSecondary
    }
    let includesOfficialSource = plannedSources.contains { $0.sourceTier == .officialPrimary }
    let includesSecondarySource = plannedSources.contains { $0.sourceTier == .reputableSecondary }

    #expect(includesSECSubmissions)
    #expect(includesSecondary13FSource)
    #expect(includesOfficialSource)
    #expect(includesSecondarySource)
}

@Test("Financials 13F degraded fallback official target still retains secondary discovery unless charter restricts")
func financials13FDegradedFallbackOfficialTargetStillRetainsSecondaryDiscovery() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_272)
    let charter = try #require(
        StandingAnalystBenchSeed()
            .seededCharters(now: now)
            .first(where: { $0.charterId == "bench-sector-financials" })
    )
    let task = AnalystTask(
        taskId: "task-financials-13f-name-only-secondary-assisted",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Situational Awareness LP 13F research",
        description: "Research Situational Awareness LP latest 13F holdings. Use official SEC evidence when available, but use reputable secondary sources for discovery and corroboration if needed. Clearly label official versus secondary evidence.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: []
    )
    let planningProvider = StubResearchPlanningProvider(
        output: AnalystResearchPlanningOutput(
            planSummary: "Start with official SEC EDGAR search to identify the filer and filing record.",
            missingInformation: [
                "Latest 13F filer identity and holdings table for Situational Awareness LP."
            ],
            researchQuestions: [
                "Can SEC EDGAR identify the latest relevant 13F filing?"
            ],
            publicTargets: [
                .init(
                    source: "SEC EDGAR search",
                    urlOrDomain: "https://www.sec.gov/edgar/search/",
                    category: "official_filings",
                    whyItMatters: "Official SEC search is the primary discovery path for filer identity and filing records.",
                    missingInformationNeed: "Whether official SEC materials identify the latest 13F filing."
                )
            ],
            sourceGapRecommendations: []
        )
    )
    let synthesisProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "13F research needs official and secondary discovery",
            findingSummary: "Official SEC search remains primary, and reputable secondary 13F discovery is retained for corroboration unless the charter expressly restricts.",
            findingThesis: "The task should not become official-only merely because the planner named SEC first.",
            findingConfidence: 0.63,
            findingTimeHorizon: "near_term",
            memoTitle: "Situational Awareness LP 13F research memo",
            memoExecutiveSummary: "The run preserved official SEC search plus reputable secondary discovery for the asset-manager 13F question.",
            memoCurrentView: "Official SEC evidence should be preferred, while secondary 13F aggregation can help discover or corroborate the filing path.",
            memoEvidenceSummary: "Source planning retained both official and secondary tiers under the Financials charter.",
            memoUncertaintySummary: "Holdings remain subject to retrieval and source-tier confirmation.",
            memoRecommendedNextStep: "Use SEC filings first and clearly label any secondary-only discovery.",
            suggestedSymbols: [],
            suggestedTags: ["13F", "Financials"]
        )
    )
    let externalProvider = RecordingExternalEvidenceProvider(documents: [])
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false, value: nil),
        researchPlanningProvider: planningProvider,
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    #expect(await planningProvider.callCount == 0)
    #expect(await synthesisProvider.callCount == 0)
    let plannedSources = await externalProvider.plannedSources()
    let includesOfficialSECDiscovery = plannedSources.contains { source in
        source.titleHint == "SEC EDGAR search"
            && source.sourceTier == .officialPrimary
    }
    let includesSecondary13FSource = plannedSources.contains { source in
        source.titleHint == "WhaleWisdom 13F research"
            && source.sourceTier == .reputableSecondary
    }

    #expect(includesOfficialSECDiscovery)
    #expect(includesSecondary13FSource)
}

@Test("Financials official-only 13F task filters secondary sources without changing charter defaults")
func financialsOfficialOnly13FTaskFiltersSecondarySources() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_275)
    let charter = try #require(
        StandingAnalystBenchSeed()
            .seededCharters(now: now)
            .first(where: { $0.charterId == "bench-sector-financials" })
    )
    let task = AnalystTask(
        taskId: "task-financials-13f-official-only",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Situational Awareness LP official-only 13F research",
        description: "Research Situational Awareness LP latest 13F holdings for CIK 0002045724 using only official primary sources. If official evidence is not recoverable, block rather than infer.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: []
    )
    let externalProvider = RecordingExternalEvidenceProvider(documents: [])
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5.5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let plannedSources = await externalProvider.plannedSources()
    let includesSecondary13FSource = plannedSources.contains { $0.titleHint == "WhaleWisdom 13F research" }
    let includesSECSubmissions = plannedSources.contains { $0.url.absoluteString == "https://data.sec.gov/submissions/CIK0002045724.json" }
    let includesSECArchive = plannedSources.contains { $0.url.absoluteString == "https://www.sec.gov/Archives/edgar/data/2045724/" }

    #expect(plannedSources.isEmpty == false)
    #expect(plannedSources.allSatisfy { $0.sourceTier == .officialPrimary || $0.sourceTier == .appOwnedTruth })
    #expect(includesSecondary13FSource == false)
    #expect(includesSECSubmissions)
    #expect(includesSECArchive)
}

@Test("Cross-lane fallback research plans preserve default secondary public research unless restricted")
func crossLaneFallbackResearchPlansPreserveSecondaryPublicResearchUnlessRestricted() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_280)
    let charterIDs = [
        "bench-sector-technology",
        "bench-sector-healthcare-biotech",
        "bench-sector-consumer",
        "bench-sector-energy-materials",
        "bench-overlay-macro-international"
    ]
    let chartersByID = Dictionary(
        uniqueKeysWithValues: StandingAnalystBenchSeed()
            .seededCharters(now: now)
            .map { ($0.charterId, $0) }
    )

    for charterID in charterIDs {
        let charter = try #require(chartersByID[charterID])
        let task = AnalystTask(
            taskId: "task-\(charterID)-secondary-assisted",
            analystId: charter.analystId,
            charterId: charter.charterId,
            title: "\(charter.title) public research check",
            description: "Do ordinary domain-relevant public web research for this analyst lane. Prefer primary sources, and use reputable secondary or domain sources for discovery, corroboration, and context unless the charter expressly restricts.",
            status: .queued,
            createdAt: now,
            updatedAt: now
        )
        let fixture = AnalystWorkerFixture(
            initialCharters: [charter],
            initialTasks: [task],
            initialNews: []
        )
        let externalProvider = RecordingExternalEvidenceProvider(documents: [])
        let service = AnalystWorkerService(
            client: fixture,
            openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
            externalEvidenceProvider: externalProvider,
            now: { now.addingTimeInterval(30) }
        )

        _ = try await service.runOnce(
            charterID: charter.charterId,
            taskID: task.taskId,
            intendedRuntimePolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5.5",
                reasoningMode: .standard,
                policySource: .pmDelegationOverride,
                createdAt: now,
                updatedAt: now
            ),
            newsLimit: 5
        )

        let plannedSources = await externalProvider.plannedSources()
        let includesSecondarySource = plannedSources.contains { $0.sourceTier == .reputableSecondary }
        #expect(includesSecondarySource, "Expected \(charter.title) to retain at least one reputable secondary/domain source unless restricted.")
    }
}

@Test("Recent News Analyst uses direct LLM web research instead of supplemental prefetch when runtime is available")
func recentNewsAnalystUsesDirectLLMWebResearchInsteadOfSupplementalPrefetchWhenRuntimeAvailable() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_290)
    let charter = try #require(
        StandingAnalystBenchSeed()
            .seededCharters(now: now)
            .first(where: { $0.charterId == recentNewsStandingAnalystCharterID })
    )
    let task = AnalystTask(
        taskId: "task-recent-news-axios",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Recent news materiality review",
        description: "Review app-owned recent news first, then perform the required Axios check and bounded supplemental outside research only if it materially adds to the read.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-recent-news-axios",
                source: "rss_marketwatch_rss",
                title: "technology infrastructure suppliers flag fresh deployment timing questions",
                url: "https://example.com/news-recent-news-axios",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "The app-owned baseline highlights the headline but leaves broader confirmation and omission checks open.",
                rawSymbolHints: ["NVDA"],
                tags: ["ai", "infrastructure"],
                payloadVersion: 1
            )
        ]
    )
    let planningProvider = StubResearchPlanningProvider(
        output: AnalystResearchPlanningOutput(
            planSummary: "Use the app-news baseline first, then do bounded outside research only where it adds to the read.",
            missingInformation: [
                "Whether broader AI and technology coverage is surfacing the same development."
            ],
            researchQuestions: [
                "Is this showing up in broader AI coverage beyond the initial app-owned item?"
            ],
            publicTargets: [],
            sourceGapRecommendations: []
        )
    )
    let synthesisProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "Recent news remains bounded",
            findingSummary: "The development is worth PM monitoring but still needs broader confirmation.",
            findingThesis: "Bounded supplemental checks help test whether the app-owned baseline is missing a broader signal.",
            findingConfidence: 0.61,
            findingTimeHorizon: "near_term",
            memoTitle: "Recent News Analyst memo",
            memoExecutiveSummary: "The app-news baseline remains primary, with bounded outside checks used to test breadth and omission risk.",
            memoCurrentView: "Keep the issue in PM monitoring while broader recent-news coverage is checked.",
            memoEvidenceSummary: "App-owned news stayed primary and the required Axios check remained in the bounded source plan.",
            memoUncertaintySummary: "Need broader confirmation from outside coverage.",
            memoRecommendedNextStep: "Re-check the broader recent-news baseline next cycle.",
            suggestedSymbols: ["NVDA"],
            suggestedTags: ["recent-news"]
        )
    )
    let externalProvider = RecordingExternalEvidenceProvider(documents: [])
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        researchPlanningProvider: planningProvider,
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: externalProvider,
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            policySource: .charterDefault,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let capturedPlannedSources = await externalProvider.plannedSources()
    let capturedSynthesisRequest = try #require(await synthesisProvider.lastRequest)

    #expect(capturedPlannedSources.isEmpty)
    #expect(capturedSynthesisRequest.publicWebSearchEnabled == true)
}

@Test("Analyst worker leaves source-gap judgment with LLM runtime when direct web research is enabled")
func analystWorkerLeavesSourceGapJudgmentWithLLMRuntimeWhenDirectWebResearchIsEnabled() async throws {
    let now = Date(timeIntervalSince1970: 1_700_710_320)
    let charter = try #require(
        StandingAnalystBenchSeed()
            .seededCharters(now: now)
            .first(where: { $0.charterId == "bench-sector-financials" })
    )
    let task = AnalystTask(
        taskId: "task-source-gap-plan",
        analystId: charter.analystId,
        charterId: charter.charterId,
        title: "Financials standing follow-up",
        description: "Use app news first, identify missing funding and credit information, and note bounded source gaps when the best follow-up source cannot be used directly.",
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
    let fixture = AnalystWorkerFixture(
        initialCharters: [charter],
        initialTasks: [task],
        initialNews: [
            NewsEvent(
                eventId: "news-source-gap-plan",
                source: "rss_marketwatch",
                title: "Regional-bank funding pressure returns to focus",
                url: "https://example.com/news-source-gap-plan",
                publishedAt: now.addingTimeInterval(10),
                receivedAt: now.addingTimeInterval(11),
                summary: "The baseline headline raises funding concerns but leaves peer breadth and deeper credit commentary unresolved.",
                rawSymbolHints: ["KRE"],
                tags: ["banks", "funding"],
                payloadVersion: 1
            )
        ]
    )
    let planningProvider = StubResearchPlanningProvider(
        output: AnalystResearchPlanningOutput(
            planSummary: "The app-news baseline is useful, but premium bank trade reporting would materially sharpen the read on deposit and funding breadth.",
            missingInformation: [
                "Whether funding pressure is isolated or showing up across a wider peer set."
            ],
            researchQuestions: [
                "Which specialist source would best answer unresolved deposit and funding breadth questions?"
            ],
            publicTargets: [
                .init(
                    source: "FDIC newsroom",
                    urlOrDomain: "https://www.fdic.gov/news/",
                    category: "regulator",
                    whyItMatters: "Official regulator materials can test whether the funding signal has broader system context.",
                    missingInformationNeed: "Whether deposit and funding conditions are worsening beyond the initial headline."
                )
            ],
            sourceGapRecommendations: [
                .init(
                    source: "American Banker",
                    domain: "www.americanbanker.com",
                    whyItMatters: "Specialist financial trade reporting would materially sharpen the read on deposit and funding breadth.",
                    missingInformationNeed: "Whether broader peer commentary confirms a system-wide funding issue rather than an isolated headline.",
                    limitationHint: "subscription_gated"
                )
            ]
        )
    )
    let synthesisProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "Funding breadth remains the key unresolved issue",
            findingSummary: "The baseline bank headline matters, but the stronger read depends on deeper funding-breadth evidence.",
            findingThesis: "The run identified one bounded source gap that would materially improve the financials review.",
            findingConfidence: 0.62,
            findingTimeHorizon: "quarterly",
            memoTitle: "Financials funding-breadth memo",
            memoExecutiveSummary: "App news came first, followed by bounded public follow-up and one explicit source-gap recommendation for a missing information need.",
            memoCurrentView: "The available public evidence remains incomplete on peer breadth and funding transmission.",
            memoEvidenceSummary: "The analyst captured a bounded source-gap recommendation when the best next source could not be used directly.",
            memoUncertaintySummary: "Peer breadth remains unresolved without stronger specialist follow-up.",
            memoRecommendedNextStep: "Keep monitoring public regulator and peer updates while the PM reviews the source-gap suggestion.",
            suggestedSymbols: ["kbe", "kre"],
            suggestedTags: ["banks", "funding"]
        )
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        researchPlanningProvider: planningProvider,
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { now.addingTimeInterval(30) }
    )

    _ = try await service.runOnce(
        charterID: charter.charterId,
        taskID: task.taskId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1",
            reasoningMode: .standard,
            policySource: .standingBenchDefault,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    let suggestions = await fixture.sourceAccessSuggestions()

    #expect(await planningProvider.callCount == 0)
    #expect(await synthesisProvider.callCount == 1)
    #expect(suggestions.isEmpty)
}

@Test("Analyst worker falls back honestly when OpenAI key is missing")
func analystWorkerFallsBackHonestlyWhenOpenAIKeyMissing() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_200)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)
    let fixture = AnalystWorkerFixture(initialCharters: [charter])
    let synthesisProvider = StubOpenAISynthesisProvider(
        output: AnalystOpenAISynthesisOutput(
            findingTitle: "unused",
            findingSummary: "unused",
            findingThesis: "unused",
            findingConfidence: 0.5,
            memoTitle: "unused",
            memoExecutiveSummary: "unused",
            memoCurrentView: "unused",
            memoEvidenceSummary: "unused",
            memoUncertaintySummary: "unused",
            memoRecommendedNextStep: "unused"
        )
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: false),
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { now.addingTimeInterval(10) }
    )

    let summary = try await service.runOnce(
        charterID: charter.charterId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    #expect(summary.usedOpenAI == false)
    #expect(summary.synthesisStatus == "fallback_missing_openai_key")
    #expect(summary.synthesisIssueSummary == "openai_api_key_missing")
    #expect(summary.runtimeProvenance?.actualRuntimeIdentifier == "deterministic_local_fallback[gpt-5]")
    #expect(await synthesisProvider.callCount == 0)
}

@Test("Analyst worker falls back honestly when OpenAI provider fails")
func analystWorkerFallsBackHonestlyWhenOpenAIProviderFails() async throws {
    let now = Date(timeIntervalSince1970: 1_700_700_300)
    let charter = AnalystCharterSeed().makeInitialCharter(now: now)
    let fixture = AnalystWorkerFixture(initialCharters: [charter])
    let synthesisProvider = StubOpenAISynthesisProvider(
        error: AnalystOpenAISynthesisError.httpStatus(503, responseSummary: nil)
    )
    let service = AnalystWorkerService(
        client: fixture,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true, value: "test-openai-key"),
        openAISynthesisProvider: synthesisProvider,
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: []),
        now: { now.addingTimeInterval(10) }
    )

    let summary = try await service.runOnce(
        charterID: charter.charterId,
        intendedRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-4.1-mini",
            reasoningMode: .standard,
            policySource: .pmDelegationOverride,
            createdAt: now,
            updatedAt: now
        ),
        newsLimit: 5
    )

    #expect(summary.usedOpenAI == false)
    #expect(summary.synthesisStatus == "fallback_openai_error")
    #expect(summary.synthesisIssueSummary == "openai_provider_failure_status=503")
    #expect(summary.runtimeProvenance?.actualRuntimeIdentifier == "deterministic_local_fallback[gpt-4.1-mini]")
    #expect(await synthesisProvider.callCount == 1)
}

@Test("External analyst worker seam round-trips via authenticated IPC")
func analystWorkerRoundTripsViaIPC() async throws {
    let state = AnalystWorkerIPCState()
    await state.setNews([
        NewsEvent(
            eventId: "news-ipc-1",
            source: "rss_fed",
            title: "Technology capex faces power bottlenecks",
            url: "https://example.com/news-ipc-1",
            publishedAt: Date(timeIntervalSince1970: 1_700_600_000),
            receivedAt: Date(timeIntervalSince1970: 1_700_600_005),
            summary: "Power and data-center capacity remain a adoption bottleneck.",
            rawSymbolHints: ["NVDA", "MSFT"],
            tags: ["ai", "power"],
            payloadVersion: 1
        )
    ])

    let token = "token-analyst-worker"
    let handlers = makeContractHandlers(
        listNews: { limit, _ in
            Array(await state.listNews().prefix(max(1, limit)))
        },
        listAnalystCharters: {
            await state.listCharters()
        },
        getAnalystCharter: { id in
            if let charter = await state.getCharter(id: id) {
                return charter
            }
            throw AnalystCharterStoreError.charterNotFound(id: id)
        },
        upsertAnalystCharter: { charter in
            await state.upsertCharter(charter)
        },
        listAnalystTasks: {
            await state.listTasks()
        },
        getAnalystTask: { id in
            if let task = await state.getTask(id: id) {
                return task
            }
            throw AnalystTaskStoreError.taskNotFound(id: id)
        },
        upsertAnalystTask: { task in
            await state.upsertTask(task)
        },
        upsertAnalystEvidenceBundle: { bundle in
            await state.upsertBundle(bundle)
        },
        upsertAnalystFinding: { finding in
            await state.upsertFinding(finding)
        },
        draftSignalFromAnalystFinding: { findingID in
            try await state.draftSignal(fromFindingID: findingID)
        },
        draftProposalFromAnalystSignal: { signalID, strategyID in
            try await state.draftProposal(fromSignalID: signalID, strategyID: strategyID)
        }
    )
    let router = AgentControlRouter(authToken: token, handlers: handlers)
    let server = LoopbackHTTPServer()
    let port = try await server.start(host: "127.0.0.1", preferredPort: 0) { request in
        await router.handle(request)
    }

    let runtimeRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests-analyst-worker-runtime-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: runtimeRoot, withIntermediateDirectories: true)
    let runtimeStore = AgentControlRuntimeInfoStore(
        fileURL: runtimeRoot.appendingPathComponent("ipc.json", isDirectory: false)
    )
    try runtimeStore.save(
        AgentControlRuntimeInfo(host: "127.0.0.1", port: port, token: token)
    )

    let session = URLSession(configuration: .ephemeral)
    let client = AnalystIPCClient(runtimeInfoStore: runtimeStore, session: session)
    let service = AnalystWorkerService(
        client: client,
        openAIKeyStatusProvider: StubOpenAIKeyProvider(configured: true),
        externalEvidenceProvider: StubExternalEvidenceProvider(documents: [
            ExternalAnalystEvidenceDocument(
                sourceID: "stanford-ai-index-report",
                url: "https://aiindex.stanford.edu/report/",
                title: "AI Index Report",
                observedAt: Date(timeIntervalSince1970: 1_700_600_050),
                summary: "Power and data-center bottlenecks remain important.",
                snippet: "Power and data-center bottlenecks remain important.",
                provenanceNote: "approved_allowlist_source:stanford_ai_index"
            )
        ]),
        now: { Date(timeIntervalSince1970: 1_700_600_100) }
    )

    do {
        let summary = try await service.runOnce(charterID: "bench-sector-technology", newsLimit: 5)
        #expect(summary.charterSeeded == true)
        #expect(summary.analystId == "bench-sector-technology-analyst")
        #expect(summary.newsCount == 1)
        #expect(summary.externalEvidenceCount == 1)
        #expect(summary.taskId == "task-bench-sector-technology-ongoing-research")

        let persistedCharters = await state.listCharters()
        #expect(persistedCharters.count == 9)
        let persistedBundles = await state.listBundles()
        #expect(persistedBundles.count == 1)
        let persistedFindings = await state.listFindings()
        let persistedTasks = await state.listTasks()
        #expect(persistedFindings.count == 1)
        #expect(persistedTasks.count == 1)
        #expect(persistedBundles[0].charterId == "bench-sector-technology")
        #expect(persistedBundles[0].taskId == summary.taskId)
        let persistedHasWebRef = persistedBundles[0].refs.contains { $0.sourceKind == .web }
        #expect(persistedHasWebRef)
        #expect(persistedFindings[0].charterId == "bench-sector-technology")
        #expect(persistedFindings[0].analystId == "bench-sector-technology-analyst")
        #expect(persistedFindings[0].taskId == summary.taskId)
        #expect(persistedFindings[0].evidenceBundleId == persistedBundles[0].bundleId)
        #expect(persistedTasks[0].checkpoint?.linkedFindingIDs == [persistedFindings[0].findingId])
    } catch {
        session.finishTasksAndInvalidate()
        await stopServerAndDrain(server)
        throw error
    }

    session.finishTasksAndInvalidate()
    await stopServerAndDrain(server)
}

private struct StubOpenAIKeyProvider: OpenAIKeyStatusProviding {
    let configured: Bool
    let value: String?

    init(configured: Bool, value: String? = nil) {
        self.configured = configured
        self.value = value
    }

    func isConfigured() -> Bool {
        configured
    }

    func apiKey() -> String? {
        value
    }
}

private func makeStubSynthesisOutput(title: String) -> AnalystOpenAISynthesisOutput {
    AnalystOpenAISynthesisOutput(
        findingTitle: title,
        findingSummary: "\(title) summary.",
        findingThesis: "\(title) thesis.",
        findingConfidence: 0.62,
        findingTimeHorizon: "near_term",
        memoTitle: title,
        memoExecutiveSummary: "\(title) executive summary.",
        memoCurrentView: "\(title) current view.",
        memoEvidenceSummary: "\(title) evidence summary.",
        memoUncertaintySummary: "\(title) uncertainty summary.",
        memoRecommendedNextStep: "\(title) next step.",
        suggestedSymbols: [],
        suggestedTags: ["Ad Hoc Research"]
    )
}

private actor StubOpenAISynthesisProvider: AnalystOpenAISynthesisProviding {
    private let output: AnalystOpenAISynthesisOutput?
    private let error: (any Error)?
    private(set) var callCount = 0
    private(set) var lastRequest: AnalystOpenAISynthesisRequest?

    init(output: AnalystOpenAISynthesisOutput) {
        self.output = output
        self.error = nil
    }

    init(error: any Error) {
        self.output = nil
        self.error = error
    }

    func synthesize(
        request: AnalystOpenAISynthesisRequest,
        apiKey: String
    ) async throws -> AnalystOpenAISynthesisOutput {
        callCount += 1
        lastRequest = request
        if let error {
            throw error
        }
        return try #require(output)
    }
}

private struct StubAnalystLLMCredentialResolver: LLMCredentialResolving {
    let resolution: LLMCredentialResolution

    func resolve(profile: LLMCredentialProfile) -> LLMCredentialResolution {
        LLMCredentialResolution(
            status: resolution.status,
            apiKey: resolution.providerKind == profile.providerKind ? resolution.apiKey : nil,
            profileId: profile.profileId,
            providerKind: profile.providerKind,
            source: resolution.source,
            matchedServiceOrLabel: resolution.matchedServiceOrLabel,
            account: profile.keychainAccount,
            summary: resolution.providerKind == profile.providerKind
                ? resolution.summary
                : "No test credential was configured for \(profile.providerKind.displayName)."
        )
    }
}

private actor StubResearchPlanningProvider: AnalystResearchPlanningProviding {
    private let output: AnalystResearchPlanningOutput
    private(set) var callCount = 0
    private(set) var lastRequest: AnalystResearchPlanningRequest?

    init(output: AnalystResearchPlanningOutput) {
        self.output = output
    }

    func planResearch(
        request: AnalystResearchPlanningRequest,
        apiKey: String
    ) async throws -> AnalystResearchPlanningOutput {
        _ = apiKey
        callCount += 1
        lastRequest = request
        return output
    }
}

private struct StubExternalEvidenceProvider: ExternalAnalystEvidenceProviding {
    let result: AnalystExternalEvidenceFetchResult

    init(documents: [ExternalAnalystEvidenceDocument]) {
        self.result = AnalystExternalEvidenceFetchResult(documents: documents)
    }

    init(result: AnalystExternalEvidenceFetchResult) {
        self.result = result
    }

    func fetchEvidence(
        for charter: AnalystCharter,
        task: AnalystTask,
        baselineNews: [NewsEvent],
        plannedSources: [ApprovedAnalystSourceDefinition]
    ) async -> AnalystExternalEvidenceFetchResult {
        _ = charter
        _ = task
        _ = baselineNews
        _ = plannedSources
        return result
    }
}

private actor RecordingExternalEvidenceProvider: ExternalAnalystEvidenceProviding {
    private let result: AnalystExternalEvidenceFetchResult
    private var calls = 0
    private var capturedBaselineNews: [NewsEvent] = []
    private var capturedPlannedSources: [ApprovedAnalystSourceDefinition] = []

    init(documents: [ExternalAnalystEvidenceDocument]) {
        self.result = AnalystExternalEvidenceFetchResult(documents: documents)
    }

    func fetchEvidence(
        for charter: AnalystCharter,
        task: AnalystTask,
        baselineNews: [NewsEvent],
        plannedSources: [ApprovedAnalystSourceDefinition]
    ) async -> AnalystExternalEvidenceFetchResult {
        _ = charter
        _ = task
        calls += 1
        capturedBaselineNews = baselineNews
        capturedPlannedSources = plannedSources
        return result
    }

    func callCount() -> Int {
        calls
    }

    func baselineNews() -> [NewsEvent] {
        capturedBaselineNews
    }

    func plannedSources() -> [ApprovedAnalystSourceDefinition] {
        capturedPlannedSources
    }
}

private actor StubExternalHTTPClient: ExternalAnalystHTTPClient {
    enum Response {
        case success(Data, URLResponse)
        case failure(any Error)
    }

    private let handler: @Sendable (URLRequest) throws -> (Data, URLResponse)
    private var capturedRequests: [URLRequest] = []

    init(response: Response) {
        self.handler = { request in
            switch response {
            case let .success(data, urlResponse):
                return (data, urlResponse)
            case let .failure(error):
                throw error
            }
        }
    }

    init(responsesByURL: [String: Response]) {
        self.handler = { request in
            guard let absoluteString = request.url?.absoluteString,
                  let response = responsesByURL[absoluteString] else {
                throw URLError(.badURL)
            }
            switch response {
            case let .success(data, urlResponse):
                return (data, urlResponse)
            case let .failure(error):
                throw error
            }
        }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        return try handler(request)
    }

    func requests() -> [URLRequest] {
        capturedRequests
    }
}

private func parseISO(_ value: String) -> Date? {
    DateCodec.parseISO8601(value)
}

private func makeExternalFetchTask(
    id: String = "task-external-fetch",
    title: String = "External evidence fetch task",
    description: String = "Fetch bounded supplemental public web evidence.",
    now: Date = Date(timeIntervalSince1970: 1_700_700_000)
) -> AnalystTask {
    AnalystTask(
        taskId: id,
        analystId: "analyst-external-fetch",
        charterId: "charter-external-fetch",
        title: title,
        description: description,
        status: .queued,
        createdAt: now,
        updatedAt: now
    )
}

private actor AnalystWorkerFixture: AnalystControlPlaneClient {
    private var storedCharters: [AnalystCharter]
    private var storedTasks: [AnalystTask]
    private var storedNews: [NewsEvent]
    private var storedBundles: [AnalystEvidenceBundle]
    private var storedMemos: [AnalystMemo]
    private var storedFindings: [AnalystFinding]
    private var storedSourceAccessSuggestions: [AnalystSourceAccessSuggestionRecord]
    private var storedSignals: [Signal]
    private var signalDraftError: AnalystIPCClientError?

    init(
        initialCharters: [AnalystCharter] = [],
        initialTasks: [AnalystTask] = [],
        initialNews: [NewsEvent] = [],
        initialBundles: [AnalystEvidenceBundle] = [],
        initialMemos: [AnalystMemo] = [],
        initialFindings: [AnalystFinding] = [],
        initialSourceAccessSuggestions: [AnalystSourceAccessSuggestionRecord] = [],
        initialSignals: [Signal] = [],
        signalDraftError: AnalystIPCClientError? = nil
    ) {
        self.storedCharters = initialCharters
        self.storedTasks = initialTasks
        self.storedNews = initialNews
        self.storedBundles = initialBundles
        self.storedMemos = initialMemos
        self.storedFindings = initialFindings
        self.storedSourceAccessSuggestions = initialSourceAccessSuggestions
        self.storedSignals = initialSignals
        self.signalDraftError = signalDraftError
    }

    func setNews(_ news: [NewsEvent]) {
        storedNews = news
    }

    func listCharters() async throws -> [AnalystCharter] { storedCharters }

    func upsertCharter(_ charter: AnalystCharter) async throws -> AnalystCharter {
        if let index = storedCharters.firstIndex(where: { $0.charterId == charter.charterId }) {
            storedCharters[index] = charter
        } else {
            storedCharters.append(charter)
        }
        return charter
    }

    func listSourceAccessSuggestions() async throws -> [AnalystSourceAccessSuggestionRecord] {
        storedSourceAccessSuggestions
    }

    func upsertSourceAccessSuggestion(_ suggestion: AnalystSourceAccessSuggestionRecord) async throws -> AnalystSourceAccessSuggestionRecord {
        if let index = storedSourceAccessSuggestions.firstIndex(where: { $0.suggestionId == suggestion.suggestionId }) {
            storedSourceAccessSuggestions[index] = suggestion
        } else {
            storedSourceAccessSuggestions.append(suggestion)
        }
        return suggestion
    }

    func listTasks() async throws -> [AnalystTask] { storedTasks }

    func getTask(id: String) async throws -> AnalystTask {
        guard let task = storedTasks.first(where: { $0.taskId == id }) else {
            throw AnalystTaskStoreError.taskNotFound(id: id)
        }
        return task
    }

    func upsertTask(_ task: AnalystTask) async throws -> AnalystTask {
        if let index = storedTasks.firstIndex(where: { $0.taskId == task.taskId }) {
            storedTasks[index] = task
        } else {
            storedTasks.append(task)
        }
        return task
    }

    func listMemos() async throws -> [AnalystMemo] { storedMemos }

    func getMemo(id: String) async throws -> AnalystMemo {
        guard let memo = storedMemos.first(where: { $0.memoId == id }) else {
            throw AnalystMemoStoreError.memoNotFound(id: id)
        }
        return memo
    }

    func listNews(limit: Int, since: Date?) async throws -> [NewsEvent] {
        storedNews
            .filter { event in
                guard let since else { return true }
                return event.publishedAt >= since
            }
            .prefix(max(1, limit))
            .map { $0 }
    }

    func upsertEvidenceBundle(_ bundle: AnalystEvidenceBundle) async throws -> AnalystEvidenceBundle {
        if let index = storedBundles.firstIndex(where: { $0.bundleId == bundle.bundleId }) {
            storedBundles[index] = bundle
        } else {
            storedBundles.append(bundle)
        }
        return bundle
    }

    func upsertMemo(_ memo: AnalystMemo) async throws -> AnalystMemo {
        if let index = storedMemos.firstIndex(where: { $0.memoId == memo.memoId }) {
            storedMemos[index] = memo
        } else {
            storedMemos.append(memo)
        }
        return memo
    }

    func upsertFinding(_ finding: AnalystFinding) async throws -> AnalystFinding {
        if let index = storedFindings.firstIndex(where: { $0.findingId == finding.findingId }) {
            storedFindings[index] = finding
        } else {
            storedFindings.append(finding)
        }
        return finding
    }

    func draftSignalFromFinding(id: String) async throws -> Signal {
        if let signalDraftError {
            throw signalDraftError
        }
        guard let findingIndex = storedFindings.firstIndex(where: { $0.findingId == id }) else {
            throw AnalystFindingStoreError.findingNotFound(id: id)
        }
        let finding = storedFindings[findingIndex]
        let signalID = finding.linkedSignalId ?? "sig-\(id)"
        let signal = Signal(
            signalId: signalID,
            createdAt: finding.createdAt,
            updatedAt: finding.updatedAt,
            status: .new,
            symbols: finding.symbols.isEmpty ? ["NVDA"] : finding.symbols,
            direction: .bullish,
            horizon: .swing,
            confidence: finding.confidence,
            score: finding.confidence,
            positionStatement: finding.thesis,
            recommendedAction: .notifyOnly,
            evidence: [
                SignalEvidenceRef(
                    type: .finding,
                    id: finding.findingId,
                    title: finding.title,
                    summary: finding.summary,
                    timestamp: finding.updatedAt
                )
            ],
            provenance: SignalProvenance(
                sourceJobId: "analyst.finding_draft",
                scoringVersion: "analyst-finding-v1",
                analystId: finding.analystId,
                charterId: finding.charterId,
                taskId: finding.taskId,
                sourceFindingId: finding.findingId,
                sourceEvidenceBundleId: finding.evidenceBundleId
            ),
            originatingFindingId: finding.findingId
        )
        if let index = storedSignals.firstIndex(where: { $0.signalId == signalID }) {
            storedSignals[index] = signal
        } else {
            storedSignals.append(signal)
        }
        var updatedFinding = finding
        updatedFinding.linkedSignalId = signalID
        storedFindings[findingIndex] = updatedFinding
        return signal
    }

    func draftProposalFromSignal(id: String, strategyID: String) async throws -> StrategyProposal {
        guard let signal = storedSignals.first(where: { $0.signalId == id }) else {
            throw SignalStoreError.signalNotFound(id: id)
        }

        return StrategyProposal(
            proposalId: "proposal-\(id)",
            createdAt: signal.createdAt,
            updatedAt: signal.updatedAt,
            createdBy: "analyst-job",
            title: "Proposal for \(id)",
            summary: signal.positionStatement,
            strategyId: strategyID,
            parameters: [:],
            scope: StrategyProposalScope(symbols: signal.symbols),
            intendedEnvironmentPaperOnly: true,
            constraints: StrategyProposalConstraints(
                maxOrdersPerMinute: 5,
                maxNotionalPerOrder: 1_000
            ),
            testPlan: StrategyProposalTestPlan(
                durationMinutes: 60,
                successMetrics: ["signal_alignment"],
                stopConditions: ["manual_stop"]
            ),
            rationale: signal.positionStatement,
            metadata: [:],
            originatingSignalId: signal.signalId,
            analystLineage: AnalystProposalLineage(
                analystId: signal.provenance.analystId,
                charterId: signal.provenance.charterId,
                taskId: signal.provenance.taskId,
                originatingFindingId: signal.originatingFindingId ?? signal.provenance.sourceFindingId,
                sourceEvidenceBundleId: signal.provenance.sourceEvidenceBundleId
            ),
            approval: StrategyProposalApproval(status: .draft)
        )
    }

    func charters() -> [AnalystCharter] { storedCharters }
    func tasks() -> [AnalystTask] { storedTasks }
    func bundles() -> [AnalystEvidenceBundle] { storedBundles }
    func memos() -> [AnalystMemo] { storedMemos }
    func findings() -> [AnalystFinding] { storedFindings }
    func signals() -> [Signal] { storedSignals }
    func sourceAccessSuggestions() -> [AnalystSourceAccessSuggestionRecord] { storedSourceAccessSuggestions }
}

private actor AnalystWorkerIPCState {
    private var charters: [String: AnalystCharter] = [:]
    private var tasks: [String: AnalystTask] = [:]
    private var bundles: [String: AnalystEvidenceBundle] = [:]
    private var memos: [String: AnalystMemo] = [:]
    private var findings: [String: AnalystFinding] = [:]
    private var signals: [String: Signal] = [:]
    private var news: [NewsEvent] = []

    func setNews(_ news: [NewsEvent]) {
        self.news = news
    }

    func listNews() -> [NewsEvent] {
        news.sorted { $0.publishedAt > $1.publishedAt }
    }

    func listCharters() -> [AnalystCharter] {
        charters.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func getCharter(id: String) -> AnalystCharter? {
        charters[id]
    }

    func upsertCharter(_ charter: AnalystCharter) -> AnalystCharter {
        charters[charter.charterId] = charter
        return charter
    }

    func listTasks() -> [AnalystTask] {
        tasks.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func getTask(id: String) -> AnalystTask? {
        tasks[id]
    }

    func upsertTask(_ task: AnalystTask) -> AnalystTask {
        tasks[task.taskId] = task
        return task
    }

    func upsertBundle(_ bundle: AnalystEvidenceBundle) -> AnalystEvidenceBundle {
        bundles[bundle.bundleId] = bundle
        return bundle
    }

    func listMemos() -> [AnalystMemo] {
        Array(memos.values)
    }

    func getMemo(id: String) -> AnalystMemo? {
        memos[id]
    }

    func upsertMemo(_ memo: AnalystMemo) -> AnalystMemo {
        memos[memo.memoId] = memo
        return memo
    }

    func upsertFinding(_ finding: AnalystFinding) -> AnalystFinding {
        findings[finding.findingId] = finding
        return finding
    }

    func draftSignal(fromFindingID id: String) throws -> Signal {
        guard var finding = findings[id] else {
            throw AnalystFindingStoreError.findingNotFound(id: id)
        }
        let signalID = finding.linkedSignalId ?? "sig-\(id)"
        let signal = Signal(
            signalId: signalID,
            createdAt: finding.createdAt,
            updatedAt: finding.updatedAt,
            status: .new,
            symbols: finding.symbols.isEmpty ? ["NVDA"] : finding.symbols,
            direction: .bullish,
            horizon: .swing,
            confidence: finding.confidence,
            score: finding.confidence,
            positionStatement: finding.thesis,
            recommendedAction: .notifyOnly,
            evidence: [
                SignalEvidenceRef(
                    type: .finding,
                    id: finding.findingId,
                    title: finding.title,
                    summary: finding.summary,
                    timestamp: finding.updatedAt
                )
            ],
            provenance: SignalProvenance(
                sourceJobId: "analyst.finding_draft",
                scoringVersion: "analyst-finding-v1",
                analystId: finding.analystId,
                charterId: finding.charterId,
                taskId: finding.taskId,
                sourceFindingId: finding.findingId,
                sourceEvidenceBundleId: finding.evidenceBundleId
            ),
            originatingFindingId: finding.findingId
        )
        finding.linkedSignalId = signalID
        findings[id] = finding
        signals[signalID] = signal
        return signal
    }

    func draftProposal(fromSignalID id: String, strategyID: String) throws -> StrategyProposal {
        guard let signal = signals[id] else {
            throw SignalStoreError.signalNotFound(id: id)
        }

        return StrategyProposal(
            proposalId: "proposal-\(id)",
            createdAt: signal.createdAt,
            updatedAt: signal.updatedAt,
            createdBy: "analyst-job",
            title: "Proposal for \(id)",
            summary: signal.positionStatement,
            strategyId: strategyID,
            parameters: [:],
            scope: StrategyProposalScope(symbols: signal.symbols),
            intendedEnvironmentPaperOnly: true,
            constraints: StrategyProposalConstraints(
                maxOrdersPerMinute: 5,
                maxNotionalPerOrder: 1_000
            ),
            testPlan: StrategyProposalTestPlan(
                durationMinutes: 60,
                successMetrics: ["signal_alignment"],
                stopConditions: ["manual_stop"]
            ),
            rationale: signal.positionStatement,
            metadata: [:],
            originatingSignalId: signal.signalId,
            analystLineage: AnalystProposalLineage(
                analystId: signal.provenance.analystId,
                charterId: signal.provenance.charterId,
                taskId: signal.provenance.taskId,
                originatingFindingId: signal.originatingFindingId ?? signal.provenance.sourceFindingId,
                sourceEvidenceBundleId: signal.provenance.sourceEvidenceBundleId
            ),
            approval: StrategyProposalApproval(status: .draft)
        )
    }

    func listBundles() -> [AnalystEvidenceBundle] {
        Array(bundles.values)
    }

    func listFindings() -> [AnalystFinding] {
        Array(findings.values)
    }

    func listSignals() -> [Signal] {
        Array(signals.values)
    }
}

private func stopServerAndDrain(_ server: LoopbackHTTPServer) async {
    await server.stop()
    try? await Task.sleep(nanoseconds: 20_000_000)
}

private func makeAnalystTempDirectory(name: String) -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
