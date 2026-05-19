import Foundation

public struct IPCServerStatus: Sendable, Equatable, Codable {
    public let running: Bool
    public let host: String
    public let port: Int?
    public let tokenFile: String?

    public init(
        running: Bool,
        host: String,
        port: Int?,
        tokenFile: String?
    ) {
        self.running = running
        self.host = host
        self.port = port
        self.tokenFile = tokenFile
    }

    public static func stopped(host: String = "127.0.0.1") -> IPCServerStatus {
        IPCServerStatus(running: false, host: host, port: nil, tokenFile: nil)
    }
}

public struct AgentControlRuntimeInfo: Sendable, Codable, Equatable {
    public let host: String
    public let port: Int
    public let token: String

    public init(host: String = "127.0.0.1", port: Int, token: String) {
        self.host = host
        self.port = port
        self.token = token
    }
}

public enum AgentControlRuntimeInfoStoreError: Error, Sendable {
    case unsupportedPath
    case missingFile
    case invalidFile
}

public struct AgentControlRuntimeInfoStore: Sendable {
    private let customFileURL: URL?

    public init(fileURL: URL? = nil) {
        self.customFileURL = fileURL
    }

    public func fileURL() throws -> URL {
        if let customFileURL {
            return customFileURL
        }

        return AppSupportPaths.rootDirectory()
            .appendingPathComponent("ipc.json", isDirectory: false)
    }

    public func save(_ info: AgentControlRuntimeInfo) throws {
        let fileURL = try fileURL()
        let directory = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(info)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([
            .posixPermissions: 0o600
        ], ofItemAtPath: fileURL.path)
    }

    public func load() throws -> AgentControlRuntimeInfo {
        let fileURL = try fileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AgentControlRuntimeInfoStoreError.missingFile
        }

        let data = try Data(contentsOf: fileURL)
        do {
            return try JSONDecoder().decode(AgentControlRuntimeInfo.self, from: data)
        } catch {
            throw AgentControlRuntimeInfoStoreError.invalidFile
        }
    }

    public func clear() throws {
        let fileURL = try fileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}

public struct IPCServerRequest: Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public struct IPCServerResponse: Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public struct AgentControlErrorBody: Sendable, Codable, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct AgentControlEnvelope: Sendable, Codable, Equatable {
    public let ok: Bool
    public let result: JSONValue?
    public let error: AgentControlErrorBody?

    public init(ok: Bool, result: JSONValue? = nil, error: AgentControlErrorBody? = nil) {
        self.ok = ok
        self.result = result
        self.error = error
    }
}

public actor AgentControlRouter {
    public struct Route: Sendable, Hashable, Codable {
        public let method: String
        public let path: String

        public init(method: String, path: String) {
            self.method = method.uppercased()
            self.path = path
        }
    }

    public static let supportedRoutes: [Route] = [
        .init(method: "GET", path: "/status"),
        .init(method: "GET", path: "/strategies"),
        .init(method: "GET", path: "/proposals"),
        .init(method: "GET", path: "/proposal"),
        .init(method: "GET", path: "/runs"),
        .init(method: "GET", path: "/jobs"),
        .init(method: "GET", path: "/schedules"),
        .init(method: "GET", path: "/schedule"),
        .init(method: "GET", path: "/retention-policy"),
        .init(method: "GET", path: "/maintenance/last"),
        .init(method: "GET", path: "/rss/feeds"),
        .init(method: "GET", path: "/news"),
        .init(method: "GET", path: "/pm/profiles"),
        .init(method: "GET", path: "/pm/profile"),
        .init(method: "POST", path: "/pm/profile/upsert"),
        .init(method: "GET", path: "/pm/mandates"),
        .init(method: "GET", path: "/pm/mandate"),
        .init(method: "POST", path: "/pm/mandate/upsert"),
        .init(method: "GET", path: "/pm/instructions"),
        .init(method: "GET", path: "/pm/instruction"),
        .init(method: "POST", path: "/pm/instruction/upsert"),
        .init(method: "GET", path: "/pm/notebook"),
        .init(method: "GET", path: "/pm/notebook-entry"),
        .init(method: "POST", path: "/pm/notebook-entry/upsert"),
        .init(method: "GET", path: "/pm/portfolio-strategy-brief"),
        .init(method: "POST", path: "/pm/portfolio-strategy-brief/upsert"),
        .init(method: "GET", path: "/pm/decisions"),
        .init(method: "GET", path: "/pm/decision"),
        .init(method: "POST", path: "/pm/decision/upsert"),
        .init(method: "GET", path: "/pm/approval-requests"),
        .init(method: "GET", path: "/pm/approval-request"),
        .init(method: "POST", path: "/pm/approval-request/upsert"),
        .init(method: "GET", path: "/pm/execution-readiness"),
        .init(method: "POST", path: "/pm/execution/route"),
        .init(method: "GET", path: "/pm/communication-sessions"),
        .init(method: "GET", path: "/pm/communication-session"),
        .init(method: "POST", path: "/pm/communication-session/upsert"),
        .init(method: "GET", path: "/pm/communication-messages"),
        .init(method: "GET", path: "/pm/communication-message"),
        .init(method: "POST", path: "/pm/communication-message/upsert"),
        .init(method: "GET", path: "/pm/delegations"),
        .init(method: "GET", path: "/pm/delegation"),
        .init(method: "POST", path: "/pm/delegation/upsert"),
        .init(method: "POST", path: "/pm/delegation/follow-up"),
        .init(method: "POST", path: "/pm/delegation/launch"),
        .init(method: "GET", path: "/analyst/charters"),
        .init(method: "GET", path: "/analyst/charter"),
        .init(method: "POST", path: "/analyst/charter/upsert"),
        .init(method: "GET", path: "/analyst/source-access-suggestions"),
        .init(method: "GET", path: "/analyst/source-access-suggestion"),
        .init(method: "POST", path: "/analyst/source-access-suggestion/upsert"),
        .init(method: "GET", path: "/analyst/tasks"),
        .init(method: "GET", path: "/analyst/task"),
        .init(method: "POST", path: "/analyst/task/upsert"),
        .init(method: "GET", path: "/analyst/findings"),
        .init(method: "GET", path: "/analyst/finding"),
        .init(method: "GET", path: "/analyst/memos"),
        .init(method: "GET", path: "/analyst/memo"),
        .init(method: "GET", path: "/analyst/news"),
        .init(method: "GET", path: "/signals"),
        .init(method: "GET", path: "/run"),
        .init(method: "GET", path: "/job"),
        .init(method: "GET", path: "/signal"),
        .init(method: "POST", path: "/jobs/submit"),
        .init(method: "POST", path: "/job/cancel"),
        .init(method: "POST", path: "/schedule/upsert"),
        .init(method: "POST", path: "/schedule/remove"),
        .init(method: "POST", path: "/schedule/enable"),
        .init(method: "POST", path: "/schedule/run-now"),
        .init(method: "POST", path: "/retention-policy/update"),
        .init(method: "POST", path: "/maintenance/run"),
        .init(method: "POST", path: "/maintenance/memory-relief"),
        .init(method: "POST", path: "/signal/ack"),
        .init(method: "POST", path: "/signal/archive"),
        .init(method: "POST", path: "/analyst/evidence-bundle/upsert"),
        .init(method: "POST", path: "/analyst/memo/upsert"),
        .init(method: "POST", path: "/analyst/finding/upsert"),
        .init(method: "POST", path: "/analyst/signal/draft-proposal"),
        .init(method: "POST", path: "/rss/feed/add"),
        .init(method: "POST", path: "/rss/feed/update"),
        .init(method: "POST", path: "/rss/feed/remove"),
        .init(method: "POST", path: "/strategy/start"),
        .init(method: "POST", path: "/strategy/start-from-proposal"),
        .init(method: "POST", path: "/strategy/stop"),
        .init(method: "POST", path: "/strategy/params"),
        .init(method: "POST", path: "/proposal/upsert"),
        .init(method: "POST", path: "/proposal/submit"),
        .init(method: "POST", path: "/proposal/approve-paper"),
        .init(method: "POST", path: "/proposal/deny-paper"),
        .init(method: "POST", path: "/run/export"),
        .init(method: "POST", path: "/replay/ingest"),
        .init(method: "POST", path: "/replay/run"),
        .init(method: "POST", path: "/replay/quick"),
        .init(method: "POST", path: "/safety/arm-live"),
        .init(method: "POST", path: "/safety/disarm-live"),
        .init(method: "POST", path: "/safety/kill-switch")
    ]

    public struct Handlers: Sendable {
        public let status: @Sendable () async -> JSONValue
        public let strategies: @Sendable () async -> [StrategyStatusSnapshot]
        public let startStrategy: @Sendable (String, [String: JSONValue]) async throws -> StrategyStatusSnapshot
        public let startStrategyFromProposal: @Sendable (String) async throws -> StrategyStatusSnapshot
        public let stopStrategy: @Sendable (String) async throws -> StrategyStatusSnapshot
        public let setStrategyParams: @Sendable (String, [String: JSONValue]) async throws -> StrategyStatusSnapshot
        public let proposals: @Sendable () async throws -> [ProposalRow]
        public let proposal: @Sendable (String) async throws -> StrategyProposal?
        public let upsertProposal: @Sendable (StrategyProposal) async throws -> StrategyProposal
        public let submitProposal: @Sendable (String) async throws -> StrategyProposal
        public let approveProposalPaper: @Sendable (String, String, String) async throws -> StrategyProposal
        public let denyProposalPaper: @Sendable (String, String, String) async throws -> StrategyProposal
        public let listRuns: @Sendable (String) async throws -> [PaperRunRecordSummary]
        public let getRun: @Sendable (String) async throws -> PaperRunRecord
        public let exportRun: @Sendable (String) async throws -> String
        public let listJobs: @Sendable () async throws -> [JobSummary]
        public let getJob: @Sendable (String) async throws -> JobRecord
        public let submitJob: @Sendable (JobType, [String: JSONValue]) async throws -> JobRecord
        public let cancelJob: @Sendable (String) async throws -> JobRecord
        public let listSchedules: @Sendable () async throws -> [ScheduledJobSummary]
        public let getSchedule: @Sendable (String) async throws -> ScheduledJob?
        public let upsertSchedule: @Sendable (ScheduledJob) async throws -> ScheduledJobSummary
        public let removeSchedule: @Sendable (String) async throws -> Void
        public let setScheduleEnabled: @Sendable (String, Bool) async throws -> ScheduledJobSummary
        public let runScheduleNow: @Sendable (String) async throws -> ScheduledJobSummary
        public let getRetentionPolicy: @Sendable () async throws -> RetentionPolicy
        public let updateRetentionPolicy: @Sendable (RetentionPolicy) async throws -> RetentionPolicy
        public let runMaintenance: @Sendable (Bool, Date?) async throws -> JobRecord
        public let runMemoryRelief: @Sendable (MemoryReliefRequest) async throws -> JSONValue
        public let lastMaintenance: @Sendable () async throws -> JobSummary?
        public let listRSSFeeds: @Sendable () async throws -> [RSSFeed]
        public let addRSSFeed: @Sendable (RSSFeed) async throws -> RSSFeed
        public let updateRSSFeed: @Sendable (RSSFeed) async throws -> RSSFeed
        public let removeRSSFeed: @Sendable (String) async throws -> Void
        public let listNews: @Sendable (Int, Date?) async throws -> [NewsEvent]
        public let listPMProfiles: @Sendable () async throws -> [PMProfile]
        public let getPMProfile: @Sendable (String) async throws -> PMProfile
        public let upsertPMProfile: @Sendable (PMProfile) async throws -> PMProfile
        public let listPMMandates: @Sendable () async throws -> [PMMandate]
        public let getPMMandate: @Sendable (String) async throws -> PMMandate
        public let upsertPMMandate: @Sendable (PMMandate) async throws -> PMMandate
        public let listPMInstructions: @Sendable () async throws -> [PMInstruction]
        public let getPMInstruction: @Sendable (String) async throws -> PMInstruction
        public let upsertPMInstruction: @Sendable (PMInstruction) async throws -> PMInstruction
        public let listPMNotebookEntries: @Sendable () async throws -> [PMNotebookEntry]
        public let getPMNotebookEntry: @Sendable (String) async throws -> PMNotebookEntry
        public let upsertPMNotebookEntry: @Sendable (PMNotebookEntry) async throws -> PMNotebookEntry
        public let getPortfolioStrategyBrief: @Sendable () async throws -> PortfolioStrategyBrief
        public let upsertPortfolioStrategyBrief: @Sendable (PortfolioStrategyBrief) async throws -> PortfolioStrategyBrief
        public let getRecentNewsAnalystRuntimeSettings: @Sendable () async throws -> RecentNewsAnalystRuntimeSettings
        public let upsertRecentNewsAnalystRuntimeSettings: @Sendable (RecentNewsAnalystRuntimeSettings) async throws -> RecentNewsAnalystRuntimeSettings
        public let getStandingBenchAnalystRuntimeSettings: @Sendable () async throws -> StandingBenchAnalystRuntimeSettings
        public let upsertStandingBenchAnalystRuntimeSettings: @Sendable (StandingBenchAnalystRuntimeSettings) async throws -> StandingBenchAnalystRuntimeSettings
        public let listPMDecisions: @Sendable () async throws -> [PMDecisionRecord]
        public let getPMDecision: @Sendable (String) async throws -> PMDecisionRecord
        public let upsertPMDecision: @Sendable (PMDecisionRecord) async throws -> PMDecisionRecord
        public let listPMApprovalRequests: @Sendable () async throws -> [PMApprovalRequest]
        public let getPMApprovalRequest: @Sendable (String) async throws -> PMApprovalRequest
        public let upsertPMApprovalRequest: @Sendable (PMApprovalRequest) async throws -> PMApprovalRequest
        public let assessPMExecutionRouting: @Sendable (String) async throws -> PMExecutionRoutingAssessment
        public let routePMExecutionApprovedIntent: @Sendable (String) async throws -> PMExecutionRoutingAssessment
        public let listPMCommunicationSessions: @Sendable () async throws -> [PMCommunicationSession]
        public let getPMCommunicationSession: @Sendable (String) async throws -> PMCommunicationSession
        public let upsertPMCommunicationSession: @Sendable (PMCommunicationSession) async throws -> PMCommunicationSession
        public let listPMCommunicationMessages: @Sendable () async throws -> [PMCommunicationMessage]
        public let getPMCommunicationMessage: @Sendable (String) async throws -> PMCommunicationMessage
        public let upsertPMCommunicationMessage: @Sendable (PMCommunicationMessage) async throws -> PMCommunicationMessage
        public let listPMDelegations: @Sendable () async throws -> [PMDelegationRecord]
        public let getPMDelegation: @Sendable (String) async throws -> PMDelegationRecord
        public let upsertPMDelegation: @Sendable (PMDelegationRecord) async throws -> PMDelegationRecord
        public let submitPMDelegationFollowUp: @Sendable (PMDelegationFollowUpRequest) async throws -> PMDelegationFollowUpResult
        public let launchPMDelegation: @Sendable (String, Bool, Bool) async throws -> AnalystWorkerLaunchResult
        public let listAnalystCharters: @Sendable () async throws -> [AnalystCharter]
        public let getAnalystCharter: @Sendable (String) async throws -> AnalystCharter
        public let upsertAnalystCharter: @Sendable (AnalystCharter) async throws -> AnalystCharter
        public let listAnalystSourceAccessSuggestions: @Sendable () async throws -> [AnalystSourceAccessSuggestionRecord]
        public let getAnalystSourceAccessSuggestion: @Sendable (String) async throws -> AnalystSourceAccessSuggestionRecord
        public let upsertAnalystSourceAccessSuggestion: @Sendable (AnalystSourceAccessSuggestionRecord) async throws -> AnalystSourceAccessSuggestionRecord
        public let listAnalystTasks: @Sendable () async throws -> [AnalystTask]
        public let getAnalystTask: @Sendable (String) async throws -> AnalystTask
        public let upsertAnalystTask: @Sendable (AnalystTask) async throws -> AnalystTask
        public let listAnalystFindings: @Sendable () async throws -> [AnalystFinding]
        public let getAnalystFinding: @Sendable (String) async throws -> AnalystFinding
        public let listAnalystMemos: @Sendable () async throws -> [AnalystMemo]
        public let getAnalystMemo: @Sendable (String) async throws -> AnalystMemo
        public let upsertAnalystEvidenceBundle: @Sendable (AnalystEvidenceBundle) async throws -> AnalystEvidenceBundle
        public let upsertAnalystMemo: @Sendable (AnalystMemo) async throws -> AnalystMemo
        public let upsertAnalystFinding: @Sendable (AnalystFinding) async throws -> AnalystFinding
        public let draftSignalFromAnalystFinding: @Sendable (String) async throws -> Signal
        public let draftProposalFromAnalystSignal: @Sendable (String, String) async throws -> StrategyProposal
        public let listSignals: @Sendable (SignalStatus?, Int) async throws -> [Signal]
        public let getSignal: @Sendable (String) async throws -> Signal
        public let acknowledgeSignal: @Sendable (String) async throws -> Signal
        public let archiveSignal: @Sendable (String) async throws -> Signal
        public let replayIngest: @Sendable (ReplayIngestRequest) async throws -> ReplayIngestResult
        public let replayRun: @Sendable (ReplayRunRequest) async throws -> ReplayRunResult
        public let replayQuick: @Sendable (ReplayQuickRequest) async throws -> ReplayRunResult
        public let armLive: @Sendable () async -> String?
        public let disarmLive: @Sendable () async -> Void
        public let setKillSwitch: @Sendable (Bool) async -> Void

        public init(
            status: @escaping @Sendable () async -> JSONValue,
            strategies: @escaping @Sendable () async -> [StrategyStatusSnapshot],
            startStrategy: @escaping @Sendable (String, [String: JSONValue]) async throws -> StrategyStatusSnapshot,
            startStrategyFromProposal: @escaping @Sendable (String) async throws -> StrategyStatusSnapshot,
            stopStrategy: @escaping @Sendable (String) async throws -> StrategyStatusSnapshot,
            setStrategyParams: @escaping @Sendable (String, [String: JSONValue]) async throws -> StrategyStatusSnapshot,
            proposals: @escaping @Sendable () async throws -> [ProposalRow],
            proposal: @escaping @Sendable (String) async throws -> StrategyProposal?,
            upsertProposal: @escaping @Sendable (StrategyProposal) async throws -> StrategyProposal,
            submitProposal: @escaping @Sendable (String) async throws -> StrategyProposal,
            approveProposalPaper: @escaping @Sendable (String, String, String) async throws -> StrategyProposal,
            denyProposalPaper: @escaping @Sendable (String, String, String) async throws -> StrategyProposal,
            listRuns: @escaping @Sendable (String) async throws -> [PaperRunRecordSummary],
            getRun: @escaping @Sendable (String) async throws -> PaperRunRecord,
            exportRun: @escaping @Sendable (String) async throws -> String,
            listJobs: @escaping @Sendable () async throws -> [JobSummary],
            getJob: @escaping @Sendable (String) async throws -> JobRecord,
            submitJob: @escaping @Sendable (JobType, [String: JSONValue]) async throws -> JobRecord,
            cancelJob: @escaping @Sendable (String) async throws -> JobRecord,
            listSchedules: @escaping @Sendable () async throws -> [ScheduledJobSummary],
            getSchedule: @escaping @Sendable (String) async throws -> ScheduledJob?,
            upsertSchedule: @escaping @Sendable (ScheduledJob) async throws -> ScheduledJobSummary,
            removeSchedule: @escaping @Sendable (String) async throws -> Void,
            setScheduleEnabled: @escaping @Sendable (String, Bool) async throws -> ScheduledJobSummary,
            runScheduleNow: @escaping @Sendable (String) async throws -> ScheduledJobSummary,
            getRetentionPolicy: @escaping @Sendable () async throws -> RetentionPolicy,
            updateRetentionPolicy: @escaping @Sendable (RetentionPolicy) async throws -> RetentionPolicy,
            runMaintenance: @escaping @Sendable (Bool, Date?) async throws -> JobRecord,
            runMemoryRelief: @escaping @Sendable (MemoryReliefRequest) async throws -> JSONValue = { request in
                .object([
                    "available": .bool(false),
                    "dryRun": .bool(request.dryRun),
                    "force": .bool(request.force),
                    "reason": .string(request.reason),
                    "summary": .string("Memory relief is not available in this runtime.")
                ])
            },
            lastMaintenance: @escaping @Sendable () async throws -> JobSummary?,
            listRSSFeeds: @escaping @Sendable () async throws -> [RSSFeed],
            addRSSFeed: @escaping @Sendable (RSSFeed) async throws -> RSSFeed,
            updateRSSFeed: @escaping @Sendable (RSSFeed) async throws -> RSSFeed,
            removeRSSFeed: @escaping @Sendable (String) async throws -> Void,
            listNews: @escaping @Sendable (Int, Date?) async throws -> [NewsEvent],
            listPMProfiles: @escaping @Sendable () async throws -> [PMProfile],
            getPMProfile: @escaping @Sendable (String) async throws -> PMProfile,
            upsertPMProfile: @escaping @Sendable (PMProfile) async throws -> PMProfile,
            listPMMandates: @escaping @Sendable () async throws -> [PMMandate],
            getPMMandate: @escaping @Sendable (String) async throws -> PMMandate,
            upsertPMMandate: @escaping @Sendable (PMMandate) async throws -> PMMandate,
            listPMInstructions: @escaping @Sendable () async throws -> [PMInstruction],
            getPMInstruction: @escaping @Sendable (String) async throws -> PMInstruction,
            upsertPMInstruction: @escaping @Sendable (PMInstruction) async throws -> PMInstruction,
            listPMNotebookEntries: @escaping @Sendable () async throws -> [PMNotebookEntry],
            getPMNotebookEntry: @escaping @Sendable (String) async throws -> PMNotebookEntry,
            upsertPMNotebookEntry: @escaping @Sendable (PMNotebookEntry) async throws -> PMNotebookEntry,
            getPortfolioStrategyBrief: @escaping @Sendable () async throws -> PortfolioStrategyBrief,
            upsertPortfolioStrategyBrief: @escaping @Sendable (PortfolioStrategyBrief) async throws -> PortfolioStrategyBrief,
            getRecentNewsAnalystRuntimeSettings: @escaping @Sendable () async throws -> RecentNewsAnalystRuntimeSettings = {
                .default(now: Date())
            },
            upsertRecentNewsAnalystRuntimeSettings: @escaping @Sendable (RecentNewsAnalystRuntimeSettings) async throws -> RecentNewsAnalystRuntimeSettings = { $0 },
            getStandingBenchAnalystRuntimeSettings: @escaping @Sendable () async throws -> StandingBenchAnalystRuntimeSettings = {
                .default(now: Date())
            },
            upsertStandingBenchAnalystRuntimeSettings: @escaping @Sendable (StandingBenchAnalystRuntimeSettings) async throws -> StandingBenchAnalystRuntimeSettings = { $0 },
            listPMDecisions: @escaping @Sendable () async throws -> [PMDecisionRecord],
            getPMDecision: @escaping @Sendable (String) async throws -> PMDecisionRecord,
            upsertPMDecision: @escaping @Sendable (PMDecisionRecord) async throws -> PMDecisionRecord,
            listPMApprovalRequests: @escaping @Sendable () async throws -> [PMApprovalRequest],
            getPMApprovalRequest: @escaping @Sendable (String) async throws -> PMApprovalRequest,
            upsertPMApprovalRequest: @escaping @Sendable (PMApprovalRequest) async throws -> PMApprovalRequest,
            assessPMExecutionRouting: @escaping @Sendable (String) async throws -> PMExecutionRoutingAssessment = { approvalRequestID in
                PMExecutionRoutingAssessment(
                    approvalRequestId: approvalRequestID,
                    decisionId: nil,
                    proposalId: nil,
                    proposalTitle: nil,
                    proposalStatus: nil,
                    environment: .paper,
                    isLiveArmed: false,
                    killSwitchEnabled: false,
                    status: .invalidState,
                    action: .none,
                    summary: "No PM execution routing handler was configured.",
                    detail: "Provide an execution-routing handler for this control-plane surface before using PM execution routes.",
                    blockedReasons: [.proposalNotLinked]
                )
            },
            routePMExecutionApprovedIntent: @escaping @Sendable (String) async throws -> PMExecutionRoutingAssessment = { approvalRequestID in
                PMExecutionRoutingAssessment(
                    approvalRequestId: approvalRequestID,
                    decisionId: nil,
                    proposalId: nil,
                    proposalTitle: nil,
                    proposalStatus: nil,
                    environment: .paper,
                    isLiveArmed: false,
                    killSwitchEnabled: false,
                    status: .invalidState,
                    action: .none,
                    summary: "No PM execution-routing handler was configured.",
                    detail: "Provide an execution-routing handler for this control-plane surface before using PM execution routes.",
                    blockedReasons: [.proposalNotLinked]
                )
            },
            listPMCommunicationSessions: @escaping @Sendable () async throws -> [PMCommunicationSession],
            getPMCommunicationSession: @escaping @Sendable (String) async throws -> PMCommunicationSession,
            upsertPMCommunicationSession: @escaping @Sendable (PMCommunicationSession) async throws -> PMCommunicationSession,
            listPMCommunicationMessages: @escaping @Sendable () async throws -> [PMCommunicationMessage],
            getPMCommunicationMessage: @escaping @Sendable (String) async throws -> PMCommunicationMessage,
            upsertPMCommunicationMessage: @escaping @Sendable (PMCommunicationMessage) async throws -> PMCommunicationMessage,
            listPMDelegations: @escaping @Sendable () async throws -> [PMDelegationRecord],
            getPMDelegation: @escaping @Sendable (String) async throws -> PMDelegationRecord,
            upsertPMDelegation: @escaping @Sendable (PMDelegationRecord) async throws -> PMDelegationRecord,
            submitPMDelegationFollowUp: @escaping @Sendable (PMDelegationFollowUpRequest) async throws -> PMDelegationFollowUpResult = { request in
                PMDelegationFollowUpResult(
                    sourceDelegationId: request.sourceDelegationId,
                    sourceFollowUpActionId: "follow-up-unconfigured",
                    createdDelegationId: nil,
                    createdTaskId: nil,
                    createdDecisionId: nil,
                    launchResult: nil
                )
            },
            launchPMDelegation: @escaping @Sendable (String, Bool, Bool) async throws -> AnalystWorkerLaunchResult,
            listAnalystCharters: @escaping @Sendable () async throws -> [AnalystCharter],
            getAnalystCharter: @escaping @Sendable (String) async throws -> AnalystCharter,
            upsertAnalystCharter: @escaping @Sendable (AnalystCharter) async throws -> AnalystCharter,
            listAnalystSourceAccessSuggestions: @escaping @Sendable () async throws -> [AnalystSourceAccessSuggestionRecord] = { [] },
            getAnalystSourceAccessSuggestion: @escaping @Sendable (String) async throws -> AnalystSourceAccessSuggestionRecord = { id in
                throw AnalystSourceAccessSuggestionStoreError.suggestionNotFound(id: id)
            },
            upsertAnalystSourceAccessSuggestion: @escaping @Sendable (AnalystSourceAccessSuggestionRecord) async throws -> AnalystSourceAccessSuggestionRecord = { $0 },
            listAnalystTasks: @escaping @Sendable () async throws -> [AnalystTask],
            getAnalystTask: @escaping @Sendable (String) async throws -> AnalystTask,
            upsertAnalystTask: @escaping @Sendable (AnalystTask) async throws -> AnalystTask,
            listAnalystFindings: @escaping @Sendable () async throws -> [AnalystFinding],
            getAnalystFinding: @escaping @Sendable (String) async throws -> AnalystFinding,
            listAnalystMemos: @escaping @Sendable () async throws -> [AnalystMemo],
            getAnalystMemo: @escaping @Sendable (String) async throws -> AnalystMemo,
            upsertAnalystEvidenceBundle: @escaping @Sendable (AnalystEvidenceBundle) async throws -> AnalystEvidenceBundle,
            upsertAnalystMemo: @escaping @Sendable (AnalystMemo) async throws -> AnalystMemo,
            upsertAnalystFinding: @escaping @Sendable (AnalystFinding) async throws -> AnalystFinding,
            draftSignalFromAnalystFinding: @escaping @Sendable (String) async throws -> Signal,
            draftProposalFromAnalystSignal: @escaping @Sendable (String, String) async throws -> StrategyProposal,
            listSignals: @escaping @Sendable (SignalStatus?, Int) async throws -> [Signal],
            getSignal: @escaping @Sendable (String) async throws -> Signal,
            acknowledgeSignal: @escaping @Sendable (String) async throws -> Signal,
            archiveSignal: @escaping @Sendable (String) async throws -> Signal,
            replayIngest: @escaping @Sendable (ReplayIngestRequest) async throws -> ReplayIngestResult,
            replayRun: @escaping @Sendable (ReplayRunRequest) async throws -> ReplayRunResult,
            replayQuick: @escaping @Sendable (ReplayQuickRequest) async throws -> ReplayRunResult,
            armLive: @escaping @Sendable () async -> String?,
            disarmLive: @escaping @Sendable () async -> Void,
            setKillSwitch: @escaping @Sendable (Bool) async -> Void
        ) {
            self.status = status
            self.strategies = strategies
            self.startStrategy = startStrategy
            self.startStrategyFromProposal = startStrategyFromProposal
            self.stopStrategy = stopStrategy
            self.setStrategyParams = setStrategyParams
            self.proposals = proposals
            self.proposal = proposal
            self.upsertProposal = upsertProposal
            self.submitProposal = submitProposal
            self.approveProposalPaper = approveProposalPaper
            self.denyProposalPaper = denyProposalPaper
            self.listRuns = listRuns
            self.getRun = getRun
            self.exportRun = exportRun
            self.listJobs = listJobs
            self.getJob = getJob
            self.submitJob = submitJob
            self.cancelJob = cancelJob
            self.listSchedules = listSchedules
            self.getSchedule = getSchedule
            self.upsertSchedule = upsertSchedule
            self.removeSchedule = removeSchedule
            self.setScheduleEnabled = setScheduleEnabled
            self.runScheduleNow = runScheduleNow
            self.getRetentionPolicy = getRetentionPolicy
            self.updateRetentionPolicy = updateRetentionPolicy
            self.runMaintenance = runMaintenance
            self.runMemoryRelief = runMemoryRelief
            self.lastMaintenance = lastMaintenance
            self.listRSSFeeds = listRSSFeeds
            self.addRSSFeed = addRSSFeed
            self.updateRSSFeed = updateRSSFeed
            self.removeRSSFeed = removeRSSFeed
            self.listNews = listNews
            self.listPMProfiles = listPMProfiles
            self.getPMProfile = getPMProfile
            self.upsertPMProfile = upsertPMProfile
            self.listPMMandates = listPMMandates
            self.getPMMandate = getPMMandate
            self.upsertPMMandate = upsertPMMandate
            self.listPMInstructions = listPMInstructions
            self.getPMInstruction = getPMInstruction
            self.upsertPMInstruction = upsertPMInstruction
            self.listPMNotebookEntries = listPMNotebookEntries
            self.getPMNotebookEntry = getPMNotebookEntry
            self.upsertPMNotebookEntry = upsertPMNotebookEntry
            self.getPortfolioStrategyBrief = getPortfolioStrategyBrief
            self.upsertPortfolioStrategyBrief = upsertPortfolioStrategyBrief
            self.getRecentNewsAnalystRuntimeSettings = getRecentNewsAnalystRuntimeSettings
            self.upsertRecentNewsAnalystRuntimeSettings = upsertRecentNewsAnalystRuntimeSettings
            self.getStandingBenchAnalystRuntimeSettings = getStandingBenchAnalystRuntimeSettings
            self.upsertStandingBenchAnalystRuntimeSettings = upsertStandingBenchAnalystRuntimeSettings
            self.listPMDecisions = listPMDecisions
            self.getPMDecision = getPMDecision
            self.upsertPMDecision = upsertPMDecision
            self.listPMApprovalRequests = listPMApprovalRequests
            self.getPMApprovalRequest = getPMApprovalRequest
            self.upsertPMApprovalRequest = upsertPMApprovalRequest
            self.assessPMExecutionRouting = assessPMExecutionRouting
            self.routePMExecutionApprovedIntent = routePMExecutionApprovedIntent
            self.listPMCommunicationSessions = listPMCommunicationSessions
            self.getPMCommunicationSession = getPMCommunicationSession
            self.upsertPMCommunicationSession = upsertPMCommunicationSession
            self.listPMCommunicationMessages = listPMCommunicationMessages
            self.getPMCommunicationMessage = getPMCommunicationMessage
            self.upsertPMCommunicationMessage = upsertPMCommunicationMessage
            self.listPMDelegations = listPMDelegations
            self.getPMDelegation = getPMDelegation
            self.upsertPMDelegation = upsertPMDelegation
            self.submitPMDelegationFollowUp = submitPMDelegationFollowUp
            self.launchPMDelegation = launchPMDelegation
            self.listAnalystCharters = listAnalystCharters
            self.getAnalystCharter = getAnalystCharter
            self.upsertAnalystCharter = upsertAnalystCharter
            self.listAnalystSourceAccessSuggestions = listAnalystSourceAccessSuggestions
            self.getAnalystSourceAccessSuggestion = getAnalystSourceAccessSuggestion
            self.upsertAnalystSourceAccessSuggestion = upsertAnalystSourceAccessSuggestion
            self.listAnalystTasks = listAnalystTasks
            self.getAnalystTask = getAnalystTask
            self.upsertAnalystTask = upsertAnalystTask
            self.listAnalystFindings = listAnalystFindings
            self.getAnalystFinding = getAnalystFinding
            self.listAnalystMemos = listAnalystMemos
            self.getAnalystMemo = getAnalystMemo
            self.upsertAnalystEvidenceBundle = upsertAnalystEvidenceBundle
            self.upsertAnalystMemo = upsertAnalystMemo
            self.upsertAnalystFinding = upsertAnalystFinding
            self.draftSignalFromAnalystFinding = draftSignalFromAnalystFinding
            self.draftProposalFromAnalystSignal = draftProposalFromAnalystSignal
            self.listSignals = listSignals
            self.getSignal = getSignal
            self.acknowledgeSignal = acknowledgeSignal
            self.archiveSignal = archiveSignal
            self.replayIngest = replayIngest
            self.replayRun = replayRun
            self.replayQuick = replayQuick
            self.armLive = armLive
            self.disarmLive = disarmLive
            self.setKillSwitch = setKillSwitch
        }
    }

    private let authToken: String
    private let handlers: Handlers

    public init(authToken: String, handlers: Handlers) {
        self.authToken = authToken
        self.handlers = handlers
    }

    public func handle(_ request: IPCServerRequest) async -> IPCServerResponse {
        guard isAuthorized(request.headers) else {
            return failureResponse(statusCode: 401, code: "unauthorized", message: "Missing or invalid X-Agent-Token header")
        }

        let route = parseRoute(request.path)
        switch (request.method.uppercased(), route.path) {
        case ("GET", "/status"):
            let result = await handlers.status()
            return success(result)
        case ("GET", "/strategies"):
            let statuses = await handlers.strategies()
            return success(.array(statuses.map(jsonValue(strategyStatus:))))
        case ("GET", "/proposals"):
            return await handleProposals()
        case ("GET", "/proposal"):
            return await handleProposalGet(route.query)
        case ("GET", "/runs"):
            return await handleRuns(route.query)
        case ("GET", "/jobs"):
            return await handleJobsList()
        case ("GET", "/schedules"):
            return await handleSchedulesList()
        case ("GET", "/schedule"):
            return await handleScheduleGet(route.query)
        case ("GET", "/retention-policy"):
            return await handleRetentionPolicyGet()
        case ("GET", "/maintenance/last"):
            return await handleMaintenanceLast()
        case ("GET", "/rss/feeds"):
            return await handleRSSFeedsList()
        case ("GET", "/news"):
            return await handleNewsList(route.query)
        case ("GET", "/pm/profiles"):
            return await handlePMProfilesList()
        case ("GET", "/pm/profile"):
            return await handlePMProfileGet(route.query)
        case ("POST", "/pm/profile/upsert"):
            return await handlePMProfileUpsert(request.body)
        case ("GET", "/pm/mandates"):
            return await handlePMMandatesList()
        case ("GET", "/pm/mandate"):
            return await handlePMMandateGet(route.query)
        case ("POST", "/pm/mandate/upsert"):
            return await handlePMMandateUpsert(request.body)
        case ("GET", "/pm/instructions"):
            return await handlePMInstructionsList()
        case ("GET", "/pm/instruction"):
            return await handlePMInstructionGet(route.query)
        case ("POST", "/pm/instruction/upsert"):
            return await handlePMInstructionUpsert(request.body)
        case ("GET", "/pm/notebook"):
            return await handlePMNotebookEntriesList()
        case ("GET", "/pm/notebook-entry"):
            return await handlePMNotebookEntryGet(route.query)
        case ("POST", "/pm/notebook-entry/upsert"):
            return await handlePMNotebookEntryUpsert(request.body)
        case ("GET", "/pm/portfolio-strategy-brief"):
            return await handlePortfolioStrategyBriefGet()
        case ("POST", "/pm/portfolio-strategy-brief/upsert"):
            return await handlePortfolioStrategyBriefUpsert(request.body)
        case ("GET", "/pm/recent-news-analyst-runtime"):
            return await handleRecentNewsAnalystRuntimeSettingsGet()
        case ("POST", "/pm/recent-news-analyst-runtime/upsert"):
            return await handleRecentNewsAnalystRuntimeSettingsUpsert(request.body)
        case ("GET", "/pm/standing-bench-analyst-runtime"):
            return await handleStandingBenchAnalystRuntimeSettingsGet()
        case ("POST", "/pm/standing-bench-analyst-runtime/upsert"):
            return await handleStandingBenchAnalystRuntimeSettingsUpsert(request.body)
        case ("GET", "/pm/decisions"):
            return await handlePMDecisionsList()
        case ("GET", "/pm/decision"):
            return await handlePMDecisionGet(route.query)
        case ("POST", "/pm/decision/upsert"):
            return await handlePMDecisionUpsert(request.body)
        case ("GET", "/pm/approval-requests"):
            return await handlePMApprovalRequestsList()
        case ("GET", "/pm/approval-request"):
            return await handlePMApprovalRequestGet(route.query)
        case ("POST", "/pm/approval-request/upsert"):
            return await handlePMApprovalRequestUpsert(request.body)
        case ("GET", "/pm/execution-readiness"):
            return await handlePMExecutionReadiness(route.query)
        case ("POST", "/pm/execution/route"):
            return await handlePMExecutionRoute(request.body)
        case ("GET", "/pm/communication-sessions"):
            return await handlePMCommunicationSessionsList()
        case ("GET", "/pm/communication-session"):
            return await handlePMCommunicationSessionGet(route.query)
        case ("POST", "/pm/communication-session/upsert"):
            return await handlePMCommunicationSessionUpsert(request.body)
        case ("GET", "/pm/communication-messages"):
            return await handlePMCommunicationMessagesList()
        case ("GET", "/pm/communication-message"):
            return await handlePMCommunicationMessageGet(route.query)
        case ("POST", "/pm/communication-message/upsert"):
            return await handlePMCommunicationMessageUpsert(request.body)
        case ("GET", "/pm/delegations"):
            return await handlePMDelegationsList()
        case ("GET", "/pm/delegation"):
            return await handlePMDelegationGet(route.query)
        case ("POST", "/pm/delegation/upsert"):
            return await handlePMDelegationUpsert(request.body)
        case ("POST", "/pm/delegation/follow-up"):
            return await handlePMDelegationFollowUp(request.body)
        case ("POST", "/pm/delegation/launch"):
            return await handlePMDelegationLaunch(request.body)
        case ("GET", "/analyst/charters"):
            return await handleAnalystChartersList()
        case ("GET", "/analyst/charter"):
            return await handleAnalystCharterGet(route.query)
        case ("POST", "/analyst/charter/upsert"):
            return await handleAnalystCharterUpsert(request.body)
        case ("GET", "/analyst/source-access-suggestions"):
            return await handleAnalystSourceAccessSuggestionsList()
        case ("GET", "/analyst/source-access-suggestion"):
            return await handleAnalystSourceAccessSuggestionGet(route.query)
        case ("POST", "/analyst/source-access-suggestion/upsert"):
            return await handleAnalystSourceAccessSuggestionUpsert(request.body)
        case ("GET", "/analyst/tasks"):
            return await handleAnalystTasksList()
        case ("GET", "/analyst/task"):
            return await handleAnalystTaskGet(route.query)
        case ("POST", "/analyst/task/upsert"):
            return await handleAnalystTaskUpsert(request.body)
        case ("GET", "/analyst/findings"):
            return await handleAnalystFindingsList()
        case ("GET", "/analyst/finding"):
            return await handleAnalystFindingGet(route.query)
        case ("GET", "/analyst/memos"):
            return await handleAnalystMemosList()
        case ("GET", "/analyst/memo"):
            return await handleAnalystMemoGet(route.query)
        case ("GET", "/analyst/news"):
            return await handleAnalystNewsList(route.query)
        case ("GET", "/signals"):
            return await handleSignalsList(route.query)
        case ("GET", "/run"):
            return await handleRunGet(route.query)
        case ("GET", "/job"):
            return await handleJobGet(route.query)
        case ("GET", "/signal"):
            return await handleSignalGet(route.query)
        case ("POST", "/jobs/submit"):
            return await handleJobSubmit(request.body)
        case ("POST", "/job/cancel"):
            return await handleJobCancel(request.body)
        case ("POST", "/schedule/upsert"):
            return await handleScheduleUpsert(request.body)
        case ("POST", "/schedule/remove"):
            return await handleScheduleRemove(request.body)
        case ("POST", "/schedule/enable"):
            return await handleScheduleEnable(request.body)
        case ("POST", "/schedule/run-now"):
            return await handleScheduleRunNow(request.body)
        case ("POST", "/retention-policy/update"):
            return await handleRetentionPolicyUpdate(request.body)
        case ("POST", "/maintenance/run"):
            return await handleMaintenanceRun(request.body)
        case ("POST", "/maintenance/memory-relief"):
            return await handleMaintenanceMemoryRelief(request.body)
        case ("POST", "/signal/ack"):
            return await handleSignalAcknowledge(request.body)
        case ("POST", "/signal/archive"):
            return await handleSignalArchive(request.body)
        case ("POST", "/analyst/evidence-bundle/upsert"):
            return await handleAnalystEvidenceBundleUpsert(request.body)
        case ("POST", "/analyst/memo/upsert"):
            return await handleAnalystMemoUpsert(request.body)
        case ("POST", "/analyst/finding/upsert"):
            return await handleAnalystFindingUpsert(request.body)
        case ("POST", "/analyst/finding/draft-signal"):
            return await handleAnalystFindingDraftSignal(request.body)
        case ("POST", "/analyst/signal/draft-proposal"):
            return await handleAnalystSignalDraftProposal(request.body)
        case ("POST", "/rss/feed/add"):
            return await handleRSSFeedAdd(request.body)
        case ("POST", "/rss/feed/update"):
            return await handleRSSFeedUpdate(request.body)
        case ("POST", "/rss/feed/remove"):
            return await handleRSSFeedRemove(request.body)
        case ("POST", "/strategy/start"):
            return await handleStrategyStart(request.body)
        case ("POST", "/strategy/start-from-proposal"):
            return await handleStrategyStartFromProposal(request.body)
        case ("POST", "/strategy/stop"):
            return await handleStrategyStop(request.body)
        case ("POST", "/strategy/params"):
            return await handleStrategyParams(request.body)
        case ("POST", "/proposal/upsert"):
            return await handleProposalUpsert(request.body)
        case ("POST", "/proposal/submit"):
            return await handleProposalSubmit(request.body)
        case ("POST", "/proposal/approve-paper"):
            return await handleProposalApproval(request.body, approve: true)
        case ("POST", "/proposal/deny-paper"):
            return await handleProposalApproval(request.body, approve: false)
        case ("POST", "/run/export"):
            return await handleRunExport(request.body)
        case ("POST", "/replay/ingest"):
            return await handleReplayIngest(request.body)
        case ("POST", "/replay/run"):
            return await handleReplayRun(request.body)
        case ("POST", "/replay/quick"):
            return await handleReplayQuick(request.body)
        case ("POST", "/safety/arm-live"):
            return success(.object([
                "armed": .bool(false),
                "armingSessionId": .null,
                "blocked": .bool(true),
                "code": .string("local_app_required_for_live_arming"),
                "message": .string("Live arming must be completed in the Mac app.")
            ]))
        case ("POST", "/safety/disarm-live"):
            await handlers.disarmLive()
            return success(.object(["armed": .bool(false)]))
        case ("POST", "/safety/kill-switch"):
            return await handleKillSwitch(request.body)
        default:
            return failureResponse(statusCode: 404, code: "not_found", message: "Endpoint not found")
        }
    }

    private func handleStrategyStart(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body) else {
            return badRequest("Invalid JSON body")
        }

        guard let id = object["id"]?.stringValue,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return badRequest("Missing strategy id")
        }

        let params = object["params"]?.objectValue ?? [:]

        do {
            let status = try await handlers.startStrategy(id, params)
            return success(jsonValue(strategyStatus: status))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "start_failed", error: error)
        }
    }

    private func handleStrategyStartFromProposal(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let proposalID = object["proposalId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !proposalID.isEmpty
        else {
            return badRequest("Missing proposalId")
        }

        do {
            let status = try await handlers.startStrategyFromProposal(proposalID)
            return success(jsonValue(strategyStatus: status))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "start_from_proposal_failed", error: error)
        }
    }

    private func handleStrategyStop(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body) else {
            return badRequest("Invalid JSON body")
        }

        guard let id = object["id"]?.stringValue,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return badRequest("Missing strategy id")
        }

        do {
            let status = try await handlers.stopStrategy(id)
            return success(jsonValue(strategyStatus: status))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "stop_failed", error: error)
        }
    }

    private func handleStrategyParams(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body) else {
            return badRequest("Invalid JSON body")
        }

        guard let id = object["id"]?.stringValue,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return badRequest("Missing strategy id")
        }

        let params = object["params"]?.objectValue ?? [:]

        do {
            let status = try await handlers.setStrategyParams(id, params)
            return success(jsonValue(strategyStatus: status))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "params_failed", error: error)
        }
    }

    private func handleProposals() async -> IPCServerResponse {
        do {
            let rows = try await handlers.proposals()
            let values = try rows.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "proposals_failed", error: error)
        }
    }

    private func handleProposalGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let proposalID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !proposalID.isEmpty
        else {
            return badRequest("Missing proposal id query parameter")
        }

        do {
            guard let proposal = try await handlers.proposal(proposalID) else {
                return failureResponse(statusCode: 404, code: "proposal_not_found", message: "Proposal not found")
            }
            return success(try jsonValue(encodable: proposal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "proposal_get_failed", error: error)
        }
    }

    private func handleRuns(_ query: [String: String]) async -> IPCServerResponse {
        guard let proposalID = query["proposalId"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !proposalID.isEmpty
        else {
            return badRequest("Missing proposalId query parameter")
        }

        do {
            let runs = try await handlers.listRuns(proposalID)
            let values = try runs.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "runs_failed", error: error)
        }
    }

    private func handleRunGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let runID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !runID.isEmpty
        else {
            return badRequest("Missing run id query parameter")
        }

        do {
            let run = try await handlers.getRun(runID)
            return success(try jsonValue(encodable: run))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "run_get_failed", error: error)
        }
    }

    private func handleJobsList() async -> IPCServerResponse {
        do {
            let jobs = try await handlers.listJobs()
            let values = try jobs.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "jobs_failed", error: error)
        }
    }

    private func handleJobGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let jobID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !jobID.isEmpty
        else {
            return badRequest("Missing job id query parameter")
        }

        do {
            let job = try await handlers.getJob(jobID)
            return success(try jsonValue(encodable: job))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "job_get_failed", error: error)
        }
    }

    private func handleJobSubmit(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body) else {
            return badRequest("Invalid JSON body")
        }
        guard let typeRaw = object["type"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              let type = JobType(rawValue: typeRaw)
        else {
            return badRequest("Missing or invalid job type")
        }
        let params = object["params"]?.objectValue ?? [:]

        do {
            let job = try await handlers.submitJob(type, params)
            return success(try jsonValue(encodable: job))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "job_submit_failed", error: error)
        }
    }

    private func handleJobCancel(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let jobID = object["jobId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !jobID.isEmpty
        else {
            return badRequest("Missing jobId")
        }

        do {
            let job = try await handlers.cancelJob(jobID)
            return success(try jsonValue(encodable: job))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "job_cancel_failed", error: error)
        }
    }

    private func handleSchedulesList() async -> IPCServerResponse {
        do {
            let schedules = try await handlers.listSchedules()
            let values = try schedules.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "schedules_failed", error: error)
        }
    }

    private func handleScheduleGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let scheduleID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !scheduleID.isEmpty
        else {
            return badRequest("Missing schedule id query parameter")
        }

        do {
            guard let schedule = try await handlers.getSchedule(scheduleID) else {
                return failureResponse(
                    statusCode: 404,
                    code: "schedule_not_found",
                    message: "Schedule not found"
                )
            }
            return success(try jsonValue(encodable: schedule))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "schedule_get_failed", error: error)
        }
    }

    private func handleScheduleUpsert(_ body: Data) async -> IPCServerResponse {
        let schedule: ScheduledJob
        do {
            schedule = try makeISO8601Decoder().decode(ScheduledJob.self, from: body)
        } catch {
            return badRequest("Invalid schedule JSON body")
        }

        do {
            let summary = try await handlers.upsertSchedule(schedule)
            return success(try jsonValue(encodable: summary))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "schedule_upsert_failed", error: error)
        }
    }

    private func handleScheduleRemove(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let scheduleID = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !scheduleID.isEmpty
        else {
            return badRequest("Missing schedule id")
        }

        do {
            try await handlers.removeSchedule(scheduleID)
            return success(.object([
                "id": .string(scheduleID),
                "removed": .bool(true)
            ]))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "schedule_remove_failed", error: error)
        }
    }

    private func handleScheduleEnable(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let scheduleID = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !scheduleID.isEmpty
        else {
            return badRequest("Missing schedule id")
        }
        guard let enabled = object["enabled"]?.boolValue else {
            return badRequest("Body must include boolean field: enabled")
        }

        do {
            let summary = try await handlers.setScheduleEnabled(scheduleID, enabled)
            return success(try jsonValue(encodable: summary))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "schedule_enable_failed", error: error)
        }
    }

    private func handleScheduleRunNow(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let scheduleID = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !scheduleID.isEmpty
        else {
            return badRequest("Missing schedule id")
        }

        do {
            let summary = try await handlers.runScheduleNow(scheduleID)
            return success(try jsonValue(encodable: summary))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "schedule_run_now_failed", error: error)
        }
    }

    private func handleRetentionPolicyGet() async -> IPCServerResponse {
        do {
            let policy = try await handlers.getRetentionPolicy()
            return success(try jsonValue(encodable: policy))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "retention_policy_get_failed", error: error)
        }
    }

    private func handleRetentionPolicyUpdate(_ body: Data) async -> IPCServerResponse {
        let policy: RetentionPolicy
        do {
            policy = try makeISO8601Decoder().decode(RetentionPolicy.self, from: body)
        } catch {
            return badRequest("Invalid retention policy JSON body")
        }

        do {
            let updated = try await handlers.updateRetentionPolicy(policy)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "retention_policy_update_failed", error: error)
        }
    }

    private func handleMaintenanceRun(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let dryRun = object["dryRun"]?.boolValue
        else {
            return badRequest("Body must include boolean field: dryRun")
        }
        let jobTelemetryCleanupBefore: Date?
        if let rawCutoff = object["jobTelemetryCleanupBefore"] {
            guard let value = rawCutoff.stringValue,
                  let parsed = DateCodec.parseISO8601(value)
            else {
                return badRequest("jobTelemetryCleanupBefore must be an ISO8601 timestamp string")
            }
            jobTelemetryCleanupBefore = parsed
        } else {
            jobTelemetryCleanupBefore = nil
        }

        do {
            let job = try await handlers.runMaintenance(dryRun, jobTelemetryCleanupBefore)
            return success(.object([
                "jobId": .string(job.jobId),
                "status": .string(job.status.rawValue),
                "dryRun": .bool(dryRun),
                "jobTelemetryCleanupBefore": jobTelemetryCleanupBefore
                    .map { .string(DateCodec.formatISO8601($0)) } ?? .null
            ]))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "maintenance_run_failed", error: error)
        }
    }

    private func handleMaintenanceMemoryRelief(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body) else {
            return badRequest("Invalid JSON body")
        }
        let dryRun: Bool
        if let value = object["dryRun"] {
            guard let parsed = value.boolValue else {
                return badRequest("dryRun must be a boolean")
            }
            dryRun = parsed
        } else {
            dryRun = false
        }
        let force: Bool
        if let value = object["force"] {
            guard let parsed = value.boolValue else {
                return badRequest("force must be a boolean")
            }
            force = parsed
        } else {
            force = false
        }
        let reason = object["reason"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedReason: String
        if let reason, reason.isEmpty == false {
            resolvedReason = reason
        } else {
            resolvedReason = "ipc_maintenance_memory_relief"
        }
        let request = MemoryReliefRequest(
            dryRun: dryRun,
            force: force,
            reason: resolvedReason
        )
        do {
            let summary = try await handlers.runMemoryRelief(request)
            return success(summary)
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "memory_relief_failed", error: error)
        }
    }

    private func handleMaintenanceLast() async -> IPCServerResponse {
        do {
            guard let job = try await handlers.lastMaintenance() else {
                return success(.null)
            }
            return success(try jsonValue(encodable: job))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "maintenance_last_failed", error: error)
        }
    }

    private func handleRSSFeedsList() async -> IPCServerResponse {
        do {
            let feeds = try await handlers.listRSSFeeds()
            let values = try feeds.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "rss_feeds_failed", error: error)
        }
    }

    private func handleRSSFeedAdd(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body) else {
            return badRequest("Invalid JSON body")
        }
        guard let name = object["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else {
            return badRequest("Missing feed name")
        }
        guard let url = object["url"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty
        else {
            return badRequest("Missing feed url")
        }

        let enabled = object["enabled"]?.boolValue ?? true
        let pollIntervalSec = max(15, object["pollIntervalSec"]?.intValue ?? 300)
        let tags = object["tags"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let feed = RSSFeed(
            name: name,
            url: url,
            enabled: enabled,
            pollIntervalSec: pollIntervalSec,
            tags: tags
        )

        do {
            let created = try await handlers.addRSSFeed(feed)
            return success(try jsonValue(encodable: created))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "rss_feed_add_failed", error: error)
        }
    }

    private func handleRSSFeedUpdate(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body) else {
            return badRequest("Invalid JSON body")
        }
        guard let id = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty
        else {
            return badRequest("Missing feed id")
        }
        guard let name = object["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else {
            return badRequest("Missing feed name")
        }
        guard let url = object["url"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty
        else {
            return badRequest("Missing feed url")
        }

        let enabled = object["enabled"]?.boolValue ?? true
        let pollIntervalSec = max(15, object["pollIntervalSec"]?.intValue ?? 300)
        let tags = object["tags"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let feed = RSSFeed(
            id: id,
            name: name,
            url: url,
            enabled: enabled,
            pollIntervalSec: pollIntervalSec,
            tags: tags
        )

        do {
            let updated = try await handlers.updateRSSFeed(feed)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "rss_feed_update_failed", error: error)
        }
    }

    private func handleRSSFeedRemove(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let id = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty
        else {
            return badRequest("Missing feed id")
        }

        do {
            try await handlers.removeRSSFeed(id)
            return success(.object(["id": .string(id), "removed": .bool(true)]))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "rss_feed_remove_failed", error: error)
        }
    }

    private func handleNewsList(_ query: [String: String]) async -> IPCServerResponse {
        let limit = max(1, query["limit"].flatMap(Int.init) ?? 50)
        let since: Date?
        if let rawSince = query["since"], !rawSince.isEmpty {
            guard let parsed = DateCodec.parseISO8601(rawSince) else {
                return badRequest("Invalid since query parameter. Expected ISO8601 timestamp, for example 2026-03-02T12:34:56.123Z")
            }
            since = parsed
        } else {
            since = nil
        }

        do {
            let events = try await handlers.listNews(limit, since)
            let values = try events.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "news_list_failed", error: error)
        }
    }

    private func handlePMProfilesList() async -> IPCServerResponse {
        do {
            let profiles = try await handlers.listPMProfiles()
            let values = try profiles.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_profiles_list_failed", error: error)
        }
    }

    private func handlePMProfileGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let pmID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pmID.isEmpty
        else {
            return badRequest("Missing PM profile id query parameter")
        }

        do {
            let profile = try await handlers.getPMProfile(pmID)
            return success(try jsonValue(encodable: profile))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_profile_get_failed", error: error)
        }
    }

    private func handlePMProfileUpsert(_ body: Data) async -> IPCServerResponse {
        let profile: PMProfile
        do {
            profile = try makeISO8601Decoder().decode(PMProfile.self, from: body)
        } catch {
            return badRequest("Invalid PM profile JSON body")
        }

        do {
            let updated = try await handlers.upsertPMProfile(profile)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_profile_upsert_failed", error: error)
        }
    }

    private func handlePMMandatesList() async -> IPCServerResponse {
        do {
            let mandates = try await handlers.listPMMandates()
            let values = try mandates.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_mandates_list_failed", error: error)
        }
    }

    private func handlePMMandateGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let mandateID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !mandateID.isEmpty
        else {
            return badRequest("Missing PM mandate id query parameter")
        }

        do {
            let mandate = try await handlers.getPMMandate(mandateID)
            return success(try jsonValue(encodable: mandate))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_mandate_get_failed", error: error)
        }
    }

    private func handlePMMandateUpsert(_ body: Data) async -> IPCServerResponse {
        let mandate: PMMandate
        do {
            mandate = try makeISO8601Decoder().decode(PMMandate.self, from: body)
        } catch {
            return badRequest("Invalid PM mandate JSON body")
        }

        do {
            let updated = try await handlers.upsertPMMandate(mandate)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_mandate_upsert_failed", error: error)
        }
    }

    private func handlePMInstructionsList() async -> IPCServerResponse {
        do {
            let instructions = try await handlers.listPMInstructions()
            let values = try instructions.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_instructions_list_failed", error: error)
        }
    }

    private func handlePMInstructionGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let instructionID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !instructionID.isEmpty
        else {
            return badRequest("Missing PM instruction id query parameter")
        }

        do {
            let instruction = try await handlers.getPMInstruction(instructionID)
            return success(try jsonValue(encodable: instruction))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_instruction_get_failed", error: error)
        }
    }

    private func handlePMInstructionUpsert(_ body: Data) async -> IPCServerResponse {
        let instruction: PMInstruction
        do {
            instruction = try makeISO8601Decoder().decode(PMInstruction.self, from: body)
        } catch {
            return badRequest("Invalid PM instruction JSON body")
        }

        do {
            let updated = try await handlers.upsertPMInstruction(instruction)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_instruction_upsert_failed", error: error)
        }
    }

    private func handlePMNotebookEntriesList() async -> IPCServerResponse {
        do {
            let entries = try await handlers.listPMNotebookEntries()
            let values = try entries.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_notebook_list_failed", error: error)
        }
    }

    private func handlePMNotebookEntryGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let entryID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !entryID.isEmpty
        else {
            return badRequest("Missing PM notebook entry id query parameter")
        }

        do {
            let entry = try await handlers.getPMNotebookEntry(entryID)
            return success(try jsonValue(encodable: entry))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_notebook_entry_get_failed", error: error)
        }
    }

    private func handlePMNotebookEntryUpsert(_ body: Data) async -> IPCServerResponse {
        let entry: PMNotebookEntry
        do {
            entry = try makeISO8601Decoder().decode(PMNotebookEntry.self, from: body)
        } catch {
            return badRequest("Invalid PM notebook entry JSON body")
        }

        do {
            let updated = try await handlers.upsertPMNotebookEntry(entry)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_notebook_entry_upsert_failed", error: error)
        }
    }

    private func handlePortfolioStrategyBriefGet() async -> IPCServerResponse {
        do {
            let brief = try await handlers.getPortfolioStrategyBrief()
            return success(try jsonValue(encodable: brief))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "portfolio_strategy_brief_get_failed", error: error)
        }
    }

    private func handlePortfolioStrategyBriefUpsert(_ body: Data) async -> IPCServerResponse {
        let brief: PortfolioStrategyBrief
        do {
            brief = try makeISO8601Decoder().decode(PortfolioStrategyBrief.self, from: body)
        } catch {
            return badRequest("Invalid portfolio strategy brief JSON body")
        }

        do {
            let updated = try await handlers.upsertPortfolioStrategyBrief(brief)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "portfolio_strategy_brief_upsert_failed", error: error)
        }
    }

    private func handleRecentNewsAnalystRuntimeSettingsGet() async -> IPCServerResponse {
        do {
            let settings = try await handlers.getRecentNewsAnalystRuntimeSettings()
            return success(try jsonValue(encodable: settings))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "recent_news_analyst_runtime_get_failed", error: error)
        }
    }

    private func handleRecentNewsAnalystRuntimeSettingsUpsert(_ body: Data) async -> IPCServerResponse {
        let settings: RecentNewsAnalystRuntimeSettings
        do {
            settings = try makeISO8601Decoder().decode(RecentNewsAnalystRuntimeSettings.self, from: body)
        } catch {
            return badRequest("Invalid recent news analyst runtime settings JSON body")
        }

        do {
            let updated = try await handlers.upsertRecentNewsAnalystRuntimeSettings(settings)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "recent_news_analyst_runtime_upsert_failed", error: error)
        }
    }

    private func handleStandingBenchAnalystRuntimeSettingsGet() async -> IPCServerResponse {
        do {
            let settings = try await handlers.getStandingBenchAnalystRuntimeSettings()
            return success(try jsonValue(encodable: settings))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "standing_bench_analyst_runtime_get_failed", error: error)
        }
    }

    private func handleStandingBenchAnalystRuntimeSettingsUpsert(_ body: Data) async -> IPCServerResponse {
        let settings: StandingBenchAnalystRuntimeSettings
        do {
            settings = try makeISO8601Decoder().decode(StandingBenchAnalystRuntimeSettings.self, from: body)
        } catch {
            return badRequest("Invalid standing bench analyst runtime settings JSON body")
        }

        do {
            let updated = try await handlers.upsertStandingBenchAnalystRuntimeSettings(settings)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "standing_bench_analyst_runtime_upsert_failed", error: error)
        }
    }

    private func handlePMDecisionsList() async -> IPCServerResponse {
        do {
            let decisions = try await handlers.listPMDecisions()
            let values = try decisions.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_decisions_list_failed", error: error)
        }
    }

    private func handlePMDecisionGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let decisionID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !decisionID.isEmpty
        else {
            return badRequest("Missing PM decision id query parameter")
        }

        do {
            let decision = try await handlers.getPMDecision(decisionID)
            return success(try jsonValue(encodable: decision))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_decision_get_failed", error: error)
        }
    }

    private func handlePMDecisionUpsert(_ body: Data) async -> IPCServerResponse {
        let decision: PMDecisionRecord
        do {
            decision = try makeISO8601Decoder().decode(PMDecisionRecord.self, from: body)
        } catch {
            return badRequest("Invalid PM decision JSON body")
        }

        do {
            let updated = try await handlers.upsertPMDecision(decision)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_decision_upsert_failed", error: error)
        }
    }

    private func handlePMApprovalRequestsList() async -> IPCServerResponse {
        do {
            let requests = try await handlers.listPMApprovalRequests()
            let values = try requests.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_approval_requests_list_failed", error: error)
        }
    }

    private func handlePMApprovalRequestGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let approvalRequestID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !approvalRequestID.isEmpty
        else {
            return badRequest("Missing PM approval request id query parameter")
        }

        do {
            let approvalRequest = try await handlers.getPMApprovalRequest(approvalRequestID)
            return success(try jsonValue(encodable: approvalRequest))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_approval_request_get_failed", error: error)
        }
    }

    private func handlePMApprovalRequestUpsert(_ body: Data) async -> IPCServerResponse {
        let approvalRequest: PMApprovalRequest
        do {
            approvalRequest = try makeISO8601Decoder().decode(PMApprovalRequest.self, from: body)
        } catch {
            return badRequest("Invalid PM approval request JSON body")
        }

        do {
            let updated = try await handlers.upsertPMApprovalRequest(approvalRequest)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_approval_request_upsert_failed", error: error)
        }
    }

    private func handlePMExecutionReadiness(_ query: [String: String]) async -> IPCServerResponse {
        guard let approvalRequestID = query["approvalRequestId"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !approvalRequestID.isEmpty
        else {
            return badRequest("Missing approvalRequestId query parameter")
        }

        do {
            let assessment = try await handlers.assessPMExecutionRouting(approvalRequestID)
            return success(try jsonValue(encodable: assessment))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_execution_readiness_failed", error: error)
        }
    }

    private func handlePMExecutionRoute(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let approvalRequestID = object["approvalRequestId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !approvalRequestID.isEmpty
        else {
            return badRequest("Missing approvalRequestId")
        }

        do {
            let assessment = try await handlers.routePMExecutionApprovedIntent(approvalRequestID)
            return success(try jsonValue(encodable: assessment))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_execution_route_failed", error: error)
        }
    }

    private func handlePMCommunicationSessionsList() async -> IPCServerResponse {
        do {
            let sessions = try await handlers.listPMCommunicationSessions()
            let values = try sessions.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_communication_sessions_list_failed", error: error)
        }
    }

    private func handlePMCommunicationSessionGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let sessionID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionID.isEmpty
        else {
            return badRequest("Missing PM communication session id query parameter")
        }

        do {
            let session = try await handlers.getPMCommunicationSession(sessionID)
            return success(try jsonValue(encodable: session))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_communication_session_get_failed", error: error)
        }
    }

    private func handlePMCommunicationSessionUpsert(_ body: Data) async -> IPCServerResponse {
        let session: PMCommunicationSession
        do {
            session = try makeISO8601Decoder().decode(PMCommunicationSession.self, from: body)
        } catch {
            return badRequest("Invalid PM communication session JSON body")
        }

        do {
            let updated = try await handlers.upsertPMCommunicationSession(session)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_communication_session_upsert_failed", error: error)
        }
    }

    private func handlePMCommunicationMessagesList() async -> IPCServerResponse {
        do {
            let messages = try await handlers.listPMCommunicationMessages()
            let values = try messages.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_communication_messages_list_failed", error: error)
        }
    }

    private func handlePMCommunicationMessageGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let messageID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !messageID.isEmpty
        else {
            return badRequest("Missing PM communication message id query parameter")
        }

        do {
            let message = try await handlers.getPMCommunicationMessage(messageID)
            return success(try jsonValue(encodable: message))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_communication_message_get_failed", error: error)
        }
    }

    private func handlePMCommunicationMessageUpsert(_ body: Data) async -> IPCServerResponse {
        let message: PMCommunicationMessage
        do {
            message = try makeISO8601Decoder().decode(PMCommunicationMessage.self, from: body)
        } catch {
            return badRequest("Invalid PM communication message JSON body")
        }

        do {
            let updated = try await handlers.upsertPMCommunicationMessage(message)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_communication_message_upsert_failed", error: error)
        }
    }

    private func handlePMDelegationsList() async -> IPCServerResponse {
        do {
            let delegations = try await handlers.listPMDelegations()
            let values = try delegations.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_delegations_list_failed", error: error)
        }
    }

    private func handlePMDelegationGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let delegationID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !delegationID.isEmpty
        else {
            return badRequest("Missing PM delegation id query parameter")
        }

        do {
            let delegation = try await handlers.getPMDelegation(delegationID)
            return success(try jsonValue(encodable: delegation))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_delegation_get_failed", error: error)
        }
    }

    private func handlePMDelegationUpsert(_ body: Data) async -> IPCServerResponse {
        let delegation: PMDelegationRecord
        do {
            delegation = try makeISO8601Decoder().decode(PMDelegationRecord.self, from: body)
        } catch {
            return badRequest("Invalid PM delegation JSON body")
        }

        do {
            let updated = try await handlers.upsertPMDelegation(delegation)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_delegation_upsert_failed", error: error)
        }
    }

    private func handlePMDelegationFollowUp(_ body: Data) async -> IPCServerResponse {
        let request: PMDelegationFollowUpRequest
        do {
            request = try makeISO8601Decoder().decode(PMDelegationFollowUpRequest.self, from: body)
        } catch {
            return badRequest("Invalid PM delegation follow-up JSON body")
        }

        do {
            let result = try await handlers.submitPMDelegationFollowUp(request)
            return success(try jsonValue(encodable: result))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_delegation_follow_up_failed", error: error)
        }
    }

    private func handlePMDelegationLaunch(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let delegationID = object["delegationId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !delegationID.isEmpty
        else {
            return badRequest("Missing delegationId")
        }

        let draftSignal = object["draftSignal"]?.boolValue ?? false
        let draftProposal = object["draftProposal"]?.boolValue ?? false
        if draftProposal && draftSignal == false {
            return badRequest("draftProposal requires draftSignal")
        }

        do {
            let result = try await handlers.launchPMDelegation(delegationID, draftSignal, draftProposal)
            return success(try jsonValue(encodable: result))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "pm_delegation_launch_failed", error: error)
        }
    }

    private func handleAnalystChartersList() async -> IPCServerResponse {
        do {
            let charters = try await handlers.listAnalystCharters()
            let values = try charters.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_charters_list_failed", error: error)
        }
    }

    private func handleAnalystCharterGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let charterID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !charterID.isEmpty
        else {
            return badRequest("Missing analyst charter id query parameter")
        }

        do {
            let charter = try await handlers.getAnalystCharter(charterID)
            return success(try jsonValue(encodable: charter))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_charter_get_failed", error: error)
        }
    }

    private func handleAnalystCharterUpsert(_ body: Data) async -> IPCServerResponse {
        let charter: AnalystCharter
        do {
            charter = try makeISO8601Decoder().decode(AnalystCharter.self, from: body)
        } catch {
            return badRequest("Invalid analyst charter JSON body")
        }

        do {
            let updated = try await handlers.upsertAnalystCharter(charter)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_charter_upsert_failed", error: error)
        }
    }

    private func handleAnalystSourceAccessSuggestionsList() async -> IPCServerResponse {
        do {
            let suggestions = try await handlers.listAnalystSourceAccessSuggestions()
            let values = try suggestions.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_source_access_suggestions_list_failed", error: error)
        }
    }

    private func handleAnalystSourceAccessSuggestionGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let suggestionID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !suggestionID.isEmpty
        else {
            return badRequest("Missing analyst source access suggestion id query parameter")
        }

        do {
            let suggestion = try await handlers.getAnalystSourceAccessSuggestion(suggestionID)
            return success(try jsonValue(encodable: suggestion))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_source_access_suggestion_get_failed", error: error)
        }
    }

    private func handleAnalystSourceAccessSuggestionUpsert(_ body: Data) async -> IPCServerResponse {
        let suggestion: AnalystSourceAccessSuggestionRecord
        do {
            suggestion = try makeISO8601Decoder().decode(AnalystSourceAccessSuggestionRecord.self, from: body)
        } catch {
            return badRequest("Invalid analyst source access suggestion JSON body")
        }

        do {
            let updated = try await handlers.upsertAnalystSourceAccessSuggestion(suggestion)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_source_access_suggestion_upsert_failed", error: error)
        }
    }

    private func handleAnalystTasksList() async -> IPCServerResponse {
        do {
            let tasks = try await handlers.listAnalystTasks()
            let values = try tasks.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_tasks_list_failed", error: error)
        }
    }

    private func handleAnalystTaskGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let taskID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !taskID.isEmpty
        else {
            return badRequest("Missing analyst task id query parameter")
        }

        do {
            let task = try await handlers.getAnalystTask(taskID)
            return success(try jsonValue(encodable: task))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_task_get_failed", error: error)
        }
    }

    private func handleAnalystTaskUpsert(_ body: Data) async -> IPCServerResponse {
        let task: AnalystTask
        do {
            task = try makeISO8601Decoder().decode(AnalystTask.self, from: body)
        } catch {
            return badRequest("Invalid analyst task JSON body")
        }

        do {
            let updated = try await handlers.upsertAnalystTask(task)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_task_upsert_failed", error: error)
        }
    }

    private func handleAnalystFindingsList() async -> IPCServerResponse {
        do {
            let findings = try await handlers.listAnalystFindings()
            let values = try findings.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_findings_list_failed", error: error)
        }
    }

    private func handleAnalystFindingGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let findingID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !findingID.isEmpty
        else {
            return badRequest("Missing analyst finding id query parameter")
        }

        do {
            let finding = try await handlers.getAnalystFinding(findingID)
            return success(try jsonValue(encodable: finding))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_finding_get_failed", error: error)
        }
    }

    private func handleAnalystMemosList() async -> IPCServerResponse {
        do {
            let memos = try await handlers.listAnalystMemos()
            let values = try memos.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_memos_list_failed", error: error)
        }
    }

    private func handleAnalystMemoGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let memoID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !memoID.isEmpty
        else {
            return badRequest("Missing analyst memo id query parameter")
        }

        do {
            let memo = try await handlers.getAnalystMemo(memoID)
            return success(try jsonValue(encodable: memo))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_memo_get_failed", error: error)
        }
    }

    private func handleAnalystNewsList(_ query: [String: String]) async -> IPCServerResponse {
        let limit = max(1, query["limit"].flatMap(Int.init) ?? 50)
        let since: Date?
        if let rawSince = query["since"], !rawSince.isEmpty {
            guard let parsed = DateCodec.parseISO8601(rawSince) else {
                return badRequest("Invalid since query parameter. Expected ISO8601 timestamp, for example 2026-03-02T12:34:56.123Z")
            }
            since = parsed
        } else {
            since = nil
        }

        do {
            let events = try await handlers.listNews(limit, since)
            let values = try events.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_news_list_failed", error: error)
        }
    }

    private func handleSignalsList(_ query: [String: String]) async -> IPCServerResponse {
        let limit = max(1, query["limit"].flatMap(Int.init) ?? 100)
        let status: SignalStatus?
        if let rawStatus = query["status"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawStatus.isEmpty {
            guard let resolved = SignalStatus(rawValue: rawStatus) else {
                return badRequest("Invalid status query parameter")
            }
            status = resolved
        } else {
            status = nil
        }

        do {
            let signals = try await handlers.listSignals(status, limit)
            let values = try signals.map { try jsonValue(encodable: $0) }
            return success(.array(values))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "signals_list_failed", error: error)
        }
    }

    private func handleSignalGet(_ query: [String: String]) async -> IPCServerResponse {
        guard let signalID = query["id"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !signalID.isEmpty
        else {
            return badRequest("Missing signal id query parameter")
        }

        do {
            let signal = try await handlers.getSignal(signalID)
            return success(try jsonValue(encodable: signal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "signal_get_failed", error: error)
        }
    }

    private func handleSignalAcknowledge(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let signalID = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !signalID.isEmpty
        else {
            return badRequest("Missing signal id")
        }

        do {
            let signal = try await handlers.acknowledgeSignal(signalID)
            return success(try jsonValue(encodable: signal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "signal_ack_failed", error: error)
        }
    }

    private func handleSignalArchive(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let signalID = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !signalID.isEmpty
        else {
            return badRequest("Missing signal id")
        }

        do {
            let signal = try await handlers.archiveSignal(signalID)
            return success(try jsonValue(encodable: signal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "signal_archive_failed", error: error)
        }
    }

    private func handleAnalystEvidenceBundleUpsert(_ body: Data) async -> IPCServerResponse {
        let bundle: AnalystEvidenceBundle
        do {
            bundle = try makeISO8601Decoder().decode(AnalystEvidenceBundle.self, from: body)
        } catch {
            return badRequest("Invalid analyst evidence bundle JSON body")
        }

        do {
            let updated = try await handlers.upsertAnalystEvidenceBundle(bundle)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_evidence_bundle_upsert_failed", error: error)
        }
    }

    private func handleAnalystMemoUpsert(_ body: Data) async -> IPCServerResponse {
        let memo: AnalystMemo
        do {
            memo = try makeISO8601Decoder().decode(AnalystMemo.self, from: body)
        } catch {
            return badRequest("Invalid analyst memo JSON body")
        }

        do {
            let updated = try await handlers.upsertAnalystMemo(memo)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_memo_upsert_failed", error: error)
        }
    }

    private func handleAnalystFindingUpsert(_ body: Data) async -> IPCServerResponse {
        let finding: AnalystFinding
        do {
            finding = try makeISO8601Decoder().decode(AnalystFinding.self, from: body)
        } catch {
            return badRequest("Invalid analyst finding JSON body")
        }

        do {
            let updated = try await handlers.upsertAnalystFinding(finding)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_finding_upsert_failed", error: error)
        }
    }

    private func handleAnalystFindingDraftSignal(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let findingID = object["findingId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !findingID.isEmpty
        else {
            return badRequest("Missing findingId")
        }

        do {
            let signal = try await handlers.draftSignalFromAnalystFinding(findingID)
            return success(try jsonValue(encodable: signal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_finding_draft_signal_failed", error: error)
        }
    }

    private func handleAnalystSignalDraftProposal(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let signalID = object["signalId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !signalID.isEmpty
        else {
            return badRequest("Missing signalId")
        }

        let strategyID: String
        if let rawStrategyID = object["strategyId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawStrategyID.isEmpty {
            strategyID = rawStrategyID
        } else {
            strategyID = "heartbeat"
        }

        do {
            let proposal = try await handlers.draftProposalFromAnalystSignal(signalID, strategyID)
            return success(try jsonValue(encodable: proposal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "analyst_signal_draft_proposal_failed", error: error)
        }
    }

    private func handleProposalUpsert(_ body: Data) async -> IPCServerResponse {
        do {
            let proposal = try decodeProposal(body)
            let updated = try await handlers.upsertProposal(proposal)
            return success(try jsonValue(encodable: updated))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch let error as DecodingError {
            return badRequest("Invalid proposal JSON: \(error.localizedDescription)")
        } catch {
            return internalFailure(code: "proposal_upsert_failed", error: error)
        }
    }

    private func handleProposalSubmit(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let id = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty
        else {
            return badRequest("Missing proposal id")
        }

        do {
            let proposal = try await handlers.submitProposal(id)
            return success(try jsonValue(encodable: proposal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "proposal_submit_failed", error: error)
        }
    }

    private func handleProposalApproval(
        _ body: Data,
        approve: Bool
    ) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let id = object["id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty
        else {
            return badRequest("Missing proposal id")
        }

        let reviewer = object["reviewedBy"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = object["notes"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let notes, !notes.isEmpty else {
            return mappedControlError(StrategyProposalExecutionError.reviewNotesRequired)
        }
        let resolvedReviewer = (reviewer?.isEmpty == false) ? reviewer! : "human"

        do {
            let proposal: StrategyProposal
            if approve {
                proposal = try await handlers.approveProposalPaper(id, resolvedReviewer, notes)
            } else {
                proposal = try await handlers.denyProposalPaper(id, resolvedReviewer, notes)
            }
            return success(try jsonValue(encodable: proposal))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: approve ? "proposal_approve_failed" : "proposal_deny_failed", error: error)
        }
    }

    private func handleRunExport(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let runID = object["runId"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !runID.isEmpty
        else {
            return badRequest("Missing runId")
        }

        do {
            let json = try await handlers.exportRun(runID)
            return success(.object(["runId": .string(runID), "json": .string(json)]))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch {
            return internalFailure(code: "run_export_failed", error: error)
        }
    }

    private func handleReplayIngest(_ body: Data) async -> IPCServerResponse {
        do {
            let request = try decodeReplayIngestRequest(body)
            let result = try await handlers.replayIngest(request)
            return success(try jsonValue(encodable: result))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch _ as DecodingError {
            return badRequest("Invalid replay ingest JSON. Expected ISO8601 timestamps for date fields.")
        } catch {
            return internalFailure(code: "replay_ingest_failed", error: error)
        }
    }

    private func handleReplayRun(_ body: Data) async -> IPCServerResponse {
        do {
            let request = try decodeReplayRunRequest(body)
            let result = try await handlers.replayRun(request)
            return success(try jsonValue(encodable: result))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch _ as DecodingError {
            return badRequest("Invalid replay run JSON. Expected ISO8601 timestamps for date fields.")
        } catch {
            return internalFailure(code: "replay_run_failed", error: error)
        }
    }

    private func handleReplayQuick(_ body: Data) async -> IPCServerResponse {
        do {
            let request = try decodeReplayQuickRequest(body)
            let result = try await handlers.replayQuick(request)
            return success(try jsonValue(encodable: result))
        } catch let controlError as AgentControlError {
            return mappedControlError(controlError)
        } catch _ as DecodingError {
            return badRequest("Invalid replay quick JSON. Expected ISO8601 timestamps for date fields.")
        } catch {
            return internalFailure(code: "replay_quick_failed", error: error)
        }
    }

    private func handleKillSwitch(_ body: Data) async -> IPCServerResponse {
        guard let object = decodeObject(body),
              let enabled = object["enabled"]?.boolValue
        else {
            return badRequest("Body must include boolean field: enabled")
        }

        await handlers.setKillSwitch(enabled)
        return success(.object(["enabled": .bool(enabled)]))
    }

    private func isAuthorized(_ headers: [String: String]) -> Bool {
        headers["x-agent-token"] == authToken
    }

    private func decodeObject(_ data: Data) -> [String: JSONValue]? {
        guard !data.isEmpty else {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return nil
        }
        return decoded.objectValue
    }

    private func decodeProposal(_ data: Data) throws -> StrategyProposal {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return try decoder.decode(StrategyProposal.self, from: data)
    }

    private func decodeReplayIngestRequest(_ data: Data) throws -> ReplayIngestRequest {
        try makeISO8601Decoder().decode(ReplayIngestRequest.self, from: data)
    }

    private func decodeReplayRunRequest(_ data: Data) throws -> ReplayRunRequest {
        try makeISO8601Decoder().decode(ReplayRunRequest.self, from: data)
    }

    private func decodeReplayQuickRequest(_ data: Data) throws -> ReplayQuickRequest {
        try makeISO8601Decoder().decode(ReplayQuickRequest.self, from: data)
    }

    private func success(_ result: JSONValue) -> IPCServerResponse {
        encodeEnvelope(
            statusCode: 200,
            envelope: AgentControlEnvelope(ok: true, result: result)
        )
    }

    private func badRequest(_ message: String) -> IPCServerResponse {
        failureResponse(statusCode: 400, code: "bad_request", message: message)
    }

    private func mappedControlError(_ error: AgentControlError) -> IPCServerResponse {
        failureResponse(
            statusCode: statusCode(for: error.code),
            code: error.code,
            message: error.message
        )
    }

    private func internalFailure(code: String, error: Error) -> IPCServerResponse {
        failureResponse(statusCode: 500, code: code, message: error.localizedDescription)
    }

    private func statusCode(for code: String) -> Int {
        if code == "unauthorized" {
            return 401
        }
        if code == "not_found" || code.hasSuffix("_not_found") {
            return 404
        }
        return 400
    }

    private func failureResponse(statusCode: Int, code: String, message: String) -> IPCServerResponse {
        encodeEnvelope(
            statusCode: statusCode,
            envelope: AgentControlEnvelope(
                ok: false,
                error: AgentControlErrorBody(code: code, message: message)
            )
        )
    }

    private func encodeEnvelope(statusCode: Int, envelope: AgentControlEnvelope) -> IPCServerResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = (try? encoder.encode(envelope)) ?? Data("{\"ok\":false,\"error\":{\"code\":\"encode_failed\",\"message\":\"Failed to encode response\"}}".utf8)
        return IPCServerResponse(statusCode: statusCode, body: body)
    }

    private func jsonValue(strategyStatus: StrategyStatusSnapshot) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(strategyStatus.id),
            "name": .string(strategyStatus.name),
            "state": .string(strategyStatus.state.rawValue),
            "parameters": .object(strategyStatus.parameters)
        ]
        object["lastMessage"] = strategyStatus.lastMessage.map(JSONValue.string) ?? .null
        object["startTime"] = strategyStatus.startTime.map(JSONValue.string) ?? .null
        object["proposalId"] = strategyStatus.proposalId.map(JSONValue.string) ?? .null
        if let constraints = strategyStatus.proposalConstraints {
            object["proposalConstraints"] = (try? jsonValue(encodable: constraints)) ?? .null
        } else {
            object["proposalConstraints"] = .null
        }
        return .object(object)
    }

    private func jsonValue<T: Encodable>(encodable: T) throws -> JSONValue {
        let data = try Self.makeISO8601Encoder().encode(encodable)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private func parseRoute(_ rawPath: String) -> (path: String, query: [String: String]) {
        let parts = rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = parts.first.map(String.init) ?? rawPath
        guard parts.count > 1 else {
            return (path, [:])
        }
        let queryText = String(parts[1])
        var query: [String: String] = [:]
        for pair in queryText.split(separator: "&") {
            let pieces = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let rawKey = pieces.first else {
                continue
            }
            let key = String(rawKey).removingPercentEncoding ?? String(rawKey)
            let value: String
            if pieces.count > 1 {
                value = String(pieces[1]).removingPercentEncoding ?? String(pieces[1])
            } else {
                value = ""
            }
            query[key] = value
        }
        return (path, query)
    }

    private static func makeISO8601Encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return encoder
    }

    private func makeISO8601Decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
        return decoder
    }
}
